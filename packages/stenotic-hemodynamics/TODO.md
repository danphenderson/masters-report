# StenoticHemodynamics Next-Round Fleet TODO

Date: 2026-06-23

This is the next supervised dispatch plan for
`packages/stenotic-hemodynamics`. It starts from the current `master` checkout
after the native resolved-FSI solver-depth round. The next objective is to make
the remaining production, restart, parity, API-boundary, documentation, and
maintenance work implementation-ready for concurrent fleet dispatch.

## Baseline For Next Round

The package currently has:

- Split native resolved-FSI adapter files:
  - `adapters/native_resolved_fsi_types.jl`
  - `adapters/native_resolved_fsi_gridap.jl`
  - `adapters/native_resolved_fsi_sampling.jl`
  - `adapters/native_resolved_fsi_partitioned.jl`
  - `adapters/native_resolved_fsi_roundtrip.jl`
- Production controls for Section 4.1 native resolved-FSI runs, including case,
  mesh, time, snapshot, Picard, membrane, coupling, and output-volume guards.
- Multi-snapshot production output with importer-compatible bundle filenames:
  `velocity.xdmf`, `pressure.xdmf`, and `displace.xdmf`.
- Production sidecars: `snapshot_manifest.csv`, `snapshot_diagnostics.csv`,
  and `restart_metadata.json`.
- Partitioned smoke depth with per-time-step coupling iteration caps,
  under-relaxation, displacement residual history, and prescribed radial wall
  velocity as Gridap wall Dirichlet data on the deformed geometry.
- Restart-identification metadata that explicitly marks state-carrying resume
  as deferred.
- Section 4.1 observation artifacts and skip-safe production parity plans.
- Separate velocity and pressure operator status seams.
- Public workflow documentation under `public/docs/stenotic-hemodynamics/`,
  with package-local native FSI docs reduced to pointer stubs.

Bounded interpretation:

- Native generation still uses independent smoke-backed partitioned solves for
  scheduled snapshots, but each partitioned smoke solve feeds the current
  reduced wall velocity into the fluid wall boundary. It is not a monolithic
  transient ALE FSI method and does not include ALE mesh-velocity terms.
- Production sidecars improve reproducibility and handoff, but do not yet
  provide state-carrying restart/resume.
- Section 4.1 observation artifacts are operator/parity artifacts. They do not
  prove paper-grade reproduction.
- External resolved-3D import remains first-class. Native generation augments
  the importer; it does not replace imported reference data support.

Known unrelated dirty-state rule:

- `public/reproducibility/release-manifest.json` may be dirty from a separate
  report/reproducibility lane. Do not edit, stage, or normalize it unless a
  later user instruction explicitly assigns that file.

## Orchestration Rules

- Start with:

  ```bash
  pipenv run ops-orchestrate status --json
  ```

- Treat the live dirty tree as authority.
- Use one writer per disjoint file set. If a worker needs files outside its
  assigned scope, it must stop and request expansion before editing.
- Do not repeat worker validation by default. Review diffs and focused
  handback validation, then run a broader gate only at the round boundary or
  when integration risk justifies it.
- Preserve public CLI commands, existing option names, existing XDMF/HDF5 file
  names, and importer schemas unless a lane explicitly widens scope.
- Native output must remain a three-field bundle: velocity, pressure, and
  displacement.
- Optional external data under `public/var/data/simulations/**` may be absent.
  Parity and report-support workflows must return expected skips rather than
  failing public-clone validation.
- Code lanes own docstrings and comments in their assigned files. Do not
  assume existing docstrings are correct after structural moves.
- Keep production helper namespace tight. Add qualified internal names only
  when they are intentional API-adjacent seams and update the boundary tests in
  the same lane.
- Do not add public exports in this round.
- CLI exposure for native resolved-FSI production is deferred in this round.

## Wave 1: Disjoint Implementation Lanes

