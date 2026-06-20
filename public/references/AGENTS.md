<!-- contract_ref: text.scoped.references_agents -->

# References Agent Instructions

This directory tree stores public bibliography metadata and private/local path
hints for literature and web-source artifacts used by or adjacent to the
master's report. The report bibliography entrypoint remains `public/references/references.bib`;
source provenance is tracked separately in `public/references/source-inventory.tsv`.
Public GitHub releases do not track third-party full-text PDFs or HTML mirrors.

## Directory Policy

The reference tree is grouped by how each source supports the current
manuscript:

- `01_report_foundations/`: currently cited continuum, rheology, wall-shear,
  Navier--Stokes, and dimension-reduction foundations.
- `02_report_model_hierarchy/`: currently cited or report-adjacent 0D, 1D, 2D,
  3D, multiscale, FSI, and stenosis-model sources.
- `03_report_clinical_pressure_flow/`: currently cited or report-adjacent
  coronary stenosis, pressure-flow, FFR, CT-FFR, and shear-output sources.
- `04_report_numerics_verification/`: currently cited or report-adjacent
  numerical methods, solver, reproducibility, benchmark, and verification
  sources.
- `70_report_adjacent_candidates/`: uncited sources plausibly useful for the
  current report if the prose later needs additional support.
- `80_future_surrogates_and_pinns/`: uncited operator-learning, PINN, Deep Ritz,
  scientific-ML, and surrogate-model sources reserved for future work.
- `90_background_archive/`: uncited broad background that is useful to retain
  but not central to the current report.
- `98_needs_review/`: files with incomplete local metadata, unknown authorship,
  uncertain bibliographic mapping, or unclear manuscript relevance.
- `99_duplicates_superseded/`: proven duplicates or superseded local snapshots
  retained only when local provenance still requires the file. Exact duplicate
  files may be removed in a scoped reference-cleanup patch after confirming the
  replacement artifact, updating `public/references/source-inventory.tsv`, and running
  the required validation below.

## Inventory Contract

Maintain `public/references/source-inventory.tsv` for every source record used by the
report or retained as research context. In public releases, `local_path` is a
private archive path hint and may point to an ignored local PDF or HTML file
that is not tracked by Git. The columns are:

```text
source_id    bib_key    local_path    status    manuscript_role    notes
```

Use these status values only:

- `current-cited`: the source artifact maps to a BibLaTeX key cited by the
  current TeX manuscript.
- `report-adjacent`: the source is close to the current report but not cited.
- `future-work`: the source is retained for later surrogate, PINN, operator
  learning, or broader method extensions.
- `background`: the source is retained as broad background only.
- `needs-review`: the source needs bibliographic, metadata, or relevance review.
- `duplicate-superseded`: the source is a duplicate or superseded local copy
  retained for a documented provenance reason.

`current-cited` rows must have a `bib_key` present in `public/references/references.bib` and cited
by the current TeX source. Rows may leave `bib_key` blank when a source has no
BibLaTeX entry yet; record that gap in `notes`.

## Naming Convention

Use:

```text
<year>_<first-author-or-org>_<short-topic-slug>.<ext>
```

If the author or year is unknown, keep the file under `98_needs_review/` until
the metadata is resolved.

## Required Validation

After moving, adding, reclassifying, or externalizing source records under
`public/references/**`, run:

```text
pipenv run ops-audit-references
pipenv run pytest packages/ops/tests/test_references_inventory.py packages/ops/tests/test_tex_preamble_audit.py
biber --tool --validate-datamodel --output-file /tmp/masters-report-references.bib public/references/references.bib
```

Run `pipenv run ops-python-check` when Python audit
or test files change. Use a scratch `latexmk` build only when `public/references/references.bib`,
TeX citations, or bibliography plumbing changes.
