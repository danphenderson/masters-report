# D14 Adversarial Review

Dispatch: D14-ADV
Mode: Review only

## Inputs Reviewed

- `editorial/patches/D14.patch.json`
- `editorial/patches/D14.diff`
- `editorial/canonical_rq_answers.md`
- `editorial/claim_evidence_ledger.yaml`
- `claim_evidence_ledger.yaml`
- `editorial/numerical_ledger.yaml`
- `editorial/terminology_ledger.yaml`
- `editorial/section_plan.yaml`
- Current Chapter 6 and 7 source: `sections/03-conclusions/index.tex`
- Directly referenced methodology, verification, and comparison sources:
  `sections/03-methodology/index.tex`, `sections/04-verification/index.tex`,
  and `sections/02-comparison/index.tex`

## Checks

- `git apply --check editorial/patches/D14.diff` succeeds against the current
  checkout at `HEAD` `6f03f6e`. The tracked target source files are clean
  relative to `HEAD`, so the check reflects the current `HEAD` text.
- `git apply --stat editorial/patches/D14.diff` reports one proposed source
  change: `sections/03-conclusions/index.tex`, with 145 insertions and 150
  deletions.
- `editorial/claim_evidence_ledger.yaml` and root `claim_evidence_ledger.yaml`
  are byte-equivalent; both have SHA-256
  `40eab1f8c3b2086fe94641e5ca92ce21aca6e1723f7fcce625282c41a24706c8`.
- `jq empty editorial/patches/D14.patch.json` passes.

## Adversarial Answers

The principal claim is unmistakable. The proposed Discussion and Conclusion
center the contribution on an authoritative implemented-model specification,
bounded MMS-based implementation-verification evidence, exposure of the
geometry-rest failure, and a diagnostic 1D-3D velocity discrepancy record under
the declared plane-tetrahedron operator.

The rest-state defect is proportionately prominent. It gets its own Discussion
subsection, is quantified against the comparison-flow scale, and is repeated in
the Conclusion as the decisive geometry-rest limitation. The required next
numerical step is stated as equilibrium-preserving discretization or
reconstruction followed by a repeated rest-state audit before stronger
production-comparison claims.

I do not see a sentence in the proposed D14 text that would reasonably be
mistaken for validation, pressure or FFR accuracy, clinical or physiological
evidence, predictive evidence, production accuracy, or causal evidence. The MMS
language remains bounded to the declared forced operator, and the C23/C40
language remains descriptive and operator-specific.

Unmatched conditions are disclosed before interpretation. The proposed 6.5
subsection restates the unpersisted 3D wall, wall-motion, boundary, material,
history, geometry-state, sample-time, and axial-flow-variation gates before
describing required next work. Chapter 5 already introduced those gates before
the metric tables, so D14 remains consistent with the evidential ordering.

The Discussion directly answers RQ1, RQ2, and RQ3 in the requested 6.1-6.5
structure. Section 6.1 answers RQ1 through the implemented model contract, 6.2
and 6.3 answer RQ2 by separating bounded MMS support from rest-equilibrium
failure, 6.4 answers RQ3 through discrepancy metrics under the declared
operator, and 6.5 states the unmatched gates and required next work.

The Conclusion follows the requested five-part structure. Its five paragraphs
cover the implemented-model contribution, bounded MMS evidence, the central
rest-equilibrium limitation, the descriptive 1D-3D comparison result, and the
next required implementation sequence.

D13 metrics are represented as discrepancy rather than error or accuracy. The
proposed text uses signed bias, mean absolute velocity discrepancy, RMS velocity
discrepancy, relative RMS discrepancy, physical-flow discrepancy, and largest
section discrepancy. It does not reintroduce obsolete cross-model error
terminology.

The radial-profile table conflict is not used for numeric support. D14 says the
radial-summary numeric table is withheld from the main evidence path pending
reconciliation, treats radial plots as qualitative secondary diagnostics, and
makes no radial-bin numerical localization claim.

The repeated clinical, pressure, and FFR exclusions are reduced rather than
inflated. The proposed text removes the broad limitation inventory from the old
Discussion and Conclusion while preserving the necessary bounded-evidence
framing already established by Chapters 4 and 5.

I do not see retained background that is merely correct rather than necessary.
The retained material in D14 is tied to direct RQ answers, the section-plan
structure, numerical ledgers, or unresolved interpretation gates.

## Findings

No BLOCKER, MAJOR, or MINOR findings.

STATUS: ACCEPT
BLOCKERS: 0
MAJORS: 0
MINORS: 0
