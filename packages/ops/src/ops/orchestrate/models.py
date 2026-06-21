"""Data models for orchestration helpers."""

from __future__ import annotations

from dataclasses import dataclass


@dataclass(frozen=True)
class StatusEntry:
    code: str
    path: str
    surface: str
    protected: bool
    original_path: str = ""


@dataclass(frozen=True)
class StatusReport:
    branch: str
    entries: tuple[StatusEntry, ...]
    dirty_by_surface: dict[str, int]
    protected_paths: tuple[str, ...]
    unclassified_paths: tuple[str, ...]


@dataclass(frozen=True)
class CheckResult:
    status: str
    issues: tuple[str, ...]


@dataclass(frozen=True)
class ReviewLaneSpec:
    surfaces: tuple[str, ...]
    mode: str
    scope: str
    files: tuple[str, ...]
    validation: tuple[str, ...]
    blocker_rules: tuple[str, ...]
