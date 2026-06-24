import { formatNumber } from "./fieldMath";
import type { LoadedEvidenceArtifact, WebVizManifest } from "./types";

export type EvidenceBadge = {
  key: string;
  label: string;
  color: "default" | "info" | "warning" | "success";
};

type CsvRows = {
  headers: string[];
  rows: Record<string, string>[];
};

export function recordCount(value: Record<string, unknown> | undefined | null): number {
  return value && typeof value === "object" ? Object.keys(value).length : 0;
}

function titleFromKey(key: string): string {
  return key
    .replace(/[_-]+/g, " ")
    .trim()
    .replace(/\b\w/g, (char) => char.toUpperCase());
}

export function artifactTitle(artifact: LoadedEvidenceArtifact): string {
  return titleFromKey(artifact.label || artifact.key);
}

export function artifactStatusLabel(artifact: LoadedEvidenceArtifact): string {
  if (artifact.loadStatus === "loaded") {
    return "loaded";
  }
  if (artifact.loadStatus === "missing") {
    return "missing";
  }
  if (artifact.loadStatus === "error") {
    return "load error";
  }
  return artifact.status || "metadata";
}

export function evidenceBadges(manifest: WebVizManifest, artifacts: LoadedEvidenceArtifact[]): EvidenceBadge[] {
  const badges: EvidenceBadge[] = [
    { key: "claim_boundary", label: "artifact/operator aid", color: "info" },
    { key: "coordinate_mode", label: `coordinates: ${manifest.coordinate_mode}`, color: "default" },
  ];
  if (manifest.result_class) {
    badges.push({ key: "result_class", label: String(manifest.result_class).replace(/_/g, " "), color: "default" });
  }
  const skippedCount = manifest.skipped_snapshots?.length ?? 0;
  if (skippedCount > 0) {
    badges.push({ key: "skipped_snapshots", label: `${skippedCount} skipped snapshot${skippedCount === 1 ? "" : "s"}`, color: "warning" });
  }
  const sidecarCount = artifacts.filter((artifact) => artifact.collection === "sidecars").length || recordCount(manifest.sidecars);
  if (sidecarCount > 0) {
    badges.push({ key: "sidecars", label: `${sidecarCount} sidecar${sidecarCount === 1 ? "" : "s"}`, color: "success" });
  }
  const observationCount = artifacts.filter((artifact) => artifact.collection === "observations").length || recordCount(manifest.observations);
  if (observationCount > 0) {
    badges.push({ key: "observations", label: `${observationCount} observation artifact${observationCount === 1 ? "" : "s"}`, color: "success" });
  }
  return badges;
}

function splitCsvLine(line: string): string[] {
  const values: string[] = [];
  let current = "";
  let quoted = false;
  for (let index = 0; index < line.length; index += 1) {
    const char = line[index];
    const next = line[index + 1];
    if (char === '"' && quoted && next === '"') {
      current += '"';
      index += 1;
    } else if (char === '"') {
      quoted = !quoted;
    } else if (char === "," && !quoted) {
      values.push(current.trim());
      current = "";
    } else {
      current += char;
    }
  }
  values.push(current.trim());
  return values;
}

function csvRowsFromLines(lines: unknown): CsvRows | null {
  if (!Array.isArray(lines)) {
    return null;
  }
  const cleanLines = lines.filter((line): line is string => typeof line === "string" && line.trim().length > 0);
  if (cleanLines.length === 0) {
    return { headers: [], rows: [] };
  }
  const headers = splitCsvLine(cleanLines[0]).map((header) => header.trim());
  const rows = cleanLines.slice(1).map((line) => {
    const values = splitCsvLine(line);
    const row: Record<string, string> = {};
    headers.forEach((header, index) => {
      row[header] = values[index] ?? "";
    });
    return row;
  });
  return { headers, rows };
}

function numericValue(value: string): number | null {
  const parsed = Number.parseFloat(value.replace(/%$/, ""));
  return Number.isFinite(parsed) ? parsed : null;
}

function summarizeCsvRows(rows: CsvRows): string {
  if (rows.rows.length === 0) {
    return "empty copied table";
  }
  const discrepancyHeaders = rows.headers.filter((header) => /discrep|diff|delta|error|residual|rmse|relative|absolute|abs/i.test(header));
  for (const header of discrepancyHeaders) {
    const values = rows.rows.map((row) => numericValue(row[header] ?? "")).filter((value): value is number => value !== null);
    if (values.length > 0) {
      const maxAbs = Math.max(...values.map((value) => Math.abs(value)));
      return `${rows.rows.length} row${rows.rows.length === 1 ? "" : "s"}; max abs ${titleFromKey(header)} ${formatNumber(maxAbs)}`;
    }
  }
  const visibleHeaders = rows.headers.slice(0, 4).map(titleFromKey).join(", ");
  return `${rows.rows.length} row${rows.rows.length === 1 ? "" : "s"}${visibleHeaders ? `; columns ${visibleHeaders}` : ""}`;
}

function objectContent(value: unknown): Record<string, unknown> | null {
  return value && typeof value === "object" && !Array.isArray(value) ? (value as Record<string, unknown>) : null;
}

export function summarizeEvidenceContent(artifact: LoadedEvidenceArtifact): string {
  if (artifact.loadStatus === "missing") {
    return artifact.sourcePath ? `missing source ${artifact.sourcePath}` : "missing source";
  }
  if (artifact.loadStatus === "error") {
    return artifact.error ?? "could not load artifact";
  }
  const content = artifact.content;
  const object = objectContent(content);
  if (object) {
    const csvRows = csvRowsFromLines(object.lines);
    if (csvRows) {
      return summarizeCsvRows(csvRows);
    }
    if (Array.isArray(object.snapshot_outputs)) {
      return `${object.snapshot_outputs.length} snapshot output${object.snapshot_outputs.length === 1 ? "" : "s"}`;
    }
    if (Array.isArray(object.rows)) {
      return `${object.rows.length} row${object.rows.length === 1 ? "" : "s"}`;
    }
    const keys = Object.keys(object).slice(0, 5).map(titleFromKey);
    return keys.length > 0 ? `keys ${keys.join(", ")}` : "loaded JSON object";
  }
  if (Array.isArray(content)) {
    return `${content.length} record${content.length === 1 ? "" : "s"}`;
  }
  if (typeof content === "string") {
    return `${content.length.toLocaleString()} text characters`;
  }
  return artifact.path ? `${artifact.byteSize?.toLocaleString() ?? "unknown"} bytes` : "manifest metadata only";
}

export function isDiscrepancyEvidence(artifact: LoadedEvidenceArtifact): boolean {
  const haystack = [artifact.collection, artifact.key, artifact.label, artifact.sourcePath, artifact.path]
    .filter(Boolean)
    .join(" ")
    .toLowerCase();
  return artifact.collection === "observations" || /parity|observation|discrep|difference|delta|error|residual|compare|benchmark|section41/.test(haystack);
}
