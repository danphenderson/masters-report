#!/usr/bin/env python3
"""Render package-benchmark CSVs into report figures and compact tables."""

from __future__ import annotations

import argparse
import csv
import math
from collections import Counter, defaultdict
from pathlib import Path
from statistics import median
from textwrap import wrap
from typing import Iterable

import matplotlib

matplotlib.use("Agg")
matplotlib.rcParams.update(
    {
        "pdf.fonttype": 42,
        "ps.fonttype": 42,
        "font.family": "serif",
        "font.serif": ["CMU Serif", "Computer Modern Roman", "DejaVu Serif"],
        "mathtext.fontset": "cm",
        "axes.unicode_minus": False,
    }
)
import matplotlib.pyplot as plt  # noqa: E402
from matplotlib.lines import Line2D  # noqa: E402


CSV_FILES = {
    "case_results": "case_results.csv",
    "refinement": "refinement.csv",
    "backend_parity": "backend_parity.csv",
    "stokes_ic": "stokes_ic.csv",
    "rheology_profile": "rheology_profile.csv",
    "boundary_openbf": "boundary_openbf.csv",
    "resolved3d": "resolved3d.csv",
}

METRIC_LABELS = {
    "area_l2": "Area",
    "flow_l2": "Flow",
    "velocity_l2": "Velocity",
    "pressure_l2": "Pressure",
}

METHOD_LABELS = {
    "fv-first-order": "FV first",
    "fv-muscl": "FV MUSCL",
    "fv-muscl-minmod": "FV MUSCL",
    "fv-lax-wendroff": "FV LW",
    "dg": "DG p-sweep",
    "dg-p0": "DG p0",
    "dg-p1": "DG p1",
    "dg-p2": "DG p2",
}

PROFILE_LABELS = {
    "flat": "Flat",
    "parabolic": "Parabolic",
    "power": "Power",
}

RHEOLOGY_LABELS = {
    "newtonian": "Newtonian",
    "carreau": "Carreau",
    "carreau-yasuda": "Carreau-Yasuda",
    "casson": "Casson",
    "power-law": "Power law",
}

STATUS_COLORS = {
    "ok": "#217A7A",
    "skipped": "#C6862C",
    "error": "#B23A3A",
}

QUALITATIVE_COLORS = [
    "#1F3A5F",
    "#B23A3A",
    "#217A7A",
    "#8067A9",
    "#C6862C",
    "#6E6E6E",
]

METRIC_COLORS = {
    "area_l2": "#1F3A5F",
    "flow_l2": "#C6862C",
    "velocity_l2": "#217A7A",
    "pressure_l2": "#B23A3A",
}


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--benchmark-dir", required=True, type=Path)
    parser.add_argument(
        "--output-dir",
        type=Path,
        default=Path("figures/static/static/rendered"),
        help="Directory for PDF/PNG figure outputs.",
    )
    parser.add_argument(
        "--table-dir",
        type=Path,
        default=Path("figures/static/static/tables/package-benchmark"),
        help="Directory for LaTeX table fragments.",
    )
    parser.add_argument("--formats", nargs="+", default=["pdf", "png"], choices=["pdf", "png"])
    return parser.parse_args()


def read_csv(path: Path) -> list[dict[str, str]]:
    if not path.exists():
        return []
    with path.open(newline="") as handle:
        return list(csv.DictReader(handle))


def read_benchmark_tables(benchmark_dir: Path) -> dict[str, list[dict[str, str]]]:
    return {name: read_csv(benchmark_dir / filename) for name, filename in CSV_FILES.items()}


def as_float(row: dict[str, str], key: str) -> float | None:
    value = (row.get(key) or "").strip()
    if not value:
        return None
    try:
        parsed = float(value)
    except ValueError:
        return None
    return parsed if math.isfinite(parsed) else None


def ok_rows(rows: Iterable[dict[str, str]]) -> list[dict[str, str]]:
    return [row for row in rows if (row.get("status") or "").strip().lower() == "ok"]


def ordered_unique(values: Iterable[str]) -> list[str]:
    seen: set[str] = set()
    ordered: list[str] = []
    for value in values:
        if value not in seen:
            seen.add(value)
            ordered.append(value)
    return ordered


