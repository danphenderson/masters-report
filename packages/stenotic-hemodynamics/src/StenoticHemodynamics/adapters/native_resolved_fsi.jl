using Gridap
using Gridap.Arrays
using Gridap.Geometry
using Gridap.ReferenceFEs
using Gridap.TensorValues

import Gridap: ∇
import Gridap.Geometry: face_labeling_from_vertex_filter, get_grid_topology

const NATIVE_RESOLVED_FSI_SMOKE_DEFAULT_OUTPUT_ROOT =
    joinpath(DEFAULT_SIMULATION_OUTPUT_ROOT, "native-resolved-fsi-smoke")
const NATIVE_RESOLVED_FSI_SMOKE_DEFAULT_TIME_S = NATIVE_RESOLVED_FSI_DEFAULT_TIME_S
const NATIVE_RESOLVED_FSI_SMOKE_MAX_OUTPUT_BYTES = 1_073_741_824
const NATIVE_RESOLVED_FSI_SMOKE_STAGE = :fixed_wall_stokes

"""
    NativeResolvedFSISmokeSpec(; kwargs...)

Typed configuration for the first native resolved-FSI smoke solve. This stage is
intentionally a fixed-wall stationary-Stokes solve on `NativeResolvedFSIMesh`,
not a full transient moving-wall FSI implementation.
"""
struct NativeResolvedFSISmokeSpec
    case_spec::NativeResolvedFSICaseSpec
    resolution::NativeResolvedFSIMeshResolution
    output_dir::String
    saved_time_s::Float64
    time_atol::Float64
    overwrite::Bool
    pressure_drop_dyn_cm2::Float64
end

function NativeResolvedFSISmokeSpec(;
    case_id::Union{Symbol,AbstractString,Real} = :sev23,
    resolution::NativeResolvedFSIMeshResolution = NativeResolvedFSIMeshResolution(axial=2, radial=1, angular=6),
    output_dir::AbstractString = "",
    saved_time_s::Real = NATIVE_RESOLVED_FSI_SMOKE_DEFAULT_TIME_S,
    time_atol::Real = 1.0e-12,
    overwrite::Bool = false,
    pressure_drop_dyn_cm2::Real = 40.0,
)
    return validate(NativeResolvedFSISmokeSpec(
        native_resolved_fsi_case_spec(case_id),
        resolution,
        String(output_dir),
        Float64(saved_time_s),
        Float64(time_atol),
        overwrite,
        Float64(pressure_drop_dyn_cm2),
    ))
end

native_resolved_fsi_smoke_spec(; kwargs...) = NativeResolvedFSISmokeSpec(; kwargs...)

"""
    NativeResolvedFSISmokeResult

Bundle returned by [`run_native_resolved_fsi_smoke`](@ref). It records the
solver-backed field round trip together with schema, geometry, time, and field
status for the staged fixed-wall smoke target.
"""
struct NativeResolvedFSISmokeResult
    spec::NativeResolvedFSISmokeSpec
    mesh::NativeResolvedFSIMesh
    output_dir::String
    mesh_h5::String
    velocity_xdmf::String
    velocity_h5::String
    pressure_xdmf::String
    pressure_h5::String
    displacement_xdmf::String
    displacement_h5::String
    saved_time_s::Float64
    fluid_model::Symbol
    velocity_dofs::Int
    pressure_dofs::Int
    sampling_fallback_count::Int
    pressure_gauge_offset_dyn_cm2::Float64
    estimated_field_payload_bytes::Int
    loaded_coordinates::Matrix{Float64}
    loaded_topology::Matrix{Int}
    loaded_velocity::Matrix{Float64}
    loaded_pressure::Vector{Float64}
    loaded_displacement::Matrix{Float64}
    loaded_deformed_coordinates::Matrix{Float64}
    schema_status::NativeResolvedFSIWorkflowStatus
    geometry_status::NativeResolvedFSIWorkflowStatus
    time_status::NativeResolvedFSIWorkflowStatus
    field_status::NativeResolvedFSIWorkflowStatus
end

struct NativeResolvedFSIStokesSmokeSolve
    velocity
    pressure
    velocity_dofs::Int
    pressure_dofs::Int
end

