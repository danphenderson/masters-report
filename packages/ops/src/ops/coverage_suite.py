"""Run on-demand coverage reporting for Python ops and Julia validation suites."""

from __future__ import annotations

import argparse
import json
import subprocess
import sys
from pathlib import Path

DEFAULT_COVERAGE_DIR = Path("tmp/coverage")


def repo_root() -> Path:
    path = Path(__file__).resolve()
    for parent in path.parents:
        if (parent / "Pipfile").is_file() and (parent / "packages" / "ops").is_dir():
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


def run(command: list[str], repo: Path) -> int:
    print(f"+ {' '.join(command)}", flush=True)
    return subprocess.run(command, cwd=repo, check=False).returncode


def write_summary(path: Path, statuses: dict[str, int], coverage_dir: Path, repo: Path) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    payload = {
        "status": "passed" if all(status == 0 for status in statuses.values()) else "failed",
        "suites": {
            "ops": {
                "returncode": statuses["ops"],
                "coverage_xml": display_path(repo, coverage_dir / "ops" / "coverage.xml"),
                "coverage_json": display_path(repo, coverage_dir / "ops" / "coverage.json"),
            },
            "julia": {
                "returncode": statuses["julia"],
                "lcov": display_path(repo, coverage_dir / "julia" / "lcov.info"),
                "summary_json": display_path(repo, coverage_dir / "julia" / "coverage-summary.json"),
            },
        },
    }
    path.write_text(json.dumps(payload, indent=2, sort_keys=True) + "\n", encoding="utf-8")


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--repo", type=Path, default=None, help="repository root; detected by default")
    parser.add_argument(
        "--coverage-dir",
        type=Path,
        default=DEFAULT_COVERAGE_DIR,
        help=f"coverage artifact root relative to the repository root (default: {DEFAULT_COVERAGE_DIR})",
    )
    args = parser.parse_args(argv)

    repo = args.repo.expanduser().resolve() if args.repo is not None else repo_root()
    coverage_dir = resolve_repo_path(repo, args.coverage_dir)
    commands = {
        "ops": [
            sys.executable,
            "-m",
            "ops.python_check",
            "--repo",
            str(repo),
            "--coverage",
            "--coverage-dir",
            display_path(repo, coverage_dir / "ops"),
        ],
        "julia": [
            sys.executable,
            "-m",
            "ops.julia_check",
            "--repo",
            str(repo),
            "--coverage",
            "--coverage-dir",
            display_path(repo, coverage_dir / "julia"),
        ],
    }

    statuses = {suite: run(command, repo) for suite, command in commands.items()}
    write_summary(coverage_dir / "full-suite-summary.json", statuses, coverage_dir, repo)
    return 0 if all(status == 0 for status in statuses.values()) else 1


if __name__ == "__main__":
    raise SystemExit(main())
