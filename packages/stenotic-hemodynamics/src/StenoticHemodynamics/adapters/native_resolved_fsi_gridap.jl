function native_resolved_fsi_gridap_model(
    mesh::NativeResolvedFSIMesh;
    coordinates::AbstractMatrix{<:Real} = mesh.coordinates,
    wall_radius_at_z = z -> native_resolved_fsi_radius(mesh.case_spec, z),
)
    size(coordinates, 1) == size(mesh.coordinates, 1) ||
        throw(DimensionMismatch("native resolved-FSI Gridap coordinates must match the mesh node count"))
    size(coordinates, 2) == 3 || throw(DimensionMismatch("native resolved-FSI Gridap coordinates must have 3 columns"))
    points = [Point(Float64(coordinates[row, 1]), Float64(coordinates[row, 2]), Float64(coordinates[row, 3])) for row in axes(coordinates, 1)]
    cell_node_ids = Table([Int32[mesh.topology[row, 1], mesh.topology[row, 2], mesh.topology[row, 3], mesh.topology[row, 4]] for row in axes(mesh.topology, 1)])
    reffes = [LagrangianRefFE(Float64, TET, 1)]
    cell_types = fill(Int8(1), size(mesh.topology, 1))
    grid = UnstructuredGrid(points, cell_node_ids, reffes, cell_types, Oriented())
    model = UnstructuredDiscreteModel(grid)
    labels = get_face_labeling(model)
    topo = get_grid_topology(model)

    length_cm = mesh.case_spec.length_cm
    ztol = max(length_cm, 1.0) * 1.0e-10
    rtol = max(mesh.case_spec.rmax_cm, 1.0) * 1.0e-8
    merge!(labels, face_labeling_from_vertex_filter(topo, "inlet", x -> abs(Float64(x[3])) <= ztol))
    merge!(labels, face_labeling_from_vertex_filter(topo, "outlet", x -> abs(Float64(x[3]) - length_cm) <= ztol))
    merge!(
        labels,
        face_labeling_from_vertex_filter(topo, "wall", x -> begin
            z = clamp(Float64(x[3]), 0.0, length_cm)
            radius = Float64(wall_radius_at_z(z))
            abs(hypot(Float64(x[1]), Float64(x[2])) - radius) <= rtol
        end),
    )
    return model, labels
end

function native_resolved_fsi_radial_wall_velocity_function(mesh::NativeResolvedFSIMesh, wall_velocity_at)
    length_cm = mesh.case_spec.length_cm
    radial_eps = max(mesh.case_spec.rmax_cm, 1.0) * 1.0e-12
    return function prescribed_radial_wall_velocity(x)
        x1 = Float64(x[1])
        x2 = Float64(x[2])
        z = clamp(Float64(x[3]), 0.0, length_cm)
        radial_distance = hypot(x1, x2)
        radial_distance > radial_eps || return VectorValue(0.0, 0.0, 0.0)
        radial_speed = Float64(wall_velocity_at(z))
        isfinite(radial_speed) || throw(ArgumentError(
            "native resolved-FSI Navier-Stokes wall velocity profile must return finite values",
        ))
        return VectorValue(
            radial_speed * x1 / radial_distance,
            radial_speed * x2 / radial_distance,
            0.0,
        )
    end
end

function native_resolved_fsi_inlet_outlet_boundary_mode(value::Union{Symbol,AbstractString})
    mode = Symbol(value)
    mode in NATIVE_RESOLVED_FSI_INLET_OUTLET_BOUNDARY_MODES ||
        throw(ArgumentError(
            "unsupported native resolved-FSI inlet/outlet boundary mode $(repr(mode)); " *
            "supported modes are $(NATIVE_RESOLVED_FSI_INLET_OUTLET_BOUNDARY_MODES)",
        ))
    return mode
end

"""
    native_resolved_fsi_pressure_space_policy(mode)

Internal Gridap pressure-space policy for the native resolved-FSI smoke
operators. The pressure unknown remains a dynamic pressure in dyn/cm^2; outlet
pressure normalization after sampling is an export gauge and is separate from
the FE pressure space.
"""
function native_resolved_fsi_pressure_space_policy(mode::Union{Symbol,AbstractString})
    mode_value = native_resolved_fsi_inlet_outlet_boundary_mode(mode)
    if mode_value === :pressure_drop_weak_inlet_outlet_gauge_smoke
        return (
            gridap_constraint=:zeromean,
            pressure_reference=:additive_nullspace,
            status="Gridap zero-mean pressure constraint active because the weak pressure-drop loading leaves pressure up to an additive constant; post-sampling outlet pressure normalization is an export gauge",
        )
    end
    if mode_value === :poiseuille_inlet_zero_outlet_stress_section41
        return (
            gridap_constraint=nothing,
            pressure_reference=:natural_cauchy_traction_absolute_pressure,
            status="no Gridap zero-mean pressure constraint: the Poiseuille-inlet / natural Cauchy-traction outlet contract fixes or interprets absolute pressure; post-sampling outlet pressure normalization is an export gauge only",
        )
    end
    throw(ArgumentError("unsupported native resolved-FSI inlet/outlet boundary mode $(repr(mode_value))"))
end

function native_resolved_fsi_pressure_test_space(model, reffe_p, labels, mode::Union{Symbol,AbstractString})
    pressure_policy = native_resolved_fsi_pressure_space_policy(mode)
    if pressure_policy.gridap_constraint === :zeromean
        return TestFESpace(model, reffe_p, labels=labels, conformity=:H1, constraint=:zeromean)
    end
    return TestFESpace(model, reffe_p, labels=labels, conformity=:H1)
end

"""
    native_resolved_fsi_navier_stokes_weak_form_coefficients(rho, mu, dt_s)

Coefficients for the force-density Navier-Stokes weak form. Pressure is not
divided by density, so the transient and Picard convection terms carry `rho`
and the Newtonian Cauchy stress uses dynamic viscosity `mu`.
"""
function native_resolved_fsi_navier_stokes_weak_form_coefficients(rho::Real, mu::Real, dt_s::Real)
    rho_value = Float64(rho)
    mu_value = Float64(mu)
    dt_value = Float64(dt_s)
    isfinite(rho_value) && rho_value > 0.0 ||
        throw(ArgumentError("native resolved-FSI Navier-Stokes weak form requires positive finite density"))
    isfinite(mu_value) && mu_value > 0.0 ||
        throw(ArgumentError("native resolved-FSI Navier-Stokes weak form requires positive finite dynamic viscosity"))
    isfinite(dt_value) && dt_value > 0.0 ||
        throw(ArgumentError("native resolved-FSI Navier-Stokes weak form requires positive finite dt_s"))
    return (
        transient_mass=rho_value / dt_value,
        previous_step_mass=rho_value / dt_value,
        convection_density=rho_value,
        cauchy_viscous_stress=2.0 * mu_value,
        dynamic_pressure=1.0,
        boundary_traction=1.0,
    )
end

struct NativeResolvedFSINavierStokesWeakFormParts
    mass_matrix_term
    viscous_matrix_term
    convection_matrix_term
    pressure_gradient_matrix_term
    divergence_matrix_term
    stable_matrix_term
    component_sum_matrix_term
    zero_matrix_term
    previous_state_rhs_term
    inlet_boundary_rhs_term
    outlet_boundary_rhs_term
    boundary_rhs_term
    component_sum_rhs_term
    zero_rhs_term
    a
    l
    component_terms::String
end

function native_resolved_fsi_navier_stokes_weak_form_parts(
    Ω,
    Γin,
    Γout,
    n_in,
    n_out,
    weak_form_coefficients;
    velocity_advector,
    velocity_previous_step,
    pressure_drop_value::Real,
    inlet_outlet_boundary_mode::Symbol,
    quadrature_degree::Integer,
)
    dΩ = Measure(Ω, Int(quadrature_degree))
    dΓin = Measure(Γin, Int(quadrature_degree))
    dΓout = Measure(Γout, Int(quadrature_degree))
    pressure_drop_value = Float64(pressure_drop_value)

    mass_matrix_term((u, _pfield), (v, _q)) =
        ∫(weak_form_coefficients.transient_mass * (v ⋅ u)) * dΩ
    viscous_matrix_term((u, _pfield), (v, _q)) =
        ∫(weak_form_coefficients.cauchy_viscous_stress * (ε(v) ⊙ ε(u))) * dΩ
    convection_matrix_term((u, _pfield), (v, _q)) =
        ∫(weak_form_coefficients.convection_density * (v ⋅ ((∇(u)) ⋅ velocity_advector))) * dΩ
    pressure_gradient_matrix_term((_u, pfield), (v, _q)) =
        ∫(-weak_form_coefficients.dynamic_pressure * (∇ ⋅ v) * pfield) * dΩ
    divergence_matrix_term((u, _pfield), (_v, q)) =
        ∫(q * (∇ ⋅ u)) * dΩ
    stable_matrix_term((u, pfield), (v, q)) =
        mass_matrix_term((u, pfield), (v, q)) +
        viscous_matrix_term((u, pfield), (v, q)) +
        pressure_gradient_matrix_term((u, pfield), (v, q)) +
        divergence_matrix_term((u, pfield), (v, q))
    component_sum_matrix_term((u, pfield), (v, q)) =
        stable_matrix_term((u, pfield), (v, q)) +
        convection_matrix_term((u, pfield), (v, q))
    zero_matrix_term((u, pfield), (v, q)) =
        ∫(0.0 * (v ⋅ u) + 0.0 * q * pfield) * dΩ
    previous_state_rhs_term((v, _q)) =
        ∫(weak_form_coefficients.previous_step_mass * (v ⋅ velocity_previous_step)) * dΩ
    inlet_boundary_rhs_term((v, _q)) =
        ∫(-weak_form_coefficients.boundary_traction * pressure_drop_value * (v ⋅ n_in)) * dΓin
    outlet_boundary_rhs_term((v, _q)) =
        ∫(0.0 * (v ⋅ n_out)) * dΓout
    boundary_rhs_term((v, q)) =
        if inlet_outlet_boundary_mode === :pressure_drop_weak_inlet_outlet_gauge_smoke
            inlet_boundary_rhs_term((v, q)) + outlet_boundary_rhs_term((v, q))
        else
            outlet_boundary_rhs_term((v, q))
        end
    component_sum_rhs_term((v, q)) =
        previous_state_rhs_term((v, q)) + boundary_rhs_term((v, q))
    zero_rhs_term((_v, q)) =
        ∫(0.0 * q) * dΩ

    a((u, pfield), (v, q)) =
        ∫(
            weak_form_coefficients.transient_mass * (v ⋅ u) +
            weak_form_coefficients.cauchy_viscous_stress * (ε(v) ⊙ ε(u)) +
            weak_form_coefficients.convection_density * (v ⋅ ((∇(u)) ⋅ velocity_advector)) -
            weak_form_coefficients.dynamic_pressure * (∇ ⋅ v) * pfield +
            q * (∇ ⋅ u)
        ) * dΩ
    l((v, q)) =
        if inlet_outlet_boundary_mode === :pressure_drop_weak_inlet_outlet_gauge_smoke
            ∫(weak_form_coefficients.previous_step_mass * (v ⋅ velocity_previous_step)) * dΩ +
            ∫(-weak_form_coefficients.boundary_traction * pressure_drop_value * (v ⋅ n_in)) * dΓin +
            ∫(-0.0 * (v ⋅ n_out)) * dΓout
        else
            ∫(weak_form_coefficients.previous_step_mass * (v ⋅ velocity_previous_step)) * dΩ +
            ∫(0.0 * (v ⋅ n_out)) * dΓout
        end

    return NativeResolvedFSINavierStokesWeakFormParts(
        mass_matrix_term,
        viscous_matrix_term,
        convection_matrix_term,
        pressure_gradient_matrix_term,
        divergence_matrix_term,
        stable_matrix_term,
        component_sum_matrix_term,
        zero_matrix_term,
        previous_state_rhs_term,
        inlet_boundary_rhs_term,
        outlet_boundary_rhs_term,
        boundary_rhs_term,
        component_sum_rhs_term,
        zero_rhs_term,
        a,
        l,
        "mass|viscous|convection|pressure_gradient|divergence|previous_state_rhs|boundary_rhs",
    )
