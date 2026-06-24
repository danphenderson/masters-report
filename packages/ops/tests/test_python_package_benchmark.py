import csv
import math
import re
import subprocess
import sys
from pathlib import Path


FIXTURE_CSV_FILES = {
    "case_results": "case_results.csv",
    "refinement": "refinement.csv",
    "backend_parity": "backend_parity.csv",
    "stokes_ic": "stokes_ic.csv",
    "rheology_profile": "rheology_profile.csv",
    "boundary_openbf": "boundary_openbf.csv",
    "resolved3d": "resolved3d.csv",
}

EXPECTED_STAGE_COUNTS = {
    "case_results": ("case results", 1, 1, 0),
    "refinement": ("refinement", 2, 2, 0),
    "backend_parity": ("time-integrator comparison", 1, 1, 0),
    "stokes_ic": ("stokes ic", 1, 1, 0),
    "rheology_profile": ("rheology profile", 1, 1, 0),
    "boundary_openbf": ("boundary openbf", 1, 1, 0),
    "resolved3d": ("resolved3d", 1, 1, 0),
}

EXPECTED_NUMERIC_FIELDS = {
    "case_results": ("elapsed_s",),
    "refinement": ("nx", "dofs", "error", "observed_order", "elapsed_s"),
    "backend_parity": (
        "native_elapsed_s",
        "sciml_elapsed_s",
        "area_l2",
        "flow_l2",
        "velocity_l2",
        "pressure_l2",
    ),
    "stokes_ic": (
        "severity",
        "pressure_drop_pa",
        "mesh_nz",
        "mesh_nr",
        "mesh_ntheta",
        "projection_nr",
        "projection_ntheta",
        "velocity_dofs",
        "pressure_dofs",
        "pressure_drop_relative_error",
        "mean_flow",
        "elapsed_s",
    ),
    "rheology_profile": (
        "severity",
        "nx",
        "tfinal",
        "elapsed_s",
        "steps",
        "min_area",
        "max_abs_u",
        "pressure_min",
        "pressure_max",
    ),
    "boundary_openbf": (
        "reflection_coefficient",
        "nx",
        "tfinal",
        "elapsed_s",
        "steps",
        "min_area",
        "max_abs_u",
        "pressure_min",
        "pressure_max",
    ),
    "resolved3d": (
        "severity",
        "section_count",
        "mean_abs_error_cm_s",
        "max_abs_error_cm_s",
        "mean_relative_error",
        "max_relative_error",
        "elapsed_s",
    ),
}

SUMMARY_ROW_PATTERN = re.compile(r"^\s*(?P<stage>.+?) & (?P<rows>\d+) & (?P<ok>\d+) & (?P<skipped>\d+) \\\\$")


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


def read_fixture_tables(root: Path) -> dict[str, list[dict[str, str]]]:
    tables: dict[str, list[dict[str, str]]] = {}
    for stage, filename in FIXTURE_CSV_FILES.items():
        path = root / filename
        assert path.exists(), f"missing fixture CSV for {stage}: {path}"
        with path.open(newline="") as handle:
            tables[stage] = list(csv.DictReader(handle))
    return tables


def finite_float(row: dict[str, str], field: str, *, stage: str, row_number: int) -> float:
    value = (row.get(field) or "").strip()
    assert value, f"{stage} row {row_number} has empty numeric field {field}"
    try:
        parsed = float(value)
    except ValueError as exc:
        raise AssertionError(f"{stage} row {row_number} has nonnumeric {field}: {value!r}") from exc
    assert math.isfinite(parsed), f"{stage} row {row_number} has non-finite {field}: {value!r}"
    return parsed


def assert_fixture_stage_counts(tables: dict[str, list[dict[str, str]]]) -> None:
    assert set(tables) == set(EXPECTED_STAGE_COUNTS)
    for stage, (_, expected_rows, expected_ok, expected_skipped_or_error) in EXPECTED_STAGE_COUNTS.items():
        rows = tables[stage]
        ok_count = sum(1 for row in rows if (row.get("status") or "").strip().lower() == "ok")
        assert len(rows) == expected_rows, f"unexpected fixture row count for {stage}"
        assert ok_count == expected_ok, f"unexpected fixture OK count for {stage}"
        assert len(rows) - ok_count == expected_skipped_or_error, f"unexpected fixture skipped/error count for {stage}"


def assert_fixture_numeric_fields(tables: dict[str, list[dict[str, str]]]) -> None:
    for stage, fields in EXPECTED_NUMERIC_FIELDS.items():
        for row_number, row in enumerate(tables[stage], start=1):
            for field in fields:
                finite_float(row, field, stage=stage, row_number=row_number)


def parse_summary_counts(table_text: str) -> dict[str, tuple[int, int, int]]:
    counts = {}
    for line in table_text.splitlines():
        match = SUMMARY_ROW_PATTERN.match(line)
        if match:
            counts[match.group("stage")] = (
                int(match.group("rows")),
                int(match.group("ok")),
                int(match.group("skipped")),
            )
    return counts


def expected_summary_counts() -> dict[str, tuple[int, int, int]]:
    return {
        label: (expected_rows, expected_ok, expected_skipped_or_error)
        for label, expected_rows, expected_ok, expected_skipped_or_error in EXPECTED_STAGE_COUNTS.values()
    }


def test_renderer_generates_figures_and_table(tmp_path: Path) -> None:
    benchmark_dir = tmp_path / "benchmark"
    output_dir = tmp_path / "figures"
    table_dir = tmp_path / "tables"
    write_fixture_csvs(benchmark_dir)
    fixture_tables = read_fixture_tables(benchmark_dir)
    assert_fixture_stage_counts(fixture_tables)
    assert_fixture_numeric_fields(fixture_tables)

    result = subprocess.run(
        [
            sys.executable,
            "-m",
            "ops.render_package_benchmark_figures",
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
    for name in (
        "package-benchmark-convergence.png",
        "package-benchmark-backend-parity.png",
        "package-benchmark-rheology-profile.png",
        "package-benchmark-resolved3d.png",
    ):
        figure = output_dir / name
        assert figure.exists()
        assert figure.stat().st_size > 0
    table = table_dir / "package-benchmark-summary.tex"
    assert table.exists()
    assert table.stat().st_size > 0
    table_text = table.read_text()
    assert "Package benchmark stage summary" in table_text
    assert "time-integrator comparison" in table_text
    assert "backend parity" not in table_text
    assert parse_summary_counts(table_text) == expected_summary_counts()
