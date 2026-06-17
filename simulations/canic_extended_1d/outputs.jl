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
        println(io, "z_cm,R0_cm,A_cm2,Q_cm3_s,uavg_cm_s,pressure_dyn_cm2,alpha_c")
        for i in eachindex(z)
            r0, r0z, _ = stenosis(z[i], p)
            row = (
                z[i],
                r0,
                A[i],
                Q[i],
                Q[i] / positive_area(A[i]),
                P[i],
                alpha_c(r0z),
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
    lines = [
        "completed_time_s,$(result.completed_time)",
        "steps,$(result.steps)",
        "output_csv,$(out.csv)",
    ]
    out.write_svg && push!(lines, "output_svg,$(out.svg)")
    append!(
        lines,
        [
            "velocity_min_cm_s,$(minimum(u))",
            "velocity_max_cm_s,$(maximum(u))",
            "pressure_min_dyn_cm2,$(minimum(P))",
            "pressure_max_dyn_cm2,$(maximum(P))",
        ],
    )
    return lines
end
