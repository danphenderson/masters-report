"""
    MembraneFSIValidationSpec(; kwargs...)

Workflow configuration for the membrane-FSI validation study. Each case combines
one stenosis severity, one stationary Stokes mesh, and one membrane wall mode,
then writes case-level profile/history files plus workflow summaries.
"""
struct MembraneFSIValidationSpec{M<:AbstractMembraneWallMode,F} <: AbstractStudySpec
    base_params::Params
    severities::Vector{Float64}
    geometry_id::String
    reference_radius_at_z::F
    pressure_drop_pa::Float64
    meshes::Vector{NTuple{3,Int}}
    mode::M
    output_dir::String
    summary_csv::String
    summary_tex::String
    manifest_json::String
    overwrite::Bool
    max_coupling_iters::Int
    coupling_tolerance_cm::Float64
    damping::Float64
    reference_radius_cm::Float64
    history_stride::Int
    parallel_workers::Int
end

function MembraneFSIValidationSpec(;
    base_params::Params = Params(nx=80, tfinal=0.0, initial_condition=GeometryRestIC()),
    severities = [23.0, 40.0],
    geometry_id::AbstractString = "",
    reference_radius_at_z = nothing,
    pressure_drop_pa::Real = 40.0,
    meshes = [(8, 2, 8), (16, 4, 16)],
    mode::AbstractMembraneWallMode = QuasiStaticMembraneMode(),
    output_dir::AbstractString = "",
    summary_csv::AbstractString = "",
    summary_tex::AbstractString = "",
    manifest_json::AbstractString = "",
    overwrite::Bool = false,
    max_coupling_iters::Int = 12,
    coupling_tolerance_cm::Real = 1.0e-7,
    damping::Real = 0.5,
    reference_radius_cm::Real = wall_reference_radius(base_params),
    history_stride::Int = 1,
    parallel_workers::Int = default_case_workers(),
)
    severity_values = [Float64(severity) for severity in severities]
    mesh_values = [(Int(mesh[1]), Int(mesh[2]), Int(mesh[3])) for mesh in meshes]
    geometry_label = membrane_geometry_label(geometry_id, reference_radius_at_z)
    return MembraneFSIValidationSpec{typeof(mode),typeof(reference_radius_at_z)}(
        base_params,
        severity_values,
        geometry_label,
        reference_radius_at_z,
        Float64(pressure_drop_pa),
        mesh_values,
        mode,
        String(output_dir),
        String(summary_csv),
        String(summary_tex),
        String(manifest_json),
        overwrite,
        max_coupling_iters,
        Float64(coupling_tolerance_cm),
        Float64(damping),
        Float64(reference_radius_cm),
        history_stride,
        parallel_workers,
    )
end

"""
    MembraneFSIValidationRow

One membrane-FSI validation case summary row, including mesh metadata, coupling
metrics, wall-response extrema, output file paths, and terminal status.
"""
Base.@kwdef struct MembraneFSIValidationRow
    case_id::String
    severity::Float64
    wall_mode::String
    geometry_id::String
    pressure_drop_pa::Float64
    pressure_drop_dyn_cm2::Float64
    mesh_nz::Int
    mesh_nr::Int
    mesh_ntheta::Int
    mesh_nodes::Int
    mesh_cells::Int
    velocity_dofs::Int
    pressure_dofs::Int
    iterations::Int
    converged::Bool
    residual_cm::Float64
    elapsed_s::Float64
    time_s::Float64
    time_step_count::Int
    reference_radius_cm::Float64
    displacement_min_cm::Float64
    displacement_max_cm::Float64
    current_radius_min_cm::Float64
    current_radius_max_cm::Float64
    max_radius_change_rel::Float64
    wall_velocity_min_cm_s::Float64
    wall_velocity_max_cm_s::Float64
    wall_force_mean_dyn_cm2::Float64
    wall_force_max_dyn_cm2::Float64
    pressure_min_dyn_cm2::Float64
    pressure_max_dyn_cm2::Float64
    mean_flow_cm3_s::Float64
    profile_csv::String
    history_csv::String
    status::String
    error_message::String
end

"""
    MembraneFSIValidationResult

Return bundle for `run_membrane_fsi_validation`, carrying the workflow spec,
case rows, and the three workflow-level summary paths written by the run.
"""
struct MembraneFSIValidationResult
    spec::MembraneFSIValidationSpec
    rows::Vector{MembraneFSIValidationRow}
    summary_csv::String
    summary_tex::String
    manifest_json::String
end

workflow_kind(::MembraneFSIValidationSpec) = "membrane_fsi_validation"

