# StenoticHemodynamics Source Agent Instructions

This file gives local guidance for importable Julia source under
`packages/stenotic-hemodynamics/src/StenoticHemodynamics/**`. It layers on top
of the root `AGENTS.md`, which remains the authority for repository-wide setup,
validation, artifact policy, commits, and pull requests. Keep this file focused:
it should help agents make source edits that fit the package architecture
without repeating the whole contributor guide.

## Scope

Treat this directory as the implementation body of the `StenoticHemodynamics`
Julia module. Package-root docs, tests, launcher scripts, report assets, Python
ops tooling, and publication workflows are outside this scoped guide unless a
task explicitly widens the lane. When the package tree is already dirty, assume
unrelated edits belong to another lane and leave them untouched.

## Layer Boundaries

- `core/` owns physical parameters, geometry, boundary descriptions, model
  closures, initial-condition descriptors, results, and diagnostics.
- `numerics/` owns spatial methods, state layout, fluxes, kernels, time
  stepping, backend dispatch, and solver contracts.
- `io/` owns CSV, JSON, manifest, checksum, overwrite, and table-writing helpers
  shared by workflows.
- `adapters/` owns optional external integrations and format translation.
- `workflows/` owns reproducible research workflows built from typed specs,
  results, runners, and writers.
- `cli/` owns command parsing and thin dispatch into package APIs.

## Source Change Rules

Prefer small, typed Julia changes that preserve the package's dispatch
protocols. Add behavior through focused specs, result types, validators, or
methods that match the owning layer. Keep optional dependencies isolated in
adapters or workflows, usually behind narrow `require_*` helpers. Keep CLI code
thin: parse inputs, construct typed package values, call source APIs, and report
outputs. Core and numerics should stay independent of command parsing, asset
publishing, report policy, and external data-format details.

## Validation

For source edits, run `pipenv run ops-julia-check` from the repository root.
For CLI or experiment-facing behavior, add a focused smoke check through
`pipenv run ops-experiment ...` when practical, with outputs written to ignored
scratch paths. Use broader Python, report, or release gates only when the change
crosses into those surfaces.

## Scratch Discipline

Write generated outputs to ignored scratch paths such as `tmp/**`,
`tmp/simulations/output/**`, or `public/var/logs/**`. Do not refresh
`public/final-report.pdf`, rendered figures, or tracked report assets from a
source-only package patch unless that artifact refresh is explicitly in scope.
