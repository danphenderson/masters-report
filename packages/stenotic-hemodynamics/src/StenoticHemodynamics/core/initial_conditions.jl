abstract type AbstractInitialConditionSpec end

"""Legacy deterministic rest state: baseline vessel area and zero flow."""
struct GeometryRestIC <: AbstractInitialConditionSpec end

"""Exact manufactured state used only by method-of-manufactured-solutions checks."""
struct ManufacturedSolutionIC <: AbstractInitialConditionSpec end

"""
    StationaryStokesIC(; pressure_drop_dyn_cm2, pressure_drop_pa, mesh_nz, mesh_nr, mesh_ntheta)

Pressure-drop-driven stationary Stokes initializer. Internally pressure is stored
in dyn/cm^2; `pressure_drop_pa` is accepted as a convenience conversion.
"""
struct StationaryStokesIC{T<:AbstractFloat} <: AbstractInitialConditionSpec
    pressure_drop_dyn_cm2::T
    mesh_nz::Int
    mesh_nr::Int
    mesh_ntheta::Int
    projection_nr::Int
    projection_ntheta::Int
    diagnostics_path::String
end

function StationaryStokesIC{T}(;
    pressure_drop_dyn_cm2::Union{Nothing,Real} = nothing,
    pressure_drop_pa::Union{Nothing,Real} = nothing,
    mesh_nz::Integer = 64,
    mesh_nr::Integer = 6,
    mesh_ntheta::Integer = 32,
    projection_nr::Integer = mesh_nr,
    projection_ntheta::Integer = mesh_ntheta,
    diagnostics_path::AbstractString = "",
) where {T<:AbstractFloat}
    if pressure_drop_dyn_cm2 !== nothing && pressure_drop_pa !== nothing
        throw(ArgumentError("provide exactly one of pressure_drop_dyn_cm2 or pressure_drop_pa"))
    end
    pressure_drop = pressure_drop_pa === nothing ? pressure_drop_dyn_cm2 : T(10) * T(pressure_drop_pa)
    pressure_value = pressure_drop === nothing ? T(NaN) : T(pressure_drop)
    return StationaryStokesIC{T}(
        pressure_value,
        Int(mesh_nz),
        Int(mesh_nr),
        Int(mesh_ntheta),
        Int(projection_nr),
        Int(projection_ntheta),
        String(diagnostics_path),
    )
end

function StationaryStokesIC(;
    pressure_drop_dyn_cm2::Union{Nothing,Real} = nothing,
    pressure_drop_pa::Union{Nothing,Real} = nothing,
    mesh_nz::Integer = 64,
    mesh_nr::Integer = 6,
    mesh_ntheta::Integer = 32,
    projection_nr::Integer = mesh_nr,
    projection_ntheta::Integer = mesh_ntheta,
    diagnostics_path::AbstractString = "",
)
    if pressure_drop_dyn_cm2 !== nothing && pressure_drop_pa !== nothing
        throw(ArgumentError("provide exactly one of pressure_drop_dyn_cm2 or pressure_drop_pa"))
    end
    provided_pressure = pressure_drop_pa === nothing ? pressure_drop_dyn_cm2 : pressure_drop_pa
    T = provided_pressure === nothing ? Float64 : _promote_float_type(provided_pressure)
    return StationaryStokesIC{T}(
        pressure_drop_dyn_cm2=pressure_drop_dyn_cm2,
        pressure_drop_pa=pressure_drop_pa,
        mesh_nz=mesh_nz,
        mesh_nr=mesh_nr,
        mesh_ntheta=mesh_ntheta,
        projection_nr=projection_nr,
        projection_ntheta=projection_ntheta,
        diagnostics_path=diagnostics_path,
    )
end

initial_condition_name(::GeometryRestIC) = "geometry-rest"
initial_condition_name(::ManufacturedSolutionIC) = "manufactured-solution"
initial_condition_name(::StationaryStokesIC) = "stationary-stokes"

function validate(ic::GeometryRestIC)
    return ic
end

function validate(ic::ManufacturedSolutionIC)
    return ic
end

function validate(ic::StationaryStokesIC)
    isfinite(ic.pressure_drop_dyn_cm2) ||
        throw(ArgumentError("stationary-stokes IC requires --ic-pressure-drop-pa or --ic-pressure-drop-dyn-cm2"))
    ic.pressure_drop_dyn_cm2 > zero(ic.pressure_drop_dyn_cm2) ||
        throw(ArgumentError("stationary-stokes pressure drop must be positive"))
    ic.mesh_nz >= 1 || throw(ArgumentError("ic mesh_nz must be positive"))
    ic.mesh_nr >= 1 || throw(ArgumentError("ic mesh_nr must be positive"))
    ic.mesh_ntheta >= 3 || throw(ArgumentError("ic mesh_ntheta must be at least 3"))
    ic.projection_nr >= 1 || throw(ArgumentError("ic projection_nr must be positive"))
    ic.projection_ntheta >= 3 || throw(ArgumentError("ic projection_ntheta must be at least 3"))
    return ic
end

struct InitialConditionSummary
    kind::String
    pressure_drop_dyn_cm2::Float64
    mesh_nz::Int
    mesh_nr::Int
    mesh_ntheta::Int
    mesh_nodes::Int
    mesh_cells::Int
    velocity_dofs::Int
    pressure_dofs::Int
    residual_norm::Float64
    projection_hash::String
    diagnostics_path::String
    projected_velocity_min::Float64
    projected_velocity_max::Float64
    projected_pressure_min::Float64
    projected_pressure_max::Float64
end

function InitialConditionSummary(kind::String)
    return InitialConditionSummary(kind, NaN, 0, 0, 0, 0, 0, 0, 0, NaN, "", "", NaN, NaN, NaN, NaN)
end

struct InitialStateResult
    z::Vector{Float64}
    area::Vector{Float64}
    flow::Vector{Float64}
    dx::Float64
    summary::InitialConditionSummary
end
