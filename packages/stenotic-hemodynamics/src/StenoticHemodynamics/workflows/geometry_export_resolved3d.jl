function export_resolved_velocity_nodes(opts::GeometryExportOptions)
    paths = String[]
    manifest = joinpath(opts.output_dir, "resolved_velocity_nodes_manifest.csv")
    cases = available_resolved3d_cases(opts.data_root)

    guarded_open(manifest, opts.overwrite) do io
        println(io, "status,data_root,case_label,severity,source_xdmf,output_csv,node_count,xdmf_time_s,target_time_s,time_error_s,min_uz_cm_s,max_uz_cm_s,max_speed_cm_s,note")
        if isempty(cases)
            println(io, csv_row(("skipped", portable_project_path(opts.data_root), "", "", "", "", 0, "", "", "", "", "", "", "no local XDMF files found")))
            return
        end

        for case in cases
            field = load_resolved3d_velocity(case)
            output_csv = resolved_velocity_nodes_path(opts.output_dir, case)
            write_resolved_velocity_nodes_csv(output_csv, field; overwrite=opts.overwrite)
            push!(paths, output_csv)
            min_uz, max_uz, max_speed = resolved_velocity_bounds(field)
            println(io, csv_row((
                "written",
                portable_project_path(opts.data_root),
                case.case_label,
                case.severity,
                portable_project_path(case.velocity_xdmf),
                portable_project_path(output_csv),
                size(field.coordinates, 1),
                field.metadata.time,
                case.target_time,
                abs(field.metadata.time - case.target_time),
                min_uz,
                max_uz,
                max_speed,
                "full node-centered resolved 3D velocity field",
            )))
        end
    end

    return [manifest; paths]
end

function resolved_velocity_nodes_path(output_dir::String, case::Resolved3DCaseSpec)
    return joinpath(
        output_dir,
        "resolved_velocity_nodes_case$(case.case_label)_sev$(round(Int, case.severity)).csv",
    )
end

function resolved_velocity_bounds(field::Resolved3DVelocityField)
    velocity = field.velocity
    min_uz = Inf
    max_uz = -Inf
    max_speed = 0.0
    for i in axes(velocity, 1)
        ux = velocity[i, 1]
        uy = velocity[i, 2]
        uz = velocity[i, 3]
        min_uz = min(min_uz, uz)
        max_uz = max(max_uz, uz)
        max_speed = max(max_speed, sqrt(ux^2 + uy^2 + uz^2))
    end
    return min_uz, max_uz, max_speed
end

function write_resolved_velocity_nodes_csv(
    path::String,
    field::Resolved3DVelocityField;
    overwrite::Bool = false,
)
    coords = field.coordinates
    velocity = field.velocity
    guarded_open(path, overwrite) do io
        println(io, "case_label,severity,node_id,z_cm,x_cm,y_cm,r_cm,theta_rad,ux_cm_s,uy_cm_s,uz_cm_s,speed_cm_s,xdmf_time_s,source")
        for i in axes(coords, 1)
            x = coords[i, 1]
            y = coords[i, 2]
            z = coords[i, 3]
            ux = velocity[i, 1]
            uy = velocity[i, 2]
            uz = velocity[i, 3]
            radius = hypot(x, y)
            theta = atan(y, x)
            theta < 0.0 && (theta += 2.0 * pi)
            println(io, csv_row((
                field.case_spec.case_label,
                field.case_spec.severity,
                i,
                z,
                x,
                y,
                radius,
                theta,
                ux,
                uy,
                uz,
                sqrt(ux^2 + uy^2 + uz^2),
                field.metadata.time,
                "node-centered-resolved-3d-velocity",
            )))
        end
    end
end

function export_resolved_envelopes(opts::GeometryExportOptions)
    paths = String[]
    manifest = joinpath(opts.output_dir, "resolved_envelope_manifest.csv")
    cases = available_resolved3d_cases(opts.data_root)

    guarded_open(manifest, opts.overwrite) do io
        println(io, "status,data_root,case_label,severity,source_xdmf,output_csv,node_count,z_bins,theta_bins,note")
        if isempty(cases)
            println(io, csv_row(("skipped", portable_project_path(opts.data_root), "", "", "", "", 0, opts.z_samples, opts.theta_samples, "no local XDMF files found")))
            return
        end

        for case in cases
            field = load_resolved3d_velocity(case)
            output_csv = resolved_envelope_path(opts.output_dir, case)
            write_resolved_envelope_csv(output_csv, field, opts; overwrite=opts.overwrite)
            push!(paths, output_csv)
            println(io, csv_row((
                "written",
                portable_project_path(opts.data_root),
                case.case_label,
                case.severity,
                portable_project_path(case.velocity_xdmf),
                portable_project_path(output_csv),
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
    opts::GeometryExportOptions;
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
