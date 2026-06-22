function compare_section_means(
    field::Resolved3DVelocityField,
    result::SimulationResult,
    params::Params,
    spec::ComparisonSpec,
)
    z_targets = collect(range(0.0, params.length_cm; length=spec.section_count))
    u1d = velocity(result)
    rows = SectionComparisonRow[]
    time_fields = resolved3d_time_fields(field, result)
    run_fields = resolved3d_run_fields(field.case_spec, params, spec.backend)

    for z in z_targets
        z_value = Float64(z)
        observation = section_observation(field, z_value, spec.operator)
        u1d_at_z = interpolate_linear(result.z, u1d, z_value)
        q1d_at_z = interpolate_linear(result.z, result.flow, z_value)
        flow_1d = pi * q1d_at_z
        abs_error = abs_or_nan(u1d_at_z, observation.mean_velocity_cm_s)
        flow_abs_error = abs_or_nan(flow_1d, observation.flow_cm3_s)
        rel_error = relative_error(abs_error, observation.mean_velocity_cm_s)

        push!(
            rows,
            SectionComparisonRow(
                field.case_spec.case_label,
                field.case_spec.severity,
                operator_name(spec.operator),
                run_fields.model,
                run_fields.nx,
                run_fields.dt_s,
                run_fields.initial_condition,
                run_fields.backend,
                run_fields.run_status,
                spec.coordinate_mode,
                z_value,
                observation.area_cm2,
                observation.flow_cm3_s,
                flow_1d,
                observation.mean_velocity_cm_s,
                u1d_at_z,
                abs_error,
                flow_abs_error,
                rel_error,
                rel_error,
                observation.intersection_count,
                observation.area_valid,
                observation.cut_status,
                observation.node_count,
                observation.observed_radius_cm,
                field.metadata.time,
                time_fields.xdmf_target_time_error_s,
                time_fields.target_time_s,
                run_fields.time_atol_s,
                time_fields.one_d_completed_time_s,
                time_fields.one_d_terminal_time_error_s,
                time_fields.xdmf_target_time_error_s,
                time_fields.cross_model_time_offset_s,
            ),
        )
    end

    return rows
end

function compare_radial_profiles(
    field::Resolved3DVelocityField,
    result::SimulationResult,
    params::Params,
    spec::ComparisonSpec,
)
    u1d = velocity(result)
    rows = RadialProfileRow[]
    time_fields = resolved3d_time_fields(field, result)
    run_fields = resolved3d_run_fields(field.case_spec, params, spec.backend)

    for z_slice in spec.profile_slices
        r0, _, _ = stenosis(z_slice, params)
        area_at_z = interpolate_linear(result.z, result.area, z_slice)
        radius_at_z = sqrt(positive_area(area_at_z))
        uavg_at_z = interpolate_linear(result.z, u1d, z_slice)
        current_area = pi * radius_at_z^2
        reference_area = pi * r0^2
        area_mismatch = abs(current_area - reference_area) / max(reference_area, eps())

        for radius_mode in spec.radial_radius_modes, bin_count in spec.radial_bin_counts
            radius_scale = radius_mode == "current" ? radius_at_z : r0
            observations = radial_profile_observations(field, z_slice, radius_scale, bin_count, spec.operator)

            for bin in 1:bin_count
                observation = observations[bin]
                r_over_radius_mid = (bin - 0.5) / bin_count
                u1d_profile = one_dimensional_profile_velocity(uavg_at_z, r_over_radius_mid * radius_scale, radius_at_z, params)
                abs_error = abs_or_nan(u1d_profile, observation.mean_velocity_cm_s)
                rel_error = relative_error(abs_error, observation.mean_velocity_cm_s)

                push!(
                    rows,
                    RadialProfileRow(
                        field.case_spec.case_label,
                        field.case_spec.severity,
                        operator_name(spec.operator),
                        run_fields.model,
                        run_fields.nx,
                        run_fields.dt_s,
                        run_fields.initial_condition,
                        run_fields.backend,
                        run_fields.run_status,
                        spec.coordinate_mode,
                        z_slice,
                        bin,
                        r_over_radius_mid,
                        observation.area_cm2,
                        observation.flow_cm3_s,
                        observation.mean_velocity_cm_s,
                        u1d_profile,
                        abs_error,
                        rel_error,
                        observation.intersection_count,
                        observation.area_valid,
                        observation.node_count,
                        field.metadata.time,
                        time_fields.xdmf_target_time_error_s,
                        time_fields.target_time_s,
                        run_fields.time_atol_s,
                        time_fields.one_d_completed_time_s,
                        time_fields.one_d_terminal_time_error_s,
                        time_fields.xdmf_target_time_error_s,
                        time_fields.cross_model_time_offset_s,
                        bin_count,
                        radius_mode,
                        radius_scale,
                        current_area,
                        reference_area,
                        area_mismatch,
                        observation.velocity_variance_cm2_s2,
                    ),
                )
            end
        end
    end

    return rows