function validate(spec::NativeResolvedFSISmokeSpec)
    spec.saved_time_s > 0.0 || throw(ArgumentError("native resolved-FSI smoke saved_time_s must be positive"))
    spec.time_atol > 0.0 || throw(ArgumentError("native resolved-FSI smoke time_atol must be positive"))
    isfinite(spec.pressure_drop_dyn_cm2) ||
        throw(ArgumentError("native resolved-FSI smoke pressure_drop_dyn_cm2 must be finite"))
    spec.pressure_drop_dyn_cm2 > 0.0 ||
        throw(ArgumentError("native resolved-FSI smoke pressure_drop_dyn_cm2 must be positive"))
    return spec
end

"""
    default_native_resolved_fsi_smoke_output_dir(spec) -> String

Return the default ignored scratch directory for the staged fixed-wall Stokes
smoke bundle.
"""
function default_native_resolved_fsi_smoke_output_dir(spec::NativeResolvedFSISmokeSpec)
    resolution = spec.resolution
    mesh_token = "$(resolution.axial)x$(resolution.radial)x$(resolution.angular)"
    return joinpath(
        NATIVE_RESOLVED_FSI_SMOKE_DEFAULT_OUTPUT_ROOT,
        string(spec.case_spec.case_id),
        mesh_token,
        "fixed-wall-stokes-t$(path_token(spec.saved_time_s))",
    )
end

"""
    run_native_resolved_fsi_smoke(spec=NativeResolvedFSISmokeSpec())

Run the first native fixed-wall smoke solve on a coarse `NativeResolvedFSIMesh`,
write velocity, pressure, and explicit zero displacement through the resolved-3D
bundle writer, reload the bundle through the importer, and return staged status
for schema, geometry, time, and field checks.
"""
function run_native_resolved_fsi_smoke(spec::NativeResolvedFSISmokeSpec = NativeResolvedFSISmokeSpec())
    validate(spec)

    mesh = native_resolved_fsi_mesh(spec.case_spec, spec.resolution)
    native_resolved_fsi_smoke_validate_mesh(mesh)
    estimated_field_payload_bytes = native_resolved_fsi_smoke_estimated_field_payload_bytes(mesh)
    estimated_field_payload_bytes <= NATIVE_RESOLVED_FSI_SMOKE_MAX_OUTPUT_BYTES || throw(ArgumentError(
        "native resolved-FSI smoke estimated raw field payload $(estimated_field_payload_bytes) bytes exceeds the $(NATIVE_RESOLVED_FSI_SMOKE_MAX_OUTPUT_BYTES)-byte cap",
    ))

    solve_result = native_resolved_fsi_solve_fixed_wall_stokes(mesh, spec)
    velocity, pressure, sampling_fallback_count = native_resolved_fsi_sample_smoke_fields(
        mesh,
        solve_result.velocity,
        solve_result.pressure,
    )
    pressure, pressure_gauge_offset_dyn_cm2 = native_resolved_fsi_outlet_gauge_pressure(pressure, mesh.tags.outlet_nodes)
    displacement = native_resolved_fsi_zero_displacement(mesh)

    output_dir = isempty(spec.output_dir) ? default_native_resolved_fsi_smoke_output_dir(spec) : spec.output_dir
    writer_result = write_resolved3d_field_bundle(
        output_dir,
        mesh.coordinates,
        mesh.topology,
        velocity,
        pressure,
        displacement;
        time=spec.saved_time_s,
        overwrite=spec.overwrite,
    )

    case_spec = Resolved3DCaseSpec(
        native_resolved_fsi_smoke_case_label(spec),
        spec.case_spec.severity_percent,
        writer_result.paths.velocity_xdmf;
        pressure_xdmf=writer_result.paths.pressure_xdmf,
        displacement_xdmf=writer_result.paths.displacement_xdmf,
        target_time=spec.saved_time_s,
        time_atol=spec.time_atol,
    )
    bundle = load_resolved3d_field_bundle(case_spec; require_pressure=true, require_displacement=true)
    deformed_field = resolved3d_velocity_field_from_bundle(bundle, "deformed")

    loaded_coordinates = Matrix{Float64}(bundle.velocity.coordinates)
    loaded_topology = Matrix{Int}(bundle.velocity.topology)
    loaded_velocity = Matrix{Float64}(bundle.velocity.velocity)
    loaded_pressure = Vector{Float64}(bundle.pressure)
    loaded_displacement = Matrix{Float64}(bundle.displacement)
    loaded_deformed_coordinates = Matrix{Float64}(deformed_field.coordinates)

    return NativeResolvedFSISmokeResult(
        spec,
        mesh,
        output_dir,
        writer_result.paths.mesh_h5,
        writer_result.paths.velocity_xdmf,
        writer_result.paths.velocity_h5,
        writer_result.paths.pressure_xdmf,
        writer_result.paths.pressure_h5,
        writer_result.paths.displacement_xdmf,
        writer_result.paths.displacement_h5,
        writer_result.time,
        NATIVE_RESOLVED_FSI_SMOKE_STAGE,
        solve_result.velocity_dofs,
        solve_result.pressure_dofs,
        sampling_fallback_count,
        pressure_gauge_offset_dyn_cm2,
        estimated_field_payload_bytes,
        loaded_coordinates,
        loaded_topology,
        loaded_velocity,
        loaded_pressure,
        loaded_displacement,
        loaded_deformed_coordinates,
        native_resolved_fsi_smoke_schema_status(bundle, writer_result, loaded_deformed_coordinates),
        native_resolved_fsi_smoke_geometry_status(mesh, loaded_coordinates, loaded_topology),
        native_resolved_fsi_smoke_time_status(spec, bundle, writer_result),
        native_resolved_fsi_smoke_field_status(
            mesh,
            loaded_velocity,
            loaded_pressure,
            loaded_displacement,
            loaded_deformed_coordinates,
            sampling_fallback_count,
        ),
    )
