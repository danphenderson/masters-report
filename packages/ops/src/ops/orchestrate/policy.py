"""Static orchestration policy data and small policy helpers."""

from __future__ import annotations

import re
from typing import Sequence

from .models import ReviewLaneSpec

SURFACES = ("report", "julia", "ops", "references", "assets", "release")
MODES = ("inspect", "bounded-edit", "hard-review", "artifact-refresh")
PROFILES = ("generic", "editorial-readiness", "claim-boundary", "citation-evidence", "pdf-sync", "source-polish")
COMMANDS = (
    "status",
    "sessions",
    "dispatch",
    "review",
    "bundle",
    "handback-check",
    "packet-check",
    "docs-contract",
    "ready-to-commit",
)
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
    "assets": ("report/assets/", "public/var/data/simulations/", "public/var/logs/"),
    "report": (
        "report/final-report.tex",
        "report/frontmatter/",
        "report/sections/",
        "report/appendices/",
        "report/preamble/",
        "report/notebooks/",
        "report/archive/",
        "report/",
    ),
    "julia": (
        "packages/stenotic-hemodynamics/",
        "julia/",
        "bin/julia-release",
        "bin/stenotic-hemodynamics",
        "bin/stenotic-hemodynamics.jl",
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
        ".github/",
        "AGENTS.md",
        "README.md",
        "CONTRIBUTING.md",
        "CITATION.cff",
        "LICENSE",
        "LICENSE-docs",
        ".gitignore",
        ".vscode/",
        "docusaurus.config.js",
        "package-lock.json",
        "package.json",
        "sidebars.js",
        "public/docs/",
        "docs/",
        "public/reproducibility/",
        "reproducibility/",
        "src/css/",
        "static/",
    ),
}

VALIDATION_COMMANDS: dict[str, tuple[str, ...]] = {
    "report": ("pipenv run ops-build-report --outdir /tmp/masters-report-build --no-sync-final-pdf",),
    "julia": ("pipenv run ops-julia-check",),
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
    "release": ("pipenv run ops-release-check --mode release",),
}

VALIDATION_MARKERS: dict[str, tuple[str, ...]] = {
    "report": ("ops-build-report",),
    "julia": ("ops-julia-check",),
    "ops": ("ops-python-check",),
    "references": ("ops-audit-references",),
    "assets": ("ops-build-report",),
    "release": ("ops-release-check",),
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
    "packages/stenotic-hemodynamics/README.md",
    "report/appendices/code-and-ai-use.tex",
    "report/sections/07-case-study/methodology.tex",
)

HISTORICAL_PATH_PREFIXES = ("report/archive/",)

STALE_PATH_PATTERNS: tuple[tuple[str, re.Pattern[str]], ...] = (
    ("removed Julia simulations package path", re.compile(r"\bpackages/stenotic-hemodynamics/simulations(?:/|\b)")),
    ("removed ops source path", re.compile(r"\btools/python(?:/|\b)")),
    ("removed root Python script wrapper", re.compile(r"(?<![\w./-])scripts/[A-Za-z0-9_.-]+\.py\b")),
    (
        "removed root reference metadata path",
        re.compile(r"(?<!public/)references/(?:AGENTS\.md|README\.md|references\.bib|source-inventory\.tsv)\b"),
    ),
    (
        "deleted TODO coordination file route; use GitHub issues and public/docs/agent-workflows.md",
        re.compile(r"\b(?:report/TODO\.md|packages/stenotic-hemodynamics/TODO\.md)\b"),
    ),
)

PACKET_STALE_PATTERNS: tuple[tuple[str, re.Pattern[str]], ...] = (
    ("stale Julia root; use packages/stenotic-hemodynamics/", re.compile(r"(?<![\w./-])julia/")),
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
        "stale Julia test wrapper; use pipenv run ops-julia-check",
        re.compile(r"(?<![\w./-])bin/julia-release\b"),
    ),
    (
        "raw Julia validation command; use pipenv run ops-julia-check",
        re.compile(
            r"packages/stenotic-hemodynamics/bin/julia-release\s+packages/stenotic-hemodynamics/test/runtests\.jl"
        ),
    ),
    (
        "stale Julia CLI wrapper; use packages/stenotic-hemodynamics/bin/stenotic-hemodynamics",
        re.compile(r"(?<![\w./-])bin/stenotic-hemodynamics\b"),
    ),
    (
        "deleted TODO coordination file route; use GitHub issues and public/docs/agent-workflows.md",
        re.compile(r"\b(?:report/TODO\.md|packages/stenotic-hemodynamics/TODO\.md)\b"),
    ),
)
PACKET_VALIDATION_NEEDLES = (
    "pipenv run ops-build-report",
    "pipenv run ops-python-check",
    "pipenv run ops-audit-references",
    "pipenv run ops-julia-check",
    "pipenv run ops-release-check",
)
OVERBROAD_PACKET_PATTERNS: tuple[re.Pattern[str], ...] = (
    re.compile(r"(?is)\bregenerate\s+experiments?\b"),
    re.compile(r"(?is)\brewrite\s+report\s+assets\s+as\s+needed\b"),
    re.compile(r"(?is)\brewrite\s+.*\bas\s+needed\b"),
    re.compile(r"(?is)\bmodify\s+any\s+files?\s+as\s+needed\b"),
)

