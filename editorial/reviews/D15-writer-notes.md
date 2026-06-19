# D15 Writer Notes

Status: READY_FOR_AUDIT after local validation.

Scope: Sections 1.1-1.3 and Chapter 2 only, plus the required reference-inventory metadata sync. The proposed diff changes the three intro child subsection files, the three Chapter 2 child files, the Chapter 2 heading file, and `references/source-inventory.tsv`; this final revision changes only the proposed source-inventory note sync and does not edit manuscript source directly.

## Claim Handling

- Uses only approved claim IDs: C-MODEL, C-NUMERICS, C-MMS, C-REST, C-OPERATOR, C-COMPARISON, C-LIMITS.
- Opens the rewritten introduction subsections around the numerical audit problem and keeps a single compact anatomy-function motivation paragraph.
- Removes pressure-ratio derivations, pressure-tap figure text, unused shear-convention prose, proof-level transport derivations, the detailed Navier-Stokes taxonomy, and the Clay-problem paragraph from the proposed main narrative.
- Focuses Chapter 2 on 1D stenosis closure dependence, well-balanced balance-law methods, implementation verification, cross-dimensional observation operators, and the distinction between implementation verification, diagnostic cross-model comparison, and external validation.
- Removes machine-learning and broad model-family discussion from the proposed Chapter 2 replacement because it is not needed for the approved research gap.
- Reclassifies eight now-uncited reference inventory rows away from `current-cited` so `scripts/audit_references.py` remains consistent after D15 is applied.
- Updates five additional reference-inventory notes without changing their statuses: `JohnEtAl2017WallShearStressVectorForm`, `PijlsEtAl1996FFRFunctionalSeverity`, `EscanedDavies2017PhysiologicalAssessment`, `LuccaEtAl2025FFRPrediction`, and `VelikorodnyEtAl2025DeepOperatorStenosed`.

## Numerical Handling

- No numerical values are changed or introduced.
- The non-well-balanced geometry-rest drift remains explicit in the Chapter 2 numerical-method context.
- Cross-model outputs are described as discrepancies.

## Word Count

TeX-ish metadata count: 5525 -> 2028.

## Validation

- `jq empty editorial/patches/D15.patch.json` passed.
- Control-byte scan over `editorial/patches/D15.patch.json` and `editorial/patches/D15.diff` found 0 control bytes.
- `git apply --check editorial/patches/D15.diff` passed.
- Scratch-applied `editorial/patches/D15.diff` in a temporary worktree after the final inventory-note sync and ran `python3 scripts/audit_references.py`; the reference audit passed.
- `git status --short` shows the three D15 proposal artifacts modified/untracked, with D15 audit reports also present as untouched untracked files; no manuscript source files were changed.
