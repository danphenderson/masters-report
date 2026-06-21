#!/usr/bin/env python3
"""Render report-ready and exploratory stenosis geometry figures from CSV exports."""

from __future__ import annotations

import argparse
import csv
import sys
from collections import defaultdict
from pathlib import Path

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
import numpy as np  # noqa: E402
from matplotlib.collections import LineCollection  # noqa: E402
from matplotlib.patches import Circle, Polygon  # noqa: E402
from mpl_toolkits.mplot3d import Axes3D  # noqa: E402, F401 - registers 3D projection


DEFAULT_DATA_DIR = Path("report/assets/data/stenosis-geometry")
DEFAULT_OUTPUT_DIR = Path("report/assets/rendered")
MANUSCRIPT_TRAJECTORY_SEVERITIES = [23, 50, 73]
TRAJECTORY_PARTICLE_COUNT = 5
RESOLVED_FLOW_CASES = [("77", 23), ("60", 40)]
REQUIRED_GEOMETRY_EXPORTS = (
    "analytic_summary.csv",
    "analytic_radius_profiles.csv",
    "analytic_cross_sections.csv",
    "analytic_surface_sev0.csv",
    "analytic_surface_sev23.csv",
    "analytic_surface_sev40.csv",
    "analytic_surface_sev50.csv",
    "analytic_surface_sev73.csv",
    "fem_mesh_view_sev50.csv",
    "fvm_mesh_view_sev50.csv",
    "stokes_particle_trajectories.csv",
)

COLORS = {
    "bloodred": "#B23A3A",
    "bloodredlight": "#F2C7C2",
    "wallgray": "#6E6E6E",
    "wallgraylight": "#D8D5D2",
    "mathblue": "#1F3A5F",
    "mathblue_lite": "#C9D6E5",
    "accent_teal": "#217A7A",
    "accent_teal_lite": "#C7E4E1",
    "trajectory_gold": "#C6862C",
    "trajectory_violet": "#8067A9",
}

TRAJECTORY_COLORS = [
    COLORS["mathblue"],
    COLORS["accent_teal"],
    COLORS["bloodred"],
    COLORS["trajectory_violet"],
    COLORS["trajectory_gold"],
]


def parse_args(argv: list[str] | None = None) -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Render stenosis geometry figures from exported CSV data.")
    parser.add_argument("--data-dir", type=Path, default=DEFAULT_DATA_DIR)
    parser.add_argument("--output-dir", type=Path, default=DEFAULT_OUTPUT_DIR)
    parser.add_argument("--formats", nargs="+", default=["pdf", "png"])
    return parser.parse_args(argv)


def rows_from_csv(path: Path) -> list[dict[str, str]]:
    if not path.is_file():
        raise FileNotFoundError(path)
    with path.open(newline="") as handle:
        return list(csv.DictReader(handle))


def missing_required_exports(data_dir: Path) -> list[str]:
    return [name for name in REQUIRED_GEOMETRY_EXPORTS if not (data_dir / name).is_file()]


def format_missing_exports_message(data_dir: Path, missing: list[str]) -> str:
    missing_list = ", ".join(missing)
    return "\n".join(
        [
            f"missing required stenosis geometry export(s) in {data_dir}: {missing_list}",
            "Generate the analytic, mesh-view, and Stokes trajectory CSVs first:",
            "  packages/stenotic-hemodynamics/bin/stenotic-hemodynamics export-assets --overwrite",
            "Then rerun:",
            "  pipenv run ops-render-stenosis-geometry-figures",
            "Use --data-dir PATH if the CSV exports already exist outside the default report asset directory.",
        ]
    )


def float_field(row: dict[str, str], key: str) -> float:
    return float(row[key])


def first_row_from_csv(path: Path) -> dict[str, str]:
    if not path.is_file():
        return {}
    rows = rows_from_csv(path)
    return rows[0] if rows else {}


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


def plot_tube(
    ax,
    data_dir: Path,
    severity: int,
    color: str,
    title: str,
    alpha: float = 0.93,
) -> None:
    z_grid, x_grid, y_grid, _ = surface_grid(data_dir / f"analytic_surface_sev{severity}.csv")
    ax.plot_surface(
        z_grid,
        x_grid,
        y_grid,
        color=color,
        linewidth=0,
        antialiased=True,
        shade=True,
        alpha=alpha,
        rasterized=True,
    )
    ax.plot([0, 6], [0, 0], [0, 0], color=COLORS["mathblue"], linewidth=0.8, alpha=0.6)
    setup_3d_axis(ax, title)