end

native_resolved_fsi_cauchy_viscous_inner(mu::Real, u, v) = 2.0 * Float64(mu) * (ε(v) ⊙ ε(u))

function native_resolved_fsi_section41_poiseuille_inlet_velocity_function(
    mesh::NativeResolvedFSIMesh,
    wall_radius_at_z,
    inlet_umax_cm_s::Real,
)
    umax = Float64(inlet_umax_cm_s)
    isfinite(umax) ||
        throw(ArgumentError("native resolved-FSI Section 4.1 inlet_umax_cm_s must be finite"))
    umax > 0.0 ||
        throw(ArgumentError("native resolved-FSI Section 4.1 inlet_umax_cm_s must be positive"))
    length_cm = mesh.case_spec.length_cm
    return function poiseuille_inlet_velocity(x)
        z = clamp(Float64(x[3]), 0.0, length_cm)
        radius = Float64(wall_radius_at_z(z))
        isfinite(radius) ||
            throw(ArgumentError("native resolved-FSI Section 4.1 inlet radius must be finite"))
        radius > 0.0 ||
            throw(ArgumentError("native resolved-FSI Section 4.1 inlet radius must be positive"))
        radial_fraction = clamp(hypot(Float64(x[1]), Float64(x[2])) / radius, 0.0, 1.0)
        return VectorValue(0.0, 0.0, umax * max(0.0, 1.0 - radial_fraction^2))
    end
end

function native_resolved_fsi_inlet_outlet_boundary_status(
    mode::Symbol;
    inlet_umax_cm_s::Real,
)
    if mode === :pressure_drop_weak_inlet_outlet_gauge_smoke
        return "pressure_drop_weak_inlet_outlet_gauge_smoke active: weak pressure-drop inlet loading " *
               "with force-density dynamic-pressure units, symmetric-gradient Newtonian Cauchy stress, " *
               "$(native_resolved_fsi_pressure_space_policy(mode).status); " *
               "local smoke boundary evidence only, " *
               "not exact Section 4.1 Poiseuille-inlet reproduction"
    end
    if mode === :poiseuille_inlet_zero_outlet_stress_section41
        return "poiseuille_inlet_zero_outlet_stress_section41 active: strong inlet Dirichlet " *
               "Poiseuille profile with u_max=$(Float64(inlet_umax_cm_s)) cm/s, force-density " *
               "dynamic-pressure units, symmetric-gradient Newtonian Cauchy stress, zero outlet stress " *
               "as the natural traction boundary for the Cauchy stress ((-pI + 2mu*epsilon(u))n = 0), " *
               "$(native_resolved_fsi_pressure_space_policy(mode).status), " *
               "and no pressure-drop weak inlet/outlet loading"
    end
    throw(ArgumentError("unsupported native resolved-FSI inlet/outlet boundary mode $(repr(mode))"))
end

function native_resolved_fsi_solve_fixed_wall_stokes(mesh::NativeResolvedFSIMesh, spec::NativeResolvedFSISmokeSpec)
    params = Params(severity=mesh.case_spec.severity_percent, tfinal=spec.saved_time_s, initial_condition=GeometryRestIC())
    mu = params.rho * params.nu
    mu > 0.0 || throw(ArgumentError("native resolved-FSI smoke requires positive dynamic viscosity rho*nu"))

    model, labels = native_resolved_fsi_gridap_model(mesh)
    order = 2
    reffe_u = ReferenceFE(lagrangian, VectorValue{3,Float64}, order)
    reffe_p = ReferenceFE(lagrangian, Float64, order - 1)
    zero_velocity(x) = VectorValue(0.0, 0.0, 0.0)
    V = TestFESpace(model, reffe_u, labels=labels, dirichlet_tags="wall", conformity=:H1)
    Q = native_resolved_fsi_pressure_test_space(
        model,
        reffe_p,
        labels,
        :pressure_drop_weak_inlet_outlet_gauge_smoke,
    )
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

    a((u, pfield), (v, q)) =
        ∫(native_resolved_fsi_cauchy_viscous_inner(mu, u, v) - (∇ ⋅ v) * pfield + q * (∇ ⋅ u)) * dΩ
    l((v, q)) = ∫(-spec.pressure_drop_dyn_cm2 * (v ⋅ n_in)) * dΓin + ∫(-0.0 * (v ⋅ n_out)) * dΓout

    velocity_h, pressure_h = solve(AffineFEOperator(a, l, X, Y))
    return NativeResolvedFSIStokesSmokeSolve(
        velocity_h,
        pressure_h,
        length(get_free_dof_values(velocity_h)),
        length(get_free_dof_values(pressure_h)),
    )
end

function native_resolved_fsi_solve_fixed_wall_navier_stokes(
    mesh::NativeResolvedFSIMesh,
    spec::NativeResolvedFSINavierStokesSmokeSpec,
)
    controls = native_resolved_fsi_navier_stokes_controls(spec)
    return native_resolved_fsi_solve_navier_stokes(
        mesh;
        dt_s=controls.dt_s,
        tfinal_s=controls.tfinal_s,
        pressure_drop_dyn_cm2=controls.pressure_drop_dyn_cm2,
        picard_iteration_count=controls.picard_iteration_count,
        picard_tolerance=controls.picard_tolerance,
    )
end

function native_resolved_fsi_navier_stokes_controls(spec::NativeResolvedFSINavierStokesSmokeSpec)
    return (
        dt_s=spec.dt_s,
        tfinal_s=spec.tfinal_s,
        pressure_drop_dyn_cm2=spec.pressure_drop_dyn_cm2,
        picard_iteration_count=spec.picard_iteration_count,
        picard_tolerance=spec.picard_tolerance,
    )
end

function native_resolved_fsi_navier_stokes_controls(spec::NativeResolvedFSIPartitionedSmokeSpec)
    return (
        dt_s=spec.dt_s,
        tfinal_s=spec.tfinal_s,
        inlet_outlet_boundary_mode=spec.inlet_outlet_boundary_mode,
        inlet_umax_cm_s=spec.inlet_umax_cm_s,
        pressure_drop_dyn_cm2=spec.pressure_drop_dyn_cm2,
        picard_iteration_count=spec.picard_iteration_count,
        picard_tolerance=spec.picard_tolerance,
    )
end

function native_resolved_fsi_short_digest(value)
    return bytes2hex(sha256(string(value)))[1:16]
end

function native_resolved_fsi_vector_digest(values)
    byte_digest = try
        bytes2hex(sha256(reinterpret(UInt8, values)))
    catch
        bytes2hex(sha256(string(collect(values))))
    end
    return native_resolved_fsi_short_digest((
        length=length(values),
        eltype=string(eltype(values)),
        byte_digest=byte_digest,
    ))
end

function native_resolved_fsi_sparse_structure_digest(matrix)
    if matrix isa SparseMatrixCSC
        return native_resolved_fsi_short_digest((
            size=size(matrix),
            nnz=nnz(matrix),
            colptr_digest=native_resolved_fsi_vector_digest(matrix.colptr),
            rowval_digest=native_resolved_fsi_vector_digest(rowvals(matrix)),
        ))
    end
    return native_resolved_fsi_short_digest((size=size(matrix), type=string(typeof(matrix))))
end

native_resolved_fsi_matrix_nnz(matrix) =
    matrix isa SparseMatrixCSC ? nnz(matrix) : count(!iszero, matrix)

function native_resolved_fsi_matrix_value_digest(matrix)
    if matrix isa SparseMatrixCSC
        return native_resolved_fsi_short_digest((
            size=size(matrix),
            nnz=nnz(matrix),
            value_digest=native_resolved_fsi_vector_digest(nonzeros(matrix)),
        ))
    end
    return native_resolved_fsi_short_digest((size=size(matrix), values=native_resolved_fsi_vector_digest(vec(Matrix(matrix)))))
end

function native_resolved_fsi_mesh_topology_digest(mesh::NativeResolvedFSIMesh)
    return native_resolved_fsi_short_digest((
        node_count=size(mesh.coordinates, 1),
        tetrahedron_count=size(mesh.topology, 1),
        topology_digest=native_resolved_fsi_vector_digest(vec(mesh.topology)),
        axial_station_digest=native_resolved_fsi_vector_digest(mesh.geometry.axial_coordinates_cm),
        reference_radius_digest=native_resolved_fsi_vector_digest(mesh.geometry.reference_radii_cm),
    ))
end

native_resolved_fsi_coordinate_value_digest(coordinates::AbstractMatrix{<:Real}) =
    native_resolved_fsi_vector_digest(vec(coordinates))

mutable struct NativeResolvedFSIGridapContext
    mesh_topology_digest::String
    node_count::Int
    tetrahedron_count::Int
    boundary_mode::Symbol
    quadrature_degree::Int
    reference_matrix_structure_digest::String
    reference_matrix_value_digest::String
    reference_matrix_rows::Int
    reference_matrix_cols::Int
    reference_matrix_nnz::Int
    symbolic_factorization::Any
    symbolic_factorization_structure_digest::String
    symbolic_factorization_setup_count::Int
    symbolic_factorization_reuse_count::Int
    numeric_factorization::Any
    numeric_factorization_cache_key::String
    numeric_factorization_structure_digest::String
    numeric_factorization_value_digest::String
    numeric_factorization_setup_count::Int
    numeric_factorization_reuse_count::Int
    matrix_value_digest_observation_count::Int
    matrix_value_digest_counts::Dict{String,Int}
    matrix_value_digest_history_tail::Vector{String}
end

