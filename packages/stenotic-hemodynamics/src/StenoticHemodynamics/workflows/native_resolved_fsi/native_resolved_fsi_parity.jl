const NATIVE_RESOLVED_FSI_PARITY_DEFAULT_COORDINATE_MODE = "deformed"
const NATIVE_RESOLVED_FSI_PARITY_DEFAULT_TIME_S = 1.0
const NATIVE_RESOLVED_FSI_PARITY_PRESSURE_GAUGE_Z_CM = SECTION41_LENGTH_CM
const NATIVE_RESOLVED_FSI_PARITY_PRESSURE_STATUS =
    "common_section41_outlet_pressure_gauge_operator_applied"
const NATIVE_RESOLVED_FSI_PARITY_PRESSURE_GAUGE_UNAVAILABLE_STATUS =
    "pressure_gauge_unavailable_without_valid_section41_outlet_cut"
const NATIVE_RESOLVED_FSI_PARITY_PRESSURE_POLICY =
    "pressure discrepancies use a common Section 4.1 outlet-gauge operator: subtract the CrossSectionQuadratureOperator mean pressure at z=$(SECTION41_LENGTH_CM) cm before comparing diagnostic pressures"

"""
    NativeResolvedFSIParitySpec(...; kwargs...)

Typed bundle-to-bundle parity configuration for native resolved-FSI fixtures or
optional imported external fields. This harness compares importer-loaded
velocity/pressure/displacement bundles and makes its scope explicit: it does
not claim full Section 4.1 transient Navier-Stokes plus membrane parity.
"""
struct NativeResolvedFSIParitySpec <: AbstractStudySpec
    native_case::Resolved3DCaseSpec
    imported_case::Resolved3DCaseSpec
    require_imported::Bool
    coordinate_mode::String
    sample_z_cm::Vector{Float64}
    radial_profile_z_cm::Vector{Float64}
    radial_bin_count::Int
    node_slab_half_widths_cm::Vector{Float64}
    geometry_atol_cm::Float64
    time_atol_s::Float64
    velocity_atol_cm_s::Float64
    pressure_atol_dyn_cm2::Float64
    displacement_atol_cm::Float64
    operator_atol::Float64
end

function NativeResolvedFSIParitySpec(
    native_case::Resolved3DCaseSpec,
    imported_case::Resolved3DCaseSpec;
    require_imported::Bool = false,
    coordinate_mode::AbstractString = NATIVE_RESOLVED_FSI_PARITY_DEFAULT_COORDINATE_MODE,
    sample_z_cm::AbstractVector{<:Real} = Float64[],
    radial_profile_z_cm::AbstractVector{<:Real} = Float64[],
    radial_bin_count::Integer = 4,
    node_slab_half_widths_cm::AbstractVector{<:Real} = [DEFAULT_NODE_SLAB_HALF_WIDTH_CM],
    geometry_atol_cm::Real = 1.0e-9,
    time_atol_s::Real = -1.0,
    velocity_atol_cm_s::Real = 1.0e-9,
    pressure_atol_dyn_cm2::Real = 1.0e-9,
    displacement_atol_cm::Real = 1.0e-9,
    operator_atol::Real = 1.0e-9,
)
    time_atol_value = time_atol_s < 0 ? max(native_case.time_atol, imported_case.time_atol) : Float64(time_atol_s)
    return validate(NativeResolvedFSIParitySpec(
        native_case,
        imported_case,
        require_imported,
        native_resolved_fsi_parity_coordinate_mode(coordinate_mode),
        Float64[Float64(value) for value in sample_z_cm],
        Float64[Float64(value) for value in radial_profile_z_cm],
        Int(radial_bin_count),
        Float64[Float64(value) for value in node_slab_half_widths_cm],
        Float64(geometry_atol_cm),
        Float64(time_atol_value),
        Float64(velocity_atol_cm_s),
        Float64(pressure_atol_dyn_cm2),
        Float64(displacement_atol_cm),
        Float64(operator_atol),
    ))
end

function NativeResolvedFSIParitySpec(
    native_velocity_xdmf::AbstractString,
    imported_velocity_xdmf::AbstractString;
    native_case_label::AbstractString = "native",
    imported_case_label::AbstractString = "imported",
    native_severity::Real = 23.0,
    imported_severity::Real = native_severity,
    native_pressure_xdmf::AbstractString = default_companion_xdmf_path(native_velocity_xdmf, "pressure.xdmf"),
    imported_pressure_xdmf::AbstractString = default_companion_xdmf_path(imported_velocity_xdmf, "pressure.xdmf"),
    native_displacement_xdmf::AbstractString = default_companion_xdmf_path(native_velocity_xdmf, "displace.xdmf"),
    imported_displacement_xdmf::AbstractString = default_companion_xdmf_path(imported_velocity_xdmf, "displace.xdmf"),
    native_target_time::Real = NATIVE_RESOLVED_FSI_PARITY_DEFAULT_TIME_S,
    imported_target_time::Real = native_target_time,
    native_time_atol::Real = 1.0e-9,
    imported_time_atol::Real = native_time_atol,
    kwargs...,
)
    native_case = Resolved3DCaseSpec(
        native_case_label,
        native_severity,
        native_velocity_xdmf;
        pressure_xdmf=native_pressure_xdmf,
        displacement_xdmf=native_displacement_xdmf,
        target_time=native_target_time,
        time_atol=native_time_atol,
    )
    imported_case = Resolved3DCaseSpec(
        imported_case_label,
        imported_severity,
        imported_velocity_xdmf;
        pressure_xdmf=imported_pressure_xdmf,
        displacement_xdmf=imported_displacement_xdmf,
        target_time=imported_target_time,
        time_atol=imported_time_atol,
    )
    return NativeResolvedFSIParitySpec(native_case, imported_case; kwargs...)
end

native_resolved_fsi_parity_spec(args...; kwargs...) = NativeResolvedFSIParitySpec(args...; kwargs...)

