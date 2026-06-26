from __future__ import annotations

import json
import sys
from pathlib import Path

import ops.coverage_suite as coverage_suite


def test_coverage_suite_runs_both_lanes_and_writes_summary(tmp_path: Path, monkeypatch) -> None:
    seen: list[list[str]] = []

    def fake_run(command: list[str], repo: Path) -> int:
        seen.append(command)
        return 0

    root = Path(__file__).resolve().parents[3]
    monkeypatch.setattr(coverage_suite, "run", fake_run)

    status = coverage_suite.main(["--repo", str(root), "--coverage-dir", str(tmp_path)])

    assert status == 0
    assert len(seen) == 2
    assert seen[0] == [
        sys.executable,
        "-m",
        "ops.python_check",
        "--repo",
        str(root),
        "--coverage",
        "--coverage-dir",
        str(tmp_path / "ops"),
    ]
    assert seen[1] == [
        sys.executable,
        "-m",
        "ops.julia_check",
        "--repo",
        str(root),
        "--coverage",
        "--coverage-dir",
        str(tmp_path / "julia"),
    ]
    summary = json.loads((tmp_path / "full-suite-summary.json").read_text(encoding="utf-8"))
    assert summary["status"] == "passed"
    assert summary["suites"]["ops"]["returncode"] == 0
    assert summary["suites"]["julia"]["returncode"] == 0


def test_coverage_suite_attempts_both_lanes_before_failing(tmp_path: Path, monkeypatch) -> None:
    statuses = iter([7, 0])
    seen: list[list[str]] = []

    def fake_run(command: list[str], repo: Path) -> int:
        seen.append(command)
        return next(statuses)

    root = Path(__file__).resolve().parents[3]
    monkeypatch.setattr(coverage_suite, "run", fake_run)

    status = coverage_suite.main(["--repo", str(root), "--coverage-dir", str(tmp_path)])

    assert status == 1
    assert len(seen) == 2
    summary = json.loads((tmp_path / "full-suite-summary.json").read_text(encoding="utf-8"))
    assert summary["status"] == "failed"
    assert summary["suites"]["ops"]["returncode"] == 7
    assert summary["suites"]["julia"]["returncode"] == 0
