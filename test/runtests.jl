if VERSION < v"1.12"
    error(
        "test/runtests.jl requires Julia 1.12 or newer. " *
        "Run it with ./scripts/julia-release test/runtests.jl.",
    )
end

using Test
using Distributed
using HDF5
using LinearAlgebra
using Statistics
using StenosisHemodynamics

include("test_helpers.jl")
include("test_public_api.jl")
include("test_io_writers.jl")
include("test_extension_contracts.jl")
include("test_parallel.jl")
include("test_core_model.jl")
include("test_openbf_stokes.jl")
include("test_backends.jl")
include("test_resolved3d_geometry.jl")
include("test_operator_validation.jl")
include("test_cli_studies.jl")
include("test_package_benchmark.jl")
include("test_verification.jl")
