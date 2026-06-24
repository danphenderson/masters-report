"""
    params_with(params; kwargs...) -> Params

Return a `Params` copy with selected fields replaced while preserving the
velocity-profile versus `alpha` exclusivity contract.
"""
function params_with(
    p::Params;
    nx::Int = p.nx,
    length_cm::Float64 = p.length_cm,
    tfinal::Float64 = p.tfinal,
    dt::Float64 = p.dt,
    cfl::Float64 = p.cfl,
    severity::Float64 = p.severity,
    rmax::Float64 = p.rmax,
    rho::Float64 = p.rho,
    nu::Float64 = p.nu,
    rheology::AbstractRheology = p.rheology,
    space::AbstractSpatialMethod = p.space,
    time_stepper::AbstractNativeTimeStepper = p.time_stepper,
    initial_condition::AbstractInitialConditionSpec = p.initial_condition,
    velocity_profile::AbstractVelocityProfile = p.velocity_profile,
    model::Union{AbstractString,AbstractForwardModel} = p.model,
    inlet_boundary::AbstractInletBoundary = p.inlet_boundary,
    outlet_boundary::AbstractOutletBoundary = p.outlet_boundary,
    wall_law::AbstractWallLaw = p.wall_law,
    forcing::AbstractForcingTerm = p.forcing,
    young::Float64 = p.young,
    wall_h::Float64 = p.wall_h,
    sigma::Float64 = p.sigma,
    alpha::Union{Nothing,Float64} = nothing,
    inlet_umax::Float64 = p.inlet_umax,
)
    if alpha !== nothing && velocity_profile != p.velocity_profile
        throw(ArgumentError("provide velocity_profile or alpha, not both"))
    end
    resolved_profile = alpha === nothing ? velocity_profile : PowerVelocityProfile(alpha=alpha)
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
        velocity_profile=resolved_profile,
        model=model,
        inlet_boundary=inlet_boundary,
        outlet_boundary=outlet_boundary,
        wall_law=wall_law,
        forcing=forcing,
        young=young,
        wall_h=wall_h,
        sigma=sigma,
        inlet_umax=inlet_umax,
    )
end

function summarize_study_run(
    study_kind::String,
    params::Params,
    backend::AbstractTimeBackend,
    result::SimulationResult,
)
    u = velocity(result)
    P = diagnostic_pressure(result, params)
    return StudyRunSummary(
        study_kind,
        params.severity,
        params.nx,
        params.length_cm / params.nx,
        backend_name(backend),
        run_algorithm_name(params, backend),
        model_name(params),
        variable_radius_terms_enabled(params),
        wall_law_name(params.wall_law),
        spatial_method_name(params.space),
        time_stepper_name(params.time_stepper),
        rheology_name(params.rheology),
        profile_name(params.velocity_profile),
        params.alpha,
        profile_exponent(params.velocity_profile),
        shear_rate_factor(params.velocity_profile),
        result.steps,
        result.completed_time,
        minimum(u),
        maximum(u),
        minimum(P),
        maximum(P),
        minimum(result.area),
    )
end
