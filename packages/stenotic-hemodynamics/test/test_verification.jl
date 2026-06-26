isdefined(@__MODULE__, :read_simple_csv) || include("test_helpers.jl")

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

    lax_rest_params = Params(
        nx=8,
        tfinal=0.0,
        dt=1.0e-5,
        initial_condition=GeometryRestIC(),
        space=FVLaxWendroffMethod(),
    )
    lax_initial = StenoticHemodynamics.initial_state_result(lax_rest_params)
    lax_cache = StenoticHemodynamics.RHSCache(length(lax_initial.area))
    @test_throws ArgumentError StenoticHemodynamics.fill_method_fluxes!(
        lax_cache.area_flux,
        lax_cache.flow_flux,
        lax_initial.area,
        lax_initial.flow,
        lax_initial.z,
        lax_initial.dx,
        0.0,
        0.0,
        lax_rest_params.space,
        lax_rest_params,
        lax_cache,
    )
    lax_residual = StenoticHemodynamics.rest_state_residual_components(lax_rest_params)
    @test lax_residual.status == "ok"
    @test isfinite(lax_residual.total_flow_residual_max_abs)
end

@testset "StenoticHemodynamics geometry-rest well-balanced finite volume" begin
    params = Params(
        nx=16,
        tfinal=2.0e-5,
        dt=1.0e-5,
        severity=23.0,
        initial_condition=GeometryRestIC(),
        forcing=NoForcing(),
        inlet_umax=0.0,
        space=FVGeometryRestWellBalancedMethod(),
    )
    initial = StenoticHemodynamics.initial_state_result(params)
    dA, dQ = StenoticHemodynamics.rhs_dt(initial.area, initial.flow, initial.z, initial.dx, 0.0, params)
    @test maximum(abs.(dA)) <= 1.0e-10
    @test maximum(abs.(dQ)) <= 1.0e-7

    residual = StenoticHemodynamics.rest_state_residual_components(params)
    @test residual.total_area_residual_max_abs <= 1.0e-10
    @test residual.total_flow_residual_max_abs <= 1.0e-7

    result = simulate(params)
    @test maximum(abs.(result.area .- initial.area)) <= 1.0e-12
    @test maximum(abs.(result.flow)) <= 1.0e-10
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
        mms_spatial_nx_max = maximum(row.nx for row in mms.rows if row.study_kind == "spatial")
        spatial_order_rows = [row for row in mms.rows if row.study_kind == "spatial" && row.nx != mms_spatial_nx_max]
        @test any(isfinite(row.area_l1_observed_order) for row in mms.rows if row.study_kind == "spatial")
        @test any(isfinite(row.area_l2_observed_order) for row in mms.rows if row.study_kind == "spatial")
        @test any(isfinite(row.area_linf_observed_order) for row in mms.rows if row.study_kind == "spatial")
        @test any(isfinite(row.flow_l1_observed_order) for row in mms.rows if row.study_kind == "spatial")
        @test any(isfinite(row.flow_l2_observed_order) for row in mms.rows if row.study_kind == "spatial")
        @test any(isfinite(row.flow_linf_observed_order) for row in mms.rows if row.study_kind == "spatial")
        @test all(row.area_observed_order == row.area_l2_observed_order for row in spatial_order_rows)
        @test all(row.flow_observed_order == row.flow_l2_observed_order for row in spatial_order_rows)
        @test all(isnan(row.area_l1_observed_order) for row in mms.rows if row.study_kind == "temporal")
        @test all(isnan(row.area_l2_observed_order) for row in mms.rows if row.study_kind == "temporal")
        @test all(isnan(row.area_linf_observed_order) for row in mms.rows if row.study_kind == "temporal")
        @test all(isnan(row.flow_l1_observed_order) for row in mms.rows if row.study_kind == "temporal")
        @test all(isnan(row.flow_l2_observed_order) for row in mms.rows if row.study_kind == "temporal")
        @test all(isnan(row.flow_linf_observed_order) for row in mms.rows if row.study_kind == "temporal")
        csv_text = read(mms.summary_csv, String)
        @test occursin("area_l1_error", csv_text)
        @test occursin("area_linf_error", csv_text)
        @test occursin("area_l1_observed_order", csv_text)
        @test occursin("area_l2_observed_order", csv_text)
        @test occursin("area_linf_observed_order", csv_text)
        @test occursin("flow_l1_error", csv_text)
        @test occursin("flow_linf_error", csv_text)
        @test occursin("flow_l1_observed_order", csv_text)
        @test occursin("flow_l2_observed_order", csv_text)
        @test occursin("flow_linf_observed_order", csv_text)
        @test occursin("accepted_dt_min", csv_text)
        @test occursin("independent_momentum_forcing_max_abs_diff", csv_text)
        tex_text = read(mms.summary_tex, String)
        @test occursin("spatial verification", tex_text)
        @test occursin("Observed spatial orders", tex_text)
        @test occursin(raw"p_{a,1}", tex_text)
        @test occursin(raw"p_{q,\infty}", tex_text)
        @test occursin("timestep-insensitivity", tex_text)

        cli_mms = StenoticHemodynamics.run_cli([
            "verify",
            "mms",
            "--output-dir",
            joinpath(dir, "mms-cli"),
            "--nxs",
            "8,12",
            "--dt-values",
            "2e-5,1e-5",
            "--tfinal",
            "1e-5",
            "--dt",
            "1e-5",
            "--overwrite",
        ])
        @test cli_mms isa StenoticHemodynamics.ManufacturedVerificationResult
        @test isfile(cli_mms.summary_csv)
        @test isfile(cli_mms.summary_tex)

        dg_projection_params = Params(
            nx=16,
            tfinal=0.0,
            dt=1.0e-5,
            severity=0.0,
            initial_condition=ManufacturedSolutionIC(),
            forcing=ManufacturedForcing(),
            space=DGMethod(2),
            time_stepper=SSPRK3Stepper(),
        )
        dg_method = DGMethod(2)
        default_dg_coefficients = StenoticHemodynamics.simulate_dg_coefficients(dg_projection_params, dg_method)
        explicit_limited_dg_coefficients =
            StenoticHemodynamics.simulate_dg_coefficients(dg_projection_params, dg_method; apply_limiter=true)
        @test explicit_limited_dg_coefficients.area_coefficients ≈ default_dg_coefficients.area_coefficients
        @test explicit_limited_dg_coefficients.flow_coefficients ≈ default_dg_coefficients.flow_coefficients

        limited_p2_projection =
            StenoticHemodynamics.simulate_dg_coefficients(dg_projection_params, DGMethod(2); apply_limiter=true)
        unlimited_p2_projection =
            StenoticHemodynamics.simulate_dg_coefficients(dg_projection_params, DGMethod(2); apply_limiter=false)
        unlimited_p4_projection =
            StenoticHemodynamics.simulate_dg_coefficients(dg_projection_params, DGMethod(4); apply_limiter=false)
        limited_p2_metrics =
            StenoticHemodynamics.dg_manufactured_error_metrics(limited_p2_projection, dg_projection_params, 2)
        unlimited_p2_metrics =
            StenoticHemodynamics.dg_manufactured_error_metrics(unlimited_p2_projection, dg_projection_params, 2)
        unlimited_p4_metrics =
            StenoticHemodynamics.dg_manufactured_error_metrics(unlimited_p4_projection, dg_projection_params, 4)
        @test unlimited_p2_metrics.area_l2_error < limited_p2_metrics.area_l2_error / 100
        @test unlimited_p4_metrics.area_l2_error < unlimited_p2_metrics.area_l2_error / 100

        dg_evolution_params = StenoticHemodynamics.params_with(
            dg_projection_params;
            nx=8,
            space=DGMethod(2),
            tfinal=2.0e-4,
        )
        unlimited_ph_demo = StenoticHemodynamics.run_ph_refinement_demo(StenoticHemodynamics.PHRefinementDemoSpec(;
            output_dir=joinpath(dir, "ph-demo-unlimited"),
            h_nxs=[6, 8],
            h_degree=2,
            degrees=[1, 2, 4],
            p_nx=8,
            base_params=dg_evolution_params,
            apply_limiter=false,
            overwrite=true,
        ))
        unlimited_p_rows = [row for row in unlimited_ph_demo.rows if row.sweep == "p_refinement"]
        @test all(row.dg_limiter_policy == "disabled" for row in unlimited_ph_demo.rows)
        @test unlimited_p_rows[2].area_l2_error < unlimited_p_rows[1].area_l2_error
        @test unlimited_p_rows[3].area_l2_error < unlimited_p_rows[2].area_l2_error
        @test unlimited_p_rows[2].flow_l2_error < unlimited_p_rows[1].flow_l2_error
        @test unlimited_p_rows[3].flow_l2_error < unlimited_p_rows[2].flow_l2_error
        unlimited_ph_csv_text = read(unlimited_ph_demo.summary_csv, String)
        @test occursin("dg_limiter_policy", unlimited_ph_csv_text)
        @test occursin("disabled", unlimited_ph_csv_text)

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
        @test StenoticHemodynamics.p_sweep_reduction_status(1.10) == "improved"
        @test StenoticHemodynamics.p_sweep_reduction_status(1.01) == "plateau"
        @test StenoticHemodynamics.p_sweep_reduction_status(0.90) == "regressed"
        @test StenoticHemodynamics.combine_p_sweep_status("improved", "regressed") == "regressed"
        @test all(row.p_sweep_status == "not_applicable" for row in ph_demo.rows if row.sweep == "h_refinement")
        @test any(row.p_sweep_status == "baseline" for row in ph_demo.rows if row.sweep == "p_refinement")
        @test all(
            row.p_sweep_status in ("baseline", "improved", "plateau", "regressed", "not_evaluated") for
            row in ph_demo.rows if row.sweep == "p_refinement"
        )
        ph_csv_text = read(ph_demo.summary_csv, String)
        @test occursin("flow_log10_l2_error", ph_csv_text)
        @test occursin("flow_l2_reduction", ph_csv_text)
        @test occursin("area_p_sweep_status", ph_csv_text)
        @test occursin("flow_p_sweep_status", ph_csv_text)
        @test occursin("p_sweep_status", ph_csv_text)
        @test occursin("dg_limiter_policy", ph_csv_text)
        @test occursin("modal_limiter", ph_csv_text)
        @test occursin("baseline", ph_csv_text)
        ph_tex_text = read(ph_demo.summary_tex, String)
        @test occursin("p- and h-refinement diagnostic", ph_tex_text)
        @test occursin("policy", ph_tex_text)
        @test occursin("modal\\_limiter", ph_tex_text)
        @test occursin("smooth-MMS verification evidence", ph_tex_text)
        @test occursin("p-status", ph_tex_text)

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
            "--disable-dg-limiter",
            "--overwrite",
        ])
        @test cli_demo isa StenoticHemodynamics.PHRefinementDemoResult
        @test isfile(cli_demo.summary_csv)
        @test all(row.dg_limiter_policy == "disabled" for row in cli_demo.rows)
        @test occursin("disabled", read(cli_demo.summary_tex, String))

        drift = StenoticHemodynamics.run_rest_state_drift(StenoticHemodynamics.RestStateDriftSpec(;
            output_dir=dir,
            severities=[22.555555555555554],
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
        summary_tex = read(drift.summary_tex, String)
        residual_tex = read(drift.residual_tex, String)
        full_tex = read(replace(drift.summary_tex, r"\\.tex$" => "_full.tex"), String)
        @test occursin("final balance residual", summary_tex)
        @test occursin("C23 (22.56\\%)", summary_tex)
        @test occursin("R_q^{\\mathrm{tot}}", residual_tex)
        @test occursin("C23 (22.56\\%)", residual_tex)
        @test occursin("final balance residual", full_tex)
        @test occursin("C23 (22.56\\%)", full_tex)

        balanced_drift = StenoticHemodynamics.run_rest_state_drift(StenoticHemodynamics.RestStateDriftSpec(;
            output_dir=joinpath(dir, "balanced-rest-state"),
            base_params=Params(
                nx=8,
                tfinal=1.0e-5,
                dt=1.0e-5,
                severity=23.0,
                initial_condition=GeometryRestIC(),
                forcing=NoForcing(),
                inlet_umax=0.0,
                space=FVGeometryRestWellBalancedMethod(),
            ),
            severities=[23.0],
            nxs=[8],
            elapsed_times=[0.0, 1.0e-5],
            overwrite=true,
        ))
        @test isfile(balanced_drift.summary_csv)
        @test isfile(balanced_drift.residual_csv)
        @test all(row.status == "ok" for row in balanced_drift.rows)
        @test all(row.max_abs_q <= 1.0e-10 for row in balanced_drift.rows)
        @test all(row.max_abs_area_drift <= 1.0e-12 for row in balanced_drift.rows)
        @test all(row.total_area_residual_max_abs <= 1.0e-10 for row in balanced_drift.residual_rows)
        @test all(row.total_flow_residual_max_abs <= 1.0e-7 for row in balanced_drift.residual_rows)
        @test occursin("total_flow_residual_max_abs", read(balanced_drift.residual_csv, String))

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

        lax_drift = StenoticHemodynamics.run_rest_state_drift(StenoticHemodynamics.RestStateDriftSpec(;
            output_dir=joinpath(dir, "lax-wendroff-rest-state"),
            base_params=Params(
                nx=8,
                tfinal=1.0e-5,
                dt=1.0e-5,
                initial_condition=GeometryRestIC(),
                space=FVLaxWendroffMethod(),
            ),
            severities=[23.0],
            nxs=[8],
            elapsed_times=[0.0, 1.0e-5],
            overwrite=true,
        ))
        @test all(row.status == "ok" for row in lax_drift.rows)
        @test all(row.status == "ok" for row in lax_drift.residual_rows)
        @test isfinite(only(lax_drift.residual_rows).total_flow_residual_max_abs)
    end
end
