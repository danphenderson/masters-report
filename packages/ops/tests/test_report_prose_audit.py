import json
import subprocess
import sys
from pathlib import Path

from ops import audit_report_prose


def init_git_repo(path: Path) -> None:
    subprocess.run(["git", "init"], cwd=path, check=True, capture_output=True)
    subprocess.run(["git", "config", "user.email", "test@example.com"], cwd=path, check=True)
    subprocess.run(["git", "config", "user.name", "Test User"], cwd=path, check=True)


def test_report_tex_files_discovers_current_report_tex(tmp_path: Path) -> None:
    init_git_repo(tmp_path)
    tracked = tmp_path / "report/final-report.tex"
    tracked.parent.mkdir(parents=True)
    tracked.write_text("Tracked prose paragraph for discovery.\n", encoding="utf-8")
    section = tmp_path / "report/sections/example.tex"
    section.parent.mkdir(parents=True)
    section.write_text("Tracked section prose paragraph for discovery.\n", encoding="utf-8")
    ignored = tmp_path / "notes/outside.tex"
    ignored.parent.mkdir(parents=True)
    ignored.write_text("Outside report.\n", encoding="utf-8")
    subprocess.run(["git", "add", "report/final-report.tex", "report/sections/example.tex"], cwd=tmp_path, check=True)
    untracked = tmp_path / "report/sections/untracked.tex"
    untracked.write_text("Untracked report prose paragraph for discovery.\n", encoding="utf-8")

    paths = {path.relative_to(tmp_path).as_posix() for path in audit_report_prose.report_tex_files(tmp_path)}

    assert paths == {
        "report/final-report.tex",
        "report/sections/example.tex",
        "report/sections/untracked.tex",
    }


def test_strip_latex_comment_preserves_escaped_percent() -> None:
    assert audit_report_prose.strip_latex_comment(r"keeps \% value % drops comment") == r"keeps \% value "


def test_parse_tex_file_excludes_tables_and_listings_but_keeps_caption(tmp_path: Path) -> None:
    init_git_repo(tmp_path)
    tex = tmp_path / "report/sections/example.tex"
    tex.parent.mkdir(parents=True)
    tex.write_text(
        "\n".join(
            [
                r"\section{Example Section}",
                "This opening paragraph contains enough ordinary manuscript prose to be retained by the parser.",
                "It should become one chunk with visible section context and no table row contamination.",
                "",
                r"\begin{table}",
                (
                    r"\caption{This retained caption explains a manuscript table in ordinary prose for audit review, "
                    "including enough descriptive language to be retained as caption prose.}"
                ),
                r"\begin{tabularx}{\textwidth}{XX}",
                r"\textbf{Column} & \textbf{Repeated generated row text} \\",
                r"Generated & repeated generated row text repeated generated row text \\",
                r"\end{tabularx}",
                r"\end{table}",
                "",
                r"\begin{lstlisting}",
                "packages/stenotic-hemodynamics/bin/stenotic-hemodynamics verify mms --output-dir tmp",
                r"\end{lstlisting}",
            ]
        ),
        encoding="utf-8",
    )

    chunks = audit_report_prose.parse_tex_file(tex, tmp_path)
    text = " ".join(chunk.text for chunk in chunks)

    assert "Example Section" in chunks[0].section_context
    assert "ordinary manuscript prose" in text
    assert "retained caption explains" in text
    assert "Generated repeated generated row" not in text
    assert "stenotic-hemodynamics verify" not in text


def test_exact_duplicate_detection_reports_repeated_span() -> None:
    chunks = (
        audit_report_prose.ProseChunk(
            path="report/sections/a.tex",
            line=10,
            section_context="A",
            environment="",
            context=False,
            text=" ".join(f"word{i}" for i in range(30)),
            normalized=" ".join(f"word{i}" for i in range(30)),
            words=tuple(f"word{i}" for i in range(30)),
        ),
        audit_report_prose.ProseChunk(
            path="report/sections/b.tex",
            line=20,
            section_context="B",
            environment="",
            context=False,
            text=" ".join(f"word{i}" for i in range(30)),
            normalized=" ".join(f"word{i}" for i in range(30)),
            words=tuple(f"word{i}" for i in range(30)),
        ),
    )

    findings = audit_report_prose.exact_duplicate_findings(chunks)

    assert any(finding.rule == "exact-duplicate" and finding.severity == "high" for finding in findings)


