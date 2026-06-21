const AREA_FLOOR = 1.0e-12
const AREA_LIMITER_FLOOR = 1.0e-10

"""
    Params(; kwargs...)

Physical case and finite-volume grid parameters for one Canic extended 1D
stenosis run. Units follow the paper and upstream MATLAB code: cm, g, s, dyn.
`nu` remains the baseline Newtonian kinematic viscosity; non-Newtonian closures
compute an effective kinematic viscosity from `rheology`. `velocity_profile`
owns the momentum-flux correction; `alpha` is retained as the derived
compatibility field.

Spatial and native time-stepping choices belong to the case because refinement
studies compare them. SciML solver options belong in `SolveSpec`; output paths
belong in `OutputSpec`.
"""
struct Params{
    R<:AbstractRheology,
    S<:AbstractSpatialMethod,
    T<:AbstractNativeTimeStepper,
    I<:AbstractInitialConditionSpec,
    P<:AbstractVelocityProfile,
    M<:AbstractForwardModel,
    B<:AbstractInletBoundary,
    O<:AbstractOutletBoundary,
    W<:AbstractWallLaw,
    F<:AbstractForcingTerm,
}
    nx::Int
    length_cm::Float64
    tfinal::Float64
    dt::Float64
    cfl::Float64
    severity::Float64
    rmax::Float64
    rho::Float64
    nu::Float64
    rheology::R
    space::S
    time_stepper::T
    initial_condition::I
    velocity_profile::P
    model::M
    inlet_boundary::B
    outlet_boundary::O
    wall_law::W
    forcing::F
    young::Float64
    wall_h::Float64
    sigma::Float64
    alpha::Float64
    inlet_umax::Float64
end

function resolve_velocity_profile(
    velocity_profile::Union{Nothing,AbstractVelocityProfile},
    alpha::Union{Nothing,Real},
)
    if velocity_profile !== nothing && alpha !== nothing
        throw(ArgumentError("provide velocity_profile or alpha, not both"))
    elseif velocity_profile !== nothing
        return velocity_profile
    elseif alpha !== nothing
        return PowerVelocityProfile(alpha=alpha)
    end
    return ParabolicVelocityProfile()
end

