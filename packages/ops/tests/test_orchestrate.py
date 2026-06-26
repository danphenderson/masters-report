import json
import subprocess
import tarfile
from pathlib import Path

from ops import orchestrate


def repo_root() -> Path:
    return Path(__file__).resolve().parents[3]


def init_git_repo(path: Path) -> None:
    subprocess.run(["git", "init"], cwd=path, check=True, capture_output=True)
    subprocess.run(["git", "config", "user.email", "test@example.com"], cwd=path, check=True)
    subprocess.run(["git", "config", "user.name", "Test User"], cwd=path, check=True)


def test_parse_status_classifies_surfaces_and_protected_artifacts() -> None:
    report = orchestrate.parse_status(
        "\n".join(
            [
                "## master",
                " M report/sections/01-intro/index.tex",
                " M report/assets/rendered/mesh.pdf",
                " M public/var/data/simulations/canic_case3/77/velocity.xdmf",
                "?? public/var/logs/.gitkeep",
                "?? public/var/logs/run.jsonl",
                "R  tools/python/scripts/build_report.py -> packages/ops/src/ops/build_report.py",
                " M .gitignore",
                "A  .vscode/settings.json",
                "?? odd/local.txt",
            ]
        )
    )

    assert report.branch == "master"
    assert report.dirty_by_surface["report"] == 1
    assert report.dirty_by_surface["assets"] == 4
    assert report.dirty_by_surface["ops"] == 1
    assert report.dirty_by_surface["release"] == 2
    assert report.dirty_by_surface["unknown"] == 1
    assert report.protected_paths == (
        "report/assets/rendered/mesh.pdf",
        "public/var/data/simulations/canic_case3/77/velocity.xdmf",
        "public/var/logs/run.jsonl",
    )
    assert report.unclassified_paths == ("odd/local.txt",)


def test_parse_status_classifies_renames_from_original_path_when_needed() -> None:
    report = orchestrate.parse_status("R  docs/artifact-policy.md -> archive/artifact-policy.md")

    assert report.entries[0].surface == "release"
    assert report.entries[0].original_path == "docs/artifact-policy.md"


def test_parse_status_classifies_report_sections_as_report_surface() -> None:
    report = orchestrate.parse_status(" M report/sections/01-intro/index.tex")

    assert report.entries[0].surface == "report"


def test_parse_status_classifies_report_root_files_as_report_surface() -> None:
    report = orchestrate.parse_status(" D report/local-note.md")

    assert report.entries[0].surface == "report"
    assert report.unclassified_paths == ()


def test_parse_status_classifies_docs_site_files_as_release_surface() -> None:
    report = orchestrate.parse_status(
        "\n".join(
            [
                "?? .github/workflows/docs-pages.yml",
                "?? public/docs/docusaurus.config.js",
                "?? public/docs/package-lock.json",
                "?? public/docs/package.json",
                "?? public/docs/sidebars.js",
                "?? public/docs/src/css/custom.css",
                "?? public/docs/static/.nojekyll",
            ]
        )
    )

    assert {entry.surface for entry in report.entries} == {"release"}
    assert report.unclassified_paths == ()


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


def test_dispatch_packet_includes_editorial_profile_guidance(monkeypatch) -> None:
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
        "hard-review",
        "Editorial readiness review",
        [],
        "editorial-readiness",
    )

    assert "Profile: editorial-readiness" in packet
    assert "## Profile Guidance" in packet
    assert "committee-facing manuscript experience" in packet
    assert "- Verdict" in packet
    assert "- Reader Impact" in packet


def test_dispatch_payload_includes_unclassified_paths(monkeypatch) -> None:
    monkeypatch.setattr(
        orchestrate,
        "status_report",
        lambda repo: orchestrate.StatusReport(
            branch="master",
            entries=(),
            dirty_by_surface={"unknown": 1},
            protected_paths=(),
            unclassified_paths=("scratch-note.md",),
        ),
    )

    payload = orchestrate.dispatch_payload(
        Path("/repo"),
        "report",
        "inspect",
        "Inspect report",
        [],
    )

    assert payload["profile"] == "generic"
    assert payload["unclassified_paths"] == ["scratch-note.md"]


