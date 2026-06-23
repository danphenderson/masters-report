# StenoticHemodynamics Authoritative Fleet TODO

Date: 2026-06-23

This is the current master implementation plan for
`packages/stenotic-hemodynamics`. It supersedes earlier next-round sketches and
incorporates the fleet poll after the corrected editorial coordination note.

## Current Baseline

Implemented and committed:

- `696a3d9 Carry native resolved FSI production state`
  - Native production advances one state-carrying partitioned snapshot series
    within a run.
  - Output bundles remain importer-compatible
    velocity/pressure/displacement XDMF/HDF5 bundles.
- `16d34b7 Add native resolved FSI parity matrix rows`
  - Qualified-internal parity matrix rows summarize native/imported/parity
    observation status without requiring optional external data.
- `15ee331 Report native resolved FSI dry-run guards`
  - Dry-run plans report default snapshot-count/output-payload guard status and
    exact required override flags.
- `ac04767 Track native resolved FSI boundary mode`
  - Current smoke results explicitly report
    `pressure_drop_weak_inlet_outlet_gauge_smoke`.
  - Its original exact-mode fail-closed placeholder is superseded by the
    low-level Gridap implementation below.
- `aafec81 Implement exact Section 4.1 Gridap boundary mode`
- `9dd964b Test exact Section 4.1 Gridap boundary mode`
  - The exact Section 4.1
    `poiseuille_inlet_zero_outlet_stress_section41` boundary mode is
    implemented and validated at tiny smoke-test scale in the low-level Gridap
    boundary path.
  - Partitioned production execution for that exact mode remains fail-closed
    until the production solver threads the mode and pressure fallback through
    every fluid solve.
- `e4c1486 Document native resolved FSI CLI boundary`
  - Native production, dry-run, restart, parity, and observation helpers remain
    qualified Julia internals.
- `2cbf835 Add native resolved FSI restart state payload`
  - Restart metadata can include versioned `state_payload` audit metadata.
  - Persisted restart/resume remains unsupported and fail-closed.
- `cbf054f Propagate native FSI boundary status`
  - Production dry-run, diagnostics, restart metadata, and parity/status rows
    record boundary mode, boundary class, Section 4.1 evidence status, and
    boundary-equivalence disclaimers.
  - Exact-mode production remains fail-closed until Lane 9C threads the mode
    through partitioned production.
- `eb277f6 Refresh native resolved FSI follow-up plan`
  - Package/public docs and this planning surface were aligned to the current
    implementation boundary.

## Non-Negotiable Claim Boundary

Exact Section 4.1 Poiseuille-inlet / zero-outlet-stress boundary mode is
implemented and smoke-test validated only in the low-level native Gridap
boundary path.

Until that mode is threaded through and validated in partitioned production:

- native production/parity outputs are local implementation and observation
  artifacts, not exact Section 4.1 boundary reproduction;
- manuscript/editorial prose must state that exact Section 4.1 inlet/outlet
  boundary support is low-level smoke-test evidence only, and production
  reproduction remains deferred;
- CLI/status surfaces must expose the boundary status clearly and must not
  imply paper-grade reproduction;
- parity matrix `ready` states mean artifact/operator readiness, not boundary
  equivalence to the imported paper data.

The editorial coordinator has been sent a corrective sync note superseding
earlier softer wording.

## Orchestration Rules

- Start substantial work with:

  ```bash
  pipenv run ops-orchestrate status --json
  ```

- Treat the live dirty tree as authority.
- Use one writer per disjoint file set. If a worker needs files outside its
  assigned scope, it must stop before editing and request expansion.
- Review worker diffs and focused validation. Do not repeat worker validation
  unless review finds integration risk or the parent agent edits after the
  worker.
- Preserve importer schemas and existing bundle filenames unless a lane
  explicitly widens scope.
- Do not add public exports without an explicit lane and public API test update.
- Keep report/manuscript files under the editorial orchestrator's ownership;
  coordinate claim changes through that thread unless explicitly assigned here.

## Consolidated Fleet Findings

- Exact Section 4.1 boundary mode now has low-level Gridap smoke-test support:
  Poiseuille inlet profile, zero-outlet-stress natural traction behavior, and
  explicit pressure gauge/normalization status.
