"""
    NativeResolvedFSIProductionParityPlan

Pair one Section 4.1 native workflow plan with the current imported-bundle
contract for parity work. `imported_available=false` marks expected-skip plans
for cases whose local external bundle is absent.
"""
struct NativeResolvedFSIProductionParityPlan
    workflow_plan::NativeResolvedFSIProductionWorkflowPlan
    imported_case::Resolved3DCaseSpec
    imported_available::Bool
    native_target_time_s::Float64
    imported_target_time_s::Float64
    time_alignment_status::String
    pressure_gauge_status::String
    evidence_tier::String
    boundary_mode::String
    boundary_mode_class::String
    section41_boundary_status::String
    boundary_equivalence_status::String
    status::String
end

"""
    native_resolved_fsi_production_parity_plans(; kwargs...)

Build Section 4.1 native/imported parity plans for `sev23`, `sev40`, and
`sev50`. The native side uses reproducible workflow specs; the imported side is
best-effort and stays skip-safe when local three-field bundles are missing.
"""
function native_resolved_fsi_production_parity_plans(;
    workflow_plans = native_resolved_fsi_section41_time_aligned_production_workflow_plans(),
    imported_data_root::AbstractString = default_resolved3d_data_root(),
    imported_target_time::Union{Nothing,Real} = nothing,
    imported_time_atol::Real = 1.0e-3,
)
    plans = NativeResolvedFSIProductionParityPlan[]
    for workflow_plan in workflow_plans
        imported_case = native_resolved_fsi_production_imported_case(
            workflow_plan.case_spec.case_id;
            data_root=String(imported_data_root),
            target_time=imported_target_time,
            time_atol=imported_time_atol,
        )
        imported_available = isempty(native_resolved_fsi_parity_missing_paths(imported_case))
        boundary_status = native_resolved_fsi_boundary_status_fields(
            workflow_plan.production_spec.inlet_outlet_boundary_mode;
            inlet_umax_cm_s=workflow_plan.production_spec.inlet_umax_cm_s,
        )
        boundary_equivalence_status = native_resolved_fsi_boundary_equivalence_status(boundary_status)
        target_policy = native_resolved_fsi_section41_imported_target_policy(imported_target_time)
        imported_reference_time_s = native_resolved_fsi_section41_imported_time_s(
            workflow_plan.case_spec.case_id,
        )
        target_offset_s = abs(imported_case.target_time - imported_reference_time_s)
        target_aligned = target_offset_s <= Float64(imported_time_atol)
        native_target_time_s = last(workflow_plan.production_spec.snapshot_times_s)
        native_target_offset_s = abs(native_target_time_s - imported_case.target_time)
        native_target_aligned = native_target_offset_s <= Float64(imported_time_atol)
        time_alignment_status = native_resolved_fsi_production_parity_time_alignment_status(
            native_target_time_s,
            imported_case.target_time,
            imported_reference_time_s,
            imported_time_atol,
        )
        pressure_gauge_status = native_resolved_fsi_production_parity_pressure_gauge_status(boundary_status)
        evidence_tier = native_resolved_fsi_production_parity_evidence_tier(boundary_status)
        status = if imported_available && target_aligned && native_target_aligned
            "ready: internal operator-readiness plan for $(workflow_plan.case_spec.paper_label) targets native_time_s=$(native_target_time_s) and is paired with imported case $(imported_case.case_label) at target_time_s=$(imported_case.target_time); imported_target_time_policy=$(target_policy); time_alignment_status=$(time_alignment_status); pressure_gauge_status=$(pressure_gauge_status); evidence_tier=$(evidence_tier); boundary_equivalence_status=$(boundary_equivalence_status)"
        elseif imported_available
            !target_aligned ?
            "expected-skip: imported case $(imported_case.case_label) is present but imported_target_time_policy=$(target_policy) gives target_time_s=$(imported_case.target_time), offset $(target_offset_s) s from the case imported final time; time_alignment_status=$(time_alignment_status); internal smoke/operator-readiness only" :
            "expected-skip: native production target_time_s=$(native_target_time_s) differs from imported case $(imported_case.case_label) target_time_s=$(imported_case.target_time) by $(native_target_offset_s) s; time_alignment_status=$(time_alignment_status); internal smoke/operator-readiness only"
        elseif isempty(imported_case.velocity_xdmf)
            "expected-skip: no default imported Section 4.1 bundle contract is wired for $(workflow_plan.case_spec.case_id); time_alignment_status=$(time_alignment_status); evidence_tier=$(evidence_tier)"
        else
            "expected-skip: imported bundle $(imported_case.case_label) is not present locally; time_alignment_status=$(time_alignment_status); evidence_tier=$(evidence_tier)"
        end
        push!(plans, NativeResolvedFSIProductionParityPlan(
            workflow_plan,
            imported_case,
            imported_available,
            native_target_time_s,
            imported_case.target_time,
            time_alignment_status,
            pressure_gauge_status,
            evidence_tier,
            boundary_status.boundary_mode,
            boundary_status.boundary_mode_class,
            boundary_status.section41_boundary_status,
            boundary_equivalence_status,
            status,
        ))
    end
    return plans
