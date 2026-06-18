import EzXML
import HDF5
using Statistics

const DEFAULT_RESOLVED3D_DATA_ROOT = joinpath("simulations", "data", "3d", "canic_case3")
const DEFAULT_COMPARISON_OUTPUT_DIR = joinpath("simulations", "output", "3d_comparison")
const DEFAULT_NODE_SLAB_HALF_WIDTH_CM = 0.015

"""
    Resolved3DCaseSpec(case_label, severity, velocity_xdmf; target_time=1.0, time_atol=1e-3)

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
    target_time::Real = 1.0,
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
Configuration for comparing one or more 3D reference cases against 1D runs.
"""
struct ComparisonSpec
    cases::Vector{Resolved3DCaseSpec}
    base_params::Params
    backend::AbstractTimeBackend
    operator::AbstractResolved3DOperator
    output_dir::String
    section_count::Int
    profile_slices::Vector{Float64}
    radial_bins::Int
    node_slab_half_widths::Vector{Float64}
    overwrite::Bool
    progress_every::Int
    write_svg::Bool
end

function ComparisonSpec(;
    cases = default_resolved3d_cases(),
    base_params::Params = Params(tfinal=1.0, initial_condition=GeometryRestIC()),
    backend::AbstractTimeBackend = NativeRK3Backend(),
    operator::AbstractResolved3DOperator = CrossSectionQuadratureOperator(),
    output_dir::String = DEFAULT_COMPARISON_OUTPUT_DIR,
    section_count::Int = 200,
    profile_slices = nothing,
    radial_bins::Int = 20,
    node_slab_half_widths = nothing,
    overwrite::Bool = false,
    progress_every::Int = 0,
    write_svg::Bool = true,
)
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

    return ComparisonSpec(
        case_values,
        base_params,
        backend,
        operator,
        output_dir,
        section_count,
        slices,
        radial_bins,
        widths,
        overwrite,
        progress_every,
        write_svg,
    )
end

"""One axial cross-section comparison row."""
struct SectionComparisonRow
    case_label::String
    severity::Float64
    operator::String
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
end

"""One area-weighted radial-bin profile comparison row."""
struct RadialProfileRow
    case_label::String
    severity::Float64
    operator::String
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
end

"""Supplemental node-slab sensitivity row."""
struct NodeSlabSensitivityRow
    case_label::String
    severity::Float64
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
end

"""Compact per-case comparison summary."""
struct ComparisonSummaryRow
    case_label::String
    severity::Float64
    operator::String
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
    xdmf_time_s::Float64
    time_error_s::Float64
end

"""Return value from `run_comparison`."""
struct ComparisonResult
    spec::ComparisonSpec
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

default_resolved3d_data_root() = DEFAULT_RESOLVED3D_DATA_ROOT

function default_resolved3d_cases(data_root::String = default_resolved3d_data_root())
    return Resolved3DCaseSpec[
        Resolved3DCaseSpec("77", 23.0, joinpath(data_root, "77", "velocity.xdmf")),
        Resolved3DCaseSpec("60", 40.0, joinpath(data_root, "60", "velocity.xdmf")),
    ]
end

function available_resolved3d_cases(data_root::String = default_resolved3d_data_root())
    cases = [case for case in default_resolved3d_cases(data_root) if isfile(case.velocity_xdmf)]
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
    kwargs...,
)
    cases = available_resolved3d_cases(data_root)
    isempty(cases) && return nothing
    return run_comparison(ComparisonSpec(; cases=cases, kwargs...))
end
