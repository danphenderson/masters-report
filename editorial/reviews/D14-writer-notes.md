# D14 Writer Notes

Status: READY_FOR_AUDIT after local validation.

Scope: Chapters 6 and 7 only, proposed as a unified diff against `sections/03-conclusions/index.tex`. No manuscript source was edited.

Root `claim_evidence_ledger.yaml` and `editorial/claim_evidence_ledger.yaml` were compared with `cmp -s`; they are byte-equivalent in this checkout.

## Claim Handling

- Uses only approved claim IDs: C-MODEL, C-NUMERICS, C-MMS, C-REST, C-OPERATOR, C-COMPARISON, C-LIMITS.
- Reorients Discussion around direct RQ answers: implemented model/auditability, bounded verification support, rest-equilibrium failure, diagnostic comparison, unmatched conditions and next work.
- Reorients Conclusion around the required five contributions/limits and the required next numerical step: equilibrium-preserving discretization, then matched 3D metadata and production sensitivity.
- Keeps cross-model terminology as discrepancy.
- Keeps the radial-profile numeric table withheld from the main evidence path and treats radial plots as qualitative secondary diagnostics only.

## Numerical Handling

- Preserves D13 section metric values: signed velocity bias 0.480/0.909 cm/s; velocity MAD 0.505/0.966 cm/s; velocity RMS 0.664/1.87 cm/s; relative RMS 0.0277/0.0688; maxima 2.35 at z=2.291 and 9.92 at z=2.261.
- Preserves physical-flow discrepancy values: signed bias 0.0472/0.0684 cm^3/s; MAD 0.0482/0.0709 cm^3/s; RMS 0.0509/0.0893 cm^3/s.
- Preserves rest-state prominence: q_comp=0.7283 cm^3/s, t=1 s rest q values 0.7313/0.7324 cm^3/s, physical pi*q values 2.297/2.301 cm^3/s, peak rest drift 1.566/1.658 cm^3/s at t=0.01 s.
- Preserves unmatched-gate values: 0.9995 s versus 1.0 s sample time, 0.0005 s offset, and 7.7%/20.2% axial 3D flow variation.

## Word Count

TeX-ish metadata count: 1366 -> 1315.

## Validation

- `jq empty editorial/patches/D14.patch.json` passed.
- Control-byte scan over `editorial/patches/D14.patch.json` and `editorial/patches/D14.diff` found 0 control bytes.
- `git apply --check editorial/patches/D14.diff` passed.
- `git status --short` shows only the three D14 proposal artifacts as untracked; no manuscript source files were changed.
