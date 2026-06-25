# StenoticHemodynamics Next-Round Revision Plan

Date: 2026-06-24
Audit status: **NO-SEND**
Surface owner: Julia package
Profile: numerical contract, claim boundary, architecture, and AI-slop removal

## Audit Basis and Scope

- The reviewed tracked-only archive has SHA-256
  `27f1ff7c9dceda468604ad4d4b1d946597f73c6bdef8c13de419403e79bfc167`.
- The dispatch packet reports `main...origin/main [ahead 6]`. The archive omits
  `.git`, so branch cleanliness, the current commit, and the previous TODO
  assertions about `20f487a` and passed readiness gates are not independently
  verifiable in this audit environment.
- Julia and Pipenv were unavailable in the audit environment. The findings
  below are based on tracked source, tests, generated text/CSV assets, and
  static local checks; they are not a claim that the Julia test suite passes.
- This package lane must not edit manuscript source, regenerate report assets,
  update `public/final-report.pdf`, or launch the long-running preproduction
  batch.

## Decision Boundary

The package is not ready for a report handoff while any P0 item is open. In
particular, internal workflow completion is not physical validation and is not
successful replication without a declared target, tolerance, time alignment,
and pressure-gauge convention.

## Merged Execution Order

1. Implement and test `J-P0-1` pressure semantics.
2. Implement `J-P0-2` time alignment and `J-P0-3` comparison/gauge criteria.
3. Run the full package check and inspect changed output schemas.
4. Hand the accepted API and evidence contract to the report owner for
   `R-P0-1` through `R-P0-3`.
5. Complete P1/P2 architecture and maintainability tasks.
6. Reopen the existing severity-23 preproduction lane only after all P0 gates
   and the official package validation pass.

## P0 — Must Fix Before Report or Advisor Handoff

### [ ] J-P0-1 Repair the evolution/diagnostic pressure API contract

**Evidence locations:**

- `src/StenoticHemodynamics/numerics/model.jl`;
- `src/StenoticHemodynamics/core/geometry.jl`;
- `test/test_core_model.jl` and `test/test_public_api.jl`;
- `README.md`;
- `src/StenoticHemodynamics/io/outputs.jl` and study/benchmark summaries.

**Required implementation:**

- Introduce an explicit evolution wall-pressure helper using
  \(K/R_{\max}^{2}\), consistent with the elastic potential, wave speed, and
  geometry source.
- Keep the local-radius \(K/R_0(z)^2\) wall pressure under an explicitly
  diagnostic name.
- Make `evolution_pressure(...)` call only the evolution helper.
- Make `diagnostic_pressure(...)` start from the local-radius diagnostic and
  then add the variable-radius `p2` correction when enabled. It must not inherit
  its base value from `evolution_pressure(...)`.
- Keep deprecated `pressure(...)` behavior explicit; if it remains an alias for
  `diagnostic_pressure(...)`, document and test that compatibility contract.
- Rename generic output columns/summary fields or add a schema-level
  `pressure_convention` field so stored values cannot be mistaken for evolution
  pressure.

**Required tests:**

- Select a stenotic location where `R0(z) != Rmax` and assert the two pressures
  against independent closed-form expressions.
- Test zero and nonzero flow, with variable-radius corrections both enabled and
  disabled.
- Assert that evolution pressure, elastic potential, wave speed, and geometry
  source use the same `Rmax` normalization.
- Assert that diagnostic output metadata identifies the local-radius-plus-`p2`
  convention.
- Retain a regression test for the deprecated `pressure(...)` alias.

**Acceptance criteria:**

- Public API, implementation, tests, README, output metadata, and report handoff
  use one consistent definition for each pressure quantity.
- No test defines correctness by comparing `evolution_pressure` only to the
  same mislabeled helper.
- Package tests pass before any report wording or assets are updated.

### [ ] J-P0-2 Enforce case-specific comparison-time alignment

**Evidence location:**
`src/StenoticHemodynamics/workflows/canic_replication/canic_replication.jl`.

**Required implementation:**

- Derive each local 1D final time from the accepted comparison target for that
  case, or require an explicit per-case map. A single global `tfinal_s` must not
  silently compare severity 50 at `1.0 s` against an imported snapshot near
  `1.4995 s`.
- Record `time_1d_s`, `time_3d_s`, and `abs_time_offset_s` in comparison and
  summary outputs.
- Apply a declared comparison-time tolerance. Fail closed or mark the case
  `skipped_time_mismatch` when the tolerance is exceeded.
- Validate velocity, pressure, and displacement metadata against the same case
  time before computing discrepancies.

**Required tests:**

- A severity-50 fixture with imported time `1.4995 s` and local time `1.0 s`
  must not return status `ok` or a paper-model summary.
