if VERSION < v"1.12"
    error(
        "simulations/export_stenosis_geometry_figures.jl requires Julia 1.12 or newer. " *
        "Run it with ./scripts/julia-release simulations/export_stenosis_geometry_figures.jl ...",
    )
end

include("canic_extended_1d/CanicExtended1D.jl")

using .CanicExtended1D
using Printf

const DEFAULT_GEOMETRY_OUTPUT_DIR = joinpath("figures", "static", "static", "data", "stenosis-geometry")
const ANALYTIC_SEVERITIES = (0.0, 23.0, 40.0, 50.0)

Base.@kwdef struct ExportOptions
    output_dir::String = DEFAULT_GEOMETRY_OUTPUT_DIR
    data_root::String = default_resolved3d_data_root()
    z_samples::Int = 181
    theta_samples::Int = 72
    overwrite::Bool = false
end

function parse_export_args(args)
    opts = ExportOptions()
    i = 1
    while i <= length(args)
        arg = args[i]
        if arg == "--output-dir"
            i += 1
            i <= length(args) || throw(ArgumentError("--output-dir requires a path"))
            opts = ExportOptions(;
                output_dir=args[i],
                data_root=opts.data_root,
                z_samples=opts.z_samples,
                theta_samples=opts.theta_samples,
                overwrite=opts.overwrite,
            )
        elseif arg == "--data-root"
            i += 1
            i <= length(args) || throw(ArgumentError("--data-root requires a path"))
            opts = ExportOptions(;
                output_dir=opts.output_dir,
                data_root=args[i],
                z_samples=opts.z_samples,
                theta_samples=opts.theta_samples,
                overwrite=opts.overwrite,
            )
        elseif arg == "--z-samples"
            i += 1
            i <= length(args) || throw(ArgumentError("--z-samples requires an integer"))
            opts = ExportOptions(;
                output_dir=opts.output_dir,
                data_root=opts.data_root,
                z_samples=parse(Int, args[i]),
                theta_samples=opts.theta_samples,
                overwrite=opts.overwrite,
            )
        elseif arg == "--theta-samples"
            i += 1
            i <= length(args) || throw(ArgumentError("--theta-samples requires an integer"))
            opts = ExportOptions(;
                output_dir=opts.output_dir,
                data_root=opts.data_root,
                z_samples=opts.z_samples,
                theta_samples=parse(Int, args[i]),
                overwrite=opts.overwrite,
            )
        elseif arg == "--overwrite"
            opts = ExportOptions(;
                output_dir=opts.output_dir,
                data_root=opts.data_root,
                z_samples=opts.z_samples,
                theta_samples=opts.theta_samples,
                overwrite=true,
            )
        elseif arg in ("-h", "--help")
            print_help()
            exit(0)
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
      ./scripts/julia-release simulations/export_stenosis_geometry_figures.jl [options]

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
    mkpath(dirname(path))
    if isfile(path) && !overwrite
        throw(ArgumentError("refusing to overwrite existing file '$path'; pass --overwrite"))
    end
    open(path, "w") do io
        writer(io)
    end
    return path
end

fmt(x::Real) = @sprintf("%.12g", Float64(x))

function csv_row(values)
    return join((value isa Real ? fmt(value) : string(value) for value in values), ",")
end

function radius_at(z::Float64, severity::Float64)
    params = Params(severity=severity)
    r0, _, _ = CanicExtended1D.stenosis(z, params)
    return r0
end

function export_all(opts::ExportOptions)
    paths = String[]
    append!(paths, export_analytic_summary(opts))
    append!(paths, export_analytic_profiles(opts))
    append!(paths, export_analytic_surfaces(opts))
    append!(paths, export_analytic_cross_sections(opts))
    append!(paths, export_resolved_envelopes(opts))

    println("wrote $(length(paths)) geometry export files")
    for path in paths
        println(path)
    end
    return paths
end

function export_analytic_summary(opts::ExportOptions)
    path = joinpath(opts.output_dir, "analytic_summary.csv")
    guarded_open(path, opts.overwrite) do io
        println(io, "severity,throat_z_cm,rmin_cm,rbase_cm,rmin_over_rbase")
        for severity in ANALYTIC_SEVERITIES
            params = Params(severity=severity)
            throat_z = stenosis_throat_z(params)
            rmin, _, _ = CanicExtended1D.stenosis(throat_z, params)
            println(io, csv_row((severity, throat_z, rmin, params.rmax, rmin / params.rmax)))
        end
    end
    return [path]
end

function export_analytic_profiles(opts::ExportOptions)
    path = joinpath(opts.output_dir, "analytic_radius_profiles.csv")
    guarded_open(path, opts.overwrite) do io
        println(io, "severity,z_cm,r0_cm,rbase_cm,s_fraction")
        for severity in ANALYTIC_SEVERITIES
            params = Params(severity=severity)
            for z in range(0.0, params.length_cm; length=opts.z_samples)
                r0, _, _ = CanicExtended1D.stenosis(Float64(z), params)
                s_fraction = 1.0 - r0 / params.rmax
                println(io, csv_row((severity, z, r0, params.rmax, s_fraction)))
            end
        end
    end
    return [path]
end

