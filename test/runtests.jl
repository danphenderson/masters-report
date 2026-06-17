using Test

include(joinpath(@__DIR__, "..", "simulations", "canic_extended_1d", "CanicExtended1D.jl"))
using .CanicExtended1D

function assert_finite_positive_state(result::SimulationResult, params::Params)
    @test result.completed_time ≈ params.tfinal
    @test result.steps >= 0
    @test length(result.area) == params.nx
    @test length(result.flow) == params.nx
    @test all(isfinite, result.area)
    @test all(isfinite, result.flow)
    @test minimum(result.area) > 0.0

    pressure_values = pressure(result, params)
    @test length(pressure_values) == params.nx
    @test all(isfinite, pressure_values)
end

@testset "CanicExtended1D simulation backends" begin
    native_params = Params(nx=8, tfinal=5.0e-5, severity=30.0)

    @testset "native short run" begin
        result = simulate(native_params, NativeRK3Backend(); progress_every=0)
        assert_finite_positive_state(result, native_params)
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

@testset "CanicExtended1D CLI parsing" begin
    @test parse_args(["--help"]) === nothing

    @testset "native defaults" begin
        params, output, backend = parse_args([
            "--tfinal", "5e-5",
            "--nx", "8",
            "--progress-every", "0",
            "--no-svg",
        ])

        @test params.tfinal == 5.0e-5
        @test params.nx == 8
        @test output.progress_every == 0
        @test output.write_svg == false
        @test backend isa NativeRK3Backend
    end

    @testset "SciML flags" begin
        params, output, backend = parse_args([
            "--backend", "sciml",
            "--alg", "tsit5",
            "--abstol", "1e-8",
            "--reltol=1e-7",
            "--save-everystep",
            "--maxiters", "123",
            "--tfinal", "5e-5",
            "--nx", "8",
            "--progress-every", "0",
            "--no-svg",
        ])

        @test params.tfinal == 5.0e-5
        @test output.write_svg == false
        @test backend isa SciMLTimeBackend
        @test backend.solve.algorithm isa Tsit5Policy
        @test backend.solve.abstol == 1.0e-8
        @test backend.solve.reltol == 1.0e-7
        @test backend.solve.save_everystep == true
        @test backend.solve.maxiters == 123
    end

    @testset "invalid combinations" begin
        @test_throws ArgumentError parse_args(["--backend", "native", "--alg", "tsit5"])
        @test_throws ArgumentError parse_args(["--backend", "sciml", "--alg", "ssprk"])
        @test_throws ArgumentError parse_args(["--abstol", "1e-8"])
        @test_throws ArgumentError parse_args(["--backend", "sciml", "--alg", "not-a-policy"])
    end
end
