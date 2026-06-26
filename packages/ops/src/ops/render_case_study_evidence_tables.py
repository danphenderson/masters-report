#!/usr/bin/env python3
"""Render additional case-study numerical experiment summaries."""

from __future__ import annotations

import argparse
import csv
import math
from dataclasses import dataclass
from pathlib import Path
from typing import Iterable


REST_METHOD_ORDER = {
    "fv-first-order": 0,
    "fv-muscl": 1,
    "fv-weno3": 2,
    "fv-lax-wendroff": 3,
    "fv-wb-geometry-rest": 4,
}
REST_METHOD_LABELS = {
    "fv-first-order": "FV first-order",
    "fv-muscl": "FV MUSCL",
    "fv-weno3": "FV WENO3",
    "fv-lax-wendroff": "FV Lax--Wendroff",
    "fv-wb-geometry-rest": "FV geometry-rest balanced",
}


@dataclass(frozen=True)
class RestMethodRow:
    method: str
    method_label: str
    severity: float
    nx: int
    final_requested_time_s: float
    initial_total_flow_residual_max_abs: float
    peak_time_s: float
    peak_max_abs_q: float
    final_max_abs_q: float
    final_rms_q: float
    max_positivity_projection_count: int
    status: str
    error_message: str
    residual_status: str
    residual_error_message: str
    source_csv: str


@dataclass(frozen=True)
class ComparisonTimeStepRow:
    case_label: str
    case_display: str
    severity: float
    spatial_method: str
    nx: int
    dt_cap_s: float
    accepted_dt_min_s: float
    accepted_dt_max_s: float
    realized_cfl_max: float
    mean_velocity_discrepancy_cm_s: float
    rms_velocity_discrepancy_cm_s: float
    max_velocity_discrepancy_cm_s: float
    relative_rms_velocity_discrepancy: float
    status: str
    source_csv: str


def parse_args(argv: list[str] | None = None) -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--rest-root",
        type=Path,
        default=Path("tmp/simulations/output/additional-evidence"),
        help="Scratch root containing rest-* directories from verify rest runs.",
    )
    parser.add_argument(
        "--comparison-root",
        type=Path,
        default=Path("tmp/simulations/output/additional-evidence"),
        help="Scratch root containing compare-dt-* directories from compare-3d runs.",
    )
    parser.add_argument(
        "--verification-data-dir",
        type=Path,
        default=Path("report/assets/data/verification"),
        help="Published verification data output directory.",
    )
    parser.add_argument(
        "--verification-table-dir",
        type=Path,
        default=Path("report/assets/tables/verification"),
        help="Published verification LaTeX table output directory.",
    )
    parser.add_argument(
        "--comparison-data-dir",
        type=Path,
        default=Path("report/assets/data/stenosis-comparison"),
        help="Published comparison data output directory.",
    )
    parser.add_argument(
        "--comparison-table-dir",
        type=Path,
        default=Path("report/assets/tables/stenosis-comparison"),
        help="Published comparison LaTeX table output directory.",
    )
    return parser.parse_args(argv)


def require_file(path: Path) -> Path:
    if not path.is_file():
        raise FileNotFoundError(f"required case-study evidence input is missing: {path}")
    return path


def read_csv(path: Path) -> list[dict[str, str]]:
    require_file(path)
    with path.open(encoding="utf-8", newline="") as handle:
        rows = list(csv.DictReader(handle))
    if not rows:
        raise ValueError(f"case-study evidence input is empty: {path}")
    return rows


def as_float(value: str, *, field: str, path: Path) -> float:
    text = value.strip()
    if text in {"", "NaN", "nan"}:
        return math.nan
    try:
        parsed = float(text)
    except ValueError as exc:
        raise ValueError(f"field '{field}' in {path} is not numeric: {value!r}") from exc
    return parsed


def as_int(value: str, *, field: str, path: Path) -> int:
    parsed = as_float(value, field=field, path=path)
    if not math.isfinite(parsed):
        return 0
    return int(round(parsed))


def finite_or_blank(value: float) -> str:
    return "" if not math.isfinite(value) else f"{value:.17g}"


def case_token(severity: float) -> str:
    return f"C{round(severity):d}"


