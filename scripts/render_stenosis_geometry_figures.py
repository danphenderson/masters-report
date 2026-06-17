#!/usr/bin/env python3
"""Render report-ready and exploratory stenosis geometry figures from CSV exports."""

from __future__ import annotations

import argparse
import csv
from collections import defaultdict
from pathlib import Path

import matplotlib

matplotlib.use("Agg")

import matplotlib.pyplot as plt
import numpy as np
from mpl_toolkits.mplot3d import Axes3D  # noqa: F401 - registers 3D projection


DEFAULT_DATA_DIR = Path("figures/static/static/data/stenosis-geometry")
DEFAULT_OUTPUT_DIR = Path("figures/static/static/rendered")

COLORS = {
    "bloodred": "#B23A3A",
    "bloodredlight": "#F2C7C2",
    "wallgray": "#6E6E6E",
    "wallgraylight": "#D8D5D2",
    "mathblue": "#1F3A5F",
    "mathblue_lite": "#C9D6E5",
    "accent_teal": "#217A7A",
    "accent_teal_lite": "#C7E4E1",
}


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Render stenosis geometry figures from exported CSV data."
    )
    parser.add_argument("--data-dir", type=Path, default=DEFAULT_DATA_DIR)
    parser.add_argument("--output-dir", type=Path, default=DEFAULT_OUTPUT_DIR)
    parser.add_argument("--formats", nargs="+", default=["pdf", "png"])
    return parser.parse_args()


def rows_from_csv(path: Path) -> list[dict[str, str]]:
    if not path.is_file():
        raise FileNotFoundError(path)
    with path.open(newline="") as handle:
        return list(csv.DictReader(handle))


def float_field(row: dict[str, str], key: str) -> float:
    return float(row[key])


def int_severity(value: str | float) -> int:
    return int(round(float(value)))


def read_summary(data_dir: Path) -> dict[int, dict[str, float]]:
    summary: dict[int, dict[str, float]] = {}
    for row in rows_from_csv(data_dir / "analytic_summary.csv"):
        severity = int_severity(row["severity"])
        summary[severity] = {
            "throat_z_cm": float_field(row, "throat_z_cm"),
            "rmin_cm": float_field(row, "rmin_cm"),
            "rbase_cm": float_field(row, "rbase_cm"),
            "rmin_over_rbase": float_field(row, "rmin_over_rbase"),
        }
    return summary


def read_profiles(data_dir: Path) -> dict[int, list[dict[str, float]]]:
    profiles: dict[int, list[dict[str, float]]] = defaultdict(list)
    for row in rows_from_csv(data_dir / "analytic_radius_profiles.csv"):
        severity = int_severity(row["severity"])
        profiles[severity].append(
            {
                "z_cm": float_field(row, "z_cm"),
                "r0_cm": float_field(row, "r0_cm"),
                "rbase_cm": float_field(row, "rbase_cm"),
                "s_fraction": float_field(row, "s_fraction"),
            }
        )
    for values in profiles.values():
        values.sort(key=lambda item: item["z_cm"])
    return profiles


def surface_grid(path: Path) -> tuple[np.ndarray, np.ndarray, np.ndarray, np.ndarray]:
    rows = rows_from_csv(path)
    z_values = sorted({float_field(row, "z_cm") for row in rows})
    theta_values = sorted({float_field(row, "theta_rad") for row in rows})
    z_index = {value: index for index, value in enumerate(z_values)}
    theta_index = {value: index for index, value in enumerate(theta_values)}

    shape = (len(z_values), len(theta_values))
    z_grid = np.full(shape, np.nan)
    x_grid = np.full(shape, np.nan)
    y_grid = np.full(shape, np.nan)
    r_grid = np.full(shape, np.nan)

    for row in rows:
        i = z_index[float_field(row, "z_cm")]
        j = theta_index[float_field(row, "theta_rad")]
        z_grid[i, j] = float_field(row, "z_cm")
        x_grid[i, j] = float_field(row, "x_cm")
        y_grid[i, j] = float_field(row, "y_cm")
        r_grid[i, j] = float_field(row, "r_cm")

    return (
        close_surface(z_grid),
        close_surface(x_grid),
        close_surface(y_grid),
        close_surface(r_grid),
    )


def close_surface(values: np.ndarray) -> np.ndarray:
    return np.concatenate([values, values[:, :1]], axis=1)


