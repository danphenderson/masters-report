#!/usr/bin/env python3
"""Render package-benchmark CSVs into report figures and compact tables."""

from __future__ import annotations

import argparse
import csv
import math
from collections import Counter
from pathlib import Path
from typing import Iterable

import matplotlib

matplotlib.use("Agg")
import matplotlib.pyplot as plt


CSV_FILES = {
    "case_results": "case_results.csv",
    "refinement": "refinement.csv",
    "backend_parity": "backend_parity.csv",
    "stokes_ic": "stokes_ic.csv",
    "rheology_profile": "rheology_profile.csv",
    "boundary_openbf": "boundary_openbf.csv",
    "resolved3d": "resolved3d.csv",
    "python_mps": "python_mps.csv",
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
    points = [
        (
            row.get("method", ""),
            row.get("metric", ""),
            as_float(row, "observed_order"),
        )
        for row in ok_rows(rows)
    ]
    points = [(method, metric, value) for method, metric, value in points if value is not None]
    if not points:
        return placeholder_figure("Package Benchmark Convergence", "No finite smoke or overnight convergence rows.")

    labels = [f"{method}\n{metric.replace('_l2', '')}" for method, metric, _ in points]
    values = [value for _, _, value in points]
    fig, ax = plt.subplots(figsize=(max(6.5, 0.45 * len(values)), 3.8))
    ax.bar(range(len(values)), values, color="#3a6ea5")
    ax.axhline(1.0, color="#666666", linewidth=0.8, linestyle="--")
    ax.set_ylabel("Observed order")
    ax.set_title("Self-convergence observed order")
    ax.set_xticks(range(len(labels)))
    ax.set_xticklabels(labels, rotation=45, ha="right", fontsize=8)
    ax.grid(axis="y", alpha=0.25)
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
            points.append((native + sciml, max(finite_errors), row.get("algorithm", "")))
    if not points:
        return placeholder_figure("Backend Parity", "No finite native/SciML parity rows.")

    fig, ax = plt.subplots(figsize=(6.5, 3.8))
    for runtime, error, label in points:
        ax.scatter(runtime, max(error, 1.0e-16), s=55, label=label)
    ax.set_xscale("log")
    ax.set_yscale("log")
    ax.set_xlabel("Combined runtime, seconds")
    ax.set_ylabel("Max final-state L2 difference")
    ax.set_title("Backend agreement versus runtime")
    ax.grid(True, which="both", alpha=0.25)
    handles, labels = ax.get_legend_handles_labels()
    if labels:
        ax.legend(fontsize=8)
    return fig


def rheology_profile_figure(rows: list[dict[str, str]]) -> plt.Figure:
    points = []
    for row in ok_rows(rows):
        value = as_float(row, "max_abs_u")
        if value is not None:
            points.append((row.get("rheology", ""), row.get("profile", ""), value))
    if not points:
        return placeholder_figure("Rheology/Profile Sensitivity", "No finite sensitivity rows.")

    labels = [f"{rheology}\n{profile}" for rheology, profile, _ in points]
    values = [value for _, _, value in points]
    fig, ax = plt.subplots(figsize=(max(6.5, 0.55 * len(values)), 3.8))
    ax.bar(range(len(values)), values, color="#7a8b48")
    ax.set_ylabel("Max absolute velocity, cm/s")
    ax.set_title("Rheology/profile sensitivity")
    ax.set_xticks(range(len(labels)))
    ax.set_xticklabels(labels, rotation=45, ha="right", fontsize=8)
    ax.grid(axis="y", alpha=0.25)
    return fig


def resolved3d_figure(rows: list[dict[str, str]]) -> plt.Figure:
    points = []
    for row in ok_rows(rows):
        value = as_float(row, "mean_abs_error_cm_s")
        if value is not None:
            points.append((row.get("case_label", ""), row.get("profile", ""), value))
    if not points:
        return placeholder_figure("Resolved-Velocity Diagnostic", "Resolved-3D diagnostics were skipped or unavailable.")

    labels = [f"{case}\n{profile}" for case, profile, _ in points]
    values = [value for _, _, value in points]
    fig, ax = plt.subplots(figsize=(max(6.5, 0.6 * len(values)), 3.8))
    ax.bar(range(len(values)), values, color="#9a5a42")
    ax.set_ylabel("Mean absolute velocity error, cm/s")
    ax.set_title("Resolved-velocity output-operator diagnostic")
    ax.set_xticks(range(len(labels)))
    ax.set_xticklabels(labels, rotation=45, ha="right", fontsize=8)
    ax.grid(axis="y", alpha=0.25)
    return fig


def python_mps_figure(rows: list[dict[str, str]]) -> plt.Figure:
    points = []
    for row in ok_rows(rows):
        elapsed = as_float(row, "elapsed_s")
        rel_area = as_float(row, "relative_area_mean_final")
        if elapsed is not None:
            points.append((row.get("method", ""), row.get("nx", ""), elapsed, rel_area))
    if not points:
        return placeholder_figure("Python CPU/MPS Benchmark", "Python/Torch-MPS rows were skipped or unavailable.")

    labels = [f"{method}\nN={nx}" for method, nx, _, _ in points]
    values = [elapsed for _, _, elapsed, _ in points]
    fig, ax = plt.subplots(figsize=(max(6.5, 0.55 * len(values)), 3.8))
    ax.bar(range(len(values)), values, color="#4c7899")
    ax.set_ylabel("Comparison runtime, seconds")
    ax.set_title("Python native CPU versus Torch-MPS")
    ax.set_xticks(range(len(labels)))
    ax.set_xticklabels(labels, rotation=45, ha="right", fontsize=8)
    ax.grid(axis="y", alpha=0.25)
    for index, (_, _, _, rel_area) in enumerate(points):
        if rel_area is not None:
            ax.text(index, values[index], f"{rel_area:.1e}", ha="center", va="bottom", fontsize=7)
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
        lines.append(
            f"        {latex_escape(name.replace('_', ' '))} & {len(rows)} & {ok} & {skipped_or_error} \\\\"
        )
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
    written.extend(save_figure(convergence_figure(tables["refinement"]), output_dir, "package-benchmark-convergence", formats))
    written.extend(save_figure(backend_parity_figure(tables["backend_parity"]), output_dir, "package-benchmark-backend-parity", formats))
    written.extend(save_figure(rheology_profile_figure(tables["rheology_profile"]), output_dir, "package-benchmark-rheology-profile", formats))
    written.extend(save_figure(resolved3d_figure(tables["resolved3d"]), output_dir, "package-benchmark-resolved3d", formats))
    written.extend(save_figure(python_mps_figure(tables["python_mps"]), output_dir, "package-benchmark-python-mps", formats))
    written.append(write_summary_table(tables, table_dir))
    return written


def main() -> None:
    args = parse_args()
    written = render_all(args.benchmark_dir, args.output_dir, args.table_dir, args.formats)
    for path in written:
        print(path)


if __name__ == "__main__":
    main()
