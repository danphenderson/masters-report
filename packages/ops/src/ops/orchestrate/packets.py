"""Dispatch and delegated-review packet rendering."""

from __future__ import annotations

from pathlib import Path
from typing import Sequence

from .policy import (
    PROFILE_GUIDANCE,
    REQUIRED_HANDBACK_SECTIONS,
    blocked_artifacts_for,
    commands_for,
    handback_sections_for,
    review_blocked_artifacts,
    review_spec,
    validate_dispatch_request,
)
from .status import status_report


def dispatch_packet(
    repo: Path, surface: str, mode: str, objective: str, files: Sequence[str], profile: str = "generic"
) -> str:
    validate_dispatch_request(mode, files)
    report = status_report(repo)
    allowed_files = list(files) or [
        f"No concrete paths supplied; stay in inspect mode until exact {surface} files are named."
    ]
    lines = [
        "# Ops Dispatch Packet",
        "",
        f"Branch: {report.branch or '<unknown>'}",
        f"Surface: {surface}",
        f"Mode: {mode}",
        f"Profile: {profile}",
        f"Objective: {objective}",
        "",
        "## Allowed Files",
        *[f"- {path}" for path in allowed_files],
        "",
        "## Blocked Artifacts",
        *[f"- {path}" for path in blocked_artifacts_for(surface, mode)],
        "",
        "## Operating Rules",
        "- Re-anchor with `git status --short --branch` before making claims about the tree.",
        "- Use repository files and local validation outputs as evidence; do not infer from stale summaries.",
        "- Keep edits path-scoped and preserve unrelated dirty work.",
        "- Do not install hooks, spawn background automation, or create persistent orchestration receipts.",
    ]
    if PROFILE_GUIDANCE[profile]:
        lines.extend(
            [
                "",
                "## Profile Guidance",
                *[f"- {item}" for item in PROFILE_GUIDANCE[profile]],
            ]
        )
    lines.extend(
        [
            "",
            "## Validation",
            *[f"- {command}" for command in commands_for(surface, mode)],
            "",
            "## Required Handback",
            *[f"- {section}" for section in handback_sections_for(profile)],
        ]
    )
    return "\n".join(lines) + "\n"


def dispatch_payload(
    repo: Path, surface: str, mode: str, objective: str, files: Sequence[str], profile: str = "generic"
) -> dict[str, object]:
    validate_dispatch_request(mode, files)
    report = status_report(repo)
    return {
        "branch": report.branch,
        "surface": surface,
        "mode": mode,
        "profile": profile,
        "objective": objective,
        "allowed_files": list(files),
        "blocked_artifacts": list(blocked_artifacts_for(surface, mode)),
        "profile_guidance": list(PROFILE_GUIDANCE[profile]),
        "validation": list(commands_for(surface, mode)),
        "required_handback": list(handback_sections_for(profile)),
        "dirty_by_surface": report.dirty_by_surface,
        "protected_paths": list(report.protected_paths),
        "unclassified_paths": list(report.unclassified_paths),
    }


def review_packet(repo: Path, commit: str, lane: str) -> str:
    report = status_report(repo)
    spec = review_spec(lane)
    lines = [
        "# Ops Review Packet",
        "",
        "Start with: `git status --short --branch`",
        f"Review commit: {commit}",
        f"Branch: {report.branch or '<unknown>'}",
        f"Lane: {lane}",
        f"Surfaces: {', '.join(spec.surfaces)}",
        f"Mode: {spec.mode}",
        f"Scope: {spec.scope}",
        "",
        "## Allowed Files",
        *[f"- {path}" for path in spec.files],
        "",
        "## Forbidden Mutations",
        "- Do not edit, stage, delete, or generate patches during review.",
        "- Do not refresh tracked artifacts or mutate ignored raw-data/output directories.",
        "- Do not install hooks, spawn background automation, or create persistent orchestration receipts.",
        "",
        "## Blocked Artifacts",
        *[f"- {path}" for path in review_blocked_artifacts(spec)],
        "",
        "## Expected Validation",
        *[f"- {command}" for command in spec.validation],
        "",
        "## Required Handback",
        *[f"- {section}" for section in REQUIRED_HANDBACK_SECTIONS],
        "",
        "## Blocker Rules",
        *[f"- {rule}" for rule in spec.blocker_rules],
    ]
    return "\n".join(lines) + "\n"


def review_payload(repo: Path, commit: str, lane: str) -> dict[str, object]:
    report = status_report(repo)
    spec = review_spec(lane)
    return {
        "branch": report.branch,
        "commit": commit,
        "lane": lane,
        "surfaces": list(spec.surfaces),
        "mode": spec.mode,
        "scope": spec.scope,
        "allowed_files": list(spec.files),
        "forbidden_mutations": [
            "Do not edit, stage, delete, or generate patches during review.",
            "Do not refresh tracked artifacts or mutate ignored raw-data/output directories.",
            "Do not install hooks, spawn background automation, or create persistent orchestration receipts.",
        ],
        "blocked_artifacts": list(review_blocked_artifacts(spec)),
        "validation": list(spec.validation),
        "required_handback": list(REQUIRED_HANDBACK_SECTIONS),
        "blocker_rules": list(spec.blocker_rules),
        "dirty_by_surface": report.dirty_by_surface,
        "protected_paths": list(report.protected_paths),
    }
