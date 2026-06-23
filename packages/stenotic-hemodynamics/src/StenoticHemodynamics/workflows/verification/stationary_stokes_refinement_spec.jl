"""
    StationaryStokesRefinementSpec(; ...)

Workflow spec for the fixed-wall stationary-Stokes refinement study.

This workflow is separate from the transient stationary-Stokes initializer
path. For each requested severity and mesh, it compares section-averaged FE
fields against projected 1D fields and records wall-traction / wall-shear
diagnostics.
"""
struct StationaryStokesRefinementSpec <: AbstractStudySpec
    base_params::Params
    severities::Vector{Float64}
    pressure_drop_pa::Float64
    meshes::Vector{NTuple{3,Int}}
    output_dir::String
    summary_csv::String
    overwrite::Bool
    parallel_workers::Int
end

function StationaryStokesRefinementSpec(;
    base_params::Params = Params(nx=80, tfinal=0.0, initial_condition=GeometryRestIC()),
    severities = [0.0, 23.0, 40.0, 50.0],
    pressure_drop_pa::Real = 40.0,
    meshes = [(8, 2, 8), (16, 4, 16), (32, 6, 32), (64, 6, 32)],
    output_dir::AbstractString = "",
    summary_csv::AbstractString = "",
    overwrite::Bool = false,
    parallel_workers::Int = default_case_workers(),
)
    severity_values = [Float64(severity) for severity in severities]
    mesh_values = [(Int(mesh[1]), Int(mesh[2]), Int(mesh[3])) for mesh in meshes]
    return StationaryStokesRefinementSpec(
        base_params,
        severity_values,
        Float64(pressure_drop_pa),
        mesh_values,
        String(output_dir),
        String(summary_csv),
        overwrite,
        parallel_workers,
    )
end

"""
    StationaryStokesRefinementRow

One output row for the stationary-Stokes refinement study summary table.
Successful rows contain FE/projection/refinement diagnostics; failed rows keep
the mesh metadata plus an error message and leave numerical fields as `NaN`.
"""
Base.@kwdef struct StationaryStokesRefinementRow
    case_id::String
    severity::Float64
    pressure_drop_pa::Float64
    mesh_nz::Int
    mesh_nr::Int
    mesh_ntheta::Int
    projection_nr::Int
    projection_ntheta::Int
    mesh_nodes::Int
    mesh_cells::Int
    velocity_dofs::Int
    pressure_dofs::Int
    elapsed_s::Float64
    mean_flow::Float64
    fe_uavg_min::Float64
    fe_uavg_max::Float64
    projection_uavg_min::Float64
    projection_uavg_max::Float64
    fe_pressure_min::Float64
    fe_pressure_max::Float64
    projection_pressure_min::Float64
    projection_pressure_max::Float64
    fe_projection_u_l2_relative_error::Float64
    fe_projection_pressure_l2_relative_error::Float64
    finest_u_l2_relative_error::Float64
    finest_pressure_l2_relative_error::Float64
    traction_samples::Int
    wall_traction_mean::Float64
    wall_traction_max::Float64
    wss_mean::Float64
    wss_max::Float64
    status::String
    error_message::String
end

"""
    StationaryStokesRefinementResult

Result bundle returned by [`run_stationary_stokes_refinement`](@ref).
"""
struct StationaryStokesRefinementResult
    spec::StationaryStokesRefinementSpec
    rows::Vector{StationaryStokesRefinementRow}
    summary_csv::String
end

workflow_kind(::StationaryStokesRefinementSpec) = "stationary_stokes_refinement"

function validate(spec::StationaryStokesRefinementSpec)
    !isempty(spec.severities) || throw(ArgumentError("stationary Stokes refinement requires at least one severity"))
    !isempty(spec.meshes) || throw(ArgumentError("stationary Stokes refinement requires at least one mesh"))
    isfinite(spec.pressure_drop_pa) || throw(ArgumentError("stationary Stokes pressure drop must be finite"))
    spec.pressure_drop_pa > 0.0 || throw(ArgumentError("stationary Stokes pressure drop must be positive"))
    spec.base_params.nx >= 3 || throw(ArgumentError("base_params.nx must be at least 3 for section sampling"))
    spec.base_params.length_cm > 0.0 || throw(ArgumentError("base_params.length_cm must be positive"))
    spec.base_params.rmax > 0.0 || throw(ArgumentError("base_params.rmax must be positive"))
    spec.base_params.rho > 0.0 || throw(ArgumentError("base_params.rho must be positive"))
    spec.base_params.nu > 0.0 || throw(ArgumentError("base_params.nu must be positive for stationary Stokes"))
    spec.parallel_workers >= 0 || throw(ArgumentError("parallel_workers must be nonnegative"))
    return spec
end

function stationary_stokes_refinement_summary_path(spec::StationaryStokesRefinementSpec)
    !isempty(spec.summary_csv) && return spec.summary_csv
    outdir = isempty(spec.output_dir) ? default_stationary_stokes_refinement_output_dir() : spec.output_dir
    return joinpath(outdir, "summary.csv")
end

default_stationary_stokes_refinement_output_dir() =
    joinpath(DEFAULT_SIMULATION_OUTPUT_ROOT, "stationary_stokes_refinement")

function stationary_stokes_refinement_tex_path(summary_csv::String)
    endswith(summary_csv, ".csv") && return summary_csv[begin:end-4] * ".tex"
    return summary_csv * ".tex"
end

function default_output_paths(spec::StationaryStokesRefinementSpec)
    summary_csv = stationary_stokes_refinement_summary_path(spec)
    return (
        summary_csv=summary_csv,
        summary_tex=stationary_stokes_refinement_tex_path(summary_csv),
    )
end

"""
    stationary_stokes_refinement_spec_from_values(values, flags)

Build a workflow spec from already-parsed CLI dictionaries.

This workflow is steady-state, so `tfinal` is forced to `0.0` before delegating
to the shared parameter builder.
"""
function stationary_stokes_refinement_spec_from_values(values::Dict{String,String}, flags::Set{String})
    param_values = copy(values)
    haskey(param_values, "tfinal") || (param_values["tfinal"] = "0.0")
    params, _, _ = params_backend_progress(param_values, flags)
    return StationaryStokesRefinementSpec(;
        base_params=params,
        severities=parse_float_list(get(values, "severities", "0,23,40,50")),
        pressure_drop_pa=parse(Float64, get(values, "pressure-drop-pa", "40")),
        meshes=parse_mesh_list(get(values, "meshes", "8x2x8,16x4x16,32x6x32,64x6x32")),
        output_dir=get(values, "output-dir", ""),
        summary_csv=get(values, "summary-csv", ""),
        overwrite=("overwrite" in flags),
        parallel_workers=parse(Int, get(values, "parallel-workers", string(default_case_workers()))),
    )
end
