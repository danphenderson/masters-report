function descriptor_health_rows(profile::String, spec::PackageBenchmarkSpec)
    rows = Vector{Vector{Any}}()
    methods = profile == "smoke" ?
        Any[FVFirstOrderMethod(), FVMUSCLMethod(), FVWENO3Method(), FVLaxWendroffMethod(), DGMethod(0), DGMethod(1), DGMethod(2)] :
        Any[FVFirstOrderMethod(), FVMUSCLMethod(), FVWENO3Method(), FVLaxWendroffMethod(), DGMethod(0), DGMethod(1), DGMethod(2)]
    steppers = profile == "smoke" ? Any[SSPRK3Stepper()] :
        Any[ForwardEulerStepper(), SSPRK2Stepper(), SSPRK3Stepper(), SSPRK54Stepper()]
    nx = profile == "smoke" ? 12 : 120
    tfinal = profile == "smoke" ? 1.0e-4 : 1.0e-2
    severity = 40
    for method in methods, stepper in steppers
        params = Params(;
            severity=severity,
            nx=nx,
            tfinal=tfinal,
            space=method,
            time_stepper=stepper,
            initial_condition=GeometryRestIC(),
            dt=1.0e-5,
        )
        case_id = "descriptor-$(method_slug(method))-$(stepper_slug(stepper))"
        push!(rows, case_result_row("descriptor_health", case_id, params, NativeRK3Backend(), spec))
    end
    return rows
end

function refinement_rows(profile::String, spec::PackageBenchmarkSpec)
    try
        nxs = profile == "smoke" ? [10, 20] : [50, 100, 200, 400]
        degrees = profile == "smoke" ? [0, 1] : [0, 1, 2]
        h_methods = profile == "smoke" ?
            [FVFirstOrderMethod(), FVMUSCLMethod(), FVWENO3Method(), DGMethod(0)] :
            [FVFirstOrderMethod(), FVMUSCLMethod(), FVWENO3Method(), DGMethod(0), DGMethod(1), DGMethod(2)]
        base_params = Params(;
            severity=40,
            nx=first(nxs),
            tfinal=profile == "smoke" ? 1.0e-4 : 1.0e-2,
            dt=1.0e-5,
            time_stepper=SSPRK3Stepper(),
            initial_condition=GeometryRestIC(),
        )
        study = RefinementStudySpec(;
            base_params=base_params,
            nxs=nxs,
            degrees=degrees,
            h_methods=AbstractSpatialMethod[h_methods...],
            backend=NativeRK3Backend(),
            output_dir=joinpath(spec.output_dir, "refinement_raw"),
            overwrite=true,
            progress_every=spec.progress_every,
            parallel_workers=0,
        )
        rows = Vector{Vector{Any}}()
        elapsed = @elapsed result = run_refinement_study(study)
        for row in result.h_rows
            push!(rows, [
                "h_refinement",
                "h-$(row.method)-nx$(row.nx)",
                row.method,
                "",
                row.nx,
                row.nx,
                "area_l2",
                row.error_A_l2,
                row.order_A,
                "ok",
                elapsed,
                "",
            ])
            push!(rows, [
                "h_refinement",
                "h-$(row.method)-nx$(row.nx)",
                row.method,
                "",
                row.nx,
                row.nx,
                "flow_l2",
                row.error_Q_l2,
                row.order_Q,
                "ok",
                elapsed,
                "",
            ])
            push!(rows, [
                "h_refinement",
                "h-$(row.method)-nx$(row.nx)",
                row.method,
                "",
                row.nx,
                row.nx,
                "velocity_l2",
                row.error_u_l2,
                row.order_u,
                "ok",
                elapsed,
                "",
            ])
            push!(rows, [
                "h_refinement",
                "h-$(row.method)-nx$(row.nx)",
                row.method,
                "",
                row.nx,
                row.nx,
                "pressure_l2",
                row.error_pressure_l2,
                row.order_pressure,
                "ok",
                elapsed,
                "",
            ])
        end
        for row in result.p_rows
            push!(rows, [
                "p_refinement",
                "p-degree$(row.degree)-dofs$(row.dofs)",
                "dg",
                row.degree,
                "",
                row.dofs,
                "area_l2",
                row.error_A_l2,
                row.order_A,
                "ok",
                elapsed,
                "",
            ])
            push!(rows, [
                "p_refinement",
                "p-degree$(row.degree)-dofs$(row.dofs)",
                "dg",
                row.degree,
                "",
                row.dofs,
                "flow_l2",
                row.error_Q_l2,
                row.order_Q,
                "ok",
                elapsed,
                "",
            ])
            push!(rows, [
                "p_refinement",
                "p-degree$(row.degree)-dofs$(row.dofs)",
                "dg",
                row.degree,
                "",
                row.dofs,
                "velocity_l2",
                row.error_u_l2,
                row.order_u,
                "ok",
                elapsed,
                "",
            ])
            push!(rows, [
                "p_refinement",
                "p-degree$(row.degree)-dofs$(row.dofs)",
                "dg",
                row.degree,
                "",
                row.dofs,
                "pressure_l2",
                row.error_pressure_l2,
                row.order_pressure,
                "ok",
                elapsed,
                "",
            ])
        end
        return rows
    catch err
        return [["refinement", "refinement-study", "", "", "", "", "", "", "", "error", 0.0, sprint(showerror, err)]]
    end
