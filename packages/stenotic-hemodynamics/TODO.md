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
- `b8451e4` / `3f1b7c7`: wall-stability and pressure-load diagnostics now
  surface through dry-run/status and fail fast before mutating wall state when
  a pressure load would invert a radius.
- Lane 10E CLI follow-up: top-level `fsi` help now describes membrane-FSI
  validation and native resolved-FSI status workflows, while `fsi
  native-status` remains dry-run/status-only and cannot trigger production
  execution by default.
- Lane 9F restart stewardship audit: no patch required after 9C. Old metadata
  remains readable, exact metadata requires positive `inlet_umax_cm_s`,
  `state_payload` remains versioned audit metadata, and persisted resume
  remains fail-closed.
- Lane 10D-1 restart schema boundary: production metadata now writes explicit
  schema-v1 audit fields, legacy metadata without `restart_schema_version`
  remains readable, schema-v2 checkpoint-manifest metadata is shape-validated,
  and `resume_supported=true` remains rejected until durable FE-state
  serialization and a reconstruction runner land.

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
- The current exact-boundary reduced partitioned path uses stationary no-slip
  wall solves on deformed geometry, not a monolithic ALE or strong moving-wall
  fluid boundary claim.
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
- Lane 10C development execution probes reached the exact-boundary partitioned
  production path for `sev23` at `(40, 3, 16)`, `dt_s=1e-4`. Earlier probes
  failed closed at time steps 2-4 before writing solver artifacts because the
  moving-wall/explicit membrane handoff produced non-positive current radii.
  The current patch changes exact-mode fluid solves to stationary no-slip wall
  data on deformed geometry and advances the reduced membrane with a
  semi-implicit update. The full development-mesh gate (`tfinal_s=1e-2`, final
  snapshot only) now completes, writes solver artifacts, and reports finite
  fields, positive current radii, positive tetrahedron orientation, direct
  finite wall-pressure sampling, importer-compatible sidecars, and exact
  stationary-wall handoff metadata. This resolves the immediate early-step P0
  failure at development scope. The run used one coupling iteration per step
  and records bounded, non-converged coupling history, so preproduction,
  production target, imported-data parity, stronger coupling evidence, and the
  moving-wall ALE-fidelity question remain open.
- Lane 10C development-output parity artifact generation ran on the completed
  `sev23` development bundle against imported case `77`. The observation and
  summary CSVs were written under the scratch snapshot directory, imported
  observations loaded, and parity rows remained exact-boundary/status-bounded.
  Development-scale differences were nonzero (`max_mean_velocity_abs_difference_cm_s
  ≈ 2.317`, `max_mean_pressure_abs_difference_dyn_cm2 ≈ 813.906`), so this is
  operator/artifact evidence and discrepancy classification, not production
  parity.
- Wall-stability observability now propagates through production dry-run plans
  and `fsi native-status`: dry-run reports the membrane oscillator `dt_s`
  guard, the mass/stiffness scale, and whether the exact-mode development
  artifact gate is the strongest observed evidence. Historical smaller
  `dt_s` scratch probes alone did not clear the gate: one `dt_s=1e-5` run
  reached the deformed-mesh guard and failed on an inverted/degenerate
  tetrahedron, while a longer `dt_s=1e-5` probe was runtime-inconclusive.
- The partitioned Navier-Stokes pressure space now uses a Gridap zero-mean
  pressure constraint and records `pressure_nullspace_status` through dry-run,
  `fsi native-status`, diagnostics, and restart metadata. Scratch probing
  showed this is pressure-gauge hygiene only: it did not reduce the exact-mode
  wall-pressure/load scale and is not accepted as wall-stability remediation.
- The partitioned wall update now has a fail-fast pressure-load plausibility
  gate that predicts radius inversion before mutating wall state and reports
  the semi-implicit displacement increment used by the current reduced wall
  step.
- Lane 10D records the persisted restart/resume design in
  `public/docs/stenotic-hemodynamics/native-resolved-fsi-restart-resume-design.md`.
  Schema-v1 audit metadata and schema-v2 checkpoint-manifest reader boundaries
  are implemented. Current `state_payload` remains audit metadata, and resume
  remains fail-closed until durable wall/mesh/FE-state serialization, a
  reconstruction runner, sidecar ownership, and split-run equivalence tests
  land.

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
2. Treat the `sev23` full development gate (`tfinal_s=1e-2`) as completed for
   artifact readiness, with the explicit caveat that one-iteration coupling
   was bounded but not converged. Diagnostics must continue to report the
   failing station, pressure load, radius, mass/stiffness/damping, stability
   scale, wall-boundary handoff mode, coupling status, and deformed-mesh
   cell/volume details when mesh orientation fails.
3. Run the exact-boundary `sev23` preproduction gate in a batch-scale lane,
   validating finite fields, wall displacement, pressure normalization,
   importer round-trip, sidecars, observation rows, and stronger coupling
   settings or explicitly bounded coupling status. The development gate took
   about 25 minutes for 101 steps at 9,600 tetrahedra; preproduction and
   production target execution must be scheduled as long-running compute work,
   not assumed interactive.
4. Execute the full case set at the production target mesh
   `(axial=120, radial=5, angular=32)`, `dt_s=1e-4`, `T=1.0 s`, final snapshot
   only, with `u_max=45 cm/s` and
   `:poiseuille_inlet_zero_outlet_stress_section41`.
5. Run imported-data parity as a separate skip-safe lane. `sev23` maps to
   imported case `77`, `sev40` maps to `60`, and `sev50` remains expected-skip
   unless a bundle is explicitly supplied.
6. Send the manuscript owner a claim-readiness handoff only after the roadmap
   gates pass; do not edit report/manuscript files from package lanes.

Validation is lane-specific. At minimum, start with dry-run/status output and
run `git diff --check` on any touched docs or package files.

### Lane 10D Follow-Up: Restart Resume Implementation

Priority: P1 after 10C planning and before any resume claim.

Objective: implement the staged design in
`public/docs/stenotic-hemodynamics/native-resolved-fsi-restart-resume-design.md`
while preserving the current fail-closed behavior for legacy audit metadata.

Recommended dispatch order:

1. Treat schema-v1 audit metadata and schema-v2 checkpoint-manifest validation
   as landed. Do not add public exports or CLI resume commands.
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
