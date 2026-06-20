# Repository Artifact Policy

This policy defines how repository artifacts should be treated before cleanup
work begins. It is intentionally conservative because the report source,
rendered figures, reference metadata, private local full-text mirrors, and
scratch experiment outputs have different ownership and validation requirements.

Cleanup should happen in scoped patches. Do not combine source moves,
reference-metadata decisions, report-artifact refreshes, and ignore-rule
changes in one sweep.

## Artifact Classes

| Class | Current examples | Usually tracked? | May be regenerated? | May be deleted automatically? | Required validation before changing |
| --- | --- | --- | --- | --- | --- |
| Source code | `src/StenosisHemodynamics.jl`, `src/StenosisHemodynamics/**`, `scripts/**`, `simulations/README.md`, `test/**`, `Project.toml`, `Manifest.toml`, `pyproject.toml`, `Pipfile`, `Pipfile.lock` | Yes. | Only by the language package or lockfile workflow that owns the file. | No. | Run targeted Julia or Python tests for the changed surface. Use `./scripts/julia-release test/runtests.jl` for Julia changes; use `pipenv run pytest`, `pipenv run ruff check .`, and `pipenv run black --check .` for Python support-tooling changes. |
| Manuscript/report source | `final-report.tex`, `frontmatter/**`, `sections/**`, `appendices/**`, `preamble/**`, `references.bib`, `figures/static/static/tikz/**` | Yes. | TeX source is edited, not regenerated, unless a file is explicitly documented as generated. | No. | Run `python3 scripts/build_report.py --outdir /tmp/masters-report-build` when report structure, citations, figures, bibliography plumbing, or TeX policy changes. The wrapper runs the preamble audit, uses scratch `latexmk`, fails on untracked consumed inputs, and writes `report-build-summary.json` in the outdir. |
| Manuscript-used static data and tables | `figures/static/static/data/**`, `figures/static/static/tables/package-benchmark/package-benchmark-summary.tex` | Yes, when the current report consumes the data or table. | Yes, through the documented simulation or rendering command that owns the asset. | No. | Check TeX references, appendix provenance text, and any recorded hashes before replacing. Rebuild the report in a scratch output directory after updates. |
| Generated report outputs | `final-report.pdf`, `figures/static/static/rendered/*.pdf`, `figures/static/static/rendered/*.png` | Rendered figures are tracked when the report consumes them; `final-report.pdf` is a release artifact, not a source-tree artifact. | Yes, but only when the source change explicitly requires a synced artifact refresh. | No for report-consumed figures; yes for ignored local PDFs. | First validate with a scratch build or renderer output. Publish final PDFs through release artifacts rather than ordinary source commits. |
| Simulation/benchmark outputs | `simulations/output/**`, `tmp/experiments/**`, per-run `manifest.json`, `series.csv`, `solution.npz`, summary CSVs, benchmark logs | No, except for deliberately published report assets copied under `figures/static/static/**`. | Yes. These are run outputs. | Yes, when they are ignored scratch outputs and are not being used as evidence for an active review. | Verify that equivalent published assets, manifests, or provenance records exist before discarding evidence-bearing outputs. For benchmark changes, rerun the relevant smoke or full command and inspect emitted summaries. |
| Reference metadata and private full-text mirrors | `references/source-inventory.tsv`, `references/AGENTS.md`, `references/README.md`, `references.bib`, ignored `references/**/*.pdf`, ignored `references/**/*.html` | Metadata is tracked; third-party full-text files are private local mirrors and are not tracked in public GitHub releases. | No. Source records are edited deliberately; full-text mirrors are reacquired from external sources or private archives. | No automatic deletion of private mirrors. | Follow `references/AGENTS.md`. Run `python3 scripts/audit_references.py`, `pipenv run pytest test/test_references_inventory.py`, and `biber --tool --validate-datamodel --output-file /tmp/masters-report-references.bib references.bib` after moving, adding, or reclassifying reference records. |
| Ignored local environments/caches | `.venv/`, `.julia_depot/`, `.pytest_cache/`, `.ruff_cache/`, `__pycache__/`, `*.egg-info/`, local editor files, `.DS_Store` | No. | Yes. They are local machine state. | Yes, if no command is actively using them. | `git status --short --ignored=matching` should show them as ignored, not untracked. Recreate environments through the documented Julia or Pipenv setup if needed. |
| Large/raw data | `simulations/data/3d/**`, local XDMF/HDF5 resolved-3D inputs, any future raw solver dumps or external datasets | No, unless the project owner explicitly chooses Git LFS, DVC, or another archival policy. | No for external raw inputs; yes for derived data when regeneration is documented. | No, unless the data is a disposable local copy and its source or archive pointer is known. | Record source, checksum, and expected local path before relying on the data. Keep raw data out of ordinary commits until an LFS or archive strategy is approved. |
| Stale or review-only artifacts | Root review handbacks, historical review notes, superseded local notes, one-off audit exports | Usually no, unless intentionally retained as project documentation. | No. | No automatic deletion. Review provenance first. | Confirm the artifact is not referenced by TeX, README, AGENTS, appendix provenance, active review notes, or pending dirty work. Move or remove it in its own cleanup patch. |

