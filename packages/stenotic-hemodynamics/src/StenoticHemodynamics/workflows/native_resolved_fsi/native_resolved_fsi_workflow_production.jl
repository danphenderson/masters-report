const NATIVE_RESOLVED_FSI_PRODUCTION_DEFAULT_OUTPUT_ROOT =
    joinpath(DEFAULT_SIMULATION_OUTPUT_ROOT, "native-resolved-fsi-production")
const NATIVE_RESOLVED_FSI_PRODUCTION_MAX_SNAPSHOT_COUNT = 50
const NATIVE_RESOLVED_FSI_PRODUCTION_MAX_OUTPUT_BYTES = 1_073_741_824
const NATIVE_RESOLVED_FSI_PARTITIONED_PRODUCTION_DEFAULT_DT_S = 1.0e-4
const NATIVE_RESOLVED_FSI_PARTITIONED_PRODUCTION_DEFAULT_PICARD_ITERATION_COUNT = 8
const NATIVE_RESOLVED_FSI_PARTITIONED_PRODUCTION_DEFAULT_PICARD_TOLERANCE = 1.0e-8
const NATIVE_RESOLVED_FSI_PARTITIONED_PRODUCTION_DEFAULT_WALL_DENSITY_G_CM3 = 1.0
const NATIVE_RESOLVED_FSI_PARTITIONED_PRODUCTION_DEFAULT_WALL_DAMPING_G_CM2_S = 0.0
const NATIVE_RESOLVED_FSI_PRODUCTION_STIFFNESS_POLICIES = (:canic_membrane_c0,)
const NATIVE_RESOLVED_FSI_PRODUCTION_REFERENCE_RADIUS_POLICIES = (:params_rmax,)
const NATIVE_RESOLVED_FSI_PRODUCTION_INLET_OUTLET_BOUNDARY_MODES = (
    :pressure_drop_weak_inlet_outlet_gauge_smoke,
    :poiseuille_inlet_zero_outlet_stress_section41,
)
const NATIVE_RESOLVED_FSI_PRODUCTION_DEFAULT_INLET_OUTLET_BOUNDARY_MODE =
    :pressure_drop_weak_inlet_outlet_gauge_smoke
const NATIVE_RESOLVED_FSI_PRODUCTION_SECTION41_INLET_UMAX_CM_S = 45.0

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
    inlet_umax > 0.0 ||
        throw(ArgumentError("native resolved-FSI exact Section 4.1 boundary status inlet_umax_cm_s must be positive"))
    inlet_condition_status = isapprox(
        inlet_umax,
        NATIVE_RESOLVED_FSI_PRODUCTION_SECTION41_INLET_UMAX_CM_S;
        atol=0.0,
        rtol=1.0e-12,
    ) ? "poiseuille_profile_umax_45_cm_s" : "poiseuille_profile_custom_umax_cm_s"
    return (
        boundary_mode=string(boundary_mode),
        boundary_mode_class="exact_section41",
        inlet_condition_status=inlet_condition_status,
        outlet_condition_status="zero_outlet_stress_natural_traction",
        pressure_gauge_status="post_sampling_outlet_mean_normalization_not_gridap_nullspace_constraint",
        section41_boundary_status="implemented_smoke_validated",
        boundary_status="exact Section 4.1 boundary mode selected; low-level Gridap and partitioned production smoke-scale threading evidence are present, but this is not paper-grade numerical reproduction or Section 4.1 parity",
    )
end

function native_resolved_fsi_boundary_equivalence_status(boundary_status::NamedTuple)
    if boundary_status.boundary_mode == string(:poiseuille_inlet_zero_outlet_stress_section41)
        return "exact_section41_boundary_mode_selected_smoke_validated; production artifacts may record exact-mode smoke-scale operator evidence, but parity ready is still artifact/operator readiness, not paper-grade reproduction"
    end
    return "not_exact_section41_boundary_equivalence; parity ready is artifact/operator readiness only"
end

function native_resolved_fsi_wall_pressure_projection_status(boundary_mode::Union{Symbol,AbstractString})
    mode = native_resolved_fsi_production_boundary_mode(boundary_mode)
    if mode === :poiseuille_inlet_zero_outlet_stress_section41
        return "direct_finite_wall_pressure_sampling_required; pressure_drop_resistance_fallback_disabled; wall_pressure_profile_outlet_gauged_before_membrane_update"
    end
    return "direct_wall_pressure_sampling_with_pressure_drop_resistance_fallback_if_needed; wall_pressure_profile_outlet_gauged_before_membrane_update"
end

"""
    NativeResolvedFSIPartitionedProductionSpec(; kwargs...)

Production-oriented control and output policy for native partitioned
resolved-FSI generation. This spec validates Section 4.1 case selection,
snapshot timing, output volume, Picard controls, and membrane/coupling policy
inputs for later production runners. It does not by itself claim a stronger
numerical method, production numerical parity, or monolithic ALE coupling.
"""
struct NativeResolvedFSIPartitionedProductionSpec
    case_spec::NativeResolvedFSICaseSpec
    resolution::NativeResolvedFSIMeshResolution
    output_root::String
    dt_s::Float64
    tfinal_s::Float64
    snapshot_times_s::Vector{Float64}
    time_atol::Float64
    overwrite::Bool
    inlet_outlet_boundary_mode::Symbol
    inlet_umax_cm_s::Float64
    pressure_drop_dyn_cm2::Float64
    picard_iteration_count::Int
    picard_tolerance::Float64
    wall_density_g_cm3::Float64
    wall_damping_g_cm2_s::Float64
    wall_stiffness_policy::Symbol
    wall_reference_radius_policy::Symbol
    coupling_iteration_count::Int
    coupling_tolerance::Float64
    coupling_under_relaxation::Float64
    allow_many_snapshots::Bool
    allow_large_output::Bool
end

function NativeResolvedFSIPartitionedProductionSpec(;
    case_id::Union{Symbol,AbstractString,Real} = :sev23,
    resolution::NativeResolvedFSIMeshResolution = NativeResolvedFSIMeshResolution(),
    output_root::AbstractString = "",
    dt_s::Real = NATIVE_RESOLVED_FSI_PARTITIONED_PRODUCTION_DEFAULT_DT_S,
    tfinal_s::Real = NATIVE_RESOLVED_FSI_DEFAULT_TIME_S,
    snapshot_times_s = (tfinal_s,),
    time_atol::Real = 1.0e-12,
    overwrite::Bool = false,
    inlet_outlet_boundary_mode::Union{Symbol,AbstractString} = NATIVE_RESOLVED_FSI_PRODUCTION_DEFAULT_INLET_OUTLET_BOUNDARY_MODE,
    inlet_umax_cm_s::Real = NATIVE_RESOLVED_FSI_PRODUCTION_SECTION41_INLET_UMAX_CM_S,
    pressure_drop_dyn_cm2::Real = 40.0,
    picard_iteration_count::Integer = NATIVE_RESOLVED_FSI_PARTITIONED_PRODUCTION_DEFAULT_PICARD_ITERATION_COUNT,
    picard_tolerance::Real = NATIVE_RESOLVED_FSI_PARTITIONED_PRODUCTION_DEFAULT_PICARD_TOLERANCE,
    wall_density_g_cm3::Real = NATIVE_RESOLVED_FSI_PARTITIONED_PRODUCTION_DEFAULT_WALL_DENSITY_G_CM3,
    wall_damping_g_cm2_s::Real = NATIVE_RESOLVED_FSI_PARTITIONED_PRODUCTION_DEFAULT_WALL_DAMPING_G_CM2_S,
    wall_stiffness_policy::Union{Symbol,AbstractString} = :canic_membrane_c0,
    wall_reference_radius_policy::Union{Symbol,AbstractString} = :params_rmax,
    coupling_iteration_count::Integer = 1,
    coupling_tolerance::Real = 1.0e-8,
    coupling_under_relaxation::Real = 1.0,
    allow_many_snapshots::Bool = false,
    allow_large_output::Bool = false,
)
    return validate(NativeResolvedFSIPartitionedProductionSpec(
        native_resolved_fsi_case_spec(case_id),
        resolution,
        String(output_root),
        Float64(dt_s),
        Float64(tfinal_s),
        Float64[Float64(time_s) for time_s in snapshot_times_s],
        Float64(time_atol),
        overwrite,
        native_resolved_fsi_production_boundary_mode(inlet_outlet_boundary_mode),
        Float64(inlet_umax_cm_s),
        Float64(pressure_drop_dyn_cm2),
        Int(picard_iteration_count),
        Float64(picard_tolerance),
        Float64(wall_density_g_cm3),
        Float64(wall_damping_g_cm2_s),
        Symbol(wall_stiffness_policy),
        Symbol(wall_reference_radius_policy),
        Int(coupling_iteration_count),
        Float64(coupling_tolerance),
        Float64(coupling_under_relaxation),
        allow_many_snapshots,
        allow_large_output,
    ))
