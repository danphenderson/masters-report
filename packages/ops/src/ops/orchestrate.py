"""Lightweight agent handoff and orchestration checks for this repository."""

from __future__ import annotations

import argparse
import json
import re
import subprocess
import sys
from dataclasses import asdict, dataclass
from pathlib import Path
from typing import Sequence


SURFACES = ("report", "julia", "ops", "references", "assets", "release")
MODES = ("inspect", "bounded-edit", "hard-review", "artifact-refresh")
COMMANDS = ("status", "dispatch", "handback-check", "docs-contract")
REQUIRED_HANDBACK_SECTIONS = ("Status", "Scope", "Files", "Validation", "Risks")

SURFACE_PREFIXES: dict[str, tuple[str, ...]] = {
    "assets": ("report/assets/", "public/var/data/simulations/"),
    "report": (
        "report/final-report.tex",
        "report/frontmatter/",
        "report/sections/",
        "report/appendices/",
        "report/preamble/",
        "report/notebooks/",
        "report/archive/",
    ),
    "julia": (
        "packages/julia/",
        "julia/",
        "bin/julia-release",
        "bin/stenosis-hemodynamics",
        "bin/stenosis-hemodynamics.jl",
    ),
    "ops": (
        "packages/ops/",
        "tools/python/",
        "scripts/",
        "Pipfile",
        "Pipfile.lock",
        "bin/build-report",
        "bin/python-check",
    ),
    "references": ("public/references/", "references/"),
    "release": (
        "AGENTS.md",
        "README.md",
        "CONTRIBUTING.md",
        "CITATION.cff",
        "LICENSE",
        "LICENSE-docs",
        ".gitignore",
        ".vscode/",
        "public/docs/",
        "docs/",
        "public/reproducibility/",
        "reproducibility/",
    ),
}

VALIDATION_COMMANDS: dict[str, tuple[str, ...]] = {
    "report": ("pipenv run ops-build-report --outdir /tmp/masters-report-build --no-sync-final-pdf",),
    "julia": ("packages/julia/bin/julia-release packages/julia/test/runtests.jl",),
    "ops": ("pipenv run ops-python-check",),
    "references": (
        "pipenv run ops-audit-references",
        "pipenv run pytest packages/ops/tests/test_references_inventory.py packages/ops/tests/test_tex_preamble_audit.py",
        "biber --tool --validate-datamodel --output-file /tmp/masters-report-references.bib public/references/references.bib",
    ),
    "assets": (
        "Run the owning renderer or Julia workflow for the changed asset.",
        "pipenv run ops-build-report --outdir /tmp/masters-report-build --no-sync-final-pdf",
    ),
    "release": (
        "git status --short --ignored",
        "pipenv run ops-audit-references",
        "packages/julia/bin/julia-release packages/julia/test/runtests.jl",
        "pipenv run ops-python-check",
        "pipenv run ops-build-report --outdir /tmp/masters-report-build --no-sync-final-pdf",
    ),
}

VALIDATION_MARKERS: dict[str, tuple[str, ...]] = {
    "report": ("ops-build-report",),
    "julia": ("julia-release", "runtests.jl"),
    "ops": ("ops-python-check",),
    "references": ("ops-audit-references",),
    "assets": ("ops-build-report",),
    "release": ("ops-python-check", "ops-build-report"),
}

DOC_CONTRACT_PATHS = (
    "AGENTS.md",
    "README.md",
    "public/docs/artifact-policy.md",
    "public/docs/agent-workflows.md",
)


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


def commands_for(surface: str, mode: str = "inspect") -> tuple[str, ...]:
    if surface == "report" and mode == "artifact-refresh":
        return ("pipenv run ops-build-report --outdir /tmp/masters-report-build",)
    return VALIDATION_COMMANDS[surface]


def blocked_artifacts_for(surface: str, mode: str) -> tuple[str, ...]:
    blocked = [
        "public/final-report.pdf unless --mode artifact-refresh",
        "report/assets/rendered/** unless the task explicitly refreshes rendered assets",
        "public/references/**/*.pdf|html|htm",
        "public/var/data/simulations/**",
        "tmp/simulations/output/** except scratch run outputs",
    ]
    if mode == "artifact-refresh":
        blocked[0] = "public/final-report.pdf may refresh only after the report gate passes"
    if surface == "references":
        blocked.append("reference metadata and private mirrors must follow public/references/AGENTS.md")
    return tuple(blocked)


def dispatch_packet(repo: Path, surface: str, mode: str, objective: str, files: Sequence[str]) -> str:
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
        "",
        "## Validation",
        *[f"- {command}" for command in commands_for(surface, mode)],
        "",
        "## Required Handback",
        *[f"- {section}" for section in REQUIRED_HANDBACK_SECTIONS],
    ]
    return "\n".join(lines) + "\n"


def dispatch_payload(repo: Path, surface: str, mode: str, objective: str, files: Sequence[str]) -> dict[str, object]:
    report = status_report(repo)
    return {
        "branch": report.branch,
        "surface": surface,
        "mode": mode,
        "objective": objective,
        "allowed_files": list(files),
        "blocked_artifacts": list(blocked_artifacts_for(surface, mode)),
        "validation": list(commands_for(surface, mode)),
        "required_handback": list(REQUIRED_HANDBACK_SECTIONS),
        "dirty_by_surface": report.dirty_by_surface,
        "protected_paths": list(report.protected_paths),
    }