def read_particle_trajectories(
    data_dir: Path,
) -> dict[int, dict[int, list[dict[str, float]]]]:
    grouped: dict[int, dict[int, list[dict[str, float]]]] = defaultdict(lambda: defaultdict(list))
    for row in rows_from_csv(data_dir / "stokes_particle_trajectories.csv"):
        severity = int_severity(row["severity"])
        particle_id = int(row["particle_id"])
        grouped[severity][particle_id].append(
            {
                "sample_index": float_field(row, "sample_index"),
                "z_cm": float_field(row, "z_cm"),
                "x_cm": float_field(row, "x_cm"),
                "y_cm": float_field(row, "y_cm"),
                "r_over_r0": float_field(row, "r_over_r0"),
                "t_s": float_field(row, "t_s"),
                "ux_cm_s": float_field(row, "ux_cm_s"),
                "uy_cm_s": float_field(row, "uy_cm_s"),
                "uz_cm_s": float_field(row, "uz_cm_s"),
            }
        )

    for particles in grouped.values():
        for rows in particles.values():
            rows.sort(key=lambda item: item["sample_index"])
    return grouped


def require_trajectory_cases(trajectories: dict[int, dict[int, list[dict[str, float]]]]) -> None:
    missing = [severity for severity in MANUSCRIPT_TRAJECTORY_SEVERITIES if severity not in trajectories]
    if missing:
        raise ValueError(
            "missing Stokes trajectory exports for s_max cases: " + ", ".join(f"{severity}%" for severity in missing)
        )

    for severity in MANUSCRIPT_TRAJECTORY_SEVERITIES:
        particle_ids = sorted(trajectories[severity])
        if len(particle_ids) != TRAJECTORY_PARTICLE_COUNT:
            raise ValueError(
                f"s_max={severity}% trajectory export has "
                f"{len(particle_ids)} particles; expected {TRAJECTORY_PARTICLE_COUNT}"
            )
        for particle_id in particle_ids:
            if not trajectories[severity][particle_id]:
                raise ValueError(f"s_max={severity}% particle {particle_id} has no trajectory rows")


def render_particle_trajectories(data_dir: Path, output_dir: Path, formats: list[str]) -> list[Path]:
    trajectories = read_particle_trajectories(data_dir)
    require_trajectory_cases(trajectories)

    fig = plt.figure(figsize=(7.2, 5.8))
    for index, severity in enumerate(MANUSCRIPT_TRAJECTORY_SEVERITIES, start=1):
        ax = fig.add_subplot(3, 1, index, projection="3d")
        plot_tube(
            ax,
            data_dir,
            severity,
            COLORS["bloodredlight"],
            rf"$s_{{\max}} = {severity}\%$",
            alpha=0.48,
        )
        for color_index, particle_id in enumerate(sorted(trajectories[severity])):
            rows = trajectories[severity][particle_id]
            ax.plot(
                [row["z_cm"] for row in rows],
                [row["x_cm"] for row in rows],
                [row["y_cm"] for row in rows],
                color=TRAJECTORY_COLORS[color_index % len(TRAJECTORY_COLORS)],
                linewidth=1.35 if particle_id == 1 else 1.15,
                alpha=0.98,
            )
            ax.scatter(
                [rows[0]["z_cm"]],
                [rows[0]["x_cm"]],
                [rows[0]["y_cm"]],
                color=TRAJECTORY_COLORS[color_index % len(TRAJECTORY_COLORS)],
                s=5,
                depthshade=False,
            )

    fig.subplots_adjust(left=0.01, right=0.99, bottom=0.02, top=0.98, hspace=-0.08)
    return save_figure(fig, output_dir, "stenosis-particle-trajectories", formats)


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


def signed_radius(x_value: float, y_value: float) -> float:
    radius = float(np.hypot(x_value, y_value))
    sign_source = x_value if abs(x_value) >= abs(y_value) else y_value
    return -radius if sign_source < 0.0 else radius


def fem_meridional_segments(
    fem_rows: list[dict[str, str]],
    line_group: str,
) -> list[list[tuple[float, float]]]:
    segments: list[list[tuple[float, float]]] = []
    for row in fem_rows:
        if row["line_group"] != line_group:
            continue
        segments.append(
            [
                (
                    float_field(row, "z1_cm"),
                    signed_radius(float_field(row, "x1_cm"), float_field(row, "y1_cm")),
                ),
                (
                    float_field(row, "z2_cm"),
                    signed_radius(float_field(row, "x2_cm"), float_field(row, "y2_cm")),
                ),
            ]
        )
    return segments


