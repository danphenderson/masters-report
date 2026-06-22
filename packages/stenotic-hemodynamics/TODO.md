Comprehensive Audit Report: packages/stenotic-hemodynamics

1. Executive Summary

This audit synthesizes two independent agent handbacks reviewing the Julia package located at:

packages/stenotic-hemodynamics/

The combined conclusion is that StenoticHemodynamics is a credible, idiomatic Julia research package for reduced one-dimensional stenotic-hemodynamics experiments, numerical verification, validation-oriented auxiliary workflows, and comparison against externally generated resolved-3D data. The package is not merely a small solver library: it owns a broad research-computation surface, including reduced 1D forward simulation, finite-volume and DG discretizations, native and SciML-compatible time integration, Gridap-based stationary-Stokes support, reduced membrane-FSI validation workflows, OpenBF-style configuration adaptation, resolved-3D XDMF/HDF5 import and comparison tools, benchmarking, CLI orchestration, and report-asset generation.

The README is mostly accurate, but its language should be tightened. In particular, it should not imply that the package performs full transient resolved 3D CFD simulations. The primary production forward model is a reduced 1D area-flow hemodynamics model. The resolved-3D functionality appears to be an import, comparison, and post-processing workflow for externally generated data, not a native 3D CFD solver. The README should also distinguish more carefully between stationary-Stokes finite-element support and the actual implemented projection used to initialize the 1D state. One agent reported that solve_stationary_stokes builds and solves the Gridap problem, while project_stationary_stokes currently uses an analytic resistance/pressure-law projection into (A,Q) rather than directly projecting the finite-element solution object. If accurate, that distinction should be documented explicitly.

The codebase has strong architectural foundations: typed configuration, multiple dispatch, explicit method/backend protocols, public API discipline, verification workflows, reproducible command surfaces, and research-oriented output generation. Its main risks are scope concentration, heavy dependencies in the core package, large multi-responsibility files, Float64 specialization, a large hand-rolled CLI, and several documentation phrases that could overstate the physical or CFD scope of the package.

⸻

2. Audit Basis

The merged audit is based on two independent agent handbacks that reported inspection of:

* the package source tree;
* the package README;
* the CLI implementation;
* tests;
* package entrypoints;
* numerical method definitions;
* backend definitions;
* adapters and workflows;
* resolved-3D comparison code;
* benchmark and verification surfaces.

Both agents reported running:

pipenv run ops-julia-check

and both reported successful completion.

This merged report does not independently re-run the code. It consolidates, critiques, and deduplicates the two supplied findings.

⸻

3. README Accuracy Verdict

3.1 Overall Verdict

The README is mostly accurate, but it needs sharper scope calibration.

It correctly presents the package as a report-facing Julia codebase for reduced stenotic-hemodynamics simulations and supporting research workflows. The implementation reportedly supports:

* a reduced 1D conservative area-flow state;
* finite-volume methods;
* DG methods;
* native time integration;
* SciML/OrdinaryDiffEq backend support for compatible methods;
* Gridap stationary-Stokes support;
* reduced membrane-FSI validation workflows;
* OpenBF-style adaptation;
* resolved-3D XDMF/HDF5 comparison tooling;
* verification studies;
* benchmark workflows;
* report-asset export.

However, the README should be revised wherever it can be read as saying that the package itself performs full transient resolved 3D CFD simulation. The package’s primary forward simulations are reduced 1D hemodynamics. Resolved-3D data appear to be externally generated and then imported for comparison.

3.2 Primary Documentation Risk

The phrase “CFD simulations” is too broad if used without qualification.

A committee member, reviewer, or future contributor could reasonably misread the package as a native 3D CFD solver. The documentation should instead distinguish four computational surfaces:

1. Primary reduced model:
    reduced 1D stenotic-vessel area-flow hemodynamics.
2. Auxiliary stationary-Stokes workflow:
    Gridap-based finite-element construction/solution used in initialization or validation-adjacent workflows.
3. Reduced membrane-FSI workflow:
    validation-oriented membrane/radial mechanics workflow, separate from the default production forward model.
4. Resolved-3D comparison workflow:
    import, sectioning, comparison, and asset generation from externally generated XDMF/HDF5 velocity data.

3.3 Stationary-Stokes Wording Caveat

