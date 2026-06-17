# Canic Extended 1D Stenosis Simulation

This folder contains a Julia finite-volume reproduction of the extended 1D
stenotic artery model from:

Canic, Guo, Wang, Yue, and Zheng, "Extended one-dimensional reduced model for
blood flow within a stenotic artery" (2024).

The implementation uses the paper's closed conservative `(A,Q)` system, the
asymmetric stenosis profile, Riemann-invariant boundary treatment, Rusanov
fluxes, and third-order SSP Runge-Kutta stepping. Units follow the paper and
the authors' MATLAB code: centimeters, grams, seconds, and dynes.

This is not a line-for-line port of the authors' DG MATLAB code. It is a
compact finite-volume implementation for reproducible local experiments,
backend comparisons, and report figures.

## Simulation Protocol

The public workflow is:

1. Define a case with `Params`.
2. Build the semi-discrete finite-volume system with `semidiscretize(params)`.
3. Choose a time backend:
   - `NativeRK3Backend()` for the built-in fixed-step SSP RK3 path.
   - `SciMLTimeBackend(solve=SolveSpec(...))` for SciML/OrdinaryDiffEq.
4. Run `simulate(params, backend)` to obtain a `SimulationResult`.
5. Derive diagnostics with `velocity(result)`, `pressure(result, params)`,
   `write_csv`, `write_svg`, or study summaries from `run_study`.

The CLI follows the same protocol internally. The default command uses
`NativeRK3Backend()` so existing native runs keep their behavior unless
`--backend sciml` is set explicitly.

## Recommended Commands

Exploratory native smoke test:

```bash
julia --project=. simulations/run_canic_extended_1d.jl --tfinal 0.01 --nx 120 --progress-every 0 --output simulations/output/verification_001s.csv --svg simulations/output/verification_001s.svg
```

Default 50% stenosis native run:

```bash
julia --project=. simulations/run_canic_extended_1d.jl --tfinal 1.0 --nx 400 --severity 50 --progress-every 10000
```

SciML runs with explicit policies:

```bash
julia --project=. simulations/run_canic_extended_1d.jl --backend sciml --alg auto --tfinal 0.001 --nx 40 --progress-every 0
julia --project=. simulations/run_canic_extended_1d.jl --backend sciml --alg tsit5 --abstol 1e-7 --reltol 1e-7 --tfinal 0.001 --nx 40 --progress-every 0
julia --project=. simulations/run_canic_extended_1d.jl --backend sciml --alg rodas5p --maxiters 1000000 --tfinal 0.001 --nx 40 --progress-every 0
```

Supported solver policy names are `auto`, `tsit5`, `rodas5p`, and `ssprk`.
The `ssprk` policy is the native fixed-step RK3 path; `auto`, `tsit5`, and
`rodas5p` require `--backend sciml`. SciML solve options such as `--abstol`,
`--reltol`, `--save-everystep`, and `--maxiters` also require
`--backend sciml`.

Validation test suite:

```bash
julia --project=. test/runtests.jl
```

Show CLI options:

```bash
julia --project=. simulations/run_canic_extended_1d.jl --help
```

Run small programmatic studies from the shared simulation protocol:

```bash
julia --project=. -e 'include("simulations/canic_extended_1d/CanicExtended1D.jl"); using .CanicExtended1D; run_study(SeveritySweepSpec(base_params=Params(nx=40,tfinal=0.001), severities=[23,50], overwrite=true))'
julia --project=. -e 'include("simulations/canic_extended_1d/CanicExtended1D.jl"); using .CanicExtended1D; run_study(GridConvergenceStudySpec(base_params=Params(tfinal=0.001,severity=50), nxs=[40,80], overwrite=true))'
```

Study summaries are written to deterministic CSV paths under
`simulations/output/` by default. Existing summary files are not overwritten
unless `overwrite=true` is set. The summary CSV format is separate from the
single-run profile CSV and includes study kind, severity, grid size, backend,
algorithm, step count, final time, velocity and pressure ranges, and minimum
area.

## Native vs SciML

Use the native backend for deterministic fixed-step smoke runs, continuity with
the original finite-volume implementation, and quick report-oriented checks.
The native path uses `Params.dt` and `Params.cfl` to choose SSP RK3 steps.

Use the SciML backend when comparing OrdinaryDiffEq algorithms, testing
adaptive tolerances, or preparing a future path to events, callbacks, and
ensembles. `SolveSpec` owns SciML solver options such as `abstol`, `reltol`,
`save_everystep`, and `maxiters`; these are intentionally separate from
`Params`, which describes the physical/numerical case.

## Current Limitations

- The RHS and caches are currently `Float64`-specialized. Stiff SciML solvers
  use finite-difference Jacobians (`AutoFiniteDiff`) rather than ForwardDiff.
- A `SemiDiscreteSimulation` owns mutable RHS cache arrays. Do not share one
  instance across concurrent solves.
- Studies run sequentially. SciML ensemble execution is a future adapter-layer
  addition.
- Study summary CSVs use simple scalar fields and minimal CSV escaping.
- The model is a finite-volume reproduction for local experimentation, not a
  full validation of the paper's DG solver or clinical predictions.

If the `julia` launcher cannot write its Juliaup lockfile, use the direct Julia
binary under `~/.julia/juliaup/.../Resources/julia/bin/julia`.
