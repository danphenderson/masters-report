import EzXML
import HDF5
using Statistics

const DEFAULT_RESOLVED3D_DATA_ROOT = joinpath("simulations", "data", "3d", "canic_case3")
const DEFAULT_COMPARISON_OUTPUT_DIR = joinpath("simulations", "output", "3d_comparison")
const DEFAULT_NODE_SLAB_HALF_WIDTH_CM = 0.015
const DEFAULT_GRID_SENSITIVITY_NXS = [200, 400, 800]

"""
    Resolved3DCaseSpec(case_label, severity, velocity_xdmf; target_time=0.9995, time_atol=1e-3)

Reference 3D velocity case to compare against a 1D run. `velocity_xdmf` points
to the XDMF metadata file; the HDF5 paths referenced inside it are resolved
relative to that XDMF file.
"""
struct Resolved3DCaseSpec
    case_label::String
    severity::Float64
    velocity_xdmf::String
    target_time::Float64
    time_atol::Float64
end

function Resolved3DCaseSpec(
    case_label,
    severity,
    velocity_xdmf;
    target_time::Real = 0.9995,
    time_atol::Real = 1.0e-3,
)
    severity_value = Float64(severity)
    target_time_value = Float64(target_time)
    time_atol_value = Float64(time_atol)
    target_time_value >= 0.0 || throw(ArgumentError("target_time must be nonnegative"))
    time_atol_value >= 0.0 || throw(ArgumentError("time_atol must be nonnegative"))
    validate(Params(severity=severity_value, tfinal=target_time_value, initial_condition=GeometryRestIC()))
    return Resolved3DCaseSpec(
        string(case_label),
        severity_value,
        String(velocity_xdmf),
        target_time_value,
        time_atol_value,
    )
end

"""
Metadata parsed from an XDMF velocity file.
"""
struct XDMFVelocityMetadata
    time::Float64
    geometry_file::String
    geometry_path::String
    geometry_dims::Tuple{Int,Int}
    topology_file::String
    topology_path::String
    topology_dims::Tuple{Int,Int}
    velocity_file::String
    velocity_path::String
    velocity_dims::Tuple{Int,Int}
end

"""
Node-centered 3D coordinates and velocities loaded from HDF5.
"""
struct Resolved3DVelocityField
    case_spec::Resolved3DCaseSpec
    metadata::XDMFVelocityMetadata
    topology::Matrix{Int}
    coordinates::Matrix{Float64}
    velocity::Matrix{Float64}
end

abstract type AbstractResolved3DOperator end

"""Area quadrature over tetrahedron/plane intersections."""
struct CrossSectionQuadratureOperator <: AbstractResolved3DOperator end

"""Arithmetic mean of node-centered values in a finite axial slab."""
struct NodeSlabOperator <: AbstractResolved3DOperator
    half_width_cm::Float64
end

NodeSlabOperator(; half_width_cm::Real = DEFAULT_NODE_SLAB_HALF_WIDTH_CM) =
    NodeSlabOperator(Float64(half_width_cm))

operator_name(::CrossSectionQuadratureOperator) = "CrossSectionQuadratureOperator"
operator_name(::NodeSlabOperator) = "node-slab-arithmetic-mean"

"""
    ComparisonSpec(; cases, base_params, backend, operator, output_dir, ...)

Workflow spec for comparing one or more resolved-3D reference cases against 1D
runs. Resolved-3D extensions should provide a `Resolved3DCaseSpec`-like data
descriptor, an `AbstractResolved3DOperator` implementation with `operator_name`,
and loader functions that return package-native arrays before comparison code
runs. HDF5/XDMF details should stay in adapter files.
"""
struct ComparisonSpec{B<:AbstractTimeBackend,O<:AbstractResolved3DOperator} <: AbstractStudySpec
    cases::Vector{Resolved3DCaseSpec}
    base_params::Params
    backend::B
    operator::O
    output_dir::String
    section_count::Int
    profile_slices::Vector{Float64}
    radial_bins::Int
    radial_bin_counts::Vector{Int}
    radial_radius_modes::Vector{String}
    node_slab_half_widths::Vector{Float64}
    overwrite::Bool
    progress_every::Int
    write_svg::Bool
end

