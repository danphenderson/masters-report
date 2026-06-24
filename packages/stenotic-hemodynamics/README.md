# StenoticHemodynamics Julia Package

`StenoticHemodynamics` is the Julia package used by the report in this
repository. Its primary forward solver evolves a reduced 1D stenotic-vessel
area-flow state, with native finite-volume and DG discretizations, explicit
time-stepping, and selected SciML backend support. Auxiliary workflows cover
Gridap-based stationary-Stokes initialization, reduced membrane-FSI examples,
OpenBF-style configuration adaptation, resolved-3D data comparison, benchmark
studies, native resolved-FSI schema/smoke/production-control harnesses, and
report asset generation. The package does not provide paper-grade transient
resolved-3D CFD or monolithic ALE FSI; resolved-3D workflows retain supported
XDMF/HDF5 importer paths for external comparison and post-processing data.

Commands below assume they are run from the repository root.

The package environment is owned by:

- `packages/stenotic-hemodynamics/Project.toml`
- `packages/stenotic-hemodynamics/Manifest.toml`
- `packages/stenotic-hemodynamics/src/StenoticHemodynamics.jl`
- `packages/stenotic-hemodynamics/src/StenoticHemodynamics/**`
- `packages/stenotic-hemodynamics/test/**`

Run package commands through the repository launcher:

```bash
packages/stenotic-hemodynamics/bin/julia-release packages/stenotic-hemodynamics/test/runtests.jl
packages/stenotic-hemodynamics/bin/stenotic-hemodynamics simulate --help
```

Agent-facing validation should use the Python ops wrapper:

```bash
pipenv run ops-julia-check
```

Reviewer-facing simulation experiments should use the Python experiment runner,
which delegates to this CLI and records JSONL/session-summary logs:

```bash
pipenv run ops-experiment simulate --help
```

## Workflow Documentation

- `../../public/docs/stenotic-hemodynamics/workflows.md`: public workflow hub
  for package studies, verification, validation, comparison, benchmark, and
  native resolved-FSI planning surfaces.
- `../../public/docs/stenotic-hemodynamics/web-visualization.md`: static
  browser visualization contract for `visualization export-web` and the Vite
  viewer.
- `../../public/docs/julia-cli-workflows.md`: command-oriented Julia CLI guide.
- `../../public/docs/resolved3d-workflows.md`: optional resolved-3D data root,
  skip behavior, and report-asset publication boundaries.
- `../../public/docs/stenotic-hemodynamics/native-resolved-fsi-design.md`:
  current native resolved-FSI tier split, sidecars, restart metadata, and
  deferred surfaces.
- `../../public/docs/stenotic-hemodynamics/native-resolved-fsi-section-4-1-reproduction.md`:
  bounded Section 4.1 generated-artifact and local observation-operator note.
- `../../public/docs/stenotic-hemodynamics/canic-2024-replication.md`:
  source-artifact replication workflow for the Canic et al. 2024 Section 4.1
  numerical findings.

## Scope

The package is organized around a reduced one-dimensional hemodynamics model.
It supports model construction, numerical verification, backend comparison,
validation-oriented auxiliary workflows, and selected comparisons against
externally generated resolved-3D data. These workflows do not by themselves
establish physical or clinical validation; reported quantities should be read
relative to the model assumptions, geometry, boundary data, numerical method,
and observation operator used to produce them.

The implemented auxiliary workflows are part of the research-computation
surface for this report. They are not a general-purpose CFD environment, a
native generator for the upstream resolved-3D datasets, or a minimal-dependency
solver-only package.

## Reduced Model

The default forward model is `canic-extended-1d`, the historical manifest token
for the Rmax-normalized Canic-derived extended 1D stenotic artery model used in
the report. Its source model is:

Canic, Guo, Wang, Yue, and Zheng, "Extended one-dimensional reduced model for
blood flow within a stenotic artery" (2024).

The implementation uses the paper's closed conservative `(A,Q)` system as the
starting point, the smooth asymmetric stenosis profile used as the report's
idealized-vessel baseline, Riemann-invariant boundary treatment, Rusanov
fluxes, and third-order SSP Runge-Kutta stepping. The report documents the
source-to-implementation differences, including the constant `Rmax` pressure
denominator, parabolic-profile main case, locally frozen-viscosity `p2`
derivative, and non-well-balanced finite-volume rest state. Units follow the
paper and the authors' MATLAB code: centimeters, grams, seconds, and dynes.

