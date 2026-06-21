# Report Assets And Provenance

Treat every file under `report/assets/**` as owned by either TeX source or a
documented generation workflow. Do not refresh or delete report-consumed assets
without checking the current TeX consumer and running the owning validation.

## Asset Classes

| Path | Role | Owning workflow | Validation |
| --- | --- | --- | --- |
| `report/assets/tikz/**` | Hand-maintained TikZ source consumed through `\figtikz`. | TeX source edits. | Validation-only report build. |
| `report/assets/data/verification/**` | Verification CSV/DAT data consumed by tables or TikZ. | `stenosis-hemodynamics verify ...` and related Julia workflows. | Owning Julia workflow plus validation-only report build. |
| `report/assets/tables/verification/**` | Verification LaTeX tables. | Julia verification workflows or renderers. | Owning workflow plus validation-only report build. |
| `report/assets/data/stenosis-comparison/**` | 1D/resolved-3D comparison data, operator validation, and sensitivity rows. | `compare-3d`, `operator-validation`, and evidence summary tools. | Resolved-3D workflow checks plus validation-only report build. |
| `report/assets/tables/stenosis-comparison/**` | Comparison and operator-validation LaTeX tables. | `compare-3d` and `operator-validation`. | Owning workflow plus validation-only report build. |
| `report/assets/data/stenosis-geometry/**` | Geometry, mesh, envelope, and resolved velocity node CSVs. | `export-assets` and optional resolved-3D exports. | Owning Julia workflow plus renderer checks. |
| `report/assets/data/package-benchmark/**` | Published package benchmark CSVs and manifest. | `benchmark --publish-report-assets`. | Benchmark post-run checks plus validation-only report build. |
| `report/assets/tables/package-benchmark/**` | Package benchmark summary table. | `ops-render-package-benchmark-figures`. | Renderer command plus validation-only report build. |
| `report/assets/rendered/**` | Rendered PDF/PNG figures consumed by TeX. | Python renderers or manually scoped figure refresh. | Owning renderer plus validation-only report build. |

## TeX Consumers

Check TeX consumers before changing assets:

- `report/sections/01-intro/index.tex` consumes
  `report/assets/rendered/stenosis-fem-fvm-meshes.pdf`.
- `report/sections/07-case-study/verification.tex` consumes verification tables,
  operator-validation tables, and `rest-state-flow-profiles`.
- `report/sections/07-case-study/comparison.tex` consumes
  `resolved-3d-flow-field.pdf`, comparison data, grid-sensitivity tables, and
  section-mean TikZ figures.
- `report/appendices/numerical-methods-details.tex` consumes package benchmark
  tables and figures, p/h refinement figures, stationary-Stokes refinement
  tables, and full rest-state drift tables.

Use `rg` against `report/**/*.tex` when a consumer is unclear.

## Refresh Rules

- Refresh TikZ assets by editing the tracked `.tex` source directly.
- Refresh data and table assets only through the Julia or ops command that owns
  the workflow.
- Refresh rendered assets only when the current TeX source consumes them and the
  task explicitly scopes the rendered path.
- Keep ordinary run outputs under `tmp/**` or `tmp/simulations/output/**`.
- Do not refresh `public/final-report.pdf` after an asset update unless release
  publication is explicitly in scope.

## Minimum Validation

After report-consumed asset changes, run:

```sh
pipenv run ops-build-report --outdir /tmp/masters-report-build --no-sync-final-pdf
```

Also run the owning workflow validation:

- Julia tests for package code or workflow behavior changes.
- The specific Julia CLI command when regenerating data/table assets.
- The specific `ops-render-*` command when regenerating rendered figures or
  LaTeX summary tables.
- `pipenv run ops-orchestrate status --strict` before release or artifact
  handoff readiness checks.

## Related Policies

- Use `public/docs/artifact-policy.md` for artifact classes and cleanup rules.
- Use `public/docs/report-builds.md` for build-gate behavior.
- Use `public/docs/ops-tooling.md` for renderer command details.
- Use `public/docs/resolved3d-workflows.md` for resolved-3D assets.
- Use `public/docs/benchmark-pipeline.md` for package benchmark assets.
