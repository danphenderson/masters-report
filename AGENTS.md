# Repository Guidelines

## Project Structure & Module Organization

This repo has three active surfaces. Report source starts at
`report/final-report.tex`, with prose in `report/sections/`, appendices in `report/appendices/`,
shared setup in `report/preamble/`, bibliography in `references/references.bib`, and assets in
`report/assets/`. Julia solver code is the `julia/` package
`StenosisHemodynamics`: `julia/src/StenosisHemodynamics.jl` includes modules under
`julia/src/StenosisHemodynamics/`, `julia/simulations/` holds simulation guidance and
local run data, and `julia/test/*.jl` holds Julia tests. Python is auxiliary
report/support tooling only: audit and render scripts live under
`tools/python/scripts/*.py`, with Python tests in `tools/python/test/test_*.py`.
The nested
`references/AGENTS.md` governs only `references/**`.

## Build, Test, and Development Commands

- `bin/julia-release julia/test/runtests.jl`: run the Julia test suite with the
  required Julia 1.12+ project environment.
- `PIPENV_PIPFILE=tools/python/Pipfile pipenv install --dev`: install Python
  report/support tooling.
- `bin/python-check`: run Python audit/render tests, Ruff, and Black.
- `bin/build-report --outdir /tmp/masters-report-build`: run the
  agent-facing report build gate. The wrapper runs the TeX preamble audit,
  invokes `latexmk -pdf -interaction=nonstopmode -halt-on-error` in a scratch
  output directory, fails on untracked consumed report inputs, and writes
  `report-build-summary.json` in the outdir.

## Coding Style & Naming Conventions

Use four-space indentation for Python. Black controls formatting with a
120-column line length; Python support scripts and helpers use snake_case.
Julia changes should enter through `using StenosisHemodynamics` and keep
descriptive lower-snake-case file names under `julia/src/StenosisHemodynamics/`. Keep
reusable LaTeX packages, macros, theorem setup, colors, and TikZ/pgfplots
styles in `report/preamble/`; section and appendix files should contain content, not
shared command definitions.

## Testing Guidelines

Add Julia tests to the focused `julia/test/test_*.jl` file and include new files from
`julia/test/runtests.jl`. Add Python tests as `tools/python/test/test_*.py`. For report or TeX
policy changes, run `bin/build-report --outdir
/tmp/masters-report-build`; it covers the preamble audit, scratch LaTeX build,
and consumed-input tracking gate. If PDF sync matters, compare rendered output
before refreshing tracked artifacts. Optional resolved-3D data may be absent;
record expected skips instead of treating them as failures.

## Artifact & Scratch Discipline

Write experiment, CLI, and build outputs to ignored scratch paths such as
`tmp/**` or `/tmp/masters-report-build`. Do not refresh `final-report.pdf` or
rendered figure assets unless the change explicitly requires those artifacts.
Keep regenerated data/assets separate from unrelated source edits when
practical. The report wrapper writes its JSON summary into the scratch outdir;
inspect it instead of staging or deleting untracked consumed inputs. See
`docs/artifact-policy.md` for artifact classes and cleanup guardrails.

## Commit & Pull Request Guidelines

Recent commits use short imperative subjects such as `Rename Julia solver
package` or `Fix resolved3D benchmark rows`. Keep commits scoped to one
logical change. Pull requests should summarize impact, list validation, identify
skipped optional inputs, and include screenshots only for rendered figure or
layout changes.
