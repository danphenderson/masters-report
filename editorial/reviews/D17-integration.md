# D17 Integration Report

Dispatch: D17-INTEGRATE
Scope: figures, tables, captions, and cross-references

## Prerequisites

- Section Writer: `READY_FOR_AUDIT`, open questions `0`.
- Technical audit: `PASS`, blockers `0`, majors `0`, minors `0`.
- Claim audit: `PASS`, prohibited claims `0`, terminology violations `0`, unsupported inferences `0`.
- Adversarial audit: `ACCEPT`, blockers `0`, majors `0`, minors `0`.
- Source HEAD before apply: `a45ec6e9c3996aa2a692bc0c913de91370108910`.
- Applied only `editorial/patches/D17.diff`.

## Applied Changes

- Removed the active compliant-vessel schematic and resolved-3D node-field rendering from the compiled manuscript path.
- Added an axial physical-flow figure from the existing tracked `section-quadrature.dat` data.
- Simplified the retained section-mean velocity discrepancy table and moved physical-flow comparison emphasis to prose and the new axial-flow figure.
- Made the geometry-rest limitation visually prominent before the rest-state summary table.
- Enlarged the retained section-mean and radial-profile plots and tightened selected figure/table captions.
- Kept secondary benchmark figures in Appendix D with shorter implementation-health captions.

## Verification

- `git apply --check --whitespace=error editorial/patches/D17.diff`: pass.
- `git diff --check`: pass.
- Deleted active figure-label references: no compiled-source references to `fig:stenosis-3d-reference-geometry`; `fig:compliant-vessel-reduction` remains only in an un-included source file.
- `python3 scripts/audit_tex_preamble.py`: pass.
- `python3 scripts/audit_references.py`: pass.
- Build pass 1: `editorial/build_logs/D17-pass1.log`, pass.
- Build pass 2: `editorial/build_logs/D17-pass2.log`, pass.
- Final log undefined-reference/citation scan: `0`.
- PDF metadata after build: 57 pages, pdfTeX 1.40.29.
- Visual inspection: rendered pages 5, 26-34, and 45-47 from `/tmp/masters-report-D17-build/final-report.pdf`; no clipping, overlap, or unreadable edited figure/table content observed.

## Word Count

- Figure/table/caption scope: `11311 -> 11270`.

## Residual Layout Notes

- Final build log reports three overfull boxes: one pre-existing Chapter 4 line at 4.6249 pt, and two Appendix D lines at 4.43495 pt and 12.66252 pt. Rendered pages remain legible.

STATUS: PASS
BLOCKERS: 0
MAJORS: 0
