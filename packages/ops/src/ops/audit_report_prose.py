#!/usr/bin/env python3
"""Audit report TeX for duplicated, repeated, and misplaced prose."""

from __future__ import annotations

import argparse
import itertools
import json
import re
import subprocess
import sys
from dataclasses import asdict, dataclass
from pathlib import Path
from typing import Iterable


PRIMARY_MIN_WORDS = 18
EXACT_SPAN_WORDS = 20
NEAR_SHINGLE_WORDS = 5
NEAR_MIN_SHARED = 8
NEAR_MIN_SCORE = 0.35
DEFAULT_MAX_FINDINGS = 50

CONTEXT_PATH_PREFIXES = (
    "report/archive/",
    "report/assets/",
    "report/preamble/",
)

EXCLUDED_ENVIRONMENTS = {
    "align",
    "align*",
    "aligned",
    "array",
    "bmatrix",
    "cases",
    "equation",
    "equation*",
    "flalign",
    "flalign*",
    "gather",
    "gather*",
    "lstlisting",
    "matrix",
    "minted",
    "pmatrix",
    "smallmatrix",
    "split",
    "tabular",
    "tabular*",
    "tabularx",
    "tikzpicture",
    "verbatim",
    "vmatrix",
}

TEXT_COMMANDS = {
    "caption",
    "emph",
    "enquote",
    "paragraph",
    "subparagraph",
    "textbf",
    "textit",
    "textrm",
    "textsc",
    "textsf",
    "underline",
}

DROP_COMMANDS_WITH_ARGUMENTS = {
    "autoref",
    "cite",
    "citeauthor",
    "citep",
    "citet",
    "cref",
    "Cref",
    "eqref",
    "figtikz",
    "footnote",
    "href",
    "includegraphics",
    "input",
    "label",
    "pageref",
    "path",
    "ref",
    "url",
}

STOP_WORDS = {
    "and",
    "are",
    "but",
    "for",
    "from",
    "into",
    "its",
    "not",
    "that",
    "the",
    "their",
    "then",
    "this",
    "through",
    "with",
}


@dataclass(frozen=True)
class ProseChunk:
    path: str
    line: int
    section_context: str
    environment: str
    context: bool
    text: str
    normalized: str
    words: tuple[str, ...]


@dataclass(frozen=True)
class RelatedLocation:
    path: str
    line: int
    section_context: str
    excerpt: str


@dataclass(frozen=True)
class Finding:
    rule: str
    severity: str
    path: str
    line: int
    message: str
    excerpt: str
    suggestion: str
    score: float | None
    related: tuple[RelatedLocation, ...]


@dataclass(frozen=True)
class TopicRule:
    name: str
    terms: tuple[str, ...]
    owner_prefixes: tuple[str, ...]
    min_terms: int
    message: str
    suggestion: str


@dataclass(frozen=True)
class AuditResult:
    files_seen: int
    primary_files: int
    context_files: int
    chunks: int
    findings: tuple[Finding, ...]
    skipped_context_files: tuple[str, ...]


TOPIC_RULES = (
    TopicRule(
        "topic-owner-continuum-foundation",
        (
            "material derivative",
            "reynolds transport",
            "cauchy stress",
            "navier stokes",
            "incompressible",
            "flow map",
        ),
        (
            "report/sections/02-continuum/",
            "report/appendices/continuum-derivation-details.tex",
            "report/appendices/ns-coordinate-energy-details.tex",
        ),
        2,
        "continuum-foundation prose appears outside the continuum section or supporting appendices",
        "move or cross-reference the continuum definition instead of restating it",
    ),
    TopicRule(
        "topic-owner-method-detail",
        (
            "muscl",
            "rusanov",
            "ssprk",
            "cfl",
            "positivity",
            "rest state",
            "finite volume",
            "boundary state",
        ),
        (
            "report/sections/05-numerical-methods/",
            "report/sections/07-case-study/",
            "report/appendices/numerical-methods-details.tex",
        ),
        2,
        "numerical-method detail appears outside the numerical-methods or case-study owner sections",
        "move detailed method prose to the methods/case-study owner and leave a short reference here",
    ),
    TopicRule(
        "topic-owner-comparison-limits",
        (
            "radial reducer",
            "radial profile rows",
            "quarantined",
            "matching limits",
            "deformed coordinate mode",
            "reference coordinate mode",
            "node centered displacement",
        ),
        (
            "report/sections/07-case-study/comparison.tex",
            "report/sections/07-case-study/methodology.tex",
            "report/sections/07-case-study/verification.tex",
            "report/appendices/numerical-methods-details.tex",
        ),
        2,
        "case-study comparison-limit prose appears outside the comparison/methodology record",
        "move the limit to the comparison record or replace the repeat with a cross-reference",
    ),
    TopicRule(
        "topic-owner-software-provenance",
        (
            "public repository",
            "archival doi",
            "sha 256",
            "codex",
            "local thesis copy",
            "reproducibility record",
        ),
        ("report/appendices/code-and-ai-use.tex",),
        2,
        "software-provenance prose appears outside the reproducibility appendix",
        "move repository/provenance detail to the reproducibility appendix",
    ),
)

