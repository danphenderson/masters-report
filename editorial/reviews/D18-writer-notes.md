# D18 Writer Notes

## Scope

D18 is a front-matter proposal only. It updates the title, abstract, keywords,
PDF metadata, and the final organization paragraph in Section 1. No manuscript
source files were edited in the working checkout; the source changes are
represented only in `editorial/patches/D18.diff`.

## Claim Handling

The proposed title is the requested working title, split over two TeX title
lines. The abstract is 232 body words, within the 220--260 word target, and
contains the required elements:

- implemented solver identity and solver-coordinate map;
- principal MUSCL/Rusanov/SSPRK3 finite-volume realization;
- bounded MMS evidence;
- explicit failure to preserve geometry-rest equilibrium;
- declared plane-tetrahedron comparison operator;
- descriptive C23/C40 discrepancy status;
- unmatched-condition limitations, including current/deformed geometry status,
  unresolved axial variation, and the 1.0 s versus 0.9995 s sample-time offset.

The abstract avoids pressure, FFR, clinical use, machine learning, and
stationary-Stokes foregrounding. It uses discrepancy terminology for the
cross-model comparison and does not claim validation, accuracy, prediction,
physiology, clinical relevance, or causation.

## Revision Response

The post-audit revision adds `preamble/hyperref.tex` to the proposal so active
PDF metadata no longer carries the stale title, broad subject, or
`pressure-ratio outputs` keyword. The proposed PDF title, subject, and keywords
now match the D18 front-matter scope. The TeX prose from the accepted front
matter proposal is unchanged.

## Metadata

- Approved claim IDs used: C-MODEL, C-NUMERICS, C-MMS, C-REST, C-OPERATOR,
  C-COMPARISON, C-LIMITS.
- Citations added: none.
- Citations removed: none.
- Equations changed: none.
- Labels changed: none.
- Numerical values changed: none.
- Word count over the touched files: 1633 -> 1648.

## Validation

Completed locally on 2026-06-19:

- Initial D18 proposal validation passed.
- Post-audit `jq empty editorial/patches/D18.patch.json` passed.
- Post-audit control-byte scan over `D18.patch.json`, `D18.diff`, and this
  notes file found zero disallowed control bytes.
- Post-audit `git apply --check editorial/patches/D18.diff` passed against HEAD
  `874f5e749a063d08aceb58c2f451d3c0b4ed9248`.
- Scratch worktree apply passed, followed by `git diff --check`.
- Scratch `python3 scripts/audit_references.py` passed.
- Scratch `latexmk -pdf -interaction=nonstopmode -halt-on-error` passed with
  output under `/tmp/masters-report-D18-revision-check.xvbHpA/build`.
- Scratch `pdfinfo` reported the revised D18 title, bounded subject, and
  focused keywords with no stale pressure-ratio metadata.
