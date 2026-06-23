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

Current bounded interpretation:

- State is now carried within one production run, but restart from saved
  metadata is still unsupported.
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

## Remaining Lanes

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

1. Dispatch 8F and 8H concurrently only while file locks remain disjoint:
   - 8F owns public API/CLI posture and reader-facing CLI docs.
   - 8H owns restart metadata/workflow internals and workflow tests. It must
     stop before editing `test/test_public_api.jl` unless 8F has returned or
     the orchestrator explicitly grants that expansion.
2. Review and commit 8F and 8H separately if their diffs remain independent.
3. Dispatch 8G last so docs reflect the final state.

Round-boundary gates:

```bash
git diff --check -- packages/stenotic-hemodynamics public/docs
pipenv run ops-orchestrate docs-contract
```

Run `pipenv run ops-julia-check` only at a true integration boundary or when a
cross-surface review finds a risk not covered by focused lane tests.
