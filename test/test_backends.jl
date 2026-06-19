@testset "StenosisHemodynamics simulation backends" begin
    native_params = Params(nx=8, tfinal=5.0e-5, severity=30.0, initial_condition=GeometryRestIC())

    @testset "native short run" begin
        result = simulate(native_params, NativeRK3Backend(); progress_every=0)
        assert_finite_positive_state(result, native_params)
    end

    @testset "native lifecycle logs" begin
        result = @test_logs (:info, "simulation started") (:info, "simulation completed") begin
            simulate(native_params, NativeRK3Backend(); progress_every=0)
        end
        assert_finite_positive_state(result, native_params)
    end

    @testset "native short run with Carreau-Yasuda rheology" begin
        rheology_params = Params(
            nx=8,
            tfinal=2.0e-5,
            severity=30.0,
            rheology=CarreauYasudaRheology(max_eta=0.5),
            initial_condition=GeometryRestIC(),
        )
        result = simulate(rheology_params, NativeRK3Backend(); progress_every=0)
        assert_finite_positive_state(result, rheology_params)
    end

    @testset "native spatial method smoke runs" begin
        for method in (FVMUSCLMethod(), FVLaxWendroffMethod(), DGMethod(0), DGMethod(1), DGMethod(2))
            params = Params(nx=8, tfinal=1.0e-5, severity=30.0, space=method, initial_condition=GeometryRestIC())
            result = simulate(params, NativeRK3Backend(); progress_every=0)
            assert_finite_positive_state(result, params)
        end
    end

    @testset "native time stepper smoke runs" begin
        for stepper in (ForwardEulerStepper(), SSPRK2Stepper(), SSPRK3Stepper())
            params = Params(nx=8, tfinal=1.0e-5, severity=30.0, time_stepper=stepper, initial_condition=GeometryRestIC())
            result = simulate(params, NativeRK3Backend(); progress_every=0)
            assert_finite_positive_state(result, params)
        end
    end

    @testset "native velocity profile smoke runs" begin
        for profile in (FlatVelocityProfile(), ParabolicVelocityProfile(), PowerVelocityProfile(exponent=9.0))
            params = Params(nx=8, tfinal=1.0e-5, severity=30.0, velocity_profile=profile, initial_condition=GeometryRestIC())
            result = simulate(params, NativeRK3Backend(); progress_every=0)
            assert_finite_positive_state(result, params)
        end
    end

    @testset "DG p0 finite-volume equivalence" begin
        fv_params = Params(nx=8, tfinal=1.0e-5, severity=30.0, space=FVFirstOrderMethod(), initial_condition=GeometryRestIC())
        dg_params = Params(nx=8, tfinal=1.0e-5, severity=30.0, space=DGMethod(0), initial_condition=GeometryRestIC())
        fv = simulate(fv_params, NativeRK3Backend(); progress_every=0)
        dg = simulate(dg_params, NativeRK3Backend(); progress_every=0)
        @test maximum(abs.(fv.area .- dg.area)) <= 1.0e-12
        @test maximum(abs.(fv.flow .- dg.flow)) <= 1.0e-12
    end

    @testset "SciML short run" begin
        backend = SciMLTimeBackend(
            solve=SolveSpec(
                algorithm=Tsit5Policy(),
                abstol=1.0e-9,
                reltol=1.0e-9,
            ),
        )
        result = simulate(native_params, backend; progress_every=0)
        assert_finite_positive_state(result, native_params)
    end

    @testset "native and SciML tiny-run agreement" begin
        backend = SciMLTimeBackend(
            solve=SolveSpec(
                algorithm=Tsit5Policy(),
                abstol=1.0e-9,
                reltol=1.0e-9,
            ),
        )
        native = simulate(native_params, NativeRK3Backend(); progress_every=0)
        sciml = simulate(native_params, backend; progress_every=0)

        # Different time integrators are expected to diverge on longer runs;
        # this smoke comparison only checks the shared semi-discrete RHS on a
        # tiny horizon where RK3 and tight-tolerance Tsit5 agree closely.
        @test maximum(abs.(native.area .- sciml.area)) <= 1.0e-8
        @test maximum(abs.(native.flow .- sciml.flow)) <= 1.0e-5
        @test maximum(abs.(velocity(native) .- velocity(sciml))) <= 1.0e-3
    end
end
