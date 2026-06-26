# Resolved-3D Workflows

Resolved-3D workflows consume the tracked Canic case3 XDMF/HDF5 inputs for cases
`50`, `60`, and `77`. Missing explicit data roots must still produce skipped
evidence or skipped commands, not false failures.

A clean public clone can rebuild the manuscript from tracked derived report
assets, regenerate raw-data-dependent comparison assets for the retained Canic
case3 inputs, and run the missing-input skip check below against an explicit
absent root.

For the broader `StenoticHemodynamics` workflow map, including native
resolved-FSI planning notes that stay inside package-owned schema/parity lanes,
use `public/docs/markdown/stenotic-hemodynamics/workflows.md`.

## Tracked Data Root

The default tracked data root is:

```text
public/var/data/simulations/canic_case3/
```

Expected tracked case files include:

```text
public/var/data/simulations/canic_case3/77/velocity.xdmf
public/var/data/simulations/canic_case3/77/velocity.h5
public/var/data/simulations/canic_case3/77/pressure.xdmf
public/var/data/simulations/canic_case3/77/pressure.h5
public/var/data/simulations/canic_case3/77/displace.xdmf
public/var/data/simulations/canic_case3/77/displace.h5
public/var/data/simulations/canic_case3/60/velocity.xdmf
public/var/data/simulations/canic_case3/60/velocity.h5
public/var/data/simulations/canic_case3/60/pressure.xdmf
public/var/data/simulations/canic_case3/60/pressure.h5
public/var/data/simulations/canic_case3/60/displace.xdmf
public/var/data/simulations/canic_case3/60/displace.h5
public/var/data/simulations/canic_case3/50/velocity.xdmf
public/var/data/simulations/canic_case3/50/velocity.h5
public/var/data/simulations/canic_case3/50/pressure.xdmf
public/var/data/simulations/canic_case3/50/pressure.h5
public/var/data/simulations/canic_case3/50/displace.xdmf
public/var/data/simulations/canic_case3/50/displace.h5
```

Keep other raw resolved-3D files ignored. The tracked Canic case3 files are
source-data inputs, not `report/assets/**` files, and are bounded by the
provenance and checksum record in
`report/assets/data/canic-replication/canic-section41-provenance.json`. For
local handoff checks, generate scratch checksum lists under `/tmp`, such as
`/tmp/raw-3d-inputs-files.txt` and `/tmp/raw-3d-inputs-sha256.txt`; do not
commit those scratch audits.

## Comparison Workflow

Run the default comparison against the tracked Canic data root:

```sh
packages/stenotic-hemodynamics/bin/stenotic-hemodynamics compare-3d \
  --target-time 0.9995 \
  --time-atol 1e-6 \
  --overwrite
```

The command prints `compare_3d_status,skipped_missing_data` when the selected
data root is missing required inputs. Treat that as an expected skip for
explicit missing-root validation. The explicit skip check is:

```sh
packages/stenotic-hemodynamics/bin/stenotic-hemodynamics compare-3d \
  --data-root /tmp/missing-resolved3d \
  --target-time 0.9995 \
  --time-atol 1e-6
```

Use `--coordinate-mode deformed` only when displacement companions are present.
The retained report assets now include both reference-coordinate and
deformed-coordinate plane cuts for the two principal cases.

Use `--publish-report-assets` only when the task intentionally promotes outputs
into `report/assets/data/stenosis-comparison/**`:

```sh
packages/stenotic-hemodynamics/bin/stenotic-hemodynamics compare-3d \
  --data-root public/var/data/simulations/canic_case3 \
  --output-dir tmp/simulations/output/3d_comparison/reference_wall_evidence_nx400 \
  --nx 400 \
  --space fv-wb-geometry-rest \
  --coordinate-mode reference \
  --target-time 0.9995 \
  --time-atol 1e-6 \
  --section-count 200 \
  --profile-slices 1.951,2.451,2.951 \
  --radial-bin-counts 20 \
  --radial-radius-modes current,reference \
  --overwrite \
  --publish-report-assets \
  --report-assets-dir report/assets/data/stenosis-comparison
```

Run a second publish command with `--coordinate-mode deformed` and a distinct
scratch `--output-dir` to refresh the displacement-aware assets without
clobbering the reference-coordinate files.

After publishing report assets, regenerate the compact tracked table fragments
from the tracked data assets:

```sh
pipenv run ops-render-resolved3d-comparison-tables
```

Then run a validation-only report build.

## Command Matrix

