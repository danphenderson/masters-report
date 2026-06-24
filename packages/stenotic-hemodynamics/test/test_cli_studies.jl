isdefined(@__MODULE__, :read_simple_csv) || include("test_helpers.jl")

const parse_args = StenoticHemodynamics.parse_args
const study_summary_path = StenoticHemodynamics.study_summary_path

@testset "StenoticHemodynamics CLI parsing" begin
    @test parse_args(["--help"]) === nothing

    @testset "native defaults" begin
        params, output, backend = parse_args([
            "--tfinal", "5e-5",
            "--nx", "8",
            "--progress-every", "0",
            "--no-svg",
            "--ic-pressure-drop-pa", "40",
        ])

        @test params.tfinal == 5.0e-5
        @test params.nx == 8
        @test params.space isa FVMUSCLMethod
        @test params.time_stepper isa SSPRK3Stepper
        @test params.rheology isa NewtonianRheology
        @test params.velocity_profile isa ParabolicVelocityProfile
        @test params.model isa CanicExtendedOneDModel
        @test model_name(params) == "canic-extended-1d"
        @test params.alpha ≈ 4.0 / 3.0
        @test params.initial_condition isa StationaryStokesIC
        @test params.initial_condition.pressure_drop_dyn_cm2 == 400.0
        @test output.progress_every == 0
        @test output.write_svg == false
        @test output.overwrite == false
        @test backend isa NativeRK3Backend
    end

    @testset "rheology flags" begin
        params, output, backend = parse_args([
            "--rheology", "carreau-yasuda",
            "--eta0", "0.2",
            "--eta-inf", "0.03",
            "--lambda-s", "1.5",
            "--yasuda-a", "1.25",
            "--flow-index", "0.6",
            "--shear-floor", "1e-6",
            "--min-eta", "0.02",
            "--max-eta", "0.4",
            "--nu", "0.05",
            "--tfinal", "5e-5",
            "--nx", "8",
            "--progress-every", "0",
            "--no-svg",
            "--ic", "geometry-rest",
        ])

        @test output.write_svg == false
        @test backend isa NativeRK3Backend
        @test params.nu == 0.05
        @test params.rheology isa CarreauYasudaRheology
        @test params.rheology.eta0 == 0.2
        @test params.rheology.eta_inf == 0.03
        @test params.rheology.lambda_s == 1.5
        @test params.rheology.a == 1.25
        @test params.rheology.n == 0.6
        @test params.rheology.shear_rate_floor == 1.0e-6
        @test params.rheology.min_eta == 0.02
        @test params.rheology.max_eta == 0.4
    end

    @testset "spatial and time-stepper flags" begin
        params, _, backend = parse_args([
            "--space", "dg",
            "--degree", "2",
            "--time-stepper", "ssprk2",
            "--limiter", "minmod",
            "--tfinal", "5e-5",
            "--nx", "8",
            "--progress-every", "0",
            "--no-svg",
            "--ic", "geometry-rest",
        ])

        @test params.space isa DGMethod
        @test params.space.degree == 2
        @test params.time_stepper isa SSPRK2Stepper
        @test backend isa NativeRK3Backend

        weno_params, _, weno_backend = parse_args([
            "--space", "fv-weno3",
            "--time-stepper", "ssprk54",
            "--tfinal", "5e-5",
            "--nx", "8",
            "--progress-every", "0",
            "--no-svg",
            "--ic", "geometry-rest",
        ])

        @test weno_params.space isa FVWENO3Method
        @test weno_params.time_stepper isa SSPRK54Stepper
        @test weno_backend isa NativeRK3Backend
    end

    @testset "velocity profile flags" begin
        flat_params, _, _ = parse_args([
            "--velocity-profile", "flat",
            "--profile-shear-factor", "4",
            "--tfinal", "5e-5",
            "--nx", "8",
            "--progress-every", "0",
            "--no-svg",
            "--ic", "geometry-rest",
        ])
        @test flat_params.velocity_profile isa FlatVelocityProfile
        @test flat_params.alpha ≈ 1.0
        @test shear_rate_factor(flat_params.velocity_profile) ≈ 4.0

        power_params, _, _ = parse_args([
            "--velocity-profile", "power",
            "--profile-exponent", "9",
            "--tfinal", "5e-5",
            "--nx", "8",
            "--progress-every", "0",
            "--no-svg",
            "--ic", "geometry-rest",
        ])
        @test power_params.velocity_profile isa PowerVelocityProfile
        @test power_params.velocity_profile.exponent ≈ 9.0
        @test power_params.alpha ≈ 1.1

        alpha_params, _, _ = parse_args([
            "--alpha", "1.1",
            "--tfinal", "5e-5",
            "--nx", "8",
            "--progress-every", "0",
            "--no-svg",
            "--ic", "geometry-rest",
        ])
        @test alpha_params.velocity_profile isa PowerVelocityProfile
        @test alpha_params.velocity_profile.exponent ≈ 9.0
        @test alpha_params.alpha ≈ power_params.alpha
    end

    @testset "forward model flags" begin
        classical_params, _, _ = parse_args([
            "--model", "classical-parabolic-1d",
            "--velocity-profile", "parabolic",
            "--tfinal", "5e-5",
            "--nx", "8",
            "--progress-every", "0",
            "--no-svg",
            "--ic", "geometry-rest",
        ])
        @test classical_params.model isa ClassicalParabolicOneDModel
        @test classical_params.model isa ClassicalNoSlip1DModel
        @test model_name(classical_params) == "classical-parabolic-1d"
        @test variable_radius_terms_enabled(classical_params) == false
        @test classical_params.velocity_profile isa ParabolicVelocityProfile

        legacy_classical_params, _, _ = parse_args([
            "--model", "classical-1d-no-slip",
            "--velocity-profile", "parabolic",
            "--tfinal", "5e-5",
            "--nx", "8",
            "--progress-every", "0",
            "--no-svg",
            "--ic", "geometry-rest",
        ])
        @test legacy_classical_params.model isa ClassicalParabolicOneDModel
        @test model_name(legacy_classical_params) == "classical-parabolic-1d"
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
            "--ic", "geometry-rest",
        ])

        @test params.tfinal == 5.0e-5
        @test output.write_svg == false
        @test backend isa SciMLTimeBackend
        @test backend.solve.algorithm isa Tsit5Policy
        @test backend.solve.abstol == 1.0e-8
        @test backend.solve.reltol == 1.0e-7
        @test backend.solve.save_everystep == true
        @test backend.solve.maxiters == 123

        vern7_params, _, vern7_backend = parse_args([
            "--backend", "sciml",
            "--alg", "vern7",
            "--tfinal", "5e-5",
            "--nx", "8",
            "--progress-every", "0",
            "--no-svg",
            "--ic", "geometry-rest",
        ])
        @test vern7_params.tfinal == 5.0e-5
        @test vern7_backend isa SciMLTimeBackend
        @test vern7_backend.solve.algorithm isa Vern7Policy

        vern9_params, _, vern9_backend = parse_args([
            "--backend", "sciml",
            "--alg", "vern9",
            "--tfinal", "5e-5",
            "--nx", "8",
            "--progress-every", "0",
            "--no-svg",
            "--ic", "geometry-rest",
        ])
        @test vern9_params.tfinal == 5.0e-5
        @test vern9_backend isa SciMLTimeBackend
        @test vern9_backend.solve.algorithm isa Vern9Policy
    end

    @testset "invalid combinations" begin
        @test_throws ArgumentError parse_args(["--backend", "native", "--alg", "tsit5"])
        @test_throws ArgumentError parse_args(["--tfinal", "5e-5", "--nx", "8"])
        @test_throws ArgumentError parse_args(["--ic-pressure-drop-pa", "40", "--ic-pressure-drop-dyn-cm2", "400"])
        @test_throws ArgumentError parse_args(["--ic", "geometry-rest", "--ic-pressure-drop-pa", "40"])
        @test_throws ArgumentError parse_args(["--backend", "sciml", "--alg", "ssprk"])
        @test_throws ArgumentError parse_args(["--abstol", "1e-8"])
        @test_throws ArgumentError parse_args(["--backend", "sciml", "--alg", "not-a-policy"])
        @test_throws ArgumentError parse_args(["--eta0", "0.2"])
        @test_throws ArgumentError parse_args(["--rheology", "casson", "--eta0", "0.2"])
        @test_throws ArgumentError parse_args(["--rheology", "not-a-model"])
        @test_throws ArgumentError parse_args(["--space", "fv-muscl", "--degree", "1"])
        @test_throws ArgumentError parse_args(["--limiter", "not-a-limiter"])
        @test_throws ArgumentError parse_args(["--time-stepper", "rk4"])
        @test_throws ArgumentError parse_args(["--velocity-profile", "power", "--ic", "geometry-rest"])
        @test_throws ArgumentError parse_args(["--velocity-profile", "flat", "--profile-shear-factor", "0", "--ic", "geometry-rest"])
        @test_throws ArgumentError parse_args(["--velocity-profile", "parabolic", "--profile-shear-factor", "4", "--ic", "geometry-rest"])
        @test_throws ArgumentError parse_args(["--alpha", "1.1", "--velocity-profile", "power", "--profile-exponent", "9", "--ic", "geometry-rest"])
        @test_throws ArgumentError parse_args(["--model", "classical-parabolic-1d", "--velocity-profile", "flat", "--ic", "geometry-rest"])
        @test_throws ArgumentError parse_args(["--model", "classical-1d-no-slip", "--velocity-profile", "flat", "--ic", "geometry-rest"])
        @test_throws ArgumentError parse_args(["--model", "classical-parabolic-1d", "--alpha", "1.1", "--ic", "geometry-rest"])
        @test_throws ArgumentError parse_args(["--model", "classical-1d-no-slip", "--alpha", "1.1", "--ic", "geometry-rest"])
    end
