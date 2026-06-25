# Report Orchestration TODO

Date: 2026-06-24

This file is the live report-side coordination document for the current
claim-boundary cleanup. Treat the live checkout as authority.

## Current Status

- The P0/P1/P2 correction batch is validation-complete for `SEND` in the live
  checkout. Future claim-affecting or numerical-output changes start again from
  `NO-SEND`.
- Report/package separation remains strict: report prose may describe package
  behavior, but package implementation evidence must land through the package
  tree and tests first.
- This P3/P4 native resolved-FSI documentation lane is source-docs only. Do
  not refresh `public/final-report.pdf`, `report/assets/rendered/**`, raw
  resolved-3D inputs, public logs, public simulation data, generated outputs,
  or reference PDFs/HTML.

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

P2 report cleanup for this batch:

1. Compress internal process language where it does not carry a scientific
   boundary.
2. Preserve the source-artifact comparison terminology for Canic Section 4.1.
3. Keep secondary DG p/h scratch exports out of the evidence path unless a
   separate derived-asset refresh lane reviews and republishes them.
4. Keep TeX hierarchy and display formatting conventional enough for the
   scratch report build to remain the governing source validation.

## Package Coordination Boundary

P0 package tasks for the same batch are pressure semantics, Canic time alignment,
and pressure gauge policy. The report must not widen claims beyond what package
tests encode. Architecture cleanup is documentary unless a separate dependency
refactor lane is opened. Corrected numerical outputs, if needed, require a
separate derived-asset refresh lane. This P3/P4 documentation batch does not
reopen a final-PDF sync or any generated-output promotion lane.

P2 package tasks are limited to maintainability changes that preserve public
behavior: typed Canic workflow output rows and a narrow split of native
resolved-FSI production policy helpers out of the oversized production workflow
file. These changes must not widen native resolved-FSI evidence claims.

Native resolved-FSI production execution, imported parity for the native Gridap
path, public/default restart or resume support, viewer controls, timing
sidecars, dry-run status rows, and checkpoint metadata remain outside manuscript
evidence unless a future report-evidence lane explicitly accepts them.

P3/P4 native resolved-FSI wording must stay bounded as follows:

- exact Section 4.1 boundary mode is a qualified internal smoke/operator
  readiness status, while pressure-drop weak loading remains the default smoke
  evidence path;
- parity and observation rows are local optional-data operator rows, not
  paper-grade Section 4.1 reproduction rows;
- pressure observation differences are non-evidentiary until a common pressure
  gauge operator is implemented, offset-tested, and accepted for the report
  comparison contract;
- schema-v3 split-run resume is qualified internal resume into a forked output
  root, not public/default resume and not a public native production CLI;
- monolithic ALE, clinical/patient validation, production-scale Section 4.1
  reproduction, and report-evidence promotion remain deferred.

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
- severity 50 is solved to the imported `1.4995` s final time by default;
- explicit local `1.0` s overrides against imported `1.4995` s are recorded as
  intentional time mismatches and non-replication;
- pressure discrepancy is gauge-normalized and tested, or withheld as
  non-evidentiary;
- evolution and diagnostic pressure tests use independent formulas at
  `R0 != R_max`;
- operator geometry tests do not compare production routines only to themselves;
- no blocked artifacts change except the explicitly synced
  `public/final-report.pdf`.
- pre-existing protected-artifact or scratch dirt is documented and left
  unstaged when it is unrelated to the source-only batch.

## Future Artifact Lane

If corrected numerical outputs are needed, open a separate derived-asset refresh lane:
regenerate into ignored scratch first, review generated CSV/JSON/TeX for claim
boundaries, then publish only accepted derived artifacts. Refresh
`public/final-report.pdf` only in an explicitly scoped publication lane; this
P3/P4 documentation lane is not such a lane.