| Block | Command | Raw 3D inputs? | Published outputs |
| --- | --- | --- | --- |
| Reference-coordinate comparison | `compare-3d --space fv-wb-geometry-rest --coordinate-mode reference --publish-report-assets --report-assets-dir report/assets/data/stenosis-comparison` with `--target-time 0.9995`, `--time-atol 1e-6`, `--nx 400`, `--section-count 200`, `--profile-slices 1.951,2.451,2.951`, `--radial-bin-counts 20`, and `--radial-radius-modes current,reference` | Yes | Reference suffixed data assets plus legacy unsuffixed compatibility copies. |
| Deformed-coordinate comparison | Same command with `--coordinate-mode deformed` and a distinct scratch `--output-dir` | Yes, including displacement companions | Deformed suffixed data assets. |
| Table fragments | `pipenv run ops-render-resolved3d-comparison-tables` | No | `coordinate_mode_comparison.tex` and `radial_profile_audit.tex` from tracked data assets. |
| Operator validation | `operator-validation` with explicit `--summary-csv` and `--summary-tex` paths | No | Synthetic operator CSV and TeX table. |
| Grid sensitivity | `compare-3d --nxs 200,400,800,1600,3200` with explicit grid summary CSV/TeX paths | Yes | Grid-sensitivity CSV and TeX table retaining N=200,400,800,1600,3200 at T=0.9995 s. |

## Published Comparison Assets

`compare-3d --publish-report-assets` writes these tracked data files under
`report/assets/data/stenosis-comparison/`:

| Artifact | Source | Role |
| --- | --- | --- |
| `section-quadrature-reference.dat`, `section-quadrature-deformed.dat`, `section-quadrature.dat` | Reference/deformed comparison runs; unsuffixed file is the reference compatibility copy. | Section-wise 1D/3D velocity and physical-flow curves consumed by TikZ and table rendering. |
| `area-audit-reference.dat`, `area-audit-deformed.dat`, `area-audit.dat` | Reference/deformed comparison runs; unsuffixed file is the reference compatibility copy. | Static section-area closure checks. |
| `production-diagnostics-reference.dat`, `production-diagnostics-deformed.dat`, `production-diagnostics.dat` | Reference/deformed comparison runs; unsuffixed file is the reference compatibility copy. | Production-grid run diagnostics consumed by the case-study verification text. |
| `node-slab-sensitivity-reference.csv`, `node-slab-sensitivity-deformed.csv`, `node-slab-sensitivity.csv` | Reference/deformed comparison runs; unsuffixed file is the reference compatibility copy. | Supplemental node-slab sensitivity rows. |
| `radial-profile-audit-reference.csv`, `radial-profile-audit-deformed.csv` | Reference/deformed comparison runs. | Supplemental radial-profile audit inputs; not main comparison evidence. |
| `cross-section-operator-validation.csv` | `operator-validation`. | Synthetic quadrature validation data. |
| `grid-sensitivity-summary.csv` | Grid-sensitivity comparison. | Output-sensitivity rows for the retained comparison protocol. |

Published comparison and sensitivity rows carry the spatial method string
(`spatial_method`) and preserve the imported C23 severity
(`22.555555555555554`) in source CSV metadata; tables may display it as
`C23 (22.56%)`.

The tracked TeX fragments under `report/assets/tables/stenosis-comparison/`
are:

| Artifact | Regeneration command | Role |
| --- | --- | --- |
| `coordinate_mode_comparison.tex` | `pipenv run ops-render-resolved3d-comparison-tables` | Compact reference/deformed discrepancy table. |
| `radial_profile_audit.tex` | `pipenv run ops-render-resolved3d-comparison-tables` | Supplemental radial-profile audit summary. |
| `cross_section_operator_validation.tex` | `operator-validation --summary-tex ...` | Synthetic operator-validation table. |
| `grid_sensitivity_summary.tex` | `compare-3d --grid-summary-tex ...` | Grid-sensitivity appendix table. |

## Grid Sensitivity

Run grid sensitivity with explicit grid sizes:

```sh
packages/stenotic-hemodynamics/bin/stenotic-hemodynamics compare-3d \
  --data-root public/var/data/simulations/canic_case3 \
  --output-dir tmp/simulations/output/3d_comparison/grid_sensitivity_severity23_severity40 \
  --nxs 200,400,800,1600,3200 \
  --space fv-wb-geometry-rest \
  --target-time 0.9995 \
  --time-atol 1e-3 \
  --case-workers 2 \
  --solver-threads 4 \
  --section-count 200 \
  --radial-bins 20 \
  --no-svg \
  --overwrite \
  --grid-summary-csv report/assets/data/stenosis-comparison/grid-sensitivity-summary.csv \
  --grid-summary-tex report/assets/tables/stenosis-comparison/grid_sensitivity_summary.tex
```

`--case-workers` controls process-level case parallelism; `0` forces serial
case execution, while values greater than `1` run cases through distributed
workers. `--solver-threads` sets `NativeRK3Backend(solver_threads=N)` for each
case. Spawned compare-3D workers start with exactly `N` Julia threads; direct
local solves require the current Julia process to have exactly `N` threads and
throw instead of silently using more threads than requested. Keep the two budgets
separate (for example, two case workers with four solver threads each) and run a
bounded probe on a small `--nxs` subset before using the setting for fine grids:

