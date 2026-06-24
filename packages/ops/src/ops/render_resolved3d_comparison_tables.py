#!/usr/bin/env python3
"""Render resolved-3D comparison data into compact report table fragments."""

from __future__ import annotations

import argparse
import csv
import math
from collections import defaultdict
from dataclasses import dataclass
from pathlib import Path
from typing import Iterable


COORDINATE_MODES = ("reference", "deformed")


@dataclass(frozen=True)
class CoordinateMetricRow:
    severity: int
    coordinate_mode: str
    mean_velocity_discrepancy: float
    rms_velocity_discrepancy: float
    max_velocity_discrepancy: float
    mean_flow_discrepancy: float


@dataclass(frozen=True)
class RadialAuditRow:
    severity: int
    coordinate_mode: str
    slice_count: int
    radial_bin_count: str
    max_summary_delta: float
    audit_result: str


def parse_args(argv: list[str] | None = None) -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--data-dir",
        type=Path,
        default=Path("report/assets/data/stenosis-comparison"),
        help="Directory containing published resolved-3D comparison data assets.",
    )
    parser.add_argument(
        "--table-dir",
        type=Path,
        default=Path("report/assets/tables/stenosis-comparison"),
        help="Directory for generated LaTeX table fragments.",
    )
    return parser.parse_args(argv)


def require_file(path: Path) -> Path:
    if not path.is_file():
        raise FileNotFoundError(f"required resolved-3D table input is missing: {path}")
    return path


def as_float(value: str, *, field: str, path: Path) -> float:
    try:
        parsed = float(value)
    except ValueError as exc:
        raise ValueError(f"field '{field}' in {path} is not numeric: {value!r}") from exc
    if not math.isfinite(parsed):
        raise ValueError(f"field '{field}' in {path} is not finite: {value!r}")
    return parsed


def read_space_table(path: Path) -> list[dict[str, str]]:
    require_file(path)
    with path.open(encoding="utf-8") as handle:
        rows = list(csv.DictReader(handle, delimiter=" ", skipinitialspace=True))
    if not rows:
        raise ValueError(f"resolved-3D table input is empty: {path}")
    return rows


def read_csv_table(path: Path) -> list[dict[str, str]]:
    require_file(path)
    with path.open(encoding="utf-8", newline="") as handle:
        rows = list(csv.DictReader(handle))
    if not rows:
        raise ValueError(f"resolved-3D table input is empty: {path}")
    return rows


def severity_tokens(rows: Iterable[dict[str, str]]) -> list[int]:
    tokens: set[int] = set()
    for row in rows:
        for key in row:
            if key.startswith("discseverity"):
                token = key.removeprefix("discseverity")
                try:
                    tokens.add(int(token))
                except ValueError as exc:
                    raise ValueError(f"unsupported severity token in column '{key}'") from exc
    if not tokens:
        raise ValueError("no discseverityXX columns found in section-quadrature input")
    return sorted(tokens)


def mean(values: list[float]) -> float:
    if not values:
        raise ValueError("cannot compute mean of an empty value list")
    return sum(values) / len(values)


def rms(values: list[float]) -> float:
    return math.sqrt(mean([value * value for value in values]))


def coordinate_metrics_for(path: Path, coordinate_mode: str) -> list[CoordinateMetricRow]:
    rows = read_space_table(path)
    metrics: list[CoordinateMetricRow] = []
    for severity in severity_tokens(rows):
        velocity_key = f"discseverity{severity}"
        flow_key = f"flowdiscseverity{severity}"
        missing = [key for key in (velocity_key, flow_key) if key not in rows[0]]
        if missing:
            raise ValueError(f"{path} is missing required columns: {', '.join(missing)}")
        velocity_values = [as_float(row[velocity_key], field=velocity_key, path=path) for row in rows]
        flow_values = [as_float(row[flow_key], field=flow_key, path=path) for row in rows]
        metrics.append(
            CoordinateMetricRow(
                severity=severity,
                coordinate_mode=coordinate_mode,
                mean_velocity_discrepancy=mean(velocity_values),
                rms_velocity_discrepancy=rms(velocity_values),
                max_velocity_discrepancy=max(velocity_values),
                mean_flow_discrepancy=mean(flow_values),
            )
        )
    return metrics


def fmt_velocity_mean(value: float) -> str:
    return f"{value:.4f}"


def fmt_velocity_rms(value: float) -> str:
    return f"{value:.4f}" if abs(value) < 1.0 else f"{value:.3f}"


def fmt_velocity_max(value: float) -> str:
    return f"{value:.3f}"


def fmt_flow_mean(value: float) -> str:
    return f"{value:.5f}"


def fmt_summary_delta(value: float) -> str:
    return f"{value:.1f}" if abs(value) < 0.05 else f"{value:.3g}"


def latex_case_label(severity: int) -> str:
    return f"{severity}\\% stenosis"


def coordinate_mode_label(mode: str) -> str:
    return mode.replace("-", " ")


