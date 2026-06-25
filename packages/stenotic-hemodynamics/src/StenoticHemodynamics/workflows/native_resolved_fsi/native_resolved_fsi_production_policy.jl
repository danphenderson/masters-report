function native_resolved_fsi_production_boundary_mode(value::Union{Symbol,AbstractString})
    if isdefined(@__MODULE__, :native_resolved_fsi_inlet_outlet_boundary_mode)
        return native_resolved_fsi_inlet_outlet_boundary_mode(value)
    end
    # The adapter-level validator is included later in module load order.
    mode = Symbol(value)
    mode in NATIVE_RESOLVED_FSI_PRODUCTION_INLET_OUTLET_BOUNDARY_MODES || throw(ArgumentError(
        "native resolved-FSI partitioned production inlet_outlet_boundary_mode must be one of " *
        "$(NATIVE_RESOLVED_FSI_PRODUCTION_INLET_OUTLET_BOUNDARY_MODES); got $(repr(mode))",
    ))
    return mode
end

function native_resolved_fsi_exact_section41_boundary_smoke_contract(;
    inlet_umax_cm_s::Real = NATIVE_RESOLVED_FSI_PRODUCTION_SECTION41_INLET_UMAX_CM_S,
)
    inlet_umax = Float64(inlet_umax_cm_s)
    isfinite(inlet_umax) ||
        throw(ArgumentError("native resolved-FSI exact Section 4.1 boundary status inlet_umax_cm_s must be finite"))
    inlet_umax > 0.0 ||
        throw(ArgumentError("native resolved-FSI exact Section 4.1 boundary status inlet_umax_cm_s must be positive"))
    inlet_condition_status = isapprox(
        inlet_umax,
        NATIVE_RESOLVED_FSI_PRODUCTION_SECTION41_INLET_UMAX_CM_S;
        atol=0.0,
        rtol=1.0e-12,
    ) ? "poiseuille_profile_umax_45_cm_s" : "poiseuille_profile_custom_umax_cm_s"
    return (
        boundary_mode=string(:poiseuille_inlet_zero_outlet_stress_section41),
        boundary_mode_class="exact_section41",
        inlet_condition_status=inlet_condition_status,
        outlet_condition_status="zero_outlet_stress_natural_traction",
        pressure_gauge_status="post_sampling_outlet_mean_normalization_not_gridap_nullspace_constraint",
        pressure_nullspace_status="no_gridap_zero_mean_pressure_constraint; post_sampling_outlet_mean_normalization_remains_export_gauge; exact_natural_cauchy_traction_pressure_reference; not_wall_stability_remediation",
        wall_pressure_projection_status="direct_finite_physical_wall_forcing_pressure_sampling_required; pressure_drop_resistance_fallback_disabled; outlet_gauge_normalization_export_only_not_membrane_forcing",
        wall_pressure_forcing_status="physical_wall_forcing_pressure_raw_direct_finite_sampling_required; fallback_disabled; post_sampling_outlet_gauge_pressure_export_only",
        section41_boundary_status="implemented_smoke_validated",
        boundary_status="exact Section 4.1 boundary mode selected; low-level Gridap and partitioned production smoke-scale threading evidence are present as smoke-scale/operator-readiness evidence only, but this is not paper-grade numerical reproduction or Section 4.1 parity",
        boundary_equivalence_status="exact_section41_boundary_mode_selected_smoke_validated; production artifacts may record exact-mode smoke-scale/operator-readiness evidence only, but parity ready is still artifact/operator readiness, not paper-grade reproduction",
    )
end

function native_resolved_fsi_boundary_status_fields(
    mode::Union{Symbol,AbstractString};
    inlet_umax_cm_s::Real = NATIVE_RESOLVED_FSI_PRODUCTION_SECTION41_INLET_UMAX_CM_S,
)
    boundary_mode = native_resolved_fsi_production_boundary_mode(mode)
    inlet_umax = Float64(inlet_umax_cm_s)
    isfinite(inlet_umax) ||
        throw(ArgumentError("native resolved-FSI boundary status inlet_umax_cm_s must be finite"))
    if boundary_mode === :pressure_drop_weak_inlet_outlet_gauge_smoke
        return (
            boundary_mode=string(boundary_mode),
            boundary_mode_class="local_smoke_loading",
            inlet_condition_status="pressure_drop_weak_loading_not_poiseuille_profile",
            outlet_condition_status="outlet_gauge_pressure_reference_not_zero_outlet_stress_evidence",
            pressure_gauge_status="post_sampling_outlet_mean_normalization_not_gridap_nullspace_constraint",
            section41_boundary_status="deferred_or_not_selected",
            boundary_status="local smoke boundary evidence only; not exact Section 4.1 boundary reproduction",
        )
    end
    exact_contract = native_resolved_fsi_exact_section41_boundary_smoke_contract(inlet_umax_cm_s=inlet_umax)
    return (
        boundary_mode=exact_contract.boundary_mode,
        boundary_mode_class=exact_contract.boundary_mode_class,
        inlet_condition_status=exact_contract.inlet_condition_status,
        outlet_condition_status=exact_contract.outlet_condition_status,
        pressure_gauge_status=exact_contract.pressure_gauge_status,
        section41_boundary_status=exact_contract.section41_boundary_status,
        boundary_status=exact_contract.boundary_status,
    )
end

function native_resolved_fsi_boundary_equivalence_status(boundary_status::NamedTuple)
    if boundary_status.boundary_mode == string(:poiseuille_inlet_zero_outlet_stress_section41)
        return native_resolved_fsi_exact_section41_boundary_smoke_contract().boundary_equivalence_status
    end
    return "not_exact_section41_boundary_equivalence; parity ready is artifact/operator readiness only"
end

function native_resolved_fsi_wall_pressure_projection_status(boundary_mode::Union{Symbol,AbstractString})
    mode = native_resolved_fsi_production_boundary_mode(boundary_mode)
    if mode === :poiseuille_inlet_zero_outlet_stress_section41
        return native_resolved_fsi_exact_section41_boundary_smoke_contract().wall_pressure_projection_status
    end
    return "physical_wall_forcing_pressure_direct_sampling_with_pressure_drop_resistance_fallback_if_needed; outlet_gauge_normalization_export_only_not_membrane_forcing"
end

function native_resolved_fsi_wall_pressure_forcing_status(boundary_mode::Union{Symbol,AbstractString})
    mode = native_resolved_fsi_production_boundary_mode(boundary_mode)
    if mode === :poiseuille_inlet_zero_outlet_stress_section41
        return native_resolved_fsi_exact_section41_boundary_smoke_contract().wall_pressure_forcing_status
    end
    return "physical_wall_forcing_pressure_raw_sampling_or_resistance_fallback; post_sampling_outlet_gauge_pressure_export_only"
end

function native_resolved_fsi_pressure_nullspace_status(boundary_mode::Union{Symbol,AbstractString})
    mode = native_resolved_fsi_production_boundary_mode(boundary_mode)
    if mode === :poiseuille_inlet_zero_outlet_stress_section41
        return native_resolved_fsi_exact_section41_boundary_smoke_contract().pressure_nullspace_status
    end
    return "gridap_zero_mean_pressure_constraint_active_additive_nullspace; post_sampling_outlet_mean_normalization_remains_export_gauge; local_smoke_loading_only"
end
