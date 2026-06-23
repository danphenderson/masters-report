import { OrbitControls } from "@react-three/drei";
import { Canvas } from "@react-three/fiber";
import { useMemo } from "react";
import * as THREE from "three";
import type { FieldName, GeometryView, LoadedSnapshotFrame, LoadedVizData, NumericRange, ViewMode } from "./types";
import { deformedPositions, fieldValues, finiteRange, geometryBounds } from "./fieldMath";

type ViewerSceneProps = {
  data: LoadedVizData;
  frame: LoadedSnapshotFrame;
  field: FieldName;
  mode: ViewMode;
  geometryView: GeometryView;
  deformationScale: number;
  showGlyphs: boolean;
  glyphDensity: number;
  colorRange: NumericRange | null;
};

function colorRamp(field: FieldName, t: number): THREE.Color {
  const clamped = THREE.MathUtils.clamp(t, 0, 1);
  if (field === "pressure") {
    const low = new THREE.Color("#315d83");
    const mid = new THREE.Color("#d8d5cc");
    const high = new THREE.Color("#9b2f3a");
    return clamped < 0.5 ? low.lerp(mid, clamped * 2) : mid.lerp(high, (clamped - 0.5) * 2);
  }
  if (field === "displacement") {
    const low = new THREE.Color("#506271");
    const mid = new THREE.Color("#d7d2c2");
    const high = new THREE.Color("#b0742c");
    return clamped < 0.5 ? low.lerp(mid, clamped * 2) : mid.lerp(high, (clamped - 0.5) * 2);
  }
  const low = new THREE.Color("#0f4e56");
  const mid = new THREE.Color("#d8d5cc");
  const high = new THREE.Color("#8f3d54");
  return clamped < 0.5 ? low.lerp(mid, clamped * 2) : mid.lerp(high, (clamped - 0.5) * 2);
}

function ResultMesh({
  data,
  frame,
  field,
  geometryView,
  deformationScale,
  colorRange,
}: Pick<ViewerSceneProps, "data" | "frame" | "field" | "geometryView" | "deformationScale" | "colorRange">) {
  const geometry = useMemo(() => {
    const values = fieldValues(field, frame);
    const [min, max] = finiteRange(values, colorRange);
    const positions = deformedPositions(
      data.positions,
      frame.displacement,
      data.manifest.coordinate_mode === "reference" && geometryView === "deformed" ? deformationScale : 0,
    );
    const colors = new Float32Array(values.length * 3);
    const denominator = Math.max(max - min, 1e-12);
    for (let i = 0; i < values.length; i += 1) {
      const color = colorRamp(field, (values[i] - min) / denominator);
      colors[i * 3] = color.r;
      colors[i * 3 + 1] = color.g;
      colors[i * 3 + 2] = color.b;
    }
    const buffer = new THREE.BufferGeometry();
    buffer.setAttribute("position", new THREE.BufferAttribute(positions, 3));
    buffer.setAttribute("color", new THREE.BufferAttribute(colors, 3));
    buffer.setIndex(new THREE.BufferAttribute(data.indices, 1));
    buffer.computeVertexNormals();
    return buffer;
  }, [colorRange, data, deformationScale, field, frame, geometryView]);

  return (
    <mesh geometry={geometry}>
      <meshStandardMaterial vertexColors side={THREE.DoubleSide} roughness={0.82} metalness={0.01} />
    </mesh>
  );
}

function ReferenceOverlay({ data, visible }: { data: LoadedVizData; visible: boolean }) {
  const geometry = useMemo(() => {
    const buffer = new THREE.BufferGeometry();
    buffer.setAttribute("position", new THREE.BufferAttribute(data.positions, 3));
    buffer.setIndex(new THREE.BufferAttribute(data.indices, 1));
    buffer.computeVertexNormals();
    return buffer;
  }, [data]);

  if (!visible) {
    return null;
  }
  return (
    <mesh geometry={geometry}>
      <meshBasicMaterial color="#111827" wireframe transparent opacity={0.18} />
    </mesh>
  );
}

function VelocityGlyphs({
  data,
  frame,
  geometryView,
  deformationScale,
  glyphDensity,
}: Pick<ViewerSceneProps, "data" | "frame" | "geometryView" | "deformationScale" | "glyphDensity">) {
  const geometry = useMemo(() => {
    const positions = deformedPositions(
      data.positions,
      frame.displacement,
      data.manifest.coordinate_mode === "reference" && geometryView === "deformed" ? deformationScale : 0,
    );
    const velocity = frame.velocity;
    const step = Math.max(1, Math.round(glyphDensity));
    const segments: number[] = [];
    for (let node = 0; node < data.manifest.geometry.node_count; node += step) {
      const p = node * 3;
      const vx = velocity[p] ?? 0;
      const vy = velocity[p + 1] ?? 0;
      const vz = velocity[p + 2] ?? 0;
      const norm = Math.hypot(vx, vy, vz);
      if (!Number.isFinite(norm) || norm <= 0) {
        continue;
      }
      const scale = 0.04;
      segments.push(positions[p], positions[p + 1], positions[p + 2]);
      segments.push(positions[p] + (vx / norm) * scale, positions[p + 1] + (vy / norm) * scale, positions[p + 2] + (vz / norm) * scale);
    }
    const buffer = new THREE.BufferGeometry();
    buffer.setAttribute("position", new THREE.Float32BufferAttribute(segments, 3));
    return buffer;
  }, [data, deformationScale, frame, geometryView, glyphDensity]);

  return (
    <lineSegments geometry={geometry}>
      <lineBasicMaterial color="#17202f" transparent opacity={0.42} />
    </lineSegments>
  );
}

export default function ViewerScene({
  data,
  frame,
  field,
  mode,
  geometryView,
  deformationScale,
  showGlyphs,
  glyphDensity,
  colorRange,
}: ViewerSceneProps) {
  const bounds = useMemo(() => geometryBounds(data.positions), [data.positions]);
  const groupPosition: [number, number, number] = [
    -bounds.center[0] * bounds.scale,
    -bounds.center[1] * bounds.scale,
    -bounds.center[2] * bounds.scale,
  ];

  return (
    <Canvas camera={{ position: [0.25, -1.05, 3.25], fov: 36 }} gl={{ antialias: true }}>
      <color attach="background" args={["#edf1f2"]} />
      <ambientLight intensity={0.74} />
      <directionalLight position={[3, -2, 4]} intensity={1.2} />
      <directionalLight position={[-2, 3, 2]} intensity={0.28} />
      <group rotation={[Math.PI / 2, 0, -Math.PI / 2]} scale={bounds.scale} position={groupPosition}>
        <ReferenceOverlay data={data} visible={data.manifest.coordinate_mode === "reference" && geometryView === "deformed" && mode === "wall"} />
        <ResultMesh data={data} frame={frame} field={field} geometryView={geometryView} deformationScale={deformationScale} colorRange={colorRange} />
        {showGlyphs ? (
          <VelocityGlyphs data={data} frame={frame} geometryView={geometryView} deformationScale={deformationScale} glyphDensity={glyphDensity} />
        ) : null}
      </group>
      <OrbitControls makeDefault enableDamping dampingFactor={0.12} minDistance={1.35} maxDistance={7} />
    </Canvas>
  );
}