- Aligned cases must record both times and a passing offset.
- A deliberate per-case override must be visible in provenance and output
  schema.

**Acceptance criteria:** no discrepancy row is emitted as admissible comparison
or replication evidence unless the compared times pass the declared tolerance.

### [ ] J-P0-3 Define comparison success, pressure gauge, and workflow naming

**Evidence locations:**

- `src/StenoticHemodynamics/workflows/canic_replication/**`;
- `src/StenoticHemodynamics/workflows/native_resolved_fsi/native_resolved_fsi_parity.jl`;
- `src/StenoticHemodynamics/adapters/resolved3d_io.jl`;
- `test/test_canic_replication.jl`.

**Required implementation:**

- Rename the workflow and provenance status to
  `source-artifact-comparison`/`reconstruction` unless a true replication
  criterion is implemented and passed.
- Replace unconditional result status `ok` with statuses derived from explicit
  gates: input completeness, metadata consistency, time alignment, finite
  observations, gauge compatibility, and predeclared numerical tolerances.
- Define a common pressure-gauge operator for imported 3D and 1D pressure, such
  as subtraction of a declared outlet-section mean. Record the operator and
  reference location in output metadata.
- Demonstrate gauge invariance in tests by adding a constant to imported
  pressure and obtaining unchanged pressure discrepancies after normalization.
- If no defensible common gauge is selected, do not compute or publish pressure
  error; emit a bounded `not_comparable_gauge_undefined` status instead.
- Treat the PDF/upstream Young-modulus mismatch as distinct configurations. Do
  not label a run with non-identical constitutive data as reproduction of the
  same numerical experiment without a sensitivity or dual-configuration audit.
- Define acceptance criteria for any retained replication claim. File creation
  and finite discrepancies are necessary but not sufficient.

**Required tests:**

- Workflow success must fail when any gate fails.
- Pressure discrepancy must be invariant to an imported constant pressure
  offset after gauge normalization.
- Existing synthetic file-generation tests must assert semantic statuses and
  tolerances, not only file existence and strings.

**Acceptance criteria:** every summary status has a machine-checkable meaning,
and no “paper model” or “replication” role is assigned solely because a model
name was selected and output files were written.

## P1 — Numerical Verification and Architecture Hardening

### [ ] J-P1-1 Add an independent observation-operator geometry reference

**Evidence locations:**

- `src/StenoticHemodynamics/workflows/operator_validation/operator_validation_metrics.jl`;
- `src/StenoticHemodynamics/workflows/operator_validation/operator_validation_synthetic.jl`;
- `test/test_operator_validation.jl`.

The current reference reuses `tetra_plane_polygon`, `polygon_center`, and
`triangle_area_xy`, so it independently checks affine triangle averaging but
not the cut geometry.

**Required work:**

- Add closed-form area, centroid, flow, and mean-velocity references for all
  sampled planes in the reference tetrahedron without calling the production
  polygonization path.
- Add at least one multi-tetrahedron mesh with shared-face and near-vertex/edge
  cuts to test duplicate handling and topology aggregation.
- Separate statuses for intersection geometry, area integration, and field
  quadrature.

**Acceptance criterion:** deliberately perturbing the production
intersection/polygonization path causes the independent geometry test to fail.

### [ ] J-P1-2 Make the dependency/architecture documentation truthful

**Evidence locations:**

- `Project.toml`;
- `src/StenoticHemodynamics.jl`;
- `src/StenoticHemodynamics/layers.jl`;
- `src/StenoticHemodynamics/adapters/stokes_ic.jl` and
  `adapters/native_resolved_fsi.jl`;
- `README.md`.

Gridap, HDF5, OrdinaryDiffEq, SciMLBase, and YAML are current hard dependencies,
and adapter/workflow files are included unconditionally. Therefore “optional
external ecosystem support” describes source organization, not package-load
optionality.

**Required work:**

- Immediate: revise module and layer documentation to state the current hard
  dependency/load contract.
- Later, only if needed: move integrations to Julia extensions/weak dependencies
  and test both minimal and extended load paths.
- Do not retain empty architecture marker types as evidence of enforced
  boundaries. Either use enforceable module/dependency checks or reduce the
  file to concise documentation.

**Acceptance criterion:** documentation and `Project.toml` describe the same
load-time dependency model.

### [ ] J-P1-3 Bound the MMS “independence” claim in code-facing documentation

The forcing audit expands formulas separately from production `flux` and
`source_point` calls but shares manufactured states, geometry, constitutive
parameters, and lower-level utilities.

- Document those shared primitives.
- Add mutation/perturbation tests where practical to show which production
  defects the audit can and cannot detect.
