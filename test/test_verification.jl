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
        @test all(row.status == "ok" for row in drift.rows)
        @test all(row.max_abs_q >= 0.0 for row in drift.rows)
        @test all(row.max_abs_area_drift >= 0.0 for row in drift.rows)
    end
end