function validate(spec::MembraneFSIValidationSpec)
    validate(spec.base_params)
    !isempty(spec.severities) || throw(ArgumentError("membrane FSI validation requires at least one severity"))
    !isempty(spec.meshes) || throw(ArgumentError("membrane FSI validation requires at least one mesh"))
    spec.pressure_drop_pa > 0.0 || throw(ArgumentError("membrane FSI pressure drop must be positive"))
    spec.base_params.nu > 0.0 || throw(ArgumentError("membrane FSI requires positive Newtonian viscosity"))
    all(mesh -> all(>(0), mesh), spec.meshes) || throw(ArgumentError("all membrane FSI mesh entries must be positive"))
    spec.max_coupling_iters >= 1 || throw(ArgumentError("max_coupling_iters must be positive"))
    spec.coupling_tolerance_cm > 0.0 || throw(ArgumentError("coupling_tolerance_cm must be positive"))
    0.0 < spec.damping <= 1.0 || throw(ArgumentError("damping must lie in (0, 1]"))
    spec.reference_radius_cm > 0.0 || throw(ArgumentError("reference_radius_cm must be positive"))
    spec.history_stride >= 1 || throw(ArgumentError("history_stride must be positive"))
    spec.parallel_workers >= 0 || throw(ArgumentError("parallel_workers must be nonnegative"))
    validate_membrane_geometry_callback(spec)
    if spec.mode isa DynamicMembraneMode
        spec.mode.wall_density > 0.0 || throw(ArgumentError("dynamic membrane wall_density must be positive"))
        spec.mode.dt > 0.0 || throw(ArgumentError("dynamic membrane dt must be positive"))
        spec.mode.tfinal > 0.0 || throw(ArgumentError("dynamic membrane tfinal must be positive"))
    end
    return spec
end

function membrane_geometry_label(geometry_id::AbstractString, reference_radius_at_z)
    text = strip(String(geometry_id))
    !isempty(text) && return text
    return reference_radius_at_z === nothing ? "canic-stenosis" : "custom-smooth-radius"
end

function validate_membrane_geometry_callback(spec::MembraneFSIValidationSpec)
    spec.reference_radius_at_z === nothing && return spec
    samples = (0.0, Float64(spec.base_params.length_cm) / 2.0, Float64(spec.base_params.length_cm))
    for z in samples
        stokes_mesh_radius(spec.reference_radius_at_z, z)
    end
    return spec
end

function default_membrane_fsi_output_dir()
    return joinpath(DEFAULT_SIMULATION_OUTPUT_ROOT, "membrane_fsi_validation")
end

function default_output_paths(spec::MembraneFSIValidationSpec)
    outdir = isempty(spec.output_dir) ? default_membrane_fsi_output_dir() : spec.output_dir
    summary_csv = isempty(spec.summary_csv) ? joinpath(outdir, "summary.csv") : spec.summary_csv
    summary_tex = isempty(spec.summary_tex) ? replace(summary_csv, r"\.csv$" => ".tex") : spec.summary_tex
    manifest_json = isempty(spec.manifest_json) ? joinpath(outdir, "manifest.json") : spec.manifest_json
    return (summary_csv=summary_csv, summary_tex=summary_tex, manifest_json=manifest_json)
end

"""
    membrane_wall_mode_from_cli(values)

Parse membrane wall-mode options from CLI key/value strings and return the
corresponding membrane mode object used by the workflow.
"""
function membrane_wall_mode_from_cli(values::Dict{String,String})
    mode = replace(lowercase(strip(get(values, "wall-mode", "quasi-static"))), "_" => "-")
    if mode in ("quasi-static", "quasistatic", "steady", "quasi-static-membrane")
        return QuasiStaticMembraneMode()
    elseif mode in ("dynamic", "dynamic-membrane")
        return DynamicMembraneMode(
            wall_density=parse(Float64, get(values, "wall-density", "1.0")),
            dt=parse(Float64, get(values, "wall-dt", "1e-5")),
            tfinal=parse(Float64, get(values, "wall-tfinal", "1e-4")),
        )
    end
    throw(ArgumentError("unknown FSI wall mode '$mode'; expected quasi-static or dynamic"))
end

"""
    membrane_fsi_validation_spec_from_values(base_params, values, flags)

Build a membrane-FSI workflow spec from CLI-parsed values without changing any
default semantics used by the existing command surface.
"""
function membrane_fsi_validation_spec_from_values(
    base_params::Params,
    values::Dict{String,String},
    flags::Set{String},
)
    return MembraneFSIValidationSpec(;
        base_params=base_params,
        severities=parse_float_list(get(values, "severities", "23,40")),
        pressure_drop_pa=parse(Float64, get(values, "pressure-drop-pa", "40")),
        meshes=parse_mesh_list(get(values, "meshes", "8x2x8,16x4x16")),
        mode=membrane_wall_mode_from_cli(values),
        output_dir=get(values, "output-dir", ""),
        summary_csv=get(values, "summary-csv", ""),
        summary_tex=get(values, "summary-tex", ""),
        manifest_json=get(values, "manifest-json", ""),
        overwrite=("overwrite" in flags),
        max_coupling_iters=parse(Int, get(values, "max-coupling-iters", "12")),
        coupling_tolerance_cm=parse(Float64, get(values, "coupling-tolerance-cm", "1e-7")),
        damping=parse(Float64, get(values, "damping", "0.5")),
        reference_radius_cm=parse(Float64, get(values, "reference-radius-cm", string(base_params.rmax))),
        history_stride=parse(Int, get(values, "history-stride", "1")),
        parallel_workers=parse(Int, get(values, "parallel-workers", string(default_case_workers()))),
    )
end
