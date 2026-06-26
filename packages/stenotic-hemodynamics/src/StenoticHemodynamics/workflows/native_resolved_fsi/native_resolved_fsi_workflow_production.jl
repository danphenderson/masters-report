const NATIVE_RESOLVED_FSI_PRODUCTION_DEFAULT_OUTPUT_ROOT =
    joinpath(DEFAULT_SIMULATION_OUTPUT_ROOT, "native-resolved-fsi-production")
const NATIVE_RESOLVED_FSI_PRODUCTION_MAX_SNAPSHOT_COUNT = 50
const NATIVE_RESOLVED_FSI_PRODUCTION_MAX_OUTPUT_BYTES = 1_073_741_824
const NATIVE_RESOLVED_FSI_PARTITIONED_PRODUCTION_DEFAULT_DT_S = 1.0e-4
const NATIVE_RESOLVED_FSI_PARTITIONED_PRODUCTION_DEFAULT_PICARD_ITERATION_COUNT = 8
const NATIVE_RESOLVED_FSI_PARTITIONED_PRODUCTION_DEFAULT_PICARD_TOLERANCE = 1.0e-8
const NATIVE_RESOLVED_FSI_PARTITIONED_PRODUCTION_DEFAULT_WALL_DENSITY_G_CM3 = 1.0
const NATIVE_RESOLVED_FSI_PARTITIONED_PRODUCTION_DEFAULT_WALL_DAMPING_G_CM2_S = 0.0
const NATIVE_RESOLVED_FSI_PRODUCTION_STIFFNESS_POLICIES = (:canic_membrane_c0,)
const NATIVE_RESOLVED_FSI_PRODUCTION_REFERENCE_RADIUS_POLICIES = (:params_rmax,)
const NATIVE_RESOLVED_FSI_PRODUCTION_INLET_OUTLET_BOUNDARY_MODES = (
    :pressure_drop_weak_inlet_outlet_gauge_smoke,
    :poiseuille_inlet_zero_outlet_stress_section41,
)
const NATIVE_RESOLVED_FSI_PRODUCTION_DEFAULT_INLET_OUTLET_BOUNDARY_MODE =
    :pressure_drop_weak_inlet_outlet_gauge_smoke
const NATIVE_RESOLVED_FSI_PRODUCTION_SECTION41_INLET_UMAX_CM_S = 45.0
const NATIVE_RESOLVED_FSI_PRODUCTION_SEV23_DEVELOPMENT_REFERENCE_TETRAHEDRA = 9_600
const NATIVE_RESOLVED_FSI_PRODUCTION_SEV23_DEVELOPMENT_REFERENCE_STEPS = 100
const NATIVE_RESOLVED_FSI_PRODUCTION_SEV23_DEVELOPMENT_REFERENCE_WALL_TIME_S = 25.0 * 60.0
const NATIVE_RESOLVED_FSI_PRODUCTION_CHECKPOINT_ROLES = (
    "wall_state",
    "mesh_identity",
    "fluid_state",
    "coupling_state",
    "output_linkage",
)
const NATIVE_RESOLVED_FSI_PRODUCTION_BATCH_CLAIM_BOUNDARY =
    "batch row records native resolved-FSI execution observability only; not production parity, " *
    "imported parity, moving-wall/ALE fidelity, restart/resume support, or paper-grade native resolved-FSI Section 4.1 reproduction"

"""
    NativeResolvedFSIPartitionedProductionSpec(; kwargs...)

Production-oriented control and output policy for native partitioned
resolved-FSI generation. This spec validates Section 4.1 case selection,
snapshot timing, output volume, Picard controls, and membrane/coupling policy
inputs for later production runners. It does not by itself claim a stronger
numerical method, production numerical parity, or monolithic ALE coupling.
"""
struct NativeResolvedFSIPartitionedProductionSpec
    case_spec::NativeResolvedFSICaseSpec
    resolution::NativeResolvedFSIMeshResolution
    output_root::String
    dt_s::Float64
    tfinal_s::Float64
    snapshot_times_s::Vector{Float64}
    time_atol::Float64
    overwrite::Bool
    inlet_outlet_boundary_mode::Symbol
    inlet_umax_cm_s::Float64
    pressure_drop_dyn_cm2::Float64
    picard_iteration_count::Int
    picard_tolerance::Float64
    wall_density_g_cm3::Float64
    wall_damping_g_cm2_s::Float64
    wall_stiffness_policy::Symbol
    wall_reference_radius_policy::Symbol
    coupling_iteration_count::Int
    coupling_tolerance::Float64
    coupling_under_relaxation::Float64
    progress_every::Int
    status_every::Int
    allow_many_snapshots::Bool
    allow_large_output::Bool
end

function NativeResolvedFSIPartitionedProductionSpec(;
    case_id::Union{Symbol,AbstractString,Real} = :sev23,
    resolution::NativeResolvedFSIMeshResolution = NativeResolvedFSIMeshResolution(),
    output_root::AbstractString = "",
    dt_s::Real = NATIVE_RESOLVED_FSI_PARTITIONED_PRODUCTION_DEFAULT_DT_S,
    tfinal_s::Real = NATIVE_RESOLVED_FSI_DEFAULT_TIME_S,
    snapshot_times_s = (tfinal_s,),
    time_atol::Real = 1.0e-12,
    overwrite::Bool = false,
    inlet_outlet_boundary_mode::Union{Symbol,AbstractString} = NATIVE_RESOLVED_FSI_PRODUCTION_DEFAULT_INLET_OUTLET_BOUNDARY_MODE,
    inlet_umax_cm_s::Real = NATIVE_RESOLVED_FSI_PRODUCTION_SECTION41_INLET_UMAX_CM_S,
    pressure_drop_dyn_cm2::Real = 40.0,
    picard_iteration_count::Integer = NATIVE_RESOLVED_FSI_PARTITIONED_PRODUCTION_DEFAULT_PICARD_ITERATION_COUNT,
    picard_tolerance::Real = NATIVE_RESOLVED_FSI_PARTITIONED_PRODUCTION_DEFAULT_PICARD_TOLERANCE,
    wall_density_g_cm3::Real = NATIVE_RESOLVED_FSI_PARTITIONED_PRODUCTION_DEFAULT_WALL_DENSITY_G_CM3,
    wall_damping_g_cm2_s::Real = NATIVE_RESOLVED_FSI_PARTITIONED_PRODUCTION_DEFAULT_WALL_DAMPING_G_CM2_S,
    wall_stiffness_policy::Union{Symbol,AbstractString} = :canic_membrane_c0,
    wall_reference_radius_policy::Union{Symbol,AbstractString} = :params_rmax,
    coupling_iteration_count::Integer = 1,
    coupling_tolerance::Real = 1.0e-8,
    coupling_under_relaxation::Real = 1.0,
    progress_every::Integer = 0,
    status_every::Integer = 1,
    allow_many_snapshots::Bool = false,
    allow_large_output::Bool = false,
)
    return validate(NativeResolvedFSIPartitionedProductionSpec(
        native_resolved_fsi_case_spec(case_id),
        resolution,
        String(output_root),
        Float64(dt_s),
        Float64(tfinal_s),
        Float64[Float64(time_s) for time_s in snapshot_times_s],
        Float64(time_atol),
        overwrite,
        native_resolved_fsi_production_boundary_mode(inlet_outlet_boundary_mode),
        Float64(inlet_umax_cm_s),
        Float64(pressure_drop_dyn_cm2),
        Int(picard_iteration_count),
        Float64(picard_tolerance),
        Float64(wall_density_g_cm3),
        Float64(wall_damping_g_cm2_s),
        Symbol(wall_stiffness_policy),
        Symbol(wall_reference_radius_policy),
        Int(coupling_iteration_count),
        Float64(coupling_tolerance),
        Float64(coupling_under_relaxation),
        Int(progress_every),
        Int(status_every),
        allow_many_snapshots,
        allow_large_output,
    ))
end

native_resolved_fsi_partitioned_production_spec(; kwargs...) =
    NativeResolvedFSIPartitionedProductionSpec(; kwargs...)

function validate(spec::NativeResolvedFSIPartitionedProductionSpec)
    isfinite(spec.dt_s) || throw(ArgumentError("native resolved-FSI partitioned production dt_s must be finite"))
    spec.dt_s > 0.0 || throw(ArgumentError("native resolved-FSI partitioned production dt_s must be positive"))
    isfinite(spec.tfinal_s) || throw(ArgumentError("native resolved-FSI partitioned production tfinal_s must be finite"))
    spec.tfinal_s > 0.0 || throw(ArgumentError("native resolved-FSI partitioned production tfinal_s must be positive"))
    isfinite(spec.time_atol) || throw(ArgumentError("native resolved-FSI partitioned production time_atol must be finite"))
    spec.time_atol > 0.0 || throw(ArgumentError("native resolved-FSI partitioned production time_atol must be positive"))
    isempty(spec.snapshot_times_s) &&
        throw(ArgumentError("native resolved-FSI partitioned production snapshot_times_s must not be empty"))
    all(isfinite, spec.snapshot_times_s) ||
        throw(ArgumentError("native resolved-FSI partitioned production snapshot_times_s must be finite"))
    for time_s in spec.snapshot_times_s
        0.0 <= time_s <= spec.tfinal_s || throw(ArgumentError(
            "native resolved-FSI partitioned production snapshot time $(time_s) lies outside [0, $(spec.tfinal_s)]",
        ))
    end
    for index in 2:length(spec.snapshot_times_s)
        spec.snapshot_times_s[index] > spec.snapshot_times_s[index - 1] || throw(ArgumentError(
            "native resolved-FSI partitioned production snapshot_times_s must be strictly increasing without duplicates",
        ))
    end
    length(spec.snapshot_times_s) <= NATIVE_RESOLVED_FSI_PRODUCTION_MAX_SNAPSHOT_COUNT ||
        spec.allow_many_snapshots || throw(ArgumentError(
            "native resolved-FSI partitioned production requested $(length(spec.snapshot_times_s)) snapshots; set allow_many_snapshots=true to exceed $(NATIVE_RESOLVED_FSI_PRODUCTION_MAX_SNAPSHOT_COUNT)",
        ))
    native_resolved_fsi_production_boundary_mode(spec.inlet_outlet_boundary_mode)
    isfinite(spec.inlet_umax_cm_s) ||
        throw(ArgumentError("native resolved-FSI partitioned production inlet_umax_cm_s must be finite"))
    if spec.inlet_outlet_boundary_mode === :poiseuille_inlet_zero_outlet_stress_section41
        spec.inlet_umax_cm_s > 0.0 ||
            throw(ArgumentError("native resolved-FSI partitioned production inlet_umax_cm_s must be positive for exact Section 4.1 mode"))
    end
    isfinite(spec.pressure_drop_dyn_cm2) ||
        throw(ArgumentError("native resolved-FSI partitioned production pressure_drop_dyn_cm2 must be finite"))
    if spec.inlet_outlet_boundary_mode === :pressure_drop_weak_inlet_outlet_gauge_smoke
        spec.pressure_drop_dyn_cm2 > 0.0 ||
            throw(ArgumentError("native resolved-FSI partitioned production pressure_drop_dyn_cm2 must be positive"))
    end
    spec.picard_iteration_count > 0 ||
        throw(ArgumentError("native resolved-FSI partitioned production picard_iteration_count must be positive"))
    isfinite(spec.picard_tolerance) ||
        throw(ArgumentError("native resolved-FSI partitioned production picard_tolerance must be finite"))
    spec.picard_tolerance > 0.0 ||
        throw(ArgumentError("native resolved-FSI partitioned production picard_tolerance must be positive"))
    isfinite(spec.wall_density_g_cm3) ||
        throw(ArgumentError("native resolved-FSI partitioned production wall_density_g_cm3 must be finite"))
    spec.wall_density_g_cm3 > 0.0 ||
        throw(ArgumentError("native resolved-FSI partitioned production wall_density_g_cm3 must be positive"))
    isfinite(spec.wall_damping_g_cm2_s) ||
        throw(ArgumentError("native resolved-FSI partitioned production wall_damping_g_cm2_s must be finite"))
    spec.wall_damping_g_cm2_s >= 0.0 ||
        throw(ArgumentError("native resolved-FSI partitioned production wall_damping_g_cm2_s must be nonnegative"))
    spec.wall_stiffness_policy in NATIVE_RESOLVED_FSI_PRODUCTION_STIFFNESS_POLICIES || throw(ArgumentError(
        "native resolved-FSI partitioned production wall_stiffness_policy must be one of $(NATIVE_RESOLVED_FSI_PRODUCTION_STIFFNESS_POLICIES)",
    ))
    spec.wall_reference_radius_policy in NATIVE_RESOLVED_FSI_PRODUCTION_REFERENCE_RADIUS_POLICIES || throw(ArgumentError(
        "native resolved-FSI partitioned production wall_reference_radius_policy must be one of $(NATIVE_RESOLVED_FSI_PRODUCTION_REFERENCE_RADIUS_POLICIES)",
    ))
    spec.coupling_iteration_count > 0 ||
        throw(ArgumentError("native resolved-FSI partitioned production coupling_iteration_count must be positive"))
    isfinite(spec.coupling_tolerance) ||
        throw(ArgumentError("native resolved-FSI partitioned production coupling_tolerance must be finite"))
    spec.coupling_tolerance > 0.0 ||
        throw(ArgumentError("native resolved-FSI partitioned production coupling_tolerance must be positive"))
    isfinite(spec.coupling_under_relaxation) ||
        throw(ArgumentError("native resolved-FSI partitioned production coupling_under_relaxation must be finite"))
    0.0 < spec.coupling_under_relaxation <= 1.0 ||
        throw(ArgumentError("native resolved-FSI partitioned production coupling_under_relaxation must lie in (0, 1]"))
    spec.progress_every >= 0 ||
        throw(ArgumentError("native resolved-FSI partitioned production progress_every must be nonnegative"))
    spec.status_every > 0 ||
        throw(ArgumentError("native resolved-FSI partitioned production status_every must be positive"))

    estimated_bytes = native_resolved_fsi_partitioned_production_estimated_field_payload_bytes(spec)
    estimated_bytes <= NATIVE_RESOLVED_FSI_PRODUCTION_MAX_OUTPUT_BYTES ||
        spec.allow_large_output || throw(ArgumentError(
            "native resolved-FSI partitioned production estimated raw field payload $(estimated_bytes) bytes exceeds the $(NATIVE_RESOLVED_FSI_PRODUCTION_MAX_OUTPUT_BYTES)-byte cap; set allow_large_output=true to override",
        ))
    return spec