def test_dispatch_requires_files_for_mutating_modes() -> None:
    for mode in ("bounded-edit", "artifact-refresh"):
        try:
            orchestrate.dispatch_packet(Path("/repo"), "report", mode, "Patch report", [])
        except ValueError as exc:
            assert f"--files is required for --mode {mode}" in str(exc)
        else:
            raise AssertionError(f"expected {mode} dispatch to require files")


def test_review_packet_prints_read_only_lane_contract(monkeypatch) -> None:
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

    packet = orchestrate.review_packet(Path("/repo"), "786e8f9", "orchestration")

    assert "Start with: `git status --short --branch --untracked-files=all`" in packet
    assert "Review commit: 786e8f9" in packet
    assert "Lane: orchestration" in packet
    assert "Mode: hard-review" in packet
    assert "- packages/ops/src/ops/orchestrate/**" in packet
    assert "Do not edit, stage, delete, or generate patches during review." in packet
    assert "pipenv run ops-orchestrate docs-contract" in packet
    for section in orchestrate.REQUIRED_HANDBACK_SECTIONS:
        assert f"- {section}" in packet


def test_review_payload_matches_lane_spec(monkeypatch) -> None:
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

    payload = orchestrate.review_payload(Path("/repo"), "786e8f9", "layout")

    assert payload["commit"] == "786e8f9"
    assert payload["lane"] == "layout"
    assert payload["surfaces"] == ["julia", "ops"]
    assert payload["mode"] == "hard-review"
    assert "packages/stenotic-hemodynamics/bin/*" in payload["allowed_files"]
    assert "pipenv run ops-julia-check" in payload["validation"]
    assert "pipenv run ops-python-check" in payload["validation"]


def test_dispatch_bundle_writes_harness_and_working_tree_snapshot(tmp_path: Path) -> None:
    repo = tmp_path / "repo"
    repo.mkdir()
    init_git_repo(repo)
    (repo / ".gitignore").write_text("tmp/\n", encoding="utf-8")
    (repo / "README.md").write_text("baseline\n", encoding="utf-8")
    (repo / "public").mkdir()
    (repo / "public/final-report.pdf").write_bytes(b"%PDF tracked artifact\n")
    subprocess.run(["git", "add", ".gitignore", "README.md", "public/final-report.pdf"], cwd=repo, check=True)
    subprocess.run(["git", "commit", "-m", "Initial"], cwd=repo, check=True, capture_output=True)

    (repo / "README.md").write_text("modified working tree\n", encoding="utf-8")
    (repo / "report" / "sections").mkdir(parents=True)
    (repo / "report" / "sections" / "local-note.tex").write_text("untracked report note\n", encoding="utf-8")

    result = orchestrate.create_dispatch_bundle(
        repo,
        objective="Inspect the current dirty tree",
        outdir=Path("tmp/dispatch-bundles"),
    )

    assert result.archive_path.exists()
    assert len(result.archive_sha256) == 64
    assert result.excluded_files == ("public/final-report.pdf",)
    assert "I uploaded a `.tar.gz` dispatch bundle" in result.prompt

    with tarfile.open(result.archive_path, "r:gz") as bundle:
        names = bundle.getnames()
        prompt_member = next(member for member in bundle.getmembers() if member.name.endswith("CHATGPT_PRO_PROMPT.md"))
        harness_member = next(
            member for member in bundle.getmembers() if member.name.endswith("CHATGPT_PRO_DISPATCH.md")
        )
        manifest_member = next(member for member in bundle.getmembers() if member.name.endswith("BUNDLE_MANIFEST.json"))
        readme_member = next(member for member in bundle.getmembers() if member.name.endswith("/repo/README.md"))
        prompt_text = bundle.extractfile(prompt_member).read().decode("utf-8")  # type: ignore[union-attr]
        harness_text = bundle.extractfile(harness_member).read().decode("utf-8")  # type: ignore[union-attr]
        manifest = json.loads(bundle.extractfile(manifest_member).read().decode("utf-8"))  # type: ignore[union-attr]
        readme = bundle.extractfile(readme_member).read().decode("utf-8")  # type: ignore[union-attr]

    assert any(name.endswith("CHATGPT_PRO_PROMPT.md") for name in names)
    assert any(name.endswith("CHATGPT_PRO_DISPATCH.md") for name in names)
    assert any(name.endswith("GIT_STATUS.txt") for name in names)
    assert any(name.endswith("GIT_DIFF.patch") for name in names)
    assert any(name.endswith("/repo/report/sections/local-note.tex") for name in names)
    assert not any(name.endswith("/repo/public/final-report.pdf") for name in names)
    assert readme == "modified working tree\n"
    assert manifest["target"] == "chatgpt-pro"
    assert manifest["objective"] == "Inspect the current dirty tree"
    assert manifest["status"]["dirty_by_surface"] == {"release": 1, "report": 1}
    assert manifest["archive_policy"]["protected_artifacts_included"] is False
    assert manifest["required_reading_order"] == [
        "BUNDLE_MANIFEST.json",
        "OPS_STATUS.json",
        "GIT_STATUS.txt",
        "GIT_DIFF.patch",
    ]
    assert manifest["follow_up_repo_reading"] == "Objective-relevant files under repo/"
    assert prompt_text == result.prompt
    assert "Working tree status: dirty at bundle creation." in result.prompt
    assert "Dirty surface `release`: 1 path(s)" in result.prompt
    assert "Dirty surface `report`: 1 path(s)" in result.prompt
    assert "M README.md (release)" in result.prompt
    assert "?? report/sections/local-note.tex (report)" in result.prompt
    assert "Excluded protected artifact: public/final-report.pdf" in result.prompt
    assert "Then inspect:" in result.prompt
    assert "Objective-relevant files under repo/" in result.prompt
    assert "repo/public/docs/markdown/agent-workflows.md" not in result.prompt
    assert "Current State" in result.prompt
    assert "Blocked-condition rules:" in result.prompt
    assert "if any listed required-reading file path is absent from the bundle" in result.prompt
    assert "## Follow-up Repo Reading" in harness_text
    assert "Included working-tree files:" in harness_text
    assert "Excluded protected artifact: public/final-report.pdf" in harness_text
    assert "Skipped files: none" in harness_text


