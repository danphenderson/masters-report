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
PROFILES = ("generic", "editorial-readiness", "claim-boundary", "citation-evidence", "pdf-sync", "source-polish")
COMMANDS = ("status", "dispatch", "review", "handback-check", "packet-check", "docs-contract")
REVIEW_LANES = ("layout", "artifacts", "orchestration", "docs")
REQUIRED_HANDBACK_SECTIONS = ("Status", "Scope", "Files", "Validation", "Risks")
PROFILE_HANDBACK_SECTIONS: dict[str, tuple[str, ...]] = {
    "generic": (),
    "editorial-readiness": ("Verdict", "Reader Impact"),
    "claim-boundary": ("Claim Boundary", "Evidence Basis"),
    "citation-evidence": ("Citation Evidence", "Unresolved Sources"),
    "pdf-sync": ("PDF Scope", "Artifact Decision"),
    "source-polish": ("Editorial Intent", "Residual Prose Risk"),
}
PROFILE_GUIDANCE: dict[str, tuple[str, ...]] = {
    "generic": (),
    "editorial-readiness": (
        "Read for the committee-facing manuscript experience before proposing source edits.",
        "Separate structure, clarity, mathematical exposition, and defense-readiness risks.",
        "Return a verdict of SUBMIT_READY, NEEDS_MINOR_REVISION, or NEEDS_MAJOR_REVISION.",
    ),
    "claim-boundary": (
        "Separate model specification, numerical verification, cross-model comparison, and validation.",
        "Flag language that treats bounded internal comparisons as physical or clinical validation.",
        "Tie every material concern to local manuscript text, local assets, or local validation output.",
    ),
    "citation-evidence": (
        "Check citation placement against public/references/references.bib and public/references/source-inventory.tsv.",
        "Do not rely on private full-text mirrors unless the task explicitly names them.",
        "Flag unsupported, stale, or ambiguous citation roles without adding new literature.",
    ),
    "pdf-sync": (
        "Treat public/final-report.pdf as an artifact that may refresh only in artifact-refresh mode.",
        "Compare source intent against rendered output when PDF scope is explicitly opened.",
        "Do not refresh rendered artifacts unless they are listed in Allowed Files.",
    ),
    "source-polish": (
        "Make bounded prose edits only in named source files.",
        "Prefer local transitions, topic sentences, and claim-calibration fixes over structural rewrites.",
        "Do not modify report artifacts or manuscript-wide numbering machinery.",
    ),
}
ALL_HANDBACK_SECTIONS = tuple(
    dict.fromkeys(
        section
        for sections in (REQUIRED_HANDBACK_SECTIONS, *PROFILE_HANDBACK_SECTIONS.values())
        for section in sections
    )
)

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
    "public/docs/policy-vocabulary.md",
)

STALE_PATH_CHECK_PATHS = (
    "AGENTS.md",
    "README.md",
    "CONTRIBUTING.md",
    "public/docs/artifact-policy.md",
    "public/docs/agent-workflows.md",
    "public/docs/policy-vocabulary.md",
    "public/docs/benchmark-pipeline.md",
    "public/docs/executive-assessment.md",
    "public/docs/publication-readiness.md",
    "packages/julia/README.md",
    "report/appendices/code-and-ai-use.tex",
    "report/sections/07-case-study/methodology.tex",
)

HISTORICAL_PATH_PREFIXES = ("report/archive/",)

STALE_PATH_PATTERNS: tuple[tuple[str, re.Pattern[str]], ...] = (
    ("removed Julia simulations package path", re.compile(r"\bpackages/julia/simulations(?:/|\b)")),
    ("removed ops source path", re.compile(r"\btools/python(?:/|\b)")),
    ("removed root Python script wrapper", re.compile(r"(?<![\w./-])scripts/[A-Za-z0-9_.-]+\.py\b")),
    (
        "removed root reference metadata path",
        re.compile(r"(?<!public/)references/(?:AGENTS\.md|README\.md|references\.bib|source-inventory\.tsv)\b"),
    ),
)

