using Gridap
using Gridap.Arrays
using Gridap.Geometry
using Gridap.ReferenceFEs
using Gridap.TensorValues
using SHA

import Gridap: ∇
import Gridap.Geometry: face_labeling_from_vertex_filter, get_grid_topology

struct GeneratedStokesMesh
    coordinates::Vector{NTuple{3,Float64}}
    cells::Vector{NTuple{4,Int}}
    nz::Int
    nr::Int
    ntheta::Int
    inlet_nodes::Int
    outlet_nodes::Int
    wall_nodes::Int
end

struct StationaryStokesSolution
    mesh::GeneratedStokesMesh
    velocity
    pressure
    velocity_dofs::Int
    pressure_dofs::Int
    raw_pressure_drop::Float64
end

function initial_state_result(p::Params)
    dx = p.length_cm / p.nx
    z = [(i - 0.5) * dx for i in 1:p.nx]
    A, Q, summary = initial_condition_values(p, z)
    return InitialStateResult(z, A, Q, dx, summary)
end

function initial_condition_values(p::Params, z::Vector{Float64})
    return initial_condition_values(p.initial_condition, p, z)
end

function initial_condition_values(::GeometryRestIC, p::Params, z::Vector{Float64})
    A = [stenosis(zi, p)[1]^2 for zi in z]
    Q = zeros(Float64, length(z))
    return A, Q, InitialConditionSummary("geometry-rest")
end

function initial_condition_values(ic::StationaryStokesIC, p::Params, z::Vector{Float64})
    validate(ic)
    solution = solve_stationary_stokes(p, ic)
    A, Q, uavg, pavg = project_stationary_stokes(solution, p, ic, z)
    summary = InitialConditionSummary(
        "stationary-stokes",
        ic.pressure_drop_dyn_cm2,
        ic.mesh_nz,
        ic.mesh_nr,
        ic.mesh_ntheta,
        length(solution.mesh.coordinates),
        length(solution.mesh.cells),
        solution.velocity_dofs,
        solution.pressure_dofs,
        abs(solution.raw_pressure_drop - ic.pressure_drop_dyn_cm2) / ic.pressure_drop_dyn_cm2,
        projection_hash(z, A, Q, pavg, ic),
        ic.diagnostics_path,
        minimum(uavg),
        maximum(uavg),
        minimum(pavg),
        maximum(pavg),
    )
    maybe_write_ic_diagnostics(ic, solution, z, A, Q, uavg, pavg)
    return A, Q, summary
end

function generated_stokes_mesh(p::Params, ic::StationaryStokesIC)
    validate(ic)
    nz = ic.mesh_nz
    nr = ic.mesh_nr
    ntheta = ic.mesh_ntheta
    nlocal = 1 + nr * ntheta

    local_id(k::Int, a::Int) = k == 0 ? 1 : 1 + (k - 1) * ntheta + a
    global_id(j::Int, l::Int) = j * nlocal + l

    coordinates = NTuple{3,Float64}[]
    for j in 0:nz
        z = p.length_cm * j / nz
        r0, _, _ = stenosis(z, p)
        push!(coordinates, (0.0, 0.0, z))
        for k in 1:nr
            r = r0 * k / nr
            for a in 1:ntheta
                theta = 2.0 * pi * (a - 1) / ntheta
                push!(coordinates, (r * cos(theta), r * sin(theta), z))
            end
        end
    end

    triangles = NTuple{3,Int}[]
    for a in 1:ntheta
        b = a == ntheta ? 1 : a + 1
        push!(triangles, sorted_tuple3(local_id(0, 1), local_id(1, a), local_id(1, b)))
        for k in 1:(nr - 1)
            push!(triangles, sorted_tuple3(local_id(k, a), local_id(k + 1, a), local_id(k + 1, b)))
            push!(triangles, sorted_tuple3(local_id(k, a), local_id(k + 1, b), local_id(k, b)))
        end
    end

    cells = NTuple{4,Int}[]
    for j in 0:(nz - 1)
        for (l1, l2, l3) in triangles
            b1 = global_id(j, l1)
            b2 = global_id(j, l2)
            b3 = global_id(j, l3)
            t1 = global_id(j + 1, l1)
            t2 = global_id(j + 1, l2)
            t3 = global_id(j + 1, l3)
            append_oriented_tet!(cells, coordinates, (b1, b2, b3, t3))
            append_oriented_tet!(cells, coordinates, (b1, b2, t3, t2))
            append_oriented_tet!(cells, coordinates, (b1, t2, t3, t1))
        end
    end

    inlet_nodes = nlocal
    outlet_nodes = nlocal
    wall_nodes = (nz + 1) * ntheta
    return GeneratedStokesMesh(coordinates, cells, nz, nr, ntheta, inlet_nodes, outlet_nodes, wall_nodes)