struct NativeResolvedFSIReuseReport
    context_reused::Bool
    model_reused::Bool
    fe_spaces_reused::Bool
    measures_reused::Bool
    matrix_structure_stable::String
    symbolic_factorization_eligible::String
    symbolic_factorization_reused::Bool
    symbolic_factorization_cache_status::String
    symbolic_factorization_setup_count::Int
    symbolic_factorization_reuse_count::Int
    numeric_factorization_reused::Bool
    numeric_factorization_cache_status::String
    numeric_factorization_cache_key::String
    numeric_factorization_matrix_value_digest::String
    numeric_factorization_setup_count::Int
    numeric_factorization_reuse_count::Int
    reason_codes::Vector{String}
    mesh_topology_digest::String
    coordinate_value_digest::String
    matrix_value_baseline_digest::String
    matrix_value_digest_observation_count::Int
    matrix_value_digest_unique_count::Int
    matrix_value_digest_current_count::Int
    matrix_value_digest_repeat_count::Int
    matrix_value_digest_history_tail::String
    boundary_mode::String
    quadrature_degree::Int
    matrix_rows::Int
    matrix_cols::Int
    matrix_nnz::Int
end

function build_native_resolved_fsi_gridap_context(
    mesh::NativeResolvedFSIMesh;
    inlet_outlet_boundary_mode::Union{Symbol,AbstractString},
    quadrature_degree::Integer,
)
    boundary_mode = native_resolved_fsi_inlet_outlet_boundary_mode(inlet_outlet_boundary_mode)
    return NativeResolvedFSIGridapContext(
        native_resolved_fsi_mesh_topology_digest(mesh),
        size(mesh.coordinates, 1),
        size(mesh.topology, 1),
        boundary_mode,
        Int(quadrature_degree),
        "",
        "",
        0,
        0,
        0,
        nothing,
        "",
        0,
        0,
        nothing,
        "",
        "",
        "",
        0,
        0,
        0,
        Dict{String,Int}(),
        String[],
    )
end

function native_resolved_fsi_validate_gridap_context(
    context::NativeResolvedFSIGridapContext,
    mesh::NativeResolvedFSIMesh;
    inlet_outlet_boundary_mode::Union{Symbol,AbstractString},
    quadrature_degree::Integer,
)
    boundary_mode = native_resolved_fsi_inlet_outlet_boundary_mode(inlet_outlet_boundary_mode)
    expected_topology_digest = native_resolved_fsi_mesh_topology_digest(mesh)
    context.mesh_topology_digest == expected_topology_digest || throw(ArgumentError(
        "native resolved-FSI Gridap context mesh topology digest does not match the current mesh",
    ))
    context.boundary_mode === boundary_mode || throw(ArgumentError(
        "native resolved-FSI Gridap context boundary mode $(repr(context.boundary_mode)) does not match $(repr(boundary_mode))",
    ))
    context.quadrature_degree == Int(quadrature_degree) || throw(ArgumentError(
        "native resolved-FSI Gridap context quadrature degree $(context.quadrature_degree) does not match $(Int(quadrature_degree))",
    ))
    return context
end

function native_resolved_fsi_gridap_context_for(
    mesh::NativeResolvedFSIMesh,
    gridap_context;
    inlet_outlet_boundary_mode::Union{Symbol,AbstractString},
    quadrature_degree::Integer,
)
    if gridap_context === nothing
        return build_native_resolved_fsi_gridap_context(
            mesh;
            inlet_outlet_boundary_mode=inlet_outlet_boundary_mode,
            quadrature_degree=quadrature_degree,
        )
    end
    gridap_context isa NativeResolvedFSIGridapContext || throw(ArgumentError(
        "native resolved-FSI Gridap context must be a NativeResolvedFSIGridapContext",
    ))
    return native_resolved_fsi_validate_gridap_context(
        gridap_context,
        mesh;
        inlet_outlet_boundary_mode=inlet_outlet_boundary_mode,
        quadrature_degree=quadrature_degree,
    )
end

function native_resolved_fsi_record_matrix_value_digest!(
    context::NativeResolvedFSIGridapContext,
    matrix_value_digest::AbstractString,
)
    digest = String(matrix_value_digest)
    if isempty(context.reference_matrix_value_digest)
        context.reference_matrix_value_digest = digest
    end
    context.matrix_value_digest_observation_count += 1
    context.matrix_value_digest_counts[digest] = get(context.matrix_value_digest_counts, digest, 0) + 1
    push!(context.matrix_value_digest_history_tail, digest)
    if length(context.matrix_value_digest_history_tail) > 16
        popfirst!(context.matrix_value_digest_history_tail)
    end
    return (
        observation_count=context.matrix_value_digest_observation_count,
        unique_count=length(context.matrix_value_digest_counts),
        current_count=context.matrix_value_digest_counts[digest],
        repeat_count=context.matrix_value_digest_observation_count - length(context.matrix_value_digest_counts),
        history_tail=join(context.matrix_value_digest_history_tail, "|"),
    )
end

function native_resolved_fsi_reuse_report!(
    context::NativeResolvedFSIGridapContext,
    matrix;
    coordinate_value_digest::AbstractString,
    matrix_structure_digest::AbstractString,
    matrix_value_digest::AbstractString,
    boundary_mode::AbstractString,
    quadrature_degree::Integer,
)
    matrix_rows = size(matrix, 1)
    matrix_cols = size(matrix, 2)
    matrix_nnz = native_resolved_fsi_matrix_nnz(matrix)
    matrix_value_observation = native_resolved_fsi_record_matrix_value_digest!(context, matrix_value_digest)
    reason_codes = String[
        "gridap_model_rebuilt_coordinate_capture_risk",
        "fe_spaces_rebuilt_boundary_function_capture_risk",
        "measures_rebuilt_gridap_object_mutability_unproven",
        "numeric_factorization_requires_exact_matrix_value_digest_match",
    ]
    structure_stable = "unknown"
    symbolic_eligible = "unknown"
    context_reused = !isempty(context.reference_matrix_structure_digest)
    if isempty(context.reference_matrix_structure_digest)
        context.reference_matrix_structure_digest = matrix_structure_digest
        context.reference_matrix_rows = matrix_rows
        context.reference_matrix_cols = matrix_cols
        context.reference_matrix_nnz = matrix_nnz
        push!(reason_codes, "matrix_structure_baseline_recorded_this_solve")
    elseif context.reference_matrix_structure_digest == matrix_structure_digest &&
           context.reference_matrix_rows == matrix_rows &&
           context.reference_matrix_cols == matrix_cols &&
           context.reference_matrix_nnz == matrix_nnz &&
           string(context.boundary_mode) == boundary_mode &&
           context.quadrature_degree == Int(quadrature_degree)
        structure_stable = "yes"
        symbolic_eligible = "yes"
        push!(reason_codes, "matrix_structure_matches_context_baseline")
        push!(reason_codes, "symbolic_factorization_eligible_for_context_cache")
    else
        structure_stable = "no"
        symbolic_eligible = "no"
        push!(reason_codes, "matrix_structure_or_context_invariant_changed")
    end
    return NativeResolvedFSIReuseReport(
        context_reused,
        false,
        false,
        false,
        structure_stable,
        symbolic_eligible,
        false,
        "pending_symbolic_factorization_decision",
        context.symbolic_factorization_setup_count,
        context.symbolic_factorization_reuse_count,
        false,
        "pending_numeric_factorization_decision",
        "",
        String(matrix_value_digest),
        context.numeric_factorization_setup_count,
        context.numeric_factorization_reuse_count,
        reason_codes,
        context.mesh_topology_digest,
        String(coordinate_value_digest),
        context.reference_matrix_value_digest,
        matrix_value_observation.observation_count,
        matrix_value_observation.unique_count,
        matrix_value_observation.current_count,
        matrix_value_observation.repeat_count,
        matrix_value_observation.history_tail,
        boundary_mode,
        Int(quadrature_degree),
        matrix_rows,
        matrix_cols,
        matrix_nnz,
    )
end

function native_resolved_fsi_reuse_report_without_context(
    matrix;
    coordinate_value_digest::AbstractString,
    matrix_value_digest::AbstractString,
    boundary_mode::AbstractString,
    quadrature_degree::Integer,
)
    return NativeResolvedFSIReuseReport(
        false,
        false,
        false,
        false,
        "unknown",
        "unknown",
        false,
        "gridap_context_missing",
        0,
        0,
        false,
        "numeric_factorization_uncached_no_gridap_context",
        "",
        String(matrix_value_digest),
        0,
        0,
        String["gridap_context_missing", "numeric_factorization_requires_gridap_context"],
        "",
        String(coordinate_value_digest),
        String(matrix_value_digest),
        1,
        1,
        1,
        0,
        String(matrix_value_digest),
        boundary_mode,
        Int(quadrature_degree),
        size(matrix, 1),
        size(matrix, 2),
        native_resolved_fsi_matrix_nnz(matrix),
    )
end

native_resolved_fsi_reuse_reason_codes(report::NativeResolvedFSIReuseReport) =
    join(report.reason_codes, "|")

function native_resolved_fsi_reuse_report_named_tuple(report::NativeResolvedFSIReuseReport)
    return (
        gridap_context_reused=report.context_reused,
        gridap_model_reused=report.model_reused,
        gridap_fe_spaces_reused=report.fe_spaces_reused,
        gridap_measures_reused=report.measures_reused,
        gridap_matrix_structure_stable=report.matrix_structure_stable,
        gridap_symbolic_factorization_eligible=report.symbolic_factorization_eligible,
        gridap_symbolic_factorization_reused=report.symbolic_factorization_reused,
        gridap_symbolic_factorization_cache_status=report.symbolic_factorization_cache_status,
        gridap_symbolic_factorization_setup_count=report.symbolic_factorization_setup_count,
        gridap_symbolic_factorization_reuse_count=report.symbolic_factorization_reuse_count,
        gridap_numeric_factorization_reused=report.numeric_factorization_reused,
        gridap_numeric_factorization_cache_status=report.numeric_factorization_cache_status,
        gridap_numeric_factorization_cache_key=report.numeric_factorization_cache_key,
        gridap_numeric_factorization_matrix_value_digest=report.numeric_factorization_matrix_value_digest,
        gridap_numeric_factorization_setup_count=report.numeric_factorization_setup_count,
        gridap_numeric_factorization_reuse_count=report.numeric_factorization_reuse_count,
        gridap_reuse_reason_codes=native_resolved_fsi_reuse_reason_codes(report),
        gridap_mesh_topology_digest=report.mesh_topology_digest,
        gridap_coordinate_value_digest=report.coordinate_value_digest,
        gridap_matrix_value_baseline_digest=report.matrix_value_baseline_digest,
        gridap_matrix_value_digest_observation_count=report.matrix_value_digest_observation_count,
        gridap_matrix_value_digest_unique_count=report.matrix_value_digest_unique_count,
        gridap_matrix_value_digest_current_count=report.matrix_value_digest_current_count,
        gridap_matrix_value_digest_repeat_count=report.matrix_value_digest_repeat_count,
        gridap_matrix_value_digest_history_tail=report.matrix_value_digest_history_tail,
        gridap_reuse_boundary_mode=report.boundary_mode,
        gridap_reuse_quadrature_degree=report.quadrature_degree,
        gridap_reuse_matrix_rows=report.matrix_rows,
        gridap_reuse_matrix_cols=report.matrix_cols,
        gridap_reuse_matrix_nnz=report.matrix_nnz,
    )