end

default_native_resolved_fsi_partitioned_production_output_root() =
    NATIVE_RESOLVED_FSI_PRODUCTION_DEFAULT_OUTPUT_ROOT

"""
    default_native_resolved_fsi_partitioned_production_output_dir(spec) -> String

Return the deterministic ignored scratch root for one native partitioned
production policy. This is an output contract for later production runners; it
does not imply production numerical parity or monolithic ALE coupling.
"""
function default_native_resolved_fsi_partitioned_production_output_dir(
    spec::NativeResolvedFSIPartitionedProductionSpec,
)
    root = isempty(spec.output_root) ? default_native_resolved_fsi_partitioned_production_output_root() : spec.output_root
    resolution = spec.resolution
    mesh_token = "$(resolution.axial)x$(resolution.radial)x$(resolution.angular)"
    snapshot_token = if length(spec.snapshot_times_s) == 1
        "snapshot-t$(path_token(only(spec.snapshot_times_s)))"
    else
        "snapshots-n$(length(spec.snapshot_times_s))-t$(path_token(first(spec.snapshot_times_s)))-to-t$(path_token(last(spec.snapshot_times_s)))"
    end
    boundary_token = if spec.inlet_outlet_boundary_mode === :poiseuille_inlet_zero_outlet_stress_section41
        "boundary-$(string(spec.inlet_outlet_boundary_mode))-umax$(path_token(spec.inlet_umax_cm_s))"
    else
        "boundary-$(string(spec.inlet_outlet_boundary_mode))"
    end
    return joinpath(
        root,
        string(spec.case_spec.case_id),
        mesh_token,
        boundary_token,
        "partitioned-production-dt$(path_token(spec.dt_s))-tfinal$(path_token(spec.tfinal_s))",
        snapshot_token,
    )
end

"""
    native_resolved_fsi_partitioned_production_sidecar_paths(spec)

Return the deterministic sidecar paths for one partitioned native production
spec. The paths describe observability and restart-identification artifacts;
they do not imply production parity or resumable checkpoint support.
"""
function native_resolved_fsi_partitioned_production_sidecar_paths(
    spec::NativeResolvedFSIPartitionedProductionSpec,
)
    output_dir = default_native_resolved_fsi_partitioned_production_output_dir(spec)
    return (
        output_dir=output_dir,
        manifest_csv=joinpath(output_dir, "snapshot_manifest.csv"),
        diagnostics_csv=joinpath(output_dir, "snapshot_diagnostics.csv"),
        restart_metadata_json=joinpath(output_dir, "restart_metadata.json"),
        batch_status_jsonl=joinpath(output_dir, "batch_status.jsonl"),
        batch_status_csv=joinpath(output_dir, "batch_status.csv"),
        batch_benchmark_json=joinpath(output_dir, "batch_benchmark.json"),
        batch_failure_json=joinpath(output_dir, "batch_failure.json"),
        checkpoint_dir=joinpath(output_dir, "checkpoint"),
    )
end

"""
    native_resolved_fsi_partitioned_production_snapshot_output_dirs(spec)

Return the resolved-3D bundle output directories in snapshot order.
Single-snapshot runs write directly into the production output directory; multi-
snapshot runs use one child directory per snapshot time.
"""
function native_resolved_fsi_partitioned_production_snapshot_output_dirs(
    spec::NativeResolvedFSIPartitionedProductionSpec,
)
    output_dir = default_native_resolved_fsi_partitioned_production_output_dir(spec)
    length(spec.snapshot_times_s) == 1 && return String[output_dir]
    return String[joinpath(output_dir, "snapshot-t$(path_token(snapshot_time_s))") for snapshot_time_s in spec.snapshot_times_s]
end

"""
    native_resolved_fsi_execution_layout(; parallel_workers, threads_per_worker, force_process)

Capture process/thread provenance for native resolved-FSI status artifacts. For
a single production solve this is metadata; multi-case scheduling is handled by
`run_native_resolved_fsi_partitioned_production_batch`.
"""
function native_resolved_fsi_execution_layout(;
    parallel_workers::Integer,
    threads_per_worker::Integer,
    force_process::Bool,
)
    parallel_workers >= 0 ||
        throw(ArgumentError("native resolved-FSI production parallel_workers must be nonnegative"))
    return (
        process_id=Distributed.myid(),
        thread_count=Threads.nthreads(),
        parallel_workers=Int(parallel_workers),
        threads_per_worker=validate_threads_per_worker(threads_per_worker),
        force_process=force_process,
    )
end

function native_resolved_fsi_partitioned_production_estimated_field_payload_bytes(
    spec::NativeResolvedFSIPartitionedProductionSpec,
)
    node_count =
        (BigInt(spec.resolution.axial) + 1) *
        (BigInt(1) + BigInt(spec.resolution.radial) * BigInt(spec.resolution.angular))
    return node_count * BigInt(7 * sizeof(Float64)) * BigInt(length(spec.snapshot_times_s))
end

function native_resolved_fsi_partitioned_production_estimated_time_step_count(
    spec::NativeResolvedFSIPartitionedProductionSpec,
)
    return ceil(Int, last(spec.snapshot_times_s) / spec.dt_s)
end

function native_resolved_fsi_partitioned_production_expected_tetrahedron_count(
    resolution::NativeResolvedFSIMeshResolution,
)
    return 3 * resolution.axial * resolution.angular * (2 * resolution.radial - 1)
end

function native_resolved_fsi_partitioned_production_estimated_runtime_s(
    spec::NativeResolvedFSIPartitionedProductionSpec,
)
    tetrahedra = native_resolved_fsi_partitioned_production_expected_tetrahedron_count(spec.resolution)
    steps = native_resolved_fsi_partitioned_production_estimated_time_step_count(spec)
    reference_work =
        NATIVE_RESOLVED_FSI_PRODUCTION_SEV23_DEVELOPMENT_REFERENCE_TETRAHEDRA *
        NATIVE_RESOLVED_FSI_PRODUCTION_SEV23_DEVELOPMENT_REFERENCE_STEPS
    work = tetrahedra * steps * max(spec.coupling_iteration_count, 1)
    return NATIVE_RESOLVED_FSI_PRODUCTION_SEV23_DEVELOPMENT_REFERENCE_WALL_TIME_S * work / reference_work
end

function native_resolved_fsi_partitioned_production_expected_fluid_solve_upper_bound(
    spec::NativeResolvedFSIPartitionedProductionSpec,
)
    steps = native_resolved_fsi_partitioned_production_estimated_time_step_count(spec)
    return steps * max(spec.coupling_iteration_count, 1) + length(spec.snapshot_times_s)
end

function native_resolved_fsi_partitioned_production_spec_digest(
    spec::NativeResolvedFSIPartitionedProductionSpec,
)
    resolution = spec.resolution
    parts = String[
        string(spec.case_spec.case_id),
        string(resolution.axial),
        string(resolution.radial),
        string(resolution.angular),
        spec.output_root,
        string(spec.dt_s),
        string(spec.tfinal_s),
        join(string.(spec.snapshot_times_s), ","),
        string(spec.inlet_outlet_boundary_mode),
        string(spec.inlet_umax_cm_s),
        string(spec.pressure_drop_dyn_cm2),
        string(spec.picard_iteration_count),
        string(spec.picard_tolerance),
        string(spec.wall_density_g_cm3),
        string(spec.wall_damping_g_cm2_s),
        string(spec.wall_stiffness_policy),
        string(spec.wall_reference_radius_policy),
        string(spec.coupling_iteration_count),
        string(spec.coupling_tolerance),
        string(spec.coupling_under_relaxation),
    ]
    return bytes2hex(sha256(join(parts, "|")))[1:16]
end

include("native_resolved_fsi_production_policy.jl")
include("native_resolved_fsi_restart_sidecars.jl")

"""
    NativeResolvedFSIPartitionedProductionResult

Wrapper returned by [`run_native_resolved_fsi_partitioned_production`](@ref).
It keeps the production control spec separate from the final carried
partitioned solver result and records bounded method/output/diagnostic/restart
statuses. The diagnostics and restart sidecars describe a state-carrying
partitioned snapshot series; durable checkpoints are limited to qualified
internal split-run resume and do not imply public/default process resume,
validated native resolved-FSI Section 4.1 reproduction, or monolithic ALE FSI coupling.
"""
struct NativeResolvedFSIPartitionedProductionResult
    spec::NativeResolvedFSIPartitionedProductionSpec
    smoke_spec
    smoke_result
    output_dir::String
    manifest_csv::String
    diagnostics_csv::String
    restart_metadata_json::String
    snapshot_results::Vector{NamedTuple}
    diagnostic_rows::Vector{NamedTuple}
    restart_metadata::Dict{String,Any}
    saved_time_s::Float64
    snapshot_times_s::Vector{Float64}
    output_status::NativeResolvedFSIWorkflowStatus
    method_status::NativeResolvedFSIWorkflowStatus
    diagnostics_status::NativeResolvedFSIWorkflowStatus
    restart_status::NativeResolvedFSIWorkflowStatus
end

"""
    NativeResolvedFSIProductionWorkflowPlan

One reproducible Section 4.1 native workflow plan. The contained
`workflow_spec` preserves the current schema-only bundle contract, while
`production_spec` records the partitioned production controls and output policy
that later runner lanes will execute. This plan does not claim production
numerical parity or monolithic ALE coupling.
"""
struct NativeResolvedFSIProductionWorkflowPlan
    case_spec::NativeResolvedFSICaseSpec
    workflow_spec::NativeResolvedFSIWorkflowSpec
    status::String
    production_spec::NativeResolvedFSIPartitionedProductionSpec
end

"""
    NativeResolvedFSIProductionDryRunPlan

Side-effect-free Section 4.1 production dry-run record. It resolves the native
production bundle paths, sidecar paths, estimated mesh/output size, and planned
imported parity case without running the production solver or writing files.
The guard fields report whether the plan fits the default production limits and
which explicit override flags are needed before a larger run is attempted.
"""
struct NativeResolvedFSIProductionDryRunPlan
    workflow_plan::NativeResolvedFSIProductionWorkflowPlan
    case_id::Symbol
    mesh_resolution::NativeResolvedFSIMeshResolution
    expected_node_count::Int
    expected_tetrahedron_count::Int
    snapshot_times_s::Vector{Float64}
    estimated_field_payload_bytes::BigInt
    snapshot_count_within_default_guard::Bool
    estimated_output_payload_within_default_guard::Bool
    required_override_flags::Vector{String}
    estimated_time_step_count::Int
    expected_fluid_solve_upper_bound::Int
    estimated_preproduction_runtime_s::Float64
    batch_status_jsonl::String
    batch_status_csv::String
    batch_benchmark_json::String
    batch_failure_json::String
    checkpoint_dir::String
    checkpoint_roles::Vector{String}
    production_spec_digest::String
    parallel_workers::Int
    threads_per_worker::Int
    force_process::Bool
    output_dir::String
    snapshot_output_dirs::Vector{String}
    manifest_csv::String
    diagnostics_csv::String
    restart_metadata_json::String
    parity_observations_csv::String
    parity_summary_csv::String
    boundary_mode::String
    boundary_mode_class::String
    inlet_condition_status::String
    outlet_condition_status::String
    pressure_gauge_status::String
    pressure_nullspace_status::String
    section41_boundary_status::String
    boundary_status::String
    boundary_equivalence_status::String
    wall_stability_status::String
    imported_case
    imported_available::Bool
    status::String
end

function NativeResolvedFSIProductionWorkflowPlan(
    case_spec::NativeResolvedFSICaseSpec,
    workflow_spec::NativeResolvedFSIWorkflowSpec,
    status::AbstractString,
)
    output_root = isempty(workflow_spec.output_dir) ? "" : dirname(workflow_spec.output_dir)
    production_spec = NativeResolvedFSIPartitionedProductionSpec(
        case_id=case_spec.case_id,
        resolution=workflow_spec.resolution,
        output_root=output_root,
        tfinal_s=workflow_spec.output_time_s,
        snapshot_times_s=(workflow_spec.output_time_s,),
        time_atol=workflow_spec.time_atol,
        overwrite=workflow_spec.overwrite,
        inlet_outlet_boundary_mode=NATIVE_RESOLVED_FSI_PRODUCTION_DEFAULT_INLET_OUTLET_BOUNDARY_MODE,
        inlet_umax_cm_s=workflow_spec.inlet_umax_cm_s,
        pressure_drop_dyn_cm2=workflow_spec.pressure_drop_dyn_cm2,
    )
    return NativeResolvedFSIProductionWorkflowPlan(case_spec, workflow_spec, String(status), production_spec)
end

