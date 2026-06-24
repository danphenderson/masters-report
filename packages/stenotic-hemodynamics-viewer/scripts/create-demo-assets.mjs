import { createHash } from "node:crypto";
import { mkdirSync, readFileSync, rmSync, statSync, writeFileSync } from "node:fs";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";

const root = dirname(dirname(fileURLToPath(import.meta.url)));
const outDir = join(root, "public", "data", "demo");
const geometryDir = join(outDir, "geometry");
const snapshotRoot = join(outDir, "snapshots");

rmSync(outDir, { recursive: true, force: true });
mkdirSync(geometryDir, { recursive: true });
mkdirSync(snapshotRoot, { recursive: true });

const axialCount = 18;
const segments = 36;
const lengthCm = 6.0;
const frameTimes = [0, 0.04, 0.08, 0.12, 0.16, 0.2];
const period = 0.2;
const positions = [];

function stenosisProfile(z) {
  const throat = Math.exp(-((z - 3.0) ** 2) / (2 * 0.62 ** 2));
  return {
    throat,
    radius: 0.19 - 0.071 * throat,
  };
}

for (let iz = 0; iz < axialCount; iz += 1) {
  const z = (lengthCm * iz) / (axialCount - 1);
  const { radius } = stenosisProfile(z);
  for (let it = 0; it < segments; it += 1) {
    const theta = (2 * Math.PI * it) / segments;
    positions.push(radius * Math.cos(theta), radius * Math.sin(theta), z);
  }
}

const indices = [];
for (let iz = 0; iz < axialCount - 1; iz += 1) {
  const base = iz * segments;
  const next = (iz + 1) * segments;
  for (let it = 0; it < segments; it += 1) {
    const a = base + it;
    const b = base + ((it + 1) % segments);
    const c = next + it;
    const d = next + ((it + 1) % segments);
    indices.push(a, c, b, b, c, d);
  }
}

function writeTyped(relativePath, array) {
  const fullPath = join(outDir, relativePath);
  mkdirSync(dirname(fullPath), { recursive: true });
  writeFileSync(fullPath, Buffer.from(array.buffer, array.byteOffset, array.byteLength));
  return fullPath;
}

function descriptor(relativePath, fullPath) {
  return {
    path: relativePath,
    byte_size: statSync(fullPath).size,
    sha256: createHash("sha256").update(readFileSync(fullPath)).digest("hex"),
  };
}

function range(values) {
  return { min: Math.min(...values), max: Math.max(...values) };
}

function mergeRanges(ranges) {
  return {
    min: Math.min(...ranges.map((entry) => entry.min)),
    max: Math.max(...ranges.map((entry) => entry.max)),
  };
}

function frameFields(timeS) {
  const velocity = [];
  const pressure = [];
  const displacement = [];
  const speed = [];
  const displacementMagnitude = [];
  const phase = (2 * Math.PI * timeS) / period;

  for (let iz = 0; iz < axialCount; iz += 1) {
    const z = (lengthCm * iz) / (axialCount - 1);
    const { throat, radius } = stenosisProfile(z);
    const axialPhase = phase - z * 0.72;
    const pulse = 1 + 0.23 * Math.sin(axialPhase);
    const wallPulse = Math.sin(axialPhase + 0.45);
    for (let it = 0; it < segments; it += 1) {
      const theta = (2 * Math.PI * it) / segments;
      const radialWave = 1 + 0.16 * Math.cos(theta - phase);
      const uz = (19 + 46 * throat) * pulse * (0.94 + 0.06 * Math.cos(2 * theta));
      const radialSpeed = 0.45 * throat * Math.sin(theta + phase);
      const vx = radialSpeed * Math.cos(theta);
      const vy = radialSpeed * Math.sin(theta);
      const p = 930 - 78 * (z / lengthCm) - 52 * throat + 22 * throat * Math.sin(axialPhase);
      const eta = (0.0016 + 0.0068 * throat) * wallPulse * radialWave;

      velocity.push(vx, vy, uz);
      pressure.push(p);
      displacement.push(eta * Math.cos(theta), eta * Math.sin(theta), 0.0007 * throat * Math.cos(axialPhase));
      speed.push(Math.hypot(vx, vy, uz));
      displacementMagnitude.push(Math.hypot(eta, 0.0007 * throat * Math.cos(axialPhase)));
    }
  }

  return {
    velocity,
    pressure,
    displacement,
    ranges: {
      speed_cm_s: range(speed),
      velocity_components_cm_s: {
        ux: range(velocity.filter((_, index) => index % 3 === 0)),
        uy: range(velocity.filter((_, index) => index % 3 === 1)),
        uz: range(velocity.filter((_, index) => index % 3 === 2)),
      },
      pressure_dyn_cm2: range(pressure),
      displacement_magnitude_cm: range(displacementMagnitude),
    },
  };
}

