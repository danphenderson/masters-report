import subprocess
import sys
from pathlib import Path


def write_ph_fixture(path: Path) -> None:
    path.write_text(
        "sweep,degree,nx,dx,dofs,dt,tfinal,completed_time,steps,"
        "area_l1_error,area_l2_error,area_linf_error,area_l2_observed_order,area_log10_l2_error,"
        "area_l2_reduction,area_p_sweep_status,flow_l1_error,flow_l2_error,flow_linf_error,"
        "flow_l2_observed_order,flow_log10_l2_error,flow_l2_reduction,flow_p_sweep_status,"
        "p_sweep_status,dg_limiter_policy,status,error_message\n"
        "h_refinement,2,20,0.3,120,5e-7,0.0002,0.0002,10,"
        "1e-4,2e-4,3e-4,2.0,-3.699,,not_applicable,2e-3,4e-3,5e-3,1.8,-2.398,,"
        "not_applicable,not_applicable,disabled,ok,\n"
        "h_refinement,2,40,0.15,240,5e-7,0.0002,0.0002,20,"
        "2e-5,5e-5,6e-5,,-4.301,,not_applicable,5e-4,1e-3,2e-3,,-3.0,,"
        "not_applicable,not_applicable,disabled,ok,\n"
        "p_refinement,0,40,0.15,80,5e-7,0.0002,0.0002,20,"
        "1e-3,2e-3,3e-3,,-2.699,,baseline,2e-2,4e-2,5e-2,,-1.398,,"
        "baseline,baseline,disabled,ok,\n"
        "p_refinement,2,40,0.15,240,5e-7,0.0002,0.0002,20,"
        "1e-4,2e-4,3e-4,,-3.699,10,improved,2e-3,4e-3,5e-3,,-2.398,10,"
        "improved,improved,disabled,ok,\n"
        "p_refinement,3,40,0.15,320,5e-7,0.0002,0.0002,20,"
        "1.5e-4,3e-4,4e-4,,-3.523,0.67,regressed,2.1e-3,4.2e-3,5.1e-3,,-2.377,0.95,"
        "plateau,regressed,modal_limiter,ok,\n"
        "p_refinement,4,40,0.15,400,5e-7,0.0002,0.0002,20,"
        "4.9e-5,9.9e-5,1.9e-4,,-4.0,1.02,plateau,9.9e-4,1.98e-3,2.9e-3,,-2.703,1.01,"
        "plateau,plateau,disabled,ok,\n"
    )


def test_ph_renderer_generates_figure_and_table(tmp_path: Path) -> None:
    csv_path = tmp_path / "p_h_refinement_demo.csv"
    output_dir = tmp_path / "figures"
    table_dir = tmp_path / "tables"
    write_ph_fixture(csv_path)

    result = subprocess.run(
        [
            sys.executable,
            "-m",
            "ops.render_ph_refinement_demo",
            "--csv",
            str(csv_path),
            "--output-dir",
            str(output_dir),
            "--table-dir",
            str(table_dir),
            "--formats",
            "png",
        ],
        check=False,
        text=True,
        capture_output=True,
    )

    assert result.returncode == 0, result.stderr
    figure = output_dir / "p-h-refinement-demo.png"
    assert figure.exists()
    assert figure.stat().st_size > 0
    table = table_dir / "p_h_refinement_demo.tex"
    assert table.exists()
    table_text = table.read_text()
    assert "Manufactured-solution p- and h-refinement diagnostic" in table_text
    assert "smooth-MMS verification evidence" in table_text
    assert "policy" in table_text
    assert "disabled" in table_text
    assert "modal\\_limiter" in table_text
    assert "p-status" in table_text
    assert "baseline" in table_text
    assert "improved" in table_text
    assert "regressed" in table_text
    assert "plateau" in table_text


def test_ph_renderer_defaults_to_pdf_only_for_tracked_report_assets(tmp_path: Path) -> None:
    csv_path = tmp_path / "p_h_refinement_demo.csv"
    output_dir = tmp_path / "figures"
    table_dir = tmp_path / "tables"
    write_ph_fixture(csv_path)

    result = subprocess.run(
        [
            sys.executable,
            "-m",
            "ops.render_ph_refinement_demo",
            "--csv",
            str(csv_path),
            "--output-dir",
            str(output_dir),
            "--table-dir",
            str(table_dir),
        ],
        check=False,
        text=True,
        capture_output=True,
    )

    assert result.returncode == 0, result.stderr
    assert (output_dir / "p-h-refinement-demo.pdf").exists()
    assert not (output_dir / "p-h-refinement-demo.png").exists()
    assert (table_dir / "p_h_refinement_demo.tex").exists()
