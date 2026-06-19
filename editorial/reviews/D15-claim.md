# D15 Claim Audit

Review basis:

- Live checkout was confirmed at `c74c371c13ab7314c9a10aa3045cb5f565d2adcc`.
- Reviewed `editorial/patches/D15.diff` and
  `editorial/patches/D15.patch.json` against
  `editorial/canonical_rq_answers.md`,
  `editorial/claim_evidence_ledger.yaml`, and
  `editorial/terminology_ledger.yaml`.
- `git apply --check editorial/patches/D15.diff` succeeds.
- `editorial/patches/D15.patch.json` parses as valid JSON.
- Scratch-applied `editorial/patches/D15.diff` under
  `/tmp/masters-report-d15-audit.LSOA1n`, initialized that scratch copy as a
  temporary git index for `git ls-files`-based checks, and ran
  `python3 scripts/audit_references.py --repo /tmp/masters-report-d15-audit.LSOA1n`;
  the reference audit passed.
- No manuscript source, bibliography file, reference asset, or patch file was
  edited in this review lane.

Findings:

- No blocking claim finding. The proposed Section 1.1 opens with the numerical
  audit problem and explicitly says the report does not infer a patient outcome
  (`sections/01-intro/pressure-flow-motivation.tex:4`).
- The retained anatomy-function motivation is compact and bounded to model
  observables, closure choices, boundary approximation, and the observation
  operator (`sections/01-intro/pressure-flow-motivation.tex:14`).
- The proposed introduction keeps the rest-state failure strong: it names the
  `non-well-balanced geometry-rest drift` in Section 1.1 and the existing
  introduction describes the retained artificial flow as same-order with the
  production comparison-flow scale and a principal numerical limitation
  (`sections/01-intro/pressure-flow-motivation.tex:19`;
  `sections/01-intro/index.tex:78`).
- Chapter 2 is focused on stenosis-aware 1D area-flow models, closure
  dependence, well-balanced methods, implementation verification, observation
  operators, and the verification/comparison/validation distinction
  (`sections/02-background/index.tex:4`;
  `sections/02-background/state-of-art-models.tex:39`;
  `sections/02-background/state-of-art-numerics.tex:1`).
- The validation wording that remains in the D15 proposal is boundary-setting
  language, not a positive validation or accuracy claim. Chapter 2 says it is
  not a comprehensive systematic review, separates implementation verification
  from diagnostic cross-model comparison, and reserves external validation for a
  separately matched accepted target (`sections/02-background/index.tex:8`;
  `sections/02-background/state-of-art-numerics.tex:42`).
- Cross-model language is ledger-aligned. The proposed D15 source uses
  discrepancy/comparison/operator wording for C23/C40 and does not introduce
  unqualified cross-model error language in Sections 1.1-1.3 or Chapter 2
  (`sections/02-background/state-of-art-numerics.tex:35`;
  `sections/02-background/synthesis-gap.tex:11`).
- Unmatched 3D conditions are not presented as resolved. The proposed Chapter 2
  keeps resolved 3D data as available velocity data with matching limits, and
  external validation remains conditional on matched geometry, wall/material
  assumptions, boundary histories, timing, and measurement or reference
  conventions (`sections/02-background/state-of-art-models.tex:24`;
  `sections/02-background/state-of-art-numerics.tex:45`).
- Removed pressure/FFR derivations, Clay/global-regularity material, broad
  cardiac CFD/model-family material, and surrogate/operator-learning material
  are not reintroduced into the proposed D15 source blocks. The D15 citation
  scan found no removed clinical FFR/CT-FFR, Clay, broad CFD, or surrogate keys
  in the proposed Sections 1.1-1.3 and Chapter 2.
- The reference-inventory sync does not imply citation support in the D15
  manuscript source. Rows for fully removed main-text support are marked
  `background`, `report-adjacent`, or `future-work` with notes such as uncited
  after the D15 focused main-text revision; rows that remain `current-cited`
  point to surviving citations outside this D15 main-text lane, such as appendix
  notation or Chapter 4 numerics.

STATUS: PASS
PROHIBITED CLAIMS: 0
TERMINOLOGY VIOLATIONS: 0
UNSUPPORTED INFERENCES: 0
