import { createHash } from "node:crypto";
import { existsSync, readFileSync, statSync } from "node:fs";
import { dirname, join, normalize } from "node:path";
import { fileURLToPath } from "node:url";

const root = dirname(dirname(fileURLToPath(import.meta.url)));
const manifestPath = join(root, "public", "data", "demo", "manifest.json");
const manifestRoot = dirname(manifestPath);

function fail(message) {
  throw new Error(`demo manifest validation failed: ${message}`);
}

function readJson(path) {
  return JSON.parse(readFileSync(path, "utf8"));
}

function assertAsset(asset, label) {
  if (!asset || typeof asset.path !== "string" || typeof asset.byte_size !== "number") {
    fail(`${label} is not an asset descriptor`);
  }
  const fullPath = normalize(join(manifestRoot, asset.path));
  if (!fullPath.startsWith(manifestRoot)) {
    fail(`${label} escapes demo directory`);
  }
  if (!existsSync(fullPath)) {
    fail(`${label} missing: ${asset.path}`);
  }
  const actualBytes = statSync(fullPath).size;
  if (actualBytes !== asset.byte_size) {
    fail(`${label} byte_size ${asset.byte_size}; actual ${actualBytes}`);
  }
  if (asset.sha256) {
    const actualSha = createHash("sha256").update(readFileSync(fullPath)).digest("hex");
    if (actualSha !== asset.sha256) {
      fail(`${label} sha256 mismatch`);
    }
  }
  return actualBytes;
}

function expectedFieldBytes(field, nodeCount, label) {
  if (!field || typeof field !== "object") {
    fail(`${label} is not a field descriptor`);
  }
  if (field.centering !== "node") {
    fail(`${label} centering ${field.centering}; expected node`);
  }
  if (!Number.isInteger(field.components) || field.components <= 0) {
    fail(`${label} has invalid component count ${field.components}`);
  }
  return nodeCount * field.components * Float32Array.BYTES_PER_ELEMENT;
}

function assertField(field, nodeCount, label) {
  const expectedBytes = expectedFieldBytes(field, nodeCount, label);
  const actualBytes = assertAsset(field.asset, label);
  if (actualBytes !== expectedBytes) {
    fail(`${label} bytes ${actualBytes}; expected ${expectedBytes}`);
  }
  return actualBytes;
}

if (!existsSync(manifestPath)) {
  fail(`manifest missing: ${manifestPath}`);
}

const manifest = readJson(manifestPath);
if (![1, 2].includes(manifest.schema_version)) {
  fail(`unsupported schema_version ${manifest.schema_version}`);
}
if (!manifest.geometry || manifest.geometry.node_count <= 0 || manifest.geometry.surface_triangle_count <= 0) {
  fail("geometry counts are missing or empty");
}
if (!Array.isArray(manifest.snapshots) || manifest.snapshots.length === 0) {
  fail("snapshots are missing");
}
if (manifest.schema_version === 2 && manifest.snapshot_count !== manifest.snapshots.length) {
  fail(`snapshot_count ${manifest.snapshot_count}; snapshots ${manifest.snapshots.length}`);
}
if (manifest.schema_version === 1 && manifest.snapshot_count && manifest.snapshot_count !== manifest.snapshots.length) {
  fail(`v1 snapshot_count ${manifest.snapshot_count}; snapshots ${manifest.snapshots.length}`);
}

let assetCount = 0;
let byteCount = 0;
for (const [label, asset] of [
  ["geometry.reference_positions", manifest.geometry.reference_positions],
  ["geometry.surface_indices", manifest.geometry.surface_indices],
]) {
  byteCount += assertAsset(asset, label);
  assetCount += 1;
}

if (manifest.geometry.reference_positions.byte_size !== manifest.geometry.node_count * 3 * Float32Array.BYTES_PER_ELEMENT) {
  fail("reference_positions byte size does not match node_count");
}
if (manifest.geometry.surface_indices.byte_size !== manifest.geometry.surface_triangle_count * 3 * Uint32Array.BYTES_PER_ELEMENT) {
  fail("surface_indices byte size does not match surface_triangle_count");
}
const surfaceIndexBuffer = readFileSync(join(manifestRoot, manifest.geometry.surface_indices.path));
const surfaceIndices = new Uint32Array(surfaceIndexBuffer.buffer, surfaceIndexBuffer.byteOffset, surfaceIndexBuffer.byteLength / Uint32Array.BYTES_PER_ELEMENT);
for (const index of surfaceIndices) {
  if (index >= manifest.geometry.node_count) {
    fail(`surface index ${index} is outside node_count ${manifest.geometry.node_count}`);
  }
}

manifest.snapshots.forEach((snapshot, index) => {
  const fields = snapshot.fields ?? manifest.fields;
  if (!fields?.velocity?.asset) {
    fail(`snapshot ${index} is missing velocity`);
  }
  for (const fieldName of ["velocity", "pressure", "displacement"]) {
    const field = fields[fieldName];
    if (field?.asset) {
      byteCount += assertField(field, manifest.geometry.node_count, `snapshot ${snapshot.id}.${fieldName}`);
      assetCount += 1;
    }
  }
  if (snapshot.derived) {
    byteCount += assertAsset(snapshot.derived, `snapshot ${snapshot.id}.derived`);
    assetCount += 1;
  }
});

console.log(`validated_demo_manifest,frames=${manifest.snapshots.length},assets=${assetCount},bytes=${byteCount}`);
