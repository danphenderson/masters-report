"""Run Julia package validation through the Python ops command surface."""

from __future__ import annotations

import argparse
import os
import subprocess
import sys
from pathlib import Path

DEFAULT_LAUNCHER = "packages/stenotic-hemodynamics/bin/julia-release"
DEFAULT_TEST_FILE = "packages/stenotic-hemodynamics/test/runtests.jl"


def repo_root() -> Path:
    path = Path(__file__).resolve()
    for parent in path.parents:
        if (parent / "packages" / "stenotic-hemodynamics").is_dir() and (parent / "packages" / "ops").is_dir():
            return parent
    raise RuntimeError("could not locate repository root")


def resolve_repo_path(repo: Path, path: str) -> Path:
    candidate = Path(path).expanduser()
    if candidate.is_absolute():
        return candidate.resolve()
    return (repo / candidate).resolve()


def display_path(repo: Path, path: Path) -> str:
    try:
        return path.relative_to(repo).as_posix()
    except ValueError:
        return path.as_posix()


def run(command: list[str], repo: Path) -> int:
    print(f"+ {' '.join(command)}", flush=True)
    return subprocess.run(command, cwd=repo, check=False).returncode


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--repo", type=Path, default=None, help="repository root; detected by default")
    parser.add_argument(
        "--launcher",
        default=DEFAULT_LAUNCHER,
        help=f"Julia release launcher relative to the repository root (default: {DEFAULT_LAUNCHER})",
    )
    parser.add_argument(
        "--test-file",
        default=DEFAULT_TEST_FILE,
        help=f"Julia test entrypoint relative to the repository root (default: {DEFAULT_TEST_FILE})",
    )
    parser.add_argument("julia_args", nargs=argparse.REMAINDER, help="extra arguments appended after the test file")
    args = parser.parse_args(argv)

    repo = args.repo.expanduser().resolve() if args.repo is not None else repo_root()
    launcher = resolve_repo_path(repo, args.launcher)
    test_file = resolve_repo_path(repo, args.test_file)
    missing = [path for path in (launcher, test_file) if not path.exists()]
    if missing:
        for path in missing:
            print(f"missing required Julia validation path: {path}", file=sys.stderr)
        return 1
    if not launcher.is_file():
        print(f"Julia validation launcher is not a file: {launcher}", file=sys.stderr)
        return 1
    if not os.access(launcher, os.X_OK):
        print(f"Julia validation launcher is not executable: {launcher}", file=sys.stderr)
        return 1
    if not test_file.is_file():
        print(f"Julia validation test entrypoint is not a file: {test_file}", file=sys.stderr)
        return 1

    command = [display_path(repo, launcher), display_path(repo, test_file), *args.julia_args]
    return run(command, repo)


if __name__ == "__main__":
    raise SystemExit(main())
