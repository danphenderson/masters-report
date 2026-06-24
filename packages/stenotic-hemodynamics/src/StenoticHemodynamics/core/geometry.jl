momentum_alpha(p::Params) = momentum_alpha(p.velocity_profile)
profile_shear_rate_factor(p::Params) = shear_rate_factor(p.velocity_profile)
gamma_plus_two(p::Params) = profile_shear_rate_factor(p)
wall_law_name(p::Params) = wall_law_name(p.wall_law)
wall_stiffness(p::Params) = p.young * p.wall_h / (1.0 - p.sigma^2)
wall_reference_radius(::CanicKoiterWallLaw, p::Params) = p.rmax
wall_reference_radius(p::Params) = wall_reference_radius(p.wall_law, p)
function wall_elastic_coefficient(::CanicKoiterWallLaw, p::Params, radius::Real)
    T = _float_input_type(radius)
    radius_t = T(radius)
    return T(wall_stiffness(p)) / radius_t^2
end
wall_elastic_coefficient(p::Params, radius::Real) = wall_elastic_coefficient(p.wall_law, p, radius)
wall_invariant_speed_factor(::CanicKoiterWallLaw, p::Params) =
    sqrt(wall_stiffness(p) / (2.0 * p.rho * wall_reference_radius(p)^2))
wall_invariant_speed_factor(p::Params) = wall_invariant_speed_factor(p.wall_law, p)
inlet_uavg(p::Params) = mean_to_max_velocity_ratio(p.velocity_profile) * p.inlet_umax
stenosis_amplitude(p::Params) = p.rmax * p.severity / 100.0

function asymmetric_geometry_terms(z::Real)
    T = _float_input_type(z)
    z_t = T(z)
    one_t = one(T)
    e = exp(-(one_t / T(2)) * (z_t - T(2.5))^2)
    g = z_t - T(3.4) + T(0.95) * e
    gp = one_t - T(0.95) * (z_t - T(2.5)) * e
    gpp = -T(0.95) * (one_t - (z_t - T(2.5))^2) * e
    kernel = exp(-T(50) * g^4)
    return g, gp, gpp, kernel
end

"""
    stenosis(z, p) -> (R0, dR0_dz, d2R0_dz2)

C^infinity asymmetric stenosis profile used for the 23%, 40%, and 50% cases
in the paper and as the baseline idealized-vessel geometry in the report.
"""
function stenosis(z::Real, p::Params)
    T = _float_input_type(z)
    a = T(stenosis_amplitude(p))
    g, gp, gpp, kernel = asymmetric_geometry_terms(T(z))
    r0 = T(p.rmax) - a * kernel
    r0z = T(200) * a * kernel * g^3 * gp
    r0zz = T(200) * a * kernel * (T(3) * g^2 * gp^2 + g^3 * gpp - T(200) * g^6 * gp^2)
    return r0, r0z, r0zz
end

function alpha_c(r0z::Real)
    T = _float_input_type(r0z)
    r0z_t = T(r0z)
    return -(T(2) / T(35)) * r0z_t^2
end

function alpha_c_z(r0z::Real, r0zz::Real)
    T = _promote_float_type(r0z, r0zz)
    return -(T(4) / T(35)) * T(r0z) * T(r0zz)
end
