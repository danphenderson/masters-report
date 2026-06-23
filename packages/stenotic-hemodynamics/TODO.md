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
- `df95c58`: follow-up scalar helper audit extended the same boundary to outlet
  pressure gauging and wall-pressure plane sampling, with focused
  `Float32`/`BigFloat` tests.
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

## Current Planning Artifact

- Lane 10C records the production-scale Section 4.1 validation roadmap in
  `public/docs/stenotic-hemodynamics/section-4-1-production-validation-plan.md`.
  The plan keeps smoke-scale exact-boundary evidence, production-scale native
  generation, imported-data parity, and manuscript claim readiness separate.
- Lane 10C preflight dry-run matrix completed as status-only planning evidence.
  In the current checkout, `sev23`, `sev40`, and `sev50` development,
  preproduction, and production-target single-snapshot plans all reported
  snapshot-count and payload guards passing, no required override flags, and
  exact-boundary status `implemented_smoke_validated`. Imported bundles were
  observed for `sev23` and `sev40`; `sev50` remains expected-skip unless a
  bundle is explicitly supplied. This did not run production or write solver
  outputs.
- Lane 10D records the persisted restart/resume design in
  `public/docs/stenotic-hemodynamics/native-resolved-fsi-restart-resume-design.md`.
  The design keeps current `state_payload` as audit metadata and keeps resume
  fail-closed until schema, serialization, runner, and tests land.

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

### Lane 10C Follow-Up: Production-Scale Section 4.1 Execution Gates

Priority: P0 before claiming native reproduction.

Objective: implement and run the staged roadmap in
`public/docs/stenotic-hemodynamics/section-4-1-production-validation-plan.md`.

Recommended dispatch order:

1. Start from the completed status-only dry-run matrix. Refresh it only if
   case parameters, guard policy, imported-data roots, or output schedules
   change.
2. Execute the exact-boundary `sev23` development and preproduction runs first,
   validating finite fields, wall displacement, pressure normalization,
   importer round-trip, sidecars, and observation rows.
3. Execute the full case set at the production target mesh
   `(axial=120, radial=5, angular=32)`, `dt_s=1e-4`, `T=1.0 s`, final snapshot
   only, with `u_max=45 cm/s` and
   `:poiseuille_inlet_zero_outlet_stress_section41`.
4. Run imported-data parity as a separate skip-safe lane. `sev23` maps to
   imported case `77`, `sev40` maps to `60`, and `sev50` remains expected-skip
   unless a bundle is explicitly supplied.
5. Send the manuscript owner a claim-readiness handoff only after the roadmap
   gates pass; do not edit report/manuscript files from package lanes.

Validation is lane-specific. At minimum, start with dry-run/status output and
run `git diff --check` on any touched docs or package files.

### Lane 10D Follow-Up: Restart Resume Implementation

Priority: P1 after 10C planning and before any resume claim.

Objective: implement the staged design in
`public/docs/stenotic-hemodynamics/native-resolved-fsi-restart-resume-design.md`
while preserving the current fail-closed behavior for legacy audit metadata.

Recommended dispatch order:

1. Define restart schema v2 with state-file manifest, checksums, parent
   checkpoint linkage, boundary status, pressure gauge/projection status,
   solver controls, and snapshot cursor fields.
2. Add durable wall, mesh, FE fluid, coupling, and cursor state
   serialization. Node-centered XDMF/HDF5 output bundles are not enough for
   exact solver resume.
3. Implement a qualified-internal resume runner that validates the checkpoint,
   reconstructs state, and continues from the next pending snapshot without
   exposing production resume through default CLI paths.
4. Add metadata, serialization, split-run/resume, sidecar ownership, exact
   boundary status, and skip-safe imported parity tests.
5. Update public docs and editorial handoff text only after implementation and
   tests land. Preserve the Section 4.1 claim boundary: persisted restart does
   not imply paper-grade reproduction or monolithic ALE FSI.

Until then, `native_resolved_fsi_resume_partitioned_production(...)` must keep
validating metadata and failing closed.

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
