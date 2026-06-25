# Report Next-Round Revision Plan

Date: 2026-06-24
Audit status: **NO-SEND**
Surface owner: report/manuscript
Profile: claim boundary, academic prose, and AI-slop removal

## Audit Basis and Scope

- The reviewed tracked-only archive has SHA-256
  `27f1ff7c9dceda468604ad4d4b1d946597f73c6bdef8c13de419403e79bfc167`.
- The dispatch packet reports `main...origin/main [ahead 6]`. The archive does
  not contain `.git`, so branch cleanliness, the current commit, tags, and the
  previous TODO claim `ahead 5, clean` are not independently verifiable here.
  Re-anchor in the live checkout before editing or closing any task.
- This lane may edit report source and this TODO. It must not regenerate or
  update `public/final-report.pdf`, `report/assets/rendered/**`, or generated
  report assets.
- Package correctness changes belong to
  `packages/stenotic-hemodynamics/**`. Report wording must follow the accepted
  package contract; it must not pre-empt that contract.

## Decision Boundary

The manuscript is not advisor-ready while either condition remains true:

1. the report defines `evolution_pressure` with an `R_max^{-2}` denominator
   while the current package implementation returns the local-`R_0^{-2}`
   pressure; or
2. the Canic Section 4.1 surface is called a replication/reproduction despite
   unmatched case times, no common pressure-gauge transform, and no numerical
   acceptance criterion.

The retained 23%/40% final-time velocity comparison may remain a **bounded
internal cross-model comparison**. It is not external physical or clinical
validation.

## Merged Execution Order

1. Close package tasks `J-P0-1` through `J-P0-3` in the package TODO.
2. Apply report tasks `R-P0-1` through `R-P0-3` without refreshing artifacts.
3. Complete the P1 mathematical/evidence hardening.
4. Complete the P2 prose pass and source-only validation.
5. Run the orchestrator gates in the live checkout; only then reconsider
   `SEND` status or open a separate artifact-refresh lane.

## P0 — Must Fix Before Advisor Submission

### [ ] R-P0-1 Align the pressure contract with the corrected package API

**Locations:**

- `report/sections/07-case-study/methodology.tex`, especially the selected wall
  law and pressure-diagnostic discussion;
- `report/appendices/domain-notation.tex`;
- `report/appendices/numerical-methods-details.tex`;
- pressure captions, tables, and appendix commands that expose package output.

**Required edit:**

- State one unambiguous evolution pressure,
  \(p_{\mathrm{evol}}=p_{\mathrm{ext}}+K R_{\max}^{-2}(\sqrt a-R_0)\),
  only after package task `J-P0-1` implements and tests that API.
- State the local-radius diagnostic separately, including the variable-radius
  correction when present. Do not call a local-denominator quantity the
  pressure used by the evolution.
- Name the pressure convention in every reader-facing output description. A
  generic label such as “pressure” is insufficient where both conventions
  exist.
- Update the implementation label to the canonical
  `classical-parabolic-1d`; retain `classical-1d-no-slip` only as an explicitly
  historical/deprecated asset token where needed for provenance.

**Acceptance criteria:**

- The continuous equation, Julia API names, tests, CSV/summary metadata, and
  manuscript notation describe the same denominator and correction terms.
- A report-wide search finds no ambiguous statement that
  `evolution_pressure` is local-denominator pressure.
- No pressure table is described as evolution pressure unless its generating
  path actually uses that convention.

### [ ] R-P0-2 Withdraw or reclassify the current Canic Section 4.1 claim

**Locations:**

- `report/appendices/code-and-ai-use.tex`, Canic workflow and table captions;
- `report/sections/07-case-study/comparison.tex`, opening scope statement and
  interpretation limits;
- `report/sections/07-case-study/methodology.tex`, references to the separate
  Section 4.1 surface.

**Required edit:**

- Replace “replication,” “reproduction of the numerical findings,” “promoted,”
  and “reproduces the comparison surfaces” with
  **source-artifact reconstruction/comparison** unless package task `J-P0-3`
  establishes explicit, passed reproduction criteria.