end

run_native_resolved_fsi(spec::NativeResolvedFSISmokeSpec) = run_native_resolved_fsi_smoke(spec)

function native_resolved_fsi_smoke_validate_mesh(mesh::NativeResolvedFSIMesh)
    size(mesh.coordinates, 1) > 0 || throw(ArgumentError("native resolved-FSI smoke mesh must contain at least one node"))
    size(mesh.topology, 1) > 0 || throw(ArgumentError("native resolved-FSI smoke mesh must contain at least one tetrahedron"))
    minimum(mesh.geometry.reference_radii_cm) > 0.0 ||
        throw(ArgumentError("native resolved-FSI smoke mesh contains a non-positive reference radius"))
    return mesh
end

function native_resolved_fsi_smoke_estimated_field_payload_bytes(mesh::NativeResolvedFSIMesh)
    return size(mesh.coordinates, 1) * 7 * sizeof(Float64)
end

function native_resolved_fsi_smoke_case_label(spec::NativeResolvedFSISmokeSpec)
    resolution = spec.resolution
    mesh_token = "$(resolution.axial)x$(resolution.radial)x$(resolution.angular)"
    return "native-$(spec.case_spec.case_id)-$(mesh_token)-fixed-wall-stokes-smoke"
end

function native_resolved_fsi_gridap_model(mesh::NativeResolvedFSIMesh)
    points = [Point(mesh.coordinates[row, 1], mesh.coordinates[row, 2], mesh.coordinates[row, 3]) for row in axes(mesh.coordinates, 1)]
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
            radius = native_resolved_fsi_radius(mesh.case_spec, z)
            abs(hypot(Float64(x[1]), Float64(x[2])) - radius) <= rtol
        end),
    )
    return model, labels
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

    a((u, pfield), (v, q)) = ∫(mu * (∇(v) ⊙ ∇(u)) - (∇ ⋅ v) * pfield + q * (∇ ⋅ u)) * dΩ
    l((v, q)) = ∫(-spec.pressure_drop_dyn_cm2 * (v ⋅ n_in)) * dΓin + ∫(-0.0 * (v ⋅ n_out)) * dΓout

    velocity_h, pressure_h = solve(AffineFEOperator(a, l, X, Y))
    return NativeResolvedFSIStokesSmokeSolve(
        velocity_h,
        pressure_h,
        length(get_free_dof_values(velocity_h)),
        length(get_free_dof_values(pressure_h)),
    )
end

