# D90 Global Consistency Report

Dispatch: D90-GLOBAL-CONSISTENCY
Role: Claim Auditor plus Technical Auditor
Mode: Review plus targeted remediation before release verification

Repository HEAD at scan start: `2abfbd4dcb443fd882dbc09ba0fa5b1efc000ac9`

## Required Scan Files

- `editorial/reviews/D90-error-scan.txt`
- `editorial/reviews/D90-claim-language-scan.txt`
- `editorial/reviews/D90-DG-range-scan.txt`
- `editorial/reviews/D90-technical-token-scan.txt`

The scan files were regenerated after remediation and correspond to the current
working tree.

## Remediation Applied Before Final Classification

Two non-scientific consistency issues were found and fixed before this report was
closed:

- Appendix H and `editorial/release/D16-release-manifest.json` still used the
  D16 integration placeholder `D16-INTEGRATION-RELEASE-ID`. This was replaced by
  the final release tag `masters-report-final-2026-06-19`, which D99 must verify
  against the detached-worktree release commit.
- `figures/static/static/tikz/axial-flow-comparison.tex` labelled the physical
  flow axis as `$Q$`. It now labels the quantity as
  `$Q_{\mathrm{phys}}$`.

No scientific value, equation, comparison datum, citation key, table datum, or
claim ledger entry was changed.

## Classification Summary

### Error Terminology

Scan: `D90-error-scan.txt`  
Occurrences: 6

- Allowed: 6
- Requires revision: 0
- False positive: 0

Classification:

- `figures/static/static/tables/package-benchmark/package-benchmark-summary.tex:7`
  uses `Skipped/error` as a package-benchmark status column, not as a
  cross-model comparison quantity.
- `figures/static/static/tables/verification/p_h_refinement_demo.tex:4`,
  `figures/static/static/tables/verification/mms_verification.tex:4`,
  `sections/04-verification/index.tex:97`, and
  `sections/04-verification/index.tex:133` use `error` only for MMS or
  implementation-verification quantities.
- `appendices/code-and-ai-use.tex:22` is the `latexmk` command-line flag
  `-halt-on-error`.

No cross-model velocity or flow comparison is called an error.

### Claim Language

Scan: `D90-claim-language-scan.txt`  
Occurrences: 29

- Allowed: 27
- Requires revision: 0
- False positive: 2

Allowed occurrences are explicit exclusions, literature-background categories,
acronym/citation context, or boundary statements:

- Claim-boundary exclusions:
  `sections/01-intro/index.tex:59--60`,
  `sections/02-comparison/index.tex:11--16`,
  `sections/03-methodology/index.tex:650`,
  `sections/04-verification/index.tex:6--7`,
  `sections/04-verification/index.tex:208`,
  `sections/01-intro/selected-1d-model.tex:192`,
  `sections/01-intro/selected-1d-model.tex:380`,
  `sections/01-intro/selected-1d-model.tex:531`,
  `sections/01-intro/model-hierarchy/1d-model.tex:49--50`,
  `sections/01-intro/model-hierarchy/2d-model.tex:23`,
  `sections/01-intro/model-hierarchy/index.tex:5`,
  `sections/01-intro/model-hierarchy/index.tex:21--22`,
  and `sections/01-intro/model-hierarchy/index.tex:101`.
- Literature or methodological context:
  `sections/02-background/index.tex:8`,
  `sections/02-background/state-of-art-models.tex:140`,
  and `sections/02-background/state-of-art-numerics.tex:45`.
- Appendix notation and acronym context:
  `appendices/domain-notation.tex:63`,
  `appendices/ns-coordinate-energy-details.tex:5`,
  and `appendices/acronyms.tex:17`.
- Figure text explicitly denies validation ranking:
  `figures/static/static/tikz/model-hierarchy.tex:47`.

False positives:

- `figures/static/static/tikz/model-hierarchy.tex:7`
- `figures/static/static/tikz/model-hierarchy.tex:40`

Both are source comments, not rendered claims.

No remaining occurrence implies validation, accuracy evidence, physiological or
clinical use, FFR support, predictive performance, or causation.