One agent identified a specific implementation-fidelity issue:

* solve_stationary_stokes reportedly builds and solves the Gridap stationary-Stokes problem.
* project_stationary_stokes reportedly does not directly use the finite-element solution object to produce the 1D projected state.
* Instead, it appears to use an analytic resistance/pressure-law projection into (A,Q).

If this report is correct, then README language should avoid saying or implying that the FE Stokes solution is directly projected into the 1D state. A more precise formulation would be:

The package includes Gridap-based stationary-Stokes routines for auxiliary finite-element initialization and validation workflows. The current 1D projected initial state is produced through the implemented analytic resistance/pressure-law projection into `(A,Q)`, rather than a direct projection of the finite-element velocity field.

3.4 Recommended README Scope Statement

Suggested replacement language:

`StenoticHemodynamics` is a Julia research package for reduced one-dimensional stenotic-vessel hemodynamics, numerical verification, validation-oriented auxiliary workflows, and comparison against externally generated resolved-3D data.
The primary forward simulations evolve a reduced conservative area-flow state. The package also includes Gridap-based stationary-Stokes workflows, reduced membrane-FSI validation examples, OpenBF-style configuration adaptation, resolved-3D XDMF/HDF5 import and comparison tools, benchmark workflows, and report-asset writers. It does not generate the resolved 3D CFD datasets used for comparison.

⸻

4. Three-Paragraph Codebase Summary

StenoticHemodynamics is a typed Julia research package centered on reduced one-dimensional stenotic-artery hemodynamics. Its primary conservative state is an area-flow pair, usually represented as (A,Q), with model behavior assembled through typed closures and configuration objects. The central configuration object, Params, reportedly carries geometry, rheology, spatial method, time stepper, initial condition, boundary conditions, wall law, forward model, forcing, and related run options. The default scientific use case is a Canic-derived reduced 1D model over a smooth idealized stenosis, with Newtonian rheology, wall-law closure, and finite-volume-style numerical evolution.

The numerical layer is organized through Julia multiple dispatch rather than object-oriented inheritance. Spatial methods, time steppers, and backend choices are exposed as typed protocols. Reported methods include first-order finite volume, MUSCL reconstruction, WENO3, Lax-Wendroff, and modal Legendre DG up to degree four. Native explicit steppers include Euler and SSPRK-family methods, while compatible semi-discrete systems can be routed through SciML/OrdinaryDiffEq. Some methods are intentionally native-only, especially where fixed-timestep or modal-solver constraints prevent a generic SciML backend from being appropriate.

Around the solver core, the package owns a broad research-workflow layer. It includes Gridap stationary-Stokes support, reduced membrane-FSI validation, OpenBF-style YAML adaptation, resolved-3D XDMF/HDF5 loading and comparison, manufactured-solution verification, rest-state drift checks, grid/refinement studies, benchmark profiles, geometry export, CSV/SVG/TeX/report-asset generation, and a command-line interface that dispatches these workflows. In practice, the package is not just a solver library; it is the repository’s scientific computation, validation, comparison, and artifact-generation package.

⸻

5. Design Patterns and Architectural Idioms

The codebase reportedly uses the following design patterns and architectural idioms.

5.1 Layered Architecture

The package is organized around distinct conceptual layers:

* core model definitions;
* numerical methods;
* state and cache management;
* I/O;
* adapters;
* workflows;
* CLI.

This separation is a significant strength, though the actual package boundary is still broad.

5.2 Strategy Pattern via Multiple Dispatch

Julia multiple dispatch provides strategy-like behavior for:

* spatial methods;
* time steppers;
* time-integration backends;
* rheology closures;
* velocity profiles;
* wall laws;
* forward models;
* forcing terms;
* boundary conditions;
* initial conditions.

This is idiomatic Julia and appropriate for a numerical-methods research package.

5.3 Adapter Pattern

Adapters translate external ecosystems or file formats into package-native representations. Reported adapter surfaces include:

* SciML/OrdinaryDiffEq;
* Gridap stationary-Stokes workflows;
* OpenBF-style YAML;
* resolved-3D XDMF/HDF5 inputs;
* membrane-FSI validation workflows.

5.4 Factory and Parser Patterns

