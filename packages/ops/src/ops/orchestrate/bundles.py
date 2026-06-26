"""Dispatch-bundle creation for external reasoning sessions."""

from __future__ import annotations

import hashlib
import io
import json
import re
import tarfile
from dataclasses import asdict, dataclass
from datetime import UTC, datetime
from pathlib import Path
from typing import Any

from ops.git_state import git_sha, git_status_short, run_git

from .status import is_protected_path, status_report

DEFAULT_BUNDLE_OUTDIR = Path("tmp/dispatch-bundles")
SUPPORTED_BUNDLE_TARGETS = ("chatgpt-pro",)
HARNESS_FILES = (
    "CHATGPT_PRO_PROMPT.md",
    "CHATGPT_PRO_DISPATCH.md",
    "BUNDLE_MANIFEST.json",
    "OPS_STATUS.json",
    "GIT_STATUS.txt",
    "GIT_DIFF.patch",
)
REQUIRED_BUNDLE_READING_ORDER = (
    "BUNDLE_MANIFEST.json",
    "OPS_STATUS.json",
    "GIT_STATUS.txt",
    "GIT_DIFF.patch",
)
OPTIONAL_REPO_CONTRACT_FILES = (
    "repo/AGENTS.md",
    "repo/public/docs/markdown/agent-workflows.md",
    "repo/public/docs/markdown/artifact-policy.md",
)
FOLLOW_UP_REPO_READING_HINT = "Objective-relevant files under repo/"
OUTPUT_CONTRACT_SECTIONS = (
    "Current State",
    "Execution Lanes",
    "Validation Plan",
    "Blocked Conditions",
    "Recommended Next Prompt or Handback",
)


@dataclass(frozen=True)
class BundleResult:
    archive_path: Path
    archive_sha256: str
    prompt: str
    manifest: dict[str, Any]
    included_files: tuple[str, ...]
    excluded_files: tuple[str, ...]
    skipped_files: tuple[str, ...]

    def to_payload(self) -> dict[str, Any]:
        return {
            "archive_path": self.archive_path.as_posix(),
            "archive_sha256": self.archive_sha256,
            "prompt": self.prompt,
            "manifest": self.manifest,
            "included_files": list(self.included_files),
            "excluded_files": list(self.excluded_files),
            "skipped_files": list(self.skipped_files),
        }


def _safe_slug(value: str) -> str:
    slug = re.sub(r"[^A-Za-z0-9._-]+", "-", value.strip().lower()).strip("-._")
    return slug or "bundle"


def _resolve_bundle_outdir(repo: Path, outdir: Path) -> Path:
    output_path = outdir if outdir.is_absolute() else repo / outdir
    resolved = output_path.expanduser().resolve(strict=False)
    repo_resolved = repo.resolve(strict=False)
    try:
        relative = resolved.relative_to(repo_resolved)
    except ValueError:
        if resolved.is_relative_to(Path("/tmp")):
            return resolved
        raise ValueError("--outdir must point under tmp/** in the repository or under /tmp")
    if not relative.parts or relative.parts[0] != "tmp":
        raise ValueError("--outdir must point under tmp/** in the repository or under /tmp")
    return resolved


def _git_lines(repo: Path, args: list[str]) -> tuple[str, ...]:
    result = run_git(repo, args)
    if result.returncode != 0:
        raise RuntimeError(result.stderr.strip() or f"git {' '.join(args)} failed")
    return tuple(line for line in result.stdout.splitlines() if line)


def _git_text(repo: Path, args: list[str]) -> str:
    result = run_git(repo, args)
    if result.returncode != 0:
        return result.stderr.strip() + "\n"
    return result.stdout


def _candidate_files(repo: Path) -> tuple[str, ...]:
    candidates = _git_lines(repo, ["ls-files", "--cached", "--others", "--exclude-standard"])
    normalized: list[str] = []
    seen: set[str] = set()
    for item in candidates:
        path = item.strip()
        if not path or path.startswith("/") or ".." in Path(path).parts:
            continue
        if path not in seen:
            normalized.append(path)
            seen.add(path)
    return tuple(normalized)


