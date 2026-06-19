# D17 Adversarial Review

Dispatch: D17-ADV re-audit
Mode: Review only; no manuscript source or patch files edited.

## Inputs Reviewed

- `editorial/patches/D17.patch.json`
- `editorial/patches/D17.diff`
- `editorial/reviews/D17-writer-notes.md`
- Current touched source files at `HEAD` `a45ec6e9c3996aa2a692bc0c913de91370108910`
- Scratch-applied D17 tree for post-patch reference, build, log, and rendered-page checks

## Verification

- Live `HEAD` matches the requested commit:
  `a45ec6e9c3996aa2a692bc0c913de91370108910`.
- `git apply --check editorial/patches/D17.diff` passed.
- `git apply --check --whitespace=error editorial/patches/D17.diff` passed.
- `jq empty editorial/patches/D17.patch.json` passed.
- D17 was applied only in a temporary clone.
- `git diff --check` passed in the scratch-applied tree.
- `python3 scripts/audit_references.py` passed in the scratch-applied tree.
- `python3 scripts/audit_tex_preamble.py` passed in the scratch-applied tree.
- Scratch `latexmk -pdf -interaction=nonstopmode -halt-on-error -outdir=<scratch>/build final-report.tex` completed.
- Log scan found no undefined references/citations or multiply-defined labels. Remaining warnings were existing hyperref PDF-string warnings and small layout warnings outside the D17-edited figure/table surfaces.
- Rendered-page inspection covered the rest-state box/table, new axial-flow figure, retained section-mean plot, revised radial-profile plot, and appendix benchmark figure pages.

## Prior Minor Status

- Radial-profile shared legend crowding: resolved. The legend is now offset above the panel titles by `0.56cm` in `figures/static/static/tikz/radial-profile-comparison.tex`, and the rendered Figure 4 has clear separation between the legend and both panel titles.

## Adversarial Answers

1. The principal claim is unmistakable. D17 keeps the visual evidence aligned with the thesis boundary: implemented-model audit, principal rest-state defect, and diagnostic C23/C40 velocity/flow comparison under the declared plane-quadrature operator.

2. The rest-state defect is proportionately prominent. The boxed note is short, visible, and followed by the generated rest-state table and quantitative prose. The revision also fixes the Chapter 4 comparison-flow-scale reference so it points to the axial-flow comparison rather than the simplified velocity-only table.

3. I do not find a sentence that could reasonably be mistaken for validation or accuracy evidence. The comparison chapter still opens with explicit non-validation/non-accuracy language, the new axial-flow caption calls the 3D flow variation a matching limit, and the appendix benchmark captions are marked secondary.

4. Unmatched conditions are disclosed before interpretation. The comparison chapter states the unresolved time offset, current/deformed geometry status, wall model, wall-motion history, inlet/outlet histories, material parameters, and prior transient history before the figures and tables. The axial-flow subsection also discloses unresolved 3D flow variation before the new figure.

5. The section answers the research-question structure. D17 supports RQ2 by foregrounding the rest-state defect and supports RQ3 by replacing a less interpretive 3D rendering with a direct axial-flow figure and retained discrepancy summaries under the declared operator.

6. I do not see retained background that is merely correct rather than necessary. Deleting the compliant-vessel schematic and resolved-3D node-field rendering improves focus without removing necessary evidence; the retained figures, tables, captions, and references all support active claims or provenance.

## D17-Specific Assessment

- Deleting the early Figure 2 and Figure 3 blocks remains safe. The removed active labels do not appear in the compiled auxiliary label set, and the residual compliant-vessel label is only in an inactive source file outside the compiled path.
- The new axial-flow figure remains safe and useful. It uses the existing `section-quadrature.dat` flow columns, renders cleanly, and is interpreted as a matching-limit display rather than validation or accuracy evidence.
- The rest-state box remains proportionate and helpful.
- Captions are concise and bounded.

## Findings

No BLOCKER, MAJOR, or MINOR findings.

STATUS: ACCEPT
BLOCKERS: 0
MAJORS: 0
MINORS: 0