"""
    NativeResolvedFSIParityStatus

Per-category parity status for schema, geometry, time, velocity, pressure,
displacement, or operator comparisons. `skipped=true` is reserved for expected
missing-external-data paths; `ready=true` means the category matched within its
configured tolerance.
"""
struct NativeResolvedFSIParityStatus
    ready::Bool
    skipped::Bool
    discrepancy_count::Int
    max_abs_difference::Float64
    status::String
end

"""
    NativeResolvedFSIParityResult

Return bundle from [`run_native_resolved_fsi_parity`](@ref). The result keeps
the loaded native/imported bundles, the operator coordinate mode used for
velocity observations, and separate discrepancy/status categories for schema,
geometry, time, velocity, pressure, displacement, and observation operators.
Velocity and pressure operator parity are tracked separately so Figure 4-style
and Figure 5-style seams do not collapse into one status.
"""
struct NativeResolvedFSIParityResult
    spec::NativeResolvedFSIParitySpec
    native_bundle::Union{Nothing,Resolved3DFieldBundle}
    imported_bundle::Union{Nothing,Resolved3DFieldBundle}
    native_operator_field::Union{Nothing,Resolved3DVelocityField}
    imported_operator_field::Union{Nothing,Resolved3DVelocityField}
    schema_status::NativeResolvedFSIParityStatus
    geometry_status::NativeResolvedFSIParityStatus
    time_status::NativeResolvedFSIParityStatus
    velocity_status::NativeResolvedFSIParityStatus
    pressure_status::NativeResolvedFSIParityStatus
    displacement_status::NativeResolvedFSIParityStatus
    velocity_operator_status::NativeResolvedFSIParityStatus
    pressure_operator_status::NativeResolvedFSIParityStatus
    operator_status::NativeResolvedFSIParityStatus
end

workflow_kind(::NativeResolvedFSIParitySpec) = "native_resolved_fsi_parity"

function validate(spec::NativeResolvedFSIParitySpec)
    spec.coordinate_mode in ("reference", "deformed") ||
        throw(ArgumentError("native resolved-FSI parity coordinate_mode must be reference or deformed"))
    spec.radial_bin_count > 0 || throw(ArgumentError("native resolved-FSI parity radial_bin_count must be positive"))
    !isempty(spec.node_slab_half_widths_cm) ||
        throw(ArgumentError("native resolved-FSI parity needs at least one node slab half width"))
    all(isfinite, spec.sample_z_cm) || throw(ArgumentError("native resolved-FSI parity sample_z_cm must be finite"))
    all(isfinite, spec.radial_profile_z_cm) ||
        throw(ArgumentError("native resolved-FSI parity radial_profile_z_cm must be finite"))
    all(>(0.0), spec.node_slab_half_widths_cm) ||
        throw(ArgumentError("native resolved-FSI parity node slab half widths must be positive"))
    spec.geometry_atol_cm >= 0.0 || throw(ArgumentError("native resolved-FSI parity geometry_atol_cm must be nonnegative"))
    spec.time_atol_s >= 0.0 || throw(ArgumentError("native resolved-FSI parity time_atol_s must be nonnegative"))
    spec.velocity_atol_cm_s >= 0.0 ||
        throw(ArgumentError("native resolved-FSI parity velocity_atol_cm_s must be nonnegative"))
    spec.pressure_atol_dyn_cm2 >= 0.0 ||
        throw(ArgumentError("native resolved-FSI parity pressure_atol_dyn_cm2 must be nonnegative"))
    spec.displacement_atol_cm >= 0.0 ||
        throw(ArgumentError("native resolved-FSI parity displacement_atol_cm must be nonnegative"))
    spec.operator_atol >= 0.0 || throw(ArgumentError("native resolved-FSI parity operator_atol must be nonnegative"))
    return spec
end

"""
    run_native_resolved_fsi_parity(spec)

Load native and imported bundles through `load_resolved3d_field_bundle(...;
require_pressure=true, require_displacement=true)`, compare their schema,
geometry, time, and nodewise fields, then compare velocity and pressure
cross-sectional observation seams separately. The current operator surface
still stops short of claiming full Section 4.1 transient/grid parity.
"""
function run_native_resolved_fsi_parity(spec::NativeResolvedFSIParitySpec)
    validate(spec)

    native_bundle = native_resolved_fsi_parity_load_required_case(spec.native_case, "native")
    imported_bundle, imported_issue = native_resolved_fsi_parity_load_imported_case(spec.imported_case, spec.require_imported)
    native_operator_field = resolved3d_velocity_field_from_bundle(native_bundle, spec.coordinate_mode)

    if imported_bundle === nothing
        imported_operator_field = nothing
        schema_status = native_resolved_fsi_parity_issue_status("schema", imported_issue)
        geometry_status = native_resolved_fsi_parity_issue_status("geometry", imported_issue)
        time_status = native_resolved_fsi_parity_issue_status("time", imported_issue)
        velocity_status = native_resolved_fsi_parity_issue_status("velocity", imported_issue)
        pressure_status = native_resolved_fsi_parity_issue_status("pressure", imported_issue)
        displacement_status = native_resolved_fsi_parity_issue_status("displacement", imported_issue)
        velocity_operator_status = native_resolved_fsi_parity_issue_status("velocity operator", imported_issue)
        pressure_operator_status = native_resolved_fsi_parity_issue_status("pressure operator", imported_issue)
        operator_status = native_resolved_fsi_parity_combined_operator_status(
            velocity_operator_status,
            pressure_operator_status,
        )
        return NativeResolvedFSIParityResult(
            spec,
            native_bundle,
            nothing,
            native_operator_field,
            imported_operator_field,
            schema_status,
            geometry_status,
            time_status,
            velocity_status,
            pressure_status,
            displacement_status,
            velocity_operator_status,
            pressure_operator_status,
            operator_status,
        )
    end

    imported_operator_field = resolved3d_velocity_field_from_bundle(imported_bundle, spec.coordinate_mode)

    schema_status = native_resolved_fsi_parity_schema_status(native_bundle, imported_bundle)
    geometry_status = native_resolved_fsi_parity_geometry_status(native_bundle, imported_bundle, spec.geometry_atol_cm)
    time_status = native_resolved_fsi_parity_time_status(native_bundle, imported_bundle, spec.time_atol_s)
    velocity_status = native_resolved_fsi_parity_velocity_status(native_bundle, imported_bundle, spec.velocity_atol_cm_s)
    pressure_status = native_resolved_fsi_parity_pressure_status(
        native_bundle,
        imported_bundle,
        native_operator_field,
        imported_operator_field,
        spec.pressure_atol_dyn_cm2,
    )
    displacement_status = native_resolved_fsi_parity_displacement_status(
        native_bundle,
        imported_bundle,
        spec.displacement_atol_cm,
    )
    velocity_operator_status = native_resolved_fsi_parity_velocity_operator_status(
        native_operator_field,
        imported_operator_field,
        spec,
    )
    pressure_operator_status = native_resolved_fsi_parity_pressure_operator_status(
        native_bundle,
        imported_bundle,
        native_operator_field,
        imported_operator_field,
        spec,
    )
    operator_status = native_resolved_fsi_parity_combined_operator_status(
        velocity_operator_status,
        pressure_operator_status,
    )

    return NativeResolvedFSIParityResult(
        spec,
        native_bundle,
        imported_bundle,
        native_operator_field,
        imported_operator_field,
        schema_status,
        geometry_status,
        time_status,
        velocity_status,
        pressure_status,
        displacement_status,
        velocity_operator_status,
        pressure_operator_status,
        operator_status,
    )
