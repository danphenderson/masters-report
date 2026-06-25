"""Command-line interface for ops orchestration helpers."""

from __future__ import annotations

import json
import sys
from dataclasses import asdict
from enum import Enum
from pathlib import Path
from typing import Annotated, Optional, Sequence

import click
import typer
from rich.console import Console
from rich.table import Table

from .bundles import DEFAULT_BUNDLE_OUTDIR, SUPPORTED_BUNDLE_TARGETS, create_dispatch_bundle
from .docs_contract import docs_contract
from .handback import check_handback
from .models import CheckResult, StatusReport
from .packet_check import packet_check
from .packets import dispatch_packet, dispatch_payload, review_packet, review_payload
from .policy import MODES, PROFILES, REVIEW_LANES, SURFACES
from .ready_commit import DEFAULT_REPORT_OUTDIR, ready_to_commit_result, shell_command
from .session_sources import SessionSummary, session_source
from .status import repo_root, status_report


SurfaceChoice = Enum("SurfaceChoice", {value.replace("-", "_"): value for value in SURFACES}, type=str)
ModeChoice = Enum("ModeChoice", {value.replace("-", "_"): value for value in MODES}, type=str)
ProfileChoice = Enum("ProfileChoice", {value.replace("-", "_"): value for value in PROFILES}, type=str)
ReviewLaneChoice = Enum(
    "ReviewLaneChoice",
    {value.replace("-", "_"): value for value in REVIEW_LANES},
    type=str,
)
SessionSourceChoice = Enum("SessionSourceChoice", {"codex_jsonl": "codex-jsonl"}, type=str)
BundleTargetChoice = Enum(
    "BundleTargetChoice",
    {value.replace("-", "_"): value for value in SUPPORTED_BUNDLE_TARGETS},
    type=str,
)

JsonOption = Annotated[bool, typer.Option("--json", help="Emit machine-readable JSON.")]
RepoOption = Annotated[
    Optional[Path],
    typer.Option("--repo", help="Repository root; defaults to git root."),
]
StrictOption = Annotated[
    bool,
    typer.Option("--strict", help="Fail on protected or unclassified dirty paths."),
]
ReportOutdirOption = Annotated[
    Path,
    typer.Option("--report-outdir", help="Scratch report build directory for report validation gates."),
]

console = Console()
app = typer.Typer(
    help=__doc__,
    no_args_is_help=True,
    context_settings={"help_option_names": ["-h", "--help"]},
    rich_markup_mode="rich",
)


def _choice_value(value: Enum | str) -> str:
    if isinstance(value, Enum):
        return str(value.value)
    return value


def _root_from_context(ctx: typer.Context) -> Path:
    if isinstance(ctx.obj, dict) and "repo" in ctx.obj:
        return ctx.obj["repo"]
    return repo_root(None)


def _normalize_files_option(argv: Sequence[str]) -> list[str]:
    normalized: list[str] = []
    index = 0
    while index < len(argv):
        token = argv[index]
        if token != "--files":
            normalized.append(token)
            index += 1
            continue

        index += 1
        values: list[str] = []
        while index < len(argv) and not argv[index].startswith("-"):
            values.append(argv[index])
            index += 1
        for value in values:
            normalized.extend(("--files", value))
    return normalized


def print_status(report: StatusReport, *, strict: bool = False, output: Console | None = None) -> int:
    target = output or console
    target.print(f"[bold]Branch:[/bold] {report.branch or '<unknown>'}")
    if not report.entries:
        target.print("[bold]Dirty paths:[/bold] none")
    else:
        table = Table(title="Dirty paths by surface", show_header=True)
        table.add_column("Surface", style="bold")
        table.add_column("Count", justify="right")
        for surface, count in sorted(report.dirty_by_surface.items()):
            table.add_row(surface, str(count))
        target.print(table)
    if report.protected_paths:
        target.print("[bold red]Protected/generated paths dirty:[/bold red]")
        for path in report.protected_paths:
            target.print(f"  {path}")
    if report.unclassified_paths:
        target.print("[bold yellow]Unclassified dirty paths:[/bold yellow]")
        for path in report.unclassified_paths:
            target.print(f"  {path}")
    return 1 if strict and (report.protected_paths or report.unclassified_paths) else 0


def print_check_result(result: CheckResult, output: Console | None = None) -> int:
    target = output or console
    if result.status == "passed":
        target.print("[green]passed[/green]")
        return 0
    target.print("[red]failed[/red]")
    for issue in result.issues:
        target.print(f"- {issue}")
    return 1


