# D16 Writer Notes

Status: READY_FOR_AUDIT after local checks.

Scope: Appendices and code/release statement, plus one directly dependent Chapter 3 provenance wording hunk. Manuscript source was not edited in the main checkout.

## Audit Response

- Technical major: corrected the proposed Appendix G SSPRK3 display so the final RHS stage is evaluated at `t^n + \tfrac12\Delta t_n`, matching `src/StenosisHemodynamics/numerics/solver.jl` where the third RHS call uses `t + 0.5 * dt`.
- Claim terminology: changed the package-check wording to “Julia package tests” and renamed the release-manifest command key to `julia_test_command`.
- Adversarial polish: split the Appendix H package-benchmark provenance sentence, moved the release-manifest path into a breakable listing, and split the raw-input path/URL/commit/subtree provenance into listings to clear the small Appendix H overfull path line while preserving the same facts.
- Scope note: restored one narrow Chapter 3 provenance wording hunk so the main text points to a file-hash manifest pointer in Appendix H rather than in-PDF hash tables. This is a directly dependent provenance wording change, not a scientific claim change.

## Claim Handling

- Uses only approved claim IDs: C-MODEL, C-NUMERICS, C-MMS, C-REST, C-OPERATOR, C-COMPARISON, C-LIMITS.
- Removes Appendices D-F from the proposed manuscript input graph instead of deleting their source files.
- Compresses Appendix B/C to essential notation and retained output conventions.
- Compresses Appendix G while retaining the exact implemented MUSCL/Rusanov/SSPRK3 operator, the alpha=1 fixed-area boundary rule, secondary implementation-health anchors, and the full rest-state drift grid.
- Rewrites Appendix H as a concise code availability and release record, with large hash inventories moved to a proposed tracked manifest outside the PDF.
- Keeps the geometry-rest failure explicit: the displayed operator is not claimed to be exactly well balanced.

## Release Gate

- No tag points at the D16 proposal base commit. The proposal records `beb774d8d32addf4fd64fae722b51ce106b9671f` as the base commit and uses `D16-INTEGRATION-RELEASE-ID` as an integration-time placeholder for the final release commit or tag.
- The proposed machine-readable manifest is `editorial/release/D16-release-manifest.json`.
- Raw 3D XDMF/HDF5 inputs remain nonarchived local inputs under `simulations/data/3d/canic_case3/`, sourced from `qcutexu/Extended-1D-AQ-system` commit `056a9da2b36b480691f18025d242d2c00f6e7180`.

## Numerical Handling

- No scientific values are changed.
- Aphys=pi*a, Qphys=pi*q, mean velocity q/a, DG support p=0,...,4, comparison command parameters, and the full rest-state grid are preserved.
- Cross-model quantities remain discrepancies, not accuracy or validation evidence.

## Word Count

TeX-ish appendix/provenance-scope count: 8404 -> 2751.

## Checks

- `jq empty editorial/patches/D16.patch.json`
- Control-byte scan over `editorial/patches/D16.patch.json` and `editorial/patches/D16.diff`
- `git apply --check editorial/patches/D16.diff`
- Scratch apply followed by `git diff --check`
- Scratch apply followed by `python3 scripts/audit_references.py --repo <scratch>`
- Scratch apply followed by `jq empty editorial/release/D16-release-manifest.json`
- Scratch apply followed by `latexmk -pdf -interaction=nonstopmode -halt-on-error -outdir=/tmp/masters-report-D16-recheck-build final-report.tex`
