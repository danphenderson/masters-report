abstract type AbstractAlgorithmPolicy end

"""SciML automatic nonstiff/stiff switching policy."""
struct AutoPolicy <: AbstractAlgorithmPolicy end

"""SciML Tsitouras 5/4 explicit Runge-Kutta policy."""
struct Tsit5Policy <: AbstractAlgorithmPolicy end

"""SciML Rodas5P stiff policy with finite-difference Jacobians."""
struct Rodas5PPolicy <: AbstractAlgorithmPolicy end

"""
Native fixed-step SSP RK3 policy.

The current finite-volume solver uses a third-order strong-stability-preserving
Runge-Kutta stepper. This is the fixed-step RK/SSP policy for the native backend.
"""
struct NativeSSPRKPolicy <: AbstractAlgorithmPolicy end

"""
    SolveSpec(; algorithm, abstol, reltol, save_everystep, maxiters)

Solver-control options for time integration. `SolveSpec` is consumed by
`SciMLTimeBackend`; native fixed-step runs use `NativeRK3Backend()` and the
`Params.dt`/`Params.cfl` limits.
"""
Base.@kwdef struct SolveSpec
    algorithm::AbstractAlgorithmPolicy = AutoPolicy()
    abstol::Float64 = 1.0e-6
    reltol::Float64 = 1.0e-6
    save_everystep::Bool = false
    maxiters::Int = 1_000_000
end

algorithm_name(::AutoPolicy) = "auto"
algorithm_name(::Tsit5Policy) = "tsit5"
algorithm_name(::Rodas5PPolicy) = "rodas5p"
algorithm_name(::NativeSSPRKPolicy) = "ssprk"

function algorithm_policy(name::AbstractString)
    normalized = lowercase(strip(name))
    if normalized == "auto"
        return AutoPolicy()
    elseif normalized == "tsit5"
        return Tsit5Policy()
    elseif normalized == "rodas5p"
        return Rodas5PPolicy()
    elseif normalized in ("ssprk", "rk3", "native-rk3", "native_ssprk")
        return NativeSSPRKPolicy()
    end

    throw(ArgumentError("unknown algorithm '$name'; expected auto, tsit5, rodas5p, or ssprk"))
end

function validate(spec::SolveSpec)
    spec.abstol > 0.0 || throw(ArgumentError("abstol must be positive"))
    spec.reltol > 0.0 || throw(ArgumentError("reltol must be positive"))
    spec.maxiters > 0 || throw(ArgumentError("maxiters must be positive"))
    return spec
end