- Exact-mode partitioned production is still intentionally fail-closed until
  the production runner passes the exact mode into each fluid solve and handles
  pressure fallback without silently reusing pressure-drop weak loading.
- Production metadata must continue to record wall boundary mode, inlet/outlet
  boundary mode, Section 4.1 evidence status, and restart `state_payload`
  limitations.
- CLI expansion is in scope next round, but should be dry-run/status-first and
  should make boundary-mode status visible. Production execution from CLI must
  remain non-default and opt-in.
- Restart `state_payload` is audit metadata only. It must not be interpreted as
  persisted resume support.
- Optional imported bundles remain skip-safe; missing external data must not
  fail public-clone validation.

## Priority Lanes

### Lane 9A: Exact Section 4.1 Boundary Mode

Status: completed at low-level Gridap smoke-test scope. Keep this lane as the
regression baseline, not as a production/parity reproduction claim.

Completed evidence:

- `:pressure_drop_weak_inlet_outlet_gauge_smoke` remains the default smoke
  path.
- `:poiseuille_inlet_zero_outlet_stress_section41` no longer fails closed in
  the low-level Gridap boundary path.
- Tiny smoke tests verify Poiseuille inlet selection, `u_max = 45 cm/s`
  status, zero-outlet-stress/natural-traction mode selection, and explicit
  gauge/normalization wording.
- Production execution for the exact mode remains fail-closed until Lane 9C.

Validation:

```bash
packages/stenotic-hemodynamics/bin/julia-release --project=packages/stenotic-hemodynamics -e 'using Test, HDF5, StenoticHemodynamics; include("packages/stenotic-hemodynamics/test/test_native_resolved_fsi_smoke.jl")'
```

Regression guard:

- Existing pressure-drop smoke tests must continue to pass.
- Exact-mode smoke tests must continue to prove the exact mode is selected and
  not silently falling back to pressure-drop loading.

### Lane 9B: Boundary Status Propagation

Status: implemented in this round's package patch. Keep this lane as the
metadata/status regression guard.

Objective: ensure inlet/outlet boundary mode and Section 4.1 boundary status
remain visible through production dry-run, diagnostics, restart metadata, and
parity/status rows.

Owned write scope:

- `src/StenoticHemodynamics/workflows/native_resolved_fsi_workflow_production.jl`
- `src/StenoticHemodynamics/workflows/native_resolved_fsi_restart.jl`
- `src/StenoticHemodynamics/workflows/native_resolved_fsi_parity_production.jl`
- `test/test_native_resolved_fsi_workflow.jl`
- `test/test_native_resolved_fsi_parity.jl`
- `test/test_public_api.jl` only if qualified internals change.

Implementation requirements:

1. Add boundary-mode/status fields to dry-run plans and production diagnostics.
2. Add boundary-mode/status fields to restart metadata and validate them when
   present.
3. Add boundary-mode/status fields to parity matrix rows so `ready` cannot be
   mistaken for exact Section 4.1 boundary equivalence.
4. Preserve backward-compatible reading of older restart metadata.

Validation:

```bash
packages/stenotic-hemodynamics/bin/julia-release --project=packages/stenotic-hemodynamics -e 'using Test, StenoticHemodynamics; include("packages/stenotic-hemodynamics/test/test_native_resolved_fsi_workflow.jl"); include("packages/stenotic-hemodynamics/test/test_native_resolved_fsi_parity.jl"); include("packages/stenotic-hemodynamics/test/test_public_api.jl")'
```

Acceptance:

- Production artifacts identify the inlet/outlet boundary mode used.
- Restart metadata remains fail-closed for persisted resume.
- Parity/status rows separate artifact readiness from boundary reproduction.

### Lane 9C: Exact Boundary Production Threading

Priority: P0 after 9B, before any production-grade reproduction claim.

Objective: thread `:poiseuille_inlet_zero_outlet_stress_section41` through the
partitioned production runner so exact-mode production can execute without
falling back to pressure-drop weak loading.

Owned write scope:

- `src/StenoticHemodynamics/adapters/native_resolved_fsi_partitioned.jl`
- `src/StenoticHemodynamics/adapters/native_resolved_fsi_gridap.jl` only for
  narrow boundary-mode plumbing or pressure fallback needed by production
