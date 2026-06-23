# Final Submission Closeout Plan

## Current Status

The targeted mathematical/numerical narrative pass is complete. Section 5.1 now
introduces finite-element incompressible-flow and FSI discretization by
cross-referencing the continuum fields and weak balances already established in
Section~\ref{sec:continuum-description}, instead of restating continuum
foundations inside the numerical-methods chapter.

The public report artifact is synced to the current active TeX. The latest PDF
refresh ran:

```sh
pipenv run ops-build-report --outdir /tmp/masters-report-build
```

The build passed, consumed `63` report inputs, reported no untracked consumed
inputs, and synced `public/final-report.pdf` with SHA-256:

```text
a7646013b30307a5adc33d3cecc78a743f9f38e61b4fc025dc5a6993d82d634f
```

`shasum -a 256 public/final-report.pdf /tmp/masters-report-build/final-report.pdf`
confirmed that the public PDF and scratch PDF match.

The active manuscript reflects the current native resolved-FSI boundary through
Appendix~G only. The package-side status through `9692072 Add native FSI
checkpoint sidecars` is:

- the exact Section 4.1 inlet/outlet mode is implemented in the native Gridap
  path and has development artifact-readiness evidence at `sev23`,
  `(40, 3, 16)`, `dt_s=1e-4`, `tfinal_s=1e-2`;
- the reduced exact-mode path uses stationary no-slip wall data on deformed
  geometry, a semi-implicit reduced membrane update, direct finite
  wall-pressure sampling, and pressure-load plausibility diagnostics;
- the completed development gate wrote native velocity, pressure, and
  displacement bundles plus sidecars, but used one coupling iteration per step
  and recorded bounded non-converged coupling history;
- the development-output parity artifact loaded the imported observations and
  wrote native observation/summary CSVs, but it recorded nonzero discrepancies;
- this is development artifact-readiness and discrepancy-classification
  evidence only, not preproduction, production-scale native generation,
  imported-data parity, Section 4.1 numerical reproduction, monolithic ALE, or
  validated moving-boundary FSI;
- production metadata now writes schema-v2 checkpoint sidecars with manifest
  role/path/SHA/byte-size checks, but these sidecars are durable diagnostic
  metadata only;
- actual persisted restart/resume remains unsupported until FE-state
  serialization and a reconstruction runner are implemented.

A check-in was sent to the principal package/developer thread after the PDF
refresh. Use any later response from that thread as coordination input, but do
not let the package lane edit `report/**` or `public/final-report.pdf`.

Validation already completed for this refreshed state:

- `pipenv run ops-build-report --outdir /tmp/masters-report-build` passed and
  synced `public/final-report.pdf`;
- scratch/public PDF hashes matched;
- active-TeX prose audit returned zero findings after the Appendix~G native
  resolved-FSI checkpoint-sidecar wording update;
- rendered-text scan of the refreshed public PDF returned no matches for the
  internal process and overclaim terms listed below.

Rendered-text scan terms for the final artifact remain:

```text
backend parity
implementation-check
accepted-reference
validation workflow
regeneration command
Newtonian wall
clinical validation result
reference standard
pending_final_release
```

## Current Grades

| Area | Grade | Editorial assessment |
| --- | --- | --- |
| Abstract/front matter | A+ | Clear scope, bounded contribution, and clean review-first framing. |
| 1 Introduction | A+ | Strong motivation and correct positioning of the case study as illustrative evidence. |
| 2 Continuum | A | Mathematically precise and well organized; dense, but appropriate for the audience. |
| 3 Model hierarchy | A+ | Retained-state and dimension language are explicit and useful. |
| 4 Closures/observables | A+ | Constitutive roles, wall closure, geometry, boundary data, and observables are cleanly separated. |
| 5 Numerical methods | A+ | Stencil language, method-family distinctions, and FEM/FSI weak-form ownership are now cleanly aligned. |
| 6 Synthesis | A | Compact proposition-family summary; effective as a bridge to the case study. |
| 7 Case-study overview | A+ | The chapter opens with positive evidence, negative limitation, and comparison target. |
| 7.1 Methodology | A | Model contract leads; table/equation density remains high but defensible. |
| 7.2 Verification | A | MMS evidence, rest-state limitation, and admissibility distinction are clear. |
| 7.3 Comparison | A | The 23%/40% result is interpreted rather than merely reported; secondary diagnostics remain dense. |
| 8 Discussion | A+ | Research questions and claim boundaries are answered directly. |
| 9 Conclusion | A | Submission-ready and accurate; intentionally concise. |
| Appendices | A | Long and command-heavy where appropriate; appendix scope keeps main prose clean. |

## Next Round Objective

Treat the manuscript as final-submission material. Do not reopen broad prose,
literature review, numerical methods, or case-study interpretation unless a
committee/advisor comment identifies a concrete issue. The expected next lane is
either:

