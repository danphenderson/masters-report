if VERSION < v"1.12"
    error(
        "simulations/export_stenosis_geometry_figures.jl requires Julia 1.12 or newer. " *
        "Run it with ./scripts/julia-release simulations/export_stenosis_geometry_figures.jl ...",
    )
end

if !isdefined(Main, :CanicExtended1D)
    include("canic_extended_1d/CanicExtended1D.jl")
end

using .CanicExtended1D
using Distributed
using Gridap: Point
using Printf

const DEFAULT_GEOMETRY_OUTPUT_DIR = joinpath("figures", "static", "static", "data", "stenosis-geometry")
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
    append!(paths, export_stokes_particle_trajectories(opts))
    append!(paths, export_resolved_envelopes(opts))

    println("wrote $(length(paths)) geometry export files")
    for path in paths
        println(path)
    end
    return paths
end

function export_stokes_particle_trajectories(
    opts::ExportOptions;
    severities = TRAJECTORY_SEVERITIES,
    ic::StationaryStokesIC = StationaryStokesIC(
        pressure_drop_pa=TRAJECTORY_PRESSURE_DROP_PA,
        mesh_nz=TRAJECTORY_MESH_NZ,
        mesh_nr=TRAJECTORY_MESH_NR,
        mesh_ntheta=TRAJECTORY_MESH_NTHETA,
    ),
    z_start::Float64 = TRAJECTORY_Z_START_CM,
    z_end::Float64 = TRAJECTORY_Z_END_CM,
    z_samples::Int = TRAJECTORY_SAMPLES,
    parallel_workers::Int = CanicExtended1D.default_case_workers(),
)
    z_samples >= 2 || throw(ArgumentError("trajectory z_samples must be at least 2"))
    z_start < z_end || throw(ArgumentError("trajectory z_start must be less than z_end"))
    parallel_workers >= 0 || throw(ArgumentError("parallel_workers must be nonnegative"))

    trajectory_path = joinpath(opts.output_dir, "stokes_particle_trajectories.csv")
    manifest_path = joinpath(opts.output_dir, "stokes_particle_trajectories_manifest.csv")
    z_values = collect(range(z_start, z_end; length=z_samples))
    cases = [
        (
            severity=Float64(severity),
            ic=ic,
            z_start=z_start,
            z_end=z_end,
            z_samples=z_samples,
            z_values=z_values,
            trajectory_path=trajectory_path,
        )
        for severity in severities
    ]
    results = stokes_particle_trajectory_results(cases; parallel_workers=parallel_workers)

    guarded_open(trajectory_path, opts.overwrite) do io
        println(io, "severity,particle_id,seed_label,sample_index,z_cm,x_cm,y_cm,r_cm,r_over_r0,t_s,ux_cm_s,uy_cm_s,uz_cm_s")
        for result in results
            for row in result.trajectory_rows
                println(io, row)
            end
        end
    end

    guarded_open(manifest_path, opts.overwrite) do io
        println(io, "status,severity,pressure_drop_pa,pressure_drop_dyn_cm2,mesh_nz,mesh_nr,mesh_ntheta,seed_count,seed_definitions,z_start_cm,z_end_cm,sample_count,trajectory_csv,note")
        for result in results
            println(io, result.manifest_row)
        end
    end

    return [trajectory_path, manifest_path]
end

function stokes_particle_trajectory_results(cases; parallel_workers::Int)
    worker_count = CanicExtended1D.effective_case_workers(length(cases), parallel_workers)
    worker_count <= 1 && return map(stokes_particle_trajectory_case, cases)

    worker_ids = CanicExtended1D.case_worker_ids!(worker_count)
    initialize_stenosis_export_workers!(worker_ids)
    return pmap(stokes_particle_trajectory_case, CachingPool(worker_ids), cases)
end

function initialize_stenosis_export_workers!(worker_ids)
    isempty(worker_ids) && return worker_ids

    script_path = abspath(@__FILE__)
    for worker_id in worker_ids
        fetch(remotecall_eval(Main, worker_id, quote
            if !isdefined(Main, :STENOSIS_GEOMETRY_EXPORT_WORKER_LOADED)
                include($script_path)
                const STENOSIS_GEOMETRY_EXPORT_WORKER_LOADED = true
            end
        end
        ))
    end

    return worker_ids
end

function stokes_particle_trajectory_case(case)
    severity = Float64(case.severity)
    params = Params(severity=severity, initial_condition=case.ic)
    CanicExtended1D.validate(params)
    solution = solve_stationary_stokes(params, case.ic)
    seeds = trajectory_seeds(params, case.z_start)

    trajectory_rows = String[]
    for (particle_id, seed) in enumerate(seeds)
        rows = trace_stokes_particle_path(solution, params, seed, case.z_values)
        for (sample_index, row) in enumerate(rows)
            push!(trajectory_rows, trajectory_csv_row(severity, particle_id, seed.label, sample_index, row))
        end
    end

    manifest_row = csv_row((
        "written",
        severity,
        case.ic.pressure_drop_dyn_cm2 / 10.0,
        case.ic.pressure_drop_dyn_cm2,
        case.ic.mesh_nz,
        case.ic.mesh_nr,
        case.ic.mesh_ntheta,
        length(seeds),
        trajectory_seed_definitions(),
        case.z_start,
        case.z_end,
        case.z_samples,
        case.trajectory_path,
        "generated stationary Stokes streamlines for C-infinity geometry",
    ))

    return (severity=severity, trajectory_rows=trajectory_rows, manifest_row=manifest_row)