end

run_native_resolved_fsi(spec::NativeResolvedFSIParitySpec) = run_native_resolved_fsi_parity(spec)

function run_native_resolved_fsi_parity(
    native_case::Resolved3DCaseSpec,
    imported_case::Resolved3DCaseSpec;
    kwargs...,
)
    return run_native_resolved_fsi_parity(NativeResolvedFSIParitySpec(native_case, imported_case; kwargs...))
end

function run_native_resolved_fsi_parity(
    native_velocity_xdmf::AbstractString,
    imported_velocity_xdmf::AbstractString;
    kwargs...,
)
    return run_native_resolved_fsi_parity(NativeResolvedFSIParitySpec(native_velocity_xdmf, imported_velocity_xdmf; kwargs...))
end

function native_resolved_fsi_parity_coordinate_mode(value::AbstractString)
    mode = replace(lowercase(strip(String(value))), "_" => "-")
    mode in ("reference", "deformed") || throw(ArgumentError("coordinate_mode must be reference or deformed"))
    return mode
end

function native_resolved_fsi_parity_load_required_case(case_spec::Resolved3DCaseSpec, label::String)
    missing = native_resolved_fsi_parity_missing_paths(case_spec)
    isempty(missing) || throw(ArgumentError("$label bundle is missing required three-field XDMF inputs: $(join(missing, ", "))"))
    return load_resolved3d_field_bundle(case_spec; require_pressure=true, require_displacement=true)
end

function native_resolved_fsi_parity_load_imported_case(case_spec::Resolved3DCaseSpec, require_imported::Bool)
    missing = native_resolved_fsi_parity_missing_paths(case_spec)
    if !isempty(missing)
        message = "imported bundle is missing required three-field XDMF inputs: $(join(missing, ", "))"
        require_imported && throw(ArgumentError(message))
        return nothing, native_resolved_fsi_parity_status(false, true, 0, NaN, message)
    end

    try
        return load_resolved3d_field_bundle(case_spec; require_pressure=true, require_displacement=true), nothing
    catch error
        require_imported && rethrow()
        return nothing, native_resolved_fsi_parity_status(
            false,
            false,
            1,
            NaN,
            "imported bundle could not be loaded through load_resolved3d_field_bundle: $(sprint(showerror, error))",
        )
    end
end

function native_resolved_fsi_parity_missing_paths(case_spec::Resolved3DCaseSpec)
    missing = String[]
    for (label, path) in (
        ("velocity", case_spec.velocity_xdmf),
        ("pressure", case_spec.pressure_xdmf),
        ("displacement", case_spec.displacement_xdmf),
    )
        if isempty(path) || !isfile(path)
            pretty_path = isempty(path) ? "<empty>" : path
            push!(missing, "$label=$pretty_path")
        end
    end
    return missing
end

function native_resolved_fsi_parity_issue_status(label::String, issue::NativeResolvedFSIParityStatus)
    prefix = issue.skipped ? "skipped" : "unavailable"
    return native_resolved_fsi_parity_status(
        false,
        issue.skipped,
        issue.discrepancy_count,
        issue.max_abs_difference,
        "$prefix: $label parity did not run because $(issue.status)",
    )
end

function native_resolved_fsi_parity_schema_status(
    native_bundle::Resolved3DFieldBundle,
    imported_bundle::Resolved3DFieldBundle,
)
    comparisons = (
        ("coordinate dimensions", size(native_bundle.velocity.coordinates), size(imported_bundle.velocity.coordinates)),
        ("topology dimensions", size(native_bundle.velocity.topology), size(imported_bundle.velocity.topology)),
        ("velocity dimensions", size(native_bundle.velocity.velocity), size(imported_bundle.velocity.velocity)),
        ("pressure dimensions", size(native_resolved_fsi_parity_required_pressure(native_bundle)), size(native_resolved_fsi_parity_required_pressure(imported_bundle))),
        ("displacement dimensions", size(native_resolved_fsi_parity_required_displacement(native_bundle)), size(native_resolved_fsi_parity_required_displacement(imported_bundle))),
    )
    discrepancy_count = count(comparison -> comparison[2] != comparison[3], comparisons)
    ready = discrepancy_count == 0
    status = ready ?
        "schema parity matched across velocity/pressure/displacement bundle dimensions" :
        "schema parity found $discrepancy_count dimension mismatches between native and imported bundles"
    return native_resolved_fsi_parity_status(ready, false, discrepancy_count, ready ? 0.0 : NaN, status)
end

