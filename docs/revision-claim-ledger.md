# Revision Claim Ledger

This ledger records the gated claim state for the revision prompted by
`executive-assessment.md`. It is a source-control companion to scratch evidence
under `tmp/revision-evidence/`; it is not itself a generated result.

## Inventory checkpoint

- HEAD at start of orchestration: `8f2a956`.
- Dirty tracked source at start: `sections/03-conclusions/index.tex`,
  `sections/03-methodology/index.tex`, and
  `sections/04-verification/index.tex`.
- Untracked assessment input: `executive-assessment.md`.
- Tracked release PDF at checkpoint: `final-report.pdf`, 88 pages, modified
  2026-06-18 21:56:15 -0700.
- Current scratch source render at checkpoint:
  `/tmp/masters-report-build/final-report.pdf`, 89 pages, modified
  2026-06-18 22:09:50 -0700.
- Local raw 3D data were present under `simulations/data/3d/canic_case3/` but
  ignored by Git. Scratch checksums were written to
  `tmp/revision-evidence/orchestrator/raw-3d-sha256.txt`.

## Claim statuses

| Claim | Status | Current disposition |
| --- | --- | --- |
| The report defines a selected `Rmax`-normalized Canic-derived 1D stenosis model and output convention. | allowed | Keep, with source-to-implementation differences visible. |
| The implementation and generated records are auditable and internally reproducible from this checkout. | provisional | Keep only as a bounded workflow claim until source/PDF and archive packaging are synchronized. |
| The Rusanov/MUSCL geometry-rest state is well balanced. | remove | Existing rest-state evidence shows material zero-input motion. |
| The extended rest-state evidence through requested `t=1.0` passes the comparison gate. | blocked | The output schema now records requested time, completed time, and terminal-time error explicitly. The current regenerated evidence still fails the numerical gate: every positive requested-time row is above 0.1 `q_comp`; at requested `t=1.0`, `N=800` remains 1.004 `q_comp` for C23 and 1.006 `q_comp` for C40, and the peak sweep ratios reach 2.151 and 2.276. |
| C23/C40 section-velocity discrepancies are model-accuracy or close-agreement evidence. | blocked | Scratch runs now cover `N=200,400,800`, a `dt=5e-6` pair at `N=400`, fixed-snapshot target times 0.95/1.05, stationary-Stokes initialization, and a classical no-slip baseline. The rest-state gate still fails and the max section discrepancy is not stable across spatial grids, so the manuscript keeps these as single-realization descriptors. |
| The C23/C40 comparison was analyzed without exposing actual sample times. | remove | The comparison outputs now distinguish `target_time_s`, `one_d_completed_time_s`, `one_d_terminal_time_error_s`, `xdmf_target_time_error_s`, and `cross_model_time_offset_s`; legacy `time_offset_s` remains the XDMF-target offset. |
| The larger C40 discrepancy demonstrates stenosis-dependent model behavior. | remove | With two cases and failed/incomplete gates, describe only that C40 is larger in this pair. The largest listed discrepancies sit upstream of the displayed throat band. |
| The plane-tetrahedron operator is defined and has analytic smoke coverage. | allowed | Keep the operator definition and synthetic-test claim; keep real-data uncertainty bounded. |
| The C40 maximum section discrepancy is insensitive to cut-area uncertainty. | blocked | Worker scratch evidence shows the reported C40 maximum is at the 4.46% area-error outlier; excluding cuts above 4% shifts the maximum to 8.74 cm/s at the next plane. |
| The resolved 3D section flow is conserved across axial cuts. | blocked | Local XDMF audit finds velocity, pressure, and displacement files, but each exposes a single time only. Worker scratch evidence shows 3D section-flow ranges of 7.7% of mean for C23 and 20.2% of mean for C40; rigid/moving-wall interpretation is not established from the comparison CSVs alone. |
| The C23/C40 flow/area decomposition is unavailable. | remove | The current manuscript already includes Table `t1-flow-area-decomposition`. |
| Pressure-drop, pressure-ratio, FFR, CT-FFR, or clinical validity are established. | remove | Keep only future-work or scope-exclusion language. |
| Raw 3D data are part of an independently reproducible Git checkout. | blocked | The files are local and ignored; release packaging must include checksums plus archive or retrieval instructions. |

## Gate defaults

- Stronger comparison claims require rest-state drift to decrease with
  refinement and remain below 10% of the smallest interpreted comparison-flow
  signal over the reported time window.
- Production C23/C40 summaries require stability within 5% relative or
  0.1 cm/s absolute for velocity summaries unless a stricter tolerance is
  declared before reruns.
- Until those gates pass, manuscript comparison language must remain
  descriptive and non-attributional.

## Current scratch evidence

- Rest-state report asset:
  `figures/static/static/tables/verification/rest_state_drift.csv`, SHA-256
  `4ef2126c5d1edb34e7d27e217bba40bc718cef008f85cef1bba2cdea10fedf3f`.
- Current rest-gate summary:
  `tmp/revision-evidence/current-summary/rest_gate_summary.csv`, SHA-256
  `8aaa75cf983c8433662834535b16441d908775da92791965173598d66bbf4299`.
- Production comparison summary:
  `simulations/output/3d_comparison/full_t1_native_nx400/comparison_summary.csv`,
  SHA-256
  `1ab569711421956b37acbd08ed7db0ed218fd29c2dbb3bb3266a4912b4934a64`.
- Production sensitivity report asset:
  `figures/static/static/data/stenosis-comparison/node-slab-sensitivity.csv`,
  SHA-256
  `99cb296d2da6156effefc660068c58d44d729be5a4a42f096fd95c90c7ea1779`.
- Current comparison-gate summary:
  `tmp/revision-evidence/current-summary/comparison_gate_summary.csv`, SHA-256
  `c2ab20fdf12d7e720dffa47bf47cbece2d173f79f0a5abd5a10232008aa97c08`.
- Current wall metadata summary:
  `tmp/revision-evidence/current-summary/resolved3d_wall_status.csv`, SHA-256
  `abf7ed55425782e9c8ee1b45c69e536d6e8c8f2fd19f6aa01e41df684bc374f5`.