def _filter_bundle_files(
    repo: Path, *, include_protected_artifacts: bool
) -> tuple[tuple[str, ...], tuple[str, ...], tuple[str, ...]]:
    included: list[str] = []
    excluded: list[str] = []
    skipped: list[str] = []
    for relative in _candidate_files(repo):
        source = repo / relative
        if not source.exists() and not source.is_symlink():
            skipped.append(relative)
            continue
        if is_protected_path(relative) and not include_protected_artifacts:
            excluded.append(relative)
            continue
        included.append(relative)
    return tuple(included), tuple(excluded), tuple(skipped)


def _tar_text(tar: tarfile.TarFile, arcname: str, text: str, *, mtime: int) -> None:
    payload = text.encode("utf-8")
    info = tarfile.TarInfo(arcname)
    info.size = len(payload)
    info.mtime = mtime
    info.mode = 0o644
    tar.addfile(info, io.BytesIO(payload))


def _diff_text(repo: Path) -> str:
    unstaged = _git_text(repo, ["diff", "--binary"])
    staged = _git_text(repo, ["diff", "--cached", "--binary"])
    return "\n".join(
        [
            "# Unstaged diff",
            unstaged.rstrip() or "<empty>",
            "",
            "# Staged diff",
            staged.rstrip() or "<empty>",
            "",
        ]
    )


def _archive_sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def _dirty_surface_lines(manifest: dict[str, Any]) -> list[str]:
    dirty = manifest["status"]["dirty_by_surface"] or {}
    if not dirty:
        return ["- Dirty surfaces: none"]
    return [f"- Dirty surface `{surface}`: {count} path(s)" for surface, count in sorted(dirty.items())]


def _dirty_path_lines(manifest: dict[str, Any]) -> list[str]:
    entries = manifest["status"]["entries"]
    if not entries:
        return ["- Dirty paths: none"]
    return [f"- {entry['code'].strip() or '<status>'} {entry['path']} ({entry['surface']})" for entry in entries]


def _excluded_artifact_lines(manifest: dict[str, Any]) -> list[str]:
    excluded = manifest["excluded_files"] or []
    if not excluded:
        return ["- Excluded protected artifacts: none"]
    return [f"- Excluded protected artifact: {path}" for path in excluded]


def _skipped_file_lines(manifest: dict[str, Any]) -> list[str]:
    skipped = manifest["skipped_files"] or []
    if not skipped:
        return ["- Skipped files: none"]
    return [f"- Skipped file: {path}" for path in skipped]


def _bundle_context_lines(manifest: dict[str, Any]) -> list[str]:
    entries = manifest["status"]["entries"]
    status = "dirty" if entries else "clean"
    return [
        f"- Branch: `{manifest['git']['branch'] or '<unknown>'}`",
        f"- HEAD: `{manifest['git']['sha']}`",
        f"- Working tree status: {status} at bundle creation.",
        f"- Included working-tree files: {manifest['included_file_count']}",
        *_dirty_surface_lines(manifest),
        *_dirty_path_lines(manifest),
        *_excluded_artifact_lines(manifest),
        *_skipped_file_lines(manifest),
    ]


def _required_reading_order(included_files: tuple[str, ...]) -> tuple[str, ...]:
    included = {f"repo/{path}" for path in included_files}
    optional_contracts = tuple(path for path in OPTIONAL_REPO_CONTRACT_FILES if path in included)
    return REQUIRED_BUNDLE_READING_ORDER + optional_contracts


def _manifest_required_reading_order(manifest: dict[str, Any] | None) -> tuple[str, ...]:
    if manifest is None:
        return REQUIRED_BUNDLE_READING_ORDER
    return tuple(manifest.get("required_reading_order", REQUIRED_BUNDLE_READING_ORDER))


def _manifest_follow_up_repo_reading(manifest: dict[str, Any] | None) -> str:
    if manifest is None:
        return FOLLOW_UP_REPO_READING_HINT
    return str(manifest.get("follow_up_repo_reading", FOLLOW_UP_REPO_READING_HINT))