function native_resolved_fsi_sample_smoke_fields(mesh::NativeResolvedFSIMesh, velocity_h, pressure_h)
    node_count = size(mesh.coordinates, 1)
    velocity = zeros(Float64, node_count, 3)
    pressure = zeros(Float64, node_count)
    sampling_fallback_count = 0
    for node in axes(mesh.coordinates, 1)
        sample_velocity, sample_pressure, used_fallback =
            native_resolved_fsi_sample_smoke_state_at_node(mesh, node, velocity_h, pressure_h)
        velocity[node, 1] = sample_velocity[1]
        velocity[node, 2] = sample_velocity[2]
        velocity[node, 3] = sample_velocity[3]
        pressure[node] = sample_pressure
        sampling_fallback_count += used_fallback ? 1 : 0
    end
    return velocity, pressure, sampling_fallback_count
end

function native_resolved_fsi_sample_smoke_state_at_node(mesh::NativeResolvedFSIMesh, node::Int, velocity_h, pressure_h)
    direct_point = Point(mesh.coordinates[node, 1], mesh.coordinates[node, 2], mesh.coordinates[node, 3])
    direct = native_resolved_fsi_try_sample_smoke_state(velocity_h, pressure_h, direct_point)
    direct !== nothing && return direct[1], direct[2], false

    fallback_point = native_resolved_fsi_smoke_interior_sample_point(mesh, node)
    fallback = native_resolved_fsi_try_sample_smoke_state(velocity_h, pressure_h, fallback_point)
    fallback !== nothing && return fallback[1], fallback[2], true

    throw(ArgumentError("native resolved-FSI smoke field sampling failed at mesh node $node"))
end

function native_resolved_fsi_try_sample_smoke_state(velocity_h, pressure_h, point::Point)
    velocity_value, pressure_value = try
        velocity_h(point), pressure_h(point)
    catch
        return nothing
    end
    velocity_components = (
        Float64(velocity_value[1]),
        Float64(velocity_value[2]),
        Float64(velocity_value[3]),
    )
    pressure_scalar = Float64(pressure_value)
    all(isfinite, velocity_components) && isfinite(pressure_scalar) || return nothing
    return velocity_components, pressure_scalar
end

function native_resolved_fsi_smoke_interior_sample_point(mesh::NativeResolvedFSIMesh, node::Int)
    x = mesh.coordinates[node, 1]
    y = mesh.coordinates[node, 2]
    z = mesh.coordinates[node, 3]
    radial_distance = hypot(x, y)
    reference_radius = native_resolved_fsi_radius(mesh.case_spec, z)
    axial_eps = native_resolved_fsi_smoke_axial_epsilon(mesh)

    sample_z = if isapprox(z, 0.0; atol=axial_eps)
        min(mesh.case_spec.length_cm, z + axial_eps)
    elseif isapprox(z, mesh.case_spec.length_cm; atol=axial_eps)
        max(0.0, z - axial_eps)
    else
        z
    end

    if radial_distance == 0.0
        return Point(0.0, 0.0, sample_z)
    end

    sample_radius = min(radial_distance, reference_radius) * (1.0 - 1.0e-8)
    sample_radius >= 0.0 || throw(ArgumentError("native resolved-FSI smoke fallback radius became negative at node $node"))
    scale = sample_radius / radial_distance
    return Point(scale * x, scale * y, sample_z)
end

function native_resolved_fsi_smoke_axial_epsilon(mesh::NativeResolvedFSIMesh)
    axial_coordinates = mesh.geometry.axial_coordinates_cm
    if length(axial_coordinates) <= 1
        return max(mesh.case_spec.length_cm * 1.0e-6, 1.0e-8)
    end
    axial_spacing = minimum(diff(axial_coordinates))
    return min(0.25 * axial_spacing, max(mesh.case_spec.length_cm * 1.0e-6, 1.0e-8))
end

function native_resolved_fsi_outlet_gauge_pressure(pressure::Vector{Float64}, outlet_nodes::Vector{Int})
    isempty(outlet_nodes) && throw(ArgumentError("native resolved-FSI smoke outlet node set must not be empty"))
    gauge_offset = sum(pressure[node] for node in outlet_nodes) / length(outlet_nodes)
    isfinite(gauge_offset) || throw(ArgumentError("native resolved-FSI smoke outlet gauge offset must be finite"))
    return pressure .- gauge_offset, gauge_offset
