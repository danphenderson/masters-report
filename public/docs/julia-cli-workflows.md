# Julia CLI Workflows

Run reviewer-facing Julia workflows through the Python experiment runner:

```sh
pipenv run ops-experiment <command> [options]
```

`ops-experiment` streams the underlying Julia CLI output in the terminal and
writes JSONL plus summary JSON logs under `public/var/logs/`. For direct solver
development, the lower-level Julia launcher remains:

```sh
packages/stenotic-hemodynamics/bin/stenotic-hemodynamics <command> [options]
```

For the code-level map of the package workflow modules behind these commands,
use `public/docs/stenotic-hemodynamics/workflows.md`.

Keep generated outputs under ignored scratch paths such as
`tmp/simulations/output/**` unless a task explicitly publishes report-consumed
assets.

## Command Families

| Command | Purpose | Default artifact posture |
| --- | --- | --- |
| `simulate` | Run one 1D forward simulation. | Write CSV/SVG outputs only to requested scratch paths unless explicitly publishing evidence. |
| `openbf-run` | Run a strict OpenBF-style `input.yml` adapter. | Treat outputs as local workflow evidence. |
| `study` | Run severity, grid, or refinement studies. | Keep summary outputs in scratch unless routed to report assets. |
| `stokes refine` | Run stationary-Stokes initialization refinement. | Publish tables only when report verification assets are in scope. |
| `fsi validate` | Run quasi-static or reduced dynamic membrane-FSI scratch workflows. | Keep wall profiles, histories, and manifests in scratch unless an explicit report-refresh lane promotes them. |
| `verify` | Run MMS, p/h refinement, or rest-state verification workflows. | Keep scratch outputs unless refreshing report verification tables or figures. |
| `compare-3d` | Compare optional resolved-3D cases against 1D runs. | Skip when local data is absent; publish assets only in explicit scope. |
| `operator-validation` | Validate cross-section quadrature on synthetic cuts. | Use for operator evidence and report tables when scoped. |
| `benchmark` | Run package benchmark profiles. | Follow `public/docs/benchmark-pipeline.md`. |
| `export-assets` | Export stenosis geometry/report CSV assets. | Follow report asset publication rules before rendering or staging outputs. |

There is intentionally no native resolved-FSI production, dry-run, restart, or
parity CLI command in this round. State-carrying production, dry-run guard
reporting, parity matrix rows, and restart metadata remain qualified Julia
internals such as
`StenoticHemodynamics.native_resolved_fsi_partitioned_production_dry_run(...)`
and
`StenoticHemodynamics.native_resolved_fsi_partitioned_production_default_guard_report(...)`.
High-output generation is still guarded by spec objects, workflow plans, and
dry-run checks, and no CLI default reaches the expensive production runner.
Restart metadata may include a versioned `state_payload` audit block, but
persisted restart/resume remains fail-closed. Exact Section 4.1 boundary-mode
matching is still deferred. The next planned CLI expansion is a dry-run or
status-first surface; production execution should stay opt-in and non-default.

## Simulation

Use `simulate` for one forward solve:

```sh
pipenv run ops-experiment simulate \
  --nx 32 \
  --tfinal 1e-5 \
  --ic geometry-rest \
  --output tmp/smoke/simulate.csv
```

The command supports model selection, spatial method selection, native or SciML
time backends, initial-condition options, velocity profiles, rheology closures,
CSV output, SVG output, overwrite control, and progress logging. Run
`packages/stenotic-hemodynamics/bin/stenotic-hemodynamics simulate --help` for option names.

## OpenBF Adapter

Use `openbf-run` only with an explicit config:

```sh
packages/stenotic-hemodynamics/bin/stenotic-hemodynamics openbf-run --config path/to/input.yml
```

Add `--verbose`, `--out-files`, or `--save-stats` only when the task needs the
extra local outputs. Treat those outputs as scratch evidence unless promoted by
a separate report-asset scope.

## Studies And Stokes Refinement

Use `study` for package-native sweeps:

```sh
pipenv run ops-experiment study severity --severities 23,50 --overwrite
pipenv run ops-experiment study grid --nxs 40,80 --overwrite
pipenv run ops-experiment study refinement --nxs 50,100,200,400 --overwrite
```

Use `stokes refine` for stationary-Stokes initialization refinement:

```sh
pipenv run ops-experiment stokes refine \
  --severities 0,23,40,50 \
  --meshes 8x2x8,16x4x16 \
  --overwrite
```

Record skipped optional data or reduced mesh choices in the handback.

Use `fsi validate` for the coupled wall-deformation workflow lane:

```sh
pipenv run ops-experiment fsi validate \
  --wall-mode quasi-static \
  --severities 23,40 \
  --meshes 8x2x8,16x4x16 \
  --output-dir tmp/simulations/output/membrane_fsi_validation \
  --overwrite
```

The quasi-static mode iterates Stokes flow and radial membrane displacement on
the current lumen geometry. Dynamic wall mode is a reduced radial membrane time
integrator coupled to repeated quasi-steady Stokes solves; it is not a transient
moving-boundary fluid solve.
Programmatic Julia runs can pass `geometry_id` and `reference_radius_at_z` to
`MembraneFSIValidationSpec` when the comparator should use another positive
sufficiently smooth vessel radius profile instead of the default Canic stenosis
profile.

## Verification

Use `verify` for numerical evidence:

```sh
pipenv run ops-experiment verify mms --nxs 20,40,80 --overwrite
pipenv run ops-experiment verify ph-refinement --h-nxs 20,40,80,160 --overwrite
pipenv run ops-experiment verify rest --severities 23,40 --nxs 50,100,200 --overwrite
```

Rest verification defaults to `--inlet-umax 0.0`. Ordinary `simulate` and
`compare-3d` workflows default to the production inlet scale instead. Preserve
that distinction in documentation and handbacks.

## Resolved-3D And Operator Workflows

Use `compare-3d` and `operator-validation` through
`public/docs/resolved3d-workflows.md`. That document defines optional data roots,
skip behavior, grid sensitivity, `--reuse-grid-summary`, and report publication
boundaries.

## Benchmark And Asset Export

Use `benchmark` through `public/docs/benchmark-pipeline.md`.

Use `export-assets` to regenerate stenosis geometry CSV assets before running
geometry renderers:

```sh
packages/stenotic-hemodynamics/bin/stenotic-hemodynamics export-assets --overwrite
```

After asset export or publication, run the owning renderer and then a
validation-only report build:

```sh
pipenv run ops-build-report --outdir /tmp/masters-report-build --no-sync-final-pdf
```

## Related Policies

- Use `public/docs/policy-vocabulary.md` for shared artifact terms.
- Use `public/docs/report-assets-and-provenance.md` before staging generated
  assets.
- Use `public/docs/stenotic-hemodynamics/workflows.md` for the package workflow
  map and focused validation surfaces.
- Use `public/docs/resolved3d-workflows.md` for optional resolved-3D data.
- Use `public/docs/benchmark-pipeline.md` for package benchmark outputs.
