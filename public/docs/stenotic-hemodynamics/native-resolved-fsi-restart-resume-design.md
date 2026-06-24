# Native Resolved-FSI Restart/Resume Design

This design records the current restart/resume boundary for native
resolved-FSI production runs. The package now writes schema-v3 durable
checkpoint metadata with wall, mesh, fluid-state, coupling, and output-linkage
sidecars, and it has a qualified internal split-run resume path for smoke-scale
operator validation.

The public contract remains narrower: `native_resolved_fsi_resume_partitioned_production(...)`
validates metadata and fails closed, and no default CLI path exposes production
resume. Restart/resume support remains package/operator evidence only; it does
not imply paper-grade Section 4.1 reproduction or monolithic ALE FSI.

## Current Contract

Current package-written restart metadata is versioned by schema:

- schema v1: legacy audit metadata, readable and fail-closed;
- schema v2: checkpoint-manifest shape validation, readable and fail-closed;
- schema v3: durable checkpoint metadata for qualified internal resume.

Schema-v3 metadata requires:

- `restart_schema_version = 3`;
- `restart_schema_status = "schema_v3_durable_checkpoint"`;
- `restart_provenance = "state_carrying_partitioned"`;
- `resume_supported = true`;
- `resume_status = "ready"`;
- `checkpoint_schema_status = "durable_checkpoint_ready"`;
- nonempty `checkpoint_manifest` entries for `wall_state`, `mesh_identity`,
  `fluid_state`, `coupling_state`, and `output_linkage`;
- checksums and byte sizes for every checkpoint sidecar;
- snapshot manifest and diagnostics paths;
- completed snapshot output bundle paths;
- boundary mode/status fields;
- a versioned `state_payload` that preserves the old audit metadata boundary.

Legacy metadata without `restart_schema_version` is treated as schema v1.
Schema-v1 and schema-v2 files must continue to carry
`resume_supported = false` and `resume_status = "deferred"`.

## State Payload Boundary

The versioned `state_payload` remains audit metadata for legacy and current
metadata. It proves that one state-carrying production run recorded finite wall
state at the last saved snapshot. It is not, by itself, a durable solver
checkpoint.

The durable checkpoint is the schema-v3 sidecar set referenced by
`checkpoint_manifest`. XDMF/HDF5 snapshot bundles are still
observation/output artifacts. They can be checked for linkage, but they are not
the FE-state source used to qualify a resume.

## Persisted State

### Restart Envelope

The restart envelope records:

- schema version and writer status;
- package version, Julia version, and schema writer identifier;
- absolute or metadata-relative checkpoint sidecar paths;
- checksums and byte sizes for checkpoint payloads, sidecars, and completed
  output bundles;
- parent metadata linkage for resumed forks.

### Wall State

The wall sidecar persists:

- axial wall station coordinates in centimeters;
- wall displacement `wall_displacement_cm` (`eta`);
- wall velocity `wall_velocity_cm_s`;
- current radii `current_radii_cm`;
- wall pressure `wall_pressure_dyn_cm2`;
- wall mass, stiffness, damping, reference-radius policy, and evaluated
  stiffness state;
- clamped endpoint status and tolerance.

Arrays must be finite, compatible in length, and tied to the saved native mesh
resolution and case id.

### Fluid State Or Restart Representation

The fluid sidecar persists the restart representation needed by the current
smoke-scale internal runner:

- velocity and pressure restart values sufficient for the next partitioned
  step;
- previous accepted velocity state required by backward Euler;
- current mesh/deformed-coordinate state associated with the saved step;
- pressure-gauge metadata, kept separate from the internal FE pressure
  representation.

If a later lane switches to a different projection or FE-DOF representation,
that mode must be labeled explicitly and compared against the direct baseline.

### Coupling History

The coupling sidecar persists:

- current physical time and completed time-step count;
- last accepted macro-step size `dt_s`;
- latest coupling residual and residual history used for diagnostics;
- coupling iteration count, tolerance, and under-relaxation value;
- wall-pressure projection and sampling fallback counters;
- Picard and coupling convergence flags.

### Mesh And Deformation

The mesh sidecar persists:

- native case id, severity, geometry parameters, and mesh resolution;
- reference-coordinate and topology checksum;
- boundary tag/node/facet checksum;
- displacement/deformation identity for the saved step;
- minimum current radius and minimum signed tetrahedron volume;
- coordinate mode used for persisted fields.