SEVERITY_RANK = {"high": 0, "medium": 1, "low": 2}


def git_lines(repo: Path, args: list[str]) -> list[str]:
    result = subprocess.run(
        ["git", *args],
        cwd=repo,
        text=True,
        capture_output=True,
        check=False,
    )
    if result.returncode != 0:
        raise RuntimeError(result.stderr.strip() or f"git {' '.join(args)} failed")
    return [line for line in result.stdout.splitlines() if line]


def report_tex_files(repo: Path) -> tuple[Path, ...]:
    paths = git_lines(repo, ["ls-files", "--cached", "--others", "--exclude-standard", "--", "report"])
    return tuple(repo / path for path in paths if path.endswith(".tex") and (repo / path).exists())


def relpath(path: Path, repo: Path) -> str:
    return path.relative_to(repo).as_posix()


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


def is_context_path(relative: str) -> bool:
    return relative.startswith(CONTEXT_PATH_PREFIXES)


def environment_name(raw: str) -> str:
    return raw.strip()


def environment_is_excluded(name: str) -> bool:
    return environment_name(name) in EXCLUDED_ENVIRONMENTS


def extract_braced_argument(text: str, start: int) -> tuple[str, int] | None:
    if start >= len(text) or text[start] != "{":
        return None
    depth = 0
    value: list[str] = []
    index = start
    while index < len(text):
        character = text[index]
        if character == "{" and (index == 0 or text[index - 1] != "\\"):
            depth += 1
            if depth > 1:
                value.append(character)
        elif character == "}" and (index == 0 or text[index - 1] != "\\"):
            depth -= 1
            if depth == 0:
                return "".join(value), index + 1
            value.append(character)
        else:
            value.append(character)
        index += 1
    return None


def extract_section_title(line: str) -> tuple[str, str] | None:
    match = re.search(r"\\(?P<level>section|subsection|subsubsection)\*?(?:\[[^\]]*\])?\s*\{", line)
    if not match:
        return None
    argument = extract_braced_argument(line, match.end() - 1)
    if argument is None:
        return None
    title, _ = argument
    title = normalize_visible_text(title).strip()
    return match.group("level"), title


def replace_text_commands(text: str) -> str:
    command_pattern = re.compile(r"\\(?P<command>[A-Za-z]+)\*?(?:\[[^\]]*\])*\s*\{")
    cursor = 0
    pieces: list[str] = []
    while cursor < len(text):
        match = command_pattern.search(text, cursor)
        if match is None:
            pieces.append(text[cursor:])
            break
        pieces.append(text[cursor : match.start()])
        command = match.group("command")
        argument = extract_braced_argument(text, match.end() - 1)
        if argument is None:
            cursor = match.end()
            continue
        value, end = argument
        if command in TEXT_COMMANDS:
            pieces.append(f" {value} ")
        elif command in DROP_COMMANDS_WITH_ARGUMENTS or command.lower().endswith("cite"):
            pieces.append(" ")
        else:
            pieces.append(f" {value} ")
        cursor = end
    return "".join(pieces)


