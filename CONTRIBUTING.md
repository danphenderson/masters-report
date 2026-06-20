# Contributing

This project is a research codebase and report source tree. Keep changes small,
reviewable, and tied to a reproducible validation path.

## Development

- Use `packages/julia/bin/julia-release packages/julia/test/runtests.jl` for Julia package changes.
- Use `pipenv run ops-python-check` for Python support-tooling changes.
- Use a scratch LaTeX output directory for report builds:

  ```sh
  pipenv run ops-build-report --outdir /tmp/masters-report-build
  ```

## Artifact Discipline

- Do not commit local caches, virtual environments, root LaTeX byproducts,
  simulation outputs, raw resolved-3D inputs, or private review notes.
- Do not commit third-party full-text PDFs or HTML mirrors under `public/references/`.
  Keep `public/references/references.bib` and `public/references/source-inventory.tsv` synchronized
  instead.
- Keep generated report assets separate from source edits when practical.

## Pull Requests

Summaries should state the changed surface, validation run, and any skipped
optional data inputs. Numerical changes should include the smallest smoke case
or regression test that exercises the changed behavior.