def section_present(text: str, section: str) -> bool:
    return re.search(rf"(?im)^\s*(?:#+\s*)?{re.escape(section)}\b\s*:?", text) is not None


def has_validation_skip_reason(text: str) -> bool:
    return (
        re.search(
            r"(?is)\b(validation|checks?)\b.*\b(skipped|not run)\b.*\b(because|reason|unavailable|optional)\b", text
        )
        is not None
    )


def validation_present(text: str, surface: str, mode: str) -> bool:
    markers = VALIDATION_MARKERS[surface]
    if surface == "report" and mode != "artifact-refresh":
        return all(marker in text for marker in markers) and "--no-sync-final-pdf" in text
    return all(marker in text for marker in markers)


def check_handback(text: str, surface: str | None = None, mode: str = "inspect") -> CheckResult:
    issues = [
        f"missing handback section: {section}"
        for section in REQUIRED_HANDBACK_SECTIONS
        if not section_present(text, section)
    ]
    if surface is not None and not validation_present(text, surface, mode) and not has_validation_skip_reason(text):
        issues.append(f"missing validation evidence for surface: {surface}")
    return CheckResult(status="failed" if issues else "passed", issues=tuple(issues))


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
    lower = combined.lower()
    for phrase in ("no repo-managed commit hooks", "no background automation", "no persistent orchestration receipts"):
        if phrase not in lower:
            issues.append(f"missing orchestration limit: {phrase}")
    return CheckResult(status="failed" if issues else "passed", issues=tuple(issues))


def print_status(report: StatusReport, *, strict: bool = False) -> int:
    print(f"Branch: {report.branch or '<unknown>'}")
    if not report.entries:
        print("Dirty paths: none")
    else:
        print("Dirty paths by surface:")
        for surface, count in sorted(report.dirty_by_surface.items()):
            print(f"  {surface}: {count}")
    if report.protected_paths:
        print("Protected/generated paths dirty:")
        for path in report.protected_paths:
            print(f"  {path}")
    if report.unclassified_paths:
        print("Unclassified dirty paths:")
        for path in report.unclassified_paths:
            print(f"  {path}")
    return 1 if strict and (report.protected_paths or report.unclassified_paths) else 0


def print_check_result(result: CheckResult) -> int:
    if result.status == "passed":
        print("passed")
        return 0
    print("failed")
    for issue in result.issues:
        print(f"- {issue}")
    return 1


def dump_json(value: object) -> None:
    print(json.dumps(value, indent=2, sort_keys=True))


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--repo", type=Path, default=None, help="repository root; defaults to git root")
    subparsers = parser.add_subparsers(dest="command", required=True)

    status_parser = subparsers.add_parser("status", help="summarize dirty paths by orchestration surface")
    status_parser.add_argument("--json", action="store_true", help="emit machine-readable JSON")
    status_parser.add_argument("--strict", action="store_true", help="fail on protected or unclassified dirty paths")

    dispatch_parser = subparsers.add_parser("dispatch", help="print a bounded dispatch packet")
    dispatch_parser.add_argument("--surface", choices=SURFACES, required=True)
    dispatch_parser.add_argument("--mode", choices=MODES, required=True)
    dispatch_parser.add_argument("--objective", required=True)
    dispatch_parser.add_argument("--files", nargs="*", default=[])
    dispatch_parser.add_argument("--json", action="store_true", help="emit machine-readable JSON")

    handback_parser = subparsers.add_parser("handback-check", help="validate a worker handback")
    handback_parser.add_argument("--path", type=Path, required=True)
    handback_parser.add_argument("--surface", choices=SURFACES, default=None)
    handback_parser.add_argument("--mode", choices=MODES, default="inspect")
    handback_parser.add_argument("--json", action="store_true", help="emit machine-readable JSON")

    docs_parser = subparsers.add_parser("docs-contract", help="validate the documented orchestration contract")
    docs_parser.add_argument("--json", action="store_true", help="emit machine-readable JSON")
    return parser


def main(argv: Sequence[str] | None = None) -> int:
    args = build_parser().parse_args(argv)
    root = repo_root(args.repo)
    if args.command == "status":
        report = status_report(root)
        if args.json:
            dump_json(asdict(report))
            return 1 if args.strict and (report.protected_paths or report.unclassified_paths) else 0
        return print_status(report, strict=args.strict)
    if args.command == "dispatch":
        if args.json:
            dump_json(dispatch_payload(root, args.surface, args.mode, args.objective, args.files))
        else:
            print(dispatch_packet(root, args.surface, args.mode, args.objective, args.files), end="")
        return 0
    if args.command == "handback-check":
        handback_path = args.path if args.path.is_absolute() else root / args.path
        text = handback_path.read_text(encoding="utf-8")
        result = check_handback(text, args.surface, args.mode)
        if args.json:
            dump_json(asdict(result))
            return 0 if result.status == "passed" else 1
        return print_check_result(result)
    if args.command == "docs-contract":
        result = docs_contract(root)
        if args.json:
            dump_json(asdict(result))
            return 0 if result.status == "passed" else 1
        return print_check_result(result)
    raise AssertionError(f"unhandled command: {args.command}")


if __name__ == "__main__":
    sys.exit(main())
