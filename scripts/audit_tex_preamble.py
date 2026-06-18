#!/usr/bin/env python3
"""Audit manuscript TeX files for preamble-boundary violations."""

from __future__ import annotations

import argparse
import re
import subprocess
import sys
from dataclasses import dataclass
from pathlib import Path


EXPECTED_PREAMBLE_INPUTS = (
    "preamble/packages.tex",
    "preamble/bibliography.tex",
    "preamble/hyperref.tex",
    "preamble/theorem-envs.tex",
    "preamble/notation-macros.tex",
    "preamble/macros.tex",
)

IGNORED_DIRS = {
    ".git",
    ".julia_depot",
    ".pytest_cache",
    ".ruff_cache",
    ".venv",
    "__pycache__",
    "tmp",
}


@dataclass(frozen=True)
class AuditIssue:
    path: str
    line: int
    rule: str
    message: str


@dataclass(frozen=True)
class OwnedCommand:
    pattern: re.Pattern[str]
    allowed_paths: frozenset[str]
    rule: str
    message: str


OWNED_COMMANDS = (
    OwnedCommand(
        re.compile(r"\\documentclass\b"),
        frozenset({"final-report.tex"}),
        "documentclass-owner",
        r"\documentclass belongs only in final-report.tex",
    ),
    OwnedCommand(
        re.compile(r"\\usepackage\b"),
        frozenset({"preamble/packages.tex", "preamble/bibliography.tex", "preamble/hyperref.tex"}),
        "package-owner",
        r"\usepackage belongs in the preamble package/bibliography/hyperref files",
    ),
    OwnedCommand(
        re.compile(r"\\usetikzlibrary\b"),
        frozenset({"preamble/packages.tex"}),
        "tikz-library-owner",
        r"\usetikzlibrary belongs in preamble/packages.tex",
    ),
    OwnedCommand(
        re.compile(r"\\graphicspath\b"),
        frozenset({"preamble/packages.tex"}),
        "graphicspath-owner",
        r"\graphicspath belongs in preamble/packages.tex",
    ),
    OwnedCommand(
        re.compile(r"\\(?:geometry|linespread)\s*\{"),
        frozenset({"preamble/packages.tex"}),
        "page-setup-owner",
        r"page setup commands belong in preamble/packages.tex",
    ),
    OwnedCommand(
        re.compile(r"\\renewcommand\*?\s*\{\\arraystretch\}"),
        frozenset({"preamble/packages.tex", "preamble/macros.tex"}),
        "arraystretch-owner",
        r"\arraystretch overrides must be defined in the preamble",
    ),
    OwnedCommand(
        re.compile(r"\\addbibresource\b"),
        frozenset({"preamble/bibliography.tex"}),
        "bibliography-owner",
        r"\addbibresource belongs in preamble/bibliography.tex",
    ),
    OwnedCommand(
        re.compile(r"\\hypersetup\b"),
        frozenset({"preamble/hyperref.tex"}),
        "hyperref-owner",
        r"\hypersetup belongs in preamble/hyperref.tex",
    ),
    OwnedCommand(
        re.compile(r"\\(?:numberwithin|theoremstyle|newtheorem)\b"),
        frozenset({"preamble/theorem-envs.tex"}),
        "theorem-owner",
        r"theorem environment setup belongs in preamble/theorem-envs.tex",
    ),
    OwnedCommand(
        re.compile(r"\\(?:newcommand|DeclareRobustCommand)\*?\b"),
        frozenset({"preamble/notation-macros.tex", "preamble/macros.tex", "preamble/theorem-envs.tex"}),
        "macro-owner",
        r"shared command definitions belong in the preamble macro files",
    ),
    OwnedCommand(
        re.compile(r"\\newenvironment\b"),
        frozenset({"preamble/macros.tex", "preamble/theorem-envs.tex"}),
        "environment-owner",
        r"shared environment definitions belong in the preamble macro/theorem files",
    ),
    OwnedCommand(
        re.compile(r"\\(?:definecolor|colorlet)\b"),
        frozenset({"preamble/macros.tex"}),
        "color-owner",
        r"color definitions belong in preamble/macros.tex",
    ),
    OwnedCommand(
        re.compile(r"\\tikzset\b"),
        frozenset({"preamble/macros.tex"}),
        "tikz-style-owner",
        r"TikZ style definitions belong in preamble/macros.tex",
    ),
    OwnedCommand(
        re.compile(r"\\pgfplotsset\b"),
        frozenset({"preamble/packages.tex", "preamble/macros.tex"}),
        "pgfplots-style-owner",
        r"pgfplots compatibility/defaults belong in the preamble",
    ),
    OwnedCommand(
        re.compile(r"\\lstdefine(?:language|style)\b"),
        frozenset({"preamble/macros.tex"}),
        "listing-style-owner",
        r"listings language/style definitions belong in preamble/macros.tex",
    ),
)