Wave 1 lanes may run concurrently only while their owned write scopes remain
disjoint. If a worker needs to expand into another lane's files, pause that
worker and reassign locks before it patches.

### Lane 7A: Wall Boundary Verification Harness

Objective: protect the prescribed radial wall-velocity Dirichlet path with
direct tests before deeper production runs depend on it.

Owned write scope:

- `src/StenoticHemodynamics/adapters/native_resolved_fsi_gridap.jl`
- `src/StenoticHemodynamics/adapters/native_resolved_fsi_partitioned.jl` only
  if a helper must move out of the local solve closure.
- `test/test_native_resolved_fsi_smoke.jl`

Implementation:

1. Add private helper
   `native_resolved_fsi_radial_wall_velocity_function(mesh, wall_velocity_at)`
   in `adapters/native_resolved_fsi_gridap.jl`.
2. Use that helper inside `native_resolved_fsi_solve_navier_stokes` for the
   non-`nothing` `wall_velocity_at` case. Preserve the default zero wall
   velocity path when `wall_velocity_at === nothing`.
3. The helper must:
   - clamp axial position into `[0, mesh.case_spec.length_cm]`;
   - return zero at degenerate centerline points;
   - reject non-finite profile values with `ArgumentError`;
   - return a radial `VectorValue(v*x/r, v*y/r, 0.0)` with the supplied signed
     speed.
4. Add tests for centerline zeroing, axial clamping, finite-value rejection,
   and radial direction/sign on representative wall points.
5. Add one tiny partitioned smoke assertion that `maximum(abs,
   result.wall_velocity_cm_s) > 0.0` and that the partitioned field/status
   strings still say prescribed radial wall-velocity Dirichlet data, not
   fixed-wall or ALE behavior.
6. Do not export the helper. Do not add CLI surface.

Validation:

```bash
packages/stenotic-hemodynamics/bin/julia-release --project=packages/stenotic-hemodynamics -e 'using Test, HDF5, StenoticHemodynamics; include("packages/stenotic-hemodynamics/test/test_native_resolved_fsi_smoke.jl")'
```

Acceptance:

- The wall boundary cannot regress to label-only metadata without test
  failures.
- Tiny tests remain deterministic.
- Status strings avoid fixed-wall-fluid and monolithic-ALE claims for the
  partitioned prescribed-wall path.

### Lane 7B: Restart Metadata Reader And Resume Stub

Objective: make `restart_metadata.json` reloadable through package-owned code
before attempting state-carrying resume.

Owned write scope:

- `src/StenoticHemodynamics.jl`
- New file: `src/StenoticHemodynamics/workflows/native_resolved_fsi_restart.jl`
- `test/test_native_resolved_fsi_workflow.jl`
- `test/test_public_api.jl`

Implementation:

1. Include `workflows/native_resolved_fsi_restart.jl` from
   `StenoticHemodynamics.jl` after
   `workflows/native_resolved_fsi_workflow_production.jl`.
2. Add qualified internal function
   `native_resolved_fsi_read_restart_metadata(path::AbstractString)`.
3. Parse package-written JSON with existing `YAML.load_file`; add no new
   package dependency.
4. Normalize the loaded metadata into `Dict{String,Any}` and validate at least:
   - `restart_provenance == "independent_smoke_backed_snapshots"`;
   - `resume_supported == false`;
   - `resume_status == "deferred"`;
   - `snapshot_manifest_csv`, `diagnostics_csv`, and every snapshot bundle
     path are strings;
   - the referenced sidecar paths exist when they are expected to be local
     outputs from the tiny production run.
5. Add qualified internal function
   `native_resolved_fsi_resume_partitioned_production(path::AbstractString; kwargs...)`
   that calls the reader, then throws `ArgumentError` explaining that
   state-carrying resume is unsupported for independent smoke-backed snapshots.
6. Add both qualified internals to `test/test_public_api.jl` as defined but
   unexported names.