- State that the tracked severity-50 row compares the imported snapshot at
  approximately `1.4995 s` with a local run configured to `1.0 s`; therefore
  that row is not admissible replication evidence.
- Mark the existing Canic summary table as non-evidentiary for replication, or
  remove it from the reader-facing claim surface pending a later,
  time-aligned artifact lane.
- Report the observed velocity discrepancies as discrepancies, not as evidence
  of successful reproduction. Workflow completion and file creation are not
  reproduction criteria.
- Preserve the Young-modulus source mismatch as a model/configuration
  difference, not a minor provenance footnote.

**Acceptance criteria:**

- Severity 50 is excluded or explicitly failed until the 1D and 3D comparison
  times agree within a declared tolerance.
- No success language is inferred from a workflow status of `ok`.
- Any retained “replication” term is paired with a declared target quantity,
  tolerance, reference, and passed result.

### [ ] R-P0-3 Define the cross-model pressure gauge or remove pressure-error claims

**Locations:**

- `report/sections/07-case-study/methodology.tex`, definition of
  \(\bar p_{3D,\mathrm g}\);
- `report/appendices/code-and-ai-use.tex`, Canic summary caption and parameter
  audit;
- any prose that interprets the Canic pressure-discrepancy column.

**Required edit:**

- Define the exact map that places imported 3D pressure and the selected 1D
  pressure diagnostic in a common gauge, including the reference location or
  mean-subtraction operator.
- Identify whether the compared 1D quantity is the evolution pressure or the
  local-radius diagnostic plus correction.
- If package task `J-P0-3` does not implement a common gauge, remove the
  pressure-error column from the evidentiary comparison or label it as an
  uncalibrated raw-offset diagnostic that cannot be interpreted as pressure
  error.

**Acceptance criteria:**

- The pressure comparison is invariant to an arbitrary additive offset in the
  imported incompressible pressure field, or pressure discrepancy is removed
  from the claim surface.
- The caption, notation, and package metadata identify the same gauge and 1D
  pressure convention.

## P1 — Mathematical and Evidence Hardening

### [ ] R-P1-1 Replace the non-identifiable residual equalities

**Location:** `report/sections/07-case-study/comparison.tex`, residual-budget
paragraph and table.

Replace the exact additive equations for
\(d_{u,j}\) and \(d_{Q,j}\) with either:

- a dependency map listing possible discrepancy sources; or
- a telescoping decomposition whose intermediate models/operators are defined
  and computed.

Do not write an equality between undefined, non-identifiable components.

**Acceptance criterion:** every displayed equality has mathematically defined
terms; the text does not present interpretive categories as measured additive
components.

### [ ] R-P1-2 Narrow the observation-operator verification claim

**Locations:**

- `report/sections/07-case-study/verification.tex`;
- `report/appendices/code-and-ai-use.tex`, operator-validation paragraph.

State that the current synthetic test checks constant/affine quadrature on the
polygon returned by the implementation. It is not an independent validation of
plane–tetrahedron intersection or polygonization because the reference path
reuses those routines. Widen the claim only after package task `J-P1-1` adds
independent analytic geometry references and a multi-tetrahedron case.

**Acceptance criterion:** “independent” is used only for code paths or data that
are demonstrably independent of the implementation under test.

### [ ] R-P1-3 Replace the qualitative cut-area acceptance statement

**Location:** `report/sections/07-case-study/comparison.tex`, cut-area
interpretation and Table `t1-area-check`.

- Replace “closely enough” with a predeclared acceptance rule.
- Explain the relevance of the reported maximum area differences (up to about
  4.6%) relative to velocity/flow discrepancies, or add a sensitivity check.
- Use “available section samples” rather than “available matched data” where
  boundary and wall histories are not matched.

**Acceptance criterion:** the manuscript either supplies a justified tolerance
and passes it or treats cut-area mismatch as a quantified limitation.

### [ ] R-P1-4 Remove unverifiable live-checkout assertions from the manuscript

**Location:** `report/appendices/code-and-ai-use.tex`, source-control,
computational-environment, and review-provenance records.

