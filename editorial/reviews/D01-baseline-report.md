# D01 Baseline Report

## Scope

- Dispatch: D01-BASELINE
- Role: Build and Visual QA Agent
- Manuscript source mode: read-only
- TeX entrypoint: `final-report.tex`
- Source commit: `371ba631f7cb24a3463e4923696218304bc6ff09`
- Branch: `master`
- Pre-baseline dirty files:
  - `?? editorial/open_issues.yaml`
  - `?? editorial/run_state.yaml`

## Artifacts Saved

- `editorial/baseline/source_manifest.json`
- `editorial/build_logs/baseline-pass1.log`
- `editorial/build_logs/baseline-pass2.log`
- `editorial/baseline/final-report-baseline.pdf`
- `editorial/baseline/pdfinfo.txt`
- `editorial/baseline/checksums.sha256`
- `editorial/reviews/D01-baseline-report.md`

## Build Record

- Build command: `latexmk -pdf -interaction=nonstopmode -halt-on-error -g final-report.tex`
- Engine: `pdflatex` / pdfTeX
- `latexmk`: 4.87
- `pdflatex`: pdfTeX 3.141592653-2.6-1.40.29 (TeX Live 2026)
- `biber`: 2.21
- Output: 94 pages, 1,302,021 bytes

Both saved build passes exited successfully and reported:

- `Output written on final-report.pdf (94 pages, 1302021 bytes).`
- `Latexmk: All targets (final-report.pdf) are up-to-date`

## Manifest Summary

- Reachable TeX inputs recorded: 45
- Bibliography configuration: `preamble/bibliography.tex`
- Bibliography file: `references.bib`
- Bibliography backend/style: `biber`, `numeric`, `sorting=none`
- Generated table inputs referenced: 6
- TikZ figure inputs referenced: 7
- Rendered graphic assets referenced: 7
- Missing referenced manuscript assets: 0

## QA Findings

### BLOCKER

None. The manuscript built twice, no undefined references or citations were found, and no referenced generated table or figure asset was missing.

### MAJOR

1. Rebuilt PDF output is not byte-reproducible under the recorded forced build command. Pass 1 SHA-256 was `3ecf1f0181e3b89bc89ea47fe7f0d67cc000cf6d7d850937feae823eb2bbf08c`; pass 2 SHA-256 was `fb3fb5be4dadc0ad6f0fe77ed7128d9c74e763c60cdf17596c5b8d2f3be50c77`. The PDFs have the same page count and byte size; volatile PDF metadata timestamps are the likely cause.
2. Required editorial harness inputs are not yet reproducibly staged under `editorial/`. `claim_evidence_ledger.yaml`, `final_editorial_rewrite_workflow.md`, and `manuscript_agent_harness.yaml` are present only as ignored root files; `editorial/claim_evidence_ledger.yaml` and `editorial/manuscript_agent_harness.yaml` are absent. `canonical_rq_answers.md` is absent at both root and `editorial/`.

### MINOR

None found in the baseline log scan or sampled rendered-page inspection. Poppler rendered all 94 pages to temporary PNGs. Representative pages covering front matter, early figures, dense verification plots/tables, discussion text, appendix equations, hash tables, and references showed no sampled clipping or overlap. Exhaustive page-by-page visual release inspection remains a later release gate.

## Checksum Note

The requested checksum paths `editorial/claim_evidence_ledger.yaml` and `editorial/manuscript_agent_harness.yaml` do not exist in this checkout. `editorial/baseline/checksums.sha256` records the root harness files actually available and read during D01, plus the saved baseline artifacts.

STATUS: REVISE
BLOCKERS: 0
MAJORS: 2
MINORS: 0
