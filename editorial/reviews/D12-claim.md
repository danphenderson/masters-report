# D12 Claim Audit

No blocking claim findings in the current D12 patch.

Review basis:

- Current checkout confirmed at `73bc59cd1df87a1208640aec2c6ec748b627cb3c`.
- `git apply --check editorial/patches/D12.diff` succeeds.
- Reviewed `editorial/patches/D12.patch.json` and `editorial/patches/D12.diff`
  against the canonical RQ answers, claim evidence ledgers, terminology ledger,
  section plan, Chapter 4, Appendix G, and generated MMS/rest/DG table assets.
- Confirmed `editorial/claim_evidence_ledger.yaml` and the root
  `claim_evidence_ledger.yaml` are byte-identical (`cmp -s` exit 0); the
  editorial copy is used for the citations below.

Findings:

- MMS remains positive but bounded implementation-verification evidence. The
  patch recasts temporal rows as a time-step-insensitivity check rather than a
  clean temporal-order study (`editorial/patches/D12.diff:197-202`) and states
  that spatial rows are bounded positive evidence, not a formal-order result for
  every model variant (`editorial/patches/D12.diff:271-276`). This matches RQ2
  and C-MMS (`editorial/canonical_rq_answers.md:11-16`;
  `editorial/claim_evidence_ledger.yaml:28-34`).
- The rest-state failure is not minimized. The proposed text says the principal
  implementation is not well balanced for geometry rest
  (`editorial/patches/D12.diff:287-293`), reports the finest-grid `t=1 s` and
  peak rest-flow values (`editorial/patches/D12.diff:324-336`), and then calls
  the geometry-rest failure the principal numerical result of the chapter
  (`editorial/patches/D12.diff:338-344`). The values match the generated rest
  CSV and full table (`figures/static/static/tables/verification/rest_state_drift.csv:17-21`;
  `figures/static/static/tables/verification/rest_state_drift.csv:37-41`;
  `figures/static/static/tables/verification/rest_state_drift_full.tex:24-28`;
  `figures/static/static/tables/verification/rest_state_drift_full.tex:44-48`).
- The rest-flow comparison to production scale is descriptive, not causal. The
  patch says the rest-flow values are same order and numerically close to the
  comparison-flow scale (`editorial/patches/D12.diff:324-336`), then limits the
  C23/C40 comparison to a velocity-output diagnostic rather than a
  discretization-accuracy study (`editorial/patches/D12.diff:338-344`).
- Secondary checks are not elevated to principal evidence. The main text moves
  self-convergence, backend parity, stationary-Stokes, resolved-velocity
  benchmark, rheology/profile, and nonselected DG material into appendix-level
  implementation-health context (`editorial/patches/D12.diff:503-511`;
  `editorial/patches/D12.diff:520-532`; `editorial/patches/D12.diff:579-585`;
  `editorial/patches/D12.diff:617-625`).
- The DG range clarification is supported and does not broaden the thesis claim.
  The patch separates implemented DG support through `p=4` from selected
  descriptor/package rows and keeps all DG rows secondary
  (`editorial/patches/D12.diff:545-551`; `editorial/patches/D12.diff:691-706`).
  This matches the generated p-refinement rows through `p=4`
  (`figures/static/static/data/verification/p_h_refinement_demo.csv:6-10`) and
  the code-level `MAX_DG_DEGREE = 4` contract
  (`src/StenosisHemodynamics/numerics/methods.jl:77-85`).
- No prohibited validation, accuracy, physiological, clinical, predictive, or
  causal claim is introduced. Those terms appear only in explicit negations or
  bounded contexts (`editorial/patches/D12.diff:17-20`;
  `editorial/patches/D12.diff:572-575`). Cross-model "error" language is not
  added; error terminology remains limited to MMS/exact-solution or sampled
  numerical-error contexts allowed by the terminology ledger
  (`editorial/terminology_ledger.yaml:5-25`).

STATUS: PASS
PROHIBITED CLAIMS: 0
TERMINOLOGY VIOLATIONS: 0
UNSUPPORTED INFERENCES: 0
