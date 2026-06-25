# Report Orchestration TODO

Date: 2026-06-24

This file is the live report-side coordination document for claim-boundary
cleanup. Treat the live checkout as authority.

## Current Status

- The P0/P1/P2 correction batch is closed in the live checkout. Future
  claim-affecting or numerical-output changes start again from `NO-SEND`.
- Report/package separation remains strict: report prose may describe package
  behavior, but package implementation evidence must land through the package
  tree and tests first.
- The outlet-gauge Step 5/6 handoff is complete in the dirty tree: Julia
  implementation/tests, accepted Canic-derived source-artifact assets, and
  source-only report integration have landed together. Do not refresh
  `public/final-report.pdf`,
  `report/assets/rendered/**`, raw resolved-3D inputs, public logs, public
  simulation data outside the accepted Canic asset refresh, or reference
  PDFs/HTML.

## Closed Report Corrections

The closed P0/P1/P2 batch established these report-side constraints:

1. Removed residual-budget equalities that implied uncomputed additive components.
2. Bounded pressure-comparison prose by the absence of a common pressure gauge.
3. Used source-artifact reconstruction/comparison language for Canic Section 4.1;
   default local solves must target the imported final time for each case, and
   explicit global `--tfinal` mismatches must be recorded as non-replication.
4. Matched operator-verification claims to the implemented independent synthetic
   geometry tests.
5. Stated the maximum section-area discrepancy and that no tolerance/sensitivity
   result proves it negligible.
6. Qualified MMS forcing checks as implementation verification: separately
   expanded formulas, shared manufactured states/parameters/utilities, not
   independent solver validation.
7. Used `classical-parabolic-1d` as the canonical label; retain
   `classical-1d-no-slip` only as historical asset provenance.
8. Removed volatile branch/commit/tag/hardware/review-state assertions from
   manuscript prose in favor of release-manifest wording.

Deferred report cleanup remains bounded to future source-only lanes:

1. Compress internal process language where it does not carry a scientific
   boundary.
2. Preserve the source-artifact comparison terminology for Canic Section 4.1.
3. Keep secondary DG p/h scratch exports out of the evidence path unless a
   separate derived-asset refresh lane reviews and republishes them.
4. Keep TeX hierarchy and display formatting conventional enough for the
   scratch report build to remain the governing source validation.

## Closed Step 5/6 Handoff

The closed Step 5/6 lane added the common Section 4.1 outlet-quadrature pressure
gauge for Canic/source-artifact diagnostics, regenerated only the accepted
Canic-derived CSV/TeX tables, and integrated the result into source-only report
prose. The report claim remains diagnostic: no FFR evidence, clinical
validation, broader native-FSI validation, or paper-grade pressure validation is
claimed from these assets.

## Package Coordination Boundary

Closed package tasks for the same batch are pressure semantics, Canic time
alignment, and pressure gauge policy. The report must not widen claims beyond
what package tests encode. Architecture cleanup is documentary unless a separate
dependency refactor lane is opened. Corrected numerical outputs beyond the
accepted Canic-derived source-artifact assets require a separate derived-asset
refresh lane. The closed Step 5/6 lane did not reopen a final-PDF sync or any
other generated-output promotion lane.

Deferred P2 package maintainability work remains limited to changes that
preserve public behavior: typed Canic workflow output rows and a narrow split
of native resolved-FSI production policy helpers out of the oversized
production workflow file. These changes must not widen native resolved-FSI
evidence claims.

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
- pressure observation differences use the common Section 4.1 outlet-quadrature
  gauge and remain diagnostic, not validation, FFR, or paper-grade reproduction
  evidence;
- schema-v3 split-run resume is qualified internal resume into a forked output
  root, not public/default resume and not a public native production CLI;
- monolithic ALE, clinical/patient validation, production-scale Section 4.1
  reproduction, and report-evidence promotion remain deferred.

## Closeout Validation Evidence

Recorded for this outlet-gauge implementation/assets/report handback:

