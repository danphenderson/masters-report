# D10 Writer Notes

Status: ready for audit.

Scope completed:

- Prepared a patch proposal for Sections 1.4-1.7 only in `sections/01-intro/index.tex`.
- Wrote the proposed replacement to `editorial/patches/D10.patch.json`.
- Wrote the proposed unified diff to `editorial/patches/D10.diff`.
- Did not edit manuscript source files.

Claim and terminology handling:

- Uses approved claim IDs only: `C-MODEL`, `C-NUMERICS`, `C-MMS`, `C-REST`, `C-OPERATOR`, `C-COMPARISON`, and `C-LIMITS`.
- Uses exactly three research questions, matching the D10 assignment content.
- States the contribution as implemented-model specification, bounded MMS evidence, material rest-equilibrium failure, declared 1D-3D velocity observation operator, and descriptive C23/C40 discrepancy localization.
- Uses `discrepancy` for cross-model results.
- Does not add equation labels, citation keys, citations, or unapproved quantitative values.
- Carries forward the approved statement that the rest-state artificial flow at
  `t = 1 s` is the same order as the production comparison-flow scale.
- Removes the repeated local out-of-scope claim inventory from this block instead of restating it.

Evidence anchors used:

- `editorial/canonical_rq_answers.md`
- `editorial/claim_evidence_ledger.yaml`
- `editorial/numerical_ledger.yaml`
- `editorial/terminology_ledger.yaml`
- `editorial/section_plan.yaml`
- `sections/03-methodology/index.tex`
- `sections/04-verification/index.tex`
- `sections/02-comparison/index.tex`

Word count:

- Before: 464
- After: 429
- Change: -35

Audit notes:

- The proposed patch preserves subsection labels `subsec:research-problem-questions`, `subsec:objectives-contributions`, `subsec:scope-limits`, and `subsec:report-organization`.
- The proposed patch removes the local cross-reference to an out-of-scope convention pointer from Sections 1.4-1.7.
- The revised scope paragraph defines the active claim boundary for the completed
  work and no longer says the already-live opening chapter contains only model,
  solver, verification, and comparison facts.
- No integration-blocking open questions are recorded. The unmatched 3D wall, boundary, material, history, geometry, axial-flow, and sample-time issues are retained as evidential gates rather than open questions.