function Params(;
    nx = 400,
    length_cm = 6.0,
    tfinal = 1.0,
    dt = 1.0e-5,
    cfl = 0.45,
    severity = 50.0,
    rmax = 0.18,
    rho = 1.055,
    nu = 0.04,
    rheology = NewtonianRheology(),
    space = FVMUSCLMethod(),
    time_stepper = SSPRK3Stepper(),
    initial_condition = StationaryStokesIC(),
    velocity_profile::Union{Nothing,AbstractVelocityProfile} = nothing,
    model::Union{AbstractString,AbstractForwardModel} = CanicExtendedOneDModel(),
    inlet_boundary::Union{Nothing,AbstractInletBoundary} = nothing,
    outlet_boundary::AbstractOutletBoundary = FixedAreaCharacteristicOutlet(),
    wall_law::AbstractWallLaw = CanicKoiterWallLaw(),
    forcing::AbstractForcingTerm = NoForcing(),
    young = 5.02e6,
    wall_h = 0.06,
    sigma = 0.5,
    alpha::Union{Nothing,Real} = nothing,
    inlet_umax = 45.0,
)
    profile = resolve_velocity_profile(velocity_profile, alpha)
    resolved_model = model isa AbstractString ? forward_model(model) : model
    alpha_value = momentum_alpha(profile)
    resolved_inlet = inlet_boundary === nothing ? SteadyVelocityInlet(umax=inlet_umax) : inlet_boundary
    inlet_umax_value = resolved_inlet isa SteadyVelocityInlet ? resolved_inlet.umax : Float64(inlet_umax)
    rheology isa AbstractRheology || throw(ArgumentError("rheology must be an AbstractRheology"))
    space isa AbstractSpatialMethod || throw(ArgumentError("space must be an AbstractSpatialMethod"))
    time_stepper isa AbstractNativeTimeStepper || throw(ArgumentError("time_stepper must be an AbstractNativeTimeStepper"))
    initial_condition isa AbstractInitialConditionSpec || throw(ArgumentError("initial_condition must be an AbstractInitialConditionSpec"))
    resolved_model isa AbstractForwardModel || throw(ArgumentError("model must be an AbstractForwardModel"))
    validate_model_profile(resolved_model, profile)
    resolved_inlet isa AbstractInletBoundary || throw(ArgumentError("inlet_boundary must be an AbstractInletBoundary"))
    outlet_boundary isa AbstractOutletBoundary || throw(ArgumentError("outlet_boundary must be an AbstractOutletBoundary"))
    wall_law isa AbstractWallLaw || throw(ArgumentError("wall_law must be an AbstractWallLaw"))
    forcing isa AbstractForcingTerm || throw(ArgumentError("forcing must be an AbstractForcingTerm"))
    return Params{
        typeof(rheology),
        typeof(space),
        typeof(time_stepper),
        typeof(initial_condition),
        typeof(profile),
        typeof(resolved_model),
        typeof(resolved_inlet),
        typeof(outlet_boundary),
        typeof(wall_law),
        typeof(forcing),
    }(
        Int(nx),
        Float64(length_cm),
        Float64(tfinal),
        Float64(dt),
        Float64(cfl),
        Float64(severity),
        Float64(rmax),
        Float64(rho),
        Float64(nu),
        rheology,
        space,
        time_stepper,
        initial_condition,
        profile,
        resolved_model,
        resolved_inlet,
        outlet_boundary,
        wall_law,
        forcing,
        Float64(young),
        Float64(wall_h),
        Float64(sigma),
        Float64(alpha_value),
        Float64(inlet_umax_value),
    )
end

function Params(
    nx,
    length_cm,
    tfinal,
    dt,
    cfl,
    severity,
    rmax,
    rho,
    nu,
    rheology::R,
    space::S,
    time_stepper::T,
    initial_condition::I,
    young,
    wall_h,
    sigma,
    alpha,
    inlet_umax,
    wall_law = CanicKoiterWallLaw(),
    model = CanicExtendedOneDModel(),
    forcing = NoForcing(),
) where {R<:AbstractRheology,S<:AbstractSpatialMethod,T<:AbstractNativeTimeStepper,I<:AbstractInitialConditionSpec}
    return Params(
        nx=nx,
        length_cm=length_cm,
        tfinal=tfinal,
        dt=dt,
        cfl=cfl,
        severity=severity,
        rmax=rmax,
        rho=rho,
        nu=nu,
        rheology=rheology,
        space=space,
        time_stepper=time_stepper,
        initial_condition=initial_condition,
        model=model,
        wall_law=wall_law,
        forcing=forcing,
        young=young,
        wall_h=wall_h,
        sigma=sigma,
        alpha=alpha,
        inlet_umax=inlet_umax,
    )
end

"""
    OutputSpec(; csv, svg, write_svg, progress_every, overwrite)

CLI output and progress-log settings for a single run. This intentionally stays
separate from `Params` and `SolveSpec`.
"""
Base.@kwdef struct OutputSpec
    csv::String = ""
    svg::String = ""
    write_svg::Bool = true
    progress_every::Int = 5000
    overwrite::Bool = false
end

"""
    SimulationResult

Final state returned by all time backends. `area` and `flow` are sampled at
cell centers `z`, and diagnostics such as `velocity(result)` and
`pressure(result, params)` are derived from this structure.
"""
struct SimulationResult
    z::Vector{Float64}
    area::Vector{Float64}
    flow::Vector{Float64}
    completed_time::Float64
    steps::Int
    initial_condition::Union{Nothing,InitialConditionSummary}
    diagnostics::SimulationDiagnostics
end