- `src/StenoticHemodynamics/workflows/native_resolved_fsi_workflow_production.jl`
- `test/test_native_resolved_fsi_smoke.jl`
- `test/test_native_resolved_fsi_workflow.jl`

Implementation requirements:

1. Pass the selected inlet/outlet boundary mode into every production fluid
   solve.
2. Preserve the smoke path and its positive `pressure_drop_dyn_cm2` validation.
3. For exact mode, do not require or apply pressure-drop weak loading.
4. Make pressure gauge/fallback behavior explicit and distinguish it from
   post-sampling outlet pressure normalization.
5. Keep exact-mode production fail-closed unless all required boundary,
   pressure, and finite-field guards are satisfied.
6. Record `inlet_umax_cm_s` in restart boundary metadata before exact production
   can write restart metadata.

Validation:

```bash
packages/stenotic-hemodynamics/bin/julia-release --project=packages/stenotic-hemodynamics -e 'using Test, HDF5, StenoticHemodynamics; include("packages/stenotic-hemodynamics/test/test_native_resolved_fsi_smoke.jl"); include("packages/stenotic-hemodynamics/test/test_native_resolved_fsi_workflow.jl")'
git diff --check -- packages/stenotic-hemodynamics
```

Acceptance:

- Exact-mode partitioned production no longer fails closed at tiny smoke scale.
- Smoke-mode production behavior and labels are unchanged.
- Restart metadata records enough boundary data, including `inlet_umax_cm_s`, to
  validate exact-mode records.
- Diagnostics still state smoke-test scale evidence, not paper-grade Section
  4.1 numerical reproduction.

### Lane 9D: Dry-Run / Status CLI Expansion

Priority: P1 after 9B; production execution CLI exposure waits until 9C.

Objective: add the first native resolved-FSI CLI exposure as a dry-run/status
surface without exposing production execution by default.

Owned write scope:

- `src/StenoticHemodynamics/cli/**`
- `test/test_public_api.jl`
- `packages/stenotic-hemodynamics/README.md`
- `public/docs/julia-cli-workflows.md`
- `public/docs/stenotic-hemodynamics/workflows.md`

Implementation requirements:

1. Prefer a dry-run/status command over an execution command.
2. Do not make `run_native_resolved_fsi_partitioned_production(...)` reachable
   from CLI defaults.
3. Print guard status, required override flags, and boundary-mode status.
4. Keep native resolved-FSI functions qualified internals; a CLI handler may
   call internals without exporting them.

Validation:

```bash
packages/stenotic-hemodynamics/bin/julia-release --project=packages/stenotic-hemodynamics -e 'using Test, StenoticHemodynamics; include("packages/stenotic-hemodynamics/test/test_public_api.jl")'
git diff --check -- packages/stenotic-hemodynamics/README.md public/docs/julia-cli-workflows.md public/docs/stenotic-hemodynamics/workflows.md packages/stenotic-hemodynamics/src/StenoticHemodynamics/cli
```

Acceptance:

- CLI can report planning/status information without running production.
- CLI output cannot imply exact Section 4.1 reproduction unless the exact mode
  is selected and the surface also reports its current production-readiness
  boundary.
- No public exports are added unless explicitly justified and tested.

### Lane 9E: Manuscript / Documentation Synchronization

Priority: P1 after 9B and again after 9C; coordinate with the editorial
orchestrator.

Objective: keep manuscript-facing and public docs claims aligned with the
implementation boundary.

Owned write scope:

- Package/public docs as assigned by the package orchestrator.
- Report/manuscript files only if explicitly coordinated with the editorial
  orchestrator.

Implementation requirements:

1. After 9A/9B, state low-level exact-boundary support and boundary-status
   propagation, while keeping production reproduction deferred.
2. After 9C lands, update docs/manuscript only to the level supported by
   tests and parity evidence.
3. Continue separating generated-artifact evidence, observation-operator
   evidence, exact boundary-mode evidence, and paper-grade numerical
   reproduction.

Validation:

```bash
pipenv run ops-orchestrate docs-contract
git diff --check -- packages/stenotic-hemodynamics public/docs
```

