@testset "CanicExtended1D rheology closures" begin
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
    @test_throws ArgumentError CanicExtended1D.validate(CarreauRheology(eta0=0.01, eta_inf=0.02))
end
@testset "CanicExtended1D velocity profiles" begin
    parabolic = ParabolicVelocityProfile()
    @test profile_name(parabolic) == "parabolic"
    @test momentum_alpha(parabolic) ≈ 4.0 / 3.0
    @test shear_rate_factor(parabolic) ≈ 4.0
    @test mean_to_max_velocity_ratio(parabolic) ≈ 0.5
    @test radial_profile_velocity(3.0, 0.0, 2.0, parabolic) ≈ 6.0
    @test radial_profile_velocity(3.0, 2.0, 2.0, parabolic) ≈ 0.0

    flat = FlatVelocityProfile(shear_rate_factor=5.0)
    @test profile_name(flat) == "flat"
    @test momentum_alpha(flat) ≈ 1.0
    @test shear_rate_factor(flat) ≈ 5.0
    @test mean_to_max_velocity_ratio(flat) ≈ 1.0
    @test radial_profile_velocity(3.0, 1.5, 2.0, flat) ≈ 3.0

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
    @test CanicExtended1D.inlet_uavg(default_params) ≈ 22.5
    @test CanicExtended1D.inlet_uavg(Params(initial_condition=GeometryRestIC(), velocity_profile=flat)) ≈ 45.0
    @test default_output_stub(Params()) == "simulations/output/canic_extended_1d_severity50_vp_parabolic"
    @test occursin("vp_parabolic", default_output_stub(default_params))
    @test default_output_stub(default_params) != default_output_stub(Params(alpha=1.1, initial_condition=GeometryRestIC()))
    @test default_output_stub(Params(initial_condition=GeometryRestIC(), velocity_profile=PowerVelocityProfile(exponent=4.0))) !=
          default_output_stub(Params(initial_condition=GeometryRestIC(), velocity_profile=PowerVelocityProfile(exponent=9.0)))
    @test default_output_stub(Params(initial_condition=GeometryRestIC(), velocity_profile=FlatVelocityProfile(shear_rate_factor=4.0))) !=
          default_output_stub(Params(initial_condition=GeometryRestIC(), velocity_profile=FlatVelocityProfile(shear_rate_factor=8.0)))
    @test_throws ArgumentError Params(alpha=1.1, velocity_profile=ParabolicVelocityProfile())
    @test_throws ArgumentError CanicExtended1D.params_with(default_params; velocity_profile=flat, alpha=1.1)
    @test_throws ArgumentError CanicExtended1D.validate(FlatVelocityProfile(shear_rate_factor=0.0))
    @test_throws ArgumentError PowerVelocityProfile(alpha=1.0)
end

@testset "CanicExtended1D Canic-Koiter wall law" begin
    params = Params(initial_condition=GeometryRestIC(), severity=30.0)
    z = 2.75
    A = 0.035
    Q = 0.012
    r0, r0z, _ = CanicExtended1D.stenosis(z, params)
    K = CanicExtended1D.wall_stiffness(params)
    gamma_plus_two = CanicExtended1D.gamma_plus_two(params)
    nu_eff = CanicExtended1D.effective_kinematic_viscosity(A, Q, r0, params)

    @test params.wall_law isa CanicKoiterWallLaw
    @test wall_law_name(params) == "canic-koiter-thin-membrane"
    @test CanicExtended1D.wall_reference_radius(params) ≈ params.rmax
    @test CanicExtended1D.wall_elastic_pressure(A, z, params) ≈ K / r0^2 * (sqrt(A) - r0)
    @test CanicExtended1D.variable_radius_pressure_correction(A, Q, r0, r0z, nu_eff, gamma_plus_two, params) ≈
          gamma_plus_two * params.rho * nu_eff * Q / A * r0z / r0
    @test CanicExtended1D.pressure([A], [Q], [z], params)[1] ≈
          CanicExtended1D.wall_elastic_pressure(A, z, params) +
          CanicExtended1D.variable_radius_pressure_correction(A, Q, r0, r0z, nu_eff, gamma_plus_two, params)
    @test CanicExtended1D.wall_elastic_potential(A, z, params) ≈ K / (3.0 * params.rho * params.rmax^2) * A^1.5
    @test CanicExtended1D.wall_wave_speed_squared(A, z, params) ≈ K / (2.0 * params.rho * params.rmax^2) * sqrt(A)
    @test CanicExtended1D.wall_geometry_source(A, z, r0, r0z, params) ≈ K / (params.rho * params.rmax^2) * A * r0z
    @test CanicExtended1D.invariant_speed_factor(params) ≈ CanicExtended1D.wall_invariant_speed_factor(params)
    @test CanicExtended1D.params_with(params; wall_law=CanicKoiterWallLaw()).wall_law isa CanicKoiterWallLaw
end