def latex_case_token(severity: float) -> str:
    if round(severity) == 23 and not math.isclose(severity, 23.0, abs_tol=1.0e-9):
        return f"C23 ({severity:.2f}\\%)"
    return case_token(severity)


def method_from_rest_dir(path: Path) -> str:
    name = path.parent.name
    if not name.startswith("rest-"):
        raise ValueError(f"rest-state CSV must live under a rest-* directory: {path}")
    return name.removeprefix("rest-")


def group_by_severity(rows: Iterable[dict[str, str]], path: Path) -> dict[int, list[dict[str, str]]]:
    grouped: dict[int, list[dict[str, str]]] = {}
    for row in rows:
        severity = round(as_float(row["severity"], field="severity", path=path))
        grouped.setdefault(severity, []).append(row)
    return grouped


def residual_index(rows: list[dict[str, str]], path: Path) -> dict[int, dict[str, str]]:
    indexed: dict[int, dict[str, str]] = {}
    for row in rows:
        severity = round(as_float(row["severity"], field="severity", path=path))
        indexed[severity] = row
    return indexed


def aggregate_error(rows: Iterable[dict[str, str]]) -> str:
    messages = sorted({row.get("error_message", "").strip() for row in rows if row.get("error_message", "").strip()})
    if not messages:
        return ""
    return messages[0] if len(messages) == 1 else "; ".join(messages)


def summarize_rest_method_csv(path: Path) -> list[RestMethodRow]:
    rows = read_csv(path)
    method = method_from_rest_dir(path)
    label = REST_METHOD_LABELS.get(method, method)
    residual_path = path.parent / "rest_state_residual_components.csv"
    residual_rows = read_csv(residual_path)
    residuals = residual_index(residual_rows, residual_path)

    summaries: list[RestMethodRow] = []
    for severity, group in sorted(group_by_severity(rows, path).items()):
        display_severity = as_float(group[0]["severity"], field="severity", path=path)
        ok_rows = [row for row in group if row.get("status") == "ok"]
        nx_values = {as_int(row["nx"], field="nx", path=path) for row in group if row.get("nx", "").strip()}
        nx = min(nx_values) if len(nx_values) == 1 else 0
        residual = residuals.get(severity)
        residual_status = (residual.get("status", "error").strip() if residual else "error") or "error"
        residual_error_message = (
            residual.get("error_message", "").strip() if residual else f"missing residual row for severity {severity}"
        )
        residual_value = (
            as_float(residual["total_flow_residual_max_abs"], field="total_flow_residual_max_abs", path=residual_path)
            if residual and residual_status == "ok"
            else math.nan
        )
        if ok_rows:
            positive_rows = [
                row for row in ok_rows if as_float(row["requested_time_s"], field="requested_time_s", path=path) > 0.0
            ]
            peak_row = max(
                positive_rows or ok_rows, key=lambda row: as_float(row["max_abs_q"], field="max_abs_q", path=path)
            )
            final_row = max(
                ok_rows, key=lambda row: as_float(row["requested_time_s"], field="requested_time_s", path=path)
            )
            summaries.append(
                RestMethodRow(
                    method=method,
                    method_label=label,
                    severity=display_severity,
                    nx=nx,
                    final_requested_time_s=as_float(final_row["requested_time_s"], field="requested_time_s", path=path),
                    initial_total_flow_residual_max_abs=residual_value,
                    peak_time_s=as_float(peak_row["elapsed_time_s"], field="elapsed_time_s", path=path),
                    peak_max_abs_q=as_float(peak_row["max_abs_q"], field="max_abs_q", path=path),
                    final_max_abs_q=as_float(final_row["max_abs_q"], field="max_abs_q", path=path),
                    final_rms_q=as_float(final_row["rms_q"], field="rms_q", path=path),
                    max_positivity_projection_count=max(
                        as_int(row["positivity_projection_count"], field="positivity_projection_count", path=path)
                        for row in ok_rows
                    ),
                    status="ok" if residual_status == "ok" else f"residual {residual_status}",
                    error_message="" if residual_status == "ok" else residual_error_message,
                    residual_status=residual_status,
                    residual_error_message=residual_error_message,
                    source_csv=path.as_posix(),
                )
            )
        else:
            error_message = aggregate_error(group)
            summaries.append(
                RestMethodRow(
                    method=method,
                    method_label=label,
                    severity=display_severity,
                    nx=nx,
                    final_requested_time_s=math.nan,
                    initial_total_flow_residual_max_abs=residual_value,
                    peak_time_s=math.nan,
                    peak_max_abs_q=math.nan,
                    final_max_abs_q=math.nan,
                    final_rms_q=math.nan,
                    max_positivity_projection_count=0,
                    status="not available",
                    error_message=error_message or residual_error_message,
                    residual_status=residual_status,
                    residual_error_message=residual_error_message,
                    source_csv=path.as_posix(),
                )
            )
    return summaries


