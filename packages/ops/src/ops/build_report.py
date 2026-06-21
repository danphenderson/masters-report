#!/usr/bin/env python3
"""Build the report through the local policy gates."""

from __future__ import annotations

import argparse
import hashlib
import json
import os
import re
import shutil
import subprocess
import sys
import time
from dataclasses import dataclass
from pathlib import Path
from typing import Any


DEFAULT_ENTRYPOINT = "report/final-report.tex"
DEFAULT_OUTDIR = "/tmp/masters-report-build"
DEFAULT_FINAL_PDF = "public/final-report.pdf"
SUMMARY_FILENAME = "report-build-summary.json"

CONSUMED_INPUT_FILES = frozenset({"report/final-report.tex", "public/references/references.bib"})
CONSUMED_INPUT_ROOTS = (
    "report/frontmatter/",
    "report/sections/",
    "report/appendices/",
    "report/preamble/",
    "report/assets/tikz/",
    "report/assets/data/",
    "report/assets/tables/",
    "report/assets/rendered/",
)

STABILIZATION_PATTERNS = (
    re.compile(r"maximum runs? of .* reached", re.IGNORECASE),
    re.compile(r"too many passes", re.IGNORECASE),
    re.compile(r"label\(s\) may have changed", re.IGNORECASE),
    re.compile(r"rerun to get cross-references right", re.IGNORECASE),
    re.compile(r"Package rerunfilecheck Warning:.*rerun", re.IGNORECASE),
    re.compile(r"\(rerunfilecheck\).*rerun", re.IGNORECASE),
)

HARD_LATEX_FAILURE_PATTERNS = (
    re.compile(r"^!", re.MULTILINE),
    re.compile(r"LaTeX Error:", re.IGNORECASE),
    re.compile(r"Package .* Error:", re.IGNORECASE),
    re.compile(r"Emergency stop", re.IGNORECASE),
    re.compile(r"Fatal error", re.IGNORECASE),
    re.compile(r"No pages of output", re.IGNORECASE),
    re.compile(r"Undefined control sequence", re.IGNORECASE),
    re.compile(r"File .* not found", re.IGNORECASE),
    re.compile(r"I couldn'?t open file", re.IGNORECASE),
    re.compile(r"Biber error", re.IGNORECASE),
)

BLOCKING_LOG_PATTERNS = (
    re.compile(r"undefined references?", re.IGNORECASE),
    re.compile(r"undefined citations?", re.IGNORECASE),
    re.compile(r"citation .*undefined", re.IGNORECASE),
    re.compile(r"reference .*undefined", re.IGNORECASE),
    re.compile(r"rerun to get cross-references right", re.IGNORECASE),
    re.compile(r"label\(s\) may have changed", re.IGNORECASE),
    re.compile(r"Package rerunfilecheck Warning:.*rerun", re.IGNORECASE),
    re.compile(r"\(rerunfilecheck\).*rerun", re.IGNORECASE),
    re.compile(r"multiply[- ]defined labels?", re.IGNORECASE),
    re.compile(r"label .*multiply defined", re.IGNORECASE),
)


@dataclass(frozen=True)
class LogScan:
    blocking_log_issues: list[str]
    warning_counts: dict[str, int]


def parse_args(argv: list[str] | None = None) -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--repo",
        type=Path,
        default=Path.cwd(),
        help="repository root to build from (default: current working directory)",
    )
    parser.add_argument(
        "--entrypoint",
        default=DEFAULT_ENTRYPOINT,
        help=f"TeX entrypoint relative to the repository root (default: {DEFAULT_ENTRYPOINT})",
    )
    parser.add_argument(
        "--outdir",
        type=Path,
        default=Path(DEFAULT_OUTDIR),
        help=f"scratch output directory for latexmk products (default: {DEFAULT_OUTDIR})",
    )
    parser.add_argument(
        "--final-pdf",
        type=Path,
        default=Path(DEFAULT_FINAL_PDF),
        help=(
            "local PDF artifact to refresh after all report build gates pass, "
            f"relative to the repository root unless absolute (default: {DEFAULT_FINAL_PDF})"
        ),
    )
    parser.add_argument(
        "--no-sync-final-pdf",
        action="store_true",
        help="skip refreshing the local public/final-report.pdf artifact after a passing build",
    )
    parser.add_argument(
        "--verbose",
        action="store_true",
        help="replay captured preamble and LaTeX process output even when commands pass",
    )
    return parser.parse_args(argv)


