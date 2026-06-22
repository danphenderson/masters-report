"""Marker type for the current membrane-FSI adapter wall-mode variants."""
abstract type AbstractMembraneWallMode end

"""
    QuasiStaticMembraneMode()

Wall-update mode that alternates stationary Stokes solves with a clamped
membrane displacement update until the radius profile stops changing within the
requested coupling tolerance.
"""
struct QuasiStaticMembraneMode <: AbstractMembraneWallMode end

"""
    DynamicMembraneMode(; wall_density=1.0, dt=1e-5, tfinal=1e-4)

Explicit membrane-update mode for the current adapter. This evolves a wall
displacement/velocity surrogate against a stationary-Stokes wall-load profile;
it is not a fully coupled transient 3D FSI solve.
"""
struct DynamicMembraneMode <: AbstractMembraneWallMode
    wall_density::Float64
    dt::Float64
    tfinal::Float64
end

DynamicMembraneMode(; wall_density::Real = 1.0, dt::Real = 1.0e-5, tfinal::Real = 1.0e-4) =
    DynamicMembraneMode(Float64(wall_density), Float64(dt), Float64(tfinal))

wall_mode_name(::QuasiStaticMembraneMode) = "quasi-static-membrane"
wall_mode_name(::DynamicMembraneMode) = "dynamic-membrane"

"""
    MembraneFSICouplingOptions(p; kwargs...)

Shared coupling controls for the membrane-FSI adapter. These options cover
fixed-point iteration limits, under-relaxation, the reference radius used by
the wall model, and history decimation.
"""
struct MembraneFSICouplingOptions{F}
    max_iterations::Int
    tolerance_cm::Float64
    damping::Float64
    reference_radius::Float64
    reference_radius_at_z::F
    history_stride::Int
end

function MembraneFSICouplingOptions(
    p::Params;
    max_iterations::Int = 12,
    tolerance_cm::Real = 1.0e-7,
    damping::Real = 0.5,
    reference_radius::Real = wall_reference_radius(p),
    reference_radius_at_z = z -> stenosis(Float64(z), p)[1],
    history_stride::Int = 1,
)
    max_iterations >= 1 || throw(ArgumentError("max_iterations must be positive"))
    tolerance = Float64(tolerance_cm)
    tolerance > 0.0 || throw(ArgumentError("tolerance_cm must be positive"))
    damping_value = Float64(damping)
    0.0 < damping_value <= 1.0 || throw(ArgumentError("damping must lie in (0, 1]"))
    radius = Float64(reference_radius)
    radius > 0.0 || throw(ArgumentError("reference_radius must be positive"))
    history_stride >= 1 || throw(ArgumentError("history_stride must be positive"))
    return MembraneFSICouplingOptions(
        max_iterations,
        tolerance,
        damping_value,
        radius,
        reference_radius_at_z,
        history_stride,
    )
end

"""
    MembraneFSIHistoryRow

One recorded coupling-history row for the membrane-FSI adapter. Depending on
wall mode, `step` counts either fixed-point iterations or explicit wall steps.
"""
Base.@kwdef struct MembraneFSIHistoryRow
    step::Int
    time_s::Float64
    residual_cm::Float64
    displacement_min_cm::Float64
    displacement_max_cm::Float64
    current_radius_min_cm::Float64
    current_radius_max_cm::Float64
    wall_pressure_min_dyn_cm2::Float64
    wall_pressure_max_dyn_cm2::Float64
    wall_velocity_min_cm_s::Float64
    wall_velocity_max_cm_s::Float64
end

"""
    MembraneFSISolution

Bundle returned by the membrane-FSI adapter, including the deformed wall
profile, the latest stationary-Stokes solve, the current wall-load surrogate,
and any recorded coupling history.
"""
struct MembraneFSISolution
    mesh::GeneratedStokesMesh
    stokes_solution::StationaryStokesSolution
    z::Vector{Float64}
    reference_radius::Vector{Float64}
    displacement::Vector{Float64}
    current_radius::Vector{Float64}
    wall_velocity::Vector{Float64}
    wall_force::Vector{Float64}
    wall_pressure::Vector{Float64}
    iterations::Int
    time_s::Float64
    time_step_count::Int
    residual::Float64
    converged::Bool
    elapsed_s::Float64
    history::Vector{MembraneFSIHistoryRow}
end

"""
    canic_membrane_c0(p; reference_radius=wall_reference_radius(p))

Return the linearized membrane stiffness scale used by the current adapter's
clamped radial wall model.
"""
function canic_membrane_c0(p::Params; reference_radius::Real = wall_reference_radius(p))::Float64
    radius = Float64(reference_radius)
    radius > 0.0 || throw(ArgumentError("membrane reference radius must be positive"))
    return wall_stiffness(p) / radius^2
end

"""
    clamped_membrane_displacement(wall_force, p; reference_radius=wall_reference_radius(p))

Map the current wall-load surrogate to a clamped membrane displacement profile.
The current adapter enforces zero displacement at the inlet and outlet nodes.
"""
function clamped_membrane_displacement(
    wall_force::AbstractVector{<:Real},
    p::Params;
    reference_radius::Real = wall_reference_radius(p),
)
    c0 = canic_membrane_c0(p; reference_radius=reference_radius)
    displacement = [Float64(force) / c0 for force in wall_force]
    !isempty(displacement) || return displacement
    displacement[begin] = 0.0
    displacement[end] = 0.0
    return displacement
end
