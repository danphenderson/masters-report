# D02 Claim-Lock Report

## Scope

- Dispatch: D02-CLAIM-LOCK
- Role: Evidence Custodian
- Manuscript source mode: read-only
- Source commit: `371ba631f7cb24a3463e4923696218304bc6ff09`
- Branch: `master`

## Inputs Checked

Required editorial claim-lock inputs:

- `editorial/canonical_rq_answers.md`: missing
- `editorial/claim_evidence_ledger.yaml`: missing

Available but not accepted as the dispatch target:

- `claim_evidence_ledger.yaml`: present at repo root, ignored by `.gitignore`

Because the author-approved canonical RQ file and the editorial claim ledger are absent, D02 cannot complete claim lock. The numerical and terminology ledgers were still created from the manuscript source, generated tables, figure data, and baseline PDF so the next dispatch has a concrete audit basis.

## Validation Summary

Supported numerical anchors were found for:

- `Aphys = pi*a`, `Qphys = pi*q`, and `uavg = q/a = Qphys/Aphys`
- `qcomp = 2.288/pi = 0.7283 cm^3/s`
- C23 and C40 rest-state peak values on the finest grid
- C23 and C40 rest-state values at `t=1.0 s` and corresponding `pi*q` physical-flow values
- final section-velocity metrics in the C23/C40 comparison summary
- maximum section discrepancies and locations
- axial 3D-flow variation percentages
- 1D and 3D sample times and `0.0005 s` offset
- active grid, timestep cap, CFL cap, MUSCL/minmod/Rusanov method, and native SSPRK3 integrator

## Unsupported Claims

No specific claim text from the available root claim draft was found to require broadening beyond the manuscript evidence. However, this is not a passed claim lock because the dispatch-required approved files are missing from `editorial/`.

## Numerical Conflicts

One numerical conflict was flagged:

1. The retained radial-profile summary table in `sections/02-comparison/index.tex` does not match direct equal-bin recomputation from `radial-quadrature-C23.dat` and `radial-quadrature-C40.dat` for several rows. Example: C23 at `z=1.951 cm` is listed as MAE/RMSE/max `0.493/0.614/1.34 cm/s`, while direct recomputation from the tracked radial data gives approximately `0.5299/0.6531/1.5669 cm/s`. This was flagged only; no source was changed.

The final section-velocity summary and maximum-discrepancy values were recomputed from `section-quadrature.dat` and matched the manuscript after rounding.

## Terminology Conflicts

The terminology ledger requires `discrepancy` for 1D-3D comparisons and reserves `error` for MMS, exact-solution, or accepted-reference contexts. Remaining 1D-3D comparison uses of `error` were flagged in:

- `sections/02-comparison/index.tex:139-142`
- `sections/03-methodology/index.tex:421-424`
- `sections/03-conclusions/index.tex:35-37`
- `sections/03-conclusions/index.tex:151-155`

No terminology was changed.

## Unresolved Gates

Flagged without resolution:

1. `p=0,1,2` versus `p=0,...,4` for DG support and p-refinement reporting.
2. Current versus reference 3D geometry status.
3. Whether displacement must be applied before plane cuts.
4. Missing or incomplete 3D boundary, wall, rheology, material, and history metadata.
5. Whether exact `0.9995 s` 1D resampling is available.

## Output Files

- `editorial/numerical_ledger.yaml`
- `editorial/terminology_ledger.yaml`
- `editorial/reviews/D02-claim-lock-report.md`

STATUS: REVISE
UNSUPPORTED CLAIMS: 0
NUMERICAL CONFLICTS: 1
UNRESOLVED GATES: 5
