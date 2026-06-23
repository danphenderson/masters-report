# Native Resolved-FSI Restart/Resume Design

This design describes what must exist before
`native_resolved_fsi_resume_partitioned_production(...)` can resume a
partitioned production run from disk. It preserves the current fail-closed
contract: the existing restart reader may validate metadata, but resume remains
unsupported until schema, serialization, runner, and validation tests land.

The current `state_payload` is audit metadata only. It proves that one
state-carrying production run recorded finite wall state at the last saved
snapshot. It is not a durable solver checkpoint and must not be described as
persisted restart support.

## Current Contract

Current package-written restart metadata can record:

- `restart_provenance = "state_carrying_partitioned"`;
- `resume_supported = false`;
- `resume_status = "deferred"`;
- snapshot manifest and diagnostics paths;
- snapshot output bundle paths;
- boundary mode/status fields;
- optional versioned `state_payload` with final wall displacement, wall
  velocity, current radius, wall pressure, saved time, and last snapshot index.

`native_resolved_fsi_resume_partitioned_production(path; kwargs...)` must keep
validating metadata and then failing closed until this design is implemented
and tested.

## Why `state_payload` Is Audit Metadata Only

The current payload is insufficient for a true future-process resume because it
does not store:

- finite-element velocity and pressure solution state in a representation that
  can seed the next backward-Euler/Picard solve;
- a durable mapping from stored field values back to Gridap spaces, DOF order,
  boundary masks, and deformed geometry;
- previous-step fluid state required by the time integrator;
- enough coupling history to preserve under-relaxation and residual behavior;
- a complete snapshot-schedule cursor and append policy for already written
  artifacts;
- checksum-verified mesh/deformation identity for the resumed solve;
- restart-safe output ownership rules for continuing sidecars without
  overwriting or duplicating rows.

The XDMF/HDF5 snapshot bundles are observation/output artifacts. They are
node-centered sampled fields, not solver checkpoints. A resume implementation
may use them for consistency checks, but they cannot by themselves reconstruct
the exact in-memory FE state.

## Required Persisted State

### Restart Envelope

Persisted restart metadata needs a new schema version and explicit support
status:

- `restart_schema_version`, with migration handling for legacy audit metadata;
- `restart_provenance = "state_carrying_partitioned"`;
- `resume_supported = true` only for checkpoint files written by the new
  implementation;
- `resume_status = "ready"` only when every required state file, checksum, and
  control field validates;
- package version or commit, Julia version, and schema writer identifier;
- absolute or metadata-relative paths for all state files;
- checksums and byte sizes for checkpoint payloads, sidecars, and last
  completed output bundles.

Legacy metadata must remain readable and fail-closed.

### Wall State

Persist enough wall state to continue the explicit membrane update without
guessing:

- axial wall station coordinates in centimeters;
- wall displacement `eta_cm`;
- wall velocity `wall_velocity_cm_s`;
- current radii `current_radii_cm`;
- previous wall displacement or previous acceleration if required by the
  selected update formula;
- wall pressure `wall_pressure_dyn_cm2` used for the last accepted update;
- wall mass, stiffness, damping, reference-radius policy, and any evaluated
  `C0` vector;
- clamped endpoint status and tolerance used to enforce it.

All arrays must be finite, same length, and tied to the saved native mesh
resolution and case id.

### Fluid State Or Restart Representation

Persist a restartable fluid state, not only sampled node output:

- velocity FE state for the current deformed mesh, preferably DOF coefficients
  plus the FE-space metadata needed to reconstruct the Gridap function;
- pressure FE state or an explicitly declared pressure initial guess for the
  next Picard solve;
- previous accepted velocity state required by backward Euler;
- current mesh/deformed-coordinate state associated with those DOFs;
- Picard iteration counters and final update norm from the last accepted step;
- pressure gauge convention applied to exported output, separate from the
  internal FE pressure representation.

If a future lane chooses projection-from-output rather than DOF persistence, it
must label that mode explicitly as a lossy restart representation and prove the
projection error is acceptable for the intended claim. It should not be the
default production resume path.

### Coupling History

Persist enough coupling state to resume the partitioned algorithm with the same
control semantics:

- current physical time and completed time-step count;
- last accepted macro-step size `dt_s`;
- latest coupling residual and residual history needed for diagnostics;
- coupling iteration count, tolerance, and under-relaxation value;
- last accepted wall update before under-relaxation, when relevant;
- wall-pressure projection fallback count and sampling fallback count;
- convergence flags for Picard and coupling loops.

### Mesh And Deformation

Persist identity and state for the mesh used by the checkpoint:

- native case id, severity, explicit geometry parameters, and mesh resolution;
- reference coordinates and topology checksum;
- boundary tags/nodes/faces checksum;
- lifted displacement field or enough wall state to reconstruct it exactly;
- minimum current radius and minimum signed tetrahedron volume at checkpoint;
- coordinate mode used for any persisted field representation.

The resume reader must reject a checkpoint if the regenerated mesh identity
does not match the stored identity.

### Snapshot Schedule Cursor

