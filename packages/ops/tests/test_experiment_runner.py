import json
from pathlib import Path

from ops import experiment_runner


def test_build_command_uses_repo_relative_launcher(tmp_path: Path) -> None:
    repo = tmp_path / "repo"
    launcher = repo / "packages/julia/bin/stenosis-hemodynamics"
    launcher.parent.mkdir(parents=True)
    launcher.write_text("#!/bin/sh\n", encoding="utf-8")
    launcher.chmod(0o755)

    command = experiment_runner.build_command(repo, "packages/julia/bin/stenosis-hemodynamics", ["benchmark"])

    assert command == ["packages/julia/bin/stenosis-hemodynamics", "benchmark"]


def test_julia_telemetry_parser_emits_structured_event() -> None:
    parser = experiment_runner.JuliaTelemetryParser()
    lines = [
        "\u250c Info: simulation completed\n",
        '\u2502   event = "simulation_completed"\n',
        '\u2502   stage = "simulate"\n',
        "\u2502   elapsed_s = 0.25\n",
        "\u2514   rows = 12\n",
    ]

    parsed = []
    for line in lines:
        parsed.extend(parser.feed(line))

    assert parsed == [
        {
            "event": "simulation_completed",
            "level": "info",
            "message": "simulation completed",
            "source": "julia-telemetry",
            "fields": {
                "event": "simulation_completed",
                "stage": "simulate",
                "elapsed_s": 0.25,
                "rows": 12,
            },
        }
    ]


def test_experiment_runner_streams_jsonl_and_summary(tmp_path: Path) -> None:
    repo = tmp_path / "repo"
    repo.mkdir()
    launcher = repo / "fake-julia-cli"
    launcher.write_text(
        "\n".join(
            [
                "#!/bin/sh",
                "echo benchmark_manifest,tmp/simulations/output/package_benchmark/smoke/manifest.json",
                "echo benchmark_csv,tmp/simulations/output/package_benchmark/smoke/case_results.csv",
                "echo stderr-status >&2",
                "printf '\\342\\224\\214 Info: package benchmark completed\\n' >&2",
                "printf '\\342\\224\\202   event = \"package_benchmark_completed\"\\n' >&2",
                "printf '\\342\\224\\202   stage = \"package_benchmark\"\\n' >&2",
                "printf '\\342\\224\\224   status = \"ok\"\\n' >&2",
            ]
        )
        + "\n",
        encoding="utf-8",
    )
    launcher.chmod(0o755)
    log_dir = repo / "public/var/logs"

    status = experiment_runner.main(
        [
            "--repo",
            str(repo),
            "--launcher",
            str(launcher),
            "--log-dir",
            str(log_dir),
            "--run-id",
            "test-run",
            "--no-stream",
            "benchmark",
            "--profile",
            "smoke",
        ]
    )

    assert status == 0
    jsonl_path = log_dir / "test-run.jsonl"
    summary_path = log_dir / "test-run.summary.json"
    records = [json.loads(line) for line in jsonl_path.read_text(encoding="utf-8").splitlines()]
    summary = json.loads(summary_path.read_text(encoding="utf-8"))

    assert any(record["event"] == "process_started" for record in records)
    assert any(
        record["event"] == "julia_output_artifact" and record["key"] == "benchmark_manifest" for record in records
    )
    assert any(record["event"] == "package_benchmark_completed" for record in records)
    assert summary["status"] == "passed"
    assert summary["dirty_policy"] == "warn"
    assert summary["git_snapshot_start"]["available"] is False
    assert summary["git_snapshot_end"]["available"] is False
    assert summary["output_artifacts"]["benchmark_manifest"] == [
        "tmp/simulations/output/package_benchmark/smoke/manifest.json"
    ]
    assert summary["event_counts"]["julia_output_artifact"] == 2


def test_experiment_runner_reports_missing_command(tmp_path: Path) -> None:
    repo = tmp_path / "repo"
    launcher = repo / "fake-julia-cli"
    launcher.parent.mkdir(parents=True)
    launcher.write_text("#!/bin/sh\n", encoding="utf-8")
    launcher.chmod(0o755)

    assert experiment_runner.main(["--repo", str(repo), "--launcher", str(launcher)]) == 2


def test_experiment_runner_rejects_non_executable_launcher(tmp_path: Path) -> None:
    repo = tmp_path / "repo"
    launcher = repo / "fake-julia-cli"
    launcher.parent.mkdir(parents=True)
    launcher.write_text("#!/bin/sh\n", encoding="utf-8")

    assert experiment_runner.main(["--repo", str(repo), "--launcher", str(launcher), "benchmark"]) == 2


def test_experiment_runner_dirty_policy_fail_stops_before_process(monkeypatch, tmp_path: Path) -> None:
    repo = tmp_path / "repo"
    repo.mkdir()
    launcher = repo / "fake-julia-cli"
    launcher.write_text("#!/bin/sh\n", encoding="utf-8")
    launcher.chmod(0o755)

    monkeypatch.setattr(
        experiment_runner,
        "git_snapshot",
        lambda repo: {
            "git_sha": "abc123",
            "branch": "master",
            "status_lines": ["## master", " M README.md"],
            "dirty": True,
            "dirty_count": 1,
            "available": True,
        },
    )

    def fail_stream_process(*args, **kwargs):  # noqa: ANN001
        raise AssertionError("dirty-policy fail should not start a process")

    monkeypatch.setattr(experiment_runner, "stream_process", fail_stream_process)

    assert (
        experiment_runner.main(
            ["--repo", str(repo), "--launcher", str(launcher), "--dirty-policy", "fail", "benchmark"]
        )
        == 3
    )
