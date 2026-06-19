# Revision Release Gates

This document records the release controls for the revision prompted by
`executive-assessment.md`. It complements `docs/revision-claim-ledger.md` and
the scratch evidence under `tmp/revision-evidence/`.

## Current release state

- The tracked release PDF is not the current source-of-record render during
  this revision. Treat page counts and hashes as volatile until the final
  scratch build is inspected.
- Several source files postdated the tracked PDF at the checkpoint. Treat the
  source tree plus scratch builds as the working revision state until a final
  PDF refresh is explicitly performed.
- The synchronized final PDF rendered on 2026-06-19 has 94 pages and SHA-256
  `4bfe9d403098b012f3df9f88d6e62afa0cc9edeb8e6f14239d23915afd866a99`.
- `executive-assessment.md` is an untracked review input. It should not be
  treated as part of the final archival report unless deliberately added in a
  separate documentation decision.

## Raw 3D data policy

The local resolved-3D files under `simulations/data/3d/canic_case3/` are
available on this machine but ignored by Git. A reproducible release must not
imply that a fresh clone contains those files.

Before claiming independent reproduction, choose exactly one data-release path:

1. Include the raw XDMF/HDF5 files in an immutable archive package with
   checksums.
2. Provide deterministic retrieval instructions plus checksums for the same
   files.

The current local checksum record is:

```text
tmp/revision-evidence/long-lived-worker/checksums.sha256
tmp/revision-evidence/current-summary/manifest.json
```

## Finalization sequence

1. Resolve numerical gates in `docs/revision-claim-ledger.md`.
2. Freeze the permitted claim set and complete source edits.
3. Run all validation required by the changed surfaces.
4. Build with:

   ```sh
   latexmk -pdf -interaction=nonstopmode -halt-on-error -outdir=/tmp/masters-report-build final-report.tex
   ```

5. Inspect the scratch PDF page count, rendered text, table readability, and
   key figures.
6. Refresh `final-report.pdf` exactly once from the approved scratch render.
7. Record final source commit, PDF checksum, generated-asset checksums, and raw
   data archive or retrieval checksums in the release notes.

## Minimum archive manifest

A committee-ready archive must contain or reference:

- report source rooted at `final-report.tex`;
- `Project.toml`, `Manifest.toml`, `src/StenosisHemodynamics/**`,
  `scripts/**`, and `test/**`;
- Python support-tooling environment files;
- raw resolved-3D data or retrieval/checksum instructions;
- generated report assets under `figures/static/static/**`;
- validation command log and final PDF checksum;
- a one-command reproduction note for the report build and any regenerated
  principal tables.
