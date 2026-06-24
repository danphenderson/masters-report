# Report Orchestration TODO

Date: 2026-06-24

This file is the live report-side coordination document for the current
claim-boundary cleanup. Treat the live checkout as authority.

## Current Status

- Status starts as `NO-SEND` until the P0/P1 corrections and validation commands
  below pass in the live checkout.
- Report/package separation remains strict: report prose may describe package
  behavior, but package implementation evidence must land through the package
  tree and tests first.
- No artifact refresh is in scope for this batch. Do not modify
  `public/final-report.pdf`, `report/assets/rendered/**`, raw resolved-3D
  inputs, public logs, public simulation data, or reference PDFs/HTML.

## Active Report Tasks

P1 report cleanup for this batch:

1. Remove residual-budget equalities that imply uncomputed additive components.
2. Bound all pressure-comparison prose by the absence of a common pressure gauge.
3. Use source-artifact reconstruction/comparison language for Canic Section 4.1;
   default local solves must target the imported final time for each case, and
   explicit global `--tfinal` mismatches must be recorded as non-replication.
4. Match operator-verification claims to the implemented independent synthetic
   geometry tests.
5. State the maximum section-area discrepancy and that no tolerance/sensitivity
   result proves it negligible.
6. Qualify MMS forcing checks as implementation verification: separately
   expanded formulas, shared manufactured states/parameters/utilities, not
   independent solver validation.
7. Use `classical-parabolic-1d` as the canonical label; retain
   `classical-1d-no-slip` only as historical asset provenance.
8. Remove volatile branch/commit/tag/hardware/review-state assertions from
   manuscript prose in favor of release-manifest wording.

## Package Coordination Boundary

P0 package tasks for the same batch are pressure semantics, Canic time alignment,
and pressure gauge policy. The report must not widen claims beyond what package
tests encode. Architecture cleanup is documentary unless a separate dependency
refactor lane is opened. Corrected numerical outputs, if needed, require a
separate artifact-refresh lane after this source-only batch.

Native resolved-FSI production execution, imported parity for the native Gridap
path, public/default restart or resume support, viewer controls, timing
sidecars, dry-run status rows, and checkpoint metadata remain outside manuscript
evidence unless a future report-evidence lane explicitly accepts them.

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
- severity 50 is solved to the imported `1.4995` s final time by default;
- explicit local `1.0` s overrides against imported `1.4995` s are recorded as
  intentional time mismatches and non-replication;
- pressure discrepancy is gauge-normalized and tested, or withheld as
  non-evidentiary;
- evolution and diagnostic pressure tests use independent formulas at
  `R0 != R_max`;
- operator geometry tests do not compare production routines only to themselves;
- no blocked artifacts change.

## Future Artifact Lane

If corrected numerical outputs are needed, open a separate artifact-refresh lane:
regenerate into ignored scratch first, review generated CSV/JSON/TeX for claim
boundaries, then publish only accepted derived artifacts. Refresh
`public/final-report.pdf` only in an explicitly scoped publication lane.