end

native_resolved_fsi_vector_l2_norm(values) = sqrt(sum(abs2, values))

function native_resolved_fsi_matrix_l2_norm(matrix)
    matrix isa SparseMatrixCSC && return sqrt(sum(abs2, nonzeros(matrix)))
    return sqrt(sum(abs2, matrix))
end

function native_resolved_fsi_relative_l2_change(candidate_norm::Real, reference_norm::Real)
    candidate_value = Float64(candidate_norm)
    reference_value = Float64(reference_norm)
    reference_value > 0.0 && return candidate_value / reference_value
    return candidate_value == 0.0 ? 0.0 : Inf
end

function native_resolved_fsi_max_abs(values)
    if values isa SparseMatrixCSC
        stored_values = nonzeros(values)
        isempty(stored_values) && return 0.0
        return Float64(maximum(abs, stored_values))
    end
    flat_values = vec(values)
    isempty(flat_values) && return 0.0
    return Float64(maximum(abs, flat_values))
end

function native_resolved_fsi_assemble_probe_operator(a, l, X, Y)
    operator_start_ns = time_ns()
    operator = AffineFEOperator(a, l, X, Y)
    operator_s = native_resolved_fsi_phase_elapsed_s(operator_start_ns)

    matrix_start_ns = time_ns()
    matrix = get_matrix(operator)
    matrix_s = native_resolved_fsi_phase_elapsed_s(matrix_start_ns)

    rhs_start_ns = time_ns()
    rhs = get_vector(operator)
    rhs_s = native_resolved_fsi_phase_elapsed_s(rhs_start_ns)

    return (
        matrix=matrix,
        rhs=rhs,
        operator_s=operator_s,
        matrix_extraction_s=matrix_s,
        rhs_extraction_s=rhs_s,
        total_s=operator_s + matrix_s + rhs_s,
    )
end

function native_resolved_fsi_matrix_difference_summary(
    candidate,
    reference;
    relative_tolerance::Real,
    absolute_tolerance::Real,
)
    difference = candidate - reference
    difference_norm = native_resolved_fsi_matrix_l2_norm(difference)
    reference_norm = native_resolved_fsi_matrix_l2_norm(reference)
    relative_difference = native_resolved_fsi_relative_l2_change(difference_norm, reference_norm)
    max_abs_difference = native_resolved_fsi_max_abs(difference)
    return (
        structure_digest=native_resolved_fsi_sparse_structure_digest(candidate),
        value_digest=native_resolved_fsi_matrix_value_digest(candidate),
        structure_digest_matches=native_resolved_fsi_sparse_structure_digest(candidate) ==
                                 native_resolved_fsi_sparse_structure_digest(reference),
        value_digest_matches=native_resolved_fsi_matrix_value_digest(candidate) ==
                             native_resolved_fsi_matrix_value_digest(reference),
        relative_l2_difference=relative_difference,
        max_abs_difference=max_abs_difference,
        within_tolerance=relative_difference <= Float64(relative_tolerance) ||
                         max_abs_difference <= Float64(absolute_tolerance),
    )
end

function native_resolved_fsi_vector_difference_summary(
    candidate,
    reference;
    relative_tolerance::Real,
    absolute_tolerance::Real,
)
    difference = candidate .- reference
    difference_norm = native_resolved_fsi_vector_l2_norm(difference)
    reference_norm = native_resolved_fsi_vector_l2_norm(reference)
    relative_difference = native_resolved_fsi_relative_l2_change(difference_norm, reference_norm)
    max_abs_difference = native_resolved_fsi_max_abs(difference)
    return (
        value_digest=native_resolved_fsi_vector_digest(candidate),
        value_digest_matches=native_resolved_fsi_vector_digest(candidate) ==
                             native_resolved_fsi_vector_digest(reference),
        relative_l2_difference=relative_difference,
        max_abs_difference=max_abs_difference,
        within_tolerance=relative_difference <= Float64(relative_tolerance) ||
                         max_abs_difference <= Float64(absolute_tolerance),
    )
end

function native_resolved_fsi_velocity_dof_digest(velocity_state)
    return native_resolved_fsi_vector_digest(get_free_dof_values(velocity_state))
end

function native_resolved_fsi_perturbed_velocity_state(U, velocity_state, perturbation_scale::Real)
    scale_value = Float64(perturbation_scale)
    isfinite(scale_value) ||
        throw(ArgumentError("native resolved-FSI velocity-state perturbation scale must be finite"))
    scale_value == 0.0 && return velocity_state
    values = Float64[Float64(value) for value in get_free_dof_values(velocity_state)]
    isempty(values) && return velocity_state
    amplitude = scale_value * max(maximum(abs, values), 1.0)
    for index in eachindex(values)
        values[index] += amplitude * sin(0.6180339887498948 * index)
    end
    return FEFunction(U, values)
end

function native_resolved_fsi_block_assembly_probe(
    weak_form_parts::NativeResolvedFSINavierStokesWeakFormParts,
    X,
    Y;
    matrix_relative_tolerance::Real = 1.0e-12,
    matrix_absolute_tolerance::Real = 1.0e-8,
    rhs_relative_tolerance::Real = 1.0e-12,
    rhs_absolute_tolerance::Real = 1.0e-8,
)
    full = native_resolved_fsi_assemble_probe_operator(weak_form_parts.a, weak_form_parts.l, X, Y)
    stable = native_resolved_fsi_assemble_probe_operator(
        weak_form_parts.stable_matrix_term,
        weak_form_parts.zero_rhs_term,
        X,
        Y,
    )
    convection = native_resolved_fsi_assemble_probe_operator(
        weak_form_parts.convection_matrix_term,
        weak_form_parts.zero_rhs_term,
        X,
        Y,
    )
    component_form_sum = native_resolved_fsi_assemble_probe_operator(
        weak_form_parts.component_sum_matrix_term,
        weak_form_parts.component_sum_rhs_term,
        X,
        Y,
    )
    previous_rhs = native_resolved_fsi_assemble_probe_operator(
        weak_form_parts.zero_matrix_term,
        weak_form_parts.previous_state_rhs_term,
        X,
        Y,
    )
    boundary_rhs = native_resolved_fsi_assemble_probe_operator(
        weak_form_parts.zero_matrix_term,
        weak_form_parts.boundary_rhs_term,
        X,
        Y,
    )

    sparse_sum_start_ns = time_ns()
    sparse_block_matrix = stable.matrix + convection.matrix
    sparse_block_rhs = previous_rhs.rhs .+ boundary_rhs.rhs
    sparse_sum_s = native_resolved_fsi_phase_elapsed_s(sparse_sum_start_ns)

    sparse_matrix_summary = native_resolved_fsi_matrix_difference_summary(
        sparse_block_matrix,
        full.matrix;
        relative_tolerance=matrix_relative_tolerance,
        absolute_tolerance=matrix_absolute_tolerance,
    )
    form_sum_matrix_summary = native_resolved_fsi_matrix_difference_summary(
        component_form_sum.matrix,
        full.matrix;
        relative_tolerance=matrix_relative_tolerance,
        absolute_tolerance=matrix_absolute_tolerance,
    )
    sparse_rhs_summary = native_resolved_fsi_vector_difference_summary(
        sparse_block_rhs,
        full.rhs;
        relative_tolerance=rhs_relative_tolerance,
        absolute_tolerance=rhs_absolute_tolerance,
    )
    form_sum_rhs_summary = native_resolved_fsi_vector_difference_summary(
        component_form_sum.rhs,
        full.rhs;
        relative_tolerance=rhs_relative_tolerance,
        absolute_tolerance=rhs_absolute_tolerance,
    )

    return (
        status="block_assembly_probe_completed",
        component_terms=weak_form_parts.component_terms,
        matrix_relative_tolerance=Float64(matrix_relative_tolerance),
        matrix_absolute_tolerance=Float64(matrix_absolute_tolerance),
        rhs_relative_tolerance=Float64(rhs_relative_tolerance),
        rhs_absolute_tolerance=Float64(rhs_absolute_tolerance),
        rows=size(full.matrix, 1),
        cols=size(full.matrix, 2),
        nnz=native_resolved_fsi_matrix_nnz(full.matrix),
        full_matrix=full.matrix,
        full_rhs=full.rhs,
        full_matrix_structure_digest=native_resolved_fsi_sparse_structure_digest(full.matrix),
        full_matrix_value_digest=native_resolved_fsi_matrix_value_digest(full.matrix),
        full_rhs_digest=native_resolved_fsi_vector_digest(full.rhs),
        stable_matrix_structure_digest=native_resolved_fsi_sparse_structure_digest(stable.matrix),
        stable_matrix_value_digest=native_resolved_fsi_matrix_value_digest(stable.matrix),
        stable_matrix_nnz=native_resolved_fsi_matrix_nnz(stable.matrix),
        convection_matrix_structure_digest=native_resolved_fsi_sparse_structure_digest(convection.matrix),
        convection_matrix_value_digest=native_resolved_fsi_matrix_value_digest(convection.matrix),
        convection_matrix_nnz=native_resolved_fsi_matrix_nnz(convection.matrix),
        sparse_block_matrix_structure_digest=sparse_matrix_summary.structure_digest,
        sparse_block_matrix_value_digest=sparse_matrix_summary.value_digest,
        sparse_block_matrix_structure_digest_matches=sparse_matrix_summary.structure_digest_matches,
        sparse_block_matrix_value_digest_matches=sparse_matrix_summary.value_digest_matches,
        sparse_block_matrix_relative_l2_difference=sparse_matrix_summary.relative_l2_difference,
        sparse_block_matrix_max_abs_difference=sparse_matrix_summary.max_abs_difference,
        sparse_block_matrix_within_tolerance=sparse_matrix_summary.within_tolerance,
        form_sum_matrix_structure_digest=form_sum_matrix_summary.structure_digest,
        form_sum_matrix_value_digest=form_sum_matrix_summary.value_digest,
        form_sum_matrix_structure_digest_matches=form_sum_matrix_summary.structure_digest_matches,
        form_sum_matrix_value_digest_matches=form_sum_matrix_summary.value_digest_matches,
        form_sum_matrix_relative_l2_difference=form_sum_matrix_summary.relative_l2_difference,
        form_sum_matrix_max_abs_difference=form_sum_matrix_summary.max_abs_difference,
        form_sum_matrix_within_tolerance=form_sum_matrix_summary.within_tolerance,
        previous_rhs_digest=native_resolved_fsi_vector_digest(previous_rhs.rhs),
        boundary_rhs_digest=native_resolved_fsi_vector_digest(boundary_rhs.rhs),
        sparse_block_rhs_digest=sparse_rhs_summary.value_digest,
        sparse_block_rhs_value_digest_matches=sparse_rhs_summary.value_digest_matches,
        sparse_block_rhs_relative_l2_difference=sparse_rhs_summary.relative_l2_difference,
        sparse_block_rhs_max_abs_difference=sparse_rhs_summary.max_abs_difference,
        sparse_block_rhs_within_tolerance=sparse_rhs_summary.within_tolerance,
        form_sum_rhs_digest=form_sum_rhs_summary.value_digest,
        form_sum_rhs_value_digest_matches=form_sum_rhs_summary.value_digest_matches,
        form_sum_rhs_relative_l2_difference=form_sum_rhs_summary.relative_l2_difference,
        form_sum_rhs_max_abs_difference=form_sum_rhs_summary.max_abs_difference,
        form_sum_rhs_within_tolerance=form_sum_rhs_summary.within_tolerance,
        full_assembly_s=full.total_s,
        stable_matrix_assembly_s=stable.total_s,
        convection_matrix_assembly_s=convection.total_s,
        component_form_sum_assembly_s=component_form_sum.total_s,
        previous_rhs_assembly_s=previous_rhs.total_s,
        boundary_rhs_assembly_s=boundary_rhs.total_s,
        sparse_sum_s=sparse_sum_s,
    )