### DG Degree Range

Scan: `D90-DG-range-scan.txt`  
Occurrences: 37

- Allowed: 6
- Requires revision: 0
- False positive: 31

Allowed substantive DG occurrences:

- `appendices/numerical-methods-details.tex:53` states the first-order
  finite-volume/DG `$p=0$` bridge.
- `appendices/numerical-methods-details.tex:56`,
  `appendices/numerical-methods-details.tex:65--67`, and
  `appendices/numerical-methods-details.tex:403` state the resolved contract:
  the implementation supports modal Legendre DG degrees `$p=0,\ldots,4$`, while
  selected benchmark rows may use subsets such as `$p=0,1,2$`.

False positives are TikZ/layout parameters such as `inner sep`, `xsep`, `1pt`,
and `aboveskip` in figure and preamble styling files. They are not DG-degree
claims.

No unresolved `$p=0,1,2$` versus `$p=0,\ldots,4$` conflict remains in
publication-facing prose.

### Technical Tokens

Scan: `D90-technical-token-scan.txt`  
Occurrences: 148

- Allowed: all substantive model, time, and provenance occurrences
- Requires revision: 0
- False positive: numeric style/table values and unrelated `1.0`/`R` tokens

Classifications:

- `R_0` and `R_{\max}` occurrences in Sections 1, 3, 4, Appendix B, and
  Appendix D are allowed technical definitions or equations. They preserve the
  selected `R_{\max}`-normalized evolution wall law and the explicit distinction
  from local `R_0^{-2}` forms.
- `pressure(result, params)` appears only in
  `sections/01-intro/selected-1d-model.tex:189` and
  `sections/03-methodology/index.tex:208`, where it is identified as a legacy
  pressure helper and not the selected evolution wall law.
- `0.9995`, `1.0`, and `0.0005` in the front matter, Chapter 3, Chapter 5,
  Chapter 6, Appendix H, and the comparison tables are allowed because they
  disclose the 3D/1D sample-time offset or record table values.
- `A_{\mathrm{phys}}`, `Q_{\mathrm{phys}}`, `a`, and `q` were checked with a
  supplemental variable scan. The implemented solver-coordinate map remains
  explicit in the abstract, Chapter 3, Appendix C, Appendix D, and the
  conclusion. The axial-flow figure now labels the physical-flow axis as
  `$Q_{\mathrm{phys}}$`.
- `classical-1d-no-slip` appears only as a historical manifest token or
  secondary benchmark descriptor, not as the selected main method.

False positives include TikZ line widths, figure scales, `inner sep` style
parameters, and generated numeric table entries not related to the technical
tokens under review.

### Duplicate Evidential Disclaimers

Repeated boundary language remains in the abstract/introduction, methodology,
verification chapter, comparison chapter, and conclusion. These occurrences are
allowed because they sit at reader-entry or interpretation-gate locations:

- initial scope boundary in Chapter 1;
- method/reporting boundary before the comparison design;
- verification boundary before MMS/rest evidence;
- comparison boundary before 1D--3D interpretation;
- final conclusion boundary.

No duplicate disclaimer was found inside a single local argument in a way that
obscures the main claim.

## Validation

- `jq empty editorial/release/D16-release-manifest.json`: PASS
- `python3 scripts/audit_tex_preamble.py`: PASS
- `python3 scripts/audit_references.py`: PASS
- `git diff --check`: PASS
- Scratch build:
  `latexmk -pdf -interaction=nonstopmode -halt-on-error -g -outdir=/tmp/masters-report-D90-build final-report.tex`
  PASS
- Final build log undefined references: 0
- Final build log undefined citations: 0
- Final PDF pages: 57
- Remaining layout warnings: three known overfull boxes, unchanged in character
  from the D18 integration baseline.

STATUS: PASS
REQUIRES REVISION: 0
MISLEADING USES: 0
OPEN RELEASE GATES: 1

The open release gate is procedural: D99 must verify that the tag
`masters-report-final-2026-06-19` points to the final release commit used for the
fresh detached-worktree build.