end

function native_resolved_fsi_production_imported_case(;
    case_id,
    data_root::String = default_resolved3d_data_root(),
    target_time::Union{Nothing,Real} = nothing,
    time_atol::Real = 1.0e-3,
)
    return native_resolved_fsi_production_imported_case(case_id; data_root, target_time, time_atol)
end

function native_resolved_fsi_production_imported_case(
    case_id::Symbol;
    data_root::String = default_resolved3d_data_root(),
    target_time::Union{Nothing,Real} = nothing,
    time_atol::Real = 1.0e-3,
)
    target_time_value = isnothing(target_time) ? native_resolved_fsi_section41_imported_time_s(case_id) : Float64(target_time)
    if case_id === :sev23
        return Resolved3DCaseSpec("77", 23.0, joinpath(data_root, "77", "velocity.xdmf"); target_time=target_time_value, time_atol)
    elseif case_id === :sev40
        return Resolved3DCaseSpec("60", 40.0, joinpath(data_root, "60", "velocity.xdmf"); target_time=target_time_value, time_atol)
    elseif case_id === :sev50
        return Resolved3DCaseSpec("50", 50.0, joinpath(data_root, "50", "velocity.xdmf"); target_time=target_time_value, time_atol)
    end
    throw(ArgumentError("unsupported native Section 4.1 case id $(repr(case_id))"))
end

function native_resolved_fsi_section41_imported_target_policy(imported_target_time)
    return isnothing(imported_target_time) ? "per_case_imported_time" : "global_imported_target_time_override"
end

function native_resolved_fsi_production_parity_time_alignment_status(
    native_target_time_s::Real,
    imported_target_time_s::Real,
    imported_reference_time_s::Real,
    time_atol_s::Real,
)
    tolerance = Float64(time_atol_s)
    imported_reference_offset_s = abs(Float64(imported_target_time_s) - Float64(imported_reference_time_s))
    native_imported_offset_s = abs(Float64(native_target_time_s) - Float64(imported_target_time_s))
    if imported_reference_offset_s <= tolerance && native_imported_offset_s <= tolerance
        return "time_aligned"
    elseif imported_reference_offset_s > tolerance
        return "not_time_aligned_imported_target"
    end
    return "not_time_aligned_native_target"
end

function native_resolved_fsi_production_parity_pressure_gauge_status(boundary_status::NamedTuple)
    return "$(boundary_status.pressure_gauge_status); common_imported_pressure_gauge_operator_unverified; pressure_discrepancy_status=$(NATIVE_RESOLVED_FSI_PARITY_PRESSURE_STATUS)"
end

function native_resolved_fsi_production_parity_evidence_tier(boundary_status::NamedTuple)
    return native_resolved_fsi_production_parity_evidence_tier(boundary_status.boundary_mode_class)
end

function native_resolved_fsi_production_parity_evidence_tier(boundary_mode_class::AbstractString)
    boundary_mode_class == "exact_section41" && return "internal_exact_boundary_smoke_operator_readiness"
    return "internal_weak_smoke_operator_readiness"
end

function native_resolved_fsi_section41_time_aligned_production_workflow_plans(;
    case_ids = SECTION41_NATIVE_CASE_IDS,
    kwargs...,
)
    plans = NativeResolvedFSIProductionWorkflowPlan[]
    for case_id in case_ids
        target_time_s = native_resolved_fsi_section41_imported_time_s(case_id)
        append!(
            plans,
            native_resolved_fsi_production_workflow_plans(;
                case_ids=(case_id,),
                output_time_s=target_time_s,
                tfinal_s=target_time_s,
                snapshot_times_s=(target_time_s,),
                kwargs...,
            ),
        )
    end
    return plans
end

function native_resolved_fsi_section41_imported_time_s(case_id::Symbol)
    case_id === :sev23 && return 0.99949999999994532
    case_id === :sev40 && return 0.99949999999994532
    case_id === :sev50 && return 1.4994999999998904
    throw(ArgumentError("unsupported native Section 4.1 case id $(repr(case_id))"))
end

function native_resolved_fsi_production_parity_output_dir(
    plan::NativeResolvedFSIProductionParityPlan;
    output_dir::AbstractString = "",
)
    !isempty(output_dir) && return String(output_dir)
    return joinpath(
        default_native_resolved_fsi_partitioned_production_output_dir(plan.workflow_plan.production_spec),
        "section41-observations",
    )
end

function native_resolved_fsi_production_parity_observations_csv(
    plan::NativeResolvedFSIProductionParityPlan;
    output_dir::AbstractString = "",
)
    return joinpath(native_resolved_fsi_production_parity_output_dir(plan; output_dir), "section41_observations.csv")
end

function native_resolved_fsi_production_parity_summary_csv(
    plan::NativeResolvedFSIProductionParityPlan;
    output_dir::AbstractString = "",
)
    return joinpath(native_resolved_fsi_production_parity_output_dir(plan; output_dir), "section41_observation_summary.csv")
