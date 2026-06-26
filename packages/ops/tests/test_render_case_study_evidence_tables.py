import subprocess
import sys
from pathlib import Path

from ops.render_case_study_evidence_tables import render_tables


REST_HEADER = (
    "severity,nx,dx,elapsed_time_s,requested_time_s,terminal_time_error_s,max_abs_q,max_abs_q_z,"
    "max_abs_area_drift,solver_volume_defect,physical_volume_defect,requested_q_in,applied_q_in,"
    "inlet_area_flux,outlet_area_flux,boundary_flux_integral,conservation_residual,inlet_cell_q,"
    "outlet_cell_q,mean_q,rms_q,lh_area_interior_max_abs,lh_area_boundary_max_abs,"
    "lh_flow_interior_max_abs,lh_flow_boundary_max_abs,realized_cfl_max,lambda_minus_min,"
    "lambda_plus_max,subcritical_margin_min,positivity_projection_count,positivity_correction_total,"
    "status,error_message\n"
)
RESIDUAL_HEADER = (
    "severity,nx,dx,mass_flux_rusanov_max_abs,mass_flux_rusanov_z_cm,"
    "elastic_flux_difference_max_abs,elastic_flux_difference_z_cm,wall_geometry_source_max_abs,"
    "wall_geometry_source_z_cm,total_flow_residual_max_abs,total_flow_residual_z_cm,"
    "total_area_residual_max_abs,status,error_message\n"
)
COMPARE_HEADER = (
    "case_label,severity,operator,model,nx,dt_s,initial_condition,backend,spatial_method,run_status,coordinate_mode,"
    "section_count,profile_count,mean_abs_discrepancy_cm_s,l2_velocity_discrepancy_cm_s,"
    "max_abs_discrepancy_cm_s,mean_relative_discrepancy,relative_l1_velocity_discrepancy,"
    "max_relative_discrepancy,relative_l2_velocity_discrepancy,mean_flow_abs_discrepancy_cm3_s,"
    "flow_l2_discrepancy_cm3_s,max_flow_abs_discrepancy_cm3_s,profile_mean_abs_discrepancy_cm_s,"
    "profile_l2_discrepancy_cm_s,profile_max_abs_discrepancy_cm_s,min_intersection_count,"
    "min_section_nodes,area_valid_count,alpha_eff_min,alpha_eff_max,characteristic_radicand_min,"
    "lambda_minus_min,lambda_minus_max,lambda_plus_min,lambda_plus_max,subcritical_margin_min,"
    "accepted_dt_min,accepted_dt_max,realized_cfl_max,min_solver_area,min_physical_area_cm2,"
    "solver_volume_defect,physical_volume_defect_cm3,positivity_projection_count,"
    "positivity_correction_total,final_inlet_area_flux,final_outlet_area_flux,final_area_flux_balance,"
    "final_rhs_area_max_abs,final_rhs_flow_max_abs,xdmf_time_s,time_offset_s,target_time_s,time_atol_s,"
    "one_d_completed_time_s,one_d_terminal_time_error_s,xdmf_target_time_error_s,cross_model_time_offset_s\n"
)


def rest_row(
    severity: str,
    requested_time: str,
    max_q: str,
    rms_q: str,
    status: str = "ok",
    message: str = "",
) -> str:
    values = [
        severity,
        "400",
        "0.015",
        requested_time if status == "ok" else "NaN",
        requested_time,
        "0.0" if status == "ok" else "NaN",
        max_q,
        "2.0",
        "0.0",
        "0.0",
        "0.0",
        "0.0",
        "0.0",
        "0.0",
        "0.0",
        "0.0",
        "0.0",
        "0.0",
        "0.0",
        "0.0",
        rms_q,
        "0.0",
        "0.0",
        "0.0",
        "0.0",
        "0.45",
        "-1.0",
        "1.0",
        "1.0",
        "0",
        "0.0",
        status,
        message,
    ]
    return ",".join(values) + "\n"


def write_rest_method(root: Path, method: str, *, ok: bool = True, residual_ok: bool = True) -> None:
    method_dir = root / f"rest-{method}"
    method_dir.mkdir(parents=True)
    if ok:
        (method_dir / "rest_state_drift.csv").write_text(
            REST_HEADER
            + rest_row("22.555555555555554", "0.0", "0.0", "0.0")
            + rest_row("22.555555555555554", "0.001", "0.12", "0.03")
            + rest_row("22.555555555555554", "0.1", "0.10", "0.02"),
            encoding="utf-8",
        )
        if residual_ok:
            residual_row = "22.555555555555554,400,0.015,1.0,2.0,3.0,4.0,5.0,6.0,8.0,2.1,1.0,ok,\n"
        else:
            residual_row = (
                "22.555555555555554,400,0.015,NaN,NaN,NaN,NaN,NaN,NaN,NaN,NaN,NaN,error,"
                "ArgumentError: fv-lax-wendroff requires a positive native timestep\n"
            )
        (method_dir / "rest_state_residual_components.csv").write_text(RESIDUAL_HEADER + residual_row, encoding="utf-8")
    else:
        message = "ArgumentError: fv-lax-wendroff requires a positive native timestep"
        (method_dir / "rest_state_drift.csv").write_text(
            REST_HEADER
            + rest_row("22.555555555555554", "0.0", "NaN", "NaN", status="error", message=message)
            + rest_row("22.555555555555554", "0.1", "NaN", "NaN", status="error", message=message),
            encoding="utf-8",
        )
        (method_dir / "rest_state_residual_components.csv").write_text(
            RESIDUAL_HEADER
            + "22.555555555555554,400,0.015,NaN,NaN,NaN,NaN,NaN,NaN,NaN,NaN,NaN,error,"
            + message
            + "\n",
            encoding="utf-8",
        )


