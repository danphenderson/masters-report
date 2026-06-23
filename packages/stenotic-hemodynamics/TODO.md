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
- `15ee331 Report native resolved FSI dry-run guards`
  - Dry-run plans report whether default snapshot-count and output-payload
    guards are satisfied and list required override flags.
- `ac04767 Track native resolved FSI boundary mode`
  - Smoke results report local pressure-drop weak inlet/outlet boundary
    evidence and fail closed for the deferred exact Section 4.1
    Poiseuille-inlet/zero-outlet-stress mode.
- `e4c1486 Document native resolved FSI CLI boundary`
  - Native production, dry-run, restart, and parity remain qualified Julia
    internals.
  - No public CLI command triggers native resolved-FSI production in the
    current round.
- `2cbf835 Add native resolved FSI restart state payload`
  - Restart metadata now carries a versioned `state_payload` audit block for
    current state-carrying runs.
  - Persisted resume remains unsupported and fail-closed despite the richer
    metadata.

Current bounded interpretation:

- State is now carried within one production run, but restart from saved
  metadata is still unsupported.
- Restart metadata may include versioned `state_payload` audit data, but that
  metadata does not make persisted resume available.
- The fluid solve explicitly reports pressure-drop-driven local smoke boundary
  evidence. Exact Section 4.1 Poiseuille inlet and zero-outlet-stress parity
  remain deferred and unclaimed.
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

## Next-Round Lanes

### Lane 9A: Dry-Run Or Status CLI First

Objective: scope the first native resolved-FSI CLI exposure without making the
production runner a default command path.

Owned write scope:

- `src/StenoticHemodynamics/cli/**` only if a narrow CLI surface is approved.
- `test/test_public_api.jl`
- `packages/stenotic-hemodynamics/README.md`
- `public/docs/julia-cli-workflows.md`
- `public/docs/stenotic-hemodynamics/workflows.md`

Implementation:

1. Prefer a dry-run or status-oriented CLI command first.
2. Do not make `run_native_resolved_fsi_partitioned_production(...)` reachable
   from CLI defaults.
3. Preserve public exports unless a later lane explicitly widens that boundary.
4. Keep guard-report and required-override-flag semantics visible if a CLI
   surface is added.

Validation:

```bash
packages/stenotic-hemodynamics/bin/julia-release --project=packages/stenotic-hemodynamics -e 'using Test, StenoticHemodynamics; include("packages/stenotic-hemodynamics/test/test_public_api.jl")'
git diff --check -- packages/stenotic-hemodynamics/README.md public/docs/julia-cli-workflows.md public/docs/stenotic-hemodynamics/workflows.md packages/stenotic-hemodynamics/src/StenoticHemodynamics/cli
```

Acceptance:

- No expensive production execution is reachable from CLI defaults.
- Public API, CLI command lists, and reader-facing docs stay synchronized.

### Lane 9B: Restart Audit Metadata And Reader Stewardship

Objective: keep the restart-reader contract and `state_payload` audit metadata
clear while persisted resume remains unsupported.

Owned write scope:

- `src/StenoticHemodynamics/workflows/native_resolved_fsi_restart.jl`
- `src/StenoticHemodynamics/workflows/native_resolved_fsi_workflow_production.jl`
- `test/test_native_resolved_fsi_workflow.jl`
- `test/test_public_api.jl` only if a qualified internal name changes.

Implementation:

1. Preserve backward-compatible reading for both legacy
   `independent_smoke_backed_snapshots` metadata and current
   `state_carrying_partitioned` metadata.
2. Keep `state_payload` explicitly documented and validated as audit metadata,
   not a persisted-resume contract.
3. Keep `native_resolved_fsi_resume_partitioned_production(...)` fail-closed
   until an actual resumed run is implemented and tested.

Validation:

```bash
packages/stenotic-hemodynamics/bin/julia-release --project=packages/stenotic-hemodynamics -e 'using Test, StenoticHemodynamics; include("packages/stenotic-hemodynamics/test/test_native_resolved_fsi_workflow.jl"); include("packages/stenotic-hemodynamics/test/test_public_api.jl")'
```

Acceptance:

- `state_payload` remains versioned audit metadata.
- Old metadata remains readable.
- Persisted resume claims remain fail-closed.

### Lane 9C: Exact Section 4.1 Boundary Mode

Objective: implement and validate the deferred exact Section 4.1
Poiseuille-inlet/zero-outlet-stress mode without weakening the current
pressure-drop smoke evidence path.

Owned write scope:

- `src/StenoticHemodynamics/adapters/native_resolved_fsi_gridap.jl`
- `src/StenoticHemodynamics/adapters/native_resolved_fsi_types.jl`
- `src/StenoticHemodynamics/adapters/native_resolved_fsi_roundtrip.jl`
- `test/test_native_resolved_fsi_smoke.jl`
- Reader-facing docs only after the code/test lane lands.

Implementation:

1. Keep the current `pressure_drop_weak_inlet_outlet_gauge_smoke` mode intact.
2. Add the exact Section 4.1 inlet/outlet mode as a separate, explicit surface.
3. Fail closed on unsupported combinations rather than silently remapping modes.

Acceptance:

- Smoke status distinguishes local pressure-drop evidence from exact Section 4.1
  boundary reproduction.
- Existing smoke coverage remains stable.

## Dispatch Order

1. Dispatch Lane 9A first if CLI exposure is in scope.
2. Lane 9B may run independently while file locks remain disjoint from 9A.
3. Lane 9C should land after 9A/9B unless a code owner explicitly narrows it to
   smoke-only implementation work.

Round-boundary gates:

```bash
git diff --check -- packages/stenotic-hemodynamics public/docs
pipenv run ops-orchestrate docs-contract
```

Run `pipenv run ops-julia-check` only at a true integration boundary or when a
cross-surface review finds a risk not covered by focused lane tests.