function ComparisonSpec(;
    cases = default_resolved3d_cases(),
    base_params::Params = Params(tfinal=0.9995, initial_condition=GeometryRestIC()),
    backend = NativeRK3Backend(),
    operator = CrossSectionQuadratureOperator(),
    output_dir::String = DEFAULT_COMPARISON_OUTPUT_DIR,
    section_count::Int = 200,
    profile_slices = nothing,
    radial_bins::Int = 20,
    radial_bin_counts = nothing,
    radial_radius_modes = nothing,
    node_slab_half_widths = nothing,
    overwrite::Bool = false,
    progress_every::Int = 0,
    write_svg::Bool = true,
)
    backend isa AbstractTimeBackend || throw(ArgumentError("backend must subtype AbstractTimeBackend"))
    operator isa AbstractResolved3DOperator || throw(ArgumentError("operator must subtype AbstractResolved3DOperator"))
    case_values = Resolved3DCaseSpec[case for case in cases]
    isempty(case_values) && throw(ArgumentError("comparison spec must include at least one case"))
    section_count >= 2 || throw(ArgumentError("section_count must be at least 2"))
    radial_bins >= 1 || throw(ArgumentError("radial_bins must be positive"))
    progress_every >= 0 || throw(ArgumentError("progress_every must be nonnegative"))
    validate(base_params)

    slices = if profile_slices === nothing
        default_profile_slices(base_params)
    else
        [Float64(z) for z in profile_slices]
    end
    isempty(slices) && throw(ArgumentError("profile_slices must include at least one z-location"))

    for z in slices
        0.0 <= z <= base_params.length_cm ||
            throw(ArgumentError("profile slice z=$(z) lies outside [0, $(base_params.length_cm)]"))
    end
    widths = if node_slab_half_widths === nothing
        current_half_width = max(0.5 * base_params.length_cm / (section_count - 1), DEFAULT_NODE_SLAB_HALF_WIDTH_CM)
        Float64[0.0075, current_half_width, 0.0301507538]
    else
        [Float64(width) for width in node_slab_half_widths]
    end
    all(>(0.0), widths) || throw(ArgumentError("node-slab half widths must be positive"))
    bin_counts = if radial_bin_counts === nothing
        Int[radial_bins]
    else
        sort!(unique([Int(value) for value in radial_bin_counts]))
    end
    !isempty(bin_counts) || throw(ArgumentError("radial_bin_counts must include at least one bin count"))
    all(count -> count >= 1, bin_counts) || throw(ArgumentError("all radial bin counts must be positive"))
    radius_modes = if radial_radius_modes === nothing
        String["current"]
    else
        [replace(lowercase(strip(string(mode))), "_" => "-") for mode in radial_radius_modes]
    end
    !isempty(radius_modes) || throw(ArgumentError("radial_radius_modes must include at least one mode"))
    all(mode -> mode in ("current", "reference"), radius_modes) ||
        throw(ArgumentError("radial_radius_modes must contain only current or reference"))

    return ComparisonSpec{typeof(backend),typeof(operator)}(
        case_values,
        base_params,
        backend,
        operator,
        output_dir,
        section_count,
        slices,
        radial_bins,
        bin_counts,
        radius_modes,
        widths,
        overwrite,
        progress_every,
        write_svg,
    )
end

workflow_kind(::ComparisonSpec) = "resolved3d_comparison"

function validate(spec::ComparisonSpec)
    isempty(spec.cases) && throw(ArgumentError("comparison spec must include at least one case"))
    validate(spec.base_params)
    assert_backend_supported(spec.base_params.space, spec.backend)
    spec.section_count >= 2 || throw(ArgumentError("section_count must be at least 2"))
    !isempty(spec.profile_slices) || throw(ArgumentError("profile_slices must include at least one z-location"))
    all(z -> 0.0 <= z <= spec.base_params.length_cm, spec.profile_slices) ||
        throw(ArgumentError("profile_slices must lie inside the base_params domain"))
    !isempty(spec.radial_bin_counts) || throw(ArgumentError("radial_bin_counts must include at least one bin count"))
    all(count -> count >= 1, spec.radial_bin_counts) || throw(ArgumentError("all radial bin counts must be positive"))
    !isempty(spec.radial_radius_modes) || throw(ArgumentError("radial_radius_modes must include at least one mode"))
    all(mode -> mode in ("current", "reference"), spec.radial_radius_modes) ||
        throw(ArgumentError("radial_radius_modes must contain only current or reference"))
    all(width -> width > 0.0, spec.node_slab_half_widths) ||
        throw(ArgumentError("node-slab half widths must be positive"))
    spec.progress_every >= 0 || throw(ArgumentError("progress_every must be nonnegative"))
    return spec
