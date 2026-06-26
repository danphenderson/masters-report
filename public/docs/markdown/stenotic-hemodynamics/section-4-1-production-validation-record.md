# Section 4.1 Production Validation Record

This record executes the Section 4.1 production-validation lane as a bounded
status-and-guard handoff. It does not promote manuscript claims or publish solver
artifacts.

Issue: `danphenderson/masters-report#9`  
Record date: 2026-06-26  
Validation plan:
[`section-4-1-production-validation-plan.md`](section-4-1-production-validation-plan.md)

## Execution boundary

The production target cases are long-running native resolved-FSI jobs:

- cases: `sev23`, `sev40`, `sev50`;
- mesh: `(axial, radial, angular) = (120, 5, 32)`;
- expected tetrahedra per case: `103680`;
- expected nodes per case: `19481`;
- time step: `dt_s = 1e-4`;
- final time and snapshot: `tfinal_s = 1.0`, `snapshot_times_s = (1.0,)`;
- boundary mode: `poiseuille_inlet_zero_outlet_stress_section41`;
- inlet maximum velocity: `45 cm/s`;
- output root:
  `tmp/simulations/output/native-resolved-fsi-production`.

This lane records the production target plan and gate status. It intentionally
does not advance the manuscript-safe claim because production solver artifacts
were not generated and reviewed in this bounded handoff.

## Commands

The following native-status commands define the production target runs and the
deterministic output contracts. Each command is a dry-run/status command; it
does not run the solver or write solver outputs.

```bash
# Run from the repository root.

packages/stenotic-hemodynamics/bin/stenotic-hemodynamics fsi native-status \
  --case-id sev23 \
  --mesh 120x5x32 \
  --dt 1.0e-4 \
  --tfinal 1.0 \
  --snapshot-times 1.0 \
  --output-root tmp/simulations/output/native-resolved-fsi-production \
  --inlet-outlet-boundary-mode poiseuille_inlet_zero_outlet_stress_section41 \
  --inlet-umax 45.0 \
  --wall-density 1.055 \
  --status-every 1000

packages/stenotic-hemodynamics/bin/stenotic-hemodynamics fsi native-status \
  --case-id sev40 \
  --mesh 120x5x32 \
  --dt 1.0e-4 \
  --tfinal 1.0 \
  --snapshot-times 1.0 \
  --output-root tmp/simulations/output/native-resolved-fsi-production \
  --inlet-outlet-boundary-mode poiseuille_inlet_zero_outlet_stress_section41 \
  --inlet-umax 45.0 \
  --wall-density 1.055 \
  --status-every 1000

packages/stenotic-hemodynamics/bin/stenotic-hemodynamics fsi native-status \
  --case-id sev50 \
  --mesh 120x5x32 \
  --dt 1.0e-4 \
  --tfinal 1.0 \
  --snapshot-times 1.0 \
  --output-root tmp/simulations/output/native-resolved-fsi-production \
  --inlet-outlet-boundary-mode poiseuille_inlet_zero_outlet_stress_section41 \
  --inlet-umax 45.0 \
  --wall-density 1.055 \
  --status-every 1000
```

Historical runner note: the same repository-relative status contract was tried
from a GitHub runner checkout with Julia 1.12.6, but package loading entered a
long dependency precompile path and was stopped before solver/status output was
emitted. The status command contract above remains the recorded production lane;
the production solver was not launched.

## Output paths

The deterministic production roots are:

