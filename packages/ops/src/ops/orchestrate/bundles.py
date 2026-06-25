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
    "CHATGPT_PRO_DISPATCH.md",
    "BUNDLE_MANIFEST.json",
    "OPS_STATUS.json",
    "GIT_STATUS.txt",
    "GIT_DIFF.patch",
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


def render_chatgpt_pro_prompt(*, archive_name: str, objective: str) -> str:
    return "\n".join(
        [
            "I uploaded a `.tar.gz` dispatch bundle named `{archive_name}`.".format(archive_name=archive_name),
            "",
            "Use ChatGPT PRO Reasoning as an orchestrator over this repository snapshot.",
            "Extract the bundle, read `CHATGPT_PRO_DISPATCH.md`, then inspect `BUNDLE_MANIFEST.json`, "
            "`GIT_STATUS.txt`, `GIT_DIFF.patch`, and the `repo/` tree before making claims.",
            "",
            "Objective:",
            objective,
            "",
            "Operating rules:",
            "- Treat the bundle as the latest provided working-tree evidence, not as a clean release.",
            "- Preserve the source/artifact boundary described by the harness.",
            "- Do not assume ignored raw resolved-3D inputs, local caches, or private mirrors are present.",
            "- Separate observations, risks, and recommended execution lanes.",
            "- Return a concrete orchestrator plan with file-level scope, validation gates, and blocked conditions.",
        ]
    )


def _harness_markdown(*, archive_name: str, objective: str, manifest: dict[str, Any]) -> str:
    dirty = manifest["status"]["dirty_by_surface"] or {}
    dirty_lines = [f"- {surface}: {count}" for surface, count in sorted(dirty.items())] or ["- none"]
    excluded = manifest["excluded_files"] or []
    excluded_lines = [f"- {path}" for path in excluded] or ["- none"]
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
            "1. `BUNDLE_MANIFEST.json`",
            "2. `GIT_STATUS.txt`",
            "3. `GIT_DIFF.patch`",
            "4. Relevant files under `repo/`",
            "",
            "## Dirty Surfaces",
            "",
            *dirty_lines,
            "",
            "## Excluded Protected Artifacts",
            "",
            *excluded_lines,
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
            "- Current-state summary.",
            "- File-scoped execution lanes.",
            "- Validation commands per lane.",
            "- Blocked conditions and missing local evidence.",
            "- Recommended next dispatch prompt or handback text.",
            "",
            "## Browser Prompt",
            "",
            render_chatgpt_pro_prompt(archive_name=archive_name, objective=objective),
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
        "included_file_count": len(included_files),
        "excluded_files": list(excluded_files),
        "skipped_files": list(skipped_files),
    }
    ops_status_json = json.dumps(asdict(report), indent=2, sort_keys=True) + "\n"
    manifest_json = json.dumps(manifest, indent=2, sort_keys=True) + "\n"
    harness = _harness_markdown(archive_name=archive_name, objective=objective, manifest=manifest)

    mtime = int(generated_at.timestamp())
    with tarfile.open(archive_path, "w:gz") as tar:
        _tar_text(tar, f"{bundle_root}/CHATGPT_PRO_DISPATCH.md", harness, mtime=mtime)
        _tar_text(tar, f"{bundle_root}/BUNDLE_MANIFEST.json", manifest_json, mtime=mtime)
        _tar_text(tar, f"{bundle_root}/OPS_STATUS.json", ops_status_json, mtime=mtime)
        _tar_text(tar, f"{bundle_root}/GIT_STATUS.txt", status_text, mtime=mtime)
        _tar_text(tar, f"{bundle_root}/GIT_DIFF.patch", diff_text, mtime=mtime)
        for relative in included_files:
            tar.add(root / relative, arcname=f"{bundle_root}/repo/{relative}", recursive=False)

    prompt = render_chatgpt_pro_prompt(archive_name=archive_name, objective=objective)
    return BundleResult(
        archive_path=archive_path,
        archive_sha256=_archive_sha256(archive_path),
        prompt=prompt,
        manifest=manifest,
        included_files=included_files,
        excluded_files=excluded_files,
        skipped_files=skipped_files,
    )