CLI tokens and user-facing configuration strings are reportedly converted into typed Julia objects through constructors and parser/factory functions such as:

* forward-model constructors;
* algorithm-policy constructors;
* rheology constructors;
* CLI option parsers.

This helps keep command-line inputs decoupled from internal typed protocols.

5.5 Command Pattern

The CLI dispatches named workflows such as:

* simulate;
* study;
* verify;
* compare-3d;
* benchmark;
* export and report-asset commands.

Each command represents an executable workflow.

5.6 Facade Pattern

Top-level entrypoints such as simulate(params, backend) provide a narrow public surface over a larger implementation. This is valuable for reproducibility and reviewer-facing scripts.

5.7 Spec/Result DTO Pattern

Several workflows appear to use explicit specification objects and result objects. This is useful for reproducibility, testing, artifact generation, and avoiding unstructured keyword sprawl.

5.8 Trait or Capability Dispatch

The code reportedly uses backend/method capability checks such as:

* whether a method supports a backend;
* whether a method requires fixed timesteps;
* whether a method requires a native modal solver.

This is an important idiom for managing method/backend compatibility without overloading the public API with ad hoc conditionals.

5.9 Null Object Pattern

Objects such as NoForcing or simple rest-state initial conditions function as null objects. This is appropriate for avoiding special-case logic in solver kernels.

5.10 Cache-Object Pattern

Explicit RHS and step caches are used in performance-sensitive numerical paths. This is appropriate for Julia numerical code, especially when avoiding repeated allocation matters.

5.11 Template-Method-Style Workflow Protocol

Workflow-level functions such as validation, output-path selection, and workflow-kind identification appear to provide a common protocol for different research workflows.

⸻

6. Strengths

6.1 Idiomatic Julia Extension Model

The package uses typed configuration and multiple dispatch in a way that fits Julia’s strengths. Major scientific and numerical choices are represented as explicit typed strategies rather than hidden flags.

6.2 Clear Numerical-Method Surface

The codebase reportedly supports multiple spatial methods and time steppers while tracking compatibility constraints between methods and backends. This is especially important for a report package comparing numerical behavior.

6.3 Strong Verification Orientation

Verification is a first-class concern. The package reportedly includes:

* manufactured-solution tests;
* rest-state drift checks;
* backend parity checks;
* operator validation;
* grid/refinement studies;
* resolved-3D comparison workflows;
* benchmark workflows.

This is a major strength for a mathematical report.

6.4 Public API Discipline

One agent reported that tests guard exported names and distinguish public API from qualified-internal names. This is valuable for maintaining a stable reviewer-facing and report-facing interface.

6.5 Reproducibility Posture

The package appears to support reproducible workflows through:

* deterministic specs;
* manifest-controlled environments;
* CLI command surfaces;
* output guards;
* scratch-output defaults;
* report-asset generation;
* benchmark profiles.

This is appropriate for a master’s report repository where committee members may inspect or rerun selected computations.

6.6 Honest Limitation Language

Both agents found that the README is generally honest about limitations and does not broadly overclaim clinical validation. This is important. The package should continue to separate:

* model specification;
* numerical verification;
* comparison to external resolved simulations;
* physical validation;
* clinical validation.

6.7 Fail-Closed Optional Data Workflows

The resolved-3D workflows reportedly skip or fail cleanly when local data are absent. That is good repository hygiene because large or proprietary resolved datasets may not always be present.

⸻

7. Weaknesses and Risks

7.1 Package Boundary Is Too Wide

The largest architectural issue is scope concentration.

The package contains:

* solver kernels;
* numerical methods;
* SciML integration;
* Gridap workflows;
* OpenBF adaptation;
* resolved-3D I/O and comparison;
* membrane-FSI validation;
* benchmarking;
* report-asset generation;
* CLI orchestration.

This makes the package powerful, but it also raises review, testing, and maintenance costs. Future contributors may struggle to distinguish the stable solver API from report-specific workflows.

7.2 Optional Dependency Boundary Is Incomplete

Both agents reported that dependencies such as Gridap, HDF5, OrdinaryDiffEq, and YAML are hard dependencies rather than isolated extension surfaces.

This weakens modularity. A user who only wants the reduced 1D solver may still inherit dependencies needed only for:

