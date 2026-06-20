from pathlib import Path

from ops import build_report


def test_default_final_pdf_is_public_local_artifact() -> None:
    assert build_report.parse_args([]).final_pdf == Path("public/final-report.pdf")


def test_parse_fls_inputs_normalizes_repo_paths(tmp_path: Path) -> None:
    repo = tmp_path / "repo"
    repo.mkdir()
    fls_path = tmp_path / "final-report.fls"
    fls_path.write_text(
        "\n".join(
            [
                "INPUT ./report/final-report.tex",
                f"INPUT {repo / 'report' / 'sections' / 'intro.tex'}",
                "INPUT report/assets/data/stenosis.csv",
                "INPUT /usr/local/texlive/texmf-dist/tex/latex/base/article.cls",
                f"INPUT {tmp_path / 'outside.tex'}",
                "OUTPUT /tmp/masters-report-build/final-report.pdf",
            ]
        ),
        encoding="utf-8",
    )

    assert build_report.parse_fls_inputs(fls_path, repo) == [
        "report/final-report.tex",
        "report/sections/intro.tex",
        "report/assets/data/stenosis.csv",
    ]


def test_filter_consumed_inputs_keeps_only_report_roots() -> None:
    assert build_report.filter_consumed_inputs(
        [
            "report/final-report.tex",
            "public/references/references.bib",
            "report/frontmatter/title.tex",
            "report/sections/01-intro/index.tex",
            "report/appendices/index.tex",
            "report/preamble/packages.tex",
            "report/assets/tikz/flow.tex",
            "report/assets/data/comparison.csv",
            "report/assets/tables/verification/table.tex",
            "report/assets/rendered/mesh.pdf",
            "report/assets/raw/private.csv",
            "README.md",
            "packages/ops/src/ops/render_package_benchmark_figures.py",
        ]
    ) == [
        "report/final-report.tex",
        "public/references/references.bib",
        "report/frontmatter/title.tex",
        "report/sections/01-intro/index.tex",
        "report/appendices/index.tex",
        "report/preamble/packages.tex",
        "report/assets/tikz/flow.tex",
        "report/assets/data/comparison.csv",
        "report/assets/tables/verification/table.tex",
        "report/assets/rendered/mesh.pdf",
    ]


def test_untracked_consumed_input_detection_uses_tracked_paths(monkeypatch) -> None:
    monkeypatch.setattr(
        build_report,
        "tracked_git_paths",
        lambda repo: {"report/final-report.tex", "report/sections/01-intro/index.tex"},
    )

    assert build_report.audit_untracked_consumed_inputs(
        Path("/repo"),
        [
            "report/final-report.tex",
            "report/sections/01-intro/index.tex",
            "report/assets/data/new-local.csv",
        ],
    ) == ["report/assets/data/new-local.csv"]


def test_sync_final_pdf_copies_pdf_and_reports_hash(tmp_path: Path) -> None:
    source = tmp_path / "scratch" / "final-report.pdf"
    destination = tmp_path / "repo" / "final-report.pdf"
    source.parent.mkdir()
    source.write_bytes(b"%PDF-1.7\nvalidated report\n")

    synced = build_report.sync_final_pdf(source, destination)

    assert destination.read_bytes() == source.read_bytes()
    assert synced == {
        "path": destination.as_posix(),
        "sha256": build_report.sha256_file(destination),
    }


def test_scan_log_text_blocks_unresolved_and_counts_nonblocking_warnings() -> None:
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