def method_label(value: str) -> str:
    return METHOD_LABELS.get(value, value.replace("-", " ").strip() or "Unspecified")


def metric_label(value: str) -> str:
    return METRIC_LABELS.get(value, value.replace("_l2", "").replace("_", " ").title())


def profile_label(value: str) -> str:
    return PROFILE_LABELS.get(value, value.replace("-", " ").title() or "Unspecified")


def resolved_case_label(row: dict[str, str]) -> str:
    severity = as_float(row, "severity")
    if severity is not None:
        return f"C{int(round(severity))}"
    return row.get("case_label", "").strip() or "case"


def resolved_profile_tick_label(value: str) -> str:
    return value.replace("-", " ").strip() or "unspecified"


def rheology_label(value: str) -> str:
    return RHEOLOGY_LABELS.get(value, value.replace("-", " ").title() or "Unspecified")


def severity_sort_key(value: str) -> tuple[int, float | str]:
    try:
        return (0, float(value))
    except ValueError:
        return (1, value)


def integer_sort_key(value: str) -> tuple[int, int | str]:
    try:
        return (0, int(value))
    except ValueError:
        return (1, value)


def min_median_max(values: list[float]) -> tuple[float, float, float]:
    return min(values), median(values), max(values)


def save_figure(fig: plt.Figure, output_dir: Path, stem: str, formats: Iterable[str]) -> list[Path]:
    output_dir.mkdir(parents=True, exist_ok=True)
    paths = []
    for fmt in formats:
        path = output_dir / f"{stem}.{fmt}"
        fig.savefig(path, bbox_inches="tight")
        paths.append(path)
    plt.close(fig)
    return paths


def placeholder_figure(title: str, message: str) -> plt.Figure:
    fig, ax = plt.subplots(figsize=(6.5, 3.5))
    ax.axis("off")
    ax.text(0.5, 0.58, title, ha="center", va="center", fontsize=13, fontweight="bold")
    ax.text(0.5, 0.42, message, ha="center", va="center", fontsize=10)
    return fig


def convergence_figure(rows: list[dict[str, str]]) -> plt.Figure:
    grouped: dict[tuple[str, str], list[float]] = defaultdict(list)
    for row in ok_rows(rows):
        value = as_float(row, "observed_order")
        if value is not None:
            grouped[(row.get("method", ""), row.get("metric", ""))].append(value)
    if not grouped:
        return placeholder_figure("Package Benchmark Convergence", "No finite smoke or overnight convergence rows.")

    methods = ordered_unique(method for method, _ in grouped)
    metric_order = ["area_l2", "flow_l2", "velocity_l2", "pressure_l2"]
    metrics = [metric for metric in metric_order if any((method, metric) in grouped for method in methods)]
    metrics.extend(sorted({metric for _, metric in grouped if metric not in metrics}))
    x_positions = list(range(len(methods)))
    bar_width = min(0.18, 0.78 / max(1, len(metrics)))

    fig, ax = plt.subplots(figsize=(7.6, 4.2))
    for metric_index, metric in enumerate(metrics):
        offset = (metric_index - (len(metrics) - 1) / 2.0) * bar_width
        positions: list[float] = []
        medians: list[float] = []
        lower_errors: list[float] = []
        upper_errors: list[float] = []
        for method_index, method in enumerate(methods):
            values = grouped.get((method, metric), [])
            if not values:
                continue
            low, mid, high = min_median_max(values)
            positions.append(method_index + offset)
            medians.append(mid)
            lower_errors.append(mid - low)
            upper_errors.append(high - mid)
        ax.bar(
            positions,
            medians,
            width=bar_width * 0.88,
            yerr=[lower_errors, upper_errors],
            capsize=2.5,
            label=metric_label(metric),
            color=METRIC_COLORS.get(metric, QUALITATIVE_COLORS[metric_index % len(QUALITATIVE_COLORS)]),
        )
    ax.axhline(1.0, color="#666666", linewidth=0.8, linestyle="--")
    ax.axhline(2.0, color="#888888", linewidth=0.8, linestyle=":")
    ax.set_ylabel("Observed order")
    ax.set_title("Self-convergence observed-order summary")
    ax.set_xticks(x_positions)
    ax.set_xticklabels([method_label(method) for method in methods], rotation=25, ha="right", fontsize=8)
    ax.grid(axis="y", alpha=0.25)
    ax.legend(
        fontsize=8,
        ncols=len(metrics),
        loc="upper center",
        bbox_to_anchor=(0.5, -0.22),
        frameon=False,
    )
    ax.text(0.01, 0.96, "Bars show medians; whiskers span min-max.", transform=ax.transAxes, fontsize=8, va="top")
    fig.tight_layout()
    return fig


