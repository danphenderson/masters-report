import importlib.util
import sys
from pathlib import Path


def load_build_report_module():
    repo = Path(__file__).resolve().parents[1]
    module_path = repo / "scripts" / "build_report.py"
    spec = importlib.util.spec_from_file_location("build_report", module_path)
    assert spec is not None
    assert spec.loader is not None
    module = importlib.util.module_from_spec(spec)
    sys.modules[spec.name] = module
    spec.loader.exec_module(module)
    return module


def test_parse_fls_inputs_normalizes_repo_paths(tmp_path: Path) -> None:
    build_report = load_build_report_module()
    repo = tmp_path / "repo"
    repo.mkdir()
    fls_path = tmp_path / "final-report.fls"
    fls_path.write_text(
        "\n".join(
            [
                "INPUT ./final-report.tex",
                f"INPUT {repo / 'sections' / 'intro.tex'}",
                "INPUT figures/static/static/data/stenosis.csv",
                "INPUT /usr/local/texlive/texmf-dist/tex/latex/base/article.cls",
                f"INPUT {tmp_path / 'outside.tex'}",
                "OUTPUT /tmp/masters-report-build/final-report.pdf",
            ]
        ),
        encoding="utf-8",
    )

    assert build_report.parse_fls_inputs(fls_path, repo) == [
        "final-report.tex",
        "sections/intro.tex",
        "figures/static/static/data/stenosis.csv",
    ]


def test_filter_consumed_inputs_keeps_only_report_roots() -> None:
    build_report = load_build_report_module()

    assert build_report.filter_consumed_inputs(
        [
            "final-report.tex",
            "references.bib",
            "frontmatter/title.tex",
            "sections/01-intro/index.tex",
            "appendices/index.tex",
            "preamble/packages.tex",
            "figures/static/static/tikz/flow.tex",
            "figures/static/static/data/comparison.csv",
            "figures/static/static/tables/verification/table.tex",
            "figures/static/static/rendered/mesh.pdf",
            "figures/static/static/raw/private.csv",
            "README.md",
            "scripts/render_package_benchmark_figures.py",
        ]
    ) == [
        "final-report.tex",
        "references.bib",
        "frontmatter/title.tex",
        "sections/01-intro/index.tex",
        "appendices/index.tex",
        "preamble/packages.tex",
        "figures/static/static/tikz/flow.tex",
        "figures/static/static/data/comparison.csv",
        "figures/static/static/tables/verification/table.tex",
        "figures/static/static/rendered/mesh.pdf",
    ]


def test_untracked_consumed_input_detection_uses_tracked_paths(monkeypatch) -> None:
    build_report = load_build_report_module()

    monkeypatch.setattr(
        build_report,
        "tracked_git_paths",
        lambda repo: {"final-report.tex", "sections/01-intro/index.tex"},
    )

    assert build_report.audit_untracked_consumed_inputs(
        Path("/repo"),
        [
            "final-report.tex",
            "sections/01-intro/index.tex",
            "figures/static/static/data/new-local.csv",
        ],
    ) == ["figures/static/static/data/new-local.csv"]


def test_scan_log_text_blocks_unresolved_and_counts_nonblocking_warnings() -> None:
    build_report = load_build_report_module()
    scan = build_report.scan_log_text(
        "\n".join(
            [
                "LaTeX Warning: Citation 'doe2026' on page 1 undefined on input line 12.",
                "LaTeX Warning: Reference `sec:missing' on page 2 undefined on input line 30.",
                "LaTeX Warning: Label(s) may have changed. Rerun to get cross-references right.",
                "LaTeX Warning: There were multiply-defined labels.",
                "Overfull \\hbox (4.0pt too wide) in paragraph at lines 1--2",
                "Underfull \\hbox (badness 10000) in paragraph at lines 3--4",
                "Package: rerunfilecheck 2025-06-21 v1.11 Rerun checks for auxiliary files (HO)",
                "Package rerunfilecheck Info: File `final-report.out' has not changed.",
                "Package hyperref Warning: Token not allowed in a PDF string (Unicode):",
            ]
        )
    )

    assert len(scan.blocking_log_issues) == 4
    assert scan.warning_counts["overfull_boxes"] == 1
    assert scan.warning_counts["underfull_boxes"] == 1
    assert scan.warning_counts["hyperref_pdf_string"] == 1
    assert scan.warning_counts["other_warnings"] == 0


def test_scan_log_text_does_not_block_layout_or_pdf_string_warnings() -> None:
    build_report = load_build_report_module()
    scan = build_report.scan_log_text(
        "\n".join(
            [
                "Overfull \\hbox (4.0pt too wide) in paragraph at lines 1--2",
                "Underfull \\hbox (badness 10000) in paragraph at lines 3--4",
                "Package hyperref Warning: Token not allowed in a PDF string (Unicode):",
            ]
        )
    )

    assert scan.blocking_log_issues == []
    assert scan.warning_counts == {
        "overfull_boxes": 1,
        "underfull_boxes": 1,
        "hyperref_pdf_string": 1,
        "other_warnings": 0,
    }


def test_scan_log_text_counts_unclassified_warning_lines() -> None:
    build_report = load_build_report_module()
    scan = build_report.scan_log_text(
        "\n".join(
            [
                "Package foo Warning: A harmless package warning.",
                "LaTeX Warning: Citation 'doe2026' on page 1 undefined on input line 12.",
                "Package hyperref Warning: Token not allowed in a PDF string (Unicode):",
                "Overfull \\hbox (4.0pt too wide) in paragraph at lines 1--2",
            ]
        )
    )

    assert len(scan.blocking_log_issues) == 1
    assert scan.warning_counts == {
        "overfull_boxes": 1,
        "underfull_boxes": 0,
        "hyperref_pdf_string": 1,
        "other_warnings": 1,
    }