def test_near_duplicate_detection_reports_high_overlap() -> None:
    first_words = tuple(
        "the model comparison limitation remains bounded because section mean velocity is retained for review".split()
    )
    second_words = tuple(
        "the model comparison limitation remains bounded because section mean velocity is retained for interpretation".split()
    )
    chunks = (
        audit_report_prose.ProseChunk(
            "report/sections/a.tex",
            1,
            "A",
            "",
            False,
            " ".join(first_words),
            " ".join(first_words),
            first_words,
        ),
        audit_report_prose.ProseChunk(
            "report/sections/b.tex",
            1,
            "B",
            "",
            False,
            " ".join(second_words),
            " ".join(second_words),
            second_words,
        ),
    )

    findings = audit_report_prose.near_duplicate_findings(chunks, set())

    assert len(findings) == 1
    assert findings[0].rule == "near-duplicate"
    assert findings[0].score is not None and findings[0].score >= 0.35


def test_topic_owner_flags_software_provenance_outside_appendix() -> None:
    text = (
        "The local thesis copy states that no public repository or archival DOI is asserted, "
        "and the reproducibility record remains local."
    )
    words = audit_report_prose.normalized_words(text)
    chunk = audit_report_prose.ProseChunk(
        "report/sections/01-intro/index.tex",
        5,
        "Introduction",
        "",
        False,
        text,
        " ".join(words),
        words,
    )

    findings = audit_report_prose.topic_owner_findings((chunk,))

    assert findings
    assert findings[0].rule == "topic-owner-software-provenance"


def test_topic_owner_comparison_limits_ignores_generic_observation_operator_overview() -> None:
    text = (
        "Observation operators are part of the model, not post-processing decoration. "
        "A 1D area-flow solution does not natively contain the same observable as a resolved 3D field."
    )
    words = audit_report_prose.normalized_words(text)
    chunk = audit_report_prose.ProseChunk(
        "report/sections/06-synthesis/index.tex",
        46,
        "Synthesis",
        "",
        False,
        text,
        " ".join(words),
        words,
    )

    findings = audit_report_prose.topic_owner_findings((chunk,))

    assert all(finding.rule != "topic-owner-comparison-limits" for finding in findings)


def test_topic_owner_comparison_limits_flags_quarantined_radial_limit_outside_owner() -> None:
    text = (
        "The radial reducer remains quarantined pending matching limits reconciliation, "
        "and deformed coordinate mode applies the node centered displacement before section cuts."
    )
    words = audit_report_prose.normalized_words(text)
    chunk = audit_report_prose.ProseChunk(
        "report/sections/08-discussion-conclusion/index.tex",
        22,
        "Integrated Discussion",
        "",
        False,
        text,
        " ".join(words),
        words,
    )

    findings = audit_report_prose.topic_owner_findings((chunk,))

    assert findings
    assert findings[0].rule == "topic-owner-comparison-limits"


def test_mms_metric_order_audit_flags_l2_only_order_wording() -> None:
    text = (
        "The verification table reports cell-center discrete errors with observed orders "
        "computed from the discrete rows as a single adjacent-grid estimate."
    )
    words = audit_report_prose.normalized_words(text)
    chunk = audit_report_prose.ProseChunk(
        "report/sections/07-case-study/verification.tex",
        128,
        "Numerical Verification > Manufactured-Solution Verification",
        "",
        False,
        text,
        " ".join(words),
        words,
    )

    findings = audit_report_prose.mms_metric_order_findings((chunk,))

    assert findings
    assert findings[0].rule == "mms-metric-order-coverage"


def test_mms_metric_order_audit_accepts_metric_specific_order_wording() -> None:
    text = (
        "The MMS verification table computes observed orders separately for the discrete "
        "L1, L2, and Linf metrics, preserving the distinction between integrated, RMS-like, "
        "and maximum pointwise error behavior."
    )
    words = audit_report_prose.normalized_words(text)
    chunk = audit_report_prose.ProseChunk(
        "report/sections/07-case-study/verification.tex",
        128,
        "Numerical Verification > Manufactured-Solution Verification",
        "",
        False,
        text,
        " ".join(words),
        words,
    )

    findings = audit_report_prose.mms_metric_order_findings((chunk,))

    assert findings == []


def test_report_prose_audit_current_tree_smoke() -> None:
    repo = Path(__file__).resolve().parents[3]
    result = subprocess.run(
        [sys.executable, "-m", "ops.audit_report_prose", "--repo", repo.as_posix(), "--json"],
        cwd=repo,
        text=True,
        capture_output=True,
        check=False,
    )

    assert result.returncode == 0, result.stdout + result.stderr
    payload = json.loads(result.stdout)
    assert payload["files_seen"] > 0
    assert "findings" in payload
