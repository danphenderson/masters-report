# Package Benchmark Pipeline

The package benchmark runs through the Julia package wrapper. The smoke profile
is a deterministic wiring check for reviewers and CI-style validation; the
overnight profile expands the same output schemas to the full benchmark matrix.

## Smoke Benchmark

```bash
packages/julia/bin/stenosis-hemodynamics benchmark \
  --profile smoke \
  --output-dir tmp/simulations/output/package_benchmark/smoke \
  --overwrite
```

## Overnight Benchmark and Report Assets

Use the overnight profile when refreshing report-consumed benchmark tables or
figures. Outputs stay under `tmp/simulations/output/**` unless
`--publish-report-assets` is provided.

```bash
packages/julia/bin/stenosis-hemodynamics benchmark \
  --profile overnight \
  --output-dir tmp/simulations/output/package_benchmark/overnight-YYYYMMDD \
  --overwrite \
  --include-resolved3d \
  --publish-report-assets

pipenv run ops-render-package-benchmark-figures \
  --benchmark-dir tmp/simulations/output/package_benchmark/overnight-YYYYMMDD
```

## Output Schema

The benchmark writes `manifest.json`, `case_results.csv`, `refinement.csv`,
`backend_parity.csv`, `stokes_ic.csv`, `rheology_profile.csv`,
`boundary_openbf.csv`, and `resolved3d.csv`.

Optional resolved-3D inputs under `public/var/data/simulations/canic_case3/` produce
skipped rows in `resolved3d.csv` when absent rather than crashing the benchmark.
Published report assets copied into `report/assets/**` should be
refreshed only when the current TeX source consumes them.
