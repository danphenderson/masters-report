const DEFAULT_RESOLVED3D_DATA_ROOT = joinpath("public", "var", "data", "simulations", "canic_case3")
const DEFAULT_COMPARISON_OUTPUT_DIR = joinpath(DEFAULT_SIMULATION_OUTPUT_ROOT, "3d_comparison")
const DEFAULT_NODE_SLAB_HALF_WIDTH_CM = 0.015
const DEFAULT_GRID_SENSITIVITY_NXS = [200, 400, 800]

"""
    Resolved3DCaseSpec(case_label, severity, velocity_xdmf; target_time=0.9995, time_atol=1e-3)

Describe one imported resolved-3D velocity case. `velocity_xdmf` points to the
XDMF metadata file; referenced HDF5 datasets are resolved relative to that file.
Companion pressure/displacement XDMF paths are optional and default to sibling
files next to the velocity metadata.
"""
struct Resolved3DCaseSpec
    case_label::String
    severity::Float64
    velocity_xdmf::String
    pressure_xdmf::String
    displacement_xdmf::String
    target_time::Float64
    time_atol::Float64
end

function resolved3d_exact_canic_geometry_severity(case_label, fallback_severity::Real)
    case_spec = native_resolved_fsi_imported_case_spec(string(case_label))
    case_spec === nothing && return Float64(fallback_severity)
    return native_resolved_fsi_reduced_geometry_severity(case_spec)
end

function Resolved3DCaseSpec(
    case_label,
    severity,
    velocity_xdmf;
    pressure_xdmf::AbstractString = default_companion_xdmf_path(velocity_xdmf, "pressure.xdmf"),
    displacement_xdmf::AbstractString = default_companion_xdmf_path(velocity_xdmf, "displace.xdmf"),
    target_time::Real = 0.9995,
    time_atol::Real = 1.0e-3,
)
    severity_value = resolved3d_exact_canic_geometry_severity(case_label, severity)
    target_time_value = Float64(target_time)
    time_atol_value = Float64(time_atol)
    target_time_value >= 0.0 || throw(ArgumentError("target_time must be nonnegative"))
    time_atol_value >= 0.0 || throw(ArgumentError("time_atol must be nonnegative"))
    validate(Params(severity=severity_value, tfinal=target_time_value, initial_condition=GeometryRestIC()))
    return Resolved3DCaseSpec(
        string(case_label),
        severity_value,
        String(velocity_xdmf),
        String(pressure_xdmf),
        String(displacement_xdmf),
        target_time_value,
        time_atol_value,
    )
end

function default_companion_xdmf_path(velocity_xdmf, filename::AbstractString)
    path = String(velocity_xdmf)
    isempty(path) && return ""
    return joinpath(dirname(path), String(filename))
end

"""
Metadata parsed from a velocity XDMF file. This is the package-native contract
after XML parsing and before any HDF5 array loads.
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
Metadata parsed from one node-centered XDMF scalar or vector attribute file.
"""
struct XDMFFieldMetadata
    time::Float64
    geometry_file::String
    geometry_path::String
    geometry_dims::Tuple{Int,Int}
    topology_file::String
    topology_path::String
    topology_dims::Tuple{Int,Int}
    field_file::String
    field_path::String
    field_dims::Tuple{Int,Int}
    attribute_type::String
end

"""
Node-centered coordinates and velocities loaded from one imported resolved-3D
case.
"""
struct Resolved3DVelocityField
    case_spec::Resolved3DCaseSpec
    metadata::XDMFVelocityMetadata
    topology::Matrix{Int}
    coordinates::Matrix{Float64}
    velocity::Matrix{Float64}
end

"""
Imported resolved-FSI field bundle. Pressure and displacement remain optional so
velocity-only comparison cases still load through the same contract.
"""
struct Resolved3DFieldBundle
    case_spec::Resolved3DCaseSpec
    velocity::Resolved3DVelocityField
    pressure_metadata::Union{Nothing,XDMFFieldMetadata}
    displacement_metadata::Union{Nothing,XDMFFieldMetadata}
    pressure::Union{Nothing,Vector{Float64}}
    displacement::Union{Nothing,Matrix{Float64}}
    deformed_coordinates::Union{Nothing,Matrix{Float64}}
end

abstract type AbstractResolved3DOperator end

"""Area quadrature over tetrahedron-plane intersections."""
struct CrossSectionQuadratureOperator <: AbstractResolved3DOperator end

"""Arithmetic mean of node-centered values in a finite axial slab."""
struct NodeSlabOperator <: AbstractResolved3DOperator
    half_width_cm::Float64
end

NodeSlabOperator(; half_width_cm::Real = DEFAULT_NODE_SLAB_HALF_WIDTH_CM) =
    NodeSlabOperator(Float64(half_width_cm))

operator_name(::CrossSectionQuadratureOperator) = "CrossSectionQuadratureOperator"
operator_name(::NodeSlabOperator) = "node-slab-arithmetic-mean"
