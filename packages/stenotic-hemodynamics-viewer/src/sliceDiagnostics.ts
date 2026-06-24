import type { GeometryView, LoadedSnapshotFrame, WebVizManifest } from "./types";

type AxisName = "x" | "y" | "z";

export type SliceDiagnostic = {
  index: number;
  label: string;
  axisCenter: number;
  sampleCount: number;
  meanRadius: number | null;
  minRadius: number | null;
  maxRadius: number | null;
  meanSpeed: number | null;
  meanPressure: number | null;
  maxDisplacement: number | null;
};

export type SliceDiagnosticSummary = {
  axis: AxisName;
  axisUnit: string;
  speedUnit: string;
  pressureUnit: string;
  displacementUnit: string;
  sampleCount: number;
  slices: SliceDiagnostic[];
  narrowestSlice: SliceDiagnostic | null;
  fastestSlice: SliceDiagnostic | null;
  pressureSpan: number | null;
};

type SliceAccumulator = {
  sampleCount: number;
  positionSums: [number, number, number];
  radiusCount: number;
  radiusSum: number;
  radiusMin: number;
  radiusMax: number;
  speedCount: number;
  speedSum: number;
  pressureCount: number;
  pressureSum: number;
  displacementCount: number;
  displacementMax: number;
};

type SliceDiagnosticsInput = {
  positions: Float32Array;
  surfaceIndices: Uint32Array;
  frame: LoadedSnapshotFrame;
  coordinateMode: WebVizManifest["coordinate_mode"];
  geometryView: GeometryView;
  deformationScale: number;
  units: WebVizManifest["units"];
  binCount?: number;
};

const axisNames: AxisName[] = ["x", "y", "z"];

function vectorMagnitude(values: Float32Array | null, nodeIndex: number): number | null {
  if (!values) {
    return null;
  }
  const offset = nodeIndex * 3;
  const magnitude = Math.hypot(values[offset] ?? 0, values[offset + 1] ?? 0, values[offset + 2] ?? 0);
  return Number.isFinite(magnitude) ? magnitude : null;
}

function finiteValue(values: Float32Array | null, nodeIndex: number): number | null {
  if (!values) {
    return null;
  }
  const value = values[nodeIndex];
  return Number.isFinite(value) ? value : null;
}

function surfaceNodeList(surfaceIndices: Uint32Array, nodeCount: number): number[] {
  const seen = new Uint8Array(nodeCount);
  const nodes: number[] = [];
  for (const rawIndex of surfaceIndices) {
    const index = Number(rawIndex);
    if (index >= 0 && index < nodeCount && seen[index] === 0) {
      seen[index] = 1;
      nodes.push(index);
    }
  }
  return nodes;
}

function emptyAccumulator(): SliceAccumulator {
  return {
    sampleCount: 0,
    positionSums: [0, 0, 0],
    radiusCount: 0,
    radiusSum: 0,
    radiusMin: Number.POSITIVE_INFINITY,
    radiusMax: Number.NEGATIVE_INFINITY,
    speedCount: 0,
    speedSum: 0,
    pressureCount: 0,
    pressureSum: 0,
    displacementCount: 0,
    displacementMax: Number.NEGATIVE_INFINITY,
  };
}

function mean(sum: number, count: number): number | null {
  return count > 0 ? sum / count : null;
}

function isCompletePosition(values: [number, number, number]): boolean {
  return values.every((value) => Number.isFinite(value));
}