end

"""
    native_resolved_fsi_production_parity_matrix_rows(dry_runs; parity_plans=(), artifacts=())

Return compact qualified-internal matrix rows for Section 4.1 native/imported
parity handoff. The helper is side-effect-free: it composes existing production
dry-run records, parity planning records, and optional observation-artifact
summaries without loading optional external bundles or writing files.
"""
function native_resolved_fsi_production_parity_matrix_rows(
    dry_runs;
    parity_plans = (),
    artifacts = (),
)
    dry_run_list = collect(dry_runs)
    parity_plan_by_case = Dict(
        string(plan.workflow_plan.case_spec.case_id) => plan for plan in parity_plans
    )
    artifact_by_case = Dict{String,Any}()
    for artifact in artifacts
        case_id = string(artifact.plan.workflow_plan.case_spec.case_id)
        haskey(artifact_by_case, case_id) &&
            throw(ArgumentError("native resolved-FSI parity matrix received duplicate artifact rows for case $case_id"))
        artifact_by_case[case_id] = artifact
    end

    rows = NamedTuple[]
    for dry_run in dry_run_list
        case_id = string(dry_run.case_id)
        parity_plan = get(parity_plan_by_case, case_id, nothing)
        if haskey(artifact_by_case, case_id)
            append!(
                rows,
                native_resolved_fsi_production_parity_matrix_artifact_rows(
                    dry_run,
                    artifact_by_case[case_id],
                ),
            )
        else
            append!(
                rows,
                native_resolved_fsi_production_parity_matrix_planned_rows(
                    dry_run,
                    parity_plan,
                ),
            )
        end
    end
    return sort(rows; by=row -> (row.case_id, row.source, row.quantity))
end

function native_resolved_fsi_production_parity_matrix_rows(
    dry_run::NativeResolvedFSIProductionDryRunPlan;
    kwargs...,
)
    return native_resolved_fsi_production_parity_matrix_rows([dry_run]; kwargs...)
end

function native_resolved_fsi_production_parity_matrix_rows(;
    workflow_plans = native_resolved_fsi_production_workflow_plans(),
    imported_data_root::AbstractString = default_resolved3d_data_root(),
    artifacts = (),
)
    dry_runs = [
        native_resolved_fsi_partitioned_production_dry_run(plan; imported_data_root=imported_data_root)
        for plan in workflow_plans
    ]
    parity_plans = native_resolved_fsi_production_parity_plans(
        workflow_plans=workflow_plans,
        imported_data_root=imported_data_root,
    )
    return native_resolved_fsi_production_parity_matrix_rows(dry_runs; parity_plans, artifacts)
end

function native_resolved_fsi_production_parity_matrix_artifact_rows(
    dry_run::NativeResolvedFSIProductionDryRunPlan,
    artifact,
)
    return NamedTuple[
        native_resolved_fsi_production_parity_matrix_row(
            dry_run,
            summary_row.source,
            summary_row.quantity;
            row_count=summary_row.row_count,
            ready_row_count=summary_row.ready_row_count,
            max_mean_velocity_abs_difference_cm_s=summary_row.max_mean_velocity_abs_difference_cm_s,
            max_mean_pressure_abs_difference_dyn_cm2=summary_row.max_mean_pressure_abs_difference_dyn_cm2,
            native_target_time_s=summary_row.native_target_time_s,
            imported_target_time_s=summary_row.imported_target_time_s,
            time_alignment_status=summary_row.time_alignment_status,
            pressure_gauge_status=summary_row.pressure_gauge_status,
            evidence_tier=summary_row.evidence_tier,
            status=summary_row.status,
        )
        for summary_row in artifact.summary_rows
    ]
end

function native_resolved_fsi_production_parity_matrix_planned_rows(
    dry_run::NativeResolvedFSIProductionDryRunPlan,
    parity_plan,
)
    rows = NamedTuple[]
    plan_status = parity_plan === nothing ? dry_run.status : parity_plan.status
    native_target_time_s = parity_plan === nothing ?
        native_resolved_fsi_production_parity_dry_run_native_target_time_s(dry_run) :
        parity_plan.native_target_time_s
    imported_target_time_s = parity_plan === nothing ?
        native_resolved_fsi_production_parity_dry_run_imported_target_time_s(dry_run) :
        parity_plan.imported_target_time_s
    time_alignment_status = parity_plan === nothing ?
        native_resolved_fsi_production_parity_dry_run_time_alignment_status(dry_run) :
        parity_plan.time_alignment_status
    pressure_gauge_status = parity_plan === nothing ?
        native_resolved_fsi_production_parity_dry_run_pressure_gauge_status(dry_run) :
        parity_plan.pressure_gauge_status
    evidence_tier = parity_plan === nothing ?
        native_resolved_fsi_production_parity_evidence_tier(dry_run.boundary_mode_class) :
        parity_plan.evidence_tier
    for quantity in ("pressure", "velocity")
        push!(rows, native_resolved_fsi_production_parity_matrix_row(
            dry_run,
            "native",
            quantity;
            native_target_time_s,
            imported_target_time_s,
            time_alignment_status,
            pressure_gauge_status,
            evidence_tier,
            status=dry_run.status,
        ))
        push!(rows, native_resolved_fsi_production_parity_matrix_row(
            dry_run,
            "imported",
            quantity;
            native_target_time_s,
            imported_target_time_s,
            time_alignment_status,
            pressure_gauge_status,
            evidence_tier,
            status=plan_status,
        ))
        dry_run.imported_available && push!(rows, native_resolved_fsi_production_parity_matrix_row(
            dry_run,
            "parity",
            quantity;
            native_target_time_s,
            imported_target_time_s,
            time_alignment_status,
            pressure_gauge_status,
            evidence_tier,
            status=plan_status,
        ))
    end
    return rows
