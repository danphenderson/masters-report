Base.@kwdef struct PackageBenchmarkSpec
    profile::String = "smoke"
    output_dir::String = joinpath("simulations", "output", "package_benchmark", "smoke")
    overwrite::Bool = false
    include_python::Bool = false
    include_resolved3d::Bool = false
    publish_report_assets::Bool = false
    progress_every::Int = 0
end

struct PackageBenchmarkResult
    output_dir::String
    manifest_path::String
    csv_paths::Vector{String}
end

const PACKAGE_BENCHMARK_DATA_DIR =
    joinpath("figures", "static", "static", "data", "package-benchmark")

const CASE_RESULTS_HEADER = [
    "stage",
    "case_id",
    "language",
    "backend",
    "device",
    "method",
    "degree",
    "stepper",
    "nx",
    "severity",
    "tfinal",
    "dt",
    "cfl",
    "ic",
    "rheology",
    "profile",
    "inlet",
    "outlet",
    "status",
    "elapsed_s",
    "steps",
    "min_area",
    "max_abs_u",
    "pressure_min",
    "pressure_max",
    "error_message",
]

const REFINEMENT_HEADER = [
    "study",
    "case_id",
    "method",
    "degree",
    "nx",
    "dofs",
    "metric",
    "error",
    "observed_order",
    "status",
    "elapsed_s",
    "error_message",
]

const BACKEND_PARITY_HEADER = [
    "case_id",
    "method",
    "degree",
    "nx",
    "tfinal",
    "algorithm",
    "native_elapsed_s",
    "sciml_elapsed_s",
    "area_l2",
    "flow_l2",
    "velocity_l2",
    "pressure_l2",
    "status",
    "error_message",
]

const STOKES_IC_HEADER = [
    "case_id",
    "severity",
    "pressure_drop_pa",
    "mesh_nz",
    "mesh_nr",
    "mesh_ntheta",
    "projection_nr",
    "projection_ntheta",
    "velocity_dofs",
    "pressure_dofs",
    "pressure_drop_relative_error",
    "projection_hash",
    "mean_flow",
    "status",
    "elapsed_s",
    "error_message",
]

const RHEOLOGY_PROFILE_HEADER = [
    "case_id",
    "severity",
    "rheology",
    "profile",
    "nx",
    "tfinal",
    "elapsed_s",
    "steps",
    "min_area",
    "max_abs_u",
    "pressure_min",
    "pressure_max",
    "status",
    "error_message",
]

const BOUNDARY_OPENBF_HEADER = [
    "case_id",
    "inlet",
    "outlet",
    "reflection_coefficient",
    "nx",
    "tfinal",
    "elapsed_s",
    "steps",
    "min_area",
    "max_abs_u",
    "pressure_min",
    "pressure_max",
    "status",
    "error_message",
]

const RESOLVED3D_HEADER = [
    "case_id",
    "case_label",
    "severity",
    "profile",
    "section_count",
    "mean_abs_error_cm_s",
    "max_abs_error_cm_s",
    "mean_relative_error",
    "max_relative_error",
    "status",
    "elapsed_s",
    "error_message",
]

const PYTHON_MPS_HEADER = [
    "case_id",
    "language",
    "backend",
    "device",
    "method",
    "degree",
    "nx",
    "tfinal",
    "status",
    "elapsed_s",
    "relative_area_mean_final",
    "relative_flow_mean_final",
    "raw_json",
    "error_message",
]

