# Keep Gridap imports and point-evaluation helpers local to the stationary
# Stokes refinement workflow split.
using Gridap: Point

"""
    stationary_stokes_wall_traction_summary(solution, params)

Sample traction and wall-shear magnitudes slightly inside the wall and return
summary statistics. Exact boundary evaluation is intentionally avoided because
coarse meshes can fail active-cell lookup on the geometric boundary.
"""
function stationary_stokes_wall_traction_summary(solution::StationaryStokesSolution, params::Params)
    traction_values = Float64[]
    wss_values = Float64[]
    for j in 0:solution.mesh.nz
        z = params.length_cm * j / solution.mesh.nz
        for a in 1:solution.mesh.ntheta
            theta = 2.0 * pi * (a - 1) / solution.mesh.ntheta
            traction_magnitude, wss_magnitude = try
                stationary_stokes_wall_traction_sample(solution, params, z, theta)
            catch
                continue
            end
            push!(traction_values, traction_magnitude)
            push!(wss_values, wss_magnitude)
        end
    end
    isempty(traction_values) && throw(ArgumentError("could not evaluate any stationary Stokes wall-traction samples"))
    return (
        samples=length(traction_values),
        traction_mean=finite_mean(traction_values),
        traction_max=finite_max(traction_values),
        wss_mean=finite_mean(wss_values),
        wss_max=finite_max(wss_values),
    )
end

function stationary_stokes_wall_traction_sample(
    solution::StationaryStokesSolution,
    params::Params,
    z::Float64,
    theta::Float64,
)
    r0, r0z, _ = stenosis(z, params)
    sample_radius = r0 * (1.0 - 1.0e-8)
    x = sample_radius * cos(theta)
    y = sample_radius * sin(theta)
    point = Point(x, y, z)
    grad_u = (∇(solution.velocity))(point)
    pressure_value = Float64(solution.pressure(point))
    nx, ny, nz = stationary_stokes_wall_normal(theta, r0z)
    sx, sy, sz = symmetric_gradient_times_normal(grad_u, nx, ny, nz)
    mu = params.rho * params.nu
    tx = -pressure_value * nx + mu * sx
    ty = -pressure_value * ny + mu * sy
    tz = -pressure_value * nz + mu * sz
    normal_component = tx * nx + ty * ny + tz * nz
    taux = tx - normal_component * nx
    tauy = ty - normal_component * ny
    tauz = tz - normal_component * nz
    return vector_norm3(tx, ty, tz), vector_norm3(taux, tauy, tauz)
end

function stationary_stokes_wall_normal(theta::Float64, r0z::Float64)
    scale = inv(sqrt(1.0 + r0z^2))
    return cos(theta) * scale, sin(theta) * scale, -r0z * scale
end

function symmetric_gradient_times_normal(grad_u, nx::Float64, ny::Float64, nz::Float64)
    sx = 2.0 * grad_u[1, 1] * nx + (grad_u[1, 2] + grad_u[2, 1]) * ny + (grad_u[1, 3] + grad_u[3, 1]) * nz
    sy = (grad_u[2, 1] + grad_u[1, 2]) * nx + 2.0 * grad_u[2, 2] * ny + (grad_u[2, 3] + grad_u[3, 2]) * nz
    sz = (grad_u[3, 1] + grad_u[1, 3]) * nx + (grad_u[3, 2] + grad_u[2, 3]) * ny + 2.0 * grad_u[3, 3] * nz
    return sx, sy, sz
end

vector_norm3(x::Real, y::Real, z::Real) = sqrt(Float64(x)^2 + Float64(y)^2 + Float64(z)^2)

"""
    safe_section_average_velocity(velocity_h, z, params, ic)

Estimate the FE axial-velocity section average with guarded point evaluation.
Sample points that fall outside any active cell are skipped so coarse meshes can
still produce diagnostic rows instead of aborting the whole study.
"""
function safe_section_average_velocity(velocity_h, z::Float64, p::Params, ic::StationaryStokesIC)
    r0, _, _ = stenosis(clamp(z, 0.0, p.length_cm), p)
    acc = 0.0
    count = 0
    polygon_scale = cos(pi / ic.mesh_ntheta) * (1.0 - 1.0e-8)
    for ir in 1:ic.projection_nr
        radius = r0 * polygon_scale * sqrt((ir - 0.5) / ic.projection_nr)
        for itheta in 1:ic.projection_ntheta
            theta = 2.0 * pi * (itheta - 0.5) / ic.projection_ntheta
            value = try
                velocity_h(Point(radius * cos(theta), radius * sin(theta), z))[3]
            catch
                continue
            end
            acc += value
            count += 1
        end
    end
    count > 0 || throw(ArgumentError("could not evaluate any FE velocity section samples at z=$z"))
    return acc / count
end

"""
    safe_section_average_pressure(pressure_h, z, params, ic)

Pressure counterpart to [`safe_section_average_velocity`](@ref), with the same
guarded sampling strategy for coarse or marginal meshes.
"""
function safe_section_average_pressure(pressure_h, z::Float64, p::Params, ic::StationaryStokesIC)
    r0, _, _ = stenosis(clamp(z, 0.0, p.length_cm), p)
    acc = 0.0
    count = 0
    polygon_scale = cos(pi / ic.mesh_ntheta) * (1.0 - 1.0e-8)
    for ir in 1:ic.projection_nr
        radius = r0 * polygon_scale * sqrt((ir - 0.5) / ic.projection_nr)
        for itheta in 1:ic.projection_ntheta
            theta = 2.0 * pi * (itheta - 0.5) / ic.projection_ntheta
            value = try
                pressure_h(Point(radius * cos(theta), radius * sin(theta), z))
            catch
                continue
            end
            acc += value
            count += 1
        end
    end
    count > 0 || throw(ArgumentError("could not evaluate any FE pressure section samples at z=$z"))
    return acc / count
end
