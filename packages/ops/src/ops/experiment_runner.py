"""Run Julia simulation experiments through the Python ops command surface."""

from __future__ import annotations

import argparse
import json
import os
import queue
import re
import signal
import subprocess
import sys
import threading
import time
import uuid
from dataclasses import dataclass, field
from datetime import datetime, timezone
from pathlib import Path
from typing import Any, TextIO

from ops.git_state import git_sha, git_snapshot

SCHEMA_VERSION = "1.0"
DEFAULT_LAUNCHER = "packages/julia/bin/stenosis-hemodynamics"
DEFAULT_LOG_DIR = "public/var/logs"
DIRTY_POLICIES = ("allow", "warn", "fail")
JULIA_FIELD_RE = re.compile(r"^[\u2502\u2514]\s+(?P<body>.*)$")
JULIA_BLOCK_START_RE = re.compile(r"^\u250c\s+(?P<level>Info|Warning|Error):\s*(?P<message>.*)$")
JULIA_SUMMARY_RE = re.compile(r"^(?P<key>[A-Za-z][A-Za-z0-9_]*)[,](?P<value>.*)$")


@dataclass(frozen=True)
class LogPaths:
    run_id: str
    log_dir: Path
    jsonl_path: Path
    summary_path: Path


@dataclass
class JuliaLogBlock:
    level: str
    message: str
    fields: dict[str, Any] = field(default_factory=dict)


@dataclass
class ExperimentState:
    run_id: str
    command: list[str]
    repo: Path
    log_paths: LogPaths
    started_at_utc: str
    git_sha: str
    dirty_policy: str
    git_snapshot_start: dict[str, Any]
    julia_summary: dict[str, list[str]] = field(default_factory=dict)
    output_artifacts: dict[str, list[str]] = field(default_factory=dict)
    event_counts: dict[str, int] = field(default_factory=dict)


def utc_timestamp() -> str:
    return datetime.now(timezone.utc).isoformat(timespec="milliseconds").replace("+00:00", "Z")


def repo_root() -> Path:
    path = Path(__file__).resolve()
    for parent in path.parents:
        if (parent / "packages" / "julia").is_dir() and (parent / "packages" / "ops").is_dir():
            return parent
    raise RuntimeError("could not locate repository root")


def resolve_repo_path(repo: Path, path: str | Path) -> Path:
    candidate = Path(path).expanduser()
    if candidate.is_absolute():
        return candidate.resolve()
    return (repo / candidate).resolve()


def display_path(repo: Path, path: Path) -> str:
    try:
        return path.relative_to(repo).as_posix()
    except ValueError:
        return path.as_posix()


def executable_path(repo: Path, path: Path) -> str:
    displayed = display_path(repo, path)
    if path.is_absolute() and path.is_relative_to(repo) and "/" not in displayed:
        return f"./{displayed}"
    return displayed


def slugify(value: str, default: str = "experiment") -> str:
    slug = re.sub(r"[^A-Za-z0-9_.-]+", "-", value.strip()).strip("-._")
    return slug[:80] or default


def build_log_paths(log_dir: Path, command_label: str, run_id: str | None = None) -> LogPaths:
    timestamp = datetime.now(timezone.utc).strftime("%Y%m%dT%H%M%SZ")
    safe_run_id = (
        slugify(run_id, default="run") if run_id else f"{timestamp}-{slugify(command_label)}-{uuid.uuid4().hex[:8]}"
    )
    return LogPaths(
        run_id=safe_run_id,
        log_dir=log_dir,
        jsonl_path=log_dir / f"{safe_run_id}.jsonl",
        summary_path=log_dir / f"{safe_run_id}.summary.json",
    )


def parse_julia_value(raw_value: str) -> Any:
    value = raw_value.strip()
    if value in {"true", "false"}:
        return value == "true"
    if value in {"nothing", "missing", "NaN"}:
        return None if value != "NaN" else "NaN"
    if value.startswith('"') and value.endswith('"'):
        try:
            return json.loads(value)
        except json.JSONDecodeError:
            return value[1:-1]
    try:
        return int(value)
    except ValueError:
        pass
    try:
        return float(value)
    except ValueError:
        return value


