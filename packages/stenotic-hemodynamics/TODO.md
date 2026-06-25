# StenoticHemodynamics Package TODO

Date: 2026-06-24

This file is the live package coordination document for claim-boundary cleanup.
Treat the live checkout as authority.

## Current Status

- The P0/P1/P2 correction batch is closed in the live checkout. Future
  claim-affecting or numerical-output changes start again from `NO-SEND`.
- Package/report separation remains strict. Package code and tests define the
  computational contract; report prose may only describe that contract.
- The outlet-gauge Step 5/6 handoff is complete in the dirty tree: Julia
  implementation/tests, accepted Canic-derived source-artifact assets, and
  source-only report integration have landed together. Do not refresh
  `public/final-report.pdf`,
  `report/assets/rendered/**`, raw resolved-3D inputs, public logs, public
  simulation data outside the accepted Canic asset refresh, or reference
  PDFs/HTML.

## Closed Package Corrections

The closed P0/P1/P2 batch established these package-side constraints:

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
   - implement and test the common Section 4.1 outlet-quadrature gauge,
     including invariance to imported pressure offsets, while keeping pressure
     discrepancies diagnostic rather than validation evidence.

## Supporting Boundaries

- Independent synthetic operator geometry tests support the current operator
  claims; otherwise, claims must remain
  narrowed to the actual test strength.
- Architecture cleanup remains documentary: Gridap, HDF5, OrdinaryDiffEq,
  SciMLBase, and YAML are hard dependencies today; layer marker types are
  descriptive only until a separate weak-dependency/extension refactor lands.
- Public/default restart and resume boundaries remain preserved; qualified internal
  split-run resume remains an operator-readiness surface, not public resume or
  CLI support.
- Report prose must stay coordinated with residual-budget removal,
  operator-claim narrowing, area-tolerance limitation, MMS dependency
  qualification, label cleanup, and provenance cleanup.

Corrected numerical outputs beyond the accepted Canic-derived source-artifact
assets require a separate derived-asset refresh lane. Future package-only
batches must not regenerate or publish report data assets, and the closed Step
5/6 lane did not reopen the report-owned `public/final-report.pdf` sync lane.

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
- Pressure observation rows use the common Section 4.1 outlet-quadrature gauge
  for diagnostic pressure differences; they remain local artifact/operator rows,
  not validation, FFR, or paper-grade reproduction evidence.
- Qualified internal split-run resume may continue a schema-v3 checkpoint into
  a forked output root. Public/default resume, public native production CLI,
  and production-scale resume validation remain deferred.

Expected adjacent-agent handoff:

- Agent A keeps the exact boundary mode explicit and leaves weak smoke as the
  default.
- Agent B keeps parity/observation rows bounded to local optional-data
  operator checks, with outlet-gauged pressure differences treated as
  diagnostics only.
- Agent C keeps internal split-run resume separate from public/default resume
  and from report-evidence promotion.

## Deferred Maintainability Tasks

- Keep Canic source-artifact comparison outputs typed at the workflow boundary
  so column order and row shape are testable without relying on `Any[]`
  accumulators.
- Split native resolved-FSI production policy helpers out of the oversized
  production workflow implementation without changing public APIs or claim
  strings.
- Leave broader native-FSI refactors, dependency changes, and numerical output
  refreshes to separate lanes.

## Closed Step 5/6 Handoff

The closed Step 5/6 lane implemented the common Section 4.1 outlet-quadrature
pressure gauge for Canic/source-artifact diagnostics, proved uniform
pressure-offset invariance in package tests, regenerated only the accepted
Canic-derived CSV/TeX report tables, and handed those diagnostic assets to the
source-only report lane. The package contract remains bounded: outlet-gauged
pressure differences are diagnostics only, not FFR evidence, clinical
validation, broader native-FSI validation, or paper-grade pressure validation.

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