def add_stenosis_profile(ax, z_profile: np.ndarray, r_profile: np.ndarray, fill_alpha: float = 0.30) -> None:
    ax.fill_between(
        z_profile,
        -r_profile,
        r_profile,
        color=COLORS["bloodredlight"],
        alpha=fill_alpha,
        linewidth=0,
    )
    ax.plot(z_profile, r_profile, color=COLORS["bloodred"], linewidth=1.35, label="$r=\\pm R_0(z)$")
    ax.plot(z_profile, -r_profile, color=COLORS["bloodred"], linewidth=1.35)


def add_shared_mesh_axis_style(ax, title: str) -> None:
    ax.set_title(title, color=COLORS["mathblue"], fontsize=10, pad=5)
    ax.set_xlabel("z (cm)", fontsize=8)
    ax.set_ylabel("signed radius r (cm)", fontsize=8)
    ax.set_xlim(0.0, 6.0)
    ax.set_ylim(-0.215, 0.215)
    ax.set_xticks([0, 2, 4, 6])
    ax.set_yticks([-0.2, 0.0, 0.2])
    ax.tick_params(labelsize=7, colors=COLORS["mathblue"])
    ax.grid(True, color="#E3E3E3", linewidth=0.45)
    ax.set_box_aspect(0.26)