def coordinate_mode_table(rows: list[CoordinateMetricRow]) -> str:
    lines = [
        r"\begin{tabular}{@{}llrrrr@{}}",
        r"\toprule",
        r"Case & Coordinates & $D_{u,1}$ & $D_{u,2}$ & $\max |d_u|$ & $D_{Q,1}$ \\",
        r"\midrule",
    ]
    for row in sorted(rows, key=lambda item: (item.severity, item.coordinate_mode != "reference")):
        lines.append(
            " & ".join(
                [
                    latex_case_label(row.severity),
                    coordinate_mode_label(row.coordinate_mode),
                    fmt_velocity_mean(row.mean_velocity_discrepancy),
                    fmt_velocity_rms(row.rms_velocity_discrepancy),
                    fmt_velocity_max(row.max_velocity_discrepancy),
                    fmt_flow_mean(row.mean_flow_discrepancy),
                ]
            )
            + r" \\"
        )
    lines.extend([r"\bottomrule", r"\end{tabular}"])
    return "\n".join(lines) + "\n"


def aggregate_status(statuses: set[str], messages: set[str]) -> str:
    normalized_statuses = {status.strip().lower() for status in statuses if status.strip()}
    normalized_messages = {message.strip() for message in messages if message.strip()}
    if normalized_statuses == {"ok"}:
        return "passed"
    if normalized_statuses == {"failed"} and normalized_messages == {"radial area closure exceeds 1%"}:
        return "failed area-closure gate"
    if len(normalized_statuses) == 1 and len(normalized_messages) == 1:
        status = next(iter(normalized_statuses))
        message = next(iter(normalized_messages))
        return f"{status}: {message}"
    if normalized_statuses:
        return "mixed " + "/".join(sorted(normalized_statuses))
    return "unknown"


def radial_audit_for(path: Path) -> list[RadialAuditRow]:
    rows = read_csv_table(path)
    required = {
        "severity",
        "coordinate_mode",
        "z_slice_cm",
        "radial_bin_count",
        "summary_mean_abs_delta_cm_s",
        "status",
        "message",
    }
    missing = sorted(required - set(rows[0]))
    if missing:
        raise ValueError(f"{path} is missing required columns: {', '.join(missing)}")

    grouped: dict[tuple[int, str], list[dict[str, str]]] = defaultdict(list)
    for row in rows:
        severity = int(round(as_float(row["severity"], field="severity", path=path)))
        grouped[(severity, row["coordinate_mode"])].append(row)

    audit_rows: list[RadialAuditRow] = []
    for (severity, mode), group in sorted(grouped.items(), key=lambda item: (item[0][0], item[0][1])):
        slices = {row["z_slice_cm"] for row in group}
        bins = sorted({row["radial_bin_count"] for row in group}, key=lambda value: int(value))
        deltas = [
            abs(as_float(row["summary_mean_abs_delta_cm_s"], field="summary_mean_abs_delta_cm_s", path=path))
            for row in group
        ]
        audit_rows.append(
            RadialAuditRow(
                severity=severity,
                coordinate_mode=mode,
                slice_count=len(slices),
                radial_bin_count=",".join(bins),
                max_summary_delta=max(deltas),
                audit_result=aggregate_status(
                    {row["status"] for row in group},
                    {row["message"] for row in group},
                ),
            )
        )
    return audit_rows


def radial_audit_table(rows: list[RadialAuditRow]) -> str:
    lines = [
        r"\begin{tabular}{@{}llrrrl@{}}",
        r"\toprule",
        r"Case & Coordinates & Slices & Bins & Summary delta & Audit result \\",
        r"\midrule",
    ]
    for row in sorted(rows, key=lambda item: (item.severity, item.coordinate_mode != "reference")):
        lines.append(
            " & ".join(
                [
                    latex_case_label(row.severity),
                    coordinate_mode_label(row.coordinate_mode),
                    str(row.slice_count),
                    row.radial_bin_count,
                    fmt_summary_delta(row.max_summary_delta),
                    row.audit_result,
                ]
            )
            + r" \\"
        )
    lines.extend([r"\bottomrule", r"\end{tabular}"])
    return "\n".join(lines) + "\n"


def render_tables(data_dir: Path, table_dir: Path) -> list[Path]:
    table_dir.mkdir(parents=True, exist_ok=True)
    coordinate_rows: list[CoordinateMetricRow] = []
    radial_rows: list[RadialAuditRow] = []
    for mode in COORDINATE_MODES:
        coordinate_rows.extend(coordinate_metrics_for(data_dir / f"section-quadrature-{mode}.dat", mode))
        radial_rows.extend(radial_audit_for(data_dir / f"radial-profile-audit-{mode}.csv"))

    coordinate_path = table_dir / "coordinate_mode_comparison.tex"
    radial_path = table_dir / "radial_profile_audit.tex"
    coordinate_path.write_text(coordinate_mode_table(coordinate_rows), encoding="utf-8")
    radial_path.write_text(radial_audit_table(radial_rows), encoding="utf-8")
    return [coordinate_path, radial_path]


def main(argv: list[str] | None = None) -> int:
    args = parse_args(argv)
    try:
        paths = render_tables(args.data_dir, args.table_dir)
    except (FileNotFoundError, ValueError) as exc:
        print(f"ops-render-resolved3d-comparison-tables: {exc}")
        return 1
    for path in paths:
        print(path)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