1. a rendered-PDF spot check against the freshly synced public artifact;
2. a native resolved-FSI boundary-status wording check if package docs change
   again; or
3. no-op closeout with only status reporting and commit discipline.

## Implementation Plan For Next Round

### Step 1 - Re-Anchor

Run:

```sh
git status --short
pipenv run ops-orchestrate status --json
```

Confirm the only intended manuscript delta is the committed Section 5/TODO
source/PDF closeout, or explicitly classify any newer dirty files before
acting.

### Step 2 - Native Resolved-FSI Boundary Check

If any package-native resolved-FSI docs or code changed since the last report
closeout, run this active-manuscript scan before editing prose or syncing the
PDF:

```sh
rg -n "native resolved-FSI|native resolved FSI|native_resolved|Section 4\\.1|Poiseuille|zero-outlet|zero outlet|pressure_drop_weak_inlet_outlet_gauge_smoke|poiseuille_inlet_zero_outlet_stress_section41|boundary mode|boundary contract|paper-grade|production execution|dry-run|state_payload|checkpoint sidecar|checkpoint manifest|persisted restart|persisted resume|outlet-gauge|pressure-nullspace|nullspace|pressure_nullspace_status|pressure_gauge_status|wall-pressure|pressure-load|plausibility gate|inlet_umax|fsi native-status|native-status|observation-artifact|workflow|wall stability|wall_stability_status|non-positive|stationary no-slip|stationary_wall_on_deformed_geometry|semi-implicit|moving-wall|ALE|development artifact|bounded coupling|coupling_converged|short-development|warm start|under-relaxation|under_relaxation|zero-mean|dt_s=1e-5|smaller-dt_s|deformed-mesh|orientation failure|runtime-inconclusive" \
  report/sections report/appendices report/frontmatter report/final-report.tex -g '*.tex' || true
```

Expected result: active manuscript prose should not imply that native
production, parity, CLI, or restart paths already reproduce the paper's Section
4.1 inlet/outlet boundary contract. If native resolved-FSI wording is added
later, it must preserve these boundaries:

- production may be described as carrying partitioned state within one run and
  writing importer-compatible velocity/pressure/displacement bundles plus
  manifest, diagnostics, and restart metadata;
- restart metadata may include versioned diagnostic state payloads and
  boundary/status fields, including `inlet_umax_cm_s`; schema-v2 checkpoint
  sidecars may be written and validated by manifest role/path/SHA/byte-size
  checks, but persisted restart/resume remains unsupported and fail-closed;
- the low-level native Gridap Navier--Stokes adapter has smoke-tested exact
  Section 4.1 boundary-mode support through
  `poiseuille_inlet_zero_outlet_stress_section41`;
- production dry-run plans, production diagnostics and restart metadata, and
  parity/status rows may report boundary-status fields;
- the exact boundary mode may be described as threaded through the tiny
  partitioned production smoke-scale harness and validated at that scope;
- `pressure_drop_weak_inlet_outlet_gauge_smoke` remains a separate local
  pressure-drop loading smoke mode and is not exact Section 4.1 boundary
  reproduction;
- production and parity `ready` rows mean artifact/operator readiness, not exact
  Section 4.1 boundary equivalence, validated Section 4.1 parity, or
  paper-grade reproduction;
- the exact-mode production path disables pressure-drop fallback for
  wall-pressure projection and requires direct finite wall-pressure sampling;
- post-sampling outlet pressure normalization must not be described as a Gridap
  pressure-nullspace constraint;
- native production, parity artifacts, CLI defaults, and restart metadata must
  not be described as reproducing exact Section 4.1 numerical results or parity
  against imported paper data until production-scale validation lands;
- `fsi native-status` may be described only as a status CLI that reports dry-run
  and boundary-status information; it does not run native resolved-FSI
  production and does not write solver outputs;
- production execution, restart/resume, parity execution, and
  observation-artifact generation remain qualified Julia internals;
- source-path references to package workflows must use the post-split
  responsibility subdirectories under
  `packages/stenotic-hemodynamics/src/StenoticHemodynamics/workflows/`.
- production-scale Section 4.1 validation planning now lives in
  `public/docs/stenotic-hemodynamics/section-4-1-production-validation-plan.md`;
  do not treat that roadmap as completed reproduction evidence;
- the current `sev23`/`sev40`/`sev50` dry-run matrix is status-only planning
  evidence and must not be described as production execution or generated
  Section 4.1 data;
- development exact-mode `sev23` evidence may be described only as a
  development-mesh artifact-readiness gate with stationary no-slip wall solves
  on deformed geometry, a semi-implicit reduced membrane update, finite
  fields, positive radii, positive tetrahedra, direct wall-pressure sampling,
  and bounded one-iteration coupling status; it must not be described as
  preproduction, production-scale native generation, imported-data parity,
  monolithic ALE, paper-grade moving-wall FSI validation, or completed
  Section 4.1 reproduction;
