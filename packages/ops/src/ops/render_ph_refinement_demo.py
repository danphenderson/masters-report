#!/usr/bin/env python3
"""Render the manufactured-solution p/h refinement demonstration."""

from __future__ import annotations

import argparse
import csv
import math
from pathlib import Path
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


DEFAULT_CSV = Path("report/assets/data/verification/p_h_refinement_demo.csv")
DEFAULT_OUTPUT_DIR = Path("report/assets/rendered")
DEFAULT_TABLE_DIR = Path("report/assets/tables/verification")


def parse_args(argv: list[str] | None = None) -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--csv", type=Path, default=DEFAULT_CSV, help="Input p/h refinement CSV.")
    parser.add_argument("--output-dir", type=Path, default=DEFAULT_OUTPUT_DIR, help="Figure output directory.")
    parser.add_argument("--table-dir", type=Path, default=DEFAULT_TABLE_DIR, help="LaTeX table output directory.")
    parser.add_argument("--formats", nargs="+", default=["pdf", "png"], choices=["pdf", "png"])
    return parser.parse_args(argv)


def read_rows(path: Path) -> list[dict[str, str]]:
    with path.open(newline="") as handle:
        return list(csv.DictReader(handle))


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


def sort_key(row: dict[str, str]) -> tuple[int, int]:
    sweep_order = 0 if row.get("sweep") == "h_refinement" else 1
    value = int(row.get("nx") or row.get("degree") or 0)
    if sweep_order == 1:
        value = int(row.get("degree") or 0)
    return sweep_order, value


def latex_number(value: str | float | None) -> str:
    if value is None:
        return "--"
    parsed = value if isinstance(value, float) else as_float({"value": str(value)}, "value")
    if parsed is None:
        return "--"
    if abs(parsed) >= 1.0e-3 and abs(parsed) < 1.0e4:
        return f"{parsed:.4g}"
    return f"{parsed:.3e}"


def sweep_label(value: str) -> str:
    return "h-refinement" if value == "h_refinement" else "p-refinement"


def p_sweep_status(row: dict[str, str]) -> str:
    status = (row.get("p_sweep_status") or "").strip()
    if status:
        return status
    return "not_applicable" if row.get("sweep") == "h_refinement" else "not_evaluated"


def limiter_policy(row: dict[str, str]) -> str:
    value = (row.get("dg_limiter_policy") or "").strip()
    return value or "unknown"


def latex_text(value: str) -> str:
    return value.replace("_", r"\_")


def render_figure(rows: list[dict[str, str]]) -> plt.Figure:
    h_rows = [row for row in rows if row.get("sweep") == "h_refinement"]
    p_rows = [row for row in rows if row.get("sweep") == "p_refinement"]

    fig, (ax_cost, ax_degree) = plt.subplots(1, 2, figsize=(8.0, 3.5))
    for group, label, color, marker in (
        (h_rows, "h-refinement, fixed $p=2$", "#1F3A5F", "o"),
        (p_rows, "p-refinement, fixed mesh", "#B23A3A", "s"),
    ):
        xs = [as_float(row, "dofs") for row in group]
        ys = [as_float(row, "area_l2_error") for row in group]
        pairs = [(x, y) for x, y in zip(xs, ys) if x is not None and y is not None and y > 0.0]
        if pairs:
            ax_cost.plot(
                [x for x, _ in pairs],
                [y for _, y in pairs],
                marker=marker,
                linewidth=1.5,
                color=color,
                label=label,
            )

    degree_pairs = [
        (as_float(row, "degree"), as_float(row, "area_log10_l2_error"))
        for row in p_rows
        if as_float(row, "degree") is not None and as_float(row, "area_log10_l2_error") is not None
    ]
    if degree_pairs:
        ax_degree.plot(
            [x for x, _ in degree_pairs],
            [y for _, y in degree_pairs],
            marker="s",
            linewidth=1.5,
            color="#B23A3A",
        )

    ax_cost.set_xscale("log")
    ax_cost.set_yscale("log")
    ax_cost.set_xlabel("State degrees of freedom")
    ax_cost.set_ylabel(r"Area $L^2$ error")
    ax_cost.set_title("Error versus cost")
    ax_cost.grid(True, which="both", alpha=0.25)
    ax_cost.legend(fontsize=8, frameon=False)

    ax_degree.set_xlabel("Polynomial degree $p$")
    ax_degree.set_ylabel(r"$\log_{10}$ area $L^2$ error")
    ax_degree.set_title("Fixed-mesh p sweep")
    ax_degree.set_xticks([0, 1, 2, 3, 4])
    ax_degree.grid(True, alpha=0.25)
    fig.tight_layout()
    return fig


def save_figure(fig: plt.Figure, output_dir: Path, formats: Iterable[str]) -> list[Path]:
    output_dir.mkdir(parents=True, exist_ok=True)
    paths = []
    for fmt in formats:
        path = output_dir / f"p-h-refinement-demo.{fmt}"
        fig.savefig(path, bbox_inches="tight")
        paths.append(path)
    plt.close(fig)
    return paths


def render_table(rows: list[dict[str, str]], table_dir: Path) -> Path:
    table_dir.mkdir(parents=True, exist_ok=True)
    path = table_dir / "p_h_refinement_demo.tex"
    lines = [
        r"\begin{table}[!htb]",
        r"    \centering",
        r"    \scriptsize",
        (
            r"    \caption{Manufactured-solution p- and h-refinement diagnostic. "
            r"The policy column records whether the modal DG limiter was applied; "
            r"limiter-disabled rows are smooth-MMS verification evidence and do not change "
            r"the conservative default DG policy.}"
        ),
        r"    \resizebox{\textwidth}{!}{%",
        r"    \begin{tabular}{@{}lrrrrrrrrrrrrr@{}}",
        r"        \toprule",
        (
            r"        Sweep & policy & $p$ & $N$ & DOFs & $\Delta t$ & steps "
            r"& $\|e_a\|_2$ & h-order & p-reduction & $\|e_q\|_2$ & h-order "
            r"& p-reduction & p-status \\"
        ),
        r"        \midrule",
    ]
    for row in sorted(rows, key=sort_key):
        lines.append(
            "        "
            + " & ".join(
                [
                    sweep_label(row.get("sweep", "")),
                    latex_text(limiter_policy(row)),
                    row.get("degree", ""),
                    row.get("nx", ""),
                    row.get("dofs", ""),
                    latex_number(row.get("dt")),
                    row.get("steps", ""),
                    latex_number(row.get("area_l2_error")),
                    latex_number(row.get("area_l2_observed_order")),
                    latex_number(row.get("area_l2_reduction")),
                    latex_number(row.get("flow_l2_error")),
                    latex_number(row.get("flow_l2_observed_order")),
                    latex_number(row.get("flow_l2_reduction")),
                    latex_text(p_sweep_status(row)),
                ]
            )
            + r" \\"
        )
    lines.extend(
        [
            r"        \bottomrule",
            r"    \end{tabular}%",
            r"    }",
            r"\end{table}",
        ]
    )
    path.write_text("\n".join(lines) + "\n")
    return path


def main(argv: list[str] | None = None) -> None:
    args = parse_args(argv)
    rows = ok_rows(read_rows(args.csv))
    if not rows:
        raise SystemExit(f"no OK p/h refinement rows found in {args.csv}")
    figure_paths = save_figure(render_figure(rows), args.output_dir, args.formats)
    table_path = render_table(rows, args.table_dir)
    for path in figure_paths:
        print(f"figure,{path}")
    print(f"table,{table_path}")


if __name__ == "__main__":
    main()