end

@testset "StenoticHemodynamics CLI command dispatch" begin
    help_text = read(`$(joinpath(pwd(), "packages", "stenotic-hemodynamics", "bin", "stenotic-hemodynamics")) --help`, String)
    @test occursin("simulate", help_text)
    @test occursin("benchmark", help_text)
    @test occursin("fsi", help_text)
    @test occursin("operator-validation", help_text)

    mktempdir() do dir
        csv_path = joinpath(dir, "simulate.csv")
        result = StenoticHemodynamics.run_cli([
            "simulate",
            "--ic", "geometry-rest",
            "--tfinal", "1e-5",
            "--nx", "8",
            "--progress-every", "0",
            "--no-svg",
            "--output", csv_path,
        ])
        @test result isa SimulationResult
        @test isfile(csv_path)
        @test occursin("model,variable_radius_terms,wall_law", first(readlines(csv_path)))
        @test_throws ArgumentError StenoticHemodynamics.run_cli([
            "simulate",
            "--ic", "geometry-rest",
            "--tfinal", "1e-5",
            "--nx", "8",
            "--progress-every", "0",
            "--no-svg",
            "--output", csv_path,
        ])
        overwritten = StenoticHemodynamics.run_cli([
            "simulate",
            "--ic", "geometry-rest",
            "--tfinal", "1e-5",
            "--nx", "8",
            "--progress-every", "0",
            "--no-svg",
            "--output", csv_path,
            "--overwrite",
        ])
        @test overwritten isa SimulationResult
    end

    mktempdir() do dir
        csv_path = joinpath(dir, "classical.csv")
        result = StenoticHemodynamics.run_cli([
            "simulate",
            "--model", "classical-1d-no-slip",
            "--velocity-profile", "parabolic",
            "--ic", "geometry-rest",
            "--tfinal", "1e-5",
            "--nx", "8",
            "--progress-every", "0",
            "--no-svg",
            "--output", csv_path,
        ])
        @test result isa SimulationResult
        rows = readlines(csv_path)
        @test occursin("classical-parabolic-1d,false,canic-koiter-thin-membrane", rows[2])
        @test_throws ArgumentError StenoticHemodynamics.run_cli([
            "simulate",
            "--model", "classical-1d-no-slip",
            "--velocity-profile", "flat",
            "--ic", "geometry-rest",
            "--tfinal", "1e-5",
            "--nx", "8",
            "--progress-every", "0",
            "--no-svg",
            "--output", joinpath(dir, "bad.csv"),
        ])
    end

    mktempdir() do dir
        config_path, _ = write_openbf_fixture(dir; project_name="cli_openbf")
        result = StenoticHemodynamics.run_cli(["openbf-run", "--config", config_path])
        @test result isa SimulationResult
        @test isfile(joinpath(dir, "out", "cli_openbf.csv"))
    end

    mktempdir() do dir
        result = StenoticHemodynamics.run_cli([
            "study",
            "severity",
            "--output-dir",
            dir,
            "--summary-csv",
            joinpath(dir, "severity.csv"),
            "--severities",
            "23,40",
            "--nx",
            "8",
            "--tfinal",
            "1e-5",
            "--dt",
            "1e-5",
            "--progress-every",
            "0",
            "--no-svg",
            "--overwrite",
            "--parallel-workers",
            "0",
        ])
        @test result isa StenoticHemodynamics.StudyResult
        @test result.study_kind == "severity_sweep"
        @test isfile(result.summary_csv)
        @test length(result.summaries) == 2
    end

    mktempdir() do dir
        result = StenoticHemodynamics.run_cli([
            "study",
            "grid",
            "--output-dir",
            dir,
            "--summary-csv",
            joinpath(dir, "grid.csv"),
            "--nxs",
            "6,8",
            "--severity",
            "23",
            "--tfinal",
            "1e-5",
            "--dt",
            "1e-5",
            "--progress-every",
            "0",
            "--no-svg",
            "--overwrite",
            "--parallel-workers",
            "0",
        ])
        @test result isa StenoticHemodynamics.StudyResult
        @test result.study_kind == "grid_convergence"
        @test isfile(result.summary_csv)
        @test sort([row.nx for row in result.summaries]) == [6, 8]
    end

    mktempdir() do dir
        result = StenoticHemodynamics.run_cli([
            "study",
            "refinement",
            "--output-dir",
            dir,
            "--nxs",
            "6,8",
            "--degrees",
            "0",
            "--tfinal",
            "1e-5",
            "--dt",
            "1e-5",
            "--progress-every",
            "0",
            "--no-svg",
            "--overwrite",
            "--parallel-workers",
            "0",
        ])
        @test result isa StenoticHemodynamics.RefinementStudyResult
        @test all(isfile, result.csv_paths)
        @test all(isfile, result.tex_paths)
        @test !isempty(result.h_rows)
        @test !isempty(result.p_rows)
    end

    mktempdir() do dir
        result = StenoticHemodynamics.run_cli([
            "stokes",
            "refine",
            "--output-dir",
            dir,
            "--nx",
            "8",
            "--severities",
            "23",
            "--meshes",
            "4x1x4",
            "--overwrite",
            "--parallel-workers",
            "0",
        ])
        @test result isa StenoticHemodynamics.StationaryStokesRefinementResult
        @test isfile(result.summary_csv)
        @test only(result.rows).status == "ok"
    end

    mktempdir() do dir
        result = StenoticHemodynamics.run_cli(["compare-3d", "--data-root", joinpath(dir, "missing"), "--output-dir", joinpath(dir, "out"), "--overwrite"])
        @test result === nothing
    end

    mktempdir() do dir
        result = StenoticHemodynamics.run_cli([
            "operator-validation",
            "--output-dir",
            dir,
            "--sample-z",
            "0.25,0.5",
            "--plane-center",
            "0.5",
            "--plane-shifts",
            "-0.02,0,0.02",
            "--overwrite",
        ])
        @test result isa StenoticHemodynamics.OperatorValidationResult
        @test length(result.rows) == 7
        @test isfile(result.summary_csv)
        @test isfile(result.summary_tex)
        @test all(row -> row.status == "pass", result.rows)
    end

    mktempdir() do dir
        result = StenoticHemodynamics.run_cli([
            "fsi",
            "validate",
            "--wall-mode",
            "dynamic",
            "--wall-tfinal",
            "3e-5",
            "--severities",
            "23",
            "--meshes",
            "4x1x4",
            "--output-dir",
            dir,
            "--overwrite",
            "--parallel-workers",
            "0",
        ])
        @test result isa StenoticHemodynamics.MembraneFSIValidationResult
        @test only(result.rows).status == "ok"
        @test only(result.rows).time_step_count == 3
        @test isfile(result.summary_csv)
        @test isfile(result.summary_tex)
        @test isfile(result.manifest_json)
        @test isfile(only(result.rows).profile_csv)
        @test isfile(only(result.rows).history_csv)
    end

    mktempdir() do dir
        data_root = joinpath(dir, "resolved")
        write_synthetic_xdmf_hdf5_case(joinpath(data_root, "77"); time=5.0e-5)
        output_dir = joinpath(dir, "comparison")
        result = StenoticHemodynamics.run_cli([
            "compare-3d",
            "--data-root",
            data_root,
            "--output-dir",
            output_dir,
            "--target-time",
            "5e-5",
            "--time-atol",
            "0",
            "--nx",
            "8",
            "--section-count",
            "3",
            "--radial-bins",
            "3",
            "--profile-slices",
            "0",
            "--progress-every",
            "0",
            "--no-svg",
            "--overwrite",
        ])
        @test result isa StenoticHemodynamics.ComparisonResult
        row = only(read_simple_csv(result.summary_csv))
        @test row["case_label"] == "77"
        @test row["model"] == "canic-extended-1d"
        @test row["nx"] == "8"
        @test row["initial_condition"] == "geometry-rest"
        @test row["backend"] == "native"
        @test row["run_status"] == "ok"
        @test parse(Float64, row["target_time_s"]) ≈ 5.0e-5
        @test parse(Float64, row["time_atol_s"]) ≈ 0.0
        @test parse(Float64, row["xdmf_time_s"]) ≈ 5.0e-5
    end

    mktempdir() do dir
        data_root = joinpath(dir, "resolved")
        write_synthetic_xdmf_hdf5_case(joinpath(data_root, "77"); time=5.0e-5)
        output_dir = joinpath(dir, "grid-comparison")
        result = StenoticHemodynamics.run_cli([
            "compare-3d",
            "--data-root",
            data_root,
            "--output-dir",
            output_dir,
            "--target-time",
            "5e-5",
            "--time-atol",
            "0",
            "--nxs",
            "6,8",
            "--section-count",
            "3",
            "--radial-bins",
            "3",
            "--profile-slices",
            "0",
            "--progress-every",
            "0",
            "--no-svg",
            "--overwrite",
        ])
        @test result isa StenoticHemodynamics.GridSensitivityResult
        @test isfile(result.summary_csv)
        @test isfile(result.summary_tex)
        rows = sort(read_simple_csv(result.summary_csv); by=row -> parse(Int, row["nx"]))
        @test [parse(Int, row["nx"]) for row in rows] == [6, 8]
        @test parse(Int, rows[2]["adjacent_from_nx"]) == 6
        @test isfinite(parse(Float64, rows[2]["adjacent_rms_velocity_difference_cm_s"]))
        @test all(isfile(joinpath(output_dir, "nx$(row["nx"])", "comparison_summary.csv")) for row in rows)

        reused_output_dir = joinpath(dir, "grid-comparison-reused")
        reused = StenoticHemodynamics.run_cli([
            "compare-3d",
            "--output-dir",
            reused_output_dir,
            "--nxs",
            "6,8",
            "--reuse-grid-summary",
            result.summary_csv,
            "--grid-summary-csv",
            joinpath(reused_output_dir, "selected_summary.csv"),
            "--grid-summary-tex",
            joinpath(reused_output_dir, "selected_summary.tex"),
            "--overwrite",
        ])
        @test reused isa StenoticHemodynamics.GridSensitivityResult
        @test isfile(reused.summary_csv)
        @test isfile(reused.summary_tex)
        reused_rows = read_simple_csv(reused.summary_csv)
        @test [row["nx"] for row in reused_rows] == ["6", "8"]
    end

    mktempdir() do dir
        result = StenoticHemodynamics.run_cli(["benchmark", "--profile", "smoke", "--output-dir", dir, "--overwrite"])
        @test result isa StenoticHemodynamics.PackageBenchmarkResult
        @test isfile(joinpath(dir, "manifest.json"))
    end

    @test StenoticHemodynamics.CLI_COMMAND_HANDLERS["export-assets"] === StenoticHemodynamics.run_export_assets_cli
    @test StenoticHemodynamics.run_cli(["export-assets", "--help"]) === nothing
    @test_throws ArgumentError StenoticHemodynamics.run_cli(["export-assets", "--z-samples", "2"])

    mktempdir() do dir
        output_dir = joinpath(dir, "exports")
        missing_root = joinpath(dir, "missing-resolved3d")
        expected_paths = [
            joinpath(output_dir, "analytic_summary.csv"),
            joinpath(output_dir, "analytic_radius_profiles.csv"),
            joinpath(output_dir, "analytic_surface_sev0.csv"),
            joinpath(output_dir, "analytic_surface_sev23.csv"),
            joinpath(output_dir, "analytic_surface_sev40.csv"),
            joinpath(output_dir, "analytic_surface_sev50.csv"),
            joinpath(output_dir, "analytic_surface_sev73.csv"),
            joinpath(output_dir, "analytic_cross_sections.csv"),
            joinpath(output_dir, "mesh_view_manifest.csv"),
            joinpath(output_dir, "fem_mesh_view_sev50.csv"),
            joinpath(output_dir, "fvm_mesh_view_sev50.csv"),
            joinpath(output_dir, "stokes_particle_trajectories.csv"),
            joinpath(output_dir, "stokes_particle_trajectories_manifest.csv"),
            joinpath(output_dir, "resolved_velocity_nodes_manifest.csv"),
            joinpath(output_dir, "resolved_envelope_manifest.csv"),
        ]
        captured = Ref{Union{Nothing, StenoticHemodynamics.GeometryExportOptions}}(nothing)
        original_handler = StenoticHemodynamics.CLI_COMMAND_HANDLERS["export-assets"]
        StenoticHemodynamics.CLI_COMMAND_HANDLERS["export-assets"] = args -> begin
            opts = StenoticHemodynamics.parse_export_args(args)
            opts === nothing && return nothing
            captured[] = opts
            for path in expected_paths
                mkpath(dirname(path))
                write(path, "stub\n")
            end
            return expected_paths
        end
        try
            result = StenoticHemodynamics.run_cli([
                "export-assets",
                "--output-dir",
                output_dir,
                "--data-root",
                missing_root,
                "--z-samples",
                "3",
                "--theta-samples",
                "12",
                "--overwrite",
            ])
            @test result == expected_paths
            @test all(isfile, expected_paths)
            @test captured[] isa StenoticHemodynamics.GeometryExportOptions
            @test captured[].output_dir == output_dir
            @test captured[].data_root == missing_root
            @test captured[].z_samples == 3
            @test captured[].theta_samples == 12
            @test captured[].overwrite == true
        finally
            StenoticHemodynamics.CLI_COMMAND_HANDLERS["export-assets"] = original_handler
        end
    end

    mktempdir() do dir
        zero_dir = joinpath(dir, "rest-zero")
        result = StenoticHemodynamics.run_cli([
            "verify",
            "rest",
            "--output-dir",
            zero_dir,
            "--severities",
            "23",
            "--nxs",
            "8",
            "--elapsed-times",
            "0,1e-5",
            "--progress-every",
            "0",
            "--overwrite",
        ])
        @test result isa StenoticHemodynamics.RestStateDriftResult
        @test result.spec.base_params.inlet_umax ≈ 0.0
        @test isfile(result.profile_csv)
        @test isfile(result.residual_csv)
        @test isfile(result.residual_tex)
        row = only(csv_row for csv_row in read_simple_csv(result.summary_csv) if csv_row["requested_time_s"] != "0.0")
        @test parse(Float64, row["requested_q_in"]) ≈ 0.0
        @test parse(Float64, row["applied_q_in"]) ≈ 0.0

        production_dir = joinpath(dir, "rest-production-inlet")
        production_result = StenoticHemodynamics.run_cli([
            "verify",
            "rest",
            "--output-dir",
            production_dir,
            "--severities",
            "23",
            "--nxs",
            "8",
            "--elapsed-times",
            "1e-5",
            "--inlet-umax",
            "45",
            "--progress-every",
            "0",
            "--overwrite",
        ])
        production_row = only(read_simple_csv(production_result.summary_csv))
        @test parse(Float64, production_row["requested_q_in"]) > 0.7
        @test parse(Float64, production_row["applied_q_in"]) > 0.7
    end
