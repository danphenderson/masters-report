"""Run Julia package validation through the Python ops command surface."""

from __future__ import annotations

import argparse
import json
import os
import shutil
import subprocess
import sys
from pathlib import Path

DEFAULT_LAUNCHER = "packages/stenotic-hemodynamics/bin/julia-release"
DEFAULT_TEST_FILE = "packages/stenotic-hemodynamics/test/runtests.jl"


def repo_root() -> Path:
    path = Path(__file__).resolve()
    for parent in path.parents:
        if (parent / "packages" / "stenotic-hemodynamics").is_dir() and (parent / "packages" / "ops").is_dir():
            return parent
    raise RuntimeError("could not locate repository root")


def resolve_repo_path(repo: Path, path: str) -> Path:
    candidate = Path(path).expanduser()
    if candidate.is_absolute():
        return candidate.resolve()
    return (repo / candidate).resolve()


def display_path(repo: Path, path: Path) -> str:
    try:
        return path.relative_to(repo).as_posix()
    except ValueError:
        return path.as_posix()


def parse_lcov(path: Path) -> dict[str, dict[int, int]]:
    coverage: dict[str, dict[int, int]] = {}
    current_source: str | None = None
    for line in path.read_text(encoding="utf-8", errors="replace").splitlines():
        if line.startswith("SF:"):
            current_source = line[3:]
            coverage.setdefault(current_source, {})
        elif line.startswith("DA:") and current_source is not None:
            location, hits_text, *_ = line[3:].split(",")
            try:
                line_number = int(location)
                hits = int(float(hits_text))
            except ValueError:
                continue
            coverage[current_source][line_number] = coverage[current_source].get(line_number, 0) + hits
        elif line == "end_of_record":
            current_source = None
    return coverage


def merge_lcov_files(tracefiles: list[Path], output: Path, summary: Path) -> None:
    merged: dict[str, dict[int, int]] = {}
    for tracefile in tracefiles:
        for source, lines in parse_lcov(tracefile).items():
            source_lines = merged.setdefault(source, {})
            for line_number, hits in lines.items():
                source_lines[line_number] = source_lines.get(line_number, 0) + hits

    output.parent.mkdir(parents=True, exist_ok=True)
    total_lines = 0
    covered_lines = 0
    with output.open("w", encoding="utf-8") as handle:
        handle.write("TN:\n")
        for source in sorted(merged):
            handle.write(f"SF:{source}\n")
            for line_number, hits in sorted(merged[source].items()):
                handle.write(f"DA:{line_number},{hits}\n")
            found = len(merged[source])
            hit = sum(1 for hits in merged[source].values() if hits > 0)
            total_lines += found
            covered_lines += hit
            handle.write(f"LH:{hit}\n")
            handle.write(f"LF:{found}\n")
            handle.write("end_of_record\n")

    payload = {
        "covered_lines": covered_lines,
        "line_rate": covered_lines / total_lines if total_lines else 0.0,
        "total_lines": total_lines,
        "tracefiles": [str(path) for path in tracefiles],
    }
    summary.write_text(json.dumps(payload, indent=2, sort_keys=True) + "\n", encoding="utf-8")


def run(command: list[str], repo: Path) -> int:
    print(f"+ {' '.join(command)}", flush=True)
    return subprocess.run(command, cwd=repo, check=False).returncode


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--repo", type=Path, default=None, help="repository root; detected by default")
    parser.add_argument(
        "--launcher",
        default=DEFAULT_LAUNCHER,
        help=f"Julia release launcher relative to the repository root (default: {DEFAULT_LAUNCHER})",
    )
    parser.add_argument("--coverage", action="store_true", help="run Julia tests with coverage and write LCOV reports")
    parser.add_argument(
        "--coverage-dir",
        type=Path,
        default=Path("tmp/coverage/julia"),
        help="coverage output directory relative to the repository root",
    )
    parser.add_argument(
        "--test-file",
        default=DEFAULT_TEST_FILE,
        help=f"Julia test entrypoint relative to the repository root (default: {DEFAULT_TEST_FILE})",
    )
    parser.add_argument("julia_args", nargs=argparse.REMAINDER, help="extra arguments appended after the test file")
    args = parser.parse_args(argv)

    repo = args.repo.expanduser().resolve() if args.repo is not None else repo_root()
    launcher = resolve_repo_path(repo, args.launcher)
    test_file = resolve_repo_path(repo, args.test_file)
    missing = [path for path in (launcher, test_file) if not path.exists()]
    if missing:
        for path in missing:
            print(f"missing required Julia validation path: {path}", file=sys.stderr)
        return 1
    if not launcher.is_file():
        print(f"Julia validation launcher is not a file: {launcher}", file=sys.stderr)
        return 1
    if not os.access(launcher, os.X_OK):
        print(f"Julia validation launcher is not executable: {launcher}", file=sys.stderr)
        return 1
    if not test_file.is_file():
        print(f"Julia validation test entrypoint is not a file: {test_file}", file=sys.stderr)
        return 1

    coverage_dir = resolve_repo_path(repo, args.coverage_dir)
    coverage_args: list[str] = []
    if args.coverage:
        if coverage_dir.exists():
            shutil.rmtree(coverage_dir)
        raw_dir = coverage_dir / "raw"
        raw_dir.mkdir(parents=True, exist_ok=True)
        tracefile_pattern = raw_dir / "julia-%p.info"
        coverage_args.append(f"--code-coverage={tracefile_pattern}")

    command = [display_path(repo, launcher), *coverage_args, display_path(repo, test_file), *args.julia_args]
    status = run(command, repo)
    if args.coverage:
        tracefiles = sorted((coverage_dir / "raw").glob("*.info"))
        merge_lcov_files(tracefiles, coverage_dir / "lcov.info", coverage_dir / "coverage-summary.json")
    return status


if __name__ == "__main__":
    raise SystemExit(main())
