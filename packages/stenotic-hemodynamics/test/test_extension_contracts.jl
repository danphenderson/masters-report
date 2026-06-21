@testset "StenoticHemodynamics extension contracts" begin
    @testset "spatial method traits" begin
        fv_methods = (
            FVFirstOrderMethod(),
            FVMUSCLMethod(),
            FVWENO3Method(),
            FVLaxWendroffMethod(),
        )
        for method in fv_methods
            @test StenoticHemodynamics.method_family(method) == :finite_volume
            @test !StenoticHemodynamics.requires_native_modal_solver(method)
            @test degrees_of_freedom(7, method) == 14
        end

        @test StenoticHemodynamics.method_family(DGMethod(2)) == :discontinuous_galerkin
        @test !StenoticHemodynamics.requires_fixed_timestep(FVMUSCLMethod())
        @test StenoticHemodynamics.requires_fixed_timestep(FVLaxWendroffMethod())
        @test !StenoticHemodynamics.requires_native_modal_solver(DGMethod(0))
        @test StenoticHemodynamics.requires_native_modal_solver(DGMethod(1))
        @test degrees_of_freedom(7, DGMethod(3)) == 56
    end

    @testset "backend support traits" begin
        native = NativeRK3Backend()
        sciml = SciMLTimeBackend()

        @test StenoticHemodynamics.supports_backend(FVMUSCLMethod(), native)
        @test StenoticHemodynamics.supports_backend(FVMUSCLMethod(), sciml)
        @test !StenoticHemodynamics.supports_backend(FVLaxWendroffMethod(), sciml)
        @test StenoticHemodynamics.supports_backend(DGMethod(0), sciml)
        @test !StenoticHemodynamics.supports_backend(DGMethod(1), sciml)

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
        limiter = StenoticHemodynamics.VanLeerLimiter()
        @test limiter_name(limiter) == "van-leer"
        @test StenoticHemodynamics.limited_slope([1.0, 2.0, 4.0], 2, limiter) ≈ 4.0 / 3.0
        @test StenoticHemodynamics.limited_slope([1.0, 2.0, 1.0], 2, limiter) == 0.0

        for method in (FVMUSCLMethod(limiter), FVLaxWendroffMethod(limiter))
            params = Params(nx=8, tfinal=1.0e-5, severity=30.0, space=method, initial_condition=GeometryRestIC())
            result = simulate(params, NativeRK3Backend(); progress_every=0)
            assert_finite_positive_state(result, params)
            @test occursin("van-leer", spatial_method_name(method))
        end
    end

    @testset "workflow protocol helpers" begin
        mktempdir() do dir
            severity_spec = StenoticHemodynamics.SeveritySweepSpec(
                base_params=Params(nx=8, tfinal=1.0e-5, initial_condition=GeometryRestIC()),
                severities=[23.0],
                summary_csv=joinpath(dir, "severity.csv"),
                parallel_workers=0,
            )
            @test severity_spec isa StenoticHemodynamics.AbstractStudySpec
            @test StenoticHemodynamics.workflow_kind(severity_spec) == "severity_sweep"
            @test StenoticHemodynamics.default_output_paths(severity_spec).summary_csv == joinpath(dir, "severity.csv")
            @test StenoticHemodynamics.validate_workflow_spec(severity_spec) === severity_spec
            default_severity_spec = StenoticHemodynamics.SeveritySweepSpec(
                base_params=Params(nx=8, tfinal=1.0e-5, initial_condition=GeometryRestIC()),
                severities=[23.0],
                parallel_workers=0,
            )
            @test dirname(StenoticHemodynamics.study_summary_path(default_severity_spec)) ==
                  joinpath(StenoticHemodynamics.DEFAULT_SIMULATION_OUTPUT_ROOT, "studies")

            default_grid_spec = StenoticHemodynamics.GridConvergenceStudySpec(
                base_params=Params(nx=8, tfinal=1.0e-5, initial_condition=GeometryRestIC()),
                nxs=[8, 16],
                parallel_workers=0,
            )
            @test dirname(StenoticHemodynamics.study_summary_path(default_grid_spec)) ==
                  joinpath(StenoticHemodynamics.DEFAULT_SIMULATION_OUTPUT_ROOT, "studies")

            refinement_spec = StenoticHemodynamics.RefinementStudySpec(
                base_params=Params(nx=8, tfinal=1.0e-5, initial_condition=GeometryRestIC()),
                nxs=[8, 16],
                degrees=[0, 1],
                output_dir=joinpath(dir, "refinement"),
                parallel_workers=0,
            )
            refinement_paths = StenoticHemodynamics.default_output_paths(refinement_spec)
            @test StenoticHemodynamics.workflow_kind(refinement_spec) == "refinement"
            @test basename.(refinement_paths.csv_paths) == ["h_refinement.csv", "p_refinement.csv"]

            case_spec = StenoticHemodynamics.Resolved3DCaseSpec("77", 23.0, joinpath(dir, "velocity.xdmf"); target_time=5.0e-5)
            comparison_spec = StenoticHemodynamics.ComparisonSpec(
                cases=[case_spec],
                base_params=Params(nx=8, tfinal=5.0e-5, initial_condition=GeometryRestIC()),
                output_dir=joinpath(dir, "comparison"),
                section_count=3,
                profile_slices=[0.0],
                radial_bins=3,
                write_svg=true,
            )
            comparison_paths = StenoticHemodynamics.default_output_paths(comparison_spec)
            @test comparison_spec isa StenoticHemodynamics.AbstractStudySpec
            @test StenoticHemodynamics.workflow_kind(comparison_spec) == "resolved3d_comparison"
            @test basename(comparison_paths.summary_csv) == "comparison_summary.csv"
            @test basename(comparison_paths.overlay_svg) == "section_quadrature_overlay.svg"

            operator_spec = StenoticHemodynamics.OperatorValidationSpec(output_dir=joinpath(dir, "operator-validation"))
            operator_paths = StenoticHemodynamics.default_output_paths(operator_spec)
            @test operator_spec isa StenoticHemodynamics.AbstractStudySpec
            @test StenoticHemodynamics.workflow_kind(operator_spec) == "cross_section_operator_validation"
            @test basename(operator_paths.summary_csv) == "cross_section_operator_validation.csv"
            @test basename(operator_paths.summary_tex) == "cross_section_operator_validation.tex"

            benchmark_spec = StenoticHemodynamics.PackageBenchmarkSpec(output_dir=joinpath(dir, "benchmark"))
            benchmark_paths = StenoticHemodynamics.default_output_paths(benchmark_spec)
            @test benchmark_spec isa StenoticHemodynamics.AbstractStudySpec
            @test StenoticHemodynamics.workflow_kind(benchmark_spec) == "package_benchmark"
            @test basename(benchmark_paths.case_results) == "case_results.csv"
            @test basename(benchmark_paths.manifest) == "manifest.json"
        end
    end

    @testset "CLI extension hooks" begin
        params, output, backend = StenoticHemodynamics.parse_args([
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
        @test params.space.limiter isa StenoticHemodynamics.VanLeerLimiter
        @test output.write_svg == false
        @test backend isa NativeRK3Backend
        @test spatial_method_name(params.space) == "fv-muscl-van-leer"

        handlers = StenoticHemodynamics.CLI_COMMAND_HANDLERS
        @test Set(keys(handlers)) == Set([
            "simulate",
            "openbf-run",
            "study",
            "stokes",
            "verify",
            "compare-3d",
            "operator-validation",
            "benchmark",
            "export-assets",
        ])
        @test handlers["simulate"] === StenoticHemodynamics.run_simulate_cli
        @test_throws ArgumentError StenoticHemodynamics.run_cli(["--tfinal", "1e-5"])
        @test_throws ArgumentError StenoticHemodynamics.run_cli(["not-a-command"])
    end
end