end

@testset "StenoticHemodynamics study output provenance" begin
    parabolic_spec = StenoticHemodynamics.SeveritySweepSpec(
        base_params=Params(nx=8, tfinal=1.0e-5, initial_condition=GeometryRestIC()),
        severities=[23.0, 50.0],
        progress_every=0,
        parallel_workers=1,
    )
    legacy_power_spec = StenoticHemodynamics.SeveritySweepSpec(
        base_params=Params(nx=8, tfinal=1.0e-5, initial_condition=GeometryRestIC(), alpha=1.1),
        severities=[23.0, 50.0],
        progress_every=0,
        parallel_workers=1,
    )
    flat_grid_spec = StenoticHemodynamics.GridConvergenceStudySpec(
        base_params=Params(
            nx=8,
            tfinal=1.0e-5,
            severity=50.0,
            initial_condition=GeometryRestIC(),
            velocity_profile=FlatVelocityProfile(shear_rate_factor=8.0),
        ),
        nxs=[8, 16],
        progress_every=0,
        parallel_workers=1,
    )

    @test occursin("_vp_parabolic_", study_summary_path(parabolic_spec))
    @test study_summary_path(parabolic_spec) != study_summary_path(legacy_power_spec)
    @test occursin("_vp_power_g_9_", study_summary_path(legacy_power_spec))
    @test occursin("_vp_flat_sf_8_", study_summary_path(flat_grid_spec))

    mktempdir() do dir
        flat_spec = StenoticHemodynamics.SeveritySweepSpec(
            base_params=Params(
                nx=8,
                tfinal=1.0e-5,
                initial_condition=GeometryRestIC(),
                velocity_profile=FlatVelocityProfile(shear_rate_factor=8.0),
            ),
            severities=[23.0],
            summary_csv=joinpath(dir, "flat.csv"),
            overwrite=true,
            progress_every=0,
            parallel_workers=1,
        )
        flat_result = StenoticHemodynamics.run_study(flat_spec)
        flat_row = only(flat_result.summaries)
        @test flat_row.model == "canic-extended-1d"
        @test flat_row.variable_radius_terms == true
        @test flat_row.wall_law == "canic-koiter-thin-membrane"
        @test flat_row.velocity_profile == "flat"
        @test flat_row.alpha ≈ 1.0
        @test isnan(flat_row.profile_exponent)
        @test flat_row.shear_rate_factor ≈ 8.0
        flat_csv = read(flat_result.summary_csv, String)
        @test occursin("model,variable_radius_terms,wall_law", flat_csv)
        @test occursin("velocity_profile,alpha,profile_exponent,shear_rate_factor", flat_csv)
        flat_csv_row = only(read_simple_csv(flat_result.summary_csv))
        @test flat_csv_row["model"] == "canic-extended-1d"
        @test flat_csv_row["variable_radius_terms"] == "true"
        @test flat_csv_row["wall_law"] == "canic-koiter-thin-membrane"
        @test flat_csv_row["velocity_profile"] == "flat"
        @test parse(Float64, flat_csv_row["alpha"]) ≈ 1.0
        @test isnan(parse(Float64, flat_csv_row["profile_exponent"]))
        @test parse(Float64, flat_csv_row["shear_rate_factor"]) ≈ 8.0

        power_spec = StenoticHemodynamics.GridConvergenceStudySpec(
            base_params=Params(
                nx=8,
                tfinal=1.0e-5,
                severity=50.0,
                initial_condition=GeometryRestIC(),
                velocity_profile=PowerVelocityProfile(exponent=9.0),
            ),
            nxs=[8],
            summary_csv=joinpath(dir, "power.csv"),
            overwrite=true,
            progress_every=0,
            parallel_workers=1,
        )
        power_result = StenoticHemodynamics.run_study(power_spec)
        power_row = only(power_result.summaries)
        @test power_row.velocity_profile == "power"
        @test power_row.alpha ≈ 1.1
        @test power_row.profile_exponent ≈ 9.0
        @test power_row.shear_rate_factor ≈ 11.0
        power_csv_row = only(read_simple_csv(power_result.summary_csv))
        @test power_csv_row["velocity_profile"] == "power"
        @test parse(Float64, power_csv_row["alpha"]) ≈ 1.1
        @test parse(Float64, power_csv_row["profile_exponent"]) ≈ 9.0
        @test parse(Float64, power_csv_row["shear_rate_factor"]) ≈ 11.0
    end
