# Canic 2024 Section 4.1 Source-Artifact Comparison

This workflow compares local 1D model outputs with source-artifact bundles for
Canic et al. 2024, Section 4.1, using original Julia implementations of the two
1D models in this package and the authors' upstream 3D XDMF/HDF5 bundles as
optional benchmark data. It is separate from the narrower `compare-3d` report
comparator.

The workflow covers:

- Table 1 and Figure 3 case parameters for 23%, 40%, and 50% stenosis;
- Figure 4-style cross-sectional mean axial velocity comparisons;
- Figure 5-style cross-sectional mean pressure comparisons;
- a postprocessed 1D radial-velocity diagnostic;
- a Figure 6-style 3D velocity-field diagnostic summary.

It does not independently regenerate the authors' full 3D FSI benchmark. The
upstream MATLAB and ParaView files are treated as external provenance and
optional comparator material only; GPL-licensed source is not copied into this
MIT-licensed package implementation.

## Raw Data Policy

Raw XDMF/HDF5 inputs remain ignored local data under:

```text
public/var/data/simulations/canic_case3/
```

A clean public clone should print an expected skip:

```sh
packages/stenotic-hemodynamics/bin/stenotic-hemodynamics canic-replication section41 \
  --data-root /tmp/missing-canic-section41
```

Expected output begins with:

```text
canic_replication_status,skipped_missing_data
```

To restore the optional upstream inputs locally:

```sh
git clone https://github.com/qcutexu/Extended-1D-AQ-system.git /tmp/canic-2024
git -C /tmp/canic-2024 checkout 056a9da2b36b480691f18025d242d2c00f6e7180
mkdir -p public/var/data/simulations/canic_case3
for case_id in 77 60 50; do
  mkdir -p "public/var/data/simulations/canic_case3/${case_id}"
  for field in velocity pressure displace; do
    cp "/tmp/canic-2024/case3_all_3d_results/${case_id}/${field}.xdmf" \
      "/tmp/canic-2024/case3_all_3d_results/${case_id}/${field}.h5" \
      "public/var/data/simulations/canic_case3/${case_id}/"
  done
done
```

The pinned upstream commit is:

```text
056a9da2b36b480691f18025d242d2c00f6e7180
```

## Canonical Commands

Full Section 4.1 source-artifact comparison:

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

Publish report-consumed derived assets only when the manuscript lane explicitly
requires them:

```sh
packages/stenotic-hemodynamics/bin/stenotic-hemodynamics canic-replication section41 \
  --data-root public/var/data/simulations/canic_case3 \
  --output-dir tmp/simulations/output/canic-replication/section41 \
  --coordinate-mode deformed \
  --nx 100 \
  --dt 1e-5 \
  --section-count 200 \
  --radial-sample-count 41 \
  --publish-report-assets \
  --report-assets-dir report/assets \
  --overwrite
```

Fast smoke with restored raw inputs:

```sh
packages/stenotic-hemodynamics/bin/stenotic-hemodynamics canic-replication section41 \
  --data-root public/var/data/simulations/canic_case3 \
  --output-dir tmp/simulations/output/canic-replication/smoke \
  --nx 6 \
  --tfinal 0 \
  --section-count 3 \
  --radial-sample-count 5 \
  --models canic-extended-1d \
  --overwrite
```

## Outputs

The scratch output directory contains:

- `canic-section41-provenance.json`;
- `canic-section41-parameter-audit.csv`;
- `canic-section41-comparison.csv`;
- `canic-section41-summary.csv`;
- `canic-section41-radial-velocity.csv`;
- `canic-section41-figure6-diagnostics.csv`;
- `canic-section41-parameter-audit.tex`;
- `canic-section41-summary.tex`.

With `--publish-report-assets`, CSV/JSON files are copied to
`report/assets/data/canic-replication/`, and TeX fragments are copied to
`report/assets/tables/canic-replication/`.

By default, the local 1D solve targets the imported final time recorded for each
case: approximately `0.9995 s` for cases `77` and `60`, and `1.4995 s` for case
`50`. Supplying `--tfinal` is an explicit global override; rows whose override
differs from the imported source-artifact time outside the declared tolerance
are recorded as intentional time mismatches and non-replication.

Pressure values are recorded under a common Section 4.1 outlet-gauge diagnostic:
the workflow subtracts the imported `CrossSectionQuadratureOperator` mean
pressure at `z = 6 cm` and the corresponding 1D diagnostic outlet pressure
before reporting pressure discrepancies. These pressure-error values are
gauge-normalized diagnostics only. They do not establish clinical validation,
FFR evidence, paper-grade native FSI reproduction, or a full Section 4.1
replication claim.

## Required Audit Caveats

The parameter audit intentionally records source inconsistencies instead of
silently normalizing them:

- the PDF Table 1 Young modulus is `5.02e6 dyn/cm^2`, while the upstream MATLAB
  `Variables.m` scripts set `E = 2e4`;
- the upstream 77 and 60 XDMF bundles are at `0.9995 s`, while the upstream 50
  bundle is at `1.4995 s`; the paper text describes the 3D benchmark as
  `T = 1 s`.

Manuscript claims should describe these outputs as source-artifact comparison
unless a scoped lane checks and records reproduction criteria for the relevant
time, coordinate, pressure-gauge, parameter, observable, and tolerance
conventions.