end

struct TrajectorySeed
    label::String
    x::Float64
    y::Float64
end

struct TrajectorySample
    z::Float64
    x::Float64
    y::Float64
    t::Float64
    ux::Float64
    uy::Float64
    uz::Float64
end

function trajectory_seeds(params::Params, z_start::Float64)
    radius = trajectory_seed_radius(params, z_start)
    seeds = TrajectorySeed[TrajectorySeed("centerline", 0.0, 0.0)]
    for (label, theta) in (
        ("theta0", 0.0),
        ("theta90", pi / 2.0),
        ("theta180", pi),
        ("theta270", 3.0 * pi / 2.0),
    )
        push!(seeds, TrajectorySeed(label, radius * cos(theta), radius * sin(theta)))
    end
    return seeds
end

function trajectory_seed_definitions()
    return "centerline;offaxis_radius_min_0p45_R0_start_0p70_R0_throat_at_theta0_90_180_270"
end

function trajectory_seed_radius(params::Params, z_start::Float64)
    r_start, _, _ = CanicExtended1D.stenosis(z_start, params)
    throat_z = stenosis_throat_z(params)
    r_throat, _, _ = CanicExtended1D.stenosis(throat_z, params)
    return min(
        TRAJECTORY_SEED_RADIUS_FRACTION * r_start,
        TRAJECTORY_THROAT_RADIUS_FRACTION_CAP * r_throat,
    )
end

function trace_stokes_particle_path(solution, params::Params, seed::TrajectorySeed, z_values::Vector{Float64})
    rows = TrajectorySample[]
    x = seed.x
    y = seed.y
    t = 0.0
    push!(rows, trajectory_sample(solution, params, x, y, z_values[1], t))

    for i in 1:(length(z_values) - 1)
        z = z_values[i]
        dz = z_values[i + 1] - z
        x, y, t = rk4_pathline_step(solution, params, x, y, t, z, dz)
        push!(rows, trajectory_sample(solution, params, x, y, z_values[i + 1], t))
    end

    return rows
end

function rk4_pathline_step(
    solution,
    params::Params,
    x::Float64,
    y::Float64,
    t::Float64,
    z::Float64,
    dz::Float64,
)
    k1 = pathline_rhs(solution, params, x, y, z)
    k2 = pathline_rhs(solution, params, x + 0.5 * dz * k1[1], y + 0.5 * dz * k1[2], z + 0.5 * dz)
    k3 = pathline_rhs(solution, params, x + 0.5 * dz * k2[1], y + 0.5 * dz * k2[2], z + 0.5 * dz)
    k4 = pathline_rhs(solution, params, x + dz * k3[1], y + dz * k3[2], z + dz)
    x_next = x + dz / 6.0 * (k1[1] + 2.0 * k2[1] + 2.0 * k3[1] + k4[1])
    y_next = y + dz / 6.0 * (k1[2] + 2.0 * k2[2] + 2.0 * k3[2] + k4[2])
    t_next = t + dz / 6.0 * (k1[3] + 2.0 * k2[3] + 2.0 * k3[3] + k4[3])
    assert_inside_geometry(params, x_next, y_next, z + dz)
    return x_next, y_next, t_next
end

function pathline_rhs(solution, params::Params, x::Float64, y::Float64, z::Float64)
    assert_inside_geometry(params, x, y, z)
    u = solution.velocity(Point(x, y, z))
    ux = Float64(u[1])
    uy = Float64(u[2])
    uz = Float64(u[3])
    abs(uz) > 1.0e-10 || throw(ArgumentError("cannot trace pathline where axial velocity is too small at z=$z"))
    return ux / uz, uy / uz, 1.0 / uz
end

function trajectory_sample(solution, params::Params, x::Float64, y::Float64, z::Float64, t::Float64)
    assert_inside_geometry(params, x, y, z)
    u = solution.velocity(Point(x, y, z))
    return TrajectorySample(z, x, y, t, Float64(u[1]), Float64(u[2]), Float64(u[3]))
end

function assert_inside_geometry(params::Params, x::Float64, y::Float64, z::Float64)
    r0, _, _ = CanicExtended1D.stenosis(clamp(z, 0.0, params.length_cm), params)
    radius = hypot(x, y)
    if radius > r0 * (1.0 + 1.0e-7)
        throw(ArgumentError("trajectory left the stenotic geometry at z=$z with r=$radius and R0=$r0"))
    end
    return nothing
end

function trajectory_csv_row(severity::Float64, particle_id::Int, seed_label::String, sample_index::Int, row::TrajectorySample)
    params = Params(severity=severity, initial_condition=GeometryRestIC())
    r0, _, _ = CanicExtended1D.stenosis(row.z, params)
    radius = hypot(row.x, row.y)
    return csv_row((
        severity,
        particle_id,
        seed_label,
        sample_index,
        row.z,
        row.x,
        row.y,
        radius,
        radius / r0,
        row.t,
        row.ux,
        row.uy,
        row.uz,
    ))
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