end

function sorted_tuple3(a::Int, b::Int, c::Int)
    values = sort!([a, b, c])
    return (values[1], values[2], values[3])
end

function append_oriented_tet!(
    cells::Vector{NTuple{4,Int}},
    coordinates::Vector{NTuple{3,Float64}},
    tet::NTuple{4,Int},
)
    volume6 = signed_tet_volume6(coordinates[tet[1]], coordinates[tet[2]], coordinates[tet[3]], coordinates[tet[4]])
    abs(volume6) > 1.0e-16 || throw(ArgumentError("generated Stokes mesh contains a degenerate tetrahedron"))
    if volume6 < 0.0
        push!(cells, (tet[1], tet[2], tet[4], tet[3]))
    else
        push!(cells, tet)
    end
    return cells
end

function signed_tet_volume6(a, b, c, d)
    ax = b[1] - a[1]
    ay = b[2] - a[2]
    az = b[3] - a[3]
    bx = c[1] - a[1]
    by = c[2] - a[2]
    bz = c[3] - a[3]
    cx = d[1] - a[1]
    cy = d[2] - a[2]
    cz = d[3] - a[3]
    return ax * (by * cz - bz * cy) - ay * (bx * cz - bz * cx) + az * (bx * cy - by * cx)
end

function gridap_model(mesh::GeneratedStokesMesh, p::Params)
    points = [Point(x, y, z) for (x, y, z) in mesh.coordinates]
    cell_node_ids = Table([Int32[cell...] for cell in mesh.cells])
    reffes = [LagrangianRefFE(Float64, TET, 1)]
    cell_types = fill(Int8(1), length(mesh.cells))
    grid = UnstructuredGrid(points, cell_node_ids, reffes, cell_types, Oriented())
    model = UnstructuredDiscreteModel(grid)
    labels = get_face_labeling(model)
    topo = get_grid_topology(model)
    ztol = max(p.length_cm, 1.0) * 1.0e-10
    rtol = max(p.rmax, 1.0) * 1.0e-8
    merge!(labels, face_labeling_from_vertex_filter(topo, "inlet", x -> abs(x[3]) <= ztol))
    merge!(labels, face_labeling_from_vertex_filter(topo, "outlet", x -> abs(x[3] - p.length_cm) <= ztol))
    merge!(
        labels,
        face_labeling_from_vertex_filter(topo, "wall", x -> begin
            r0, _, _ = stenosis(x[3], p)
            abs(hypot(x[1], x[2]) - r0) <= rtol
        end),
    )
    return model, labels
end

