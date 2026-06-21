"""Session-audit source interfaces for orchestration summaries."""

from __future__ import annotations

import json
import re
from dataclasses import dataclass
from pathlib import Path
from typing import Any, Protocol

VALIDATION_NEEDLES = (
    "ops-python-check",
    "ops-julia-check",
    "ops-release-check",
    "ops-build-report",
    "ops-orchestrate",
    "ops-experiment",
    "git diff --check",
    "pytest",
    "ruff",
    "black",
    "latexmk",
    "pdfinfo",
    "pdftotext",
)

ROLLOUT_FILENAME_RE = re.compile(
    r"^rollout-(?P<timestamp>\d{4}-\d{2}-\d{2}T\d{2}-\d{2}-\d{2})-(?P<rollout_id>[0-9a-fA-F-]{36})\.jsonl$"
)


@dataclass(frozen=True)
class SessionSummary:
    source: str
    path: str
    rollout_filename_id: str
    session_id: str
    cwd: str
    started_at_utc: str
    prompt_headline: str
    final_status: str
    command_count: int
    validation_commands: tuple[str, ...]
    child_or_fork: bool
    parent_session_id: str


class SessionSource(Protocol):
    source_name: str

    def load_sessions(self, *, date: str, repo: Path | None = None) -> list[SessionSummary]:
        """Return normalized session summaries for a date."""


def default_codex_sessions_root() -> Path:
    return Path.home() / ".codex" / "sessions"


def _date_path(root: Path, date: str) -> Path:
    year, month, day = date.split("-", 2)
    return root / year / month / day


def _first_text(content: Any) -> str:
    if isinstance(content, str):
        return content
    if not isinstance(content, list):
        return ""
    parts: list[str] = []
    for item in content:
        if isinstance(item, dict):
            text = item.get("text") or item.get("input_text") or item.get("output_text")
            if isinstance(text, str):
                parts.append(text)
    return "\n".join(parts)


def prompt_headline(text: str, *, limit: int = 120) -> str:
    for line in text.splitlines():
        stripped = line.strip()
        if stripped:
            return stripped[:limit]
    return ""


def user_prompt_text(text: str) -> str:
    cleaned = text
    for marker in ("</environment_context>", "</INSTRUCTIONS>"):
        if marker in cleaned:
            cleaned = cleaned.split(marker, 1)[1]
    return cleaned.strip()


def _repo_matches(session_cwd: str, repo: Path | None) -> bool:
    if repo is None:
        return True
    if not session_cwd:
        return False
    try:
        return Path(session_cwd).expanduser().resolve(strict=False) == repo.expanduser().resolve(strict=False)
    except OSError:
        return False


def _json_arguments(value: Any) -> Any:
    if isinstance(value, str):
        try:
            return json.loads(value)
        except json.JSONDecodeError:
            return {}
    return value if isinstance(value, (dict, list)) else {}


def _extract_commands_from_args(value: Any) -> list[str]:
    commands: list[str] = []
    if isinstance(value, dict):
        cmd = value.get("cmd")
        if isinstance(cmd, str):
            commands.append(cmd)
        command = value.get("command")
        if isinstance(command, list) and all(isinstance(part, str) for part in command):
            commands.append(" ".join(command))
        for child in value.values():
            commands.extend(_extract_commands_from_args(child))
    elif isinstance(value, list):
        for child in value:
            commands.extend(_extract_commands_from_args(child))
    return commands


def _dedupe_preserve_order(values: list[str]) -> tuple[str, ...]:
    seen: set[str] = set()
    deduped: list[str] = []
    for value in values:
        if value not in seen:
            seen.add(value)
            deduped.append(value)
    return tuple(deduped)


def _is_validation_command(command: str) -> bool:
    return any(needle in command for needle in VALIDATION_NEEDLES)


