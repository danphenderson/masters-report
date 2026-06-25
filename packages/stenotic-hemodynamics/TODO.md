# StenoticHemodynamics Package TODO

Date: 2026-06-24

This file is the live package coordination document for the current
claim-boundary cleanup. Treat the live checkout as authority.

## Current Status

- The P0/P1/P2 correction batch is validation-complete for `SEND` in the live
  checkout. Future claim-affecting or numerical-output changes start again from
  `NO-SEND`.
- Package/report separation remains strict. Package code and tests define the
  computational contract; report prose may only describe that contract.
- This P3/P4 native resolved-FSI documentation lane is source-docs only. Do
  not refresh `public/final-report.pdf`, `report/assets/rendered/**`, raw
  resolved-3D inputs, public logs, public simulation data, generated outputs,
  or reference PDFs/HTML.

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
- Preserve public/default restart and resume boundaries; qualified internal
  split-run resume remains an operator-readiness surface, not public resume or
  CLI support.
- Coordinate with report prose for residual-budget removal, operator-claim
  narrowing, area-tolerance limitation, MMS dependency qualification, label
  cleanup, and provenance cleanup.

Corrected numerical outputs, if needed, require a separate derived-asset refresh
lane. This package batch must not regenerate or publish report data assets, and
it does not reopen the report-owned `public/final-report.pdf` sync lane.

## P3/P4 Native Resolved-FSI Documentation Boundary

P3/P4 native resolved-FSI work is internal smoke/operator-readiness only:

- P3 exact-boundary readiness may document the internal
  `poiseuille_inlet_zero_outlet_stress_section41` mode, but the weak
  pressure-drop smoke path remains the default evidence path. Exact-mode rows
  must say they are smoke-scale/operator-readiness evidence, not validated
  Section 4.1 boundary reproduction.
- P4 sidecar, observation, and resume readiness may document production
  dry-run plans, state-carrying sidecars, bounded native/imported observation
  rows, and schema-v3 checkpoints. These rows are local artifact/operator
  checks only, not production-scale Section 4.1 reproduction or report
  evidence.
- Pressure observation rows remain non-evidentiary for pressure discrepancy
  claims until a common gauge operator is implemented, tested for imported
  pressure offsets, and selected for the Section 4.1 comparison contract.
- Qualified internal split-run resume may continue a schema-v3 checkpoint into
  a forked output root. Public/default resume, public native production CLI,
  and production-scale resume validation remain deferred.

Expected adjacent-agent handoff:

- Agent A keeps the exact boundary mode explicit and leaves weak smoke as the
  default.
- Agent B keeps parity/observation rows bounded to local optional-data
  operator checks, with pressure non-evidentiary unless the gauge is resolved.
- Agent C keeps internal split-run resume separate from public/default resume
  and from report-evidence promotion.

## P2 Maintainability Tasks

- Keep Canic source-artifact comparison outputs typed at the workflow boundary
  so column order and row shape are testable without relying on `Any[]`
  accumulators.
- Split native resolved-FSI production policy helpers out of the oversized
  production workflow implementation without changing public APIs or claim
  strings.
- Leave broader native-FSI refactors, dependency changes, and numerical output
  refreshes to separate lanes.

## Validation

Required before a future `SEND` handback:

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

# If the live checkout contains pre-existing protected-artifact or scratch
# dirt outside this source batch, the orchestrator may additionally run the
# focused gate with explicit allowances after confirming the protected-artifact
# diff is not part of the staged source change:
pipenv run ops-orchestrate ready-to-commit --allow-protected-artifacts --allow-unclassified
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
- no blocked artifacts change except the explicitly synced
  `public/final-report.pdf`.
- pre-existing protected-artifact or scratch dirt is documented and left
  unstaged when it is unrelated to the source-only batch.