def backend_parity_figure(rows: list[dict[str, str]]) -> plt.Figure:
    points = []
    for row in ok_rows(rows):
        native = as_float(row, "native_elapsed_s")
        sciml = as_float(row, "sciml_elapsed_s")
        errors = [
            as_float(row, "area_l2"),
            as_float(row, "flow_l2"),
            as_float(row, "velocity_l2"),
            as_float(row, "pressure_l2"),
        ]
        finite_errors = [value for value in errors if value is not None]
        if native is not None and sciml is not None and finite_errors:
            points.append((row.get("method", ""), row.get("algorithm", ""), native + sciml, max(finite_errors)))
    if not points:
        return placeholder_figure("Backend Parity", "No finite native/SciML parity rows.")

    methods = ordered_unique(method for method, _, _, _ in points)
    algorithms = ordered_unique(algorithm for _, algorithm, _, _ in points)
    color_map = {method: QUALITATIVE_COLORS[index % len(QUALITATIVE_COLORS)] for index, method in enumerate(methods)}
    marker_cycle = ["o", "s", "^", "D", "P", "X"]
    marker_map = {algorithm: marker_cycle[index % len(marker_cycle)] for index, algorithm in enumerate(algorithms)}

    fig, ax = plt.subplots(figsize=(7.0, 4.1))
    for method, algorithm, runtime, error in points:
        ax.scatter(
            runtime,
            max(error, 1.0e-16),
            s=62,
            color=color_map[method],
            marker=marker_map[algorithm],
            edgecolor="white",
            linewidth=0.5,
            alpha=0.9,
        )
    ax.set_xscale("log")
    ax.set_yscale("log")
    ax.set_xlabel("Combined runtime, seconds")
    ax.set_ylabel("Max final-state L2 difference")
    ax.set_title("Backend parity: runtime versus final-state difference")
    ax.grid(True, which="both", alpha=0.25)
    ax.annotate(
        "Lower left is better",
        xy=(0.11, 0.14),
        xycoords="axes fraction",
        xytext=(0.39, 0.45),
        textcoords="axes fraction",
        arrowprops={"arrowstyle": "->", "color": "#555555", "linewidth": 0.9},
        fontsize=8,
        ha="center",
        va="center",
        bbox={"boxstyle": "round,pad=0.2", "facecolor": "white", "edgecolor": "#cccccc", "alpha": 0.9},
    )
    method_handles = [
        Line2D([0], [0], marker="o", linestyle="", color=color_map[method], label=method_label(method), markersize=6)
        for method in methods
    ]
    algorithm_handles = [
        Line2D(
            [0],
            [0],
            marker=marker_map[algorithm],
            linestyle="",
            markerfacecolor="#777777",
            markeredgecolor="#777777",
            color="#777777",
            label=algorithm or "unspecified",
            markersize=6,
        )
        for algorithm in algorithms
    ]
    method_legend = ax.legend(
        handles=method_handles,
        title="Method",
        loc="upper left",
        bbox_to_anchor=(1.01, 1.0),
        fontsize=8,
        title_fontsize=8,
    )
    ax.add_artist(method_legend)
    ax.legend(
        handles=algorithm_handles,
        title="SciML algorithm",
        loc="lower left",
        bbox_to_anchor=(1.01, 0.0),
        fontsize=8,
        title_fontsize=8,
    )
    fig.tight_layout()
    return fig


