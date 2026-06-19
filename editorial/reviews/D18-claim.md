# D18 Claim Re-Audit

Dispatch: D18-CLAIM
Mode: review only

Reviewed revised files:
- `editorial/patches/D18.patch.json`
- `editorial/patches/D18.diff`
- `editorial/reviews/D18-writer-notes.md`

Against:
- `editorial/canonical_rq_answers.md`
- `editorial/claim_evidence_ledger.yaml`
- `editorial/terminology_ledger.yaml`

## Basis

- Confirmed live `HEAD` is `874f5e749a063d08aceb58c2f451d3c0b4ed9248`.
- Confirmed the revised patch declares only the approved claim set: `C-MODEL`, `C-NUMERICS`, `C-MMS`, `C-REST`, `C-OPERATOR`, `C-COMPARISON`, and `C-LIMITS`.
- Confirmed `jq empty editorial/patches/D18.patch.json` passes.
- Confirmed `git apply --check editorial/patches/D18.diff` passes.
- Scratch-applied the revised diff at `/tmp/masters-report-d18-reaudit.G6u4KW` and audited the post-apply title, abstract, printed keywords, PDF metadata, and final organization paragraph.
- This re-audit did not edit manuscript source files or patch files.

## Findings

No blocking claim findings.

The prior D18 metadata blocker is resolved. The revised `preamble/hyperref.tex` replaces the stale PDF title, broad PDF subject, and old keyword list. It no longer contains `pressure-ratio outputs`, `blood flow simulation`, or the old "Mathematical Simulation of Blood Flow" framing. The active PDF metadata now matches the bounded D18 front-matter scope: numerical audit, reduced-order stenosis solver, diagnostic 1D--3D velocity comparison, manufactured-solution verification, geometry-rest equilibrium, plane-tetrahedron quadrature, and velocity discrepancy.

The proposed title is bounded to a numerical audit and diagnostic 1D--3D velocity comparison. It does not imply validation, accuracy, physiology, clinical use, pressure/FFR output, machine learning, stationary Stokes foregrounding, or causal interpretation.

The proposed abstract remains claim-bounded. It identifies the implemented solver and solver-coordinate map, names the principal MUSCL/Rusanov/SSPRK3 realization, states positive but bounded manufactured-solution evidence, and keeps the rest-state failure central: the current MUSCL/Rusanov realization does not preserve geometry rest, and artificial zero-forcing rest flow at `t=1 s` is the same order as the production comparison-flow scale. This does not soften the rest-state failure.

The abstract and metadata use discrepancy terminology for the C23/C40 cross-model comparison and contain no unqualified cross-model error wording. The comparison is presented only through the declared plane-tetrahedron quadrature operator for section area, physical flow, and area-mean axial velocity.

The unmatched 3D gates remain honest. The abstract still limits interpretation by unmatched or unpersisted 3D wall, boundary, material, history, current/deformed geometry information, unresolved axial variation in extracted 3D flow, and the `1.0 s` versus `0.9995 s` sample-time offset. The final organization paragraph says matched 3D metadata and production-sensitivity records are next required steps, not completed evidence.

Focused scans over the revised title, abstract, printed keywords, PDF metadata, and organization paragraph found no positive validation or accuracy wording, clinical or physiological implication, unsupported causation, pressure/FFR foregrounding, machine-learning foregrounding, or claim that unmatched 3D conditions have been resolved. Existing hits in the surrounding introduction are either negative boundary statements or outside the D18 front-matter focus.

STATUS: PASS
PROHIBITED CLAIMS: 0
TERMINOLOGY VIOLATIONS: 0
UNSUPPORTED INFERENCES: 0
