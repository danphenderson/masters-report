# D11 Writer Notes

Status: ready for audit.

Scope completed:

- Prepared a patch proposal for Chapter 3 in `sections/03-methodology/index.tex`.
- Added one supporting Appendix G proposal block in `appendices/numerical-methods-details.tex` to move the secondary solver-surface table out of the main narrative while preserving its label.
- Did not edit manuscript source files, ledgers, run state, or prior review files.

D11 requirements addressed:

Revision response:

- Second revision: clarified that modal Legendre DG is implemented for
  `p=0,...,4`, while descriptor-health/package-benchmark rows may exercise only
  `p=0,1,2` and the p-refinement verification workflow runs through `p=4`;
  this remains appendix context, not the principal comparison method.
- Second revision: added a forward pointer that defines the `p_{2,\mathrm g}`
  formula below when `S_{p_2}` and `\partial_z^{\mathrm{frz}}p_{2,\mathrm g}`
  first appear.
- Added an explicit rest-state sentence stating that continuous compatibility does not imply discrete preservation and that the current MUSCL/Rusanov realization exhibits the reported non-well-balanced geometry-rest drift.
- Restored one comparison-boundary sentence stating that C23/C40 section and radial quantities are descriptive discrepancies under the declared operator, not validation, accuracy, pressure-drop, FFR, physiological, clinical, predictive, or causal evidence.
- Moved the Appendix G secondary-solver subsection after the generic setup paragraph so that paragraph remains section-level context.
- Compressed generic boundary alternatives to a single lead-in sentence and focused the retained definition on the literal implemented boundary rule.


- Reordered Chapter 3 around physical/solver variables, geometry and wall law, implemented R_max-normalized balance law, source-to-implementation differences, boundary approximation, principal MUSCL/Rusanov/SSPRK3 realization, plane-tetrahedron operator, and comparison design/provenance.
- Preserved `A_{\mathrm{phys}}=\pi a`, `Q_{\mathrm{phys}}=\pi q`, and mean velocity `q/a`.
- States that the evolution wall law uses `R_{\max}` normalization and that the legacy pressure helper is not the evolution wall law.
- States that the boundary invariant is an `alpha=1` fixed-area approximation used for the variable-alpha solver.
- Keeps only the principal MUSCL/Rusanov/SSPRK3 method in the main narrative; secondary surfaces move to Appendix G.
- Uses `discrepancy` terminology for cross-model metric prose and does not add prohibited validation or accuracy claims.

Word count:

- Before: 3626
- After: 3449
- Change: -177

Validation run:

- `jq empty editorial/patches/D11.patch.json`
- `git apply --check editorial/patches/D11.diff`
- `git diff -- sections/03-methodology/index.tex appendices/numerical-methods-details.tex`

Audit notes:

- The word count uses expanded current Chapter 3, substituting `sections/01-intro/selected-1d-model.tex` for the current input line, then compares it to the proposed Chapter 3 replacement plus the Appendix G inserted table.
- No integration-blocking open questions are recorded.