def dump_json(value: object, output: Console | None = None) -> None:
    target = output or console
    target.file.write(json.dumps(value, indent=2, sort_keys=True) + "\n")
    target.file.flush()


def write_raw(text: str, output: Console | None = None) -> None:
    target = output or console
    target.file.write(text)
    target.file.flush()


def _is_ignored_markdown_export(root: Path, path: Path) -> bool:
    resolved = path.expanduser().resolve(strict=False)
    try:
        relative = resolved.relative_to(root.resolve(strict=False))
    except ValueError:
        return resolved.is_relative_to(Path("/tmp"))
    return bool(relative.parts) and relative.parts[0] == "tmp"


def _markdown_sessions(summaries: list[SessionSummary], *, source: str, date: str, repo: Path) -> str:
    lines = [
        f"# Codex Session Summary {date}",
        "",
        f"- Source: `{source}`",
        f"- Repo: `{repo.as_posix()}`",
        f"- Sessions: {len(summaries)}",
        "",
    ]
    for summary in summaries:
        headline = summary.prompt_headline or "<no prompt headline>"
        validations = ", ".join(summary.validation_commands) if summary.validation_commands else "none detected"
        lines.extend(
            [
                f"## {summary.session_id}",
                "",
                f"- Rollout file id: `{summary.rollout_filename_id}`",
                f"- Started: `{summary.started_at_utc or '<unknown>'}`",
                f"- Status: `{summary.final_status}`",
                f"- Commands: {summary.command_count}",
                f"- Validation commands: {validations}",
                f"- Child/fork marker: `{summary.child_or_fork}`",
                f"- Prompt: {headline}",
                f"- Path: `{summary.path}`",
                "",
            ]
        )
    return "\n".join(lines).rstrip() + "\n"


def build_parser() -> typer.Typer:
    return app


@app.callback()
def configure(ctx: typer.Context, repo: RepoOption = None) -> None:
    ctx.obj = {"repo": repo_root(repo)}


@app.command("status", help="Summarize dirty paths by orchestration surface.")
def status_command(ctx: typer.Context, json_output: JsonOption = False, strict: StrictOption = False) -> int:
    report = status_report(_root_from_context(ctx))
    if json_output:
        dump_json(asdict(report))
        return 1 if strict and (report.protected_paths or report.unclassified_paths) else 0
    return print_status(report, strict=strict)


@app.command("sessions", help="Summarize local Codex sessions for one date.")
def sessions_command(
    ctx: typer.Context,
    source: Annotated[SessionSourceChoice, typer.Option("--source", help="Session source adapter.")] = (
        SessionSourceChoice.codex_jsonl
    ),
    date: Annotated[str, typer.Option("--date", help="Local session date, formatted YYYY-MM-DD.")] = "",
    sessions_root: Annotated[
        Optional[Path],
        typer.Option("--sessions-root", help="Override the source root, mainly for tests or imported logs."),
    ] = None,
    markdown_out: Annotated[
        Optional[Path],
        typer.Option("--markdown-out", help="Optional markdown export path under tmp/** or /tmp."),
    ] = None,
    json_output: JsonOption = False,
) -> int:
    if not date:
        raise typer.BadParameter("--date is required")

    root = _root_from_context(ctx)
    source_value = _choice_value(source)
    summaries = session_source(source_value, root=sessions_root).load_sessions(date=date, repo=root)
    if markdown_out is not None:
        output_path = markdown_out if markdown_out.is_absolute() else root / markdown_out
        if not _is_ignored_markdown_export(root, output_path):
            raise typer.BadParameter("--markdown-out must point under tmp/** or /tmp")
        output_path.parent.mkdir(parents=True, exist_ok=True)
        output_path.write_text(
            _markdown_sessions(summaries, source=source_value, date=date, repo=root), encoding="utf-8"
        )

    payload = {
        "source": source_value,
        "date": date,
        "repo": root.as_posix(),
        "sessions": [asdict(summary) for summary in summaries],
    }
    if json_output:
        dump_json(payload)
        return 0

    table = Table(title=f"Codex sessions {date}", show_header=True)
    table.add_column("Session", overflow="fold")
    table.add_column("Status")
    table.add_column("Cmds", justify="right")
    table.add_column("Validations", justify="right")
    table.add_column("Prompt", overflow="fold")
    for summary in summaries:
        table.add_row(
            summary.session_id,
            summary.final_status,
            str(summary.command_count),
            str(len(summary.validation_commands)),
            summary.prompt_headline or "<no prompt headline>",
        )
    console.print(table)
    if markdown_out is not None:
        console.print(f"Markdown export: {output_path}")
    return 0