end

function backend_parity_rows(profile::String, spec::PackageBenchmarkSpec)
    rows = Vector{Vector{Any}}()
    methods = profile == "smoke" ?
        Any[FVMUSCLMethod()] :
        Any[FVFirstOrderMethod(), FVMUSCLMethod(), FVWENO3Method(), DGMethod(0)]
    nxs = profile == "smoke" ? [12] : [80, 160]
    algorithms = profile == "smoke" ? ["tsit5"] : ["auto", "tsit5", "vern7", "vern9", "rodas5p"]
    tfinal = profile == "smoke" ? 1.0e-4 : 1.0e-2
    for method in methods, nx in nxs, algorithm in algorithms
        case_id = "backend-$(method_slug(method))-nx$(nx)-$(algorithm)"
        params = Params(;
            severity=40,
            nx=nx,
            tfinal=tfinal,
            dt=1.0e-5,
            space=method,
            time_stepper=SSPRK3Stepper(),
            initial_condition=GeometryRestIC(),
        )
        native_elapsed = 0.0
        sciml_elapsed = 0.0
        try
            native_elapsed = @elapsed native = simulate(params, NativeRK3Backend(); progress_every=spec.progress_every)
            sciml_backend = SciMLTimeBackend(solve=SolveSpec(algorithm=sciml_policy(algorithm)))
            sciml_elapsed = @elapsed sciml = simulate(params, sciml_backend; progress_every=spec.progress_every)
            native_pressure = diagnostic_pressure(native, params)
            sciml_pressure = diagnostic_pressure(sciml, params)
            native_velocity = velocity(native)
            sciml_velocity = velocity(sciml)
            area_l2 = l2_error_against_reference(sciml.z, sciml.area, native.z, native.area)
            flow_l2 = l2_error_against_reference(sciml.z, sciml.flow, native.z, native.flow)
            velocity_l2 = l2_error_against_reference(sciml.z, sciml_velocity, native.z, native_velocity)
            pressure_l2 = l2_error_against_reference(sciml.z, sciml_pressure, native.z, native_pressure)
            push!(rows, [
                case_id,
                benchmark_method_name(method),
                benchmark_method_degree(method),
                nx,
                tfinal,
                algorithm,
                native_elapsed,
                sciml_elapsed,
                area_l2,
                flow_l2,
                velocity_l2,
                pressure_l2,
                "ok",
                "",
            ])
        catch err
            push!(rows, [
                case_id,
                benchmark_method_name(method),
                benchmark_method_degree(method),
                nx,
                tfinal,
                algorithm,
                native_elapsed,
                sciml_elapsed,
                "",
                "",
                "",
                "",
                "error",
                sprint(showerror, err),
            ])
        end
    end
    return rows
end

