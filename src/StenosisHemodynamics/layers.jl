"""
    AbstractArchitectureLayer

Internal documentation marker for the package architecture layers.

Layer marker types do not participate in runtime dispatch. They exist so the
layer contracts are available to Julia's help system and future generated API
documentation.
"""
abstract type AbstractArchitectureLayer end

"""
    CoreLayer

Owns physical parameters, geometry, boundary descriptions, model closures,
initial-condition descriptors, result data, and diagnostic summaries.

The core layer must remain free of workflow orchestration, CLI parsing, report
publication, and heavyweight optional integrations such as Gridap, HDF5, YAML,
or SciML solve adapters. Code in this layer should favor immutable configuration
objects and small dispatch protocols over process-level state.
"""
struct CoreLayer <: AbstractArchitectureLayer end

"""
    NumericsLayer

Owns spatial methods, semidiscrete state layout, finite-volume and DG kernels,
time-stepping policies, backend dispatch, and solver result contracts.

The numerics layer may allocate per-solve caches and mutate those caches inside
well-documented function barriers. It should not parse experiment
configuration, write publication assets, or know about external resolved-3D
data formats.
"""
struct NumericsLayer <: AbstractArchitectureLayer end

"""
    IOLayer

Owns file-output guards, table serialization, manifest serialization, checksums,
and schema helpers shared by workflows.

The I/O layer is the only place new workflow code should add CSV, JSON, or
manifest writing behavior. Callers should pass typed rows or simple tables and
let this layer own escaping, overwrite policy, and hash generation.
"""
struct IOLayer <: AbstractArchitectureLayer end

"""
    AdapterLayer

Owns integrations with external formats and optional numerical ecosystems.

Adapter files translate package-native specs into external inputs or outputs:
SciML problems, OpenBF-style YAML, Gridap stationary-Stokes initialization, and
resolved-3D XDMF/HDF5 loading. Long-term, these files are candidates for Julia
package extensions or weak-dependency modules.
"""
struct AdapterLayer <: AbstractArchitectureLayer end

"""
    WorkflowsLayer

Owns reproducible research workflows built from the core, numerics, adapter,
and I/O layers.

Workflow modules expose typed `Spec` and `Result` objects plus `run_*` and
`write_*` functions. They may schedule cases, compare outputs, and publish
derived artifacts, but they should not parse command-line arguments directly.
"""
struct WorkflowsLayer <: AbstractArchitectureLayer end

"""
    CLILayer

Owns command-line parsing and console-oriented command dispatch.

The CLI layer should remain thin: parse flags or config files into typed specs,
call workflow or simulation APIs, and print human-readable output locations. It
must not own solver logic, publication semantics, or destructive cleanup policy.
"""
struct CLILayer <: AbstractArchitectureLayer end