"""
    native_resolved_fsi_production_workflow_plans(; kwargs...)

Build deterministic Section 4.1 native workflow plans for `sev23`, `sev40`,
and `sev50`. The plans keep the benchmark case/time contracts and production
output policy explicit while making clear that this lane adds controls rather
than a stronger numerical method by itself.
"""
function native_resolved_fsi_production_workflow_plans(;
    case_ids = SECTION41_NATIVE_CASE_IDS,
    resolution::NativeResolvedFSIMeshResolution = NativeResolvedFSIMeshResolution(),
    output_root::AbstractString = "",
    output_time_s::Real = NATIVE_RESOLVED_FSI_DEFAULT_TIME_S,
    dt_s::Real = NATIVE_RESOLVED_FSI_PARTITIONED_PRODUCTION_DEFAULT_DT_S,
    tfinal_s::Real = output_time_s,
    snapshot_times_s = (tfinal_s,),
    time_atol::Real = 1.0e-12,
    overwrite::Bool = false,
    inlet_outlet_boundary_mode::Union{Symbol,AbstractString} = NATIVE_RESOLVED_FSI_PRODUCTION_DEFAULT_INLET_OUTLET_BOUNDARY_MODE,
    inlet_umax_cm_s::Real = 45.0,
    pressure_drop_dyn_cm2::Real = 40.0,
    picard_iteration_count::Integer = NATIVE_RESOLVED_FSI_PARTITIONED_PRODUCTION_DEFAULT_PICARD_ITERATION_COUNT,
    picard_tolerance::Real = NATIVE_RESOLVED_FSI_PARTITIONED_PRODUCTION_DEFAULT_PICARD_TOLERANCE,
    wall_density_g_cm3::Real = NATIVE_RESOLVED_FSI_PARTITIONED_PRODUCTION_DEFAULT_WALL_DENSITY_G_CM3,
    wall_damping_g_cm2_s::Real = NATIVE_RESOLVED_FSI_PARTITIONED_PRODUCTION_DEFAULT_WALL_DAMPING_G_CM2_S,
    wall_stiffness_policy::Union{Symbol,AbstractString} = :canic_membrane_c0,
    wall_reference_radius_policy::Union{Symbol,AbstractString} = :params_rmax,
    coupling_iteration_count::Integer = 1,
    coupling_tolerance::Real = 1.0e-8,
    coupling_under_relaxation::Real = 1.0,
    progress_every::Integer = 0,
    status_every::Integer = 1,
    allow_many_snapshots::Bool = false,
    allow_large_output::Bool = false,
    displacement_mode::Union{Symbol,AbstractString} = :synthetic_radial_lift,
    synthetic_lift_amplitude_cm::Real = 0.002,
)
    root = String(output_root)
    mode = native_resolved_fsi_displacement_mode(displacement_mode)
    plans = NativeResolvedFSIProductionWorkflowPlan[]
    for case_id in case_ids
        case_spec = native_resolved_fsi_case_spec(case_id)
        production_spec = NativeResolvedFSIPartitionedProductionSpec(
            case_id=case_spec.case_id,
            resolution=resolution,
            output_root=root,
            dt_s=dt_s,
            tfinal_s=tfinal_s,
            snapshot_times_s=snapshot_times_s,
            time_atol=time_atol,
            overwrite=overwrite,
            inlet_outlet_boundary_mode=inlet_outlet_boundary_mode,
            inlet_umax_cm_s=inlet_umax_cm_s,
            pressure_drop_dyn_cm2=pressure_drop_dyn_cm2,
            picard_iteration_count=picard_iteration_count,
            picard_tolerance=picard_tolerance,
            wall_density_g_cm3=wall_density_g_cm3,
            wall_damping_g_cm2_s=wall_damping_g_cm2_s,
            wall_stiffness_policy=wall_stiffness_policy,
            wall_reference_radius_policy=wall_reference_radius_policy,
            coupling_iteration_count=coupling_iteration_count,
            coupling_tolerance=coupling_tolerance,
            coupling_under_relaxation=coupling_under_relaxation,
            progress_every=progress_every,
            status_every=status_every,
            allow_many_snapshots=allow_many_snapshots,
            allow_large_output=allow_large_output,
        )
        workflow_spec = NativeResolvedFSIWorkflowSpec(
            case_id=case_spec.case_id,
            resolution=resolution,
            output_dir=isempty(root) ? "" : joinpath(root, string(case_spec.case_id)),
            output_time_s=last(production_spec.snapshot_times_s),
            time_atol=time_atol,
            overwrite=overwrite,
            inlet_umax_cm_s=inlet_umax_cm_s,
            pressure_drop_dyn_cm2=pressure_drop_dyn_cm2,
            displacement_mode=mode,
            synthetic_lift_amplitude_cm=synthetic_lift_amplitude_cm,
        )
        boundary_status = native_resolved_fsi_boundary_status_fields(
            production_spec.inlet_outlet_boundary_mode;
            inlet_umax_cm_s=production_spec.inlet_umax_cm_s,
        )
        status = native_resolved_fsi_production_plan_status(case_spec, production_spec, boundary_status)
        push!(plans, NativeResolvedFSIProductionWorkflowPlan(case_spec, workflow_spec, status, production_spec))
    end
    return plans
end

"""
    native_resolved_fsi_partitioned_production_dry_run(plan; imported_data_root=default_resolved3d_data_root())

Resolve the output and parity artifact contract for one Section 4.1 production
workflow plan without running the native production solver and without writing
any files. High-resolution execution remains gated by explicit production
specs and their normal output-volume validation/overrides.
"""
function native_resolved_fsi_partitioned_production_dry_run(
    plan::NativeResolvedFSIProductionWorkflowPlan;
    imported_data_root::AbstractString = default_resolved3d_data_root(),
    parallel_workers::Integer = default_case_workers(),
    threads_per_worker::Integer = 1,
    force_process::Bool = false,
)
    spec = validate(plan.production_spec)
    parallel_workers >= 0 || throw(ArgumentError("native resolved-FSI dry-run parallel_workers must be nonnegative"))
    requested_threads_per_worker = validate_threads_per_worker(threads_per_worker)
    resolution = spec.resolution
    paths = native_resolved_fsi_partitioned_production_sidecar_paths(spec)
    output_dir = paths.output_dir
    snapshot_output_dirs = native_resolved_fsi_partitioned_production_snapshot_output_dirs(spec)
    parity_plan = only(native_resolved_fsi_production_parity_plans(
        workflow_plans=[plan],
        imported_data_root=String(imported_data_root),
    ))
    expected_node_count = (resolution.axial + 1) * (1 + resolution.radial * resolution.angular)
    expected_tetrahedron_count = native_resolved_fsi_partitioned_production_expected_tetrahedron_count(resolution)
    estimated_time_step_count = native_resolved_fsi_partitioned_production_estimated_time_step_count(spec)
    expected_fluid_solve_upper_bound =
        native_resolved_fsi_partitioned_production_expected_fluid_solve_upper_bound(spec)
    estimated_preproduction_runtime_s = native_resolved_fsi_partitioned_production_estimated_runtime_s(spec)
    guard_report = native_resolved_fsi_partitioned_production_default_guard_report(spec)
    boundary_status = native_resolved_fsi_boundary_status_fields(
        spec.inlet_outlet_boundary_mode;
        inlet_umax_cm_s=spec.inlet_umax_cm_s,
    )
    boundary_equivalence_status = native_resolved_fsi_boundary_equivalence_status(boundary_status)
    pressure_nullspace_status = native_resolved_fsi_pressure_nullspace_status(spec.inlet_outlet_boundary_mode)
    wall_stability_status = native_resolved_fsi_partitioned_wall_stability_status(spec)
    override_status = isempty(guard_report.required_override_flags) ?
        "default guards satisfied; required override flags: none" :
        "default guards would block production without required override flags: $(join(guard_report.required_override_flags, ", "))"
    imported_status = parity_plan.imported_available ? "imported bundle available" : "imported bundle expected-skip"
    layout_status =
        "requested process/thread layout: parallel_workers=$(Int(parallel_workers)), " *
        "threads_per_worker=$(requested_threads_per_worker), force_process=$(force_process)"
    status = native_resolved_fsi_partitioned_production_dry_run_status(
        spec;
        layout_status=layout_status,
        override_status=override_status,
        imported_status=imported_status,
        boundary_status=boundary_status,
        pressure_nullspace_status=pressure_nullspace_status,
        wall_stability_status=wall_stability_status,
    )
    return NativeResolvedFSIProductionDryRunPlan(
        plan,
        spec.case_spec.case_id,
        resolution,
        expected_node_count,
        expected_tetrahedron_count,
        copy(spec.snapshot_times_s),
        guard_report.estimated_field_payload_bytes,
        guard_report.snapshot_count_within_default_guard,
        guard_report.estimated_output_payload_within_default_guard,
        copy(guard_report.required_override_flags),
        estimated_time_step_count,
        expected_fluid_solve_upper_bound,
        estimated_preproduction_runtime_s,
        paths.batch_status_jsonl,
        paths.batch_status_csv,
        paths.batch_benchmark_json,
        paths.batch_failure_json,
        paths.checkpoint_dir,
        collect(String, NATIVE_RESOLVED_FSI_PRODUCTION_CHECKPOINT_ROLES),
        native_resolved_fsi_partitioned_production_spec_digest(spec),
        Int(parallel_workers),
        requested_threads_per_worker,
        force_process,
        output_dir,
        snapshot_output_dirs,
        paths.manifest_csv,
        paths.diagnostics_csv,
        paths.restart_metadata_json,
        native_resolved_fsi_production_parity_observations_csv(parity_plan),
        native_resolved_fsi_production_parity_summary_csv(parity_plan),
        boundary_status.boundary_mode,
        boundary_status.boundary_mode_class,
        boundary_status.inlet_condition_status,
        boundary_status.outlet_condition_status,
        boundary_status.pressure_gauge_status,
        pressure_nullspace_status,
        boundary_status.section41_boundary_status,
        boundary_status.boundary_status,
        boundary_equivalence_status,
        wall_stability_status,
        parity_plan.imported_case,
        parity_plan.imported_available,
        status,
    )
end