def test_dispatch_bundle_required_reading_includes_repo_contract_files_when_present(tmp_path: Path) -> None:
    repo = tmp_path / "repo"
    repo.mkdir()
    init_git_repo(repo)
    (repo / "README.md").write_text("baseline\n", encoding="utf-8")
    (repo / "AGENTS.md").write_text("repo guide\n", encoding="utf-8")
    (repo / "public" / "docs" / "markdown").mkdir(parents=True)
    (repo / "public" / "docs" / "markdown" / "agent-workflows.md").write_text("agent workflow\n", encoding="utf-8")
    (repo / "public" / "docs" / "markdown" / "artifact-policy.md").write_text("artifact policy\n", encoding="utf-8")
    subprocess.run(
        [
            "git",
            "add",
            "README.md",
            "AGENTS.md",
            "public/docs/markdown/agent-workflows.md",
            "public/docs/markdown/artifact-policy.md",
        ],
        cwd=repo,
        check=True,
    )
    subprocess.run(["git", "commit", "-m", "Initial"], cwd=repo, check=True, capture_output=True)

    result = orchestrate.create_dispatch_bundle(
        repo,
        objective="Inspect the current dirty tree",
        outdir=Path("tmp/dispatch-bundles"),
    )

    assert result.manifest["required_reading_order"] == [
        "BUNDLE_MANIFEST.json",
        "OPS_STATUS.json",
        "GIT_STATUS.txt",
        "GIT_DIFF.patch",
        "repo/AGENTS.md",
        "repo/public/docs/markdown/agent-workflows.md",
        "repo/public/docs/markdown/artifact-policy.md",
    ]
    assert "repo/AGENTS.md" in result.prompt
    assert "repo/public/docs/markdown/agent-workflows.md" in result.prompt
    assert "repo/public/docs/markdown/artifact-policy.md" in result.prompt


def test_dispatch_bundle_rejects_dirty_protected_artifacts(tmp_path: Path) -> None:
    repo = tmp_path / "repo"
    repo.mkdir()
    init_git_repo(repo)
    (repo / "public").mkdir()
    (repo / "public/final-report.pdf").write_bytes(b"%PDF baseline\n")
    subprocess.run(["git", "add", "public/final-report.pdf"], cwd=repo, check=True)
    subprocess.run(["git", "commit", "-m", "Initial"], cwd=repo, check=True, capture_output=True)
    (repo / "public/final-report.pdf").write_bytes(b"%PDF changed\n")

    try:
        orchestrate.create_dispatch_bundle(repo, objective="Inspect", outdir=Path("tmp/dispatch-bundles"))
    except ValueError as exc:
        assert "protected artifact paths require --include-protected-artifacts" in str(exc)
        assert "public/final-report.pdf" in str(exc)
    else:
        raise AssertionError("expected dirty protected artifact to fail bundle creation")


