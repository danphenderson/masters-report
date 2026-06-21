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

from .docs_contract import docs_contract
from .handback import check_handback
from .models import CheckResult, StatusReport
from .packet_check import packet_check
from .packets import dispatch_packet, dispatch_payload, review_packet, review_payload
from .policy import MODES, PROFILES, REVIEW_LANES, SURFACES
from .status import repo_root, status_report


SurfaceChoice = Enum("SurfaceChoice", {value.replace("-", "_"): value for value in SURFACES}, type=str)
ModeChoice = Enum("ModeChoice", {value.replace("-", "_"): value for value in MODES}, type=str)
ProfileChoice = Enum("ProfileChoice", {value.replace("-", "_"): value for value in PROFILES}, type=str)
ReviewLaneChoice = Enum(
    "ReviewLaneChoice",
    {value.replace("-", "_"): value for value in REVIEW_LANES},
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