```bash
git status --short --branch --untracked-files=all

git diff --check -- \
  report/TODO.md \
  packages/stenotic-hemodynamics/TODO.md \
  packages/stenotic-hemodynamics/README.md \
  packages/stenotic-hemodynamics/src/StenoticHemodynamics/workflows/canic_replication/canic_replication.jl \
  packages/stenotic-hemodynamics/src/StenoticHemodynamics/workflows/native_resolved_fsi/native_resolved_fsi_parity.jl \
  packages/stenotic-hemodynamics/test/test_canic_replication.jl \
  packages/stenotic-hemodynamics/test/test_native_resolved_fsi_parity.jl \
  report/sections/07-case-study/comparison.tex \
  report/sections/07-case-study/methodology.tex \
  report/appendices/code-and-ai-use.tex \
  report/assets/data/canic-replication \
  report/assets/tables/canic-replication \
  public/docs/artifact-policy.md \
  public/docs/julia-cli-workflows.md \
  public/docs/publication-readiness.md \
  public/docs/report-assets-and-provenance.md \
  public/docs/report-builds.md \
  public/docs/stenotic-hemodynamics/canic-2024-replication.md \
  public/docs/stenotic-hemodynamics/native-resolved-fsi-design.md \
  public/docs/stenotic-hemodynamics/native-resolved-fsi-section-4-1-reproduction.md \
  public/docs/stenotic-hemodynamics/section-4-1-production-validation-plan.md \
  public/docs/stenotic-hemodynamics/workflows.md \
  README.md \
  public/reproducibility/release-manifest.json

julia +release --project=packages/stenotic-hemodynamics \
  -e 'using Test, HDF5, StenoticHemodynamics; include("packages/stenotic-hemodynamics/test/test_helpers.jl"); include("packages/stenotic-hemodynamics/test/test_native_resolved_fsi_parity.jl"); include("packages/stenotic-hemodynamics/test/test_canic_replication.jl")'

julia +release --project=packages/stenotic-hemodynamics \
  packages/stenotic-hemodynamics/test/runtests.jl

julia +release --project=packages/stenotic-hemodynamics \
  packages/stenotic-hemodynamics/bin/stenotic-hemodynamics.jl canic-replication section41 \
  --data-root public/var/data/simulations/canic_case3 \
  --output-dir tmp/simulations/output/canic-replication/section41 \
  --coordinate-mode deformed \
  --nx 100 \
  --dt 1e-5 \
  --section-count 200 \
  --radial-sample-count 41 \
  --publish-report-assets \
  --report-assets-dir report/assets \
  --overwrite

pipenv run ops-orchestrate docs-contract
pipenv run ops-build-report --outdir /tmp/masters-report-build --no-sync-final-pdf
```

Observed closeout results:

- the direct Julia focused shard and full suite exit zero with
  `julia +release`;
- `pipenv run ops-julia-check` remains blocked before tests only because the
  local Julia selector wrapper cannot select Julia 1.12+;
- pressure-gauge tests prove uniform imported-pressure offset invariance;
- refreshed Canic source-artifact assets report finite outlet-gauged pressure
  diagnostics with `common_section41_outlet_pressure_gauge_operator_applied`;
- report source describes those pressure values as diagnostics only, not
  clinical validation, FFR evidence, paper-grade native FSI reproduction, or
  full Section 4.1 replication;
- release policy docs and the manifest agree on source-first PDF handling and
  any retained legacy tracked PDF provenance;
- no blocked artifacts change, including `public/final-report.pdf`.

If a future handoff reopens Julia code, report TeX, or generated assets, add the
surface-specific gates from `public/docs/artifact-policy.md` and start that lane
from `NO-SEND`.

## Future Artifact Lane

If corrected numerical outputs are needed, open a separate derived-asset refresh lane:
regenerate into ignored scratch first, review generated CSV/JSON/TeX for claim
boundaries, then publish only accepted derived artifacts. Refresh
`public/final-report.pdf` only in an explicitly scoped publication lane; this
P3/P4 documentation lane is not such a lane.
