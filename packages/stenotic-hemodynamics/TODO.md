# StenoticHemodynamics Package TODO

Date: 2026-06-24

This file is the live package coordination document for the current
claim-boundary cleanup. Treat the live checkout as authority.

## Current Status

- Status starts as `NO-SEND` until the P0/P1 corrections and validation commands
  below pass in the live checkout.
- Package/report separation remains strict. Package code and tests define the
  computational contract; report prose may only describe that contract.
- No artifact refresh is in scope for this batch. Do not modify
  `public/final-report.pdf`, `report/assets/rendered/**`, raw resolved-3D
  inputs, public logs, public simulation data, or reference PDFs/HTML.

## P0 Package Tasks

1. Pressure semantics:
   - `evolution_pressure` must expose the `K/R_max^2` evolution convention.
   - diagnostic/local pressure must be distinct and tested against the local
     `K/R0(z)^2` convention at `R0(z) != R_max`.
   - README/API language must state pressure conventions and gauge boundaries.
2. Canic Section 4.1 time alignment:
   - comparison rows must record imported/reference time, local target time,
     local completed time, tolerance, and alignment status;
   - default local solves must use the imported final time for each case,
     including severity 50 at imported `1.4995` s;
   - explicit global `--tfinal` mismatches, such as local `1.0` s versus
     imported `1.4995` s, must be recorded as intentional non-replication;
   - native parity planning for the same source-artifact comparison must wire
     severity 50 to imported case `50` rather than a placeholder skip;
   - reproduction/replication language is unavailable unless time, parameters,
     gauge, observation, and tolerances are recorded as satisfied.
3. Pressure gauge policy:
   - either implement and test a common gauge operator, including invariance to
     imported pressure offsets, or withhold pressure discrepancy as
     non-evidentiary.

## P1 Supporting Tasks

- Add independent synthetic operator geometry tests or keep operator claims
  narrowed to the actual test strength.
- Keep architecture cleanup documentary: Gridap, HDF5, OrdinaryDiffEq,
  SciMLBase, and YAML are hard dependencies today; layer marker types are
  descriptive only until a separate weak-dependency/extension refactor lands.
- Preserve public/default restart and resume boundaries; do not widen CLI
  support.
- Coordinate with report prose for residual-budget removal, operator-claim
  narrowing, area-tolerance limitation, MMS dependency qualification, label
  cleanup, and provenance cleanup.

Corrected numerical outputs, if needed, require a separate artifact-refresh
lane. This source-only batch must not regenerate or publish report assets.

## Validation

Required before a `SEND` handback:

```bash
git status --short --branch --untracked-files=all

git diff --check -- \
  report/TODO.md \
  report/frontmatter \
  report/sections \
  report/appendices \
  report/preamble \
  packages/stenotic-hemodynamics/TODO.md \
  packages/stenotic-hemodynamics/README.md \
  packages/stenotic-hemodynamics/Project.toml \
  packages/stenotic-hemodynamics/src \
  packages/stenotic-hemodynamics/test \
  packages/stenotic-hemodynamics/bin

packages/stenotic-hemodynamics/bin/julia-release \
  -e 'using Pkg; Pkg.test()'

pipenv run ops-julia-check
pipenv run ops-audit-report-prose --json
pipenv run ops-build-report --outdir /tmp/masters-report-build --no-sync-final-pdf
pipenv run ops-orchestrate ready-to-commit
```

Expected results:

- all commands exit zero;
- pressure API tests independently distinguish evolution and diagnostic formulas
  at `R0 != R_max`;
- Canic tests encode severity-50 default alignment to imported `1.4995` s and
  non-replication under explicit time mismatch;
- pressure discrepancy is gauge-normalized and invariant under offset, or
  explicitly withheld as evidence;
- operator geometry tests use independent closed-form synthetic references or
  claims remain narrowed;
- no blocked artifacts change.
