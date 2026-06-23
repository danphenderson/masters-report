"""
    NativeResolvedFSIProductionParityPlan

Pair one Section 4.1 native workflow plan with the current imported-bundle
contract for parity work. `imported_available=false` marks expected-skip plans
for cases whose local external bundle is absent or not wired by default.
"""
struct NativeResolvedFSIProductionParityPlan
    workflow_plan::NativeResolvedFSIProductionWorkflowPlan
    imported_case::Resolved3DCaseSpec
    imported_available::Bool
    status::String
end

"""
    native_resolved_fsi_production_parity_plans(; kwargs...)

Build Section 4.1 native/imported parity plans for `sev23`, `sev40`, and
`sev50`. The native side uses reproducible workflow specs; the imported side is
best-effort and stays skip-safe when local three-field bundles are missing.
"""
function native_resolved_fsi_production_parity_plans(;
    workflow_plans = native_resolved_fsi_production_workflow_plans(),
    imported_data_root::AbstractString = default_resolved3d_data_root(),
    imported_target_time::Real = 0.9995,
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
        status = if imported_available
            "ready: native production plan for $(workflow_plan.case_spec.paper_label) is paired with imported case $(imported_case.case_label)"
        elseif isempty(imported_case.velocity_xdmf)
            "expected-skip: no default imported Section 4.1 bundle contract is wired for $(workflow_plan.case_spec.case_id)"
        else
            "expected-skip: imported bundle $(imported_case.case_label) is not present locally"
        end
        push!(plans, NativeResolvedFSIProductionParityPlan(workflow_plan, imported_case, imported_available, status))
    end
    return plans
end

function native_resolved_fsi_production_imported_case(;
    case_id,
    data_root::String = default_resolved3d_data_root(),
    target_time::Real = 0.9995,
    time_atol::Real = 1.0e-3,
)
    return native_resolved_fsi_production_imported_case(case_id; data_root, target_time, time_atol)
end

function native_resolved_fsi_production_imported_case(
    case_id::Symbol;
    data_root::String = default_resolved3d_data_root(),
    target_time::Real = 0.9995,
    time_atol::Real = 1.0e-3,
)
    if case_id === :sev23
        return Resolved3DCaseSpec("77", 23.0, joinpath(data_root, "77", "velocity.xdmf"); target_time, time_atol)
    elseif case_id === :sev40
        return Resolved3DCaseSpec("60", 40.0, joinpath(data_root, "60", "velocity.xdmf"); target_time, time_atol)
    elseif case_id === :sev50
        return Resolved3DCaseSpec(
            "sev50-unavailable",
            50.0,
            "";
            pressure_xdmf="",
            displacement_xdmf="",
            target_time,
            time_atol,
        )
    end
    throw(ArgumentError("unsupported native Section 4.1 case id $(repr(case_id))"))
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
        !isempty(output_dir) && return String(output_dir)
        return joinpath(
            default_native_resolved_fsi_partitioned_production_output_dir(plan.workflow_plan.production_spec),
            "section41-observations",
        )
    end

    function artifact_csv_path()
        return joinpath(artifact_output_dir(), "section41_observations.csv")
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
        return (
            case_id=string(plan.workflow_plan.case_spec.case_id),
            case_label=case_label,
            source=source,
            quantity=quantity,
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
        status = area_valid ? "ready" : "invalid-cut"
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
            area_abs_difference_cm2=difference_or_nan(
                native_velocity_observation.area_cm2,
                imported_velocity_observation.area_cm2,
            ),
            flow_abs_difference_cm3_s=difference_or_nan(
                native_velocity_observation.flow_cm3_s,
                imported_velocity_observation.flow_cm3_s,
            ),
            mean_velocity_abs_difference_cm_s=difference_or_nan(
                native_velocity_observation.mean_velocity_cm_s,
                imported_velocity_observation.mean_velocity_cm_s,
            ),
            mean_pressure_abs_difference_dyn_cm2=difference_or_nan(
                native_pressure_observation.mean_pressure_dyn_cm2,
                imported_pressure_observation.mean_pressure_dyn_cm2,
            ),
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

    function write_observations(path::String, rows::Vector{NamedTuple})
        isempty(rows) && throw(ArgumentError("native resolved-FSI production parity observations require at least one row"))
        header = string.(propertynames(first(rows)))
        return write_csv_table(path, header, (Tuple(row) for row in rows); overwrite=true)
    end

    function artifact_status(observations_csv::String, rows::Vector{NamedTuple})
        ready = isfile(observations_csv) && !isempty(rows)
        status = ready ?
            "ready: Section 4.1 observation CSV written using CrossSectionQuadratureOperator rows" :
            "failed: Section 4.1 observation CSV was not written"
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
    rows = observation_rows(parity_spec, parity_result)
    observations_csv = artifact_csv_path()
    write_observations(observations_csv, rows)
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
        artifact_status=artifact_status(observations_csv, rows),
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
