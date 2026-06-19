# D13 Claim Audit

No blocking claim findings in the revised D13 patch.

Review basis:

- Current checkout confirmed at `263b4a9`.
- `git apply --check editorial/patches/D13.diff` succeeds, and the stricter
  `git apply --check --whitespace=error editorial/patches/D13.diff` also
  succeeds.
- `editorial/patches/D13.patch.json` parses as valid JSON.
- `editorial/claim_evidence_ledger.yaml` and the root
  `claim_evidence_ledger.yaml` are byte-identical
  (`40eab1f8c3b2086fe94641e5ca92ce21aca6e1723f7fcce625282c41a24706c8`).
- Reviewed the D13 diff and patch metadata against the canonical RQ answers,
  claim ledger, numerical ledger, terminology ledger, section plan, current
  Chapter 5 source, Section 3.11, and dependent discussion/conclusion text.
- Applied D13 in a scratch copy under `/tmp` for post-patch terminology and
  artifact-safety scans; no manuscript source was edited.

Findings:

- Chapter 5 is diagnostic/descriptive only. The proposed title and opening frame
  the chapter as a diagnostic cross-model comparison and explicitly exclude
  validation, accuracy, pressure-drop, FFR, physiological, clinical, predictive,
  and causal evidence.
- The rest-state failure is not softened. The opening keeps the zero-input
  rest-state drift at the same order as the comparison-flow scale and limits the
  C23/C40 values to single-realization descriptors rather than a clean
  discretization-accuracy study.
- Unmatched conditions are disclosed before interpretation: C23/C40 source IDs,
  `1.0 s` versus `0.9995 s`, unresolved current/deformed geometry status, and
  unpersisted 3D wall, wall-motion, inlet/outlet, material, and transient
  history metadata.
- The flow/area decomposition is framed as bookkeeping, not causal attribution.
  The table heading says "Larger bookkeeping term at max" and the prose/caption
  state that the split does not identify a mechanism.
- Axial 3D-flow variation is placed before section-velocity interpretation. The
  proposed 7.7% and 20.2% values match direct recomputation from
  `section-quadrature.dat`.
- The sample-time offset is reported rather than resolved: the proposed text
  keeps the `5\times10^{-4}` s offset visible and does not claim exact-time
  matching.
- The current/deformed geometry question remains unresolved. The static
  cut-area audit is not promoted into evidence that displacement application or
  final-time deformed-wall plane cuts have been resolved.
- The radial-profile numeric table is withheld/removed from the main chapter,
  and the proposed discussion/conclusion do not use radial-bin numeric values as
  principal or secondary support while the recomputation conflict remains.
- The Section 3.11 and dependent discussion/conclusion wording use signed bias,
  mean absolute discrepancy, RMS discrepancy, maximum discrepancy, and relative
  RMS discrepancy language; obsolete cross-model error and L3 wording is removed.
- New signed-bias values are supported by the tracked section data: `mean(u1D) -
  mean(u3D)` rounds to `0.480` and `0.909` cm/s, and `mean(Q1D) - mean(Q3D)`
  rounds to `0.0472` and `0.0684` cm^3/s. Mean absolute and RMS discrepancy
  values match the numerical ledger.
- No control-byte corruption is present in the diff, JSON patch artifact, or
  scratch-applied post-patch files; the `\bar` formulas are intact.

STATUS: PASS
PROHIBITED CLAIMS: 0
TERMINOLOGY VIOLATIONS: 0
UNSUPPORTED INFERENCES: 0