def resolve_outdir(repo: Path, outdir: Path) -> Path:
    expanded = outdir.expanduser()
    if expanded.is_absolute():
        return expanded.resolve()
    return (repo / expanded).resolve()


def resolve_repo_path(repo: Path, path: Path) -> Path:
    expanded = path.expanduser()
    if expanded.is_absolute():
        return expanded.resolve()
    return (repo / expanded).resolve()


def artifact_paths(outdir: Path, entrypoint: str) -> dict[str, Path]:
    stem = Path(entrypoint).stem
    return {
        "pdf": outdir / f"{stem}.pdf",
        "fls": outdir / f"{stem}.fls",
        "log": outdir / f"{stem}.log",
        "summary": outdir / SUMMARY_FILENAME,
    }


def normalize_repo_input(raw_input: str, repo: Path) -> str | None:
    raw = raw_input.strip()
    while raw.startswith("./"):
        raw = raw[2:]
    if not raw:
        return None

    path = Path(raw)
    absolute = path if path.is_absolute() else repo / path
    try:
        relative = absolute.resolve(strict=False).relative_to(repo.resolve())
    except ValueError:
        return None
    return relative.as_posix()


def is_consumed_report_input(relative_path: str) -> bool:
    return relative_path in CONSUMED_INPUT_FILES or any(relative_path.startswith(root) for root in CONSUMED_INPUT_ROOTS)


def filter_consumed_inputs(relative_paths: list[str]) -> list[str]:
    unique: dict[str, None] = {}
    for relative_path in relative_paths:
        if is_consumed_report_input(relative_path):
            unique.setdefault(relative_path, None)
    return list(unique)


def parse_fls_inputs(fls_path: Path, repo: Path) -> list[str]:
    inputs: list[str] = []
    for line in fls_path.read_text(encoding="utf-8", errors="replace").splitlines():
        if not line.startswith("INPUT "):
            continue
        normalized = normalize_repo_input(line.removeprefix("INPUT "), repo)
        if normalized is not None:
            inputs.append(normalized)
    return filter_consumed_inputs(inputs)


def tracked_git_paths(repo: Path) -> set[str]:
    result = subprocess.run(
        ["git", "ls-files", "-z"],
        cwd=repo,
        text=False,
        capture_output=True,
        check=False,
    )
    if result.returncode != 0:
        stderr = result.stderr.decode("utf-8", errors="replace").strip()
        raise RuntimeError(f"git ls-files failed: {stderr}")
    return {path.decode("utf-8", errors="replace") for path in result.stdout.split(b"\0") if path}


def audit_untracked_consumed_inputs(
    repo: Path, consumed_inputs: list[str], tracked_paths: set[str] | None = None
) -> list[str]:
    tracked = tracked_git_paths(repo) if tracked_paths is None else tracked_paths
    return [path for path in consumed_inputs if path not in tracked]


def scan_log_text(log_text: str) -> LogScan:
    blocking: list[str] = []
    seen_blocking: set[str] = set()
    for line in log_text.splitlines():
        stripped = line.strip()
        if not stripped:
            continue
        if any(pattern.search(stripped) for pattern in BLOCKING_LOG_PATTERNS) and stripped not in seen_blocking:
            blocking.append(stripped)
            seen_blocking.add(stripped)

    warning_counts = {
        "overfull_boxes": len(re.findall(r"Overfull \\[hv]box", log_text)),
        "underfull_boxes": len(re.findall(r"Underfull \\[hv]box", log_text)),
        "hyperref_pdf_string": len(
            re.findall(r"Package hyperref Warning: Token not allowed in a PDF string", log_text)
        ),
    }
    warning_lines = [line.strip() for line in log_text.splitlines() if re.search(r"\bWarning:", line)]
    warning_counts["other_warnings"] = sum(
        1
        for line in warning_lines
        if not re.search(r"Package hyperref Warning: Token not allowed in a PDF string", line)
        and not any(pattern.search(line) for pattern in BLOCKING_LOG_PATTERNS)
    )
    return LogScan(blocking_log_issues=blocking, warning_counts=warning_counts)


