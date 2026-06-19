# D15 Integration Report

Dispatch: D15

Scope integrated:

- `sections/01-intro/pressure-flow-motivation.tex`
- `sections/01-intro/blood-continuum.tex`
- `sections/01-intro/governing-equations.tex`
- `sections/02-background/index.tex`
- `sections/02-background/state-of-art-models.tex`
- `sections/02-background/state-of-art-numerics.tex`
- `sections/02-background/synthesis-gap.tex`
- `references/source-inventory.tsv`

Prerequisites:

- Section Writer: `STATUS: READY_FOR_AUDIT`
- Open questions: 0
- Technical Auditor: `STATUS: PASS`, `BLOCKERS: 0`, `MAJORS: 0`
- Claim Auditor: `STATUS: PASS`, `PROHIBITED CLAIMS: 0`, `TERMINOLOGY VIOLATIONS: 0`, `UNSUPPORTED INFERENCES: 0`
- Adversarial Reviewer: `STATUS: ACCEPT`, `BLOCKERS: 0`, `MAJORS: 0`

Pre-apply checks:

- Source HEAD before apply: `c74c371c13ab7314c9a10aa3045cb5f565d2adcc`
- `git apply --check editorial/patches/D15.diff`: pass
- Control-byte scan of `editorial/patches/D15.diff` and `editorial/patches/D15.patch.json`: pass
- Patch touched only the seven reviewed D15 TeX files plus the reviewed `references/source-inventory.tsv` metadata sync.
- Root and editorial claim ledgers: byte-identical, SHA256 `40eab1f8c3b2086fe94641e5ca92ce21aca6e1723f7fcce625282c41a24706c8`

Applied change:

- Rewrote Sections 1.1--1.3 so the introduction opens with the numerical audit problem and retains only compact anatomy--function motivation.
- Removed pressure-ratio derivations, pressure-output figure prose, unused shear-convention prose, proof-level transport derivations, detailed Navier--Stokes taxonomy, and Clay-problem discussion from the scoped main narrative.
- Focused Chapter 2 on stenosis-aware 1D models, closure dependence, balance-law discretization, well-balanced behavior, implementation verification, cross-dimensional observation operators, and evidence-category boundaries.
- Kept the rest-state limitation prominent with `non-well-balanced geometry-rest drift` wording.
- Synchronized `references/source-inventory.tsv` metadata for D15 citation removals without changing `references.bib` or reference artifacts.

Reference validation:

- `python3 scripts/audit_references.py`: pass
- `python3 scripts/audit_tex_preamble.py`: pass
- `pipenv install --dev`: pass
- `pipenv run pytest test/test_references_inventory.py test/test_tex_preamble_audit.py`: pass, 3 tests
- `biber --tool --validate-datamodel --output-file /tmp/masters-report-D15-references.bib references.bib`: pass

Build verification:

- Pass 1: `latexmk -pdf -interaction=nonstopmode -halt-on-error -g -outdir=/tmp/masters-report-D15-build final-report.tex`
- Pass 2: `latexmk -pdf -interaction=nonstopmode -halt-on-error -g -outdir=/tmp/masters-report-D15-build final-report.tex`
- Logs:
  - `editorial/build_logs/D15-pass1.log`
  - `editorial/build_logs/D15-pass2.log`
- Undefined references after pass 2: 0
- Undefined citations after pass 2: 0
- Multiply-defined labels after pass 2: 0

PDF inspection:

- Output inspected: `/tmp/masters-report-D15-build/final-report.pdf`
- Page count after D15: 80
- Rendered pages inspected: 5-12, with table-of-contents mapping checked on page 2.
- Rewritten introduction, compact continuum display, research-question transition, focused Chapter 2 tables, and evidence-category close rendered without clipping, overlap, or missing content.
- Page 9 is sparse because Section 1 ends there; no visual defect was found.

Residual minor issues:

- The second build reports one pre-existing small overfull hbox: `4.6249pt` in Chapter 4 lines 38--44.

Word count:

- Before: 5525
- After: 2028

STATUS: PASS
BLOCKERS: 0
MAJORS: 0
MINORS: 1