The resume reader rejects checkpoints when the requested spec regenerates a
different mesh identity.

### Snapshot Schedule Cursor

The output-linkage sidecar persists:

- `tfinal_s`, `snapshot_times_s`, `time_atol`, and current physical time;
- `last_snapshot_index` and the next pending snapshot index;
- completed snapshot output directories;
- parent manifest and diagnostics files;
- forked output-root policy for resumed production.

A resume run must not silently rewrite completed parent snapshots.

### Solver Controls

Schema-v3 resume validation rejects attempts to change controls that affect
the numerical evolution, including:

- `dt_s`, Picard controls, and coupling controls;
- wall density, wall damping, wall stiffness policy, and reference-radius
  policy;
- inlet/outlet boundary mode;
- `inlet_umax_cm_s` for exact Section 4.1 mode;
- pressure-drop value for smoke-loading mode;
- output guard overrides and snapshot schedule.

Continuation-with-changed-controls is outside the current design.

### Boundary And Pressure Status

Checkpoint metadata preserves and revalidates claim-critical status fields:

- boundary mode and boundary-mode class;
- inlet and outlet condition status;
- Section 4.1 boundary status;
- boundary-equivalence status;
- wall-pressure projection status;
- pressure-gauge status.

Exact Section 4.1 mode continues to require positive `inlet_umax_cm_s` and
keeps pressure-drop wall-pressure fallback disabled.

## Resume Runner Semantics

The current runner is deliberately qualified-internal:

1. callers must opt into private/internal resume controls;
2. metadata is read and unsupported schemas are rejected;
3. sidecar checksums, mesh identity, solver controls, boundary status, and
   output ownership are validated;
4. the run must resume into a forked output root, not overwrite the parent
   production directory;
5. execution continues from the first pending snapshot after the parent
   checkpoint;
6. resumed sidecars preserve parent manifest and diagnostics rows and append
   new rows for the resumed fork;
7. new schema-v3 metadata advances the cursor and records parent metadata
   linkage.

Public `native_resolved_fsi_resume_partitioned_production(...)` remains a
metadata-validation plus fail-closed API. The default CLI exposes only
`fsi native-status` for dry-run/status reporting.

## Validation Status

Implemented validation covers:

- legacy schema-v1 audit metadata remains readable and fail-closed;
- schema-v2 checkpoint-manifest metadata validates required
  role/path/checksum/size fields and remains fail-closed;
- schema-v3 metadata requires durable-checkpoint status, nonempty required
  sidecar roles, checksums, and byte sizes;
- missing state files, bad checksums, inconsistent paths, invalid mesh/spec
  controls, and non-forked output roots fail closed;
- exact boundary metadata still requires positive `inlet_umax_cm_s`;
- public resume validates metadata and still fails closed;
- a two-snapshot smoke-scale production run can be split into prefix plus
  qualified internal resume, preserving parent rows and writing the remaining
  resumed snapshot under a forked output root.

Remaining validation before any stronger claim:

- broader numerical equivalence against uninterrupted runs across more cases
  and schedules;
- imported-parity skip-safe resume coverage when optional upstream bundles are
  present or absent;
- production-scale resume validation on long `sev23` runs;
- any public API or CLI exposure review, if a future lane proposes one.

## Claim Boundary Tests

Tests and docs must keep these boundaries intact:

- schema-v3 durable checkpoints are package/operator control evidence;
- public/default resume remains unsupported and fail-closed;
- restart support does not imply monolithic ALE FSI;
- restart support does not imply paper-grade Section 4.1 reproduction;
- old `state_payload` wording remains audit-only.

## Follow-Up Lanes

1. **10D-1 metadata schema.** Completed. Schema-v1 audit metadata, schema-v2
   checkpoint-manifest validation, and schema-v3 durable checkpoint validation
   are implemented.
2. **10D-2 state serialization.** Completed at smoke-scale operator scope for
   wall, mesh, fluid-state, coupling, cursor, and output-linkage sidecars.
3. **10D-3 resume runner.** Completed for the qualified internal split-run
   path only. Public API and CLI resume stay closed.
4. **10D-4 validation tests.** Completed for metadata validation, sidecar
   ownership, forked output roots, and split-run smoke-scale resume. Broader
   production-scale and imported-parity resume validation remains future work.
5. **10D-5 docs and claim boundary.** Completed for package docs and TODO
   handoff. Manuscript claim promotion remains out of scope.