const referencePath = writeTyped("geometry/reference_positions.f32", new Float32Array(positions));
const surfacePath = writeTyped("geometry/surface_indices.u32", new Uint32Array(indices));
const snapshots = [];
const timeAxis = [];
const speedRanges = [];
const pressureRanges = [];
const displacementRanges = [];

frameTimes.forEach((timeS, index) => {
  const id = `t${String(index).padStart(4, "0")}`;
  const frameDir = join("snapshots", id);
  const fields = frameFields(timeS);
  const velocityPath = writeTyped(join(frameDir, "velocity.f32"), new Float32Array(fields.velocity));
  const pressurePath = writeTyped(join(frameDir, "pressure.f32"), new Float32Array(fields.pressure));
  const displacementPath = writeTyped(join(frameDir, "displacement.f32"), new Float32Array(fields.displacement));
  const derivedPath = join(outDir, frameDir, "derived.json");
  writeFileSync(derivedPath, `${JSON.stringify(fields.ranges, null, 2)}\n`);

  speedRanges.push(fields.ranges.speed_cm_s);
  pressureRanges.push(fields.ranges.pressure_dyn_cm2);
  displacementRanges.push(fields.ranges.displacement_magnitude_cm);
  timeAxis.push({
    frame_id: id,
    time_s: timeS,
    delta_t_s: index === 0 ? null : timeS - frameTimes[index - 1],
  });
  snapshots.push({
    id,
    source_id: `snapshot-t${String(timeS).replace(".", "p")}`,
    time_s: timeS,
    fields: {
      velocity: {
        components: 3,
        centering: "node",
        units: "cm/s",
        asset: descriptor(join(frameDir, "velocity.f32"), velocityPath),
      },
      pressure: {
        components: 1,
        centering: "node",
        units: "dyn/cm^2",
        asset: descriptor(join(frameDir, "pressure.f32"), pressurePath),
      },
      displacement: {
        components: 3,
        centering: "node",
        units: "cm",
        asset: descriptor(join(frameDir, "displacement.f32"), displacementPath),
      },
    },
    derived: descriptor(join(frameDir, "derived.json"), derivedPath),
    ranges: fields.ranges,
  });
});

const globalRanges = {
  speed_cm_s: mergeRanges(speedRanges),
  pressure_dyn_cm2: mergeRanges(pressureRanges),
  displacement_magnitude_cm: mergeRanges(displacementRanges),
};

const manifest = {
  schema_version: 2,
  case_id: "demo-sev23",
  case_label: "Demo sev23 temporal native resolved-FSI",
  severity_percent: 23,
  result_class: "native_resolved_fsi_temporal_web_export_fixture",
  claim_boundary: "native resolved-FSI artifact/operator evidence only; not paper-grade native resolved-FSI Section 4.1 reproduction",
  coordinate_mode: "reference",
  geometry_mode: "surface",
  units: {
    length: "cm",
    velocity: "cm/s",
    pressure: "dyn/cm^2",
    displacement: "cm",
    time: "s",
  },
  snapshot_count: snapshots.length,
  estimated_playback_fps: 12,
  time_axis: timeAxis,
  available_fields: [
    {
      name: "velocity",
      components: 3,
      centering: "node",
      units: "cm/s",
      range: globalRanges.speed_cm_s,
    },
    {
      name: "speed",
      components: 1,
      centering: "node",
      units: "cm/s",
      range: globalRanges.speed_cm_s,
    },
    {
      name: "pressure",
      components: 1,
      centering: "node",
      units: "dyn/cm^2",
      range: globalRanges.pressure_dyn_cm2,
    },
    {
      name: "displacement",
      components: 3,
      centering: "node",
      units: "cm",
      range: globalRanges.displacement_magnitude_cm,
    },
  ],
  global_ranges: globalRanges,
  mesh: {
    node_indexing: "zero_based",
    index_dtype: "uint32",
    field_dtype: "float32",
  },
  source: {
    fixture: true,
    input_production_dir: "synthetic temporal demo",
  },
  geometry: {
    node_count: positions.length / 3,
    tetrahedron_count: 0,
    surface_triangle_count: indices.length / 3,
    reference_positions: descriptor("geometry/reference_positions.f32", referencePath),
    surface_indices: descriptor("geometry/surface_indices.u32", surfacePath),
    tetra_indices_debug: null,
  },
  snapshots,
  skipped_snapshots: [],
  sidecars: {},
  observations: {},
};

writeFileSync(join(outDir, "manifest.json"), `${JSON.stringify(manifest, null, 2)}\n`);
console.log(`wrote ${snapshots.length} demo frames to ${outDir}`);
