# D13 Writer Notes

Status: ready for audit.

Scope completed:

- Prepared a patch proposal for Chapter 5 in `sections/02-comparison/index.tex`.
- Proposed a Section 3.11 metric-definition update in `sections/03-methodology/index.tex`.
- Proposed directly dependent discussion/conclusion wording updates in `sections/03-conclusions/index.tex`.
- Did not edit manuscript source files, ledgers, run state, generated assets, or prior review files.

D13 requirements addressed:

- Retitled Chapter 5 to `Diagnostic 1D-3D Velocity Comparison`.
- Reordered the chapter as: available data/matching limits, observation operator, cut-area audit, axial physical-flow behavior, section-mean velocity discrepancies, radial-profile discrepancies, and interpretation limits.
- Reframed `E_u`/`E_Q` prose and table notation as discrepancy measures: signed mean bias, mean absolute discrepancy, RMS discrepancy, maximum absolute discrepancy/location, and relative RMS discrepancy.
- Moved unresolved 3D axial-flow variation before velocity interpretation and retained the `1.0` s versus `0.9995` s offset.
- Stated that flow/area decomposition is bookkeeping rather than causal attribution.
- Kept current/deformed geometry, displacement, wall, boundary, material, and history limits unresolved.
- Withheld the radial-profile numeric table from the main chapter pending reconciliation of the radial-summary conflict.
- Updated downstream discussion/conclusion prose from obsolete Lp metric wording to D13 discrepancy metrics.
- Preserved figures, citation keys, generated data assets, and unchanged retained table values; corrected signed-bias table cells and intentionally removed the main radial-summary table label from the proposed Chapter 5 path.

Word count:

- Before: 2309
- After: 2590
- Change: +281

Validation run:

- `jq empty editorial/patches/D13.patch.json`
- `git apply --check editorial/patches/D13.diff`
- Control-byte scan over `editorial/patches/D13.diff` and `editorial/patches/D13.patch.json`
- Scratch `git diff --check` after applying the proposed diff
- Scratch worktree apply followed by `latexmk -pdf -interaction=nonstopmode -halt-on-error -outdir=/tmp/masters-report-D13-revision-check final-report.tex`
- `git diff -- sections/02-comparison/index.tex sections/03-methodology/index.tex sections/03-conclusions/index.tex`

Audit notes:

- `claim_evidence_ledger.yaml` and `editorial/claim_evidence_ledger.yaml` are byte-equivalent in the current checkout.
- Corrected signed velocity and physical-flow bias values to 0.480/0.909 cm/s and 0.0472/0.0684 cm$^3$/s while preserving MAD values.
- Regenerated the diff from escaped LaTeX replacement text so `\bar` remains an ASCII backslash sequence, not a control byte.
- Removed the radial-profile numeric table from the proposed main Chapter 5 path; retained only qualitative radial-figure limitation language.
- Tied the alpha/radicand diagnostics table to the subcritical-boundary gate for the paired C23/C40 comparison runs.
- Added D13-dependent discussion/conclusion consistency edits for signed bias, MAD, RMS, relative RMS, and maximum discrepancy wording.
- No integration-blocking open questions are recorded.