function stokes_ic_rows(profile::String, spec::PackageBenchmarkSpec)
    rows = Vector{Vector{Any}}()
    severities = profile == "smoke" ? [0] : [0, 40, 50]
    meshes = profile == "smoke" ? [(8, 2, 8)] : [(8, 2, 8), (16, 4, 16), (32, 6, 32), (64, 6, 32)]
    for severity in severities, mesh in meshes
        nz, nr, ntheta = mesh
        case_id = "stokes-s$(severity)-$(nz)x$(nr)x$(ntheta)"
        ic = StationaryStokesIC(;
            pressure_drop_pa=40.0,
            mesh_nz=nz,
            mesh_nr=nr,
            mesh_ntheta=ntheta,
            projection_nr=nr,
            projection_ntheta=ntheta,
            diagnostics_path=joinpath(spec.output_dir, "stokes_ic", case_id),
        )
        params = Params(;
            severity=severity,
            nx=profile == "smoke" ? 12 : 80,
            tfinal=0.0,
            space=FVMUSCLMethod(),
            initial_condition=ic,
        )
        elapsed = 0.0
        try
            elapsed = @elapsed state = initial_state_result(params)
            summary = state.summary
            push!(rows, [
                case_id,
                severity,
                40.0,
                nz,
                nr,
                ntheta,
                nr,
                ntheta,
                get_summary_field(summary, :velocity_dofs, ""),
                get_summary_field(summary, :pressure_dofs, ""),
                get_summary_field(summary, :residual_norm, ""),
                get_summary_field(summary, :projection_hash, ""),
                mean(state.flow),
                "ok",
                elapsed,
                "",
            ])
        catch err
            push!(rows, [
                case_id,
                severity,
                40.0,
                nz,
                nr,
                ntheta,
                nr,
                ntheta,
                "",
                "",
                "",
                "",
                "",
                "error",
                elapsed,
                sprint(showerror, err),
            ])
        end
    end
    return rows
end

function rheology_profile_rows(profile::String, spec::PackageBenchmarkSpec)
    rows = Vector{Vector{Any}}()
    severities = profile == "smoke" ? [40] : [23, 40, 50, 73]
    rheologies = profile == "smoke" ?
        Any[NewtonianRheology(), CarreauRheology()] :
        Any[NewtonianRheology(), CarreauRheology(), CarreauYasudaRheology(), CassonRheology(), PowerLawRheology()]
    profiles = profile == "smoke" ?
        Any[ParabolicVelocityProfile(), FlatVelocityProfile()] :
        Any[ParabolicVelocityProfile(), FlatVelocityProfile(), PowerVelocityProfile(alpha=1.1)]
    nx = profile == "smoke" ? 16 : 200
    tfinal = profile == "smoke" ? 1.0e-4 : 2.0e-2
    for severity in severities, rheology in rheologies, velocity_profile in profiles
        case_id = "rheology-s$(severity)-$(rheology_slug(rheology))-$(profile_slug(velocity_profile))"
        params = Params(;
            severity=severity,
            nx=nx,
            tfinal=tfinal,
            dt=1.0e-5,
            rheology=rheology,
            velocity_profile=velocity_profile,
            space=FVMUSCLMethod(),
            time_stepper=SSPRK3Stepper(),
            initial_condition=GeometryRestIC(),
        )
        push!(rows, compact_metrics_row(case_id, severity, rheology_name(rheology), profile_name(velocity_profile), params, spec))
    end
    return rows
end

function boundary_openbf_rows(profile::String, spec::PackageBenchmarkSpec)
    rows = Vector{Vector{Any}}()
    waveform_path = joinpath(spec.output_dir, "synthetic_waveform.csv")
    guarded_open_write(waveform_path, true) do io
        write(io, "0.0 0.0\n")
        write(io, "0.00005 1.0\n")
        write(io, "0.00010 0.0\n")
        if profile == "overnight"
            write(io, "0.01000 0.0\n")
        end
    end
    rt_values = profile == "smoke" ? [0.0, 0.25] : [0.0, 0.25, 0.5]
    nx = profile == "smoke" ? 16 : 200
    tfinal = profile == "smoke" ? 1.0e-4 : 2.0e-2
    for rt in rt_values
        inlet = FlowWaveformInlet(waveform_path)
        outlet = ReflectionCoefficientOutlet(rt)
        params = Params(;
            severity=40,
            nx=nx,
            tfinal=tfinal,
            dt=1.0e-5,
            inlet_boundary=inlet,
            outlet_boundary=outlet,
            space=FVMUSCLMethod(),
            time_stepper=SSPRK3Stepper(),
            initial_condition=GeometryRestIC(),
        )
        case_id = "boundary-waveform-rt$(replace(string(rt), "." => "p"))"
        elapsed = 0.0
        try
            elapsed = @elapsed result = simulate(params, NativeRK3Backend(); progress_every=spec.progress_every)
            metrics = result_metrics(params, result)
            push!(rows, [
                case_id,
                inlet_boundary_name(inlet),
                outlet_boundary_name(outlet),
                rt,
                nx,
                tfinal,
                elapsed,
                result.steps,
                metrics.min_area,
                metrics.max_abs_u,
                metrics.pressure_min,
                metrics.pressure_max,
                "ok",
                "",
            ])
        catch err
            push!(rows, [
                case_id,
                inlet_boundary_name(inlet),
                outlet_boundary_name(outlet),
                rt,
                nx,
                tfinal,
                elapsed,
                "",
                "",
                "",
                "",
                "",
                "error",
                sprint(showerror, err),
            ])
        end
    end
    return rows
