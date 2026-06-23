# Next Prose Lane: Committee-Ready A+ Polish

## Status

Refreshed after a validation-only report build on the current manuscript:

```sh
pipenv run ops-build-report --outdir /tmp/masters-report-build --no-sync-final-pdf
pdftotext -layout /tmp/masters-report-build/final-report.pdf /tmp/final-report-current.txt
```

The build passed. The scratch PDF, not `public/final-report.pdf`, is the basis
for this critique. This is a source-only prose lane unless the specific appendix
table wording below requires a tracked generated table fragment or its renderer
to be updated.

## Overall Critique

The report is committee-ready at an `A` level and close to `A+`. Its strongest
features are the review-first structure, the explicit separation of
verification, cross-model comparison, and validation, and the sustained
mathematical framing around retained state, closures, discretization, observation
operators, and evidence category.

The remaining `A+` risk is not mathematical correctness. It is reader cadence.
Section 7 still carries the largest narrative load, while the integrated
discussion and conclusion are short relative to the worked example. Appendix G
also exposes one benchmark label, "backend parity", that reads like internal
tooling rather than committee-facing numerical evidence. The next round should
therefore tighten the case-study narrative, harvest its interpretation slightly
more explicitly in the discussion/conclusion, and remove remaining
implementation-facing vocabulary from reader-visible appendix material.

## Current Section Grades

| Area | Grade | Brief finding |
| --- | --- | --- |
| Abstract and front matter | A+ | Directly states scope, evidence categories, and limits without overclaiming. |
| 1 Introduction and report methodology | A+ | Strong review-first contract; the case study's illustrative role is clear. |
| 2 Continuum description | A | Mathematically sound and readable; dense derivation blocks are now oriented well enough, with only minor cadence risk. |
| 3 Model hierarchy | A+ | Clear retained-state framing and effective 0D/1D/2D/3D distinctions. |
| 4 Closures and observables | A+ | Constitutive roles, membrane-wall language, and observable dependence are committee-facing and bounded. |
| 5 Numerical methods | A | Strong stencil/evidence framing; a few method-catalog paragraphs remain dense but defensible. |
| 6 Literature synthesis | A | Coherent proposition families; concise enough to work as a bridge to the case study. |
| 7 Case-study overview | A | The positive result, negative limitation, and diagnostic comparison are visible early. |
| 7.1 Methodology | A- | Correct and traceable, but still long enough that code-adjacent labels and contract details slow the mathematical reading. |
| 7.2 Verification | A- | Evidence hierarchy is right; procedure and table density still compete with the interpretation. |
| 7.3 Comparison | A- | Main 23%/40% result is clear; secondary diagnostics still read more sequential than interpretive. |
| 8 Integrated discussion | A | Accurate and bounded; should harvest Section 7 slightly more explicitly. |
| 9 Conclusion | A | Clean final answer; could better echo the diagnostic lesson from the worked example. |
| Appendices | A- | Useful evidence support, but Appendix G has one reader-visible internal benchmark label and remains long. |

## Objective

Lift the remaining `A-`/`A` surfaces to `A+` without changing mathematical
claims, numerical values, citations, generated figures, claim registers, raw
data, package code, or `public/final-report.pdf`.

## Files in Scope

Primary prose files:

- `report/sections/07-case-study/index.tex`
- `report/sections/07-case-study/methodology.tex`
- `report/sections/07-case-study/verification.tex`
- `report/sections/07-case-study/comparison.tex`
- `report/sections/03-conclusions/index.tex`
- `report/appendices/numerical-methods-details.tex`
- `report/TODO.md`

Conditional table wording:

- `report/assets/tables/package-benchmark/package-benchmark-summary.tex`

Conditional source or renderer:

- Search for the generator or source of the package-benchmark summary before
  changing the generated table fragment. If the owning renderer is in scope and
  easy to identify, patch the label there as well so future regeneration does
  not restore implementation-facing wording.

Out of scope:

- `packages/stenotic-hemodynamics/**`
- `public/docs/**`
- `public/reproducibility/**`
- `public/var/data/**`
- `tmp/**`
- bibliography entries and source-inventory rows
- public claim registers
- `public/final-report.pdf`

## Implementation Plan

### Step 1 - Re-Anchor and Protect Scope

Run:

```sh
git status --short
pipenv run ops-orchestrate status --json
```

If unrelated package, docs, release, or runtime files are dirty, leave them
unstaged. This lane owns only the report prose/table wording listed above.

### Step 2 - Remove Reader-Visible Internal Benchmark Language

Find the package-benchmark summary label source:

```sh
rg -n "backend parity|package-benchmark-summary|benchmark stage summary" \
  report packages public
```

Replace reader-visible "backend parity" with a mathematical or evidence-facing
label such as "integrator comparison" or "time-integrator comparison". Prefer a
label that still matches the row's purpose without exposing implementation
internals.

Acceptance criteria:

