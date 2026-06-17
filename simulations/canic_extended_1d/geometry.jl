gamma_plus_two(p::Params) = p.alpha / (p.alpha - 1.0)
wall_stiffness(p::Params) = p.young * p.wall_h / (1.0 - p.sigma^2)
inlet_uavg(p::Params) = 0.5 * p.inlet_umax
stenosis_amplitude(p::Params) = p.rmax * p.severity / 100.0

function asymmetric_geometry_terms(z::Float64)
    e = exp(-0.5 * (z - 2.5)^2)
    g = z - 3.4 + 0.95 * e
    gp = 1.0 - 0.95 * (z - 2.5) * e
    gpp = -0.95 * (1.0 - (z - 2.5)^2) * e
    kernel = exp(-50.0 * g^4)
    return g, gp, gpp, kernel
end

"""
    stenosis(z, p) -> (R0, dR0_dz, d2R0_dz2)

Asymmetric stenosis profile used for the 23%, 40%, and 50% cases in the paper.
"""
function stenosis(z::Float64, p::Params)
    a = stenosis_amplitude(p)
    g, gp, gpp, kernel = asymmetric_geometry_terms(z)
    r0 = p.rmax - a * kernel
    r0z = 200.0 * a * kernel * g^3 * gp
    r0zz = 200.0 * a * kernel * (3.0 * g^2 * gp^2 + g^3 * gpp - 200.0 * g^6 * gp^2)
    return r0, r0z, r0zz
end

alpha_c(r0z::Float64) = -2.0 / 35.0 * r0z^2
alpha_c_z(r0z::Float64, r0zz::Float64) = -4.0 / 35.0 * r0z * r0zz
