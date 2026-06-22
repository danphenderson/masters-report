"""
    export_stokes_particle_trajectories(opts; ...)

Write fixed-wall stationary-Stokes particle-pathline CSV assets for the smooth
stenosis geometry. These trajectories come from the stationary Gridap solution
used for figure/report assets and are distinct from transient 1D, resolved-3D,
or FSI runtime outputs.
"""
function export_stokes_particle_trajectories(
    opts::GeometryExportOptions;
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
    parallel_workers::Int = default_case_workers(),
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
    worker_count = effective_case_workers(length(cases), parallel_workers)
    worker_count <= 1 && return map(stokes_particle_trajectory_case, cases)

    worker_ids = case_worker_ids!(worker_count)
    initialize_stenosis_export_workers!(worker_ids)
    return pmap(stokes_particle_trajectory_case, CachingPool(worker_ids), cases)
end

function stokes_particle_trajectory_case(case)
    severity = Float64(case.severity)
    params = Params(severity=severity, initial_condition=case.ic)
    validate(params)
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
        portable_project_path(case.trajectory_path),
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
    r_start, _, _ = stenosis(z_start, params)
    throat_z = stenosis_throat_z(params)
    r_throat, _, _ = stenosis(throat_z, params)
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
    r0, _, _ = stenosis(clamp(z, 0.0, params.length_cm), params)
    radius = hypot(x, y)
    if radius > r0 * (1.0 + 1.0e-7)
        throw(ArgumentError("trajectory left the stenotic geometry at z=$z with r=$radius and R0=$r0"))
    end
    return nothing
end

function trajectory_csv_row(severity::Float64, particle_id::Int, seed_label::String, sample_index::Int, row::TrajectorySample)
    params = Params(severity=severity, initial_condition=GeometryRestIC())
    r0, _, _ = stenosis(row.z, params)
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
