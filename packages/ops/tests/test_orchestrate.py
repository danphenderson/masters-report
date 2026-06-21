import json
from pathlib import Path

from ops import orchestrate


def repo_root() -> Path:
    return Path(__file__).resolve().parents[3]


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
            "Please regenerate experiments or rewrite report assets as needed.",
        ]
    )

    result = orchestrate.packet_check(packet)

    assert result.status == "failed"
    assert "stale Julia root; use packages/stenotic-hemodynamics/" in result.issues
    assert "stale Python tooling root; use packages/ops/" in result.issues
    assert "stale report build wrapper; use pipenv run ops-build-report" in result.issues
    assert "missing final PDF artifact guardrail: public/final-report.pdf" in result.issues
    assert "missing rendered report asset guardrail: report/assets/rendered/**" in result.issues
    assert "missing current ops validation command" in result.issues
    assert "overbroad packet authority: avoid regenerate/rewrite/modify-as-needed language" in result.issues


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