export function computeSliceDiagnostics(input: SliceDiagnosticsInput): SliceDiagnosticSummary | null {
  const nodeCount = input.positions.length / 3;
  if (!Number.isInteger(nodeCount) || nodeCount <= 0) {
    return null;
  }

  const surfaceNodes = surfaceNodeList(input.surfaceIndices, nodeCount);
  if (surfaceNodes.length === 0) {
    return null;
  }

  const displacement =
    input.coordinateMode === "reference" && input.geometryView === "deformed" && input.frame.displacement
      ? input.frame.displacement
      : null;
  const scale = displacement ? input.deformationScale : 0;

  const positionForNode = (nodeIndex: number): [number, number, number] => {
    const offset = nodeIndex * 3;
    return [
      (input.positions[offset] ?? 0) + scale * (displacement?.[offset] ?? 0),
      (input.positions[offset + 1] ?? 0) + scale * (displacement?.[offset + 1] ?? 0),
      (input.positions[offset + 2] ?? 0) + scale * (displacement?.[offset + 2] ?? 0),
    ];
  };

  const boundsMin: [number, number, number] = [Number.POSITIVE_INFINITY, Number.POSITIVE_INFINITY, Number.POSITIVE_INFINITY];
  const boundsMax: [number, number, number] = [Number.NEGATIVE_INFINITY, Number.NEGATIVE_INFINITY, Number.NEGATIVE_INFINITY];
  const usableNodes: number[] = [];
  for (const nodeIndex of surfaceNodes) {
    const position = positionForNode(nodeIndex);
    if (!isCompletePosition(position)) {
      continue;
    }
    usableNodes.push(nodeIndex);
    for (let axis = 0; axis < 3; axis += 1) {
      boundsMin[axis] = Math.min(boundsMin[axis], position[axis]);
      boundsMax[axis] = Math.max(boundsMax[axis], position[axis]);
    }
  }
  if (usableNodes.length === 0) {
    return null;
  }

  const spans = boundsMax.map((value, axis) => value - boundsMin[axis]);
  const axisIndex = spans.reduce((best, value, axis) => (value > spans[best] ? axis : best), 0);
  const axisSpan = spans[axisIndex];
  if (!Number.isFinite(axisSpan) || Math.abs(axisSpan) < 1e-12) {
    return null;
  }

  const binCount = Math.max(4, Math.min(12, Math.round(input.binCount ?? 8)));
  const bins = Array.from({ length: binCount }, emptyAccumulator);
  const binForPosition = (position: [number, number, number]): number => {
    const normalized = (position[axisIndex] - boundsMin[axisIndex]) / axisSpan;
    return Math.min(binCount - 1, Math.max(0, Math.floor(normalized * binCount)));
  };

  for (const nodeIndex of usableNodes) {
    const position = positionForNode(nodeIndex);
    const bin = bins[binForPosition(position)];
    bin.sampleCount += 1;
    for (let axis = 0; axis < 3; axis += 1) {
      bin.positionSums[axis] += position[axis];
    }
  }

  for (const nodeIndex of usableNodes) {
    const position = positionForNode(nodeIndex);
    const bin = bins[binForPosition(position)];
    const transverseAxes = [0, 1, 2].filter((axis) => axis !== axisIndex);
    const transverseCenter0 = bin.positionSums[transverseAxes[0]] / Math.max(1, bin.sampleCount);
    const transverseCenter1 = bin.positionSums[transverseAxes[1]] / Math.max(1, bin.sampleCount);
    const radius = Math.hypot(position[transverseAxes[0]] - transverseCenter0, position[transverseAxes[1]] - transverseCenter1);
    if (Number.isFinite(radius)) {
      bin.radiusCount += 1;
      bin.radiusSum += radius;
      bin.radiusMin = Math.min(bin.radiusMin, radius);
      bin.radiusMax = Math.max(bin.radiusMax, radius);
    }

    const speed = vectorMagnitude(input.frame.velocity, nodeIndex);
    if (speed !== null) {
      bin.speedCount += 1;
      bin.speedSum += speed;
    }

    const pressure = finiteValue(input.frame.pressure, nodeIndex);
    if (pressure !== null) {
      bin.pressureCount += 1;
      bin.pressureSum += pressure;
    }

    const displacementMagnitude = vectorMagnitude(input.frame.displacement, nodeIndex);
    if (displacementMagnitude !== null) {
      bin.displacementCount += 1;
      bin.displacementMax = Math.max(bin.displacementMax, displacementMagnitude);
    }
  }

  const slices = bins.map((bin, index) => {
    const axisCenter = boundsMin[axisIndex] + ((index + 0.5) * axisSpan) / binCount;
    return {
      index,
      label: `${axisNames[axisIndex]}=${axisCenter.toFixed(2)}`,
      axisCenter,
      sampleCount: bin.sampleCount,
      meanRadius: mean(bin.radiusSum, bin.radiusCount),
      minRadius: bin.radiusCount > 0 ? bin.radiusMin : null,
      maxRadius: bin.radiusCount > 0 ? bin.radiusMax : null,
      meanSpeed: mean(bin.speedSum, bin.speedCount),
      meanPressure: mean(bin.pressureSum, bin.pressureCount),
      maxDisplacement: bin.displacementCount > 0 ? bin.displacementMax : null,
    };
  });

  const populated = slices.filter((slice) => slice.sampleCount > 0);
  const narrowestSlice = populated.reduce<SliceDiagnostic | null>(
    (best, slice) =>
      slice.meanRadius !== null && (!best || best.meanRadius === null || slice.meanRadius < best.meanRadius)
        ? slice
        : best,
    null,
  );
  const fastestSlice = populated.reduce<SliceDiagnostic | null>(
    (best, slice) => (slice.meanSpeed !== null && (!best || best.meanSpeed === null || slice.meanSpeed > best.meanSpeed) ? slice : best),
    null,
  );
  const pressureMeans = populated.map((slice) => slice.meanPressure).filter((value): value is number => value !== null);
  const pressureSpan =
    pressureMeans.length > 0 ? Math.max(...pressureMeans) - Math.min(...pressureMeans) : null;

  return {
    axis: axisNames[axisIndex],
    axisUnit: input.units.length ?? "cm",
    speedUnit: input.units.velocity ?? "cm/s",
    pressureUnit: input.units.pressure ?? "dyn/cm^2",
    displacementUnit: input.units.displacement ?? "cm",
    sampleCount: usableNodes.length,
    slices,
    narrowestSlice,
    fastestSlice,
    pressureSpan,
  };
}