end

native_resolved_fsi_partitioned_production_spec(; kwargs...) =
    NativeResolvedFSIPartitionedProductionSpec(; kwargs...)

function validate(spec::NativeResolvedFSIPartitionedProductionSpec)
    isfinite(spec.dt_s) || throw(ArgumentError("native resolved-FSI partitioned production dt_s must be finite"))
    spec.dt_s > 0.0 || throw(ArgumentError("native resolved-FSI partitioned production dt_s must be positive"))
    isfinite(spec.tfinal_s) || throw(ArgumentError("native resolved-FSI partitioned production tfinal_s must be finite"))
    spec.tfinal_s > 0.0 || throw(ArgumentError("native resolved-FSI partitioned production tfinal_s must be positive"))
    isfinite(spec.time_atol) || throw(ArgumentError("native resolved-FSI partitioned production time_atol must be finite"))
    spec.time_atol > 0.0 || throw(ArgumentError("native resolved-FSI partitioned production time_atol must be positive"))
    isempty(spec.snapshot_times_s) &&
        throw(ArgumentError("native resolved-FSI partitioned production snapshot_times_s must not be empty"))
    all(isfinite, spec.snapshot_times_s) ||
        throw(ArgumentError("native resolved-FSI partitioned production snapshot_times_s must be finite"))
    for time_s in spec.snapshot_times_s
        0.0 <= time_s <= spec.tfinal_s || throw(ArgumentError(
            "native resolved-FSI partitioned production snapshot time $(time_s) lies outside [0, $(spec.tfinal_s)]",
        ))
    end
    for index in 2:length(spec.snapshot_times_s)
        spec.snapshot_times_s[index] > spec.snapshot_times_s[index - 1] || throw(ArgumentError(
            "native resolved-FSI partitioned production snapshot_times_s must be strictly increasing without duplicates",
        ))
    end
    length(spec.snapshot_times_s) <= NATIVE_RESOLVED_FSI_PRODUCTION_MAX_SNAPSHOT_COUNT ||
        spec.allow_many_snapshots || throw(ArgumentError(
            "native resolved-FSI partitioned production requested $(length(spec.snapshot_times_s)) snapshots; set allow_many_snapshots=true to exceed $(NATIVE_RESOLVED_FSI_PRODUCTION_MAX_SNAPSHOT_COUNT)",
        ))
    native_resolved_fsi_production_boundary_mode(spec.inlet_outlet_boundary_mode)
    isfinite(spec.inlet_umax_cm_s) ||
        throw(ArgumentError("native resolved-FSI partitioned production inlet_umax_cm_s must be finite"))
    if spec.inlet_outlet_boundary_mode === :poiseuille_inlet_zero_outlet_stress_section41
        spec.inlet_umax_cm_s > 0.0 ||
            throw(ArgumentError("native resolved-FSI partitioned production inlet_umax_cm_s must be positive for exact Section 4.1 mode"))
    end
    isfinite(spec.pressure_drop_dyn_cm2) ||
        throw(ArgumentError("native resolved-FSI partitioned production pressure_drop_dyn_cm2 must be finite"))
    if spec.inlet_outlet_boundary_mode === :pressure_drop_weak_inlet_outlet_gauge_smoke
        spec.pressure_drop_dyn_cm2 > 0.0 ||
            throw(ArgumentError("native resolved-FSI partitioned production pressure_drop_dyn_cm2 must be positive"))
    end
    spec.picard_iteration_count > 0 ||
        throw(ArgumentError("native resolved-FSI partitioned production picard_iteration_count must be positive"))
    isfinite(spec.picard_tolerance) ||
        throw(ArgumentError("native resolved-FSI partitioned production picard_tolerance must be finite"))
    spec.picard_tolerance > 0.0 ||
        throw(ArgumentError("native resolved-FSI partitioned production picard_tolerance must be positive"))
    isfinite(spec.wall_density_g_cm3) ||
        throw(ArgumentError("native resolved-FSI partitioned production wall_density_g_cm3 must be finite"))
    spec.wall_density_g_cm3 > 0.0 ||
        throw(ArgumentError("native resolved-FSI partitioned production wall_density_g_cm3 must be positive"))
    isfinite(spec.wall_damping_g_cm2_s) ||
        throw(ArgumentError("native resolved-FSI partitioned production wall_damping_g_cm2_s must be finite"))
    spec.wall_damping_g_cm2_s >= 0.0 ||
        throw(ArgumentError("native resolved-FSI partitioned production wall_damping_g_cm2_s must be nonnegative"))
    spec.wall_stiffness_policy in NATIVE_RESOLVED_FSI_PRODUCTION_STIFFNESS_POLICIES || throw(ArgumentError(
        "native resolved-FSI partitioned production wall_stiffness_policy must be one of $(NATIVE_RESOLVED_FSI_PRODUCTION_STIFFNESS_POLICIES)",
    ))
    spec.wall_reference_radius_policy in NATIVE_RESOLVED_FSI_PRODUCTION_REFERENCE_RADIUS_POLICIES || throw(ArgumentError(
        "native resolved-FSI partitioned production wall_reference_radius_policy must be one of $(NATIVE_RESOLVED_FSI_PRODUCTION_REFERENCE_RADIUS_POLICIES)",
    ))
    spec.coupling_iteration_count > 0 ||
        throw(ArgumentError("native resolved-FSI partitioned production coupling_iteration_count must be positive"))
    isfinite(spec.coupling_tolerance) ||
        throw(ArgumentError("native resolved-FSI partitioned production coupling_tolerance must be finite"))
    spec.coupling_tolerance > 0.0 ||
        throw(ArgumentError("native resolved-FSI partitioned production coupling_tolerance must be positive"))
    isfinite(spec.coupling_under_relaxation) ||
        throw(ArgumentError("native resolved-FSI partitioned production coupling_under_relaxation must be finite"))
    0.0 < spec.coupling_under_relaxation <= 1.0 ||
        throw(ArgumentError("native resolved-FSI partitioned production coupling_under_relaxation must lie in (0, 1]"))

    estimated_bytes = native_resolved_fsi_partitioned_production_estimated_field_payload_bytes(spec)
    estimated_bytes <= NATIVE_RESOLVED_FSI_PRODUCTION_MAX_OUTPUT_BYTES ||
        spec.allow_large_output || throw(ArgumentError(
            "native resolved-FSI partitioned production estimated raw field payload $(estimated_bytes) bytes exceeds the $(NATIVE_RESOLVED_FSI_PRODUCTION_MAX_OUTPUT_BYTES)-byte cap; set allow_large_output=true to override",
        ))
    return spec
end

default_native_resolved_fsi_partitioned_production_output_root() =
    NATIVE_RESOLVED_FSI_PRODUCTION_DEFAULT_OUTPUT_ROOT

