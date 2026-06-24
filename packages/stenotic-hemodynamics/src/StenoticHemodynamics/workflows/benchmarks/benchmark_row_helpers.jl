function resolved3d_status_row(case_id::String, profile_label::String, status::String, elapsed::Float64, message::String)
    row = Any["" for _ in RESOLVED3D_HEADER]
    row[1] = case_id
    row[4] = profile_label
    row[end - 2] = status
    row[end - 1] = elapsed
    row[end] = message
    return row
end

function compact_metrics_row(case_id, severity, rheology_label, profile_label, params, spec)
    elapsed = 0.0
    try
        elapsed = @elapsed result = simulate(params, NativeRK3Backend(); progress_every=spec.progress_every)
        metrics = result_metrics(params, result)
        return [
            case_id,
            severity,
            rheology_label,
            profile_label,
            params.nx,
            params.tfinal,
            elapsed,
            result.steps,
            metrics.min_area,
            metrics.max_abs_u,
            metrics.pressure_min,
            metrics.pressure_max,
            "ok",
            "",
        ]
    catch err
        return [
            case_id,
            severity,
            rheology_label,
            profile_label,
            params.nx,
            params.tfinal,
            elapsed,
            "",
            "",
            "",
            "",
            "",
            "error",
            sprint(showerror, err),
        ]
    end
end

function case_result_row(stage::String, case_id::String, params, backend, spec::PackageBenchmarkSpec)
    elapsed = 0.0
    try
        elapsed = @elapsed result = simulate(params, backend; progress_every=spec.progress_every)
        metrics = result_metrics(params, result)
        return [
            stage,
            case_id,
            "julia",
            "StenoticHemodynamics",
            model_name(params),
            variable_radius_terms_enabled(params),
            wall_law_name(params),
            backend_name(backend),
            "cpu",
            benchmark_method_name(params.space),
            benchmark_method_degree(params.space),
            stepper_name(params.time_stepper),
            params.nx,
            params.severity,
            params.tfinal,
            params.dt,
            params.cfl,
            ic_name(params.initial_condition),
            rheology_name(params.rheology),
            profile_name(params.velocity_profile),
            inlet_boundary_name(params.inlet_boundary),
            outlet_boundary_name(params.outlet_boundary),
            "ok",
            elapsed,
            result.steps,
            metrics.min_area,
            metrics.max_abs_u,
            metrics.pressure_min,
            metrics.pressure_max,
            metrics.realized_cfl_min,
            metrics.realized_cfl_max,
            metrics.lambda_minus_min,
            metrics.lambda_minus_max,
            metrics.lambda_plus_min,
            metrics.lambda_plus_max,
            metrics.subcritical_margin_min,
            metrics.mass_defect,
            metrics.positivity_projection_count,
            metrics.positivity_correction_total,
            "",
        ]
    catch err
        return [
            stage,
            case_id,
            "julia",
            "StenoticHemodynamics",
            model_name(params),
            variable_radius_terms_enabled(params),
            wall_law_name(params),
            backend_name(backend),
            "cpu",
            benchmark_method_name(params.space),
            benchmark_method_degree(params.space),
            stepper_name(params.time_stepper),
            params.nx,
            params.severity,
            params.tfinal,
            params.dt,
            params.cfl,
            ic_name(params.initial_condition),
            rheology_name(params.rheology),
            profile_name(params.velocity_profile),
            inlet_boundary_name(params.inlet_boundary),
            outlet_boundary_name(params.outlet_boundary),
            "error",
            elapsed,
            "",
            "",
            "",
            "",
            "",
            "",
            "",
            "",
            "",
            "",
            "",
            "",
            "",
            "",
            "",
            sprint(showerror, err),
        ]
    end
end

function result_metrics(params, result)
    velocity_values = velocity(result)
    pressure_values = diagnostic_pressure(result, params)
    return (;
        min_area=minimum(result.area),
        max_abs_u=maximum(abs.(velocity_values)),
        pressure_min=minimum(pressure_values),
        pressure_max=maximum(pressure_values),
        realized_cfl_min=result.diagnostics.cfl_min,
        realized_cfl_max=result.diagnostics.cfl_max,
        lambda_minus_min=result.diagnostics.lambda_minus_min,
        lambda_minus_max=result.diagnostics.lambda_minus_max,
        lambda_plus_min=result.diagnostics.lambda_plus_min,
        lambda_plus_max=result.diagnostics.lambda_plus_max,
        subcritical_margin_min=result.diagnostics.subcritical_margin_min,
        mass_defect=result.diagnostics.mass_defect,
        positivity_projection_count=result.diagnostics.positivity_projection_count,
        positivity_correction_total=result.diagnostics.positivity_correction_total,
    )
end

function sciml_policy(name::String)
    lower = lowercase(name)
    lower == "auto" && return AutoPolicy()
    lower == "tsit5" && return Tsit5Policy()
    lower == "vern7" && return Vern7Policy()
    lower == "vern9" && return Vern9Policy()
    lower == "rodas5p" && return Rodas5PPolicy()
    throw(ArgumentError("unsupported SciML algorithm: $name"))
end

benchmark_method_name(::FVFirstOrderMethod) = "fv-first-order"
benchmark_method_name(::FVMUSCLMethod) = "fv-muscl"
benchmark_method_name(::FVWENO3Method) = "fv-weno3"
benchmark_method_name(::FVLaxWendroffMethod) = "fv-lax-wendroff"
benchmark_method_name(method::DGMethod) = "dg-p$(method.degree)"
benchmark_method_name(method) = string(typeof(method))

method_slug(method) = replace(benchmark_method_name(method), "_" => "-", "." => "p")
benchmark_method_degree(method::DGMethod) = method.degree
benchmark_method_degree(method::AbstractSpatialMethod) = ""
benchmark_method_degree(method) = ""

stepper_name(stepper::ForwardEulerStepper) = "forward-euler"
stepper_name(stepper::SSPRK2Stepper) = "ssprk2"
stepper_name(stepper::SSPRK3Stepper) = "ssprk3"
stepper_name(stepper::SSPRK54Stepper) = "ssprk54"
stepper_name(stepper) = string(typeof(stepper))
stepper_slug(stepper) = stepper_name(stepper)

ic_name(ic::GeometryRestIC) = "GeometryRestIC"
ic_name(ic::StationaryStokesIC) = "StationaryStokesIC"
ic_name(ic) = string(typeof(ic))

rheology_slug(rheology) = replace(rheology_name(rheology), " " => "-", "." => "p")

profile_slug(profile::PowerVelocityProfile) = "power-g-" * path_token(profile.exponent)
profile_slug(profile) = replace(replace(profile_name(profile), " " => "-"), "." => "p")

function get_summary_field(summary, field::Symbol, default)
    return field in propertynames(summary) ? getproperty(summary, field) : default
end
