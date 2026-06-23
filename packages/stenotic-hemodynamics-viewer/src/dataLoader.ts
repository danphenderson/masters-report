import type {
  AssetDescriptor,
  FieldDescriptor,
  FieldName,
  FrameDescriptor,
  LoadedSnapshotFrame,
  LoadedVizData,
  NumericRange,
  SnapshotFieldAssets,
  WebVizManifest,
} from "./types";

const frameCache = new Map<string, Promise<LoadedSnapshotFrame>>();

function assetUrl(manifestUrl: string, asset: AssetDescriptor): string {
  return new URL(asset.path, manifestUrl).toString();
}

function assertAssetByteLength(asset: AssetDescriptor, buffer: ArrayBuffer): void {
  if (buffer.byteLength !== asset.byte_size) {
    throw new Error(`asset ${asset.path} has ${buffer.byteLength} bytes; expected ${asset.byte_size}`);
  }
}

async function loadBinaryAsset(asset: AssetDescriptor, manifestUrl: string): Promise<ArrayBuffer> {
  const response = await fetch(assetUrl(manifestUrl, asset));
  if (!response.ok) {
    throw new Error(`failed to load ${asset.path}: HTTP ${response.status}`);
  }
  const buffer = await response.arrayBuffer();
  assertAssetByteLength(asset, buffer);
  return buffer;
}

async function loadFloat32(asset: AssetDescriptor, manifestUrl: string): Promise<Float32Array> {
  const buffer = await loadBinaryAsset(asset, manifestUrl);
  if (buffer.byteLength % Float32Array.BYTES_PER_ELEMENT !== 0) {
    throw new Error(`asset ${asset.path} is not aligned to Float32 elements`);
  }
  return new Float32Array(buffer);
}

async function loadUint32(asset: AssetDescriptor, manifestUrl: string): Promise<Uint32Array> {
  const buffer = await loadBinaryAsset(asset, manifestUrl);
  if (buffer.byteLength % Uint32Array.BYTES_PER_ELEMENT !== 0) {
    throw new Error(`asset ${asset.path} is not aligned to Uint32 elements`);
  }
  return new Uint32Array(buffer);
}

function assertManifestShape(manifest: WebVizManifest): void {
  if (manifest.schema_version !== 1 && manifest.schema_version !== 2) {
    throw new Error(`unsupported manifest schema_version ${manifest.schema_version}`);
  }
  if (manifest.geometry.node_count <= 0 || manifest.geometry.surface_triangle_count <= 0) {
    throw new Error("manifest geometry is empty");
  }
  if (!Array.isArray(manifest.snapshots) || manifest.snapshots.length <= 0) {
    throw new Error("manifest has no snapshots");
  }
  if (manifest.schema_version === 1 && !manifest.fields?.velocity?.asset) {
    throw new Error("v1 manifest is missing the required velocity field");
  }
}

function expectedFieldValues(nodeCount: number, field: FieldDescriptor): number {
  return nodeCount * field.components;
}

function assertFieldShape(nodeCount: number, field: FieldDescriptor, label: string): void {
  if (field.centering !== "node") {
    throw new Error(`${label} field centering ${field.centering}; expected node`);
  }
  if (!Number.isInteger(field.components) || field.components <= 0) {
    throw new Error(`${label} field has invalid component count ${field.components}`);
  }
  if (!field.asset) {
    throw new Error(`${label} field is missing an asset descriptor`);
  }
  const expectedBytes = expectedFieldValues(nodeCount, field) * Float32Array.BYTES_PER_ELEMENT;
  if (field.asset.byte_size !== expectedBytes) {
    throw new Error(`${label} byte_size ${field.asset.byte_size}; expected ${expectedBytes}`);
  }
}

function rangeOrNull(range: unknown): NumericRange | null {
  if (!range || typeof range !== "object") {
    return null;
  }
  const candidate = range as Partial<NumericRange>;
  return {
    min: typeof candidate.min === "number" ? candidate.min : null,
    max: typeof candidate.max === "number" ? candidate.max : null,
  };
}

function normalizeFrames(manifest: WebVizManifest): FrameDescriptor[] {
  return manifest.snapshots.map((snapshot, index) => {
    const fields = snapshot.fields ?? manifest.fields;
    if (!fields?.velocity?.asset) {
      throw new Error(`snapshot ${snapshot.id} is missing velocity assets`);
    }
    assertFieldShape(manifest.geometry.node_count, fields.velocity, `snapshot ${snapshot.id}.velocity`);
    if (fields.pressure?.asset) {
      assertFieldShape(manifest.geometry.node_count, fields.pressure, `snapshot ${snapshot.id}.pressure`);
    }
    if (fields.displacement?.asset) {
      assertFieldShape(manifest.geometry.node_count, fields.displacement, `snapshot ${snapshot.id}.displacement`);
    }
    return {
      index,
      id: snapshot.id,
      time_s: snapshot.time_s,
      sourceId: snapshot.source_id,
      fields,
      ranges: snapshot.ranges,
    };
  });
}

