# D13 Adversarial Review

Dispatch: D13-ADV
Mode: Review only

## Inputs Reviewed

- `editorial/patches/D13.patch.json`
- `editorial/patches/D13.diff`
- `editorial/canonical_rq_answers.md`
- `editorial/claim_evidence_ledger.yaml`
- `claim_evidence_ledger.yaml`
- `editorial/numerical_ledger.yaml`
- `editorial/terminology_ledger.yaml`
- `editorial/section_plan.yaml`
- Current Chapter 5 source: `sections/02-comparison/index.tex`
- Current Section 3.11 source: `sections/03-methodology/index.tex`
- Current discussion/conclusion source: `sections/03-conclusions/index.tex`
- Dependent comparison data under `figures/static/static/data/stenosis-comparison/`
- Dependent resolved-3D summary data in `figures/static/static/data/package-benchmark/resolved3d.csv`
- Dependent radial-profile figure source: `figures/static/static/tikz/radial-profile-comparison.tex`

## Checks

- `git apply --check editorial/patches/D13.diff` succeeds against current `HEAD` `263b4a9`.
- `git apply --stat editorial/patches/D13.diff` reports three proposed source changes: `sections/02-comparison/index.tex`, `sections/03-methodology/index.tex`, and `sections/03-conclusions/index.tex`.
- `editorial/claim_evidence_ledger.yaml` and root `claim_evidence_ledger.yaml` are byte-equivalent; both have SHA-256 `40eab1f8c3b2086fe94641e5ca92ce21aca6e1723f7fcce625282c41a24706c8`.
- No unsafe control bytes were found in `editorial/patches/D13.diff` or `editorial/patches/D13.patch.json`.
- Direct recomputation from `section-quadrature.dat` supports the D13 signed-bias and discrepancy values:
  - C23: signed velocity bias `0.479760...`, mean absolute velocity discrepancy `0.504899...`, RMS `0.663679...`, relative RMS `0.027717...`, signed flow bias `0.047165...`, mean absolute flow discrepancy `0.048219...`, 3D axial-flow variation `7.7228%`.
  - C40: signed velocity bias `0.908565...`, mean absolute velocity discrepancy `0.966027...`, RMS `1.868373...`, relative RMS `0.068809...`, signed flow bias `0.068377...`, mean absolute flow discrepancy `0.070870...`, 3D axial-flow variation `20.2162%`.

## Adversarial Answers

The principal claim is unmistakable. The proposed Chapter 5 title and opening make the section a diagnostic 1D-3D velocity and physical-flow comparison under a declared quadrature operator, not a validation or accuracy study.

The rest-state defect is proportionately prominent. It appears in the first paragraph of Chapter 5 as a limitation of the same order as the comparison-flow scale at `t=1 s`, before any C23/C40 interpretation.

I do not see a sentence in the proposed Chapter 5, Section 3.11, discussion, or conclusion text that would reasonably be mistaken for validation, pressure/FFR accuracy, physiological, clinical, predictive, or causal evidence. The remaining uses of validation and accuracy language are negations, scope boundaries, or future-study caveats.

Unmatched conditions are disclosed before interpretation. The proposed first subsection states the `1.0 s` versus `0.9995 s` offset, unresolved current/deformed 3D geometry status, possible displacement-application issue, and unpersisted 3D wall, motion-history, inlet/outlet, material, and transient-history metadata before the velocity-result subsections.

The section answers RQ3. It defines the observation operator, reports section-mean velocity and physical-flow discrepancies against the available resolved 3D data, and states which unmatched conditions limit interpretation.

I do not see retained background that is merely correct rather than necessary. The subcritical-boundary diagnostic table is tied to the paired C23/C40 comparison runs and explicitly bounded so it does not widen the velocity-comparison claim.

The discrepancy metrics are understandable without implying accuracy. Section 3.11 replaces `E_{u,p}` / `E_{Q,p}` and cross-model `L^1`/`L^2`/`L^3` error language with signed bias, mean absolute discrepancy, RMS discrepancy, maximum discrepancy, and relative RMS discrepancy.

Signed-bias and mean-absolute-discrepancy values are not conflated. The proposed table and prose separate `\overline d_u` from `D_{u,1}` and `\overline d_Q` from `D_{Q,1}`, and the values match the tracked section data after rounding.

The flow/area decomposition is clearly bookkeeping rather than causation. Both the surrounding prose and table caption say the split is bookkeeping and not causal attribution.

Unresolved axial 3D-flow variation appears early enough. The 7.7% and 20.2% values are introduced in the new axial-flow subsection before section-mean velocity interpretation and are framed as an unresolved matching gate.

The current/deformed geometry and sample-time limitations are honest. The static cut-area audit is not promoted into resolved current/deformed geometry evidence, and the `5\times10^{-4}` s time offset is reported rather than eliminated.

The conflicted radial-profile numeric table is withheld sufficiently. D13 removes `tab:t1-radial-profile-summary` from the main chapter, states that direct equal-bin recomputation has not been reconciled with the existing radial-summary values, and makes no radial-bin numerical localization claim. The retained radial figure reads directly from the tracked radial-quadrature data and is described only as a qualitative secondary diagnostic.

The downstream discussion/conclusion paragraphs are consistent with D13 metrics. The proposed discussion and conclusion use signed bias, mean absolute discrepancy, RMS discrepancy, relative RMS discrepancy, and largest section discrepancy; obsolete cross-model `L^1`/`L^2`/`L^3` error wording is removed.

The `current-radius` phrases are safe. In Chapter 5 they become `1D current-radius normalization`, which does not imply that the resolved 3D current/deformed geometry question has been settled.

## Findings

No BLOCKER, MAJOR, or MINOR findings.

STATUS: ACCEPT
BLOCKERS: 0
MAJORS: 0
MINORS: 0
