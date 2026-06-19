# D16 Adversarial Review

Dispatch: D16-ADV final re-audit
Mode: Review only; no manuscript source or patch files edited.

## Inputs Reviewed

- `editorial/patches/D16.diff`
- `editorial/patches/D16.patch.json`
- `editorial/reviews/D16-writer-notes.md`
- Scratch-applied D16 tree at `HEAD` `beb774d8d32addf4fd64fae722b51ce106b9671f`
- Current and post-patch touched sources:
  `sections/03-methodology/index.tex`,
  `appendices/acronyms.tex`,
  `appendices/code-and-ai-use.tex`,
  `appendices/domain-notation.tex`,
  `appendices/index.tex`,
  `appendices/mathematical-notation.tex`, and
  `appendices/numerical-methods-details.tex`
- Implementation spot-check for the revised SSPRK3 display:
  `src/StenosisHemodynamics/numerics/solver.jl`

## Verification

- Live `HEAD` matches the requested commit:
  `beb774d8d32addf4fd64fae722b51ce106b9671f`.
- `git apply --check editorial/patches/D16.diff` passed.
- `git apply --check --whitespace=error editorial/patches/D16.diff` passed.
- `jq empty editorial/patches/D16.patch.json` passed.
- D16 was applied in a temporary Git clone only.
- `python3 scripts/audit_references.py` passed in the scratch-applied tree.
- `jq empty editorial/release/D16-release-manifest.json` passed in the scratch-applied tree.
- `python3 scripts/audit_tex_preamble.py` passed in the scratch-applied tree.
- `git diff --check` passed in the scratch-applied tree.
- Scratch `latexmk -pdf -interaction=nonstopmode -halt-on-error -outdir=/tmp/masters-report-D16-final-build final-report.tex` completed.
- Log scan found no undefined citation/reference or multiply-defined-label warnings. Remaining warnings were existing hyperref PDF-string warnings and small layout warnings outside Appendix H.
- The revised SSPRK3 display matches the implementation: the third RHS evaluation uses `t + 0.5 * dt` in `src/StenosisHemodynamics/numerics/solver.jl`.

## Prior Minor Status

- Stale Chapter 3 file-hash wording: resolved. The revised Chapter 3 sentence now points to a "file-hash manifest pointer" in Appendix H rather than saying that Appendix H itself lists file hashes.
- Appendix H raw-input overfull: resolved. The raw-input provenance is split across prose and listings, and the scratch build no longer reports an Appendix H overfull box.

## Adversarial Answers

1. The principal claim is unmistakable. D16 presents appendix support for a bounded numerical-methods and provenance claim: implemented solver contract, rest-state defect record, diagnostic velocity comparison limits, and release manifest pointers. It does not recast the work as external validation or a clinically accurate stenosis model.

2. The rest-state defect is proportionately prominent. Appendix G retains the non-well-balanced operator caveat and the full rest-grid record, while the manuscript's main interpretation remains centered on the geometry-rest defect rather than burying it in appendix machinery.

3. I do not find a sentence that can reasonably be mistaken for validation or accuracy evidence. Uses of validation language are either negated physical-validation statements or bounded package-test/release-gate wording, and the C23/C40 comparison remains explicitly diagnostic.

4. Unmatched conditions are disclosed before interpretation. Appendix H states that raw resolved-3D inputs are not archived, gives the expected local source convention and upstream repository provenance, and lists unresolved geometry, displacement, wall/boundary/material, and exact-time resampling gates before the comparison is used interpretively.

5. The section answers the research-question structure through necessary appendix support. It preserves the evidence needed for the numerical-method, rest-state, and comparison/provenance claims without opening a new unsupported research claim.

6. I do not see retained background that is merely correct rather than necessary. The patch removes dormant Appendix D-F material from the include graph and keeps only notation, conventions, numerical-method details, and release/provenance records that support active claims.

## Findings

No BLOCKER, MAJOR, or MINOR findings.

STATUS: ACCEPT
BLOCKERS: 0
MAJORS: 0
MINORS: 0
