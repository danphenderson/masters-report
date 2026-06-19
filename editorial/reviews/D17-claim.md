# D17 Claim Re-Audit

Dispatch: D17-CLAIM
Mode: review only

Reviewed revised files:
- `editorial/patches/D17.patch.json`
- `editorial/patches/D17.diff`
- `editorial/reviews/D17-writer-notes.md`

Against:
- `editorial/canonical_rq_answers.md`
- `editorial/claim_evidence_ledger.yaml`
- `editorial/terminology_ledger.yaml`

## Basis

- Confirmed live `HEAD` is `a45ec6e9c3996aa2a692bc0c913de91370108910`.
- Confirmed the revised patch still declares only `C-REST`, `C-OPERATOR`, `C-COMPARISON`, and `C-LIMITS`.
- Confirmed `jq empty editorial/patches/D17.patch.json` passes.
- Confirmed `git apply --check editorial/patches/D17.diff` passes.
- Scratch-applied the revised diff at `/tmp/masters-report-d17-reaudit.eLH3N7` and audited the post-apply claim surface.
- This re-audit did not edit manuscript source files or patch files.

## Findings

No blocking claim findings.

The revised `Q_comp` wording in Chapter 4 does not broaden the claim. It keeps `q_{\mathrm{comp}}=2.288/pi=0.7283 cm^3/s` as the solver-coordinate comparison-flow scale and `Q_{\mathrm{comp}}\approx2.288 cm^3/s` as the corresponding physical circular flow scale, then points to the axial-flow figure for that comparison-flow context. It continues to state that the zero-forcing rest-flow values are the same order as, and numerically close to, the comparison-flow scale. This preserves the rest-state failure as the principal numerical limitation and does not turn the value into validation, accuracy, or physiological evidence.

The radial-legend revision is layout-only. The TikZ legend offset changes from the prior placement to `(0,0.56cm)` above the two radial panels; plotted data, station labels, caption language, and the surrounding radial-profile caveat remain unchanged. The chapter still says the radial plots are qualitative secondary diagnostics and make no radial-bin numerical localization claim.

The new axial-flow figure and related text remain bounded to descriptive physical-flow and velocity discrepancies under the declared plane-quadrature operator. The text explicitly treats axial 3D flow variation as an unresolved matching gate, not a solved mechanism, and does not attribute the variation to 3D numerical state, boundary/history mismatch, geometry handling, operator sensitivity, or any other unique cause.

The simplified section-mean table continues to use discrepancy terminology for C23/C40 cross-model comparisons. A focused scan found no unqualified cross-model error wording in the revised active surface; remaining "error" wording is confined to verification contexts with declared references.

The unresolved 3D gates remain honest. Appendix H still states that raw XDMF/HDF5 velocity inputs are not archived and that current/deformed 3D geometry, displacement before cuts, wall/boundary/material histories, and exact-time 0.9995 s resampling remain unresolved unless a later release record adds those data.

Search hits for validation, accuracy, clinical, physiological, predictive, or causal language on the revised active surface are negative boundary statements, not positive claims. The revised D17 patch does not introduce physiological or clinical implication, unsupported causation, softened treatment of the rest-state failure, cross-model error language, or any claim that unmatched 3D conditions have been resolved.

STATUS: PASS
PROHIBITED CLAIMS: 0
TERMINOLOGY VIOLATIONS: 0
UNSUPPORTED INFERENCES: 0
