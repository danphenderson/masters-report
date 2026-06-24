const default_output_stub = StenoticHemodynamics.default_output_stub
const dg_quadrature = StenoticHemodynamics.dg_quadrature
const legendre_derivative = StenoticHemodynamics.legendre_derivative
const legendre_value = StenoticHemodynamics.legendre_value
const observed_order = StenoticHemodynamics.observed_order

@testset "StenoticHemodynamics rheology closures" begin
    @test rheology_name(NewtonianRheology()) == "newtonian"
    @test effective_kinematic_viscosity(NewtonianRheology(), 25.0, 1.055, 0.04) ≈ 0.04

    carreau = CarreauRheology(eta0=0.10, eta_inf=0.02, lambda_s=2.0, n=0.5)
    expected_carreau = 0.02 + (0.10 - 0.02) * (1.0 + (2.0 * 3.0)^2)^((0.5 - 1.0) / 2.0)
    @test effective_dynamic_viscosity(carreau, 3.0, 1.055, 0.04) ≈ expected_carreau

    carreau_yasuda = CarreauYasudaRheology(eta0=0.10, eta_inf=0.02, lambda_s=2.0, a=1.5, n=0.5)
    expected_carreau_yasuda = 0.02 + (0.10 - 0.02) * (1.0 + (2.0 * 3.0)^1.5)^((0.5 - 1.0) / 1.5)
    @test effective_dynamic_viscosity(carreau_yasuda, 3.0, 1.055, 0.04) ≈ expected_carreau_yasuda

    casson = CassonRheology(yield_stress=0.09, plastic_viscosity=0.04)
    expected_casson = (sqrt(0.09 / 9.0) + sqrt(0.04))^2
    @test effective_dynamic_viscosity(casson, 9.0, 1.055, 0.04) ≈ expected_casson

    power_law = PowerLawRheology(consistency=0.12, n=0.75)
    @test effective_dynamic_viscosity(power_law, 16.0, 1.055, 0.04) ≈ 0.12 * 16.0^-0.25

    clamped = PowerLawRheology(consistency=10.0, n=0.5, max_eta=0.2)
    @test effective_dynamic_viscosity(clamped, 1.0e-4, 1.055, 0.04) ≈ 0.2

    legacy_alpha = Params(alpha=1.1, initial_condition=GeometryRestIC())
    @test legacy_alpha.velocity_profile isa PowerVelocityProfile
    @test legacy_alpha.alpha ≈ 1.1
    @test characteristic_shear_rate(0.04, 0.2, 0.2, legacy_alpha) > 0.0
    @test_throws ArgumentError StenoticHemodynamics.validate(CarreauRheology(eta0=0.01, eta_inf=0.02))