"""
    default_native_resolved_fsi_partitioned_production_output_dir(spec) -> String

Return the deterministic ignored scratch root for one native partitioned
production policy. This is an output contract for later production runners; it
does not imply production numerical parity or monolithic ALE coupling.
"""
function default_native_resolved_fsi_partitioned_production_output_dir(
    spec::NativeResolvedFSIPartitionedProductionSpec,
)
    root = isempty(spec.output_root) ? default_native_resolved_fsi_partitioned_production_output_root() : spec.output_root
    resolution = spec.resolution
    mesh_token = "$(resolution.axial)x$(resolution.radial)x$(resolution.angular)"
    snapshot_token = if length(spec.snapshot_times_s) == 1
        "snapshot-t$(path_token(only(spec.snapshot_times_s)))"
    else
        "snapshots-n$(length(spec.snapshot_times_s))-t$(path_token(first(spec.snapshot_times_s)))-to-t$(path_token(last(spec.snapshot_times_s)))"
    end
    boundary_token = if spec.inlet_outlet_boundary_mode === :poiseuille_inlet_zero_outlet_stress_section41
        "boundary-$(string(spec.inlet_outlet_boundary_mode))-umax$(path_token(spec.inlet_umax_cm_s))"
    else
        "boundary-$(string(spec.inlet_outlet_boundary_mode))"
    end
    return joinpath(
        root,
        string(spec.case_spec.case_id),
        mesh_token,
        boundary_token,
        "partitioned-production-dt$(path_token(spec.dt_s))-tfinal$(path_token(spec.tfinal_s))",
        snapshot_token,
    )
end

function native_resolved_fsi_partitioned_production_estimated_field_payload_bytes(
    spec::NativeResolvedFSIPartitionedProductionSpec,
)
    node_count =
        (BigInt(spec.resolution.axial) + 1) *
        (BigInt(1) + BigInt(spec.resolution.radial) * BigInt(spec.resolution.angular))
    return node_count * BigInt(7 * sizeof(Float64)) * BigInt(length(spec.snapshot_times_s))
end

"""
    NativeResolvedFSIPartitionedProductionResult

Wrapper returned by [`run_native_resolved_fsi_partitioned_production`](@ref).
It keeps the production control spec separate from the final carried
partitioned solver result and records bounded method/output/diagnostic/restart
statuses. The diagnostics and restart sidecars describe a state-carrying
partitioned snapshot series; they do not imply persisted restart/resume support,
validated Section 4.1 reproduction, or monolithic ALE FSI coupling.
"""
struct NativeResolvedFSIPartitionedProductionResult
    spec::NativeResolvedFSIPartitionedProductionSpec
    smoke_spec
    smoke_result
    output_dir::String
    manifest_csv::String
    diagnostics_csv::String
    restart_metadata_json::String
    snapshot_results::Vector{NamedTuple}
    diagnostic_rows::Vector{NamedTuple}
    restart_metadata::Dict{String,Any}
    saved_time_s::Float64
    snapshot_times_s::Vector{Float64}
    output_status::NativeResolvedFSIWorkflowStatus
    method_status::NativeResolvedFSIWorkflowStatus
    diagnostics_status::NativeResolvedFSIWorkflowStatus
    restart_status::NativeResolvedFSIWorkflowStatus
end

"""
    NativeResolvedFSIProductionWorkflowPlan

One reproducible Section 4.1 native workflow plan. The contained
`workflow_spec` preserves the current schema-only bundle contract, while
`production_spec` records the partitioned production controls and output policy
that later runner lanes will execute. This plan does not claim production
numerical parity or monolithic ALE coupling.
"""
struct NativeResolvedFSIProductionWorkflowPlan
    case_spec::NativeResolvedFSICaseSpec
    workflow_spec::NativeResolvedFSIWorkflowSpec
    status::String
    production_spec::NativeResolvedFSIPartitionedProductionSpec
end

"""
    NativeResolvedFSIProductionDryRunPlan

Side-effect-free Section 4.1 production dry-run record. It resolves the native
production bundle paths, sidecar paths, estimated mesh/output size, and planned
imported parity case without running the production solver or writing files.
The guard fields report whether the plan fits the default production limits and
which explicit override flags are needed before a larger run is attempted.
"""
struct NativeResolvedFSIProductionDryRunPlan
    workflow_plan::NativeResolvedFSIProductionWorkflowPlan
    case_id::Symbol
    mesh_resolution::NativeResolvedFSIMeshResolution
    expected_node_count::Int
    expected_tetrahedron_count::Int
    snapshot_times_s::Vector{Float64}
    estimated_field_payload_bytes::BigInt
    snapshot_count_within_default_guard::Bool
    estimated_output_payload_within_default_guard::Bool
    required_override_flags::Vector{String}
    output_dir::String
    snapshot_output_dirs::Vector{String}
    manifest_csv::String
    diagnostics_csv::String
    restart_metadata_json::String
    parity_observations_csv::String
    parity_summary_csv::String
    boundary_mode::String
    boundary_mode_class::String
    inlet_condition_status::String
    outlet_condition_status::String
    pressure_gauge_status::String
    section41_boundary_status::String
    boundary_status::String
    boundary_equivalence_status::String
    imported_case
    imported_available::Bool
    status::String
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

function NativeResolvedFSIProductionWorkflowPlan(
    case_spec::NativeResolvedFSICaseSpec,
    workflow_spec::NativeResolvedFSIWorkflowSpec,
    status::AbstractString,
)
    output_root = isempty(workflow_spec.output_dir) ? "" : dirname(workflow_spec.output_dir)
    production_spec = NativeResolvedFSIPartitionedProductionSpec(
        case_id=case_spec.case_id,
        resolution=workflow_spec.resolution,
        output_root=output_root,
        tfinal_s=workflow_spec.output_time_s,
        snapshot_times_s=(workflow_spec.output_time_s,),
        time_atol=workflow_spec.time_atol,
        overwrite=workflow_spec.overwrite,
        inlet_outlet_boundary_mode=NATIVE_RESOLVED_FSI_PRODUCTION_DEFAULT_INLET_OUTLET_BOUNDARY_MODE,
        inlet_umax_cm_s=workflow_spec.inlet_umax_cm_s,
        pressure_drop_dyn_cm2=workflow_spec.pressure_drop_dyn_cm2,
    )
    return NativeResolvedFSIProductionWorkflowPlan(case_spec, workflow_spec, String(status), production_spec)
end

