# State construction and residual evaluation helpers for rest-state drift runs.

function simulate_rest_state_drift_case(params::Params, backend::AbstractTimeBackend; progress_every::Int = 0)
    # Native finite-volume runs expose the boundary-area flux integral directly.
    if backend isa NativeRK3Backend && method_family(params.space) != :discontinuous_galerkin
        return simulate_rest_state_drift_native(params; progress_every=progress_every)
    end

    result = simulate(params, backend; progress_every=progress_every)
    initial = initial_state_result(params)
    return (
        result=result,
        boundary_flux_integral=NaN,
        initial_lh=rest_state_lh_metrics(initial.area, initial.flow, initial.z, initial.dx, params),
        final_flux=rest_state_boundary_flux_metrics(
            result.area,
            result.flow,
            result.z,
            params.length_cm / params.nx,
            params,
            result.completed_time,
        ),
    )
end

function simulate_rest_state_drift_native(params::Params; progress_every::Int = 0)
    snapshots = simulate_rest_state_drift_native_snapshots(params, [params.tfinal]; progress_every=progress_every)
    return only(snapshots)
end

function simulate_rest_state_drift_native_snapshots(
    params::Params,
    sample_times::AbstractVector{<:Real};
    progress_every::Int = 0,
)
    validate(params)
    sorted_sample_times = sort(Float64.(sample_times))
    all(t -> t >= 0.0, sorted_sample_times) || throw(ArgumentError("rest-state sample times must be nonnegative"))
    initial = initial_state_result(params)
    z = copy(initial.z)
    A = copy(initial.area)
    Q = copy(initial.flow)
    dx = initial.dx
    step_cache = NativeStepCache(length(A))
    flux_cache = RHSCache(length(A))
    diagnostics = DiagnosticsAccumulator(A, dx)
    initial_lh = rest_state_lh_metrics(A, Q, z, dx, params)
    boundary_flux_integral = 0.0
    t = 0.0
    step = 0
    snapshots = NamedTuple[]

    for target_time in sorted_sample_times
        while t < target_time - 1.0e-14
            dt = rest_state_choose_dt_record_timestep!(diagnostics, A, Q, z, dx, target_time - t, params)
            mass_before = diagnostics.mass_final
            native_step!(A, Q, z, dx, dt, t, params, step_cache, diagnostics)
            t += dt
            step += 1
            record_mass_diagnostics!(diagnostics, A, dx)
            boundary_flux_integral += mass_before - diagnostics.mass_final

            if progress_every > 0 && step % progress_every == 0
                @telemetry_info "rest-state progress" event="rest_state_progress" stage="verification" nx=params.nx tfinal=params.tfinal status="running" step t dt
            end

            if !all(isfinite, A) || !all(isfinite, Q)
                error("non-finite solution at t=$(t)")
            end
        end

        push!(snapshots, rest_state_drift_native_snapshot(
            A,
            Q,
            z,
            dx,
            t,
            step,
            initial.summary,
            diagnostics,
            params,
            boundary_flux_integral,
            initial_lh,
            flux_cache,
        ))
    end

    return snapshots
end

function rest_state_choose_dt_record_timestep!(
    diagnostics::DiagnosticsAccumulator,
    A::Vector{Float64},
    Q::Vector{Float64},
    z::Vector{Float64},
    dx::Float64,
    remaining_time::Float64,
    params::Params,
)
    max_speed = 0.0
    for i in eachindex(A)
        lambda_minus, lambda_plus, _, _ = characteristic_speeds(A[i], Q[i], z[i], params)
        max_speed = max(max_speed, abs(lambda_minus), abs(lambda_plus))
        diagnostics.lambda_minus_min = min(diagnostics.lambda_minus_min, lambda_minus)
        diagnostics.lambda_minus_max = max(diagnostics.lambda_minus_max, lambda_minus)
        diagnostics.lambda_plus_min = min(diagnostics.lambda_plus_min, lambda_plus)
        diagnostics.lambda_plus_max = max(diagnostics.lambda_plus_max, lambda_plus)
        diagnostics.subcritical_margin_min = min(diagnostics.subcritical_margin_min, min(-lambda_minus, lambda_plus))
    end
    dt = min(params.dt, params.cfl * dx / max(max_speed, eps()), remaining_time)
    diagnostics.dt_min = min(diagnostics.dt_min, dt)
    diagnostics.dt_max = max(diagnostics.dt_max, dt)
    cfl = max_speed * dt / dx
    diagnostics.cfl_min = min(diagnostics.cfl_min, cfl)
    diagnostics.cfl_max = max(diagnostics.cfl_max, cfl)
    return dt
end

function rest_state_drift_native_snapshot(
    A::Vector{Float64},
    Q::Vector{Float64},
    z::Vector{Float64},
    dx::Float64,
    t::Float64,
    step::Int,
    initial_summary,
    diagnostics::DiagnosticsAccumulator,
    params::Params,
    boundary_flux_integral::Float64,
    initial_lh,
    flux_cache::RHSCache,
)
    result = SimulationResult(copy(z), copy(A), copy(Q), t, step, initial_summary, finalize_diagnostics(diagnostics))
    final_flux = rest_state_boundary_flux_metrics(A, Q, z, dx, params, t, flux_cache)
    return (
        result=result,
        boundary_flux_integral=boundary_flux_integral,
        initial_lh=initial_lh,
        final_flux=final_flux,
    )
