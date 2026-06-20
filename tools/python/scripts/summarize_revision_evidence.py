#!/usr/bin/env python3
"""Summarize scratch evidence for the masters-report revision gates.

The generated summaries are provenance aids, not numerical acceptance labels.
They preserve execution/schema status separately from any manuscript claim
decision.
"""

from __future__ import annotations

import argparse
import csv
import hashlib
import json
from collections import defaultdict
from dataclasses import dataclass
from pathlib import Path
from xml.etree import ElementTree


COMPARISON_FLOW_SCALE_CM3_S = 2.288 / 3.141592653589793
COMPARISON_REQUIRED_COLUMNS = (
    "case_label",
    "severity",
    "model",
    "nx",
    "dt_s",
    "initial_condition",
    "backend",
    "run_status",
    "target_time_s",
    "time_atol_s",
    "xdmf_time_s",
    "one_d_completed_time_s",
    "xdmf_target_time_error_s",
)


@dataclass(frozen=True)
class XDMFSummary:
    path: Path
    exists: bool
    times: tuple[str, ...]
    attributes: tuple[str, ...]


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--repo", type=Path, default=Path.cwd(), help="repository root")
    parser.add_argument("--output-dir", type=Path, default=Path("tmp/revision-evidence/summary"))
    parser.add_argument("--rest-csv", type=Path, action="append", default=[], help="rest-state drift CSV")
    parser.add_argument(
        "--comparison-root",
        type=Path,
        action="append",
        default=[],
        help="directory containing comparison_summary.csv files",
    )
    parser.add_argument(
        "--data-root",
        type=Path,
        default=Path("julia/simulations/data/3d/canic_case3"),
        help="local resolved-3D data root",
    )
    return parser.parse_args()


def repo_path(repo: Path, path: Path) -> Path:
    return path if path.is_absolute() else repo / path


def read_csv(path: Path) -> list[dict[str, str]]:
    if not path.exists():
        return []
    with path.open(encoding="utf-8", newline="") as handle:
        return list(csv.DictReader(handle))