end

function native_resolved_fsi_smoke_schema_status(bundle, writer_result, deformed_coordinates::Matrix{Float64})
    required_files_exist = all(
        isfile,
        (
            writer_result.paths.mesh_h5,
            writer_result.paths.velocity_xdmf,
            writer_result.paths.velocity_h5,
            writer_result.paths.pressure_xdmf,
            writer_result.paths.pressure_h5,
            writer_result.paths.displacement_xdmf,
            writer_result.paths.displacement_h5,
        ),
    )
    ready = required_files_exist &&
            bundle.pressure !== nothing &&
            bundle.displacement !== nothing &&
            bundle.deformed_coordinates !== nothing &&
            size(deformed_coordinates, 2) == 3
    status = ready ?
        "fixed-wall smoke writer/importer round trip succeeded with required pressure, displacement, and deformed coordinates" :
        "fixed-wall smoke writer/importer round trip is incomplete"
    return NativeResolvedFSIWorkflowStatus(ready, status)
end

function native_resolved_fsi_smoke_geometry_status(
    mesh::NativeResolvedFSIMesh,
    loaded_coordinates::Matrix{Float64},
    loaded_topology::Matrix{Int},
)
    tag_counts = native_resolved_fsi_tag_counts(mesh)
    ready = loaded_coordinates == mesh.coordinates &&
            loaded_topology == mesh.topology &&
            tag_counts.inlet > 0 &&
            tag_counts.outlet > 0 &&
            tag_counts.wall > 0
    status = ready ?
        "reference native mesh geometry/topology reloaded exactly with $(size(mesh.coordinates, 1)) nodes and $(size(mesh.topology, 1)) tetrahedra" :
        "reloaded smoke geometry/topology does not match NativeResolvedFSIMesh"
    return NativeResolvedFSIWorkflowStatus(ready, status)
end

function native_resolved_fsi_smoke_time_status(spec::NativeResolvedFSISmokeSpec, bundle, writer_result)
    pressure_metadata = bundle.pressure_metadata
    displacement_metadata = bundle.displacement_metadata
    ready = abs(writer_result.time - spec.saved_time_s) <= spec.time_atol &&
            abs(bundle.velocity.metadata.time - spec.saved_time_s) <= spec.time_atol &&
            pressure_metadata !== nothing &&
            abs(pressure_metadata.time - spec.saved_time_s) <= spec.time_atol &&
            displacement_metadata !== nothing &&
            abs(displacement_metadata.time - spec.saved_time_s) <= spec.time_atol
    status = ready ?
        "staged fixed-wall smoke bundle saved and reloaded at $(spec.saved_time_s) s" :
        "fixed-wall smoke time metadata does not match the requested saved time"
    return NativeResolvedFSIWorkflowStatus(ready, status)
end

function native_resolved_fsi_smoke_field_status(
    mesh::NativeResolvedFSIMesh,
    velocity::Matrix{Float64},
    pressure::Vector{Float64},
    displacement::Matrix{Float64},
    deformed_coordinates::Matrix{Float64},
    sampling_fallback_count::Int,
)
    finite_fields = all(isfinite, velocity) && all(isfinite, pressure) && all(isfinite, displacement)
    nontrivial_velocity = maximum(abs, velocity) > 0.0
    nontrivial_pressure = maximum(pressure) > minimum(pressure)
    outlet_pressure_mean = sum(pressure[node] for node in mesh.tags.outlet_nodes) / length(mesh.tags.outlet_nodes)
    outlet_gauge_ok = abs(outlet_pressure_mean) <= 1.0e-9
    zero_displacement_ok = all(iszero, displacement)
    deformed_ok = deformed_coordinates == mesh.coordinates .+ displacement
    ready = finite_fields &&
            nontrivial_velocity &&
            nontrivial_pressure &&
            outlet_gauge_ok &&
            zero_displacement_ok &&
            deformed_ok
    status = ready ?
        "staged stationary Stokes smoke produced finite solver-backed velocity/pressure, outlet-gauge pressure, and explicit zero displacement (vertex fallbacks: $(sampling_fallback_count))" :
        "fixed-wall Stokes smoke field checks failed"
    return NativeResolvedFSIWorkflowStatus(ready, status)
end
