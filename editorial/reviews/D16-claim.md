# D16 Claim Final Re-Audit

Review basis:

- Live checkout was confirmed at `beb774d8d32addf4fd64fae722b51ce106b9671f`.
- Reviewed final revised `editorial/patches/D16.diff`,
  `editorial/patches/D16.patch.json`, and
  `editorial/reviews/D16-writer-notes.md` against
  `editorial/canonical_rq_answers.md`,
  `editorial/claim_evidence_ledger.yaml`, and
  `editorial/terminology_ledger.yaml`.
- `git apply --check editorial/patches/D16.diff` succeeds.
- `editorial/patches/D16.patch.json` parses as valid JSON and records
  `julia_test_command` in the proposed release manifest metadata.
- Scratch-applied final D16 under
  `/tmp/masters-report-d16-final-audit.p9bQE5` to inspect proposed post-patch
  text without modifying manuscript source in the main checkout.
- No manuscript source, patch file, bibliography file, figure asset, or release
  manifest was edited in this review lane.

Findings:

- Prior software-terminology issue remains resolved. Appendix H says
  `Julia package tests are run through the repository launcher`, not package
  validation wording (`appendices/code-and-ai-use.tex:24` in the scratch-applied
  tree).
- Prior manifest-key issue remains resolved. The proposed
  `editorial/release/D16-release-manifest.json` uses `julia_test_command`
  (`editorial/release/D16-release-manifest.json:184`) and does not contain
  `julia_validation_command`.
- The restored Chapter 3 provenance hunk does not broaden claims. It changes
  only the asset provenance sentence to say the baseline regeneration command,
  source-path convention, and file-hash manifest pointer are listed in
  Appendix H (`sections/03-methodology/index.tex:678`-`682` in scratch). It does
  not alter the diagnostic comparison, validation-boundary, or unresolved-gate
  claims around it.
- No positive validation, accuracy, physiological, clinical, predictive,
  pressure-accuracy, FFR, or unsupported causal implication was found in the
  proposed included source. Remaining validation/clinical hits are negative
  boundary statements, such as `not physical validation` and `not a clinical
  measurement model`.
- Cross-model language is ledger-aligned. Proposed C23/C40 and backend
  comparison language uses diagnostic comparison/discrepancy wording rather than
  unqualified cross-model error language.
- Unmatched 3D conditions remain honest. Appendix H states that raw XDMF/HDF5
  velocity inputs are not archived, that generated CSV and PGFPlots-ready assets
  are what the report archives, and that current/deformed 3D geometry,
  displacement application before plane cuts, wall/boundary/material histories,
  and exact-time `0.9995 s` resampling remain unresolved unless a later release
  record adds those data.
- The rest-state failure is not softened. Appendix G still states that the
  displayed operator is not exactly well-balanced for the geometry-rest state
  and describes the nonzero discrete residual mechanism.

STATUS: PASS
PROHIBITED CLAIMS: 0
TERMINOLOGY VIOLATIONS: 0
UNSUPPORTED INFERENCES: 0