"""
    run_native_resolved_fsi_partitioned_production(spec; parallel_workers=1,
                                                   threads_per_worker=Threads.nthreads(),
                                                   force_process=false)

Run the production-depth partitioned native snapshot harness by advancing one
coarse partitioned state through each requested positive snapshot time. The
driver carries reduced wall displacement, wall velocity, current radii, wall
pressure, coupling residual history, and fluid free-DOF state between steps.
It writes one normal resolved-3D bundle per snapshot plus a compact CSV
manifest, per-snapshot diagnostics CSV, and restart-identification metadata.
The process/thread keywords are recorded in status sidecars for provenance; they
do not schedule multiple specs. Qualified internal restart/resume callers may
seed the state-carrying runner from durable checkpoint sidecars, but no default
CLI path exposes resume.
"""
function run_native_resolved_fsi_partitioned_production(
    spec::NativeResolvedFSIPartitionedProductionSpec;
    parallel_workers::Integer = 1,
    threads_per_worker::Integer = Threads.nthreads(),
    force_process::Bool = false,
    _resume_checkpoint_path = nothing,
    _qualified_internal_resume::Bool = false,
    _internal_stop_after_snapshot_index = nothing,
)
    execution_layout = native_resolved_fsi_execution_layout(
        parallel_workers=parallel_workers,
        threads_per_worker=threads_per_worker,
        force_process=force_process,
    )
    resume_context = nothing
    if _resume_checkpoint_path !== nothing
        _qualified_internal_resume || throw(ArgumentError(
            "native resolved-FSI checkpoint resume requires qualified internal split-run resume approval",
        ))
        resume_context = native_resolved_fsi_restart_resume_context(String(_resume_checkpoint_path), spec)
    end
    internal_stop_after_snapshot_index = if _internal_stop_after_snapshot_index === nothing
        nothing
    else
        _qualified_internal_resume || throw(ArgumentError(
            "native resolved-FSI prefix checkpoint stops require qualified internal split-run resume approval",
        ))
        Int(_internal_stop_after_snapshot_index)
    end
    resume_context !== nothing && internal_stop_after_snapshot_index !== nothing && throw(ArgumentError(
        "native resolved-FSI production cannot combine checkpoint resume with an internal stop-after snapshot limit",
    ))

    function validate_runner_scope(local_spec::NativeResolvedFSIPartitionedProductionSpec)
        if any(time_s -> time_s <= 0.0, local_spec.snapshot_times_s)
            throw(ArgumentError(
                "native resolved-FSI partitioned production runner requires positive snapshot times; t=0 initial-condition bundle output is not implemented",
            ))
        end
        if internal_stop_after_snapshot_index !== nothing
            1 <= internal_stop_after_snapshot_index <= length(local_spec.snapshot_times_s) || throw(ArgumentError(
                "native resolved-FSI internal stop-after snapshot index must be within the requested snapshot schedule",
            ))
        end
        if resume_context !== nothing
            resume_context.next_snapshot_index <= length(local_spec.snapshot_times_s) || throw(ArgumentError(
                "native resolved-FSI checkpoint resume has no pending snapshots in the requested schedule",
            ))
        end
        return local_spec
    end

    function production_canonical_path(path::String)
        normalized = normpath(abspath(path))
        while length(normalized) > 1 && (endswith(normalized, "/") || endswith(normalized, "\\"))
            normalized = normalized[begin:prevind(normalized, lastindex(normalized))]
        end
        return normalized
    end

    production_repo_root() =
        production_canonical_path(joinpath(@__DIR__, "..", "..", "..", "..", "..", ".."))

    function production_same_or_descendant(path::String, parent::String)
        rel = relpath(production_canonical_path(path), production_canonical_path(parent))
        return rel == "." || !(rel == ".." || startswith(rel, "../") || startswith(rel, "..\\") || isabspath(rel))
    end

    function assert_production_output_path(output_dir::String)
        output_abs = production_canonical_path(output_dir)
        repo_root = production_repo_root()
        output_abs == repo_root && throw(ArgumentError(
            "refusing to use protected repository root as native resolved-FSI production output_dir: $output_dir",
        ))
        protected_roots = (
            joinpath(repo_root, "packages", "stenotic-hemodynamics", "src"),
            joinpath(repo_root, "packages", "stenotic-hemodynamics", "test"),
            joinpath(repo_root, "packages", "ops", "src"),
            joinpath(repo_root, "packages", "ops", "tests"),
            joinpath(repo_root, "public", "docs"),
            joinpath(repo_root, "public", "references"),
            joinpath(repo_root, "public", "reproducibility"),
            joinpath(repo_root, "public", "var", "data", "simulations"),
            joinpath(repo_root, "report"),
        )
        for protected in protected_roots
            if production_same_or_descendant(output_abs, protected)
                throw(ArgumentError(
                    "refusing to use protected repository path as native resolved-FSI production output_dir: $output_dir",
                ))
            end
        end
        return output_dir
    end

    function snapshot_output_dir(local_spec::NativeResolvedFSIPartitionedProductionSpec, snapshot_time_s::Float64)
        output_dir = default_native_resolved_fsi_partitioned_production_output_dir(local_spec)
        length(local_spec.snapshot_times_s) == 1 && return output_dir
        return joinpath(output_dir, "snapshot-t$(path_token(snapshot_time_s))")
    end

    manifest_path(local_spec::NativeResolvedFSIPartitionedProductionSpec) =
        native_resolved_fsi_partitioned_production_sidecar_paths(local_spec).manifest_csv

    diagnostics_path(local_spec::NativeResolvedFSIPartitionedProductionSpec) =
        native_resolved_fsi_partitioned_production_sidecar_paths(local_spec).diagnostics_csv

    restart_metadata_path(local_spec::NativeResolvedFSIPartitionedProductionSpec) =
        native_resolved_fsi_partitioned_production_sidecar_paths(local_spec).restart_metadata_json

    batch_status_jsonl_path(local_spec::NativeResolvedFSIPartitionedProductionSpec) =
        native_resolved_fsi_partitioned_production_sidecar_paths(local_spec).batch_status_jsonl

    batch_status_csv_path(local_spec::NativeResolvedFSIPartitionedProductionSpec) =
        native_resolved_fsi_partitioned_production_sidecar_paths(local_spec).batch_status_csv

    batch_benchmark_path(local_spec::NativeResolvedFSIPartitionedProductionSpec) =
        native_resolved_fsi_partitioned_production_sidecar_paths(local_spec).batch_benchmark_json

    batch_failure_path(local_spec::NativeResolvedFSIPartitionedProductionSpec) =
        native_resolved_fsi_partitioned_production_sidecar_paths(local_spec).batch_failure_json

    function checkpoint_sidecar_paths(local_spec::NativeResolvedFSIPartitionedProductionSpec)
        checkpoint_dir = native_resolved_fsi_partitioned_production_sidecar_paths(local_spec).checkpoint_dir
        return String[
            joinpath(checkpoint_dir, "wall_state.json"),
            joinpath(checkpoint_dir, "mesh_identity.json"),
            joinpath(checkpoint_dir, "fluid_state.json"),
            joinpath(checkpoint_dir, "coupling_state.json"),
            joinpath(checkpoint_dir, "output_linkage.json"),
        ]
    end

    function snapshot_bundle_paths(local_spec::NativeResolvedFSIPartitionedProductionSpec)
        paths = String[]
        for snapshot_time_s in local_spec.snapshot_times_s
            output_dir = snapshot_output_dir(local_spec, snapshot_time_s)
            append!(paths, String[
                joinpath(output_dir, NATIVE_RESOLVED_FSI_DEFAULT_MESH_H5),
                joinpath(output_dir, NATIVE_RESOLVED_FSI_DEFAULT_VELOCITY_XDMF),
                joinpath(output_dir, NATIVE_RESOLVED_FSI_DEFAULT_VELOCITY_H5),
                joinpath(output_dir, NATIVE_RESOLVED_FSI_DEFAULT_PRESSURE_XDMF),
                joinpath(output_dir, NATIVE_RESOLVED_FSI_DEFAULT_PRESSURE_H5),
                joinpath(output_dir, NATIVE_RESOLVED_FSI_DEFAULT_DISPLACEMENT_XDMF),
                joinpath(output_dir, NATIVE_RESOLVED_FSI_DEFAULT_DISPLACEMENT_H5),
            ])
        end
        return paths
    end

    function preflight_production_outputs(local_spec::NativeResolvedFSIPartitionedProductionSpec)
        output_dir = default_native_resolved_fsi_partitioned_production_output_dir(local_spec)
        assert_production_output_path(output_dir)
        isfile(output_dir) && throw(ArgumentError(
            "native resolved-FSI production output path exists and is not a directory: $output_dir",
        ))
        if isdir(output_dir) && !local_spec.overwrite
            throw(ArgumentError(
                "native resolved-FSI production output directory exists; pass overwrite=true to replace workflow-owned files: $output_dir",
            ))
        end
        paths = vcat(
            String[
                manifest_path(local_spec),
                diagnostics_path(local_spec),
                restart_metadata_path(local_spec),
                batch_status_jsonl_path(local_spec),
                batch_status_csv_path(local_spec),
                batch_benchmark_path(local_spec),
                batch_failure_path(local_spec),
            ],
            snapshot_bundle_paths(local_spec),
            checkpoint_sidecar_paths(local_spec),
        )
        for path in paths
            if (isfile(path) || isdir(path)) && !local_spec.overwrite
                throw(ArgumentError(
                    "native resolved-FSI production output exists before solve; pass overwrite=true to replace workflow-owned output: $path",
                ))
            end
        end
        return output_dir
    end

    batch_status_header() = (
        "event",
        "status",
        "case_id",
        "time_step_index",
        "expected_time_step_count",
        "snapshot_time_s",
        "physical_time_s",
        "dt_s",
        "elapsed_s",
        "estimated_remaining_s",
        "maxrss_bytes",
        "process_id",
        "thread_count",
        "parallel_workers",
        "threads_per_worker",
        "force_process",
        "minimum_current_radius_cm",
        "minimum_signed_tetra_volume6",
        "field_finite_status",
        "final_coupling_displacement_residual_cm",
        "step_coupling_converged",
        "coupling_converged",
        "max_coupling_iterations_used",
        "pressure_projection_fallback_count",
        "fluid_wall_boundary_mode",
        "inlet_outlet_boundary_mode",
        "production_spec_digest",
        "gridap_rebuild_status",
        "gridap_reuse_status",
        "gridap_reuse_miss_reason",
        "gridap_operator_component_status",
        "gridap_operator_component_terms",
        "gridap_solver_backend_status",
        "gridap_context_reused",
        "gridap_model_reused",
        "gridap_fe_spaces_reused",
        "gridap_measures_reused",
        "gridap_matrix_structure_stable",
        "gridap_symbolic_factorization_eligible",
        "gridap_symbolic_factorization_reused",
        "gridap_symbolic_factorization_cache_status",
        "gridap_symbolic_factorization_setup_count",
        "gridap_symbolic_factorization_reuse_count",
        "gridap_numeric_factorization_reused",
        "gridap_numeric_factorization_cache_status",
        "gridap_numeric_factorization_cache_key",
        "gridap_numeric_factorization_matrix_value_digest",
        "gridap_numeric_factorization_setup_count",
        "gridap_numeric_factorization_reuse_count",
        "gridap_reuse_reason_codes",
        "gridap_mesh_topology_digest",
        "gridap_coordinate_value_digest",
        "gridap_matrix_value_baseline_digest",
        "gridap_matrix_value_digest_observation_count",
        "gridap_matrix_value_digest_unique_count",
        "gridap_matrix_value_digest_current_count",
        "gridap_matrix_value_digest_repeat_count",
        "gridap_matrix_value_digest_history_tail",
        "gridap_reuse_boundary_mode",
        "gridap_reuse_quadrature_degree",
        "gridap_reuse_matrix_rows",
        "gridap_reuse_matrix_cols",
        "gridap_reuse_matrix_nnz",
        "gridap_matrix_rows",
        "gridap_matrix_cols",
        "gridap_matrix_nnz",
        "gridap_matrix_structure_digest",
        "gridap_matrix_value_digest",
        "gridap_rhs_digest",
        "gridap_boundary_mode",
        "gridap_pressure_constraint",
        "gridap_pressure_reference",
        "gridap_wall_boundary_mode",
        "gridap_quadrature_degree",
        "gridap_quadrature_sensitivity_degree",
        "gridap_quadrature_sensitivity_matrix_relative_change",
        "gridap_quadrature_sensitivity_rhs_relative_change",
        "gridap_quadrature_sensitivity_status",
        "gridap_open_boundary_status",
        "gridap_outlet_node_count",
        "gridap_outlet_velocity_sampling_fallback_count",
        "gridap_outlet_backflow_node_count",
        "gridap_outlet_normal_velocity_min_cm_s",
        "gridap_outlet_normal_velocity_max_cm_s",
        "gridap_outlet_normal_velocity_mean_cm_s",
        "gridap_dt_s",
        "gridap_time_step_index",
        "gridap_picard_iteration",
        "gridap_linear_solve_count",
        "gridap_rebuild_count",
        "gridap_model_setup_s",
        "gridap_space_setup_s",
        "gridap_measure_setup_s",
        "gridap_operator_assembly_s",
        "gridap_affine_operator_s",
        "gridap_matrix_extraction_s",
        "gridap_rhs_extraction_s",
        "linear_symbolic_factorization_s",
        "linear_numeric_factorization_s",
        "linear_backsolve_s",
        "fluid_solve_total_s",
        "wall_pressure_sampling_s",
        "wall_update_s",
        "diagnostics_s",
        "checkpoint_output_s",
        "output_write_s",
        "step_total_s",
        "output_dir",
        "snapshot_manifest_csv",
        "snapshot_diagnostics_csv",
        "restart_metadata_json",
        "batch_status_jsonl",
        "batch_status_csv",
        "batch_benchmark_json",
        "batch_failure_json",
        "message",
    )

    function prepare_batch_status_sidecars(local_spec::NativeResolvedFSIPartitionedProductionSpec)
        status_jsonl = batch_status_jsonl_path(local_spec)
        status_csv = batch_status_csv_path(local_spec)
        if local_spec.overwrite
            isfile(batch_benchmark_path(local_spec)) && rm(batch_benchmark_path(local_spec); force=true)
            isfile(batch_failure_path(local_spec)) && rm(batch_failure_path(local_spec); force=true)
        end
        guarded_open_write(status_jsonl, local_spec.overwrite) do io
            write(io, "")
        end
        guarded_open_write(status_csv, local_spec.overwrite) do io
            println(io, csv_record(batch_status_header()))
        end
        return (status_jsonl=status_jsonl, status_csv=status_csv)
    end

    function batch_memory_bytes()
        return try
            isdefined(Sys, :maxrss) ? Int(Sys.maxrss()) : 0
        catch
            0
        end
    end

    batch_event_value(event::NamedTuple, key::Symbol, default) =
        haskey(event, key) ? getfield(event, key) : default

    function batch_status_row(
        local_spec::NativeResolvedFSIPartitionedProductionSpec,
        event::NamedTuple,
        start_ns::UInt64,
    )
        step_index = batch_event_value(event, :time_step_index, 0)
        expected_steps = batch_event_value(
            event,
            :expected_time_step_count,
            native_resolved_fsi_partitioned_production_estimated_time_step_count(local_spec),
        )
        elapsed_s = telemetry_elapsed_s(start_ns)
        estimated_remaining_s =
            step_index > 0 && expected_steps >= step_index ?
            round(elapsed_s * (expected_steps - step_index) / step_index; digits=6) :
            NaN
        phase_timing = batch_event_value(event, :phase_timing_s, native_resolved_fsi_empty_phase_timing())
        solver_diagnostics =
            batch_event_value(event, :solver_diagnostics, native_resolved_fsi_empty_solver_diagnostics())
        return (
            event=string(batch_event_value(event, :event, "status")),
            status=string(batch_event_value(event, :status, "running")),
            case_id=string(local_spec.case_spec.case_id),
            time_step_index=step_index,
            expected_time_step_count=expected_steps,
            snapshot_time_s=batch_event_value(event, :snapshot_time_s, NaN),
            physical_time_s=batch_event_value(event, :time_s, NaN),
            dt_s=batch_event_value(event, :dt_s, NaN),
            elapsed_s=elapsed_s,
            estimated_remaining_s=estimated_remaining_s,
            maxrss_bytes=batch_memory_bytes(),
            process_id=execution_layout.process_id,
            thread_count=execution_layout.thread_count,
            parallel_workers=execution_layout.parallel_workers,
            threads_per_worker=execution_layout.threads_per_worker,
            force_process=execution_layout.force_process,
            minimum_current_radius_cm=batch_event_value(event, :minimum_current_radius_cm, NaN),
            minimum_signed_tetra_volume6=batch_event_value(event, :minimum_signed_tetra_volume6, NaN),
            field_finite_status=string(batch_event_value(event, :field_finite_status, "unknown")),
            final_coupling_displacement_residual_cm=
                batch_event_value(event, :final_coupling_displacement_residual_cm, NaN),
            step_coupling_converged=batch_event_value(event, :step_coupling_converged, false),
            coupling_converged=batch_event_value(event, :coupling_converged, false),
            max_coupling_iterations_used=batch_event_value(event, :max_coupling_iterations_used, 0),
            pressure_projection_fallback_count=batch_event_value(event, :pressure_projection_fallback_count, 0),
            fluid_wall_boundary_mode=string(batch_event_value(event, :fluid_wall_boundary_mode, "")),
            inlet_outlet_boundary_mode=string(batch_event_value(
                event,
                :inlet_outlet_boundary_mode,
                string(local_spec.inlet_outlet_boundary_mode),
            )),
            production_spec_digest=native_resolved_fsi_partitioned_production_spec_digest(local_spec),
            gridap_rebuild_status=solver_diagnostics.gridap_rebuild_status,
            gridap_reuse_status=solver_diagnostics.gridap_reuse_status,
            gridap_reuse_miss_reason=solver_diagnostics.gridap_reuse_miss_reason,
            gridap_operator_component_status=solver_diagnostics.gridap_operator_component_status,
            gridap_operator_component_terms=solver_diagnostics.gridap_operator_component_terms,
            gridap_solver_backend_status=solver_diagnostics.gridap_solver_backend_status,
            gridap_context_reused=solver_diagnostics.gridap_context_reused,
            gridap_model_reused=solver_diagnostics.gridap_model_reused,
            gridap_fe_spaces_reused=solver_diagnostics.gridap_fe_spaces_reused,
            gridap_measures_reused=solver_diagnostics.gridap_measures_reused,
            gridap_matrix_structure_stable=solver_diagnostics.gridap_matrix_structure_stable,
            gridap_symbolic_factorization_eligible=solver_diagnostics.gridap_symbolic_factorization_eligible,
            gridap_symbolic_factorization_reused=solver_diagnostics.gridap_symbolic_factorization_reused,
            gridap_symbolic_factorization_cache_status=
                solver_diagnostics.gridap_symbolic_factorization_cache_status,
            gridap_symbolic_factorization_setup_count=
                solver_diagnostics.gridap_symbolic_factorization_setup_count,
            gridap_symbolic_factorization_reuse_count=
                solver_diagnostics.gridap_symbolic_factorization_reuse_count,
            gridap_numeric_factorization_reused=solver_diagnostics.gridap_numeric_factorization_reused,
            gridap_numeric_factorization_cache_status=
                solver_diagnostics.gridap_numeric_factorization_cache_status,
            gridap_numeric_factorization_cache_key=solver_diagnostics.gridap_numeric_factorization_cache_key,
            gridap_numeric_factorization_matrix_value_digest=
                solver_diagnostics.gridap_numeric_factorization_matrix_value_digest,
            gridap_numeric_factorization_setup_count=
                solver_diagnostics.gridap_numeric_factorization_setup_count,
            gridap_numeric_factorization_reuse_count=
                solver_diagnostics.gridap_numeric_factorization_reuse_count,
            gridap_reuse_reason_codes=solver_diagnostics.gridap_reuse_reason_codes,
            gridap_mesh_topology_digest=solver_diagnostics.gridap_mesh_topology_digest,
            gridap_coordinate_value_digest=solver_diagnostics.gridap_coordinate_value_digest,
            gridap_matrix_value_baseline_digest=solver_diagnostics.gridap_matrix_value_baseline_digest,
            gridap_matrix_value_digest_observation_count=
                solver_diagnostics.gridap_matrix_value_digest_observation_count,
            gridap_matrix_value_digest_unique_count=solver_diagnostics.gridap_matrix_value_digest_unique_count,
            gridap_matrix_value_digest_current_count=solver_diagnostics.gridap_matrix_value_digest_current_count,
            gridap_matrix_value_digest_repeat_count=solver_diagnostics.gridap_matrix_value_digest_repeat_count,
            gridap_matrix_value_digest_history_tail=solver_diagnostics.gridap_matrix_value_digest_history_tail,
            gridap_reuse_boundary_mode=solver_diagnostics.gridap_reuse_boundary_mode,
            gridap_reuse_quadrature_degree=solver_diagnostics.gridap_reuse_quadrature_degree,
            gridap_reuse_matrix_rows=solver_diagnostics.gridap_reuse_matrix_rows,
            gridap_reuse_matrix_cols=solver_diagnostics.gridap_reuse_matrix_cols,
            gridap_reuse_matrix_nnz=solver_diagnostics.gridap_reuse_matrix_nnz,
            gridap_matrix_rows=solver_diagnostics.gridap_matrix_rows,
            gridap_matrix_cols=solver_diagnostics.gridap_matrix_cols,
            gridap_matrix_nnz=solver_diagnostics.gridap_matrix_nnz,
            gridap_matrix_structure_digest=solver_diagnostics.gridap_matrix_structure_digest,
            gridap_matrix_value_digest=solver_diagnostics.gridap_matrix_value_digest,
            gridap_rhs_digest=solver_diagnostics.gridap_rhs_digest,
            gridap_boundary_mode=solver_diagnostics.gridap_boundary_mode,
            gridap_pressure_constraint=solver_diagnostics.gridap_pressure_constraint,
            gridap_pressure_reference=solver_diagnostics.gridap_pressure_reference,
            gridap_wall_boundary_mode=solver_diagnostics.gridap_wall_boundary_mode,
            gridap_quadrature_degree=solver_diagnostics.gridap_quadrature_degree,
            gridap_quadrature_sensitivity_degree=solver_diagnostics.gridap_quadrature_sensitivity_degree,
            gridap_quadrature_sensitivity_matrix_relative_change=
                solver_diagnostics.gridap_quadrature_sensitivity_matrix_relative_change,
            gridap_quadrature_sensitivity_rhs_relative_change=
                solver_diagnostics.gridap_quadrature_sensitivity_rhs_relative_change,
            gridap_quadrature_sensitivity_status=solver_diagnostics.gridap_quadrature_sensitivity_status,
            gridap_open_boundary_status=solver_diagnostics.gridap_open_boundary_status,
            gridap_outlet_node_count=solver_diagnostics.gridap_outlet_node_count,
            gridap_outlet_velocity_sampling_fallback_count=
                solver_diagnostics.gridap_outlet_velocity_sampling_fallback_count,
            gridap_outlet_backflow_node_count=solver_diagnostics.gridap_outlet_backflow_node_count,
            gridap_outlet_normal_velocity_min_cm_s=solver_diagnostics.gridap_outlet_normal_velocity_min_cm_s,
            gridap_outlet_normal_velocity_max_cm_s=solver_diagnostics.gridap_outlet_normal_velocity_max_cm_s,
            gridap_outlet_normal_velocity_mean_cm_s=solver_diagnostics.gridap_outlet_normal_velocity_mean_cm_s,
            gridap_dt_s=solver_diagnostics.gridap_dt_s,
            gridap_time_step_index=solver_diagnostics.gridap_time_step_index,
            gridap_picard_iteration=solver_diagnostics.gridap_picard_iteration,
            gridap_linear_solve_count=solver_diagnostics.gridap_linear_solve_count,
            gridap_rebuild_count=solver_diagnostics.gridap_rebuild_count,
            gridap_model_setup_s=phase_timing.gridap_model_setup_s,
            gridap_space_setup_s=phase_timing.gridap_space_setup_s,
            gridap_measure_setup_s=phase_timing.gridap_measure_setup_s,
            gridap_operator_assembly_s=phase_timing.gridap_operator_assembly_s,
            gridap_affine_operator_s=phase_timing.gridap_affine_operator_s,
            gridap_matrix_extraction_s=phase_timing.gridap_matrix_extraction_s,
            gridap_rhs_extraction_s=phase_timing.gridap_rhs_extraction_s,
            linear_symbolic_factorization_s=phase_timing.linear_symbolic_factorization_s,
            linear_numeric_factorization_s=phase_timing.linear_numeric_factorization_s,
            linear_backsolve_s=phase_timing.linear_backsolve_s,
            fluid_solve_total_s=phase_timing.fluid_solve_total_s,
            wall_pressure_sampling_s=phase_timing.wall_pressure_sampling_s,
            wall_update_s=phase_timing.wall_update_s,
            diagnostics_s=phase_timing.diagnostics_s,
            checkpoint_output_s=phase_timing.checkpoint_output_s,
            output_write_s=phase_timing.output_write_s,
            step_total_s=phase_timing.step_total_s,
            output_dir=default_native_resolved_fsi_partitioned_production_output_dir(local_spec),
            snapshot_manifest_csv=manifest_path(local_spec),
            snapshot_diagnostics_csv=diagnostics_path(local_spec),
            restart_metadata_json=restart_metadata_path(local_spec),
            batch_status_jsonl=batch_status_jsonl_path(local_spec),
            batch_status_csv=batch_status_csv_path(local_spec),
            batch_benchmark_json=batch_benchmark_path(local_spec),
            batch_failure_json=batch_failure_path(local_spec),
            message=string(batch_event_value(event, :message, "")),
        )
    end

    function append_batch_status!(
        local_spec::NativeResolvedFSIPartitionedProductionSpec,
        row::NamedTuple,
    )
        function write_compact_status_value(io, value)
            if value isa Bool
                write(io, value ? "true" : "false")
            elseif value isa Number
                write(io, isfinite(float(value)) ? string(value) : "null")
            elseif value === nothing
                write(io, "null")
            else
                write(io, json_string(string(value)))
            end
        end
        function write_compact_status_row(io, row::NamedTuple)
            write(io, "{")
            first = true
            for (key, value) in pairs(row)
                first || write(io, ",")
                write(io, json_string(string(key)), ":")
                write_compact_status_value(io, value)
                first = false
            end
            write(io, "}")
        end
        open(batch_status_jsonl_path(local_spec), "a") do io
            write_compact_status_row(io, row)
            write(io, "\n")
        end
        open(batch_status_csv_path(local_spec), "a") do io
            println(io, csv_record(Tuple(row)))
        end
        return row
    end

    function write_batch_failure(
        local_spec::NativeResolvedFSIPartitionedProductionSpec,
        error,
        start_ns::UInt64,
    )
        row = batch_status_row(
            local_spec,
            (
                event="production_failed",
                status="error",
                message=sprint(showerror, error),
            ),
            start_ns,
        )
        if isfile(batch_status_jsonl_path(local_spec)) && isfile(batch_status_csv_path(local_spec))
            append_batch_status!(local_spec, row)
        end
        write_json(batch_failure_path(local_spec), Dict{String,Any}(
            string(key) => value for (key, value) in pairs(row)
        ); overwrite=true)
        return row
    end

    function write_batch_benchmark(
        local_spec::NativeResolvedFSIPartitionedProductionSpec,
        result,
        start_ns::UInt64;
        phase_timing = result.smoke_result.phase_timing_s,
    )
        elapsed_s = telemetry_elapsed_s(start_ns)
        time_steps = result.smoke_result.time_step_count
        tetrahedra = size(result.smoke_result.mesh.topology, 1)
        phase_timing_dict = Dict{String,Any}(
            string(key) => get(phase_timing, key, 0.0) for key in NATIVE_RESOLVED_FSI_PHASE_TIMING_KEYS
        )
        solver_diagnostics = result.smoke_result.solver_diagnostics
        solver_diagnostics_dict = Dict{String,Any}(
            string(key) => get(solver_diagnostics, key, nothing) for key in NATIVE_RESOLVED_FSI_SOLVER_DIAGNOSTIC_KEYS
        )
        benchmark = Dict{String,Any}(
            "case_id" => string(local_spec.case_spec.case_id),
            "mesh_resolution" => Dict{String,Any}(
                "axial" => local_spec.resolution.axial,
                "radial" => local_spec.resolution.radial,
                "angular" => local_spec.resolution.angular,
            ),
            "tetrahedron_count" => tetrahedra,
            "node_count" => size(result.smoke_result.mesh.coordinates, 1),
            "dt_s" => local_spec.dt_s,
            "tfinal_s" => local_spec.tfinal_s,
            "snapshot_times_s" => copy(local_spec.snapshot_times_s),
            "time_step_count" => time_steps,
            "elapsed_wall_time_s" => elapsed_s,
            "seconds_per_step" => time_steps > 0 ? elapsed_s / time_steps : NaN,
            "steps_per_second" => elapsed_s > 0.0 ? time_steps / elapsed_s : NaN,
            "tetrahedron_steps_per_second" => elapsed_s > 0.0 ? tetrahedra * time_steps / elapsed_s : NaN,
            "phase_timing_s" => phase_timing_dict,
            "phase_timing_total_s" => native_resolved_fsi_phase_timing_total_s(phase_timing),
            "solver_diagnostics" => solver_diagnostics_dict,
            "gridap_rebuild_status" => solver_diagnostics.gridap_rebuild_status,
            "gridap_reuse_status" => solver_diagnostics.gridap_reuse_status,
            "gridap_reuse_miss_reason" => solver_diagnostics.gridap_reuse_miss_reason,
            "gridap_operator_component_status" => solver_diagnostics.gridap_operator_component_status,
            "gridap_operator_component_terms" => solver_diagnostics.gridap_operator_component_terms,
            "gridap_solver_backend_status" => solver_diagnostics.gridap_solver_backend_status,
            "gridap_context_reused" => solver_diagnostics.gridap_context_reused,
            "gridap_model_reused" => solver_diagnostics.gridap_model_reused,
            "gridap_fe_spaces_reused" => solver_diagnostics.gridap_fe_spaces_reused,
            "gridap_measures_reused" => solver_diagnostics.gridap_measures_reused,
            "gridap_matrix_structure_stable" => solver_diagnostics.gridap_matrix_structure_stable,
            "gridap_symbolic_factorization_eligible" => solver_diagnostics.gridap_symbolic_factorization_eligible,
            "gridap_symbolic_factorization_reused" => solver_diagnostics.gridap_symbolic_factorization_reused,
            "gridap_symbolic_factorization_cache_status" =>
                solver_diagnostics.gridap_symbolic_factorization_cache_status,
            "gridap_symbolic_factorization_setup_count" =>
                solver_diagnostics.gridap_symbolic_factorization_setup_count,
            "gridap_symbolic_factorization_reuse_count" =>
                solver_diagnostics.gridap_symbolic_factorization_reuse_count,
            "gridap_numeric_factorization_reused" => solver_diagnostics.gridap_numeric_factorization_reused,
            "gridap_numeric_factorization_cache_status" =>
                solver_diagnostics.gridap_numeric_factorization_cache_status,
            "gridap_numeric_factorization_cache_key" =>
                solver_diagnostics.gridap_numeric_factorization_cache_key,
            "gridap_numeric_factorization_matrix_value_digest" =>
                solver_diagnostics.gridap_numeric_factorization_matrix_value_digest,
            "gridap_numeric_factorization_setup_count" =>
                solver_diagnostics.gridap_numeric_factorization_setup_count,
            "gridap_numeric_factorization_reuse_count" =>
                solver_diagnostics.gridap_numeric_factorization_reuse_count,
            "gridap_reuse_reason_codes" => solver_diagnostics.gridap_reuse_reason_codes,
            "gridap_mesh_topology_digest" => solver_diagnostics.gridap_mesh_topology_digest,
            "gridap_coordinate_value_digest" => solver_diagnostics.gridap_coordinate_value_digest,
            "gridap_matrix_value_baseline_digest" => solver_diagnostics.gridap_matrix_value_baseline_digest,
            "gridap_matrix_value_digest_observation_count" =>
                solver_diagnostics.gridap_matrix_value_digest_observation_count,
            "gridap_matrix_value_digest_unique_count" =>
                solver_diagnostics.gridap_matrix_value_digest_unique_count,
            "gridap_matrix_value_digest_current_count" =>
                solver_diagnostics.gridap_matrix_value_digest_current_count,
            "gridap_matrix_value_digest_repeat_count" =>
                solver_diagnostics.gridap_matrix_value_digest_repeat_count,
            "gridap_matrix_value_digest_history_tail" => solver_diagnostics.gridap_matrix_value_digest_history_tail,
            "gridap_reuse_boundary_mode" => solver_diagnostics.gridap_reuse_boundary_mode,
            "gridap_reuse_quadrature_degree" => solver_diagnostics.gridap_reuse_quadrature_degree,
            "gridap_reuse_matrix_rows" => solver_diagnostics.gridap_reuse_matrix_rows,
            "gridap_reuse_matrix_cols" => solver_diagnostics.gridap_reuse_matrix_cols,
            "gridap_reuse_matrix_nnz" => solver_diagnostics.gridap_reuse_matrix_nnz,
            "gridap_matrix_rows" => solver_diagnostics.gridap_matrix_rows,
            "gridap_matrix_cols" => solver_diagnostics.gridap_matrix_cols,
            "gridap_matrix_nnz" => solver_diagnostics.gridap_matrix_nnz,
            "gridap_matrix_structure_digest" => solver_diagnostics.gridap_matrix_structure_digest,
            "gridap_matrix_value_digest" => solver_diagnostics.gridap_matrix_value_digest,
            "gridap_rhs_digest" => solver_diagnostics.gridap_rhs_digest,
            "gridap_boundary_mode" => solver_diagnostics.gridap_boundary_mode,
            "gridap_pressure_constraint" => solver_diagnostics.gridap_pressure_constraint,
            "gridap_pressure_reference" => solver_diagnostics.gridap_pressure_reference,
            "gridap_wall_boundary_mode" => solver_diagnostics.gridap_wall_boundary_mode,
            "gridap_quadrature_degree" => solver_diagnostics.gridap_quadrature_degree,
            "gridap_quadrature_sensitivity_degree" => solver_diagnostics.gridap_quadrature_sensitivity_degree,
            "gridap_quadrature_sensitivity_matrix_relative_change" =>
                solver_diagnostics.gridap_quadrature_sensitivity_matrix_relative_change,
            "gridap_quadrature_sensitivity_rhs_relative_change" =>
                solver_diagnostics.gridap_quadrature_sensitivity_rhs_relative_change,
            "gridap_quadrature_sensitivity_status" => solver_diagnostics.gridap_quadrature_sensitivity_status,
            "gridap_open_boundary_status" => solver_diagnostics.gridap_open_boundary_status,
            "gridap_outlet_node_count" => solver_diagnostics.gridap_outlet_node_count,
            "gridap_outlet_velocity_sampling_fallback_count" =>
                solver_diagnostics.gridap_outlet_velocity_sampling_fallback_count,
            "gridap_outlet_backflow_node_count" => solver_diagnostics.gridap_outlet_backflow_node_count,
            "gridap_outlet_normal_velocity_min_cm_s" => solver_diagnostics.gridap_outlet_normal_velocity_min_cm_s,
            "gridap_outlet_normal_velocity_max_cm_s" => solver_diagnostics.gridap_outlet_normal_velocity_max_cm_s,
            "gridap_outlet_normal_velocity_mean_cm_s" => solver_diagnostics.gridap_outlet_normal_velocity_mean_cm_s,
            "gridap_dt_s" => solver_diagnostics.gridap_dt_s,
            "gridap_time_step_index" => solver_diagnostics.gridap_time_step_index,
            "gridap_picard_iteration" => solver_diagnostics.gridap_picard_iteration,
            "gridap_linear_solve_count" => solver_diagnostics.gridap_linear_solve_count,
            "gridap_rebuild_count" => solver_diagnostics.gridap_rebuild_count,
            "gridap_model_setup_s" => phase_timing.gridap_model_setup_s,
            "gridap_space_setup_s" => phase_timing.gridap_space_setup_s,
            "gridap_measure_setup_s" => phase_timing.gridap_measure_setup_s,
            "gridap_operator_assembly_s" => phase_timing.gridap_operator_assembly_s,
            "gridap_affine_operator_s" => phase_timing.gridap_affine_operator_s,
            "gridap_matrix_extraction_s" => phase_timing.gridap_matrix_extraction_s,
            "gridap_rhs_extraction_s" => phase_timing.gridap_rhs_extraction_s,
            "linear_symbolic_factorization_s" => phase_timing.linear_symbolic_factorization_s,
            "linear_numeric_factorization_s" => phase_timing.linear_numeric_factorization_s,
            "linear_backsolve_s" => phase_timing.linear_backsolve_s,
            "fluid_solve_total_s" => phase_timing.fluid_solve_total_s,
            "wall_pressure_sampling_s" => phase_timing.wall_pressure_sampling_s,
            "wall_update_s" => phase_timing.wall_update_s,
            "diagnostics_s" => phase_timing.diagnostics_s,
            "checkpoint_output_s" => phase_timing.checkpoint_output_s,
            "output_write_s" => phase_timing.output_write_s,
            "step_total_s" => phase_timing.step_total_s,
            "phase_timing_status" =>
                "instrumentation_only_no_solver_semantics_changed; optimize only after measured phase timings",
            "estimated_runtime_s_from_development_reference" =>
                native_resolved_fsi_partitioned_production_estimated_runtime_s(local_spec),
            "maxrss_bytes" => batch_memory_bytes(),
            "process_id" => execution_layout.process_id,
            "thread_count" => execution_layout.thread_count,
            "parallel_workers" => execution_layout.parallel_workers,
            "threads_per_worker" => execution_layout.threads_per_worker,
            "force_process" => execution_layout.force_process,
            "coupling_converged" => result.smoke_result.coupling_converged,
            "final_coupling_displacement_residual_cm" =>
                result.smoke_result.final_coupling_displacement_residual_cm,
            "minimum_current_radius_cm" => result.smoke_result.minimum_current_radius_cm,
            "minimum_signed_tetra_volume6" => result.smoke_result.minimum_signed_tetra_volume6,
            "field_finite_status" => result.smoke_result.field_status.ready ? "ready" : "failed",
            "output_dir" => result.output_dir,
            "snapshot_manifest_csv" => result.manifest_csv,
            "snapshot_diagnostics_csv" => result.diagnostics_csv,
            "restart_metadata_json" => result.restart_metadata_json,
            "batch_status_jsonl" => batch_status_jsonl_path(local_spec),
            "batch_status_csv" => batch_status_csv_path(local_spec),
            "batch_benchmark_json" => batch_benchmark_path(local_spec),
            "batch_failure_json" => batch_failure_path(local_spec),
            "production_spec_digest" => native_resolved_fsi_partitioned_production_spec_digest(local_spec),
            "claim_boundary" =>
                "benchmark sidecar records batch execution observability only; not production parity or paper-grade reproduction",
        )
        write_json(batch_benchmark_path(local_spec), benchmark; overwrite=local_spec.overwrite)
        return benchmark
    end

    function production_spec_digest(local_spec::NativeResolvedFSIPartitionedProductionSpec)
        return native_resolved_fsi_partitioned_production_spec_digest(local_spec)
    end

    function snapshot_production_spec(
        local_spec::NativeResolvedFSIPartitionedProductionSpec,
        snapshot_time_s::Float64,
    )
        return NativeResolvedFSIPartitionedProductionSpec(
            case_id=local_spec.case_spec.case_id,
            resolution=local_spec.resolution,
            output_root=local_spec.output_root,
            dt_s=local_spec.dt_s,
            tfinal_s=snapshot_time_s,
            snapshot_times_s=[snapshot_time_s],
            time_atol=local_spec.time_atol,
            overwrite=local_spec.overwrite,
            inlet_outlet_boundary_mode=local_spec.inlet_outlet_boundary_mode,
            inlet_umax_cm_s=local_spec.inlet_umax_cm_s,
            pressure_drop_dyn_cm2=local_spec.pressure_drop_dyn_cm2,
            picard_iteration_count=local_spec.picard_iteration_count,
            picard_tolerance=local_spec.picard_tolerance,
            wall_density_g_cm3=local_spec.wall_density_g_cm3,
            wall_damping_g_cm2_s=local_spec.wall_damping_g_cm2_s,
            wall_stiffness_policy=local_spec.wall_stiffness_policy,
            wall_reference_radius_policy=local_spec.wall_reference_radius_policy,
            coupling_iteration_count=local_spec.coupling_iteration_count,
            coupling_tolerance=local_spec.coupling_tolerance,
            coupling_under_relaxation=local_spec.coupling_under_relaxation,
            progress_every=local_spec.progress_every,
            status_every=local_spec.status_every,
            allow_large_output=local_spec.allow_large_output,
        )
    end

    function snapshot_smoke_spec(
        local_spec::NativeResolvedFSIPartitionedProductionSpec,
        snapshot_time_s::Float64,
        output_dir::String,
    )
        return NativeResolvedFSIPartitionedSmokeSpec(
            case_id=local_spec.case_spec.case_id,
            resolution=local_spec.resolution,
            output_dir=output_dir,
            dt_s=local_spec.dt_s,
            tfinal_s=snapshot_time_s,
            time_atol=local_spec.time_atol,
            overwrite=local_spec.overwrite,
            inlet_outlet_boundary_mode=local_spec.inlet_outlet_boundary_mode,
            inlet_umax_cm_s=local_spec.inlet_umax_cm_s,
            pressure_drop_dyn_cm2=local_spec.pressure_drop_dyn_cm2,
            picard_iteration_count=local_spec.picard_iteration_count,
            picard_tolerance=local_spec.picard_tolerance,
            wall_density_g_cm3=local_spec.wall_density_g_cm3,
            wall_damping_g_cm2_s=local_spec.wall_damping_g_cm2_s,
            coupling_iteration_count=local_spec.coupling_iteration_count,
            coupling_tolerance=local_spec.coupling_tolerance,
            coupling_under_relaxation=local_spec.coupling_under_relaxation,
        )
    end

    function snapshot_status(
        local_spec::NativeResolvedFSIPartitionedProductionSpec,
        snapshot_time_s::Float64,
        smoke_result,
    )
        ready = smoke_result.schema_status.ready &&
                smoke_result.geometry_status.ready &&
                smoke_result.time_status.ready &&
                smoke_result.field_status.ready &&
                smoke_result.post_update_fluid_refresh &&
                isapprox(smoke_result.saved_time_s, snapshot_time_s; atol=local_spec.time_atol)
        return NativeResolvedFSIWorkflowStatus(ready, ready ? "ready" : "failed")
    end

    function run_independent_snapshot(
        local_spec::NativeResolvedFSIPartitionedProductionSpec,
        snapshot_time_s::Float64,
        output_dir::String,
    )
        snapshot_spec = snapshot_production_spec(local_spec, snapshot_time_s)
        smoke_spec = snapshot_smoke_spec(local_spec, snapshot_time_s, output_dir)
        smoke_result = run_native_resolved_fsi_partitioned_smoke(smoke_spec)
        return (
            snapshot_time_s=snapshot_time_s,
            output_dir=output_dir,
            spec=snapshot_spec,
            smoke_spec=smoke_spec,
            smoke_result=smoke_result,
            provenance="independent_smoke_backed_snapshot",
            status=snapshot_status(local_spec, snapshot_time_s, smoke_result),
        )
    end

    function run_state_carrying_snapshots(local_spec::NativeResolvedFSIPartitionedProductionSpec, start_ns::UInt64)
        mesh = native_resolved_fsi_mesh(local_spec.case_spec, local_spec.resolution)
        native_resolved_fsi_smoke_validate_mesh(mesh)
        estimated_field_payload_bytes = native_resolved_fsi_smoke_estimated_field_payload_bytes(mesh)
        estimated_field_payload_bytes <= NATIVE_RESOLVED_FSI_SMOKE_MAX_OUTPUT_BYTES || throw(ArgumentError(
            "native resolved-FSI partitioned production estimated single-snapshot raw field payload $(estimated_field_payload_bytes) bytes exceeds the $(NATIVE_RESOLVED_FSI_SMOKE_MAX_OUTPUT_BYTES)-byte smoke cap",
        ))
        requested_snapshot_times_s = if resume_context !== nothing
            copy(local_spec.snapshot_times_s[resume_context.next_snapshot_index:end])
        elseif internal_stop_after_snapshot_index !== nothing
            copy(local_spec.snapshot_times_s[1:internal_stop_after_snapshot_index])
        else
            copy(local_spec.snapshot_times_s)
        end
        isempty(requested_snapshot_times_s) && throw(ArgumentError(
            "native resolved-FSI partitioned production has no snapshots to run",
        ))
        series_spec = snapshot_smoke_spec(
            local_spec,
            local_spec.tfinal_s,
            default_native_resolved_fsi_partitioned_production_output_dir(local_spec),
        )
        gridap_context = build_native_resolved_fsi_gridap_context(
            mesh;
            inlet_outlet_boundary_mode=series_spec.inlet_outlet_boundary_mode,
            quadrature_degree=4,
        )
        solve_workspace = NativeResolvedFSISolveWorkspace(length(mesh.geometry.axial_coordinates_cm))
        function progress_callback(progress_event::NamedTuple)
            row = batch_status_row(local_spec, progress_event, start_ns)
            event_name = row.event
            step_index = row.time_step_index
            write_status = event_name == "snapshot_completed" ||
                           (step_index > 0 && step_index % local_spec.status_every == 0)
            write_status && append_batch_status!(local_spec, row)
            write_progress = local_spec.progress_every > 0 &&
                             step_index > 0 &&
                             step_index % local_spec.progress_every == 0
            if write_progress || event_name == "snapshot_completed"
                @telemetry_info "native resolved-FSI production progress" event=event_name stage="native_resolved_fsi_production" status=row.status case_id=row.case_id step=step_index total_steps=row.expected_time_step_count time_s=row.physical_time_s elapsed_s=row.elapsed_s estimated_remaining_s=row.estimated_remaining_s min_radius_cm=row.minimum_current_radius_cm min_tetra_volume6=row.minimum_signed_tetra_volume6 coupling_converged=row.coupling_converged coupling_residual_cm=row.final_coupling_displacement_residual_cm output_dir=row.output_dir production_spec_digest=row.production_spec_digest
            end
            return row
        end
        solve_results = native_resolved_fsi_solve_partitioned_snapshot_series(
            mesh,
            series_spec,
            requested_snapshot_times_s,
            progress_callback=progress_callback,
            restart_state=resume_context === nothing ? nothing : resume_context.solver_state,
            gridap_context=gridap_context,
            workspace=solve_workspace,
        )
        snapshot_results = NamedTuple[]
        completed_snapshot_count = resume_context === nothing ? 0 : resume_context.completed_snapshot_count
        for (offset, snapshot_time_s) in enumerate(requested_snapshot_times_s)
            snapshot_index = completed_snapshot_count + offset
            snapshot_dir = snapshot_output_dir(local_spec, snapshot_time_s)
            snapshot_spec = snapshot_production_spec(local_spec, snapshot_time_s)
            smoke_spec = snapshot_smoke_spec(local_spec, snapshot_time_s, snapshot_dir)
            solve_result = solve_results[offset]
            smoke_result = native_resolved_fsi_partitioned_smoke_result(
                mesh,
                smoke_spec,
                solve_result;
                output_dir=snapshot_dir,
                saved_time_s=snapshot_time_s,
                estimated_field_payload_bytes=estimated_field_payload_bytes,
            )
            push!(snapshot_results, (
                snapshot_index=snapshot_index,
                snapshot_time_s=snapshot_time_s,
                output_dir=snapshot_dir,
                spec=snapshot_spec,
                smoke_spec=smoke_spec,
                solve_result=solve_result,
                smoke_result=smoke_result,
                provenance="state_carrying_partitioned",
                status=snapshot_status(local_spec, snapshot_time_s, smoke_result),
            ))
        end
        return snapshot_results
    end

    function manifest_row(local_spec::NativeResolvedFSIPartitionedProductionSpec, snapshot_result::NamedTuple)
        smoke_result = snapshot_result.smoke_result
        boundary_status = native_resolved_fsi_boundary_status_fields(
            smoke_result.inlet_outlet_boundary_mode;
            inlet_umax_cm_s=local_spec.inlet_umax_cm_s,
        )
        return (
            string(local_spec.case_spec.case_id),
            snapshot_result.snapshot_time_s,
            snapshot_result.output_dir,
            smoke_result.velocity_xdmf,
            smoke_result.pressure_xdmf,
            smoke_result.displacement_xdmf,
            snapshot_result.provenance,
            size(smoke_result.mesh.coordinates, 1),
            size(smoke_result.mesh.topology, 1),
            smoke_result.estimated_field_payload_bytes,
            snapshot_result.status.ready ? "ready" : "failed",
            boundary_status.boundary_mode,
            boundary_status.boundary_mode_class,
            boundary_status.section41_boundary_status,
            native_resolved_fsi_boundary_equivalence_status(boundary_status),
        )
    end

    function write_manifest(
        path::String,
        local_spec::NativeResolvedFSIPartitionedProductionSpec,
        snapshot_results::Vector{NamedTuple},
    )
        header = (
            "case_id",
            "snapshot_time_s",
            "output_dir",
            "velocity_xdmf",
            "pressure_xdmf",
            "displacement_xdmf",
            "provenance",
            "node_count",
            "tetrahedron_count",
            "estimated_field_payload_bytes",
            "status",
            "boundary_mode",
            "boundary_mode_class",
            "section41_boundary_status",
            "boundary_equivalence_status",
        )
        rows = (manifest_row(local_spec, snapshot_result) for snapshot_result in snapshot_results)
        if resume_context !== nothing
            guarded_open_write(path, local_spec.overwrite) do io
                println(io, csv_record(header))
                for line in resume_context.completed_manifest_data_lines
                    println(io, line)
                end
                for row in rows
                    println(io, csv_record(row))
                end
            end
            return path
        end
        return write_csv_table(path, header, rows; overwrite=local_spec.overwrite)
    end

    function wall_update_ready(smoke_result)
        return all(isfinite, smoke_result.wall_displacement_cm) &&
               all(isfinite, smoke_result.wall_velocity_cm_s) &&
               all(isfinite, smoke_result.wall_pressure_dyn_cm2) &&
               all(isfinite, smoke_result.current_radii_cm) &&
               smoke_result.minimum_current_radius_cm > 0.0 &&
               smoke_result.minimum_signed_tetra_volume6 > 0.0 &&
               !isempty(smoke_result.wall_displacement_cm) &&
               iszero(smoke_result.wall_displacement_cm[begin]) &&
               iszero(smoke_result.wall_displacement_cm[end]) &&
               iszero(smoke_result.wall_velocity_cm_s[begin]) &&
               iszero(smoke_result.wall_velocity_cm_s[end])
    end

    function diagnostic_row(
        local_spec::NativeResolvedFSIPartitionedProductionSpec,
        snapshot_index::Int,
        snapshot_result::NamedTuple,
    )
        smoke_result = snapshot_result.smoke_result
        solver_diagnostics = smoke_result.solver_diagnostics
        solver_convergence_ready =
            smoke_result.picard_converged &&
            smoke_result.max_picard_iterations_used > 0 &&
            isfinite(smoke_result.final_picard_update_norm)
        importer_roundtrip_ready =
            smoke_result.schema_status.ready &&
            smoke_result.geometry_status.ready &&
            smoke_result.time_status.ready &&
            smoke_result.field_status.ready
        wall_ready = wall_update_ready(smoke_result)
        boundary_status = native_resolved_fsi_boundary_status_fields(
            smoke_result.inlet_outlet_boundary_mode;
            inlet_umax_cm_s=local_spec.inlet_umax_cm_s,
        )
        return (
            case_id=string(local_spec.case_spec.case_id),
            snapshot_index=snapshot_index,
            snapshot_time_s=snapshot_result.snapshot_time_s,
            saved_time_s=smoke_result.saved_time_s,
            output_dir=snapshot_result.output_dir,
            provenance=snapshot_result.provenance,
            time_step_count=smoke_result.time_step_count,
            picard_iteration_count=local_spec.picard_iteration_count,
            picard_tolerance=local_spec.picard_tolerance,
            max_picard_iterations_used=smoke_result.max_picard_iterations_used,
            final_picard_update_norm=smoke_result.final_picard_update_norm,
            solver_convergence_ready=solver_convergence_ready,
            picard_converged=smoke_result.picard_converged,
            coupling_iteration_count=local_spec.coupling_iteration_count,
            coupling_tolerance=local_spec.coupling_tolerance,
            coupling_under_relaxation=local_spec.coupling_under_relaxation,
            max_coupling_iterations_used=smoke_result.max_coupling_iterations_used,
            final_coupling_displacement_residual_cm=smoke_result.final_coupling_displacement_residual_cm,
            coupling_converged=smoke_result.coupling_converged,
            coupling_residual_count=length(smoke_result.coupling_residual_history),
            fluid_wall_boundary_mode=string(smoke_result.fluid_wall_boundary_mode),
            boundary_mode=boundary_status.boundary_mode,
            boundary_mode_class=boundary_status.boundary_mode_class,
            inlet_condition_status=boundary_status.inlet_condition_status,
            outlet_condition_status=boundary_status.outlet_condition_status,
            pressure_gauge_status=boundary_status.pressure_gauge_status,
            pressure_nullspace_status=
                native_resolved_fsi_pressure_nullspace_status(smoke_result.inlet_outlet_boundary_mode),
            wall_pressure_projection_status=
                native_resolved_fsi_wall_pressure_projection_status(smoke_result.inlet_outlet_boundary_mode),
            wall_pressure_forcing_status=
                native_resolved_fsi_wall_pressure_forcing_status(smoke_result.inlet_outlet_boundary_mode),
            section41_boundary_status=boundary_status.section41_boundary_status,
            boundary_status=boundary_status.boundary_status,
            boundary_equivalence_status=native_resolved_fsi_boundary_equivalence_status(boundary_status),
            post_update_fluid_refresh=smoke_result.post_update_fluid_refresh,
            wall_update_ready=wall_ready,
            wall_displacement_min_cm=minimum(smoke_result.wall_displacement_cm),
            wall_displacement_max_cm=maximum(smoke_result.wall_displacement_cm),
            wall_velocity_min_cm_s=minimum(smoke_result.wall_velocity_cm_s),
            wall_velocity_max_cm_s=maximum(smoke_result.wall_velocity_cm_s),
            wall_pressure_min_dyn_cm2=minimum(smoke_result.wall_pressure_dyn_cm2),
            wall_pressure_max_dyn_cm2=maximum(smoke_result.wall_pressure_dyn_cm2),
            physical_wall_forcing_pressure_min_dyn_cm2=minimum(smoke_result.wall_pressure_dyn_cm2),
            physical_wall_forcing_pressure_max_dyn_cm2=maximum(smoke_result.wall_pressure_dyn_cm2),
            pressure_gauge_convention="outlet_gauge_normalization_export_only_not_membrane_forcing",
            minimum_current_radius_cm=smoke_result.minimum_current_radius_cm,
            minimum_signed_tetra_volume6=smoke_result.minimum_signed_tetra_volume6,
            pressure_projection_fallback_count=smoke_result.pressure_projection_fallback_count,
            sampling_fallback_count=smoke_result.sampling_fallback_count,
            gridap_quadrature_degree=solver_diagnostics.gridap_quadrature_degree,
            gridap_quadrature_sensitivity_degree=solver_diagnostics.gridap_quadrature_sensitivity_degree,
            gridap_quadrature_sensitivity_matrix_relative_change=
                solver_diagnostics.gridap_quadrature_sensitivity_matrix_relative_change,
            gridap_quadrature_sensitivity_rhs_relative_change=
                solver_diagnostics.gridap_quadrature_sensitivity_rhs_relative_change,
            gridap_quadrature_sensitivity_status=solver_diagnostics.gridap_quadrature_sensitivity_status,
            gridap_open_boundary_status=solver_diagnostics.gridap_open_boundary_status,
            gridap_outlet_node_count=solver_diagnostics.gridap_outlet_node_count,
            gridap_outlet_velocity_sampling_fallback_count=
                solver_diagnostics.gridap_outlet_velocity_sampling_fallback_count,
            gridap_outlet_backflow_node_count=solver_diagnostics.gridap_outlet_backflow_node_count,
            gridap_outlet_normal_velocity_min_cm_s=solver_diagnostics.gridap_outlet_normal_velocity_min_cm_s,
            gridap_outlet_normal_velocity_max_cm_s=solver_diagnostics.gridap_outlet_normal_velocity_max_cm_s,
            gridap_outlet_normal_velocity_mean_cm_s=solver_diagnostics.gridap_outlet_normal_velocity_mean_cm_s,
            schema_ready=smoke_result.schema_status.ready,
            geometry_ready=smoke_result.geometry_status.ready,
            time_ready=smoke_result.time_status.ready,
            field_ready=smoke_result.field_status.ready,
            output_ready=snapshot_result.status.ready,
            importer_roundtrip_ready=importer_roundtrip_ready,
            estimated_field_payload_bytes=smoke_result.estimated_field_payload_bytes,
            status=snapshot_result.status.ready ? "ready" : "failed",
        )
    end

    function build_diagnostic_rows(
        local_spec::NativeResolvedFSIPartitionedProductionSpec,
        snapshot_results::Vector{NamedTuple},
    )
        return NamedTuple[
            diagnostic_row(
                local_spec,
                haskey(snapshot_result, :snapshot_index) ? snapshot_result.snapshot_index : snapshot_index,
                snapshot_result,
            )
            for (snapshot_index, snapshot_result) in enumerate(snapshot_results)
        ]
    end

    function write_diagnostics(path::String, rows::Vector{NamedTuple}, overwrite::Bool)
        isempty(rows) && throw(ArgumentError("native resolved-FSI production diagnostics require at least one row"))
        header = string.(propertynames(first(rows)))
        if resume_context !== nothing
            guarded_open_write(path, overwrite) do io
                println(io, csv_record(header))
                for line in resume_context.completed_diagnostics_data_lines
                    println(io, line)
                end
                for row in rows
                    println(io, csv_record(Tuple(row)))
                end
            end
            return path
        end
        return write_csv_table(path, header, (Tuple(row) for row in rows); overwrite=overwrite)
    end

    function diagnostics_status(rows::Vector{NamedTuple}, diagnostics_csv::String)
        ready = isfile(diagnostics_csv) &&
                !isempty(rows) &&
                all(
                    row ->
                        row.solver_convergence_ready &&
                        row.max_coupling_iterations_used > 0 &&
                        isfinite(row.final_coupling_displacement_residual_cm) &&
                        row.wall_update_ready &&
                        row.output_ready &&
                        row.importer_roundtrip_ready,
                    rows,
                )
        status = ready ?
            "production diagnostics CSV captured state-carrying per-snapshot solver convergence, wall-update, output, and importer health" :
            "production diagnostics are missing or one or more snapshot health checks failed"
        return NativeResolvedFSIWorkflowStatus(ready, status)
    end

    function output_status(
        local_spec::NativeResolvedFSIPartitionedProductionSpec,
        snapshot_results::Vector{NamedTuple},
        manifest_csv::String,
        diagnostics_csv::String,
        restart_metadata_json::String,
    )
        expected_output_dir = default_native_resolved_fsi_partitioned_production_output_dir(local_spec)
        completed_snapshot_count = resume_context === nothing ? 0 : resume_context.completed_snapshot_count
        expected_completed_count = completed_snapshot_count + length(snapshot_results)
        ready = isfile(manifest_csv) &&
                isfile(diagnostics_csv) &&
                isfile(restart_metadata_json) &&
                (
                    expected_completed_count == length(local_spec.snapshot_times_s) ||
                    internal_stop_after_snapshot_index !== nothing
                ) &&
                all(
                    snapshot -> snapshot.status.ready && startswith(snapshot.output_dir, expected_output_dir),
                    snapshot_results,
                )
        status = if ready && resume_context !== nothing
            "resumed production fork wrote $(length(snapshot_results)) new importer-compatible bundle(s) under $(expected_output_dir) and preserved $(completed_snapshot_count) parent snapshot row(s)"
        elseif ready && internal_stop_after_snapshot_index !== nothing
            "partial production checkpoint wrote $(length(snapshot_results)) importer-compatible bundle(s) under $(expected_output_dir) and preserved the full checkpoint cursor for internal resume"
        elseif ready
            "production snapshot manifest, diagnostics CSV, restart metadata, and $(length(snapshot_results)) importer-compatible bundle(s) were written under $(expected_output_dir)"
        else
            "one or more production snapshot bundles or production sidecars failed output, schema, geometry, time, or field checks"
        end
        return NativeResolvedFSIWorkflowStatus(ready, status)
    end

    function method_status(snapshot_results::Vector{NamedTuple})
        ready = !isempty(snapshot_results) && all(
                snapshot ->
                    snapshot.smoke_result.field_status.ready &&
                    snapshot.smoke_result.post_update_fluid_refresh &&
                    snapshot.provenance == "state_carrying_partitioned" &&
                    snapshot.smoke_result.fluid_model === NATIVE_RESOLVED_FSI_PARTITIONED_SMOKE_STAGE,
            snapshot_results,
        )
        exact_boundary_mode =
            !isempty(snapshot_results) &&
            all(
                snapshot -> snapshot.smoke_result.inlet_outlet_boundary_mode ===
                            :poiseuille_inlet_zero_outlet_stress_section41,
                snapshot_results,
        )
        ready_status = if exact_boundary_mode
            "production snapshot harness advanced one state-carrying partitioned solve series as repeated deformed-domain fluid solves through each requested time with a reduced radial membrane update and stationary no-slip wall solves for the exact Section 4.1 Poiseuille inlet / zero-outlet-stress boundary mode as smoke-scale/operator-readiness evidence only; direct finite physical wall-forcing pressure sampling was required with pressure-drop fallback disabled, and outlet-gauge pressure normalization is export-only; diagnostics are cumulative per-snapshot summaries with carried coupling residuals; schema-v3 checkpoint resume is qualified-internal split-run only, while public/default process resume, paper-grade Section 4.1 parity, paper-grade reproduction, and monolithic ALE coupling remain out of scope"
        else
            "production snapshot harness advanced one state-carrying partitioned solve series as repeated deformed-domain fluid solves through each requested time with a reduced radial membrane update and prescribed radial wall-velocity Dirichlet data on deformed geometry; physical wall-forcing pressure uses raw sampling or the pressure-drop resistance fallback, while outlet-gauge pressure normalization is export-only; diagnostics are cumulative per-snapshot summaries with carried coupling residuals; schema-v3 checkpoint resume is qualified-internal split-run only, while public/default process resume, validated Section 4.1 parity, and monolithic ALE coupling remain out of scope"
        end
        status = ready ?
            ready_status :
            "production-depth partitioned native driver did not complete the bounded state-carrying method contract"
        return NativeResolvedFSIWorkflowStatus(ready, status)
    end

    validate(spec)
    validate_runner_scope(spec)

    start_ns = telemetry_start_ns()
    production_output_dir = default_native_resolved_fsi_partitioned_production_output_dir(spec)
    preflight_production_outputs(spec)
    prepare_batch_status_sidecars(spec)
    append_batch_status!(spec, batch_status_row(
        spec,
        (
            event="production_started",
            status="started",
            expected_time_step_count=native_resolved_fsi_partitioned_production_estimated_time_step_count(spec),
            dt_s=spec.dt_s,
            time_s=0.0,
            snapshot_time_s=first(spec.snapshot_times_s),
            field_finite_status="not_sampled_yet",
            inlet_outlet_boundary_mode=string(spec.inlet_outlet_boundary_mode),
            message="native resolved-FSI production batch started",
        ),
        start_ns,
    ))
    @telemetry_info "native resolved-FSI production started" event="native_resolved_fsi_production_started" stage="native_resolved_fsi_production" status="started" case_id=string(spec.case_spec.case_id) output_dir=production_output_dir dt_s=spec.dt_s tfinal_s=spec.tfinal_s expected_time_step_count=native_resolved_fsi_partitioned_production_estimated_time_step_count(spec) expected_fluid_solve_upper_bound=native_resolved_fsi_partitioned_production_expected_fluid_solve_upper_bound(spec) production_spec_digest=native_resolved_fsi_partitioned_production_spec_digest(spec)
    try
        snapshot_results = run_state_carrying_snapshots(spec, start_ns)
        post_solve_phase_timing = native_resolved_fsi_phase_timing_accumulator()
        manifest_csv = manifest_path(spec)
        manifest_start_ns = time_ns()
        write_manifest(manifest_csv, spec, snapshot_results)
        native_resolved_fsi_add_phase_timing!(
            post_solve_phase_timing,
            :output_write_s,
            native_resolved_fsi_phase_elapsed_s(manifest_start_ns),
        )
        diagnostics_csv = diagnostics_path(spec)
        diagnostics_start_ns = time_ns()
        diagnostic_rows = build_diagnostic_rows(spec, snapshot_results)
        write_diagnostics(diagnostics_csv, diagnostic_rows, spec.overwrite)
        native_resolved_fsi_add_phase_timing!(
            post_solve_phase_timing,
            :diagnostics_s,
            native_resolved_fsi_phase_elapsed_s(diagnostics_start_ns),
        )
        restart_metadata_json = restart_metadata_path(spec)
        checkpoint_start_ns = time_ns()
        checkpoint_manifest = native_resolved_fsi_write_restart_checkpoint_state(
            spec,
            snapshot_results,
            diagnostic_rows,
            manifest_csv,
            diagnostics_csv,
            restart_metadata_json,
            resume_context=resume_context,
        )
        metadata = native_resolved_fsi_restart_metadata(
            spec,
            snapshot_results,
            diagnostic_rows,
            manifest_csv,
            diagnostics_csv,
            checkpoint_manifest,
            resume_context=resume_context,
            execution_layout=execution_layout,
        )
        native_resolved_fsi_write_restart_metadata(restart_metadata_json, metadata, spec.overwrite)
        native_resolved_fsi_add_phase_timing!(
            post_solve_phase_timing,
            :checkpoint_output_s,
            native_resolved_fsi_phase_elapsed_s(checkpoint_start_ns),
        )
        final_snapshot = snapshot_results[end]
        production_phase_timing = native_resolved_fsi_phase_timing_accumulator()
        native_resolved_fsi_merge_phase_timing!(production_phase_timing, final_snapshot.smoke_result.phase_timing_s)
        native_resolved_fsi_merge_phase_timing!(
            production_phase_timing,
            native_resolved_fsi_phase_timing_named_tuple(post_solve_phase_timing),
        )
        result = NativeResolvedFSIPartitionedProductionResult(
            spec,
            final_snapshot.smoke_spec,
            final_snapshot.smoke_result,
            production_output_dir,
            manifest_csv,
            diagnostics_csv,
            restart_metadata_json,
            snapshot_results,
            diagnostic_rows,
            metadata,
            final_snapshot.snapshot_time_s,
            copy(spec.snapshot_times_s),
            output_status(spec, snapshot_results, manifest_csv, diagnostics_csv, restart_metadata_json),
            method_status(snapshot_results),
            diagnostics_status(diagnostic_rows, diagnostics_csv),
            native_resolved_fsi_restart_status(metadata, restart_metadata_json),
        )
        write_batch_benchmark(
            spec,
            result,
            start_ns;
            phase_timing=native_resolved_fsi_phase_timing_named_tuple(production_phase_timing),
        )
        append_batch_status!(spec, batch_status_row(
            spec,
            (
                event="production_completed",
                status="ok",
                time_step_index=result.smoke_result.time_step_count,
                expected_time_step_count=native_resolved_fsi_partitioned_production_estimated_time_step_count(spec),
                snapshot_time_s=result.saved_time_s,
                time_s=result.saved_time_s,
                dt_s=spec.dt_s,
                minimum_current_radius_cm=result.smoke_result.minimum_current_radius_cm,
                minimum_signed_tetra_volume6=result.smoke_result.minimum_signed_tetra_volume6,
                field_finite_status=result.smoke_result.field_status.ready ? "ready" : "failed",
                final_coupling_displacement_residual_cm=
                    result.smoke_result.final_coupling_displacement_residual_cm,
                step_coupling_converged=result.smoke_result.coupling_converged,
                coupling_converged=result.smoke_result.coupling_converged,
                max_coupling_iterations_used=result.smoke_result.max_coupling_iterations_used,
                pressure_projection_fallback_count=result.smoke_result.pressure_projection_fallback_count,
                fluid_wall_boundary_mode=string(result.smoke_result.fluid_wall_boundary_mode),
                inlet_outlet_boundary_mode=string(result.smoke_result.inlet_outlet_boundary_mode),
                solver_diagnostics=result.smoke_result.solver_diagnostics,
                phase_timing_s=native_resolved_fsi_phase_timing_named_tuple(production_phase_timing),
                message="native resolved-FSI production batch completed",
            ),
            start_ns,
        ))
        @telemetry_info "native resolved-FSI production completed" event="native_resolved_fsi_production_completed" stage="native_resolved_fsi_production" status="ok" case_id=string(spec.case_spec.case_id) elapsed_s=telemetry_elapsed_s(start_ns) output_dir=production_output_dir time_step_count=result.smoke_result.time_step_count coupling_converged=result.smoke_result.coupling_converged production_spec_digest=native_resolved_fsi_partitioned_production_spec_digest(spec)
        return result
    catch err
        write_batch_failure(spec, err, start_ns)
        @telemetry_error "native resolved-FSI production failed" event="native_resolved_fsi_production_failed" stage="native_resolved_fsi_production" status="error" case_id=string(spec.case_spec.case_id) elapsed_s=telemetry_elapsed_s(start_ns) output_dir=production_output_dir reason=sprint(showerror, err) production_spec_digest=native_resolved_fsi_partitioned_production_spec_digest(spec)
        rethrow()
    end
