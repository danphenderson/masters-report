const NATIVE_RESOLVED_FSI_WEB_EXPORT_STATIC_SCHEMA_VERSION = 1
const NATIVE_RESOLVED_FSI_WEB_EXPORT_TEMPORAL_SCHEMA_VERSION = 2
const NATIVE_RESOLVED_FSI_WEB_EXPORT_SCHEMA_VERSION = NATIVE_RESOLVED_FSI_WEB_EXPORT_STATIC_SCHEMA_VERSION
const NATIVE_RESOLVED_FSI_WEB_EXPORT_DEFAULT_OUTPUT_ROOT =
    joinpath(DEFAULT_SIMULATION_OUTPUT_ROOT, "visualization")
const NATIVE_RESOLVED_FSI_WEB_EXPORT_CLAIM_BOUNDARY =
    "native resolved-FSI artifact/operator evidence only; not paper-grade Section 4.1 reproduction"

"""
    NativeResolvedFSIWebExportSpec(; kwargs...)

Static-browser export policy for one resolved-3D velocity/pressure/displacement
bundle. This workflow converts package-native XDMF/HDF5 fields into small JSON
and binary assets for a Vite/React viewer. It does not run solvers or promote
generated assets into report-consumed outputs.
"""
struct NativeResolvedFSIWebExportSpec
    schema_version::Int
    velocity_xdmf::String
    pressure_xdmf::String
    displacement_xdmf::String
    input_production_dir::String
    output_dir::String
    case_id::Symbol
    target_time::Float64
    time_atol::Float64
    coordinate_mode::Symbol
    geometry_mode::Symbol
    include_tetra_debug::Bool
    include_observations::Bool
    include_derived::Bool
    allow_velocity_only::Bool
    diagnostics_csv::String
    restart_metadata_json::String
    observations_csv::String
    observation_summary_csv::String
    batch_benchmark_json::String
    snapshot_include::Vector{String}
    snapshot_exclude::Vector{String}
    snapshot_stride::Int
    max_snapshots::Union{Nothing,Int}
    overwrite::Bool
end

function NativeResolvedFSIWebExportSpec(;
    schema_version = nothing,
    velocity_xdmf::AbstractString = "",
    pressure_xdmf::AbstractString = default_companion_xdmf_path(velocity_xdmf, "pressure.xdmf"),
    displacement_xdmf::AbstractString = default_companion_xdmf_path(velocity_xdmf, "displace.xdmf"),
    input_production_dir::AbstractString = "",
    output_dir::AbstractString = "",
    case_id::Union{Symbol,AbstractString,Real} = :sev23,
    target_time::Real = RESOLVED3D_DEFAULT_BENCHMARK_TIME_S,
    time_atol::Real = 1.0e-3,
    coordinate_mode::Union{Symbol,AbstractString} = :reference,
    geometry_mode::Union{Symbol,AbstractString} = :surface,
    include_tetra_debug::Bool = false,
    include_observations::Bool = true,
    include_derived::Bool = true,
    allow_velocity_only::Bool = false,
    diagnostics_csv::AbstractString = "",
    restart_metadata_json::AbstractString = "",
    observations_csv::AbstractString = "",
    observation_summary_csv::AbstractString = "",
    batch_benchmark_json::AbstractString = "",
    snapshot_include = String[],
    snapshot_exclude = String[],
    snapshot_stride::Integer = 1,
    max_snapshots = nothing,
    overwrite::Bool = false,
)
    native_case = native_resolved_fsi_case_spec(case_id)
    outdir = isempty(output_dir) ? default_native_resolved_fsi_web_export_output_dir(native_case) : String(output_dir)
    production_dir = String(input_production_dir)
    resolved_schema_version = schema_version === nothing ?
                              (isempty(production_dir) ?
                               NATIVE_RESOLVED_FSI_WEB_EXPORT_STATIC_SCHEMA_VERSION :
                               NATIVE_RESOLVED_FSI_WEB_EXPORT_TEMPORAL_SCHEMA_VERSION) :
                              native_resolved_fsi_web_export_schema_version(schema_version)
    return validate(NativeResolvedFSIWebExportSpec(
        resolved_schema_version,
        String(velocity_xdmf),
        String(pressure_xdmf),
        String(displacement_xdmf),
        production_dir,
        outdir,
        native_case.case_id,
        Float64(target_time),
        Float64(time_atol),
        native_resolved_fsi_web_export_coordinate_mode(coordinate_mode),
        native_resolved_fsi_web_export_geometry_mode(geometry_mode),
        include_tetra_debug,
        include_observations,
        include_derived,
        allow_velocity_only,
        String(diagnostics_csv),
        String(restart_metadata_json),
        String(observations_csv),
        String(observation_summary_csv),
        String(batch_benchmark_json),
        native_resolved_fsi_web_export_selector_values(snapshot_include),
        native_resolved_fsi_web_export_selector_values(snapshot_exclude),
        Int(snapshot_stride),
        native_resolved_fsi_web_export_optional_int(max_snapshots, "max_snapshots"),
        overwrite,
    ))
end

native_resolved_fsi_web_export_spec(; kwargs...) = NativeResolvedFSIWebExportSpec(; kwargs...)

