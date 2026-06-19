# Repository Guidelines

## Project Structure & Module Organization

This repo has three active surfaces. Report source starts at
`final-report.tex`, with prose in `sections/`, appendices in `appendices/`,
shared setup in `preamble/`, bibliography in `references.bib`, and assets in
`figures/static/static/`. Julia solver code is the root package
`CanicExtended1D`: `src/CanicExtended1D.jl` includes modules under
`src/CanicExtended1D/`, `simulations/` holds drivers, and `test/*.jl` holds
Julia tests. The `research-hemodynamics` Python CLI lives under
`python/src/research_hemodynamics`, with Python tests in `test/test_*.py`. The
nested `references/AGENTS.md` governs only `references/**`.

## Build, Test, and Development Commands

- `./scripts/julia-release test/runtests.jl`: run the Julia test suite with the
  required Julia 1.12+ project environment.
- `pipenv install --dev && pipenv run python -m pip install -e .`: install
  Python tooling and the CLI.
- `pipenv run pytest`: run Python tests, including CLI and TeX audit tests.
- `pipenv run ruff check .` and `pipenv run black --check .`: lint and verify
  Python formatting.
- `latexmk -pdf -interaction=nonstopmode -halt-on-error -outdir=/tmp/masters-report-build final-report.tex`:
  validate the report in a scratch output directory.

## Coding Style & Naming Conventions

Use four-space indentation for Python. Black controls formatting with a
120-column line length; Python modules, functions, and CLI internals use
snake_case. Julia changes should enter through `using CanicExtended1D` and keep
descriptive lower-snake-case file names under `src/CanicExtended1D/`. Keep
reusable LaTeX packages, macros, theorem setup, colors, and TikZ/pgfplots
styles in `preamble/`; section and appendix files should contain content, not
shared command definitions.

## Testing Guidelines

Add Julia tests to the focused `test/test_*.jl` file and include new files from
`test/runtests.jl`. Add Python tests as `test/test_*.py`. For report or TeX
policy changes, run the preamble audit and a scratch `latexmk` build. If PDF
sync matters, compare rendered output before refreshing tracked artifacts.
Optional resolved-3D data, SciPy, and Torch/MPS support may be
absent; record expected skips instead of treating them as failures.

## Artifact & Scratch Discipline

Write experiment, CLI, and build outputs to ignored scratch paths such as
`tmp/**` or `/tmp/masters-report-build`. Do not refresh `final-report.pdf` or
rendered figure assets unless the change explicitly requires those artifacts.
Keep regenerated data/assets separate from unrelated source edits when
practical. See `docs/artifact-policy.md` for artifact classes and cleanup
guardrails.

## Commit & Pull Request Guidelines

Recent commits use short imperative subjects such as `Add Python hemodynamics
CLI baseline` or `Fix resolved3D benchmark rows`. Keep commits scoped to one
logical change. Pull requests should summarize impact, list validation, identify
skipped optional inputs, and include screenshots only for rendered figure or
layout changes.