def rheology_profile_figure(rows: list[dict[str, str]]) -> plt.Figure:
    values_by_key: dict[tuple[str, str, str], float] = {}
    for row in ok_rows(rows):
        value = as_float(row, "max_abs_u")
        if value is not None:
            values_by_key[(row.get("severity", ""), row.get("rheology", ""), row.get("profile", ""))] = value
    if not values_by_key:
        return placeholder_figure("Rheology/Profile Sensitivity", "No finite sensitivity rows.")

    severities = sorted(ordered_unique(severity for severity, _, _ in values_by_key), key=severity_sort_key)
    rheologies = ordered_unique(rheology for _, rheology, _ in values_by_key)
    profiles = ordered_unique(profile for _, _, profile in values_by_key)
    ncols = 2 if len(severities) > 1 else 1
    nrows = math.ceil(len(severities) / ncols)
    fig, axes = plt.subplots(nrows, ncols, figsize=(8.0, 2.8 * nrows), squeeze=False)
    bar_width = min(0.22, 0.78 / max(1, len(profiles)))
    profile_colors = {
        profile: QUALITATIVE_COLORS[index % len(QUALITATIVE_COLORS)] for index, profile in enumerate(profiles)
    }

    for ax, severity in zip(axes.ravel(), severities):
        x_positions = list(range(len(rheologies)))
        for profile_index, profile in enumerate(profiles):
            offset = (profile_index - (len(profiles) - 1) / 2.0) * bar_width
            positions: list[float] = []
            heights: list[float] = []
            for rheology_index, rheology in enumerate(rheologies):
                value = values_by_key.get((severity, rheology, profile))
                if value is None:
                    continue
                positions.append(rheology_index + offset)
                heights.append(value)
            ax.bar(
                positions, heights, width=bar_width * 0.88, color=profile_colors[profile], label=profile_label(profile)
            )
        ax.set_title(f"Severity {severity}%")
        ax.set_xticks(x_positions)
        ax.set_xticklabels([rheology_label(rheology) for rheology in rheologies], rotation=25, ha="right", fontsize=8)
        ax.grid(axis="y", alpha=0.25)
        ax.set_ylabel("Max |u|, cm/s")

    for ax in axes.ravel()[len(severities) :]:
        ax.axis("off")
    handles = [
        Line2D([0], [0], color=profile_colors[profile], linewidth=6, label=profile_label(profile))
        for profile in profiles
    ]
    fig.legend(
        handles=handles,
        title="Velocity profile",
        loc="upper center",
        bbox_to_anchor=(0.5, 0.95),
        ncols=len(handles),
        fontsize=8,
        title_fontsize=8,
    )
    fig.suptitle("Rheology/profile sensitivity by stenosis severity", y=0.995)
    fig.tight_layout(rect=[0, 0, 1, 0.86])
    return fig


def resolved3d_figure(rows: list[dict[str, str]]) -> plt.Figure:
    points = []
    for row in ok_rows(rows):
        value = as_float(row, "mean_abs_discrepancy_cm_s")
        if value is None:
            value = as_float(row, "mean_abs_error_cm_s")
        if value is not None:
            points.append((resolved_case_label(row), row.get("profile", ""), value))
    if not points:
        statuses = Counter((row.get("status") or "missing").strip().lower() or "missing" for row in rows)
        if not rows:
            statuses["missing"] = 1
        status_order = [status for status in ("ok", "skipped", "error", "missing") if status in statuses]
        status_order.extend(sorted(status for status in statuses if status not in status_order))
        fig, (ax_status, ax_note) = plt.subplots(
            1,
            2,
            figsize=(6.4, 1.9),
            gridspec_kw={"width_ratios": [1.0, 2.35]},
        )
        ax_status.barh(
            range(len(status_order)),
            [statuses[status] for status in status_order],
            color=[STATUS_COLORS.get(status, "#777777") for status in status_order],
        )
        ax_status.set_yticks(range(len(status_order)))
        ax_status.set_yticklabels([status.title() for status in status_order], fontsize=8)
        ax_status.set_xlabel("Rows", fontsize=8)
        ax_status.set_title("CSV status", fontsize=9)
        ax_status.tick_params(axis="x", labelsize=8)
        ax_status.grid(axis="x", alpha=0.2)

        total = len(rows)
        ok_count = statuses.get("ok", 0)
        profiles = ", ".join(
            profile_label(value)
            for value in ordered_unique(row.get("profile", "") for row in rows if row.get("profile", ""))
        )
        first_message = next((row.get("error_message", "") for row in rows if row.get("error_message", "")), "")
        reason = (
            "No OK rows were emitted; the source CSV records row-level error details."
            if first_message
            else "No OK resolved-velocity diagnostic rows were emitted."
        )
        ax_note.axis("off")
        ax_note.text(0.0, 0.82, "Resolved-velocity diagnostic availability", fontsize=10, fontweight="bold")
        ax_note.text(0.0, 0.58, f"{ok_count}/{total} rows OK; profiles: {profiles or 'none'}", fontsize=8.5)
        for line_index, line in enumerate(wrap(f"Boundary: {reason}", width=58)[:3]):
            ax_note.text(0.0, 0.36 - 0.16 * line_index, line, fontsize=8, color="#444444")
        fig.tight_layout()
        return fig

    labels = [f"{case} {resolved_profile_tick_label(profile)}" for case, profile, _ in points]
    values = [value for _, _, value in points]
    fig, ax = plt.subplots(figsize=(max(6.5, 0.6 * len(values)), 3.8))
    ax.bar(range(len(values)), values, color="#217A7A")
    ax.set_ylabel("Velocity $L_1$ average discrepancy, cm/s")
    ax.set_title("Resolved-velocity CrossSectionQuadratureOperator diagnostic")
    ax.set_xticks(range(len(labels)))
    ax.set_xticklabels(labels, rotation=25, ha="right", fontsize=8)
    ax.grid(axis="y", alpha=0.25)
    return fig