* Gridap stationary-Stokes workflows;
* resolved-3D HDF5/XDMF comparison;
* SciML backend integration;
* OpenBF YAML adaptation.

Long-term, these should be moved behind Julia package extensions, weak dependencies, or subpackage boundaries if maintenance scope justifies it.

7.3 Large Multi-Responsibility Files

The agents identified large files such as:

* CLI implementation;
* verification implementation;
* benchmark implementation;
* resolved-3D output/comparison implementation;
* solver implementation.

Large files are not automatically wrong, but they are a maintenance risk when they combine parsing, validation, computation, output formatting, and report-specific concerns.

7.4 CLI Is Too Heavy

The CLI is useful and reviewer-facing, but it appears to have become a large hand-rolled orchestration surface. This conflicts with the ideal that the CLI remain thin over typed workflow specs.

The preferred direction is:

CLI parser -> typed spec -> validated workflow -> result object -> output writer

The CLI should not own scientific logic, validation logic, or artifact-formatting logic beyond command routing and argument parsing.

7.5 Params May Be Over-Concentrated

Params reportedly carries physical case definitions, numerical discretization, solver configuration, closures, boundary data, forcing, and run defaults. This is convenient, but it may become too monolithic.

A possible future split is:

PhysicalModelSpec
GeometrySpec
BoundarySpec
DiscretizationSpec
TimeIntegrationSpec
InitialConditionSpec
RunSpec

This should not be done prematurely, but it is a reasonable refactor target if Params becomes difficult to test or document.

7.6 Heavy Float64 Specialization

The core paths are reportedly specialized to Float64.

This may be acceptable for the current report, but it limits future support for:

* arbitrary precision experiments;
* automatic differentiation;
* unitful computation;
* GPU-oriented kernels;
* uncertainty propagation;
* alternative scalar types.

For the master’s report, this is probably a documented limitation rather than a blocker. For a long-term numerical package, it is a real design constraint.

7.7 Stationary-Stokes Projection Documentation Mismatch

The README should be reconciled with the actual implementation of Stokes-based initialization. If the finite-element Stokes solution is solved but not directly projected into the 1D state, the documentation must say so.

This is not necessarily a code defect. It is primarily a claim-calibration issue unless the intended algorithm was direct FE-to-1D projection.

7.8 Resolved-3D Parsing Fragility

One agent flagged XDMF parsing as format-specific and possibly regex-dependent. If the resolved-3D datasets all come from one known pipeline, this may be acceptable. If the workflow is intended to support broader XDMF variants, the parser should be hardened or its accepted dialect documented.

7.9 Potential Overlap Between Validation and Demonstration

The package appears to include validation-adjacent workflows, but the manuscript and README should avoid overstating validation. Imported resolved-3D comparisons, stationary Stokes tests, membrane-FSI examples, MMS, and rest-state checks are valuable evidence, but they do not constitute clinical validation.

⸻

8. Prioritized Findings

Priority 0: Immediate Documentation Corrections

These should be addressed before committee submission or public release.

1. Clarify that the primary forward model is reduced 1D hemodynamics.
2. Clarify that resolved-3D workflows import and compare externally generated data.
3. Clarify the difference between stationary-Stokes solve support and the actual 1D projection used.
4. Remove or qualify any language implying full native transient 3D CFD simulation.
5. Add a short “What this package does not do” section.

Priority 1: Architectural Hygiene

These are important but do not need to block report submission.

1. Thin the CLI by moving scientific logic into typed workflow modules.
2. Split large files by responsibility.
3. Create a workflow-spec/result pattern consistently across commands.
4. Document the stable public API versus report-internal workflow API.

Priority 2: Dependency and Extension Refactor

These are medium-term improvements.

1. Move Gridap support behind an extension or optional workflow boundary.
2. Move HDF5/XDMF resolved-3D support behind an extension or optional workflow boundary.
3. Move YAML/OpenBF support behind an adapter extension if possible.
4. Keep the reduced 1D solver installable with a smaller dependency footprint.

Priority 3: Long-Term Numerical Generality

These are not required for the master’s report unless the manuscript claims such generality.

1. Audit Float64 assumptions.
2. Identify which kernels could become scalar-type generic.
3. Add tests for a non-Float64 scalar type where feasible.
4. Document remaining type restrictions explicitly.

⸻

