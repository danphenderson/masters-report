"""Clamp the inlet and outlet wall degrees of freedom to zero in place."""
function clamp_membrane_endpoints!(values::Vector{Float64})
    isempty(values) && return values
    values[begin] = 0.0
    values[end] = 0.0
    return values
end

"""
    maybe_push_membrane_history!(history, step, time_s, residual, displacement, current_radii, wall_pressure, wall_velocity)

Append one membrane-FSI history row using the current wall state extrema.
"""
function maybe_push_membrane_history!(
    history::Vector{MembraneFSIHistoryRow},
    step::Int,
    time_s::Float64,
    residual::Float64,
    displacement::Vector{Float64},
    current_radii::Vector{Float64},
    wall_pressure::Vector{Float64},
    wall_velocity::Vector{Float64},
)
    push!(
        history,
        MembraneFSIHistoryRow(
            step=step,
            time_s=time_s,
            residual_cm=residual,
            displacement_min_cm=minimum(displacement),
            displacement_max_cm=maximum(displacement),
            current_radius_min_cm=minimum(current_radii),
            current_radius_max_cm=maximum(current_radii),
            wall_pressure_min_dyn_cm2=minimum(wall_pressure),
            wall_pressure_max_dyn_cm2=maximum(wall_pressure),
            wall_velocity_min_cm_s=minimum(wall_velocity),
            wall_velocity_max_cm_s=maximum(wall_velocity),
        ),
    )
    return history
end

"""Return whether the current step should be retained in coupling history."""
function should_capture_membrane_history(step::Int, stride::Int, force::Bool)
    return force || step == 1 || step % stride == 0
end

function maybe_push_membrane_history!(
    history::Vector{MembraneFSIHistoryRow},
    step::Int,
    time_s::Float64,
    residual::Float64,
    displacement::Vector{Float64},
    current_radii::Vector{Float64},
    wall_pressure::Vector{Float64},
    wall_velocity::Vector{Float64},
    stride::Int,
    force::Bool,
)
    should_capture_membrane_history(step, stride, force) || return history
    return maybe_push_membrane_history!(
        history,
        step,
        time_s,
        residual,
        displacement,
        current_radii,
        wall_pressure,
        wall_velocity,
    )
end