def add_quadrature_inset(ax, radius: float, mesh_nr: int, mesh_ntheta: int) -> None:
    inset = ax.inset_axes([0.745, 0.17, 0.21, 0.68])
    inset.add_patch(
        Circle(
            (0.0, 0.0),
            radius,
            facecolor=COLORS["bloodredlight"],
            edgecolor=COLORS["bloodred"],
            linewidth=0.9,
            alpha=0.42,
        )
    )
    for ring in range(1, mesh_nr + 1):
        inset.add_patch(
            Circle(
                (0.0, 0.0),
                radius * ring / mesh_nr,
                facecolor="none",
                edgecolor=COLORS["wallgray"],
                linewidth=0.22,
                alpha=0.32,
            )
        )
    spoke_step = max(1, mesh_ntheta // 8)
    for index in range(0, mesh_ntheta, spoke_step):
        theta = 2.0 * np.pi * index / mesh_ntheta
        inset.plot(
            [0.0, radius * np.cos(theta)],
            [0.0, radius * np.sin(theta)],
            color=COLORS["mathblue"],
            linewidth=0.26,
            alpha=0.45,
        )

    theta1 = np.pi / 7.0
    theta2 = theta1 + 2.0 * np.pi / mesh_ntheta
    center = np.array([0.0, 0.0])
    p1 = radius * np.array([np.cos(theta1), np.sin(theta1)])
    p2 = radius * np.array([np.cos(theta2), np.sin(theta2)])
    inset.add_patch(
        Polygon(
            [center, p1, p2],
            closed=True,
            facecolor=COLORS["trajectory_gold"],
            edgecolor=COLORS["trajectory_gold"],
            linewidth=0.65,
            alpha=0.35,
        )
    )
    quadrature_points = np.array(
        [
            (2.0 / 3.0) * center + (1.0 / 6.0) * p1 + (1.0 / 6.0) * p2,
            (1.0 / 6.0) * center + (2.0 / 3.0) * p1 + (1.0 / 6.0) * p2,
            (1.0 / 6.0) * center + (1.0 / 6.0) * p1 + (2.0 / 3.0) * p2,
        ]
    )
    inset.scatter(
        quadrature_points[:, 0],
        quadrature_points[:, 1],
        s=8,
        color=COLORS["trajectory_gold"],
        edgecolors=COLORS["mathblue"],
        linewidths=0.25,
        zorder=4,
    )
    inset.set_title("$S_j,\\ \\mathcal{Q}_j$", fontsize=7, color=COLORS["mathblue"], pad=1)
    inset.text(
        0.0,
        -1.05 * radius,
        "3-pt quadrature",
        ha="center",
        va="top",
        fontsize=5.6,
        color=COLORS["mathblue"],
    )
    inset.set_aspect("equal", adjustable="box")
    inset.set_xlim(-1.2 * radius, 1.2 * radius)
    inset.set_ylim(-1.24 * radius, 1.2 * radius)
    inset.set_xticks([])
    inset.set_yticks([])
    for spine in inset.spines.values():
        spine.set_color("#D8D8D8")
        spine.set_linewidth(0.45)


def render_mesh_overview(data_dir: Path, output_dir: Path, formats: list[str]) -> list[Path]:
    fem_rows = rows_from_csv(data_dir / "fem_mesh_view_sev50.csv")
    fvm_rows = sorted(
        rows_from_csv(data_dir / "fvm_mesh_view_sev50.csv"),
        key=lambda row: int(row["cell_index"]),
    )
    if not fem_rows:
        raise ValueError("FEM mesh view CSV has no rows")
    if not fvm_rows:
        raise ValueError("FVM mesh view CSV has no rows")

    manifest = first_row_from_csv(data_dir / "mesh_view_manifest.csv")
    mesh_nz = int(manifest.get("fem_mesh_nz", 64))
    mesh_nr = int(manifest.get("fem_mesh_nr", 6))
    mesh_ntheta = int(manifest.get("fem_mesh_ntheta", 32))
    fvm_nx = int(fvm_rows[0]["nx"])
    fvm_dx = float_field(fvm_rows[0], "dx_cm")
    z_left = np.array([float_field(row, "z_left_cm") for row in fvm_rows])
    z_center = np.array([float_field(row, "z_center_cm") for row in fvm_rows])
    z_right = np.array([float_field(row, "z_right_cm") for row in fvm_rows])
    r_center = np.array([float_field(row, "r_center_cm") for row in fvm_rows])
    z_profile = np.concatenate([z_left[:1], z_center, z_right[-1:]])
    r_profile = np.concatenate(
        [
            np.array([float_field(fvm_rows[0], "r_left_cm")]),
            r_center,
            np.array([float_field(fvm_rows[-1], "r_right_cm")]),
        ]
    )
    throat_index = int(np.argmin(r_profile))
    throat_z = z_profile[throat_index]
    throat_radius = r_profile[throat_index]

    fig = plt.figure(figsize=(7.4, 4.95))
    grid = fig.add_gridspec(
        2,
        1,
        height_ratios=[1.0, 1.0],
        left=0.075,
        right=0.985,
        bottom=0.09,
        top=0.95,
        hspace=0.44,
    )
    ax_fem = fig.add_subplot(grid[0, 0])
    ax_fvm = fig.add_subplot(grid[1, 0])

    add_stenosis_profile(ax_fem, z_profile, r_profile, fill_alpha=0.22)
    ax_fem.add_collection(
        LineCollection(
            fem_meridional_segments(fem_rows, "cut-axial"),
            colors=COLORS["mathblue"],
            linewidths=0.34,
            alpha=0.72,
        )
    )
    ax_fem.add_collection(
        LineCollection(
            fem_meridional_segments(fem_rows, "cut-radial"),
            colors=COLORS["bloodred"],
            linewidths=0.62,
            alpha=0.78,
        )
    )
    ax_fem.axvline(throat_z, color=COLORS["accent_teal"], linewidth=0.95, linestyle="--", alpha=0.88)
    ax_fem.text(
        throat_z + 0.06,
        0.176,
        "$S_j$ at $z^\\star$",
        color=COLORS["accent_teal"],
        fontsize=7,
        ha="left",
        va="center",
    )
    ax_fem.text(
        0.015,
        0.95,
        f"$\\mathcal{{T}}_h$: $N_z={mesh_nz}$, $N_r={mesh_nr}$, $N_\\theta={mesh_ntheta}$",
        transform=ax_fem.transAxes,
        ha="left",
        va="top",
        fontsize=7,
        color=COLORS["mathblue"],
        bbox={"facecolor": "white", "edgecolor": "#D8D8D8", "linewidth": 0.4, "alpha": 0.86, "pad": 2.5},
    )
    add_shared_mesh_axis_style(ax_fem, "(a) FEM meridional cut and plane quadrature")
    add_quadrature_inset(ax_fem, throat_radius, mesh_nr, mesh_ntheta)

    add_stenosis_profile(ax_fvm, z_profile, r_profile, fill_alpha=0.38)
    interfaces = np.concatenate([z_left, z_right[-1:]])
    radii = np.interp(interfaces, z_profile, r_profile)
    ax_fvm.vlines(
        interfaces,
        -radii,
        radii,
        color=COLORS["mathblue"],
        linewidth=0.18,
        alpha=0.28,
    )
    emphasis_stride = max(1, len(interfaces) // 20)
    ax_fvm.vlines(
        interfaces[::emphasis_stride],
        -radii[::emphasis_stride],
        radii[::emphasis_stride],
        color=COLORS["mathblue"],
        linewidth=0.42,
        alpha=0.75,
    )
    example_cell = int(np.argmin(np.abs(z_center - throat_z)))
    ax_fvm.axvspan(
        z_left[example_cell],
        z_right[example_cell],
        color=COLORS["accent_teal_lite"],
        alpha=0.62,
        linewidth=0,
    )
    ax_fvm.axvline(throat_z, color=COLORS["accent_teal"], linewidth=0.95, linestyle="--", alpha=0.88)
    center_stride = max(1, len(z_center) // 20)
    ax_fvm.scatter(
        z_center[::center_stride],
        np.zeros_like(z_center[::center_stride]),
        s=8,
        color=COLORS["mathblue"],
        alpha=0.90,
        zorder=4,
    )
    ax_fvm.text(
        z_center[example_cell] + 0.045,
        -0.032,
        "$z_i$",
        color=COLORS["mathblue"],
        fontsize=7,
        ha="left",
        va="center",
    )
    ax_fvm.text(
        z_left[example_cell] - 0.015,
        0.168,
        "$z_{i-1/2}$",
        color=COLORS["accent_teal"],
        fontsize=6.5,
        ha="right",
        va="center",
    )
    ax_fvm.text(
        z_right[example_cell] + 0.015,
        0.168,
        "$z_{i+1/2}$",
        color=COLORS["accent_teal"],
        fontsize=6.5,
        ha="left",
        va="center",
    )
    ax_fvm.text(
        0.015,
        0.95,
        f"$I_i=[z_{{i-1/2}},z_{{i+1/2}}]$, $N={fvm_nx}$, $\\Delta z={fvm_dx:.3f}$ cm",
        transform=ax_fvm.transAxes,
        ha="left",
        va="top",
        fontsize=7,
        color=COLORS["mathblue"],
        bbox={"facecolor": "white", "edgecolor": "#D8D8D8", "linewidth": 0.4, "alpha": 0.86, "pad": 2.5},
    )
    add_shared_mesh_axis_style(ax_fvm, "(b) FVM cells and reference-radius sampling")

    return save_figure(fig, output_dir, "stenosis-fem-fvm-meshes", formats)


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


def render_resolved_envelopes(data_dir: Path, output_dir: Path, formats: list[str]) -> list[Path]:
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


def read_resolved_velocity_nodes(
    data_dir: Path,
) -> dict[tuple[str, int], list[dict[str, float | str]]]:
    cases: dict[tuple[str, int], list[dict[str, float | str]]] = {}
    for csv_path in sorted(data_dir.glob("resolved_velocity_nodes_case*_sev*.csv")):
        rows = rows_from_csv(csv_path)
        if not rows:
            continue
        case_label = rows[0]["case_label"]
        severity = int_severity(rows[0]["severity"])
        cases[(case_label, severity)] = [
            {
                "case_label": row["case_label"],
                "severity": int_severity(row["severity"]),
                "node_id": int(row["node_id"]),
                "z_cm": float_field(row, "z_cm"),
                "x_cm": float_field(row, "x_cm"),
                "y_cm": float_field(row, "y_cm"),
                "ux_cm_s": float_field(row, "ux_cm_s"),
                "uy_cm_s": float_field(row, "uy_cm_s"),
                "uz_cm_s": float_field(row, "uz_cm_s"),
                "speed_cm_s": float_field(row, "speed_cm_s"),
                "xdmf_time_s": float_field(row, "xdmf_time_s"),
            }
            for row in rows
        ]
    return cases


def resolved_velocity_arrays(rows: list[dict[str, float | str]]) -> dict[str, np.ndarray]:
    return {
        "z": np.array([row["z_cm"] for row in rows], dtype=float),
        "x": np.array([row["x_cm"] for row in rows], dtype=float),
        "y": np.array([row["y_cm"] for row in rows], dtype=float),
        "ux": np.array([row["ux_cm_s"] for row in rows], dtype=float),
        "uy": np.array([row["uy_cm_s"] for row in rows], dtype=float),
        "uz": np.array([row["uz_cm_s"] for row in rows], dtype=float),
        "speed": np.array([row["speed_cm_s"] for row in rows], dtype=float),
    }


def plot_envelope_frame(ax, data_dir: Path, case_label: str, severity: int) -> None:
    envelope_path = data_dir / f"resolved_envelope_case{case_label}_sev{severity}.csv"
    if not envelope_path.is_file():
        return
    z_grid, x_grid, y_grid, _ = surface_grid(envelope_path)
    ax.plot_surface(
        z_grid,
        x_grid,
        y_grid,
        color=COLORS["accent_teal_lite"],
        linewidth=0,
        antialiased=True,
        shade=True,
        alpha=0.08,
        rasterized=True,
    )


def render_resolved_velocity_field(data_dir: Path, output_dir: Path, formats: list[str]) -> list[Path]:
    cases = read_resolved_velocity_nodes(data_dir)
    missing = [case for case in RESOLVED_FLOW_CASES if case not in cases]
    if missing:
        print(
            "no complete resolved velocity node CSV set found; skipped resolved flow render: "
            + ", ".join(f"case {case_label}" for case_label, _ in missing)
        )
        return []

    arrays_by_case = {case: resolved_velocity_arrays(cases[case]) for case in RESOLVED_FLOW_CASES}
    uz_values = np.concatenate([arrays["uz"] for arrays in arrays_by_case.values()])
    color_norm = plt.Normalize(float(np.min(uz_values)), float(np.max(uz_values)))

    fig = plt.figure(figsize=(7.4, 3.0))
    grid = fig.add_gridspec(
        2,
        2,
        height_ratios=[1.0, 0.08],
        left=0.025,
        right=0.985,
        bottom=0.13,
        top=0.92,
        wspace=0.02,
        hspace=0.02,
    )
    axes = []
    scatter = None
    for index, (case_label, severity) in enumerate(RESOLVED_FLOW_CASES, start=1):
        ax = fig.add_subplot(grid[0, index - 1], projection="3d")
        axes.append(ax)
        arrays = arrays_by_case[(case_label, severity)]
        display_mask = arrays["x"] >= -0.002
        plot_envelope_frame(ax, data_dir, case_label, severity)
        scatter = ax.scatter(
            arrays["z"][display_mask],
            arrays["x"][display_mask],
            arrays["y"][display_mask],
            c=arrays["uz"][display_mask],
            cmap="viridis",
            norm=color_norm,
            s=3.0,
            alpha=0.92,
            depthshade=False,
            rasterized=True,
        )

        visible_indices = np.flatnonzero(display_mask)
        order = visible_indices[np.argsort(arrays["z"][visible_indices])]
        step = max(1, len(order) // 130)
        arrow_index = order[::step]
        ax.quiver(
            arrays["z"][arrow_index],
            arrays["x"][arrow_index],
            arrays["y"][arrow_index],
            arrays["uz"][arrow_index],
            arrays["ux"][arrow_index],
            arrays["uy"][arrow_index],
            length=0.13,
            normalize=True,
            color=COLORS["mathblue"],
            linewidth=0.35,
            alpha=0.28,
        )
        setup_3d_axis(
            ax,
            f"({chr(96 + index)}) C{severity}, {severity}% velocity nodes",
        )
        try:
            ax.set_box_aspect((6.0, 0.68, 0.68), zoom=1.95)
        except TypeError:
            ax.set_box_aspect((6.0, 0.68, 0.68))

    if scatter is not None:
        cax = fig.add_subplot(grid[1, :])
        cbar = fig.colorbar(
            scatter,
            cax=cax,
            orientation="horizontal",
        )
        cbar.set_label("$u_z$ (cm/s)", fontsize=8)
        cbar.ax.tick_params(labelsize=7)
    return save_figure(fig, output_dir, "resolved-3d-flow-field", formats)


def main(argv: list[str] | None = None) -> int:
    args = parse_args(argv)
    data_dir = args.data_dir
    output_dir = args.output_dir
    formats = [fmt.lower().lstrip(".") for fmt in args.formats]
    missing = missing_required_exports(data_dir)
    if missing:
        print(format_missing_exports_message(data_dir, missing), file=sys.stderr)
        return 2

    written: list[Path] = []
    written.extend(render_overview(data_dir, output_dir, formats))
    written.extend(render_mesh_overview(data_dir, output_dir, formats))
    written.extend(render_particle_trajectories(data_dir, output_dir, formats))
    written.extend(render_slices(data_dir, output_dir, formats))
    written.extend(render_severity_gallery(data_dir, output_dir, formats))
    written.extend(render_resolved_velocity_field(data_dir, output_dir, formats))

    print(f"wrote {len(written)} rendered files")
    for path in written:
        print(path)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