9. Recommended README Patch Plan

9.1 Add a Scope Section

Add near the top of the README:

## Scope
This package primarily performs reduced one-dimensional stenotic-vessel hemodynamics simulations. It evolves a conservative area-flow state and provides finite-volume, DG, native time-stepping, and selected SciML-compatible workflows.
The package also includes auxiliary research workflows for stationary-Stokes initialization, reduced membrane-FSI validation examples, OpenBF-style configuration adaptation, resolved-3D data import/comparison, benchmark studies, and report-asset generation.
It does not generate the resolved 3D CFD datasets used for comparison. Resolved-3D workflows load externally generated XDMF/HDF5 data and compare derived observables against reduced-model outputs.

9.2 Add a Model/Evidence Boundary Section

## Evidence Boundary
The package supports model construction, numerical verification, backend comparison, and comparison against selected externally generated resolved-3D data. These workflows do not by themselves establish physical or clinical validation. Reported quantities should be interpreted relative to the model assumptions, boundary data, geometry, numerical method, and observation operator used to produce them.

9.3 Clarify Stokes Initialization

## Stationary-Stokes Support
The package includes Gridap-based routines for constructing and solving auxiliary stationary-Stokes problems. The current reduced 1D initialization workflow should be interpreted according to the implemented projection map. If the active projection uses an analytic resistance/pressure-law map into `(A,Q)` rather than directly projecting the finite-element velocity field, that distinction is part of the model specification.

9.4 Add a “Does Not Do” Section

## Non-Goals
This package does not currently provide:
- a general-purpose 3D CFD solver;
- native generation of the resolved-3D datasets used for comparison;
- clinical validation of stenosis severity metrics;
- generic support for arbitrary scalar types across all numerical kernels;
- a minimal-dependency install path for only the reduced 1D solver.

⸻

10. Suggested Harnessed Agentic Workflow

The following workflow is designed to address the merged audit findings while preserving repository stability and report-readiness.

10.1 Workflow Objective

Revise packages/stenotic-hemodynamics documentation and code organization so that:

1. README claims exactly match implemented behavior.
2. Reduced 1D, stationary-Stokes, membrane-FSI, and resolved-3D workflows are clearly separated.
3. CLI and workflow boundaries become easier to audit.
4. Optional-heavy dependencies are documented and prepared for future modularization.
5. The package remains passing under the existing repository check command.

10.2 Workflow Rules

Each agent must obey the following constraints:

* Do not change numerical algorithms unless explicitly assigned.
* Do not change report results, generated assets, or benchmark baselines unless explicitly assigned.
* Do not rewrite broad files opportunistically.
* Preserve public CLI commands unless a command is demonstrably broken.
* Prefer small, reviewable patches.
* Every patch must end with:

pipenv run ops-julia-check

* If a full check is too expensive in a local context, the agent must at least run the closest package-specific Julia tests and report the limitation.

⸻

11. Harnessed Agent Roles

Agent A: Documentation Fidelity Agent

Objective

Patch the README so that it accurately reflects the codebase and avoids overclaiming CFD scope.

Inputs

* packages/stenotic-hemodynamics/README.md
* packages/stenotic-hemodynamics/src/StenoticHemodynamics.jl
* packages/stenotic-hemodynamics/src/StenoticHemodynamics/cli/cli.jl
* packages/stenotic-hemodynamics/src/StenoticHemodynamics/adapters/stokes_ic.jl
* packages/stenotic-hemodynamics/src/StenoticHemodynamics/adapters/membrane_fsi.jl
* packages/stenotic-hemodynamics/src/StenoticHemodynamics/workflows/resolved3d_*
* package tests

Tasks

1. Identify every README phrase that could imply native full 3D CFD simulation.
2. Replace those phrases with reduced-model and comparison-workflow language.
3. Add or revise sections for:
    * package scope;
    * computational modes;
    * evidence boundary;
    * non-goals;
    * stationary-Stokes projection caveat;
    * resolved-3D import/comparison caveat.
4. Ensure terminology is consistent:
    * “reduced 1D hemodynamics”;
    * “externally generated resolved-3D data”;
    * “comparison workflow”;
    * “validation-oriented” rather than “validated” unless evidence supports stronger language.
5. Run checks.

Deliverable