end

function native_resolved_fsi_production_parity_dry_run_native_target_time_s(
    dry_run::NativeResolvedFSIProductionDryRunPlan,
)
    isempty(dry_run.snapshot_times_s) && return NaN
    return Float64(last(dry_run.snapshot_times_s))
end

function native_resolved_fsi_production_parity_dry_run_imported_target_time_s(
    dry_run::NativeResolvedFSIProductionDryRunPlan,
)
    hasproperty(dry_run.imported_case, :target_time) || return NaN
    return Float64(dry_run.imported_case.target_time)
end

function native_resolved_fsi_production_parity_dry_run_time_alignment_status(
    dry_run::NativeResolvedFSIProductionDryRunPlan,
)
    native_target_time_s = native_resolved_fsi_production_parity_dry_run_native_target_time_s(dry_run)
    imported_target_time_s = native_resolved_fsi_production_parity_dry_run_imported_target_time_s(dry_run)
    if !isfinite(native_target_time_s) || !isfinite(imported_target_time_s)
        return "time_alignment_unavailable"
    end
    abs(native_target_time_s - imported_target_time_s) <= 1.0e-3 && return "time_aligned"
    return "not_time_aligned_native_target"
end

function native_resolved_fsi_production_parity_dry_run_pressure_gauge_status(
    dry_run::NativeResolvedFSIProductionDryRunPlan,
)
    return "$(dry_run.pressure_gauge_status); common_imported_pressure_gauge_operator_unverified; pressure_discrepancy_status=$(NATIVE_RESOLVED_FSI_PARITY_PRESSURE_STATUS)"
end

function native_resolved_fsi_production_parity_matrix_row(
    dry_run::NativeResolvedFSIProductionDryRunPlan,
    source::AbstractString,
    quantity::AbstractString;
    row_count::Integer = 0,
    ready_row_count::Integer = 0,
    max_mean_velocity_abs_difference_cm_s::Real = NaN,
    max_mean_pressure_abs_difference_dyn_cm2::Real = NaN,
    native_target_time_s::Real = native_resolved_fsi_production_parity_dry_run_native_target_time_s(dry_run),
    imported_target_time_s::Real = native_resolved_fsi_production_parity_dry_run_imported_target_time_s(dry_run),
    time_alignment_status::AbstractString = native_resolved_fsi_production_parity_dry_run_time_alignment_status(dry_run),
    pressure_gauge_status::AbstractString = native_resolved_fsi_production_parity_dry_run_pressure_gauge_status(dry_run),
    evidence_tier::AbstractString = native_resolved_fsi_production_parity_evidence_tier(dry_run.boundary_mode_class),
    status::AbstractString,
)
    return (
        case_id=string(dry_run.case_id),
        source=String(source),
        quantity=String(quantity),
        qualification="qualified-internal",
        source_label=native_resolved_fsi_production_parity_matrix_source_label(dry_run, source),
        native_target_time_s=Float64(native_target_time_s),
        imported_target_time_s=Float64(imported_target_time_s),
        time_alignment_status=String(time_alignment_status),
        pressure_gauge_status=String(pressure_gauge_status),
        evidence_tier=String(evidence_tier),
        imported_available=dry_run.imported_available,
        observations_csv=dry_run.parity_observations_csv,
        summary_csv=dry_run.parity_summary_csv,
        boundary_mode=dry_run.boundary_mode,
        boundary_mode_class=dry_run.boundary_mode_class,
        section41_boundary_status=dry_run.section41_boundary_status,
        boundary_equivalence_status=dry_run.boundary_equivalence_status,
        row_count=Int(row_count),
        ready_row_count=Int(ready_row_count),
        max_mean_velocity_abs_difference_cm_s=Float64(max_mean_velocity_abs_difference_cm_s),
        max_mean_pressure_abs_difference_dyn_cm2=Float64(max_mean_pressure_abs_difference_dyn_cm2),
        status=native_resolved_fsi_production_parity_matrix_status(dry_run, status),
    )
end

