# StenoticHemodynamics Authoritative Fleet TODO

Date: 2026-06-23

This is the current implementation plan for `packages/stenotic-hemodynamics`.
Treat the live checkout as authority before dispatch. This plan is optimized for
supervised fleet execution after the exact-boundary and status-CLI wave.

## Current Baseline

Implemented and committed:

- `aafec81` / `9dd964b`: exact Section 4.1
  `poiseuille_inlet_zero_outlet_stress_section41` boundary mode in the
  low-level Gridap path, validated at tiny smoke-test scale.
- `cbf054f`: boundary mode, boundary class, Section 4.1 evidence status, and
  boundary-equivalence disclaimers propagated through production dry-run,
  diagnostics, restart metadata, and parity/status rows.
- `1832e1e`: exact boundary mode threaded through the tiny partitioned
  production smoke-scale harness. Exact-mode production disables
  pressure-drop wall-pressure fallback and requires direct finite pressure
  sampling.
- `f972368`: parity/status wording bounded so `ready` means
  artifact/operator readiness, not paper-grade reproduction or validated
  Section 4.1 parity.
- `d6ba01e`: `fsi native-status` CLI added as a status-only dry-run surface.
  It reports guard status, output paths, boundary status, and imported-bundle
  status without running production or writing solver outputs.
- Lane 9F restart stewardship audit: no patch required after 9C. Old metadata
  remains readable, exact metadata requires positive `inlet_umax_cm_s`,
  `state_payload` remains versioned audit metadata, and persisted resume
  remains fail-closed.

## Non-Negotiable Claim Boundary

- Exact Section 4.1 boundary-mode support now exists in the low-level Gridap
  path and in the tiny partitioned production smoke-scale harness.
- This is not paper-grade Section 4.1 numerical reproduction, not validated
  parity against imported external data, and not monolithic ALE FSI.
- `:pressure_drop_weak_inlet_outlet_gauge_smoke` remains local smoke/loading
  evidence.
- `:poiseuille_inlet_zero_outlet_stress_section41` remains smoke-scale
  exact-boundary/operator-readiness evidence until production-scale validation
  and imported-data parity evidence land.
- Post-sampling outlet pressure normalization is not a Gridap pressure
  nullspace constraint.
- Restart `state_payload` is audit metadata only; persisted restart/resume is
  unsupported and fail-closed.
- CLI/status surfaces must continue to expose these boundaries and must not
  imply paper-grade reproduction.

## Orchestration Rules

- Start substantial work with:

  ```bash
  pipenv run ops-orchestrate status --json
  ```

- Treat the live dirty tree as authority.
- Use one writer per disjoint file set. Workers must stop before expanding
  scope.
- Review worker diffs and handback validation. Do not repeat worker tests
  unless integration risk demands it or the orchestrator edits after handback.
- Preserve public exports, CLI command semantics, artifact filenames, importer
  schemas, and restart metadata compatibility unless a lane explicitly widens
  scope.
- Keep report/manuscript files under editorial ownership. Send sync notes for
  package claim-boundary changes instead of editing report files directly.
- Do not touch unrelated dirty state, including `public/reproducibility` or
  `report/**`, unless explicitly assigned.

## Next Dispatch Priority

### Lane 10A: Workflow Directory Responsibility Split

Priority: P0 structural gate before more CLI/API expansion.

Objective: split the flat `src/StenoticHemodynamics/workflows/` directory into
clear responsibility subtrees without changing behavior.

Rationale: this should have preceded the 9D CLI surface. The CLI now exposes
only a narrow status facade, so the correction is to stabilize workflow module
ownership next before adding any further user-facing surface.

Owned write scope:

- `packages/stenotic-hemodynamics/src/StenoticHemodynamics/workflows/**`
- `packages/stenotic-hemodynamics/src/StenoticHemodynamics.jl`
- focused workflow/public API tests affected by include-path changes
- package/public docs only for path/ownership references affected by the move

Implementation requirements:

1. Inventory all current workflow files and group them into stable domains:
   native resolved-FSI, resolved-3D comparison/parity, verification, benchmarks,
   studies, geometry exports, membrane-FSI validation, operator validation, and
   shared workflow utilities.
2. Move files in small include-order-preserving batches.
3. Keep qualified internal names, public exports, CLI commands, artifact
   filenames, restart/importer schemas, and runtime behavior unchanged.
4. Avoid behavior changes. Any discovered behavior issue becomes a follow-up
   lane unless required to preserve includes/tests after the move.