end

function resolved3d_rows(profile::String, spec::PackageBenchmarkSpec)
    if !spec.include_resolved3d
        @telemetry_info "package benchmark stage skipped" event="stage_skipped" stage="resolved3d" backend="package-benchmark" method=profile nx="" tfinal="" status="skipped" rows=1 output_dir=spec.output_dir reason="include_resolved3d=false"
        return [resolved3d_status_row("resolved3d", "", "skipped", 0.0, "include_resolved3d=false")]
    end
    if profile == "smoke"
        @telemetry_info "package benchmark stage skipped" event="stage_skipped" stage="resolved3d" backend="package-benchmark" method=profile nx="" tfinal="" status="skipped" rows=1 output_dir=spec.output_dir reason="smoke profile does not run resolved-3D diagnostics"
        return [resolved3d_status_row("resolved3d", "", "skipped", 0.0, "smoke profile does not run resolved-3D diagnostics")]
    end

    rows = Vector{Vector{Any}}()
    for velocity_profile in Any[ParabolicVelocityProfile(), PowerVelocityProfile(alpha=1.1)]
        case_id = "resolved3d-$(profile_slug(velocity_profile))"
        elapsed = 0.0
        try
            output_dir = joinpath(spec.output_dir, "resolved3d", profile_slug(velocity_profile))
            base_params = Params(;
                velocity_profile=velocity_profile,
                initial_condition=GeometryRestIC(),
            )
            elapsed = @elapsed result = run_available_resolved3d_comparison(;
                output_dir=output_dir,
                overwrite=true,
                write_svg=false,
                base_params=base_params,
            )
            if result === nothing
                @telemetry_info "package benchmark case skipped" event="case_skipped" stage="resolved3d" backend="package-benchmark" method=profile nx="" tfinal="" status="skipped" elapsed_s=elapsed rows=1 output_dir=output_dir reason="no local resolved-3D comparison files found"
                push!(rows, resolved3d_status_row(case_id, profile_name(velocity_profile), "skipped", elapsed, "no local resolved-3D comparison files found"))
            else
                for row in result.summary_rows
                    push!(rows, [
                        case_id,
                        row.case_label,
                        row.severity,
                        profile_name(velocity_profile),
                        row.operator,
                        row.section_count,
                        row.mean_abs_error_cm_s,
                        row.l2_velocity_error_cm_s,
                        row.max_abs_error_cm_s,
                        row.mean_rel_error,
                        row.relative_l1_velocity_error,
                        row.max_rel_error,
                        row.rel_l2_velocity_error,
                        row.mean_flow_abs_error_cm3_s,
                        row.flow_l2_error_cm3_s,
                        row.max_flow_abs_error_cm3_s,
                        row.min_intersection_count,
                        row.area_valid_count,
                        row.alpha_eff_min,
                        row.alpha_eff_max,
                        row.characteristic_radicand_min,
                        row.lambda_minus_min,
                        row.lambda_minus_max,
                        row.lambda_plus_min,
                        row.lambda_plus_max,
                        row.subcritical_margin_min,
                        "ok",
                        elapsed,
                        "",
                    ])
                end
            end
        catch err
            push!(rows, resolved3d_status_row(case_id, profile_name(velocity_profile), "error", elapsed, sprint(showerror, err)))
        end
    end
    isempty(rows) && push!(rows, resolved3d_status_row("resolved3d", "", "skipped", 0.0, "no diagnostics produced"))
    return rows
end
