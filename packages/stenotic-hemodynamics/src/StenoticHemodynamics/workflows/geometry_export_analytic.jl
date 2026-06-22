function export_analytic_summary(opts::GeometryExportOptions)
    path = joinpath(opts.output_dir, "analytic_summary.csv")
    guarded_open(path, opts.overwrite) do io
        println(io, "severity,throat_z_cm,rmin_cm,rbase_cm,rmin_over_rbase")
        for severity in ANALYTIC_SEVERITIES
            params = Params(severity=severity)
            throat_z = stenosis_throat_z(params)
            rmin, _, _ = stenosis(throat_z, params)
            println(io, csv_row((severity, throat_z, rmin, params.rmax, rmin / params.rmax)))
        end
    end
    return [path]
end

function export_analytic_profiles(opts::GeometryExportOptions)
    path = joinpath(opts.output_dir, "analytic_radius_profiles.csv")
    guarded_open(path, opts.overwrite) do io
        println(io, "severity,z_cm,r0_cm,rbase_cm,s_fraction")
        for severity in ANALYTIC_SEVERITIES
            params = Params(severity=severity)
            for z in range(0.0, params.length_cm; length=opts.z_samples)
                r0, _, _ = stenosis(Float64(z), params)
                s_fraction = 1.0 - r0 / params.rmax
                println(io, csv_row((severity, z, r0, params.rmax, s_fraction)))
            end
        end
    end
    return [path]
end

function export_analytic_surfaces(opts::GeometryExportOptions)
    paths = String[]
    for severity in ANALYTIC_SEVERITIES
        params = Params(severity=severity)
        path = joinpath(opts.output_dir, "analytic_surface_sev$(round(Int, severity)).csv")
        guarded_open(path, opts.overwrite) do io
            println(io, "severity,z_cm,theta_rad,x_cm,y_cm,r_cm")
            for z in range(0.0, params.length_cm; length=opts.z_samples)
                r0, _, _ = stenosis(Float64(z), params)
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

function export_analytic_cross_sections(opts::GeometryExportOptions)
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
            r0, _, _ = stenosis(Float64(z), params)
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