```sh
packages/stenotic-hemodynamics/bin/stenotic-hemodynamics compare-3d \
  --data-root public/var/data/simulations/canic_case3 \
  --output-dir tmp/simulations/output/3d_comparison/grid_sensitivity_thread_probe \
  --nxs 200,400 \
  --case-workers 1 \
  --solver-threads 2 \
  --target-time 0.9995 \
  --no-svg \
  --overwrite
```

The comparison summaries record elapsed time, case-worker count, solver-thread
count, Julia thread count, and process id for runtime provenance; these probes
are performance checks, not resolved-FSI reproduction or production validation
evidence.

Use `--reuse-grid-summary` when the task needs to reformat or republish an
already reviewed summary without rerunning the full comparison:

```sh
packages/stenotic-hemodynamics/bin/stenotic-hemodynamics compare-3d \
  --nxs 200,400,800,1600,3200 \
  --reuse-grid-summary tmp/simulations/output/3d_comparison/grid_sensitivity_severity23_severity40/grid_sensitivity_summary.csv \
  --grid-summary-csv report/assets/data/stenosis-comparison/grid-sensitivity-summary.csv \
  --grid-summary-tex report/assets/tables/stenosis-comparison/grid_sensitivity_summary.tex \
  --overwrite
```

Do not treat grid sensitivity as physical validation. It is output sensitivity
for the declared comparison workflow.

## Membrane-FSI Workflow

Run the membrane-FSI workflow when the task needs a Canic-style coupled-wall
comparator generated by the package:

```sh
packages/stenotic-hemodynamics/bin/stenotic-hemodynamics fsi validate \
  --wall-mode quasi-static \
  --severities 23,40 \
  --meshes 8x2x8,16x4x16 \
  --parallel-workers 0 \
  --output-dir tmp/simulations/output/membrane_fsi_validation \
  --publish-report-assets \
  --report-assets-dir report/assets \
  --overwrite
```

The workflow writes a summary CSV, a TeX fragment, per-case wall profiles, a
per-case history CSV, and a manifest under the output directory. With
`--publish-report-assets`, it also writes the retained table and plot data under
`report/assets/data/membrane-fsi/` and `report/assets/tables/membrane-fsi/`.
Dynamic wall mode is a reduced radial membrane time integrator coupled to repeated
quasi-steady Stokes solves; it is not a transient moving-boundary fluid solve.
The default profile is the Canic stenosis geometry, but package-level runs can
set `geometry_id` and `reference_radius_at_z` on `MembraneFSIValidationSpec` for
other positive sufficiently smooth vessel radius profiles.

## Operator Validation

Run synthetic cross-section operator validation when operator evidence or report
tables are in scope:

```sh
packages/stenotic-hemodynamics/bin/stenotic-hemodynamics operator-validation \
  --output-dir tmp/simulations/output/operator_validation \
  --overwrite
```

Publish to report assets only with explicit paths:

```sh
packages/stenotic-hemodynamics/bin/stenotic-hemodynamics operator-validation \
  --output-dir report/assets/tables/stenosis-comparison \
  --summary-csv report/assets/data/stenosis-comparison/cross-section-operator-validation.csv \
  --summary-tex report/assets/tables/stenosis-comparison/cross_section_operator_validation.tex \
  --overwrite
```

## Resolved Flow Rendering

Use `export-assets` and the geometry renderer for resolved envelopes and
resolved velocity field figures:

```sh
packages/stenotic-hemodynamics/bin/stenotic-hemodynamics export-assets --overwrite
pipenv run ops-render-stenosis-geometry-figures
```

The renderer skips resolved-flow figures when no complete resolved velocity node
CSV set is present. Treat skipped renders as expected when the figure-refresh
lane has not generated or retained those intermediate CSV inputs.

## Publication Boundaries

- Track only the approved Canic case3 XDMF/HDF5 input bundle under
  `public/var/data/simulations/canic_case3/**`; keep any additional raw
  resolved-3D inputs ignored unless a separate data-release policy approves
  them.
- Do not publish report assets unless the current TeX source consumes them.
- Treat radial-profile audit rows as supplemental reproducibility artifacts,
  not promoted localization evidence.
- Do not refresh `public/final-report.pdf` unless release publication is
  explicitly in scope.
- Record skipped explicit missing roots or unavailable additional inputs in
  handbacks and PR summaries.

## Related Policies

- Use `public/reproducibility/release-manifest.json` for the retained
  release-provenance pointer to the raw-input convention, final PDF hash, and
  validation-only report build command.
- Use `public/docs/markdown/artifact-policy.md` before moving or publishing artifacts.
- Use `public/docs/markdown/report-assets-and-provenance.md` for asset ownership.
- Use `public/docs/markdown/stenotic-hemodynamics/workflows.md` for the package workflow
  map and links to the native resolved-FSI design/reproduction notes.
- Use `public/docs/markdown/julia-cli-workflows.md` for general Julia command usage.
- Use `public/docs/markdown/report-builds.md` after publishing report-consumed assets.
