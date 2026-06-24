import type { FieldName, LoadedSnapshotFrame, NumericRange } from "./types";

export function fieldValues(field: FieldName, frame: LoadedSnapshotFrame): Float32Array {
  if (field === "pressure") {
    if (!frame.pressure) {
      throw new Error(`pressure field is unavailable for frame ${frame.descriptor.id}`);
    }
    return frame.pressure;
  }
  if (field === "displacement") {
    if (!frame.displacement) {
      throw new Error(`displacement field is unavailable for frame ${frame.descriptor.id}`);
    }
    return vectorMagnitude(frame.displacement);
  }
  return vectorMagnitude(frame.velocity);
}

export function vectorMagnitude(values: Float32Array): Float32Array {
  const out = new Float32Array(values.length / 3);
  for (let i = 0; i < out.length; i += 1) {
    const offset = i * 3;
    const x = values[offset] ?? 0;
    const y = values[offset + 1] ?? 0;
    const z = values[offset + 2] ?? 0;
    out[i] = Math.hypot(x, y, z);
  }
  return out;
}

export function finiteRange(values: Float32Array, preferredRange?: NumericRange | null): [number, number] {
  if (
    preferredRange &&
    typeof preferredRange.min === "number" &&
    typeof preferredRange.max === "number" &&
    Number.isFinite(preferredRange.min) &&
    Number.isFinite(preferredRange.max) &&
    Math.abs(preferredRange.max - preferredRange.min) > 1e-12
  ) {
    return [preferredRange.min, preferredRange.max];
  }

  let min = Number.POSITIVE_INFINITY;
  let max = Number.NEGATIVE_INFINITY;
  for (const value of values) {
    if (Number.isFinite(value)) {
      min = Math.min(min, value);
      max = Math.max(max, value);
    }
  }
  if (!Number.isFinite(min) || !Number.isFinite(max)) {
    return [0, 1];
  }
  if (Math.abs(max - min) < 1e-12) {
    return [min - 0.5, max + 0.5];
  }
  return [min, max];
}

export function deformedPositions(
  positions: Float32Array,
  displacement: Float32Array | null,
  deformationScale: number,
): Float32Array {
  if (!displacement || deformationScale === 0) {
    return positions.slice();
  }
  const out = new Float32Array(positions.length);
  for (let i = 0; i < positions.length; i += 1) {
    out[i] = positions[i] + deformationScale * displacement[i];
  }
  return out;
}

export function geometryBounds(positions: Float32Array): {
  center: [number, number, number];
  scale: number;
  span: [number, number, number];
} {
  const min = [Number.POSITIVE_INFINITY, Number.POSITIVE_INFINITY, Number.POSITIVE_INFINITY];
  const max = [Number.NEGATIVE_INFINITY, Number.NEGATIVE_INFINITY, Number.NEGATIVE_INFINITY];
  for (let i = 0; i < positions.length; i += 3) {
    for (let axis = 0; axis < 3; axis += 1) {
      const value = positions[i + axis];
      min[axis] = Math.min(min[axis], value);
      max[axis] = Math.max(max[axis], value);
    }
  }
  const span: [number, number, number] = [max[0] - min[0], max[1] - min[1], max[2] - min[2]];
  const maxSpan = Math.max(span[0], span[1], span[2], 1e-6);
  return {
    center: [(min[0] + max[0]) / 2, (min[1] + max[1]) / 2, (min[2] + max[2]) / 2],
    scale: 3.2 / maxSpan,
    span,
  };
}

export function formatNumber(value: number | null | undefined): string {
  if (typeof value !== "number" || !Number.isFinite(value)) {
    return "n/a";
  }
  if (Math.abs(value) >= 1000 || Math.abs(value) < 0.01) {
    return value.toExponential(2);
  }
  return value.toFixed(Math.abs(value) < 1 ? 3 : 2);
}
