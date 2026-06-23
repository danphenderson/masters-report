export type AssetDescriptor = {
  path: string;
  byte_size: number;
  sha256?: string;
};

export type FieldName = "velocity" | "speed" | "pressure" | "displacement";
export type ViewMode = "flow" | "pressure" | "wall";
export type GeometryView = "reference" | "deformed";

export type NumericRange = {
  min: number | null;
  max: number | null;
};

export type FieldDescriptor = {
  name?: string;
  components: number;
  centering: "node";
  units: string;
  asset?: AssetDescriptor;
  range?: NumericRange;
};

export type SnapshotFieldAssets = {
  velocity: FieldDescriptor;
  pressure?: FieldDescriptor | null;
  displacement?: FieldDescriptor | null;
};

export type WebVizSnapshot = {
  id: string;
  source_id?: string;
  time_s: number;
  fields?: SnapshotFieldAssets;
  derived?: AssetDescriptor | null;
  ranges: Record<string, NumericRange | Record<string, NumericRange>>;
};

export type WebVizManifest = {
  schema_version: 1 | 2;
  case_id: string;
  case_label: string;
  severity_percent: number;
  result_class: string;
  claim_boundary: string;
  coordinate_mode: "reference" | "deformed";
  geometry_mode: "surface";
  units: Record<string, string>;
  source: Record<string, unknown>;
  geometry: {
    node_count: number;
    tetrahedron_count: number;
    surface_triangle_count: number;
    reference_positions: AssetDescriptor;
    surface_indices: AssetDescriptor;
    tetra_indices_debug?: AssetDescriptor | null;
  };
  mesh?: {
    node_indexing?: "zero_based";
    index_dtype?: "uint32";
    field_dtype?: "float32";
  };
  fields?: SnapshotFieldAssets;
  snapshots: WebVizSnapshot[];
  snapshot_count?: number;
  time_axis?: Array<{
    frame_id: string;
    time_s: number;
    delta_t_s?: number | null;
  }>;
  available_fields?: FieldDescriptor[];
  global_ranges?: Record<string, NumericRange>;
  skipped_snapshots?: string[];
  estimated_playback_fps?: number;
  sidecars: Record<string, unknown>;
  observations: Record<string, unknown>;
};

export type FrameDescriptor = {
  index: number;
  id: string;
  time_s: number;
  sourceId?: string;
  fields: SnapshotFieldAssets;
  ranges: Record<string, NumericRange | Record<string, NumericRange>>;
};

export type LoadedSnapshotFrame = {
  descriptor: FrameDescriptor;
  velocity: Float32Array;
  pressure: Float32Array | null;
  displacement: Float32Array | null;
};

export type LoadedVizData = {
  manifestUrl: string;
  manifest: WebVizManifest;
  positions: Float32Array;
  indices: Uint32Array;
  frames: FrameDescriptor[];
  globalRanges: Record<string, NumericRange>;
  fieldCatalog: Record<FieldName, { label: string; units: string; range: NumericRange | null }>;
};