7. Keep the current restart JSON schema backward-compatible. Do not rename
   existing keys.

Validation:

```bash
packages/stenotic-hemodynamics/bin/julia-release --project=packages/stenotic-hemodynamics -e 'using Test, StenoticHemodynamics; include("packages/stenotic-hemodynamics/test/test_native_resolved_fsi_workflow.jl"); include("packages/stenotic-hemodynamics/test/test_public_api.jl")'
```

Acceptance:

- A tiny production run writes metadata that the package can read back.
- Missing, malformed, or unsupported metadata fails with actionable
  `ArgumentError` messages.
- Resume remains explicitly deferred unless a later lane implements and tests
  real state-carrying resume.

### Lane 7D: Production Observation Artifact Hardening

Objective: make the Section 4.1 observation artifact deterministic and summary
ready for future report/comparison lanes.

Owned write scope:

- `src/StenoticHemodynamics/workflows/native_resolved_fsi_parity_production.jl`
- `test/test_native_resolved_fsi_parity.jl`

Implementation:

1. Sort observation rows deterministically before writing by
   `(case_id, source, quantity, z_cm, case_label)`.
2. Add `section41_observation_summary.csv` in the same output directory as
   `section41_observations.csv`.
3. Extend the artifact return value with:
   - `summary_csv`;
   - `summary_rows`.
4. Summary rows must include:
   - `case_id`;
   - `source`;
   - `quantity`;
   - `row_count`;
   - `ready_row_count`;
   - `max_mean_velocity_abs_difference_cm_s`;
   - `max_mean_pressure_abs_difference_dyn_cm2`;
   - `status`.
5. For native-only expected-skip cases, write native observation rows and a
   summary row with `NaN` max-difference fields and expected-skip imported
   status. Do not require optional external data.
6. Keep velocity and pressure operator statuses separate.
7. Do not change importer schema or XDMF/HDF5 filenames.

Validation:

```bash
packages/stenotic-hemodynamics/bin/julia-release --project=packages/stenotic-hemodynamics -e 'using Test, HDF5, StenoticHemodynamics; include("packages/stenotic-hemodynamics/test/test_native_resolved_fsi_parity.jl")'
```

Acceptance:

- Repeated runs write observations and summaries in deterministic row order.
- Native-only, imported-only, and paired parity cases are covered by tests.
- Optional imported bundles are never required for package tests.

### Lane 7H: Scalar Genericity Continuation

Objective: widen low-risk scalar-generic numerical kernels while leaving
Gridap-backed native resolved-FSI entrypoints `Float64`.

Owned write scope:

- `src/StenoticHemodynamics/numerics/solver_fluxes.jl`
- `test/test_scalar_generality.jl`

Implementation:

1. Target the WENO scalar helpers first:
   - `weno3_left_scalar`
   - `weno3_right_scalar`
2. Replace concrete `Float64` argument annotations with scalar-generic
   `T<:AbstractFloat`-compatible behavior where the local arithmetic already
   supports it.
3. Preserve existing `Float64` behavior and allocations for current solver
   paths.
4. Add `Float32` and `BigFloat` tests for the scalar helper results.
5. Document in tests or comments that Gridap native resolved-FSI remains
   `Float64` because Gridap FE spaces and XDMF/HDF5 writer surfaces are still
   `Float64` in this package.

Validation:

```bash
packages/stenotic-hemodynamics/bin/julia-release --project=packages/stenotic-hemodynamics -e 'using Test, StenoticHemodynamics; include("packages/stenotic-hemodynamics/test/test_scalar_generality.jl")'
```

Acceptance:

- WENO scalar helper tests cover `Float32`, `Float64`, and `BigFloat`.
- No Gridap/native resolved-FSI genericity claim is introduced.

## Wave 2: Dependent Production And Boundary Lanes

### Lane 7C: Section 4.1 Production Dry-Run Harness