end

function default_output_paths(spec::ComparisonSpec)
    return (
        section_csvs=section_csv_paths(spec),
        profile_csvs=profile_csv_paths(spec),
        sensitivity_csv=sensitivity_csv_path(spec),
        summary_csv=comparison_summary_path(spec),
        overlay_svg=joinpath(spec.output_dir, "section_quadrature_overlay.svg"),
    )
end

"""
    GridSensitivitySpec(; nxs=[200, 400, 800], ...)

Run the resolved-3D comparison at multiple 1D grid resolutions with a common
target time and section-plane definition, then aggregate compact per-grid
diagnostics.
"""
struct GridSensitivitySpec{B<:AbstractTimeBackend,O<:AbstractResolved3DOperator} <: AbstractStudySpec
    cases::Vector{Resolved3DCaseSpec}
    base_params::Params
    backend::B
    operator::O
    output_dir::String
    nxs::Vector{Int}
    section_count::Int
    profile_slices::Vector{Float64}
    radial_bins::Int
    radial_bin_counts::Vector{Int}
    radial_radius_modes::Vector{String}
    node_slab_half_widths::Vector{Float64}
    overwrite::Bool
    progress_every::Int
    write_svg::Bool
    summary_csv::String
    summary_tex::String
end

function GridSensitivitySpec(;
    cases = default_resolved3d_cases(),
    base_params::Params = Params(tfinal=0.9995, initial_condition=GeometryRestIC()),
    backend = NativeRK3Backend(),
    operator = CrossSectionQuadratureOperator(),
    output_dir::String = joinpath(DEFAULT_COMPARISON_OUTPUT_DIR, "grid_sensitivity"),
    nxs = DEFAULT_GRID_SENSITIVITY_NXS,
    section_count::Int = 200,
    profile_slices = nothing,
    radial_bins::Int = 20,
    radial_bin_counts = nothing,
    radial_radius_modes = nothing,
    node_slab_half_widths = nothing,
    overwrite::Bool = false,
    progress_every::Int = 0,
    write_svg::Bool = true,
    summary_csv::String = "",
    summary_tex::String = "",
)
    backend isa AbstractTimeBackend || throw(ArgumentError("backend must subtype AbstractTimeBackend"))
    operator isa AbstractResolved3DOperator || throw(ArgumentError("operator must subtype AbstractResolved3DOperator"))
    case_values = Resolved3DCaseSpec[case for case in cases]
    isempty(case_values) && throw(ArgumentError("grid sensitivity spec must include at least one case"))
    nx_values = [Int(nx) for nx in nxs]
    isempty(nx_values) && throw(ArgumentError("grid sensitivity requires at least one nx value"))
    all(nx -> nx >= 3, nx_values) || throw(ArgumentError("all grid sensitivity sizes must be at least 3"))
    sort(nx_values) == nx_values || throw(ArgumentError("grid sensitivity sizes must be sorted ascending"))
    length(unique(nx_values)) == length(nx_values) || throw(ArgumentError("grid sensitivity sizes must be unique"))
    section_count >= 2 || throw(ArgumentError("section_count must be at least 2"))
    radial_bins >= 1 || throw(ArgumentError("radial_bins must be positive"))
    progress_every >= 0 || throw(ArgumentError("progress_every must be nonnegative"))
    validate(base_params)

    slices = if profile_slices === nothing
        default_profile_slices(base_params)
    else
        [Float64(z) for z in profile_slices]
    end
    isempty(slices) && throw(ArgumentError("profile_slices must include at least one z-location"))
    for z in slices
        0.0 <= z <= base_params.length_cm ||
            throw(ArgumentError("profile slice z=$(z) lies outside [0, $(base_params.length_cm)]"))
    end

    widths = if node_slab_half_widths === nothing
        current_half_width = max(0.5 * base_params.length_cm / (section_count - 1), DEFAULT_NODE_SLAB_HALF_WIDTH_CM)
        Float64[0.0075, current_half_width, 0.0301507538]
    else
        [Float64(width) for width in node_slab_half_widths]
    end
    all(>(0.0), widths) || throw(ArgumentError("node-slab half widths must be positive"))

    bin_counts = if radial_bin_counts === nothing
        Int[radial_bins]
    else
        sort!(unique([Int(value) for value in radial_bin_counts]))
    end
    !isempty(bin_counts) || throw(ArgumentError("radial_bin_counts must include at least one bin count"))
    all(count -> count >= 1, bin_counts) || throw(ArgumentError("all radial bin counts must be positive"))

    radius_modes = if radial_radius_modes === nothing
        String["current"]
    else
        [replace(lowercase(strip(string(mode))), "_" => "-") for mode in radial_radius_modes]
    end
    !isempty(radius_modes) || throw(ArgumentError("radial_radius_modes must include at least one mode"))
    all(mode -> mode in ("current", "reference"), radius_modes) ||
        throw(ArgumentError("radial_radius_modes must contain only current or reference"))

    csv_path = isempty(summary_csv) ? joinpath(output_dir, "grid_sensitivity_summary.csv") : summary_csv
    tex_path = isempty(summary_tex) ? joinpath(output_dir, "grid_sensitivity_summary.tex") : summary_tex

    return GridSensitivitySpec{typeof(backend),typeof(operator)}(
        case_values,
        base_params,
        backend,
        operator,
        output_dir,
        nx_values,
        section_count,
        slices,
        radial_bins,
        bin_counts,
        radius_modes,
        widths,
        overwrite,
        progress_every,
        write_svg,
        csv_path,
        tex_path,
    )