def normalize_visible_text(text: str) -> str:
    text = re.sub(r"\$[^$]*\$", " ", text)
    text = re.sub(r"\\\([^)]*\\\)", " ", text)
    text = re.sub(r"\\\[[\s\S]*?\\\]", " ", text)
    text = replace_text_commands(text)
    text = re.sub(r"\\(?:begin|end)\{[^{}]+\}", " ", text)
    text = re.sub(r"\\[A-Za-z]+\*?(?:\[[^\]]*\])?", " ", text)
    text = re.sub(r"\\.", " ", text)
    text = text.replace("~", " ")
    text = text.replace("--", " ")
    text = text.replace("{", " ").replace("}", " ")
    return re.sub(r"\s+", " ", text).strip()


def normalized_words(text: str) -> tuple[str, ...]:
    visible = normalize_visible_text(text)
    normalized = re.sub(r"[^A-Za-z0-9]+", " ", visible).lower()
    words = tuple(word for word in normalized.split() if len(word) > 2 and not word.isdigit())
    return words


def display_excerpt(text: str, max_words: int = 28) -> str:
    words = normalize_visible_text(text).split()
    excerpt = " ".join(words[:max_words])
    if len(words) > max_words:
        excerpt += " ..."
    return excerpt


def is_shell_or_path_heavy(text: str) -> bool:
    visible = normalize_visible_text(text)
    words = visible.split()
    if len(words) < PRIMARY_MIN_WORDS:
        return False
    pathish = sum(1 for word in words if "/" in word or word.startswith("--") or word.endswith((".jl", ".py", ".tex")))
    return pathish / len(words) >= 0.25


def context_label(section_parts: dict[str, str]) -> str:
    return " > ".join(part for key in ("section", "subsection", "subsubsection") if (part := section_parts.get(key)))


def current_environment(stack: list[str]) -> str:
    for name in reversed(stack):
        if not environment_is_excluded(name):
            return name
    return ""


def parse_tex_file(path: Path, repo: Path, include_context: bool = False) -> tuple[ProseChunk, ...]:
    relative = relpath(path, repo)
    file_context = is_context_path(relative)
    if file_context and not include_context:
        return ()

    raw_lines = path.read_text(encoding="utf-8").splitlines()
    section_parts: dict[str, str] = {}
    environment_stack: list[str] = []
    chunks: list[ProseChunk] = []
    paragraph_lines: list[str] = []
    paragraph_start = 1
    paragraph_environment = ""

    def flush() -> None:
        nonlocal paragraph_lines, paragraph_start, paragraph_environment
        if not paragraph_lines:
            return
        text = " ".join(line.strip() for line in paragraph_lines if line.strip())
        words = normalized_words(text)
        chunk_context = file_context or is_shell_or_path_heavy(text)
        if len(words) >= PRIMARY_MIN_WORDS:
            chunks.append(
                ProseChunk(
                    path=relative,
                    line=paragraph_start,
                    section_context=context_label(section_parts),
                    environment=paragraph_environment,
                    context=chunk_context,
                    text=normalize_visible_text(text),
                    normalized=" ".join(words),
                    words=words,
                )
            )
        paragraph_lines = []
        paragraph_environment = ""

    for line_number, raw_line in enumerate(raw_lines, start=1):
        line = strip_latex_comment(raw_line)
        section_title = extract_section_title(line)
        if section_title is not None:
            flush()
            level, title = section_title
            section_parts[level] = title
            if level == "section":
                section_parts.pop("subsection", None)
                section_parts.pop("subsubsection", None)
            elif level == "subsection":
                section_parts.pop("subsubsection", None)
            continue

        begin_names = [environment_name(match.group(1)) for match in re.finditer(r"\\begin\{([^{}]+)\}", line)]
        end_names = [environment_name(match.group(1)) for match in re.finditer(r"\\end\{([^{}]+)\}", line)]
        starts_excluded = any(environment_is_excluded(name) for name in begin_names)
        in_excluded = any(environment_is_excluded(name) for name in environment_stack)

        if starts_excluded or in_excluded:
            flush()
            for name in begin_names:
                environment_stack.append(name)
            for name in end_names:
                if name in environment_stack:
                    del environment_stack[len(environment_stack) - 1 - environment_stack[::-1].index(name)]
            continue

        visible = normalize_visible_text(line)
        if not visible:
            flush()
        else:
            if not paragraph_lines:
                paragraph_start = line_number
                paragraph_environment = current_environment(environment_stack)
            paragraph_lines.append(line)

        for name in begin_names:
            environment_stack.append(name)
        for name in end_names:
            if name in environment_stack:
                del environment_stack[len(environment_stack) - 1 - environment_stack[::-1].index(name)]

    flush()
    return tuple(chunks)


