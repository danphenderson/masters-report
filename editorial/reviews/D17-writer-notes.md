# D17 Writer Notes

Status: READY_FOR_AUDIT after local checks.

Scope: Figures, tables, captions, and directly dependent cross-references. The main checkout manuscript source was not edited; proposed source edits are contained in `editorial/patches/D17.diff`.

## Changes Proposed

- Removes two early active figure blocks: the compliant-vessel notation figure in Chapter 3 and the resolved-3D node-field rendering in Chapter 5. Neither removed label is referenced after the proposal is applied.
- Adds `figures/static/static/tikz/axial-flow-comparison.tex` and a Chapter 5 figure showing $Q_{1D}(z)=\pi q(z)$ against $Q_{3D}(z)$ from the tracked `section-quadrature.dat` asset.
- Simplifies Table `tab:t1-3d-comparison-summary` to retained section-mean velocity discrepancy metrics; physical-flow means and discrepancies remain in the axial-flow prose and new axial-flow figure.
- Makes the geometry-rest result more visually prominent with a boxed principal-limitation note and a rest-state table caption that foregrounds the result.
- Enlarges the retained section-mean and radial-profile plots by increasing their plot heights; Figure 1 is set to full text width and has a shorter evidential-status caption.
- Keeps secondary benchmark figures in the appendix as implementation-health records and shortens their captions to state that status.

## Audit Response

- Technical minor: removed the stale `Table~\ref{tab:t1-3d-comparison-summary}` reference from the Chapter 4 production-flow-scale sentence after the D17 table simplification. The physical-flow value remains `2.288 cm^3/s` and now points to Figure `fig:t1-axial-flow-comparison`.
- Adversarial minor: increased the shared radial-profile legend offset above the panel titles from `0.28cm` to `0.56cm`; plotted data, labels, and caption meaning are unchanged.

## Evidence Handling

- Uses approved claim IDs only: C-REST, C-OPERATOR, C-COMPARISON, C-LIMITS.
- Does not alter underlying data, citations, generated numerical values, equations, or table labels.
- The rest-state summary table still includes both peak and `t=1` columns. In the post-D16 scratch build it renders as Table 9, while the full rest-state grid renders as Table 19; the dispatch's “Table 12” reference appears to be stale relative to current numbering.
- Cross-model language remains discrepancy terminology. No figure caption implies validation, accuracy, or causation.

## Validation

- `git diff --check` passed in scratch worktree `/tmp/masters-report-D17.02rOdS/wt`.
- Scratch `latexmk -pdf -interaction=nonstopmode -halt-on-error -outdir=/tmp/masters-report-D17-build final-report.tex` passed.
- `jq empty editorial/patches/D17.patch.json` passed.
- Control-byte scan over `editorial/patches/D17.patch.json` and `editorial/patches/D17.diff` passed.
- `git apply --check editorial/patches/D17.diff` passed.
- Fresh scratch apply from the exported diff passed `git diff --check`.
- Fresh scratch `python3 scripts/audit_references.py --repo <scratch>` passed.
- Fresh scratch `latexmk -pdf -interaction=nonstopmode -halt-on-error -outdir=<scratch>/build final-report.tex` passed.
- Revision scratch worktree: `/tmp/masters-report-D17-rev.hGCbi6/wt`.
- Exported-diff revision scratch worktree: `/tmp/masters-report-D17-rev-final.YHOMW8/wt`.
- Final scratch LaTeX log has no unresolved references to the deleted figure labels.

## Word Count

TeX-ish touched-file count: 11311 -> 11270.