def collect_rest_method_rows(rest_root: Path) -> list[RestMethodRow]:
    paths = sorted(rest_root.glob("rest-*/rest_state_drift.csv"))
    if not paths:
        raise FileNotFoundError(f"no rest-state method CSVs found under {rest_root}")
    rows: list[RestMethodRow] = []
    for path in paths:
        rows.extend(summarize_rest_method_csv(path))
    return sorted(rows, key=lambda row: (REST_METHOD_ORDER.get(row.method, 99), row.severity))


def direct_comparison_case_display(case_label: str, severity: float) -> str:
    rounded = case_token(severity)
    if case_label == "77" and not math.isclose(severity, 23.0, abs_tol=1.0e-9):
        return f"C23 ({severity:.2f}%)"
    if case_label == "60":
        return "C40"
    return rounded


def summarize_comparison_csv(path: Path) -> list[ComparisonTimeStepRow]:
    rows = read_csv(path)
    summaries: list[ComparisonTimeStepRow] = []
    for row in rows:
        severity = as_float(row["severity"], field="severity", path=path)
        summaries.append(
            ComparisonTimeStepRow(
                case_label=row["case_label"],
                case_display=direct_comparison_case_display(row["case_label"], severity),
                severity=severity,
                spatial_method=row.get("spatial_method", "not-recorded"),
                nx=as_int(row["nx"], field="nx", path=path),
                dt_cap_s=as_float(row["dt_s"], field="dt_s", path=path),
                accepted_dt_min_s=as_float(row["accepted_dt_min"], field="accepted_dt_min", path=path),
                accepted_dt_max_s=as_float(row["accepted_dt_max"], field="accepted_dt_max", path=path),
                realized_cfl_max=as_float(row["realized_cfl_max"], field="realized_cfl_max", path=path),
                mean_velocity_discrepancy_cm_s=as_float(
                    row["mean_abs_discrepancy_cm_s"], field="mean_abs_discrepancy_cm_s", path=path
                ),
                rms_velocity_discrepancy_cm_s=as_float(
                    row["l2_velocity_discrepancy_cm_s"], field="l2_velocity_discrepancy_cm_s", path=path
                ),
                max_velocity_discrepancy_cm_s=as_float(
                    row["max_abs_discrepancy_cm_s"], field="max_abs_discrepancy_cm_s", path=path
                ),
                relative_rms_velocity_discrepancy=as_float(
                    row["relative_l2_velocity_discrepancy"],
                    field="relative_l2_velocity_discrepancy",
                    path=path,
                ),
                status=row["run_status"],
                source_csv=path.as_posix(),
            )
        )
    return summaries


def collect_comparison_time_step_rows(comparison_root: Path) -> list[ComparisonTimeStepRow]:
    paths = sorted(comparison_root.glob("compare-dt-*/comparison_summary.csv"))
    if not paths:
        raise FileNotFoundError(f"no compare-dt summary CSVs found under {comparison_root}")
    rows: list[ComparisonTimeStepRow] = []
    for path in paths:
        rows.extend(summarize_comparison_csv(path))
    return sorted(rows, key=lambda row: (round(row.severity), row.dt_cap_s))


def write_dict_csv(path: Path, rows: list[dict[str, str]], fieldnames: list[str]) -> Path:
    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open("w", encoding="utf-8", newline="") as handle:
        writer = csv.DictWriter(handle, fieldnames=fieldnames, lineterminator="\n")
        writer.writeheader()
        writer.writerows(rows)
    return path