function native_resolved_fsi_parity_geometry_status(
    native_bundle::Resolved3DFieldBundle,
    imported_bundle::Resolved3DFieldBundle,
    atol::Float64,
)
    native_coordinates = native_bundle.velocity.coordinates
    imported_coordinates = imported_bundle.velocity.coordinates
    native_topology = native_bundle.velocity.topology
    imported_topology = imported_bundle.velocity.topology

    size(native_coordinates) == size(imported_coordinates) || return native_resolved_fsi_parity_status(
        false,
        false,
        1,
        NaN,
        "geometry parity requires matching coordinate dimensions",
    )
    size(native_topology) == size(imported_topology) || return native_resolved_fsi_parity_status(
        false,
        false,
        1,
        NaN,
        "geometry parity requires matching topology dimensions",
    )

    coordinate_discrepancies, max_coordinate_difference = native_resolved_fsi_parity_diff_summary(
        native_coordinates,
        imported_coordinates,
        atol,
    )
    topology_discrepancies = native_resolved_fsi_parity_exact_difference_count(native_topology, imported_topology)
    discrepancy_count = coordinate_discrepancies + topology_discrepancies
    ready = discrepancy_count == 0
    status = ready ?
        "reference geometry/topology matched within $(atol) cm" :
        "geometry parity found $coordinate_discrepancies coordinate entries above tolerance and $topology_discrepancies topology mismatches"
    return native_resolved_fsi_parity_status(ready, false, discrepancy_count, max_coordinate_difference, status)
end

function native_resolved_fsi_parity_time_status(
    native_bundle::Resolved3DFieldBundle,
    imported_bundle::Resolved3DFieldBundle,
    atol::Float64,
)
    native_pressure_meta = native_resolved_fsi_parity_required_metadata(native_bundle.pressure_metadata, "native pressure")
    imported_pressure_meta = native_resolved_fsi_parity_required_metadata(imported_bundle.pressure_metadata, "imported pressure")
    native_displacement_meta = native_resolved_fsi_parity_required_metadata(native_bundle.displacement_metadata, "native displacement")
    imported_displacement_meta = native_resolved_fsi_parity_required_metadata(imported_bundle.displacement_metadata, "imported displacement")

    differences = [
        abs(native_bundle.velocity.metadata.time - imported_bundle.velocity.metadata.time),
        abs(native_pressure_meta.time - imported_pressure_meta.time),
        abs(native_displacement_meta.time - imported_displacement_meta.time),
    ]
    discrepancy_count = count(>(atol), differences)
    ready = discrepancy_count == 0
    max_difference = isempty(differences) ? 0.0 : maximum(differences)
    status = ready ?
        "native and imported bundles share velocity/pressure/displacement time stamps within $(atol) s" :
        "time parity found $discrepancy_count metadata differences above $(atol) s"
    return native_resolved_fsi_parity_status(ready, false, discrepancy_count, max_difference, status)
end

function native_resolved_fsi_parity_velocity_status(
    native_bundle::Resolved3DFieldBundle,
    imported_bundle::Resolved3DFieldBundle,
    atol::Float64,
)
    comparable, reason = native_resolved_fsi_parity_nodewise_comparable(native_bundle, imported_bundle)
    comparable || return native_resolved_fsi_parity_status(false, false, 1, NaN, "velocity parity did not run because $reason")

    discrepancies, max_difference = native_resolved_fsi_parity_diff_summary(
        native_bundle.velocity.velocity,
        imported_bundle.velocity.velocity,
        atol,
    )
    ready = discrepancies == 0
    status = ready ?
        "nodewise velocity parity matched within $(atol) cm/s" :
        "nodewise velocity parity found $discrepancies entries above $(atol) cm/s"
    return native_resolved_fsi_parity_status(ready, false, discrepancies, max_difference, status)
end

function native_resolved_fsi_parity_pressure_status(
    native_bundle::Resolved3DFieldBundle,
    imported_bundle::Resolved3DFieldBundle,
    native_field::Resolved3DVelocityField,
    imported_field::Resolved3DVelocityField,
    atol::Float64,
)
    comparable, reason = native_resolved_fsi_parity_nodewise_comparable(native_bundle, imported_bundle)
    comparable || return native_resolved_fsi_parity_status(false, false, 1, NaN, "pressure diagnostic did not run because $reason")

    native_pressure = native_resolved_fsi_parity_required_pressure(native_bundle)
    imported_pressure = native_resolved_fsi_parity_required_pressure(imported_bundle)
    native_gauge = native_resolved_fsi_parity_pressure_gauge(native_field, native_pressure)
    imported_gauge = native_resolved_fsi_parity_pressure_gauge(imported_field, imported_pressure)
    if !native_gauge.ready || !imported_gauge.ready
        return native_resolved_fsi_parity_status(
            false,
            false,
            1,
            NaN,
            "nodewise pressure diagnostic requires finite outlet-gauge cuts for native and imported bundles; native=$(native_gauge.status); imported=$(imported_gauge.status)",
        )
    end

    native_gauged_pressure = native_resolved_fsi_parity_apply_pressure_gauge(native_pressure, native_gauge)
    imported_gauged_pressure = native_resolved_fsi_parity_apply_pressure_gauge(imported_pressure, imported_gauge)
    discrepancies, max_difference = native_resolved_fsi_parity_diff_summary(
        native_gauged_pressure,
        imported_gauged_pressure,
        atol,
    )
    ready = discrepancies == 0
    status = ready ?
        "nodewise pressure diagnostic matched within $(atol) dyn/cm^2 after common Section 4.1 outlet-gauge normalization; status=$(NATIVE_RESOLVED_FSI_PARITY_PRESSURE_STATUS)" :
        "nodewise pressure discrepancy status=$(NATIVE_RESOLVED_FSI_PARITY_PRESSURE_STATUS); found $discrepancies outlet-gauged entries above $(atol) dyn/cm^2; $(NATIVE_RESOLVED_FSI_PARITY_PRESSURE_POLICY)"
    return native_resolved_fsi_parity_status(ready, false, discrepancies, max_difference, status)
end