def render_chatgpt_pro_prompt(*, archive_name: str, objective: str, manifest: dict[str, Any] | None = None) -> str:
    context_lines = _bundle_context_lines(manifest) if manifest is not None else []
    context_block = ["Bundle context:", *context_lines, ""] if context_lines else []
    required_reading_order = _manifest_required_reading_order(manifest)
    follow_up_repo_reading = _manifest_follow_up_repo_reading(manifest)
    return "\n".join(
        [
            "I uploaded a `.tar.gz` dispatch bundle named `{archive_name}`.".format(archive_name=archive_name),
            "",
            "Objective:",
            objective,
            "",
            *context_block,
            "Required reading order:",
            *[f"{index}. `{path}`" for index, path in enumerate(required_reading_order, start=1)],
            "",
            "Then inspect:",
            f"- `{follow_up_repo_reading}`",
            "",
            "Evidence hierarchy:",
            "- Treat `BUNDLE_MANIFEST.json`, `OPS_STATUS.json`, `GIT_STATUS.txt`, and `GIT_DIFF.patch` as primary evidence.",
            "- Treat files under `repo/` as secondary evidence for implementation details and source contracts.",
            "- Do not rely on stale summaries, prior chat context, or outside assumptions when they conflict with bundle evidence.",
            "",
            "Repo guardrails:",
            "- Treat the bundle as the latest provided working-tree evidence, not as a clean release unless the context says clean.",
            "- Preserve the source/artifact boundary described by the harness and repo policy docs.",
            "- Do not assume ignored raw resolved-3D inputs, local caches, or private mirrors are present.",
            "- Treat excluded protected artifacts as unavailable for refresh or inspection unless explicitly included in the bundle.",
            "- Keep artifact-refresh, source-edit, report, Julia, references, and release lanes separate.",
            "",
            "Output contract:",
            *[f"- `{section}`" for section in OUTPUT_CONTRACT_SECTIONS],
            "",
            "Blocked-condition rules:",
            "- Stop and report if any listed required-reading file path is absent from the bundle.",
            "- Stop and report if the task depends on ignored raw resolved-3D inputs, local caches, or private mirrors.",
            "- Stop and report if protected artifacts would need refresh without explicit artifact-refresh scope.",
            "- Stop and report any conflict between metadata/status/diff evidence and repo file evidence.",
        ]
    )


def _harness_markdown(*, archive_name: str, objective: str, manifest: dict[str, Any], prompt: str) -> str:
    required_reading_order = _manifest_required_reading_order(manifest)
    follow_up_repo_reading = _manifest_follow_up_repo_reading(manifest)
    return "\n".join(
        [
            "# ChatGPT PRO Dispatch Harness",
            "",
            f"Archive: `{archive_name}`",
            f"Target: `{manifest['target']}`",
            f"Branch: `{manifest['git']['branch'] or '<unknown>'}`",
            f"HEAD: `{manifest['git']['sha']}`",
            "",
            "## Objective",
            "",
            objective,
            "",
            "## Required Reading Order",
            "",
            *[f"{index}. `{path}`" for index, path in enumerate(required_reading_order, start=1)],
            "",
            "## Follow-up Repo Reading",
            "",
            f"- `{follow_up_repo_reading}`",
            "",
            "## Bundle Context",
            "",
            *_bundle_context_lines(manifest),
            "",
            "## Operating Rules",
            "",
            "- Treat this tarball as a read-only evidence snapshot.",
            "- Re-anchor every recommendation in files contained in `repo/` or the included status/diff files.",
            "- Do not infer from stale paths, older package names, or missing ignored local data.",
            "- Keep artifact-refresh, source-edit, report, Julia, references, and release lanes separate.",
            "- Use `pipenv run ops-orchestrate ready-to-commit` as the orchestrator-owned final gate.",
            "",
            "## Expected Output",
            "",
            *[f"- {section}" for section in OUTPUT_CONTRACT_SECTIONS],
            "",
            "## Browser Prompt",
            "",
            prompt,
            "",
        ]
    )