def compare_row(case_label: str, severity: str, dt: str, mean: str, rms: str, rel: str) -> str:
    values = [
        case_label,
        severity,
        "CrossSectionQuadratureOperator",
        "canic-extended-1d",
        "400",
        dt,
        "geometry-rest",
        "native",
        "fv-wb-geometry-rest-muscl-minmod",
        "ok",
        "reference",
        "200",
        "0",
        mean,
        rms,
        "1.25",
        "0.0",
        "0.0",
        "0.0",
        rel,
        "0.02",
        "0.03",
        "0.04",
        "0.0",
        "0.0",
        "0.0",
        "10",
        "0",
        "200",
        "1.3",
        "1.33",
        "1.0",
        "-1.0",
        "-0.5",
        "0.5",
        "1.0",
        "0.5",
        "5e-6",
        dt,
        "0.4",
        "0.1",
        "0.01",
        "0.0",
        "0.0",
        "0",
        "0.0",
        "0.0",
        "0.0",
        "0.0",
        "0.0",
        "0.0",
        "0.9995",
        "0.0",
        "0.9995",
        "1e-6",
        "0.9995",
        "0.0",
        "0.0",
        "0.0",
    ]
    return ",".join(values) + "\n"


def write_comparison(root: Path, dt_dir: str, dt: str) -> None:
    compare_dir = root / dt_dir
    compare_dir.mkdir(parents=True)
    (compare_dir / "comparison_summary.csv").write_text(
        COMPARE_HEADER
        + compare_row("77", "22.555555555555554", dt, "0.46", "0.57", "0.023")
        + compare_row("60", "40.0", dt, "0.96", "1.87", "0.068"),
        encoding="utf-8",
    )


def test_render_case_study_evidence_tables(tmp_path: Path) -> None:
    rest_root = tmp_path / "scratch"
    write_rest_method(rest_root, "fv-muscl")
    write_rest_method(rest_root, "fv-weno3", residual_ok=False)
    write_rest_method(rest_root, "fv-lax-wendroff", ok=False)
    write_comparison(rest_root, "compare-dt-5e-6", "5e-6")
    write_comparison(rest_root, "compare-dt-2e-5", "2e-5")

    output = render_tables(
        rest_root,
        rest_root,
        tmp_path / "data" / "verification",
        tmp_path / "tables" / "verification",
        tmp_path / "data" / "stenosis-comparison",
        tmp_path / "tables" / "stenosis-comparison",
    )

    assert output == [
        tmp_path / "data" / "verification" / "rest_method_sensitivity.csv",
        tmp_path / "tables" / "verification" / "rest_method_sensitivity.tex",
        tmp_path / "data" / "stenosis-comparison" / "comparison_time_step_sensitivity.csv",
        tmp_path / "tables" / "stenosis-comparison" / "comparison_time_step_sensitivity.tex",
    ]
    rest_table = output[1].read_text(encoding="utf-8")
    assert "FV MUSCL & C23 (22.56\\%) & 8 &" in rest_table
    assert "FV WENO3 & C23 (22.56\\%) & -- & 0.001 & 0.12 & 0.1 & residual skipped" in rest_table
    assert "FV Lax--Wendroff & C23 (22.56\\%) & -- & -- & -- & -- & not available" in rest_table
    rest_csv = output[0].read_text(encoding="utf-8")
    assert "residual_status,residual_error_message,source_csv" in rest_csv
    assert "22.555555555555554,C23," in rest_csv
    assert "residual error,ArgumentError: fv-lax-wendroff requires a positive native timestep,error" in rest_csv

    comparison_csv = output[2].read_text(encoding="utf-8")
    assert "C23 (22.56%)" in comparison_csv
    comparison_table = output[3].read_text(encoding="utf-8")
    assert "C23 (22.56\\%) & 5.000e-06" in comparison_table
    assert "C40 & 2.000e-05" in comparison_table


def test_render_case_study_evidence_tables_reports_missing_inputs(tmp_path: Path) -> None:
    result = subprocess.run(
        [
            sys.executable,
            "-m",
            "ops.render_case_study_evidence_tables",
            "--rest-root",
            str(tmp_path / "missing"),
            "--comparison-root",
            str(tmp_path / "missing"),
            "--verification-data-dir",
            str(tmp_path / "data"),
            "--verification-table-dir",
            str(tmp_path / "tables"),
        ],
        check=False,
        text=True,
        capture_output=True,
    )

    assert result.returncode == 1
    assert "no rest-state method CSVs found" in result.stdout
