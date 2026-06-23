# Final Committee-Readiness Audit and A+ Execution Plan

> Status: implemented in the final committee-readiness closeout lane. The
> remaining value of this file is as an audit trail of the prose and PDF
> refresh gates used for submission readiness.

## Audit Basis

This plan is based on a second pass over the manuscript as a single TeX
document, using:

- `report/final-report.tex` as the authoritative include spine.
- `/tmp/masters-report-build/final-report.toc` as the compiled section order.
- `/tmp/masters-report-build/report-build-summary.json` as the consumed-input
  and build-health record.
- `/tmp/masters-report-build/final-report.pdf` and rendered text as the
  committee-facing artifact inspected in scratch.

The compiled body order is correct:

1. Introduction and Report Methodology
2. Continuum Description of Blood Flow
3. Mathematical Model Hierarchy
4. Closure Choices, Data, and Hemodynamic Observables
5. Numerical Methods and Evidence Standards
6. Literature Synthesis and Open Challenges
7. Idealized Stenosis Case Study
8. Integrated Discussion
9. Conclusion

The source tree is healthy after the closeout lane:
`report/sections/08-discussion-conclusion/index.tex` is included last as the
discussion and conclusion. The compiled `.toc` is correct, and the path name now
matches the manuscript spine.

## Pre-Closeout Readiness Grade

Pre-closeout grade: **A- / committee-ready after minor cleanup**

The manuscript is now mathematically coherent and defensible for an
applied/computational graduate mathematics committee. The main narrative is
review-first, the case study is bounded as a worked example, and the distinction
between verification, diagnostic comparison, reproducibility, and validation is
visible. The closeout lane targeted pre-submission polish: first-page wording,
appendix terminology, one stale reproducibility sentence, source-spine hygiene,
and final PDF synchronization.

## Rubric

| Category | Grade | Reason |
| --- | --- | --- |
| Central thesis and contribution | A | The report consistently argues that model dimension is not an accuracy ladder and that claims require declared model/observation/evidence contracts. |
| Mathematical exposition | A- | Continuum, hierarchy, closures, numerics, and synthesis are well sequenced; Section 7 methodology remains necessarily dense but no longer dominates the argument by itself. |
| Numerical evidence framing | A | MMS, rest-state behavior, admissibility diagnostics, and 1D--3D velocity comparison are separated cleanly. |
| Literature synthesis | A | Sources are integrated by retained state, closure, observation, and evidence role rather than listed paper-by-paper. |
| Case-study integration | A- | The worked example now supports the review framework; its length is still high relative to the two-page discussion/conclusion. |
| Appendix discipline | B+ | Appendices correctly hold technical and reproducibility detail, but headings and terms such as "descriptor", "implementation-check", "record", and "validation workflow" still read more like internal tooling than committee-facing support. |
| Source-bundle readiness | A | The compiled document is correct and the discussion/conclusion path now matches the manuscript spine; some report tree assets remain useful provenance or archive material outside the consumed TeX input set. |
| Artifact readiness | B+ | Scratch build passed, but tracked `public/final-report.pdf` was intentionally not refreshed in the last prose lanes. |

Post-closeout target: **A+ / ready to submit** after Lanes 1--4 and Lane 6 pass.

## Execution Plan

### Lane 1 - First-Page and Conclusion Claim Polish

Purpose: remove remaining process language from the most visible committee
pages while preserving claim boundaries.

Target files:

- `report/frontmatter/abstract.tex`
- `report/sections/07-case-study/comparison.tex`
- `report/sections/08-discussion-conclusion/index.tex`

Edits:

1. In the abstract, replace:
   - "manufactured-solution verification record" with
     "manufactured-solution verification evidence".
   - "reproducibility records" with "reproducibility evidence" or
     "reproducibility information".
2. In the comparison section caption for
   `tab:t1-normalized-scale-comparison`, replace
   "accepted-reference validation result" with "external validation result".
3. In the RQ3 discussion, replace
   "accepted-reference prediction result" with "external validation result".
4. In the RQ2 membrane sentence, keep the boundary but make it less validator-like:
   replace "not a full transient FSI validation target" with
   "not evidence for a full transient moving-boundary FSI model."
5. Do not alter numerical values, citations, labels, or table data.

Acceptance checks:

```sh
rg -n "verification record|reproducibility records|accepted-reference|validation target" report/frontmatter report/sections
```

Expected result: no matches in frontmatter or main sections.

