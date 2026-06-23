# StenoticHemodynamics Next-Round Fleet TODO

Date: 2026-06-23

This is the next supervised dispatch plan for
`packages/stenotic-hemodynamics` after the native resolved-FSI wall-boundary,
restart-reader, dry-run, parity-summary, API-boundary, scalar-genericity, and
documentation round. The next objective is to move from independent
smoke-backed snapshot artifacts toward a state-carrying native resolved-FSI
production path while preserving importer compatibility and bounded Section
4.1 claims.

## Baseline For Next Round

The package currently has:

- Native resolved-FSI mesh, Gridap adapter, sampling, partitioned solve, and
  round-trip files split by responsibility.
- A tested radial wall-velocity helper,
  `native_resolved_fsi_radial_wall_velocity_function(...)`, used as Gridap wall
  Dirichlet data for partitioned smoke solves.
- Partitioned smoke coupling controls: iteration cap, under-relaxation,
  displacement residual history, prescribed radial wall-velocity boundary mode,
  and status text that avoids fixed-wall/ALE overclaims.
- Production planning and execution surfaces:
  - `native_resolved_fsi_production_workflow_plans(...)`;
  - `native_resolved_fsi_partitioned_production_dry_run(...)`;
  - `run_native_resolved_fsi_partitioned_production(...)`.
- Production sidecars:
  - `snapshot_manifest.csv`;
  - `snapshot_diagnostics.csv`;
  - `restart_metadata.json`.
- Restart metadata reader/stub:
  - `native_resolved_fsi_read_restart_metadata(...)`;
  - `native_resolved_fsi_resume_partitioned_production(...)`, which fails
    closed because state-carrying resume is not implemented.
- Production parity artifacts:
  - `section41_observations.csv`;
  - `section41_observation_summary.csv`.
- Existing XDMF/HDF5 importer support for external bundles remains first-class
  and skip-safe when optional local data is absent.
- Native resolved-FSI production/dry-run/restart/parity helpers are qualified
  Julia internals. There is no public CLI command for native resolved-FSI
  production.

Bounded interpretation:

- The current production runner still executes independent smoke-backed
  snapshots. It is not yet a state-carrying transient production solve.
- The current partitioned fluid solve prescribes radial wall velocity on a
  deformed geometry, but it does not include ALE mesh-velocity terms.
- Section 4.1 artifacts are generated-artifact and local observation-operator
  evidence. They do not prove paper-grade numerical reproduction.

## Orchestration Rules

- Start with:

  ```bash
  pipenv run ops-orchestrate status --json
  ```

- Treat the live dirty tree as authority.
- Use one writer per disjoint file set. If a worker needs files outside its
  assigned scope, it must stop and request expansion before editing.
- Review worker diffs and focused validation. Do not repeat worker validation
  unless the review finds integration risk or the parent agent edits after the
  worker.
- Preserve public CLI commands, existing option names, importer schemas, and
  bundle filenames unless a lane explicitly widens scope.
- Native generated bundles remain three-field bundles: velocity, pressure, and
  displacement.
- Optional external data under `public/var/data/simulations/**` may be absent.
  Parity and report-support workflows must return expected skips rather than
  failing public-clone validation.
- Code lanes own docstrings and comments in their assigned files. Do not
  assume existing docstrings are correct.
- Do not add public exports in this round.
- Do not touch report or reproducibility files outside the assigned lane.

## Wave 1: Production-State And Boundary Foundations

Wave 1 lanes may run concurrently only while their owned write scopes remain
disjoint.

### Lane 8A: State-Carrying Snapshot Driver

Objective: replace independent per-snapshot smoke solves with a state-carrying
partitioned production driver for tiny/coarse runs.

Owned write scope:

- `src/StenoticHemodynamics/adapters/native_resolved_fsi_partitioned.jl`
- `src/StenoticHemodynamics/adapters/native_resolved_fsi_types.jl`
- `src/StenoticHemodynamics/workflows/native_resolved_fsi_workflow_production.jl`
- `test/test_native_resolved_fsi_smoke.jl`
- `test/test_native_resolved_fsi_workflow.jl`

Implementation:

1. Add a state-carrying production solve path that advances once to each
   requested snapshot time while carrying wall displacement, wall velocity,
   current radii, pressure history, and fluid free-DOF state between steps.
2. Keep the existing independent smoke-backed runner available as an explicit
   compatibility mode or internal helper until tests no longer need it.
3. Record whether each snapshot came from `state_carrying_partitioned` or
   `independent_smoke_backed` provenance.
4. Preserve coupling residual history per physical time step and per coupling
   iteration.