def shingle(words: tuple[str, ...], width: int) -> set[tuple[str, ...]]:
    if len(words) < width:
        return set()
    return {tuple(words[index : index + width]) for index in range(len(words) - width + 1)}


def shared_severity(primary: ProseChunk, related: ProseChunk, exact: bool = False) -> str:
    if primary.context or related.context:
        return "low"
    if exact and primary.path != related.path:
        return "high"
    return "medium" if exact else "medium"


def related_location(chunk: ProseChunk) -> RelatedLocation:
    return RelatedLocation(
        path=chunk.path,
        line=chunk.line,
        section_context=chunk.section_context,
        excerpt=display_excerpt(chunk.text),
    )


def exact_duplicate_findings(chunks: tuple[ProseChunk, ...]) -> list[Finding]:
    findings: list[Finding] = []
    by_paragraph: dict[str, list[ProseChunk]] = {}
    for chunk in chunks:
        if len(chunk.words) >= PRIMARY_MIN_WORDS:
            by_paragraph.setdefault(chunk.normalized, []).append(chunk)

    for matches in by_paragraph.values():
        unique_locations = {(chunk.path, chunk.line) for chunk in matches}
        if len(unique_locations) < 2:
            continue
        primary, *related_chunks = sorted(matches, key=lambda item: (item.path, item.line))
        findings.append(
            Finding(
                rule="exact-duplicate",
                severity=shared_severity(primary, related_chunks[0], exact=True),
                path=primary.path,
                line=primary.line,
                message="exact normalized prose paragraph appears in more than one location",
                excerpt=display_excerpt(primary.text),
                suggestion="merge or delete the repeated paragraph unless this is deliberate glossary-style repetition",
                score=1.0,
                related=tuple(related_location(chunk) for chunk in related_chunks),
            )
        )

    span_index: dict[tuple[str, ...], list[int]] = {}
    for index, chunk in enumerate(chunks):
        for span in shingle(chunk.words, EXACT_SPAN_WORDS):
            span_index.setdefault(span, []).append(index)

    seen_pairs: set[tuple[int, int]] = set()
    for span, indices in span_index.items():
        if len(indices) < 2:
            continue
        for left, right in itertools.combinations(sorted(set(indices)), 2):
            if left == right or (left, right) in seen_pairs:
                continue
            seen_pairs.add((left, right))
            primary = chunks[left]
            related = chunks[right]
            findings.append(
                Finding(
                    rule="exact-duplicate",
                    severity=shared_severity(primary, related, exact=True),
                    path=primary.path,
                    line=primary.line,
                    message=f"exact {EXACT_SPAN_WORDS}-word prose span repeats in another location",
                    excerpt=" ".join(span),
                    suggestion="keep the strongest home and replace the repeat with a cross-reference if needed",
                    score=1.0,
                    related=(related_location(related),),
                )
            )
    return findings


