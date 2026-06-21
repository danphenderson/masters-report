# Repository Artifact Policy

Apply this policy before moving, regenerating, deleting, staging, or ignoring
repository artifacts.

Separate source moves, reference-metadata decisions, report-artifact refreshes,
and ignore-rule changes into distinct patches. Do not combine them in one
cleanup sweep. Use `public/docs/agent-workflows.md` for bounded agent handoffs.
Treat `pipenv run ops-orchestrate status` as read-only classification.

Do not install repo-managed commit hooks. Do not create background automation.
Do not write persistent orchestration receipts.

## Non-Negotiable Rules

- Do not delete manuscript-linked figures, tables, PDFs, static data, or
  rendered assets until TeX references and appendix provenance have been
  checked.
- Do not delete private reference mirrors merely because they appear duplicated.
- Do not commit local environments, caches, scratch simulation outputs, LaTeX
  byproducts, raw 3D data, or ignored experiment outputs.
- Do not refresh `public/final-report.pdf` except through a passing report build
  gate and an explicitly scoped artifact-refresh or publication task.
- Do not refresh report-consumed rendered assets unless the current TeX source
  consumes them and the task explicitly lists them in scope.
- Do not hide source, published assets, or provenance files behind broad
  `.gitignore` patterns.
- Do not stage or delete untracked report inputs automatically when the report
  build wrapper reports them. Inspect `report-build-summary.json` first.

## Artifact Classes

| Class | Examples | Tracking policy | Regeneration authority | Automatic deletion | Required validation |
| --- | --- | --- | --- | --- | --- |
| Source code | `packages/julia/src/StenosisHemodynamics.jl`, `packages/julia/src/StenosisHemodynamics/**`, `packages/julia/bin/**`, `packages/julia/README.md`, `packages/julia/test/**`, `packages/julia/Project.toml`, `packages/julia/Manifest.toml`, `Pipfile`, `Pipfile.lock`, `packages/ops/**` | Track source, package manifests, lockfiles, tests, and documented wrappers. | Regenerate only through the owning language package or lockfile workflow. | Never. | Run targeted Julia or Python tests for the changed surface. Use `pipenv run ops-julia-check` for Julia validation and `pipenv run ops-python-check` for Python support-tooling changes. |
| Manuscript/report source | `report/final-report.tex`, `report/frontmatter/**`, `report/sections/**`, `report/appendices/**`, `report/preamble/**`, `public/references/references.bib`, `report/assets/tikz/**` | Track TeX source, bibliography metadata, TikZ source, and report-consumed inputs. | Edit source deliberately. Regenerate only files documented as generated. | Never. | For ordinary source validation, run `pipenv run ops-build-report --outdir /tmp/masters-report-build --no-sync-final-pdf`. Use the full build only when artifact refresh or publication is in scope. |
| Manuscript-used static data and tables | `report/assets/data/**`, `report/assets/tables/package-benchmark/package-benchmark-summary.tex` | Track when the current report consumes the data or table. | Regenerate through the documented simulation, benchmark, or rendering command that owns the asset. | Never. | Check TeX references, appendix provenance text, and recorded hashes before replacing. Follow with a validation-only report build unless publication is in scope. |
| Generated report outputs | `public/final-report.pdf`, `report/assets/rendered/*.pdf`, `report/assets/rendered/*.png` | Track rendered figures only when the report consumes them. Keep `public/final-report.pdf` as an ignored local/release artifact, not source. | Refresh only through a passing owning gate and an explicitly scoped artifact-refresh task. | Never for report-consumed figures. Ignored local PDFs may be removed when not active evidence. | Validate with scratch renderer output or report build first. Publish final PDFs through release artifacts, not ordinary source commits. |
| Simulation/benchmark outputs | `tmp/simulations/output/**`, `tmp/experiments/**`, `public/var/logs/*.jsonl`, `public/var/logs/*.json`, per-run `manifest.json`, `series.csv`, `solution.npz`, summary CSVs, benchmark logs | Keep run outputs and logs ignored except deliberately published report assets under `report/assets/**`. | Regenerate as run outputs through `pipenv run ops-experiment ...`; Julia remains the numerical execution engine underneath. | Delete only ignored scratch outputs that are not active evidence. | Verify that equivalent published assets, manifests, logs, or provenance records exist before discarding evidence-bearing outputs. For benchmark changes, run the relevant smoke or overnight command and inspect summaries. |
| Reference metadata and private full-text mirrors | `public/references/source-inventory.tsv`, `public/references/AGENTS.md`, `public/references/README.md`, `public/references/references.bib`, ignored `public/references/**/*.pdf`, ignored `public/references/**/*.html` | Track metadata. Keep third-party full-text files as private local mirrors outside public Git releases. | Edit source records deliberately. Reacquire full-text mirrors from external sources or private archives. | Never automatically delete private mirrors. | Follow `public/references/AGENTS.md`. Run `pipenv run ops-audit-references`, `pipenv run pytest packages/ops/tests/test_references_inventory.py packages/ops/tests/test_tex_preamble_audit.py`, and `biber --tool --validate-datamodel --output-file /tmp/masters-report-references.bib public/references/references.bib` after moving, adding, or reclassifying reference records. |
| Ignored local environments/caches | `.venv/`, `.julia_depot/`, `.pytest_cache/`, `.ruff_cache/`, `__pycache__/`, `*.egg-info/`, local editor files, `.DS_Store` | Do not track. | Recreate through documented Julia or Pipenv setup. | Delete when no command is actively using them. | `git status --short --ignored=matching` must show them as ignored, not untracked. |
| Large/raw data | `public/var/data/simulations/**`, local XDMF/HDF5 resolved-3D inputs, future raw solver dumps or external datasets | Do not track unless the project owner approves Git LFS, DVC, or another archival policy. | Do not regenerate external raw inputs. Regenerate derived data only when regeneration is documented. | Delete only disposable local copies with known source or archive pointers. | Record source, checksum, and expected local path before relying on the data. Keep raw data out of ordinary commits until an archival strategy is approved. |
| Stale or review-only artifacts | Root review handbacks, historical review notes, superseded local notes, one-off audit exports | Do not track unless intentionally retained as project documentation. | Do not regenerate. | Do not delete automatically. | Confirm the artifact is not referenced by TeX, README, AGENTS, appendix provenance, active review notes, or pending dirty work. Move or remove it in its own cleanup patch. |