This is not a line-for-line port of the authors' DG MATLAB code. It is a
package-native implementation for reproducible local experiments and report
figures.

## Public Protocol

The exported core workflow is:

1. Define a case with `Params`.
2. Choose a time backend:
   - `NativeRK3Backend()` for the built-in fixed-step SSP RK3 path.
   - `SciMLTimeBackend(solve=SolveSpec(...))` for SciML/OrdinaryDiffEq.
3. Run `simulate(params, backend)` to obtain a `SimulationResult`.
4. Derive diagnostics with exported helpers such as `velocity(result)` and
   `diagnostic_pressure(result, params)`. `evolution_pressure(result, params)`
   exposes the wall-law pressure used by the evolution convention, while the
   deprecated compatibility helper `pressure(result, params)` currently aliases
   `diagnostic_pressure(result, params)`.

Study, benchmark, adapter, native resolved-FSI, and report-asset helpers are
intentionally qualified module internals, for example
`StenoticHemodynamics.run_study(...)`. The CLI uses the same core protocol and
owns ordinary CSV/SVG output writing. Native resolved-FSI production execution,
restart-reader, resume-stub, parity-matrix, and observation-artifact helpers are
still Julia-qualified internal workflows. The `fsi native-status` CLI command
is status-only: it prints dry-run guard status, boundary-mode status, planned
output paths, and imported-bundle status without running production or writing
solver outputs. High-output generation remains guarded by explicit spec
objects, workflow plans, and qualified Julia dry-run guard reporting.

## CLI Examples

Small native smoke run through the experiment runner:

```bash
pipenv run ops-experiment simulate \
  --tfinal 0.01 \
  --nx 120 \
  --ic-pressure-drop-pa 40 \
  --ic-mesh-nz 2 \
  --ic-mesh-nr 2 \
  --ic-mesh-ntheta 8 \
  --progress-every 0 \
  --output tmp/simulations/output/verification_001s.csv \
  --svg tmp/simulations/output/verification_001s.svg
```

Default 50% stenosis run:

```bash
pipenv run ops-experiment simulate \
  --tfinal 1.0 \
  --nx 400 \
  --severity 50 \
  --ic-pressure-drop-pa 40 \
  --progress-every 10000
```

Validation suite:

```bash
pipenv run ops-julia-check
```

Run small studies through the dispatcher:

```bash
pipenv run ops-experiment study severity --severities 23,50 --nx 40 --tfinal 0.001 --ic geometry-rest --overwrite
pipenv run ops-experiment study grid --nxs 40,80 --severity 50 --tfinal 0.001 --ic geometry-rest --overwrite
pipenv run ops-experiment study refinement --nxs 50,100,200,400 --severity 40 --tfinal 0.001 --ic geometry-rest --overwrite
pipenv run ops-experiment stokes refine --nx 80 --parallel-workers 1 --overwrite
```

Generated simulation, verification, benchmark, and comparison outputs default
to ignored paths under `tmp/simulations/output/**`. Pass explicit `--output`,
`--svg`, or `--output-dir` paths when a run must feed a report-asset publishing
workflow.

Browser-ready native resolved-FSI export:

```bash
pipenv run ops-experiment visualization export-web \
  --velocity-xdmf public/var/data/simulations/canic_case3/50/velocity.xdmf \
  --pressure-xdmf public/var/data/simulations/canic_case3/50/pressure.xdmf \
  --displacement-xdmf public/var/data/simulations/canic_case3/50/displace.xdmf \
  --case-id sev50 \
  --target-time 1.4995 \
  --output-dir tmp/simulations/output/visualization/canic_case3 \
  --overwrite
```

Production-directory temporal export:

```bash
pipenv run ops-experiment visualization export-web \
  --input-production-dir tmp/simulations/output/native-resolved-fsi-production/sev23 \
  --case-id sev23 \
  --snapshot-stride 1 \
  --max-snapshots 24 \
  --output-dir tmp/simulations/output/visualization/sev23 \
  --overwrite
```

The web exporter consumes resolved-3D XDMF/HDF5 bundles through the retained
importer path, writes a static manifest plus binary mesh/field assets, and
keeps the same claim boundary as the native resolved-FSI artifact surface:
operator/artifact evidence only, not paper-grade native resolved-FSI
Section 4.1 reproduction.
Direct XDMF/HDF5 mode defaults to schema v1; production-directory mode defaults
to temporal schema v2. The companion browser app lives in
`../stenotic-hemodynamics-viewer`.

