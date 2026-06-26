import subprocess
import sys
from pathlib import Path

from ops import julia_check, release_check


def test_julia_check_runs_repository_launcher(monkeypatch) -> None:
    calls: list[tuple[list[str], Path]] = []

    def fake_run(command, cwd, check):  # noqa: ANN001
        calls.append((command, cwd))
        return subprocess.CompletedProcess(command, 0)

    monkeypatch.setattr(julia_check.subprocess, "run", fake_run)

    root = Path(__file__).resolve().parents[3]
    assert julia_check.main(["--repo", str(root)]) == 0

    assert calls == [
        (
            ["packages/stenotic-hemodynamics/bin/julia-release", "packages/stenotic-hemodynamics/test/runtests.jl"],
            root,
        )
    ]


def test_julia_check_rejects_non_executable_launcher(tmp_path: Path) -> None:
    repo = tmp_path / "repo"
    launcher = repo / "packages/stenotic-hemodynamics/bin/julia-release"
    test_file = repo / "packages/stenotic-hemodynamics/test/runtests.jl"
    launcher.parent.mkdir(parents=True)
    test_file.parent.mkdir(parents=True)
    launcher.write_text("#!/bin/sh\n", encoding="utf-8")
    test_file.write_text("using Test\n", encoding="utf-8")

    assert julia_check.main(["--repo", str(repo)]) == 1


def test_release_check_uses_ops_validation_modules(monkeypatch, tmp_path: Path) -> None:
    commands: list[list[str]] = []

    def fake_run(command, cwd, text, capture_output, check):  # noqa: ANN001
        commands.append(command)
        stdout = "## master\n" if command[:3] == ["git", "status", "--short"] else ""
        return subprocess.CompletedProcess(command, 0, stdout=stdout, stderr="")

    monkeypatch.setattr(release_check.subprocess, "run", fake_run)

    root = Path(__file__).resolve().parents[3]
    assert release_check.main(["--repo", str(root), "--report-outdir", str(tmp_path), "--strict-status"]) == 0

    assert ["git", "diff", "--check"] in commands
    assert any(command[:3] == [release_check.sys.executable, "-m", "ops.julia_check"] for command in commands)
    assert any(command[:3] == [release_check.sys.executable, "-m", "ops.python_check"] for command in commands)
    assert any(command[:3] == [release_check.sys.executable, "-m", "ops.build_report"] for command in commands)


def test_release_check_patch_mode_allows_dirty_tree(monkeypatch, tmp_path: Path) -> None:
    commands: list[list[str]] = []

    def fake_run(command, cwd, text, capture_output, check):  # noqa: ANN001
        commands.append(command)
        stdout = "## master\n M README.md\n" if command[:3] == ["git", "status", "--short"] else ""
        return subprocess.CompletedProcess(command, 0, stdout=stdout, stderr="")

    monkeypatch.setattr(release_check.subprocess, "run", fake_run)

    root = Path(__file__).resolve().parents[3]
    assert release_check.main(["--repo", str(root), "--report-outdir", str(tmp_path), "--mode", "patch"]) == 0

    assert ["git", "diff", "--check"] in commands


def test_release_check_strict_status_rejects_dirty_tree(monkeypatch, tmp_path: Path) -> None:
    def fake_run(command, cwd, text, capture_output, check):  # noqa: ANN001
        return subprocess.CompletedProcess(command, 0, stdout="## master\n M README.md\n", stderr="")

    monkeypatch.setattr(release_check.subprocess, "run", fake_run)

    root = Path(__file__).resolve().parents[3]
    assert release_check.main(["--repo", str(root), "--report-outdir", str(tmp_path), "--strict-status"]) == 1


def test_release_check_release_mode_rejects_dirty_tree(monkeypatch, tmp_path: Path) -> None:
    def fake_run(command, cwd, text, capture_output, check):  # noqa: ANN001
        return subprocess.CompletedProcess(command, 0, stdout="## master\n M README.md\n", stderr="")

    monkeypatch.setattr(release_check.subprocess, "run", fake_run)

    root = Path(__file__).resolve().parents[3]
    assert release_check.main(["--repo", str(root), "--report-outdir", str(tmp_path), "--mode", "release"]) == 1