def write_csv(path: Path, rows: list[dict[str, object]], fieldnames: tuple[str, ...]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open("w", encoding="utf-8", newline="") as handle:
        writer = csv.DictWriter(handle, fieldnames=fieldnames)
        writer.writeheader()
        for row in rows:
            writer.writerow({field: row.get(field, "") for field in fieldnames})


def as_float(value: str, default: float = float("nan")) -> float:
    try:
        return float(value)
    except (TypeError, ValueError):
        return default


def sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def summarize_rest(rest_paths: list[Path]) -> list[dict[str, object]]:
    grouped: dict[tuple[Path, str, str], list[dict[str, str]]] = defaultdict(list)
    for path in rest_paths:
        for row in read_csv(path):
            grouped[(path, row.get("severity", ""), row.get("nx", ""))].append(row)

    summaries: list[dict[str, object]] = []
    for (path, severity, nx), rows in sorted(
        grouped.items(), key=lambda item: (str(item[0][0]), item[0][1], item[0][2])
    ):
        ok_rows = [row for row in rows if row.get("status", "") == "ok"]
        positive_rows = [row for row in ok_rows if as_float(row.get("requested_time_s", "0")) > 0.0]
        max_time = max((as_float(row.get("requested_time_s", "nan")) for row in ok_rows), default=float("nan"))
        peak_row = max(positive_rows, key=lambda row: as_float(row.get("max_abs_q", "nan")), default={})
        max_abs_q = as_float(peak_row.get("max_abs_q", "nan")) if peak_row else float("nan")
        status = "ok-through-t1" if max_time >= 1.0 and len(ok_rows) == len(rows) else "incomplete-or-error"
        summaries.append(
            {
                "source_csv": path.as_posix(),
                "severity": severity,
                "nx": nx,
                "row_count": len(rows),
                "max_requested_time_s": max_time,
                "peak_requested_time_s": peak_row.get("requested_time_s", ""),
                "max_abs_q": max_abs_q,
                "normalized_to_comparison_flow": max_abs_q / COMPARISON_FLOW_SCALE_CM3_S,
                "max_abs_area_drift": peak_row.get("max_abs_area_drift", ""),
                "solver_volume_defect": peak_row.get(
                    "solver_volume_defect",
                    peak_row.get("mass_defect", ""),
                ),
                "boundary_flux_integral": peak_row.get("boundary_flux_integral", ""),
                "conservation_residual": peak_row.get("conservation_residual", ""),
                "evidence_status": status,
            }
        )
    return summaries


def comparison_summary_paths(roots: list[Path]) -> list[Path]:
    paths: list[Path] = []
    for root in roots:
        if root.is_file() and root.name == "comparison_summary.csv":
            paths.append(root)
        elif root.exists():
            paths.extend(sorted(root.rglob("comparison_summary.csv")))
    return sorted(set(paths))


def summarize_comparisons(paths: list[Path]) -> list[dict[str, object]]:
    summaries: list[dict[str, object]] = []
    for path in paths:
        rows = read_csv(path)
        observed = set(rows[0].keys()) if rows else set()
        missing = [column for column in COMPARISON_REQUIRED_COLUMNS if column not in observed]
        for row in rows:
            status = "schema-ok" if not missing and row.get("run_status", "") == "ok" else "missing-provenance-or-error"
            summaries.append(
                {
                    "source_csv": path.as_posix(),
                    "case_label": row.get("case_label", ""),
                    "severity": row.get("severity", ""),
                    "model": row.get("model", ""),
                    "nx": row.get("nx", ""),
                    "dt_s": row.get("dt_s", ""),
                    "initial_condition": row.get("initial_condition", ""),
                    "backend": row.get("backend", ""),
                    "run_status": row.get("run_status", ""),
                    "target_time_s": row.get("target_time_s", ""),
                    "time_atol_s": row.get("time_atol_s", ""),
                    "xdmf_time_s": row.get("xdmf_time_s", ""),
                    "one_d_completed_time_s": row.get("one_d_completed_time_s", ""),
                    "xdmf_target_time_error_s": row.get("xdmf_target_time_error_s", ""),
                    "mean_abs_discrepancy_cm_s": row.get("mean_abs_discrepancy_cm_s", ""),
                    "l2_velocity_discrepancy_cm_s": row.get("l2_velocity_discrepancy_cm_s", ""),
                    "max_abs_discrepancy_cm_s": row.get("max_abs_discrepancy_cm_s", ""),
                    "mean_flow_abs_discrepancy_cm3_s": row.get("mean_flow_abs_discrepancy_cm3_s", ""),
                    "evidence_status": status,
                    "missing_columns": ";".join(missing),
                }
            )
    return summaries


def local_name(tag: str) -> str:
    return tag.rsplit("}", 1)[-1]


def summarize_xdmf(path: Path) -> XDMFSummary:
    if not path.exists():
        return XDMFSummary(path=path, exists=False, times=(), attributes=())
    root = ElementTree.parse(path).getroot()
    times: list[str] = []
    attributes: list[str] = []
    for elem in root.iter():
        name = local_name(elem.tag)
        if name == "Time":
            value = elem.attrib.get("Value")
            if value is not None:
                times.append(value)
        elif name == "Attribute":
            attr_name = elem.attrib.get("Name")
            if attr_name:
                attributes.append(attr_name)
    return XDMFSummary(
        path=path, exists=True, times=tuple(sorted(set(times))), attributes=tuple(sorted(set(attributes)))
    )


def wall_status_for(displacement: XDMFSummary) -> str:
    if not displacement.exists:
        return "unknown-no-displacement-xdmf"
    if len(displacement.times) == 0:
        return "displacement-present-no-time-metadata"
    if len(displacement.times) == 1:
        return "single-displacement-snapshot"
    return "displacement-time-series"


def audit_wall_status(data_root: Path) -> list[dict[str, object]]:
    rows: list[dict[str, object]] = []
    if not data_root.exists():
        return [
            {
                "case_label": "",
                "case_dir": data_root.as_posix(),
                "wall_status": "missing-data-root",
                "velocity_times": "",
                "pressure_times": "",
                "displacement_times": "",
                "displacement_attributes": "",
            }
        ]

    for case_dir in sorted(path for path in data_root.iterdir() if path.is_dir()):
        velocity = summarize_xdmf(case_dir / "velocity.xdmf")
        pressure = summarize_xdmf(case_dir / "pressure.xdmf")
        displacement = summarize_xdmf(case_dir / "displace.xdmf")
        rows.append(
            {
                "case_label": case_dir.name,
                "case_dir": case_dir.as_posix(),
                "wall_status": wall_status_for(displacement),
                "velocity_exists": velocity.exists,
                "pressure_exists": pressure.exists,
                "displacement_exists": displacement.exists,
                "velocity_times": ";".join(velocity.times),
                "pressure_times": ";".join(pressure.times),
                "displacement_times": ";".join(displacement.times),
                "displacement_attributes": ";".join(displacement.attributes),
            }
        )
    return rows


def write_manifest(output_dir: Path, inputs: list[Path], outputs: list[Path]) -> None:
    payload = {
        "status_meaning": {
            "rest:evidence_status": "schema/execution completeness only; not a numerical acceptance decision",
            "comparison:evidence_status": "schema/execution completeness only; not a numerical acceptance decision",
            "wall_status": "local XDMF metadata classification only",
        },
        "inputs": [{"path": path.as_posix(), "sha256": sha256(path)} for path in inputs if path.exists()],
        "outputs": [{"path": path.as_posix(), "sha256": sha256(path)} for path in outputs if path.exists()],
    }
    path = output_dir / "manifest.json"
    path.write_text(json.dumps(payload, indent=2, sort_keys=True) + "\n", encoding="utf-8")


def main() -> int:
    args = parse_args()
    repo = args.repo.resolve()
    output_dir = repo_path(repo, args.output_dir)
    rest_paths = [repo_path(repo, path) for path in args.rest_csv]
    comparison_roots = [repo_path(repo, path) for path in args.comparison_root]
    data_root = repo_path(repo, args.data_root)

    rest_rows = summarize_rest(rest_paths)
    comparison_paths = comparison_summary_paths(comparison_roots)
    comparison_rows = summarize_comparisons(comparison_paths)
    wall_rows = audit_wall_status(data_root)

    rest_path = output_dir / "rest_gate_summary.csv"
    comparison_path = output_dir / "comparison_gate_summary.csv"
    wall_path = output_dir / "resolved3d_wall_status.csv"
    write_csv(
        rest_path,
        rest_rows,
        (
            "source_csv",
            "severity",
            "nx",
            "row_count",
            "max_requested_time_s",
            "peak_requested_time_s",
            "max_abs_q",
            "normalized_to_comparison_flow",
            "max_abs_area_drift",
            "solver_volume_defect",
            "boundary_flux_integral",
            "conservation_residual",
            "evidence_status",
        ),
    )
    write_csv(
        comparison_path,
        comparison_rows,
        (
            "source_csv",
            "case_label",
            "severity",
            "model",
            "nx",
            "dt_s",
            "initial_condition",
            "backend",
            "run_status",
            "target_time_s",
            "time_atol_s",
            "xdmf_time_s",
            "one_d_completed_time_s",
            "xdmf_target_time_error_s",
            "mean_abs_discrepancy_cm_s",
            "l2_velocity_discrepancy_cm_s",
            "max_abs_discrepancy_cm_s",
            "mean_flow_abs_discrepancy_cm3_s",
            "evidence_status",
            "missing_columns",
        ),
    )
    write_csv(
        wall_path,
        wall_rows,
        (
            "case_label",
            "case_dir",
            "wall_status",
            "velocity_exists",
            "pressure_exists",
            "displacement_exists",
            "velocity_times",
            "pressure_times",
            "displacement_times",
            "displacement_attributes",
        ),
    )
    write_manifest(output_dir, [*rest_paths, *comparison_paths], [rest_path, comparison_path, wall_path])

    print(f"rest_gate_summary,{rest_path}")
    print(f"comparison_gate_summary,{comparison_path}")
    print(f"resolved3d_wall_status,{wall_path}")
    print(f"manifest,{output_dir / 'manifest.json'}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