def test_dispatch_bundle_cli_json_output(tmp_path: Path, capsys) -> None:
    repo = tmp_path / "repo"
    repo.mkdir()
    init_git_repo(repo)
    (repo / "README.md").write_text("baseline\n", encoding="utf-8")
    subprocess.run(["git", "add", "README.md"], cwd=repo, check=True)
    subprocess.run(["git", "commit", "-m", "Initial"], cwd=repo, check=True, capture_output=True)

    assert (
        orchestrate.main(
            [
                "--repo",
                str(repo),
                "bundle",
                "--objective",
                "Smoke-test the bundle command",
                "--outdir",
                str(repo / "tmp/dispatch-bundles"),
                "--json",
            ]
        )
        == 0
    )
    payload = json.loads(capsys.readouterr().out)

    assert Path(payload["archive_path"]).exists()
    assert len(payload["archive_sha256"]) == 64
    assert payload["manifest"]["objective"] == "Smoke-test the bundle command"
    assert payload["manifest"]["required_reading_order"] == [
        "BUNDLE_MANIFEST.json",
        "OPS_STATUS.json",
        "GIT_STATUS.txt",
        "GIT_DIFF.patch",
    ]
    assert "Working tree status: clean at bundle creation." in payload["prompt"]
    assert "Dirty surfaces: none" in payload["prompt"]
    assert "Required reading order:" in payload["prompt"]
    assert "Then inspect:" in payload["prompt"]
    assert "Evidence hierarchy:" in payload["prompt"]
    assert "Repo guardrails:" in payload["prompt"]
    assert "Output contract:" in payload["prompt"]
    assert "Blocked-condition rules:" in payload["prompt"]
    assert "repo/AGENTS.md" not in payload["prompt"]


def test_report_artifact_refresh_allows_final_pdf_sync() -> None:
    commands = orchestrate.commands_for("report", "artifact-refresh")

    assert commands == ("pipenv run ops-build-report --outdir /tmp/masters-report-build",)


def test_artifact_refresh_clarifies_rendered_asset_scope() -> None:
    blocked = orchestrate.blocked_artifacts_for("report", "artifact-refresh")

    assert "public/final-report.pdf may refresh only after the report gate passes" in blocked
    assert (
        "report/assets/rendered/** may refresh only when listed in Allowed Files and the owning gate passes" in blocked
    )


def test_handback_check_requires_sections_and_validation_evidence() -> None:
    result = orchestrate.check_handback("Status: blocked\n", "ops")

    assert result.status == "failed"
    assert "missing handback section: Scope" in result.issues
    assert "missing validation evidence for surface: ops" in result.issues


def test_handback_check_rejects_missing_validation_command() -> None:
    result = orchestrate.check_handback(
        "\n".join(
            [
                "Status: passed",
                "Scope: ops package",
                "Files: packages/ops/src/ops/orchestrate/__init__.py",
                "Validation: pytest packages/ops/tests/test_orchestrate.py",
                "Risks: narrow ops-only change with no artifact churn",
            ]
        ),
        "ops",
    )

    assert result.status == "failed"
    assert "missing validation evidence for surface: ops" in result.issues


def test_handback_check_rejects_empty_validation_even_when_marker_is_elsewhere() -> None:
    result = orchestrate.check_handback(
        "\n".join(
            [
                "Status: passed",
                "Scope: ops package; expected command is pipenv run ops-python-check",
                "Files: packages/ops/src/ops/orchestrate/__init__.py",
                "Validation:",
                "Risks: no artifact or report-output churn in scope",
            ]
        ),
        "ops",
    )

    assert result.status == "failed"
    assert "insufficient handback section: Validation" in result.issues
    assert "missing validation evidence for surface: ops" in result.issues


def test_handback_check_rejects_empty_or_boilerplate_risks() -> None:
    result = orchestrate.check_handback(
        "\n".join(
            [
                "Status: passed",
                "Scope: ops package only",
                "Files: packages/ops/src/ops/orchestrate/__init__.py",
                "Validation: pipenv run ops-python-check",
                "Risks: none",
            ]
        ),
        "ops",
    )

    assert result.status == "failed"
    assert "insufficient handback section: Risks" in result.issues