- Replace volatile branch cleanliness, local-tag, hardware, and refresh-state
  prose with a release-manifest record tied to an immutable source identifier,
  or label each value explicitly as historical snapshot metadata.
- Do not say “in this checkout” unless the value is generated and checked in
  the release lane.
- Keep operational orchestration terms out of the scientific narrative unless
  they are needed for reproducibility.

**Acceptance criterion:** every source-state assertion is derivable from a
tracked manifest or from a command recorded in the final release handoff.

### [ ] R-P1-5 Bound the MMS independence wording

**Location:** `report/sections/07-case-study/verification.tex`.

Replace “independent enough” with an exact statement: the audit expression
expands the flux/source formulas separately from the production helper calls,
but shares manufactured states, geometry, constitutive parameters, and
low-level primitives. Preserve the positive result as implementation
verification, not independent validation.

## P2 — Prose, Presentation, and AI-Slop Removal

### [ ] R-P2-1 Perform a local metadiscourse compression pass

Prioritize repeated terms and noun stacks such as “declared,” “retained,”
“bounded,” “promoted,” “tracked,” “package audit,” and repeated lists of model,
discretization, observation, boundary, and metric layers.

- Keep each material limitation once at its point of use and once in the final
  synthesis; remove nearby repetitions.
- Replace internal workflow/status language with direct scientific prose.
- Preserve the report’s careful verification/validation distinction; do not
  delete necessary claim boundaries.

**Acceptance criterion:** each paragraph advances a mathematical, numerical,
or evidentiary point rather than restating process status.

### [ ] R-P2-2 Correct local wording and hierarchy defects

- In the abstract, replace “equilibrium preservation” with
  “equilibrium-preservation testing,” because the test exposes non-well-balanced
  drift.
- Correct the section hierarchy that produces the numerical-methods bookmark
  warning (`\subsubsection` directly under `\section`).
- Resolve the overfull display reported near the continuum weak-form block.
- Remove “clean public source tree” wording unless verified at release time.

## Report Acceptance Criteria

The report lane is complete only when all of the following are true:

- P0 tasks are closed against an already accepted package contract.
- Canic time and pressure-gauge provenance are explicit and machine-readable.
- No external validation or clinical claim is inferred from internal
  cross-model comparison.
- The report source builds in a temporary output directory.
- No tracked PDF, rendered asset, generated data table, or raw simulation input
  changes in this lane.
- The live checkout is re-anchored and all required validation commands exit
  zero.

## Validation and Expected Results

Run from the live repository root after the edits:

```bash
git status --short --branch --untracked-files=all
git diff --check -- \
  report/TODO.md \
  report/frontmatter \
  report/sections \
  report/appendices \
  report/preamble
rg -n "replication|reproduces|promoted" \
  report/sections/07-case-study report/appendices/code-and-ai-use.tex
rg -n "classical-1d-no-slip" report
pipenv run ops-audit-report-prose --json
pipenv run ops-build-report \
  --outdir /tmp/masters-report-build \
  --no-sync-final-pdf
pipenv run ops-orchestrate ready-to-commit
```

Expected results:

- `git status` reports the actual live branch and preserves unrelated work.
- `git diff --check` exits `0`.
- High-risk claim terms occur only in explicitly bounded or historical
  contexts.
- The deprecated model token occurs only where historical asset provenance
  requires it.
- Prose audit and source-only report build exit `0`.
- The official gate exits `0`.
- `git diff -- public/final-report.pdf report/assets/rendered` is empty.

**Orchestrator validation scope:**

```bash
pipenv run ops-build-report --outdir /tmp/masters-report-build --no-sync-final-pdf
```

## Risks to Carry Forward

- Existing Canic generated tables remain stale relative to the required
  time/gauge corrections; they must not be silently treated as refreshed
  evidence.
- Fixing the package pressure API may change numerical pressure outputs and
  downstream table values. That change requires a separate, reviewed
  artifact-refresh lane.
- The raw 3D inputs are not part of this tracked-only review environment, so
  raw-data-dependent claims cannot be revalidated here.
- A source-only build does not validate the Julia computations that generated
  tracked numerical assets.
