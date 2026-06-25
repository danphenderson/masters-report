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
| `fsi native-status` | Print native resolved-FSI production dry-run/status fields without running production. | Status-only; prints paths, guard status, boundary status, and imported-bundle status without writing solver outputs. |
| `verify` | Run MMS, p/h refinement, or rest-state verification workflows. | Keep scratch outputs unless refreshing report verification tables or figures. |
| `compare-3d` | Compare optional resolved-3D cases against 1D runs. | Skip when local data is absent; publish assets only in explicit scope. |
| `operator-validation` | Validate cross-section quadrature on synthetic cuts. | Use for operator evidence and report tables when scoped. |
| `benchmark` | Run package benchmark profiles. | Follow `public/docs/benchmark-pipeline.md`. |
| `export-assets` | Export stenosis geometry/report CSV assets. | Follow report asset publication rules before rendering or staging outputs. |
| `visualization export-web` | Convert resolved-FSI/resolved-3D XDMF/HDF5 bundles into static browser assets. | Keep exports in `tmp/simulations/output/visualization/**` unless curating a reviewed viewer demo. |
| `canic-replication section41` | Compare local 1D outputs with Canic et al. 2024 Section 4.1 source artifacts for velocity, pressure observation rows, radial postprocessing, and 3D diagnostics. | Skip when local raw data is absent; publish assets only in an explicit manuscript lane. |

There is intentionally no native resolved-FSI production, restart, resume, or
parity execution CLI command in this round. `fsi native-status` is a status-only
front door over the qualified Julia dry-run surface. State-carrying production,
parity matrix rows, and restart metadata remain qualified Julia internals such
as
`StenoticHemodynamics.native_resolved_fsi_partitioned_production_dry_run(...)`
and
`StenoticHemodynamics.native_resolved_fsi_partitioned_production_default_guard_report(...)`.
High-output generation is still guarded by spec objects, workflow plans, and
dry-run checks, and no CLI default reaches the expensive production runner.
Restart metadata may include schema-v3 checkpoint sidecars and a versioned
`state_payload` audit block. Qualified internal split-run resume is available
only through Julia internals and forked output roots; public/default
restart/resume remains fail-closed. The internal exact Section 4.1 boundary
mode (`poiseuille_inlet_zero_outlet_stress_section41`) is wired through the
low-level Gridap/native production harness and surfaced here only as status
output; it remains smoke-scale/operator-readiness evidence, not paper-grade
native resolved-FSI Section 4.1 reproduction. Use
`canic-replication section41` for the separate source-artifact Section 4.1
comparison workflow.

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

Use `fsi native-status` for native resolved-FSI production dry-run status only:

```sh
pipenv run ops-experiment fsi native-status \
  --case-id sev23 \
  --mesh 2x1x6 \
  --snapshot-times 1e-4 \
  --inlet-outlet-boundary-mode poiseuille_inlet_zero_outlet_stress_section41 \
  --ic-pressure-drop-dyn-cm2 0.0
```

The command prints guard status, required override flags, boundary mode/class,
Section 4.1 boundary status, boundary-equivalence status, planned output paths,
and imported-bundle availability. It does not run
`run_native_resolved_fsi_partitioned_production(...)` and does not write solver
outputs.

## Browser Visualization Export

Use `visualization export-web` to create static assets for the browser viewer.
Direct XDMF/HDF5 mode defaults to schema v1:

```sh
pipenv run ops-experiment visualization export-web \
  --velocity-xdmf public/var/data/simulations/canic_case3/50/velocity.xdmf \
  --pressure-xdmf public/var/data/simulations/canic_case3/50/pressure.xdmf \
  --displacement-xdmf public/var/data/simulations/canic_case3/50/displace.xdmf \
  --case-id sev50 \
  --target-time 1.4995 \
  --output-dir tmp/simulations/output/visualization/canic_case3 \
  --overwrite
```

Production-directory mode discovers `snapshot_outputs`,
`snapshot_manifest.csv`, `snapshot-t*` directories, or a direct fallback bundle
and defaults to temporal schema v2:

```sh
pipenv run ops-experiment visualization export-web \
  --input-production-dir tmp/simulations/output/native-resolved-fsi-production/sev23 \
  --case-id sev23 \
  --snapshot-stride 1 \
  --max-snapshots 24 \
  --output-dir tmp/simulations/output/visualization/sev23 \
  --overwrite
```

The command prints `manifest_json`, `asset_count`, `frame_count`,
`skipped_snapshots`, and `estimated_playback_fps`. See
`public/docs/stenotic-hemodynamics/web-visualization.md` for the schema and
viewer contract.

## Canic 2024 Section 4.1 Source-Artifact Comparison

Use `canic-replication section41` for the article-level Section 4.1
source-artifact comparison workflow. It runs the local `canic-extended-1d` and
`classical-parabolic-1d` models, compares them with optional upstream 3D
velocity/pressure/displacement bundles for cases `77`, `60`, and `50`, writes a
parameter audit, and records raw-input provenance.

Clean-clone skip check:

```sh
packages/stenotic-hemodynamics/bin/stenotic-hemodynamics canic-replication section41 \
  --data-root /tmp/missing-canic-section41
```

Full source-artifact comparison after restoring raw inputs:

```sh
packages/stenotic-hemodynamics/bin/stenotic-hemodynamics canic-replication section41 \
  --data-root public/var/data/simulations/canic_case3 \
  --output-dir tmp/simulations/output/canic-replication/section41 \
  --coordinate-mode deformed \
  --nx 100 \
  --dt 1e-5 \
  --section-count 200 \
  --radial-sample-count 41 \
  --overwrite
```

By default, each local solve targets the imported XDMF time for that case,
including `1.4995 s` for severity 50. Supplying a mismatched global `--tfinal`,
such as `1.0` s against the severity-50 bundle, records an intentional
time-mismatch non-replication row. Pressure discrepancy values use the common
Section 4.1 outlet-gauge diagnostic: imported
`CrossSectionQuadratureOperator` mean pressure at `z = 6 cm` and the
corresponding 1D diagnostic outlet pressure are subtracted before comparison.
Those pressure values remain diagnostics, not clinical validation, FFR evidence,
paper-grade native FSI reproduction, or full replication evidence.

See `public/docs/stenotic-hemodynamics/canic-2024-replication.md` for raw-data
restoration, outputs, provenance, and manuscript claim boundaries.

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
- Use `public/docs/stenotic-hemodynamics/web-visualization.md` for browser
  visualization export and viewer checks.
- Use `public/docs/resolved3d-workflows.md` for optional resolved-3D data.
- Use `public/docs/benchmark-pipeline.md` for package benchmark outputs.