def test_handback_check_accepts_complete_ops_handback() -> None:
    result = orchestrate.check_handback(
        "\n".join(
            [
                "## Status",
                "passed",
                "## Scope",
                "ops package only",
                "## Files",
                "packages/ops/src/ops/orchestrate/__init__.py",
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


def test_handback_check_accepts_orchestrator_validation_scope() -> None:
    result = orchestrate.check_handback(
        "\n".join(
            [
                "## Status",
                "passed",
                "## Scope",
                "ops package only",
                "## Files",
                "packages/ops/src/ops/orchestrate/cli.py",
                "## Validation",
                "Orchestrator validation scope: pipenv run ops-python-check",
                "## Risks",
                "official validation remains orchestrator-owned before commit",
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
            "Risks: final PDF sync remains blocked outside artifact-refresh mode",
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


def test_handback_check_rejects_validation_skip_with_success_status() -> None:
    handback = "\n".join(
        [
            "Status: passed",
            "Scope: ops package",
            "Files: packages/ops/src/ops/orchestrate/__init__.py",
            "Validation: not run because optional in this checkout",
            "Risks: validation omitted but this still claims pass",
        ]
    )

    result = orchestrate.check_handback(handback, "ops")

    assert result.status == "failed"
    assert "validation skip requires a blocked, failed, or no-send Status" in result.issues


def test_handback_check_rejects_pending_validation_intent() -> None:
    handback = "\n".join(
        [
            "Status: passed",
            "Scope: ops package",
            "Files: packages/ops/src/ops/orchestrate/__init__.py",
            "Validation: TODO run pipenv run ops-python-check before commit",
            "Risks: reviewer should verify because validation is still pending",
        ]
    )

    result = orchestrate.check_handback(handback, "ops")

    assert result.status == "failed"
    assert "pending validation evidence for surface: ops" in result.issues


def test_handback_check_requires_profile_sections() -> None:
    handback = "\n".join(
        [
            "Status: passed",
            "Scope: report",
            "Files: report/sections/06-synthesis/index.tex",
            "Validation: pipenv run ops-build-report --outdir /tmp/masters-report-build --no-sync-final-pdf",
            "Risks: editorial review only; no artifact refresh in scope",
        ]
    )

    result = orchestrate.check_handback(handback, "report", "inspect", "editorial-readiness")

    assert result.status == "failed"
    assert "missing handback section: Verdict" in result.issues
    assert "missing handback section: Reader Impact" in result.issues


def test_packet_check_flags_stale_paths_and_overbroad_authority() -> None:
    packet = "\n".join(
        [
            "Use julia/Project.toml and tools/python/scripts/build_report.py.",
            "Run bin/build-report --outdir /tmp/build.",
            "Coordinate with report/TODO.md.",
            "Please regenerate experiments or rewrite report assets as needed.",
        ]
    )

    result = orchestrate.packet_check(packet)

    assert result.status == "failed"
    assert "stale Julia root; use packages/stenotic-hemodynamics/" in result.issues
    assert "stale Python tooling root; use packages/ops/" in result.issues
    assert "stale report build wrapper; use pipenv run ops-build-report" in result.issues
    assert (
        "deleted TODO coordination file route; use GitHub issues and public/docs/markdown/agent-workflows.md"
        in result.issues
    )
    assert "missing final PDF artifact guardrail: public/final-report.pdf" in result.issues
    assert "missing rendered report asset guardrail: report/assets/rendered/**" in result.issues
    assert "missing current ops validation command" in result.issues
    assert "overbroad packet authority: avoid regenerate/rewrite/modify-as-needed language" in result.issues


def test_packet_check_rejects_deleted_todo_coordination_file_route() -> None:
    packet = "\n".join(
        [
            "Coordinate with packages/stenotic-hemodynamics/TODO.md.",
            "Guard public/final-report.pdf and report/assets/rendered/**.",
            "Validation: pipenv run ops-python-check passed.",
        ]
    )

    result = orchestrate.packet_check(packet)

    assert result.status == "failed"
    assert result.issues == (
        "deleted TODO coordination file route; use GitHub issues and public/docs/markdown/agent-workflows.md",
    )


def test_packet_check_accepts_profiled_dispatch_packet(monkeypatch) -> None:
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
        "hard-review",
        "Editorial readiness review",
        [],
        "editorial-readiness",
    )

    result = orchestrate.packet_check(packet, "editorial-readiness")

    assert result.status == "passed"


def test_ready_to_commit_gates_select_focused_surface_validation() -> None:
    report = orchestrate.parse_status(
        "\n".join(
            [
                "## master",
                " M packages/ops/src/ops/orchestrate/cli.py",
                " M report/sections/01-intro/index.tex",
            ]
        )
    )

    gates = orchestrate.ready_to_commit_gates(report, report_outdir=Path("/tmp/build"))
    commands = [orchestrate.shell_command(gate.command) for gate in gates]

    assert "git diff --check" in commands
    assert "git diff --cached --check" in commands
    assert "pipenv run ops-orchestrate docs-contract" in commands
    assert "pipenv run pre-commit run --all-files" in commands
    assert "pipenv run ops-python-check" in commands
    assert "pipenv run ops-audit-report-prose --json" in commands
    assert "pipenv run ops-build-report --outdir /tmp/build --no-sync-final-pdf" in commands
    assert all("ops-release-check" not in command for command in commands)


def test_ready_to_commit_skips_julia_validation_for_package_markdown_only() -> None:
    report = orchestrate.parse_status("## master\n M packages/stenotic-hemodynamics/README.md")

    gates = orchestrate.ready_to_commit_gates(report, report_outdir=Path("/tmp/build"))
    commands = [orchestrate.shell_command(gate.command) for gate in gates]

    assert "pipenv run ops-julia-check" not in commands


def test_ready_to_commit_skips_report_build_for_report_markdown_only() -> None:
    report = orchestrate.parse_status("## master\n M report/notebooks/note.md")

    gates = orchestrate.ready_to_commit_gates(report, report_outdir=Path("/tmp/build"))
    commands = [orchestrate.shell_command(gate.command) for gate in gates]

    assert "pipenv run ops-build-report --outdir /tmp/build --no-sync-final-pdf" not in commands
    assert "pipenv run ops-audit-report-prose --json" not in commands


def test_ready_to_commit_runs_report_build_for_tex_source() -> None:
    report = orchestrate.parse_status("## master\n M report/sections/01-intro/index.tex")

    gates = orchestrate.ready_to_commit_gates(report, report_outdir=Path("/tmp/build"))
    commands = [orchestrate.shell_command(gate.command) for gate in gates]

    assert "pipenv run ops-build-report --outdir /tmp/build --no-sync-final-pdf" in commands
    assert "pipenv run ops-audit-report-prose --json" in commands


def test_ready_to_commit_runs_julia_validation_for_package_source() -> None:
    report = orchestrate.parse_status("## master\n M packages/stenotic-hemodynamics/src/StenoticHemodynamics.jl")

    gates = orchestrate.ready_to_commit_gates(report, report_outdir=Path("/tmp/build"))
    commands = [orchestrate.shell_command(gate.command) for gate in gates]

    assert "pipenv run ops-julia-check" in commands


def test_ready_to_commit_all_uses_aggregate_patch_gate() -> None:
    report = orchestrate.parse_status("## master\n M packages/ops/src/ops/orchestrate/cli.py")

    gates = orchestrate.ready_to_commit_gates(report, report_outdir=Path("/tmp/build"), all_gates=True)

    assert [orchestrate.shell_command(gate.command) for gate in gates] == [
        "pipenv run ops-release-check --mode patch --report-outdir /tmp/build"
    ]


def test_ready_to_commit_allows_protected_artifacts_by_default() -> None:
    report = orchestrate.parse_status("## master\n M public/final-report.pdf")

    issues = orchestrate.ready_to_commit_issues(report)

    assert issues == ()


def test_ready_to_commit_ignores_legacy_protected_artifact_flag() -> None:
    report = orchestrate.parse_status("## master\n M public/final-report.pdf")

    issues = orchestrate.ready_to_commit_issues(report, allow_protected_artifacts=False)

    assert issues == ()


def test_cli_json_subcommands_smoke(tmp_path: Path, capsys) -> None:
    root = repo_root()

    assert orchestrate.main(["--repo", str(root), "status", "--json"]) == 0
    assert "branch" in json.loads(capsys.readouterr().out)

    assert (
        orchestrate.main(
            [
                "--repo",
                str(root),
                "dispatch",
                "--surface",
                "ops",
                "--mode",
                "inspect",
                "--objective",
                "review smoke",
                "--files",
                "packages/ops/src/ops/orchestrate/__init__.py",
                "packages/ops/src/ops/orchestrate/cli.py",
                "--json",
            ]
        )
        == 0
    )
    dispatch = json.loads(capsys.readouterr().out)
    assert dispatch["surface"] == "ops"
    assert dispatch["allowed_files"] == [
        "packages/ops/src/ops/orchestrate/__init__.py",
        "packages/ops/src/ops/orchestrate/cli.py",
    ]

    assert (
        orchestrate.main(["--repo", str(root), "review", "--commit", "HEAD", "--lane", "orchestration", "--json"]) == 0
    )
    assert json.loads(capsys.readouterr().out)["lane"] == "orchestration"

    sessions_root = tmp_path / "sessions"
    session_dir = sessions_root / "2026/06/20"
    session_dir.mkdir(parents=True)
    session_path = session_dir / "rollout-2026-06-20T12-00-00-019ee000-0000-7000-8000-000000000001.jsonl"
    session_path.write_text(
        "\n".join(
            [
                json.dumps(
                    {
                        "timestamp": "2026-06-20T19:00:00.000Z",
                        "type": "session_meta",
                        "payload": {
                            "id": "019ee000-0000-7000-8000-000000000001",
                            "timestamp": "2026-06-20T19:00:00.000Z",
                            "cwd": root.as_posix(),
                        },
                    }
                ),
                json.dumps(
                    {
                        "type": "response_item",
                        "payload": {
                            "type": "message",
                            "role": "user",
                            "content": [{"type": "input_text", "text": "Run validation"}],
                        },
                    }
                ),
                json.dumps(
                    {
                        "type": "response_item",
                        "payload": {
                            "type": "function_call",
                            "name": "exec_command",
                            "arguments": json.dumps({"cmd": "pipenv run ops-python-check"}),
                        },
                    }
                ),
                json.dumps({"type": "event_msg", "payload": {"type": "task_complete"}}),
            ]
        )
        + "\n",
        encoding="utf-8",
    )
    assert (
        orchestrate.main(
            [
                "--repo",
                str(root),
                "sessions",
                "--source",
                "codex-jsonl",
                "--date",
                "2026-06-20",
                "--sessions-root",
                str(sessions_root),
                "--json",
            ]
        )
        == 0
    )
    sessions_payload = json.loads(capsys.readouterr().out)
    assert sessions_payload["sessions"][0]["command_count"] == 1
    assert sessions_payload["sessions"][0]["validation_commands"] == ["pipenv run ops-python-check"]

    handback_path = tmp_path / "handback.md"
    handback_path.write_text(
        "\n".join(
            [
                "Status: passed",
                "Scope: ops package",
                "Files: packages/ops/src/ops/orchestrate/__init__.py",
                "Validation: pipenv run ops-python-check",
                "Risks: none identified",
            ]
        ),
        encoding="utf-8",
    )
    assert (
        orchestrate.main(
            [
                "--repo",
                str(root),
                "handback-check",
                "--path",
                str(handback_path),
                "--surface",
                "ops",
                "--json",
            ]
        )
        == 0
    )
    assert json.loads(capsys.readouterr().out)["status"] == "passed"

    packet_path = tmp_path / "packet.md"
    packet_path.write_text(
        "\n".join(
            [
                "Surface: ops",
                "Mode: inspect",
                "public/final-report.pdf unless --mode artifact-refresh",
                "report/assets/rendered/** unless listed in Allowed Files with --mode artifact-refresh",
                "pipenv run ops-python-check",
            ]
        ),
        encoding="utf-8",
    )
    assert orchestrate.main(["--repo", str(root), "packet-check", "--path", str(packet_path), "--json"]) == 0
    assert json.loads(capsys.readouterr().out)["status"] == "passed"

    assert orchestrate.main(["--repo", str(root), "docs-contract", "--json"]) == 0
    assert json.loads(capsys.readouterr().out)["status"] == "passed"

    assert (
        orchestrate.main(
            [
                "--repo",
                str(root),
                "ready-to-commit",
                "--dry-run",
                "--allow-unclassified",
                "--json",
            ]
        )
        == 0
    )
    ready_payload = json.loads(capsys.readouterr().out)
    assert ready_payload["status"] == "passed"
    assert "gates" in ready_payload