end
@testset "StenoticHemodynamics velocity profiles" begin
    parabolic = ParabolicVelocityProfile()
    @test profile_name(parabolic) == "parabolic"
    @test momentum_alpha(parabolic) ≈ 4.0 / 3.0
    @test shear_rate_factor(parabolic) ≈ 4.0
    @test mean_to_max_velocity_ratio(parabolic) ≈ 0.5
    @test reconstructed_axial_velocity(3.0, 0.0, 2.0, parabolic) ≈ 6.0
    @test reconstructed_axial_velocity(3.0, 2.0, 2.0, parabolic) ≈ 0.0
    @test radial_profile_velocity(3.0, 0.0, 2.0, parabolic) ≈ 6.0

    flat = FlatVelocityProfile(shear_rate_factor=5.0)
    @test profile_name(flat) == "flat"
    @test momentum_alpha(flat) ≈ 1.0
    @test shear_rate_factor(flat) ≈ 5.0
    @test mean_to_max_velocity_ratio(flat) ≈ 1.0
    @test reconstructed_axial_velocity(3.0, 1.5, 2.0, flat) ≈ 3.0

    power = PowerVelocityProfile(exponent=2.0)
    @test momentum_alpha(power) ≈ 4.0 / 3.0
    @test shear_rate_factor(power) ≈ 4.0
    @test mean_to_max_velocity_ratio(power) ≈ 0.5

    legacy_power = PowerVelocityProfile(alpha=1.1)
    @test legacy_power.exponent ≈ 9.0
    @test momentum_alpha(legacy_power) ≈ 1.1
    @test shear_rate_factor(legacy_power) ≈ 11.0

    default_params = Params(initial_condition=GeometryRestIC())
    @test default_params.velocity_profile isa ParabolicVelocityProfile
    @test default_params.alpha ≈ 4.0 / 3.0
    @test StenoticHemodynamics.inlet_uavg(default_params) ≈ 22.5
    @test StenoticHemodynamics.inlet_uavg(Params(initial_condition=GeometryRestIC(), velocity_profile=flat)) ≈ 45.0
    @test default_params.model isa CanicExtendedOneDModel
    @test model_name(default_params) == "canic-extended-1d"
    @test variable_radius_terms_enabled(default_params) == true
    @test default_output_stub(Params()) == "tmp/simulations/output/stenotic_hemodynamics_canic_extended_1d_severity50_vp_parabolic"
    @test occursin("vp_parabolic", default_output_stub(default_params))
    @test default_output_stub(default_params) != default_output_stub(Params(alpha=1.1, initial_condition=GeometryRestIC()))
    classical = Params(initial_condition=GeometryRestIC(), model="classical-1d-no-slip")
    @test classical.model isa ClassicalParabolicOneDModel
    @test classical.model isa ClassicalNoSlip1DModel
    @test model_name(classical) == "classical-parabolic-1d"
    @test variable_radius_terms_enabled(classical) == false
    @test_throws ArgumentError Params(initial_condition=GeometryRestIC(), model="classical-1d-no-slip", velocity_profile=flat)
    @test_throws ArgumentError Params(initial_condition=GeometryRestIC(), model="classical-1d-no-slip", alpha=1.1)
    @test default_output_stub(Params(initial_condition=GeometryRestIC(), velocity_profile=PowerVelocityProfile(exponent=4.0))) !=
          default_output_stub(Params(initial_condition=GeometryRestIC(), velocity_profile=PowerVelocityProfile(exponent=9.0)))
    @test default_output_stub(Params(initial_condition=GeometryRestIC(), velocity_profile=FlatVelocityProfile(shear_rate_factor=4.0))) !=
          default_output_stub(Params(initial_condition=GeometryRestIC(), velocity_profile=FlatVelocityProfile(shear_rate_factor=8.0)))
    @test_throws ArgumentError Params(alpha=1.1, velocity_profile=ParabolicVelocityProfile())
    @test_throws ArgumentError StenoticHemodynamics.params_with(default_params; velocity_profile=flat, alpha=1.1)
    @test_throws ArgumentError StenoticHemodynamics.validate(FlatVelocityProfile(shear_rate_factor=0.0))
    @test_throws ArgumentError PowerVelocityProfile(alpha=1.0)
end

