# D12 Writer Notes

Status: ready for audit.

Scope completed:

- Prepared a patch proposal for Chapter 4 in `sections/04-verification/index.tex`.
- Proposed a generated-fragment update to `figures/static/static/tables/verification/rest_state_drift.tex` so the main rest-state table reports both peak and `t=1 s` solver `q` and physical `pi*q` values.
- Proposed Appendix G movement for package benchmark, p/h DG demonstration, self-convergence, backend parity, stationary-Stokes, resolved-velocity benchmark, and rheology/profile sensitivity material.
- Did not edit manuscript source files, ledgers, run state, generated table sources, or prior review files.

D12 requirements addressed:

- Reordered Chapter 4 around the hierarchy: MMS evidence, geometry-rest preservation, boundary/CFL/positivity/conservation diagnostics, and secondary implementation-health checks.
- Described temporal MMS rows as time-step insensitivity rather than a clean temporal-order study.
- Made the geometry-rest failure the principal numerical result and stated that the principal MUSCL/Rusanov implementation is not well balanced.
- Compared the `t=1 s` rest-flow values directly with the production comparison-flow scale in solver `q` and physical `pi*q` units.
- Moved secondary self-convergence, backend parity, stationary-Stokes, broad rheology/profile, resolved-velocity benchmark, and nonselected DG material to Appendix G.
- Resolved the DG degree-range conflict by distinguishing implemented modal Legendre DG support `p=0,...,4` from descriptor-health/package-benchmark rows that may exercise only selected degrees such as `p=0,1,2`.

Word count:

- Before: 4983
- After: 4662
- Change: -321

Validation run:

- `jq empty editorial/patches/D12.patch.json`
- `git apply --check editorial/patches/D12.diff`
- `git diff -- sections/04-verification/index.tex appendices/numerical-methods-details.tex figures/static/static/tables/verification/rest_state_drift.tex`

Audit notes:

- Word count uses the full touched-file proposal scope: Chapter 4, Appendix G, and the rest-state table fragment.
- The proposed rest-state table values are derived from `figures/static/static/tables/verification/rest_state_drift.csv`; no underlying data changes are proposed.
- No integration-blocking open questions are recorded.
