<!-- contract_ref: text.scoped.references_agents -->

# References Agent Instructions

This directory tree stores literature and web-source files under `references/**`.
Provenance control is governed by the editable source-map truth, see `public/artifacts/source-map/source-map.json`, and the manuscript plus docs consumers are generated from that artifact.


## Directory Policy

The reference tree is grouped by how a source supports the current notes:

- `01_core_foundations/`: mathematical, physiological, rheological, and
  hemodynamic foundations.
- `02_hemodynamics_models/`: 0D, 1D, 2D, 3D, FSI, and coupled-model references.
- `03_conventional_solvers/`: FEM, FVM, numerical PDE, and solver background.
- `04_clinical_metrics/`: coronary stenosis, FFR, pressure-flow severity, and
  clinical motivation.
- `05_operator_learning/`: neural operators, FNO, DeepONet, and hemodynamic
  surrogate references.
- `06_physics_informed_ml/`: PINNs, VPINNs, Deep Ritz, and related scientific
  ML solver methods.
- `07_validation_benchmarking/`: reproducibility, validation, benchmark design,
  uncertainty, identifiability, and metrics.
- `90_background/`: useful background that is not central to the current notes.
- `95_unused_candidates/`: possibly useful sources that are not currently cited
  or weakly connected.
- `98_unknown_needs_review/`: files that could not be classified confidently
  from local metadata and notes evidence.
- `99_duplicates_superseded/`: reserved for proven duplicates or superseded
  sources; do not delete sources just because they look redundant.

## Naming Convention

Use:

```text
<year>_<first-author-or-org>_<short-topic-slug>.<ext>
```