# StenoticHemodynamics Fleet TODO

Date: 2026-06-23

This is the current supervised dispatch plan for
`packages/stenotic-hemodynamics`. It starts from the native resolved-FSI depth
work already landed this round and keeps the next lanes narrow enough for
disjoint write locks.

## Landed Baseline

Recent commits established:

- `696a3d9 Carry native resolved FSI production state`
  - Production now advances one state-carrying partitioned snapshot series
    through the requested snapshot schedule.
  - Snapshot bundles keep the existing velocity/pressure/displacement
    XDMF/HDF5 importer-compatible filenames.
  - Manifest, diagnostics, method status, and restart metadata now report
    `state_carrying_partitioned` provenance.
  - Restart metadata reading accepts both legacy
    `independent_smoke_backed_snapshots` metadata and current
    `state_carrying_partitioned` metadata, while persisted resume remains
    fail-closed.
- `16d34b7 Add native resolved FSI parity matrix rows`
  - A qualified-internal parity matrix helper reports deterministic
    `case/source/quantity` rows across `sev23`, `sev40`, and `sev50`.
  - Missing imported bundles remain expected skips.
- `65c01ad Refine native resolved FSI depth dispatch`
  - The current orchestration rules use disjoint write locks by file set.

Current bounded interpretation:

- State is now carried within one production run, but restart from saved
  metadata is still unsupported.
- The fluid solve still uses pressure-drop-driven local smoke boundary
  evidence. Exact Section 4.1 Poiseuille inlet and zero-outlet-stress parity
  remain unclaimed.
- The partitioned fluid solve prescribes radial wall velocity on deformed
  geometry, but it does not include ALE mesh-velocity terms.
- Native production/dry-run/restart/parity helpers remain qualified Julia
  internals. No public CLI command triggers native resolved-FSI production.
- Optional external data under `public/var/data/simulations/**` may be absent;
  parity workflows must stay skip-safe.

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
- Stage only assigned package/docs files.
- Preserve public CLI commands, existing option names, importer schemas, and
  bundle filenames unless a lane explicitly widens scope.
- Do not add public exports in this round.
- Code lanes own docstrings and comments in their assigned files. Do not
  assume existing docstrings are correct.
- Leave report, reproducibility, scratch, and optional external-data files
  untouched unless explicitly assigned.

## Wave 2: Boundary And Guard Hardening

Wave 2 lanes may run concurrently if their file locks remain exactly disjoint.

### Lane 8B: Paper Boundary-Condition Gap Audit

Objective: make the Section 4.1 inlet/outlet boundary gap executable and
tracked before claiming stronger paper parity.

Owned write scope:

- `src/StenoticHemodynamics/adapters/native_resolved_fsi_gridap.jl`
- `src/StenoticHemodynamics/adapters/native_resolved_fsi_types.jl`
- `test/test_native_resolved_fsi_smoke.jl`
- `public/docs/stenotic-hemodynamics/native-resolved-fsi-section-4-1-reproduction.md`

Implementation:

1. Add explicit boundary-condition mode/status for the current
   pressure-drop-driven smoke solve versus the paper's Poiseuille inlet and
   zero-outlet-stress contract.
2. Add a small test that the current mode is local smoke boundary evidence,
   not exact Section 4.1 boundary reproduction.
3. If a low-risk Poiseuille-inlet strong Dirichlet option fits the current
   Gridap spaces, add it behind an explicit internal option and keep the
   default unchanged.
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

### Lane 8E: Production Guard Calibration

Objective: make dry-run output-volume and mesh-count estimates actionable for
larger Section 4.1 runs without generating large files in tests.

Owned write scope:

- `src/StenoticHemodynamics/workflows/native_resolved_fsi_workflow_production.jl`
- `test/test_native_resolved_fsi_workflow.jl`

Implementation:

1. Add dry-run status fields for whether snapshot count and output payload are
   within default guards.
2. Report exact override flags needed for large runs:
   `allow_many_snapshots` and/or `allow_large_output`.
3. Add tests for guard-ready and guard-blocked dry-run plans.
4. Keep all tests coarse and avoid high-resolution production execution.

Validation:

```bash
packages/stenotic-hemodynamics/bin/julia-release --project=packages/stenotic-hemodynamics -e 'using Test, StenoticHemodynamics; include("packages/stenotic-hemodynamics/test/test_native_resolved_fsi_workflow.jl")'
```

Acceptance:

- Dry-run output identifies whether execution would require
  `allow_many_snapshots`, `allow_large_output`, or neither.
- No test generates large bundles.

## Wave 3: API, Restart Payload, And Docs

Run these after Wave 2 lands unless a worker requests a safe disjoint
expansion.

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

Objective: update public docs after the state-carrying, boundary, guard, and
CLI-posture lanes land.

Owned write scope:

- `public/docs/stenotic-hemodynamics/workflows.md`
- `public/docs/stenotic-hemodynamics/native-resolved-fsi-design.md`
- `public/docs/stenotic-hemodynamics/native-resolved-fsi-section-4-1-reproduction.md`
- `packages/stenotic-hemodynamics/README.md`

Implementation:

1. Document state-carrying production as implemented in-run, not persisted
   restart/resume.
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

### Lane 8H: Restart State-Payload Schema

Objective: add a versioned restart `state_payload` schema without claiming
actual persisted resume.

Owned write scope:

- `src/StenoticHemodynamics/workflows/native_resolved_fsi_restart.jl`
- `src/StenoticHemodynamics/workflows/native_resolved_fsi_workflow_production.jl`
- `test/test_native_resolved_fsi_workflow.jl`
- `test/test_public_api.jl` only if new qualified internals are added.

Implementation:

1. Add a nested `state_payload` metadata block with schema version, saved time,
   last snapshot index, final wall displacement, wall velocity, current radii,
   wall pressure, solver provenance, and resume status.
2. Keep existing top-level metadata keys backward-compatible.
3. Update the reader to report or validate whether a state payload is present.
4. Keep `native_resolved_fsi_resume_partitioned_production(...)` fail-closed
   until an actual resumed run is implemented and tested.

Validation:

```bash
packages/stenotic-hemodynamics/bin/julia-release --project=packages/stenotic-hemodynamics -e 'using Test, StenoticHemodynamics; include("packages/stenotic-hemodynamics/test/test_native_resolved_fsi_workflow.jl"); include("packages/stenotic-hemodynamics/test/test_public_api.jl")'
```

Acceptance:

- New metadata includes a versioned `state_payload`.
- Old metadata remains readable.
- Resume claims remain fail-closed.

## Dispatch Order

1. Dispatch 8B and 8E concurrently only while the owned files stay disjoint.
2. Review and commit 8B and 8E separately if their diffs remain independent.
3. Dispatch 8F after 8E clarifies production/dry-run guard posture.
4. Dispatch 8H after 8E unless 8E requests the restart metadata surface as a
   required expansion.
5. Dispatch 8G last so docs reflect the final state.

Round-boundary gates:

```bash
git diff --check -- packages/stenotic-hemodynamics public/docs
pipenv run ops-orchestrate docs-contract
```

Run `pipenv run ops-julia-check` only at a true integration boundary or when a
cross-surface review finds a risk not covered by focused lane tests.