end

function rest_state_boundary_flux_metrics(
    A::Vector{Float64},
    Q::Vector{Float64},
    z::Vector{Float64},
    dx::Float64,
    params::Params,
    t::Float64,
)
    return rest_state_boundary_flux_metrics(A, Q, z, dx, params, t, RHSCache(length(A)))
end

function rest_state_boundary_flux_metrics(
    A::Vector{Float64},
    Q::Vector{Float64},
    z::Vector{Float64},
    dx::Float64,
    params::Params,
    t::Float64,
    cache::RHSCache,
)
    fill_method_fluxes!(cache.area_flux, cache.flow_flux, A, Q, z, dx, params.dt, t, params.space, params, cache)
    _, applied_q_in, _, _ = boundary_states(A, Q, params, t)
    return (
        requested_q_in=inlet_flow(params, t),
        applied_q_in=applied_q_in,
        inlet_area_flux=cache.area_flux[begin],
        outlet_area_flux=cache.area_flux[end],
    )
end

function rest_state_lh_metrics(
    A::Vector{Float64},
    Q::Vector{Float64},
    z::Vector{Float64},
    dx::Float64,
    params::Params,
)
    cache = RHSCache(length(A))
    dA = similar(A)
    dQ = similar(Q)
    fill_rhs_dt!(dA, dQ, A, Q, z, dx, params.dt, 0.0, params, cache)
    return (
        area_interior_max_abs=maximum_abs_index_range(dA, 2:(length(dA) - 1)),
        area_boundary_max_abs=max(abs(dA[begin]), abs(dA[end])),
        flow_interior_max_abs=maximum_abs_index_range(dQ, 2:(length(dQ) - 1)),
        flow_boundary_max_abs=max(abs(dQ[begin]), abs(dQ[end])),
    )
end

"""
    rest_state_residual_components(params)

Evaluate the geometry-rest residual decomposition at `t = 0` on one grid.
"""
function rest_state_residual_components(params::Params)
    validate(params)
    initial = initial_state_result(params)
    A = initial.area
    Q = initial.flow
    z = initial.z
    dx = initial.dx
    nx = length(A)
    cache = RHSCache(nx)
    fill_method_fluxes!(cache.area_flux, cache.flow_flux, A, Q, z, dx, params.dt, 0.0, params.space, params, cache)
    fill_source!(cache.source, A, Q, z, dx, params)
    apply_geometry_rest_well_balanced_source!(cache.source, z, dx, 0.0, params.space, params)

    mass_flux = Vector{Float64}(undef, nx)
    elastic_flux_difference = Vector{Float64}(undef, nx)
    wall_geometry_source = copy(cache.source)
    total_flow_residual = Vector{Float64}(undef, nx)
    for i in 1:nx
        mass_flux[i] = -(cache.area_flux[i + 1] - cache.area_flux[i]) / dx
        elastic_flux_difference[i] = -(cache.flow_flux[i + 1] - cache.flow_flux[i]) / dx
        total_flow_residual[i] = elastic_flux_difference[i] + wall_geometry_source[i]
    end

    mass_value, mass_z = max_abs_with_z(mass_flux, z)
    elastic_value, elastic_z = max_abs_with_z(elastic_flux_difference, z)
    source_value, source_z = max_abs_with_z(wall_geometry_source, z)
    total_flow_value, total_flow_z = max_abs_with_z(total_flow_residual, z)

    return RestStateResidualComponentRow(
        severity=params.severity,
        nx=nx,
        dx=dx,
        mass_flux_rusanov_max_abs=mass_value,
        mass_flux_rusanov_z_cm=mass_z,
        elastic_flux_difference_max_abs=elastic_value,
        elastic_flux_difference_z_cm=elastic_z,
        wall_geometry_source_max_abs=source_value,
        wall_geometry_source_z_cm=source_z,
        total_flow_residual_max_abs=total_flow_value,
        total_flow_residual_z_cm=total_flow_z,
        total_area_residual_max_abs=mass_value,
        status="ok",
        error_message="",
    )
end

function max_abs_with_z(values::AbstractVector{Float64}, z::AbstractVector{Float64})
    length(values) == length(z) || throw(DimensionMismatch("values and z must have matching length"))
    !isempty(values) || throw(ArgumentError("values must be nonempty"))
    index = argmax(abs.(values))
    return abs(values[index]), z[index]
end

function maximum_abs_index_range(values::AbstractVector{Float64}, indices)
    max_value = 0.0
    for i in indices
        max_value = max(max_value, abs(values[i]))
    end
    return max_value
end

function rest_state_profile_rows(params::Params, result::SimulationResult)
    return [
        (
            severity=params.severity,
            nx=params.nx,
            requested_time_s=params.tfinal,
            elapsed_time_s=result.completed_time,
            z_cm=result.z[i],
            a_cm2=result.area[i],
            q_cm3_s=result.flow[i],
            u_cm_s=result.flow[i] / result.area[i],
        )
        for i in eachindex(result.z)
    ]
end
