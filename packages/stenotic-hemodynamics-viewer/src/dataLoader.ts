import type {
  AssetDescriptor,
  FieldDescriptor,
  FieldName,
  FrameDescriptor,
  LoadedEvidenceArtifact,
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

async function loadTextAsset(asset: AssetDescriptor, manifestUrl: string): Promise<string> {
  const buffer = await loadBinaryAsset(asset, manifestUrl);
  return new TextDecoder().decode(buffer);
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

function hasFrameField(frames: FrameDescriptor[], field: "pressure" | "displacement"): boolean {
  return frames.some((frame) => Boolean(frame.fields[field]?.asset));
}

function fieldCatalog(
  manifest: WebVizManifest,
  frames: FrameDescriptor[],
  globalRanges: Record<string, NumericRange>,
): LoadedVizData["fieldCatalog"] {
  const available = manifest.available_fields ?? [];
  const byName = new Map(available.map((field) => [field.name, field]));
  const speedRange = rangeOrNull(globalRanges.speed_cm_s ?? byName.get("speed")?.range);
  const pressureRange = rangeOrNull(globalRanges.pressure_dyn_cm2 ?? byName.get("pressure")?.range);
  const displacementRange = rangeOrNull(globalRanges.displacement_magnitude_cm ?? byName.get("displacement")?.range);
  return {
    velocity: {
      label: "Velocity vector",
      units: byName.get("velocity")?.units ?? manifest.units.velocity ?? "cm/s",
      range: speedRange,
      available: true,
    },
    speed: {
      label: "Velocity magnitude",
      units: byName.get("speed")?.units ?? manifest.units.velocity ?? "cm/s",
      range: speedRange,
      available: true,
    },
    pressure: {
      label: "Pressure",
      units: byName.get("pressure")?.units ?? manifest.units.pressure ?? "dyn/cm^2",
      range: pressureRange,
      available: hasFrameField(frames, "pressure"),
    },
    displacement: {
      label: "Wall displacement magnitude",
      units: byName.get("displacement")?.units ?? manifest.units.displacement ?? "cm",
      range: displacementRange,
      available: hasFrameField(frames, "displacement"),
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

  const frames = normalizeFrames(manifest);
  const globalRanges = normalizeGlobalRanges(manifest);

  return {
    manifestUrl,
    manifest,
    positions,
    indices,
    frames,
    globalRanges,
    fieldCatalog: fieldCatalog(manifest, frames, globalRanges),
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
  if (field === "pressure" && !frame.descriptor.fields.pressure?.asset) {
    return null;
  }
  if (field === "displacement" && !frame.descriptor.fields.displacement?.asset) {
    return null;
  }
  if (useGlobalRange) {
    return data.fieldCatalog[field].range;
  }
  const key = field === "pressure" ? "pressure_dyn_cm2" : field === "displacement" ? "displacement_magnitude_cm" : "speed_cm_s";
  return rangeOrNull(frame.descriptor.ranges[key]);
}

function evidenceEntryObject(value: unknown): Record<string, unknown> {
  return value && typeof value === "object" ? (value as Record<string, unknown>) : {};
}

function evidenceEntryAsset(value: unknown): AssetDescriptor | null {
  const entry = evidenceEntryObject(value);
  return typeof entry.path === "string" && typeof entry.byte_size === "number"
    ? { path: entry.path, byte_size: entry.byte_size, sha256: typeof entry.sha256 === "string" ? entry.sha256 : undefined }
    : null;
}

function evidenceEntryLabel(key: string, value: unknown): string {
  const entry = evidenceEntryObject(value);
  return typeof entry.label === "string" && entry.label ? entry.label : key;
}

function evidenceEntryStatus(value: unknown, asset: AssetDescriptor | null): string {
  const entry = evidenceEntryObject(value);
  if (typeof entry.status === "string" && entry.status) {
    return entry.status;
  }
  return asset ? "copied" : "metadata";
}

async function loadEvidenceEntry(
  data: LoadedVizData,
  collection: LoadedEvidenceArtifact["collection"],
  key: string,
  value: unknown,
): Promise<LoadedEvidenceArtifact> {
  const entry = evidenceEntryObject(value);
  const asset = evidenceEntryAsset(value);
  const status = evidenceEntryStatus(value, asset);
  const base = {
    collection,
    key,
    label: evidenceEntryLabel(key, value),
    status,
    sourcePath: typeof entry.source_path === "string" ? entry.source_path : null,
    path: asset?.path ?? null,
    byteSize: asset?.byte_size ?? null,
  };
  if (status === "missing") {
    return { ...base, content: null, loadStatus: "missing" };
  }
  if (!asset) {
    return { ...base, content: null, loadStatus: "metadata" };
  }
  try {
    const text = await loadTextAsset(asset, data.manifestUrl);
    try {
      return { ...base, content: JSON.parse(text), loadStatus: "loaded" };
    } catch {
      return { ...base, content: text, loadStatus: "loaded" };
    }
  } catch (err: unknown) {
    return {
      ...base,
      content: null,
      loadStatus: "error",
      error: err instanceof Error ? err.message : String(err),
    };
  }
}

export async function loadEvidenceArtifacts(data: LoadedVizData): Promise<LoadedEvidenceArtifact[]> {
  const sidecarEntries = Object.entries(data.manifest.sidecars ?? {}).map(([key, value]) =>
    loadEvidenceEntry(data, "sidecars", key, value),
  );
  const observationEntries = Object.entries(data.manifest.observations ?? {}).map(([key, value]) =>
    loadEvidenceEntry(data, "observations", key, value),
  );
  return Promise.all([...sidecarEntries, ...observationEntries]);
}
