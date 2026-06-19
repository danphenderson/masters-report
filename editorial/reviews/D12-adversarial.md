# D12 Adversarial Review

Scope reviewed: `editorial/patches/D12.patch.json`, `editorial/patches/D12.diff`,
`editorial/canonical_rq_answers.md`, both claim-evidence ledgers,
`editorial/numerical_ledger.yaml`, `editorial/terminology_ledger.yaml`,
`editorial/section_plan.yaml`, current Chapter 4, Appendix G, and the dependent
rest-state table assets.

Validation: `git apply --check editorial/patches/D12.diff` succeeds against the
current checkout. `diff -u editorial/claim_evidence_ledger.yaml
claim_evidence_ledger.yaml` produced no output, so the root and editorial
claim-evidence ledgers are equivalent for this review.

Overall verdict: accept with minor cleanup. The patch makes the RQ2 answer
plain: MMS is bounded positive implementation-verification evidence, and the
non-well-balanced geometry-rest drift is the principal numerical result. I do
not see validation, accuracy, FFR, physiological, clinical, predictive, or
causal broadening. The proposed rest-state table values match the tracked CSV:
the N800 peak values are 1.566 and 1.658 cm^3/s in solver q, and the N800 t=1 s
values are 0.7313 and 0.7324 cm^3/s, with pi*q conversions of 2.297 and
2.301 cm^3/s. The rest-state defect is proportionately prominent and connected
to the comparison-flow scale before the section points to the C23/C40 comparison
as a velocity-output diagnostic rather than an accuracy study.

Asked checks:

- Principal claim unmistakable: yes. `D12.diff:17-20`, `D12.diff:35-45`, and
  `D12.diff:338-344` put the bounded claim and principal rest-state failure in
  the foreground.
- Rest-state defect proportionately prominent: yes. The proposed Chapter 4 text
  and revised table both show peak and t=1 s artificial flow relative to the
  comparison-flow scale.
- Validation or accuracy confusion: no blocker. "Accuracy", "validation", and
  "physical validation" appear only as negated or explicitly bounded language;
  "error" is used in MMS/error-norm contexts where the reference is declared.
- Unmatched conditions before interpretation: adequate for D12. The patch
  discloses zero-forcing/zero-inlet rest conditions before interpreting rest
  drift, then limits the C23/C40 comparison to a velocity-output diagnostic.
- Research-question answer: yes. It answers RQ2 from the canonical answers:
  positive but bounded MMS evidence, plus failure to preserve geometry rest.
- Retained background necessity: acceptable. The finite-volume context paragraph
  is short and relevant; secondary benchmark, DG, backend, rheology/profile,
  stationary-Stokes, and resolved-output records are moved to Appendix G.

Findings:

- MINOR: `editorial/patches/D12.diff:287-293` cites the continuous
  rest-compatibility proposition but states the equilibrium with indexed
  discrete notation, `$a_i=R_0(z_i)^2` and `$q_i=0`. The underlying claim is
  supported by `sections/01-intro/selected-1d-model.tex:324-329`, but that
  proposition states the continuous equilibrium as `a(z)=R_0(z)^2` and
  `q(z)=0`. For examiner clarity, use continuous notation in the proposition
  sentence and reserve indexed notation for the runner/table diagnostics.

- MINOR: D12's Appendix G DG wording is supportable, but it should not be
  described as globally resolving the DG-range consistency issue. The patch
  changes Appendix G to implemented support through `p=4` and correctly notes
  selected package rows such as `p=0,1,2` (`editorial/patches/D12.diff:547-551`,
  `editorial/patches/D12.diff:695-706`), and the live constructor supports that
  range. A stale user-facing CLI help string still says `--degree` is "0, 1, or
  2" in `src/StenosisHemodynamics/cli/cli.jl:38`; leave that for a later code
  lane rather than claiming D12 closes the issue everywhere.

STATUS: ACCEPT
BLOCKERS: 0
MAJORS: 0
MINORS: 2
