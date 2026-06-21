"""Small git-state helpers shared by ops entry points."""

from __future__ import annotations

import subprocess
from pathlib import Path
from typing import Any


def run_git(repo: Path, args: list[str]) -> subprocess.CompletedProcess[str]:
    return subprocess.run(["git", *args], cwd=repo, text=True, capture_output=True, check=False)


def git_sha(repo: Path) -> str:
    result = run_git(repo, ["rev-parse", "HEAD"])
    if result.returncode != 0:
        return "unknown"
    return result.stdout.strip() or "unknown"


def git_status_short(repo: Path) -> str:
    result = run_git(repo, ["status", "--short", "--branch", "--untracked-files=all"])
    if result.returncode != 0:
        raise RuntimeError(result.stderr.strip() or "git status failed")
    return result.stdout


def dirty_status_lines(status_stdout: str) -> list[str]:
    return [line for line in status_stdout.splitlines() if line and not line.startswith("## ")]


def git_snapshot(repo: Path) -> dict[str, Any]:
    status_result = run_git(repo, ["status", "--short", "--branch", "--untracked-files=all"])
    if status_result.returncode != 0:
        return {
            "git_sha": git_sha(repo),
            "branch": "",
            "status_lines": [],
            "dirty": False,
            "dirty_count": 0,
            "available": False,
            "error": status_result.stderr.strip() or "git status failed",
        }

    status_lines = status_result.stdout.splitlines()
    branch = ""
    for line in status_lines:
        if line.startswith("## "):
            branch = line[3:].strip()
            break
    dirty_lines = dirty_status_lines(status_result.stdout)
    return {
        "git_sha": git_sha(repo),
        "branch": branch,
        "status_lines": status_lines,
        "dirty": bool(dirty_lines),
        "dirty_count": len(dirty_lines),
        "available": True,
    }
