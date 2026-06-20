# Repository Guidelines

## Project Structure & Module Organization

This repo has three active surfaces. Report source starts at
`final-report.tex`, with prose in `sections/`, appendices in `appendices/`,
shared setup in `preamble/`, bibliography in `references.bib`, and assets in
`figures/static/static/`. Julia solver code is the root package
`StenosisHemodynamics`: `src/StenosisHemodynamics.jl` includes modules under
`src/StenosisHemodynamics/`, `simulations/` holds drivers, and `test/*.jl` holds
Julia tests. Python is auxiliary report/support tooling only: audit and render
scripts live under `scripts/*.py`, with Python tests in `test/test_*.py`. The nested
`references/AGENTS.md` governs only `references/**`.

## Build, Test, and Development Commands

- `./scripts/julia-release test/runtests.jl`: run the Julia test suite with the
  required Julia 1.12+ project environment.
- `pipenv install --dev`: install Python report/support tooling.
- `pipenv run pytest`: run Python audit/render tests.
- `pipenv run ruff check .` and `pipenv run black --check .`: lint and verify
  Python formatting.
- `python3 scripts/build_report.py --outdir /tmp/masters-report-build`: run the
  agent-facing report build gate. The wrapper runs the TeX preamble audit,
  invokes `latexmk -pdf -interaction=nonstopmode -halt-on-error` in a scratch
  output directory, fails on untracked consumed report inputs, and writes
  `report-build-summary.json` in the outdir.

## Coding Style & Naming Conventions

Use four-space indentation for Python. Black controls formatting with a
120-column line length; Python support scripts and helpers use snake_case.
Julia changes should enter through `using StenosisHemodynamics` and keep
descriptive lower-snake-case file names under `src/StenosisHemodynamics/`. Keep
reusable LaTeX packages, macros, theorem setup, colors, and TikZ/pgfplots
styles in `preamble/`; section and appendix files should contain content, not
shared command definitions.

## Testing Guidelines

Add Julia tests to the focused `test/test_*.jl` file and include new files from
`test/runtests.jl`. Add Python tests as `test/test_*.py`. For report or TeX
policy changes, run `python3 scripts/build_report.py --outdir
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