def rest_method_rows_for_csv(rows: list[RestMethodRow]) -> list[dict[str, str]]:
    return [
        {
            "method": row.method,
            "method_label": row.method_label,
            "severity": str(row.severity),
            "case": case_token(row.severity),
            "nx": str(row.nx),
            "final_requested_time_s": finite_or_blank(row.final_requested_time_s),
            "initial_total_flow_residual_max_abs": finite_or_blank(row.initial_total_flow_residual_max_abs),
            "peak_time_s": finite_or_blank(row.peak_time_s),
            "peak_max_abs_q": finite_or_blank(row.peak_max_abs_q),
            "final_max_abs_q": finite_or_blank(row.final_max_abs_q),
            "final_rms_q": finite_or_blank(row.final_rms_q),
            "max_positivity_projection_count": str(row.max_positivity_projection_count),
            "status": row.status,
            "error_message": row.error_message,
            "residual_status": row.residual_status,
            "residual_error_message": row.residual_error_message,
            "source_csv": row.source_csv,
        }
        for row in rows
    ]


def comparison_rows_for_csv(rows: list[ComparisonTimeStepRow]) -> list[dict[str, str]]:
    return [
        {
            "case_label": row.case_label,
            "case": row.case_display,
            "severity": finite_or_blank(row.severity),
            "spatial_method": row.spatial_method,
            "nx": str(row.nx),
            "dt_cap_s": finite_or_blank(row.dt_cap_s),
            "accepted_dt_min_s": finite_or_blank(row.accepted_dt_min_s),
            "accepted_dt_max_s": finite_or_blank(row.accepted_dt_max_s),
            "realized_cfl_max": finite_or_blank(row.realized_cfl_max),
            "mean_velocity_discrepancy_cm_s": finite_or_blank(row.mean_velocity_discrepancy_cm_s),
            "rms_velocity_discrepancy_cm_s": finite_or_blank(row.rms_velocity_discrepancy_cm_s),
            "max_velocity_discrepancy_cm_s": finite_or_blank(row.max_velocity_discrepancy_cm_s),
            "relative_rms_velocity_discrepancy": finite_or_blank(row.relative_rms_velocity_discrepancy),
            "status": row.status,
            "source_csv": row.source_csv,
        }
        for row in rows
    ]


def latex_number(value: float) -> str:
    if not math.isfinite(value):
        return "--"
    if value == 0.0:
        return "0"
    abs_value = abs(value)
    if abs_value < 1.0e-3 or abs_value >= 1.0e3:
        return f"{value:.3e}"
    return f"{value:.4g}"


def latex_percent(value: float) -> str:
    if not math.isfinite(value):
        return "--"
    return f"{100.0 * value:.2f}\\%"


def latex_dt_range(min_value: float, max_value: float) -> str:
    if not math.isfinite(min_value) or not math.isfinite(max_value):
        return "--"
    if math.isclose(min_value, max_value, rel_tol=1.0e-6, abs_tol=0.0):
        return latex_number(max_value)
    return f"{latex_number(min_value)}--{latex_number(max_value)}"


def latex_text(value: str) -> str:
    return value.replace("%", r"\%").replace("_", r"\_")


def status_label(row: RestMethodRow) -> str:
    if row.status == "ok":
        return "ok"
    if row.status.startswith("residual ") and "positive native timestep" in row.residual_error_message:
        return "residual skipped"
    if "positive native timestep" in row.error_message:
        return "not available"
    return row.status


def rest_method_table(rows: list[RestMethodRow]) -> str:
    lines = [
        r"\begin{tabular}{@{}llrrrrl@{}}",
        r"\toprule",
        r"Method & Case & $\max |R_q(0)|$ & $t_{\mathrm{peak}}$ & peak $\max |q|$ & final $\max |q|$ & Status \\",
        r"\midrule",
    ]
    for row in rows:
        lines.append(
            " & ".join(
                [
                    latex_text(row.method_label),
                    latex_case_token(row.severity),
                    latex_number(row.initial_total_flow_residual_max_abs),
                    latex_number(row.peak_time_s),
                    latex_number(row.peak_max_abs_q),
                    latex_number(row.final_max_abs_q),
                    latex_text(status_label(row)),
                ]
            )
            + r" \\"
        )
    lines.extend([r"\bottomrule", r"\end{tabular}"])
    return "\n".join(lines) + "\n"