function native_resolved_fsi_parity_displacement_status(
    native_bundle::Resolved3DFieldBundle,
    imported_bundle::Resolved3DFieldBundle,
    atol::Float64,
)
    comparable, reason = native_resolved_fsi_parity_nodewise_comparable(native_bundle, imported_bundle)
    comparable || return native_resolved_fsi_parity_status(false, false, 1, NaN, "displacement parity did not run because $reason")

    native_displacement = native_resolved_fsi_parity_required_displacement(native_bundle)
    imported_displacement = native_resolved_fsi_parity_required_displacement(imported_bundle)
    native_deformed = native_resolved_fsi_parity_required_deformed_coordinates(native_bundle)
    imported_deformed = native_resolved_fsi_parity_required_deformed_coordinates(imported_bundle)

    displacement_discrepancies, max_displacement_difference = native_resolved_fsi_parity_diff_summary(
        native_displacement,
        imported_displacement,
        atol,
    )
    deformed_discrepancies, max_deformed_difference = native_resolved_fsi_parity_diff_summary(
        native_deformed,
        imported_deformed,
        atol,
    )

    discrepancy_count = displacement_discrepancies + deformed_discrepancies
    ready = discrepancy_count == 0
    max_difference = max(max_displacement_difference, max_deformed_difference)
    status = ready ?
        "nodewise displacement and derived deformed coordinates matched within $(atol) cm" :
        "displacement parity found $displacement_discrepancies displacement entries and $deformed_discrepancies derived deformed-coordinate entries above $(atol) cm"
    return native_resolved_fsi_parity_status(ready, false, discrepancy_count, max_difference, status)
end

function native_resolved_fsi_parity_velocity_operator_status(
    native_field::Resolved3DVelocityField,
    imported_field::Resolved3DVelocityField,
    spec::NativeResolvedFSIParitySpec,
)
    z_samples = isempty(spec.sample_z_cm) ?
        native_resolved_fsi_parity_default_sample_z(native_field, imported_field) :
        spec.sample_z_cm
    profile_z_samples, unmatched_profile_z_count = native_resolved_fsi_parity_profile_z_samples(
        spec.radial_profile_z_cm,
        z_samples,
    )

    isempty(z_samples) && return native_resolved_fsi_parity_status(
        false,
        false,
        1,
        NaN,
        "operator parity requires an overlapping z-range between the native and imported fields",
    )

    discrepancy_count = Ref(0)
    numeric_differences = Float64[]
    quadrature_operator = CrossSectionQuadratureOperator()
    discrepancy_count[] += unmatched_profile_z_count

    for z in z_samples
        native_observation = section_observation(native_field, z, quadrature_operator)
        imported_observation = section_observation(imported_field, z, quadrature_operator)
        native_resolved_fsi_parity_compare_bool!(discrepancy_count, native_observation.area_valid, imported_observation.area_valid)
        native_resolved_fsi_parity_compare_exact!(discrepancy_count, native_observation.cut_status, imported_observation.cut_status)
        native_resolved_fsi_parity_compare_exact!(discrepancy_count, native_observation.intersection_count, imported_observation.intersection_count)
        native_resolved_fsi_parity_compare_scalar!(
            numeric_differences,
            discrepancy_count,
            native_observation.area_cm2,
            imported_observation.area_cm2,
            spec.operator_atol,
        )
        native_resolved_fsi_parity_compare_scalar!(
            numeric_differences,
            discrepancy_count,
            native_observation.flow_cm3_s,
            imported_observation.flow_cm3_s,
            spec.operator_atol,
        )
        native_resolved_fsi_parity_compare_scalar!(
            numeric_differences,
            discrepancy_count,
            native_observation.mean_velocity_cm_s,
            imported_observation.mean_velocity_cm_s,
            spec.operator_atol,
        )
    end

    for half_width in spec.node_slab_half_widths_cm
        operator = NodeSlabOperator(half_width_cm=half_width)
        for z in z_samples
            native_observation = section_observation(native_field, z, operator)
            imported_observation = section_observation(imported_field, z, operator)
            native_resolved_fsi_parity_compare_exact!(discrepancy_count, native_observation.cut_status, imported_observation.cut_status)
            native_resolved_fsi_parity_compare_exact!(discrepancy_count, native_observation.node_count, imported_observation.node_count)
            native_resolved_fsi_parity_compare_scalar!(
                numeric_differences,
                discrepancy_count,
                native_observation.mean_velocity_cm_s,
                imported_observation.mean_velocity_cm_s,
                spec.operator_atol,
            )
            native_resolved_fsi_parity_compare_scalar!(
                numeric_differences,
                discrepancy_count,
                native_observation.observed_radius_cm,
                imported_observation.observed_radius_cm,
                spec.operator_atol,
            )
        end
    end

    for z in profile_z_samples
        radius_scale = native_resolved_fsi_parity_profile_radius_scale(native_field, imported_field, z, spec)
        if !isfinite(radius_scale) || radius_scale <= 0.0
            discrepancy_count[] += 1
            continue
        end
        native_profiles = radial_profile_observations(native_field, z, radius_scale, spec.radial_bin_count, quadrature_operator)
        imported_profiles = radial_profile_observations(imported_field, z, radius_scale, spec.radial_bin_count, quadrature_operator)
        for bin in eachindex(native_profiles, imported_profiles)
            native_row = native_profiles[bin]
            imported_row = imported_profiles[bin]
            native_resolved_fsi_parity_compare_bool!(discrepancy_count, native_row.area_valid, imported_row.area_valid)
            native_resolved_fsi_parity_compare_exact!(discrepancy_count, native_row.intersection_count, imported_row.intersection_count)
            native_resolved_fsi_parity_compare_scalar!(
                numeric_differences,
                discrepancy_count,
                native_row.mean_velocity_cm_s,
                imported_row.mean_velocity_cm_s,
                spec.operator_atol,
            )
            native_resolved_fsi_parity_compare_scalar!(
                numeric_differences,
                discrepancy_count,
                native_row.velocity_variance_cm2_s2,
                imported_row.velocity_variance_cm2_s2,
                spec.operator_atol,
            )
        end
    end

    max_difference = isempty(numeric_differences) ? 0.0 : maximum(numeric_differences)
    if discrepancy_count[] > 0
        unmatched_profile_message = unmatched_profile_z_count == 0 ? "" :
            "; $(unmatched_profile_z_count) radial profile z-cut(s) were not evaluated because they do not match section sample_z_cm"
        return native_resolved_fsi_parity_status(
            false,
            false,
            discrepancy_count[],
            max_difference,
            "velocity observation parity found $(discrepancy_count[]) section/radial/node-slab discrepancies above $(spec.operator_atol)$(unmatched_profile_message)",
        )
    end

    return native_resolved_fsi_parity_status(
        true,
        false,
        0,
        max_difference,
        "velocity section/radial/node-slab observations matched within $(spec.operator_atol)",
    )