@testset "StenoticHemodynamics Canic-Koiter wall law" begin
    params = Params(initial_condition=GeometryRestIC(), severity=30.0)
    z = 2.75
    A = 0.035
    Q = 0.012
    r0, r0z, _ = StenoticHemodynamics.stenosis(z, params)
    K = StenoticHemodynamics.wall_stiffness(params)
    gamma_plus_two = StenoticHemodynamics.gamma_plus_two(params)
    nu_eff = StenoticHemodynamics.effective_kinematic_viscosity(A, Q, r0, params)

    @test params.wall_law isa CanicKoiterWallLaw
    @test wall_law_name(params) == "canic-koiter-thin-membrane"
    @test StenoticHemodynamics.wall_reference_radius(params) ≈ params.rmax
    @test StenoticHemodynamics.wall_elastic_pressure(A, z, params) ≈ K / r0^2 * (sqrt(A) - r0)
    @test StenoticHemodynamics.variable_radius_pressure_correction(A, Q, r0, r0z, nu_eff, gamma_plus_two, params) ≈
          gamma_plus_two * params.rho * nu_eff * Q / A * r0z / r0
    @test StenoticHemodynamics.diagnostic_pressure([A], [Q], [z], params)[1] ≈
          StenoticHemodynamics.wall_elastic_pressure(A, z, params) +
          StenoticHemodynamics.variable_radius_pressure_correction(A, Q, r0, r0z, nu_eff, gamma_plus_two, params)
    @test StenoticHemodynamics.evolution_pressure([A], [Q], [z], params)[1] ≈
          StenoticHemodynamics.wall_elastic_pressure(A, z, params)
    @test StenoticHemodynamics.pressure([A], [Q], [z], params) ≈
          StenoticHemodynamics.diagnostic_pressure([A], [Q], [z], params)
    classical_params = Params(initial_condition=GeometryRestIC(), severity=30.0, model="classical-1d-no-slip")
    @test StenoticHemodynamics.diagnostic_pressure([A], [Q], [z], classical_params)[1] ≈
          StenoticHemodynamics.wall_elastic_pressure(A, z, classical_params)
    @test StenoticHemodynamics.wall_elastic_potential(A, z, params) ≈ K / (3.0 * params.rho * params.rmax^2) * A^1.5
    @test StenoticHemodynamics.wall_wave_speed_squared(A, z, params) ≈ K / (2.0 * params.rho * params.rmax^2) * sqrt(A)
    @test StenoticHemodynamics.wall_geometry_source(A, z, r0, r0z, params) ≈ K / (params.rho * params.rmax^2) * A * r0z
    @test StenoticHemodynamics.invariant_speed_factor(params) ≈ StenoticHemodynamics.wall_invariant_speed_factor(params)
    @test StenoticHemodynamics.params_with(params; wall_law=CanicKoiterWallLaw()).wall_law isa CanicKoiterWallLaw
end

@testset "StenoticHemodynamics inlet and outlet boundaries" begin
    waveform = FlowWaveformInlet([0.0, 1.0], [0.0, 10.0])
    waveform_params = Params(initial_condition=GeometryRestIC(), inlet_boundary=waveform)
    @test inlet_boundary_name(waveform_params.inlet_boundary) == "flow-waveform"
    @test inlet_flow(waveform_params, 0.5) ≈ 5.0
    @test inlet_flow(waveform_params, 1.25) ≈ 2.5

    steady_params = Params(initial_condition=GeometryRestIC(), inlet_boundary=SteadyVelocityInlet(20.0))
    r0_in, _, _ = StenoticHemodynamics.stenosis(0.0, steady_params)
    @test inlet_boundary_name(steady_params.inlet_boundary) == "steady-velocity"
    @test inlet_flow(steady_params, 10.0) ≈ r0_in^2 * 10.0

    rt_params = Params(
        nx=4,
        severity=0.0,
        initial_condition=GeometryRestIC(),
        outlet_boundary=ReflectionCoefficientOutlet(0.0),
    )
    _, _, Aout, Qout = StenoticHemodynamics.boundary_states([0.04, 0.04, 0.04, 0.04], [0.0, 0.0, 0.0, 0.01], rt_params, 0.0)
    r0_out, _, _ = StenoticHemodynamics.stenosis(rt_params.length_cm, rt_params)
    @test StenoticHemodynamics.invariant_minus(Aout, Qout, rt_params) ≈ StenoticHemodynamics.invariant_minus(r0_out^2, 0.0, rt_params)
    @test_throws ArgumentError StenoticHemodynamics.validate(ReflectionCoefficientOutlet(1.5))
end

