<!-- contract_ref: text.scoped.references_agents -->

# References Agent Instructions

This directory tree stores local literature and web-source artifacts used by or
adjacent to the master's report. The report bibliography entrypoint remains
`references.bib`; local archive provenance is tracked separately in
`references/source-inventory.tsv`.

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
- `99_duplicates_superseded/`: proven duplicates or superseded local snapshots;
  do not delete sources just because they look redundant.

## Inventory Contract

Maintain `references/source-inventory.tsv` for every tracked source artifact
under `references/**` except this file and the inventory itself. The columns are:

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
- `duplicate-superseded`: the source is a duplicate or superseded local copy.

`current-cited` rows must have a `bib_key` present in `references.bib` and cited
by the current TeX source. Rows may leave `bib_key` blank when a local artifact
has no BibLaTeX entry yet; record that gap in `notes`.

## Naming Convention

Use:

```text
<year>_<first-author-or-org>_<short-topic-slug>.<ext>
```

If the author or year is unknown, keep the file under `98_needs_review/` until
the metadata is resolved.

## Required Validation

After moving, adding, or reclassifying files under `references/**`, run:

```text
python3 scripts/audit_references.py
pipenv run pytest test/test_references_inventory.py test/test_tex_preamble_audit.py
biber --tool --validate-datamodel --output-file /tmp/masters-report-references.bib references.bib
```

Run `pipenv run ruff check .` and `pipenv run black --check .` when Python audit
or test files change. Use a scratch `latexmk` build only when `references.bib`,
TeX citations, or bibliography plumbing changes.