end

function native_resolved_fsi_quadrature_sensitivity_diagnostics(
    matrix,
    rhs,
    sensitivity_operator_builder;
    primary_degree::Integer,
    sensitivity_degree::Integer,
)
    primary_degree_value = Int(primary_degree)
    sensitivity_degree_value = Int(sensitivity_degree)
    try
        sensitivity_operator = sensitivity_operator_builder()
        sensitivity_matrix = get_matrix(sensitivity_operator)
        sensitivity_rhs = get_vector(sensitivity_operator)
        matrix_relative_change = native_resolved_fsi_relative_l2_change(
            native_resolved_fsi_matrix_l2_norm(sensitivity_matrix - matrix),
            native_resolved_fsi_matrix_l2_norm(matrix),
        )
        rhs_relative_change = native_resolved_fsi_relative_l2_change(
            native_resolved_fsi_vector_l2_norm(sensitivity_rhs .- rhs),
            native_resolved_fsi_vector_l2_norm(rhs),
        )
        finite_status =
            isfinite(matrix_relative_change) && isfinite(rhs_relative_change) ?
            "higher_degree_quadrature_assembly_comparison_recorded" :
            "higher_degree_quadrature_assembly_comparison_nonfinite"
        return (
            gridap_quadrature_degree=primary_degree_value,
            gridap_quadrature_sensitivity_degree=sensitivity_degree_value,
            gridap_quadrature_sensitivity_matrix_relative_change=matrix_relative_change,
            gridap_quadrature_sensitivity_rhs_relative_change=rhs_relative_change,
            gridap_quadrature_sensitivity_status=
                "$(finite_status); diagnostic_only_no_convergence_or_solver_semantics_claim",
        )
    catch error
        return (
            gridap_quadrature_degree=primary_degree_value,
            gridap_quadrature_sensitivity_degree=sensitivity_degree_value,
            gridap_quadrature_sensitivity_matrix_relative_change=NaN,
            gridap_quadrature_sensitivity_rhs_relative_change=NaN,
            gridap_quadrature_sensitivity_status=
                "higher_degree_quadrature_assembly_comparison_failed: $(sprint(showerror, error)); " *
                "diagnostic_only_no_solver_semantics_changed",
        )
    end
end

function native_resolved_fsi_solver_diagnostics(
    matrix,
    rhs;
    context::NamedTuple = NamedTuple(),
)
    pressure_constraint = string(get(context, :pressure_constraint, "unknown"))
    pressure_reference = string(get(context, :pressure_reference, "unknown"))
    boundary_mode = string(get(context, :boundary_mode, "unknown"))
    wall_boundary_mode = string(get(context, :wall_boundary_mode, "unknown"))
    quadrature_degree = Int(get(context, :quadrature_degree, 0))
    coordinate_value_digest = string(get(context, :coordinate_value_digest, ""))
    gridap_context = get(context, :gridap_context, nothing)
    matrix_rows = size(matrix, 1)
    matrix_cols = size(matrix, 2)
    matrix_nnz = native_resolved_fsi_matrix_nnz(matrix)
    matrix_structure_digest = native_resolved_fsi_sparse_structure_digest(matrix)
    matrix_value_digest = native_resolved_fsi_matrix_value_digest(matrix)
    rhs_digest = native_resolved_fsi_vector_digest(rhs)
    reuse_report = if gridap_context isa NativeResolvedFSIGridapContext
        native_resolved_fsi_reuse_report!(
            gridap_context,
            matrix;
            coordinate_value_digest=coordinate_value_digest,
            matrix_structure_digest=matrix_structure_digest,
            matrix_value_digest=matrix_value_digest,
            boundary_mode=boundary_mode,
            quadrature_degree=quadrature_degree,
        )
    else
        native_resolved_fsi_reuse_report_without_context(
            matrix;
            coordinate_value_digest=coordinate_value_digest,
            matrix_value_digest=matrix_value_digest,
            boundary_mode=boundary_mode,
            quadrature_degree=quadrature_degree,
        )
    end
    return merge((
        gridap_rebuild_status="rebuild_unconditionally_current_path",
        gridap_reuse_status="structured_reuse_diagnostics_symbolic_and_exact_numeric_cache_probe",
        gridap_reuse_miss_reason=join(reuse_report.reason_codes, "; "),
        gridap_operator_component_status=string(get(
            context,
            :operator_component_status,
            "not_evaluated",
        )),
        gridap_operator_component_terms=string(get(context, :operator_component_terms, "")),
        gridap_solver_backend_status="gridap_lusolver_default_backend",
        gridap_matrix_rows=matrix_rows,
        gridap_matrix_cols=matrix_cols,
        gridap_matrix_nnz=matrix_nnz,
        gridap_matrix_structure_digest=matrix_structure_digest,
        gridap_matrix_value_digest=matrix_value_digest,
        gridap_rhs_digest=rhs_digest,
        gridap_boundary_mode=boundary_mode,
        gridap_pressure_constraint=pressure_constraint,
        gridap_pressure_reference=pressure_reference,
        gridap_wall_boundary_mode=wall_boundary_mode,
        gridap_quadrature_degree=quadrature_degree,
        gridap_quadrature_sensitivity_degree=Int(get(context, :quadrature_sensitivity_degree, 0)),
        gridap_quadrature_sensitivity_matrix_relative_change=NaN,
        gridap_quadrature_sensitivity_rhs_relative_change=NaN,
        gridap_quadrature_sensitivity_status="not_evaluated",
        gridap_open_boundary_status="not_evaluated",
        gridap_outlet_node_count=0,
        gridap_outlet_velocity_sampling_fallback_count=0,
        gridap_outlet_backflow_node_count=0,
        gridap_outlet_normal_velocity_min_cm_s=NaN,
        gridap_outlet_normal_velocity_max_cm_s=NaN,
        gridap_outlet_normal_velocity_mean_cm_s=NaN,
        gridap_dt_s=Float64(get(context, :dt_s, NaN)),
        gridap_time_step_index=Int(get(context, :time_step_index, 0)),
        gridap_picard_iteration=Int(get(context, :picard_iteration, 0)),
        gridap_linear_solve_count=Int(get(context, :linear_solve_count, 0)),
        gridap_rebuild_count=Int(get(context, :gridap_rebuild_count, 0)),
    ), native_resolved_fsi_reuse_report_named_tuple(reuse_report))
end

function native_resolved_fsi_numeric_factorization_cache_key(solver_diagnostics::NamedTuple)
    return native_resolved_fsi_short_digest((
        matrix_structure_digest=solver_diagnostics.gridap_matrix_structure_digest,
        matrix_value_digest=solver_diagnostics.gridap_matrix_value_digest,
        matrix_rows=solver_diagnostics.gridap_matrix_rows,
        matrix_cols=solver_diagnostics.gridap_matrix_cols,
        matrix_nnz=solver_diagnostics.gridap_matrix_nnz,
        boundary_mode=solver_diagnostics.gridap_boundary_mode,
        quadrature_degree=solver_diagnostics.gridap_quadrature_degree,
        pressure_constraint=solver_diagnostics.gridap_pressure_constraint,
        pressure_reference=solver_diagnostics.gridap_pressure_reference,
    ))
end

function native_resolved_fsi_numeric_factorization_diagnostics(
    context::NativeResolvedFSIGridapContext;
    reused::Bool,
    cache_status::AbstractString,
    cache_key::AbstractString,
    matrix_value_digest::AbstractString,
)
    return (
        gridap_numeric_factorization_reused=reused,
        gridap_numeric_factorization_cache_status=String(cache_status),
        gridap_numeric_factorization_cache_key=String(cache_key),
        gridap_numeric_factorization_matrix_value_digest=String(matrix_value_digest),
        gridap_numeric_factorization_setup_count=context.numeric_factorization_setup_count,
        gridap_numeric_factorization_reuse_count=context.numeric_factorization_reuse_count,
    )
end

function native_resolved_fsi_numeric_factorization_diagnostics(;
    reused::Bool,
    cache_status::AbstractString,
    cache_key::AbstractString,
    matrix_value_digest::AbstractString,
)
    return (
        gridap_numeric_factorization_reused=reused,
        gridap_numeric_factorization_cache_status=String(cache_status),
        gridap_numeric_factorization_cache_key=String(cache_key),
        gridap_numeric_factorization_matrix_value_digest=String(matrix_value_digest),
        gridap_numeric_factorization_setup_count=0,
        gridap_numeric_factorization_reuse_count=0,
    )
end

function native_resolved_fsi_symbolic_factorization_diagnostics(
    context::NativeResolvedFSIGridapContext;
    reused::Bool,
    cache_status::AbstractString,
)
    return (
        gridap_symbolic_factorization_reused=reused,
        gridap_symbolic_factorization_cache_status=String(cache_status),
        gridap_symbolic_factorization_setup_count=context.symbolic_factorization_setup_count,
        gridap_symbolic_factorization_reuse_count=context.symbolic_factorization_reuse_count,
    )
end

function native_resolved_fsi_symbolic_factorization_diagnostics(;
    reused::Bool,
    cache_status::AbstractString,
)
    return (
        gridap_symbolic_factorization_reused=reused,
        gridap_symbolic_factorization_cache_status=String(cache_status),
        gridap_symbolic_factorization_setup_count=0,
        gridap_symbolic_factorization_reuse_count=0,
    )
end