- Hand back exact wording to the report owner; avoid “independent enough.”

### [ ] J-P1-4 Canonicalize model labels in new outputs

- Emit `classical-parabolic-1d` in all newly generated rows and manifests.
- Accept `classical-1d-no-slip` only as a deprecated input alias or historical
  tracked-asset token.
- Add explicit schema/provenance handling so old and new rows are not silently
  mixed.

## P2 — Maintainability and AI-Slop Removal

### [ ] J-P2-1 Replace untyped computation rows at workflow boundaries

Use typed result rows for Canic comparison, parameter audit, native parity,
restart metadata construction, and other numerical computation stages. Convert
to `Dict{String,Any}` or heterogeneous rows only at serialization boundaries.
Do not perform broad type churn before the P0 semantics are fixed.

### [ ] J-P2-2 Split oversized native-FSI implementation files by responsibility

After correctness gates pass, separate production planning, stepping,
diagnostics, serialization, and restart logic. Preserve public API and file
schemas. Require focused tests for each extracted unit before accepting the
refactor.

### [ ] J-P2-3 Remove operationally persuasive but non-semantic status prose

Replace long status strings and labels such as “promoted,” “paper-grade,” or
“ready” with enumerated statuses tied to explicit predicates. Human-readable
messages may explain a status but must not substitute for a gate.

## Existing Long-Running Lane

### [ ] Lane 10C — Severity-23 preproduction batch execution

**Status: BLOCKED by `J-P0-1` through `J-P0-3` and package validation.**

Do not launch the long-running preproduction batch from this revision round.
Reopen it only after:

- pressure semantics and output metadata are accepted;
- Canic time/gauge/success gates pass;
- `pipenv run ops-julia-check` exits zero;
- the live checkout is re-anchored;
- the package/report handoff explicitly confirms that the run will not be used
  as physical or clinical validation.

When reopened, keep raw outputs under ignored scratch paths and preserve the
existing report-ownership boundary.

## Package Acceptance Criteria

The package lane is complete only when all of the following are true:

- P0 tests fail against the audited implementation and pass after the fixes.
- Evolution and diagnostic pressure conventions are distinct in API, tests,
  outputs, and documentation.
- No Canic comparison row passes with unmatched times or undefined gauge.
- Replication/reproduction status is based on declared numerical criteria.
- The complete Julia test/check surface passes in the live environment.
- No report source, tracked PDF, rendered asset, generated report table, or raw
  simulation input is changed in this package lane.

## Validation and Expected Results

Run from the live repository root:

```bash
git status --short --branch --untracked-files=all
git diff --check -- \
  packages/stenotic-hemodynamics/TODO.md \
  packages/stenotic-hemodynamics/README.md \
  packages/stenotic-hemodynamics/Project.toml \
  packages/stenotic-hemodynamics/src \
  packages/stenotic-hemodynamics/test \
  packages/stenotic-hemodynamics/bin
packages/stenotic-hemodynamics/bin/julia-release \
  -e 'using Pkg; Pkg.test()'
pipenv run ops-julia-check
pipenv run ops-orchestrate ready-to-commit
```

Required focused assertions within the test suite:

```text
R0(z) != Rmax:
  evolution_pressure == K/Rmax^2 * (sqrt(A) - R0)
  diagnostic_pressure == K/R0^2 * (sqrt(A) - R0) + p2
severity 50, time_1d=1.0, time_3d=1.4995:
  status != ok
  no admissible replication summary row
imported pressure p and p + C after common-gauge normalization:
  identical pressure-discrepancy metrics
independent analytic tetrahedron reference:
  area, centroid, flow, and mean pass without production polygonization reuse
```

Expected results:

- `git diff --check` exits `0`.
- Direct `Pkg.test()`, `ops-julia-check`, and the official orchestrator gate
  exit `0`.
- Tests exercise semantic failure modes, not only output creation.
- `git diff -- report/frontmatter report/sections report/appendices report/preamble report/assets public/final-report.pdf` is empty.

**Orchestrator validation scope:**

```bash
pipenv run ops-julia-check
```

## Risks to Carry Forward

- Correcting pressure semantics may change diagnostic/evolution outputs,
  benchmark summaries, and report tables; do not hide that change behind a
  compatibility alias.
- Existing generated Canic assets are not trustworthy replication evidence
  after the time/gauge findings; regeneration belongs to a later reviewed
  artifact lane.
- The Young-modulus mismatch prevents a simple same-configuration replication
  claim unless both configurations are explicitly analyzed.
- Hard-dependency restructuring can destabilize load order and extension tests;
  keep it behind the P0 correctness work.
- The native-FSI surface is large and weakly modularized. Broad refactoring
  before semantic fixes would increase regression risk.
