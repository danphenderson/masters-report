# Next-Round Mathematical and Numerical Narrative Plan

## Current Status

The public report PDF has been refreshed and committed from the current report
source.

- Build command: `pipenv run ops-build-report --outdir /tmp/masters-report-build`
- Build result: `passed`
- Consumed report inputs: `63`
- Untracked consumed inputs: none
- Synced PDF: `public/final-report.pdf`
- Synced PDF SHA-256:
  `c0d76a37e34142499c7fdfb3628459eb805468f48af05768069d126935f1d3a7`
- PDF refresh commit: `7920835 Refresh final report PDF`

The mathematical and numerical narrative is committee-ready at an overall
`A` to near-`A+` level. The next round should be a small source-only editorial
pass, not another broad rewrite. The only concrete prose-audit finding from
`pipenv run ops-audit-report-prose --json` is a low-severity topic-ownership
warning in `report/sections/05-numerical-methods/index.tex:65`: the opening of
the FEM/FSI subsection restates continuum-foundation language inside the
numerical-methods chapter.

The rendered-text scan of the refreshed PDF found no reader-visible matches for:

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
TODO
FIXME
```

The live dirty tree may include unrelated Julia package/runtime files under
`packages/stenotic-hemodynamics/**`. Those files are outside this editorial lane
and must not be staged, normalized, or reverted as part of the next report prose
pass.

## Audit Grades

| Area | Grade | Editorial assessment |
| --- | --- | --- |
| Abstract/front matter | A+ | Clear scope, bounded contribution, and clean review-first framing. |
| 1 Introduction | A+ | Strong motivation and correct positioning of the case study as illustrative evidence. |
| 2 Continuum | A | Mathematically precise and well organized; dense, but appropriate for the audience. |
| 3 Model hierarchy | A+ | Retained-state and dimension language are explicit and useful. |
| 4 Closures/observables | A+ | Constitutive roles, wall closure, geometry, boundary data, and observables are cleanly separated. |
| 5 Numerical methods | A | Strong stencil and evidence standard; one subsection opening should cross-reference continuum setup rather than restating it. |
| 6 Synthesis | A | Compact proposition-family summary; effective as a bridge to the case study. |
| 7 Case-study overview | A+ | The chapter opens with positive evidence, negative limitation, and comparison target. |
| 7.1 Methodology | A | Model contract leads; table/equation density remains high but defensible. |
| 7.2 Verification | A | MMS evidence, rest-state limitation, and admissibility distinction are clear. |
| 7.3 Comparison | A | The 23%/40% result is interpreted rather than merely reported; secondary diagnostics remain dense. |
| 8 Discussion | A+ | Research questions and claim boundaries are answered directly. |
| 9 Conclusion | A | Submission-ready and accurate; intentionally concise. |
| Appendices | A | Long and command-heavy where appropriate; appendix scope keeps main prose clean. |

## Next Round Objective

Lift the numerical-methods narrative from `A` to `A+` by resolving the Section 5
topic-ownership warning and checking the case-study numerical narrative for
only concrete cadence defects. Preserve all mathematical claims, citations,
tables, figures, labels, numerical values, public claim registers, bibliography
metadata, package files, generated assets, and `public/final-report.pdf` unless
the next instruction explicitly widens scope.

## Implementation Plan

### Step 1 - Re-Anchor and Protect Unrelated Work

Run:

```sh
git status --short
pipenv run ops-orchestrate status --json
```

Confirm any dirty `packages/stenotic-hemodynamics/**` files are unrelated to the
report prose lane. Do not stage or edit them.

### Step 2 - Patch the Section 5.1 Opening

Edit only `report/sections/05-numerical-methods/index.tex`.

Target: the first paragraph of
`\subsection{Finite-Element Incompressible Flow and FSI}` around line 65.

Required change:

- Make the paragraph begin from the continuum fields and weak-form setup already
  established in Section~\ref{sec:continuum-description}.
- Avoid restating Navier--Stokes or Stokes foundations as if Section 5 owns the
  continuum derivation.
- Preserve the claim that the FEM/FSI numerical assertion is a mixed weak-form
  and interface-coupling assertion, not simply a mesh assertion.
- Preserve the existing citation to `GaldiEtAl2008HemodynamicalFlows`.
- Preserve the stiffness/sparsity/stencil paragraph that follows.

Suggested replacement shape:

```tex
With the continuum fields and weak balances fixed in
Section~\ref{sec:continuum-description}, a resolved finite-element calculation
discretizes the weak incompressible-flow or FSI problem. The numerical claim is
therefore a mixed weak-form and interface-coupling claim, not simply a mesh
claim. A finite-element realization chooses discrete velocity and pressure
spaces ...
```

Adjust the final wording to fit local cadence and avoid duplicate "weak" usage.
Do not introduce new citations or derivations.

### Step 3 - Run the Prose Audit Before Any Wider Edit

Run:

```sh
pipenv run ops-audit-report-prose --json > /tmp/report-prose-audit.json
jq '{chunks, context_files, files_seen, primary_files, findings: [.findings[] | {path,line,severity,rule,message}]}' \
  /tmp/report-prose-audit.json
```

Expected result: the Section 5 topic-owner warning is gone. If a different
low-severity finding appears, inspect it before editing. If the tool still flags
the same paragraph, make one more local Section 5 adjustment rather than
rewriting Section 2 or Section 7.

### Step 4 - Bounded Case-Study Cadence Check

Do not reopen Section 7 by default. Review only for concrete mathematical or
numerical narrative defects introduced by the previous prose passes:

```sh
rg -n "not validation|diagnostic|finite-volume|MMS|rest-state|23\\%|40\\%|observation operator|membrane" \
  report/sections/07-case-study -g '*.tex'
```

Allowed edits:

- one-sentence transition repairs;
- obvious typo or duplicated-word fixes;
- wording that makes verification, comparison, and validation boundaries more
  precise without changing the claim.

Disallowed edits:

- moving generated table assets;
- changing numerical values;
- adding new citations;
- adding new validation language;
- refreshing the public PDF.

If no concrete defect appears, leave Section 7 unchanged.

### Step 5 - Leave Source Labels Alone Unless They Become Reader-Facing

The source scan may still find stable TeX labels such as
`app:num-rheology-descriptor-details` or `app:num-secondary-implementation-checks`.
These are not reader-facing manuscript prose. Do not rename them just to satisfy
a raw source-string search; label churn is only worth doing if a rendered
caption, heading, or paragraph exposes the same implementation-facing wording.

### Step 6 - Validate the Source-Only Patch

Run:

```sh
git diff --check -- report/sections/05-numerical-methods/index.tex report/TODO.md
pipenv run ops-audit-report-prose --json > /tmp/report-prose-audit.json
jq '{findings: [.findings[] | {path,line,severity,rule,message}]}' /tmp/report-prose-audit.json
pipenv run ops-audit-references
pipenv run ops-build-report --outdir /tmp/masters-report-build --no-sync-final-pdf
pdftotext -layout /tmp/masters-report-build/final-report.pdf /tmp/final-report-next-narrative.txt
rg -n "backend parity|implementation-check|accepted-reference|validation workflow|regeneration command|Newtonian wall|clinical validation result|reference standard|pending_final_release" \
  /tmp/final-report-next-narrative.txt || true
```

Expected result:

- no whitespace errors;
- no new bibliography or source-inventory work;
- report build passes;
- `untracked_consumed_inputs` remains empty;
- rendered claim-boundary scan is clean;
- `public/final-report.pdf` remains unchanged in this source-only next round.

### Step 7 - Commit Discipline

Stage only the report-source files edited in the next round. The expected source
patch is:

```sh
git add report/sections/05-numerical-methods/index.tex
```

If the next round updates this plan after implementation, also stage
`report/TODO.md`. Do not stage unrelated Julia package/runtime files or refresh
`public/final-report.pdf` unless explicitly requested.

Suggested commit subject for the next source-only patch:

```text
Tighten numerical methods continuum bridge
```

## Do Not Reopen

The next round should not reopen:

- the report spine or section order;
- broad mathematical derivations;
- new literature review sources;
- bibliography entries or `public/references/source-inventory.tsv`;
- public claim registers or reproducibility metadata;
- package/runtime code;
- raw data under `public/var/data/**`;
- generated report assets;
- the synced public PDF.

## Live Layout Guardrails

Use the current layout, not stale historical paths:

- manuscript entrypoint: `report/final-report.tex`;
- discussion and conclusion: `report/sections/08-discussion-conclusion/index.tex`;
- Appendix G: `report/appendices/numerical-methods-details.tex`;
- Appendix H: `report/appendices/code-and-ai-use.tex`;
- repo documentation: `public/docs/**`.

Do not reference nonexistent root `docs/revision-claim-ledger.md`,
`docs/revision-release-gates.md`, or
`report/sections/03-conclusions/index.tex`.
