# Canonical Research-Question Answers

Source status: author-approved editorial control for the harnessed rewrite.

## RQ1

What continuous model, solver-coordinate map, closure choices, boundary approximation, and discrete operator define the implemented 1D stenosis solver?

Answer: The implemented solver is an `R_max`-normalized Canic-derived 1D area-flow model in solver coordinates `a = R^2` and `q = Qphys / pi`, with `Aphys = pi*a`, `Qphys = pi*q`, and mean velocity `q/a`. The principal comparison realization is the `canic-extended-1d` member using the parabolic velocity-profile closure, Newtonian rheology, fixed-area characteristic boundary approximation, MUSCL finite volume, minmod-limited states, Rusanov flux, source splitting, and native SSPRK3.

## RQ2

Does the implementation converge on a smooth manufactured solution and preserve the geometry-rest equilibrium?

Answer: The manufactured-solution record is positive but bounded implementation-verification evidence for the declared forced operator. The current MUSCL/Rusanov realization does not preserve the geometry-rest equilibrium. The corrected zero-inlet rest rerun removes the earlier production-inlet fingerprint and records localized nonzero artificial rest flow; the retained production-grid and audit-grid values are below the comparison-flow scale, while the full grid records larger coarse-grid transients.

## RQ3

Under the declared plane-quadrature operator, what velocity discrepancies are measured against the available resolved 3D data, and which unmatched conditions limit interpretation?

Answer: The declared plane-tetrahedron quadrature operator defines a common section velocity and physical-flow observable for the available C23/C40 resolved 3D velocity data. The reported section differences are descriptive cross-model discrepancies, not validation or accuracy estimates. Radial-profile outputs are quarantined because direct recomputation from the tracked radial data has not been reconciled with the existing summary values, so no radial discrepancy claim is retained. Interpretation is limited by unmatched or unpersisted 3D wall, boundary, material, history, and current/deformed geometry information, by unresolved axial variation in extracted 3D flow, and by the `1.0 s` versus `0.9995 s` sample-time offset unless exact-time evidence is added.

## Contribution Boundary

The contribution is an authoritative implemented-model specification, bounded MMS-based verification evidence, exposure of a material rest-equilibrium failure, a declared 1D-3D velocity observation operator, and descriptive C23/C40 discrepancy localization.

The manuscript must not broaden this into validation, pressure-accuracy, FFR, physiological, clinical, predictive, or causal claims.
