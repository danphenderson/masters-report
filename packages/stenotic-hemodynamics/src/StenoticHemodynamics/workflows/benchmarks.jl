"""
    PackageBenchmarkSpec(; profile, output_dir, overwrite, include_resolved3d,
        publish_report_assets, progress_every)

Workflow spec for the package benchmark matrix. The benchmark participates in
the internal workflow protocol through `workflow_kind`, `validate_workflow_spec`,
and `default_output_paths`, but remains public only through
`run_package_benchmark`.
"""
Base.@kwdef struct PackageBenchmarkSpec <: AbstractStudySpec
    profile::String = "smoke"
    output_dir::String = joinpath(DEFAULT_SIMULATION_OUTPUT_ROOT, "package_benchmark", "smoke")
    overwrite::Bool = false
    include_resolved3d::Bool = false
    publish_report_assets::Bool = false
    progress_every::Int = 0
end

struct PackageBenchmarkResult
    output_dir::String
    manifest_path::String
    csv_paths::Vector{String}
end

workflow_kind(::PackageBenchmarkSpec) = "package_benchmark"

function validate(spec::PackageBenchmarkSpec)
    profile = lowercase(strip(spec.profile))
    profile in ("smoke", "overnight") ||
        throw(ArgumentError("profile must be smoke or overnight, got $(spec.profile)"))
    spec.progress_every >= 0 || throw(ArgumentError("progress_every must be nonnegative"))
    return spec
end

function default_output_paths(spec::PackageBenchmarkSpec)
    return (
        case_results=joinpath(spec.output_dir, "case_results.csv"),
        refinement=joinpath(spec.output_dir, "refinement.csv"),
        backend_parity=joinpath(spec.output_dir, "backend_parity.csv"),
        stokes_ic=joinpath(spec.output_dir, "stokes_ic.csv"),
        rheology_profile=joinpath(spec.output_dir, "rheology_profile.csv"),
        boundary_openbf=joinpath(spec.output_dir, "boundary_openbf.csv"),
        resolved3d=joinpath(spec.output_dir, "resolved3d.csv"),
        manifest=joinpath(spec.output_dir, "manifest.json"),
    )
end

const PACKAGE_BENCHMARK_DATA_DIR =
    joinpath("report", "assets", "data", "package-benchmark")

const PACKAGE_BENCHMARK_OWNED_FILES = [
    "case_results.csv",
    "refinement.csv",
    "backend_parity.csv",
    "stokes_ic.csv",
    "rheology_profile.csv",
    "boundary_openbf.csv",
    "resolved3d.csv",
    "manifest.json",
    "synthetic_waveform.csv",
]

const PACKAGE_BENCHMARK_OWNED_DIRS = [
    "refinement_raw",
    "stokes_ic",
    "resolved3d",
]

const CASE_RESULTS_HEADER = [
    "stage",
    "case_id",
    "language",
    "package",
    "model",
    "variable_radius_terms",
    "wall_law",
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
    "realized_cfl_min",
    "realized_cfl_max",
    "lambda_minus_min",
    "lambda_minus_max",
    "lambda_plus_min",
    "lambda_plus_max",
    "subcritical_margin_min",
    "mass_defect",
    "positivity_projection_count",
    "positivity_correction_total",
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
    "operator",
    "section_count",
    "mean_abs_discrepancy_cm_s",
    "l2_velocity_discrepancy_cm_s",
    "max_abs_discrepancy_cm_s",
    "mean_relative_discrepancy",
    "relative_l1_velocity_discrepancy",
    "max_relative_discrepancy",
    "relative_l2_velocity_discrepancy",
    "mean_flow_abs_discrepancy_cm3_s",
    "flow_l2_discrepancy_cm3_s",
    "max_flow_abs_discrepancy_cm3_s",
    "min_intersection_count",
    "area_valid_count",
    "alpha_eff_min",
    "alpha_eff_max",
    "characteristic_radicand_min",
    "lambda_minus_min",
    "lambda_minus_max",
    "lambda_plus_min",
    "lambda_plus_max",
    "subcritical_margin_min",
    "status",
    "elapsed_s",
    "error_message",
]