function solve_stationary_stokes(p::Params, ic::StationaryStokesIC)
    mesh = generated_stokes_mesh(p, ic)
    model, labels = gridap_model(mesh, p)
    order = 2
    mu = p.rho * p.nu
    mu > 0.0 || throw(ArgumentError("stationary-stokes IC requires positive Newtonian dynamic viscosity rho*nu"))

    reffe_u = ReferenceFE(lagrangian, VectorValue{3,Float64}, order)
    reffe_p = ReferenceFE(lagrangian, Float64, order - 1)
    zero_velocity(x) = VectorValue(0.0, 0.0, 0.0)
    V = TestFESpace(model, reffe_u, labels=labels, dirichlet_tags="wall", conformity=:H1)
    Q = TestFESpace(model, reffe_p, labels=labels, conformity=:H1)
    U = TrialFESpace(V, zero_velocity)
    P = TrialFESpace(Q)
    X = MultiFieldFESpace([U, P])
    Y = MultiFieldFESpace([V, Q])

    Ω = Triangulation(model)
    Γin = BoundaryTriangulation(model, labels, tags="inlet")
    Γout = BoundaryTriangulation(model, labels, tags="outlet")
    n_in = get_normal_vector(Γin)
    n_out = get_normal_vector(Γout)
    degree = 2 * order
    dΩ = Measure(Ω, degree)
    dΓin = Measure(Γin, degree)
    dΓout = Measure(Γout, degree)
    pressure_drop = ic.pressure_drop_dyn_cm2

    a((u, pfield), (v, q)) = ∫(mu * (∇(v) ⊙ ∇(u)) - (∇ ⋅ v) * pfield + q * (∇ ⋅ u)) * dΩ
    l((v, q)) = ∫(-pressure_drop * (v ⋅ n_in)) * dΓin + ∫(-0.0 * (v ⋅ n_out)) * dΓout

    velocity_h, pressure_h = solve(AffineFEOperator(a, l, X, Y))
    return StationaryStokesSolution(
        mesh,
        velocity_h,
        pressure_h,
        length(get_free_dof_values(velocity_h)),
        length(get_free_dof_values(pressure_h)),
        ic.pressure_drop_dyn_cm2,
    )
end

function project_stationary_stokes(
    solution::StationaryStokesSolution,
    p::Params,
    ic::StationaryStokesIC,
    z::Vector{Float64},
)
    _ = solution
    resistance = stokes_resistance_integral(p, ic)
    flow_over_pi = ic.pressure_drop_dyn_cm2 / (8.0 * p.rho * p.nu * resistance)

    A = Vector{Float64}(undef, length(z))
    Q = Vector{Float64}(undef, length(z))
    uavg = Vector{Float64}(undef, length(z))
    pavg = Vector{Float64}(undef, length(z))
    for (i, zi) in pairs(z)
        r0, _, _ = stenosis(zi, p)
        ui = flow_over_pi / r0^2
        pi = stokes_pressure_at(zi, p, ic, resistance)
        Ai = area_for_pressure_and_velocity(pi, ui, zi, p)
        A[i] = Ai
        Q[i] = Ai * ui
        uavg[i] = ui
        pavg[i] = pi
    end
    return A, Q, uavg, pavg
end

function stokes_resistance_integral(p::Params, ic::StationaryStokesIC)
    samples = max(10 * ic.mesh_nz, 200)
    dz = p.length_cm / samples
    accum = 0.0
    for j in 0:samples
        z = j * dz
        r0, _, _ = stenosis(z, p)
        weight = (j == 0 || j == samples) ? 0.5 : 1.0
        accum += weight / r0^4
    end
    return accum * dz
end

function stokes_pressure_at(z::Float64, p::Params, ic::StationaryStokesIC, total_resistance::Float64)
    samples = max(10 * ic.mesh_nz, 200)
    z0 = clamp(z, 0.0, p.length_cm)
    dz = (p.length_cm - z0) / samples
    accum = 0.0
    for j in 0:samples
        zi = z0 + j * dz
        r0, _, _ = stenosis(zi, p)
        weight = (j == 0 || j == samples) ? 0.5 : 1.0
        accum += weight / r0^4
    end
    return ic.pressure_drop_dyn_cm2 * (accum * dz) / total_resistance
end

function section_average_velocity(velocity_h, z::Float64, p::Params, ic::StationaryStokesIC)
    r0, _, _ = stenosis(clamp(z, 0.0, p.length_cm), p)
    acc = 0.0
    count = 0
    polygon_scale = cos(pi / ic.mesh_ntheta) * (1.0 - 1.0e-8)
    for ir in 1:ic.projection_nr
        radius = r0 * polygon_scale * sqrt((ir - 0.5) / ic.projection_nr)
        for itheta in 1:ic.projection_ntheta
            theta = 2.0 * pi * (itheta - 0.5) / ic.projection_ntheta
            u = velocity_h(Point(radius * cos(theta), radius * sin(theta), z))
            acc += u[3]
            count += 1
        end
    end
    return acc / count
