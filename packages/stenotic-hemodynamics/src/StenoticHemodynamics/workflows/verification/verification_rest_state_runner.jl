# Workflow orchestration and row construction for rest-state drift verification.

"""
    run_rest_state_drift(spec = RestStateDriftSpec())

Run the requested geometry-rest drift cases, write the CSV/LaTeX summaries, and
return the collected rows plus output paths.
"""
function run_rest_state_drift(spec::RestStateDriftSpec = RestStateDriftSpec())
    validate_workflow_spec(spec)
    rows = RestStateDriftRow[]
    profile_rows = NamedTuple[]
    case_results = threaded_rest_state_drift_cases(spec)
    for (case_rows, profiles) in case_results
        append!(rows, case_rows)
        append!(profile_rows, profiles)
    end
    residual_rows = rest_state_residual_component_rows(spec)
    paths = default_output_paths(spec)
    csv_path = paths.summary_csv
    tex_path = paths.summary_tex
    write_rest_state_drift_csv(csv_path, rows; overwrite=spec.overwrite)
    write_rest_state_drift_tex(tex_path, rows; overwrite=spec.overwrite)
    write_rest_state_drift_full_tex(paths.full_tex, rows; overwrite=spec.overwrite)
    write_rest_state_drift_profile_csv(paths.profile_csv, profile_rows; overwrite=spec.overwrite)
    write_rest_state_residual_components_csv(paths.residual_csv, residual_rows; overwrite=spec.overwrite)
    write_rest_state_residual_components_tex(paths.residual_tex, residual_rows; overwrite=spec.overwrite)
    return RestStateDriftResult(
        spec,
        rows,
        residual_rows,
        csv_path,
        tex_path,
        paths.profile_csv,
        paths.residual_csv,
        paths.residual_tex,
    )
end

function threaded_rest_state_drift_cases(spec::RestStateDriftSpec)
    tasks = [(severity=Float64(severity), nx=nx) for severity in spec.severities for nx in sort(spec.nxs)]
    results = Vector{Tuple{Vector{RestStateDriftRow},Vector{NamedTuple}}}(undef, length(tasks))
    Threads.@threads for index in eachindex(tasks)
        task = tasks[index]
        results[index] = rest_state_drift_cases(spec, task.severity, task.nx)
    end
    return results
end

function rest_state_residual_component_rows(spec::RestStateDriftSpec)
    rows = RestStateResidualComponentRow[]
    for severity in spec.severities, nx in sort(spec.nxs)
        push!(rows, rest_state_residual_component_case(spec, Float64(severity), nx))
    end
    return rows
end

function rest_state_residual_component_case(spec::RestStateDriftSpec, severity::Float64, nx::Int)
    params = params_with(spec.base_params; severity=severity, nx=nx, tfinal=0.0)
    try
        return rest_state_residual_components(params)
    catch err
        return RestStateResidualComponentRow(
            severity=severity,
            nx=nx,
            dx=params.length_cm / nx,
            mass_flux_rusanov_max_abs=NaN,
            mass_flux_rusanov_z_cm=NaN,
            elastic_flux_difference_max_abs=NaN,
            elastic_flux_difference_z_cm=NaN,
            wall_geometry_source_max_abs=NaN,
            wall_geometry_source_z_cm=NaN,
            total_flow_residual_max_abs=NaN,
            total_flow_residual_z_cm=NaN,
            total_area_residual_max_abs=NaN,
            status="error",
            error_message=sprint(showerror, err),
        )
    end
end

function rest_state_drift_case(spec::RestStateDriftSpec, severity::Float64, nx::Int, tfinal::Float64)
    params = params_with(spec.base_params; severity=severity, nx=nx, tfinal=tfinal)
    try
        case = simulate_rest_state_drift_case(params, spec.backend; progress_every=spec.progress_every)
        return rest_state_drift_row_from_case(params, severity, nx, tfinal, case), rest_state_profile_rows(params, case.result)
    catch err
        return rest_state_drift_error_row(params, severity, nx, tfinal, err), NamedTuple[]
    end
end

