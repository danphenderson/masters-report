# StenoticHemodynamics Source Agent Instructions

This file governs importable Julia source under
`packages/stenotic-hemodynamics/src/StenoticHemodynamics/**`. It supplements the
root `AGENTS.md`; package-root docs, tests, launcher scripts, report assets,
Python ops tooling, commits, and pull requests remain governed by the root
guide unless a narrower instruction file applies.

## Scope

Treat this tree as package source for the `StenoticHemodynamics` Julia module.
Keep edits local to the source layer being changed, and avoid normalizing
unrelated files in the currently dirty package tree. Do not use this scoped
guide as permission to refresh generated report artifacts or rewrite package
documentation outside `src/StenoticHemodynamics/**`.

## Layer Boundaries

- `core/` owns physical parameters, geometry, boundary descriptions, model
  closures, initial-condition descriptors, results, and diagnostics.
- `numerics/` owns spatial methods, state layout, fluxes, kernels, time
  stepping, backend dispatch, and solver contracts.
- `io/` owns CSV, JSON, manifest, checksum, overwrite, and table-writing
  helpers shared by workflows.
- `adapters/` owns optional external integrations and format translation.
- `workflows/` owns reproducible research workflows built from typed specs,
  results, runners, and writers.
- `cli/` owns command parsing and thin dispatch into package APIs.

## Source Change Rules

Preserve typed Julia protocols and multiple-dispatch boundaries. Add new
behavior through small specs, result types, validators, or methods that match
the existing layer contract. Keep optional dependencies isolated in adapters or
workflow code, preferably behind narrow `require_*` helpers. Keep CLI files
thin: parse flags, construct typed package inputs, call source APIs, and print
locations or summaries. Do not put report publication policy, destructive
cleanup, file-format escaping, or solver logic in the CLI layer. Do not put
workflow orchestration, asset publishing, CLI parsing, or optional dependency
loading in `core/` or `numerics/`.

## Validation

For source edits, run `pipenv run ops-julia-check` from the repository root.
For CLI or experiment-facing behavior, add a focused smoke check through
`pipenv run ops-experiment ...` when practical and write outputs to ignored
scratch paths. Run broader `ops-release-check`, Python, or report gates only
when the change crosses into those surfaces.

## Scratch Discipline

Write generated outputs to ignored scratch paths such as `tmp/**`,
`tmp/simulations/output/**`, or `public/var/logs/**`. Do not refresh
`public/final-report.pdf`, rendered figures, or tracked report assets from a
source-only package patch unless that artifact refresh is explicitly in scope.
