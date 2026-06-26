"""Run the Python operations package validation checks."""

from __future__ import annotations

import argparse
import os
import shutil
import subprocess
import sys
from pathlib import Path


def repo_root() -> Path:
    path = Path(__file__).resolve()
    for parent in path.parents:
        if (parent / "packages" / "ops").is_dir() and (parent / "report").is_dir():
            return parent
    raise RuntimeError("could not locate repository root")


def resolve_repo_path(repo: Path, path: Path) -> Path:
    path = path.expanduser()
    if path.is_absolute():
        return path.resolve()
    return (repo / path).resolve()


def display_path(repo: Path, path: Path) -> str:
    try:
        return path.relative_to(repo).as_posix()
    except ValueError:
        return path.as_posix()


def run(command: list[str], repo: Path, env: dict[str, str]) -> int:
    return subprocess.run(command, cwd=repo, env=env, check=False).returncode


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--repo", type=Path, default=None, help="repository root; detected by default")
    parser.add_argument("--coverage", action="store_true", help="run pytest under coverage.py and write reports")
    parser.add_argument(
        "--coverage-dir",
        type=Path,
        default=Path("tmp/coverage/ops"),
        help="coverage output directory relative to the repository root",
    )
    args = parser.parse_args(argv)

    repo = args.repo.resolve() if args.repo is not None else repo_root()
    package_root = repo / "packages" / "ops"
    env = os.environ.copy()
    env["RUFF_CACHE_DIR"] = str(package_root / ".ruff_cache")

    pytest_command = [sys.executable, "-m", "pytest", "packages/ops/tests"]
    if args.coverage:
        coverage_dir = resolve_repo_path(repo, args.coverage_dir)
        if coverage_dir.exists():
            shutil.rmtree(coverage_dir)
        coverage_dir.mkdir(parents=True, exist_ok=True)
        env["COVERAGE_FILE"] = str(coverage_dir / ".coverage")
        pytest_command = [
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

    commands = [
        pytest_command,
        [sys.executable, "-m", "ruff", "check", "packages/ops"],
        [sys.executable, "-m", "black", "--check", "packages/ops"],
    ]
    for command in commands:
        status = run(command, repo, env)
        if status != 0:
            return status

    if args.coverage:
        xml_status = run(
            [sys.executable, "-m", "coverage", "xml", "-o", display_path(repo, coverage_dir / "coverage.xml")],
            repo,
            env,
        )
        if xml_status != 0:
            return xml_status
        json_status = run(
            [sys.executable, "-m", "coverage", "json", "-o", display_path(repo, coverage_dir / "coverage.json")],
            repo,
            env,
        )
        if json_status != 0:
            return json_status
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