Acceptance:

- No manuscript or docs text overclaims exact Section 4.1 reproduction.
- Editorial coordinator receives an explicit sync note for any claim-boundary
  change.

### Lane 9F: Restart Payload / Resume Stewardship

Priority: P2, can run in parallel with 9D if file locks stay disjoint.

Objective: preserve the restart-reader and `state_payload` contract while
persisted resume remains unsupported.

Owned write scope:

- `src/StenoticHemodynamics/workflows/native_resolved_fsi_restart.jl`
- `src/StenoticHemodynamics/workflows/native_resolved_fsi_workflow_production.jl`
- `test/test_native_resolved_fsi_workflow.jl`

Implementation requirements:

1. Preserve old metadata readability.
2. Keep `state_payload` versioned audit metadata, not a resume contract.
3. Keep `native_resolved_fsi_resume_partitioned_production(...)` fail-closed
   until a true resumed run is implemented and tested.

Validation:

```bash
packages/stenotic-hemodynamics/bin/julia-release --project=packages/stenotic-hemodynamics -e 'using Test, StenoticHemodynamics; include("packages/stenotic-hemodynamics/test/test_native_resolved_fsi_workflow.jl")'
```

Acceptance:

- Resume claims remain fail-closed.
- Metadata schema remains backward-compatible.

### Lane 9G: Workflow Directory Responsibility Split

Priority: P2 after 9B, and preferably after 9D if CLI workflow surfaces are
still moving.

Objective: split the flat `src/StenoticHemodynamics/workflows/` directory into
clearer responsibility subtrees without changing public commands, exports,
workflow semantics, or artifact schemas.

Owned write scope:

- `src/StenoticHemodynamics/workflows/**`
- `src/StenoticHemodynamics.jl`
- focused workflow tests affected by include-path changes
- package/public docs only if import paths or workflow ownership prose changes

Implementation requirements:

1. Inventory workflow files by responsibility before moving anything.
2. Propose subdirectories that reflect stable domains, for example native
   resolved-FSI, resolved-3D comparison/parity, verification, benchmarks,
   studies, geometry exports, and validation workflows.
3. Move files in small batches with include-order-preserving patches.
4. Keep qualified internal names, public exports, CLI commands, artifact
   filenames, and restart/importer schemas unchanged.
5. Avoid mixing directory moves with behavior changes; behavior changes require
   separate lanes.

Validation:

```bash
packages/stenotic-hemodynamics/bin/julia-release --project=packages/stenotic-hemodynamics -e 'using Test, StenoticHemodynamics; include("packages/stenotic-hemodynamics/test/test_public_api.jl")'
packages/stenotic-hemodynamics/bin/julia-release --project=packages/stenotic-hemodynamics -e 'using Test, StenoticHemodynamics; include("packages/stenotic-hemodynamics/test/test_native_resolved_fsi_workflow.jl"); include("packages/stenotic-hemodynamics/test/test_native_resolved_fsi_parity.jl")'
git diff --check -- packages/stenotic-hemodynamics
```

Acceptance:

- `workflows/` ownership is clearer and no longer one flat mixed-responsibility
  surface.
- Include order is explicit and tested.
- Public API and CLI exposure remain unchanged.
- No generated artifacts or manuscript files are touched.

## Execution Sequence

1. Treat 9A and 9B as completed baseline/regression guards.
2. Dispatch 9C first in the next implementation wave. It is the remaining
   exact-boundary production blocker.
3. Dispatch 9D as status-only CLI work after 9B if its file ownership is
   disjoint; do not expose production execution through CLI until 9C lands.
4. Dispatch 9E after any implementation status changes; coordinate with the
   editorial orchestrator before report/manuscript edits.
5. Dispatch 9F opportunistically when restart metadata work is disjoint.
6. Dispatch 9G as a structure-only refactor once active workflow behavior
   lanes have stabilized.

Round-boundary gates:

```bash
git diff --check -- packages/stenotic-hemodynamics public/docs
pipenv run ops-orchestrate docs-contract
```

Run `pipenv run ops-julia-check` only at a true integration boundary or when a
cross-surface review finds a risk not covered by focused lane tests.