end

function native_resolved_fsi_partitioned_production_batch_row(
    index::Int,
    spec::NativeResolvedFSIPartitionedProductionSpec;
    parallel_workers::Integer,
    threads_per_worker::Integer,
    force_process::Bool,
)
    paths = native_resolved_fsi_partitioned_production_sidecar_paths(spec)
    start_ns = telemetry_start_ns()
    execution_layout = native_resolved_fsi_execution_layout(
        parallel_workers=parallel_workers,
        threads_per_worker=threads_per_worker,
        force_process=force_process,
    )
    try
        result = run_native_resolved_fsi_partitioned_production(
            spec;
            parallel_workers=parallel_workers,
            threads_per_worker=threads_per_worker,
            force_process=force_process,
        )
        ready = result.output_status.ready &&
                result.method_status.ready &&
                result.diagnostics_status.ready &&
                result.restart_status.ready
        return (
            index=index,
            case_id=string(spec.case_spec.case_id),
            process_id=execution_layout.process_id,
            thread_count=execution_layout.thread_count,
            parallel_workers=execution_layout.parallel_workers,
            threads_per_worker=execution_layout.threads_per_worker,
            force_process=execution_layout.force_process,
            output_dir=result.output_dir,
            snapshot_output_dirs=native_resolved_fsi_partitioned_production_snapshot_output_dirs(spec),
            velocity_xdmf=result.smoke_result.velocity_xdmf,
            pressure_xdmf=result.smoke_result.pressure_xdmf,
            displacement_xdmf=result.smoke_result.displacement_xdmf,
            manifest_csv=result.manifest_csv,
            diagnostics_csv=result.diagnostics_csv,
            restart_metadata_json=result.restart_metadata_json,
            batch_status_jsonl=paths.batch_status_jsonl,
            batch_status_csv=paths.batch_status_csv,
            batch_benchmark_json=paths.batch_benchmark_json,
            batch_failure_json=paths.batch_failure_json,
            status=ready ? "ready" : "failed",
            elapsed_s=telemetry_elapsed_s(start_ns),
            saved_time_s=result.saved_time_s,
            snapshot_times_s=copy(result.snapshot_times_s),
            claim_boundary=NATIVE_RESOLVED_FSI_PRODUCTION_BATCH_CLAIM_BOUNDARY,
            method_status=result.method_status.status,
            failure_message="",
        )
    catch err
        return (
            index=index,
            case_id=string(spec.case_spec.case_id),
            process_id=execution_layout.process_id,
            thread_count=execution_layout.thread_count,
            parallel_workers=execution_layout.parallel_workers,
            threads_per_worker=execution_layout.threads_per_worker,
            force_process=execution_layout.force_process,
            output_dir=paths.output_dir,
            snapshot_output_dirs=native_resolved_fsi_partitioned_production_snapshot_output_dirs(spec),
            velocity_xdmf="",
            pressure_xdmf="",
            displacement_xdmf="",
            manifest_csv=paths.manifest_csv,
            diagnostics_csv=paths.diagnostics_csv,
            restart_metadata_json=paths.restart_metadata_json,
            batch_status_jsonl=paths.batch_status_jsonl,
            batch_status_csv=paths.batch_status_csv,
            batch_benchmark_json=paths.batch_benchmark_json,
            batch_failure_json=paths.batch_failure_json,
            status="error",
            elapsed_s=telemetry_elapsed_s(start_ns),
            saved_time_s=NaN,
            snapshot_times_s=copy(spec.snapshot_times_s),
            claim_boundary=NATIVE_RESOLVED_FSI_PRODUCTION_BATCH_CLAIM_BOUNDARY,
            method_status="native resolved-FSI batch production did not complete",
            failure_message=sprint(showerror, err),
        )
    end
