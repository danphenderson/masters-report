# StenoticHemodynamics Package TODO

Date: 2026-06-24

This file is the live package coordination document. Keep it short: current
state, claim boundary, active work, and future gates only.

## Current State

- No package task is currently open in this TODO. No numerical-output refresh or
  report-evidence promotion is open here.
- Package/report separation remains strict. Package code and tests define the
  computational contract; report prose may only describe that contract.
- Do not refresh `public/final-report.pdf`, `report/assets/rendered/**`, raw
  resolved-3D inputs, public logs, public simulation data outside accepted
  Canic asset refreshes, or reference PDFs/HTML unless a future lane explicitly
  scopes that work.

## Claim Boundary

- Canic pressure values are outlet-gauged source-artifact diagnostics only.
- Do not present those pressure diagnostics as FFR evidence, clinical
  validation, broader native-FSI validation, full Section 4.1 replication, or
  paper-grade pressure validation.
- Canic comparisons must keep imported-time targeting explicit, including
  severity 50 at imported `1.4995` s; explicit global `--tfinal` mismatches
  remain intentional non-replication rows.
- Native resolved-FSI P3/P4 rows remain smoke/operator-readiness or local
  artifact checks, not report evidence or production-scale Section 4.1
  reproduction.

## Active Work

- Broader native-FSI refactors, dependency changes, new numerical output
  refreshes, and report-evidence promotion require separate lanes.

## Future Gates

- TODO/docs-only edits:
  `git diff --check -- report/TODO.md packages/stenotic-hemodynamics/TODO.md`
  and `pipenv run ops-orchestrate docs-contract`.
- Package code edits: run the affected focused tests and the package suite
  through the available Julia 1.12+ launcher. If the local `ops-julia-check`
  selector wrapper is fixed, use it as the agent-facing package gate.
- Canic asset refreshes: regenerate into ignored scratch first, publish only
  accepted derived CSV/JSON/TeX assets, then run docs-contract and source-only
  report validation.
- Synced `public/final-report.pdf` refresh requires an explicitly scoped
  publication lane.