def latex_escape(value: str) -> str:
    replacements = {
        "\\": r"\textbackslash{}",
        "&": r"\&",
        "%": r"\%",
        "$": r"\$",
        "#": r"\#",
        "_": r"\_",
        "{": r"\{",
        "}": r"\}",
        "~": r"\textasciitilde{}",
        "^": r"\textasciicircum{}",
    }
    for old, new in replacements.items():
        value = value.replace(old, new)
    return value


def write_summary_table(tables: dict[str, list[dict[str, str]]], table_dir: Path) -> Path:
    table_dir.mkdir(parents=True, exist_ok=True)
    path = table_dir / "package-benchmark-summary.tex"
    lines = [
        r"\begin{table}[!htb]",
        r"    \centering",
        r"    \scriptsize",
        r"    \caption{Package benchmark stage summary.}",
        r"    \begin{tabular}{@{}lrrr@{}}",
        r"        \toprule",
        r"        Stage & Rows & OK & Skipped/error \\",
        r"        \midrule",
    ]
    for name in CSV_FILES:
        rows = tables.get(name, [])
        statuses = Counter((row.get("status") or "").strip().lower() for row in rows)
        ok = statuses.get("ok", 0)
        skipped_or_error = len(rows) - ok
        lines.append(f"        {latex_escape(name.replace('_', ' '))} & {len(rows)} & {ok} & {skipped_or_error} \\\\")
    lines.extend(
        [
            r"        \bottomrule",
            r"    \end{tabular}",
            r"\end{table}",
            "",
        ]
    )
    path.write_text("\n".join(lines))
    return path


def render_all(benchmark_dir: Path, output_dir: Path, table_dir: Path, formats: Iterable[str]) -> list[Path]:
    tables = read_benchmark_tables(benchmark_dir)
    written: list[Path] = []
    written.extend(
        save_figure(convergence_figure(tables["refinement"]), output_dir, "package-benchmark-convergence", formats)
    )
    written.extend(
        save_figure(
            backend_parity_figure(tables["backend_parity"]), output_dir, "package-benchmark-backend-parity", formats
        )
    )
    written.extend(
        save_figure(
            rheology_profile_figure(tables["rheology_profile"]),
            output_dir,
            "package-benchmark-rheology-profile",
            formats,
        )
    )
    written.extend(
        save_figure(resolved3d_figure(tables["resolved3d"]), output_dir, "package-benchmark-resolved3d", formats)
    )
    written.append(write_summary_table(tables, table_dir))
    return written


def main() -> None:
    args = parse_args()
    written = render_all(args.benchmark_dir, args.output_dir, args.table_dir, args.formats)
    for path in written:
        print(path)


if __name__ == "__main__":
    main()