"""
    native_resolved_fsi_production_workflow_plans(; kwargs...)

Build deterministic Section 4.1 native workflow plans for `sev23`, `sev40`,
and `sev50`. The plans keep the benchmark case/time contracts and production
output policy explicit while making clear that this lane adds controls rather
than a stronger numerical method by itself.
"""
function native_resolved_fsi_production_workflow_plans(;
    case_ids = SECTION41_NATIVE_CASE_IDS,
    resolution::NativeResolvedFSIMeshResolution = NativeResolvedFSIMeshResolution(),
    output_root::AbstractString = "",
    output_time_s::Real = NATIVE_RESOLVED_FSI_DEFAULT_TIME_S,
    dt_s::Real = NATIVE_RESOLVED_FSI_PARTITIONED_PRODUCTION_DEFAULT_DT_S,
    tfinal_s::Real = output_time_s,
    snapshot_times_s = (tfinal_s,),
    time_atol::Real = 1.0e-12,
    overwrite::Bool = false,
    inlet_outlet_boundary_mode::Union{Symbol,AbstractString} = NATIVE_RESOLVED_FSI_PRODUCTION_DEFAULT_INLET_OUTLET_BOUNDARY_MODE,
    inlet_umax_cm_s::Real = 45.0,
    pressure_drop_dyn_cm2::Real = 40.0,
    picard_iteration_count::Integer = NATIVE_RESOLVED_FSI_PARTITIONED_PRODUCTION_DEFAULT_PICARD_ITERATION_COUNT,
    picard_tolerance::Real = NATIVE_RESOLVED_FSI_PARTITIONED_PRODUCTION_DEFAULT_PICARD_TOLERANCE,
    wall_density_g_cm3::Real = NATIVE_RESOLVED_FSI_PARTITIONED_PRODUCTION_DEFAULT_WALL_DENSITY_G_CM3,
    wall_damping_g_cm2_s::Real = NATIVE_RESOLVED_FSI_PARTITIONED_PRODUCTION_DEFAULT_WALL_DAMPING_G_CM2_S,
    wall_stiffness_policy::Union{Symbol,AbstractString} = :canic_membrane_c0,
    wall_reference_radius_policy::Union{Symbol,AbstractString} = :params_rmax,
    coupling_iteration_count::Integer = 1,
    coupling_tolerance::Real = 1.0e-8,
    coupling_under_relaxation::Real = 1.0,
    allow_many_snapshots::Bool = false,
    allow_large_output::Bool = false,
    displacement_mode::Union{Symbol,AbstractString} = :synthetic_radial_lift,
    synthetic_lift_amplitude_cm::Real = 0.002,
)
    root = String(output_root)
    mode = native_resolved_fsi_displacement_mode(displacement_mode)
    plans = NativeResolvedFSIProductionWorkflowPlan[]
    for case_id in case_ids
        case_spec = native_resolved_fsi_case_spec(case_id)
        production_spec = NativeResolvedFSIPartitionedProductionSpec(
            case_id=case_spec.case_id,
            resolution=resolution,
            output_root=root,
            dt_s=dt_s,
            tfinal_s=tfinal_s,
            snapshot_times_s=snapshot_times_s,
            time_atol=time_atol,
            overwrite=overwrite,
            inlet_outlet_boundary_mode=inlet_outlet_boundary_mode,
            inlet_umax_cm_s=inlet_umax_cm_s,
            pressure_drop_dyn_cm2=pressure_drop_dyn_cm2,
            picard_iteration_count=picard_iteration_count,
            picard_tolerance=picard_tolerance,
            wall_density_g_cm3=wall_density_g_cm3,
            wall_damping_g_cm2_s=wall_damping_g_cm2_s,
            wall_stiffness_policy=wall_stiffness_policy,
            wall_reference_radius_policy=wall_reference_radius_policy,
            coupling_iteration_count=coupling_iteration_count,
            coupling_tolerance=coupling_tolerance,
            coupling_under_relaxation=coupling_under_relaxation,
            allow_many_snapshots=allow_many_snapshots,
            allow_large_output=allow_large_output,
        )
        workflow_spec = NativeResolvedFSIWorkflowSpec(
            case_id=case_spec.case_id,
            resolution=resolution,
            output_dir=isempty(root) ? "" : joinpath(root, string(case_spec.case_id)),
            output_time_s=last(production_spec.snapshot_times_s),
            time_atol=time_atol,
            overwrite=overwrite,
            inlet_umax_cm_s=inlet_umax_cm_s,
            pressure_drop_dyn_cm2=pressure_drop_dyn_cm2,
            displacement_mode=mode,
            synthetic_lift_amplitude_cm=synthetic_lift_amplitude_cm,
        )
        boundary_status = native_resolved_fsi_boundary_status_fields(
            production_spec.inlet_outlet_boundary_mode;
            inlet_umax_cm_s=production_spec.inlet_umax_cm_s,
        )
        status = if production_spec.inlet_outlet_boundary_mode === :poiseuille_inlet_zero_outlet_stress_section41
            "Section 4.1 native production plan for $(case_spec.paper_label) through T=$(last(production_spec.snapshot_times_s)) s; production runner support advances the exact inlet/outlet boundary mode through the coarse partitioned smoke-scale snapshot harness; boundary_mode=$(boundary_status.boundary_mode); section41_boundary_status=$(boundary_status.section41_boundary_status); this is not a paper-grade reproduction, validated Section 4.1 parity result, or monolithic ALE solve"
        else
            "Section 4.1 native production plan for $(case_spec.paper_label) through T=$(last(production_spec.snapshot_times_s)) s; production runner support advances one coarse state-carrying partitioned native FSI snapshot series for the requested schedule using local pressure-drop smoke inlet/outlet loading, while the legacy workflow_spec remains schema-only; boundary_mode=$(boundary_status.boundary_mode); section41_boundary_status=$(boundary_status.section41_boundary_status); this is not a paper-grade reproduction or monolithic ALE solve"
        end
        push!(plans, NativeResolvedFSIProductionWorkflowPlan(case_spec, workflow_spec, status, production_spec))
    end
    return plans
end

"""
    native_resolved_fsi_partitioned_production_dry_run(plan; imported_data_root=default_resolved3d_data_root())

Resolve the output and parity artifact contract for one Section 4.1 production
workflow plan without running the native production solver and without writing
any files. High-resolution execution remains gated by explicit production
specs and their normal output-volume validation/overrides.
"""
function native_resolved_fsi_partitioned_production_dry_run(
    plan::NativeResolvedFSIProductionWorkflowPlan;
    imported_data_root::AbstractString = default_resolved3d_data_root(),
)
    spec = validate(plan.production_spec)
    resolution = spec.resolution
    output_dir = default_native_resolved_fsi_partitioned_production_output_dir(spec)
    snapshot_output_dirs = if length(spec.snapshot_times_s) == 1
        String[output_dir]
    else
        String[joinpath(output_dir, "snapshot-t$(path_token(snapshot_time_s))") for snapshot_time_s in spec.snapshot_times_s]
    end
    parity_plan = only(native_resolved_fsi_production_parity_plans(
        workflow_plans=[plan],
        imported_data_root=String(imported_data_root),
    ))
    expected_node_count = (resolution.axial + 1) * (1 + resolution.radial * resolution.angular)
    expected_tetrahedron_count = 3 * resolution.axial * resolution.angular * (2 * resolution.radial - 1)
    guard_report = native_resolved_fsi_partitioned_production_default_guard_report(spec)
    boundary_status = native_resolved_fsi_boundary_status_fields(
        spec.inlet_outlet_boundary_mode;
        inlet_umax_cm_s=spec.inlet_umax_cm_s,
    )
    boundary_equivalence_status = native_resolved_fsi_boundary_equivalence_status(boundary_status)
    override_status = isempty(guard_report.required_override_flags) ?
        "default guards satisfied; required override flags: none" :
        "default guards would block production without required override flags: $(join(guard_report.required_override_flags, ", "))"
    imported_status = parity_plan.imported_available ? "imported bundle available" : "imported bundle expected-skip"
    execution_status =
        spec.inlet_outlet_boundary_mode === :poiseuille_inlet_zero_outlet_stress_section41 ?
        "production execution is available only through explicit production specs and remains smoke-scale/operator-readiness evidence, not paper-grade reproduction" :
        "production execution remains opt-in through explicit production specs and output-volume overrides"
    status = "dry-run ready: no production solver executed and no files written; $(override_status); $(imported_status); boundary_mode=$(boundary_status.boundary_mode); section41_boundary_status=$(boundary_status.section41_boundary_status); $(execution_status)"
    return NativeResolvedFSIProductionDryRunPlan(
        plan,
        spec.case_spec.case_id,
        resolution,
        expected_node_count,
        expected_tetrahedron_count,
        copy(spec.snapshot_times_s),
        guard_report.estimated_field_payload_bytes,
        guard_report.snapshot_count_within_default_guard,
        guard_report.estimated_output_payload_within_default_guard,
        copy(guard_report.required_override_flags),
        output_dir,
        snapshot_output_dirs,
        joinpath(output_dir, "snapshot_manifest.csv"),
        joinpath(output_dir, "snapshot_diagnostics.csv"),
        joinpath(output_dir, "restart_metadata.json"),
        native_resolved_fsi_production_parity_observations_csv(parity_plan),
        native_resolved_fsi_production_parity_summary_csv(parity_plan),
        boundary_status.boundary_mode,
        boundary_status.boundary_mode_class,
        boundary_status.inlet_condition_status,
        boundary_status.outlet_condition_status,
        boundary_status.pressure_gauge_status,
        boundary_status.section41_boundary_status,
        boundary_status.boundary_status,
        boundary_equivalence_status,
        parity_plan.imported_case,
        parity_plan.imported_available,
        status,
    )
end