5. Preserve finite-field, positive-radius, non-inverted-tetrahedron,
   post-refresh, and output-volume guards.
6. Keep tiny tests coarse and deterministic; do not attempt high-resolution
   Section 4.1 execution in this lane.

Validation:

```bash
packages/stenotic-hemodynamics/bin/julia-release --project=packages/stenotic-hemodynamics -e 'using Test, HDF5, StenoticHemodynamics; include("packages/stenotic-hemodynamics/test/test_native_resolved_fsi_smoke.jl"); include("packages/stenotic-hemodynamics/test/test_native_resolved_fsi_workflow.jl")'
```

Acceptance:

- A two-snapshot tiny production run carries state forward instead of solving
  each snapshot from rest.
- Diagnostics and restart metadata identify state-carrying provenance.
- Existing importer-compatible bundle filenames remain unchanged.

### Lane 8B: Paper Boundary-Condition Gap Audit

Objective: make the Section 4.1 inlet/outlet boundary gap executable and
tracked before claiming stronger paper parity.

Owned write scope:

- `src/StenoticHemodynamics/adapters/native_resolved_fsi_gridap.jl`
- `src/StenoticHemodynamics/adapters/native_resolved_fsi_types.jl`
- `test/test_native_resolved_fsi_smoke.jl`
- `public/docs/stenotic-hemodynamics/native-resolved-fsi-section-4-1-reproduction.md`

Implementation:

1. Add an explicit boundary-condition mode/status for the current
   pressure-drop-driven smoke solve versus the paper's Poiseuille inlet and
   zero-outlet-stress contract.
2. Add a small test that the current mode is reported as local smoke boundary
   evidence, not paper-boundary reproduction.
3. If a low-risk Poiseuille-inlet strong Dirichlet option is already supported
   by the current Gridap spaces, add it behind an explicit internal option and
   keep the default unchanged.
4. Do not remove the existing pressure-drop smoke path.

Validation:

```bash
packages/stenotic-hemodynamics/bin/julia-release --project=packages/stenotic-hemodynamics -e 'using Test, HDF5, StenoticHemodynamics; include("packages/stenotic-hemodynamics/test/test_native_resolved_fsi_smoke.jl")'
git diff --check -- public/docs/stenotic-hemodynamics/native-resolved-fsi-section-4-1-reproduction.md
```

Acceptance:

- Status and docs distinguish local smoke boundary conditions from exact
  Section 4.1 boundary reproduction.
- Any new boundary mode is opt-in and tested.

### Lane 8C: Restart Resume Contract Upgrade

Objective: upgrade restart metadata from identification-only toward a tested
state snapshot contract, without claiming full resume until state reload works.

Owned write scope:

- `src/StenoticHemodynamics/workflows/native_resolved_fsi_restart.jl`
- `src/StenoticHemodynamics/workflows/native_resolved_fsi_workflow_production.jl`
- `test/test_native_resolved_fsi_workflow.jl`
- `test/test_public_api.jl` only if new qualified internals are added.

Implementation:

1. Extend restart metadata with a versioned `state_payload` block for the
   final wall state, current radii, saved time, last snapshot index, and solver
   provenance.
2. Keep existing keys backward-compatible.
3. Update the reader to distinguish:
   - metadata reloadable;
   - state payload present;
   - state-carrying resume supported;
   - resume still unsupported.
4. Keep `native_resolved_fsi_resume_partitioned_production(...)` fail-closed
   unless this lane also implements and tests an actual resumed run.

Validation:

```bash
packages/stenotic-hemodynamics/bin/julia-release --project=packages/stenotic-hemodynamics -e 'using Test, StenoticHemodynamics; include("packages/stenotic-hemodynamics/test/test_native_resolved_fsi_workflow.jl"); include("packages/stenotic-hemodynamics/test/test_public_api.jl")'
```

Acceptance:

- New metadata reads back with explicit state-payload status.
- Older metadata remains readable or fails with an actionable version message.
- Resume claims remain fail-closed unless tested.

## Wave 2: Parity And Production Readiness

### Lane 8D: Native/Imported Parity Matrix

Objective: make production parity planning and summaries easier to compare
across `sev23`, `sev40`, and `sev50`.

Owned write scope:

- `src/StenoticHemodynamics/workflows/native_resolved_fsi_parity_production.jl`
- `test/test_native_resolved_fsi_parity.jl`

Implementation:

1. Add a compact parity matrix helper that returns one summary row per
   case/source/quantity from existing dry-run and observation-artifact results.
2. Preserve expected-skip behavior for absent imported bundles.
3. Keep velocity and pressure summaries separate.
4. Do not require optional external data for tests.

Validation:

```bash
packages/stenotic-hemodynamics/bin/julia-release --project=packages/stenotic-hemodynamics -e 'using Test, HDF5, StenoticHemodynamics; include("packages/stenotic-hemodynamics/test/test_native_resolved_fsi_parity.jl")'
```

Acceptance:

- The helper reports deterministic rows for `sev23`, `sev40`, and `sev50`.
- Missing imported bundles are expected skips, not failures.

### Lane 8E: Production Guard Calibration

Objective: make dry-run output-volume and mesh-count estimates actionable for
larger Section 4.1 runs without generating large files in tests.

Owned write scope:

- `src/StenoticHemodynamics/workflows/native_resolved_fsi_workflow_production.jl`
- `test/test_native_resolved_fsi_workflow.jl`

Implementation:

1. Add dry-run status fields for whether snapshot count and output payload are
   within default guards.
2. Report the exact override flags needed for large runs.
3. Add tests for guard-ready and guard-blocked dry-run plans.
4. Do not run high-resolution production.

Validation:

```bash
packages/stenotic-hemodynamics/bin/julia-release --project=packages/stenotic-hemodynamics -e 'using Test, StenoticHemodynamics; include("packages/stenotic-hemodynamics/test/test_native_resolved_fsi_workflow.jl")'
```

Acceptance:

- Dry-run output clearly identifies whether execution would require
  `allow_many_snapshots` or `allow_large_output`.
- No test generates large bundles.

## Wave 3: API And Documentation Closeout

### Lane 8F: CLI Exposure Reassessment

Objective: decide whether to keep native resolved-FSI production qualified
internal or expose only a dry-run CLI command.

Owned write scope:

- `test/test_public_api.jl`
- CLI files only if exposing dry-run CLI is explicitly chosen.
- `packages/stenotic-hemodynamics/README.md`
- `public/docs/julia-cli-workflows.md`
- `public/docs/stenotic-hemodynamics/workflows.md`

Implementation:

1. Default posture remains no production CLI command.
2. If adding CLI, expose dry-run only; no solver execution from CLI defaults.
3. Keep public exports unchanged unless deliberately widened and tested.
4. Document the final posture.

Validation:

```bash
packages/stenotic-hemodynamics/bin/julia-release --project=packages/stenotic-hemodynamics -e 'using Test, StenoticHemodynamics; include("packages/stenotic-hemodynamics/test/test_public_api.jl")'
git diff --check -- packages/stenotic-hemodynamics/README.md public/docs/julia-cli-workflows.md public/docs/stenotic-hemodynamics/workflows.md
```

Acceptance:

- No expensive production run is reachable from CLI defaults.
- Public API and CLI command lists match the documented posture.

### Lane 8G: Documentation Refresh

Objective: update public docs after the state-carrying, boundary, restart, and
parity lanes land.

Owned write scope:

- `public/docs/stenotic-hemodynamics/workflows.md`
- `public/docs/stenotic-hemodynamics/native-resolved-fsi-design.md`
- `public/docs/stenotic-hemodynamics/native-resolved-fsi-section-4-1-reproduction.md`
- `packages/stenotic-hemodynamics/README.md`

Implementation:

1. Document whether state-carrying production is implemented or still partial.
2. Preserve claim boundaries around ALE, exact Section 4.1 boundary
   reproduction, and paper-grade parity.
3. Keep external importer support explicit.
4. Keep CLI exposure status synchronized with Lane 8F.

Validation:

```bash
pipenv run ops-orchestrate docs-contract
git diff --check -- packages/stenotic-hemodynamics/README.md public/docs/stenotic-hemodynamics public/docs/julia-cli-workflows.md
```

Acceptance:

- Docs describe the actual implemented state after the round.
- No paper-grade reproduction claim is introduced without evidence.

## Dispatch Order

1. Run 8A and 8B sequentially if both need Gridap/partitioned adapter files.
2. Run 8C in parallel with 8B only if 8B does not edit production workflow or
   restart files.
3. Run 8D in parallel with 8C only if file locks stay disjoint.
4. Run 8E after 8A and 8C so it can reflect final production metadata.
5. Run 8F after production behavior is stable.
6. Run 8G last.

Round-boundary gates:

```bash
git diff --check -- packages/stenotic-hemodynamics public/docs
pipenv run ops-orchestrate docs-contract
```

Run `pipenv run ops-julia-check` only at a true integration boundary or when a
cross-surface review finds a risk not covered by focused lane tests.

Commit scope:

- Stage only files assigned in the round.
- Leave unrelated `report/**`, `public/reproducibility/**`, scratch outputs,
  and generated artifacts untouched unless explicitly assigned.
