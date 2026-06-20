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

- `packages/julia/bin/julia-release packages/julia/test/runtests.jl`: run the Julia test suite with the
  required Julia 1.12+ project environment.
- `PIPENV_VENV_IN_PROJECT=1 pipenv install --dev`: create the root `.venv/`
  and install Python report/support tooling.
- `pipenv run ops-python-check`: run Python audit/render tests, Ruff, and Black.
- `pipenv run ops-orchestrate status`: summarize the live dirty tree by
  handoff surface before planning or delegation.
- `pipenv run ops-build-report --outdir /tmp/masters-report-build`: run the
  agent-facing report build gate. The wrapper runs the TeX preamble audit,
  invokes `latexmk -pdf -interaction=nonstopmode -halt-on-error` in a scratch
  output directory, fails on untracked consumed report inputs, and writes
  `report-build-summary.json` in the outdir.

## Coding Style & Naming Conventions

Use four-space indentation for Python. Black controls formatting with a
120-column line length; Python support scripts and helpers use snake_case.
Julia changes should enter through `using StenosisHemodynamics` and keep
descriptive lower-snake-case file names under `packages/julia/src/StenosisHemodynamics/`. Keep
reusable LaTeX packages, macros, theorem setup, colors, and TikZ/pgfplots
styles in `report/preamble/`; section and appendix files should contain content, not
shared command definitions.

## Testing Guidelines

Add Julia tests to the focused `packages/julia/test/test_*.jl` file and include new files from
`packages/julia/test/runtests.jl`. Add Python tests as `packages/ops/tests/test_*.py`. For report or TeX
policy changes, run `pipenv run ops-build-report --outdir
/tmp/masters-report-build`; it covers the preamble audit, scratch LaTeX build,
and consumed-input tracking gate. If PDF sync matters, compare rendered output
before refreshing tracked artifacts. Optional resolved-3D data may be absent;
record expected skips instead of treating them as failures.

## Artifact & Scratch Discipline

Write experiment, CLI, and build outputs to ignored scratch paths such as
`tmp/**`, `tmp/simulations/output/**`, or `/tmp/masters-report-build`. Do not refresh `public/final-report.pdf` or
rendered figure assets unless the change explicitly requires those artifacts.
Keep regenerated data/assets separate from unrelated source edits when
practical. The report wrapper writes its JSON summary into the scratch outdir;
inspect it instead of staging or deleting untracked consumed inputs. See
`public/docs/artifact-policy.md` for artifact classes and cleanup guardrails,
and `public/docs/agent-workflows.md` for the lightweight handoff contract.

## Patch Discipline

Implementation patches should land in small chunks: one coherent surface per
patch, followed by the narrow validation for that surface. Do not mix source,
artifact, and documentation churn unless the validation dependency requires the
files to move together.

## Commit & Pull Request Guidelines

Recent commits use short imperative subjects such as `Rename Julia solver
package` or `Fix resolved3D benchmark rows`. Keep commits scoped to one
logical change. Pull requests should summarize impact, list validation, identify
skipped optional inputs, and include screenshots only for rendered figure or
layout changes.