- preproduction and production-scale `sev23` gates remain package work and
  must not be described as completed native generation until they pass;
- zero-mean pressure, fixed-wall warm start, and under-relaxation probes are
  diagnostic evidence for the blocker, not accepted remediation and not
  generated Section 4.1 evidence;
- `wall_stability_status` in package dry-run or CLI output is diagnostic
  status only, not a successful production execution result;
- `pressure_nullspace_status` records FE pressure gauge hygiene only and must
  not be presented as the wall-stability remediation;
- smaller-`dt_s` scratch probes have not cleared the native exact-boundary
  gate and must not be presented as completed Section 4.1 native generation;
- restart/resume design now lives in
  `public/docs/stenotic-hemodynamics/native-resolved-fsi-restart-resume-design.md`;
  schema-v2 checkpoint sidecars are durable diagnostic metadata and
  package-side implementation details, not active persisted resume support;
- scalar-helper genericity changes preserve local `Float32`/`BigFloat` sampling
  values where safe, but manuscript text must not imply the native resolved-FSI
  Gridap/production/XDMF-HDF5 stack is type-generic.

### Step 3 - Optional Public PDF Sync

The public PDF is currently synced. Run this step only if active TeX changes
again or if the next lane explicitly requests a new public-artifact refresh:

```sh
pipenv run ops-build-report --outdir /tmp/masters-report-build
shasum -a 256 public/final-report.pdf /tmp/masters-report-build/final-report.pdf
jq '{status, consumed_count: (.consumed_inputs|length), untracked_consumed_inputs, synced_pdf, warning_counts}' \
  /tmp/masters-report-build/report-build-summary.json
```

Expected result: build status `passed`, consumed-input count `63` unless
explained, no untracked consumed inputs, and matching public/scratch PDF hashes.

### Step 4 - Final Rendered Claim-Boundary Scan

After any PDF sync, run:

```sh
pdftotext -layout public/final-report.pdf /tmp/final-report-release-check.txt
rg -n "backend parity|implementation-check|accepted-reference|validation workflow|regeneration command|Newtonian wall|clinical validation result|reference standard|pending_final_release|TODO|FIXME" \
  /tmp/final-report-release-check.txt || true
```

Expected result: no reader-visible internal process language, no clinical
validation overclaim, and no release placeholders in rendered report text.

### Step 5 - Visual Spot Check

Spot-check the public PDF if it is refreshed:

- Section 5 opening pages around the FEM/FSI subsection;
- Section 7 opening pages;
- Section 7 verification and comparison tables;
- Appendix G package-benchmark material;
- Appendix H software and AI-use disclosure.

Fix only real rendered defects: broken cross-references, orphaned captions,
overfull table text, stale reader-facing labels, or typo-level issues.

### Step 6 - Commit Discipline

For a TODO-only closeout, stage only:

```sh
git add report/TODO.md
```

For a PDF-sync closeout after active TeX changed, stage only the refreshed
artifact and any intentionally edited report planning/prose files:

```sh
git add public/final-report.pdf report/TODO.md
```

Suggested TODO-only commit subject:

```text
Refresh final submission TODO
```

Suggested PDF/TODO sync commit subject:

```text
Refresh final report PDF and closeout plan
```

## Do Not Reopen

Do not reopen:

- the report spine or section order;
- broad mathematical derivations;
- new literature review sources;
- manuscript wording that treats native production, parity artifacts, CLI
  defaults, restart metadata, or the separate pressure-drop smoke mode as exact
  Section 4.1 Poiseuille-inlet / zero-outlet-stress reproduction;
- manuscript wording that treats `fsi native-status` as production execution or
  a solver-output writer;
- bibliography entries or `public/references/source-inventory.tsv`;
- public claim registers or reproducibility metadata;
- package/runtime code;
- raw data under `public/var/data/**`;
- generated report assets, unless a build reports a missing consumed input;
- `public/final-report.pdf`, unless the next instruction explicitly requests a
  synced artifact refresh.

## Live Layout Guardrails

Use the current layout, not stale historical paths:

- manuscript entrypoint: `report/final-report.tex`;
- discussion and conclusion: `report/sections/08-discussion-conclusion/index.tex`;
- Appendix G: `report/appendices/numerical-methods-details.tex`;
- Appendix H: `report/appendices/code-and-ai-use.tex`;
- repo documentation: `public/docs/**`.
- package workflow source paths: use the responsibility subdirectories under
  `packages/stenotic-hemodynamics/src/StenoticHemodynamics/workflows/`, such as
  `native_resolved_fsi/`, `resolved3d/`, `verification/`, `benchmarks/`,
  `membrane_fsi/`, `operator_validation/`, `geometry_exports/`, `studies/`, and
  `shared/`.

Do not reference nonexistent root `docs/revision-claim-ledger.md`,
`docs/revision-release-gates.md`, or
`report/sections/03-conclusions/index.tex`.
