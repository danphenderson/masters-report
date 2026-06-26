import subprocess
import sys
from pathlib import Path

from ops.render_resolved3d_comparison_tables import render_tables


def write_fixture_data(data_dir: Path) -> None:
    data_dir.mkdir(parents=True)
    (data_dir / "section-quadrature-reference.dat").write_text(
        "z discseverity23 flowdiscseverity23 discseverity40 flowdiscseverity40\n"
        "0.0 0.4 0.02 0.8 0.06\n"
        "1.0 0.6 0.04 1.2 0.08\n",
        encoding="utf-8",
    )
    (data_dir / "section-quadrature-deformed.dat").write_text(
        "z discseverity23 flowdiscseverity23 discseverity40 flowdiscseverity40\n"
        "0.0 0.3 0.01 0.9 0.05\n"
        "1.0 0.5 0.03 1.1 0.07\n",
        encoding="utf-8",
    )
    (data_dir / "radial-profile-audit-reference.csv").write_text(
        "severity,case,coordinate_mode,z_slice_cm,radial_bin_count,area_mismatch_rel,"
        "reconstructed_mean_abs_error_cm_s,summary_mean_abs_delta_cm_s,status,message\n"
        "22.555555555555554,severity23,reference,1.0,20,NaN,0.6,0.0,failed,radial area closure exceeds 1%\n"
        "22.555555555555554,severity23,reference,2.0,20,NaN,0.7,0.0,failed,radial area closure exceeds 1%\n"
        "40.0,severity40,reference,1.0,20,NaN,1.6,0.1,ok,\n",
        encoding="utf-8",
    )
    (data_dir / "radial-profile-audit-deformed.csv").write_text(
        "severity,case,coordinate_mode,z_slice_cm,radial_bin_count,area_mismatch_rel,"
        "reconstructed_mean_abs_error_cm_s,summary_mean_abs_delta_cm_s,status,message\n"
        "22.555555555555554,severity23,deformed,1.0,10,NaN,0.6,0.2,ok,\n"
        "40.0,severity40,deformed,1.0,20,NaN,1.6,0.0,failed,radial area closure exceeds 1%\n",
        encoding="utf-8",
    )


def test_render_resolved3d_comparison_tables(tmp_path: Path) -> None:
    data_dir = tmp_path / "data"
    table_dir = tmp_path / "tables"
    write_fixture_data(data_dir)

    paths = render_tables(data_dir, table_dir)

    assert paths == [table_dir / "coordinate_mode_comparison.tex", table_dir / "radial_profile_audit.tex"]
    assert (table_dir / "coordinate_mode_comparison.tex").read_text(encoding="utf-8") == (
        "\\begin{tabular}{@{}llrrrr@{}}\n"
        "\\toprule\n"
        "Case & Coordinates & $D_{u,1}$ & $D_{u,2}$ & $\\max |d_u|$ & $D_{Q,1}$ \\\\\n"
        "\\midrule\n"
        "C23 (22.56\\%) & reference & 0.5000 & 0.5099 & 0.600 & 0.03000 \\\\\n"
        "C23 (22.56\\%) & deformed & 0.4000 & 0.4123 & 0.500 & 0.02000 \\\\\n"
        "40\\% stenosis & reference & 1.0000 & 1.020 & 1.200 & 0.07000 \\\\\n"
        "40\\% stenosis & deformed & 1.0000 & 1.005 & 1.100 & 0.06000 \\\\\n"
        "\\bottomrule\n"
        "\\end{tabular}\n"
    )
    assert (table_dir / "radial_profile_audit.tex").read_text(encoding="utf-8") == (
        "\\begin{tabular}{@{}llrrrl@{}}\n"
        "\\toprule\n"
        "Case & Coordinates & Slices & Bins & Summary delta & Audit result \\\\\n"
        "\\midrule\n"
        "C23 (22.56\\%) & reference & 2 & 20 & 0.0 & failed area-closure gate \\\\\n"
        "C23 (22.56\\%) & deformed & 1 & 10 & 0.2 & passed \\\\\n"
        "40\\% stenosis & reference & 1 & 20 & 0.1 & passed \\\\\n"
        "40\\% stenosis & deformed & 1 & 20 & 0.0 & failed area-closure gate \\\\\n"
        "\\bottomrule\n"
        "\\end{tabular}\n"
    )


def test_render_resolved3d_comparison_tables_reports_missing_inputs(tmp_path: Path) -> None:
    data_dir = tmp_path / "data"
    table_dir = tmp_path / "tables"
    data_dir.mkdir()

    result = subprocess.run(
        [
            sys.executable,
            "-m",
            "ops.render_resolved3d_comparison_tables",
            "--data-dir",
            str(data_dir),
            "--table-dir",
            str(table_dir),
        ],
        check=False,
        text=True,
        capture_output=True,
    )

    assert result.returncode == 1
    assert "required resolved-3D table input is missing" in result.stdout
