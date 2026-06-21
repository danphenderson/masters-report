import json
from pathlib import Path

from ops.orchestrate.session_sources import CodexJsonlSessionSource


def write_session(path: Path, records: list[dict]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text("\n".join(json.dumps(record) for record in records) + "\n", encoding="utf-8")


def test_codex_jsonl_source_normalizes_sessions_and_filters_repo(tmp_path: Path) -> None:
    repo = tmp_path / "repo"
    repo.mkdir()
    other_repo = tmp_path / "other"
    other_repo.mkdir()
    root = tmp_path / "sessions"
    day = root / "2026/06/20"

    write_session(
        day / "rollout-2026-06-20T10-00-00-019ee000-0000-7000-8000-000000000001.jsonl",
        [
            {
                "timestamp": "2026-06-20T17:00:00.000Z",
                "type": "session_meta",
                "payload": {
                    "id": "019ee000-0000-7000-8000-000000000001",
                    "timestamp": "2026-06-20T17:00:00.000Z",
                    "cwd": repo.as_posix(),
                    "parent_session_id": "019edfff-0000-7000-8000-000000000000",
                },
            },
            {
                "type": "response_item",
                "payload": {
                    "type": "message",
                    "role": "user",
                    "content": [{"type": "input_text", "text": "Validate the ops package\n\nThen hand back."}],
                },
            },
            {
                "type": "response_item",
                "payload": {
                    "type": "function_call",
                    "name": "exec_command",
                    "arguments": json.dumps({"cmd": "pipenv run ops-python-check"}),
                },
            },
            {
                "type": "response_item",
                "payload": {
                    "type": "function_call",
                    "name": "multi_tool_use.parallel",
                    "arguments": json.dumps(
                        {
                            "tool_uses": [
                                {
                                    "recipient_name": "functions.exec_command",
                                    "parameters": {"cmd": "pipenv run ops-orchestrate status --json"},
                                }
                            ]
                        }
                    ),
                },
            },
            {"type": "event_msg", "payload": {"type": "task_complete"}},
        ],
    )
    write_session(
        day / "rollout-2026-06-20T11-00-00-019ee000-0000-7000-8000-000000000002.jsonl",
        [
            {
                "timestamp": "2026-06-20T18:00:00.000Z",
                "type": "session_meta",
                "payload": {
                    "id": "019ee000-0000-7000-8000-000000000002",
                    "timestamp": "2026-06-20T18:00:00.000Z",
                    "cwd": repo.as_posix(),
                },
            },
            {
                "type": "response_item",
                "payload": {
                    "type": "message",
                    "role": "user",
                    "content": [{"type": "input_text", "text": "Start a long audit"}],
                },
            },
            {
                "type": "response_item",
                "payload": {
                    "type": "function_call",
                    "name": "exec_command",
                    "arguments": json.dumps({"cmd": "rg -n TODO packages/ops"}),
                },
            },
        ],
    )
    write_session(
        day / "rollout-2026-06-20T12-00-00-019ee000-0000-7000-8000-000000000003.jsonl",
        [
            {
                "timestamp": "2026-06-20T19:00:00.000Z",
                "type": "session_meta",
                "payload": {
                    "id": "019ee000-0000-7000-8000-000000000003",
                    "timestamp": "2026-06-20T19:00:00.000Z",
                    "cwd": other_repo.as_posix(),
                },
            },
        ],
    )

    summaries = CodexJsonlSessionSource(root).load_sessions(date="2026-06-20", repo=repo)

    assert [summary.session_id for summary in summaries] == [
        "019ee000-0000-7000-8000-000000000001",
        "019ee000-0000-7000-8000-000000000002",
    ]
    assert summaries[0].prompt_headline == "Validate the ops package"
    assert summaries[0].rollout_filename_id == "019ee000-0000-7000-8000-000000000001"
    assert summaries[0].final_status == "completed"
    assert summaries[0].command_count == 2
    assert summaries[0].validation_commands == (
        "pipenv run ops-python-check",
        "pipenv run ops-orchestrate status --json",
    )
    assert summaries[0].child_or_fork is True
    assert summaries[0].parent_session_id == "019edfff-0000-7000-8000-000000000000"
    assert summaries[1].final_status == "incomplete"
    assert summaries[1].validation_commands == ()
