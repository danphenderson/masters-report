const SCIMLBASE_UUID = Base.UUID("0bca4576-84f4-4d90-8ffe-ffa030f20462")
const ORDINARYDIFFEQ_UUID = Base.UUID("1dea7af3-3e70-54e6-95c3-0bf5283fa5ed")

function require_scimlbase()
    try
        return Base.require(Base.PkgId(SCIMLBASE_UUID, "SciMLBase"))
    catch err
        msg = "SciMLBase is required to construct an ODEProblem. Install or activate an environment with SciMLBase available."
        throw(ArgumentError(msg))
    end
end

function require_ordinarydiffeq()
    try
        return Base.require(Base.PkgId(ORDINARYDIFFEQ_UUID, "OrdinaryDiffEq"))
    catch err
        msg = "OrdinaryDiffEq is required for SciMLTimeBackend solves. Install or activate an environment with OrdinaryDiffEq available."
        throw(ArgumentError(msg))
    end
end

"""
    ode_problem(sim; u0=initial_condition(sim), tspan=(0.0, sim.params.tfinal))

Construct a SciML `ODEProblem` for the packed in-place RHS. SciML packages are
loaded lazily in this adapter file to keep model code SciML-free.
"""
function ode_problem(
    sim::SemiDiscreteSimulation;
    u0::AbstractVector{Float64} = initial_condition(sim),
    tspan = (0.0, sim.params.tfinal),
    kwargs...,
)
    assert_state_length(u0, sim.layout)
    SciMLBase = require_scimlbase()
    return Base.invokelatest(SciMLBase.ODEProblem, rhs!, copy(u0), tspan, sim; kwargs...)
end

function ode_problem(p::Params; kwargs...)
    sim = semidiscretize(p)
    return ode_problem(sim; kwargs...)
end

function sciml_algorithm(policy::AutoPolicy)
    OrdinaryDiffEq = require_ordinarydiffeq()
    stiff_alg = rodas5p_algorithm(OrdinaryDiffEq)
    return Base.invokelatest(OrdinaryDiffEq.AutoTsit5, stiff_alg)
end

function sciml_algorithm(policy::Tsit5Policy)
    OrdinaryDiffEq = require_ordinarydiffeq()
    return Base.invokelatest(OrdinaryDiffEq.Tsit5)
end

function sciml_algorithm(policy::Vern7Policy)
    OrdinaryDiffEq = require_ordinarydiffeq()
    return Base.invokelatest(OrdinaryDiffEq.Vern7)
end

function sciml_algorithm(policy::Vern9Policy)
    OrdinaryDiffEq = require_ordinarydiffeq()
    return Base.invokelatest(OrdinaryDiffEq.Vern9)
end

function sciml_algorithm(policy::Rodas5PPolicy)
    OrdinaryDiffEq = require_ordinarydiffeq()
    return rodas5p_algorithm(OrdinaryDiffEq)
end

function sciml_algorithm(policy::NativeSSPRKPolicy)
    throw(ArgumentError("algorithm '$(algorithm_name(policy))' is only available with the native backend"))
end

function rodas5p_algorithm(OrdinaryDiffEq)
    autodiff = Base.invokelatest(OrdinaryDiffEq.AutoFiniteDiff)
    return Base.invokelatest(OrdinaryDiffEq.Rodas5P; autodiff=autodiff)
end

function solve_ode_problem(prob, backend)
    SciMLBase = require_scimlbase()
    spec = validate(backend.solve)
    alg = sciml_algorithm(spec.algorithm)
    sol = Base.invokelatest(
        SciMLBase.solve,
        prob,
        alg;
        abstol=spec.abstol,
        reltol=spec.reltol,
        save_everystep=spec.save_everystep,
        maxiters=spec.maxiters,
    )

    if isdefined(SciMLBase, :successful_retcode) &&
       !Base.invokelatest(SciMLBase.successful_retcode, sol)
        error("SciML solve failed with retcode $(sol.retcode)")
    end

    return sol
end
