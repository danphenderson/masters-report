# StenoticHemodynamics Authoritative Fleet TODO

Date: 2026-06-23

This is the current implementation plan for `packages/stenotic-hemodynamics`.
Treat the live checkout as authority before dispatch.

## Current Baseline

Implemented and committed:

- `aafec81` / `9dd964b`: exact Section 4.1
  `poiseuille_inlet_zero_outlet_stress_section41` boundary mode in the
  low-level Gridap path, validated at tiny smoke-test scale.
- `cbf054f`: boundary mode, boundary class, Section 4.1 evidence status, and
  boundary-equivalence disclaimers propagated through production dry-run,
  diagnostics, restart metadata, and parity/status rows.
- `1832e1e`: exact boundary mode threaded through the tiny partitioned
  production smoke-scale harness. Exact-mode production disables pressure-drop
  wall-pressure fallback and requires direct finite pressure sampling.
- `f972368`: parity/status wording bounded so `ready` means
  artifact/operator readiness, not paper-grade reproduction or validated
  Section 4.1 parity.
- `d6ba01e`: `fsi native-status` CLI added as a status-only dry-run surface.
  It reports guard status, output paths, boundary status, and imported-bundle
  status without running production or writing solver outputs.
- `362940d`: workflow files split into responsibility subdirectories under
  `src/StenoticHemodynamics/workflows/` without changing behavior, exports,
  CLI commands, artifact filenames, restart/importer schemas, or public API.
- `f7934bb`: package/public docs synced to the post-9C/9D/10A evidence
  boundary.
- `fc8bbad`: local native resolved-FSI sampling helpers now preserve finite
  real scalar pressure/velocity values instead of downcasting before the
  existing `Float64` production-array boundary.
- Lane 9F restart stewardship audit: no patch required after 9C. Old metadata
  remains readable, exact metadata requires positive `inlet_umax_cm_s`,
  `state_payload` remains versioned audit metadata, and persisted resume
  remains fail-closed.

## Non-Negotiable Claim Boundary

- Exact Section 4.1 boundary-mode support exists in the low-level Gridap path
  and in the tiny partitioned production smoke-scale harness.
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
- Native resolved-FSI production arrays and Gridap adapter surfaces remain
  `Float64`-oriented unless a future lane explicitly generalizes them. Local
  scalar helpers should avoid unnecessary downcasts when they can preserve
  `AbstractFloat` values safely.

## Orchestration Rules

- Start substantial work with:

  ```bash
  pipenv run ops-orchestrate status --json
  ```

- Treat the live dirty tree as authority.
- Use one writer per disjoint file set. Workers must stop before expanding
  scope.
- Prefer structural boundaries before new CLI/API surface area.
- Review worker diffs and handback validation. Do not repeat worker tests
  unless integration risk demands it or the orchestrator edits after handback.
- Preserve public exports, CLI command semantics, artifact filenames, importer
  schemas, and restart metadata compatibility unless a lane explicitly widens
  scope.
- Keep report/manuscript files under editorial ownership. Send sync notes for
  package claim-boundary changes instead of editing report files directly.
- Do not touch unrelated dirty state, including `public/reproducibility` or
  `report/**`, unless explicitly assigned.

## Remaining Dispatch Priority

### Lane 10C: Production-Scale Section 4.1 Validation Plan

Priority: P0 planning lane before claiming native reproduction.

Objective: convert smoke-scale exact-boundary support into an implementation
and validation roadmap for production-scale native Section 4.1 evidence without
overclaiming.

Owned write scope:

- `packages/stenotic-hemodynamics/TODO.md`
- optional new package/public docs under
  `public/docs/stenotic-hemodynamics/**`

Requirements:

1. Specify Section 4.1 cases, mesh/time schedules, inlet `u_max`, outlet
   natural traction, pressure handling, wall material parameters, and expected
   imported-data parity artifacts.
2. Define required validation gates for finite fields, wall displacement,
   pressure normalization, importer round-trip, observation rows, and parity
   summaries.
3. Separate operator-readiness, smoke-scale evidence, production-scale native
   generation, imported-data parity, and manuscript claim readiness.
4. Keep missing optional external bundles skip-safe.
5. Include compute/output guard expectations and required override flags for
   any non-smoke run.

Validation:

```bash
git diff --check -- packages/stenotic-hemodynamics/TODO.md public/docs/stenotic-hemodynamics
```

### Lane 10D: Restart Resume Implementation Design

Priority: P1 design-only unless explicitly promoted.

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

Priority: P2 after 10C claim/validation planning.

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

### Lane 10F: Scalar-Genericity Boundary Follow-Up

Priority: P2, disjoint from production-scale validation unless code paths
overlap.

Objective: continue the scalar-genericity cleanup without pretending the full
native resolved-FSI stack is generic.

Owned write scope:

- `packages/stenotic-hemodynamics/src/StenoticHemodynamics/adapters/native_resolved_fsi_*.jl`
- focused native resolved-FSI tests
- optional docs note if restrictions change

Requirements:

1. Inventory local helper-level `Float64(...)` conversions in native
   resolved-FSI adapters.
2. Preserve `AbstractFloat`/`Real` values in pure scalar helpers when doing so
   does not change array schemas, writer schemas, or Gridap solve contracts.
3. Keep production arrays, HDF5/XDMF schema values, and Gridap solve adapters
   `Float64` unless a future lane explicitly generalizes them.
4. Add focused `Float32`/`BigFloat` helper tests for any generalized helper.
5. Document remaining `Float64` restrictions instead of papering over them.

Validation:

```bash
packages/stenotic-hemodynamics/bin/julia-release --project=packages/stenotic-hemodynamics -e 'using Test, HDF5, StenoticHemodynamics; include("packages/stenotic-hemodynamics/test/test_native_resolved_fsi_smoke.jl")'
git diff --check -- packages/stenotic-hemodynamics
```