end

"""
    run_native_resolved_fsi_partitioned_production_batch(specs; parallel_workers,
                                                         threads_per_worker,
                                                         force_process=false)

Run multiple explicit partitioned production specs through the package case
worker pool and return deterministic rows sorted by input order. Each row is an
observability summary only; it is not a production-parity, imported-parity,
moving-wall/ALE fidelity, or restart/resume claim.
"""
function run_native_resolved_fsi_partitioned_production_batch(
    specs::AbstractVector{<:NativeResolvedFSIPartitionedProductionSpec};
    parallel_workers::Integer = default_case_workers(),
    threads_per_worker::Integer = 1,
    force_process::Bool = false,
)
    parallel_workers >= 0 ||
        throw(ArgumentError("native resolved-FSI production batch parallel_workers must be nonnegative"))
    worker_threads = validate_threads_per_worker(threads_per_worker)
    indexed_specs = collect(enumerate(specs))
    isempty(indexed_specs) && return NamedTuple[]
    rows = parallel_case_map(
        indexed_specs;
        parallel_workers=parallel_workers,
        threads_per_worker=worker_threads,
        force_process=force_process,
    ) do indexed_spec
        native_resolved_fsi_partitioned_production_batch_row(
            indexed_spec[1],
            indexed_spec[2];
            parallel_workers=parallel_workers,
            threads_per_worker=worker_threads,
            force_process=force_process,
        )
    end
    sort!(rows; by=row -> row.index)
    return rows
end

run_native_resolved_fsi(spec::NativeResolvedFSIPartitionedProductionSpec) =
    run_native_resolved_fsi_partitioned_production(spec)

run_native_resolved_fsi_production_workflow(spec::NativeResolvedFSIPartitionedProductionSpec) =
    run_native_resolved_fsi_partitioned_production(spec)

run_native_resolved_fsi_production_workflow(plan::NativeResolvedFSIProductionWorkflowPlan) =
    run_native_resolved_fsi_partitioned_production(plan.production_spec)