PACKET_STALE_PATTERNS: tuple[tuple[str, re.Pattern[str]], ...] = (
    ("stale Julia root; use packages/julia/", re.compile(r"(?<![\w./-])julia/")),
    ("stale Python tooling root; use packages/ops/", re.compile(r"(?<![\w./-])tools/python/")),
    (
        "stale bibliography path; use public/references/references.bib",
        re.compile(r"(?<!public/)references/references\.bib\b"),
    ),
    (
        "stale source inventory path; use public/references/source-inventory.tsv",
        re.compile(r"(?<!public/)references/source-inventory\.tsv\b"),
    ),
    ("stale report build wrapper; use pipenv run ops-build-report", re.compile(r"(?<![\w./-])bin/build-report\b")),
    ("stale Python check wrapper; use pipenv run ops-python-check", re.compile(r"(?<![\w./-])bin/python-check\b")),
    (
        "stale Julia test wrapper; use packages/julia/bin/julia-release",
        re.compile(r"(?<![\w./-])bin/julia-release\b"),
    ),
    (
        "stale Julia CLI wrapper; use packages/julia/bin/stenosis-hemodynamics",
        re.compile(r"(?<![\w./-])bin/stenosis-hemodynamics\b"),
    ),
)
PACKET_VALIDATION_NEEDLES = (
    "pipenv run ops-build-report",
    "pipenv run ops-python-check",
    "pipenv run ops-audit-references",
    "packages/julia/bin/julia-release",
)
OVERBROAD_PACKET_PATTERNS: tuple[re.Pattern[str], ...] = (
    re.compile(r"(?is)\bregenerate\s+experiments?\b"),
    re.compile(r"(?is)\brewrite\s+report\s+assets\s+as\s+needed\b"),
    re.compile(r"(?is)\brewrite\s+.*\bas\s+needed\b"),
    re.compile(r"(?is)\bmodify\s+any\s+files?\s+as\s+needed\b"),
)

BOILERPLATE_SECTION_BODIES = frozenset({"", "n/a", "na", "none", "not applicable", "pending", "tbd", "todo"})


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


REVIEW_LANE_SPECS: dict[str, ReviewLaneSpec] = {
    "layout": ReviewLaneSpec(
        surfaces=("julia", "ops"),
        mode="hard-review",
        scope="Julia and ops package relocation, console entry points, and removed root wrappers.",
        files=(
            "packages/julia/README.md",
            "packages/julia/bin/*",
            "packages/ops/pyproject.toml",
            "Pipfile",
            "deleted bin/ and scripts/ wrappers via git history/status",
        ),
        validation=(
            "packages/julia/bin/julia-release packages/julia/test/runtests.jl",
            "pipenv run ops-python-check",
        ),
        blocker_rules=("Return BLOCKED if any documented command still points to removed root wrapper paths.",),
    ),
    "artifacts": ReviewLaneSpec(
        surfaces=("assets", "release"),
        mode="hard-review",
        scope="Raw-data exclusion, ignored local artifacts, rendered PDF/data refresh boundaries.",
        files=(
            ".gitignore",
            "public/docs/artifact-policy.md",
            "report/assets/rendered/stenosis-fem-fvm-meshes.pdf",
            "report/assets/data/stenosis-comparison/grid-sensitivity-summary.csv",
        ),
        validation=("pipenv run ops-orchestrate status --strict",),
        blocker_rules=(
            "Return BLOCKED if public/var/**, public/final-report.pdf, biber logs, or caches become trackable.",
            "Current clean trees should pass strict status; future protected-artifact drift should fail.",
        ),
    ),
    "orchestration": ReviewLaneSpec(
        surfaces=("ops", "release"),
        mode="hard-review",
        scope="ops-orchestrate behavior, docs contract, handback validation, and test coverage.",
        files=(
            "packages/ops/src/ops/orchestrate.py",
            "packages/ops/tests/test_orchestrate.py",
            "packages/ops/tests/test_docs_contract.py",
            "public/docs/agent-workflows.md",
        ),
        validation=(
            "pipenv run ops-orchestrate docs-contract",
            'pipenv run ops-orchestrate dispatch --surface ops --mode inspect --objective "review smoke" '
            "--files packages/ops/src/ops/orchestrate.py",
        ),
        blocker_rules=(
            "Return BLOCKED if JSON/human dispatch outputs disagree.",
            "Return BLOCKED if handback checks can pass without meaningful validation evidence.",
        ),
    ),
    "docs": ReviewLaneSpec(
        surfaces=("report", "release", "julia"),
        mode="hard-review",
        scope="Public docs and report provenance after packages/julia/simulations/** removal.",
        files=(
            "README.md",
            "AGENTS.md",
            "public/docs/benchmark-pipeline.md",
            "report/appendices/code-and-ai-use.tex",
            "report/sections/07-case-study/methodology.tex",
            "packages/julia/README.md",
        ),
        validation=(
            'rg -n "packages/julia/simulations" AGENTS.md README.md public/docs '
            "report/appendices/code-and-ai-use.tex report/sections/07-case-study/methodology.tex "
            "packages/julia/README.md",
        ),
        blocker_rules=("Return BLOCKED if active docs mention stale paths outside historical archives.",),
    ),
}


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
        "report/assets/rendered/** unless listed in Allowed Files with --mode artifact-refresh",
        "public/references/**/*.pdf|html|htm",
        "public/var/data/simulations/**",
        "tmp/simulations/output/** except scratch run outputs",
    ]
    if mode == "artifact-refresh":
        blocked[0] = "public/final-report.pdf may refresh only after the report gate passes"
        blocked[1] = (
            "report/assets/rendered/** may refresh only when listed in Allowed Files and the owning gate passes"
        )
    if surface == "references":
        blocked.append("reference metadata and private mirrors must follow public/references/AGENTS.md")
    return tuple(blocked)


