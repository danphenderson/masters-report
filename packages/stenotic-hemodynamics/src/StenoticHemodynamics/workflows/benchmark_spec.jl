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

function package_benchmark_spec_from_values(values::Dict{String,String}, flags::Set{String})
    return PackageBenchmarkSpec(;
        profile=get(values, "profile", "smoke"),
        output_dir=get(values, "output-dir", joinpath(DEFAULT_SIMULATION_OUTPUT_ROOT, "package_benchmark", "smoke")),
        overwrite=("overwrite" in flags),
        include_resolved3d=("include-resolved3d" in flags),
        publish_report_assets=("publish-report-assets" in flags),
        progress_every=parse(Int, get(values, "progress-every", "0")),
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