| Case | Native output directory | Observation CSV | Summary CSV |
| --- | --- | --- | --- |
| `sev23` | `tmp/simulations/output/native-resolved-fsi-production/sev23/120x5x32/boundary-poiseuille_inlet_zero_outlet_stress_section41-umax45/partitioned-production-dt0p0001-tfinal1/snapshot-t1` | `tmp/simulations/output/native-resolved-fsi-production/sev23/120x5x32/boundary-poiseuille_inlet_zero_outlet_stress_section41-umax45/partitioned-production-dt0p0001-tfinal1/snapshot-t1/section41-observations/section41_observations.csv` | `tmp/simulations/output/native-resolved-fsi-production/sev23/120x5x32/boundary-poiseuille_inlet_zero_outlet_stress_section41-umax45/partitioned-production-dt0p0001-tfinal1/snapshot-t1/section41-observations/section41_observation_summary.csv` |
| `sev40` | `tmp/simulations/output/native-resolved-fsi-production/sev40/120x5x32/boundary-poiseuille_inlet_zero_outlet_stress_section41-umax45/partitioned-production-dt0p0001-tfinal1/snapshot-t1` | `tmp/simulations/output/native-resolved-fsi-production/sev40/120x5x32/boundary-poiseuille_inlet_zero_outlet_stress_section41-umax45/partitioned-production-dt0p0001-tfinal1/snapshot-t1/section41-observations/section41_observations.csv` | `tmp/simulations/output/native-resolved-fsi-production/sev40/120x5x32/boundary-poiseuille_inlet_zero_outlet_stress_section41-umax45/partitioned-production-dt0p0001-tfinal1/snapshot-t1/section41-observations/section41_observation_summary.csv` |
| `sev50` | `tmp/simulations/output/native-resolved-fsi-production/sev50/120x5x32/boundary-poiseuille_inlet_zero_outlet_stress_section41-umax45/partitioned-production-dt0p0001-tfinal1/snapshot-t1` | `tmp/simulations/output/native-resolved-fsi-production/sev50/120x5x32/boundary-poiseuille_inlet_zero_outlet_stress_section41-umax45/partitioned-production-dt0p0001-tfinal1/snapshot-t1/section41-observations/section41_observations.csv` | `tmp/simulations/output/native-resolved-fsi-production/sev50/120x5x32/boundary-poiseuille_inlet_zero_outlet_stress_section41-umax45/partitioned-production-dt0p0001-tfinal1/snapshot-t1/section41-observations/section41_observation_summary.csv` |

Expected sidecars under each native output directory:

- `snapshot_manifest.csv`;
- `snapshot_diagnostics.csv`;
- `restart_metadata.json`;
- `batch_status.jsonl`;
- `batch_status.csv`;
- `batch_benchmark.json`;
- `batch_failure.json`.

## Gate status

| Gate | Representation in this bounded lane | Status |
| --- | --- | --- |
| 1. Dry-run and guard review | Case matrix, production mesh/time parameters, exact boundary mode, output roots, and no-default-CLI production policy recorded above. | `pending-status-output`: command contract recorded; sandbox precompile stopped before native-status output. |
| 2. Native finite-field gate | Required velocity, pressure, displacement finite-field checks are listed for the target output roots. | `blocked-no-production-artifacts`: no production snapshots were generated in this lane. |
| 3. Displacement and wall-state gate | Required positive current radii, non-inverted deformed tetrahedra, finite wall displacement/velocity/pressure, clamped-end displacement, and `state_payload` review remain required for each case. | `blocked-no-production-artifacts`. |
| 4. Pressure normalization gate | Required direct finite pressure sampling and outlet-node mean export gauge review remain required for each saved pressure field. | `blocked-no-production-artifacts`. |
| 5. Importer round-trip gate | Required `load_resolved3d_field_bundle(...)` round-trip, shared topology/reference geometry, deformed coordinate loading, and target-time agreement remain required for each native bundle. | `blocked-no-production-artifacts`. |
| 6. Observation row gate | Required native velocity/pressure observation rows and imported skip rows are represented by the planned `section41_observations.csv` path for each case. | `blocked-no-production-artifacts`; optional imports below are expected skips. |
| 7. Parity summary gate | Required summary/parity rows are represented by the planned `section41_observation_summary.csv` path for each case. | `blocked-no-production-artifacts`; no parity claims. |
| 8. Manuscript claim readiness | Manuscript claims remain limited to smoke-scale/operator-readiness support until gates 1-7 pass and artifacts are reviewed. | `not-advanced`. |

## Optional imported-bundle status

Optional imported-data parity is not executed in this bounded status lane:

| Native case | Imported case | Expected local bundle root | Status |
| --- | --- | --- | --- |
| `sev23` | `77` | `public/var/data/simulations/canic_case3/77` | `not-executed`; use this local bundle when imported parity is explicitly run. |
| `sev40` | `60` | `public/var/data/simulations/canic_case3/60` | `not-executed`; use this local bundle when imported parity is explicitly run. |
| `sev50` | `50` | `public/var/data/simulations/canic_case3/50` | `not-executed`; use this local bundle when imported parity is explicitly run. |

Missing optional imported bundles are not failures for the native dry-run/status
record. Imported parity claims remain blocked until the bundle for each case is
present, the parity workflow is explicitly run, and its artifacts are reviewed.

## Claim outcome

No manuscript claim advances from this record. The production target gates remain
open until the three native cases produce reviewed artifacts with finite fields,
positive geometry, pressure normalization, importer round-trip, observation
rows, and parity summaries where optional imported bundles are present.
