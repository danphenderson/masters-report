# Package Benchmark Pipeline

Run package benchmarks through the Julia package wrapper. Use the smoke profile
for wiring checks and reviewer validation. Use the overnight profile only when
refreshing the full benchmark matrix or report-consumed benchmark assets.

Read `public/docs/artifact-policy.md` before publishing benchmark outputs into
`report/assets/**`. Use `public/docs/policy-vocabulary.md` for shared artifact
and build vocabulary.

## Profile Selection

Use `--profile smoke` when checking CLI wiring, schema emission, or CI-style
review readiness.

```sh
packages/julia/bin/stenosis-hemodynamics benchmark \
  --profile smoke \
  --output-dir tmp/simulations/output/package_benchmark/smoke \
  --overwrite
```

Use `--profile overnight` when refreshing benchmark evidence, report-consumed
tables, or report-consumed figures. Do not publish report assets unless the
current TeX source consumes them and the task explicitly authorizes
artifact-refresh scope.

```sh
packages/julia/bin/stenosis-hemodynamics benchmark \
  --profile overnight \
  --output-dir tmp/simulations/output/package_benchmark/overnight-YYYYMMDD \
  --overwrite \
  --include-resolved3d \
  --publish-report-assets
```

Keep ordinary run outputs under `tmp/simulations/output/**`. The benchmark
copies CSVs and `manifest.json` into `report/assets/data/package-benchmark/`
only when `--publish-report-assets` is present.

## Post-Run Checks

After each benchmark run, inspect `manifest.json` as the provenance anchor. It
records the package, profile, output directory, UTC timestamp, Git SHA, Julia
version, resolved-3D inclusion flag, report-asset publication flag, command, and
output hashes.

Treat these files as required after a successful run:

- `case_results.csv`: per-case descriptor and completion status rows.
- `refinement.csv`: refinement-study rows.
- `backend_parity.csv`: backend-comparison rows.
- `stokes_ic.csv`: stationary Stokes initial-condition rows.
- `rheology_profile.csv`: rheology-profile rows.
- `boundary_openbf.csv`: boundary/OpenBF compatibility rows.
- `resolved3d.csv`: completed, errored, or deliberately skipped resolved-3D
  rows.
- `manifest.json`: run provenance and output hash record.

Treat missing required files as benchmark failure. Treat absent optional
resolved-3D inputs under `public/var/data/simulations/canic_case3/` as skipped
evidence rows in `resolved3d.csv`, not as failed execution.

## Report Asset Publication

Use `--publish-report-assets` only when benchmark outputs are intentionally
being promoted into `report/assets/**`.

After publishing benchmark data, render the report figures and summary table
only when those assets are in scope:

```sh
pipenv run ops-render-package-benchmark-figures \
  --benchmark-dir tmp/simulations/output/package_benchmark/overnight-YYYYMMDD
```

Then run a validation-only report build:

```sh
pipenv run ops-build-report --outdir /tmp/masters-report-build --no-sync-final-pdf
```

Use the full report build only when refreshing `public/final-report.pdf` is
explicitly in scope:

```sh
pipenv run ops-build-report --outdir /tmp/masters-report-build
```

Do not combine benchmark generation, rendered-asset publication, and release-PDF
refresh unless the task explicitly opens all three scopes.

## Related Policies

- Use `public/docs/policy-vocabulary.md` for shared terms and modal verbs.
- Use `public/docs/artifact-policy.md` before moving, deleting, regenerating, or
  publishing artifacts.
- Use `public/docs/agent-workflows.md` for bounded handoffs involving benchmark
  review or artifact refresh.
- Use `public/docs/publication-readiness.md` before publishing a release PDF or
  public source export.