def near_duplicate_findings(
    chunks: tuple[ProseChunk, ...], exact_pairs: set[tuple[str, int, str, int]]
) -> list[Finding]:
    findings: list[Finding] = []
    chunk_shingles = [shingle(chunk.words, NEAR_SHINGLE_WORDS) for chunk in chunks]
    for left, right in itertools.combinations(range(len(chunks)), 2):
        first = chunks[left]
        second = chunks[right]
        pair_key = (first.path, first.line, second.path, second.line)
        reverse_key = (second.path, second.line, first.path, first.line)
        if pair_key in exact_pairs or reverse_key in exact_pairs:
            continue
        if first.path == second.path and abs(first.line - second.line) < 8:
            continue
        first_shingles = chunk_shingles[left]
        second_shingles = chunk_shingles[right]
        if not first_shingles or not second_shingles:
            continue
        shared = len(first_shingles & second_shingles)
        if shared < NEAR_MIN_SHARED:
            continue
        score = shared / min(len(first_shingles), len(second_shingles))
        if score < NEAR_MIN_SCORE:
            continue
        severity = "low" if first.context or second.context else "medium"
        findings.append(
            Finding(
                rule="near-duplicate",
                severity=severity,
                path=first.path,
                line=first.line,
                message=f"near-duplicate prose shares {shared} normalized {NEAR_SHINGLE_WORDS}-word spans",
                excerpt=display_excerpt(first.text),
                suggestion="compare the two passages and condense repeated caveat, motivation, or limitation language",
                score=round(score, 3),
                related=(related_location(second),),
            )
        )
    return findings


def phrase_count(normalized_text: str, terms: Iterable[str]) -> int:
    return sum(1 for term in terms if re.sub(r"[^a-z0-9]+", " ", term.lower()).strip() in normalized_text)


def topic_owner_findings(chunks: tuple[ProseChunk, ...]) -> list[Finding]:
    findings: list[Finding] = []
    for chunk in chunks:
        for rule in TOPIC_RULES:
            if chunk.path.startswith(rule.owner_prefixes):
                continue
            hits = phrase_count(chunk.normalized, rule.terms)
            if hits < rule.min_terms:
                continue
            findings.append(
                Finding(
                    rule=rule.name,
                    severity="low",
                    path=chunk.path,
                    line=chunk.line,
                    message=f"{rule.message}; matched {hits} topic markers",
                    excerpt=display_excerpt(chunk.text),
                    suggestion=rule.suggestion,
                    score=None,
                    related=(),
                )
            )
    return findings


def sort_findings(findings: Iterable[Finding]) -> tuple[Finding, ...]:
    return tuple(
        sorted(
            findings,
            key=lambda finding: (
                SEVERITY_RANK[finding.severity],
                finding.rule,
                finding.path,
                finding.line,
                finding.message,
            ),
        )
    )


def audit(repo: Path, include_context: bool = False) -> AuditResult:
    files = report_tex_files(repo)
    context_files = tuple(path for path in files if is_context_path(relpath(path, repo)))
    primary_files = tuple(path for path in files if not is_context_path(relpath(path, repo)))
    chunks = tuple(
        chunk
        for path in files
        for chunk in parse_tex_file(path, repo, include_context=include_context)
        if include_context or not chunk.context
    )
    exact = exact_duplicate_findings(chunks)
    exact_pairs = {
        (finding.path, finding.line, related.path, related.line)
        for finding in exact
        for related in finding.related
        if finding.rule == "exact-duplicate"
    }
    near = near_duplicate_findings(chunks, exact_pairs)
    topics = topic_owner_findings(chunks)
    findings = sort_findings([*exact, *near, *topics])
    skipped = tuple(relpath(path, repo) for path in context_files) if not include_context else ()
    return AuditResult(
        files_seen=len(files),
        primary_files=len(primary_files),
        context_files=len(context_files),
        chunks=len(chunks),
        findings=findings,
        skipped_context_files=skipped,
    )


def finding_to_dict(finding: Finding) -> dict[str, object]:
    return asdict(finding)


def result_to_dict(result: AuditResult) -> dict[str, object]:
    return {
        "files_seen": result.files_seen,
        "primary_files": result.primary_files,
        "context_files": result.context_files,
        "chunks": result.chunks,
        "skipped_context_files": list(result.skipped_context_files),
        "findings": [finding_to_dict(finding) for finding in result.findings],
    }


def severity_counts(findings: Iterable[Finding]) -> dict[str, int]:
    counts = {"high": 0, "medium": 0, "low": 0}
    for finding in findings:
        counts[finding.severity] += 1
    return counts


