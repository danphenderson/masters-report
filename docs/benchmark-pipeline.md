# Package Benchmark Pipeline

The package benchmark runs through the Julia package wrapper. The smoke profile
is a deterministic wiring check for reviewers and CI-style validation; the
overnight profile expands the same output schemas to the full benchmark matrix.

## Smoke Benchmark

```bash
bin/stenosis-hemodynamics benchmark \
  --profile smoke \
  --output-dir julia/simulations/output/package_benchmark/smoke \
  --overwrite
```

## Overnight Benchmark and Report Assets

Use the overnight profile when refreshing report-consumed benchmark tables or
figures. Outputs stay under `julia/simulations/output/**` unless
`--publish-report-assets` is provided.

```bash
bin/stenosis-hemodynamics benchmark \
  --profile overnight \
  --output-dir julia/simulations/output/package_benchmark/overnight-YYYYMMDD \
  --overwrite \
  --include-resolved3d \
  --publish-report-assets

PIPENV_PIPFILE=tools/python/Pipfile pipenv run python tools/python/scripts/render_package_benchmark_figures.py \
  --benchmark-dir julia/simulations/output/package_benchmark/overnight-YYYYMMDD
```

## Output Schema

The benchmark writes `manifest.json`, `case_results.csv`, `refinement.csv`,
`backend_parity.csv`, `stokes_ic.csv`, `rheology_profile.csv`,
`boundary_openbf.csv`, and `resolved3d.csv`.

Optional resolved-3D inputs under `julia/simulations/data/3d/canic_case3/` produce
skipped rows in `resolved3d.csv` when absent rather than crashing the benchmark.
Published report assets copied into `report/assets/**` should be
refreshed only when the current TeX source consumes them.