Canic et al. 2024 Section 4.1 source-artifact replication after restoring the
optional upstream bundles:

```bash
packages/stenotic-hemodynamics/bin/stenotic-hemodynamics canic-replication section41 \
  --data-root public/var/data/simulations/canic_case3 \
  --output-dir tmp/simulations/output/canic-replication/section41 \
  --coordinate-mode deformed \
  --nx 100 \
  --dt 1e-5 \
  --tfinal 1.0 \
  --section-count 200 \
  --radial-sample-count 41 \
  --overwrite
```

Without restored raw inputs, the same command family reports an expected
`canic_replication_status,skipped_missing_data` skip instead of failing.

## Methods and Closures

The default command uses `NativeRK3Backend()` with finite-volume MUSCL
reconstruction, the minmod TVD limiter, and SSPRK3 stepping unless options
override that method stack. Supported spatial method flags are:

- `--space fv-first-order`: legacy first-order Rusanov finite volume.
- `--space fv-muscl`: TVD MUSCL finite volume.
- `--space fv-weno3`: third-order finite volume with WENO reconstruction.
- `--space fv-lax-wendroff`: native fixed-step Richtmyer/Lax-Wendroff finite
  volume with limited interface states.
- `--space dg --degree 0|1|2|3|4`: modal Legendre DG.

Native time steppers are selected with `--time-stepper euler`,
`--time-stepper ssprk2`, `--time-stepper ssprk3`, or
`--time-stepper ssprk54`. SciML remains available for semi-discrete methods
that do not require a fixed-step predictor. The Lax-Wendroff method is
native-only.

The default velocity profile is `ParabolicVelocityProfile()`, equivalent to
Poiseuille transport with `alpha = 4/3`, shear-rate factor `4`, and
`inlet_uavg = 0.5 * inlet_umax`. CLI profile options are:

- `--velocity-profile parabolic`
- `--velocity-profile flat --profile-shear-factor 4`
- `--velocity-profile power --profile-exponent GAMMA`

The forward-model descriptor defaults to `--model canic-extended-1d`. Use
`--model classical-parabolic-1d` for the classical parabolic-profile baseline;
it requires `--velocity-profile parabolic` and disables the Canic
variable-radius effective-alpha correction terms. The previous
`--model classical-1d-no-slip` token and `ClassicalNoSlip1DModel` constructor
remain deprecated compatibility aliases for `ClassicalParabolicOneDModel`.

Radial profile helpers reconstruct axial velocity from the 1D section-mean
state. Use `reconstructed_axial_velocity(...)`; the older
`radial_profile_velocity(...)` name remains a deprecated compatibility alias.
Resolved-3D radial-bin observations use the normalized cylindrical coordinate
`hypot(x, y) / radius_scale`, equal-width bins on `[0, 1]`, and retain
near-wall overshoot through normalized radius `1.05` by clamping it into the
outer bin. Samples beyond that tolerance are excluded from radial-bin area,
flow, and velocity totals.

The default rheology is Newtonian and uses `Params.nu` as the kinematic
viscosity. Additional local closure objects are available for comparison hooks:

- `CarreauRheology`
- `CarreauYasudaRheology`
- `CassonRheology`
- `PowerLawRheology`

These closures compute pointwise effective kinematic viscosity from the current
1D state and a wall-shear-rate proxy. They do not replace the reduced-model
derivation.

## Initial Conditions

Two deterministic initial-condition modes are available:

- `--ic stationary-stokes`: default. Builds a generated 3D stenotic-vessel mesh
  and assembles a Gridap Taylor-Hood stationary Stokes solve driven by the
  requested pressure drop. The current 1D `(A,Q)` initialization is produced by
  an analytic resistance and pressure-law projection, rather than by direct
  section averaging of the finite-element velocity and pressure fields.
- `--ic geometry-rest`: legacy baseline with `A=R0^2` and `Q=0`.

Stationary Stokes pressure drops are stored internally in dyn/cm^2. The CLI
also accepts Pa and converts with `1 Pa = 10 dyn/cm^2`. The generated FEM mesh
defaults are `--ic-mesh-nz 64 --ic-mesh-nr 6 --ic-mesh-ntheta 32`; small smoke
tests can lower these values.

