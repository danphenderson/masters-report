# Report Orchestration TODO

Date: 2026-06-24

This file is the live report-side coordination document. Keep it short:
current state, claim boundary, active work, and future gates only.

## Current State

- The only open report-side coordination item in this file is TODO upkeep; no
  new report source task is open here.
- Report/package separation remains strict. Report prose may describe package
  behavior, but package evidence must land through package code, tests, and
  accepted generated assets first.
- Do not refresh `public/final-report.pdf`, `report/assets/rendered/**`, raw
  resolved-3D inputs, public logs, public simulation data outside accepted
  Canic asset refreshes, or reference PDFs/HTML unless a future lane explicitly
  scopes that work.

## Claim Boundary

- Canic pressure values are outlet-gauged source-artifact diagnostics only.
- Do not present those pressure diagnostics as FFR evidence, clinical
  validation, broader native-FSI validation, full Section 4.1 replication, or
  paper-grade pressure validation.
- Native resolved-FSI observation and production rows remain local
  operator/artifact checks unless a future report-evidence lane accepts them.
- Corrected numerical outputs beyond the accepted Canic-derived assets require
  a separate derived-asset refresh lane.

## Active Work

- Future source-only cleanup may compress process language or clarify the
  source-artifact comparison wording, but claim-affecting edits must start from
  `NO-SEND`.

## Future Gates

- TODO/docs-only edits:
  `git diff --check -- report/TODO.md packages/stenotic-hemodynamics/TODO.md`
  and `pipenv run ops-orchestrate docs-contract`.
- Report source edits:
  `pipenv run ops-build-report --outdir /tmp/masters-report-build --no-sync-final-pdf`.
- Mixed Julia/assets/report lanes: run the package suite through the available
  Julia 1.12+ launcher, rerun affected asset generation into ignored scratch
  before publishing accepted assets, then run docs-contract and source-only
  report validation.
- Synced `public/final-report.pdf` refresh requires an explicitly scoped
  publication lane.