PENDING_VALIDATION_PATTERNS: tuple[re.Pattern[str], ...] = (
    re.compile(r"(?is)\btodo\b"),
    re.compile(r"(?is)\bpending\b"),
    re.compile(r"(?is)\bwill\s+run\b"),
    re.compile(r"(?is)\bto\s+run\b"),
    re.compile(r"(?is)\bbefore\s+commit\b"),
    re.compile(r"(?is)\bnot\s+yet\s+run\b"),
)
SUCCESS_STATUS_PATTERNS: tuple[re.Pattern[str], ...] = (
    re.compile(r"(?is)\bpassed\b"),
    re.compile(r"(?is)\bapproved\b"),
    re.compile(r"(?is)\bsend\b"),
    re.compile(r"(?is)\bsubmit_ready\b"),
    re.compile(r"(?is)\bready\b"),
)
UNSUCCESSFUL_STATUS_PATTERNS: tuple[re.Pattern[str], ...] = (
    re.compile(r"(?is)\bblocked\b"),
    re.compile(r"(?is)\bfailed\b"),
    re.compile(r"(?is)\bno-send\b"),
    re.compile(r"(?is)\bneeds_major_revision\b"),
    re.compile(r"(?is)\bnot\s+ready\b"),
)

BOILERPLATE_SECTION_BODIES = frozenset({"", "n/a", "na", "none", "not applicable", "pending", "tbd", "todo"})

REVIEW_LANE_SPECS: dict[str, ReviewLaneSpec] = {
    "layout": ReviewLaneSpec(
        surfaces=("julia", "ops"),
        mode="hard-review",
        scope="Julia and ops package relocation, console entry points, and removed root wrappers.",
        files=(
            "packages/stenotic-hemodynamics/README.md",
            "packages/stenotic-hemodynamics/bin/*",
            "packages/ops/pyproject.toml",
            "Pipfile",
            "deleted bin/ and scripts/ wrappers via git history/status",
        ),
        validation=(
            "pipenv run ops-julia-check",
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
            "packages/ops/src/ops/orchestrate/**",
            "packages/ops/tests/test_orchestrate.py",
            "packages/ops/tests/test_docs_contract.py",
            "public/docs/agent-workflows.md",
        ),
        validation=(
            "pipenv run ops-orchestrate docs-contract",
            'pipenv run ops-orchestrate dispatch --surface ops --mode inspect --objective "review smoke" '
            "--files packages/ops/src/ops/orchestrate/__init__.py",
        ),
        blocker_rules=(
            "Return BLOCKED if JSON/human dispatch outputs disagree.",
            "Return BLOCKED if handback checks can pass without meaningful validation evidence.",
        ),
    ),
    "docs": ReviewLaneSpec(
        surfaces=("report", "release", "julia"),
        mode="hard-review",
        scope="Public docs and report provenance after packages/stenotic-hemodynamics/simulations/** removal.",
        files=(
            "README.md",
            "AGENTS.md",
            "public/docs/benchmark-pipeline.md",
            "report/appendices/code-and-ai-use.tex",
            "report/sections/07-case-study/methodology.tex",
            "packages/stenotic-hemodynamics/README.md",
        ),
        validation=(
            'rg -n "packages/stenotic-hemodynamics/simulations" AGENTS.md README.md public/docs '
            "report/appendices/code-and-ai-use.tex report/sections/07-case-study/methodology.tex "
            "packages/stenotic-hemodynamics/README.md",
        ),
        blocker_rules=("Return BLOCKED if active docs mention stale paths outside historical archives.",),
    ),
}


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
        "public/var/logs/*.json|jsonl",
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
