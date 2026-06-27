from pathlib import Path

from ops import render_stenosis_geometry_figures


def test_renderer_reports_missing_export_assets_prerequisite(tmp_path: Path, capsys) -> None:
    data_dir = tmp_path / "stenosis-geometry"

    exit_code = render_stenosis_geometry_figures.main(["--data-dir", str(data_dir)])

    assert exit_code == 2
    captured = capsys.readouterr()
    assert "missing required stenosis geometry export(s)" in captured.err
    assert "analytic_summary.csv" in captured.err
    assert "packages/stenotic-hemodynamics/bin/stenotic-hemodynamics export-assets --overwrite" in captured.err
    assert "pipenv run ops-render-stenosis-geometry-figures" in captured.err
    assert "Traceback" not in captured.err


def test_resolved_case_display_distinguishes_c23_reduced_severity() -> None:
    assert render_stenosis_geometry_figures.resolved_case_display("77", 23) == "C23 (22.56%)"
    assert render_stenosis_geometry_figures.resolved_case_display("60", 40) == "C40"
    assert render_stenosis_geometry_figures.resolved_case_display("99", 50) == "C50"