def markdown_report(result: AuditResult) -> str:
    counts = severity_counts(result.findings)
    lines = [
        "# Report Prose Audit",
        "",
        f"- Files seen: {result.files_seen}",
        f"- Primary files: {result.primary_files}",
        f"- Context files: {result.context_files}",
        f"- Prose chunks audited: {result.chunks}",
        f"- Findings: {len(result.findings)} "
        f"(high {counts['high']}, medium {counts['medium']}, low {counts['low']})",
        "",
    ]
    if result.skipped_context_files:
        lines.extend(["## Skipped Context Files", ""])
        lines.extend(f"- `{path}`" for path in result.skipped_context_files)
        lines.append("")

    lines.extend(["## Findings", ""])
    if not result.findings:
        lines.append("No duplicate or topic-owner findings.")
        return "\n".join(lines) + "\n"

    for finding in result.findings:
        score = f" score={finding.score}" if finding.score is not None else ""
        lines.extend(
            [
                f"### {finding.severity.upper()} {finding.rule}",
                "",
                f"- Location: `{finding.path}:{finding.line}`{score}",
                f"- Message: {finding.message}",
                f"- Excerpt: {finding.excerpt}",
                f"- Suggested action: {finding.suggestion}",
            ]
        )
        for related in finding.related:
            lines.append(f"- Related: `{related.path}:{related.line}` - {related.excerpt}")
        lines.append("")
    return "\n".join(lines)


def print_text_summary(result: AuditResult, max_findings: int) -> None:
    counts = severity_counts(result.findings)
    print(
        "Report prose audit completed: "
        f"{len(result.findings)} finding(s) "
        f"(high {counts['high']}, medium {counts['medium']}, low {counts['low']}); "
        f"{result.chunks} prose chunk(s) across {result.primary_files} primary file(s)."
    )
    if result.skipped_context_files:
        print(f"Skipped {len(result.skipped_context_files)} context file(s); pass --include-context to include them.")
    if not result.findings:
        return
    shown = result.findings[:max_findings]
    for finding in shown:
        score = f" score={finding.score}" if finding.score is not None else ""
        print(f"{finding.path}:{finding.line}: {finding.severity}: {finding.rule}:{score} {finding.message}")
        print(f"  excerpt: {finding.excerpt}")
        print(f"  action: {finding.suggestion}")
        for related in finding.related:
            print(f"  related: {related.path}:{related.line}: {related.excerpt}")
    if len(result.findings) > max_findings:
        print(f"... {len(result.findings) - max_findings} additional finding(s) omitted by --max-findings.")


def parse_args(argv: list[str] | None = None) -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--repo", type=Path, default=Path.cwd(), help="repository root to audit")
    parser.add_argument(
        "--include-context",
        action="store_true",
        help="include archive, assets, preamble, and other context prose in the scored audit",
    )
    parser.add_argument("--json", action="store_true", help="print machine-readable JSON output")
    parser.add_argument("--markdown-out", type=Path, help="write a Markdown audit report to this path")
    parser.add_argument(
        "--fail-on",
        choices=("none", "exact"),
        default="none",
        help="return nonzero only for the selected finding class (default: advisory/no failure)",
    )
    parser.add_argument(
        "--max-findings",
        type=int,
        default=DEFAULT_MAX_FINDINGS,
        help=f"maximum text-summary findings to print (default: {DEFAULT_MAX_FINDINGS})",
    )
    return parser.parse_args(argv)


def main(argv: list[str] | None = None) -> int:
    args = parse_args(argv)
    repo = args.repo.expanduser().resolve()
    result = audit(repo, include_context=args.include_context)

    if args.markdown_out:
        output_path = args.markdown_out.expanduser()
        if not output_path.is_absolute():
            output_path = repo / output_path
        output_path.parent.mkdir(parents=True, exist_ok=True)
        output_path.write_text(markdown_report(result), encoding="utf-8")

    if args.json:
        print(json.dumps(result_to_dict(result), indent=2, sort_keys=True))
    else:
        print_text_summary(result, max_findings=args.max_findings)

    if args.fail_on == "exact" and any(finding.rule == "exact-duplicate" for finding in result.findings):
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