A patch to README plus a short handback containing:

* changed sections;
* claims tightened;
* any unresolved implementation/documentation ambiguities;
* check results.

⸻

Agent B: Stokes Projection Truth Audit Agent

Objective

Determine the exact relationship between the Gridap stationary-Stokes solve and the projected 1D initial state.

Inputs

* adapters/stokes_ic.jl
* related tests;
* any CLI command invoking stationary-Stokes initialization;
* README sections mentioning Stokes initialization.

Tasks

1. Trace the call graph:
    * Stokes problem construction;
    * Stokes solve;
    * projection into 1D state;
    * use in Params or simulation setup.
2. Determine whether the FE solution object contributes to the final (A,Q) state.
3. Classify the implementation as one of:
    * direct FE-to-1D projection;
    * analytic projection after FE solve;
    * hybrid;
    * currently dead/unused FE solve path.
4. Add or update a focused test if behavior is not currently tested.
5. Recommend exact README wording.
6. Do not change the algorithm unless there is an obvious bug and the fix is minimal.

Deliverable

A short technical note plus any minimal test/documentation patch needed.

⸻

Agent C: CLI Boundary Agent

Objective

Reduce CLI maintenance risk without changing public commands.

Inputs

* cli/cli.jl
* workflow modules;
* tests covering CLI commands.

Tasks

1. Inventory CLI responsibilities:
    * argument parsing;
    * validation;
    * spec construction;
    * scientific computation;
    * output writing;
    * report-asset formatting.
2. Identify logic that should move out of CLI into workflow modules.
3. Make only low-risk extractions, such as:
    * parser helper extraction;
    * spec construction helper extraction;
    * output path helper extraction.
4. Do not rename public commands.
5. Do not change CLI output format unless tests require it.
6. Add tests only for extracted behavior if needed.

Deliverable

A patch that makes the CLI thinner, or a no-code refactor plan if safe extraction is too large for one pass.

⸻

Agent D: Dependency Boundary Agent

Objective

Assess and document the dependency-boundary problem; optionally prepare a future extension split.

Inputs

* Project.toml
* package imports;
* adapter modules;
* workflow modules;
* tests.

Tasks

1. List hard dependencies and the modules that require them.
2. Classify dependencies by surface:
    * core reduced solver;
    * SciML backend;
    * Gridap stationary-Stokes;
    * HDF5/XDMF resolved-3D;
    * YAML/OpenBF;
    * plotting/export/report assets.
3. Determine whether a minimal reduced-solver dependency profile is possible.
4. Do not perform a large extension split unless explicitly authorized.
5. Add README/developer-doc notes explaining current dependency scope.

Deliverable

A dependency-boundary report, optionally with documentation patches.

⸻

Agent E: Large-File Responsibility Agent

Objective

Produce a safe decomposition plan for large source files.

Inputs

* source tree;
* file sizes;
* module includes;
* tests.

Tasks

1. Identify the largest source files.
2. For each large file, classify responsibilities.
3. Recommend split points that preserve API behavior.
4. Avoid large code movement unless trivial and low-risk.
5. Identify test coverage needed before splitting.

Deliverable

A refactor plan with file-by-file proposed destination modules.

⸻

Agent F: Final Integration Agent

Objective

Review all patches and ensure the package remains coherent.

Tasks

1. Review the combined diff.
2. Check for terminology consistency across README, docs, CLI help, and tests.
3. Run:

pipenv run ops-julia-check

4. Inspect generated documentation/help output if relevant.
5. Produce a final handback.

Deliverable

Final integration report containing:

* summary of changes;
* remaining risks;
* check results;
* whether the repository is ready for committee-facing use.

⸻

12. Suggested Dispatch Prompts

12.1 Documentation Fidelity Dispatch

