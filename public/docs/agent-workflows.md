# Lightweight Agent Workflows

Use `ops-orchestrate` for bounded agent handoffs. Treat it as a planning and
checking surface, not as an execution engine.

Tracked pre-commit config is allowed; local hook installation is explicit. Do
not create background automation. Do not write persistent orchestration
receipts. Re-anchor every handoff on the live checkout, local files, and
validation output. Scope mutations to explicitly named files.

Contract limits:

- Tracked pre-commit config is allowed; local hook installation is explicit.
- No background automation.
- No persistent orchestration receipts.

Read `public/docs/artifact-policy.md` before cleanup, artifact moves, generated
asset refreshes, or release-PDF work. Use `public/docs/policy-vocabulary.md`
for shared terms and modal verbs.

## Command Surface

```sh
pipenv run ops-orchestrate status
pipenv run ops-orchestrate sessions --source codex-jsonl --date YYYY-MM-DD --json
pipenv run ops-orchestrate dispatch --surface report --mode inspect --objective "Review section scope"
pipenv run ops-orchestrate review --commit 786e8f9 --lane orchestration
pipenv run ops-orchestrate handback-check --path /tmp/handback.md --surface report --mode inspect
pipenv run ops-orchestrate packet-check --path /tmp/handoff.md --profile editorial-readiness
pipenv run ops-orchestrate docs-contract
```

Run `status` before dispatching cleanup, editorial, artifact, or release work.
It classifies dirty paths by surface and flags protected/generated artifact
drift. Add `--strict` when protected artifacts or unclassified paths must fail a
readiness check.

Run `sessions` when auditing local Codex work. The `codex-jsonl` source reads
date-sharded logs under `~/.codex/sessions`, filters by repository cwd, and
normalizes rollout filename id, session id, timestamps, prompt headline, final
status, command count, validation commands, and child/fork markers. Keep default
output in the terminal or JSON; write markdown only to ignored `tmp/**` or
`/tmp`.

Run `dispatch` to print a copy-paste-ready task packet. Treat the packet as
handoff text, not execution. Name exact files with `--files` before allowing
edits. Mutating modes `bounded-edit` and `artifact-refresh` require `--files`.

Run `review` to print a read-only delegated review packet for one named lane.
Start reviewers from `git status --short --branch --untracked-files=all`, cite
the reviewed commit, forbid mutations, list allowed inspection files, and
require the standard handback sections.

Run `handback-check` on worker handbacks. Require `Status`, `Scope`, `Files`,
`Validation`, and `Risks`. Require the expected validation command, or a
deliberate skip reason in `Validation`. When `--profile` is supplied, require
the profile-specific handback sections.

Run `packet-check` before sending external handoff text. Reject stale taxonomy
paths, missing current validation commands, missing `public/final-report.pdf`
and `report/assets/rendered/**` guardrails, and broad
regenerate/rewrite-as-needed authority.

Run `docs-contract` after changing this workflow or related public docs. It
checks that the documented orchestration surface still matches the live
lightweight contract.

## Mode Semantics

| Mode | Mutation allowed? | Required scope | Intended use |
| --- | --- | --- | --- |
| `inspect` | No | Surface only | Read-only orientation or scoped review |
| `hard-review` | No | Surface plus lane or profile | Findings-first delegated review |
| `bounded-edit` | Yes | Explicit `--files` | Named-file source edits |
| `artifact-refresh` | Yes | Explicit `--files` plus passed owning gate | Generated report assets or release PDF refresh |

Supported surfaces are `report`, `julia`, `ops`, `references`, `assets`, and
`release`.

Use `artifact-refresh` only when a tracked rendered asset or
`public/final-report.pdf` is intentionally in scope. Keep `public/final-report.pdf`
blocked in every other mode. Refresh `report/assets/rendered/**` only when the
paths are listed in `--files` and the owning gate passes.

## Editorial Profiles

Use `--profile generic` for the base workflow. Use a specific editorial profile
when the handoff needs a controlled review vocabulary:

- `editorial-readiness`: committee-facing structure, clarity, mathematical
  exposition, defense-readiness risks, and a final readiness verdict.
- `claim-boundary`: separation of model specification, numerical verification,
  cross-model comparison, and validation.
- `citation-evidence`: citation placement, bibliography/source-inventory
  consistency, and unresolved source roles.
- `pdf-sync`: source/rendered-PDF alignment when `public/final-report.pdf` is
  explicitly in scope.
- `source-polish`: bounded prose edits in named source files without artifact or
  numbering churn.

Profiled handbacks still include `Status`, `Scope`, `Files`, `Validation`, and
`Risks`. They also include the profile-specific sections printed by the dispatch
packet.

## Patch Discipline

Keep implementation patches small. Limit each patch to one coherent surface.
Validate that surface before starting the next patch. Do not mix source,
artifact, and documentation churn unless the validation dependency requires the
files to move together.

Preserve unrelated dirty work. If the live tree already contains manuscript,
artifact, or ops changes outside the task, treat those changes as user-owned
context and leave them intact.

## Validation Defaults

- `report`: `pipenv run ops-build-report --outdir /tmp/masters-report-build --no-sync-final-pdf`
- `julia`: `pipenv run ops-julia-check`
- `ops`: `pipenv run ops-python-check`
- `references`: `pipenv run ops-audit-references`, targeted reference/preamble
  tests, and `biber --tool --validate-datamodel`
- `assets`: the owning renderer or Julia workflow, followed by
  `pipenv run ops-build-report --outdir /tmp/masters-report-build --no-sync-final-pdf`
- `release`: `pipenv run ops-release-check --mode release`

Use validation-only report builds for ordinary source review. Use the full
report build only for `artifact-refresh` tasks that explicitly include
`public/final-report.pdf` or generated report assets.

## Related Policies

- Use `public/docs/index.md` for the full documentation map.
- Use `public/docs/policy-vocabulary.md` for shared terms and modal verbs.
- Use `public/docs/report-builds.md` for validation-only and artifact-refresh
  report builds.
- Use `public/docs/ops-tooling.md` for packaged Python support commands.
- Use `public/docs/julia-cli-workflows.md` for Julia command workflows.
- Use `public/docs/report-assets-and-provenance.md` before report asset refresh.
- Use `public/docs/resolved3d-workflows.md` before optional resolved-3D work.
- Use `public/docs/artifact-policy.md` before moving, deleting, regenerating, or
  publishing artifacts.
- Use `public/docs/benchmark-pipeline.md` when generating package benchmark
  outputs or report-consumed benchmark assets.
- Use `public/docs/publication-readiness.md` before public export or release
  publication.
