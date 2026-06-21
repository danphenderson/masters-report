struct RestStateFailingBackend <: AbstractTimeBackend end

@testset "StenoticHemodynamics simulation diagnostics and forcing" begin
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
    mms_state = StenoticHemodynamics.initial_state_result(mms_params)
    @test length(mms_state.area) == 8
    @test all(isfinite, mms_state.area)
    @test all(isfinite, mms_state.flow)
    forcing_audit = StenoticHemodynamics.manufactured_forcing_residual_audit(mms_params)
    @test forcing_audit.mass_max_abs_diff < 1.0e-7
    @test forcing_audit.momentum_max_abs_diff < 1.0e-3
    mutated_audit = StenoticHemodynamics.manufactured_forcing_residual_audit(mms_params; momentum_scale=-1.0)
    @test mutated_audit.momentum_max_abs_diff > forcing_audit.momentum_max_abs_diff + 1.0
end

@testset "StenoticHemodynamics verification runners" begin
    mktempdir() do dir
        default_mms_spec = StenoticHemodynamics.ManufacturedVerificationSpec()
        default_drift_spec = StenoticHemodynamics.RestStateDriftSpec()
        @test typeof(default_mms_spec) <: StenoticHemodynamics.ManufacturedVerificationSpec{NativeRK3Backend}
        @test typeof(default_drift_spec) <: StenoticHemodynamics.RestStateDriftSpec{NativeRK3Backend}

        mms = StenoticHemodynamics.run_manufactured_verification(StenoticHemodynamics.ManufacturedVerificationSpec(;
            output_dir=dir,
            base_params=Params(
                nx=8,
                tfinal=1.0e-5,
                dt=1.0e-5,
                severity=0.0,
                initial_condition=ManufacturedSolutionIC(),
                forcing=ManufacturedForcing(),
            ),
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
        @test all(isfinite(row.accepted_dt_min) for row in mms.rows)
        @test all(isfinite(row.accepted_dt_max) for row in mms.rows)
        @test all(isfinite(row.realized_cfl_max) for row in mms.rows)
        @test all(row.independent_mass_forcing_max_abs_diff < 1.0e-7 for row in mms.rows)
        @test all(row.independent_momentum_forcing_max_abs_diff < 1.0e-3 for row in mms.rows)
        @test all(isnan(row.area_observed_order) for row in mms.rows if row.study_kind == "temporal")
        @test all(isnan(row.flow_observed_order) for row in mms.rows if row.study_kind == "temporal")
        csv_text = read(mms.summary_csv, String)
        @test occursin("area_l1_error", csv_text)
        @test occursin("area_linf_error", csv_text)
        @test occursin("flow_l1_error", csv_text)
        @test occursin("flow_linf_error", csv_text)
        @test occursin("accepted_dt_min", csv_text)
        @test occursin("independent_momentum_forcing_max_abs_diff", csv_text)
        tex_text = read(mms.summary_tex, String)
        @test occursin("spatial verification", tex_text)
        @test occursin("timestep-insensitivity", tex_text)

        ph_demo = StenoticHemodynamics.run_ph_refinement_demo(StenoticHemodynamics.PHRefinementDemoSpec(;
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

        cli_demo = StenoticHemodynamics.run_cli([
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
        @test cli_demo isa StenoticHemodynamics.PHRefinementDemoResult
        @test isfile(cli_demo.summary_csv)

        drift = StenoticHemodynamics.run_rest_state_drift(StenoticHemodynamics.RestStateDriftSpec(;
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
        @test isfile(drift.residual_csv)
        @test isfile(drift.residual_tex)
        @test isfile(replace(drift.summary_tex, r"\.tex$" => "_full.tex"))
        @test all(row.status == "ok" for row in drift.rows)
        @test all(row.status == "ok" for row in drift.residual_rows)
        @test all(row.max_abs_q >= 0.0 for row in drift.rows)
        @test all(row.max_abs_area_drift >= 0.0 for row in drift.rows)
        @test all(row.requested_q_in ≈ 0.0 for row in drift.rows)
        @test all(row.applied_q_in ≈ 0.0 for row in drift.rows)
        @test all(row.mass_flux_rusanov_max_abs >= 0.0 for row in drift.residual_rows)
        @test all(row.elastic_flux_difference_max_abs >= 0.0 for row in drift.residual_rows)
        @test all(row.wall_geometry_source_max_abs >= 0.0 for row in drift.residual_rows)
        @test all(row.total_flow_residual_max_abs >= 0.0 for row in drift.residual_rows)
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
        residual_header = split(readline(drift.residual_csv), ",")
        @test all(
            in(residual_header),
            [
                "mass_flux_rusanov_max_abs",
                "elastic_flux_difference_max_abs",
                "wall_geometry_source_max_abs",
                "total_flow_residual_max_abs",
            ],
        )
        drift_csv_row = only(row for row in read_simple_csv(drift.summary_csv) if row["nx"] == "8" && row["requested_time_s"] != "0.0")
        @test parse(Float64, drift_csv_row["elapsed_time_s"]) ≈ parse(Float64, drift_csv_row["requested_time_s"])
        @test parse(Float64, drift_csv_row["terminal_time_error_s"]) <= 1.0e-12
        @test parse(Float64, drift_csv_row["requested_q_in"]) ≈ 0.0
        @test parse(Float64, drift_csv_row["applied_q_in"]) ≈ 0.0
        @test occursin("\\Delta\\!\\int a\\,dz", read(drift.summary_tex, String))
        @test occursin("R_q^{\\mathrm{tot}}", read(drift.residual_tex, String))
        @test occursin("\\Delta\\!\\int a\\,dz", read(replace(drift.summary_tex, r"\\.tex$" => "_full.tex"), String))

        failing_drift = StenoticHemodynamics.run_rest_state_drift(StenoticHemodynamics.RestStateDriftSpec(;
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
        @test isfile(failing_drift.residual_csv)
    end
end