function native_resolved_fsi_symbolic_setup_with_cache!(
    solver,
    matrix,
    phase_timing::AbstractDict{Symbol,Float64},
    solver_diagnostics::NamedTuple,
    gridap_context,
)
    structure_digest = solver_diagnostics.gridap_matrix_structure_digest
    if gridap_context isa NativeResolvedFSIGridapContext &&
       solver_diagnostics.gridap_symbolic_factorization_eligible == "yes" &&
       gridap_context.symbolic_factorization !== nothing &&
       gridap_context.symbolic_factorization_structure_digest == structure_digest
        gridap_context.symbolic_factorization_reuse_count += 1
        return gridap_context.symbolic_factorization, merge(
            solver_diagnostics,
            native_resolved_fsi_symbolic_factorization_diagnostics(
                gridap_context;
                reused=true,
                cache_status="symbolic_factorization_reused_from_context",
            ),
        )
    end

    start_ns = time_ns()
    symbolic = symbolic_setup(solver, matrix)
    native_resolved_fsi_record_phase_elapsed!(:linear_symbolic_factorization_s, start_ns, phase_timing)

    if gridap_context isa NativeResolvedFSIGridapContext
        cache_status = if solver_diagnostics.gridap_symbolic_factorization_eligible == "yes"
            "symbolic_factorization_cache_miss_rebuilt"
        elseif solver_diagnostics.gridap_symbolic_factorization_eligible == "unknown"
            "symbolic_factorization_cache_initialized"
        else
            "symbolic_factorization_not_cached_structure_or_context_changed"
        end
        if solver_diagnostics.gridap_symbolic_factorization_eligible != "no"
            gridap_context.symbolic_factorization = symbolic
            gridap_context.symbolic_factorization_structure_digest = structure_digest
        end
        gridap_context.symbolic_factorization_setup_count += 1
        return symbolic, merge(
            solver_diagnostics,
            native_resolved_fsi_symbolic_factorization_diagnostics(
                gridap_context;
                reused=false,
                cache_status=cache_status,
            ),
        )
    end

    return symbolic, merge(
        solver_diagnostics,
        native_resolved_fsi_symbolic_factorization_diagnostics(
            reused=false,
            cache_status="symbolic_factorization_uncached_no_gridap_context",
        ),
    )
end

function native_resolved_fsi_numeric_setup_with_cache!(
    symbolic,
    matrix,
    phase_timing::AbstractDict{Symbol,Float64},
    solver_diagnostics::NamedTuple,
    gridap_context,
)
    cache_key = native_resolved_fsi_numeric_factorization_cache_key(solver_diagnostics)
    matrix_value_digest = solver_diagnostics.gridap_matrix_value_digest
    structure_digest = solver_diagnostics.gridap_matrix_structure_digest
    if gridap_context isa NativeResolvedFSIGridapContext &&
       gridap_context.numeric_factorization !== nothing &&
       gridap_context.numeric_factorization_cache_key == cache_key &&
       gridap_context.numeric_factorization_value_digest == matrix_value_digest &&
       gridap_context.numeric_factorization_structure_digest == structure_digest
        gridap_context.numeric_factorization_reuse_count += 1
        return gridap_context.numeric_factorization, merge(
            solver_diagnostics,
            native_resolved_fsi_numeric_factorization_diagnostics(
                gridap_context;
                reused=true,
                cache_status="numeric_factorization_reused_exact_matrix_value_digest",
                cache_key=cache_key,
                matrix_value_digest=matrix_value_digest,
            ),
        )
    end

    start_ns = time_ns()
    numeric = numerical_setup(symbolic, matrix)
    native_resolved_fsi_record_phase_elapsed!(:linear_numeric_factorization_s, start_ns, phase_timing)

    if gridap_context isa NativeResolvedFSIGridapContext
        cache_status = if isempty(gridap_context.numeric_factorization_cache_key)
            "numeric_factorization_cache_initialized"
        elseif gridap_context.numeric_factorization_structure_digest != structure_digest
            "numeric_factorization_cache_miss_structure_changed"
        elseif gridap_context.numeric_factorization_value_digest != matrix_value_digest
            "numeric_factorization_cache_miss_matrix_value_changed"
        else
            "numeric_factorization_cache_miss_key_changed"
        end
        gridap_context.numeric_factorization = numeric
        gridap_context.numeric_factorization_cache_key = cache_key
        gridap_context.numeric_factorization_structure_digest = structure_digest
        gridap_context.numeric_factorization_value_digest = matrix_value_digest
        gridap_context.numeric_factorization_setup_count += 1
        return numeric, merge(
            solver_diagnostics,
            native_resolved_fsi_numeric_factorization_diagnostics(
                gridap_context;
                reused=false,
                cache_status=cache_status,
                cache_key=cache_key,
                matrix_value_digest=matrix_value_digest,
            ),
        )
    end

    return numeric, merge(
        solver_diagnostics,
        native_resolved_fsi_numeric_factorization_diagnostics(
            reused=false,
            cache_status="numeric_factorization_uncached_no_gridap_context",
            cache_key=cache_key,
            matrix_value_digest=matrix_value_digest,
        ),
    )
end

function native_resolved_fsi_timed_affine_solve(
    a,
    l,
    X,
    Y,
    phase_timing::AbstractDict{Symbol,Float64};
    context::NamedTuple = NamedTuple(),
    quadrature_sensitivity_operator_builder = nothing,
)
    operator_start_ns = time_ns()
    operator = AffineFEOperator(a, l, X, Y)
    affine_operator_elapsed_s =
        native_resolved_fsi_record_phase_elapsed!(:gridap_affine_operator_s, operator_start_ns, phase_timing)

    start_ns = time_ns()
    matrix = get_matrix(operator)
    matrix_extraction_elapsed_s =
        native_resolved_fsi_record_phase_elapsed!(:gridap_matrix_extraction_s, start_ns, phase_timing)

    start_ns = time_ns()
    rhs = get_vector(operator)
    rhs_extraction_elapsed_s =
        native_resolved_fsi_record_phase_elapsed!(:gridap_rhs_extraction_s, start_ns, phase_timing)
    native_resolved_fsi_add_phase_timing!(
        phase_timing,
        :gridap_operator_assembly_s,
        affine_operator_elapsed_s + matrix_extraction_elapsed_s + rhs_extraction_elapsed_s,
    )
    solver_diagnostics = native_resolved_fsi_solver_diagnostics(matrix, rhs; context=context)
    if quadrature_sensitivity_operator_builder !== nothing
        solver_diagnostics = merge(
            solver_diagnostics,
            native_resolved_fsi_quadrature_sensitivity_diagnostics(
                matrix,
                rhs,
                quadrature_sensitivity_operator_builder;
                primary_degree=Int(get(context, :quadrature_degree, 0)),
                sensitivity_degree=Int(get(context, :quadrature_sensitivity_degree, 0)),
            ),
        )
    end

    solver = LUSolver()

    symbolic, solver_diagnostics = native_resolved_fsi_symbolic_setup_with_cache!(
        solver,
        matrix,
        phase_timing,
        solver_diagnostics,
        get(context, :gridap_context, nothing),
    )

    numeric, solver_diagnostics = native_resolved_fsi_numeric_setup_with_cache!(
        symbolic,
        matrix,
        phase_timing,
        solver_diagnostics,
        get(context, :gridap_context, nothing),
    )

    solution_dofs = similar(rhs)
    start_ns = time_ns()
    solve!(solution_dofs, numeric, rhs)
    native_resolved_fsi_record_phase_elapsed!(:linear_backsolve_s, start_ns, phase_timing)

    solution = FEFunction(X, solution_dofs)
    velocity_h, pressure_h = solution
    return velocity_h, pressure_h, solver_diagnostics
end

function native_resolved_fsi_sample_velocity_at_node(
    mesh::NativeResolvedFSIMesh,
    node::Int,
    velocity_h;
    coordinates::AbstractMatrix{<:Real} = mesh.coordinates,
    wall_radius_at_z = z -> native_resolved_fsi_radius(mesh.case_spec, z),
)
    direct_point = Point(Float64(coordinates[node, 1]), Float64(coordinates[node, 2]), Float64(coordinates[node, 3]))
    direct_value = try
        velocity_h(direct_point)
    catch
        nothing
    end
    if direct_value !== nothing
        components = (direct_value[1], direct_value[2], direct_value[3])
        all(component -> component isa Real && isfinite(component), components) &&
            return components, false
    end

    fallback_point = native_resolved_fsi_smoke_interior_sample_point(
        mesh,
        node;
        coordinates=coordinates,
        wall_radius_at_z=wall_radius_at_z,
    )
    fallback_value = try
        velocity_h(fallback_point)
    catch
        nothing
    end
    if fallback_value !== nothing
        components = (fallback_value[1], fallback_value[2], fallback_value[3])
        all(component -> component isa Real && isfinite(component), components) &&
            return components, true
    end
    throw(ArgumentError("native resolved-FSI open-boundary velocity diagnostic sampling failed at mesh node $node"))
end

function native_resolved_fsi_open_boundary_diagnostics(
    mesh::NativeResolvedFSIMesh,
    velocity_h;
    coordinates::AbstractMatrix{<:Real} = mesh.coordinates,
    wall_radius_at_z = z -> native_resolved_fsi_radius(mesh.case_spec, z),
    inlet_outlet_boundary_mode::Symbol,
)
    outlet_nodes = mesh.tags.outlet_nodes
    isempty(outlet_nodes) &&
        throw(ArgumentError("native resolved-FSI open-boundary diagnostics require at least one outlet node"))
    normal_velocity_cm_s = Float64[]
    fallback_count = 0
    for node in outlet_nodes
        velocity_value, used_fallback = native_resolved_fsi_sample_velocity_at_node(
            mesh,
            node,
            velocity_h;
            coordinates=coordinates,
            wall_radius_at_z=wall_radius_at_z,
        )
        push!(normal_velocity_cm_s, Float64(velocity_value[3]))
        fallback_count += used_fallback ? 1 : 0
    end
    backflow_count = count(value -> value < -1.0e-10, normal_velocity_cm_s)
    normal_min = minimum(normal_velocity_cm_s)
    normal_max = maximum(normal_velocity_cm_s)
    normal_mean = sum(normal_velocity_cm_s) / length(normal_velocity_cm_s)
    boundary_status = if inlet_outlet_boundary_mode === :poiseuille_inlet_zero_outlet_stress_section41
        "zero_outlet_stress_natural_traction_open_boundary"
    else
        "pressure_drop_smoke_outlet_reference_not_section41_open_boundary_evidence"
    end
    backflow_status = backflow_count == 0 ? "no_mesh_node_backflow_detected" : "mesh_node_backflow_detected"
    return (
        gridap_open_boundary_status=
            "$(boundary_status); $(backflow_status); diagnostic_node_sample_only_no_outflow_stabilization_claim",
        gridap_outlet_node_count=length(outlet_nodes),
        gridap_outlet_velocity_sampling_fallback_count=fallback_count,
        gridap_outlet_backflow_node_count=backflow_count,
        gridap_outlet_normal_velocity_min_cm_s=normal_min,
        gridap_outlet_normal_velocity_max_cm_s=normal_max,
        gridap_outlet_normal_velocity_mean_cm_s=normal_mean,
    )
end