Objective: provide a deterministic dry-run surface for tiny and larger Section
4.1 production plans without triggering accidental high-output generation.

Dependencies:

- Run after Lane 7B so the dry-run can report restart metadata path/reader
  readiness consistently.

Owned write scope:

- `src/StenoticHemodynamics/workflows/native_resolved_fsi_workflow_production.jl`
- `src/StenoticHemodynamics/workflows/native_resolved_fsi_parity_production.jl`
- `test/test_native_resolved_fsi_workflow.jl`
- `test/test_native_resolved_fsi_parity.jl`
- `test/test_public_api.jl` if adding a new qualified internal name.

Implementation:

1. Add qualified internal type `NativeResolvedFSIProductionDryRunPlan`.
2. Add qualified internal function
   `native_resolved_fsi_partitioned_production_dry_run(plan::NativeResolvedFSIProductionWorkflowPlan; imported_data_root=default_resolved3d_data_root())`.
3. Do not run the production solver from the dry-run function.
4. Dry-run result fields must include:
   - `workflow_plan`;
   - `case_id`;
   - `mesh_resolution`;
   - `expected_node_count`;
   - `expected_tetrahedron_count`;
   - `snapshot_times_s`;
   - `estimated_field_payload_bytes`;
   - `output_dir`;
   - `snapshot_output_dirs`;
   - `manifest_csv`;
   - `diagnostics_csv`;
   - `restart_metadata_json`;
   - `parity_observations_csv`;
   - `parity_summary_csv`;
   - `imported_case`;
   - `imported_available`;
   - `status`.
5. Use existing production output-dir and parity-plan helpers for all paths.
6. Keep high-resolution Section 4.1 execution opt-in only through explicit
   production specs and output-volume overrides.
7. Add the new type/function to `test/test_public_api.jl` as defined but
   unexported qualified internals.

Validation:

```bash
packages/stenotic-hemodynamics/bin/julia-release --project=packages/stenotic-hemodynamics -e 'using Test, HDF5, StenoticHemodynamics; include("packages/stenotic-hemodynamics/test/test_native_resolved_fsi_workflow.jl"); include("packages/stenotic-hemodynamics/test/test_native_resolved_fsi_parity.jl"); include("packages/stenotic-hemodynamics/test/test_public_api.jl")'
```

Acceptance:

- Dry-run plans are deterministic for `sev23`, `sev40`, and `sev50`.
- The dry-run reports expected-skip imported availability for missing optional
  bundles.
- No files are written by dry-run calls.
- No expensive production run can be triggered from defaults.

### Lane 7G: Dependency-Boundary Follow-Up

Objective: update dependency-boundary tests only for the new surfaces added by
Lanes 7A, 7B, and 7D.

Dependencies:

- Run after Lanes 7A, 7B, and 7D land.

Owned write scope:

- `test/test_extension_contracts.jl`

Implementation:

1. Confirm Gridap use remains confined to native/stokes workflow or adapter
   surfaces that need it, including the wall-boundary helper from Lane 7A.
2. Confirm HDF5/EzXML remain confined to resolved-3D I/O and writer surfaces.
3. Confirm YAML use for restart metadata reading is documented/tested as an
   existing dependency reuse, not a new JSON dependency.
4. Do not widen OpenBF or SciML assertions unless the new lanes actually touch
   those surfaces.

Validation:

```bash
packages/stenotic-hemodynamics/bin/julia-release --project=packages/stenotic-hemodynamics -e 'using Test, StenoticHemodynamics; include("packages/stenotic-hemodynamics/test/test_extension_contracts.jl")'
```

Acceptance:

- Boundary tests reflect only the new code paths from this round.
- No broad dependency refactor is attempted in this lane.

## Wave 3: API Boundary And Documentation Lanes

### Lane 7E: CLI Non-Exposure Boundary

Objective: lock the round's native resolved-FSI production posture to
qualified-internal APIs only.

Dependencies:

- Run after Lane 7C so public API tests know the final dry-run internals.

Owned write scope:

- `test/test_public_api.jl`
- `packages/stenotic-hemodynamics/README.md`
- `public/docs/stenotic-hemodynamics/workflows.md`
- `public/docs/julia-cli-workflows.md`

Implementation:

1. Do not add a production CLI command.
2. Test that new native production dry-run/restart names are defined qualified
   internals and are not exported.
3. Test or document that `CLI_COMMAND_NAMES` contains no native resolved-FSI
   production command.
4. Document that production and dry-run surfaces are Julia-qualified internal
   workflows for now, while high-output generation remains guarded by specs.

Validation:

```bash
packages/stenotic-hemodynamics/bin/julia-release --project=packages/stenotic-hemodynamics -e 'using Test, StenoticHemodynamics; include("packages/stenotic-hemodynamics/test/test_public_api.jl")'
git diff --check -- packages/stenotic-hemodynamics/README.md public/docs/stenotic-hemodynamics/workflows.md public/docs/julia-cli-workflows.md
```

Acceptance:

- Public exports remain unchanged.
- Public CLI commands remain unchanged.
- Docs state that CLI exposure is deferred.

### Lane 7F: Native Resolved-FSI Documentation Refresh

Objective: refresh public docs after the code lanes land without inflating
numerical claims.

Dependencies:

- Run last, after Lanes 7A through 7E land.

Owned write scope:

- `public/docs/stenotic-hemodynamics/workflows.md`
- `public/docs/stenotic-hemodynamics/native-resolved-fsi-design.md`
- `public/docs/stenotic-hemodynamics/native-resolved-fsi-section-4-1-reproduction.md`
- `packages/stenotic-hemodynamics/README.md`
- Package-local pointer stubs only if links change.

Implementation:

1. Document the current tier split:
   - schema workflow;
   - fixed-wall smoke;
   - partitioned smoke with prescribed radial wall velocity;
   - production sidecars;
   - restart metadata reader with resume deferred;
   - production dry-run;
   - observation/parity artifacts and summaries;
   - deferred CLI exposure and deferred paper-grade reproduction claims.
2. Keep external importer support described as retained and supported.
3. Keep Section 4.1 reproduction language bounded to generated artifacts and
   local operator parity evidence.
4. Keep package-local docs as pointer stubs unless a local contract requires
   otherwise.

Validation:

```bash
pipenv run ops-orchestrate docs-contract
git diff --check -- packages/stenotic-hemodynamics/README.md packages/stenotic-hemodynamics/docs public/docs
```

Acceptance:

- Public docs are the authoritative Julia package documentation site.
- Claims do not exceed implemented solver depth.
- Native generation remains described as augmenting, not replacing, external
  resolved-3D import support.

## Dispatch Order

1. Wave 1 can run concurrently if write locks remain disjoint:
   - 7A wall-boundary verification.
   - 7B restart metadata reader/stub.
   - 7D observation artifact hardening.
   - 7H scalar genericity continuation.
2. Wave 2 starts after dependencies land:
   - 7C dry-run production harness after 7B.
   - 7G dependency-boundary follow-up after 7A, 7B, and 7D.
3. Wave 3 starts after code/status surfaces stabilize:
   - 7E CLI non-exposure boundary after 7C.
   - 7F docs refresh last.

Round-boundary gates:

```bash
git diff --check -- packages/stenotic-hemodynamics public/docs
pipenv run ops-orchestrate docs-contract
```

Run `pipenv run ops-julia-check` only at a true integration boundary or when a
cross-surface review finds a real risk not covered by focused tests.

Commit scope:

- Stage only package/public-doc implementation files assigned in the round.
- Leave unrelated `public/reproducibility/release-manifest.json`, `report/**`,
  `report/TODO.md`, package `AGENTS.md`, scratch outputs, and generated
  artifacts untouched unless explicitly assigned.