## Report Build Gates

Use validation-only builds for ordinary report source review:

```sh
pipenv run ops-build-report --outdir /tmp/masters-report-build --no-sync-final-pdf
```

Use artifact-refresh builds only when `public/final-report.pdf` or a generated
report asset is explicitly in scope:

```sh
pipenv run ops-build-report --outdir /tmp/masters-report-build
```

The wrapper runs the TeX preamble audit, invokes `latexmk` in a scratch output
directory, fails on untracked consumed report inputs, and writes
`report-build-summary.json` in the outdir. The full build refreshes the ignored
`public/final-report.pdf` only after the gate passes.

Do not refresh ignored public PDFs during ordinary source validation.

## Cleanup Sequence

1. Re-anchor on the live checkout with `git status --short --branch` and
   `pipenv run ops-orchestrate status`.
2. Resolve or explicitly set aside active manuscript, PDF, or generated-asset
   dirty work before moving or deleting artifacts.
3. Update policy docs before broad cleanup when policy gaps are discovered.
4. Handle stale root review handbacks or historical review notes in a small
   documentation/provenance patch.
5. Audit unused report assets by checking TeX inputs, `\includegraphics`,
   `\figtikz`, appendix provenance text, and static hash records.
6. Keep bibliography metadata public while keeping third-party full-text mirrors
   ignored locally unless redistribution rights are approved.
7. Tighten `.gitignore` only for confirmed gaps. Avoid broad patterns that might
   hide manuscript source, published report assets, or provenance files.
8. Validate after each cleanup patch instead of after a large combined sweep.

## Baseline Validation Commands

Use the narrowest validation set that matches the patch. For policy-only
changes, run:

```sh
git status --short
git diff --check
pipenv run ops-orchestrate docs-contract
```

For reference metadata changes, add:

```sh
pipenv run ops-audit-references
pipenv run pytest packages/ops/tests/test_references_inventory.py packages/ops/tests/test_tex_preamble_audit.py
biber --tool --validate-datamodel --output-file /tmp/masters-report-references.bib public/references/references.bib
```

For report source or report-consumed asset validation, add:

```sh
pipenv run ops-build-report --outdir /tmp/masters-report-build --no-sync-final-pdf
```

For publication refreshes that intentionally update the local release PDF, use:

```sh
pipenv run ops-build-report --outdir /tmp/masters-report-build
```

For code changes, add the relevant test suite:

```sh
pipenv run ops-julia-check
pipenv run ops-python-check
```

For simulation or benchmark execution, run through the ops experiment runner so
terminal output and JSON logs are captured together:

```sh
pipenv run ops-experiment benchmark --profile smoke \
  --output-dir tmp/simulations/output/package_benchmark/smoke --overwrite
```

## Related Policies

- Use `public/docs/index.md` for the full documentation map.
- Use `public/docs/policy-vocabulary.md` for shared terms and modal verbs.
- Use `public/docs/agent-workflows.md` for bounded agent dispatch and review.
- Use `public/docs/report-builds.md` for report build modes and summary JSON.
- Use `public/docs/ops-tooling.md` for audit and renderer commands.
- Use `public/docs/julia-cli-workflows.md` for Julia workflow commands.
- Use `public/docs/report-assets-and-provenance.md` before report asset refresh.
- Use `public/docs/resolved3d-workflows.md` before optional resolved-3D work.
- Use `public/docs/benchmark-pipeline.md` before generating package benchmark
  outputs or report-consumed benchmark assets.
- Use `public/docs/publication-readiness.md` before public export or release
  publication.