@testset "CanicExtended1D inlet and outlet boundaries" begin
    waveform = FlowWaveformInlet([0.0, 1.0], [0.0, 10.0])
    waveform_params = Params(initial_condition=GeometryRestIC(), inlet_boundary=waveform)
    @test inlet_boundary_name(waveform_params.inlet_boundary) == "flow-waveform"
    @test inlet_flow(waveform_params, 0.5) ≈ 5.0
    @test inlet_flow(waveform_params, 1.25) ≈ 2.5

    steady_params = Params(initial_condition=GeometryRestIC(), inlet_boundary=SteadyVelocityInlet(20.0))
    r0_in, _, _ = CanicExtended1D.stenosis(0.0, steady_params)
    @test inlet_boundary_name(steady_params.inlet_boundary) == "steady-velocity"
    @test inlet_flow(steady_params, 10.0) ≈ r0_in^2 * 10.0

    rt_params = Params(
        nx=4,
        severity=0.0,
        initial_condition=GeometryRestIC(),
        outlet_boundary=ReflectionCoefficientOutlet(0.0),
    )
    _, _, Aout, Qout = CanicExtended1D.boundary_states([0.04, 0.04, 0.04, 0.04], [0.0, 0.0, 0.0, 0.01], rt_params, 0.0)
    r0_out, _, _ = CanicExtended1D.stenosis(rt_params.length_cm, rt_params)
    @test CanicExtended1D.invariant_minus(Aout, Qout, rt_params) ≈ CanicExtended1D.invariant_minus(r0_out^2, 0.0, rt_params)
    @test_throws ArgumentError CanicExtended1D.validate(ReflectionCoefficientOutlet(1.5))
end

@testset "CanicExtended1D spatial methods and steppers" begin
    @test minmod(2.0, 3.0) == 2.0
    @test minmod(-2.0, -3.0) == -2.0
    @test minmod(-2.0, 3.0) == 0.0

    @test CanicExtended1D.reconstructed_area(0.02, -0.01, 1.0) > 0.0
    @test CanicExtended1D.reconstructed_area(1.0e-14, -1.0, 1.0) >= CanicExtended1D.AREA_LIMITER_FLOOR

    xis, weights = dg_quadrature()
    @test sum(weights) ≈ 2.0
    @test sum(w * legendre_value(1, xi) for (xi, w) in zip(xis, weights)) ≈ 0.0 atol=1.0e-14
    @test sum(w * legendre_value(2, xi) for (xi, w) in zip(xis, weights)) ≈ 0.0 atol=1.0e-14
    @test sum(w * xi^4 for (xi, w) in zip(xis, weights)) ≈ 2.0 / 5.0

    @test observed_order(0.25, 0.125) ≈ 1.0
    @test isnan(observed_order(0.0, 0.125))

    params = Params(nx=8, tfinal=1.0e-5, severity=30.0, initial_condition=GeometryRestIC())
    z, A, Q, dx = CanicExtended1D.initial_state(params)
    dt = min(CanicExtended1D.choose_dt(A, Q, z, dx, params), params.tfinal)
    dA_uncached, dQ_uncached = CanicExtended1D.rhs_dt(A, Q, z, dx, dt, 0.0, params)
    dA_cached, dQ_cached = CanicExtended1D.rhs_dt(A, Q, z, dx, dt, 0.0, params; cache=CanicExtended1D.RHSCache(length(A)))
    @test dA_cached ≈ dA_uncached
    @test dQ_cached ≈ dQ_uncached

    A_reference, Q_reference = CanicExtended1D.native_step(copy(A), copy(Q), z, dx, dt, 0.0, params.time_stepper, params)
    A_mutating = copy(A)
    Q_mutating = copy(Q)
    CanicExtended1D.native_step!(A_mutating, Q_mutating, z, dx, dt, 0.0, params, CanicExtended1D.NativeStepCache(length(A)))
    @test A_mutating ≈ A_reference
    @test Q_mutating ≈ Q_reference
end

function write_openbf_fixture(dir::String; project_name::String = "strict_one", extra_vessel::String = "", include_canic::Bool = true)
    inlet_path = joinpath(dir, "inlet.dat")
    write(
        inlet_path,
        """
        0.0 1.0e-6
        1.0e-5 2.0e-6
        """,
    )

    canic_block = include_canic ? """
    canic:
      severity_percent: 30.0
      dt: 1.0e-5
      initial_condition:
        pressure_drop_pa: 40.0
        mesh_nz: 1
        mesh_nr: 1
        mesh_ntheta: 4
    """ : ""

    config_path = joinpath(dir, "input.yml")
    write(
        config_path,
        """
        project_name: $project_name
        inlet_file: "inlet.dat"
        output_directory: "out"
        write_results: ["P", "Q", "A", "u"]
        blood:
          rho: 1060.0
          mu: 0.004
        solver:
          Ccfl: 0.45
          cycles: 2
          jump: 5
          convergence_tolerance: 1.0
        network:
          - label: vessel
            sn: 1
            tn: 2
            L: 0.06
            M: 8
            E: 5.02e5
            R0: 0.0018
            h0: 0.0006
            gamma_profile: 9
            Rt: 0.25
            $extra_vessel
        $canic_block
        """,
    )
    return config_path, inlet_path
end
