"""Run the Python operations package validation checks."""

from __future__ import annotations

import argparse
import os
import subprocess
import sys
from pathlib import Path


def repo_root() -> Path:
    path = Path(__file__).resolve()
    for parent in path.parents:
        if (parent / "packages" / "ops").is_dir() and (parent / "report").is_dir():
            return parent
    raise RuntimeError("could not locate repository root")


def run(command: list[str], repo: Path, env: dict[str, str]) -> int:
    return subprocess.run(command, cwd=repo, env=env, check=False).returncode


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--repo", type=Path, default=None, help="repository root; detected by default")
    args = parser.parse_args(argv)

    repo = args.repo.resolve() if args.repo is not None else repo_root()
    package_root = repo / "packages" / "ops"
    env = os.environ.copy()
    env["RUFF_CACHE_DIR"] = str(package_root / ".ruff_cache")

    commands = [
        [sys.executable, "-m", "pytest", "packages/ops/tests"],
        [sys.executable, "-m", "ruff", "check", "packages/ops"],
        [sys.executable, "-m", "black", "--check", "packages/ops"],
    ]
    for command in commands:
        status = run(command, repo, env)
        if status != 0:
            return status
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