@app.command("dispatch", help="Print a bounded dispatch packet.")
def dispatch_command(
    ctx: typer.Context,
    surface: Annotated[SurfaceChoice, typer.Option("--surface", help="Handoff surface.")],
    mode: Annotated[ModeChoice, typer.Option("--mode", help="Allowed work mode.")],
    objective: Annotated[str, typer.Option("--objective", help="Delegated work objective.")],
    files: Annotated[Optional[list[str]], typer.Option("--files", help="Allowed path. May be repeated.")] = None,
    profile: Annotated[ProfileChoice, typer.Option("--profile", help="Review profile.")] = ProfileChoice.generic,
    json_output: JsonOption = False,
) -> int:
    root = _root_from_context(ctx)
    surface_value = _choice_value(surface)
    mode_value = _choice_value(mode)
    profile_value = _choice_value(profile)
    allowed_files = files or []
    try:
        if json_output:
            dump_json(dispatch_payload(root, surface_value, mode_value, objective, allowed_files, profile_value))
        else:
            write_raw(dispatch_packet(root, surface_value, mode_value, objective, allowed_files, profile_value))
    except ValueError as exc:
        raise typer.BadParameter(str(exc)) from exc
    return 0


@app.command("review", help="Print a read-only delegated review packet.")
def review_command(
    ctx: typer.Context,
    commit: Annotated[str, typer.Option("--commit", help="Commit or ref to review.")],
    lane: Annotated[ReviewLaneChoice, typer.Option("--lane", help="Review lane.")],
    json_output: JsonOption = False,
) -> int:
    root = _root_from_context(ctx)
    lane_value = _choice_value(lane)
    if json_output:
        dump_json(review_payload(root, commit, lane_value))
    else:
        write_raw(review_packet(root, commit, lane_value))
    return 0


@app.command("bundle", help="Create a ChatGPT PRO dispatch bundle and print the browser prompt.")
def bundle_command(
    ctx: typer.Context,
    objective: Annotated[str, typer.Option("--objective", help="Reasoning objective for the harnessed session.")],
    target: Annotated[
        BundleTargetChoice,
        typer.Option("--target", help="External reasoning target."),
    ] = BundleTargetChoice.chatgpt_pro,
    outdir: Annotated[
        Path,
        typer.Option("--outdir", help="Ignored scratch output directory under tmp/** or /tmp."),
    ] = DEFAULT_BUNDLE_OUTDIR,
    allow_unclassified: Annotated[
        bool,
        typer.Option("--allow-unclassified", help="Permit unclassified dirty paths after ownership review."),
    ] = False,
    include_protected_artifacts: Annotated[
        bool,
        typer.Option(
            "--include-protected-artifacts",
            help="Include protected artifacts and permit them to be dirty in the bundle.",
        ),
    ] = False,
    json_output: JsonOption = False,
) -> int:
    root = _root_from_context(ctx)
    try:
        result = create_dispatch_bundle(
            root,
            target=_choice_value(target),
            objective=objective,
            outdir=outdir,
            allow_unclassified=allow_unclassified,
            include_protected_artifacts=include_protected_artifacts,
        )
    except ValueError as exc:
        raise typer.BadParameter(str(exc)) from exc
    except RuntimeError as exc:
        raise click.ClickException(str(exc)) from exc

    if json_output:
        dump_json(result.to_payload())
        return 0

    write_raw(
        "\n".join(
            [
                f"Dispatch bundle: {result.archive_path}",
                f"SHA256: {result.archive_sha256}",
                "",
                "Recommended ChatGPT PRO Reasoning prompt:",
                "",
                result.prompt,
                "",
            ]
        )
    )
    return 0