function run_package_benchmark(spec::PackageBenchmarkSpec=PackageBenchmarkSpec())
    validate_workflow_spec(spec)
    profile = lowercase(strip(spec.profile))

    start_ns = telemetry_start_ns()
    kind = workflow_kind(spec)
    @telemetry_info "package benchmark started" event="package_benchmark_started" stage=kind backend="package-benchmark" method=profile nx="" tfinal="" status="started" output_dir=spec.output_dir
    try
        prepare_package_benchmark_output_dir(spec.output_dir; overwrite=spec.overwrite)

        paths = default_output_paths(spec)

        csv_outputs = String[]
        run_benchmark_stage!(csv_outputs, paths.case_results, CASE_RESULTS_HEADER, "case_results", spec, profile) do
            descriptor_health_rows(profile, spec)
        end
        run_benchmark_stage!(csv_outputs, paths.refinement, REFINEMENT_HEADER, "refinement", spec, profile) do
            refinement_rows(profile, spec)
        end
        run_benchmark_stage!(csv_outputs, paths.backend_parity, BACKEND_PARITY_HEADER, "backend_parity", spec, profile) do
            backend_parity_rows(profile, spec)
        end
        run_benchmark_stage!(csv_outputs, paths.stokes_ic, STOKES_IC_HEADER, "stokes_ic", spec, profile) do
            stokes_ic_rows(profile, spec)
        end
        run_benchmark_stage!(csv_outputs, paths.rheology_profile, RHEOLOGY_PROFILE_HEADER, "rheology_profile", spec, profile) do
            rheology_profile_rows(profile, spec)
        end
        run_benchmark_stage!(csv_outputs, paths.boundary_openbf, BOUNDARY_OPENBF_HEADER, "boundary_openbf", spec, profile) do
            boundary_openbf_rows(profile, spec)
        end
        run_benchmark_stage!(csv_outputs, paths.resolved3d, RESOLVED3D_HEADER, "resolved3d", spec, profile) do
            resolved3d_rows(profile, spec)
        end

        manifest_path = paths.manifest
        write_manifest(manifest_path, spec, profile, csv_outputs)

        if spec.publish_report_assets
            publish_package_benchmark_assets(spec.output_dir, csv_outputs, manifest_path)
        end

        @telemetry_info "package benchmark completed" event="package_benchmark_completed" stage=kind backend="package-benchmark" method=profile nx="" tfinal="" status="ok" elapsed_s=telemetry_elapsed_s(start_ns) rows=length(csv_outputs) output_dir=spec.output_dir
        return PackageBenchmarkResult(spec.output_dir, manifest_path, csv_outputs)
    catch err
        @telemetry_error "package benchmark failed" event="package_benchmark_failed" stage=kind backend="package-benchmark" method=profile nx="" tfinal="" status="error" elapsed_s=telemetry_elapsed_s(start_ns) output_dir=spec.output_dir reason=sprint(showerror, err)
        rethrow()
    end
end

"""
    prepare_package_benchmark_output_dir(output_dir; overwrite=false)

Validate and prepare a package-benchmark output directory.

When `overwrite=false`, an existing directory is rejected. When
`overwrite=true`, only files and subdirectories owned by the package benchmark
workflow are removed; unrelated files in `output_dir` are preserved. Repository
source, report, reference, and raw-data paths are rejected even with overwrite
enabled.
"""
function prepare_package_benchmark_output_dir(output_dir::String; overwrite::Bool = false)
    isempty(strip(output_dir)) && throw(ArgumentError("benchmark output_dir must not be empty"))
    assert_package_benchmark_output_path(output_dir)

    if isdir(output_dir)
        overwrite ||
            throw(ArgumentError("output directory exists; pass overwrite=true to replace benchmark-owned files: $output_dir"))
        clear_package_benchmark_outputs(output_dir)
    elseif isfile(output_dir)
        throw(ArgumentError("output path exists and is not a directory: $output_dir"))
    else
        mkpath(output_dir)
    end
    return output_dir
end

function clear_package_benchmark_outputs(output_dir::String)
    for name in PACKAGE_BENCHMARK_OWNED_FILES
        path = joinpath(output_dir, name)
        isfile(path) && rm(path; force=true)
    end
    for name in PACKAGE_BENCHMARK_OWNED_DIRS
        path = joinpath(output_dir, name)
        isdir(path) && rm(path; recursive=true, force=true)
    end
    return output_dir