function SimulationResult(
    z::Vector{Float64},
    area::Vector{Float64},
    flow::Vector{Float64},
    completed_time::Float64,
    steps::Int,
)
    return SimulationResult(z, area, flow, completed_time, steps, nothing, empty_simulation_diagnostics())
end

function SimulationResult(
    z::Vector{Float64},
    area::Vector{Float64},
    flow::Vector{Float64},
    completed_time::Float64,
    steps::Int,
    initial_condition::Union{Nothing,InitialConditionSummary},
)
    return SimulationResult(z, area, flow, completed_time, steps, initial_condition, empty_simulation_diagnostics())
end

velocity(result::SimulationResult) = result.flow ./ result.area

const DEFAULT_SIMULATION_OUTPUT_ROOT = joinpath("tmp", "simulations", "output")

terminal_time_error(actual_time::Real, requested_time::Real) = abs(Float64(actual_time) - Float64(requested_time))

function default_output_stub(p::Params)
    severity_label = round(Int, p.severity)
    model_token = replace(model_name(p), "-" => "_")
    base = joinpath(
        DEFAULT_SIMULATION_OUTPUT_ROOT,
        "stenosis_hemodynamics_$(model_token)_severity$(severity_label)_vp_$(velocity_profile_path_token(p.velocity_profile))",
    )
    tokens = String[]
    !(p.space isa FVMUSCLMethod) && push!(tokens, replace(spatial_method_name(p.space), "-" => "_"))
    !(p.time_stepper isa SSPRK3Stepper) && push!(tokens, replace(time_stepper_name(p.time_stepper), "-" => "_"))
    !(p.rheology isa NewtonianRheology) && push!(tokens, replace(rheology_name(p.rheology), "-" => "_"))
    !(p.initial_condition isa StationaryStokesIC) && push!(tokens, replace(initial_condition_name(p.initial_condition), "-" => "_"))
    !(p.wall_law isa CanicKoiterWallLaw) && push!(tokens, wall_law_path_token(p.wall_law))
    isempty(tokens) && return base
    return base * "_" * join(tokens, "_")
end

function validate(p::Params)
    p.nx >= 3 || throw(ArgumentError("nx must be at least 3"))
    p.length_cm > 0.0 || throw(ArgumentError("length_cm must be positive"))
    p.tfinal >= 0.0 || throw(ArgumentError("tfinal must be nonnegative"))
    p.dt > 0.0 || throw(ArgumentError("dt must be positive"))
    p.cfl > 0.0 || throw(ArgumentError("cfl must be positive"))
    0.0 <= p.severity < 100.0 || throw(ArgumentError("severity must be in [0, 100)"))
    p.rmax > 0.0 || throw(ArgumentError("rmax must be positive"))
    p.rho > 0.0 || throw(ArgumentError("rho must be positive"))
    p.nu >= 0.0 || throw(ArgumentError("nu must be nonnegative"))
    validate(p.rheology)
    validate(p.space)
    validate(p.time_stepper)
    validate(p.initial_condition)
    validate(p.velocity_profile)
    validate_model_profile(p.model, p.velocity_profile)
    validate(p.inlet_boundary)
    validate(p.outlet_boundary)
    validate(p.wall_law)
    validate(p.forcing)
    p.young > 0.0 || throw(ArgumentError("young must be positive"))
    p.wall_h > 0.0 || throw(ArgumentError("wall_h must be positive"))
    abs(p.sigma) < 1.0 || throw(ArgumentError("abs(sigma) must be less than 1"))
    p.alpha >= 1.0 || throw(ArgumentError("alpha must be at least 1"))
    isapprox(p.alpha, momentum_alpha(p.velocity_profile); rtol=0.0, atol=1.0e-12) ||
        throw(ArgumentError("alpha must match the selected velocity profile"))
    p.inlet_umax >= 0.0 || throw(ArgumentError("inlet_umax must be nonnegative"))
    return p
end