function native_resolved_fsi_first_picard_block_assembly_probe(
    mesh::NativeResolvedFSIMesh;
    coordinates::AbstractMatrix{<:Real} = mesh.coordinates,
    wall_radius_at_z = z -> native_resolved_fsi_radius(mesh.case_spec, z),
    inlet_outlet_boundary_mode::Union{Symbol,AbstractString} = :pressure_drop_weak_inlet_outlet_gauge_smoke,
    inlet_umax_cm_s::Real = NATIVE_RESOLVED_FSI_SECTION41_INLET_UMAX_CM_S,
    dt_s::Real,
    pressure_drop_dyn_cm2::Real,
    initial_velocity_dofs = nothing,
    advector_velocity_dof_perturbation_scale::Real = 0.0,
    previous_velocity_dof_perturbation_scale::Real = 0.0,
    wall_velocity_at = nothing,
    matrix_relative_tolerance::Real = 1.0e-12,
    matrix_absolute_tolerance::Real = 1.0e-8,
    rhs_relative_tolerance::Real = 1.0e-12,
    rhs_absolute_tolerance::Real = 1.0e-8,
)
    dt_value = Float64(dt_s)
    pressure_drop_value = Float64(pressure_drop_dyn_cm2)
    inlet_outlet_boundary_mode_value = native_resolved_fsi_inlet_outlet_boundary_mode(inlet_outlet_boundary_mode)
    inlet_umax_value = Float64(inlet_umax_cm_s)
    dt_value > 0.0 || throw(ArgumentError("native resolved-FSI block assembly probe dt_s must be positive"))
    isfinite(pressure_drop_value) ||
        throw(ArgumentError("native resolved-FSI block assembly probe pressure_drop_dyn_cm2 must be finite"))
    if inlet_outlet_boundary_mode_value === :pressure_drop_weak_inlet_outlet_gauge_smoke
        pressure_drop_value > 0.0 ||
            throw(ArgumentError("native resolved-FSI block assembly probe pressure_drop_dyn_cm2 must be positive"))
    end
    isfinite(inlet_umax_value) ||
        throw(ArgumentError("native resolved-FSI block assembly probe inlet_umax_cm_s must be finite"))
    if inlet_outlet_boundary_mode_value === :poiseuille_inlet_zero_outlet_stress_section41
        inlet_umax_value > 0.0 ||
            throw(ArgumentError("native resolved-FSI block assembly probe inlet_umax_cm_s must be positive"))
    end

    params = Params(severity=mesh.case_spec.severity_percent, tfinal=dt_value, initial_condition=GeometryRestIC())
    rho = params.rho
    mu = rho * params.nu
    rho > 0.0 || throw(ArgumentError("native resolved-FSI block assembly probe requires positive density"))
    mu > 0.0 || throw(ArgumentError("native resolved-FSI block assembly probe requires positive dynamic viscosity"))

    phase_timing = native_resolved_fsi_phase_timing_accumulator()
    setup_start_ns = time_ns()
    model, labels = native_resolved_fsi_gridap_model(mesh; coordinates=coordinates, wall_radius_at_z=wall_radius_at_z)
    native_resolved_fsi_record_phase_elapsed!(:gridap_model_setup_s, setup_start_ns, phase_timing)

    order = 2
    quadrature_degree = 2 * order
    setup_start_ns = time_ns()
    reffe_u = ReferenceFE(lagrangian, VectorValue{3,Float64}, order)
    reffe_p = ReferenceFE(lagrangian, Float64, order - 1)
    zero_velocity(x) = VectorValue(0.0, 0.0, 0.0)
    wall_velocity_function = if wall_velocity_at === nothing
        zero_velocity
    else
        native_resolved_fsi_radial_wall_velocity_function(mesh, wall_velocity_at)
    end
    inlet_velocity_function = if inlet_outlet_boundary_mode_value === :poiseuille_inlet_zero_outlet_stress_section41
        native_resolved_fsi_section41_poiseuille_inlet_velocity_function(
            mesh,
            wall_radius_at_z,
            inlet_umax_value,
        )
    else
        zero_velocity
    end
    initial_velocity_function = native_resolved_fsi_navier_stokes_initial_velocity_function(
        mesh,
        inlet_outlet_boundary_mode_value,
        wall_velocity_function,
        inlet_velocity_function,
    )
    V = if inlet_outlet_boundary_mode_value === :pressure_drop_weak_inlet_outlet_gauge_smoke
        TestFESpace(model, reffe_u, labels=labels, dirichlet_tags="wall", conformity=:H1)
    else
        TestFESpace(model, reffe_u, labels=labels, dirichlet_tags=["wall", "inlet"], conformity=:H1)
    end
    Q = native_resolved_fsi_pressure_test_space(model, reffe_p, labels, inlet_outlet_boundary_mode_value)
    U = if inlet_outlet_boundary_mode_value === :pressure_drop_weak_inlet_outlet_gauge_smoke
        TrialFESpace(V, wall_velocity_function)
    else
        TrialFESpace(V, [wall_velocity_function, inlet_velocity_function])
    end
    P = TrialFESpace(Q)
    X = MultiFieldFESpace([U, P])
    Y = MultiFieldFESpace([V, Q])
    native_resolved_fsi_record_phase_elapsed!(:gridap_space_setup_s, setup_start_ns, phase_timing)

    setup_start_ns = time_ns()
    Ω = Triangulation(model)
    Γin = BoundaryTriangulation(model, labels, tags="inlet")
    Γout = BoundaryTriangulation(model, labels, tags="outlet")
    n_in = get_normal_vector(Γin)
    n_out = get_normal_vector(Γout)
    native_resolved_fsi_record_phase_elapsed!(:gridap_measure_setup_s, setup_start_ns, phase_timing)

    velocity_state = native_resolved_fsi_navier_stokes_initial_velocity_state(U, initial_velocity_function, initial_velocity_dofs)
    velocity_advector_state = native_resolved_fsi_perturbed_velocity_state(
        U,
        velocity_state,
        advector_velocity_dof_perturbation_scale,
    )
    velocity_previous_state = native_resolved_fsi_perturbed_velocity_state(
        U,
        velocity_state,
        previous_velocity_dof_perturbation_scale,
    )
    weak_form_coefficients =
        native_resolved_fsi_navier_stokes_weak_form_coefficients(rho, mu, dt_value)
    weak_form_parts = native_resolved_fsi_navier_stokes_weak_form_parts(
        Ω,
        Γin,
        Γout,
        n_in,
        n_out,
        weak_form_coefficients;
        velocity_advector=velocity_advector_state,
        velocity_previous_step=velocity_previous_state,
        pressure_drop_value=pressure_drop_value,
        inlet_outlet_boundary_mode=inlet_outlet_boundary_mode_value,
        quadrature_degree=quadrature_degree,
    )
    probe = native_resolved_fsi_block_assembly_probe(
        weak_form_parts,
        X,
        Y;
        matrix_relative_tolerance=matrix_relative_tolerance,
        matrix_absolute_tolerance=matrix_absolute_tolerance,
        rhs_relative_tolerance=rhs_relative_tolerance,
        rhs_absolute_tolerance=rhs_absolute_tolerance,
    )
    pressure_policy = native_resolved_fsi_pressure_space_policy(inlet_outlet_boundary_mode_value)
    return merge(
        probe,
        (
            boundary_mode=string(inlet_outlet_boundary_mode_value),
            pressure_constraint=pressure_policy.gridap_constraint === nothing ?
                                "none" :
                                string(pressure_policy.gridap_constraint),
            pressure_reference=string(pressure_policy.pressure_reference),
            quadrature_degree=quadrature_degree,
            dt_s=dt_value,
            advector_velocity_dof_perturbation_scale=Float64(advector_velocity_dof_perturbation_scale),
            previous_velocity_dof_perturbation_scale=Float64(previous_velocity_dof_perturbation_scale),
            base_velocity_dof_digest=native_resolved_fsi_velocity_dof_digest(velocity_state),
            advector_velocity_dof_digest=native_resolved_fsi_velocity_dof_digest(velocity_advector_state),
            previous_velocity_dof_digest=native_resolved_fsi_velocity_dof_digest(velocity_previous_state),
            coordinate_value_digest=native_resolved_fsi_coordinate_value_digest(coordinates),
            gridap_model_setup_s=phase_timing[:gridap_model_setup_s],
            gridap_space_setup_s=phase_timing[:gridap_space_setup_s],
            gridap_measure_setup_s=phase_timing[:gridap_measure_setup_s],
        ),
    )
end

