"""Git status parsing and path classification."""

from __future__ import annotations

import subprocess
from pathlib import Path

from .models import StatusEntry, StatusReport
from .policy import SURFACE_PREFIXES, SURFACES


def repo_root(repo: Path | None = None) -> Path:
    if repo is not None:
        return repo.expanduser().resolve()
    result = subprocess.run(
        ["git", "rev-parse", "--show-toplevel"],
        cwd=Path.cwd(),
        text=True,
        capture_output=True,
        check=False,
    )
    if result.returncode == 0 and result.stdout.strip():
        return Path(result.stdout.strip()).resolve()
    return Path.cwd().resolve()


def run_git_status(repo: Path) -> str:
    result = subprocess.run(
        ["git", "status", "--short", "--branch"],
        cwd=repo,
        text=True,
        capture_output=True,
        check=False,
    )
    if result.returncode != 0:
        raise RuntimeError(result.stderr.strip() or "git status failed")
    return result.stdout


def normalize_status_path(raw: str) -> tuple[str, str]:
    path = raw.strip()
    if " -> " not in path:
        return path, ""
    original, renamed = path.split(" -> ", 1)
    return renamed.strip(), original.strip()


def normalize_repo_path(path: str) -> str:
    normalized = path.strip()
    while normalized.startswith("./"):
        normalized = normalized[2:]
    return normalized


def parse_status(text: str) -> StatusReport:
    branch = ""
    entries: list[StatusEntry] = []
    for line in text.splitlines():
        if not line:
            continue
        if line.startswith("## "):
            branch = line[3:].strip()
            continue
        code = line[:2]
        raw_path = line[3:] if len(line) > 3 else ""
        path, original_path = normalize_status_path(raw_path)
        surface = classify_path(path)
        if surface == "unknown" and original_path:
            surface = classify_path(original_path)
        protected = is_protected_path(path) or (bool(original_path) and is_protected_path(original_path))
        entries.append(
            StatusEntry(code=code, path=path, surface=surface, protected=protected, original_path=original_path)
        )

    dirty_by_surface = {surface: 0 for surface in (*SURFACES, "unknown")}
    for entry in entries:
        dirty_by_surface[entry.surface] = dirty_by_surface.get(entry.surface, 0) + 1

    protected_paths = tuple(entry.path for entry in entries if entry.protected)
    unclassified_paths = tuple(entry.path for entry in entries if entry.surface == "unknown")
    return StatusReport(
        branch=branch,
        entries=tuple(entries),
        dirty_by_surface={key: value for key, value in dirty_by_surface.items() if value},
        protected_paths=protected_paths,
        unclassified_paths=unclassified_paths,
    )


def classify_path(path: str) -> str:
    normalized = normalize_repo_path(path)
    for surface, prefixes in SURFACE_PREFIXES.items():
        for prefix in prefixes:
            if prefix.endswith("/"):
                if normalized.startswith(prefix):
                    return surface
            elif normalized == prefix:
                return surface
    return "unknown"


def is_protected_path(path: str) -> bool:
    normalized = normalize_repo_path(path)
    suffix = Path(normalized).suffix.lower()
    return (
        normalized == "public/final-report.pdf"
        or normalized.startswith("report/assets/rendered/")
        or (normalized.startswith("public/references/") and suffix in {".pdf", ".html", ".htm"})
        or normalized.startswith("public/var/data/simulations/")
        or normalized.startswith("tmp/simulations/output/")
    )


def status_report(repo: Path) -> StatusReport:
    return parse_status(run_git_status(repo))
