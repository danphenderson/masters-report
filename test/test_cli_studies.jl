@testset "StenosisHemodynamics CLI parsing" begin
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
            "--model", "classical-1d-no-slip",
            "--velocity-profile", "parabolic",
            "--tfinal", "5e-5",
            "--nx", "8",
            "--progress-every", "0",
            "--no-svg",
            "--ic", "geometry-rest",
        ])
        @test classical_params.model isa ClassicalNoSlip1DModel
        @test model_name(classical_params) == "classical-1d-no-slip"
        @test variable_radius_terms_enabled(classical_params) == false
        @test classical_params.velocity_profile isa ParabolicVelocityProfile
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
        @test_throws ArgumentError parse_args(["--model", "classical-1d-no-slip", "--velocity-profile", "flat", "--ic", "geometry-rest"])
        @test_throws ArgumentError parse_args(["--model", "classical-1d-no-slip", "--alpha", "1.1", "--ic", "geometry-rest"])
    end
end

@testset "StenosisHemodynamics CLI command dispatch" begin
    help_text = read(`$(joinpath(pwd(), "scripts", "stenosis-hemodynamics")) --help`, String)
    @test occursin("simulate", help_text)
    @test occursin("benchmark", help_text)

    mktempdir() do dir
        csv_path = joinpath(dir, "simulate.csv")
        result = run_cli([
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
    end

    mktempdir() do dir
        csv_path = joinpath(dir, "classical.csv")
        result = run_cli([
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
        @test occursin("classical-1d-no-slip,false,canic-koiter-thin-membrane", rows[2])
        @test_throws ArgumentError run_cli([
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
        result = run_cli(["openbf-run", "--config", config_path])
        @test result isa SimulationResult
        @test isfile(joinpath(dir, "out", "cli_openbf.csv"))
    end

    mktempdir() do dir
        result = run_cli(["compare-3d", "--data-root", joinpath(dir, "missing"), "--output-dir", joinpath(dir, "out"), "--overwrite"])
        @test result === nothing
    end

    mktempdir() do dir
        result = run_cli(["benchmark", "--profile", "smoke", "--output-dir", dir, "--overwrite"])
        @test result isa PackageBenchmarkResult
        @test isfile(joinpath(dir, "manifest.json"))
    end
end

@testset "StenosisHemodynamics study output provenance" begin
    parabolic_spec = SeveritySweepSpec(
        base_params=Params(nx=8, tfinal=1.0e-5, initial_condition=GeometryRestIC()),
        severities=[23.0, 50.0],
        progress_every=0,
        parallel_workers=1,
    )
    legacy_power_spec = SeveritySweepSpec(
        base_params=Params(nx=8, tfinal=1.0e-5, initial_condition=GeometryRestIC(), alpha=1.1),
        severities=[23.0, 50.0],
        progress_every=0,
        parallel_workers=1,
    )
    flat_grid_spec = GridConvergenceStudySpec(
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
        flat_spec = SeveritySweepSpec(
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
        flat_result = run_study(flat_spec)
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

        power_spec = GridConvergenceStudySpec(
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
        power_result = run_study(power_spec)
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

@testset "StenosisHemodynamics process-parallel studies" begin
    mktempdir() do dir
        spec = SeveritySweepSpec(
            base_params=Params(nx=8, tfinal=1.0e-5, initial_condition=GeometryRestIC()),
            severities=[23.0, 50.0],
            summary_csv=joinpath(dir, "parallel_severity.csv"),
            overwrite=true,
            progress_every=0,
            parallel_workers=2,
        )
        result = run_study(spec)

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

@testset "StenosisHemodynamics stationary Stokes refinement study" begin
    mktempdir() do dir
        base_params = Params(nx=4, tfinal=0.0, severity=0.0, initial_condition=GeometryRestIC())
        spec = StationaryStokesRefinementSpec(
            base_params=base_params,
            severities=[0.0],
            meshes=[(2, 2, 8), (3, 2, 8), (0, 2, 8)],
            output_dir=dir,
            overwrite=true,
            parallel_workers=1,
        )
        result = run_stationary_stokes_refinement(spec)

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

@testset "StenosisHemodynamics refinement studies" begin
    mktempdir() do dir
        @test SeveritySweepSpec(severities=[23.0]).base_params.initial_condition isa GeometryRestIC
        @test GridConvergenceStudySpec(nxs=[8, 16]).base_params.initial_condition isa GeometryRestIC
        @test RefinementStudySpec().base_params.initial_condition isa GeometryRestIC

        spec = RefinementStudySpec(
            base_params=Params(nx=8, tfinal=1.0e-5, severity=30.0, initial_condition=GeometryRestIC()),
            nxs=[8, 16],
            degrees=[0, 1, 2],
            h_methods=AbstractSpatialMethod[FVMUSCLMethod()],
            output_dir=dir,
            overwrite=true,
            progress_every=0,
            parallel_workers=1,
        )
        result = run_refinement_study(spec)

        @test length(result.h_rows) == 2
        @test length(result.p_rows) == 6
        @test all(isfile, result.csv_paths)
        @test all(isfile, result.tex_paths)
        @test occursin("error_A_l2", read(result.csv_paths[1], String))
        @test occursin("\\begin{table}", read(result.tex_paths[1], String))
        @test all(row.expected_order == row.degree + 1 for row in result.p_rows if row.degree >= 0)
    end
end
