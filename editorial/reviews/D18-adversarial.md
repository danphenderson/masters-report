# D18 Adversarial Review

Dispatch: D18-ADV re-audit after metadata hunk
Mode: Review only; no manuscript source or patch files edited.

## Inputs Reviewed

- `editorial/patches/D18.patch.json`
- `editorial/patches/D18.diff`
- `editorial/reviews/D18-writer-notes.md`
- Current touched source files at `HEAD` `874f5e749a063d08aceb58c2f451d3c0b4ed9248`
- Scratch-applied D18 tree for post-patch source, PDF metadata, rendered first page, and log checks

## Verification

- Live `HEAD` matches the requested commit:
  `874f5e749a063d08aceb58c2f451d3c0b4ed9248`.
- `jq empty editorial/patches/D18.patch.json` passed.
- `git apply --check editorial/patches/D18.diff` passed.
- `git apply --check --whitespace=error editorial/patches/D18.diff` passed.
- D18 was applied only in a temporary clone.
- `git diff --check` passed in the scratch-applied tree.
- `python3 scripts/audit_references.py` passed in the scratch-applied tree.
- `python3 scripts/audit_tex_preamble.py` passed in the scratch-applied tree.
- Scratch `latexmk -pdf -interaction=nonstopmode -halt-on-error -outdir=<scratch>/build final-report.tex` completed.
- Final build log inspection found no unresolved-reference/citation failures. Remaining final warnings were pre-existing hyperref PDF-string warnings and small layout warnings outside the D18-edited front matter.
- `pdfinfo` on the scratch PDF reported the revised D18 title, bounded subject, and focused keywords, with no stale `pressure-ratio outputs` metadata.
- First-page `pdftotext -layout` extraction and rendered page inspection confirmed the title, abstract, and keywords are coherent and fit on the title page.

## Metadata Hunk Status

The added `preamble/hyperref.tex` hunk resolves the prior metadata gap. The PDF title now matches the proposed report title in PDF-safe `1D-3D` form, the subject is bounded to the numerical audit and diagnostic velocity comparison, and the PDF keywords match the printed keyword set. The stale broad title, broad blood-flow subject, and `pressure-ratio outputs` keyword are removed from the proposed metadata.

## Adversarial Answers

1. The principal claim is unmistakable. The title, abstract, printed keywords, PDF metadata, and organization paragraph all frame the completed work as a numerical audit of a reduced-order stenosis solver plus a diagnostic 1D--3D velocity comparison.

2. The rest-state defect is proportionately prominent. The abstract calls the geometry-rest failure the central numerical limitation and states that zero-forcing C23/C40 rest runs retain artificial flow at `t=1` s on the same order as the production comparison-flow scale. The organization paragraph also makes this defect the constraint on the later comparison.

3. No revised sentence is likely to be mistaken for validation or accuracy evidence. "Manufactured-solution evidence" is bounded to the declared forced operator, while the cross-model material is described as diagnostic, descriptive, and discrepancy-based. The only validation/accuracy language in the touched region is a protective Chapter 1 boundary sentence excluding broader validation, pressure-accuracy, FFR, physiological, clinical, predictive, and causal claims.

4. Unmatched conditions are disclosed before interpretation is closed. The abstract's final limitation sentence names unmatched or unpersisted wall, boundary, material, history, and current/deformed geometry information, unresolved axial variation in extracted 3D flow, and the `1.0` s versus `0.9995` s sample-time offset. The organization paragraph likewise says the 3D comparison states unmatched conditions that limit interpretation.

5. The front matter answers the research-question structure at summary level. It identifies the implemented solver and coordinate map, reports bounded MMS evidence, foregrounds the rest-state failure, defines the plane--tetrahedron comparison operator, and states that C23/C40 outputs are descriptive discrepancy results under that operator.

6. I do not see retained background that is merely correct rather than necessary. The abstract removes the earlier secondary-solver inventory and keeps only the solver identity, principal realization, verification boundary, rest defect, comparison operator, and interpretation limits needed to name the completed study.

## D18-Specific Assessment

- The abstract is direct, bounded, and complete without becoming overstuffed. It is dense, but each sentence contributes to the final claim boundary.
- The title accurately names the completed study and replaces the older broad literature-review framing.
- The printed and PDF keywords fit the final report and no longer foreground generic blood-flow simulation, Navier--Stokes, idealized stenosis, or pressure-ratio outputs.
- The PDF metadata is now aligned with the proposed title, abstract, and keyword boundary.
- The organization paragraph tracks the stabilized chapter structure and names the next required work without widening the achieved contribution.

## Findings

No BLOCKER, MAJOR, or MINOR findings.

STATUS: ACCEPT
BLOCKERS: 0
MAJORS: 0
MINORS: 0