## Cleanup Safety Rules

- Never delete manuscript-linked figures, tables, PDFs, or static data without
  checking TeX references and appendix provenance tables first.
- Never delete private reference mirrors solely because they appear duplicated.
  The `references/AGENTS.md` policy governs `references/**` and explicitly
  requires provenance-aware handling.
- Do not commit `.venv/`, `.julia_depot/`, caches, LaTeX byproducts, `tmp/**`,
  `simulations/output/**`, or raw 3D data under `simulations/data/3d/**`.
- Treat `final-report.pdf` as a local/release artifact. Keep report-consumed
  rendered figures tracked unless the project owner changes this policy.
- Use `python3 scripts/build_report.py --outdir /tmp/masters-report-build` as
  the preferred report build gate. If it reports untracked consumed inputs, do
  not stage or delete them automatically; inspect the summary and handle the
  source/asset ownership deliberately.
- Perform cleanup in scoped patches. Keep source edits, generated-artifact
  refreshes, reference-metadata changes, and ignore-rule changes separate.
- If the tree already contains active manuscript or PDF work, resolve or
  explicitly set aside that work before moving or deleting artifacts.
- Prefer scratch output directories such as `/tmp/masters-report-build` and
  `tmp/**` for validation and experiments.

## Recommended Cleanup Sequence

1. Resolve the active manuscript dirty state, including any untracked live
   section files and any local `final-report.pdf` drift.
2. Establish or update this policy before moving artifacts.
3. Handle stale root review handbacks or historical review notes in a small
   documentation/provenance patch.
4. Audit unused report assets by checking TeX inputs, `\includegraphics`,
   `\figtikz`, appendix provenance text, and static hash records.
5. Keep bibliography metadata public while keeping third-party full-text mirrors
   ignored locally, or publish full text only through a rights-cleared archive.
6. Tighten `.gitignore` only for confirmed gaps. Do not add broad patterns that
   might hide manuscript source, published report assets, or provenance files.
7. Validate build and tests after each cleanup patch rather than after a large
   combined sweep.

## Baseline Validation Commands

Use the narrowest validation set that matches the patch. For policy-only
changes, run:

```sh
git status --short
git diff --check
```

For reference metadata changes, add:

```sh
python3 scripts/audit_references.py
pipenv run pytest test/test_references_inventory.py test/test_tex_preamble_audit.py
biber --tool --validate-datamodel --output-file /tmp/masters-report-references.bib references.bib
```

For report source or published report-asset changes, add a scratch build:

```sh
python3 scripts/build_report.py --outdir /tmp/masters-report-build
```

The wrapper calls `latexmk -pdf -interaction=nonstopmode -halt-on-error`
underneath and leaves the PDF/log/FLS plus `report-build-summary.json` in the
scratch output directory.

For code changes, add the relevant test suite:

```sh
./scripts/julia-release test/runtests.jl
pipenv run pytest
pipenv run ruff check .
pipenv run black --check .
```
