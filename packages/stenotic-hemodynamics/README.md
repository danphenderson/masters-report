# StenoticHemodynamics Julia Package

`StenoticHemodynamics` is the Julia package used by the report in this
repository. Its primary forward solver evolves a reduced 1D stenotic-vessel
area-flow state, with native finite-volume and DG discretizations, explicit
time-stepping, and selected SciML backend support. Auxiliary workflows cover
Gridap-based stationary-Stokes initialization, reduced membrane-FSI examples,
OpenBF-style configuration adaptation, resolved-3D data comparison, benchmark
studies, and report asset generation. The package does not run transient
resolved-3D CFD; resolved-3D workflows import externally generated XDMF/HDF5
velocity data for comparison and post-processing.

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
- `../../public/docs/julia-cli-workflows.md`: command-oriented Julia CLI guide.
- `../../public/docs/resolved3d-workflows.md`: optional resolved-3D data root,
  skip behavior, and report-asset publication boundaries.
- `../../public/docs/stenotic-hemodynamics/native-resolved-fsi-design.md` and
  `../../public/docs/stenotic-hemodynamics/native-resolved-fsi-section-4-1-reproduction.md`:
  bounded native resolved-FSI design and Section 4.1 reproduction notes.

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
   `pressure(result, params)`.

Study, benchmark, adapter, and report-asset helpers are intentionally qualified
module internals, for example `StenoticHemodynamics.run_study(...)`. The CLI
uses the same core protocol and owns ordinary CSV/SVG output writing.
Native resolved-FSI production, dry-run, and restart-identification helpers are
also Julia-qualified internal workflows for now; there is no production CLI
command. High-output generation remains guarded by explicit spec objects and
planning/dry-run surfaces.

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
`--model classical-1d-no-slip` for the classical parabolic-profile baseline; it
requires `--velocity-profile parabolic` and disables the Canic variable-radius
effective-alpha correction terms.

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
- The package does not provide a general-purpose 3D CFD solver, native resolved
  dataset generation, or clinical validation of stenosis metrics.
- Native resolved-FSI production-control and dry-run surfaces are qualified
  Julia internals, not public CLI commands.
- Stationary Stokes initialization is a projection contract for the 1D state,
  not a transient FSI solve or direct finite-element field projection.
- The model is a finite-volume reproduction for local experimentation, not a
  clinical validation or a full validation of the source paper's DG solver.
