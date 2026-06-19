# D12 Technical Audit

Verdict: PASS. I found no blocker or major technical issue in D12.

Reviewed against current source commit `73bc59c`. The root
`claim_evidence_ledger.yaml` and `editorial/claim_evidence_ledger.yaml` are
byte-equivalent in this checkout. `git apply --check
editorial/patches/D12.diff` succeeds against the live tree, and the same patch
also applies cleanly to a scratch copy made from HEAD.

Findings:

- MINOR: The proposed manuscript DG wording is technically correct: D12 changes
  the appendix statement to implemented support through `p=0,\ldots,4` while
  quarantining package/descriptor rows as selected degrees such as `p=0,1,2`
  (`editorial/patches/D12.diff:545-551`,
  `editorial/patches/D12.diff:691-706`). This matches
  `src/StenosisHemodynamics/numerics/methods.jl:77-84`, and the CLI dispatch
  passes `--degree` into `DGMethod(degree)` at
  `src/StenosisHemodynamics/cli/cli.jl:172-191`. A source-facing simulate help
  string still says "DG polynomial degree 0, 1, or 2"
  (`src/StenosisHemodynamics/cli/cli.jl:37-38`). This is outside the D12
  manuscript patch, but if the DG-range conflict is meant to be closed
  repository-wide, that help text remains stale.

- MINOR: A scratch patched `latexmk` build succeeds, with no undefined
  references, undefined citations, or multiply-defined labels introduced by
  D12. The build log does report one small overfull hbox, 4.6249 pt, in the new
  Chapter 4 MMS paragraph at patched `sections/04-verification/index.tex` lines
  38-44. This is a layout polish issue, not a numerical or reference blocker.

Checks passed:

- The MMS equations, forcing residual definitions, error norms, and observed
  order formula are preserved. The temporal rows are correctly reframed as a
  time-step-insensitivity check rather than a clean temporal-order study
  (`editorial/patches/D12.diff:197-202`), consistent with the flat temporal
  values in `figures/static/static/tables/verification/mms_verification.tex:14-17`.

- The geometry-rest failure is correctly made central. The patched text states
  that the continuous selected source-balanced law admits `a_i=R_0(z_i)^2`,
  `q_i=0`, while the current MUSCL/Rusanov implementation is not well balanced
  (`editorial/patches/D12.diff:287-293`,
  `editorial/patches/D12.diff:338-344`). This matches
  `editorial/canonical_rq_answers.md:11-15` and
  `editorial/claim_evidence_ledger.yaml:35-42`.

- The proposed rest-state table values are derived from the existing CSV
  without changing the CSV. C23/C40 N800 peak `q` values come from
  `figures/static/static/tables/verification/rest_state_drift.csv:19` and
  `:39`; N800 `t=1` `q`, mass defect, and subcritical margins come from `:21`
  and `:41`. The proposed physical-flow columns are direct `pi*q` conversions,
  matching D12's `4.921`, `5.209`, `2.297`, and `2.301` table entries
  (`editorial/patches/D12.diff:734-737`).

- Solver `q` versus physical `pi*q` units are handled correctly. The comparison
  scale is stated as `q_comp=2.288/pi=0.7283 cm^3/s` in solver coordinates and
  `Q_comp=2.288 cm^3/s` physically (`editorial/patches/D12.diff:324-333`),
  consistent with `editorial/numerical_ledger.yaml:64-72`.

- `R_0` versus `R_max` usage stays consistent. Rest states use `R_0(z)^2`,
  while the wall-law and characteristic-speed denominators remain tied to
  `R_max^2` in `appendices/numerical-methods-details.tex:172-180`,
  `:416-439`, and `:741-743`.

- Boundary approximation wording is bounded. The patch keeps the fixed-area
  characteristic boundary rule under the subcritical sign condition and does
  not treat positive radicand alone as boundary-regime evidence
  (`editorial/patches/D12.diff:472-485`). The CSV records zero positivity
  projection counts for the rest grid
  (`figures/static/static/tables/verification/rest_state_drift.csv:18-21`,
  `:38-41`).

- Moved package-benchmark, p/h, backend-parity, resolved-velocity, descriptor,
  and stationary-Stokes material preserves its labels in Appendix G. In the
  scratch patched tree, each moved D12 label appears once in TeX, and the
  Chapter 4 citation keys all exist in `references.bib`.

STATUS: PASS
BLOCKERS: 0
MAJORS: 0
MINORS: 2