def comparison_time_step_table(rows: list[ComparisonTimeStepRow]) -> str:
    lines = [
        r"\begin{tabular}{@{}llrrrrrr@{}}",
        r"\toprule",
        r"Case & $\Delta t_{\max}$ & accepted $\Delta t$ & CFL & $D_{u,1}$ & $D_{u,2}$ & rel. $D_{u,2}$ & $\max |d_u|$ \\",
        r"\midrule",
    ]
    for row in rows:
        lines.append(
            " & ".join(
                [
                    latex_text(row.case_display),
                    latex_number(row.dt_cap_s),
                    latex_dt_range(row.accepted_dt_min_s, row.accepted_dt_max_s),
                    latex_number(row.realized_cfl_max),
                    latex_number(row.mean_velocity_discrepancy_cm_s),
                    latex_number(row.rms_velocity_discrepancy_cm_s),
                    latex_percent(row.relative_rms_velocity_discrepancy),
                    latex_number(row.max_velocity_discrepancy_cm_s),
                ]
            )
            + r" \\"
        )
    lines.extend([r"\bottomrule", r"\end{tabular}"])
    return "\n".join(lines) + "\n"


def render_tables(
    rest_root: Path,
    comparison_root: Path,
    verification_data_dir: Path,
    verification_table_dir: Path,
    comparison_data_dir: Path,
    comparison_table_dir: Path,
) -> list[Path]:
    rest_rows = collect_rest_method_rows(rest_root)
    comparison_rows = collect_comparison_time_step_rows(comparison_root)

    verification_data_path = verification_data_dir / "rest_method_sensitivity.csv"
    verification_table_path = verification_table_dir / "rest_method_sensitivity.tex"
    comparison_data_path = comparison_data_dir / "comparison_time_step_sensitivity.csv"
    comparison_table_path = comparison_table_dir / "comparison_time_step_sensitivity.tex"

    write_dict_csv(
        verification_data_path,
        rest_method_rows_for_csv(rest_rows),
        [
            "method",
            "method_label",
            "severity",
            "case",
            "nx",
            "final_requested_time_s",
            "initial_total_flow_residual_max_abs",
            "peak_time_s",
            "peak_max_abs_q",
            "final_max_abs_q",
            "final_rms_q",
            "max_positivity_projection_count",
            "status",
            "error_message",
            "residual_status",
            "residual_error_message",
            "source_csv",
        ],
    )
    write_dict_csv(
        comparison_data_path,
        comparison_rows_for_csv(comparison_rows),
        [
            "case_label",
            "case",
            "severity",
            "spatial_method",
            "nx",
            "dt_cap_s",
            "accepted_dt_min_s",
            "accepted_dt_max_s",
            "realized_cfl_max",
            "mean_velocity_discrepancy_cm_s",
            "rms_velocity_discrepancy_cm_s",
            "max_velocity_discrepancy_cm_s",
            "relative_rms_velocity_discrepancy",
            "status",
            "source_csv",
        ],
    )

    verification_table_dir.mkdir(parents=True, exist_ok=True)
    comparison_table_dir.mkdir(parents=True, exist_ok=True)
    verification_table_path.write_text(rest_method_table(rest_rows), encoding="utf-8")
    comparison_table_path.write_text(comparison_time_step_table(comparison_rows), encoding="utf-8")
    return [verification_data_path, verification_table_path, comparison_data_path, comparison_table_path]


def main(argv: list[str] | None = None) -> int:
    args = parse_args(argv)
    try:
        paths = render_tables(
            args.rest_root,
            args.comparison_root,
            args.verification_data_dir,
            args.verification_table_dir,
            args.comparison_data_dir,
            args.comparison_table_dir,
        )
    except (FileNotFoundError, ValueError) as exc:
        print(f"ops-render-case-study-evidence-tables: {exc}")
        return 1
    for path in paths:
        print(path)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
