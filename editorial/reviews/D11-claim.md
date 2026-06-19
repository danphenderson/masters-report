# D11 Claim Audit

No blocking claim findings in the current second-revision D11 patch.

Review basis:

- Current checkout confirmed at `fc62416703f26406424376d628829e776b7a47d7`.
- `git apply --check editorial/patches/D11.diff` succeeds.
- Scope checked against `editorial/canonical_rq_answers.md`,
  `claim_evidence_ledger.yaml`, `editorial/claim_evidence_ledger.yaml`,
  `editorial/terminology_ledger.yaml`, `editorial/section_plan.yaml`,
  `sections/03-methodology/index.tex`, and
  `appendices/numerical-methods-details.tex`.

Findings:

- The C23/C40 comparison boundary is acceptable. The revised paragraph calls the
  study a "diagnostic cross-model velocity comparison" and states that the
  section and radial quantities are descriptive discrepancies, not validation,
  accuracy, pressure-drop, FFR, physiological, clinical, predictive, or causal
  evidence (`editorial/patches/D11.diff:653-663`). This matches the canonical
  RQ3 and contribution boundary (`editorial/canonical_rq_answers.md:19-27`) and
  the claim ledger's C-COMPARISON/C-LIMITS limits
  (`editorial/claim_evidence_ledger.yaml:48-60`).
- The rest-state failure remains prominent enough for a methodology patch. The
  new rest-state proposition is explicitly continuous
  (`editorial/patches/D11.diff:432-438`) and is followed immediately by the
  limitation that the current MUSCL/Rusanov realization exhibits the reported
  non-well-balanced geometry-rest drift
  (`editorial/patches/D11.diff:458-460`). Appendix G still denies a
  machine-precision discrete rest-state claim for the displayed operator
  (`appendices/numerical-methods-details.tex:377-385`).
- The DG range clarification does not broaden the thesis claim. The D11 main
  narrative says only the MUSCL/Rusanov/SSPRK3 realization is principal and moves
  other finite-volume, modal-DG, native-stepper, and SciML surfaces to
  implementation-check or sensitivity context
  (`editorial/patches/D11.diff:615-627`). The inserted Appendix G table states
  DG support through `p=4`, while saying descriptor-health/package-benchmark rows
  may exercise only `p=0,1,2`, p-refinement runs through `p=4`, and all such rows
  are appendix context, not the principal C23/C40 method
  (`editorial/patches/D11.diff:708-756`). That is bounded to the flag in the
  terminology and numerical ledgers (`editorial/terminology_ledger.yaml:87-90`;
  `editorial/numerical_ledger.yaml:356-364`).
- Cross-model "error" terminology is corrected in the D11 scope. The metric text
  changes empirical sample "errors" to "discrepancies" and "discrepancy norms"
  (`editorial/patches/D11.diff:691-696`), satisfying the terminology ledger rule
  for 1D-3D comparisons (`editorial/terminology_ledger.yaml:5-14`).
- Unmatched 3D conditions are not presented as resolved. The revised material row
  says only that material-parameter matching is not established
  (`editorial/patches/D11.diff:667-672`), while the retained matrix keeps wall,
  initial condition, inlet/outlet, time/history, and numerical resolution behind
  unmatched, unknown, or unresolved statuses in the current source
  (`sections/03-methodology/index.tex:312-359`). This stays inside the section
  plan's instruction not to infer unresolved 3D metadata
  (`editorial/section_plan.yaml:43-55`).
- Source-paper, pressure, FFR, and clinical/physiological scope remain bounded.
  The source-to-implementation paragraph continues to frame the solver as a
  documented Canic-derived implementation rather than source-paper fidelity
  (`editorial/patches/D11.diff:465-483`), and the comparison-boundary paragraph
  explicitly negates pressure-drop, FFR, physiological, clinical, predictive,
  and causal readings (`editorial/patches/D11.diff:659-663`).

STATUS: PASS
PROHIBITED CLAIMS: 0
TERMINOLOGY VIOLATIONS: 0
UNSUPPORTED INFERENCES: 0
