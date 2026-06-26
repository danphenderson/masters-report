"""Documentation contract checks for the orchestration workflow."""

from __future__ import annotations

import re
from pathlib import Path
from typing import Sequence

from .models import CheckResult
from .policy import (
    COMMANDS,
    DOC_CONTRACT_PATHS,
    HISTORICAL_PATH_PREFIXES,
    PROFILES,
    STALE_PATH_CHECK_PATHS,
    STALE_PATH_PATTERNS,
)
from .status import normalize_repo_path

GENERATED_DOCS_DIRS = frozenset({"node_modules", "build", ".docusaurus"})


def is_historical_path(path: str) -> bool:
    normalized = normalize_repo_path(path)
    return any(normalized.startswith(prefix) for prefix in HISTORICAL_PATH_PREFIXES)


def is_generated_docs_path(path: Path) -> bool:
    return bool(GENERATED_DOCS_DIRS.intersection(path.parts))


def default_stale_path_check_paths(repo: Path) -> tuple[str, ...]:
    paths = list(STALE_PATH_CHECK_PATHS)
    public_docs = repo / "public" / "docs"
    if public_docs.is_dir():
        paths.extend(
            path.relative_to(repo).as_posix()
            for path in sorted(public_docs.rglob("*.md"))
            if not is_generated_docs_path(path.relative_to(public_docs))
        )
    return tuple(dict.fromkeys(paths))


def stale_path_issues(repo: Path, paths: Sequence[str] | None = None) -> tuple[str, ...]:
    issues: list[str] = []
    for relative in paths if paths is not None else default_stale_path_check_paths(repo):
        normalized = normalize_repo_path(relative)
        if is_historical_path(normalized):
            continue
        path = repo / normalized
        if not path.exists() or path.is_dir():
            continue
        for line_number, line in enumerate(path.read_text(encoding="utf-8").splitlines(), start=1):
            for label, pattern in STALE_PATH_PATTERNS:
                match = pattern.search(line)
                if match is None:
                    continue
                issues.append(f"stale active path reference in {normalized}:{line_number}: {match.group(0)} ({label})")
    return tuple(issues)


def markdown_layout_issues(repo: Path) -> tuple[str, ...]:
    docs_root = repo / "public" / "docs"
    markdown_root = docs_root / "markdown"
    if not docs_root.is_dir():
        return ()

    issues: list[str] = []
    for path in sorted(docs_root.rglob("*.md")):
        if is_generated_docs_path(path.relative_to(docs_root)):
            continue
        try:
            path.relative_to(markdown_root)
        except ValueError:
            issues.append(
                "public docs Markdown must live under public/docs/markdown: " f"{path.relative_to(repo).as_posix()}"
            )
    return tuple(issues)


def docs_contract(repo: Path) -> CheckResult:
    issues: list[str] = []
    combined_parts: list[str] = []
    for relative in DOC_CONTRACT_PATHS:
        path = repo / relative
        if not path.exists():
            issues.append(f"missing docs contract file: {relative}")
            continue
        combined_parts.append(path.read_text(encoding="utf-8"))
    combined = "\n".join(combined_parts)
    for command in COMMANDS:
        needle = f"ops-orchestrate {command}"
        if needle not in combined:
            issues.append(f"missing documented command: {needle}")
    for profile in PROFILES:
        if profile not in combined:
            issues.append(f"missing documented profile: {profile}")
    lower = re.sub(r"\s+", " ", combined.lower())
    for phrase in (
        "tracked pre-commit config is allowed; local hook installation is explicit",
        "no background automation",
        "no persistent orchestration receipts",
    ):
        if phrase not in lower:
            issues.append(f"missing orchestration limit: {phrase}")
    for phrase in ("github issues", "ops-orchestrate status"):
        if phrase not in lower:
            issues.append(f"missing coordination guidance: {phrase}")
    issues.extend(markdown_layout_issues(repo))
    issues.extend(stale_path_issues(repo))
    return CheckResult(status="failed" if issues else "passed", issues=tuple(issues))