def _session_parent_id(payload: dict[str, Any]) -> str:
    for key in ("parent_session_id", "parent_id", "forked_from", "forked_from_session_id"):
        value = payload.get(key)
        if isinstance(value, str):
            return value
    return ""


class CodexJsonlSessionSource:
    source_name = "codex-jsonl"

    def __init__(self, root: Path | None = None) -> None:
        self.root = (root or default_codex_sessions_root()).expanduser()

    def load_sessions(self, *, date: str, repo: Path | None = None) -> list[SessionSummary]:
        date_dir = _date_path(self.root, date)
        if not date_dir.exists():
            return []
        summaries = [self._load_file(path, repo=repo) for path in sorted(date_dir.glob("rollout-*.jsonl"))]
        return [summary for summary in summaries if summary is not None]

    def _load_file(self, path: Path, *, repo: Path | None) -> SessionSummary | None:
        filename_match = ROLLOUT_FILENAME_RE.match(path.name)
        rollout_filename_id = filename_match.group("rollout_id") if filename_match else path.stem
        filename_timestamp = filename_match.group("timestamp") if filename_match else ""

        session_id = ""
        cwd = ""
        started_at_utc = ""
        prompt = ""
        final_status = "incomplete"
        parent_session_id = ""
        commands: list[str] = []

        for line in path.read_text(encoding="utf-8", errors="replace").splitlines():
            if not line.strip():
                continue
            try:
                record = json.loads(line)
            except json.JSONDecodeError:
                continue

            record_type = record.get("type")
            payload = record.get("payload") if isinstance(record.get("payload"), dict) else {}
            if record_type == "session_meta":
                session_id = str(payload.get("id") or "")
                cwd = str(payload.get("cwd") or "")
                started_at_utc = str(payload.get("timestamp") or record.get("timestamp") or "")
                parent_session_id = _session_parent_id(payload)
                continue

            if record_type == "event_msg":
                event_type = str(payload.get("type") or "")
                if event_type in {"task_complete", "turn_complete"}:
                    final_status = "completed"
                if event_type in {"error", "agent_error"}:
                    final_status = "failed"
                if not prompt and event_type == "user_message":
                    prompt = user_prompt_text(_first_text(payload.get("content") or payload.get("message")))
                continue

            if record_type != "response_item":
                continue

            item_type = str(payload.get("type") or "")
            if item_type == "message":
                role = str(payload.get("role") or "")
                if role == "user" and not prompt:
                    prompt = user_prompt_text(_first_text(payload.get("content")))
                if role == "assistant":
                    phase = str(payload.get("phase") or "")
                    if phase in {"final", "final_answer"}:
                        final_status = "completed"
                continue

            if item_type == "function_call":
                name = str(payload.get("name") or "")
                args = _json_arguments(payload.get("arguments"))
                if name.endswith("exec_command") or "exec_command" in json.dumps(args):
                    commands.extend(_extract_commands_from_args(args))

        if not _repo_matches(cwd, repo):
            return None

        validation_commands = _dedupe_preserve_order(
            [command for command in commands if _is_validation_command(command)]
        )
        started = started_at_utc or filename_timestamp
        effective_session_id = session_id or rollout_filename_id
        child_or_fork = bool(parent_session_id) or (
            bool(session_id) and bool(rollout_filename_id) and session_id != rollout_filename_id
        )

        return SessionSummary(
            source=self.source_name,
            path=path.as_posix(),
            rollout_filename_id=rollout_filename_id,
            session_id=effective_session_id,
            cwd=cwd,
            started_at_utc=started,
            prompt_headline=prompt_headline(prompt),
            final_status=final_status,
            command_count=len(commands),
            validation_commands=validation_commands,
            child_or_fork=child_or_fork,
            parent_session_id=parent_session_id,
        )


def session_source(name: str, *, root: Path | None = None) -> SessionSource:
    if name == "codex-jsonl":
        return CodexJsonlSessionSource(root)
    raise ValueError(f"unknown session source: {name}")