function run_package_benchmark(spec::PackageBenchmarkSpec=PackageBenchmarkSpec())
    profile = lowercase(strip(spec.profile))
    profile in ("smoke", "overnight") ||
        throw(ArgumentError("profile must be smoke or overnight, got $(spec.profile)"))

    if isdir(spec.output_dir)
        spec.overwrite ||
            throw(ArgumentError("output directory exists; pass overwrite=true to replace it: $(spec.output_dir)"))
        rm(spec.output_dir; recursive=true, force=true)
    elseif isfile(spec.output_dir)
        throw(ArgumentError("output path exists and is not a directory: $(spec.output_dir)"))
    end
    mkpath(spec.output_dir)

    paths = Dict{String,String}(
        "case_results" => joinpath(spec.output_dir, "case_results.csv"),
        "refinement" => joinpath(spec.output_dir, "refinement.csv"),
        "backend_parity" => joinpath(spec.output_dir, "backend_parity.csv"),
        "stokes_ic" => joinpath(spec.output_dir, "stokes_ic.csv"),
        "rheology_profile" => joinpath(spec.output_dir, "rheology_profile.csv"),
        "boundary_openbf" => joinpath(spec.output_dir, "boundary_openbf.csv"),
        "resolved3d" => joinpath(spec.output_dir, "resolved3d.csv"),
        "python_mps" => joinpath(spec.output_dir, "python_mps.csv"),
    )

    csv_outputs = String[]
    write_csv(paths["case_results"], CASE_RESULTS_HEADER, descriptor_health_rows(profile, spec))
    push!(csv_outputs, paths["case_results"])
    write_csv(paths["refinement"], REFINEMENT_HEADER, refinement_rows(profile, spec))
    push!(csv_outputs, paths["refinement"])
    write_csv(paths["backend_parity"], BACKEND_PARITY_HEADER, backend_parity_rows(profile, spec))
    push!(csv_outputs, paths["backend_parity"])
    write_csv(paths["stokes_ic"], STOKES_IC_HEADER, stokes_ic_rows(profile, spec))
    push!(csv_outputs, paths["stokes_ic"])
    write_csv(paths["rheology_profile"], RHEOLOGY_PROFILE_HEADER, rheology_profile_rows(profile, spec))
    push!(csv_outputs, paths["rheology_profile"])
    write_csv(paths["boundary_openbf"], BOUNDARY_OPENBF_HEADER, boundary_openbf_rows(profile, spec))
    push!(csv_outputs, paths["boundary_openbf"])
    write_csv(paths["resolved3d"], RESOLVED3D_HEADER, resolved3d_rows(profile, spec))
    push!(csv_outputs, paths["resolved3d"])
    write_csv(paths["python_mps"], PYTHON_MPS_HEADER, python_mps_rows(profile, spec))
    push!(csv_outputs, paths["python_mps"])

    manifest_path = joinpath(spec.output_dir, "manifest.json")
    write_manifest(manifest_path, spec, profile, csv_outputs)

    if spec.publish_report_assets
        publish_package_benchmark_assets(spec.output_dir, csv_outputs, manifest_path)
    end

    return PackageBenchmarkResult(spec.output_dir, manifest_path, csv_outputs)
end

