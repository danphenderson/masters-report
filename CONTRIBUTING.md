# Contributing

This project is a research codebase and report source tree. Keep changes small,
reviewable, and tied to a reproducible validation path.

## Development

- Use `pipenv run ops-julia-check` for Julia package validation.
- Use `pipenv run ops-python-check` for Python support-tooling changes.
- Install the explicit local pre-commit hook with
  `pipenv run pre-commit install --install-hooks` when fast commit-time hygiene
  checks should run automatically.
- Use `pipenv run pre-commit run --all-files` to run the fast hook stack
  manually.
- Use `pipenv run ops-orchestrate ready-to-commit` immediately before staging
  or committing a managed lane. It selects focused validation from the dirty
  surfaces and keeps official validation in the orchestrator/commit-wrapper
  path.
- Use `pipenv run ops-experiment ...` for foreground simulation, study,
  verification, comparison, and benchmark runs that need terminal streaming and
  JSON logs.
- Use a scratch LaTeX output directory for report builds:

  ```sh
  pipenv run ops-build-report --outdir /tmp/masters-report-build --no-sync-final-pdf
  ```

- Use the full report build without `--no-sync-final-pdf` only when a release PDF
  refresh is explicitly in scope.
- Use `pipenv run ops-release-check --mode patch` for dirty-tree aggregate
  validation before major handbacks, pushes, or release-readiness decisions.
  Use `--mode release` only for clean publication readiness.

## Artifact Discipline

- Do not commit local caches, virtual environments, root LaTeX byproducts,
  simulation outputs, raw resolved-3D inputs, or private review notes.
- Do not commit third-party full-text PDFs or HTML mirrors under `public/references/`.
  Keep `public/references/references.bib` and `public/references/source-inventory.tsv` synchronized
  instead.
- Keep generated report assets separate from source edits when practical.
- Use `public/docs/report-assets-and-provenance.md` before refreshing tracked
  report assets.

## Pull Requests

Summaries should state the changed surface, validation run, and any skipped
optional data inputs. Numerical changes should include the smallest smoke case
or regression test that exercises the changed behavior.

See `public/docs/index.md` for the full documentation map.