function export_analytic_surfaces(opts::ExportOptions)
    paths = String[]
    for severity in ANALYTIC_SEVERITIES
        params = Params(severity=severity)
        path = joinpath(opts.output_dir, "analytic_surface_sev$(round(Int, severity)).csv")
        guarded_open(path, opts.overwrite) do io
            println(io, "severity,z_cm,theta_rad,x_cm,y_cm,r_cm")
            for z in range(0.0, params.length_cm; length=opts.z_samples)
                r0, _, _ = CanicExtended1D.stenosis(Float64(z), params)
                for j in 0:(opts.theta_samples - 1)
                    theta = 2.0 * pi * j / opts.theta_samples
                    x = r0 * cos(theta)
                    y = r0 * sin(theta)
                    println(io, csv_row((severity, z, theta, x, y, r0)))
                end
            end
        end
        push!(paths, path)
    end
    return paths
end

function export_analytic_cross_sections(opts::ExportOptions)
    params = Params(severity=50.0)
    throat_z = stenosis_throat_z(params)
    slices = (
        ("upstream", max(0.0, throat_z - 0.5)),
        ("throat", throat_z),
        ("downstream", min(params.length_cm, throat_z + 0.5)),
    )
    path = joinpath(opts.output_dir, "analytic_cross_sections.csv")
    guarded_open(path, opts.overwrite) do io
        println(io, "severity,slice_label,z_cm,theta_rad,x_cm,y_cm,r_cm")
        for (label, z) in slices
            r0, _, _ = CanicExtended1D.stenosis(Float64(z), params)
            for j in 0:(opts.theta_samples - 1)
                theta = 2.0 * pi * j / opts.theta_samples
                x = r0 * cos(theta)
                y = r0 * sin(theta)
                println(io, csv_row((50.0, label, z, theta, x, y, r0)))
            end
        end
    end
    return [path]
end

function export_resolved_envelopes(opts::ExportOptions)
    paths = String[]
    manifest = joinpath(opts.output_dir, "resolved_envelope_manifest.csv")
    cases = available_resolved3d_cases(opts.data_root)

    guarded_open(manifest, opts.overwrite) do io
        println(io, "status,data_root,case_label,severity,source_xdmf,output_csv,node_count,z_bins,theta_bins,note")
        if isempty(cases)
            println(io, csv_row(("skipped", opts.data_root, "", "", "", "", 0, opts.z_samples, opts.theta_samples, "no local XDMF files found")))
            return
        end

        for case in cases
            field = load_resolved3d_velocity(case)
            output_csv = resolved_envelope_path(opts.output_dir, case)
            write_resolved_envelope_csv(output_csv, field, opts; overwrite=opts.overwrite)
            push!(paths, output_csv)
            println(io, csv_row((
                "written",
                opts.data_root,
                case.case_label,
                case.severity,
                case.velocity_xdmf,
                output_csv,
                size(field.coordinates, 1),
                opts.z_samples,
                opts.theta_samples,
                "node-envelope view, not exact wall surface",
            )))
        end
    end

    return [manifest; paths]
end

function resolved_envelope_path(output_dir::String, case::Resolved3DCaseSpec)
    return joinpath(
        output_dir,
        "resolved_envelope_case$(case.case_label)_sev$(round(Int, case.severity)).csv",
    )
end

function write_resolved_envelope_csv(
    path::String,
    field::Resolved3DVelocityField,
    opts::ExportOptions;
    overwrite::Bool = false,
)
    coords = field.coordinates
    z_values = coords[:, 3]
    zmin = minimum(z_values)
    zmax = maximum(z_values)
    zspan = max(zmax - zmin, eps())

    max_radius = fill(NaN, opts.z_samples, opts.theta_samples)
    counts = zeros(Int, opts.z_samples, opts.theta_samples)

    for i in axes(coords, 1)
        x = coords[i, 1]
        y = coords[i, 2]
        z = coords[i, 3]
        radius = hypot(x, y)
        theta = atan(y, x)
        theta < 0.0 && (theta += 2.0 * pi)
        z_bin = clamp(floor(Int, (z - zmin) / zspan * opts.z_samples) + 1, 1, opts.z_samples)
        theta_bin = clamp(floor(Int, theta / (2.0 * pi) * opts.theta_samples) + 1, 1, opts.theta_samples)
        counts[z_bin, theta_bin] += 1
        if !isfinite(max_radius[z_bin, theta_bin]) || radius > max_radius[z_bin, theta_bin]
            max_radius[z_bin, theta_bin] = radius
        end
    end

    guarded_open(path, overwrite) do io
        println(io, "case_label,severity,z_cm,theta_rad,x_cm,y_cm,r_cm,node_count,source")
        for iz in 1:opts.z_samples
            z_center = zmin + (iz - 0.5) / opts.z_samples * zspan
            for itheta in 1:opts.theta_samples
                count = counts[iz, itheta]
                count == 0 && continue
                theta = 2.0 * pi * (itheta - 0.5) / opts.theta_samples
                radius = max_radius[iz, itheta]
                x = radius * cos(theta)
                y = radius * sin(theta)
                println(io, csv_row((
                    field.case_spec.case_label,
                    field.case_spec.severity,
                    z_center,
                    theta,
                    x,
                    y,
                    radius,
                    count,
                    "node-envelope-not-wall-surface",
                )))
            end
        end
    end
end

if abspath(PROGRAM_FILE) == @__FILE__
    export_all(parse_export_args(ARGS))
end
