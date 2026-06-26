---
slug: /
sidebar_position: 1
title: Documentation index
---

# Documentation index

<section className="academic-hero">
  <div className="academic-kicker">Reproducible stenotic hemodynamics</div>
  <div className="academic-deck">
    {'This site documents the source tree for an idealized stenotic-vessel hemodynamics master\'s report: report builds, Julia solver workflows, artifact boundaries, and public-release guardrails. The emphasis is reproducibility and bounded evidence, not marketing copy or unqualified simulation claims.'}
  </div>
</section>

<div className="academic-card-grid">
  <div className="academic-card">
    <h3>Build from source</h3>
    <div className="academic-card-body">
      {'Use the report build and ops tooling pages for validation-only builds, support scripts, and release gates.'}
    </div>
  </div>
  <div className="academic-card">
    <h3>Trace artifact ownership</h3>
    <div className="academic-card-body">
      {'Use the artifact and provenance pages before moving, regenerating, or publishing data, figures, logs, or release PDFs.'}
    </div>
  </div>
  <div className="academic-card">
    <h3>Inspect numerical workflows</h3>
    <div className="academic-card-body">
      {'Use the Julia CLI and StenoticHemodynamics pages to separate smoke, validation, comparison, and deferred reproduction claims.'}
    </div>
  </div>
</div>

<div className="academic-callout">
  <h2>Evidence boundary</h2>
  <div className="academic-callout-body">
    {'Current native resolved-FSI documentation describes package/operator evidence, schema-v3 checkpoint metadata, and qualified internal split-run resume. It does not claim public/default resume, production-scale Section 4.1 reproduction, monolithic ALE FSI, clinical validation, or report evidence promotion.'}
  </div>
</div>

Use this map to find the repository guide that matches the task. Keep policy
terms aligned with `public/docs/policy-vocabulary.md`.

## Start here

- `README.md`: reviewer quick start, environment setup, and top-level project
  layout.
- `AGENTS.md`: repository rules for coding agents and scoped handoffs.
- `CONTRIBUTING.md`: short contributor checklist for small patches and pull
  requests.

## Build and validation

<div className="academic-map-list">

- [Report builds](report-builds.md): report build wrapper, validation-only builds,
  artifact-refresh builds, consumed-input tracking, and failure summaries.
- [Ops tooling](ops-tooling.md): packaged Python `ops-*` commands for
  experiments, audits, renderers, orchestration, and evidence summaries.
- [Julia CLI workflows](julia-cli-workflows.md): Julia command families exposed through
  `packages/stenotic-hemodynamics/bin/stenotic-hemodynamics`.

</div>

## Artifacts and data

<div className="academic-map-list">

- [Repository artifact policy](artifact-policy.md): artifact classes, non-negotiable cleanup
  rules, and baseline validation gates.
- [Report assets and provenance](report-assets-and-provenance.md): report asset directories,
  owning commands, TeX consumers, and refresh validation.
- [Resolved-3D workflows](resolved3d-workflows.md): optional resolved-3D inputs, skip
  behavior, comparison workflows, and publication boundaries.
- [Package benchmark pipeline](benchmark-pipeline.md): package benchmark profiles, outputs, and
  report-asset publication rules.

</div>

## Handoffs and release

<div className="academic-map-list">

- [Lightweight agent workflows](agent-workflows.md): `ops-orchestrate` modes, profiles, packet
  checks, and validation defaults.
- [GitHub publication readiness](publication-readiness.md): public export rules and release
  validation.
- [Docs site publishing](docs-site-publishing.md): Docusaurus local build,
  GitHub Pages workflow, repository setting, and deferred search follow-up.
- [Policy vocabulary](policy-vocabulary.md): modal verbs and shared artifact/build
  vocabulary.
- [Executive assessment](executive-assessment.md): dated public-readiness assessment; do
  not treat it as current workflow policy.

</div>

## StenoticHemodynamics

<div className="academic-map-list">

- [StenoticHemodynamics workflow hub](stenotic-hemodynamics/workflows.md):
  code-level workflow map for package studies, verification, validation,
  benchmarks, visualization, and native resolved-FSI support.
- [StenoticHemodynamics web visualization](stenotic-hemodynamics/web-visualization.md):
  static browser visualization contract, export commands, temporal schema, and
  viewer checks.
- [Native resolved-FSI design boundary](stenotic-hemodynamics/native-resolved-fsi-design.md):
  package-owned implementation tiers and claim boundaries.
- [Native resolved-FSI Section 4.1 reproduction spec](stenotic-hemodynamics/native-resolved-fsi-section-4-1-reproduction.md):
  Section 4.1 reproduction contract and package mapping.
- [Native resolved-FSI restart/resume design](stenotic-hemodynamics/native-resolved-fsi-restart-resume-design.md):
  schema-v3 checkpoint metadata and qualified internal split-run resume
  boundary.
- [Section 4.1 production-scale validation plan](stenotic-hemodynamics/section-4-1-production-validation-plan.md):
  future production-scale evidence gates and operational safeguards.
- [Canic 2024 Section 4.1 source-artifact comparison](stenotic-hemodynamics/canic-2024-replication.md):
  source-artifact comparison workflow for Canic et al. 2024 Section 4.1
  numerical findings.

</div>

## References

- `public/references/README.md`: public reference metadata overview.
- `public/references/AGENTS.md`: scoped policy for `public/references/**`.
