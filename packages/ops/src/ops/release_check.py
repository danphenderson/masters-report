"""Run the source-release validation gates through the Python ops surface."""

from __future__ import annotations

import argparse
import subprocess
import sys
from dataclasses import dataclass
from pathlib import Path

from ops.git_state import git_status_short

DEFAULT_REPORT_OUTDIR = "/tmp/masters-report-build"
MODES = ("patch", "release")
LATEX_BYPRODUCT_SUFFIXES = {
    ".acn",
    ".acr",
    ".alg",
    ".aux",
    ".bbl",
    ".bcf",
    ".blg",
    ".fdb_latexmk",
    ".fls",
    ".glg",
    ".glo",
    ".gls",
    ".ist",
    ".lof",
    ".log",
    ".lot",
    ".out",
    ".run.xml",
    ".synctex.gz",
    ".toc",
}
CACHE_PARTS = {"__pycache__", ".pytest_cache", ".ruff_cache", ".mypy_cache", ".ipynb_checkpoints"}
PRIVATE_REFERENCE_SUFFIXES = {".pdf", ".html", ".htm"}
ALLOWED_PUBLIC_VAR_TRACKED = {"public/var/logs/.gitkeep"}


@dataclass(frozen=True)
class Gate:
    name: str
    command: list[str]
    capture: bool = False


def repo_root() -> Path:
    path = Path(__file__).resolve()
    for parent in path.parents:
        if (parent / "packages" / "julia").is_dir() and (parent / "packages" / "ops").is_dir():
            return parent
    raise RuntimeError("could not locate repository root")


def run_gate(gate: Gate, repo: Path) -> subprocess.CompletedProcess[str]:
    print(f"\n==> {gate.name}", flush=True)
    print(f"+ {' '.join(gate.command)}", flush=True)
    return subprocess.run(
        gate.command,
        cwd=repo,
        text=True,
        capture_output=gate.capture,
        check=False,
    )


def print_captured(result: subprocess.CompletedProcess[str]) -> None:
    if result.stdout:
        print(result.stdout, end="" if result.stdout.endswith("\n") else "\n")
    if result.stderr:
        print(result.stderr, end="" if result.stderr.endswith("\n") else "\n", file=sys.stderr)


def status_has_dirty_entries(status_stdout: str) -> bool:
    return any(line and not line.startswith("## ") for line in status_stdout.splitlines())


def tracked_paths(repo: Path) -> list[str]:
    result = subprocess.run(
        ["git", "ls-files"],
        cwd=repo,
        text=True,
        capture_output=True,
        check=False,
    )
    if result.returncode != 0:
        raise RuntimeError(result.stderr.strip() or "git ls-files failed")
    return [line for line in result.stdout.splitlines() if line]


def _tracked_hygiene_issue(path: str) -> str | None:
    path_obj = Path(path)
    parts = set(path_obj.parts)
    suffixes = "".join(path_obj.suffixes[-2:]).lower()
    suffix = path_obj.suffix.lower()
    effective_suffix = suffixes if suffixes in LATEX_BYPRODUCT_SUFFIXES else suffix

    if parts & CACHE_PARTS or suffix in {".pyc", ".pyo"}:
        return f"tracked cache or Python byproduct: {path}"
    if effective_suffix in LATEX_BYPRODUCT_SUFFIXES:
        return f"tracked LaTeX byproduct: {path}"
    if path in {"public/final-report.pdf", "final-report.pdf", "report/final-report.pdf"}:
        return f"tracked final PDF artifact: {path}"
    if path.startswith("public/references/") and suffix in PRIVATE_REFERENCE_SUFFIXES:
        return f"tracked private reference mirror: {path}"
    if path.startswith("public/var/") and path not in ALLOWED_PUBLIC_VAR_TRACKED:
        return f"tracked public/var artifact outside allowlist: {path}"
    return None


def _status_path_from_short_line(line: str) -> str:
    raw = line[3:] if len(line) > 3 else ""
    if " -> " in raw:
        raw = raw.split(" -> ", 1)[1]
    return raw.strip()


def release_hygiene_issues(repo: Path) -> list[str]:
    issues: list[str] = []
    for path in tracked_paths(repo):
        issue = _tracked_hygiene_issue(path)
        if issue is not None:
            issues.append(issue)

    for line in git_status_short(repo).splitlines():
        if not line or line.startswith("## "):
            continue
        path = _status_path_from_short_line(line)
        if path.startswith("public/var/") and path not in ALLOWED_PUBLIC_VAR_TRACKED:
            issues.append(f"dirty public/var artifact outside allowlist: {path}")
    return issues


def parse_args(argv: list[str] | None = None) -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--repo", type=Path, default=None, help="repository root; detected by default")
    parser.add_argument(
        "--mode",
        choices=MODES,
        default="patch",
        help="validation posture: patch allows dirty trees; release enforces clean status and hygiene (default: patch)",
    )
    parser.add_argument(
        "--report-outdir",
        type=Path,
        default=Path(DEFAULT_REPORT_OUTDIR),
        help=f"scratch report build directory (default: {DEFAULT_REPORT_OUTDIR})",
    )
    parser.add_argument(
        "--strict-status",
        action="store_true",
        help="fail if git status contains tracked or untracked non-ignored changes; implied by --mode release",
    )
    parser.add_argument(
        "--sync-final-pdf",
        action="store_true",
        help="allow ops-build-report to refresh public/final-report.pdf after passing gates",
    )
    return parser.parse_args(argv)


def gates(repo: Path, report_outdir: Path, sync_final_pdf: bool) -> list[Gate]:
    report_command = [
        sys.executable,
        "-m",
        "ops.build_report",
        "--repo",
        repo.as_posix(),
        "--outdir",
        report_outdir.as_posix(),
    ]
    if not sync_final_pdf:
        report_command.append("--no-sync-final-pdf")

    return [
        Gate("git status", ["git", "status", "--short", "--branch", "--untracked-files=all"], capture=True),
        Gate("diff check", ["git", "diff", "--check"]),
        Gate("reference audit", [sys.executable, "-m", "ops.audit_references", "--repo", repo.as_posix()]),
        Gate(
            "orchestration docs contract",
            [sys.executable, "-m", "ops.orchestrate", "--repo", repo.as_posix(), "docs-contract"],
        ),
        Gate("Julia package validation", [sys.executable, "-m", "ops.julia_check", "--repo", repo.as_posix()]),
        Gate("Python ops validation", [sys.executable, "-m", "ops.python_check", "--repo", repo.as_posix()]),
        Gate("report build validation", report_command),
    ]


def main(argv: list[str] | None = None) -> int:
    args = parse_args(argv)
    repo = args.repo.expanduser().resolve() if args.repo is not None else repo_root()
    report_outdir = args.report_outdir.expanduser()
    strict_status = args.strict_status or args.mode == "release"

    for gate in gates(repo, report_outdir, args.sync_final_pdf):
        result = run_gate(gate, repo)
        if gate.capture:
            print_captured(result)
        if gate.name == "git status" and strict_status and status_has_dirty_entries(result.stdout):
            mode_hint = " --mode patch" if args.mode == "release" else " without --strict-status"
            print(f"git status is not clean; rerun{mode_hint} for dirty-tree validation.", file=sys.stderr)
            return 1
        if gate.name == "git status" and args.mode == "release":
            hygiene_issues = release_hygiene_issues(repo)
            if hygiene_issues:
                print("release hygiene failed:", file=sys.stderr)
                for issue in hygiene_issues:
                    print(f"  {issue}", file=sys.stderr)
                return 1
        if result.returncode != 0:
            return result.returncode
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
