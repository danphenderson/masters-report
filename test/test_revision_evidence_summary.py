import csv
import subprocess
import sys
from pathlib import Path


def read_csv(path: Path) -> list[dict[str, str]]:
    with path.open(encoding="utf-8", newline="") as handle:
        return list(csv.DictReader(handle))


def write_xdmf(path: Path, time: str, attribute_name: str) -> None:
    path.write_text(
        f"""<?xml version="1.0" ?>
<Xdmf Version="3.0">
  <Domain>
    <Grid Name="mesh" GridType="Uniform">
      <Time Value="{time}" />
      <Attribute Name="{attribute_name}" AttributeType="Vector" Center="Node">
        <DataItem Dimensions="1 3" Format="HDF">fixture.h5:/values</DataItem>
      </Attribute>
    </Grid>
  </Domain>
</Xdmf>
""",
        encoding="utf-8",
    )


def test_revision_evidence_summarizer_writes_gate_and_wall_status(tmp_path: Path) -> None:
    repo = Path(__file__).resolve().parents[1]
    rest_csv = tmp_path / "rest_state_drift.csv"
    rest_csv.write_text(
        "severity,nx,requested_time_s,max_abs_q,max_abs_area_drift,solver_volume_defect,boundary_flux_integral,conservation_residual,status\n"
        "23.0,100,0.1,0.2,0.01,0.001,-0.001,0.0,ok\n"
        "23.0,100,1.0,0.4,0.02,0.002,-0.002,0.0,ok\n",
        encoding="utf-8",
    )

    comparison_root = tmp_path / "comparison"
    comparison_root.mkdir()
    (comparison_root / "comparison_summary.csv").write_text(
        "case_label,severity,operator,model,nx,dt_s,initial_condition,backend,run_status,"
        "target_time_s,time_atol_s,xdmf_time_s,one_d_completed_time_s,xdmf_target_time_error_s,"
        "mean_abs_discrepancy_cm_s,l2_velocity_discrepancy_cm_s,max_abs_discrepancy_cm_s,"
        "mean_flow_abs_discrepancy_cm3_s\n"
        "77,23.0,CrossSectionQuadratureOperator,canic-extended-1d,400,1e-5,geometry-rest,native,ok,"
        "0.9995,0.000001,0.9995,0.9995,0.0,0.2,0.3,0.4,0.05\n",
        encoding="utf-8",
    )

    case_dir = tmp_path / "data" / "77"
    case_dir.mkdir(parents=True)
    write_xdmf(case_dir / "velocity.xdmf", "0.9995", "velocity")
    write_xdmf(case_dir / "pressure.xdmf", "0.9995", "pressure")
    write_xdmf(case_dir / "displace.xdmf", "0.9995", "f_51")

    output_dir = tmp_path / "summary"
    result = subprocess.run(
        [
            sys.executable,
            "scripts/summarize_revision_evidence.py",
            "--repo",
            str(repo),
            "--output-dir",
            str(output_dir),
            "--rest-csv",
            str(rest_csv),
            "--comparison-root",
            str(comparison_root),
            "--data-root",
            str(tmp_path / "data"),
        ],
        cwd=repo,
        text=True,
        capture_output=True,
        check=False,
    )

    assert result.returncode == 0, result.stdout + result.stderr
    rest_rows = read_csv(output_dir / "rest_gate_summary.csv")
    assert rest_rows[0]["evidence_status"] == "ok-through-t1"
    assert rest_rows[0]["peak_requested_time_s"] == "1.0"

    comparison_rows = read_csv(output_dir / "comparison_gate_summary.csv")
    assert comparison_rows[0]["evidence_status"] == "schema-ok"
    assert comparison_rows[0]["model"] == "canic-extended-1d"
    assert comparison_rows[0]["target_time_s"] == "0.9995"

    wall_rows = read_csv(output_dir / "resolved3d_wall_status.csv")
    assert wall_rows[0]["wall_status"] == "single-displacement-snapshot"
    assert wall_rows[0]["displacement_times"] == "0.9995"
    assert wall_rows[0]["displacement_attributes"] == "f_51"
    assert (output_dir / "manifest.json").is_file()
