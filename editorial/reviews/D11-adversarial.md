# D11 Adversarial Review

Scope: reviewed the second revised `editorial/patches/D11.diff` and
`editorial/patches/D11.patch.json` against `editorial/canonical_rq_answers.md`,
both claim ledgers, the numerical and terminology ledgers, the section plan, the
current Chapter 3 source, and Appendix G. The checkout is at the requested
`fc62416703f26406424376d628829e776b7a47d7`, and `git apply --check
editorial/patches/D11.diff` succeeds.

## Findings

No BLOCKER, MAJOR, or MINOR findings against the current second revised D11
patch.

## Adversarial Checks

Principal claim: acceptable. The opening at `editorial/patches/D11.diff:15-21`
makes Chapter 3 the implementation contract, and the replacement then states the
solver-coordinate map, selected wall/source law, boundary approximation,
principal MUSCL/Rusanov/SSPRK3 realization, observation operator, comparison
design, and provenance before numerical interpretation.

Rest-state defect prominence: acceptable. The continuous compatibility
proposition is bounded to the selected continuous source-balanced law at
`editorial/patches/D11.diff:432-456`, and the next sentence states that the
current MUSCL/Rusanov realization exhibits the reported non-well-balanced
geometry-rest drift at `editorial/patches/D11.diff:458-460`. That is
proportionate for Chapter 3 without burying the defect.

Validation or accuracy ambiguity: no finding. The comparison boundary at
`editorial/patches/D11.diff:653-663` calls C23/C40 a diagnostic cross-model
velocity comparison and explicitly negates validation, accuracy, pressure-drop,
FFR, physiological, clinical, predictive, and causal readings. The metric
paragraph is changed from sample errors to discrepancy norms at
`editorial/patches/D11.diff:691-696`.

Unmatched conditions before interpretation: acceptable. The timing offset is
declared before the comparison tables at `editorial/patches/D11.diff:653-657`,
and the matching matrix keeps wall, density, material/rheology, initial
condition, inlet/outlet, time/history, and resolution entries as unmatched,
unknown, or unresolved before the discrepancy norms are defined.

RQ1 answer: acceptable. The section makes the implementation contract
authoritative rather than relying on source-paper naming. The `R_{\max}` wall
normalization, `a=R^2`, `q=Q_{\mathrm{phys}}/\pi`, principal discretization,
and boundary approximation are all part of the contract.

Retained background: no finding. The remaining general model material supports
variable definitions, the source-to-implementation distinction, boundary scope,
or the declared observation operator. It does not cross the threshold into
background that is merely correct rather than necessary.

## Second-Revision Focus

The DG clarification now reads as a bounded implementation-surface distinction,
not a new main claim. Appendix G states implemented modal Legendre DG support
through `p=0,\ldots,4` while distinguishing descriptor-health and
package-benchmark rows that may exercise only `p=0,1,2`
(`editorial/patches/D11.diff:750-756`). Chapter 3 still says these methods are
implementation-check or sensitivity context, not the principal C23/C40 method
(`editorial/patches/D11.diff:621-627`).

The `p_2` forward pointer is readable enough. The implemented-balance definition
uses `p_2`, immediately says the correction is defined in the
Source-to-Implementation subsection, and then gives the formula shortly after
(`editorial/patches/D11.diff:401-417` and
`editorial/patches/D11.diff:471-483`). This is auditable and does not create a
claim or notation blocker.

Prior adversarial fixes remain intact. The rest-state warning remains adjacent
to the continuous proposition, the comparison boundary still excludes
validation/accuracy readings, Appendix G remains the home for secondary solver
surfaces, and the boundary subsection stays focused on the realized finite-volume
boundary rule.

STATUS: ACCEPT
BLOCKERS: 0
MAJORS: 0
MINORS: 0