Persist the output schedule and cursor:

- `tfinal_s`, `snapshot_times_s`, `time_atol`, and current physical time;
- `last_snapshot_index` and next pending snapshot index;
- completed snapshot output directories;
- policy for appending to or forking from existing sidecars;
- whether the next run may overwrite, append, or must choose a new output root.

A resume run must not silently rewrite completed snapshots.

### Solver Controls

Persist all controls that affect numerical evolution:

- `dt_s`, Picard iteration count, Picard tolerance;
- coupling iteration count, coupling tolerance, coupling under-relaxation;
- wall density, wall damping, wall stiffness policy, reference-radius policy;
- inlet/outlet boundary mode;
- `inlet_umax_cm_s` for exact Section 4.1 mode;
- pressure-drop value for the smoke-loading mode;
- output guard overrides, including `allow_many_snapshots` and
  `allow_large_output`;
- output root and path token policy.

Resume should reject attempts to change these controls unless a future design
adds an explicit continuation-with-changed-controls mode.

### Boundary And Pressure Status

Persist and revalidate claim-critical status fields:

- boundary mode and boundary mode class;
- inlet condition status;
- outlet condition status;
- Section 4.1 boundary status;
- boundary equivalence status;
- wall-pressure projection status;
- pressure gauge status.

Exact Section 4.1 mode must continue to require positive
`inlet_umax_cm_s = 45 cm/s` for claim-scale runs and must keep pressure-drop
wall-pressure fallback disabled.

### Output Manifest Linkage

Link restart metadata to sidecars and output artifacts:

- `snapshot_manifest.csv`;
- `snapshot_diagnostics.csv`;
- `restart_metadata.json`;
- completed velocity/pressure/displacement bundles;
- optional `section41_observations.csv`;
- optional `section41_observation_summary.csv`;
- checksums for all files the resume code depends on.

Resume validation should fail if any referenced file is missing, has a checksum
mismatch, or points outside the intended output root without explicit approval.

## Resume Runner Semantics

A future resume runner should:

1. Read metadata and reject unsupported schemas.
2. Validate checksums, mesh identity, sidecar linkage, and output ownership.
3. Reconstruct wall, mesh, fluid, and coupling state.
4. Rebuild Gridap spaces and restore or project the fluid state according to
   the declared checkpoint representation.
5. Resume from the first unsaved snapshot time, not from the last completed
   snapshot.
6. Append/fork sidecars according to an explicit policy.
7. Write new restart metadata that advances the cursor and preserves backward
   links to the parent checkpoint.

The runner should be callable only through qualified internals until tests and
docs prove it is safe. No default CLI path should trigger production resume.

## Validation Plan

### Metadata Schema Tests

- legacy audit metadata remains readable and fail-closed;
- unsupported schema versions fail with clear errors;
- missing state files, bad checksums, or inconsistent paths fail;
- exact boundary metadata still requires positive `inlet_umax_cm_s`;
- `resume_supported=true` is accepted only for the new checkpoint schema.

### State Serialization Tests

- wall arrays round-trip exactly within the chosen binary/text precision;
- mesh identity checks fail when case, resolution, topology, or boundary tags
  differ;
- FE state or projection state round-trips into a finite restart state;
- pressure gauge metadata is preserved separately from internal pressure state.

### Resume Runner Tests

- a two-snapshot smoke-scale run can be split into run + resume and produce the
  same final sidecar/status shape as an uninterrupted run;
- completed snapshots are not overwritten silently;
- cursor advancement handles final-snapshot-only and multi-snapshot schedules;
- failed resume leaves existing sidecars untouched.

### Numerical Equivalence Tests

- resumed smoke-scale runs match uninterrupted runs within predeclared
  tolerances for wall displacement, wall velocity, pressure, and velocity
  summaries;
- exact Section 4.1 boundary status survives resume;
- imported-data parity rows remain skip-safe when optional bundles are absent.

### Claim Boundary Tests

- docs and status rows keep persisted resume separate from paper-grade Section
  4.1 reproduction;
- restart support does not imply monolithic ALE FSI;
- `state_payload` remains described as audit metadata for old schemas.

## Follow-Up Lanes

1. **10D-1 metadata schema.** Define schema v2 fields, state-file manifest,
   checksums, parent checkpoint linkage, and fail-closed migration from current
   audit metadata.
2. **10D-2 state serialization.** Add durable wall, mesh, FE fluid, coupling,
   and cursor state writers/readers under ignored scratch output roots.
3. **10D-3 resume runner.** Implement a qualified-internal resume runner that
   reconstructs state and continues from the next pending snapshot without
   exposing production resume through default CLI paths.
4. **10D-4 validation tests.** Add metadata, serialization, split-run/resume,
   sidecar append/fork, and exact-boundary status tests.
5. **10D-5 docs and claim boundary.** Update public docs and editorial
   handoff text after implementation lands, preserving Section 4.1 and
   reproduction claim limits.

Until these lanes land, keep
`native_resolved_fsi_resume_partitioned_production(...)` fail-closed.