end

function assert_package_benchmark_output_path(output_dir::String)
    output_abs = canonical_package_benchmark_path(output_dir)
    repo_root = package_benchmark_repo_root()
    output_abs == repo_root && throw(ArgumentError(
        "refusing to use protected repository root as package benchmark output_dir: $output_dir",
    ))

    for protected in package_benchmark_protected_roots(repo_root)
        if same_or_descendant(output_abs, protected)
            throw(ArgumentError(
                "refusing to use protected repository path as package benchmark output_dir: $output_dir",
            ))
        end
    end
    return output_dir
end

function canonical_package_benchmark_path(path::String)
    normalized = normpath(abspath(path))
    while length(normalized) > 1 && (endswith(normalized, "/") || endswith(normalized, "\\"))
        normalized = normalized[begin:prevind(normalized, lastindex(normalized))]
    end
    return normalized
end

package_benchmark_repo_root() = canonical_package_benchmark_path(joinpath(@__DIR__, "..", "..", "..", "..", ".."))

function package_benchmark_protected_roots(repo_root::String = package_benchmark_repo_root())
    return [
        joinpath(repo_root, "packages", "stenotic-hemodynamics", "src"),
        joinpath(repo_root, "packages", "stenotic-hemodynamics", "test"),
        joinpath(repo_root, "public", "var", "data", "simulations"),
        joinpath(repo_root, "packages", "ops", "src"),
        joinpath(repo_root, "packages", "ops", "tests"),
        joinpath(repo_root, "public", "docs"),
        joinpath(repo_root, "public", "references"),
        joinpath(repo_root, "public", "reproducibility"),
        joinpath(repo_root, "report"),
    ]
end

function same_or_descendant(path::String, parent::String)
    rel = relpath(canonical_package_benchmark_path(path), canonical_package_benchmark_path(parent))
    return rel == "." || !(rel == ".." || startswith(rel, "../") || startswith(rel, "..\\") || isabspath(rel))
end

function run_benchmark_stage!(producer, csv_outputs::Vector{String}, path::String, header, stage::String, spec::PackageBenchmarkSpec, profile::String)
    start_ns = telemetry_start_ns()
    @telemetry_info "package benchmark stage started" event="stage_started" stage=stage backend="package-benchmark" method=profile nx="" tfinal="" status="started" output_dir=spec.output_dir
    try
        rows = producer()
        write_csv_table(path, header, rows; pad_rows=true)
        push!(csv_outputs, path)
        @telemetry_info "package benchmark stage completed" event="stage_completed" stage=stage backend="package-benchmark" method=profile nx="" tfinal="" status="ok" elapsed_s=telemetry_elapsed_s(start_ns) rows=length(rows) output_dir=spec.output_dir
        return rows
    catch err
        @telemetry_error "package benchmark stage failed" event="stage_failed" stage=stage backend="package-benchmark" method=profile nx="" tfinal="" status="error" elapsed_s=telemetry_elapsed_s(start_ns) rows=0 output_dir=spec.output_dir reason=sprint(showerror, err)
        rethrow()
    end
end

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
    pressure_values = pressure(result, params)
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
        "package" => "StenoticHemodynamics",
        "default_model" => "canic-extended-1d",
        "default_wall_law" => wall_law_name(CanicKoiterWallLaw()),
        "default_variable_radius_terms" => variable_radius_terms_enabled(CanicExtendedOneDModel()),
        "profile" => profile,
        "output_dir" => spec.output_dir,
        "timestamp_utc" => chomp(read(`date -u +%Y-%m-%dT%H:%M:%SZ`, String)),
        "git_sha" => safe_readchomp(`git rev-parse HEAD`),
        "julia_version" => string(VERSION),
        "include_resolved3d" => spec.include_resolved3d,
        "publish_report_assets" => spec.publish_report_assets,
        "command" => join(vcat(isempty(PROGRAM_FILE) ? "julia" : PROGRAM_FILE, ARGS), " "),
        "output_hashes" => Dict(basename(p) => sha256_file(p) for p in hash_paths if isfile(p)),
    )
    write_json(path, manifest)
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

function safe_readchomp(cmd::Cmd)
    try
        return chomp(read(cmd, String))
    catch err
        return "unavailable: " * sprint(showerror, err)
    end
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