@app.command("handback-check", help="Validate a worker handback.")
def handback_check_command(
    ctx: typer.Context,
    path: Annotated[Path, typer.Option("--path", help="Handback markdown path.")],
    surface: Annotated[Optional[SurfaceChoice], typer.Option("--surface", help="Expected surface.")] = None,
    mode: Annotated[ModeChoice, typer.Option("--mode", help="Expected mode.")] = ModeChoice.inspect,
    profile: Annotated[ProfileChoice, typer.Option("--profile", help="Expected profile.")] = ProfileChoice.generic,
    json_output: JsonOption = False,
) -> int:
    root = _root_from_context(ctx)
    handback_path = path if path.is_absolute() else root / path
    result = check_handback(
        handback_path.read_text(encoding="utf-8"),
        _choice_value(surface) if surface is not None else None,
        _choice_value(mode),
        _choice_value(profile),
    )
    if json_output:
        dump_json(asdict(result))
        return 0 if result.status == "passed" else 1
    return print_check_result(result)


@app.command("packet-check", help="Validate an external handoff packet.")
def packet_check_command(
    ctx: typer.Context,
    path: Annotated[Path, typer.Option("--path", help="Packet markdown path.")],
    profile: Annotated[ProfileChoice, typer.Option("--profile", help="Expected profile.")] = ProfileChoice.generic,
    json_output: JsonOption = False,
) -> int:
    root = _root_from_context(ctx)
    packet_path = path if path.is_absolute() else root / path
    result = packet_check(packet_path.read_text(encoding="utf-8"), _choice_value(profile))
    if json_output:
        dump_json(asdict(result))
        return 0 if result.status == "passed" else 1
    return print_check_result(result)


@app.command("docs-contract", help="Validate the documented orchestration contract.")
def docs_contract_command(ctx: typer.Context, json_output: JsonOption = False) -> int:
    result = docs_contract(_root_from_context(ctx))
    if json_output:
        dump_json(asdict(result))
        return 0 if result.status == "passed" else 1
    return print_check_result(result)


@app.command("ready-to-commit", help="Run the centralized commit-readiness validation gate.")
def ready_to_commit_command(
    ctx: typer.Context,
    all_gates: Annotated[
        bool,
        typer.Option("--all", help="Run the aggregate patch gate instead of focused dirty-surface gates."),
    ] = False,
    dry_run: Annotated[
        bool,
        typer.Option("--dry-run", help="Print the selected gates without executing them."),
    ] = False,
    allow_protected_artifacts: Annotated[
        bool,
        typer.Option(
            "--allow-protected-artifacts",
            help="Permit protected artifact paths after the owning artifact-refresh validation is in scope.",
        ),
    ] = False,
    allow_unclassified: Annotated[
        bool,
        typer.Option("--allow-unclassified", help="Permit unclassified dirty paths after ownership review."),
    ] = False,
    report_outdir: ReportOutdirOption = DEFAULT_REPORT_OUTDIR,
    json_output: JsonOption = False,
) -> int:
    root = _root_from_context(ctx)
    report = status_report(root)
    result = ready_to_commit_result(
        report,
        repo=root,
        report_outdir=report_outdir,
        all_gates=all_gates,
        dry_run=dry_run,
        stream=not json_output,
        allow_protected_artifacts=allow_protected_artifacts,
        allow_unclassified=allow_unclassified,
    )
    payload = {
        "status": result.status,
        "issues": list(result.issues),
        "dirty_surfaces": list(result.dirty_surfaces),
        "gates": [{"name": gate.name, "surface": gate.surface, "command": list(gate.command)} for gate in result.gates],
        "results": [
            {"name": item.name, "command": list(item.command), "returncode": item.returncode} for item in result.results
        ],
    }
    if json_output:
        dump_json(payload)
        return 0 if result.status == "passed" else 1

    if report.entries:
        console.print(f"[bold]Dirty surfaces:[/bold] {', '.join(result.dirty_surfaces) or '<unclassified only>'}")
    else:
        console.print("[bold]Dirty surfaces:[/bold] none")
    if result.issues:
        for issue in result.issues:
            console.print(f"[red]- {issue}[/red]")
        return 1
    if dry_run:
        for gate in result.gates:
            console.print(f"- {gate.name}: `{shell_command(gate.command)}`")
    return 0 if result.status == "passed" else 1


def main(argv: Sequence[str] | None = None) -> int:
    args = _normalize_files_option(sys.argv[1:] if argv is None else list(argv))
    try:
        result = app(args=args, prog_name="ops-orchestrate", standalone_mode=False)
    except click.exceptions.Exit as exc:
        return int(exc.exit_code)
    except click.ClickException as exc:
        exc.show()
        return int(exc.exit_code)
    return int(result or 0)
