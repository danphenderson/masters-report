"""Commit-readiness validation planning and execution."""

from __future__ import annotations

import shlex
import subprocess
from dataclasses import dataclass
from pathlib import Path
from typing import Iterable

from .models import StatusReport

DEFAULT_REPORT_OUTDIR = Path("/tmp/masters-report-build")


@dataclass(frozen=True)
class ReadyGate:
    name: str
    command: tuple[str, ...]
    surface: str


@dataclass(frozen=True)
class ReadyGateResult:
    name: str
    command: tuple[str, ...]
    returncode: int


@dataclass(frozen=True)
class ReadyToCommitResult:
    status: str
    issues: tuple[str, ...]
    gates: tuple[ReadyGate, ...]
    results: tuple[ReadyGateResult, ...]
    dirty_surfaces: tuple[str, ...]


def shell_command(command: Iterable[str]) -> str:
    return shlex.join(tuple(command))


def dirty_surfaces(report: StatusReport) -> tuple[str, ...]:
    return tuple(sorted({entry.surface for entry in report.entries if entry.surface != "unknown"}))


def _requires_julia_validation(path: str) -> bool:
    if not path.startswith("packages/stenotic-hemodynamics/"):
        return True
    return Path(path).suffix.lower() not in {".md", ".txt"}


def _requires_report_validation(path: str) -> bool:
    if path == "report/TODO.md":
        return False
    return Path(path).suffix.lower() not in {".md", ".txt"}


def ready_to_commit_issues(
    report: StatusReport,
    *,
    allow_protected_artifacts: bool = True,
    allow_unclassified: bool = False,
) -> tuple[str, ...]:
    issues: list[str] = []
    unclassified_paths = tuple(path for path in report.unclassified_paths if path not in report.protected_paths)
    if unclassified_paths and not allow_unclassified:
        unknown = ", ".join(unclassified_paths)
        issues.append(f"unclassified dirty paths require --allow-unclassified after ownership review: {unknown}")
    return tuple(issues)


def _append_unique(gates: list[ReadyGate], gate: ReadyGate) -> None:
    if all(existing.command != gate.command for existing in gates):
        gates.append(gate)


def ready_to_commit_gates(
    report: StatusReport,
    *,
    report_outdir: Path = DEFAULT_REPORT_OUTDIR,
    all_gates: bool = False,
) -> tuple[ReadyGate, ...]:
    if all_gates:
        return (
            ReadyGate(
                "aggregate patch gate",
                (
                    "pipenv",
                    "run",
                    "ops-release-check",
                    "--mode",
                    "patch",
                    "--report-outdir",
                    report_outdir.as_posix(),
                ),
                "aggregate",
            ),
        )

    surfaces = set(dirty_surfaces(report))
    gates = [
        ReadyGate("unstaged diff check", ("git", "diff", "--check"), "base"),
        ReadyGate("staged diff check", ("git", "diff", "--cached", "--check"), "base"),
        ReadyGate("orchestration docs contract", ("pipenv", "run", "ops-orchestrate", "docs-contract"), "base"),
        ReadyGate("lightweight pre-commit hooks", ("pipenv", "run", "pre-commit", "run", "--all-files"), "base"),
    ]

    if "ops" in surfaces:
        _append_unique(gates, ReadyGate("Python ops validation", ("pipenv", "run", "ops-python-check"), "ops"))
    julia_validation_required = any(
        entry.surface == "julia" and _requires_julia_validation(entry.path) for entry in report.entries
    )
    if julia_validation_required:
        _append_unique(gates, ReadyGate("Julia package validation", ("pipenv", "run", "ops-julia-check"), "julia"))
    report_validation_required = any(
        entry.surface == "report" and _requires_report_validation(entry.path) for entry in report.entries
    )
    if report_validation_required or "assets" in surfaces or report.protected_paths:
        _append_unique(
            gates,
            ReadyGate("report prose audit", ("pipenv", "run", "ops-audit-report-prose", "--json"), "report"),
        )
        _append_unique(
            gates,
            ReadyGate(
                "report validation build",
                (
                    "pipenv",
                    "run",
                    "ops-build-report",
                    "--outdir",
                    report_outdir.as_posix(),
                    "--no-sync-final-pdf",
                ),
                "report",
            ),
        )
    if "references" in surfaces:
        _append_unique(
            gates,
            ReadyGate("reference audit", ("pipenv", "run", "ops-audit-references"), "references"),
        )

    return tuple(gates)


def run_ready_to_commit_gates(
    gates: tuple[ReadyGate, ...],
    repo: Path,
    *,
    stream: bool = True,
) -> tuple[ReadyGateResult, ...]:
    results: list[ReadyGateResult] = []
    for gate in gates:
        if stream:
            print(f"\n==> {gate.name}", flush=True)
            print(f"+ {shell_command(gate.command)}", flush=True)
        completed = subprocess.run(gate.command, cwd=repo, text=True, capture_output=not stream, check=False)
        result = ReadyGateResult(gate.name, gate.command, completed.returncode)
        results.append(result)
        if completed.returncode != 0:
            break
    return tuple(results)


def ready_to_commit_result(
    report: StatusReport,
    *,
    repo: Path,
    report_outdir: Path = DEFAULT_REPORT_OUTDIR,
    all_gates: bool = False,
    dry_run: bool = False,
    stream: bool = True,
    allow_protected_artifacts: bool = True,
    allow_unclassified: bool = False,
) -> ReadyToCommitResult:
    gates = ready_to_commit_gates(report, report_outdir=report_outdir, all_gates=all_gates)
    issues = ready_to_commit_issues(
        report,
        allow_protected_artifacts=allow_protected_artifacts,
        allow_unclassified=allow_unclassified,
    )
    if issues or dry_run:
        return ReadyToCommitResult(
            "failed" if issues else "passed",
            issues,
            gates,
            (),
            dirty_surfaces(report),
        )

    results = run_ready_to_commit_gates(gates, repo, stream=stream)
    failed = tuple(result for result in results if result.returncode != 0)
    gate_issues = tuple(
        f"validation gate failed: {result.name} ({shell_command(result.command)}) returned {result.returncode}"
        for result in failed
    )
    return ReadyToCommitResult(
        "failed" if gate_issues else "passed",
        gate_issues,
        gates,
        results,
        dirty_surfaces(report),
    )
