# StenoticHemodynamics Authoritative Fleet TODO

Date: 2026-06-24

This file is the live package dispatch document. Historical completed lanes
were removed from the active queue during this refresh; use git history and
`public/docs/stenotic-hemodynamics/**` for detailed implementation records.

## Live State

- Current branch state at refresh start: `main...origin/main [ahead 5]`, clean.
- Latest package integration commit: `20f487a Refresh native FSI contract and
  resume stewardship`.
- `20f487a` landed the current code wave: canonical
  `ClassicalParabolicOneDModel`, canonical axial/reconstructed-axial
  observation terminology, `diagnostic_pressure(...)` /
  `evolution_pressure(...)`, Gridap quadrature/backflow diagnostics, repeated
  deformed-domain native-FSI classification, schema-v3 durable checkpoint
  sidecars, and qualified internal split-run resume.
- Commit-readiness validation for `20f487a` passed:
  `pipenv run ops-orchestrate ready-to-commit --allow-unclassified`.

## Claim Boundary

- Exact Section 4.1 boundary-mode support exists in the low-level Gridap path
  and tiny partitioned production smoke-scale harness.
- `:poiseuille_inlet_zero_outlet_stress_section41` remains
  smoke-scale/operator-readiness evidence until production-scale execution and
  imported-data parity pass.
- Paper-grade native resolved-FSI reproduction, imported parity for the Gridap
  production path, monolithic ALE FSI, and strong moving-wall fluid-boundary
  fidelity remain unestablished.
- The separate `canic-replication section41` source-artifact workflow owns the
  promoted manuscript Section 4.1 comparison against restored upstream bundles.
- Post-sampling outlet pressure normalization is diagnostic/export-only and is
  not a Gridap pressure nullspace constraint.
- Native resolved-FSI production/Gridap arrays remain `Float64`-oriented.
- Schema-v3 durable checkpoints support qualified internal split-run resume for
  package/operator validation only. Public/default restart/resume and CLI
  resume remain unsupported and fail closed.
- Timing sidecars, matrix/RHS fingerprints, viewer controls, and restart
  checkpoint sidecars are execution/inspection metadata. They do not promote
  native resolved-FSI claims or manuscript evidence.

## Active Dispatch

### Lane 10C: Sev23 Preproduction Batch Execution

Status: open as a deliberate long-running compute lane. Current-source
dry-run/status evidence is refreshed; actual preproduction execution and
imported parity remain unrun.

Objective: execute the exact-boundary `sev23` preproduction gate from
`public/docs/stenotic-hemodynamics/section-4-1-production-validation-plan.md`
without changing numerical semantics or widening claims.

Current dry-run evidence:

- case/resolution: `sev23`, `(axial=80, radial=4, angular=24)`;
- controls: `dt_s=1e-4`, `T=0.1`, final snapshot only,
  `u_max=45 cm/s`, exact Section 4.1 inlet/outlet mode;
- production spec digest: `9d1cfb96eb525113`;
- estimated time steps: `1000`;
- expected fluid-solve upper bound: `1001`;
- estimated runtime: `63000 s`;
- required override flags: none;
- snapshot/payload guards: passing;
- imported bundle: case `77` available.

Dispatch rules:

1. Start only in a deliberate long-running compute session. Do not launch this
   from opportunistic package-worker or TODO-cleanup rounds.
2. Reconfirm the dry-run immediately before execution if case parameters,
   guard policy, imported-data roots, or output schedules changed.
3. Write outputs to ignored scratch paths under `tmp/simulations/output/**`.
4. Parse and review `batch_status.jsonl`, `batch_status.csv`,
   `batch_benchmark.json`, `snapshot_manifest.csv`,
   `snapshot_diagnostics.csv`, and `restart_metadata.json`.
5. Validate finite fields, positive radii/cell orientation, wall displacement,
   pressure normalization, importer round trip, checkpoint metadata, and
   bounded coupling status.
6. Run imported-data parity as a separate skip-safe lane. `sev23` maps to
   imported case `77`, `sev40` maps to `60`, and `sev50` remains expected-skip
   unless a bundle is explicitly supplied.
7. Send a report-owner handoff only after production execution and parity gates
   pass. Do not edit manuscript source, `report/assets/**`, or
   `public/final-report.pdf` from this package lane.

### Conditional Future Work

These are not active TODOs for the next package round:

- Assembly optimization: only reopen after a concrete design identifies which
  parts of Gridap affine-operator construction are invariant under changing
  geometry, Picard/advection state, boundary values, pressure policy, mesh
  topology, and constrained DOF maps. Numeric factorization reuse is currently
  blocked by changing matrix values.
- Public/default resume or CLI resume: only reopen after production-scale
  resume validation, broader split-run equivalence, and imported-parity resume
  coverage justify a public contract change.
- Viewer/report promotion: only reopen from the report side after accepted
  production/parity evidence creates a reader-facing figure/table objective.

## Orchestration Rules

- Start substantial package work with:

  ```bash
  pipenv run ops-orchestrate status --json
  ```

- Treat the live checkout as authority.
- Keep one writer per disjoint file set.
- Preserve public exports, CLI semantics, artifact filenames, importer
  schemas, and restart metadata compatibility unless a lane explicitly widens
  scope.
- Keep report/manuscript files under report ownership. Package lanes may update
  this TODO and public package docs, but should not promote claims directly.

## Validation

For this TODO-only refresh:

```bash
git diff --check -- packages/stenotic-hemodynamics/TODO.md report/TODO.md
pipenv run ops-orchestrate docs-contract
```

For future package implementation lanes, run the focused validation selected by
the touched surfaces and close with:

```bash
pipenv run ops-orchestrate ready-to-commit --allow-unclassified
```