function descriptor_health_rows(profile::String, spec::PackageBenchmarkSpec)
    rows = Vector{Vector{Any}}()
    methods = profile == "smoke" ?
        Any[FVFirstOrderMethod(), FVMUSCLMethod(), FVLaxWendroffMethod(), DGMethod(0), DGMethod(1), DGMethod(2)] :
        Any[FVFirstOrderMethod(), FVMUSCLMethod(), FVLaxWendroffMethod(), DGMethod(0), DGMethod(1), DGMethod(2)]
    steppers = profile == "smoke" ? Any[SSPRK3Stepper()] :
        Any[ForwardEulerStepper(), SSPRK2Stepper(), SSPRK3Stepper()]
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
        [FVFirstOrderMethod(), FVMUSCLMethod(), DGMethod(0)] :
        [FVFirstOrderMethod(), FVMUSCLMethod(), DGMethod(0), DGMethod(1), DGMethod(2)]
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
        Any[FVFirstOrderMethod(), FVMUSCLMethod(), DGMethod(0)]
    nxs = profile == "smoke" ? [12] : [80, 160]
    algorithms = profile == "smoke" ? ["tsit5"] : ["auto", "tsit5", "rodas5p"]
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
            native_pressure = pressure(native, params)
            sciml_pressure = pressure(sciml, params)
            native_velocity = velocity(native)
            sciml_velocity = velocity(sciml)
            area_l2 = l2_error_against_reference(sciml.z, sciml.area, native.z, native.area)
            flow_l2 = l2_error_against_reference(sciml.z, sciml.flow, native.z, native.flow)
            velocity_l2 = l2_error_against_reference(sciml.z, sciml_velocity, native.z, native_velocity)
            pressure_l2 = l2_error_against_reference(sciml.z, sciml_pressure, native.z, native_pressure)
            push!(rows, [
                case_id,
                method_name(method),
                method_degree(method),
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
                method_name(method),
                method_degree(method),
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
    open(waveform_path, "w") do io
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
        return [["resolved3d", "", "", "", "", "", "", "", "", "skipped", 0.0, "include_resolved3d=false"]]
    end
    if profile == "smoke"
        return [["resolved3d", "", "", "", "", "", "", "", "", "skipped", 0.0, "smoke profile does not run resolved-3D diagnostics"]]
    end

    rows = Vector{Vector{Any}}()
    for velocity_profile in Any[ParabolicVelocityProfile(), PowerVelocityProfile(alpha=1.1)]
        case_id = "resolved3d-$(profile_slug(velocity_profile))"
        elapsed = 0.0
        try
            output_dir = joinpath(spec.output_dir, "resolved3d", profile_slug(velocity_profile))
            base_params = Params(; velocity_profile=velocity_profile)
            elapsed = @elapsed result = run_available_resolved3d_comparison(;
                output_dir=output_dir,
                overwrite=true,
                write_svg=false,
                base_params=base_params,
            )
            if result === nothing
                push!(rows, [case_id, "", "", profile_name(velocity_profile), "", "", "", "", "", "skipped", elapsed, "no local resolved-3D comparison files found"])
            else
                for row in result.summary_rows
                    push!(rows, [
                        case_id,
                        row.case_label,
                        row.severity,
                        profile_name(velocity_profile),
                        row.section_count,
                        row.mean_abs_error_cm_s,
                        row.max_abs_error_cm_s,
                        row.mean_relative_error,
                        row.max_relative_error,
                        "ok",
                        elapsed,
                        "",
                    ])
                end
            end
        catch err
            push!(rows, [case_id, "", "", profile_name(velocity_profile), "", "", "", "", "", "error", elapsed, sprint(showerror, err)])
        end
    end
    isempty(rows) && push!(rows, ["resolved3d", "", "", "", "", "", "", "", "", "skipped", 0.0, "no diagnostics produced"])
    return rows
end

function python_mps_rows(profile::String, spec::PackageBenchmarkSpec)
    if !spec.include_python
        return [["python", "python", "torch", "mps", "", "", "", "", "skipped", 0.0, "", "", "", "include_python=false"]]
    end
    rows = Vector{Vector{Any}}()
    methods = profile == "smoke" ?
        [("fv-first-order", -1)] :
        [("fv-first-order", -1), ("fv-muscl", -1), ("dg-p0", 0), ("dg-p1", 1), ("dg-p2", 2)]
    nxs = profile == "smoke" ? [16] : [64, 128, 256]
    tfinal = profile == "smoke" ? 1.0e-4 : 1.0e-2
    for (method, degree) in methods, nx in nxs
        case_id = "python-$(method)-nx$(nx)"
        raw_path = joinpath(spec.output_dir, "$(case_id).json")
        elapsed = 0.0
        try
            cmd = `pipenv run research-hemodynamics compare --left-backend native --right-backend torch --device mps --allow-cpu-fallback --space $(method) --nx $(nx) --tfinal $(tfinal) --saveat $(tfinal)`
            elapsed = @elapsed text = read(cmd, String)
            write(raw_path, text)
            push!(rows, [
                case_id,
                "python",
                "torch",
                "mps",
                method,
                degree,
                nx,
                tfinal,
                "ok",
                elapsed,
                extract_relative_metric(text, "area_mean_final"),
                extract_relative_metric(text, "flow_mean_final"),
                raw_path,
                "",
            ])
        catch err
            push!(rows, [
                case_id,
                "python",
                "torch",
                "mps",
                method,
                degree,
                nx,
                tfinal,
                "skipped",
                elapsed,
                "",
                "",
                raw_path,
                sprint(showerror, err),
            ])
        end
    end
    return rows
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
            backend_name(backend),
            "cpu",
            method_name(params.space),
            method_degree(params.space),
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
            "",
        ]
    catch err
        return [
            stage,
            case_id,
            "julia",
            backend_name(backend),
            "cpu",
            method_name(params.space),
            method_degree(params.space),
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
            sprint(showerror, err),
        ]
    end
end

function result_metrics(params, result)
    velocity_values = velocity(result)
    pressure_values = pressure(result, params)
    return (;
        min_area=minimum(result.area),
        max_abs_u=maximum(abs.(velocity_values)),
        pressure_min=minimum(pressure_values),
        pressure_max=maximum(pressure_values),
    )
end

function publish_package_benchmark_assets(output_dir::String, csv_outputs::Vector{String}, manifest_path::String)
    mkpath(PACKAGE_BENCHMARK_DATA_DIR)
    for path in csv_outputs
        cp(path, joinpath(PACKAGE_BENCHMARK_DATA_DIR, basename(path)); force=true)
    end
    cp(manifest_path, joinpath(PACKAGE_BENCHMARK_DATA_DIR, "manifest.json"); force=true)
    return PACKAGE_BENCHMARK_DATA_DIR
end

function write_manifest(path::String, spec::PackageBenchmarkSpec, profile::String, csv_outputs::Vector{String})
    hash_paths = manifest_output_paths(spec.output_dir, csv_outputs, path)
    manifest = Dict{String,Any}(
        "profile" => profile,
        "output_dir" => spec.output_dir,
        "timestamp_utc" => chomp(read(`date -u +%Y-%m-%dT%H:%M:%SZ`, String)),
        "git_sha" => safe_readchomp(`git rev-parse HEAD`),
        "julia_version" => string(VERSION),
        "python_version" => safe_readchomp(`pipenv run python --version`),
        "torch_version" => safe_readchomp(`pipenv run python -c "import torch; print(torch.__version__)"`),
        "mps_available" => safe_readchomp(`pipenv run python -c "import torch; print(torch.backends.mps.is_available())"`),
        "scipy_available" => safe_readchomp(`pipenv run python -c "import importlib.util; print(importlib.util.find_spec('scipy') is not None)"`),
        "include_python" => spec.include_python,
        "include_resolved3d" => spec.include_resolved3d,
        "publish_report_assets" => spec.publish_report_assets,
        "command" => join(vcat(isempty(PROGRAM_FILE) ? "julia" : PROGRAM_FILE, ARGS), " "),
        "output_hashes" => Dict(basename(p) => sha256_file(p) for p in hash_paths if isfile(p)),
    )
    open(path, "w") do io
        write_json(io, manifest, 0)
        write(io, "\n")
    end
    return path
end

function manifest_output_paths(output_dir::String, csv_outputs::Vector{String}, manifest_path::String)
    output_files = isdir(output_dir) ? filter(isfile, readdir(output_dir; join=true)) : String[]
    manifest_abs = abspath(manifest_path)
    candidates = vcat(csv_outputs, output_files)
    unique_paths = Dict{String,String}()
    for path in candidates
        isfile(path) || continue
        abspath(path) == manifest_abs && continue
        unique_paths[abspath(path)] = path
    end
    return sort!(collect(values(unique_paths)); by=basename)
end

function write_csv(path::String, header::Vector{String}, rows::Vector{Vector{Any}})
    open(path, "w") do io
        write(io, join(header, ","), "\n")
        for row in rows
            padded = length(row) < length(header) ? vcat(row, fill("", length(header) - length(row))) : row[1:length(header)]
            write(io, join(csv_cell.(padded), ","), "\n")
        end
    end
    return path
end

function csv_cell(value)
    if value === nothing
        return ""
    end
    text = string(value)
    if any(occursin.(["\"", ",", "\n", "\r"], Ref(text)))
        return "\"" * replace(text, "\"" => "\"\"") * "\""
    end
    return text
end

function write_json(io, value, indent::Int)
    pad = repeat(" ", indent)
    if value isa AbstractDict
        write(io, "{")
        first = true
        for key in sort!(collect(keys(value)); by=string)
            first || write(io, ",")
            write(io, "\n", repeat(" ", indent + 2), json_string(string(key)), ": ")
            write_json(io, value[key], indent + 2)
            first = false
        end
        write(io, "\n", pad, "}")
    elseif value isa AbstractVector
        write(io, "[")
        for (i, item) in enumerate(value)
            i == 1 || write(io, ", ")
            write_json(io, item, indent)
        end
        write(io, "]")
    elseif value isa Bool
        write(io, value ? "true" : "false")
    elseif value isa Number
        if isfinite(float(value))
            write(io, string(value))
        else
            write(io, "null")
        end
    elseif value === nothing
        write(io, "null")
    else
        write(io, json_string(string(value)))
    end
end

function json_string(text::String)
    escaped = replace(text, "\\" => "\\\\", "\"" => "\\\"", "\n" => "\\n", "\r" => "\\r", "\t" => "\\t")
    return "\"" * escaped * "\""
end

function sha256_file(path::String)
    open(path, "r") do io
        return bytes2hex(sha256(io))
    end
end

function safe_readchomp(cmd::Cmd)
    try
        return chomp(read(cmd, String))
    catch err
        return "unavailable: " * sprint(showerror, err)
    end
end

function extract_relative_metric(text::String, metric::String)
    pattern = Regex("\"relative_difference\"\\s*:\\s*\\{[^}]*\"" * metric * "\"\\s*:\\s*([-+0-9.eE]+)")
    m = match(pattern, text)
    return m === nothing ? "" : m.captures[1]
end

function sciml_policy(name::String)
    lower = lowercase(name)
    lower == "auto" && return AutoPolicy()
    lower == "tsit5" && return Tsit5Policy()
    lower == "rodas5p" && return Rodas5PPolicy()
    throw(ArgumentError("unsupported SciML algorithm: $name"))
end

method_name(method::FVFirstOrderMethod) = "fv-first-order"
method_name(method::FVMUSCLMethod) = "fv-muscl"
method_name(method::FVLaxWendroffMethod) = "fv-lax-wendroff"
method_name(method::DGMethod) = "dg-p$(method.degree)"
method_name(method) = string(typeof(method))

method_slug(method) = replace(method_name(method), "_" => "-", "." => "p")
method_degree(method::DGMethod) = method.degree
method_degree(method) = ""

stepper_name(stepper::ForwardEulerStepper) = "forward-euler"
stepper_name(stepper::SSPRK2Stepper) = "ssprk2"
stepper_name(stepper::SSPRK3Stepper) = "ssprk3"
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
