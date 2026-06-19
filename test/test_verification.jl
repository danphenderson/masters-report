struct RestStateFailingBackend <: AbstractTimeBackend end

@testset "StenosisHemodynamics simulation diagnostics and forcing" begin
    params = Params(nx=12, tfinal=1.0e-5, dt=1.0e-5, initial_condition=GeometryRestIC())
    result = simulate(params)
    @test result.diagnostics.dt_max > 0.0
    @test result.diagnostics.cfl_max > 0.0
    @test result.diagnostics.lambda_minus_min < 0.0
    @test result.diagnostics.lambda_plus_max > 0.0
    @test result.diagnostics.subcritical_margin_min > 0.0
    @test result.diagnostics.positivity_projection_count == 0

    mms_params = Params(
        nx=8,
        tfinal=1.0e-5,
        dt=1.0e-5,
        severity=0.0,
        initial_condition=ManufacturedSolutionIC(),
        forcing=ManufacturedForcing(),
    )
    mms_state = StenosisHemodynamics.initial_state_result(mms_params)
    @test length(mms_state.area) == 8
    @test all(isfinite, mms_state.area)
    @test all(isfinite, mms_state.flow)
end

@testset "StenosisHemodynamics verification runners" begin
    mktempdir() do dir
        mms = run_manufactured_verification(ManufacturedVerificationSpec(;
            output_dir=dir,
            nxs=[8, 12],
            dt_values=[2.0e-5, 1.0e-5],
            overwrite=true,
        ))
        @test length(mms.rows) == 4
        @test isfile(mms.summary_csv)
        @test isfile(mms.summary_tex)
        @test all(row.status == "ok" for row in mms.rows)
        @test any(row.study_kind == "spatial" for row in mms.rows)
        @test any(row.study_kind == "temporal" for row in mms.rows)
        @test all(isfinite(row.area_l1_error) for row in mms.rows)
        @test all(isfinite(row.area_linf_error) for row in mms.rows)
        @test all(isfinite(row.flow_l1_error) for row in mms.rows)
        @test all(isfinite(row.flow_linf_error) for row in mms.rows)
        csv_text = read(mms.summary_csv, String)
        @test occursin("area_l1_error", csv_text)
        @test occursin("area_linf_error", csv_text)
        @test occursin("flow_l1_error", csv_text)
        @test occursin("flow_linf_error", csv_text)

        ph_demo = run_ph_refinement_demo(PHRefinementDemoSpec(;
            output_dir=joinpath(dir, "ph-demo"),
            h_nxs=[6, 8],
            h_degree=2,
            degrees=[0, 2, 4],
            p_nx=6,
            base_params=Params(
                nx=6,
                tfinal=1.0e-5,
                dt=1.0e-5,
                severity=0.0,
                initial_condition=ManufacturedSolutionIC(),
                forcing=ManufacturedForcing(),
                space=DGMethod(2),
            ),
            overwrite=true,
        ))
        @test length(ph_demo.rows) == 5
        @test isfile(ph_demo.summary_csv)
        @test isfile(ph_demo.summary_tex)
        @test all(row.status == "ok" for row in ph_demo.rows)
        @test any(row.sweep == "h_refinement" && isfinite(row.flow_l2_observed_order) for row in ph_demo.rows)
        @test any(row.sweep == "p_refinement" && row.degree == 4 for row in ph_demo.rows)
        ph_csv_text = read(ph_demo.summary_csv, String)
        @test occursin("flow_log10_l2_error", ph_csv_text)
        @test occursin("flow_l2_reduction", ph_csv_text)

        cli_demo = run_cli([
            "verify",
            "ph-refinement",
            "--output-dir",
            joinpath(dir, "ph-cli"),
            "--h-nxs",
            "6,8",
            "--h-degree",
            "2",
            "--degrees",
            "0,4",
            "--p-nx",
            "6",
            "--tfinal",
            "1e-5",
            "--dt",
            "1e-5",
            "--overwrite",
        ])
        @test cli_demo isa PHRefinementDemoResult
        @test isfile(cli_demo.summary_csv)

        drift = run_rest_state_drift(RestStateDriftSpec(;
            output_dir=dir,
            severities=[23.0],
            nxs=[8, 12],
            elapsed_times=[0.0, 1.0e-5],
            overwrite=true,
        ))
        @test length(drift.rows) == 4
        @test isfile(drift.summary_csv)
        @test isfile(drift.summary_tex)
        @test isfile(drift.profile_csv)
        @test isfile(replace(drift.summary_tex, r"\.tex$" => "_full.tex"))
        @test all(row.status == "ok" for row in drift.rows)
        @test all(row.max_abs_q >= 0.0 for row in drift.rows)
        @test all(row.max_abs_area_drift >= 0.0 for row in drift.rows)
        @test all(row.requested_q_in ≈ 0.0 for row in drift.rows)
        @test all(row.applied_q_in ≈ 0.0 for row in drift.rows)
        ok_drift_row = only(row for row in drift.rows if row.nx == 8 && row.requested_time_s > 0.0)
        @test ok_drift_row.elapsed_time_s ≈ ok_drift_row.requested_time_s
        @test ok_drift_row.terminal_time_error_s ≈
              abs(ok_drift_row.elapsed_time_s - ok_drift_row.requested_time_s)
        @test ok_drift_row.terminal_time_error_s <= 1.0e-12
        @test isfinite(ok_drift_row.solver_volume_defect)
        @test isfinite(ok_drift_row.boundary_flux_integral)
        @test isfinite(ok_drift_row.conservation_residual)

        drift_header = split(readline(drift.summary_csv), ",")
        @test all(
            in(drift_header),
            [
                "elapsed_time_s",
                "requested_time_s",
                "terminal_time_error_s",
                "requested_q_in",
                "applied_q_in",
                "solver_volume_defect",
                "boundary_flux_integral",
                "conservation_residual",
            ],
        )
        @test !("mass_defect" in drift_header)
        drift_csv_row = only(row for row in read_simple_csv(drift.summary_csv) if row["nx"] == "8" && row["requested_time_s"] != "0.0")
        @test parse(Float64, drift_csv_row["elapsed_time_s"]) ≈ parse(Float64, drift_csv_row["requested_time_s"])
        @test parse(Float64, drift_csv_row["terminal_time_error_s"]) <= 1.0e-12
        @test parse(Float64, drift_csv_row["requested_q_in"]) ≈ 0.0
        @test parse(Float64, drift_csv_row["applied_q_in"]) ≈ 0.0
        @test occursin("\\Delta\\!\\int a\\,dz", read(drift.summary_tex, String))
        @test occursin("\\Delta\\!\\int a\\,dz", read(replace(drift.summary_tex, r"\\.tex$" => "_full.tex"), String))

        failing_drift = run_rest_state_drift(RestStateDriftSpec(;
            output_dir=joinpath(dir, "failing-rest-state"),
            severities=[23.0],
            nxs=[8],
            elapsed_times=[1.0e-5],
            backend=RestStateFailingBackend(),
            overwrite=true,
        ))
        error_row = only(failing_drift.rows)
        @test error_row.status == "error"
        @test error_row.requested_time_s ≈ 1.0e-5
        @test isnan(error_row.elapsed_time_s)
        @test isnan(error_row.terminal_time_error_s)
    end
end