def strip_latex_comment(line: str) -> str:
    """Remove a LaTeX comment, preserving escaped percent signs."""
    for index, character in enumerate(line):
        if character != "%":
            continue
        backslashes = 0
        cursor = index - 1
        while cursor >= 0 and line[cursor] == "\\":
            backslashes += 1
            cursor -= 1
        if backslashes % 2 == 0:
            return line[:index]
    return line


def relpath(path: Path, repo: Path) -> str:
    return path.relative_to(repo).as_posix()


def tracked_tex_files(repo: Path) -> tuple[Path, ...]:
    result = subprocess.run(
        ["git", "ls-files", "--", "*.tex"],
        cwd=repo,
        text=True,
        capture_output=True,
        check=False,
    )
    if result.returncode == 0 and result.stdout.strip():
        return tuple(repo / line for line in result.stdout.splitlines())

    files = []
    for path in repo.rglob("*.tex"):
        relative_parts = path.relative_to(repo).parts
        if any(part in IGNORED_DIRS for part in relative_parts):
            continue
        files.append(path)
    return tuple(sorted(files))


def normalized_input_path(raw_path: str) -> str:
    return raw_path if raw_path.endswith(".tex") else f"{raw_path}.tex"


def check_preamble_order(repo: Path) -> list[AuditIssue]:
    root = repo / "final-report.tex"
    lines = root.read_text(encoding="utf-8").splitlines()
    input_pattern = re.compile(r"\\input\{(preamble/[^}]+)\}")
    actual = []
    first_line = 1
    for line_number, line in enumerate(lines, start=1):
        stripped = strip_latex_comment(line)
        match = input_pattern.search(stripped)
        if match:
            if not actual:
                first_line = line_number
            actual.append(normalized_input_path(match.group(1)))

    if tuple(actual) == EXPECTED_PREAMBLE_INPUTS:
        return []

    expected = ", ".join(EXPECTED_PREAMBLE_INPUTS)
    observed = ", ".join(actual) if actual else "<none>"
    return [
        AuditIssue(
            "final-report.tex",
            first_line,
            "preamble-order",
            f"expected preamble input order [{expected}], observed [{observed}]",
        )
    ]


def check_owned_commands(repo: Path, tex_files: tuple[Path, ...]) -> list[AuditIssue]:
    issues = []
    for path in tex_files:
        relative = relpath(path, repo)
        for line_number, line in enumerate(path.read_text(encoding="utf-8").splitlines(), start=1):
            stripped = strip_latex_comment(line)
            if not stripped.strip():
                continue
            for command in OWNED_COMMANDS:
                if command.pattern.search(stripped) and relative not in command.allowed_paths:
                    issues.append(AuditIssue(relative, line_number, command.rule, command.message))
    return issues


def tikz_options_include_fig(options: str) -> bool:
    return any(part.strip() == "fig" for part in options.split(","))


def check_tikz_figure_styles(repo: Path, tex_files: tuple[Path, ...]) -> list[AuditIssue]:
    issues = []
    begin_pattern = re.compile(r"\\begin\{tikzpicture\}\s*(?:\[(?P<options>[^\]]*)\])?", re.DOTALL)
    for path in tex_files:
        relative = relpath(path, repo)
        if not relative.startswith("figures/static/static/tikz/"):
            continue
        raw_lines = path.read_text(encoding="utf-8").splitlines()
        text = "\n".join(strip_latex_comment(line) for line in raw_lines)
        for match in begin_pattern.finditer(text):
            line_number = text.count("\n", 0, match.start()) + 1
            options = match.group("options")
            if options is None or not tikz_options_include_fig(options):
                issues.append(
                    AuditIssue(
                        relative,
                        line_number,
                        "tikz-fig-style",
                        r"figure TikZ pictures must opt into the shared [fig] style",
                    )
                )
    return issues


def audit(repo: Path) -> tuple[list[AuditIssue], int]:
    tex_files = tracked_tex_files(repo)
    issues = []
    issues.extend(check_preamble_order(repo))
    issues.extend(check_owned_commands(repo, tex_files))
    issues.extend(check_tikz_figure_styles(repo, tex_files))
    return sorted(issues, key=lambda issue: (issue.path, issue.line, issue.rule)), len(tex_files)


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--repo", type=Path, default=Path.cwd(), help="repository root to audit")
    args = parser.parse_args(argv)

    repo = args.repo.resolve()
    issues, file_count = audit(repo)
    if issues:
        print(f"TeX preamble audit failed with {len(issues)} issue(s):")
        for issue in issues:
            print(f"{issue.path}:{issue.line}: {issue.rule}: {issue.message}")
        return 1

    print(f"TeX preamble audit passed for {file_count} tracked .tex files.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