## Native Resolved-FSI Boundary

The native resolved-FSI surface is intentionally tiered:

- schema workflow: `run_native_resolved_fsi_workflow(...)` writes generated
  velocity/pressure/displacement bundles and reloads them through the retained
  resolved-3D importer;
- fixed-wall smoke: fixed-wall Stokes and Navier-Stokes smoke paths write
  solver-backed fields with zero displacement;
- partitioned smoke: `run_native_resolved_fsi_partitioned_smoke(...)`
  prescribes radial wall-velocity Dirichlet data from a reduced wall update;
- production dry-run: `native_resolved_fsi_partitioned_production_dry_run(...)`
  resolves output, sidecar, restart, and optional imported-parity paths without
  writing files, and reports default guard status through
  `native_resolved_fsi_partitioned_production_default_guard_report(...)`; the
  status-only CLI entrypoint is `fsi native-status`;
- boundary-mode status: the low-level Gridap
  `poiseuille_inlet_zero_outlet_stress_section41` mode is threaded through the
  tiny partitioned production harness and reported as smoke-scale/operator-readiness
  evidence only;
- production sidecars: state-carrying partitioned snapshot runs write
  `snapshot_manifest.csv`, `snapshot_diagnostics.csv`, and
  `restart_metadata.json`;
- restart metadata: `native_resolved_fsi_read_restart_metadata(...)` validates
  package-written legacy and current metadata, including versioned
  `state_payload` audit data when present, while
  `native_resolved_fsi_resume_partitioned_production(...)` fails closed because
  persisted state-carrying resume is deferred;
- observation artifacts: production parity can write `section41_observations.csv`
  and `section41_observation_summary.csv` using local velocity and pressure
  section-observation operators.

These surfaces are generated-artifact and local-operator evidence. The exact
boundary mode is smoke-scale/operator-readiness evidence only. They do not
claim paper-grade native resolved-FSI Section 4.1 reproduction, persisted
restart, or monolithic ALE FSI.

## Resolved-3D Comparison Data

Resolved-3D comparison workflows read optional upstream XDMF/HDF5 velocity
inputs from this ignored local root:

```text
public/var/data/simulations/canic_case3/
```

The default comparison cases are:

- upstream case `77`, severity `23`, expected XDMF time near `0.9995`
- upstream case `60`, severity `40`, expected XDMF time near `0.9995`

Expected local files include:

```text
public/var/data/simulations/canic_case3/77/velocity.xdmf
public/var/data/simulations/canic_case3/77/velocity.h5
public/var/data/simulations/canic_case3/60/velocity.xdmf
public/var/data/simulations/canic_case3/60/velocity.h5
```

Run the default comparison when the data root is present:

```bash
packages/stenotic-hemodynamics/bin/stenotic-hemodynamics compare-3d \
  --target-time 0.9995 \
  --time-atol 1e-6 \
  --overwrite \
  --publish-report-assets
```

The default comparison operator intersects the tetrahedral 3D mesh with each
target plane, linearly interpolates axial velocity on cut edges, triangulates
each cut polygon, and integrates physical area and flow. Node-slab arithmetic
means are emitted only as supplemental sensitivity rows.

## Non-Goals and Limitations

- Solver RHS entrypoints remain `Float64`-specialized. Cache constructors and
  local limiter/basis helpers now have typed footholds for staged scalar
  genericization.
- Internal semi-discrete simulation objects own mutable RHS cache arrays; do not
  share one instance across concurrent solves.
- Study summary CSVs use simple scalar fields and minimal CSV escaping.
- The package does not provide a general-purpose 3D CFD solver, paper-grade
  native resolved-FSI reproduction, or clinical validation of stenosis metrics.
- Native resolved-FSI production-control execution, restart, resume-stub, and
  observation-artifact surfaces are qualified Julia internals. The CLI exposes
  only `fsi native-status` for dry-run/status reporting.
- Native resolved-FSI production metadata records state-carrying partitioned
  snapshots and a versioned `state_payload` audit block. Persisted resume and
  paper-grade native resolved-FSI Section 4.1 reproduction remain deferred;
  exact boundary-mode support is smoke-scale/operator-readiness evidence only.
- Stationary Stokes initialization is a projection contract for the 1D state,
  not a transient FSI solve or direct finite-element field projection.
- The model is a finite-volume reproduction for local experimentation, not a
  clinical validation or a full validation of the source paper's DG solver.