end

workflow_kind(::GridSensitivitySpec) = "resolved3d_grid_sensitivity"

function validate(spec::GridSensitivitySpec)
    isempty(spec.cases) && throw(ArgumentError("grid sensitivity spec must include at least one case"))
    validate(spec.base_params)
    assert_backend_supported(spec.base_params.space, spec.backend)
    !isempty(spec.nxs) || throw(ArgumentError("grid sensitivity requires at least one nx value"))
    all(nx -> nx >= 3, spec.nxs) || throw(ArgumentError("all grid sensitivity sizes must be at least 3"))
    sort(spec.nxs) == spec.nxs || throw(ArgumentError("grid sensitivity sizes must be sorted ascending"))
    length(unique(spec.nxs)) == length(spec.nxs) || throw(ArgumentError("grid sensitivity sizes must be unique"))
    spec.section_count >= 2 || throw(ArgumentError("section_count must be at least 2"))
    !isempty(spec.profile_slices) || throw(ArgumentError("profile_slices must include at least one z-location"))
    all(z -> 0.0 <= z <= spec.base_params.length_cm, spec.profile_slices) ||
        throw(ArgumentError("profile_slices must lie inside the base_params domain"))
    !isempty(spec.radial_bin_counts) || throw(ArgumentError("radial_bin_counts must include at least one bin count"))
    all(count -> count >= 1, spec.radial_bin_counts) || throw(ArgumentError("all radial bin counts must be positive"))
    !isempty(spec.radial_radius_modes) || throw(ArgumentError("radial_radius_modes must include at least one mode"))
    all(mode -> mode in ("current", "reference"), spec.radial_radius_modes) ||
        throw(ArgumentError("radial_radius_modes must contain only current or reference"))
    all(width -> width > 0.0, spec.node_slab_half_widths) ||
        throw(ArgumentError("node-slab half widths must be positive"))
    spec.progress_every >= 0 || throw(ArgumentError("progress_every must be nonnegative"))
    return spec
end

function default_output_paths(spec::GridSensitivitySpec)
    return (summary_csv=spec.summary_csv, summary_tex=spec.summary_tex)
end

"""One axial cross-section comparison row."""
struct SectionComparisonRow
    case_label::String
    severity::Float64
    operator::String
    model::String
    nx::Int
    dt_s::Float64
    initial_condition::String
    backend::String
    run_status::String
    z_cm::Float64
    area_cm2::Float64
    flow_3d_cm3_s::Float64
    flow_1d_cm3_s::Float64
    mean_u3d_cm_s::Float64
    mean_u1d_cm_s::Float64
    abs_velocity_error_cm_s::Float64
    flow_abs_error_cm3_s::Float64
    rel_error::Float64
    rel_l2_velocity_component::Float64
    intersection_count::Int
    area_valid::Bool
    cut_status::String
    node_count::Int
    observed_radius_cm::Float64
    xdmf_time_s::Float64
    time_error_s::Float64
    target_time_s::Float64
    time_atol_s::Float64
    one_d_completed_time_s::Float64
    one_d_terminal_time_error_s::Float64
    xdmf_target_time_error_s::Float64
    cross_model_time_offset_s::Float64
