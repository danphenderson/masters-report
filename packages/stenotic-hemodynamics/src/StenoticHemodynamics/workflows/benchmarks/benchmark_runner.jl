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
