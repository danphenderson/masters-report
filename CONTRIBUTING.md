# Contributing

This project is a research codebase and report source tree. Keep changes small,
reviewable, and tied to a reproducible validation path.

## Development

- Use `./scripts/julia-release test/runtests.jl` for Julia package changes.
- Use `pipenv run pytest`, `pipenv run ruff check .`, and
  `pipenv run black --check .` for Python support-tooling changes.
- Use a scratch LaTeX output directory for report builds:

  ```sh
  latexmk -pdf -interaction=nonstopmode -halt-on-error -outdir=/tmp/masters-report-build final-report.tex
  ```

## Artifact Discipline

- Do not commit local caches, virtual environments, root LaTeX byproducts,
  simulation outputs, raw resolved-3D inputs, or private review notes.
- Do not commit third-party full-text PDFs or HTML mirrors under `references/`.
  Keep `references.bib` and `references/source-inventory.tsv` synchronized
  instead.
- Keep generated report assets separate from source edits when practical.

## Pull Requests

Summaries should state the changed surface, validation run, and any skipped
optional data inputs. Numerical changes should include the smallest smoke case
or regression test that exercises the changed behavior.