"""
    run_native_resolved_fsi_partitioned_production(spec)

Run the production-depth partitioned native snapshot harness by advancing one
coarse partitioned state through each requested positive snapshot time. The
driver carries reduced wall displacement, wall velocity, current radii, wall
pressure, coupling residual history, and fluid free-DOF state between steps.
It writes one normal resolved-3D bundle per snapshot plus a compact CSV
manifest, per-snapshot diagnostics CSV, and restart-identification metadata.
Persisted external resume remains explicitly deferred.
"""
function run_native_resolved_fsi_partitioned_production(spec::NativeResolvedFSIPartitionedProductionSpec)
    function validate_runner_scope(local_spec::NativeResolvedFSIPartitionedProductionSpec)
        if any(time_s -> time_s <= 0.0, local_spec.snapshot_times_s)
            throw(ArgumentError(
                "native resolved-FSI partitioned production runner requires positive snapshot times; t=0 initial-condition bundle output is not implemented",
            ))
        end
        return local_spec
    end

    function snapshot_output_dir(local_spec::NativeResolvedFSIPartitionedProductionSpec, snapshot_time_s::Float64)
        output_dir = default_native_resolved_fsi_partitioned_production_output_dir(local_spec)
        length(local_spec.snapshot_times_s) == 1 && return output_dir
        return joinpath(output_dir, "snapshot-t$(path_token(snapshot_time_s))")
    end

    manifest_path(local_spec::NativeResolvedFSIPartitionedProductionSpec) =
        joinpath(default_native_resolved_fsi_partitioned_production_output_dir(local_spec), "snapshot_manifest.csv")

    diagnostics_path(local_spec::NativeResolvedFSIPartitionedProductionSpec) =
        joinpath(default_native_resolved_fsi_partitioned_production_output_dir(local_spec), "snapshot_diagnostics.csv")

    restart_metadata_path(local_spec::NativeResolvedFSIPartitionedProductionSpec) =
        joinpath(default_native_resolved_fsi_partitioned_production_output_dir(local_spec), "restart_metadata.json")

    function production_spec_digest(local_spec::NativeResolvedFSIPartitionedProductionSpec)
        resolution = local_spec.resolution
        parts = String[
            string(local_spec.case_spec.case_id),
            string(resolution.axial),
            string(resolution.radial),
            string(resolution.angular),
            local_spec.output_root,
            string(local_spec.dt_s),
            string(local_spec.tfinal_s),
            join(string.(local_spec.snapshot_times_s), ","),
            string(local_spec.inlet_outlet_boundary_mode),
            string(local_spec.inlet_umax_cm_s),
            string(local_spec.pressure_drop_dyn_cm2),
            string(local_spec.picard_iteration_count),
            string(local_spec.picard_tolerance),
            string(local_spec.wall_density_g_cm3),
            string(local_spec.wall_damping_g_cm2_s),
            string(local_spec.wall_stiffness_policy),
            string(local_spec.wall_reference_radius_policy),
            string(local_spec.coupling_iteration_count),
            string(local_spec.coupling_tolerance),
            string(local_spec.coupling_under_relaxation),
        ]
        return bytes2hex(sha256(join(parts, "|")))[1:16]
    end

    function snapshot_production_spec(
        local_spec::NativeResolvedFSIPartitionedProductionSpec,
        snapshot_time_s::Float64,
    )
        return NativeResolvedFSIPartitionedProductionSpec(
            case_id=local_spec.case_spec.case_id,
            resolution=local_spec.resolution,
            output_root=local_spec.output_root,
            dt_s=local_spec.dt_s,
            tfinal_s=snapshot_time_s,
            snapshot_times_s=[snapshot_time_s],
            time_atol=local_spec.time_atol,
            overwrite=local_spec.overwrite,
            inlet_outlet_boundary_mode=local_spec.inlet_outlet_boundary_mode,
            inlet_umax_cm_s=local_spec.inlet_umax_cm_s,
            pressure_drop_dyn_cm2=local_spec.pressure_drop_dyn_cm2,
            picard_iteration_count=local_spec.picard_iteration_count,
            picard_tolerance=local_spec.picard_tolerance,
            wall_density_g_cm3=local_spec.wall_density_g_cm3,
            wall_damping_g_cm2_s=local_spec.wall_damping_g_cm2_s,
            wall_stiffness_policy=local_spec.wall_stiffness_policy,
            wall_reference_radius_policy=local_spec.wall_reference_radius_policy,
            coupling_iteration_count=local_spec.coupling_iteration_count,
            coupling_tolerance=local_spec.coupling_tolerance,
            coupling_under_relaxation=local_spec.coupling_under_relaxation,
            allow_large_output=local_spec.allow_large_output,
        )
    end

    function snapshot_smoke_spec(
        local_spec::NativeResolvedFSIPartitionedProductionSpec,
        snapshot_time_s::Float64,
        output_dir::String,
    )
        return NativeResolvedFSIPartitionedSmokeSpec(
            case_id=local_spec.case_spec.case_id,
            resolution=local_spec.resolution,
            output_dir=output_dir,
            dt_s=local_spec.dt_s,
            tfinal_s=snapshot_time_s,
            time_atol=local_spec.time_atol,
            overwrite=local_spec.overwrite,
            inlet_outlet_boundary_mode=local_spec.inlet_outlet_boundary_mode,
            inlet_umax_cm_s=local_spec.inlet_umax_cm_s,
            pressure_drop_dyn_cm2=local_spec.pressure_drop_dyn_cm2,
            picard_iteration_count=local_spec.picard_iteration_count,
            picard_tolerance=local_spec.picard_tolerance,
            wall_density_g_cm3=local_spec.wall_density_g_cm3,
            wall_damping_g_cm2_s=local_spec.wall_damping_g_cm2_s,
            coupling_iteration_count=local_spec.coupling_iteration_count,
            coupling_tolerance=local_spec.coupling_tolerance,
            coupling_under_relaxation=local_spec.coupling_under_relaxation,
        )
    end

    function snapshot_status(
        local_spec::NativeResolvedFSIPartitionedProductionSpec,
        snapshot_time_s::Float64,
        smoke_result,
    )
        ready = smoke_result.schema_status.ready &&
                smoke_result.geometry_status.ready &&
                smoke_result.time_status.ready &&
                smoke_result.field_status.ready &&
                smoke_result.post_update_fluid_refresh &&
                isapprox(smoke_result.saved_time_s, snapshot_time_s; atol=local_spec.time_atol)
        return NativeResolvedFSIWorkflowStatus(ready, ready ? "ready" : "failed")
    end

    function run_independent_snapshot(
        local_spec::NativeResolvedFSIPartitionedProductionSpec,
        snapshot_time_s::Float64,
        output_dir::String,
    )
        snapshot_spec = snapshot_production_spec(local_spec, snapshot_time_s)
        smoke_spec = snapshot_smoke_spec(local_spec, snapshot_time_s, output_dir)
        smoke_result = run_native_resolved_fsi_partitioned_smoke(smoke_spec)
        return (
            snapshot_time_s=snapshot_time_s,
            output_dir=output_dir,
            spec=snapshot_spec,
            smoke_spec=smoke_spec,
            smoke_result=smoke_result,
            provenance="independent_smoke_backed_snapshot",
            status=snapshot_status(local_spec, snapshot_time_s, smoke_result),
        )
    end

    function run_state_carrying_snapshots(local_spec::NativeResolvedFSIPartitionedProductionSpec)
        mesh = native_resolved_fsi_mesh(local_spec.case_spec, local_spec.resolution)
        native_resolved_fsi_smoke_validate_mesh(mesh)
        estimated_field_payload_bytes = native_resolved_fsi_smoke_estimated_field_payload_bytes(mesh)
        estimated_field_payload_bytes <= NATIVE_RESOLVED_FSI_SMOKE_MAX_OUTPUT_BYTES || throw(ArgumentError(
            "native resolved-FSI partitioned production estimated single-snapshot raw field payload $(estimated_field_payload_bytes) bytes exceeds the $(NATIVE_RESOLVED_FSI_SMOKE_MAX_OUTPUT_BYTES)-byte smoke cap",
        ))
        series_spec = snapshot_smoke_spec(
            local_spec,
            local_spec.tfinal_s,
            default_native_resolved_fsi_partitioned_production_output_dir(local_spec),
        )
        solve_results = native_resolved_fsi_solve_partitioned_snapshot_series(
            mesh,
            series_spec,
            local_spec.snapshot_times_s,
        )
        snapshot_results = NamedTuple[]
        for (index, snapshot_time_s) in enumerate(local_spec.snapshot_times_s)
            snapshot_dir = snapshot_output_dir(local_spec, snapshot_time_s)
            snapshot_spec = snapshot_production_spec(local_spec, snapshot_time_s)
            smoke_spec = snapshot_smoke_spec(local_spec, snapshot_time_s, snapshot_dir)
            smoke_result = native_resolved_fsi_partitioned_smoke_result(
                mesh,
                smoke_spec,
                solve_results[index];
                output_dir=snapshot_dir,
                saved_time_s=snapshot_time_s,
                estimated_field_payload_bytes=estimated_field_payload_bytes,
            )
            push!(snapshot_results, (
                snapshot_time_s=snapshot_time_s,
                output_dir=snapshot_dir,
                spec=snapshot_spec,
                smoke_spec=smoke_spec,
                smoke_result=smoke_result,
                provenance="state_carrying_partitioned",
                status=snapshot_status(local_spec, snapshot_time_s, smoke_result),
            ))
        end
        return snapshot_results
    end

    function manifest_row(local_spec::NativeResolvedFSIPartitionedProductionSpec, snapshot_result::NamedTuple)
        smoke_result = snapshot_result.smoke_result
        boundary_status = native_resolved_fsi_boundary_status_fields(
            smoke_result.inlet_outlet_boundary_mode;
            inlet_umax_cm_s=local_spec.inlet_umax_cm_s,
        )
        return (
            string(local_spec.case_spec.case_id),
            snapshot_result.snapshot_time_s,
            snapshot_result.output_dir,
            smoke_result.velocity_xdmf,
            smoke_result.pressure_xdmf,
            smoke_result.displacement_xdmf,
            snapshot_result.provenance,
            size(smoke_result.mesh.coordinates, 1),
            size(smoke_result.mesh.topology, 1),
            smoke_result.estimated_field_payload_bytes,
            snapshot_result.status.ready ? "ready" : "failed",
            boundary_status.boundary_mode,
            boundary_status.boundary_mode_class,
            boundary_status.section41_boundary_status,
            native_resolved_fsi_boundary_equivalence_status(boundary_status),
        )
    end

    function write_manifest(
        path::String,
        local_spec::NativeResolvedFSIPartitionedProductionSpec,
        snapshot_results::Vector{NamedTuple},
    )
        header = (
            "case_id",
            "snapshot_time_s",
            "output_dir",
            "velocity_xdmf",
            "pressure_xdmf",
            "displacement_xdmf",
            "provenance",
            "node_count",
            "tetrahedron_count",
            "estimated_field_payload_bytes",
            "status",
            "boundary_mode",
            "boundary_mode_class",
            "section41_boundary_status",
            "boundary_equivalence_status",
        )
        rows = (manifest_row(local_spec, snapshot_result) for snapshot_result in snapshot_results)
        return write_csv_table(path, header, rows; overwrite=local_spec.overwrite)
    end

    function wall_update_ready(smoke_result)
        return all(isfinite, smoke_result.wall_displacement_cm) &&
               all(isfinite, smoke_result.wall_velocity_cm_s) &&
               all(isfinite, smoke_result.wall_pressure_dyn_cm2) &&
               all(isfinite, smoke_result.current_radii_cm) &&
               smoke_result.minimum_current_radius_cm > 0.0 &&
               smoke_result.minimum_signed_tetra_volume6 > 0.0 &&
               !isempty(smoke_result.wall_displacement_cm) &&
               iszero(smoke_result.wall_displacement_cm[begin]) &&
               iszero(smoke_result.wall_displacement_cm[end]) &&
               iszero(smoke_result.wall_velocity_cm_s[begin]) &&
               iszero(smoke_result.wall_velocity_cm_s[end])
    end

    function diagnostic_row(
        local_spec::NativeResolvedFSIPartitionedProductionSpec,
        snapshot_index::Int,
        snapshot_result::NamedTuple,
    )
        smoke_result = snapshot_result.smoke_result
        solver_convergence_ready =
            smoke_result.picard_converged &&
            smoke_result.max_picard_iterations_used > 0 &&
            isfinite(smoke_result.final_picard_update_norm)
        importer_roundtrip_ready =
            smoke_result.schema_status.ready &&
            smoke_result.geometry_status.ready &&
            smoke_result.time_status.ready &&
            smoke_result.field_status.ready
        wall_ready = wall_update_ready(smoke_result)
        boundary_status = native_resolved_fsi_boundary_status_fields(
            smoke_result.inlet_outlet_boundary_mode;
            inlet_umax_cm_s=local_spec.inlet_umax_cm_s,
        )
        return (
            case_id=string(local_spec.case_spec.case_id),
            snapshot_index=snapshot_index,
            snapshot_time_s=snapshot_result.snapshot_time_s,
            saved_time_s=smoke_result.saved_time_s,
            output_dir=snapshot_result.output_dir,
            provenance=snapshot_result.provenance,
            time_step_count=smoke_result.time_step_count,
            picard_iteration_count=local_spec.picard_iteration_count,
            picard_tolerance=local_spec.picard_tolerance,
            max_picard_iterations_used=smoke_result.max_picard_iterations_used,
            final_picard_update_norm=smoke_result.final_picard_update_norm,
            solver_convergence_ready=solver_convergence_ready,
            picard_converged=smoke_result.picard_converged,
            coupling_iteration_count=local_spec.coupling_iteration_count,
            coupling_tolerance=local_spec.coupling_tolerance,
            coupling_under_relaxation=local_spec.coupling_under_relaxation,
            max_coupling_iterations_used=smoke_result.max_coupling_iterations_used,
            final_coupling_displacement_residual_cm=smoke_result.final_coupling_displacement_residual_cm,
            coupling_converged=smoke_result.coupling_converged,
            coupling_residual_count=length(smoke_result.coupling_residual_history),
            fluid_wall_boundary_mode=string(smoke_result.fluid_wall_boundary_mode),
            boundary_mode=boundary_status.boundary_mode,
            boundary_mode_class=boundary_status.boundary_mode_class,
            inlet_condition_status=boundary_status.inlet_condition_status,
            outlet_condition_status=boundary_status.outlet_condition_status,
            pressure_gauge_status=boundary_status.pressure_gauge_status,
            wall_pressure_projection_status=
                native_resolved_fsi_wall_pressure_projection_status(smoke_result.inlet_outlet_boundary_mode),
            section41_boundary_status=boundary_status.section41_boundary_status,
            boundary_status=boundary_status.boundary_status,
            boundary_equivalence_status=native_resolved_fsi_boundary_equivalence_status(boundary_status),
            post_update_fluid_refresh=smoke_result.post_update_fluid_refresh,
            wall_update_ready=wall_ready,
            wall_displacement_min_cm=minimum(smoke_result.wall_displacement_cm),
            wall_displacement_max_cm=maximum(smoke_result.wall_displacement_cm),
            wall_velocity_min_cm_s=minimum(smoke_result.wall_velocity_cm_s),
            wall_velocity_max_cm_s=maximum(smoke_result.wall_velocity_cm_s),
            wall_pressure_min_dyn_cm2=minimum(smoke_result.wall_pressure_dyn_cm2),
            wall_pressure_max_dyn_cm2=maximum(smoke_result.wall_pressure_dyn_cm2),
            minimum_current_radius_cm=smoke_result.minimum_current_radius_cm,
            minimum_signed_tetra_volume6=smoke_result.minimum_signed_tetra_volume6,
            pressure_projection_fallback_count=smoke_result.pressure_projection_fallback_count,
            sampling_fallback_count=smoke_result.sampling_fallback_count,
            schema_ready=smoke_result.schema_status.ready,
            geometry_ready=smoke_result.geometry_status.ready,
            time_ready=smoke_result.time_status.ready,
            field_ready=smoke_result.field_status.ready,
            output_ready=snapshot_result.status.ready,
            importer_roundtrip_ready=importer_roundtrip_ready,
            estimated_field_payload_bytes=smoke_result.estimated_field_payload_bytes,
            status=snapshot_result.status.ready ? "ready" : "failed",
        )
    end

    function build_diagnostic_rows(
        local_spec::NativeResolvedFSIPartitionedProductionSpec,
        snapshot_results::Vector{NamedTuple},
    )
        return NamedTuple[
            diagnostic_row(local_spec, snapshot_index, snapshot_result)
            for (snapshot_index, snapshot_result) in enumerate(snapshot_results)
        ]
    end

    function write_diagnostics(path::String, rows::Vector{NamedTuple}, overwrite::Bool)
        isempty(rows) && throw(ArgumentError("native resolved-FSI production diagnostics require at least one row"))
        header = string.(propertynames(first(rows)))
        return write_csv_table(path, header, (Tuple(row) for row in rows); overwrite=overwrite)
    end

    function diagnostics_status(rows::Vector{NamedTuple}, diagnostics_csv::String)
        ready = isfile(diagnostics_csv) &&
                !isempty(rows) &&
                all(
                    row ->
                        row.solver_convergence_ready &&
                        row.max_coupling_iterations_used > 0 &&
                        isfinite(row.final_coupling_displacement_residual_cm) &&
                        row.wall_update_ready &&
                        row.output_ready &&
                        row.importer_roundtrip_ready,
                    rows,
                )
        status = ready ?
            "production diagnostics CSV captured state-carrying per-snapshot solver convergence, wall-update, output, and importer health" :
            "production diagnostics are missing or one or more snapshot health checks failed"
        return NativeResolvedFSIWorkflowStatus(ready, status)
    end

    function restart_metadata(
        local_spec::NativeResolvedFSIPartitionedProductionSpec,
        snapshot_results::Vector{NamedTuple},
        rows::Vector{NamedTuple},
        manifest_csv::String,
        diagnostics_csv::String,
    )
        final_snapshot = snapshot_results[end]
        final_smoke = final_snapshot.smoke_result
        resolution = local_spec.resolution
        final_boundary_status = native_resolved_fsi_boundary_status_fields(
            final_smoke.inlet_outlet_boundary_mode;
            inlet_umax_cm_s=local_spec.inlet_umax_cm_s,
        )
        snapshot_outputs = Any[]
        for (index, snapshot) in enumerate(snapshot_results)
            snapshot_boundary_status = native_resolved_fsi_boundary_status_fields(
                snapshot.smoke_result.inlet_outlet_boundary_mode;
                inlet_umax_cm_s=local_spec.inlet_umax_cm_s,
            )
            push!(snapshot_outputs, Dict{String,Any}(
                "snapshot_index" => index,
                "snapshot_time_s" => snapshot.snapshot_time_s,
                "saved_time_s" => snapshot.smoke_result.saved_time_s,
                "output_dir" => snapshot.output_dir,
                "velocity_xdmf" => snapshot.smoke_result.velocity_xdmf,
                "pressure_xdmf" => snapshot.smoke_result.pressure_xdmf,
                "displacement_xdmf" => snapshot.smoke_result.displacement_xdmf,
                "provenance" => snapshot.provenance,
                "time_step_count" => snapshot.smoke_result.time_step_count,
                "max_coupling_iterations_used" => snapshot.smoke_result.max_coupling_iterations_used,
                "final_coupling_displacement_residual_cm" =>
                    snapshot.smoke_result.final_coupling_displacement_residual_cm,
                "coupling_converged" => snapshot.smoke_result.coupling_converged,
                "fluid_wall_boundary_mode" => string(snapshot.smoke_result.fluid_wall_boundary_mode),
                "inlet_umax_cm_s" => local_spec.inlet_umax_cm_s,
                "boundary_mode" => snapshot_boundary_status.boundary_mode,
                "boundary_mode_class" => snapshot_boundary_status.boundary_mode_class,
                "inlet_condition_status" => snapshot_boundary_status.inlet_condition_status,
                "outlet_condition_status" => snapshot_boundary_status.outlet_condition_status,
                "pressure_gauge_status" => snapshot_boundary_status.pressure_gauge_status,
                "wall_pressure_projection_status" =>
                    native_resolved_fsi_wall_pressure_projection_status(snapshot.smoke_result.inlet_outlet_boundary_mode),
                "section41_boundary_status" => snapshot_boundary_status.section41_boundary_status,
                "boundary_status" => snapshot_boundary_status.boundary_status,
                "boundary_equivalence_status" =>
                    native_resolved_fsi_boundary_equivalence_status(snapshot_boundary_status),
                "status" => snapshot.status.status,
            ))
        end
        coupling_residual_history = Any[
            Dict{String,Any}(
                "time_step_index" => row.time_step_index,
                "coupling_iteration" => row.coupling_iteration,
                "time_start_s" => row.time_start_s,
                "time_end_s" => row.time_end_s,
                "displacement_residual_cm" => row.displacement_residual_cm,
                "coupling_tolerance_cm" => row.coupling_tolerance_cm,
                "under_relaxation" => row.under_relaxation,
                "converged" => row.converged,
                "fluid_wall_boundary_mode" => row.fluid_wall_boundary_mode,
            ) for row in final_smoke.coupling_residual_history
        ]
        state_payload = Dict{String,Any}(
            "schema_version" => 1,
            "saved_time_s" => final_smoke.saved_time_s,
            "last_snapshot_index" => length(snapshot_results),
            "final_wall_displacement_cm" => copy(final_smoke.wall_displacement_cm),
            "final_wall_velocity_cm_s" => copy(final_smoke.wall_velocity_cm_s),
            "current_radii_cm" => copy(final_smoke.current_radii_cm),
            "final_wall_pressure_dyn_cm2" => copy(final_smoke.wall_pressure_dyn_cm2),
            "solver_provenance" => "state_carrying_partitioned",
            "state_carrying_in_run" => true,
            "resume_supported" => false,
            "resume_status" => "deferred",
        )
        return Dict{String,Any}(
            "case_id" => string(local_spec.case_spec.case_id),
            "severity_percent" => local_spec.case_spec.severity_percent,
            "mesh_resolution" => Dict{String,Any}(
                "axial" => resolution.axial,
                "radial" => resolution.radial,
                "angular" => resolution.angular,
            ),
            "dt_s" => local_spec.dt_s,
            "tfinal_s" => local_spec.tfinal_s,
            "output_root" => local_spec.output_root,
            "production_output_dir" => default_native_resolved_fsi_partitioned_production_output_dir(local_spec),
            "snapshot_times_s" => copy(local_spec.snapshot_times_s),
            "current_snapshot_index" => length(snapshot_results),
            "current_snapshot_time_s" => final_snapshot.snapshot_time_s,
            "current_saved_time_s" => final_smoke.saved_time_s,
            "current_smoke_time_step_count" => final_smoke.time_step_count,
            "coupling_iteration_count" => local_spec.coupling_iteration_count,
            "coupling_tolerance" => local_spec.coupling_tolerance,
            "coupling_under_relaxation" => local_spec.coupling_under_relaxation,
            "max_coupling_iterations_used" => final_smoke.max_coupling_iterations_used,
            "final_coupling_displacement_residual_cm" =>
                final_smoke.final_coupling_displacement_residual_cm,
            "coupling_converged" => final_smoke.coupling_converged,
            "coupling_residual_history" => coupling_residual_history,
            "fluid_wall_boundary_mode" => string(final_smoke.fluid_wall_boundary_mode),
            "wall_velocity_fluid_bc_status" => "prescribed_radial_wall_velocity_on_deformed_geometry",
            "inlet_umax_cm_s" => local_spec.inlet_umax_cm_s,
            "boundary_mode" => final_boundary_status.boundary_mode,
            "boundary_mode_class" => final_boundary_status.boundary_mode_class,
            "inlet_condition_status" => final_boundary_status.inlet_condition_status,
            "outlet_condition_status" => final_boundary_status.outlet_condition_status,
            "pressure_gauge_status" => final_boundary_status.pressure_gauge_status,
            "wall_pressure_projection_status" =>
                native_resolved_fsi_wall_pressure_projection_status(final_smoke.inlet_outlet_boundary_mode),
            "section41_boundary_status" => final_boundary_status.section41_boundary_status,
            "boundary_status" => final_boundary_status.boundary_status,
            "boundary_equivalence_status" => native_resolved_fsi_boundary_equivalence_status(final_boundary_status),
            "current_wall_displacement_cm" => copy(final_smoke.wall_displacement_cm),
            "current_wall_velocity_cm_s" => copy(final_smoke.wall_velocity_cm_s),
            "current_wall_pressure_dyn_cm2" => copy(final_smoke.wall_pressure_dyn_cm2),
            "current_geometry_status" => final_smoke.geometry_status.status,
            "current_minimum_radius_cm" => final_smoke.minimum_current_radius_cm,
            "current_minimum_signed_tetra_volume6" => final_smoke.minimum_signed_tetra_volume6,
            "current_output_status" => final_snapshot.status.status,
            "current_importer_roundtrip_ready" => rows[end].importer_roundtrip_ready,
            "snapshot_manifest_csv" => manifest_csv,
            "diagnostics_csv" => diagnostics_csv,
            "snapshot_outputs" => snapshot_outputs,
            "state_payload" => state_payload,
            "production_spec_digest" => production_spec_digest(local_spec),
            "restart_provenance" => "state_carrying_partitioned",
            "state_carrying_restart" => true,
            "resume_supported" => false,
            "resume_status" => "deferred",
            "resume_note" => "Production snapshots carry partitioned state within the run; persisted resume from restart metadata remains deferred.",
        )
    end

    write_restart_metadata(path::String, metadata::Dict{String,Any}, overwrite::Bool) =
        write_json(path, metadata; overwrite=overwrite)

    function restart_status(metadata::Dict{String,Any}, restart_metadata_json::String)
        ready = isfile(restart_metadata_json) &&
                get(metadata, "restart_provenance", "") == "state_carrying_partitioned" &&
                get(metadata, "state_carrying_restart", false) == true &&
                get(metadata, "resume_supported", true) == false &&
                get(metadata, "resume_status", "") == "deferred" &&
                get(get(metadata, "state_payload", Dict{String,Any}()), "schema_version", nothing) == 1
        status = ready ?
            "restart metadata was written with state-carrying partitioned snapshot provenance; persisted resume remains explicitly deferred" :
            "restart metadata is missing or does not mark the current state-carrying non-resumable provenance"
        return NativeResolvedFSIWorkflowStatus(ready, status)
    end

    function output_status(
        local_spec::NativeResolvedFSIPartitionedProductionSpec,
        snapshot_results::Vector{NamedTuple},
        manifest_csv::String,
        diagnostics_csv::String,
        restart_metadata_json::String,
    )
        expected_output_dir = default_native_resolved_fsi_partitioned_production_output_dir(local_spec)
        ready = isfile(manifest_csv) &&
                isfile(diagnostics_csv) &&
                isfile(restart_metadata_json) &&
                length(snapshot_results) == length(local_spec.snapshot_times_s) &&
                all(
                    snapshot -> snapshot.status.ready && startswith(snapshot.output_dir, expected_output_dir),
                    snapshot_results,
                )
        status = ready ?
            "production snapshot manifest, diagnostics CSV, restart metadata, and $(length(snapshot_results)) importer-compatible bundle(s) were written under $(expected_output_dir)" :
            "one or more production snapshot bundles or production sidecars failed output, schema, geometry, time, or field checks"
        return NativeResolvedFSIWorkflowStatus(ready, status)
    end

    function method_status(snapshot_results::Vector{NamedTuple})
        ready = !isempty(snapshot_results) && all(
                snapshot ->
                    snapshot.smoke_result.field_status.ready &&
                    snapshot.smoke_result.post_update_fluid_refresh &&
                    snapshot.provenance == "state_carrying_partitioned" &&
                    snapshot.smoke_result.fluid_model === NATIVE_RESOLVED_FSI_PARTITIONED_SMOKE_STAGE &&
                    snapshot.smoke_result.fluid_wall_boundary_mode ===
                        NATIVE_RESOLVED_FSI_PARTITIONED_SMOKE_FLUID_WALL_BOUNDARY_MODE,
            snapshot_results,
        )
        exact_boundary_mode =
            !isempty(snapshot_results) &&
            all(
                snapshot -> snapshot.smoke_result.inlet_outlet_boundary_mode ===
                            :poiseuille_inlet_zero_outlet_stress_section41,
                snapshot_results,
            )
        ready_status = if exact_boundary_mode
            "production snapshot harness advanced one state-carrying partitioned solve through each requested time with prescribed radial wall-velocity Dirichlet data on deformed geometry and exact Section 4.1 inlet/outlet boundary mode; direct finite wall-pressure sampling was required with pressure-drop fallback disabled; diagnostics are cumulative per-snapshot summaries with carried coupling residuals, while persisted resume, paper-grade Section 4.1 parity, and monolithic ALE coupling remain out of scope"
        else
            "production snapshot harness advanced one state-carrying partitioned solve through each requested time with prescribed radial wall-velocity Dirichlet data on deformed geometry; diagnostics are cumulative per-snapshot summaries with carried coupling residuals, while persisted resume, validated Section 4.1 parity, and monolithic ALE coupling remain out of scope"
        end
        status = ready ?
            ready_status :
            "production-depth partitioned native driver did not complete the bounded state-carrying method contract"
        return NativeResolvedFSIWorkflowStatus(ready, status)
    end

    validate(spec)
    validate_runner_scope(spec)

    production_output_dir = default_native_resolved_fsi_partitioned_production_output_dir(spec)
    snapshot_results = run_state_carrying_snapshots(spec)
    manifest_csv = manifest_path(spec)
    write_manifest(manifest_csv, spec, snapshot_results)
    diagnostics_csv = diagnostics_path(spec)
    diagnostic_rows = build_diagnostic_rows(spec, snapshot_results)
    write_diagnostics(diagnostics_csv, diagnostic_rows, spec.overwrite)
    restart_metadata_json = restart_metadata_path(spec)
    metadata = restart_metadata(spec, snapshot_results, diagnostic_rows, manifest_csv, diagnostics_csv)
    write_restart_metadata(restart_metadata_json, metadata, spec.overwrite)
    final_snapshot = snapshot_results[end]

    return NativeResolvedFSIPartitionedProductionResult(
        spec,
        final_snapshot.smoke_spec,
        final_snapshot.smoke_result,
        production_output_dir,
        manifest_csv,
        diagnostics_csv,
        restart_metadata_json,
        snapshot_results,
        diagnostic_rows,
        metadata,
        final_snapshot.snapshot_time_s,
        copy(spec.snapshot_times_s),
        output_status(spec, snapshot_results, manifest_csv, diagnostics_csv, restart_metadata_json),
        method_status(snapshot_results),
        diagnostics_status(diagnostic_rows, diagnostics_csv),
        restart_status(metadata, restart_metadata_json),
    )
end

run_native_resolved_fsi(spec::NativeResolvedFSIPartitionedProductionSpec) =
    run_native_resolved_fsi_partitioned_production(spec)

run_native_resolved_fsi_production_workflow(spec::NativeResolvedFSIPartitionedProductionSpec) =
    run_native_resolved_fsi_partitioned_production(spec)

run_native_resolved_fsi_production_workflow(plan::NativeResolvedFSIProductionWorkflowPlan) =
    run_native_resolved_fsi_partitioned_production(plan.production_spec)