function fieldCatalog(manifest: WebVizManifest): LoadedVizData["fieldCatalog"] {
  const available = manifest.available_fields ?? [];
  const byName = new Map(available.map((field) => [field.name, field]));
  const speedRange = rangeOrNull(manifest.global_ranges?.speed_cm_s);
  const pressureRange = rangeOrNull(manifest.global_ranges?.pressure_dyn_cm2);
  const displacementRange = rangeOrNull(manifest.global_ranges?.displacement_magnitude_cm);
  return {
    velocity: {
      label: "Velocity vector",
      units: byName.get("velocity")?.units ?? manifest.units.velocity ?? "cm/s",
      range: speedRange,
    },
    speed: {
      label: "Velocity magnitude",
      units: byName.get("speed")?.units ?? manifest.units.velocity ?? "cm/s",
      range: speedRange,
    },
    pressure: {
      label: "Pressure",
      units: byName.get("pressure")?.units ?? manifest.units.pressure ?? "dyn/cm^2",
      range: pressureRange,
    },
    displacement: {
      label: "Wall displacement magnitude",
      units: byName.get("displacement")?.units ?? manifest.units.displacement ?? "cm",
      range: displacementRange,
    },
  };
}

function normalizeGlobalRanges(manifest: WebVizManifest): Record<string, NumericRange> {
  if (manifest.global_ranges) {
    return manifest.global_ranges;
  }
  const first = manifest.snapshots[0]?.ranges ?? {};
  return {
    speed_cm_s: rangeOrNull(first.speed_cm_s) ?? { min: null, max: null },
    pressure_dyn_cm2: rangeOrNull(first.pressure_dyn_cm2) ?? { min: null, max: null },
    displacement_magnitude_cm: rangeOrNull(first.displacement_magnitude_cm) ?? { min: null, max: null },
  };
}

export function resolveManifestUrl(): string {
  const query = new URLSearchParams(window.location.search);
  const override = query.get("manifest");
  if (override) {
    return new URL(override, window.location.href).toString();
  }
  return new URL(`${import.meta.env.BASE_URL}data/demo/manifest.json`, window.location.origin).toString();
}

export async function loadVizData(manifestUrl: string): Promise<LoadedVizData> {
  const manifestResponse = await fetch(manifestUrl);
  if (!manifestResponse.ok) {
    throw new Error(`failed to load manifest: HTTP ${manifestResponse.status}`);
  }
  const manifest = (await manifestResponse.json()) as WebVizManifest;
  assertManifestShape(manifest);

  const [positions, indices] = await Promise.all([
    loadFloat32(manifest.geometry.reference_positions, manifestUrl),
    loadUint32(manifest.geometry.surface_indices, manifestUrl),
  ]);

  const expectedPositionValues = manifest.geometry.node_count * 3;
  if (positions.length !== expectedPositionValues) {
    throw new Error(`reference_positions length ${positions.length}; expected ${expectedPositionValues}`);
  }
  if (indices.length !== manifest.geometry.surface_triangle_count * 3) {
    throw new Error("surface_indices length does not match surface_triangle_count");
  }
  for (const index of indices) {
    if (index >= manifest.geometry.node_count) {
      throw new Error(`surface index ${index} is outside node_count ${manifest.geometry.node_count}`);
    }
  }

  return {
    manifestUrl,
    manifest,
    positions,
    indices,
    frames: normalizeFrames(manifest),
    globalRanges: normalizeGlobalRanges(manifest),
    fieldCatalog: fieldCatalog(manifest),
  };
}

export function loadSnapshotFrame(data: LoadedVizData, index: number): Promise<LoadedSnapshotFrame> {
  const descriptor = data.frames[index];
  if (!descriptor) {
    return Promise.reject(new Error(`snapshot index ${index} is outside the loaded timeline`));
  }
  const key = `${data.manifestUrl}#${descriptor.id}`;
  const cached = frameCache.get(key);
  if (cached) {
    return cached;
  }

  const promise = Promise.all([
    loadFloat32(descriptor.fields.velocity.asset!, data.manifestUrl),
    descriptor.fields.pressure?.asset ? loadFloat32(descriptor.fields.pressure.asset, data.manifestUrl) : Promise.resolve(null),
    descriptor.fields.displacement?.asset
      ? loadFloat32(descriptor.fields.displacement.asset, data.manifestUrl)
      : Promise.resolve(null),
  ]).then(([velocity, pressure, displacement]) => {
    if (velocity.length !== expectedFieldValues(data.manifest.geometry.node_count, descriptor.fields.velocity)) {
      throw new Error(`velocity length mismatch for ${descriptor.id}`);
    }
    if (pressure && descriptor.fields.pressure && pressure.length !== expectedFieldValues(data.manifest.geometry.node_count, descriptor.fields.pressure)) {
      throw new Error(`pressure length mismatch for ${descriptor.id}`);
    }
    if (
      displacement &&
      descriptor.fields.displacement &&
      displacement.length !== expectedFieldValues(data.manifest.geometry.node_count, descriptor.fields.displacement)
    ) {
      throw new Error(`displacement length mismatch for ${descriptor.id}`);
    }
    return { descriptor, velocity, pressure, displacement };
  });

  frameCache.set(key, promise);
  return promise;
}

export function prefetchSnapshotFrame(data: LoadedVizData, index: number): void {
  if (index >= 0 && index < data.frames.length) {
    void loadSnapshotFrame(data, index);
  }
}

export function rangeForField(data: LoadedVizData, frame: LoadedSnapshotFrame, field: FieldName, useGlobalRange: boolean): NumericRange | null {
  if (useGlobalRange) {
    return data.fieldCatalog[field].range;
  }
  const key = field === "pressure" ? "pressure_dyn_cm2" : field === "displacement" ? "displacement_magnitude_cm" : "speed_cm_s";
  return rangeOrNull(frame.descriptor.ranges[key]);
}
