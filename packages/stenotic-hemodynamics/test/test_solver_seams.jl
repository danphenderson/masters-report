@testset "solver seams inlet area solve" begin
    params = Params(initial_condition=GeometryRestIC(), severity=0.0)
    c0 = StenoticHemodynamics.invariant_speed_factor(params)
    target_area = 0.04
    Qin = 0.8
    w2 = Qin / target_area - 4.0 * c0 * target_area^0.25

    Ain = StenoticHemodynamics.solve_inlet_area(Qin, w2, 0.02, params)
    residual = Qin / Ain - w2 - 4.0 * c0 * Ain^0.25

    @test Ain > StenoticHemodynamics.AREA_LIMITER_FLOOR
    @test Ain ≈ target_area atol=1.0e-10
    @test abs(residual) <= 1.0e-8

    controls = StenoticHemodynamics.InletAreaSolveControls(
        residual_tolerance=1.0e-12,
        area_tolerance=1.0e-14,
        max_bisection_iterations=96,
    )
    controlled_Ain = StenoticHemodynamics.solve_inlet_area(Qin, w2, 0.02, params; controls)
    controlled_residual = Qin / controlled_Ain - w2 - 4.0 * c0 * controlled_Ain^0.25
    @test controlled_Ain ≈ target_area atol=1.0e-11
    @test abs(controlled_residual) <= 1.0e-9

    Ain32 = StenoticHemodynamics.solve_inlet_area(Float32(Qin), Float32(w2), Float32(0.02), params)
    @test typeof(Ain32) === Float32
    @test Ain32 ≈ Float32(target_area) atol=Float32(1.0e-6)

    growth_controls = StenoticHemodynamics.InletAreaSolveControls(
        bracket_lower_scale=0.8,
        bracket_upper_scale=1.2,
        bracket_growth_factor=2.0,
        residual_tolerance=1.0e-12,
        area_tolerance=1.0e-14,
        max_bracket_iterations=8,
        max_bisection_iterations=96,
    )
    growth_Ain = StenoticHemodynamics.solve_inlet_area(Qin, w2, 0.002, params; controls=growth_controls)
    @test growth_Ain ≈ target_area atol=1.0e-11

    no_growth_controls = StenoticHemodynamics.InletAreaSolveControls(
        bracket_lower_scale=0.8,
        bracket_upper_scale=1.2,
        bracket_growth_factor=2.0,
        max_bracket_iterations=0,
    )
    no_growth = @test_logs (:warn, "inlet area solver failed to bracket; returning limited guess") begin
        StenoticHemodynamics.solve_inlet_area(Qin, w2, 0.002, params; controls=no_growth_controls)
    end
    @test no_growth == 0.002

    invalid_controls = (
        StenoticHemodynamics.InletAreaSolveControls(bracket_lower_scale=0.0),
        StenoticHemodynamics.InletAreaSolveControls(bracket_upper_scale=0.01),
        StenoticHemodynamics.InletAreaSolveControls(bracket_growth_factor=1.0),
        StenoticHemodynamics.InletAreaSolveControls(residual_tolerance=Inf),
        StenoticHemodynamics.InletAreaSolveControls(area_tolerance=0.0),
        StenoticHemodynamics.InletAreaSolveControls(max_bracket_iterations=-1),
    )
    for invalid_control in invalid_controls
        @test_throws ArgumentError StenoticHemodynamics.solve_inlet_area(
            Qin,
            w2,
            0.02,
            params;
            controls=invalid_control,
        )
    end

    @test_throws ArgumentError StenoticHemodynamics.solve_inlet_area(
        Qin,
        w2,
        0.02,
        params;
        controls=StenoticHemodynamics.InletAreaSolveControls(max_bisection_iterations=0),
    )

    failed_guess = StenoticHemodynamics.AREA_LIMITER_FLOOR / 10.0
    failed = @test_logs (:warn, "inlet area solver failed to bracket; returning limited guess") begin
        StenoticHemodynamics.solve_inlet_area(-0.01, 0.0, failed_guess, params)
    end
    @test failed == StenoticHemodynamics.AREA_LIMITER_FLOOR
end