function native_resolved_fsi_solve_navier_stokes(
    mesh::NativeResolvedFSIMesh;
    coordinates::AbstractMatrix{<:Real} = mesh.coordinates,
    wall_radius_at_z = z -> native_resolved_fsi_radius(mesh.case_spec, z),
    inlet_outlet_boundary_mode::Union{Symbol,AbstractString} = :pressure_drop_weak_inlet_outlet_gauge_smoke,
    inlet_umax_cm_s::Real = NATIVE_RESOLVED_FSI_SECTION41_INLET_UMAX_CM_S,
    dt_s::Real,
    tfinal_s::Real,
    pressure_drop_dyn_cm2::Real,
    picard_iteration_count::Integer,
    picard_tolerance::Real,
    initial_velocity_dofs = nothing,
    wall_velocity_at = nothing,
    gridap_context = nothing,
)
    dt_value = Float64(dt_s)
    tfinal_value = Float64(tfinal_s)
    pressure_drop_value = Float64(pressure_drop_dyn_cm2)
    picard_iteration_count_value = Int(picard_iteration_count)
    picard_tolerance_value = Float64(picard_tolerance)
    inlet_outlet_boundary_mode_value = native_resolved_fsi_inlet_outlet_boundary_mode(inlet_outlet_boundary_mode)
    inlet_umax_value = Float64(inlet_umax_cm_s)
    dt_value > 0.0 || throw(ArgumentError("native resolved-FSI Navier-Stokes dt_s must be positive"))
    tfinal_value > 0.0 || throw(ArgumentError("native resolved-FSI Navier-Stokes tfinal_s must be positive"))
    isfinite(pressure_drop_value) || throw(ArgumentError("native resolved-FSI Navier-Stokes pressure_drop_dyn_cm2 must be finite"))
    if inlet_outlet_boundary_mode_value === :pressure_drop_weak_inlet_outlet_gauge_smoke
        pressure_drop_value > 0.0 ||
            throw(ArgumentError("native resolved-FSI Navier-Stokes pressure_drop_dyn_cm2 must be positive"))
    end
    isfinite(inlet_umax_value) || throw(ArgumentError("native resolved-FSI Navier-Stokes inlet_umax_cm_s must be finite"))
    if inlet_outlet_boundary_mode_value === :poiseuille_inlet_zero_outlet_stress_section41
        inlet_umax_value > 0.0 ||
            throw(ArgumentError("native resolved-FSI Section 4.1 inlet_umax_cm_s must be positive"))
    end
    picard_iteration_count_value > 0 || throw(ArgumentError("native resolved-FSI Navier-Stokes picard_iteration_count must be positive"))
    isfinite(picard_tolerance_value) || throw(ArgumentError("native resolved-FSI Navier-Stokes picard_tolerance must be finite"))
    picard_tolerance_value > 0.0 || throw(ArgumentError("native resolved-FSI Navier-Stokes picard_tolerance must be positive"))

    params = Params(severity=mesh.case_spec.severity_percent, tfinal=tfinal_value, initial_condition=GeometryRestIC())
    rho = params.rho
    mu = rho * params.nu
    rho > 0.0 || throw(ArgumentError("native resolved-FSI Navier-Stokes smoke requires positive density"))
    mu > 0.0 || throw(ArgumentError("native resolved-FSI Navier-Stokes smoke requires positive dynamic viscosity rho*nu"))

    order = 2
    quadrature_degree = 2 * order
    quadrature_sensitivity_degree = quadrature_degree + 2
    gridap_context_value = native_resolved_fsi_gridap_context_for(
        mesh,
        gridap_context;
        inlet_outlet_boundary_mode=inlet_outlet_boundary_mode_value,
        quadrature_degree=quadrature_degree,
    )
    coordinate_value_digest = native_resolved_fsi_coordinate_value_digest(coordinates)

    phase_timing = native_resolved_fsi_phase_timing_accumulator()
    setup_start_ns = time_ns()
    model, labels = native_resolved_fsi_gridap_model(mesh; coordinates=coordinates, wall_radius_at_z=wall_radius_at_z)
    native_resolved_fsi_record_phase_elapsed!(:gridap_model_setup_s, setup_start_ns, phase_timing)
    setup_start_ns = time_ns()
    reffe_u = ReferenceFE(lagrangian, VectorValue{3,Float64}, order)
    reffe_p = ReferenceFE(lagrangian, Float64, order - 1)
    zero_velocity(x) = VectorValue(0.0, 0.0, 0.0)
    wall_velocity_function = if wall_velocity_at === nothing
        zero_velocity
    else
        native_resolved_fsi_radial_wall_velocity_function(mesh, wall_velocity_at)
    end
    inlet_velocity_function = if inlet_outlet_boundary_mode_value === :poiseuille_inlet_zero_outlet_stress_section41
        native_resolved_fsi_section41_poiseuille_inlet_velocity_function(
            mesh,
            wall_radius_at_z,
            inlet_umax_value,
        )
    else
        zero_velocity
    end
    zero_pressure(x) = 0.0
    initial_velocity_function = native_resolved_fsi_navier_stokes_initial_velocity_function(
        mesh,
        inlet_outlet_boundary_mode_value,
        wall_velocity_function,
        inlet_velocity_function,
    )
    V = if inlet_outlet_boundary_mode_value === :pressure_drop_weak_inlet_outlet_gauge_smoke
        TestFESpace(model, reffe_u, labels=labels, dirichlet_tags="wall", conformity=:H1)
    else
        TestFESpace(model, reffe_u, labels=labels, dirichlet_tags=["wall", "inlet"], conformity=:H1)
    end
    Q = native_resolved_fsi_pressure_test_space(model, reffe_p, labels, inlet_outlet_boundary_mode_value)
    U = if inlet_outlet_boundary_mode_value === :pressure_drop_weak_inlet_outlet_gauge_smoke
        TrialFESpace(V, wall_velocity_function)
    else
        TrialFESpace(V, [wall_velocity_function, inlet_velocity_function])
    end
    P = TrialFESpace(Q)
    X = MultiFieldFESpace([U, P])
    Y = MultiFieldFESpace([V, Q])
    native_resolved_fsi_record_phase_elapsed!(:gridap_space_setup_s, setup_start_ns, phase_timing)

    setup_start_ns = time_ns()
    Ω = Triangulation(model)
    Γin = BoundaryTriangulation(model, labels, tags="inlet")
    Γout = BoundaryTriangulation(model, labels, tags="outlet")
    n_in = get_normal_vector(Γin)
    n_out = get_normal_vector(Γout)
    native_resolved_fsi_record_phase_elapsed!(:gridap_measure_setup_s, setup_start_ns, phase_timing)

    velocity_state = native_resolved_fsi_navier_stokes_initial_velocity_state(U, initial_velocity_function, initial_velocity_dofs)
    pressure_state = interpolate_everywhere(zero_pressure, P)
    time_s = 0.0
    time_step_count = 0
    max_picard_iterations_used = 0
    final_picard_update_norm = 0.0
    picard_converged = true
    fluid_solve_start_ns = time_ns()
    solver_diagnostics = native_resolved_fsi_empty_solver_diagnostics()
    linear_solve_count = 0

    while time_s < tfinal_value
        dt_step = min(dt_value, tfinal_value - time_s)
        dt_step > 0.0 || break

        velocity_previous_step = velocity_state
        velocity_iterate = velocity_state
        step_converged = false
        step_iterations_used = 0
        step_update_norm = Inf

        for iteration in 1:picard_iteration_count_value
            velocity_advector = velocity_iterate
            weak_form_coefficients =
                native_resolved_fsi_navier_stokes_weak_form_coefficients(rho, mu, dt_step)
            function weak_forms_for_quadrature_degree(degree_value::Int)
                parts = native_resolved_fsi_navier_stokes_weak_form_parts(
                    Ω,
                    Γin,
                    Γout,
                    n_in,
                    n_out,
                    weak_form_coefficients;
                    velocity_advector=velocity_advector,
                    velocity_previous_step=velocity_previous_step,
                    pressure_drop_value=pressure_drop_value,
                    inlet_outlet_boundary_mode=inlet_outlet_boundary_mode_value,
                    quadrature_degree=degree_value,
                )
                return parts.a, parts.l, parts
            end
            a, l, weak_form_parts = weak_forms_for_quadrature_degree(quadrature_degree)
            quadrature_sensitivity_operator_builder = () -> begin
                a_sensitivity, l_sensitivity, _ = weak_forms_for_quadrature_degree(quadrature_sensitivity_degree)
                return AffineFEOperator(a_sensitivity, l_sensitivity, X, Y)
            end

            linear_solve_count += 1
            pressure_policy = native_resolved_fsi_pressure_space_policy(inlet_outlet_boundary_mode_value)
            wall_boundary_mode = wall_velocity_at === nothing ? :stationary_wall : :prescribed_radial_wall_velocity
            velocity_next, pressure_next, solver_diagnostics = native_resolved_fsi_timed_affine_solve(
                a,
                l,
                X,
                Y,
                phase_timing;
                context=(
                    boundary_mode=string(inlet_outlet_boundary_mode_value),
                    operator_component_status="matrix_rhs_component_terms_available_monolithic_full_affine_operator_assembly",
                    operator_component_terms=weak_form_parts.component_terms,
                    pressure_constraint=pressure_policy.gridap_constraint === nothing ?
                                        "none" :
                                        string(pressure_policy.gridap_constraint),
                    pressure_reference=string(pressure_policy.pressure_reference),
                    wall_boundary_mode=string(wall_boundary_mode),
                    quadrature_degree=quadrature_degree,
                    quadrature_sensitivity_degree=quadrature_sensitivity_degree,
                    coordinate_value_digest=coordinate_value_digest,
                    gridap_context=gridap_context_value,
                    dt_s=dt_step,
                    time_step_index=time_step_count + 1,
                    picard_iteration=iteration,
                    linear_solve_count=linear_solve_count,
                    gridap_rebuild_count=linear_solve_count,
                ),
                quadrature_sensitivity_operator_builder=quadrature_sensitivity_operator_builder,
            )
            solver_diagnostics = merge(
                solver_diagnostics,
                native_resolved_fsi_open_boundary_diagnostics(
                    mesh,
                    velocity_next;
                    coordinates=coordinates,
                    wall_radius_at_z=wall_radius_at_z,
                    inlet_outlet_boundary_mode=inlet_outlet_boundary_mode_value,
                ),
            )
            step_update_norm = native_resolved_fsi_smoke_velocity_update_norm(velocity_next, velocity_iterate)
            velocity_scale = max(native_resolved_fsi_smoke_velocity_dof_norm(velocity_next), 1.0)
            velocity_state = velocity_next
            pressure_state = pressure_next
            velocity_iterate = velocity_next
            step_iterations_used = iteration

            if step_update_norm <= picard_tolerance_value * velocity_scale
                step_converged = true
                break
            end
        end

        max_picard_iterations_used = max(max_picard_iterations_used, step_iterations_used)
        final_picard_update_norm = step_update_norm
        picard_converged = picard_converged && step_converged
        time_s += dt_step
        time_step_count += 1
    end
    native_resolved_fsi_record_phase_elapsed!(:fluid_solve_total_s, fluid_solve_start_ns, phase_timing)

    time_step_count > 0 ||
        throw(ArgumentError("native resolved-FSI Navier-Stokes smoke produced zero time steps despite positive tfinal_s"))
    isfinite(final_picard_update_norm) ||
        throw(ArgumentError("native resolved-FSI Navier-Stokes smoke Picard update norm must be finite"))

    return NativeResolvedFSINavierStokesSmokeSolve(
        velocity_state,
        pressure_state,
        length(get_free_dof_values(velocity_state)),
        length(get_free_dof_values(pressure_state)),
        time_step_count,
        max_picard_iterations_used,
        final_picard_update_norm,
        picard_converged,
        inlet_outlet_boundary_mode_value,
        inlet_outlet_boundary_mode_value === :poiseuille_inlet_zero_outlet_stress_section41 ? inlet_umax_value : 0.0,
        native_resolved_fsi_inlet_outlet_boundary_status(
            inlet_outlet_boundary_mode_value;
            inlet_umax_cm_s=inlet_umax_value,
        ),
        solver_diagnostics,
        native_resolved_fsi_phase_timing_named_tuple(phase_timing),
    )
end

function native_resolved_fsi_navier_stokes_initial_velocity_function(
    mesh::NativeResolvedFSIMesh,
    inlet_outlet_boundary_mode::Symbol,
    wall_velocity_function,
    inlet_velocity_function,
)
    inlet_outlet_boundary_mode === :poiseuille_inlet_zero_outlet_stress_section41 || return wall_velocity_function
    ztol = max(mesh.case_spec.length_cm, 1.0) * 1.0e-10
    return x -> abs(Float64(x[3])) <= ztol ? inlet_velocity_function(x) : wall_velocity_function(x)
end

function native_resolved_fsi_navier_stokes_initial_velocity_state(U, wall_velocity_function, initial_velocity_dofs)
    if initial_velocity_dofs === nothing
        return interpolate_everywhere(wall_velocity_function, U)
    end
    values = Float64[Float64(value) for value in initial_velocity_dofs]
    return FEFunction(U, values)
end

function native_resolved_fsi_smoke_velocity_dof_norm(velocity_h)
    return sqrt(sum(abs2, get_free_dof_values(velocity_h)))
end

function native_resolved_fsi_smoke_velocity_update_norm(velocity_next, velocity_previous)
    return sqrt(sum(abs2, get_free_dof_values(velocity_next) .- get_free_dof_values(velocity_previous)))
end
