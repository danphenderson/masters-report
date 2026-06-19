# D15 Technical Audit

Dispatch: D15-TECH
Mode: review only; manuscript source not edited
Reviewed: `editorial/patches/D15.patch.json`, `editorial/patches/D15.diff`,
current source at `c74c371c13ab7314c9a10aa3045cb5f565d2adcc`,
`editorial/numerical_ledger.yaml`, `editorial/terminology_ledger.yaml`, and
`references/source-inventory.tsv` under `references/AGENTS.md`.

## Verdict

PASS. I found no technical blockers, major issues, or minor issues in the final
D15 proposal. The patch applies cleanly, stays inside the declared D15 lane, and
does not alter `references.bib`, reference artifacts, generated tables, figures,
numerical data, or non-D15 manuscript source.

## Scope And Metadata

- `git apply --check editorial/patches/D15.diff` passes.
- `git apply --numstat editorial/patches/D15.diff` confirms exactly eight
  changed paths: seven TeX source files plus `references/source-inventory.tsv`.
- `editorial/patches/D15.patch.json` is valid JSON and its metadata matches the
  patch shape: seven TeX source files, one source-inventory metadata sync, 13
  inventory row updates, eight status-and-note updates, and five note-only
  cleanups.
- `git -C /tmp/masters-report-D15-technical diff --check` passes after applying
  D15 in the scratch worktree.

## Prior Issues Verified

- The compact continuum display is syntactically valid: after applying D15,
  `sections/01-intro/governing-equations.tex` uses `&&\\` between the mass and
  momentum rows.
- The rest-state failure is not softened. The phrase
  `non-well-balanced geometry-rest drift` appears in the rewritten introduction,
  numerical background, synthesis/gap text, verification chapter, and conclusion.
- The metadata states seven TeX source files plus
  `references/source-inventory.tsv`; the diff confirms the same path set.
- `python3 scripts/audit_references.py` passes after applying D15.
- The stale source-inventory notes are fixed:
  `JohnEtAl2017WallShearStressVectorForm`,
  `PijlsEtAl1996FFRFunctionalSeverity`,
  `EscanedDavies2017PhysiologicalAssessment`, and
  `LuccaEtAl2025FFRPrediction` remain `current-cited` with notes matching their
  remaining citation locations, while `VelikorodnyEtAl2025DeepOperatorStenosed`
  is `future-work` with an uncited future-method note.

## Technical Checks

- Equations and coefficients: D15 introduces only a compact schematic continuum
  display and does not change the implemented solver equations, coefficients,
  generated tables, figures, or numerical values.
- Units: no new numerical values or unit conversions are introduced.
- `A_{\mathrm{phys}}/a` and `Q_{\mathrm{phys}}/q`: the rewritten comparison
  background preserves the distinction by using `Q_{1D}=\pi q` and
  `\bar u_{1D}=q/a`.
- `R_0` versus `R_{\max}`: D15 uses `R_{\max}` only for the implemented solver
  normalization and leaves `R_0` in its reference-geometry/rest-state role.
- Wall-law denominator: no local-denominator evolution-wall-law claim is
  introduced; the authoritative `R_{\max}^{-2}` wall-law wording remains in
  Chapter 3 and the appendix.
- Boundary approximation wording: the new text stays at boundary-rule or
  boundary-approximation level and does not overstate the fixed-area
  characteristic treatment as an exact invariant for the full variable-radius
  system.
- Table and figure references: deleted figure/definition labels have no
  surviving TeX references in the scratch-applied tree, and the scratch build
  resolves labels and citations.
- DG degree range: D15 mentions DG only as generic numerical-method context and
  does not introduce a conflicting degree range.
- Time alignment: D15 does not claim exact 1D/3D time alignment; the existing
  `1.0` s versus `0.9995` s limitation remains outside this patch.
- Citation and reference inventory consistency: surviving citation keys resolve
  against `references.bib`; uncited rows are no longer marked `current-cited`
  except for keys still cited elsewhere.

## Validation

- Scratch worktree used: `/tmp/masters-report-D15-technical`, with D15 applied;
  removed after validation.
- `python3 scripts/audit_references.py`: passed.
- `python3 scripts/audit_tex_preamble.py`: passed.
- `pipenv install --dev && pipenv run pytest test/test_references_inventory.py test/test_tex_preamble_audit.py`: passed, 3 tests.
- `biber --tool --validate-datamodel --output-file /tmp/masters-report-D15-references.bib references.bib`: passed.
- `latexmk -pdf -interaction=nonstopmode -halt-on-error -outdir=/tmp/masters-report-D15-build final-report.tex`: passed. Final log scan found no undefined references or undefined citations; scratch build output removed after validation.

STATUS: PASS
BLOCKERS: 0
MAJORS: 0
MINORS: 0