function rest_state_drift_cases(spec::RestStateDriftSpec, severity::Float64, nx::Int)
    tfinals = sort(Float64.(spec.elapsed_times))
    max_tfinal = maximum(tfinals)
    params = params_with(spec.base_params; severity=severity, nx=nx, tfinal=max_tfinal)
    if spec.backend isa NativeRK3Backend && method_family(params.space) != :discontinuous_galerkin
        try
            cases = simulate_rest_state_drift_native_snapshots(params, tfinals; progress_every=spec.progress_every)
            rows = RestStateDriftRow[]
            profile_rows = NamedTuple[]
            for (tfinal, case) in zip(tfinals, cases)
                row_params = params_with(spec.base_params; severity=severity, nx=nx, tfinal=tfinal)
                push!(rows, rest_state_drift_row_from_case(row_params, severity, nx, tfinal, case))
                append!(profile_rows, rest_state_profile_rows(row_params, case.result))
            end
            return rows, profile_rows
        catch err
            return [
                rest_state_drift_error_row(params_with(spec.base_params; severity=severity, nx=nx, tfinal=tfinal), severity, nx, tfinal, err)
                for tfinal in tfinals
            ], NamedTuple[]
        end
    end

    rows = RestStateDriftRow[]
    profile_rows = NamedTuple[]
    for tfinal in tfinals
        row, profiles = rest_state_drift_case(spec, severity, nx, tfinal)
        push!(rows, row)
        append!(profile_rows, profiles)
    end
    return rows, profile_rows
end

function rest_state_drift_row_from_case(params::Params, severity::Float64, nx::Int, tfinal::Float64, case)
    result = case.result
    reference_A = [stenosis(zi, params)[1]^2 for zi in result.z]
    max_abs_q_index = argmax(abs.(result.flow))
    solver_volume_defect = section_mass(result.area, params.length_cm / nx) - section_mass(reference_A, params.length_cm / nx)
    physical_volume_defect = pi * solver_volume_defect
    conservation_residual = solver_volume_defect + case.boundary_flux_integral
    return RestStateDriftRow(
        severity=severity,
        nx=nx,
        dx=params.length_cm / nx,
        elapsed_time_s=result.completed_time,
        requested_time_s=tfinal,
        terminal_time_error_s=terminal_time_error(result.completed_time, tfinal),
        max_abs_q=maximum(abs.(result.flow)),
        max_abs_q_z=result.z[max_abs_q_index],
        max_abs_area_drift=maximum(abs.(result.area .- reference_A)),
        solver_volume_defect=solver_volume_defect,
        physical_volume_defect=physical_volume_defect,
        requested_q_in=case.final_flux.requested_q_in,
        applied_q_in=case.final_flux.applied_q_in,
        inlet_area_flux=case.final_flux.inlet_area_flux,
        outlet_area_flux=case.final_flux.outlet_area_flux,
        boundary_flux_integral=case.boundary_flux_integral,
        conservation_residual=conservation_residual,
        inlet_cell_q=result.flow[begin],
        outlet_cell_q=result.flow[end],
        mean_q=mean(result.flow),
        rms_q=sqrt(mean(abs2, result.flow)),
        lh_area_interior_max_abs=case.initial_lh.area_interior_max_abs,
        lh_area_boundary_max_abs=case.initial_lh.area_boundary_max_abs,
        lh_flow_interior_max_abs=case.initial_lh.flow_interior_max_abs,
        lh_flow_boundary_max_abs=case.initial_lh.flow_boundary_max_abs,
        realized_cfl_max=result.diagnostics.cfl_max,
        lambda_minus_min=result.diagnostics.lambda_minus_min,
        lambda_plus_max=result.diagnostics.lambda_plus_max,
        subcritical_margin_min=result.diagnostics.subcritical_margin_min,
        positivity_projection_count=result.diagnostics.positivity_projection_count,
        positivity_correction_total=result.diagnostics.positivity_correction_total,
        status="ok",
        error_message="",
    )
end

function rest_state_drift_error_row(params::Params, severity::Float64, nx::Int, tfinal::Float64, err)
    return RestStateDriftRow(
        severity=severity,
        nx=nx,
        dx=params.length_cm / nx,
        elapsed_time_s=NaN,
        requested_time_s=tfinal,
        terminal_time_error_s=NaN,
        max_abs_q=NaN,
        max_abs_q_z=NaN,
        max_abs_area_drift=NaN,
        solver_volume_defect=NaN,
        physical_volume_defect=NaN,
        requested_q_in=NaN,
        applied_q_in=NaN,
        inlet_area_flux=NaN,
        outlet_area_flux=NaN,
        boundary_flux_integral=NaN,
        conservation_residual=NaN,
        inlet_cell_q=NaN,
        outlet_cell_q=NaN,
        mean_q=NaN,
        rms_q=NaN,
        lh_area_interior_max_abs=NaN,
        lh_area_boundary_max_abs=NaN,
        lh_flow_interior_max_abs=NaN,
        lh_flow_boundary_max_abs=NaN,
        realized_cfl_max=NaN,
        lambda_minus_min=NaN,
        lambda_plus_max=NaN,
        subcritical_margin_min=NaN,
        positivity_projection_count=0,
        positivity_correction_total=NaN,
        status="error",
        error_message=sprint(showerror, err),
    )
end