def test_release_hygiene_flags_tracked_byproducts_and_public_var(monkeypatch) -> None:
    monkeypatch.setattr(
        release_check,
        "tracked_paths",
        lambda repo: [
            "report/final-report.aux",
            "packages/ops/src/ops/__pycache__/module.pyc",
            "public/references/private-paper.pdf",
            "public/final-report.pdf",
            "public/var/logs/.gitkeep",
            "public/var/logs/run.summary.json",
        ],
    )
    monkeypatch.setattr(
        release_check,
        "git_status_short",
        lambda repo: "\n".join(["## master", "?? public/var/data/simulations/raw.xdmf"]),
    )

    issues = release_check.release_hygiene_issues(Path("/repo"))

    assert "tracked LaTeX byproduct: report/final-report.aux" in issues
    assert "tracked cache or Python byproduct: packages/ops/src/ops/__pycache__/module.pyc" in issues
    assert "tracked private reference mirror: public/references/private-paper.pdf" in issues
    assert "tracked final PDF artifact: public/final-report.pdf" in issues
    assert "tracked public/var artifact outside allowlist: public/var/logs/run.summary.json" in issues
    assert "dirty public/var artifact outside allowlist: public/var/data/simulations/raw.xdmf" in issues


def test_ops_python_check_coverage_mode_uses_coverage_py(tmp_path: Path, monkeypatch) -> None:
    seen: list[list[str]] = []

    def fake_run(command: list[str], repo: Path, env: dict[str, str]) -> int:
        seen.append(command)
        return 0

    import ops.python_check as python_check

    root = Path(__file__).resolve().parents[3]
    monkeypatch.setattr(python_check, "run", fake_run)

    status = python_check.main(["--repo", str(root), "--coverage", "--coverage-dir", str(tmp_path)])

    assert status == 0
    assert seen[0] == [
        sys.executable,
        "-m",
        "coverage",
        "run",
        "--source",
        "packages/ops/src/ops",
        "-m",
        "pytest",
        "packages/ops/tests",
    ]
    assert [sys.executable, "-m", "coverage", "xml", "-o", str(tmp_path / "coverage.xml")] in seen
    assert [sys.executable, "-m", "coverage", "json", "-o", str(tmp_path / "coverage.json")] in seen


def test_ops_julia_check_coverage_mode_writes_lcov(tmp_path: Path, monkeypatch) -> None:
    seen: dict[str, object] = {}

    def fake_run(command: list[str], repo: Path) -> int:
        seen["command"] = command
        seen["repo"] = repo
        (tmp_path / "raw").mkdir(parents=True, exist_ok=True)
        (tmp_path / "raw" / "julia-1.info").write_text(
            "TN:\nSF:/tmp/example.jl\nDA:1,1\nDA:2,0\nend_of_record\n", encoding="utf-8"
        )
        return 0

    import ops.julia_check as julia_check

    root = Path(__file__).resolve().parents[3]
    monkeypatch.setattr(julia_check, "run", fake_run)

    status = julia_check.main(["--repo", str(root), "--coverage", "--coverage-dir", str(tmp_path)])

    assert status == 0
    assert seen["repo"] == root
    assert seen["command"] == [
        "packages/stenotic-hemodynamics/bin/julia-release",
        f"--code-coverage={tmp_path / 'raw' / 'julia-%p.info'}",
        "packages/stenotic-hemodynamics/test/runtests.jl",
    ]
    assert (tmp_path / "lcov.info").read_text(encoding="utf-8") == (
        "TN:\nSF:/tmp/example.jl\nDA:1,1\nDA:2,0\nLH:1\nLF:2\nend_of_record\n"
    )
    assert (tmp_path / "coverage-summary.json").is_file()