end

@testset "StenoticHemodynamics process-parallel studies" begin
    mktempdir() do dir
        spec = StenoticHemodynamics.SeveritySweepSpec(
            base_params=Params(nx=8, tfinal=1.0e-5, initial_condition=GeometryRestIC()),
            severities=[23.0, 50.0],
            summary_csv=joinpath(dir, "parallel_severity.csv"),
            overwrite=true,
            progress_every=0,
            parallel_workers=2,
        )
        result = StenoticHemodynamics.run_study(spec)

        @test length(result.summaries) == 2
        @test [row.severity for row in result.summaries] == [23.0, 50.0]
        @test all(row.velocity_profile == "parabolic" for row in result.summaries)
        @test all(row.alpha ≈ 4.0 / 3.0 for row in result.summaries)
        @test all(row.profile_exponent ≈ 2.0 for row in result.summaries)
        @test all(row.shear_rate_factor ≈ 4.0 for row in result.summaries)
        @test isfile(result.summary_csv)
        @test occursin("severity_sweep", read(result.summary_csv, String))
    end
end

@testset "StenoticHemodynamics stationary Stokes refinement study" begin
    mktempdir() do dir
        base_params = Params(nx=4, tfinal=0.0, severity=0.0, initial_condition=GeometryRestIC())
        spec = StenoticHemodynamics.StationaryStokesRefinementSpec(
            base_params=base_params,
            severities=[0.0],
            meshes=[(2, 2, 8), (3, 2, 8), (0, 2, 8)],
            output_dir=dir,
            overwrite=true,
            parallel_workers=1,
        )
        result = StenoticHemodynamics.run_stationary_stokes_refinement(spec)

        @test result.summary_csv == joinpath(dir, "summary.csv")
        @test isfile(result.summary_csv)
        @test length(result.rows) == 3
        ok_rows = [row for row in result.rows if row.status == "ok"]
        error_rows = [row for row in result.rows if row.status == "error"]
        @test length(ok_rows) == 2
        @test length(error_rows) == 1
        @test occursin("ic mesh_nz must be positive", only(error_rows).error_message)

        for row in ok_rows
            @test row.velocity_dofs > 0
            @test row.pressure_dofs > 0
            @test row.traction_samples > 0
            @test isfinite(row.wall_traction_mean)
            @test isfinite(row.wall_traction_max)
            @test isfinite(row.wss_mean)
            @test isfinite(row.wss_max)
            @test row.wall_traction_mean >= 0.0
            @test row.wall_traction_max >= row.wall_traction_mean
            @test row.wss_mean >= 0.0
            @test row.wss_max >= row.wss_mean
            @test row.fe_projection_u_l2_relative_error >= 0.0
            @test row.fe_projection_pressure_l2_relative_error >= 0.0
        end

        finest_row = ok_rows[end]
        @test finest_row.finest_u_l2_relative_error == 0.0
        @test finest_row.finest_pressure_l2_relative_error == 0.0

        straight_row = ok_rows[1]
        mu = base_params.rho * base_params.nu
        pressure_drop_dyn_cm2 = spec.pressure_drop_pa * 10.0
        analytic_u = pressure_drop_dyn_cm2 * base_params.rmax^2 / (8.0 * mu * base_params.length_cm)
        @test isapprox(straight_row.projection_uavg_min, analytic_u; rtol=0.05)
        @test isapprox(straight_row.projection_uavg_max, analytic_u; rtol=0.05)

        csv_text = read(result.summary_csv, String)
        @test occursin("wall_traction_mean", csv_text)
        @test occursin("finest_u_l2_relative_error", csv_text)
        csv_rows = read_simple_csv(result.summary_csv)
        @test length(csv_rows) == 3
        @test count(row -> row["status"] == "ok", csv_rows) == 2
        @test count(row -> row["status"] == "error", csv_rows) == 1
        @test parse(Int, csv_rows[1]["traction_samples"]) > 0
        @test parse(Int, only(row for row in csv_rows if row["status"] == "error")["traction_samples"]) == 0
    end