def scan_log_file(log_path: Path) -> LogScan:
    if not log_path.exists():
        return LogScan(blocking_log_issues=[f"missing log file: {log_path}"], warning_counts={})
    return scan_log_text(log_path.read_text(encoding="utf-8", errors="replace"))


def run_command(command: list[str], repo: Path) -> subprocess.CompletedProcess[str]:
    print(f"+ {' '.join(command)}", flush=True)
    return subprocess.run(command, cwd=repo, text=True, capture_output=True, check=False)


def print_process_output(result: subprocess.CompletedProcess[str]) -> None:
    if result.stdout:
        write_process_output(sys.stdout, result.stdout)
    if result.stderr:
        write_process_output(sys.stderr, result.stderr)


def maybe_print_process_output(result: subprocess.CompletedProcess[str], *, verbose: bool) -> None:
    if verbose or result.returncode != 0:
        print_process_output(result)


def write_process_output(stream: Any, text: str) -> None:
    payload = text if text.endswith("\n") else f"{text}\n"
    try:
        fd = stream.fileno()
    except (AttributeError, OSError):
        stream.write(payload)
        stream.flush()
        return

    data = payload.encode(getattr(stream, "encoding", None) or "utf-8", errors="replace")
    offset = 0
    while offset < len(data):
        try:
            written = os.write(fd, data[offset : offset + 16384])
            if written == 0:
                raise RuntimeError("process output stream accepted zero bytes")
            offset += written
        except BlockingIOError:
            time.sleep(0.05)


def should_rerun_for_stabilization(
    result: subprocess.CompletedProcess[str],
    pdf_path: Path,
    fls_path: Path,
) -> bool:
    if result.returncode == 0 or not pdf_path.exists() or not fls_path.exists():
        return False
    combined_output = f"{result.stdout}\n{result.stderr}"
    has_stabilization_signal = any(pattern.search(combined_output) for pattern in STABILIZATION_PATTERNS)
    has_hard_failure = any(pattern.search(combined_output) for pattern in HARD_LATEX_FAILURE_PATTERNS)
    return has_stabilization_signal and not has_hard_failure


def write_summary(summary_path: Path, summary: dict[str, Any]) -> None:
    summary_path.parent.mkdir(parents=True, exist_ok=True)
    summary_path.write_text(json.dumps(summary, indent=2, sort_keys=True) + "\n", encoding="utf-8")


