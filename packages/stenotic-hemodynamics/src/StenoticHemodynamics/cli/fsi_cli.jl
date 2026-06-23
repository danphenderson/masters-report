function print_fsi_usage()
    println("""
    Usage:
      packages/stenotic-hemodynamics/bin/stenotic-hemodynamics fsi validate [--wall-mode quasi-static|dynamic] [--severities 23,40] [--meshes 8x2x8,16x4x16] [--publish-report-assets] [options]
      packages/stenotic-hemodynamics/bin/stenotic-hemodynamics fsi native-status [--case-id sev23] [--mesh 2x1x6] [--snapshot-times 1e-4] [--inlet-outlet-boundary-mode pressure_drop_weak_inlet_outlet_gauge_smoke|poiseuille_inlet_zero_outlet_stress_section41] [options]

    Dynamic mode is a reduced radial membrane model coupled to repeated quasi-steady Stokes solves.
    Dynamic options use cgs-compatible units: --wall-density G/CM3, --wall-dt SECONDS, --wall-tfinal SECONDS.
    Native status is a dry-run/status surface only; it never runs native resolved-FSI production.
    Report assets are written under --report-assets-dir, default report/assets.
    """)
end

function native_resolved_fsi_status_resolution(values::Dict{String,String})
    mesh = only(parse_mesh_list(get(values, "mesh", "2x1x6")))
    return NativeResolvedFSIMeshResolution(axial=mesh[1], radial=mesh[2], angular=mesh[3])
end

function native_resolved_fsi_status_case_id(values::Dict{String,String})
    raw = get(values, "case-id", get(values, "severity", "sev23"))
    return startswith(raw, "sev") ? Symbol(raw) : parse(Float64, raw)
end

function native_resolved_fsi_status_plan_from_values(values::Dict{String,String}, flags::Set{String})
    snapshot_times = parse_float_list(get(values, "snapshot-times", get(values, "tfinal", "1.0e-4")))
    isempty(snapshot_times) && throw(ArgumentError("fsi native-status requires at least one snapshot time"))
    tfinal = parse(Float64, get(values, "tfinal", string(maximum(snapshot_times))))
    return only(native_resolved_fsi_production_workflow_plans(
        case_ids=(native_resolved_fsi_status_case_id(values),),
        resolution=native_resolved_fsi_status_resolution(values),
        output_root=get(values, "output-root", get(values, "output-dir", "")),
        dt_s=parse(Float64, get(values, "dt", "1.0e-4")),
        tfinal_s=tfinal,
        snapshot_times_s=snapshot_times,
        time_atol=parse(Float64, get(values, "time-atol", "1.0e-12")),
        overwrite=("overwrite" in flags),
        inlet_outlet_boundary_mode=get(
            values,
            "inlet-outlet-boundary-mode",
            "pressure_drop_weak_inlet_outlet_gauge_smoke",
        ),
        inlet_umax_cm_s=parse(Float64, get(values, "inlet-umax", "45.0")),
        pressure_drop_dyn_cm2=parse(Float64, get(values, "ic-pressure-drop-dyn-cm2", "40.0")),
        picard_iteration_count=parse(Int, get(values, "maxiters", "8")),
        picard_tolerance=parse(Float64, get(values, "reltol", "1.0e-8")),
        coupling_iteration_count=parse(Int, get(values, "max-coupling-iters", "1")),
        coupling_tolerance=parse(Float64, get(values, "coupling-tolerance-cm", "1.0e-8")),
        coupling_under_relaxation=parse(Float64, get(values, "alpha", "1.0")),
        allow_many_snapshots=("allow-many-snapshots" in flags),
        allow_large_output=("allow-large-output" in flags),
    ))
end

function print_native_resolved_fsi_status(dry_run::NativeResolvedFSIProductionDryRunPlan)
    println("native_resolved_fsi_status,dry_run")
    println("case_id,$(dry_run.case_id)")
    println("output_dir,$(dry_run.output_dir)")
    println("snapshot_manifest_csv,$(dry_run.manifest_csv)")
    println("snapshot_diagnostics_csv,$(dry_run.diagnostics_csv)")
    println("restart_metadata_json,$(dry_run.restart_metadata_json)")
    println("parity_observations_csv,$(dry_run.parity_observations_csv)")
    println("parity_summary_csv,$(dry_run.parity_summary_csv)")
    println("snapshot_count_within_default_guard,$(dry_run.snapshot_count_within_default_guard)")
    println("estimated_output_payload_within_default_guard,$(dry_run.estimated_output_payload_within_default_guard)")
    override_flags = isempty(dry_run.required_override_flags) ? "none" : join(dry_run.required_override_flags, "|")
    println("required_override_flags,$override_flags")
    println("boundary_mode,$(dry_run.boundary_mode)")
    println("boundary_mode_class,$(dry_run.boundary_mode_class)")
    println("section41_boundary_status,$(dry_run.section41_boundary_status)")
    println("boundary_equivalence_status,$(dry_run.boundary_equivalence_status)")
    println("wall_stability_status,$(dry_run.wall_stability_status)")
    println("imported_bundle_status,$(dry_run.imported_available ? "available" : "expected-skip")")
    println("imported_case,$(dry_run.imported_case.case_label)")
    println(
        "native_resolved_fsi_claim_boundary," *
        "exact mode is smoke-scale/operator-readiness evidence only; not paper-grade Section 4.1 reproduction",
    )
    println("status,$(dry_run.status)")
end

function run_fsi_cli(args::Vector{String})
    isempty(args) && (print_fsi_usage(); return nothing)
    subcommand = args[1]
    rest = args[2:end]
    subcommand in ("--help", "-h", "help") && (print_fsi_usage(); return nothing)
    subcommand in ("validate", "native-status") ||
        throw(ArgumentError("unknown fsi subcommand '$subcommand'; expected validate or native-status"))
    values, flags = parse_cli_options(rest, FSI_VALUE_OPTIONS, FSI_FLAG_OPTIONS)
    if "help" in flags
        print_fsi_usage()
        return nothing
    end
    if subcommand == "native-status"
        plan = native_resolved_fsi_status_plan_from_values(values, flags)
        dry_run = native_resolved_fsi_partitioned_production_dry_run(
            plan;
            imported_data_root=get(values, "imported-data-root", default_resolved3d_data_root()),
        )
        print_native_resolved_fsi_status(dry_run)
        return dry_run
    end
    haskey(values, "tfinal") || (values["tfinal"] = "0.0")
    params, _, _ = params_backend_progress(values, flags)
    result = run_membrane_fsi_validation(membrane_fsi_validation_spec_from_values(params, values, flags))
    println("fsi_validation_summary_csv,$(result.summary_csv)")
    println("fsi_validation_summary_tex,$(result.summary_tex)")
    println("fsi_validation_manifest_json,$(result.manifest_json)")
    if "publish-report-assets" in flags
        paths = publish_membrane_fsi_report_assets(
            result;
            report_assets_dir=get(values, "report-assets-dir", joinpath("report", "assets")),
            overwrite=("overwrite" in flags),
        )
        for path in paths
            println("fsi_validation_report_asset,$path")
        end
    end
    return result
end