You are the Documentation Fidelity Agent for `packages/stenotic-hemodynamics`.
Objective:
Patch the package README so that every claim accurately reflects the implemented codebase.
Primary concerns:
- The package should not be described as a native full transient 3D CFD solver.
- The primary forward model is reduced one-dimensional stenotic-vessel hemodynamics.
- Resolved-3D workflows should be described as import/comparison/post-processing of externally generated XDMF/HDF5 data.
- Stationary-Stokes support must be described according to the implementation. Verify whether the FE solution is directly projected into `(A,Q)` or whether the current projection uses an analytic resistance/pressure-law map.
- Validation language must be calibrated: distinguish numerical verification, backend comparison, resolved-3D comparison, physical validation, and clinical validation.
Tasks:
1. Inspect `packages/stenotic-hemodynamics/README.md`.
2. Inspect the relevant source files for solver scope, CLI workflows, stationary-Stokes support, membrane-FSI support, and resolved-3D comparison.
3. Patch the README to add or revise:
   - Scope;
   - Computational modes;
   - Evidence boundary;
   - Stationary-Stokes caveat;
   - Resolved-3D comparison caveat;
   - Non-goals.
4. Preserve concise academic/technical tone.
5. Do not change numerical code.
6. Run `pipenv run ops-julia-check`.
Return:
- summary of README changes;
- exact claims tightened;
- unresolved ambiguities;
- check result.

12.2 Stokes Projection Truth Audit Dispatch

You are the Stokes Projection Truth Audit Agent for `packages/stenotic-hemodynamics`.
Objective:
Determine exactly how the Gridap stationary-Stokes workflow contributes to the reduced 1D initial state.
Tasks:
1. Trace the implementation in `src/StenoticHemodynamics/adapters/stokes_ic.jl`.
2. Identify the call graph from Stokes problem construction to the final `(A,Q)` initial condition.
3. Determine whether `project_stationary_stokes` uses the finite-element Stokes solution object directly.
4. Classify the implementation as:
   - direct FE-to-1D projection;
   - analytic projection after FE solve;
   - hybrid;
   - unused/dead FE solve path.
5. Add or update a focused test if the behavior is not covered and the test is low-risk.
6. Recommend exact README wording.
7. Do not change the algorithm unless there is an obvious implementation bug.
Run:
`pipenv run ops-julia-check`
Return:
- implementation finding;
- source locations;
- any patch made;
- recommended README wording;
- check result.

12.3 Architecture Boundary Dispatch

You are the Architecture Boundary Agent for `packages/stenotic-hemodynamics`.
Objective:
Audit the package boundary, CLI thickness, large files, and dependency surface. Produce an implementation-ready refactor plan. Make only small, safe patches if they are obvious.
Tasks:
1. Inventory the package layers: core, numerics, adapters, workflows, I/O, CLI.
2. Identify large files and classify their responsibilities.
3. Identify logic currently in the CLI that belongs in typed workflow/spec/result modules.
4. Identify hard dependencies that are only needed by optional workflows.
5. Recommend a staged refactor plan:
   - immediate no-risk documentation/API boundary changes;
   - low-risk code extractions;
   - medium-term package-extension or weak-dependency split;
   - long-term scalar-type generalization.
6. Do not change public CLI commands.
7. Do not alter numerical algorithms.
8. Run `pipenv run ops-julia-check` if code is changed.
Return:
- package-boundary critique;
- large-file decomposition plan;
- dependency-boundary map;
- recommended next patches;
- check result if applicable.

⸻

13. Recommended Execution Order

Run the agents in this order:

1. Stokes Projection Truth Audit Agent
    Resolve the most concrete implementation/documentation ambiguity first.
2. Documentation Fidelity Agent
    Patch README using the Stokes audit result.
3. Architecture Boundary Agent
    Produce the broader refactor plan after the documentation is truthful.
4. CLI Boundary Agent
    Only if time remains before submission; otherwise defer.
5. Dependency Boundary Agent
    Defer unless packaging burden is actively harming users.
6. Final Integration Agent
    Review all changes, run checks, and produce final handback.

For committee-facing readiness, the minimum recommended sequence is:

Stokes Projection Truth Audit -> Documentation Fidelity -> Final Integration

⸻

14. Final Recommendation

The package appears strong enough to support the master’s report, provided the documentation is calibrated. The immediate goal should not be a broad refactor. The immediate goal should be truthful scope language:

* reduced 1D primary model;
* auxiliary stationary-Stokes workflows;
* reduced membrane-FSI validation examples;
* externally generated resolved-3D comparison data;
* numerical verification rather than clinical validation.

After that, the next engineering priority is to reduce maintenance risk by thinning the CLI, splitting large workflow files, and preparing optional-heavy dependencies for future extension boundaries.