def create_dispatch_bundle(
    repo: Path,
    *,
    target: str = "chatgpt-pro",
    objective: str,
    outdir: Path = DEFAULT_BUNDLE_OUTDIR,
    allow_unclassified: bool = False,
    include_protected_artifacts: bool = False,
) -> BundleResult:
    if target not in SUPPORTED_BUNDLE_TARGETS:
        raise ValueError(f"unsupported bundle target: {target}")
    root = repo.expanduser().resolve()
    report = status_report(root)
    if report.protected_paths and not include_protected_artifacts:
        protected = ", ".join(report.protected_paths)
        raise ValueError(f"protected artifact paths require --include-protected-artifacts: {protected}")
    if report.unclassified_paths and not allow_unclassified:
        unclassified = ", ".join(report.unclassified_paths)
        raise ValueError(
            f"unclassified dirty paths require --allow-unclassified after ownership review: {unclassified}"
        )

    output_dir = _resolve_bundle_outdir(root, outdir)
    output_dir.mkdir(parents=True, exist_ok=True)

    generated_at = datetime.now(UTC)
    timestamp = generated_at.strftime("%Y%m%dT%H%M%SZ")
    sha = git_sha(root)
    archive_name = f"{root.name}-{_safe_slug(target)}-dispatch-{timestamp}-{sha[:12]}.tar.gz"
    archive_path = output_dir / archive_name
    bundle_root = archive_name.removesuffix(".tar.gz")

    included_files, excluded_files, skipped_files = _filter_bundle_files(
        root, include_protected_artifacts=include_protected_artifacts
    )
    required_reading_order = _required_reading_order(included_files)
    status_text = git_status_short(root)
    diff_text = _diff_text(root)
    manifest: dict[str, Any] = {
        "schema_version": 1,
        "target": target,
        "objective": objective,
        "generated_at_utc": generated_at.isoformat().replace("+00:00", "Z"),
        "git": {
            "sha": sha,
            "branch": report.branch,
            "status_command": "git status --short --branch --untracked-files=all",
            "diff_command": "git diff --binary && git diff --cached --binary",
        },
        "status": {
            "dirty_by_surface": report.dirty_by_surface,
            "entries": [asdict(entry) for entry in report.entries],
            "protected_paths": list(report.protected_paths),
            "unclassified_paths": list(report.unclassified_paths),
        },
        "archive_policy": {
            "included_source": "git tracked files plus non-ignored untracked files from the working tree",
            "ignored_files": "excluded by git ignore rules",
            "protected_artifacts_included": include_protected_artifacts,
        },
        "harness_files": list(HARNESS_FILES),
        "required_reading_order": list(required_reading_order),
        "follow_up_repo_reading": FOLLOW_UP_REPO_READING_HINT,
        "included_file_count": len(included_files),
        "excluded_files": list(excluded_files),
        "skipped_files": list(skipped_files),
    }
    ops_status_json = json.dumps(asdict(report), indent=2, sort_keys=True) + "\n"
    manifest_json = json.dumps(manifest, indent=2, sort_keys=True) + "\n"
    prompt = render_chatgpt_pro_prompt(archive_name=archive_name, objective=objective, manifest=manifest)
    harness = _harness_markdown(archive_name=archive_name, objective=objective, manifest=manifest, prompt=prompt)

    mtime = int(generated_at.timestamp())
    with tarfile.open(archive_path, "w:gz") as tar:
        _tar_text(tar, f"{bundle_root}/CHATGPT_PRO_PROMPT.md", prompt, mtime=mtime)
        _tar_text(tar, f"{bundle_root}/CHATGPT_PRO_DISPATCH.md", harness, mtime=mtime)
        _tar_text(tar, f"{bundle_root}/BUNDLE_MANIFEST.json", manifest_json, mtime=mtime)
        _tar_text(tar, f"{bundle_root}/OPS_STATUS.json", ops_status_json, mtime=mtime)
        _tar_text(tar, f"{bundle_root}/GIT_STATUS.txt", status_text, mtime=mtime)
        _tar_text(tar, f"{bundle_root}/GIT_DIFF.patch", diff_text, mtime=mtime)
        for relative in included_files:
            tar.add(root / relative, arcname=f"{bundle_root}/repo/{relative}", recursive=False)

    return BundleResult(
        archive_path=archive_path,
        archive_sha256=_archive_sha256(archive_path),
        prompt=prompt,
        manifest=manifest,
        included_files=included_files,
        excluded_files=excluded_files,
        skipped_files=skipped_files,
    )