def setup_3d_axis(ax, title: str) -> None:
    ax.set_title(title, color=COLORS["mathblue"], fontsize=10, pad=4)
    ax.set_xlabel("z (cm)", fontsize=8, labelpad=-5)
    ax.set_ylabel("")
    ax.set_zlabel("")
    ax.set_xlim(0.0, 6.0)
    ax.set_ylim(-0.24, 0.24)
    ax.set_zlim(-0.24, 0.24)
    try:
        ax.set_box_aspect((6.0, 0.7, 0.7), zoom=1.55)
    except TypeError:
        ax.set_box_aspect((6.0, 0.7, 0.7))
    ax.view_init(elev=15, azim=-65)
    ax.set_xticks([0, 2, 4, 6])
    ax.set_yticks([])
    ax.set_zticks([])
    ax.tick_params(
        axis="both",
        which="major",
        labelsize=7,
        colors=COLORS["mathblue"],
        pad=-2,
    )
    ax.xaxis.pane.set_facecolor((1, 1, 1, 0))
    ax.yaxis.pane.set_facecolor((1, 1, 1, 0))
    ax.zaxis.pane.set_facecolor((1, 1, 1, 0))
    ax.grid(False)


def plot_tube(ax, data_dir: Path, severity: int, color: str, title: str) -> None:
    z_grid, x_grid, y_grid, _ = surface_grid(
        data_dir / f"analytic_surface_sev{severity}.csv"
    )
    ax.plot_surface(
        z_grid,
        x_grid,
        y_grid,
        color=color,
        linewidth=0,
        antialiased=True,
        shade=True,
        alpha=0.93,
        rasterized=True,
    )
    ax.plot([0, 6], [0, 0], [0, 0], color=COLORS["mathblue"], linewidth=0.8, alpha=0.6)
    setup_3d_axis(ax, title)


def save_figure(fig, output_dir: Path, stem: str, formats: list[str]) -> list[Path]:
    output_dir.mkdir(parents=True, exist_ok=True)
    paths: list[Path] = []
    for fmt in formats:
        path = output_dir / f"{stem}.{fmt}"
        save_kwargs = {"bbox_inches": "tight"}
        if fmt.lower() == "png":
            save_kwargs["dpi"] = 240
        fig.savefig(path, **save_kwargs)
        paths.append(path)
    plt.close(fig)
    return paths


def render_overview(data_dir: Path, output_dir: Path, formats: list[str]) -> list[Path]:
    summary = read_summary(data_dir)
    throat_z = summary[50]["throat_z_cm"]
    rmin = summary[50]["rmin_cm"]

    fig = plt.figure(figsize=(7.2, 2.25))
    ax_healthy = fig.add_subplot(1, 2, 1, projection="3d")
    ax_stenotic = fig.add_subplot(1, 2, 2, projection="3d")

    plot_tube(ax_healthy, data_dir, 0, COLORS["wallgraylight"], "smooth reference vessel")
    plot_tube(ax_stenotic, data_dir, 50, COLORS["bloodredlight"], "50% smooth narrowed vessel")

    ax_stenotic.plot(
        [throat_z, throat_z],
        [0.0, rmin],
        [0.0, 0.0],
        color=COLORS["bloodred"],
        linewidth=1.2,
    )
    ax_stenotic.text(
        throat_z + 0.1,
        rmin + 0.02,
        0.02,
        "$z_\\star$",
        color=COLORS["bloodred"],
        fontsize=9,
    )

    fig.subplots_adjust(left=0.01, right=0.99, bottom=0.02, top=0.92, wspace=0.02)
    return save_figure(fig, output_dir, "stenosis-3d-overview", formats)


def render_slices(data_dir: Path, output_dir: Path, formats: list[str]) -> list[Path]:
    profiles = read_profiles(data_dir)
    cross_rows = rows_from_csv(data_dir / "analytic_cross_sections.csv")
    grouped: dict[str, list[dict[str, str]]] = defaultdict(list)
    for row in cross_rows:
        grouped[row["slice_label"]].append(row)

    fig = plt.figure(figsize=(7.2, 5.6), constrained_layout=True)
    grid = fig.add_gridspec(2, 3, height_ratios=[1.3, 1.0])
    ax_profile = fig.add_subplot(grid[0, :])

    for severity, color in [
        (0, COLORS["wallgray"]),
        (23, COLORS["accent_teal"]),
        (40, COLORS["mathblue"]),
        (50, COLORS["bloodred"]),
    ]:
        values = profiles[severity]
        ax_profile.plot(
            [item["z_cm"] for item in values],
            [item["r0_cm"] for item in values],
            color=color,
            linewidth=1.6 if severity == 50 else 1.1,
            label=f"{severity}% severity",
        )

    ax_profile.set_xlabel("axial coordinate z (cm)")
    ax_profile.set_ylabel("$R_0(z)$ (cm)")
    ax_profile.set_title("Reference radius profile", color=COLORS["mathblue"], fontsize=10)
    ax_profile.grid(True, color="#DDDDDD", linewidth=0.5)
    ax_profile.legend(loc="lower right", fontsize=8, frameon=True)

    slice_order = ["upstream", "throat", "downstream"]
    for index, label in enumerate(slice_order):
        ax = fig.add_subplot(grid[1, index])
        rows = sorted(grouped[label], key=lambda item: float_field(item, "theta_rad"))
        x = [float_field(item, "x_cm") for item in rows]
        y = [float_field(item, "y_cm") for item in rows]
        if rows:
            x.append(x[0])
            y.append(y[0])
        ax.fill(x, y, color=COLORS["bloodredlight"], alpha=0.9)
        ax.plot(x, y, color=COLORS["bloodred"], linewidth=1.2)
        z_value = float_field(rows[0], "z_cm") if rows else float("nan")
        r_value = float_field(rows[0], "r_cm") if rows else float("nan")
        ax.set_title(f"{label}\nz={z_value:.3f} cm, R={r_value:.3f} cm", fontsize=9)
        ax.set_aspect("equal", adjustable="box")
        ax.set_xlim(-0.21, 0.21)
        ax.set_ylim(-0.21, 0.21)
        ax.set_xlabel("x (cm)")
        ax.set_ylabel("y (cm)")
        ax.grid(True, color="#E5E5E5", linewidth=0.45)

    return save_figure(fig, output_dir, "stenosis-geometry-slices", formats)