class JuliaTelemetryParser:
    """Parse Julia default logger blocks without depending on Julia internals."""

    def __init__(self) -> None:
        self._current: JuliaLogBlock | None = None

    def feed(self, line: str) -> list[dict[str, Any]]:
        stripped = line.rstrip("\n")
        emitted: list[dict[str, Any]] = []
        start = JULIA_BLOCK_START_RE.match(stripped)
        if start is not None:
            emitted.extend(self.flush())
            self._current = JuliaLogBlock(
                level=start.group("level").lower(),
                message=start.group("message").strip(),
            )
            return emitted

        if self._current is None:
            return emitted

        field_match = JULIA_FIELD_RE.match(stripped)
        if field_match is not None:
            body = field_match.group("body").strip()
            if " = " in body:
                key, value = body.split(" = ", 1)
                self._current.fields[key.strip()] = parse_julia_value(value)
            if stripped.startswith("\u2514"):
                emitted.extend(self.flush())
            return emitted

        if stripped.startswith("\u2514"):
            emitted.extend(self.flush())
        return emitted

    def flush(self) -> list[dict[str, Any]]:
        if self._current is None:
            return []
        block = self._current
        self._current = None
        fields = dict(block.fields)
        return [
            {
                "event": str(fields.get("event") or "julia_log"),
                "level": block.level,
                "message": block.message,
                "source": "julia-telemetry",
                "fields": fields,
            }
        ]


class JsonlLogger:
    def __init__(self, path: Path, base: dict[str, Any]) -> None:
        path.parent.mkdir(parents=True, exist_ok=True)
        self._handle = path.open("w", encoding="utf-8")
        self._base = dict(base)

    def close(self) -> None:
        self._handle.close()

    def write(self, event: str, **payload: Any) -> None:
        record = {
            **self._base,
            **payload,
            "schema_version": SCHEMA_VERSION,
            "timestamp_utc": utc_timestamp(),
            "event": event,
        }
        json.dump(record, self._handle, sort_keys=True)
        self._handle.write("\n")
        self._handle.flush()


def parse_summary_line(line: str) -> tuple[str, str] | None:
    match = JULIA_SUMMARY_RE.match(line.strip())
    if match is None:
        return None
    return match.group("key"), match.group("value")


def is_output_artifact_key(key: str) -> bool:
    return key.endswith(("_asset", "_assets", "_csv", "_dir", "_manifest", "_path", "_svg", "_tex")) or key in {
        "benchmark_manifest",
        "benchmark_csv",
        "benchmark_report_assets",
        "output_csv",
        "output_svg",
    }


def enqueue_stream(stream_name: str, pipe: TextIO, events: queue.Queue[tuple[str, str | None]]) -> None:
    try:
        for line in pipe:
            events.put((stream_name, line))
    finally:
        events.put((stream_name, None))


def write_summary(path: Path, summary: dict[str, Any]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(summary, indent=2, sort_keys=True) + "\n", encoding="utf-8")


def build_summary(
    state: ExperimentState,
    *,
    returncode: int,
    elapsed_s: float,
    status: str,
    git_snapshot_end: dict[str, Any],
) -> dict[str, Any]:
    return {
        "schema_version": SCHEMA_VERSION,
        "run_id": state.run_id,
        "status": status,
        "returncode": returncode,
        "command": state.command,
        "cwd": state.repo.as_posix(),
        "git_sha": state.git_sha,
        "dirty_policy": state.dirty_policy,
        "git_snapshot_start": state.git_snapshot_start,
        "git_snapshot_end": git_snapshot_end,
        "started_at_utc": state.started_at_utc,
        "finished_at_utc": utc_timestamp(),
        "elapsed_s": round(elapsed_s, 6),
        "jsonl_log": state.log_paths.jsonl_path.as_posix(),
        "summary_path": state.log_paths.summary_path.as_posix(),
        "julia_summary": state.julia_summary,
        "output_artifacts": state.output_artifacts,
        "event_counts": state.event_counts,
    }


def increment_event_count(state: ExperimentState, event: str) -> None:
    state.event_counts[event] = state.event_counts.get(event, 0) + 1


def write_parsed_event(logger: JsonlLogger, state: ExperimentState, stream_name: str, parsed: dict[str, Any]) -> None:
    event_name = str(parsed["event"])
    payload = {key: value for key, value in parsed.items() if key != "event"}
    logger.write(event_name, stream=stream_name, **payload)
    increment_event_count(state, event_name)


