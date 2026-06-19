import subprocess
import sys
from pathlib import Path


def write_fixture_csvs(root: Path) -> None:
    root.mkdir()
    (root / "case_results.csv").write_text("stage,case_id,status,elapsed_s\n" "descriptor_health,smoke,ok,0.01\n")
    (root / "refinement.csv").write_text(
        "study,case_id,method,degree,nx,dofs,metric,error,observed_order,status,elapsed_s,error_message\n"
        "h_refinement,h-fv-nx10,fv-first-order,,10,10,area_l2,0.1,1.0,ok,0.01,\n"
        "h_refinement,h-fv-nx20,fv-first-order,,20,20,flow_l2,0.05,1.0,ok,0.01,\n"
    )
    (root / "backend_parity.csv").write_text(
        "case_id,method,degree,nx,tfinal,algorithm,native_elapsed_s,sciml_elapsed_s,area_l2,flow_l2,velocity_l2,pressure_l2,status,error_message\n"
        "backend,fv-muscl,,12,0.0001,tsit5,0.01,0.02,1e-8,1e-8,1e-8,1e-8,ok,\n"
    )
    (root / "stokes_ic.csv").write_text(
        "case_id,severity,pressure_drop_pa,mesh_nz,mesh_nr,mesh_ntheta,projection_nr,projection_ntheta,velocity_dofs,pressure_dofs,pressure_drop_relative_error,projection_hash,mean_flow,status,elapsed_s,error_message\n"
        "stokes,0,40,8,2,8,2,8,10,4,1e-8,abc,0.1,ok,0.01,\n"
    )
    (root / "rheology_profile.csv").write_text(
        "case_id,severity,rheology,profile,nx,tfinal,elapsed_s,steps,min_area,max_abs_u,pressure_min,pressure_max,status,error_message\n"
        "rheo,40,newtonian,parabolic,16,0.0001,0.01,1,0.1,10,0,1,ok,\n"
    )
    (root / "boundary_openbf.csv").write_text(
        "case_id,inlet,outlet,reflection_coefficient,nx,tfinal,elapsed_s,steps,min_area,max_abs_u,pressure_min,pressure_max,status,error_message\n"
        "boundary,flow-waveform,reflection-coefficient,0.25,16,0.0001,0.01,1,0.1,10,0,1,ok,\n"
    )
    (root / "resolved3d.csv").write_text(
        "case_id,case_label,severity,profile,section_count,mean_abs_error_cm_s,max_abs_error_cm_s,mean_relative_error,max_relative_error,status,elapsed_s,error_message\n"
        "resolved,77,23,parabolic,20,0.5,1.0,0.1,0.2,ok,0.01,\n"
    )


def test_renderer_generates_figures_and_table(tmp_path: Path) -> None:
    benchmark_dir = tmp_path / "benchmark"
    output_dir = tmp_path / "figures"
    table_dir = tmp_path / "tables"
    write_fixture_csvs(benchmark_dir)

    result = subprocess.run(
        [
            sys.executable,
            "scripts/render_package_benchmark_figures.py",
            "--benchmark-dir",
            str(benchmark_dir),
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
    for name in [
        "package-benchmark-convergence.png",
        "package-benchmark-backend-parity.png",
        "package-benchmark-rheology-profile.png",
        "package-benchmark-resolved3d.png",
    ]:
        assert (output_dir / name).exists()
    table = table_dir / "package-benchmark-summary.tex"
    assert table.exists()
    assert "Package benchmark stage summary" in table.read_text()