5. Update path references in package/public docs only after code tests pass.

Validation:

```bash
packages/stenotic-hemodynamics/bin/julia-release --project=packages/stenotic-hemodynamics -e 'using Test, StenoticHemodynamics; include("packages/stenotic-hemodynamics/test/test_public_api.jl")'
packages/stenotic-hemodynamics/bin/julia-release --project=packages/stenotic-hemodynamics -e 'using Test, StenoticHemodynamics; include("packages/stenotic-hemodynamics/test/test_native_resolved_fsi_workflow.jl"); include("packages/stenotic-hemodynamics/test/test_native_resolved_fsi_parity.jl")'
git diff --check -- packages/stenotic-hemodynamics public/docs
```

Acceptance:

- Workflow ownership is visibly clearer and no longer one flat mixed-purpose
  directory.
- Include order remains explicit and tested.
- Public API and CLI command exposure are unchanged.
- No generated artifacts or manuscript files are touched.

### Lane 10B: Native Resolved-FSI Docs Claim Sync

Priority: P1 after 10A, or in parallel only if docs files do not overlap
10A path updates.

Objective: update package/public docs to the current evidence boundary after
9C/9D while avoiding stale path references after 10A.

Owned write scope:

- `packages/stenotic-hemodynamics/README.md`
- `public/docs/julia-cli-workflows.md`
- `public/docs/stenotic-hemodynamics/workflows.md`
- `public/docs/stenotic-hemodynamics/native-resolved-fsi-design.md`
- `public/docs/stenotic-hemodynamics/native-resolved-fsi-section-4-1-reproduction.md`

Requirements:

1. State that `fsi native-status` is status-only and never runs production.
2. State that exact boundary mode is threaded through tiny production
   smoke-scale evidence, but paper-grade Section 4.1 reproduction remains
   deferred.
3. Keep parity/status wording bounded to artifact/operator readiness.
4. Preserve restart `state_payload` as audit metadata only.
5. Do not edit manuscript/report files; send an editorial sync note if wording
   implications change.

Validation:

```bash
pipenv run ops-orchestrate docs-contract
git diff --check -- packages/stenotic-hemodynamics public/docs
```

### Lane 10C: Production-Scale Section 4.1 Validation Plan

Priority: P1 planning lane after 10A, before claiming native reproduction.

Objective: convert smoke-scale exact-boundary support into a production-scale
validation roadmap without overclaiming.

Owned write scope:

- `packages/stenotic-hemodynamics/TODO.md`
- optional new package/public docs under `public/docs/stenotic-hemodynamics/**`

Requirements:

1. Specify Section 4.1 cases, mesh/time schedules, inlet `u_max`, outlet
   natural traction, pressure handling, wall material parameters, and expected
   imported-data parity artifacts.
2. Define required validation gates for finite fields, wall displacement,
   pressure normalization, importer round-trip, observation rows, and parity
   summaries.
3. Separate operator-readiness, smoke-scale evidence, production-scale native
   generation, and imported-data parity.
4. Keep missing optional external bundles skip-safe.

### Lane 10D: Restart Resume Implementation Design

Priority: P2 design-only unless explicitly promoted.

Objective: design true persisted restart/resume support while preserving the
current fail-closed contract.

Owned write scope:

- `packages/stenotic-hemodynamics/TODO.md`
- optional design doc under `public/docs/stenotic-hemodynamics/**`

Requirements:

1. Define the persisted state required to restart partitioned production:
   wall state, carried velocity/pressure state, coupling history, mesh
   deformation, snapshot schedule cursor, and solver controls.
2. Explain why current `state_payload` is audit metadata only.
3. Keep `native_resolved_fsi_resume_partitioned_production(...)` fail-closed
   until implementation and tests land.

### Lane 10E: CLI Surface Follow-Up After Workflow Split

Priority: P2 after 10A and 10B.

Objective: decide whether `fsi native-status` should stay under `fsi` or move
behind a workflow-specific facade after directory restructuring.

Requirements:

1. Do not add production execution from CLI by default.
2. Preserve the existing `fsi native-status` behavior unless a migration path is
   explicitly tested and documented.
3. Keep exact-boundary claim text visible in CLI output.

Validation:

```bash
packages/stenotic-hemodynamics/bin/julia-release --project=packages/stenotic-hemodynamics -e 'using Test, StenoticHemodynamics; include("packages/stenotic-hemodynamics/test/test_public_api.jl")'
git diff --check -- packages/stenotic-hemodynamics public/docs
```
