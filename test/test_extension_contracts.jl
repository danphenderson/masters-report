@testset "StenosisHemodynamics extension contracts" begin
    @testset "spatial method traits" begin
        fv_methods = (
            FVFirstOrderMethod(),
            FVMUSCLMethod(),
            FVWENO3Method(),
            FVLaxWendroffMethod(),
        )
        for method in fv_methods
            @test StenosisHemodynamics.method_family(method) == :finite_volume
            @test !StenosisHemodynamics.requires_native_modal_solver(method)
            @test degrees_of_freedom(7, method) == 14
        end

        @test StenosisHemodynamics.method_family(DGMethod(2)) == :discontinuous_galerkin
        @test !StenosisHemodynamics.requires_fixed_timestep(FVMUSCLMethod())
        @test StenosisHemodynamics.requires_fixed_timestep(FVLaxWendroffMethod())
        @test !StenosisHemodynamics.requires_native_modal_solver(DGMethod(0))
        @test StenosisHemodynamics.requires_native_modal_solver(DGMethod(1))
        @test degrees_of_freedom(7, DGMethod(3)) == 56
    end

    @testset "backend support traits" begin
        native = NativeRK3Backend()
        sciml = SciMLTimeBackend()

        @test StenosisHemodynamics.supports_backend(FVMUSCLMethod(), native)
        @test StenosisHemodynamics.supports_backend(FVMUSCLMethod(), sciml)
        @test !StenosisHemodynamics.supports_backend(FVLaxWendroffMethod(), sciml)
        @test StenosisHemodynamics.supports_backend(DGMethod(0), sciml)
        @test !StenosisHemodynamics.supports_backend(DGMethod(1), sciml)

        lax_params = Params(
            nx=8,
            tfinal=1.0e-5,
            space=FVLaxWendroffMethod(),
            initial_condition=GeometryRestIC(),
        )
        lax_error = try
            simulate(lax_params, sciml; progress_every=0)
            nothing
        catch err
            err
        end
        @test lax_error isa ArgumentError
        @test occursin("fixed-step", sprint(showerror, lax_error))

        dg_params = Params(
            nx=8,
            tfinal=1.0e-5,
            space=DGMethod(1),
            initial_condition=GeometryRestIC(),
        )
        dg_error = try
            simulate(dg_params, sciml; progress_every=0)
            nothing
        catch err
            err
        end
        @test dg_error isa ArgumentError
        @test occursin("native modal DG solver", sprint(showerror, dg_error))
    end

    @testset "Van Leer limiter extension pilot" begin
        limiter = StenosisHemodynamics.VanLeerLimiter()
        @test limiter_name(limiter) == "van-leer"
        @test StenosisHemodynamics.limited_slope([1.0, 2.0, 4.0], 2, limiter) ≈ 4.0 / 3.0
        @test StenosisHemodynamics.limited_slope([1.0, 2.0, 1.0], 2, limiter) == 0.0

        for method in (FVMUSCLMethod(limiter), FVLaxWendroffMethod(limiter))
            params = Params(nx=8, tfinal=1.0e-5, severity=30.0, space=method, initial_condition=GeometryRestIC())
            result = simulate(params, NativeRK3Backend(); progress_every=0)
            assert_finite_positive_state(result, params)
            @test occursin("van-leer", spatial_method_name(method))
        end
    end

    @testset "workflow protocol helpers" begin
        mktempdir() do dir
            severity_spec = SeveritySweepSpec(
                base_params=Params(nx=8, tfinal=1.0e-5, initial_condition=GeometryRestIC()),
                severities=[23.0],
                summary_csv=joinpath(dir, "severity.csv"),
                parallel_workers=0,
            )
            @test severity_spec isa AbstractStudySpec
            @test StenosisHemodynamics.workflow_kind(severity_spec) == "severity_sweep"
            @test StenosisHemodynamics.default_output_paths(severity_spec).summary_csv == joinpath(dir, "severity.csv")
            @test StenosisHemodynamics.validate_workflow_spec(severity_spec) === severity_spec

            refinement_spec = RefinementStudySpec(
                base_params=Params(nx=8, tfinal=1.0e-5, initial_condition=GeometryRestIC()),
                nxs=[8, 16],
                degrees=[0, 1],
                output_dir=joinpath(dir, "refinement"),
                parallel_workers=0,
            )
            refinement_paths = StenosisHemodynamics.default_output_paths(refinement_spec)
            @test StenosisHemodynamics.workflow_kind(refinement_spec) == "refinement"
            @test basename.(refinement_paths.csv_paths) == ["h_refinement.csv", "p_refinement.csv"]

            case_spec = Resolved3DCaseSpec("77", 23.0, joinpath(dir, "velocity.xdmf"); target_time=5.0e-5)
            comparison_spec = ComparisonSpec(
                cases=[case_spec],
                base_params=Params(nx=8, tfinal=5.0e-5, initial_condition=GeometryRestIC()),
                output_dir=joinpath(dir, "comparison"),
                section_count=3,
                profile_slices=[0.0],
                radial_bins=3,
                write_svg=true,
            )
            comparison_paths = StenosisHemodynamics.default_output_paths(comparison_spec)
            @test comparison_spec isa AbstractStudySpec
            @test StenosisHemodynamics.workflow_kind(comparison_spec) == "resolved3d_comparison"
            @test basename(comparison_paths.summary_csv) == "comparison_summary.csv"
            @test basename(comparison_paths.overlay_svg) == "section_quadrature_overlay.svg"

            benchmark_spec = PackageBenchmarkSpec(output_dir=joinpath(dir, "benchmark"))
            benchmark_paths = StenosisHemodynamics.default_output_paths(benchmark_spec)
            @test benchmark_spec isa AbstractStudySpec
            @test StenosisHemodynamics.workflow_kind(benchmark_spec) == "package_benchmark"
            @test basename(benchmark_paths.case_results) == "case_results.csv"
            @test basename(benchmark_paths.manifest) == "manifest.json"
        end
    end

    @testset "CLI extension hooks" begin
        params, output, backend = StenosisHemodynamics.parse_args([
            "--space",
            "fv-muscl",
            "--limiter",
            "van_leer",
            "--tfinal",
            "1e-5",
            "--nx",
            "8",
            "--progress-every",
            "0",
            "--no-svg",
            "--ic",
            "geometry-rest",
        ])
        @test params.space isa FVMUSCLMethod
        @test params.space.limiter isa StenosisHemodynamics.VanLeerLimiter
        @test output.write_svg == false
        @test backend isa NativeRK3Backend
        @test spatial_method_name(params.space) == "fv-muscl-van-leer"

        handlers = StenosisHemodynamics.CLI_COMMAND_HANDLERS
        @test Set(keys(handlers)) == Set([
            "simulate",
            "openbf-run",
            "study",
            "stokes",
            "verify",
            "compare-3d",
            "benchmark",
            "export-assets",
        ])
        @test handlers["simulate"] === StenosisHemodynamics.run_simulate_cli
        @test_throws ArgumentError run_cli(["--tfinal", "1e-5"])
        @test_throws ArgumentError run_cli(["not-a-command"])
    end
end