end

function section_average_pressure(pressure_h, z::Float64, p::Params, ic::StationaryStokesIC)
    r0, _, _ = stenosis(clamp(z, 0.0, p.length_cm), p)
    acc = 0.0
    count = 0
    polygon_scale = cos(pi / ic.mesh_ntheta) * (1.0 - 1.0e-8)
    for ir in 1:ic.projection_nr
        radius = r0 * polygon_scale * sqrt((ir - 0.5) / ic.projection_nr)
        for itheta in 1:ic.projection_ntheta
            theta = 2.0 * pi * (itheta - 0.5) / ic.projection_ntheta
            acc += pressure_h(Point(radius * cos(theta), radius * sin(theta), z))
            count += 1
        end
    end
    return acc / count
end

function area_for_pressure_and_velocity(target_pressure::Float64, uavg::Float64, z::Float64, p::Params)
    r0, _, _ = stenosis(z, p)
    guess = max(r0^2, AREA_LIMITER_FLOOR)
    residual(A) = pressure([A], [A * uavg], [z], p)[1] - target_pressure
    lo = AREA_LIMITER_FLOOR
    hi = max(guess * 4.0, lo * 2.0)
    flo = residual(lo)
    fhi = residual(hi)
    for _ in 1:80
        flo * fhi <= 0.0 && break
        hi *= 2.0
        fhi = residual(hi)
    end
    if flo * fhi > 0.0
        throw(ArgumentError("could not invert 1D pressure law for stationary-stokes IC at z=$z"))
    end
    for _ in 1:80
        mid = 0.5 * (lo + hi)
        fm = residual(mid)
        if abs(fm) <= 1.0e-9 || abs(hi - lo) <= 1.0e-12
            return max(mid, AREA_LIMITER_FLOOR)
        elseif flo * fm <= 0.0
            hi = mid
            fhi = fm
        else
            lo = mid
            flo = fm
        end
    end
    return max(0.5 * (lo + hi), AREA_LIMITER_FLOOR)
end

function projection_hash(z, A, Q, pavg, ic::StationaryStokesIC)
    parts = String[]
    for value in Iterators.flatten((z, A, Q, pavg))
        push!(parts, string(round(Float64(value), sigdigits=16)))
    end
    push!(parts, string(ic.pressure_drop_dyn_cm2, ":", ic.mesh_nz, ":", ic.mesh_nr, ":", ic.mesh_ntheta))
    return bytes2hex(sha256(join(parts, ",")))[1:16]
end

function maybe_write_ic_diagnostics(
    ic::StationaryStokesIC,
    solution::StationaryStokesSolution,
    z::Vector{Float64},
    A::Vector{Float64},
    Q::Vector{Float64},
    uavg::Vector{Float64},
    pavg::Vector{Float64},
)
    isempty(ic.diagnostics_path) && return nothing
    ensure_parent(ic.diagnostics_path)
    open(ic.diagnostics_path, "w") do io
        println(io, "z_cm,A_cm2,Q_cm3_s,uavg_cm_s,pressure_dyn_cm2")
        for i in eachindex(z)
            println(io, join((z[i], A[i], Q[i], uavg[i], pavg[i]), ","))
        end
        println(io, "# mesh_nodes,$(length(solution.mesh.coordinates))")
        println(io, "# mesh_cells,$(length(solution.mesh.cells))")
        println(io, "# velocity_dofs,$(solution.velocity_dofs)")
        println(io, "# pressure_dofs,$(solution.pressure_dofs)")
        println(io, "# raw_pressure_drop_dyn_cm2,$(solution.raw_pressure_drop)")
    end
    return ic.diagnostics_path
end