def stream_process(state: ExperimentState, *, stream_output: bool = True) -> int:
    logger = JsonlLogger(
        state.log_paths.jsonl_path,
        {
            "run_id": state.run_id,
            "cwd": state.repo.as_posix(),
            "git_sha": state.git_sha,
            "command": state.command,
        },
    )
    start = time.monotonic()
    process: subprocess.Popen[str] | None = None
    try:
        logger.write(
            "experiment_started",
            level="info",
            source="ops-experiment",
            log_path=state.log_paths.jsonl_path.as_posix(),
            summary_path=state.log_paths.summary_path.as_posix(),
        )
        process = subprocess.Popen(
            state.command,
            cwd=state.repo,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            text=True,
            bufsize=1,
        )
        logger.write("process_started", level="info", source="ops-experiment", pid=process.pid)
        events: queue.Queue[tuple[str, str | None]] = queue.Queue()
        parsers = {"stdout": JuliaTelemetryParser(), "stderr": JuliaTelemetryParser()}
        threads = [
            threading.Thread(target=enqueue_stream, args=("stdout", process.stdout, events), daemon=True),
            threading.Thread(target=enqueue_stream, args=("stderr", process.stderr, events), daemon=True),
        ]
        for thread in threads:
            thread.start()

        open_streams = {"stdout", "stderr"}
        while open_streams:
            stream_name, line = events.get()
            if line is None:
                open_streams.discard(stream_name)
                for parsed in parsers[stream_name].flush():
                    write_parsed_event(logger, state, stream_name, parsed)
                continue

            output = sys.stdout if stream_name == "stdout" else sys.stderr
            if stream_output:
                print(line, end="", file=output, flush=True)
            logger.write("process_output", level="info", source="process", stream=stream_name, line=line.rstrip("\n"))
            increment_event_count(state, "process_output")

            for parsed in parsers[stream_name].feed(line):
                write_parsed_event(logger, state, stream_name, parsed)

            artifact = parse_summary_line(line)
            if artifact is not None:
                key, value = artifact
                state.julia_summary.setdefault(key, []).append(value)
                logger.write(
                    "julia_summary_line",
                    level="info",
                    source="julia-summary",
                    stream=stream_name,
                    key=key,
                    value=value,
                )
                increment_event_count(state, "julia_summary_line")
                if is_output_artifact_key(key):
                    state.output_artifacts.setdefault(key, []).append(value)
                    logger.write(
                        "julia_output_artifact",
                        level="info",
                        source="julia-summary",
                        stream=stream_name,
                        key=key,
                        value=value,
                    )
                    increment_event_count(state, "julia_output_artifact")

        returncode = process.wait()
        for thread in threads:
            thread.join(timeout=1)
        status = "passed" if returncode == 0 else "failed"
        elapsed_s = time.monotonic() - start
        logger.write(
            "experiment_completed",
            level="info" if returncode == 0 else "error",
            source="ops-experiment",
            returncode=returncode,
            status=status,
            elapsed_s=round(elapsed_s, 6),
        )
        increment_event_count(state, "experiment_completed")
        write_summary(
            state.log_paths.summary_path,
            build_summary(
                state,
                returncode=returncode,
                elapsed_s=elapsed_s,
                status=status,
                git_snapshot_end=git_snapshot(state.repo),
            ),
        )
        return returncode
    except KeyboardInterrupt:
        if process is not None and process.poll() is None:
            logger.write("experiment_interrupted", level="warning", source="ops-experiment", signal="SIGINT")
            process.send_signal(signal.SIGINT)
            try:
                process.wait(timeout=5)
            except subprocess.TimeoutExpired:
                process.kill()
                process.wait()
        elapsed_s = time.monotonic() - start
        write_summary(
            state.log_paths.summary_path,
            build_summary(
                state,
                returncode=130,
                elapsed_s=elapsed_s,
                status="interrupted",
                git_snapshot_end=git_snapshot(state.repo),
            ),
        )
        return 130
    finally:
        logger.close()


def write_rejected_run(state: ExperimentState, *, reason: str, message: str, returncode: int) -> None:
    logger = JsonlLogger(
        state.log_paths.jsonl_path,
        {
            "run_id": state.run_id,
            "cwd": state.repo.as_posix(),
            "git_sha": state.git_sha,
            "command": state.command,
        },
    )
    try:
        logger.write(
            "experiment_rejected",
            level="error",
            source="ops-experiment",
            reason=reason,
            message=message,
            dirty_count=state.git_snapshot_start.get("dirty_count", 0),
        )
        increment_event_count(state, "experiment_rejected")
    finally:
        logger.close()
    write_summary(
        state.log_paths.summary_path,
        build_summary(
            state,
            returncode=returncode,
            elapsed_s=0.0,
            status="rejected",
            git_snapshot_end=git_snapshot(state.repo),
        ),
    )


