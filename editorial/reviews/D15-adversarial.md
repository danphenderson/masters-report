# D15 Adversarial Review

Dispatch: D15-ADV
Mode: Review only; no manuscript source edited.

## Inputs Reviewed

- `editorial/patches/D15.diff`
- `editorial/patches/D15.patch.json`
- Scratch-applied D15 tree at `HEAD` `c74c371c13ab7314c9a10aa3045cb5f565d2adcc`
- `editorial/canonical_rq_answers.md`
- `references/source-inventory.tsv`
- Scoped post-patch TeX for Sections 1.1-1.3 and Chapter 2

## Verification

- Live `HEAD` matches the orchestrator commit: `c74c371c13ab7314c9a10aa3045cb5f565d2adcc`.
- `git apply --check editorial/patches/D15.diff` passed.
- `jq empty editorial/patches/D15.patch.json` passed.
- `git apply --stat editorial/patches/D15.diff` reports 8 files: 7 manuscript-source files plus `references/source-inventory.tsv`, with 259 insertions and 1048 deletions.
- D15 was applied only in `/tmp/masters-report-d15-adv.OyEyaw` for review.
- In the scratch-applied tree, `python3 scripts/audit_references.py` passed.
- Scratch `latexmk -pdf -interaction=nonstopmode -halt-on-error -outdir=/tmp/masters-report-d15-adv-build final-report.tex` completed. Log scan found no undefined citation/reference or multiply-defined-label warnings; only pre-existing hyperref PDF-string warnings were present.
- A scoped citation-key scan found no retained D15-removed clinical FFR/CT-FFR, Clay/global-regularity, or ML/operator-learning citation keys in `sections/01-intro/pressure-flow-motivation.tex`, `sections/01-intro/blood-continuum.tex`, `sections/01-intro/governing-equations.tex`, or `sections/02-background/*.tex`.
- The scratch `pipenv run pytest test/test_references_inventory.py` command did not run because Pipenv created a fresh temporary virtualenv without `pytest`; I did not treat that as a manuscript blocker because the repository reference audit passed directly.

## Adversarial Answers

1. The principal claim is unmistakable. The introduction opens with the numerical audit problem, not clinical FFR, and the contribution is framed as implemented-model specification, bounded MMS evidence, exposure of rest-equilibrium failure, a declared observation operator, and descriptive C23/C40 discrepancy localization.

2. The rest-state defect is proportionately prominent. It appears in the research questions and contribution boundary, is described as a material failure and principal numerical limitation in the introduction, is motivated in the numerical-method literature review, and is repeated in the synthesis gap.

3. I do not find a proposed D15 sentence that would reasonably be mistaken for validation or accuracy evidence. The text repeatedly separates implementation verification, diagnostic cross-model comparison, and external validation, and it explicitly rejects broader validation, pressure-accuracy, FFR, clinical, predictive, and causal claims.

4. Unmatched conditions are disclosed before interpretation. The introduction states the unmatched or unpersisted 3D wall, boundary, material, history, and current/deformed geometry information before presenting the comparison role; Chapter 2 states the matched-condition requirement before assigning the C23/C40 comparison to diagnostic cross-model comparison.

5. The section answers a research question. Chapter 2 is focused around the three research questions: closure contract, verification/well-balanced behavior, and declared cross-dimensional observation operators.

6. I do not see retained background that is merely correct rather than necessary. The remaining continuum and Navier-Stokes material is compact vocabulary for area-flow reduction, boundary data, and closure dependence. The pressure-loss closure references that remain in Chapter 2 are tied to 1D stenosis closure context rather than to an FFR or pressure-accuracy claim.

## Reference-Inventory Metadata Review

- The metadata sync does not create a manuscript claim. Reclassified rows say they are uncited after D15 and retained only as background, report-adjacent, or future-work metadata.
- The sync does not hide deleted source support. Rows whose D15 source support was removed are reclassified away from `current-cited` when uncited, or have notes narrowed to their remaining live citation locations.
- I found no stale notes claiming removed D15 source-support locations. In particular, `JohnEtAl2017WallShearStressVectorForm`, `PijlsEtAl1996FFRFunctionalSeverity`, `EscanedDavies2017PhysiologicalAssessment`, `LuccaEtAl2025FFRPrediction`, and `VelikorodnyEtAl2025DeepOperatorStenosed` now reflect the post-D15 citation locations/statuses.

## Findings

No BLOCKER, MAJOR, or MINOR findings.

STATUS: ACCEPT
BLOCKERS: 0
MAJORS: 0
MINORS: 0