end

"""One area-weighted radial-bin profile comparison row."""
struct RadialProfileRow
    case_label::String
    severity::Float64
    operator::String
    model::String
    nx::Int
    dt_s::Float64
    initial_condition::String
    backend::String
    run_status::String
    z_slice_cm::Float64
    radial_bin::Int
    r_over_r0_mid::Float64
    area_cm2::Float64
    flow_3d_cm3_s::Float64
    mean_u3d_cm_s::Float64
    mean_u1d_cm_s::Float64
    abs_velocity_error_cm_s::Float64
    rel_error::Float64
    intersection_count::Int
    area_valid::Bool
    node_count::Int
    xdmf_time_s::Float64
    time_error_s::Float64
    target_time_s::Float64
    time_atol_s::Float64
    one_d_completed_time_s::Float64
    one_d_terminal_time_error_s::Float64
    xdmf_target_time_error_s::Float64
    cross_model_time_offset_s::Float64
    radial_bin_count::Int
    radius_mode::String
    radius_scale_cm::Float64
    current_area_cm2::Float64
    reference_area_cm2::Float64
    current_area_mismatch_rel::Float64
    velocity_variance_cm2_s2::Float64
end

"""Supplemental node-slab sensitivity row."""
struct NodeSlabSensitivityRow
    case_label::String
    severity::Float64
    model::String
    nx::Int
    dt_s::Float64
    initial_condition::String
    backend::String
    run_status::String
    half_width_cm::Float64
    z_cm::Float64
    mean_u3d_cm_s::Float64
    mean_u1d_cm_s::Float64
    abs_velocity_error_cm_s::Float64
    rel_error::Float64
    node_count::Int
    observed_radius_cm::Float64
    xdmf_time_s::Float64
    time_error_s::Float64
    target_time_s::Float64
    time_atol_s::Float64
    one_d_completed_time_s::Float64
    one_d_terminal_time_error_s::Float64
    xdmf_target_time_error_s::Float64
    cross_model_time_offset_s::Float64
end

"""Compact per-case comparison summary."""
struct ComparisonSummaryRow
    case_label::String
    severity::Float64
    operator::String
    model::String
    nx::Int
    dt_s::Float64
    initial_condition::String
    backend::String
    run_status::String
    section_count::Int
    profile_count::Int
    mean_abs_error_cm_s::Float64
    l2_velocity_error_cm_s::Float64
    max_abs_error_cm_s::Float64
    mean_rel_error::Float64
    relative_l1_velocity_error::Float64
    max_rel_error::Float64
    rel_l2_velocity_error::Float64
    mean_flow_abs_error_cm3_s::Float64
    flow_l2_error_cm3_s::Float64
    max_flow_abs_error_cm3_s::Float64
    profile_mean_abs_error_cm_s::Float64
    profile_l2_error_cm_s::Float64
    profile_max_abs_error_cm_s::Float64
    min_intersection_count::Int
    min_section_nodes::Int
    area_valid_count::Int
    alpha_eff_min::Float64
    alpha_eff_max::Float64
    characteristic_radicand_min::Float64
    lambda_minus_min::Float64
    lambda_minus_max::Float64
    lambda_plus_min::Float64
    lambda_plus_max::Float64
    subcritical_margin_min::Float64
    accepted_dt_min::Float64
    accepted_dt_max::Float64
    realized_cfl_max::Float64
    min_solver_area::Float64
    min_physical_area_cm2::Float64
    solver_volume_defect::Float64
    physical_volume_defect_cm3::Float64
    positivity_projection_count::Int
    positivity_correction_total::Float64
    final_inlet_area_flux::Float64
    final_outlet_area_flux::Float64
    final_area_flux_balance::Float64
    final_rhs_area_max_abs::Float64
    final_rhs_flow_max_abs::Float64
    xdmf_time_s::Float64
    time_error_s::Float64
    target_time_s::Float64
    time_atol_s::Float64
    one_d_completed_time_s::Float64
    one_d_terminal_time_error_s::Float64
    xdmf_target_time_error_s::Float64
    cross_model_time_offset_s::Float64