- `pdftotext` output contains no `backend parity`.
- The appendix still accurately describes the diagnostic as secondary
  numerical context.
- If a generated table fragment is patched directly, the handback names the
  generator/source follow-up if it could not be found safely.

### Step 3 - Tighten the Section 7 Entry Point

In `report/sections/07-case-study/index.tex`:

- Keep the existing result-preview paragraph.
- Add or sharpen one routing sentence that tells the reader how to read the
  chapter: methodology defines the model contract, verification separates MMS
  evidence from the rest-state limitation, and comparison interprets the
  23%/40% final-time section-mean discrepancies.
- Do not add new claims or numerical values.

Acceptance criteria:

- A reader reaches the positive result, negative limitation, and comparison
  target before the chapter moves into contract details.

### Step 4 - Compress Methodology Around Mathematical Roles

In `report/sections/07-case-study/methodology.tex`:

- Make retained variables, closure choices, boundary approximation,
  finite-volume operator, observation map, and matching limits lead the prose.
- Reduce duplicate prose that immediately restates table cells.
- Keep implementation labels only as traceability tags, preferably in
  parentheses.
- Preserve every equation, numerical value, table label, and citation unless a
  sentence is being moved without changing meaning.

Acceptance criteria:

- The section reads as a mathematical model contract rather than a solver
  receipt.
- The contract table remains useful, but surrounding paragraphs no longer
  repeat it row by row.

### Step 5 - Rebalance Verification Toward Interpretation

In `report/sections/07-case-study/verification.tex`:

- Keep the opening evidence hierarchy.
- Compress mechanics that describe forcing construction, call paths, mutation
  gates, or stored artifacts unless they are necessary for the evidence claim.
- Make the three verification outcomes easy to scan:
  1. MMS gives positive finite-volume code-verification evidence.
  2. The geometry-rest state is not preserved by the production operator.
  3. The production comparison remains diagnostic, not a clean
     discretization-accuracy or validation study.

Acceptance criteria:

- The interpretation appears before detailed tables whenever practical.
- The section does not introduce new validation language.

### Step 6 - Make the Comparison Read as an Interpreted Result

In `report/sections/07-case-study/comparison.tex`:

- Keep the 23% and 40% final-time discrepancy claims exactly bounded.
- Keep the resolved metadata table, area-check table, axial-flow figure,
  velocity discrepancy summary table, coordinate-mode comparison, and membrane
  comparator.
- Compress transitions around secondary diagnostics so the narrative does not
  become a sequence of tables.
- Add or sharpen one interpretation sentence after the main velocity
  discrepancy table: the larger 40% discrepancy is throat-localized and
  observation-map dependent, but cannot be assigned to one closure, wall,
  boundary, geometry, or numerical mechanism.

Acceptance criteria:

- The section reads as a bounded cross-model comparison, not a diagnostic log.
- The final-time numerical claims and limitations are unchanged.

### Step 7 - Harvest the Case-Study Lesson in Discussion and Conclusion

In `report/sections/03-conclusions/index.tex`:

- Add one or two sentences to the integrated discussion or conclusion that
  explicitly connect the case study to the report's main thesis:
  manufactured-solution verification, equilibrium preservation, observation
  operator, and validation are distinct claim categories.
- Keep the addition compact; do not turn the conclusion into another case-study
  summary.

Acceptance criteria:

- The final pages explain why the worked example matters without broadening its
  evidence status.

### Step 8 - Validation Gate

Run:

```sh
git diff --check -- \
  report/sections \
  report/appendices \
  report/assets/tables/package-benchmark \
  report/TODO.md

pipenv run ops-audit-references
pipenv run ops-build-report --outdir /tmp/masters-report-build --no-sync-final-pdf
pdftotext -layout /tmp/masters-report-build/final-report.pdf /tmp/final-report-prose-lane.txt
rg -n "backend parity|implementation-check|accepted-reference|validation workflow|regeneration command|Newtonian wall|clinical validation result|reference standard" \
  /tmp/final-report-prose-lane.txt
```

Expected result:

- Diff check passes.
- Reference audit passes.
- Report build passes.
- The final `rg` command returns no matches.
- `public/final-report.pdf` remains unchanged unless the user explicitly
  scopes a synced PDF refresh.

### Step 9 - Commit Discipline

Use one commit for validated report-prose work:

```sh
git status --short
git add \
  report/sections/07-case-study/index.tex \
  report/sections/07-case-study/methodology.tex \
  report/sections/07-case-study/verification.tex \
  report/sections/07-case-study/comparison.tex \
  report/sections/03-conclusions/index.tex \
  report/appendices/numerical-methods-details.tex \
  report/assets/tables/package-benchmark/package-benchmark-summary.tex \
  report/TODO.md
git commit -m "Polish case-study prose narrative"
```

Omit unchanged paths from `git add`. Do not stage package/runtime docs or raw
data.