def handback_sections_for(profile: str = "generic") -> tuple[str, ...]:
    return (*REQUIRED_HANDBACK_SECTIONS, *PROFILE_HANDBACK_SECTIONS[profile])


def validate_dispatch_request(mode: str, files: Sequence[str]) -> None:
    if mode in {"bounded-edit", "artifact-refresh"} and not files:
        raise ValueError(f"--files is required for --mode {mode}")


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


def review_spec(lane: str) -> ReviewLaneSpec:
    return REVIEW_LANE_SPECS[lane]


def review_blocked_artifacts(spec: ReviewLaneSpec) -> tuple[str, ...]:
    blocked: list[str] = []
    seen: set[str] = set()
    for surface in spec.surfaces:
        for item in blocked_artifacts_for(surface, spec.mode):
            if item not in seen:
                blocked.append(item)
                seen.add(item)
    return tuple(blocked)


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


def section_present(text: str, section: str) -> bool:
    return re.search(rf"(?im)^[^\S\r\n]*(?:#+[^\S\r\n]*)?{re.escape(section)}\b[^\S\r\n]*:?", text) is not None


def section_body(text: str, section: str) -> str:
    match = re.search(
        rf"(?im)^[^\S\r\n]*(?:#+[^\S\r\n]*)?{re.escape(section)}\b[^\S\r\n]*:?[^\S\r\n]*(?P<inline>[^\r\n]*)",
        text,
    )
    if match is None:
        return ""
    following = text[match.end() :]
    section_names = "|".join(re.escape(name) for name in ALL_HANDBACK_SECTIONS)
    next_section = re.search(rf"(?im)^[^\S\r\n]*(?:#+[^\S\r\n]*)?(?:{section_names})\b[^\S\r\n]*:?", following)
    if next_section is not None:
        following = following[: next_section.start()]
    return "\n".join(part for part in (match.group("inline").strip(), following.strip()) if part).strip()


def is_boilerplate_section_body(body: str) -> bool:
    normalized = re.sub(r"\s+", " ", body).strip().strip(".:").lower()
    return normalized in BOILERPLATE_SECTION_BODIES


def has_validation_skip_reason(text: str) -> bool:
    return re.search(r"(?is)\b(skipped|not run)\b.*\b(because|reason|unavailable|optional)\b", text) is not None


def validation_present(text: str, surface: str, mode: str) -> bool:
    markers = VALIDATION_MARKERS[surface]
    if surface == "report" and mode != "artifact-refresh":
        return all(marker in text for marker in markers) and "--no-sync-final-pdf" in text
    return all(marker in text for marker in markers)


def check_handback(
    text: str, surface: str | None = None, mode: str = "inspect", profile: str = "generic"
) -> CheckResult:
    issues = [
        f"missing handback section: {section}"
        for section in handback_sections_for(profile)
        if not section_present(text, section)
    ]
    for section in ("Validation", "Risks"):
        if section_present(text, section) and is_boilerplate_section_body(section_body(text, section)):
            issues.append(f"insufficient handback section: {section}")
    validation_body = section_body(text, "Validation")
    if (
        surface is not None
        and not validation_present(validation_body, surface, mode)
        and not has_validation_skip_reason(validation_body)
    ):
        issues.append(f"missing validation evidence for surface: {surface}")
    return CheckResult(status="failed" if issues else "passed", issues=tuple(issues))


