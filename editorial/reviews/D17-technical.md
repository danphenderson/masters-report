# D17 Technical Re-Audit

Dispatch: D17-TECH
Mode: review only; manuscript source and D17 patch files not edited
Reviewed: `editorial/patches/D17.patch.json`, `editorial/patches/D17.diff`,
`editorial/reviews/D17-writer-notes.md`, current source at
`a45ec6e9c3996aa2a692bc0c913de91370108910`, and
`editorial/numerical_ledger.yaml`.

## Verdict

PASS. The prior D17-TECH minor is resolved. The production physical-flow scale
sentence in Chapter 4 no longer points to the simplified
`tab:t1-3d-comparison-summary`; it now points to
Figure~`fig:t1-axial-flow-comparison`, where the axial physical-flow data and
units are actually shown. I found zero blockers, zero majors, and zero minors.

## Findings

None.

## Technical Checks

- Scope: D17 remains limited to figures, tables, captions, and directly
  dependent cross-references. It adds one TikZ figure from existing tracked data
  and does not alter underlying numerical data.
- Patch shape: `git apply --check --whitespace=error editorial/patches/D17.diff`
  passed. `git apply --numstat` reports the expected presentation-surface files:
  six manuscript TeX files, three existing figure/table TeX files, and one new
  `figures/static/static/tikz/axial-flow-comparison.tex`.
- Prior finding: `Q_{\mathrm{comp}}\approx2.288\,\mathrm{cm}^3/\mathrm{s}` is
  now described as physical circular flow used in the axial-flow comparison and
  references Figure~`fig:t1-axial-flow-comparison`. The simplified
  `tab:t1-3d-comparison-summary` is now referenced only for retained
  section-mean velocity discrepancy metrics.
- Underlying data: byte comparisons confirmed that
  `section-quadrature.dat`, `area-audit.dat`, and `rest_state_drift.csv` are
  unchanged after applying the patch.
- New axial-flow figure: the new figure reads `flow1dC23`, `flow3dC23`,
  `flow1dC40`, and `flow3dC40` from the existing `section-quadrature.dat` asset.
  Its axis and caption state physical flow in `cm^3/s` with
  `Q_{1D}(z)=\pi q(z)`, preserving the `Qphys/q` distinction.
- Axial-flow values: recomputation from `section-quadrature.dat` gives C23 3D
  flow range/mean `7.7228%` and C40 `20.2162%`, matching the rounded `7.7%` and
  `20.2%` text. The listed flow means, signed biases, MAE, and RMS flow
  discrepancies also match after rounding.
- Simplified `tab:t1-3d-comparison-summary`: recomputation confirms the retained
  velocity means, signed biases, MAE, RMS, relative RMS, maximum discrepancies,
  and maximum locations.
- Rest-state table caption and prose: the caption correctly distinguishes
  solver flow `q` from physical circular flow `\pi q`. The `q_{\mathrm{comp}}`
  value, finest-grid `t=1` rest-flow values, physical-flow conversions, peak
  rest drift values, mass defects, and subcritical margins match
  `rest_state_drift.csv`.
- Equations and coefficients: D17 does not change the solver equations. The
  patched tree still preserves the SSPRK3 half-step, flux/source coefficients,
  Rusanov speed, WSS proxy, and positivity-regularized radius-squared divisions
  from current source.
- Units and solver/physical variables: the patched tree preserves
  `A_{\mathrm{phys}}=\pi a`, `Q_{\mathrm{phys}}=\pi q`, and
  `\bar u=q/a=Q_{\mathrm{phys}}/A_{\mathrm{phys}}`.
- `R_0` versus `R_{\max}` and wall-law denominator: the patched tree keeps
  `R_0(z)` as stenosed reference-radius geometry and `R_{\max}` as the selected
  wall-law denominator. The denominator remains `R_{\max}^2`, consistent with
  `wall_reference_radius(p)=p.rmax`.
- Boundary approximation wording: the patched tree still describes the boundary
  rule as the implemented `alpha=1`, fixed-area characteristic approximation,
  not an exact invariant for the full variable-radius balance law.
- Numerical values and time alignment: `N=400`, `target-time=1.0`,
  `time-atol=1e-3`, radial bin counts `10,20,40`, and the `1.0 s` versus
  `0.9995 s` sample-time offset remain consistent with the ledger.
- DG degree range: Appendix G still states native modal DG support as
  `p=0,\ldots,4` and separates package-benchmark subsets such as `p=0,1,2`.
- Deleted figure labels: after applying D17, removed labels such as
  `fig:stenosis-3d-reference-geometry` and `fig:t1-section-flow` are not
  referenced. New labels for the axial, section-mean, radial-profile, and
  simplified table surfaces are defined and used consistently.
- Labels and citation keys: scratch label/reference parsing found no missing
  labels; `python3 scripts/audit_references.py` passed; scratch `latexmk`
  passed; the final log scan found no undefined references or undefined
  citations.

## Validation

- `git apply --check --whitespace=error editorial/patches/D17.diff`: passed.
- `python3 -m json.tool editorial/patches/D17.patch.json`: passed.
- Scratch apply in `/tmp/masters-report-D17-retech`: passed.
- Scoped scratch `git diff --cached --check` on D17 changed files: passed.
- `python3 scripts/audit_tex_preamble.py`: passed in the scratch-applied tree.
- `python3 scripts/audit_references.py`: passed in the scratch-applied tree.
- `latexmk -pdf -interaction=nonstopmode -halt-on-error -outdir=/tmp/masters-report-D17-retech-build final-report.tex`:
  passed in the scratch-applied tree.
- Scratch build log scan for undefined references or citations: clean.

STATUS: PASS
BLOCKERS: 0
MAJORS: 0
MINORS: 0
