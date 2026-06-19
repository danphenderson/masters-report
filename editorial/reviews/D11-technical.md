# D11 Technical Audit

Dispatch: D11-TECH
Mode: second revised-patch audit, review only
Source commit checked: `fc62416703f26406424376d628829e776b7a47d7`

## Verdict

PASS. The current D11 patch applies cleanly and is technically consistent with
the live source, the root claim ledger, the editorial claim ledger, and the
numerical/terminology ledgers checked for this lane. No blocker, major, or minor
findings remain.

## Second-Revision Focus

The Appendix G DG-row blocker from the prior technical audit is resolved.
`editorial/patches/D11.diff:750-756` now states that modal Legendre DG is
implemented for degrees `p=0,\ldots,4`, distinguishes descriptor-health and
package-benchmark rows that currently exercise `p=0,1,2`, states that the
p-refinement verification workflow runs through `p=4`, and keeps those rows as
appendix context rather than the principal C23/C40 method.

That distinction matches the live implementation and records checked here:
`src/StenosisHemodynamics/numerics/methods.jl:77-84` sets
`MAX_DG_DEGREE = 4`; `src/StenosisHemodynamics/cli/cli.jl:744-749` and
`src/StenosisHemodynamics/cli/cli.jl:809-814` expose the p/h-refinement default
degrees `0,1,2,3,4`; `src/StenosisHemodynamics/workflows/verification.jl:49-63`
and `src/StenosisHemodynamics/workflows/verification.jl:173-190` validate that
verification range; and
`figures/static/static/tables/verification/p_h_refinement_demo.tex:14-18`
contains p-refinement rows through `p=4`. The narrower descriptor-health and
package-benchmark qualifier is also correct: `figures/static/static/data/package-benchmark/case_results.csv:11-19`
and `src/StenosisHemodynamics/workflows/benchmarks.jl:381-385` cover DG p0-p2
for descriptor health, while `src/StenosisHemodynamics/workflows/benchmarks.jl:407-425`
and `src/StenosisHemodynamics/workflows/refinement.jl:3-6` keep the package
benchmark refinement degrees at `0,1,2`.

The `p_2` forward pointer is technically adequate. The selected implemented
balance law introduces `S_{p_2}` and explicitly says the pressure correction is
defined in `Section~\ref{subsec:source-to-implementation-variant}`
(`editorial/patches/D11.diff:396-417`). The formula appears shortly after at
`editorial/patches/D11.diff:471-483`, and its coefficient and locally
frozen-viscosity derivative match `src/StenosisHemodynamics/numerics/model.jl:101-111`
and `appendices/numerical-methods-details.tex:401-438`.

## Technical Checks Passed

- `git apply --check editorial/patches/D11.diff` succeeds against the requested
  source commit.
- The `A_{\mathrm{phys}}=\pi a`, `Q_{\mathrm{phys}}=\pi q`, and `\bar u=q/a`
  distinction in D11 matches `editorial/canonical_rq_answers.md:7-9`, both claim
  ledgers, and the live comparison/operator convention.
- The Rmax-normalized evolution wall potential, wave-speed term, and wall source
  match `src/StenosisHemodynamics/numerics/model.jl:24-37` and
  `src/StenosisHemodynamics/core/geometry.jl:5-11`. The local-denominator
  pressure diagnostic remains correctly separated from the selected evolution
  wall law (`src/StenosisHemodynamics/numerics/model.jl:3-7`,
  `src/StenosisHemodynamics/numerics/model.jl:118-128`).
- The rest-state compatibility language remains bounded: D11 assumes constant
  gauge external pressure and boundary data compatible with `q=0`, proves only
  the continuous source-balanced state, and immediately preserves the reported
  discrete MUSCL/Rusanov drift limitation (`editorial/patches/D11.diff:432-460`).
- The boundary approximation wording matches the live fixed-area characteristic
  implementation: reference-area inlet solver flow, inlet ghost-area solve,
  fixed `a_{\mathrm{out}}=R_0(L)^2`, and an explicitly approximate `alpha=1`
  invariant for the variable-alpha solver (`src/StenosisHemodynamics/core/boundaries.jl:112-115`,
  `src/StenosisHemodynamics/numerics/solver.jl:6-8`,
  `src/StenosisHemodynamics/numerics/solver.jl:45-51`,
  `src/StenosisHemodynamics/numerics/solver.jl:73-81`;
  `editorial/patches/D11.diff:499-516`, `editorial/patches/D11.diff:602-609`).
- The comparison-boundary fix remains intact. Added validation, accuracy,
  pressure-drop, FFR, physiological, clinical, predictive, and causal language is
  negated scope language only; the former Chapter 3 cross-model "errors" wording
  is changed to discrepancy terminology (`editorial/patches/D11.diff:657-663`,
  `editorial/patches/D11.diff:691-697`; compare
  `editorial/canonical_rq_answers.md:19-27` and
  `editorial/terminology_ledger.yaml:5-25`).
- The Appendix G insertion is in the right role: the secondary solver-surface
  table is moved out of the main methodology narrative, retains
  `tab:implemented-discretization-surface`, and is inserted as Appendix G
  context after the numerical-record setup paragraph
  (`editorial/patches/D11.diff:703-769`). Existing references are label-based.
- The case labels, sample times, time offset, grid, timestep cap, CFL cap,
  parameter values, output-operator formulas, table labels, and cited keys checked
  for this lane are consistent with the editorial ledgers and current source.

STATUS: PASS
BLOCKERS: 0
MAJORS: 0
MINORS: 0