function native_resolved_fsi_production_parity_matrix_status(
    dry_run::NativeResolvedFSIProductionDryRunPlan,
    status::AbstractString,
)
    row_status = String(status)
    dry_run.boundary_mode == string(:poiseuille_inlet_zero_outlet_stress_section41) || return row_status
    occursin("parity status is artifact/operator readiness only", row_status) && return row_status
    return row_status *
           "; parity status is artifact/operator readiness only, internal smoke/operator-readiness evidence, not validated Section 4.1 parity"
end

function native_resolved_fsi_production_parity_matrix_source_label(
    dry_run::NativeResolvedFSIProductionDryRunPlan,
    source::AbstractString,
)
    source == "native" && return string(dry_run.case_id)
    source == "imported" && return dry_run.imported_case.case_label
    source == "parity" && return "$(dry_run.case_id):$(dry_run.imported_case.case_label)"
    return String(source)
end

"""
    run_native_resolved_fsi_parity(plan, native_case; output_dir="", kwargs...)

Write Section 4.1 observation rows for one native generated bundle and, when
the planned imported bundle is present, paired imported/parity rows. This
artifact workflow reuses the existing cross-section velocity and pressure
operators; it is skip-safe for absent optional external data and does not claim
validated paper parity.
"""
function run_native_resolved_fsi_parity(
    plan::NativeResolvedFSIProductionParityPlan,
    native_case::Resolved3DCaseSpec;
    output_dir::AbstractString = "",
    coordinate_mode::AbstractString = NATIVE_RESOLVED_FSI_PARITY_DEFAULT_COORDINATE_MODE,
    sample_z_cm::AbstractVector{<:Real} = Float64[],
    kwargs...,
)
    function artifact_output_dir()
        return native_resolved_fsi_production_parity_output_dir(plan; output_dir)
    end

    function artifact_csv_path()
        return native_resolved_fsi_production_parity_observations_csv(plan; output_dir)
    end

    function artifact_summary_csv_path()
        return native_resolved_fsi_production_parity_summary_csv(plan; output_dir)
    end

    function native_only_sample_z(field::Resolved3DVelocityField)
        z_values = view(field.coordinates, :, 3)
        z_min = minimum(z_values)
        z_max = maximum(z_values)
        span = z_max - z_min
        span <= 1.0e-12 && return [z_min]
        return [z_min + 0.25 * span, z_min + 0.5 * span, z_min + 0.75 * span]
    end

    function selected_sample_z(parity_spec::NativeResolvedFSIParitySpec, parity_result::NativeResolvedFSIParityResult)
        !isempty(parity_spec.sample_z_cm) && return copy(parity_spec.sample_z_cm)
        if parity_result.imported_operator_field !== nothing
            return native_resolved_fsi_parity_default_sample_z(
                parity_result.native_operator_field,
                parity_result.imported_operator_field,
            )
        end
        return native_only_sample_z(parity_result.native_operator_field)
    end

    difference_or_nan(native_value, imported_value) =
        isfinite(native_value) && isfinite(imported_value) ? abs(Float64(native_value) - Float64(imported_value)) : NaN

    function observation_row(;
        source::String,
        quantity::String,
        case_label::String,
        snapshot_time_s::Float64,
        z_cm::Float64,
        area_cm2::Float64 = NaN,
        flow_cm3_s::Float64 = NaN,
        mean_velocity_cm_s::Float64 = NaN,
        mean_pressure_dyn_cm2::Float64 = NaN,
        intersection_count::Int = 0,
        area_valid::Bool = false,
        cut_status::String = "",
        paired_source::String = "",
        area_abs_difference_cm2::Float64 = NaN,
        flow_abs_difference_cm3_s::Float64 = NaN,
        mean_velocity_abs_difference_cm_s::Float64 = NaN,
        mean_pressure_abs_difference_dyn_cm2::Float64 = NaN,
        status::String = "ready",
    )
        boundary_status = native_resolved_fsi_boundary_status_fields(
            plan.workflow_plan.production_spec.inlet_outlet_boundary_mode;
            inlet_umax_cm_s=plan.workflow_plan.production_spec.inlet_umax_cm_s,
        )
        return (
            case_id=string(plan.workflow_plan.case_spec.case_id),
            case_label=case_label,
            source=source,
            quantity=quantity,
            native_target_time_s=plan.native_target_time_s,
            imported_target_time_s=plan.imported_target_time_s,
            time_alignment_status=plan.time_alignment_status,
            pressure_gauge_status=plan.pressure_gauge_status,
            evidence_tier=plan.evidence_tier,
            snapshot_time_s=snapshot_time_s,
            z_cm=z_cm,
            operator_name=operator_name(CrossSectionQuadratureOperator()),
            coordinate_mode=parity_spec.coordinate_mode,
            area_cm2=area_cm2,
            flow_cm3_s=flow_cm3_s,
            mean_velocity_cm_s=mean_velocity_cm_s,
            mean_pressure_dyn_cm2=mean_pressure_dyn_cm2,
            intersection_count=intersection_count,
            area_valid=area_valid,
            cut_status=cut_status,
            paired_source=paired_source,
            area_abs_difference_cm2=area_abs_difference_cm2,
            flow_abs_difference_cm3_s=flow_abs_difference_cm3_s,
            mean_velocity_abs_difference_cm_s=mean_velocity_abs_difference_cm_s,
            mean_pressure_abs_difference_dyn_cm2=mean_pressure_abs_difference_dyn_cm2,
            boundary_mode=boundary_status.boundary_mode,
            boundary_mode_class=boundary_status.boundary_mode_class,
            section41_boundary_status=boundary_status.section41_boundary_status,
            boundary_equivalence_status=native_resolved_fsi_boundary_equivalence_status(boundary_status),
            status=status,
        )
    end

    function push_source_rows!(
        rows::Vector{NamedTuple},
        source::String,
        bundle::Resolved3DFieldBundle,
        field::Resolved3DVelocityField,
        z::Float64,
    )
        pressure = native_resolved_fsi_parity_required_pressure(bundle)
        velocity_observation = section_observation(field, z, CrossSectionQuadratureOperator())
        pressure_observation = native_resolved_fsi_parity_pressure_section_observation(field, pressure, z)
        push!(rows, observation_row(
            source=source,
            quantity="velocity",
            case_label=bundle.case_spec.case_label,
            snapshot_time_s=bundle.velocity.metadata.time,
            z_cm=z,
            area_cm2=velocity_observation.area_cm2,
            flow_cm3_s=velocity_observation.flow_cm3_s,
            mean_velocity_cm_s=velocity_observation.mean_velocity_cm_s,
            intersection_count=velocity_observation.intersection_count,
            area_valid=velocity_observation.area_valid,
            cut_status=velocity_observation.cut_status,
        ))
        push!(rows, observation_row(
            source=source,
            quantity="pressure",
            case_label=bundle.case_spec.case_label,
            snapshot_time_s=bundle.velocity.metadata.time,
            z_cm=z,
            area_cm2=pressure_observation.area_cm2,
            mean_pressure_dyn_cm2=pressure_observation.mean_pressure_dyn_cm2,
            intersection_count=pressure_observation.intersection_count,
            area_valid=pressure_observation.area_valid,
            cut_status=pressure_observation.cut_status,
        ))
        return velocity_observation, pressure_observation
    end

    function push_parity_row!(
        rows::Vector{NamedTuple},
        native_bundle::Resolved3DFieldBundle,
        imported_bundle::Resolved3DFieldBundle,
        native_velocity_observation,
        imported_velocity_observation,
        native_pressure_observation,
        imported_pressure_observation,
        z::Float64,
    )
        cut_status = "$(native_velocity_observation.cut_status):$(imported_velocity_observation.cut_status)"
        area_valid = native_velocity_observation.area_valid && imported_velocity_observation.area_valid
        area_abs_difference = difference_or_nan(
            native_velocity_observation.area_cm2,
            imported_velocity_observation.area_cm2,
        )
        flow_abs_difference = difference_or_nan(
            native_velocity_observation.flow_cm3_s,
            imported_velocity_observation.flow_cm3_s,
        )
        mean_velocity_abs_difference = difference_or_nan(
            native_velocity_observation.mean_velocity_cm_s,
            imported_velocity_observation.mean_velocity_cm_s,
        )
        mean_pressure_abs_difference = difference_or_nan(
            native_pressure_observation.mean_pressure_dyn_cm2,
            imported_pressure_observation.mean_pressure_dyn_cm2,
        )
        status = if !area_valid
            "invalid-cut"
        elseif isfinite(mean_pressure_abs_difference) && mean_pressure_abs_difference > parity_spec.operator_atol
            NATIVE_RESOLVED_FSI_PARITY_PRESSURE_STATUS
        else
            "ready"
        end
        push!(rows, observation_row(
            source="parity",
            quantity="velocity_pressure",
            case_label="$(native_bundle.case_spec.case_label):$(imported_bundle.case_spec.case_label)",
            snapshot_time_s=native_bundle.velocity.metadata.time,
            z_cm=z,
            area_cm2=native_velocity_observation.area_cm2,
            flow_cm3_s=native_velocity_observation.flow_cm3_s,
            mean_velocity_cm_s=native_velocity_observation.mean_velocity_cm_s,
            mean_pressure_dyn_cm2=native_pressure_observation.mean_pressure_dyn_cm2,
            intersection_count=native_velocity_observation.intersection_count,
            area_valid=area_valid,
            cut_status=cut_status,
            paired_source="native:imported",
            area_abs_difference_cm2=area_abs_difference,
            flow_abs_difference_cm3_s=flow_abs_difference,
            mean_velocity_abs_difference_cm_s=mean_velocity_abs_difference,
            mean_pressure_abs_difference_dyn_cm2=mean_pressure_abs_difference,
            status=status,
        ))
        return rows
    end

    function observation_rows(parity_spec::NativeResolvedFSIParitySpec, parity_result::NativeResolvedFSIParityResult)
        rows = NamedTuple[]
        z_samples = selected_sample_z(parity_spec, parity_result)
        for z in z_samples
            native_velocity_observation, native_pressure_observation = push_source_rows!(
                rows,
                "native",
                parity_result.native_bundle,
                parity_result.native_operator_field,
                z,
            )
            if parity_result.imported_bundle !== nothing
                imported_velocity_observation, imported_pressure_observation = push_source_rows!(
                    rows,
                    "imported",
                    parity_result.imported_bundle,
                    parity_result.imported_operator_field,
                    z,
                )
                push_parity_row!(
                    rows,
                    parity_result.native_bundle,
                    parity_result.imported_bundle,
                    native_velocity_observation,
                    imported_velocity_observation,
                    native_pressure_observation,
                    imported_pressure_observation,
                    z,
                )
            end
        end
        return rows
    end

    function sorted_observation_rows(rows::Vector{NamedTuple})
        return sort(rows; by=row -> (row.case_id, row.source, row.quantity, row.z_cm, row.case_label))
    end

    function max_finite_or_nan(values)
        finite_values = Float64[Float64(value) for value in values if isfinite(value)]
        return isempty(finite_values) ? NaN : maximum(finite_values)
    end

    function summary_row(;
        case_id::String,
        source::String,
        quantity::String,
        row_count::Int,
        ready_row_count::Int,
        max_mean_velocity_abs_difference_cm_s::Float64 = NaN,
        max_mean_pressure_abs_difference_dyn_cm2::Float64 = NaN,
        status::String,
    )
        boundary_status = native_resolved_fsi_boundary_status_fields(
            plan.workflow_plan.production_spec.inlet_outlet_boundary_mode;
            inlet_umax_cm_s=plan.workflow_plan.production_spec.inlet_umax_cm_s,
        )
        return (
            case_id=case_id,
            source=source,
            quantity=quantity,
            native_target_time_s=plan.native_target_time_s,
            imported_target_time_s=plan.imported_target_time_s,
            time_alignment_status=plan.time_alignment_status,
            pressure_gauge_status=plan.pressure_gauge_status,
            evidence_tier=plan.evidence_tier,
            row_count=row_count,
            ready_row_count=ready_row_count,
            max_mean_velocity_abs_difference_cm_s=max_mean_velocity_abs_difference_cm_s,
            max_mean_pressure_abs_difference_dyn_cm2=max_mean_pressure_abs_difference_dyn_cm2,
            boundary_mode=boundary_status.boundary_mode,
            boundary_mode_class=boundary_status.boundary_mode_class,
            section41_boundary_status=boundary_status.section41_boundary_status,
            boundary_equivalence_status=native_resolved_fsi_boundary_equivalence_status(boundary_status),
            status=status,
        )
    end

    function summarized_status(rows::Vector{NamedTuple})
        statuses = sort!(unique(String[row.status for row in rows]))
        length(statuses) == 1 && return only(statuses)
        return "mixed: $(join(statuses, "; "))"
    end

    function observed_source_summary_rows(rows::Vector{NamedTuple})
        groups = Dict{Tuple{String,String,String},Vector{NamedTuple}}()
        for row in rows
            row.source == "parity" && continue
            push!(get!(groups, (row.case_id, row.source, row.quantity), NamedTuple[]), row)
        end

        summaries = NamedTuple[]
        for key in sort!(collect(keys(groups)))
            source_rows = groups[key]
            case_id, source, quantity = key
            push!(summaries, summary_row(
                case_id=case_id,
                source=source,
                quantity=quantity,
                row_count=length(source_rows),
                ready_row_count=count(row -> row.status == "ready", source_rows),
                max_mean_velocity_abs_difference_cm_s=max_finite_or_nan(
                    row.mean_velocity_abs_difference_cm_s for row in source_rows
                ),
                max_mean_pressure_abs_difference_dyn_cm2=max_finite_or_nan(
                    row.mean_pressure_abs_difference_dyn_cm2 for row in source_rows
                ),
                status=summarized_status(source_rows),
            ))
        end
        return summaries
    end

    function parity_summary_rows(rows::Vector{NamedTuple}, parity_result::NativeResolvedFSIParityResult)
        rows_for_parity = [row for row in rows if row.source == "parity"]
        isempty(rows_for_parity) && return NamedTuple[]
        case_id = first(rows_for_parity).case_id
        return NamedTuple[
            summary_row(
                case_id=case_id,
                source="parity",
                quantity="velocity",
                row_count=length(rows_for_parity),
                ready_row_count=parity_result.velocity_operator_status.ready ? length(rows_for_parity) : 0,
                max_mean_velocity_abs_difference_cm_s=max_finite_or_nan(
                    row.mean_velocity_abs_difference_cm_s for row in rows_for_parity
                ),
                status=parity_result.velocity_operator_status.status,
            ),
            summary_row(
                case_id=case_id,
                source="parity",
                quantity="pressure",
                row_count=length(rows_for_parity),
                ready_row_count=parity_result.pressure_operator_status.ready ? length(rows_for_parity) : 0,
                max_mean_pressure_abs_difference_dyn_cm2=max_finite_or_nan(
                    row.mean_pressure_abs_difference_dyn_cm2 for row in rows_for_parity
                ),
                status=parity_result.pressure_operator_status.status,
            ),
        ]
    end

    function expected_skip_summary_rows(plan::NativeResolvedFSIProductionParityPlan, parity_result::NativeResolvedFSIParityResult)
        parity_result.imported_bundle === nothing || return NamedTuple[]
        case_id = string(plan.workflow_plan.case_spec.case_id)
        return NamedTuple[
            summary_row(
                case_id=case_id,
                source="imported",
                quantity="velocity",
                row_count=0,
                ready_row_count=0,
                status="expected-skip: $(parity_result.velocity_operator_status.status)",
            ),
            summary_row(
                case_id=case_id,
                source="imported",
                quantity="pressure",
                row_count=0,
                ready_row_count=0,
                status="expected-skip: $(parity_result.pressure_operator_status.status)",
            ),
        ]
    end

    function summary_rows(
        plan::NativeResolvedFSIProductionParityPlan,
        parity_result::NativeResolvedFSIParityResult,
        rows::Vector{NamedTuple},
    )
        summaries = NamedTuple[]
        append!(summaries, observed_source_summary_rows(rows))
        append!(summaries, parity_summary_rows(rows, parity_result))
        append!(summaries, expected_skip_summary_rows(plan, parity_result))
        return sort(summaries; by=row -> (row.case_id, row.source, row.quantity))
    end

    function write_observations(path::String, rows::Vector{NamedTuple})
        isempty(rows) && throw(ArgumentError("native resolved-FSI production parity observations require at least one row"))
        header = string.(propertynames(first(rows)))
        return write_csv_table(path, header, (Tuple(row) for row in rows); overwrite=true)
    end

    function write_summary(path::String, rows::Vector{NamedTuple})
        isempty(rows) && throw(ArgumentError("native resolved-FSI production parity summary requires at least one row"))
        header = string.(propertynames(first(rows)))
        return write_csv_table(path, header, (Tuple(row) for row in rows); overwrite=true)
    end

    function artifact_status(
        observations_csv::String,
        rows::Vector{NamedTuple},
        summary_csv::String,
        summary_rows::Vector{NamedTuple},
    )
        ready = isfile(observations_csv) && !isempty(rows) && isfile(summary_csv) && !isempty(summary_rows)
        status = ready ?
            "ready: Section 4.1-scoped operator observation and summary CSVs written using CrossSectionQuadratureOperator rows" :
            "failed: Section 4.1-scoped operator observation artifact CSVs were not written"
        return NativeResolvedFSIWorkflowStatus(ready, status)
    end

    parity_spec = NativeResolvedFSIParitySpec(
        native_case,
        plan.imported_case;
        require_imported=false,
        coordinate_mode=coordinate_mode,
        sample_z_cm=sample_z_cm,
        kwargs...,
    )
    parity_result = run_native_resolved_fsi_parity(parity_spec)
    rows = sorted_observation_rows(observation_rows(parity_spec, parity_result))
    summaries = summary_rows(plan, parity_result, rows)
    observations_csv = artifact_csv_path()
    summary_csv = artifact_summary_csv_path()
    write_observations(observations_csv, rows)
    write_summary(summary_csv, summaries)
    imported_status = parity_result.imported_bundle === nothing ?
        NativeResolvedFSIWorkflowStatus(false, "expected-skip: $(parity_result.operator_status.status)") :
        NativeResolvedFSIWorkflowStatus(true, "ready: imported bundle observations were written")

    return (
        plan=plan,
        parity_spec=parity_spec,
        parity_result=parity_result,
        output_dir=artifact_output_dir(),
        observations_csv=observations_csv,
        observation_rows=rows,
        summary_csv=summary_csv,
        summary_rows=summaries,
        artifact_status=artifact_status(observations_csv, rows, summary_csv, summaries),
        imported_status=imported_status,
        velocity_operator_status=parity_result.velocity_operator_status,
        pressure_operator_status=parity_result.pressure_operator_status,
        operator_status=parity_result.operator_status,
    )
end

function run_native_resolved_fsi_parity(
    plan::NativeResolvedFSIProductionParityPlan,
    production_result::NativeResolvedFSIPartitionedProductionResult;
    kwargs...,
)
    native_case = Resolved3DCaseSpec(
        string(plan.workflow_plan.case_spec.case_id),
        plan.workflow_plan.case_spec.severity_percent,
        production_result.smoke_result.velocity_xdmf;
        pressure_xdmf=production_result.smoke_result.pressure_xdmf,
        displacement_xdmf=production_result.smoke_result.displacement_xdmf,
        target_time=production_result.saved_time_s,
        time_atol=production_result.spec.time_atol,
    )
    return run_native_resolved_fsi_parity(plan, native_case; kwargs...)
end