end

function native_resolved_fsi_parity_pressure_operator_status(
    native_bundle::Resolved3DFieldBundle,
    imported_bundle::Resolved3DFieldBundle,
    native_field::Resolved3DVelocityField,
    imported_field::Resolved3DVelocityField,
    spec::NativeResolvedFSIParitySpec,
)
    z_samples = isempty(spec.sample_z_cm) ?
        native_resolved_fsi_parity_default_sample_z(native_field, imported_field) :
        spec.sample_z_cm

    isempty(z_samples) && return native_resolved_fsi_parity_status(
        false,
        false,
        1,
        NaN,
        "pressure operator diagnostic requires an overlapping z-range between the native and imported fields",
    )

    native_pressure = native_resolved_fsi_parity_required_pressure(native_bundle)
    imported_pressure = native_resolved_fsi_parity_required_pressure(imported_bundle)
    native_gauge = native_resolved_fsi_parity_pressure_gauge(native_field, native_pressure)
    imported_gauge = native_resolved_fsi_parity_pressure_gauge(imported_field, imported_pressure)
    if !native_gauge.ready || !imported_gauge.ready
        return native_resolved_fsi_parity_status(
            false,
            false,
            1,
            NaN,
            "pressure section-average operator diagnostic requires finite Section 4.1 outlet-gauge cuts; native=$(native_gauge.status); imported=$(imported_gauge.status)",
        )
    end

    discrepancy_count = Ref(0)
    numeric_differences = Float64[]

    for z in z_samples
        native_observation = native_resolved_fsi_parity_pressure_section_observation(
            native_field,
            native_pressure,
            z;
            gauge=native_gauge,
        )
        imported_observation = native_resolved_fsi_parity_pressure_section_observation(
            imported_field,
            imported_pressure,
            z;
            gauge=imported_gauge,
        )
        native_resolved_fsi_parity_compare_bool!(discrepancy_count, native_observation.area_valid, imported_observation.area_valid)
        native_resolved_fsi_parity_compare_exact!(discrepancy_count, native_observation.cut_status, imported_observation.cut_status)
        native_resolved_fsi_parity_compare_exact!(discrepancy_count, native_observation.intersection_count, imported_observation.intersection_count)
        native_resolved_fsi_parity_compare_scalar!(
            numeric_differences,
            discrepancy_count,
            native_observation.area_cm2,
            imported_observation.area_cm2,
            spec.operator_atol,
        )
        native_resolved_fsi_parity_compare_scalar!(
            numeric_differences,
            discrepancy_count,
            native_observation.mean_pressure_dyn_cm2,
            imported_observation.mean_pressure_dyn_cm2,
            spec.operator_atol,
        )
    end

    max_difference = isempty(numeric_differences) ? 0.0 : maximum(numeric_differences)
    ready = discrepancy_count[] == 0
    status = ready ?
        "pressure section-average operator diagnostics matched within $(spec.operator_atol) after common Section 4.1 outlet-gauge normalization; status=$(NATIVE_RESOLVED_FSI_PARITY_PRESSURE_STATUS)" :
        "pressure section-average discrepancy status=$(NATIVE_RESOLVED_FSI_PARITY_PRESSURE_STATUS); found $(discrepancy_count[]) outlet-gauged diagnostics above $(spec.operator_atol); $(NATIVE_RESOLVED_FSI_PARITY_PRESSURE_POLICY)"
    return native_resolved_fsi_parity_status(ready, false, discrepancy_count[], max_difference, status)
end

function native_resolved_fsi_parity_combined_operator_status(
    velocity_status::NativeResolvedFSIParityStatus,
    pressure_status::NativeResolvedFSIParityStatus,
)
    skipped = velocity_status.skipped && pressure_status.skipped
    ready = velocity_status.ready && pressure_status.ready
    discrepancy_count = velocity_status.discrepancy_count + pressure_status.discrepancy_count
    max_difference = if skipped
        NaN
    else
        differences = Float64[
            value for value in (velocity_status.max_abs_difference, pressure_status.max_abs_difference) if isfinite(value)
        ]
        isempty(differences) ? 0.0 : maximum(differences)
    end
    status = if skipped
        "skipped: operator parity did not run because $(velocity_status.status)"
    elseif ready
        "velocity operator parity and outlet-gauged pressure operator diagnostics matched within configured tolerances"
    else
        "operator readiness summary: velocity=$(velocity_status.status); pressure=$(pressure_status.status)"
    end
    return native_resolved_fsi_parity_status(ready, skipped, discrepancy_count, max_difference, status)
end

function native_resolved_fsi_parity_pressure_section_observation(
    field::Resolved3DVelocityField,
    pressure::AbstractVector{<:Real},
    z::Float64,
    ;
    gauge = native_resolved_fsi_parity_pressure_gauge(field, pressure),
)
    observation = native_resolved_fsi_parity_raw_pressure_section_observation(field, pressure, z)
    mean_pressure = observation.area_valid && gauge.ready ?
        observation.mean_pressure_dyn_cm2 - gauge.offset_dyn_cm2 :
        NaN
    return (
        area_cm2=observation.area_cm2,
        mean_pressure_dyn_cm2=mean_pressure,
        raw_mean_pressure_dyn_cm2=observation.mean_pressure_dyn_cm2,
        pressure_gauge_offset_dyn_cm2=gauge.offset_dyn_cm2,
        pressure_gauge_z_cm=gauge.z_cm,
        pressure_gauge_status=gauge.status,
        intersection_count=observation.intersection_count,
        area_valid=observation.area_valid,
        cut_status=observation.cut_status,
        observed_radius_cm=observation.observed_radius_cm,
    )