end

function compare_node_slab_sensitivity(
    field::Resolved3DVelocityField,
    result::SimulationResult,
    params::Params,
    spec::ComparisonSpec,
)
    z_targets = collect(range(0.0, params.length_cm; length=spec.section_count))
    u1d = velocity(result)
    rows = NodeSlabSensitivityRow[]
    time_fields = resolved3d_time_fields(field, result)
    run_fields = resolved3d_run_fields(field.case_spec, params, spec.backend)

    for half_width in spec.node_slab_half_widths
        operator = NodeSlabOperator(half_width_cm=half_width)
        for z in z_targets
            z_value = Float64(z)
            observation = section_observation(field, z_value, operator)
            u1d_at_z = interpolate_linear(result.z, u1d, z_value)
            abs_error = abs_or_nan(u1d_at_z, observation.mean_velocity_cm_s)
            push!(
                rows,
                NodeSlabSensitivityRow(
                    field.case_spec.case_label,
                    field.case_spec.severity,
                    run_fields.model,
                    run_fields.nx,
                    run_fields.dt_s,
                    run_fields.initial_condition,
                    run_fields.backend,
                    run_fields.run_status,
                    spec.coordinate_mode,
                    half_width,
                    z_value,
                    observation.mean_velocity_cm_s,
                    u1d_at_z,
                    abs_error,
                    relative_error(abs_error, observation.mean_velocity_cm_s),
                    observation.node_count,
                    observation.observed_radius_cm,
                    field.metadata.time,
                    time_fields.xdmf_target_time_error_s,
                    time_fields.target_time_s,
                    run_fields.time_atol_s,
                    time_fields.one_d_completed_time_s,
                    time_fields.one_d_terminal_time_error_s,
                    time_fields.xdmf_target_time_error_s,
                    time_fields.cross_model_time_offset_s,
                ),
            )
        end
    end

    return rows
end

function summarize_comparison(
    case::Resolved3DCaseSpec,
    metadata::XDMFVelocityMetadata,
    params::Params,
    backend::AbstractTimeBackend,
    section_rows::Vector{SectionComparisonRow},
    profile_rows::Vector{RadialProfileRow},
    diagnostics,
    production_diagnostics,
    one_d_completed_time::Real,
)
    section_abs = finite_values(row.abs_velocity_error_cm_s for row in section_rows)
    section_rel = finite_values(row.rel_error for row in section_rows)
    flow_abs = finite_values(row.flow_abs_error_cm3_s for row in section_rows)
    profile_abs = finite_values(row.abs_velocity_error_cm_s for row in profile_rows)
    node_counts = [row.node_count for row in section_rows]
    intersection_counts = [row.intersection_count for row in section_rows if row.intersection_count > 0]
    time_fields = resolved3d_time_fields(case.target_time, metadata.time, one_d_completed_time)
    run_fields = resolved3d_run_fields(case, params, backend)
    velocity_errors = finite_values(row.abs_velocity_error_cm_s for row in section_rows)
    velocity_refs = finite_values(row.mean_u3d_cm_s for row in section_rows)
    coordinate_mode = isempty(section_rows) ? "reference" : first(section_rows).coordinate_mode

    return ComparisonSummaryRow(
        case.case_label,
        case.severity,
        isempty(section_rows) ? "" : first(section_rows).operator,
        run_fields.model,
        run_fields.nx,
        run_fields.dt_s,
        run_fields.initial_condition,
        run_fields.backend,
        run_fields.run_status,
        coordinate_mode,
        length(section_rows),
        length(profile_rows),
        mean_or_nan(section_abs),
        l2_mean_or_nan(section_abs),
        maximum_or_nan(section_abs),
        mean_or_nan(section_rel),
        relative_l1(velocity_errors, velocity_refs),
        maximum_or_nan(section_rel),
        relative_l2(velocity_errors, velocity_refs),
        mean_or_nan(flow_abs),
        l2_mean_or_nan(flow_abs),
        maximum_or_nan(flow_abs),
        mean_or_nan(profile_abs),
        l2_mean_or_nan(profile_abs),
        maximum_or_nan(profile_abs),
        isempty(intersection_counts) ? 0 : minimum(intersection_counts),
        isempty(node_counts) ? 0 : minimum(node_counts),
        count(row -> row.area_valid, section_rows),
        diagnostics.alpha_eff_min,
        diagnostics.alpha_eff_max,
        diagnostics.characteristic_radicand_min,
        diagnostics.lambda_minus_min,
        diagnostics.lambda_minus_max,
        diagnostics.lambda_plus_min,
        diagnostics.lambda_plus_max,
        diagnostics.subcritical_margin_min,
        production_diagnostics.accepted_dt_min,
        production_diagnostics.accepted_dt_max,
        production_diagnostics.realized_cfl_max,
        production_diagnostics.min_solver_area,
        production_diagnostics.min_physical_area_cm2,
        production_diagnostics.solver_volume_defect,
        production_diagnostics.physical_volume_defect_cm3,
        production_diagnostics.positivity_projection_count,
        production_diagnostics.positivity_correction_total,
        production_diagnostics.final_inlet_area_flux,
        production_diagnostics.final_outlet_area_flux,
        production_diagnostics.final_area_flux_balance,
        production_diagnostics.final_rhs_area_max_abs,
        production_diagnostics.final_rhs_flow_max_abs,
        metadata.time,
        time_fields.xdmf_target_time_error_s,
        time_fields.target_time_s,
        run_fields.time_atol_s,
        time_fields.one_d_completed_time_s,
        time_fields.one_d_terminal_time_error_s,
        time_fields.xdmf_target_time_error_s,
        time_fields.cross_model_time_offset_s,
    )
