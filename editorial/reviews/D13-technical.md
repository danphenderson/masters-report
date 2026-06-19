# D13 Technical Audit

Dispatch: D13-TECH
Mode: review only
Scope: `editorial/patches/D13.patch.json`, `editorial/patches/D13.diff`, current source, numerical ledgers, terminology ledger, section plan, and directly referenced Chapter 5 / Section 3.11 data assets.

## Verdict

No D13 technical blockers found. The patch applies cleanly, contains no control-byte corruption, builds in a scratch-applied tree, and keeps the 1D--3D comparison inside the approved diagnostic-discrepancy boundary.

## Mechanical Checks

- `editorial/claim_evidence_ledger.yaml` and root `claim_evidence_ledger.yaml` are byte-equivalent; both hash to `40eab1f8c3b2086fe94641e5ca92ce21aca6e1723f7fcce625282c41a24706c8`.
- No disallowed control bytes were found in `editorial/patches/D13.diff` or `editorial/patches/D13.patch.json`.
- `editorial/patches/D13.patch.json` parses as JSON.
- `git apply --check editorial/patches/D13.diff` passes.
- `git apply --numstat editorial/patches/D13.diff` reports changes only to:
  - `sections/02-comparison/index.tex`
  - `sections/03-methodology/index.tex`
  - `sections/03-conclusions/index.tex`
- Scratch-applied build from a tracked-HEAD archive succeeded:
  - apply tree: `/tmp/masters-report-D13-gF7Kbn`
  - build dir: `/tmp/masters-report-build-D13-eldTK8`
  - command: `latexmk -pdf -interaction=nonstopmode -halt-on-error -outdir=/tmp/masters-report-build-D13-eldTK8 final-report.tex`
- Build-log scan found no undefined references/citations. Remaining warnings were a pre-existing-style hyperref PDF-string warning and an overfull box in Section 4, outside the D13 patch area.
- Patched Section 3.11 retains literal TeX `\bar u` sequences; no backspace/control-byte corruption is present.

## Numerical Checks

Recomputed from `figures/static/static/data/stenosis-comparison/section-quadrature.dat`:

- Signed velocity bias:
  - C23: `0.479760...`, displayed as `0.480`.
  - C40: `0.908565...`, displayed as `0.909`.
- Mean absolute velocity discrepancy and RMS discrepancy remain:
  - C23: `0.505`, `0.664`, relative RMS `0.0277`.
  - C40: `0.966`, `1.87`, relative RMS `0.0688`.
- Signed physical-flow bias is correctly distinguished from mean absolute discrepancy:
  - C23: signed `0.047164...`, displayed as `0.0472`; MAD `0.0482`.
  - C40: signed `0.068377...`, displayed as `0.0684`; MAD `0.0709`.
- Axial 3D flow variation is supported:
  - C23: `7.7228%`, displayed as `7.7%`.
  - C40: `20.2162%`, displayed as `20.2%`.
- Top section-discrepancy rows match after rounding; the maximum row remains C40 at `z=2.261 cm`, `|d_u|=9.92 cm/s`, `|d_Q|=0.339 cm^3/s`, `759` triangles.
- Area audit values match `area-audit.dat` after rounding: C23 `0.045/0.281/0.389/2.94%`; C40 `0.005/0.291/0.397/4.46%`.
- `node-slab-sensitivity.csv` supports the stated time alignment: 1D completed time `1.0 s`, 3D XDMF time `0.9994999999999453 s`, offset `5.0e-4 s`.
- Direct radial equal-bin recomputation still conflicts with the old radial-summary table values, so D13's removal/withholding of that main-text numeric table is technically appropriate.

## Consistency Checks

- Chapter title becomes `Diagnostic 1D-3D Velocity Comparison`.
- Cross-model quantities in the patched Chapter 5 and conclusions use discrepancy terminology rather than obsolete error/accuracy wording.
- The old `E_{u,p}` / `E_{Q,p}` Section 3.11 notation is replaced by signed bias, `D_{u,1}`, `D_{u,2}`, `D_{u,\infty}`, relative RMS, and corresponding flow discrepancy metrics.
- `Aphys/a` and `Qphys/q` distinctions are preserved: `A_{1D}=\pi a`, `Q_{1D}=\pi q`, and `\bar u=q/a`.
- `R_0(z)` is used for static reference geometry and cut-area audit; D13 does not disturb the live `R_{\max}`-normalized wall-law denominator discussion.
- Boundary wording remains bounded as a fixed-area characteristic approximation under the subcritical gate; no exact-invariant claim is introduced.
- Current/deformed geometry and displacement application remain unresolved unless future evidence is added.
- The radial-profile numeric table is removed from main Chapter 5, and patched scans find no stale `tab:t1-radial-profile-summary` label or reference.
- The downstream discussion/conclusion no longer use obsolete cross-model `L^1/L^2/L^3` error wording for D13 metrics.
- DG degree range is not touched by this patch.

## Non-Blocking Notes

- The subcritical diagnostic table's alpha and radicand values are partly corroborated by `figures/static/static/data/package-benchmark/resolved3d.csv`; the lambda extrema are preserved from current source rather than separately exposed in the tracked CSVs I found. Since D13 moves/reframes that existing table rather than changing its values, I do not treat this as a D13 blocker.
- D13 leaves allowed negated scope language such as not-validation and not-accuracy claims; those are consistent with the terminology ledger.

STATUS: PASS
BLOCKERS: 0
MAJORS: 0
MINORS: 0