end

"""Compact per-case, per-grid resolved-3D grid-sensitivity summary."""
struct GridSensitivitySummaryRow
    case_label::String
    severity::Float64
    operator::String
    model::String
    nx::Int
    dt_s::Float64
    initial_condition::String
    backend::String
    run_status::String
    target_time_s::Float64
    section_count::Int
    valid_section_count::Int
    mean_physical_flow_bias_cm3_s::Float64
    mean_physical_flow_discrepancy_cm3_s::Float64
    rms_physical_flow_discrepancy_cm3_s::Float64
    mean_velocity_bias_cm_s::Float64
    mean_velocity_discrepancy_cm_s::Float64
    rms_velocity_discrepancy_cm_s::Float64
    max_velocity_discrepancy_cm_s::Float64
    max_velocity_discrepancy_z_cm::Float64
    relative_rms_velocity_discrepancy::Float64
    adjacent_from_nx::Int
    adjacent_mean_abs_velocity_difference_cm_s::Float64
    adjacent_rms_velocity_difference_cm_s::Float64
    adjacent_max_abs_velocity_difference_cm_s::Float64
    adjacent_relative_rms_velocity_difference::Float64
    one_d_completed_time_s::Float64
    cross_model_time_offset_s::Float64
    comparison_summary_csv::String
    section_csv::String
end

"""Return value from `run_comparison`."""
struct ComparisonResult{S<:ComparisonSpec}
    spec::S
    section_rows::Vector{SectionComparisonRow}
    profile_rows::Vector{RadialProfileRow}
    sensitivity_rows::Vector{NodeSlabSensitivityRow}
    summary_rows::Vector{ComparisonSummaryRow}
    section_csvs::Vector{String}
    profile_csvs::Vector{String}
    sensitivity_csv::String
    summary_csv::String
    svg_paths::Vector{String}
end

"""Return value from `run_grid_sensitivity`."""
struct GridSensitivityResult{S<:GridSensitivitySpec}
    spec::S
    comparison_results::Vector{ComparisonResult}
    summary_rows::Vector{GridSensitivitySummaryRow}
    summary_csv::String
    summary_tex::String
end

default_resolved3d_data_root() = DEFAULT_RESOLVED3D_DATA_ROOT

function default_resolved3d_cases(
    data_root::String = default_resolved3d_data_root();
    target_time::Real = 0.9995,
    time_atol::Real = 1.0e-3,
)
    return Resolved3DCaseSpec[
        Resolved3DCaseSpec("77", 23.0, joinpath(data_root, "77", "velocity.xdmf"); target_time, time_atol),
        Resolved3DCaseSpec("60", 40.0, joinpath(data_root, "60", "velocity.xdmf"); target_time, time_atol),
    ]
end

function available_resolved3d_cases(
    data_root::String = default_resolved3d_data_root();
    target_time::Real = 0.9995,
    time_atol::Real = 1.0e-3,
)
    cases = [
        case for case in default_resolved3d_cases(data_root; target_time, time_atol) if isfile(case.velocity_xdmf)
    ]
    if isempty(cases)
        @telemetry_info "skipping resolved 3D comparison because no case XDMF files were found" event="resolved3d_skipped" stage="resolved3d" backend="resolved3d" method="" nx="" tfinal="" status="skipped" rows=0 reason="missing_xdmf" data_root expected_layout=[
            joinpath(data_root, "77", "velocity.xdmf"),
            joinpath(data_root, "60", "velocity.xdmf"),
        ]
    end
    return cases
end

function run_available_resolved3d_comparison(;
    data_root::String = default_resolved3d_data_root(),
    target_time::Real = 0.9995,
    time_atol::Real = 1.0e-3,
    kwargs...,
)
    cases = available_resolved3d_cases(data_root; target_time, time_atol)
    isempty(cases) && return nothing
    return run_comparison(ComparisonSpec(; cases=cases, kwargs...))
end

function run_available_resolved3d_grid_sensitivity(;
    data_root::String = default_resolved3d_data_root(),
    target_time::Real = 0.9995,
    time_atol::Real = 1.0e-3,
    kwargs...,
)
    cases = available_resolved3d_cases(data_root; target_time, time_atol)
    isempty(cases) && return nothing
    return run_grid_sensitivity(GridSensitivitySpec(; cases=cases, kwargs...))
end