end

function native_resolved_fsi_parity_raw_pressure_section_observation(
    field::Resolved3DVelocityField,
    pressure::AbstractVector{<:Real},
    z::Float64,
)
    area = 0.0
    weighted_pressure = 0.0
    count = 0
    observed_radius = 0.0
    degenerate_count = 0

    for tet in eachrow(field.topology)
        polygon = native_resolved_fsi_parity_tetra_plane_scalar_polygon(field.coordinates, field.topology, pressure, tet, z)
        if 0 < length(polygon) < 3
            degenerate_count += 1
            continue
        end
        length(polygon) >= 3 || continue
        center = polygon_center(polygon)
        tet_triangles = 0
        for i in eachindex(polygon)
            p1 = polygon[i]
            p2 = polygon[mod1(i + 1, length(polygon))]
            tri_area = triangle_area_xy(center, p1, p2)
            tri_area > 1.0e-14 || continue
            tri_pressure = (center[4] + p1[4] + p2[4]) / 3.0
            area += tri_area
            weighted_pressure += tri_area * tri_pressure
            count += 1
            tet_triangles += 1
            observed_radius = max(observed_radius, hypot(p1[1], p1[2]), hypot(p2[1], p2[2]))
        end
        tet_triangles > 0 || (degenerate_count += 1)
    end

    area_valid = area > 0.0 && isfinite(area)
    cut_status = area_valid ? "valid" : (degenerate_count > 0 ? "degenerate-cut" : "empty-plane")
    return (
        area_cm2=area_valid ? area : NaN,
        mean_pressure_dyn_cm2=area_valid ? weighted_pressure / area : NaN,
        intersection_count=count,
        area_valid=area_valid,
        cut_status=cut_status,
        observed_radius_cm=area_valid ? observed_radius : NaN,
    )
end

function native_resolved_fsi_parity_pressure_gauge(
    field::Resolved3DVelocityField,
    pressure::AbstractVector{<:Real},
)
    gauge_z = NATIVE_RESOLVED_FSI_PARITY_PRESSURE_GAUGE_Z_CM
    observation = native_resolved_fsi_parity_raw_pressure_section_observation(field, pressure, gauge_z)
    ready = observation.area_valid && isfinite(observation.mean_pressure_dyn_cm2)
    status = ready ?
        "$(NATIVE_RESOLVED_FSI_PARITY_PRESSURE_STATUS); gauge_z_cm=$(gauge_z)" :
        "$(NATIVE_RESOLVED_FSI_PARITY_PRESSURE_GAUGE_UNAVAILABLE_STATUS); gauge_z_cm=$(gauge_z); cut_status=$(observation.cut_status)"
    return (
        ready=ready,
        z_cm=gauge_z,
        offset_dyn_cm2=ready ? observation.mean_pressure_dyn_cm2 : NaN,
        status=status,
        observation=observation,
    )
end

function native_resolved_fsi_parity_apply_pressure_gauge(
    pressure::AbstractVector{<:Real},
    gauge,
)
    gauge.ready || return fill(NaN, length(pressure))
    return Float64[Float64(value) - gauge.offset_dyn_cm2 for value in pressure]
end

function native_resolved_fsi_parity_tetra_plane_scalar_polygon(
    coordinates::Matrix{Float64},
    topology::Matrix{Int},
    scalar_values::AbstractVector{<:Real},
    tet,
    z::Float64,
)
    size(coordinates, 1) == length(scalar_values) ||
        throw(DimensionMismatch("scalar section observation requires one scalar value per node"))

    points = NTuple{4,Float64}[]
    for local_index in 1:4
        node = tet[local_index]
        dz = coordinates[node, 3] - z
        if abs(dz) <= PLANE_INTERSECTION_TOL
            native_resolved_fsi_parity_push_unique_scalar_intersection!(points, coordinates, scalar_values, node)
        end
    end

    for (a, b) in TETRA_EDGES
        ia = tet[a]
        ib = tet[b]
        za = coordinates[ia, 3]
        zb = coordinates[ib, 3]
        da = za - z
        db = zb - z
        if (da < -PLANE_INTERSECTION_TOL && db > PLANE_INTERSECTION_TOL) ||
           (da > PLANE_INTERSECTION_TOL && db < -PLANE_INTERSECTION_TOL)
            weight = (z - za) / (zb - za)
            native_resolved_fsi_parity_push_unique_scalar_intersection!(
                points,
                coordinates,
                scalar_values,
                ia,
                ib,
                weight,
                z,
            )
        end
    end

    length(points) >= 3 || return points
    center = polygon_center(points)
    sort!(points; by=point -> atan(point[2] - center[2], point[1] - center[1]))
    return points
end

function native_resolved_fsi_parity_push_unique_scalar_intersection!(
    points::Vector{NTuple{4,Float64}},
    coordinates::Matrix{Float64},
    scalar_values::AbstractVector{<:Real},
    node::Int,
)
    point = (
        coordinates[node, 1],
        coordinates[node, 2],
        coordinates[node, 3],
        Float64(scalar_values[node]),
    )
    return push_unique_intersection!(points, point)
end

function native_resolved_fsi_parity_push_unique_scalar_intersection!(
    points::Vector{NTuple{4,Float64}},
    coordinates::Matrix{Float64},
    scalar_values::AbstractVector{<:Real},
    left::Int,
    right::Int,
    weight::Float64,
    z::Float64,
)
    point = (
        (1.0 - weight) * coordinates[left, 1] + weight * coordinates[right, 1],
        (1.0 - weight) * coordinates[left, 2] + weight * coordinates[right, 2],
        z,
        (1.0 - weight) * Float64(scalar_values[left]) + weight * Float64(scalar_values[right]),
    )
    return push_unique_intersection!(points, point)
end

