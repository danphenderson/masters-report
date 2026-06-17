function ensure_parent(path::String)
    dir = dirname(path)
    if !isempty(dir) && !isdir(dir)
        mkpath(dir)
    end
end

function write_csv(path::String, result::SimulationResult, p::Params)
    write_csv(path, result.z, result.area, result.flow, p)
end

function write_csv(path::String, z::Vector{Float64}, A::Vector{Float64}, Q::Vector{Float64}, p::Params)
    ensure_parent(path)
    P = pressure(A, Q, z, p)

    open(path, "w") do io
        println(io, "z_cm,R0_cm,A_cm2,Q_cm3_s,uavg_cm_s,pressure_dyn_cm2,alpha_c,shear_rate_1_s,nu_eff_cm2_s,rheology")
        for i in eachindex(z)
            r0, r0z, _ = stenosis(z[i], p)
            shear_rate = characteristic_shear_rate(A[i], Q[i], r0, p)
            nu_eff = effective_kinematic_viscosity(p.rheology, shear_rate, p.rho, p.nu)
            row = (
                z[i],
                r0,
                A[i],
                Q[i],
                Q[i] / positive_area(A[i]),
                P[i],
                alpha_c(r0z),
                shear_rate,
                nu_eff,
                rheology_name(p.rheology),
            )
            println(io, join(row, ","))
        end
    end
end

function write_svg(path::String, result::SimulationResult, p::Params)
    write_svg(path, result.z, result.area, result.flow, p)
end

function write_svg(path::String, z::Vector{Float64}, A::Vector{Float64}, Q::Vector{Float64}, p::Params)
    ensure_parent(path)

    u = Q ./ A
    P = pressure(A, Q, z, p)
    r0 = [stenosis(zi, p)[1] for zi in z]

    width = 900
    height = 620
    margin = 55
    panels = (
        ("Average velocity (cm/s)", u, 70, 230),
        ("Pressure (dyn/cm^2)", P, 270, 430),
        ("Reference radius R0 (cm)", r0, 470, 590),
    )

    open(path, "w") do io
        println(io, """<svg xmlns="http://www.w3.org/2000/svg" width="$width" height="$height" viewBox="0 0 $width $height">""")
        println(io, """<rect width="100%" height="100%" fill="white"/>""")
        println(io, """<text x="55" y="30" font-family="Arial" font-size="18" fill="#111">Canic extended 1D stenotic artery simulation, severity $(p.severity)%</text>""")

        for (title, values, ytop, ybot) in panels
            ymin = minimum(values)
            ymax = maximum(values)
            pad = 0.08 * max(ymax - ymin, 1.0e-9)
            ymin -= pad
            ymax += pad

            println(io, """<line x1="$margin" y1="$ybot" x2="$(width - margin)" y2="$ybot" stroke="#333" stroke-width="1"/>""")
            println(io, """<line x1="$margin" y1="$ytop" x2="$margin" y2="$ybot" stroke="#333" stroke-width="1"/>""")
            println(io, """<text x="$margin" y="$(ytop - 12)" font-family="Arial" font-size="14" fill="#111">$title</text>""")
            println(io, """<text x="$(width - margin - 40)" y="$(ybot + 28)" font-family="Arial" font-size="12" fill="#333">z (cm)</text>""")
            println(io, """<text x="$(margin + 4)" y="$(ytop + 14)" font-family="Arial" font-size="11" fill="#555">$(round(ymax, sigdigits=4))</text>""")
            println(io, """<text x="$(margin + 4)" y="$(ybot - 4)" font-family="Arial" font-size="11" fill="#555">$(round(ymin, sigdigits=4))</text>""")

            points = String[]
            for (x, y) in zip(z, values)
                sx = margin + (x / p.length_cm) * (width - 2margin)
                sy = ybot - (y - ymin) / max(ymax - ymin, eps()) * (ybot - ytop)
                push!(points, string(round(sx, digits=2), ",", round(sy, digits=2)))
            end

            println(io, """<polyline points="$(join(points, " "))" fill="none" stroke="#a51f2d" stroke-width="2"/>""")
        end

        println(io, "</svg>")
    end
end

function summary_lines(result::SimulationResult, p::Params, out::OutputSpec)
    u = velocity(result)
    P = pressure(result, p)
    nu_eff = [
        effective_kinematic_viscosity(result.area[i], result.flow[i], stenosis(result.z[i], p)[1], p)
        for i in eachindex(result.z)
    ]
    shear_rates = [
        characteristic_shear_rate(result.area[i], result.flow[i], stenosis(result.z[i], p)[1], p)
        for i in eachindex(result.z)
    ]
    lines = [
        "completed_time_s,$(result.completed_time)",
        "steps,$(result.steps)",
        "output_csv,$(out.csv)",
        "spatial_method,$(spatial_method_name(p.space))",
        "time_stepper,$(time_stepper_name(p.time_stepper))",
        "rheology,$(rheology_name(p.rheology))",
        "velocity_profile,$(profile_name(p.velocity_profile))",
        "inlet_boundary,$(inlet_boundary_name(p.inlet_boundary))",
        "outlet_boundary,$(outlet_boundary_name(p.outlet_boundary))",
        "alpha,$(p.alpha)",
        "profile_exponent,$(profile_exponent(p.velocity_profile))",
        "shear_rate_factor,$(shear_rate_factor(p.velocity_profile))",
        "initial_condition,$(initial_condition_name(p.initial_condition))",
    ]
    append_initial_condition_summary!(lines, result.initial_condition)
    out.write_svg && push!(lines, "output_svg,$(out.svg)")
    append!(
        lines,
        [
            "velocity_min_cm_s,$(minimum(u))",
            "velocity_max_cm_s,$(maximum(u))",
            "pressure_min_dyn_cm2,$(minimum(P))",
            "pressure_max_dyn_cm2,$(maximum(P))",
            "shear_rate_min_1_s,$(minimum(shear_rates))",
            "shear_rate_max_1_s,$(maximum(shear_rates))",
            "nu_eff_min_cm2_s,$(minimum(nu_eff))",
            "nu_eff_max_cm2_s,$(maximum(nu_eff))",
        ],
    )
    return lines
end

function append_initial_condition_summary!(lines::Vector{String}, summary::Nothing)
    return lines
end

function append_initial_condition_summary!(lines::Vector{String}, summary::InitialConditionSummary)
    append!(
        lines,
        [
            "ic_kind,$(summary.kind)",
            "ic_pressure_drop_dyn_cm2,$(summary.pressure_drop_dyn_cm2)",
            "ic_mesh_nz,$(summary.mesh_nz)",
            "ic_mesh_nr,$(summary.mesh_nr)",
            "ic_mesh_ntheta,$(summary.mesh_ntheta)",
            "ic_mesh_nodes,$(summary.mesh_nodes)",
            "ic_mesh_cells,$(summary.mesh_cells)",
            "ic_velocity_dofs,$(summary.velocity_dofs)",
            "ic_pressure_dofs,$(summary.pressure_dofs)",
            "ic_residual_norm,$(summary.residual_norm)",
            "ic_projection_hash,$(summary.projection_hash)",
            "ic_projected_velocity_min_cm_s,$(summary.projected_velocity_min)",
            "ic_projected_velocity_max_cm_s,$(summary.projected_velocity_max)",
            "ic_projected_pressure_min_dyn_cm2,$(summary.projected_pressure_min)",
            "ic_projected_pressure_max_dyn_cm2,$(summary.projected_pressure_max)",
        ],
    )
    isempty(summary.diagnostics_path) || push!(lines, "ic_diagnostics,$(summary.diagnostics_path)")
    return lines
end
