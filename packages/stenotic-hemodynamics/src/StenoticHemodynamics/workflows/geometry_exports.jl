using Printf

const PROJECT_ROOT = normpath(joinpath(@__DIR__, "..", "..", "..", ".."))
const DEFAULT_GEOMETRY_OUTPUT_DIR = joinpath(PROJECT_ROOT, "report", "assets", "data", "stenosis-geometry")
const ANALYTIC_SEVERITIES = (0.0, 23.0, 40.0, 50.0, 73.0)
const TRAJECTORY_SEVERITIES = (23.0, 50.0, 73.0)
const TRAJECTORY_Z_START_CM = 0.05
const TRAJECTORY_Z_END_CM = 5.95
const TRAJECTORY_SAMPLES = 241
const TRAJECTORY_PRESSURE_DROP_PA = 40.0
const TRAJECTORY_MESH_NZ = 64
const TRAJECTORY_MESH_NR = 6
const TRAJECTORY_MESH_NTHETA = 32
const TRAJECTORY_SEED_RADIUS_FRACTION = 0.45
const TRAJECTORY_THROAT_RADIUS_FRACTION_CAP = 0.70
const MESH_VIEW_SEVERITY = 50.0
const MESH_VIEW_PRESSURE_DROP_PA = TRAJECTORY_PRESSURE_DROP_PA
const MESH_VIEW_FEM_NZ = TRAJECTORY_MESH_NZ
const MESH_VIEW_FEM_NR = TRAJECTORY_MESH_NR
const MESH_VIEW_FEM_NTHETA = TRAJECTORY_MESH_NTHETA

Base.@kwdef struct GeometryExportOptions
    output_dir::String = DEFAULT_GEOMETRY_OUTPUT_DIR
    data_root::String = default_geometry_data_root()
    z_samples::Int = 181
    theta_samples::Int = 72
    overwrite::Bool = false
end

const ExportOptions = GeometryExportOptions

function default_geometry_data_root()
    root = default_resolved3d_data_root()
    return isabspath(root) ? root : joinpath(PROJECT_ROOT, root)
end

function export_options_like(
    opts::GeometryExportOptions;
    output_dir::String = opts.output_dir,
    data_root::String = opts.data_root,
    z_samples::Int = opts.z_samples,
    theta_samples::Int = opts.theta_samples,
    overwrite::Bool = opts.overwrite,
)
    return GeometryExportOptions(
        output_dir=output_dir,
        data_root=data_root,
        z_samples=z_samples,
        theta_samples=theta_samples,
        overwrite=overwrite,
    )
end

function parse_export_args(args)
    opts = GeometryExportOptions()
    i = 1
    while i <= length(args)
        arg = args[i]
        if arg == "--output-dir"
            i += 1
            i <= length(args) || throw(ArgumentError("--output-dir requires a path"))
            opts = export_options_like(opts; output_dir=args[i])
        elseif arg == "--data-root"
            i += 1
            i <= length(args) || throw(ArgumentError("--data-root requires a path"))
            opts = export_options_like(opts; data_root=args[i])
        elseif arg == "--z-samples"
            i += 1
            i <= length(args) || throw(ArgumentError("--z-samples requires an integer"))
            opts = export_options_like(opts; z_samples=parse(Int, args[i]))
        elseif arg == "--theta-samples"
            i += 1
            i <= length(args) || throw(ArgumentError("--theta-samples requires an integer"))
            opts = export_options_like(opts; theta_samples=parse(Int, args[i]))
        elseif arg == "--overwrite"
            opts = export_options_like(opts; overwrite=true)
        elseif arg in ("-h", "--help")
            print_help()
            return nothing
        else
            throw(ArgumentError("unknown argument: $arg"))
        end
        i += 1
    end

    opts.z_samples >= 3 || throw(ArgumentError("--z-samples must be at least 3"))
    opts.theta_samples >= 12 || throw(ArgumentError("--theta-samples must be at least 12"))
    return opts
end

function print_help()
    println("""
    Usage:
      packages/stenotic-hemodynamics/bin/stenotic-hemodynamics export-assets [options]

    Options:
      --output-dir PATH      CSV output directory (default: $(DEFAULT_GEOMETRY_OUTPUT_DIR))
      --data-root PATH       optional resolved 3D XDMF/HDF5 root
      --z-samples N          axial samples for analytic surfaces (default: 181)
      --theta-samples N      angular samples for surfaces/envelopes (default: 72)
      --overwrite            replace existing generated CSVs
      -h, --help             show this help
    """)
end

function guarded_open(writer, path::String, overwrite::Bool)
    return guarded_open_write(writer, path, overwrite)
end

fmt(x::Real) = @sprintf("%.12g", Float64(x))

function csv_row(values)
    return csv_record(values; real_formatter=fmt)
end

function portable_project_path(path::String)
    normal = normpath(path)
    project_parts = splitpath(PROJECT_ROOT)
    path_parts = splitpath(normal)
    if isabspath(normal) &&
       length(path_parts) >= length(project_parts) &&
       path_parts[1:length(project_parts)] == project_parts
        return relpath(normal, PROJECT_ROOT)
    end
    return normal
end

function radius_at(z::Float64, severity::Float64)
    params = Params(severity=severity)
    r0, _, _ = stenosis(z, params)
    return r0
end

include("geometry_export_analytic.jl")
include("geometry_export_stokes.jl")
include("geometry_export_resolved3d.jl")

function export_all(opts::GeometryExportOptions)
    paths = String[]
    append!(paths, export_analytic_summary(opts))
    append!(paths, export_analytic_profiles(opts))
    append!(paths, export_analytic_surfaces(opts))
    append!(paths, export_analytic_cross_sections(opts))
    append!(paths, export_mesh_view_data(opts))
    append!(paths, export_stokes_particle_trajectories(opts))
    append!(paths, export_resolved_velocity_nodes(opts))
    append!(paths, export_resolved_envelopes(opts))

    println("wrote $(length(paths)) geometry export files")
    for path in paths
        println(path)
    end
    return paths
end

function export_stenosis_geometry_figures(opts::GeometryExportOptions = GeometryExportOptions())
    return export_all(opts)
end
