from pathlib import Path

from ops import orchestrate


def test_parse_status_classifies_surfaces_and_protected_artifacts() -> None:
    report = orchestrate.parse_status(
        "\n".join(
            [
                "## master",
                " M report/sections/01-intro/index.tex",
                " M report/assets/rendered/mesh.pdf",
                " M public/var/data/simulations/canic_case3/77/velocity.xdmf",
                "R  tools/python/scripts/build_report.py -> packages/ops/src/ops/build_report.py",
                " M .gitignore",
                "A  .vscode/settings.json",
                "?? odd/local.txt",
            ]
        )
    )

    assert report.branch == "master"
    assert report.dirty_by_surface["report"] == 1
    assert report.dirty_by_surface["assets"] == 2
    assert report.dirty_by_surface["ops"] == 1
    assert report.dirty_by_surface["release"] == 2
    assert report.dirty_by_surface["unknown"] == 1
    assert report.protected_paths == (
        "report/assets/rendered/mesh.pdf",
        "public/var/data/simulations/canic_case3/77/velocity.xdmf",
    )
    assert report.unclassified_paths == ("odd/local.txt",)


def test_parse_status_classifies_renames_from_original_path_when_needed() -> None:
    report = orchestrate.parse_status("R  docs/artifact-policy.md -> archive/artifact-policy.md")

    assert report.entries[0].surface == "release"
    assert report.entries[0].original_path == "docs/artifact-policy.md"


def test_dispatch_packet_includes_guardrails_and_validation(monkeypatch) -> None:
    monkeypatch.setattr(
        orchestrate,
        "status_report",
        lambda repo: orchestrate.StatusReport(
            branch="master",
            entries=(),
            dirty_by_surface={},
            protected_paths=(),
            unclassified_paths=(),
        ),
    )

    packet = orchestrate.dispatch_packet(
        Path("/repo"),
        "report",
        "inspect",
        "Review report structure",
        ["report/sections/01-intro/index.tex"],
    )

    assert "Surface: report" in packet
    assert "- report/sections/01-intro/index.tex" in packet
    assert "pipenv run ops-build-report --outdir /tmp/masters-report-build --no-sync-final-pdf" in packet
    assert "Do not install hooks, spawn background automation, or create persistent orchestration receipts." in packet
    for section in orchestrate.REQUIRED_HANDBACK_SECTIONS:
        assert f"- {section}" in packet


def test_report_artifact_refresh_allows_final_pdf_sync() -> None:
    commands = orchestrate.commands_for("report", "artifact-refresh")

    assert commands == ("pipenv run ops-build-report --outdir /tmp/masters-report-build",)


def test_handback_check_requires_sections_and_validation_evidence() -> None:
    result = orchestrate.check_handback("Status: blocked\n", "ops")

    assert result.status == "failed"
    assert "missing handback section: Scope" in result.issues
    assert "missing validation evidence for surface: ops" in result.issues


def test_handback_check_accepts_complete_ops_handback() -> None:
    result = orchestrate.check_handback(
        "\n".join(
            [
                "## Status",
                "passed",
                "## Scope",
                "ops package only",
                "## Files",
                "packages/ops/src/ops/orchestrate.py",
                "## Validation",
                "pipenv run ops-python-check",
                "## Risks",
                "none identified",
            ]
        ),
        "ops",
    )

    assert result.status == "passed"
    assert result.issues == ()


def test_report_handback_requires_no_sync_final_pdf_outside_artifact_refresh() -> None:
    handback = "\n".join(
        [
            "Status: passed",
            "Scope: report",
            "Files: report/sections/01-intro/index.tex",
            "Validation: pipenv run ops-build-report --outdir /tmp/masters-report-build",
            "Risks: none",
        ]
    )

    assert orchestrate.check_handback(handback, "report", "inspect").status == "failed"
    assert orchestrate.check_handback(handback, "report", "artifact-refresh").status == "passed"


def test_handback_check_accepts_explicit_validation_skip_reason() -> None:
    handback = "\n".join(
        [
            "Status: blocked",
            "Scope: report",
            "Files: report/sections/01-intro/index.tex",
            "Validation: not run because latexmk is unavailable in this checkout",
            "Risks: report build remains unverified",
        ]
    )

    assert orchestrate.check_handback(handback, "report").status == "passed"
