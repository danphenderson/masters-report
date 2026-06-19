# D12 Integration Report

Dispatch: D12

Scope integrated:

- `sections/04-verification/index.tex`
- `appendices/numerical-methods-details.tex`
- `figures/static/static/tables/verification/rest_state_drift.tex`

Prerequisites:

- Section Writer: `STATUS: READY_FOR_AUDIT`
- Open questions: 0
- Technical Auditor: `STATUS: PASS`, `BLOCKERS: 0`, `MAJORS: 0`
- Claim Auditor: `STATUS: PASS`, `PROHIBITED CLAIMS: 0`, `TERMINOLOGY VIOLATIONS: 0`, `UNSUPPORTED INFERENCES: 0`
- Adversarial Reviewer: `STATUS: ACCEPT`, `BLOCKERS: 0`, `MAJORS: 0`

Pre-apply checks:

- Source HEAD before apply: `73bc59cd1df87a1208640aec2c6ec748b627cb3c`
- `git apply --check editorial/patches/D12.diff`: pass
- Root and editorial claim ledgers: byte-identical, SHA256 `40eab1f8c3b2086fe94641e5ca92ce21aca6e1723f7fcce625282c41a24706c8`
- Patch touched only the reviewed D12 files listed above.

Applied change:

- Rewrote Chapter 4 around the evidence hierarchy: MMS evidence, geometry-rest preservation failure, boundary/CFL/positivity/conservation diagnostics, and secondary implementation-health checks.
- Revised the rest-state summary table to show peak and `t=1 s` solver `q` plus physical `pi q` values.
- Moved secondary benchmark, DG, backend-parity, resolved-output, rheology/profile, and stationary-Stokes records to Appendix G.
- Clarified that implemented DG support runs through `p=4` while selected benchmark rows may use narrower displayed degree sets.

Build verification:

- Pass 1: `latexmk -pdf -interaction=nonstopmode -halt-on-error -g -outdir=/tmp/masters-report-D12-build final-report.tex`
- Pass 2: `latexmk -pdf -interaction=nonstopmode -halt-on-error -g -outdir=/tmp/masters-report-D12-build final-report.tex`
- Logs:
  - `editorial/build_logs/D12-pass1.log`
  - `editorial/build_logs/D12-pass2.log`
- Undefined references: 0
- Undefined citations: 0
- Multiply-defined labels: 0

PDF inspection:

- Output inspected: `/tmp/masters-report-D12-build/final-report.pdf`
- Page count after D12: 92
- Rendered pages inspected: 36-40 and 72-76.
- Chapter 4 opening, MMS table, rest-state table, rest-state interpretation, and boundary diagnostics rendered without clipping or overlap.
- Appendix G moved tables and figures rendered legibly.

Residual minor issues:

- The second build reports one small overfull hbox: `4.6249pt` in Chapter 4 lines 38--44.
- Appendix G float placement leaves the G.3 paragraph continuing after moved G.2 figures on page 75; content remains readable.
- A source-facing CLI help string still says DG degree `0, 1, or 2`; D12 resolves the manuscript wording only, not the code help text.

Word count:

- Before: 4983
- After: 4662

STATUS: PASS
BLOCKERS: 0
MAJORS: 0
MINORS: 3