end

@testset "StenoticHemodynamics refinement studies" begin
    mktempdir() do dir
        @test StenoticHemodynamics.SeveritySweepSpec(severities=[23.0]).base_params.initial_condition isa GeometryRestIC
        @test StenoticHemodynamics.GridConvergenceStudySpec(nxs=[8, 16]).base_params.initial_condition isa GeometryRestIC
        @test StenoticHemodynamics.RefinementStudySpec().base_params.initial_condition isa GeometryRestIC

        spec = StenoticHemodynamics.RefinementStudySpec(
            base_params=Params(nx=8, tfinal=1.0e-5, severity=30.0, initial_condition=GeometryRestIC()),
            nxs=[8, 16],
            degrees=[0, 1, 2],
            h_methods=AbstractSpatialMethod[FVMUSCLMethod()],
            output_dir=dir,
            overwrite=true,
            progress_every=0,
            parallel_workers=1,
        )
        result = StenoticHemodynamics.run_refinement_study(spec)

        @test length(result.h_rows) == 2
        @test length(result.p_rows) == 6
        @test all(isfile, result.csv_paths)
        @test all(isfile, result.tex_paths)
        @test occursin("error_A_l2", read(result.csv_paths[1], String))
        @test occursin("\\begin{table}", read(result.tex_paths[1], String))
        @test sort(unique(row.degree for row in result.p_rows)) == [0, 1, 2]
        @test sort(unique(row.nx for row in result.p_rows)) == [8, 16]
        @test all(row -> isfinite(row.error_A_l2) && row.error_A_l2 >= 0.0, result.p_rows)
        @test all(row -> isfinite(row.error_Q_l2) && row.error_Q_l2 >= 0.0, result.p_rows)
        @test any(row -> row.error_A_l2 > 0.0, result.p_rows)
        @test any(row -> row.error_Q_l2 > 0.0, result.p_rows)
        @test all(row.expected_order == row.degree + 1 for row in result.p_rows if row.degree >= 0)
    end
end