@testset "StenoticHemodynamics spatial methods and steppers" begin
    @test minmod(2.0, 3.0) == 2.0
    @test minmod(-2.0, -3.0) == -2.0
    @test minmod(-2.0, 3.0) == 0.0
    @test DGMethod(3).degree == 3
    @test DGMethod(4).degree == 4
    @test_throws ArgumentError DGMethod(5)

    @test StenoticHemodynamics.reconstructed_area(0.02, -0.01, 1.0) > 0.0
    @test StenoticHemodynamics.reconstructed_area(1.0e-14, -1.0, 1.0) >= StenoticHemodynamics.AREA_LIMITER_FLOOR

    weno_params = Params(nx=6, tfinal=1.0e-5, severity=0.0, initial_condition=GeometryRestIC())
    z_weno = [(i - 0.5) * (weno_params.length_cm / weno_params.nx) for i in 1:weno_params.nx]
    A_constant = fill(0.04, weno_params.nx)
    Q_constant = fill(0.02, weno_params.nx)
    AL, QL, AR, QR = StenoticHemodynamics.weno3_interface_states(
        A_constant,
        Q_constant,
        z_weno,
        3,
        FVWENO3Method().epsilon,
        weno_params,
    )
    @test AL ≈ 0.04
    @test QL ≈ 0.02
    @test AR ≈ 0.04
    @test QR ≈ 0.02

    A_monotone = [0.02, 0.025, 0.03, 0.035, 0.04, 0.045]
    Q_monotone = [0.00, 0.01, 0.02, 0.03, 0.04, 0.05]
    ALm, QLm, ARm, QRm = StenoticHemodynamics.weno3_interface_states(
        A_monotone,
        Q_monotone,
        z_weno,
        3,
        FVWENO3Method().epsilon,
        weno_params,
    )
    @test isfinite(ALm)
    @test isfinite(QLm)
    @test isfinite(ARm)
    @test isfinite(QRm)
    @test ALm >= StenoticHemodynamics.AREA_LIMITER_FLOOR
    @test ARm >= StenoticHemodynamics.AREA_LIMITER_FLOOR

    lambda_minus, lambda_plus = StenoticHemodynamics.characteristic_basis(0.04, 0.02, z_weno[3], weno_params)
    wminus, wplus = StenoticHemodynamics.conservative_to_characteristic(0.04, 0.02, lambda_minus, lambda_plus)
    Around, Qround = StenoticHemodynamics.characteristic_to_conservative(wminus, wplus, lambda_minus, lambda_plus)
    @test Around ≈ 0.04
    @test Qround ≈ 0.02

    xis, weights = dg_quadrature()
    @test sum(weights) ≈ 2.0
    @test sum(w * legendre_value(1, xi) for (xi, w) in zip(xis, weights)) ≈ 0.0 atol=1.0e-14
    @test sum(w * legendre_value(2, xi) for (xi, w) in zip(xis, weights)) ≈ 0.0 atol=1.0e-14
    @test sum(w * xi^4 for (xi, w) in zip(xis, weights)) ≈ 2.0 / 5.0
    @test legendre_value(3, 0.25) ≈ 0.5 * (5.0 * 0.25^3 - 3.0 * 0.25)
    @test legendre_value(4, 0.25) ≈ (35.0 * 0.25^4 - 30.0 * 0.25^2 + 3.0) / 8.0
    @test legendre_derivative(3, 0.25) ≈ 0.5 * (15.0 * 0.25^2 - 3.0)
    @test legendre_derivative(4, 0.25) ≈ 0.5 * (35.0 * 0.25^3 - 15.0 * 0.25)
    xis5, weights5 = dg_quadrature(4)
    @test length(xis5) == 5
    @test sum(weights5) ≈ 2.0
    @test sum(w * xi^8 for (xi, w) in zip(xis5, weights5)) ≈ 2.0 / 9.0
    zq_centers = collect(range(0.125, step=0.25, length=64))
    zq_dx = 0.25
    StenoticHemodynamics.dg_quadrature_locations(zq_centers, zq_dx, xis5)
    zq_allocated = @allocated StenoticHemodynamics.dg_quadrature_locations(zq_centers, zq_dx, xis5)
    zq_locations = StenoticHemodynamics.dg_quadrature_locations(zq_centers, zq_dx, xis5)
    @test length(zq_locations) == length(zq_centers) * length(xis5)
    @test zq_locations[begin:length(xis5)] ≈ [first(zq_centers) + 0.5 * zq_dx * xi for xi in xis5]
    @test zq_locations[(end - length(xis5) + 1):end] ≈ [last(zq_centers) + 0.5 * zq_dx * xi for xi in xis5]
    @test zq_allocated <= sizeof(Float64) * length(zq_locations) + 2048

    @test observed_order(0.25, 0.125) ≈ 1.0
    @test isnan(observed_order(0.0, 0.125))

    params = Params(nx=8, tfinal=1.0e-5, severity=30.0, initial_condition=GeometryRestIC())
    z, A, Q, dx = StenoticHemodynamics.initial_state(params)
    dt = min(StenoticHemodynamics.choose_dt(A, Q, z, dx, params), params.tfinal)
    dA_uncached, dQ_uncached = StenoticHemodynamics.rhs_dt(A, Q, z, dx, dt, 0.0, params)
    dA_cached, dQ_cached = StenoticHemodynamics.rhs_dt(A, Q, z, dx, dt, 0.0, params; cache=StenoticHemodynamics.RHSCache(length(A)))
    @test dA_cached ≈ dA_uncached
    @test dQ_cached ≈ dQ_uncached

    A_reference, Q_reference = StenoticHemodynamics.native_step(copy(A), copy(Q), z, dx, dt, 0.0, params.time_stepper, params)
    A_mutating = copy(A)
    Q_mutating = copy(Q)
    StenoticHemodynamics.native_step!(A_mutating, Q_mutating, z, dx, dt, 0.0, params, StenoticHemodynamics.NativeStepCache(length(A)))
    @test A_mutating ≈ A_reference
    @test Q_mutating ≈ Q_reference

    dg_method = DGMethod(2)
    dg_params = Params(nx=8, tfinal=1.0e-5, severity=30.0, space=dg_method, initial_condition=GeometryRestIC())
    z_dg, Acoef, Qcoef, dx_dg = StenoticHemodynamics.dg_initial_coefficients(dg_params, dg_method)
    StenoticHemodynamics.limit_dg_coefficients!(Acoef, Qcoef, dg_method)
    dt_dg = min(StenoticHemodynamics.choose_dt_dg(Acoef, Qcoef, z_dg, dx_dg, dg_params, dg_method), dg_params.tfinal)
    dA_dg, dQ_dg = StenoticHemodynamics.dg_rhs(Acoef, Qcoef, z_dg, dx_dg, dg_params, dg_method, 0.0)
    dg_rhs_cache = StenoticHemodynamics.DGRHSCache(size(Acoef, 1), dg_method.degree)
    dA_cached = similar(Acoef)
    dQ_cached = similar(Qcoef)
    StenoticHemodynamics.fill_dg_rhs!(
        dA_cached,
        dQ_cached,
        Acoef,
        Qcoef,
        z_dg,
        dx_dg,
        dg_params,
        dg_method,
        0.0,
        dg_rhs_cache,
    )
    @test dA_cached ≈ dA_dg
    @test dQ_cached ≈ dQ_dg

    A_dg_reference, Q_dg_reference =
        StenoticHemodynamics.dg_step(copy(Acoef), copy(Qcoef), z_dg, dx_dg, dt_dg, 0.0, dg_params, dg_method)
    A_dg_mutating = copy(Acoef)
    Q_dg_mutating = copy(Qcoef)
    StenoticHemodynamics.dg_step!(
        A_dg_mutating,
        Q_dg_mutating,
        z_dg,
        dx_dg,
        dt_dg,
        0.0,
        dg_params,
        dg_method,
        StenoticHemodynamics.DGStepCache(size(Acoef, 1), dg_method.degree),
    )
    @test A_dg_mutating ≈ A_dg_reference
    @test Q_dg_mutating ≈ Q_dg_reference
end
