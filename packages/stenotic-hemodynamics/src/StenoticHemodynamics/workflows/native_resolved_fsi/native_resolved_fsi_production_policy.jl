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

function native_resolved_fsi_partitioned_production_default_guard_report(
    spec::NativeResolvedFSIPartitionedProductionSpec,
)
    estimated_field_payload_bytes = native_resolved_fsi_partitioned_production_estimated_field_payload_bytes(spec)
    snapshot_count_within_default_guard =
        length(spec.snapshot_times_s) <= NATIVE_RESOLVED_FSI_PRODUCTION_MAX_SNAPSHOT_COUNT
    estimated_output_payload_within_default_guard =
        estimated_field_payload_bytes <= NATIVE_RESOLVED_FSI_PRODUCTION_MAX_OUTPUT_BYTES
    required_override_flags = String[]
    snapshot_count_within_default_guard || push!(required_override_flags, "allow_many_snapshots")
    estimated_output_payload_within_default_guard || push!(required_override_flags, "allow_large_output")
    return (
        estimated_field_payload_bytes=estimated_field_payload_bytes,
        snapshot_count_within_default_guard=snapshot_count_within_default_guard,
        estimated_output_payload_within_default_guard=estimated_output_payload_within_default_guard,
        required_override_flags=required_override_flags,
    )
end

function native_resolved_fsi_partitioned_wall_stability_status(spec::NativeResolvedFSIPartitionedProductionSpec)
    params = Params(
        severity=spec.case_spec.severity_percent,
        tfinal=spec.tfinal_s,
        initial_condition=GeometryRestIC(),
    )
    wall_stiffness_c0_dyn_cm3 = canic_membrane_c0(params; reference_radius=params.rmax)
    wall_mass_g_cm2 = spec.wall_density_g_cm3 * params.wall_h
    explicit_dt_limit_s = wall_mass_g_cm2 > 0.0 && wall_stiffness_c0_dyn_cm3 > 0.0 ?
                          1.9 * sqrt(wall_mass_g_cm2 / wall_stiffness_c0_dyn_cm3) : NaN
    oscillator_guard = isfinite(explicit_dt_limit_s) && spec.dt_s <= explicit_dt_limit_s ?
                       "explicit_membrane_oscillator_dt_guard_pass" :
                       "explicit_membrane_oscillator_dt_guard_fail"
    common_status =
        "$(oscillator_guard); dt_s=$(spec.dt_s); explicit_stability_dt_limit_s=$(explicit_dt_limit_s); " *
        "wall_mass_g_cm2=$(wall_mass_g_cm2); wall_stiffness_c0_dyn_cm3=$(wall_stiffness_c0_dyn_cm3)"
    if spec.inlet_outlet_boundary_mode === :poiseuille_inlet_zero_outlet_stress_section41
        known_probe_status =
            spec.case_spec.case_id === :sev23 &&
            spec.resolution.axial == 80 &&
            spec.resolution.radial == 4 &&
            spec.resolution.angular == 24 &&
            isapprox(spec.dt_s, 1.0e-4; atol=0.0, rtol=1.0e-12) &&
            isapprox(spec.tfinal_s, 1.0e-4; atol=0.0, rtol=1.0e-12) ?
            "sev23_preproduction_mesh_exact_boundary_probe_mesh80x4x24_tfinal0p0001_planned: finite_fields=pending_artifact_review; positive_radii_tets=pending_artifact_review; pressure_normalization=pending_artifact_review; importer_round_trip=pending_artifact_review; coupling_status=pending_execution; stationary wall-on-deformed-geometry handoff only; not paper-grade Section 4.1 parity, moving-wall ALE validation, or production-scale all-case validation" :
            spec.case_spec.case_id === :sev23 &&
            isapprox(spec.dt_s, 1.0e-4; atol=0.0, rtol=1.0e-12) ?
            "sev23_development_exact_boundary_artifact_gate_passed_tfinal0p01: finite fields, positive radii, positive tetrahedra, direct wall-pressure sampling, and sidecars observed with stationary wall-on-deformed-geometry handoff; one-iteration coupling remains bounded evidence, not production/preproduction validation" :
            "pressure_load_stability_requires_execution_gate"
        return "$(common_status); $(known_probe_status); dry-run does not certify wall-pressure/load stability"
    end
    return "$(common_status); local pressure-drop smoke loading, not exact Section 4.1 wall-stability evidence"
end

function native_resolved_fsi_production_plan_status(case_spec, production_spec, boundary_status::NamedTuple)
    if production_spec.inlet_outlet_boundary_mode === :poiseuille_inlet_zero_outlet_stress_section41
        return "Section 4.1 native production plan for $(case_spec.paper_label) through T=$(last(production_spec.snapshot_times_s)) s; production runner support advances the exact Poiseuille inlet / zero-outlet-stress boundary mode through the coarse partitioned smoke-scale snapshot harness as smoke-scale/operator-readiness evidence only; boundary_mode=$(boundary_status.boundary_mode); section41_boundary_status=$(boundary_status.section41_boundary_status); this is not a paper-grade reproduction, validated Section 4.1 parity result, or monolithic ALE solve"
    end
    return "Section 4.1 native production plan for $(case_spec.paper_label) through T=$(last(production_spec.snapshot_times_s)) s; production runner support advances one coarse state-carrying partitioned native FSI snapshot series for the requested schedule using local pressure-drop smoke inlet/outlet loading, while the legacy workflow_spec remains schema-only; boundary_mode=$(boundary_status.boundary_mode); section41_boundary_status=$(boundary_status.section41_boundary_status); this is not a paper-grade reproduction or monolithic ALE solve"
end

function native_resolved_fsi_partitioned_production_dry_run_status(
    spec::NativeResolvedFSIPartitionedProductionSpec;
    layout_status::AbstractString,
    override_status::AbstractString,
    imported_status::AbstractString,
    boundary_status::NamedTuple,
    pressure_nullspace_status::AbstractString,
    wall_stability_status::AbstractString,
)
    execution_status =
        spec.inlet_outlet_boundary_mode === :poiseuille_inlet_zero_outlet_stress_section41 ?
        "production execution is available only through explicit production specs and remains smoke-scale/operator-readiness evidence only, not paper-grade native resolved-FSI Section 4.1 reproduction" :
        "production execution remains opt-in through explicit production specs and output-volume overrides"
    return "dry-run ready: no production solver executed and no files written; $(layout_status); $(override_status); $(imported_status); boundary_mode=$(boundary_status.boundary_mode); section41_boundary_status=$(boundary_status.section41_boundary_status); pressure_nullspace_status=$(pressure_nullspace_status); wall_stability_status=$(wall_stability_status); $(execution_status)"
end
