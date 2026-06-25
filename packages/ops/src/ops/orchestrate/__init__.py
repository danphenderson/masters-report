"""Lightweight agent handoff and orchestration checks for this repository."""

from __future__ import annotations

from .bundles import (
    DEFAULT_BUNDLE_OUTDIR,
    HARNESS_FILES,
    SUPPORTED_BUNDLE_TARGETS,
    BundleResult,
    create_dispatch_bundle,
    render_chatgpt_pro_prompt,
)
from .cli import build_parser, dump_json, main, print_check_result, print_status
from .docs_contract import docs_contract, is_historical_path, stale_path_issues
from .handback import (
    check_handback,
    has_validation_skip_reason,
    is_boilerplate_section_body,
    section_body,
    section_present,
    validation_present,
)
from .models import CheckResult, ReviewLaneSpec, StatusEntry, StatusReport
from .packet_check import packet_check
from . import packets as _packets
from .policy import (
    ALL_HANDBACK_SECTIONS,
    BOILERPLATE_SECTION_BODIES,
    COMMANDS,
    DOC_CONTRACT_PATHS,
    HISTORICAL_PATH_PREFIXES,
    MODES,
    OVERBROAD_PACKET_PATTERNS,
    PACKET_STALE_PATTERNS,
    PACKET_VALIDATION_NEEDLES,
    PROFILES,
    PROFILE_GUIDANCE,
    PROFILE_HANDBACK_SECTIONS,
    REQUIRED_HANDBACK_SECTIONS,
    REVIEW_LANE_SPECS,
    REVIEW_LANES,
    STALE_PATH_CHECK_PATHS,
    STALE_PATH_PATTERNS,
    SURFACE_PREFIXES,
    SURFACES,
    VALIDATION_COMMANDS,
    VALIDATION_MARKERS,
    blocked_artifacts_for,
    commands_for,
    handback_sections_for,
    review_blocked_artifacts,
    review_spec,
    validate_dispatch_request,
)
from .ready_commit import (
    DEFAULT_REPORT_OUTDIR,
    ReadyGate,
    ReadyGateResult,
    ReadyToCommitResult,
    ready_to_commit_gates,
    ready_to_commit_issues,
    ready_to_commit_result,
    shell_command,
)
from .session_sources import CodexJsonlSessionSource, SessionSource, SessionSummary, session_source
from .status import (
    classify_path,
    is_protected_path,
    normalize_repo_path,
    normalize_status_path,
    parse_status,
    repo_root,
    run_git_status,
    status_report,
)


def dispatch_packet(*args, **kwargs):
    _packets.status_report = status_report
    return _packets.dispatch_packet(*args, **kwargs)


def dispatch_payload(*args, **kwargs):
    _packets.status_report = status_report
    return _packets.dispatch_payload(*args, **kwargs)


def review_packet(*args, **kwargs):
    _packets.status_report = status_report
    return _packets.review_packet(*args, **kwargs)


def review_payload(*args, **kwargs):
    _packets.status_report = status_report
    return _packets.review_payload(*args, **kwargs)


__all__ = [
    "ALL_HANDBACK_SECTIONS",
    "BOILERPLATE_SECTION_BODIES",
    "BundleResult",
    "COMMANDS",
    "DEFAULT_BUNDLE_OUTDIR",
    "DEFAULT_REPORT_OUTDIR",
    "DOC_CONTRACT_PATHS",
    "HARNESS_FILES",
    "HISTORICAL_PATH_PREFIXES",
    "MODES",
    "OVERBROAD_PACKET_PATTERNS",
    "PACKET_STALE_PATTERNS",
    "PACKET_VALIDATION_NEEDLES",
    "PROFILES",
    "PROFILE_GUIDANCE",
    "PROFILE_HANDBACK_SECTIONS",
    "REQUIRED_HANDBACK_SECTIONS",
    "REVIEW_LANE_SPECS",
    "REVIEW_LANES",
    "STALE_PATH_CHECK_PATHS",
    "STALE_PATH_PATTERNS",
    "SURFACE_PREFIXES",
    "SUPPORTED_BUNDLE_TARGETS",
    "SURFACES",
    "VALIDATION_COMMANDS",
    "VALIDATION_MARKERS",
    "CheckResult",
    "ReviewLaneSpec",
    "StatusEntry",
    "StatusReport",
    "ReadyGate",
    "ReadyGateResult",
    "ReadyToCommitResult",
    "CodexJsonlSessionSource",
    "SessionSource",
    "SessionSummary",
    "blocked_artifacts_for",
    "build_parser",
    "check_handback",
    "classify_path",
    "commands_for",
    "create_dispatch_bundle",
    "dispatch_packet",
    "dispatch_payload",
    "docs_contract",
    "dump_json",
    "handback_sections_for",
    "has_validation_skip_reason",
    "is_boilerplate_section_body",
    "is_historical_path",
    "is_protected_path",
    "main",
    "normalize_repo_path",
    "normalize_status_path",
    "packet_check",
    "parse_status",
    "print_check_result",
    "print_status",
    "repo_root",
    "ready_to_commit_gates",
    "ready_to_commit_issues",
    "ready_to_commit_result",
    "render_chatgpt_pro_prompt",
    "review_blocked_artifacts",
    "review_packet",
    "review_payload",
    "review_spec",
    "session_source",
    "run_git_status",
    "section_body",
    "section_present",
    "shell_command",
    "stale_path_issues",
    "status_report",
    "validate_dispatch_request",
    "validation_present",
]