@testset "solver seams finite-volume flux helpers" begin
    first_order_params = Params(
        nx=6,
        tfinal=1.0e-5,
        severity=20.0,
        space=FVFirstOrderMethod(),
        initial_condition=GeometryRestIC(),
    )
    z_first, A_first_base, _, dx_first = StenoticHemodynamics.initial_state(first_order_params)
    A_first = collect(A_first_base .+ range(-1.0e-4, 1.0e-4; length=first_order_params.nx))
    Q_first = collect(range(0.001, 0.006; length=first_order_params.nx))
    first_cache = StenoticHemodynamics.RHSCache(length(A_first))

    StenoticHemodynamics.fill_method_fluxes!(
        first_cache.area_flux,
        first_cache.flow_flux,
        A_first,
        Q_first,
        z_first,
        dx_first,
        0.0,
        0.0,
        first_order_params.space,
        first_order_params,
        first_cache,
    )

    Ain, Qin, _, _ = StenoticHemodynamics.boundary_states(A_first, Q_first, first_order_params, 0.0)
    expected_inlet = StenoticHemodynamics.rusanov_flux(Ain, Qin, A_first[1], Q_first[1], 0.0, first_order_params)
    zi = 0.5 * (z_first[2] + z_first[3])
    expected_interior = StenoticHemodynamics.rusanov_flux(
        A_first[2],
        Q_first[2],
        A_first[3],
        Q_first[3],
        zi,
        first_order_params,
    )

    @test first_cache.area_flux[1] ≈ expected_inlet[1]
    @test first_cache.flow_flux[1] ≈ expected_inlet[2]
    @test first_cache.area_flux[3] ≈ expected_interior[1]
    @test first_cache.flow_flux[3] ≈ expected_interior[2]

    muscl_params = Params(
        nx=6,
        tfinal=1.0e-5,
        severity=20.0,
        space=FVMUSCLMethod(),
        initial_condition=GeometryRestIC(),
    )
    z_muscl, A_muscl_base, _, dx_muscl = StenoticHemodynamics.initial_state(muscl_params)
    A_muscl = collect(A_muscl_base .+ range(-1.0e-4, 1.0e-4; length=muscl_params.nx))
    Q_muscl = collect(range(0.001, 0.006; length=muscl_params.nx))
    A_original = copy(A_muscl)
    Q_original = copy(Q_muscl)
    dt_muscl = min(StenoticHemodynamics.choose_dt(A_muscl, Q_muscl, z_muscl, dx_muscl, muscl_params), muscl_params.tfinal)

    FA_uncached = zeros(length(A_muscl) + 1)
    FQ_uncached = zeros(length(A_muscl) + 1)
    FA_cached = similar(FA_uncached)
    FQ_cached = similar(FQ_uncached)
    muscl_cache = StenoticHemodynamics.RHSCache(length(A_muscl))

    StenoticHemodynamics.fill_method_fluxes!(
        FA_uncached,
        FQ_uncached,
        A_muscl,
        Q_muscl,
        z_muscl,
        dx_muscl,
        dt_muscl,
        0.0,
        muscl_params.space,
        muscl_params,
    )
    StenoticHemodynamics.fill_method_fluxes!(
        FA_cached,
        FQ_cached,
        A_muscl,
        Q_muscl,
        z_muscl,
        dx_muscl,
        dt_muscl,
        0.0,
        muscl_params.space,
        muscl_params,
        muscl_cache,
    )

    @test FA_cached ≈ FA_uncached
    @test FQ_cached ≈ FQ_uncached
    @test all(isfinite, FA_cached)
    @test all(isfinite, FQ_cached)
    @test A_muscl == A_original
    @test Q_muscl == Q_original
end

@testset "solver seams native step cache reuse" begin
    params = Params(
        nx=8,
        tfinal=1.0e-5,
        severity=30.0,
        space=FVMUSCLMethod(),
        time_stepper=SSPRK3Stepper(),
        initial_condition=GeometryRestIC(),
    )
    z, A, Q, dx = StenoticHemodynamics.initial_state(params)
    dt = min(StenoticHemodynamics.choose_dt(A, Q, z, dx, params), params.tfinal)

    A_reference, Q_reference =
        StenoticHemodynamics.native_step(copy(A), copy(Q), z, dx, dt, 0.0, params.time_stepper, params)

    cache = StenoticHemodynamics.NativeStepCache(length(A))

    A_one = copy(A)
    Q_one = copy(Q)
    StenoticHemodynamics.native_step!(A_one, Q_one, z, dx, dt, 0.0, params, cache)

    A_two = copy(A)
    Q_two = copy(Q)
    StenoticHemodynamics.native_step!(A_two, Q_two, z, dx, dt, 0.0, params, cache)

    @test A_one ≈ A_reference
    @test Q_one ≈ Q_reference
    @test A_two ≈ A_reference
    @test Q_two ≈ Q_reference
end