def render_severity_gallery(data_dir: Path, output_dir: Path, formats: list[str]) -> list[Path]:
    fig = plt.figure(figsize=(7.4, 4.4))
    for index, severity in enumerate([0, 23, 40, 50], start=1):
        ax = fig.add_subplot(2, 2, index, projection="3d")
        color = COLORS["wallgraylight"] if severity == 0 else COLORS["bloodredlight"]
        plot_tube(ax, data_dir, severity, color, f"{severity}% severity")
    fig.suptitle(
        "Exploratory severity gallery for the same analytic profile",
        fontsize=10,
        color=COLORS["mathblue"],
    )
    fig.subplots_adjust(left=0.01, right=0.99, bottom=0.01, top=0.87, wspace=0.02, hspace=-0.18)
    return save_figure(fig, output_dir, "stenosis-severity-gallery", formats)


def render_resolved_envelopes(
    data_dir: Path, output_dir: Path, formats: list[str]
) -> list[Path]:
    paths: list[Path] = []
    for csv_path in sorted(data_dir.glob("resolved_envelope_case*_sev*.csv")):
        rows = rows_from_csv(csv_path)
        if not rows:
            continue

        z_values = sorted({float_field(row, "z_cm") for row in rows})
        theta_values = sorted({float_field(row, "theta_rad") for row in rows})
        z_index = {value: index for index, value in enumerate(z_values)}
        theta_index = {value: index for index, value in enumerate(theta_values)}
        shape = (len(z_values), len(theta_values))
        z_grid = np.full(shape, np.nan)
        x_grid = np.full(shape, np.nan)
        y_grid = np.full(shape, np.nan)

        for row in rows:
            i = z_index[float_field(row, "z_cm")]
            j = theta_index[float_field(row, "theta_rad")]
            z_grid[i, j] = float_field(row, "z_cm")
            x_grid[i, j] = float_field(row, "x_cm")
            y_grid[i, j] = float_field(row, "y_cm")

        fig = plt.figure(figsize=(6.5, 3.8), constrained_layout=True)
        ax = fig.add_subplot(1, 1, 1, projection="3d")
        ax.plot_surface(
            close_surface(z_grid),
            close_surface(x_grid),
            close_surface(y_grid),
            color=COLORS["accent_teal_lite"],
            linewidth=0,
            antialiased=True,
            shade=True,
            alpha=0.9,
            rasterized=True,
        )
        case_label = rows[0]["case_label"]
        severity = int_severity(rows[0]["severity"])
        setup_3d_axis(
            ax,
            f"case {case_label}, {severity}% node envelope (not wall surface)",
        )
        stem = f"resolved-envelope-case{case_label}-sev{severity}"
        paths.extend(save_figure(fig, output_dir, stem, formats))

    if not paths:
        print("no resolved envelope CSVs found; skipped resolved envelope renders")
    return paths


def main() -> None:
    args = parse_args()
    data_dir = args.data_dir
    output_dir = args.output_dir
    formats = [fmt.lower().lstrip(".") for fmt in args.formats]

    written: list[Path] = []
    written.extend(render_overview(data_dir, output_dir, formats))
    written.extend(render_slices(data_dir, output_dir, formats))
    written.extend(render_severity_gallery(data_dir, output_dir, formats))
    written.extend(render_resolved_envelopes(data_dir, output_dir, formats))

    print(f"wrote {len(written)} rendered files")
    for path in written:
        print(path)


if __name__ == "__main__":
    main()