function default_native_resolved_fsi_web_export_output_dir(case_spec::NativeResolvedFSICaseSpec)
    return joinpath(NATIVE_RESOLVED_FSI_WEB_EXPORT_DEFAULT_OUTPUT_ROOT, string(case_spec.case_id))
end

function native_resolved_fsi_web_export_schema_version(value)
    version = value isa AbstractString ? parse(Int, value) : Int(value)
    version in (
        NATIVE_RESOLVED_FSI_WEB_EXPORT_STATIC_SCHEMA_VERSION,
        NATIVE_RESOLVED_FSI_WEB_EXPORT_TEMPORAL_SCHEMA_VERSION,
    ) || throw(ArgumentError("native resolved-FSI web export schema_version must be 1 or 2"))
    return version
end

function native_resolved_fsi_web_export_coordinate_mode(value::Union{Symbol,AbstractString})
    mode = Symbol(replace(lowercase(strip(String(value))), "-" => "_"))
    mode in (:reference, :deformed) ||
        throw(ArgumentError("native resolved-FSI web export coordinate_mode must be reference or deformed"))
    return mode
end

function native_resolved_fsi_web_export_geometry_mode(value::Union{Symbol,AbstractString})
    mode = Symbol(replace(lowercase(strip(String(value))), "-" => "_"))
    mode === :surface ||
        throw(ArgumentError("native resolved-FSI web export geometry_mode currently supports only surface"))
    return mode
end

function native_resolved_fsi_web_export_selector_values(values::AbstractString)
    text = strip(String(values))
    isempty(text) && return String[]
    return String[strip(part) for part in split(text, ",") if !isempty(strip(part))]
end

function native_resolved_fsi_web_export_selector_values(values)
    return String[strip(String(value)) for value in values if !isempty(strip(String(value)))]
end

function native_resolved_fsi_web_export_optional_int(value, label::String)
    value === nothing && return nothing
    int_value = value isa AbstractString ? parse(Int, value) : Int(value)
    int_value >= 1 || throw(ArgumentError("native resolved-FSI web export $label must be positive"))
    return int_value
end

function validate(spec::NativeResolvedFSIWebExportSpec)
    native_resolved_fsi_web_export_schema_version(spec.schema_version)
    if isempty(spec.input_production_dir)
        !isempty(spec.velocity_xdmf) ||
            throw(ArgumentError("native resolved-FSI web export requires --velocity-xdmf or --input-production-dir"))
        isfile(spec.velocity_xdmf) ||
            throw(ArgumentError("native resolved-FSI web export velocity XDMF not found: $(spec.velocity_xdmf)"))
        spec.allow_velocity_only || !isempty(spec.pressure_xdmf) ||
            throw(ArgumentError("native resolved-FSI web export requires pressure_xdmf unless allow_velocity_only=true"))
        spec.allow_velocity_only || !isempty(spec.displacement_xdmf) ||
            throw(ArgumentError("native resolved-FSI web export requires displacement_xdmf unless allow_velocity_only=true"))
        spec.allow_velocity_only || isfile(spec.pressure_xdmf) ||
            throw(ArgumentError("native resolved-FSI web export pressure XDMF not found: $(spec.pressure_xdmf)"))
        spec.allow_velocity_only || isfile(spec.displacement_xdmf) ||
            throw(ArgumentError("native resolved-FSI web export displacement XDMF not found: $(spec.displacement_xdmf)"))
    else
        isdir(spec.input_production_dir) ||
            throw(ArgumentError("native resolved-FSI web export production input directory not found: $(spec.input_production_dir)"))
    end
    isfinite(spec.target_time) ||
        throw(ArgumentError("native resolved-FSI web export target_time must be finite"))
    spec.target_time >= 0.0 ||
        throw(ArgumentError("native resolved-FSI web export target_time must be nonnegative"))
    isfinite(spec.time_atol) ||
        throw(ArgumentError("native resolved-FSI web export time_atol must be finite"))
    spec.time_atol >= 0.0 ||
        throw(ArgumentError("native resolved-FSI web export time_atol must be nonnegative"))
    !isempty(spec.output_dir) ||
        throw(ArgumentError("native resolved-FSI web export output_dir must not be empty"))
    native_resolved_fsi_web_export_coordinate_mode(spec.coordinate_mode)
    native_resolved_fsi_web_export_geometry_mode(spec.geometry_mode)
    spec.snapshot_stride >= 1 ||
        throw(ArgumentError("native resolved-FSI web export snapshot_stride must be positive"))
    return spec
end

struct NativeResolvedFSIWebExportSnapshotSource
    source_id::String
    time_s::Float64
    velocity_xdmf::String
    pressure_xdmf::String
    displacement_xdmf::String
end

"""
    NativeResolvedFSIWebExportResult

Paths and manifest metadata written by `run_native_resolved_fsi_web_export`.
"""
struct NativeResolvedFSIWebExportResult
    spec::NativeResolvedFSIWebExportSpec
    output_dir::String
    manifest_json::String
    asset_paths::Vector{String}
    manifest::Dict{String,Any}
    frame_count::Int
    skipped_snapshots::Vector{String}
    estimated_playback_fps::Float64
end
