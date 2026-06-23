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
  - The exact Section 4.1 `poiseuille_inlet_zero_outlet_stress_section41` mode
    remains fail-closed and deferred.
- `e4c1486 Document native resolved FSI CLI boundary`
  - Native production, dry-run, restart, parity, and observation helpers remain
    qualified Julia internals.
- `2cbf835 Add native resolved FSI restart state payload`
  - Restart metadata can include versioned `state_payload` audit metadata.
  - Persisted restart/resume remains unsupported and fail-closed.
- `eb277f6 Refresh native resolved FSI follow-up plan`
  - Package/public docs and this planning surface were aligned to the current
    implementation boundary.

## Non-Negotiable Claim Boundary

Exact Section 4.1 Poiseuille-inlet / zero-outlet-stress boundary mode remains
an open implementation requirement.

Until that mode is implemented and validated:

- native production/parity outputs are local implementation and observation
  artifacts, not exact Section 4.1 boundary reproduction;
- manuscript/editorial prose must state that exact Section 4.1 inlet/outlet
  boundary matching is deferred;
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

- Exact Section 4.1 boundary mode is feasible but nontrivial: it needs a real
  Poiseuille inlet profile, zero-outlet-stress handling, pressure nullspace or
  gauge treatment, and Gridap tests.
- The current `:poiseuille_inlet_zero_outlet_stress_section41` mode is a
  fail-closed placeholder, not an implementation.
- Production metadata currently records wall boundary mode and state payload,
  but exact inlet/outlet boundary status should be threaded through production
  diagnostics, restart metadata, and parity/status surfaces when the mode lands.
- CLI expansion is in scope next round, but should be dry-run/status-first and
  should make boundary-mode status visible. Production execution from CLI must
  remain non-default and opt-in.
- Restart `state_payload` is audit metadata only. It must not be interpreted as
  persisted resume support.
- Optional imported bundles remain skip-safe; missing external data must not
  fail public-clone validation.

## Priority Lanes

### Lane 9A: Exact Section 4.1 Boundary Mode

Priority: P0. This is the main implementation and manuscript claim gate.

Objective: implement the exact Section 4.1 Poiseuille-inlet /
zero-outlet-stress boundary mode as an explicit native Gridap mode while
preserving the existing pressure-drop smoke path.

Owned write scope:

- `src/StenoticHemodynamics/adapters/native_resolved_fsi_gridap.jl`
- `src/StenoticHemodynamics/adapters/native_resolved_fsi_types.jl`
- `src/StenoticHemodynamics/adapters/native_resolved_fsi_partitioned.jl` only
  if the mode must be threaded through partitioned solves.
- `src/StenoticHemodynamics/workflows/native_resolved_fsi_workflow_production.jl`
  only if production specs/diagnostics need boundary-mode fields.
- `test/test_native_resolved_fsi_smoke.jl`
- `test/test_native_resolved_fsi_workflow.jl` only if production metadata is
  changed.
- Reader-facing docs only after code/tests land.

Implementation requirements:

1. Keep `:pressure_drop_weak_inlet_outlet_gauge_smoke` intact as the default.
2. Replace the current fail-closed placeholder for
   `:poiseuille_inlet_zero_outlet_stress_section41` with a real implementation.
3. Use a Poiseuille inlet profile with the paper's `u_max = 45 cm/s` contract
   or an explicitly parameterized equivalent that defaults to that value for
   Section 4.1 plans.
4. Implement zero-outlet-stress behavior without silently reusing the current
   pressure-drop weak loading.
5. Handle pressure nullspace/gauge behavior explicitly.
6. Preserve finite-field, mesh, time, and importer round-trip guards.

Validation:

```bash
packages/stenotic-hemodynamics/bin/julia-release --project=packages/stenotic-hemodynamics -e 'using Test, HDF5, StenoticHemodynamics; include("packages/stenotic-hemodynamics/test/test_native_resolved_fsi_smoke.jl")'
```

Acceptance:

- Existing pressure-drop smoke tests still pass.
- New tests prove the exact Section 4.1 mode no longer fails closed.
- New tests verify inlet-profile enforcement and outlet/gauge behavior at the
  tiny smoke-test scale.
- Status strings distinguish exact Section 4.1 boundary evidence from local
  pressure-drop smoke evidence.

### Lane 9B: Boundary Status Propagation

Priority: P0 after 9A.

Objective: propagate inlet/outlet boundary mode and Section 4.1 boundary status
through production dry-run, diagnostics, restart metadata, parity/status rows,
and docs.

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

### Lane 9C: Dry-Run / Status CLI Expansion

Priority: P1 after 9A/9B status surfaces exist, or earlier only if it reports
boundary deferral explicitly.

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
- CLI output cannot imply exact Section 4.1 reproduction unless 9A/9B support
  that status.
- No public exports are added unless explicitly justified and tested.

### Lane 9D: Manuscript / Documentation Synchronization

Priority: P1 after 9A/9B; coordinate with the editorial orchestrator.

Objective: keep manuscript-facing and public docs claims aligned with the
implementation boundary.

Owned write scope:

- Package/public docs as assigned by the package orchestrator.
- Report/manuscript files only if explicitly coordinated with the editorial
  orchestrator.

Implementation requirements:

1. Before 9A lands, keep exact Section 4.1 boundary mode marked deferred.
2. After 9A/9B land, update docs/manuscript only to the level supported by
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

### Lane 9E: Restart Payload / Resume Stewardship

Priority: P2, can run in parallel with 9C if file locks stay disjoint.

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

## Execution Sequence

1. Dispatch 9A first. It is the implementation and manuscript claim gate.
2. Dispatch 9B immediately after 9A or as a supervised continuation if 9A
   already touches production metadata.
3. Dispatch 9C only after boundary-mode status is visible, unless the CLI is
   explicitly status-only and reports the deferral.
4. Dispatch 9D after any implementation status changes; coordinate with the
   editorial orchestrator before report/manuscript edits.
5. Dispatch 9E opportunistically when restart metadata work is disjoint.

Round-boundary gates:

```bash
git diff --check -- packages/stenotic-hemodynamics public/docs
pipenv run ops-orchestrate docs-contract
```

Run `pipenv run ops-julia-check` only at a true integration boundary or when a
cross-surface review finds a risk not covered by focused lane tests.