def packet_check(text: str, profile: str = "generic") -> CheckResult:
    issues: list[str] = []
    for label, pattern in PACKET_STALE_PATTERNS:
        if pattern.search(text):
            issues.append(label)
    if "public/final-report.pdf" not in text:
        issues.append("missing final PDF artifact guardrail: public/final-report.pdf")
    if "report/assets/rendered" not in text:
        issues.append("missing rendered report asset guardrail: report/assets/rendered/**")
    if not any(needle in text for needle in PACKET_VALIDATION_NEEDLES):
        issues.append("missing current ops validation command")
    if any(pattern.search(text) for pattern in OVERBROAD_PACKET_PATTERNS):
        issues.append("overbroad packet authority: avoid regenerate/rewrite/modify-as-needed language")
    if profile != "generic" and profile not in text:
        issues.append(f"missing packet profile marker: {profile}")
    return CheckResult(status="failed" if issues else "passed", issues=tuple(dict.fromkeys(issues)))


def is_historical_path(path: str) -> bool:
    normalized = normalize_repo_path(path)
    return any(normalized.startswith(prefix) for prefix in HISTORICAL_PATH_PREFIXES)


def stale_path_issues(repo: Path, paths: Sequence[str] = STALE_PATH_CHECK_PATHS) -> tuple[str, ...]:
    issues: list[str] = []
    for relative in paths:
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
    for phrase in ("no repo-managed commit hooks", "no background automation", "no persistent orchestration receipts"):
        if phrase not in lower:
            issues.append(f"missing orchestration limit: {phrase}")
    issues.extend(stale_path_issues(repo))
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
    dispatch_parser.add_argument("--profile", choices=PROFILES, default="generic")
    dispatch_parser.add_argument("--json", action="store_true", help="emit machine-readable JSON")

    review_parser = subparsers.add_parser("review", help="print a read-only delegated review packet")
    review_parser.add_argument("--commit", required=True)
    review_parser.add_argument("--lane", choices=REVIEW_LANES, required=True)
    review_parser.add_argument("--json", action="store_true", help="emit machine-readable JSON")

    handback_parser = subparsers.add_parser("handback-check", help="validate a worker handback")
    handback_parser.add_argument("--path", type=Path, required=True)
    handback_parser.add_argument("--surface", choices=SURFACES, default=None)
    handback_parser.add_argument("--mode", choices=MODES, default="inspect")
    handback_parser.add_argument("--profile", choices=PROFILES, default="generic")
    handback_parser.add_argument("--json", action="store_true", help="emit machine-readable JSON")

    packet_parser = subparsers.add_parser("packet-check", help="validate an external handoff packet")
    packet_parser.add_argument("--path", type=Path, required=True)
    packet_parser.add_argument("--profile", choices=PROFILES, default="generic")
    packet_parser.add_argument("--json", action="store_true", help="emit machine-readable JSON")

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
        try:
            if args.json:
                dump_json(dispatch_payload(root, args.surface, args.mode, args.objective, args.files, args.profile))
            else:
                print(dispatch_packet(root, args.surface, args.mode, args.objective, args.files, args.profile), end="")
        except ValueError as exc:
            build_parser().error(str(exc))
        return 0
    if args.command == "review":
        if args.json:
            dump_json(review_payload(root, args.commit, args.lane))
        else:
            print(review_packet(root, args.commit, args.lane), end="")
        return 0
    if args.command == "handback-check":
        handback_path = args.path if args.path.is_absolute() else root / args.path
        text = handback_path.read_text(encoding="utf-8")
        result = check_handback(text, args.surface, args.mode, args.profile)
        if args.json:
            dump_json(asdict(result))
            return 0 if result.status == "passed" else 1
        return print_check_result(result)
    if args.command == "packet-check":
        packet_path = args.path if args.path.is_absolute() else root / args.path
        text = packet_path.read_text(encoding="utf-8")
        result = packet_check(text, args.profile)
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