### Lane 2 - Appendix Terminology Upgrade

Purpose: keep the appendices rigorous while reducing internal-tooling language
visible in the table of contents and rendered text.

Target files:

- `report/appendices/domain-notation.tex`
- `report/appendices/mathematical-notation.tex`
- `report/appendices/numerical-methods-details.tex`
- `report/appendices/code-and-ai-use.tex`

Edits:

1. Rename appendix headings without changing labels unless references require it:
   - `Case-study rheology descriptor details` -> `Case-study rheology closure details`.
   - `Secondary implementation-check records` -> `Secondary numerical diagnostics`.
   - `Self-convergence, backend parity, and descriptor sensitivity` ->
     `Self-convergence, integrator comparison, and closure sensitivity`.
   - `Fixed-wall stationary-Stokes refinement record` ->
     `Fixed-wall stationary-Stokes refinement check`.
   - `Quasi-static membrane-FSI validation workflow` ->
     `Quasi-static membrane-FSI comparator workflow`.
2. In notation tables, replace reader-facing uses of "descriptor" with
   "closure family", "closure label", "model member", or "diagnostic label":
   - `rheology descriptor` -> `rheology closure family`.
   - `wall descriptor` -> `wall closure family`.
   - `computed descriptor cases` -> `computed closure-family cases`.
   - `extended 1D descriptor` -> `extended 1D model member`.
3. Replace appendix prose phrases:
   - "implementation-check records" -> "secondary numerical diagnostics" where
     the sentence is about report interpretation.
   - "backend parity" -> "integrator comparison".
   - "backend-context surfaces" -> "integrator-context surfaces".
   - "descriptor wiring" -> "closure-family wiring".
4. Keep "record" only where it clearly means a source-control, reproducibility,
   manifest, or archive entry.
5. Do not rename labels in this pass unless a heading-label mismatch becomes
   confusing enough to justify an explicit `rg`/build update.

Acceptance checks:

```sh
pdftotext -layout /tmp/masters-report-build/final-report.pdf - | rg -n "descriptor|implementation-check|backend parity|validation workflow"
rg -n "descriptor|implementation-check|backend parity|validation workflow" report/appendices
```

Expected result: remaining matches are either label names or explicitly
defensible reproducibility terms, not rendered appendix headings.

### Lane 3 - Reproducibility Appendix Consistency Fix

Purpose: make Appendix H agree with the current compiled comparison narrative
and the consumed inputs.

Target file:

- `report/appendices/code-and-ai-use.tex`

Edits:

1. In the raw 3D inputs paragraph, replace the stale sentence:
   "Deformed-coordinate plane cuts are now implemented ... but the retained
   comparison assets still use the earlier reference-coordinate velocity
   comparison."
2. New wording:
   "The retained comparison assets include the reference-coordinate and
   deformed-coordinate section summaries consumed by
   Section~\\ref{subsec:deformed-coordinate-comparison}; wall, boundary,
   material, and earlier transient histories remain unresolved unless a later
   release entry adds those data."
3. Verify that the two comparison commands each have one
   `--report-assets-dir report/assets/data/stenosis-comparison` line; do not
   add or remove command options unless the duplicate actually exists in the
   source.
4. Keep the local raw-input limitation and upstream pointer intact.

Acceptance checks:

```sh
rg -n "earlier reference-coordinate|retained comparison assets|--report-assets-dir report/assets/data/stenosis-comparison" report/appendices/code-and-ai-use.tex
```

Expected result: no stale "earlier reference-coordinate" sentence; exactly two
`--report-assets-dir report/assets/data/stenosis-comparison` command lines, one
per comparison command.

### Lane 4 - Source Spine Hygiene

Purpose: make the report tree match the compiled manuscript spine so the source
bundle looks intentional to a committee member or advisor who inspects it.

Target files/paths:

- `report/final-report.tex`
- Moved path: `report/sections/08-discussion-conclusion/index.tex`

Edits:

1. The source path has been moved to
   `report/sections/08-discussion-conclusion/index.tex`.

2. `report/final-report.tex` now uses:

```tex
\input{report/sections/08-discussion-conclusion/index}
```

3. Search for stale source-path references:

```sh
rg -n "sections/0[0-7]-conclusions|0[0-7]-conclusions" report --glob '!TODO.md'
```

4. Do not change section labels (`sec:discussion`,
   `sec:conclusions-limitations`) or cross-references. This is a path hygiene
   rename only.

Acceptance checks:

```sh
git diff --check -- report/final-report.tex report/sections
pipenv run ops-build-report --outdir /tmp/masters-report-build --no-sync-final-pdf
```

Expected result: `.toc` still shows sections 8 and 9 in the same order; no
label or reference warnings.

### Lane 5 - Optional Asset-Tree Stewardship

Purpose: distinguish submission-critical consumed inputs from unused report
tree artifacts without deleting useful source history.

Target surfaces:

- `report/assets/**`
- `report/notebooks/**`
- `report/archive/**`
- `/tmp/masters-report-build/report-build-summary.json`

Actions:

1. Generate the consumed-input list from the build summary:

```sh
jq -r '.consumed_inputs[]' /tmp/masters-report-build/report-build-summary.json | sort > /tmp/report-consumed-inputs.txt
find report/assets report/notebooks report/archive -type f | sort > /tmp/report-tree-artifacts.txt
comm -13 /tmp/report-consumed-inputs.txt /tmp/report-tree-artifacts.txt > /tmp/report-unconsumed-artifacts.txt
```

2. Review `/tmp/report-unconsumed-artifacts.txt`.
3. Do not delete assets in the first pass. Classify them in the handback as:
   consumed, source-support, notebook/provenance, archive/superseded, or
   likely stale.
4. Only if a later cleanup lane is approved, move stale report-only artifacts
   into `report/archive/superseded/**` or document why they remain.

Acceptance checks:

```sh
wc -l /tmp/report-consumed-inputs.txt /tmp/report-unconsumed-artifacts.txt
sed -n '1,120p' /tmp/report-unconsumed-artifacts.txt
```

Expected result: a reviewable artifact inventory, not a destructive cleanup.

### Lane 6 - Final PDF Refresh and Release Gate

Purpose: produce the actual committee-facing PDF after source polish is done.

Target artifact:

- `public/final-report.pdf`

Commands:

```sh
git diff --check -- report/final-report.tex report/frontmatter report/sections report/appendices report/TODO.md
pipenv run ops-audit-references
pipenv run ops-build-report --outdir /tmp/masters-report-build --no-sync-final-pdf
pipenv run ops-build-report --outdir /tmp/masters-report-build
```

Then verify the tracked PDF changed intentionally:

```sh
git status --short -- public/final-report.pdf report
pdfinfo public/final-report.pdf | sed -n '1,80p'
pdftotext -layout public/final-report.pdf /tmp/final-report-public.txt
rg -n "TODO|FIXME|verification record|reproducibility records|accepted-reference|validation workflow|Newtonian wall|clinical validation result|reference standard" /tmp/final-report-public.txt
```

Expected result:

- Build passes.
- `public/final-report.pdf` is refreshed.
- No blocking prose terms remain in the rendered public PDF.
- Any remaining appendix-specific terms are intentional and defensible.

## Final Validation Gate

Run this after all lanes:

```sh
git diff --check -- report public/final-report.pdf
pipenv run ops-audit-references
pipenv run ops-build-report --outdir /tmp/masters-report-build --no-sync-final-pdf
pipenv run ops-build-report --outdir /tmp/masters-report-build
pdftotext -layout public/final-report.pdf /tmp/final-report-public.txt
rg -n "TODO|FIXME|these notes|clamp|floor|hook|local dataset|raw rows|quarantined|regeneration command|verification record|reproducibility records|accepted-reference|validation workflow|Newtonian wall|clinical validation result|reference standard" /tmp/final-report-public.txt
```

Interpretation:

- No matches: ready to send.
- Matches only in Appendix H command headings or reproducibility context:
  manually review and accept if committee-facing.
- Matches in abstract, main sections, discussion, or conclusion: block
  submission and patch.

## Commit Plan

Use two commits if all lanes are implemented:

1. `Polish report for committee submission`
   - `report/final-report.tex`
   - `report/frontmatter/**`
   - `report/sections/**`
   - `report/appendices/**`
   - `report/TODO.md` if retained as a planning artifact

2. `Refresh final report PDF`
   - `public/final-report.pdf`

Do not stage unrelated package/runtime/doc changes currently present under
`packages/stenotic-hemodynamics/**` or `public/docs/**` unless a separate lane
explicitly owns them.

## Submission Verdict After Plan

If Lanes 1--4 and Lane 6 pass, the report should be treated as **A+ ready for
committee submission**. Lane 5 is useful source stewardship but should not block
submission unless the committee will receive the full repository tree rather
than only the PDF and core report sources.
