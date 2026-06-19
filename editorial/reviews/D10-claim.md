# D10 Revised Claim Review

Reviewed the current revised `editorial/patches/D10.patch.json` and
`editorial/patches/D10.diff` against the canonical RQ answers, claim evidence
ledger, terminology ledger, section plan, and current `sections/01-intro/index.tex`.
The previous D10 claim report is superseded.

Findings:

- No prohibited validation, accuracy, clinical, physiological, FFR, predictive,
  or causal claim is introduced. The new report-level guardrail is explicitly
  negative: "The report makes no broader validation, pressure-accuracy, FFR,
  physiological, clinical, predictive, or causal claim"
  (`editorial/patches/D10.diff:51-53`), matching the canonical contribution
  boundary (`editorial/canonical_rq_answers.md:23-27`) and the prohibited
  extensions in the claim ledger (`editorial/claim_evidence_ledger.yaml:5-11`).
- The same-order rest-flow statement is supported. The revised patch states
  that at `t=1` s the artificial flow is the same order as the comparison-flow
  scale and uses that to keep the failure as a principal numerical limitation,
  not a secondary caveat (`editorial/patches/D10.diff:106-111`). This matches
  the canonical RQ2 answer (`editorial/canonical_rq_answers.md:11-15`), C-REST
  (`editorial/claim_evidence_ledger.yaml:35-42`), and the numerical ledger's
  `qcomp` and `t1_N800` rest-state anchors (`editorial/numerical_ledger.yaml:64-72`,
  `editorial/numerical_ledger.yaml:91-119`).
- No cross-model `error` language is introduced. Added comparison language uses
  `discrepancy`, `discrepancies`, or `differences` for C23/C40 quantities
  (`editorial/patches/D10.diff:49`, `editorial/patches/D10.diff:113-117`,
  `editorial/patches/D10.diff:146-148`), consistent with the terminology lock
  (`editorial/terminology_ledger.yaml:5-14`).
- No unsupported causation is introduced. The only explanatory connector in the
  comparison-limit sentence ties interpretation limits to already-declared
  unmatched or unpersisted 3D conditions, axial 3D flow variation, and
  sample-time alignment gates (`editorial/patches/D10.diff:113-117`), matching
  C-LIMITS (`editorial/claim_evidence_ledger.yaml:54-60`) and section-plan
  requirements (`editorial/section_plan.yaml:70-82`).
- The patch does not claim that unmatched 3D conditions have been resolved. It
  explicitly keeps wall, boundary, material, history, current/deformed geometry,
  axial-flow variation, and sample-time alignment as evidential gates
  (`editorial/patches/D10.diff:113-117`).

STATUS: PASS
PROHIBITED CLAIMS: 0
TERMINOLOGY VIOLATIONS: 0
UNSUPPORTED INFERENCES: 0