function native_resolved_fsi_parity_default_sample_z(
    native_field::Resolved3DVelocityField,
    imported_field::Resolved3DVelocityField,
)
    z_min, z_max = native_resolved_fsi_parity_overlap_bounds(native_field, imported_field)
    z_min <= z_max || return Float64[]
    span = z_max - z_min
    span <= 1.0e-12 && return [z_min]
    return [z_min + 0.25 * span, z_min + 0.5 * span, z_min + 0.75 * span]
end

function native_resolved_fsi_parity_profile_z_samples(
    requested_profile_z::AbstractVector{<:Real},
    section_z_samples::AbstractVector{<:Real},
)
    isempty(requested_profile_z) && return (Float64[Float64(z) for z in section_z_samples], 0)
    matched = Float64[]
    unmatched_count = 0
    for requested_z in requested_profile_z
        section_index = findfirst(z -> isapprox(z, requested_z; atol=1.0e-9), section_z_samples)
        if section_index === nothing
            unmatched_count += 1
            continue
        end
        section_z = Float64(section_z_samples[section_index])
        any(z -> isapprox(z, section_z; atol=1.0e-9), matched) || push!(matched, section_z)
    end
    return matched, unmatched_count
end

function native_resolved_fsi_parity_overlap_bounds(
    native_field::Resolved3DVelocityField,
    imported_field::Resolved3DVelocityField,
)
    native_z = view(native_field.coordinates, :, 3)
    imported_z = view(imported_field.coordinates, :, 3)
    z_min = max(minimum(native_z), minimum(imported_z))
    z_max = min(maximum(native_z), maximum(imported_z))
    return z_min, z_max
end

function native_resolved_fsi_parity_profile_radius_scale(
    native_field::Resolved3DVelocityField,
    imported_field::Resolved3DVelocityField,
    z::Float64,
    spec::NativeResolvedFSIParitySpec,
)
    half_width = maximum(spec.node_slab_half_widths_cm)
    node_slab = NodeSlabOperator(half_width_cm=half_width)
    native_radius = section_observation(native_field, z, node_slab).observed_radius_cm
    imported_radius = section_observation(imported_field, z, node_slab).observed_radius_cm
    radii = [radius for radius in (native_radius, imported_radius) if isfinite(radius) && radius > 0.0]
    isempty(radii) && return NaN
    return maximum(radii)
end

function native_resolved_fsi_parity_nodewise_comparable(
    native_bundle::Resolved3DFieldBundle,
    imported_bundle::Resolved3DFieldBundle,
)
    size(native_bundle.velocity.coordinates) == size(imported_bundle.velocity.coordinates) ||
        return false, "coordinate dimensions differ"
    size(native_bundle.velocity.topology) == size(imported_bundle.velocity.topology) ||
        return false, "topology dimensions differ"
    native_bundle.velocity.topology == imported_bundle.velocity.topology ||
        return false, "topology values differ"
    return true, ""
end

function native_resolved_fsi_parity_diff_summary(native_values, imported_values, atol::Float64)
    size(native_values) == size(imported_values) || throw(DimensionMismatch("parity diff summary requires matching dimensions"))
    discrepancy_count = 0
    max_difference = 0.0
    for index in eachindex(native_values)
        difference = abs(Float64(native_values[index]) - Float64(imported_values[index]))
        max_difference = max(max_difference, difference)
        difference > atol && (discrepancy_count += 1)
    end
    return discrepancy_count, max_difference
end

function native_resolved_fsi_parity_exact_difference_count(native_values, imported_values)
    size(native_values) == size(imported_values) || throw(DimensionMismatch("exact parity comparison requires matching dimensions"))
    discrepancy_count = 0
    for index in eachindex(native_values)
        native_values[index] == imported_values[index] || (discrepancy_count += 1)
    end
    return discrepancy_count
end

function native_resolved_fsi_parity_compare_scalar!(
    numeric_differences::Vector{Float64},
    discrepancy_count::Base.RefValue{Int},
    native_value,
    imported_value,
    atol::Float64,
)
    if isnan(native_value) && isnan(imported_value)
        return nothing
    end
    if isfinite(native_value) && isfinite(imported_value)
        difference = abs(Float64(native_value) - Float64(imported_value))
        push!(numeric_differences, difference)
        difference > atol && (discrepancy_count[] += 1)
        return nothing
    end
    push!(numeric_differences, Inf)
    discrepancy_count[] += 1
    return nothing
end

function native_resolved_fsi_parity_compare_exact!(
    discrepancy_count::Base.RefValue{Int},
    native_value,
    imported_value,
)
    native_value == imported_value || (discrepancy_count[] += 1)
    return nothing
end

function native_resolved_fsi_parity_compare_bool!(
    discrepancy_count::Base.RefValue{Int},
    native_value::Bool,
    imported_value::Bool,
)
    native_value == imported_value || (discrepancy_count[] += 1)
    return nothing
end

function native_resolved_fsi_parity_status(
    ready::Bool,
    skipped::Bool,
    discrepancy_count::Integer,
    max_abs_difference::Real,
    status::AbstractString,
)
    max_difference = skipped ? NaN : Float64(max_abs_difference)
    return NativeResolvedFSIParityStatus(
        ready,
        skipped,
        Int(discrepancy_count),
        max_difference,
        String(status),
    )
end

function native_resolved_fsi_parity_required_metadata(metadata::Union{Nothing,XDMFFieldMetadata}, label::String)
    metadata === nothing && error("$label metadata should exist after requiring the three-field bundle")
    return metadata
end

function native_resolved_fsi_parity_required_pressure(bundle::Resolved3DFieldBundle)
    bundle.pressure === nothing && error("pressure field should exist after requiring the three-field bundle")
    return bundle.pressure
end

function native_resolved_fsi_parity_required_displacement(bundle::Resolved3DFieldBundle)
    bundle.displacement === nothing && error("displacement field should exist after requiring the three-field bundle")
    return bundle.displacement
end

function native_resolved_fsi_parity_required_deformed_coordinates(bundle::Resolved3DFieldBundle)
    bundle.deformed_coordinates === nothing &&
        error("deformed coordinates should exist after requiring the displacement field")
    return bundle.deformed_coordinates
end

include("native_resolved_fsi_parity_production.jl")