end

function comparison_production_diagnostics(result::SimulationResult, params::Params)
    dx = params.length_cm / params.nx
    cache = RHSCache(length(result.area))
    dA = similar(result.area)
    dQ = similar(result.flow)
    fill_rhs_dt!(dA, dQ, result.area, result.flow, result.z, dx, 0.0, result.completed_time, params, cache)
    fill_method_fluxes!(
        cache.area_flux,
        cache.flow_flux,
        result.area,
        result.flow,
        result.z,
        dx,
        0.0,
        result.completed_time,
        params.space,
        params,
        cache,
    )
    return (
        accepted_dt_min=result.diagnostics.dt_min,
        accepted_dt_max=result.diagnostics.dt_max,
        realized_cfl_max=result.diagnostics.cfl_max,
        min_solver_area=minimum(result.area),
        min_physical_area_cm2=pi * minimum(result.area),
        solver_volume_defect=result.diagnostics.mass_defect,
        physical_volume_defect_cm3=pi * result.diagnostics.mass_defect,
        positivity_projection_count=result.diagnostics.positivity_projection_count,
        positivity_correction_total=result.diagnostics.positivity_correction_total,
        final_inlet_area_flux=cache.area_flux[begin],
        final_outlet_area_flux=cache.area_flux[end],
        final_area_flux_balance=cache.area_flux[end] - cache.area_flux[begin],
        final_rhs_area_max_abs=maximum(abs.(dA)),
        final_rhs_flow_max_abs=maximum(abs.(dQ)),
    )
end

function finite_values(values)
    return [Float64(value) for value in values if isfinite(Float64(value))]
end

mean_or_nan(values::Vector{Float64}) = isempty(values) ? NaN : mean(values)
maximum_or_nan(values::Vector{Float64}) = isempty(values) ? NaN : maximum(values)
l2_mean_or_nan(values::Vector{Float64}) = isempty(values) ? NaN : sqrt(mean(value^2 for value in values))

function relative_l1(errors::Vector{Float64}, references::Vector{Float64})
    isempty(errors) && return NaN
    length(errors) == length(references) || return NaN
    denominator = sum(abs(reference) for reference in references)
    return denominator > 0.0 ? sum(abs(error) for error in errors) / denominator : NaN
end

function relative_l2(errors::Vector{Float64}, references::Vector{Float64})
    isempty(errors) && return NaN
    length(errors) == length(references) || return NaN
    numerator = sqrt(sum(error^2 for error in errors))
    denominator = sqrt(sum(reference^2 for reference in references))
    return denominator > 0.0 ? numerator / denominator : NaN
end

function characteristic_diagnostics(result::SimulationResult, params::Params)
    alpha_min = Inf
    alpha_max = -Inf
    radicand_min = Inf
    lambda_minus_min = Inf
    lambda_minus_max = -Inf
    lambda_plus_min = Inf
    lambda_plus_max = -Inf
    subcritical_margin_min = Inf

    for (A, Q, z) in zip(result.area, result.flow, result.z)
        lambda_minus, lambda_plus, radicand, alpha_eff = characteristic_speeds(A, Q, z, params)
        alpha_min = min(alpha_min, alpha_eff)
        alpha_max = max(alpha_max, alpha_eff)
        radicand_min = min(radicand_min, radicand)
        lambda_minus_min = min(lambda_minus_min, lambda_minus)
        lambda_minus_max = max(lambda_minus_max, lambda_minus)
        lambda_plus_min = min(lambda_plus_min, lambda_plus)
        lambda_plus_max = max(lambda_plus_max, lambda_plus)
        subcritical_margin_min = min(subcritical_margin_min, min(-lambda_minus, lambda_plus))
    end

    return (
        alpha_eff_min=alpha_min,
        alpha_eff_max=alpha_max,
        characteristic_radicand_min=radicand_min,
        lambda_minus_min=lambda_minus_min,
        lambda_minus_max=lambda_minus_max,
        lambda_plus_min=lambda_plus_min,
        lambda_plus_max=lambda_plus_max,
        subcritical_margin_min=subcritical_margin_min,
    )
end
