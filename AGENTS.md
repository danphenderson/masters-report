# Repository Guidelines

## Project Structure & Module Organization

This repo has three active surfaces. Report source starts at
`report/final-report.tex`, with prose in `report/sections/`, appendices in `report/appendices/`,
shared setup in `report/preamble/`, bibliography in `public/references/references.bib`, and assets in
`report/assets/`. Julia solver code is the `packages/julia/` package
`StenosisHemodynamics`: `packages/julia/src/StenosisHemodynamics.jl` includes modules under
`packages/julia/src/StenosisHemodynamics/`, `packages/julia/README.md` documents package usage,
and `packages/julia/test/*.jl` holds Julia tests. Optional local raw resolved-3D inputs live
under ignored `public/var/data/simulations/`. Python is auxiliary
report/support tooling only: audit and render scripts live under
`packages/ops/src/ops/*.py`, with Python tests in `packages/ops/tests/test_*.py`.
The root `Pipfile` owns the Python development environment and installs the
ops package from `packages/ops`.
The nested
`public/references/AGENTS.md` governs only `public/references/**`.

## Build, Test, and Development Commands

- `PIPENV_VENV_IN_PROJECT=1 pipenv install --dev`: create the root `.venv/`
  and install Python report/support tooling.
- `pipenv run ops-julia-check`: run the Julia test suite through the
  agent-facing Python ops validation surface. The wrapper uses the required
  Julia 1.12+ project launcher underneath.
- `pipenv run ops-python-check`: run Python audit/render tests, Ruff, and Black.
- `pipenv run ops-release-check --mode patch`: run the aggregate validation
  gates on a dirty development tree. Use `--mode release` only for clean
  publication readiness.
- `pipenv run ops-experiment <julia-command> [options]`: run Julia simulation,
  study, verification, comparison, or benchmark workflows through the Python
  experiment runner with live terminal streaming and JSON/JSONL logs under
  `public/var/logs/`.
- `pipenv run ops-orchestrate status`: summarize the live dirty tree by
  handoff surface before planning or delegation.
- `pipenv run ops-orchestrate sessions --source codex-jsonl --date YYYY-MM-DD --json`:
  summarize local Codex JSONL sessions for this repository when auditing agent
  work.
- `pipenv run ops-build-report --outdir /tmp/masters-report-build --no-sync-final-pdf`: run the
  validation-only report build gate. The wrapper runs the TeX preamble audit,
  invokes `latexmk -pdf -interaction=nonstopmode -halt-on-error` in a scratch
  output directory, fails on untracked consumed report inputs, and writes
  `report-build-summary.json` in the outdir. Omit `--no-sync-final-pdf` only
  for explicitly scoped artifact-refresh or publication work.

## Coding Style & Naming Conventions

Use four-space indentation for Python. Black controls formatting with a
120-column line length; Python support scripts and helpers use snake_case.
Julia changes should enter through `using StenosisHemodynamics` and keep
descriptive lower-snake-case file names under `packages/julia/src/StenosisHemodynamics/`. Keep
reusable LaTeX packages, macros, theorem setup, colors, and TikZ/pgfplots
styles in `report/preamble/`; section and appendix files should contain content, not
shared command definitions.

## Testing Guidelines

Add Julia tests to the focused `packages/julia/test/test_*.jl` file and include
new files from `packages/julia/test/runtests.jl`; run them with `pipenv run
ops-julia-check` for agent validation. Add Python tests as
`packages/ops/tests/test_*.py`. For report or TeX
policy changes, run `pipenv run ops-build-report --outdir
/tmp/masters-report-build --no-sync-final-pdf`; it covers the preamble audit,
scratch LaTeX build, and consumed-input tracking gate without refreshing the
local release PDF. If PDF sync matters, compare rendered output before
refreshing tracked artifacts. Optional resolved-3D data may be absent; record
expected skips instead of treating them as failures.

## Artifact & Scratch Discipline

Write experiment, CLI, and build outputs to ignored scratch paths such as
`tmp/**`, `tmp/simulations/output/**`, `public/var/logs/*.jsonl`, or
`/tmp/masters-report-build`. Do not refresh `public/final-report.pdf` or
rendered figure assets unless the change explicitly requires those artifacts.
Keep regenerated data/assets separate from unrelated source edits when
practical. The report wrapper writes its JSON summary into the scratch outdir;
inspect it instead of staging or deleting untracked consumed inputs. See
`public/docs/index.md` for the documentation map,
`public/docs/artifact-policy.md` for artifact classes and cleanup guardrails,
`public/docs/report-builds.md` for build modes,
`public/docs/report-assets-and-provenance.md` for report asset ownership, and
`public/docs/agent-workflows.md` for the lightweight handoff contract.

## Patch Discipline

Implementation patches should land in small chunks: one coherent surface per
patch, followed by the narrow validation for that surface. Do not mix source,
artifact, and documentation churn unless the validation dependency requires the
files to move together.

## Recommended Codex Sequence

Start substantial Codex work with `pipenv run ops-orchestrate status --json`.
Run experiments through `pipenv run ops-experiment --dirty-policy warn ...` so
the handback can cite the summary JSON under `public/var/logs/`. For ordinary
dirty-tree validation, use `pipenv run ops-release-check --mode patch
--report-outdir /tmp/masters-report-build`. Reserve `pipenv run
ops-release-check --mode release` for clean publication readiness or final
artifact refresh lanes.

## Commit & Pull Request Guidelines

Recent commits use short imperative subjects such as `Rename Julia solver
package` or `Fix resolved3D benchmark rows`. Keep commits scoped to one
logical change. Pull requests should summarize impact, list validation, identify
skipped optional inputs, and include screenshots only for rendered figure or
layout changes.