def sha256_file(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def sync_final_pdf(source_pdf: Path, final_pdf: Path) -> dict[str, Any]:
    final_pdf.parent.mkdir(parents=True, exist_ok=True)
    if source_pdf.resolve(strict=False) != final_pdf.resolve(strict=False):
        shutil.copy2(source_pdf, final_pdf)
    return {
        "path": final_pdf.as_posix(),
        "sha256": sha256_file(final_pdf),
    }


def build_initial_summary(
    repo: Path,
    entrypoint: str,
    outdir: Path,
    final_pdf: Path | None,
    preamble_command: list[str],
    latexmk_command: list[str],
    paths: dict[str, Path],
    verbose: bool,
) -> dict[str, Any]:
    return {
        "command": {
            "preamble_audit": preamble_command,
            "latexmk": latexmk_command,
        },
        "repo": repo.as_posix(),
        "entrypoint": entrypoint,
        "outdir": outdir.as_posix(),
        "pdf_path": paths["pdf"].as_posix(),
        "fls_path": paths["fls"].as_posix(),
        "log_path": paths["log"].as_posix(),
        "synced_pdf": None,
        "sync_pdf_target": final_pdf.as_posix() if final_pdf is not None else None,
        "consumed_inputs": [],
        "untracked_consumed_inputs": [],
        "blocking_log_issues": [],
        "warning_counts": {},
        "status": "not_started",
        "failure_reasons": [],
        "verbose": verbose,
    }


def main(argv: list[str] | None = None) -> int:
    args = parse_args(argv)
    repo = args.repo.expanduser().resolve()
    outdir = resolve_outdir(repo, args.outdir)
    final_pdf = None if args.no_sync_final_pdf else resolve_repo_path(repo, args.final_pdf)
    entrypoint = args.entrypoint
    paths = artifact_paths(outdir, entrypoint)

    preamble_command = [sys.executable, "-m", "ops.audit_tex_preamble", "--repo", repo.as_posix()]
    latexmk_command = [
        "latexmk",
        "-g",
        "-pdf",
        "-interaction=nonstopmode",
        "-halt-on-error",
        f"-outdir={outdir.as_posix()}",
        entrypoint,
    ]
    summary = build_initial_summary(
        repo,
        entrypoint,
        outdir,
        final_pdf,
        preamble_command,
        latexmk_command,
        paths,
        args.verbose,
    )

    preamble_result = run_command(preamble_command, repo)
    maybe_print_process_output(preamble_result, verbose=args.verbose)
    if preamble_result.returncode != 0:
        summary["status"] = "failed"
        summary["failure_reasons"] = ["preamble_audit_failed"]
        write_summary(paths["summary"], summary)
        return preamble_result.returncode

    latex_result = run_command(latexmk_command, repo)
    maybe_print_process_output(latex_result, verbose=args.verbose)
    if should_rerun_for_stabilization(latex_result, paths["pdf"], paths["fls"]):
        print("First latexmk pass reported cross-reference stabilization only; rerunning once.", flush=True)
        latex_result = run_command(latexmk_command, repo)
        maybe_print_process_output(latex_result, verbose=args.verbose)

    if paths["fls"].exists():
        summary["consumed_inputs"] = parse_fls_inputs(paths["fls"], repo)
        summary["untracked_consumed_inputs"] = audit_untracked_consumed_inputs(repo, summary["consumed_inputs"])
    else:
        summary["failure_reasons"].append("missing_fls")

    if paths["log"].exists():
        log_scan = scan_log_file(paths["log"])
        summary["blocking_log_issues"] = log_scan.blocking_log_issues
        summary["warning_counts"] = log_scan.warning_counts
    else:
        summary["failure_reasons"].append("missing_log")

    if not paths["pdf"].exists():
        summary["failure_reasons"].append("missing_pdf")

    if latex_result.returncode != 0:
        summary["failure_reasons"].append("latexmk_failed")
    if summary["untracked_consumed_inputs"]:
        summary["failure_reasons"].append("untracked_consumed_inputs")
    if summary["blocking_log_issues"]:
        summary["failure_reasons"].append("blocking_log_issues")

    summary["status"] = "failed" if summary["failure_reasons"] else "passed"
    if summary["status"] == "passed" and final_pdf is not None:
        summary["synced_pdf"] = sync_final_pdf(paths["pdf"], final_pdf)
    write_summary(paths["summary"], summary)

    if summary["untracked_consumed_inputs"]:
        print("Untracked consumed report inputs:", file=sys.stderr)
        for path in summary["untracked_consumed_inputs"]:
            print(f"  {path}", file=sys.stderr)
    if summary["blocking_log_issues"]:
        print("Blocking LaTeX log issues:", file=sys.stderr)
        for issue in summary["blocking_log_issues"]:
            print(f"  {issue}", file=sys.stderr)
    if summary["synced_pdf"] is not None:
        print(f"Synced final PDF: {summary['synced_pdf']['path']}")
    print(f"Report build status: {summary['status']}")
    if summary["failure_reasons"]:
        print(f"Failure reasons: {', '.join(summary['failure_reasons'])}", file=sys.stderr)
    print(f"Report build summary: {paths['summary']}")

    if summary["failure_reasons"]:
        return latex_result.returncode if latex_result.returncode != 0 else 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