def parse_args(argv: list[str] | None = None) -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--repo", type=Path, default=None, help="repository root; detected by default")
    parser.add_argument(
        "--launcher",
        default=DEFAULT_LAUNCHER,
        help=f"Julia CLI launcher relative to the repository root (default: {DEFAULT_LAUNCHER})",
    )
    parser.add_argument(
        "--log-dir",
        type=Path,
        default=Path(DEFAULT_LOG_DIR),
        help=f"JSON log directory relative to the repository root (default: {DEFAULT_LOG_DIR})",
    )
    parser.add_argument("--run-id", default=None, help="optional stable run identifier used in log file names")
    parser.add_argument("--label", default=None, help="optional label used when generating a run identifier")
    parser.add_argument(
        "--dirty-policy",
        choices=DIRTY_POLICIES,
        default="warn",
        help="how to handle a dirty git tree before running: allow, warn, or fail (default: warn)",
    )
    parser.add_argument("--no-stream", action="store_true", help="write JSON logs without echoing process output")
    parser.add_argument("julia_args", nargs=argparse.REMAINDER, help="Julia CLI command and options to run")
    return parser.parse_args(argv)


def build_command(repo: Path, launcher_value: str, julia_args: list[str]) -> list[str]:
    launcher = resolve_repo_path(repo, launcher_value)
    if not launcher.exists():
        raise FileNotFoundError(f"missing Julia experiment launcher: {launcher}")
    if not launcher.is_file():
        raise FileNotFoundError(f"Julia experiment launcher is not a file: {launcher}")
    if not os.access(launcher, os.X_OK):
        raise PermissionError(f"Julia experiment launcher is not executable: {launcher}")
    args = list(julia_args)
    if args and args[0] == "--":
        args = args[1:]
    if not args:
        raise ValueError("missing Julia CLI command; for example: ops-experiment benchmark --profile smoke")
    return [executable_path(repo, launcher), *args]


def main(argv: list[str] | None = None) -> int:
    args = parse_args(argv)
    repo = args.repo.expanduser().resolve() if args.repo is not None else repo_root()
    try:
        command = build_command(repo, args.launcher, args.julia_args)
    except (FileNotFoundError, PermissionError, ValueError) as exc:
        print(str(exc), file=sys.stderr)
        return 2

    command_label = args.label or command[1]
    log_dir = resolve_repo_path(repo, args.log_dir)
    log_paths = build_log_paths(log_dir, command_label, args.run_id)
    start_snapshot = git_snapshot(repo)
    state = ExperimentState(
        run_id=log_paths.run_id,
        command=command,
        repo=repo,
        log_paths=log_paths,
        started_at_utc=utc_timestamp(),
        git_sha=git_sha(repo),
        dirty_policy=args.dirty_policy,
        git_snapshot_start=start_snapshot,
    )

    print(f"Experiment run: {state.run_id}", flush=True)
    print(f"JSON log: {display_path(repo, log_paths.jsonl_path)}", flush=True)
    print(f"Summary: {display_path(repo, log_paths.summary_path)}", flush=True)
    if start_snapshot.get("dirty") and args.dirty_policy == "fail":
        message = "git tree is dirty; refusing to run because --dirty-policy=fail was requested."
        print(message, file=sys.stderr)
        write_rejected_run(state, reason="dirty_tree", message=message, returncode=3)
        print(f"Experiment summary: {display_path(repo, log_paths.summary_path)}", flush=True)
        return 3
    if start_snapshot.get("dirty") and args.dirty_policy == "warn":
        dirty_count = start_snapshot.get("dirty_count", 0)
        print(f"Warning: git tree is dirty before experiment ({dirty_count} status entries).", file=sys.stderr)
    print(f"+ {' '.join(command)}", flush=True)
    returncode = stream_process(state, stream_output=not args.no_stream)
    print(f"Experiment summary: {display_path(repo, log_paths.summary_path)}", flush=True)
    return returncode


if __name__ == "__main__":
    raise SystemExit(main())
