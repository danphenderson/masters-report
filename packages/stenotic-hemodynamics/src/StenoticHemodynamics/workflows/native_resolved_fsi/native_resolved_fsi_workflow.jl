const NATIVE_RESOLVED_FSI_DEFAULT_OUTPUT_ROOT = joinpath(DEFAULT_SIMULATION_OUTPUT_ROOT, "native-resolved-fsi")
const NATIVE_RESOLVED_FSI_DEFAULT_TIME_S = 1.0
const NATIVE_RESOLVED_FSI_DEFAULT_MESH_H5 = "mesh.h5"
const NATIVE_RESOLVED_FSI_DEFAULT_VELOCITY_XDMF = "velocity.xdmf"
const NATIVE_RESOLVED_FSI_DEFAULT_VELOCITY_H5 = "velocity.h5"
const NATIVE_RESOLVED_FSI_DEFAULT_PRESSURE_XDMF = "pressure.xdmf"
const NATIVE_RESOLVED_FSI_DEFAULT_PRESSURE_H5 = "pressure.h5"
const NATIVE_RESOLVED_FSI_DEFAULT_DISPLACEMENT_XDMF = "displace.xdmf"
const NATIVE_RESOLVED_FSI_DEFAULT_DISPLACEMENT_H5 = "displace.h5"
const NATIVE_RESOLVED_FSI_DISPLACEMENT_MODES = (:zero, :synthetic_radial_lift)

"""
    NativeResolvedFSIWorkflowSpec(; kwargs...)

Internal workflow configuration for the native resolved-FSI schema skeleton.
This lane does not run a physical 3D FSI solve. It generates deterministic
velocity, pressure, and displacement arrays on `NativeResolvedFSIMesh`, writes
them through the resolved-3D bundle writer, and reloads them through the
existing importer so later solver/parity lanes inherit a stable contract.
"""
struct NativeResolvedFSIWorkflowSpec <: AbstractStudySpec
    case_spec::NativeResolvedFSICaseSpec
    resolution::NativeResolvedFSIMeshResolution
    output_dir::String
    output_time_s::Float64
    time_atol::Float64
    overwrite::Bool
    inlet_umax_cm_s::Float64
    pressure_drop_dyn_cm2::Float64
    displacement_mode::Symbol
    synthetic_lift_amplitude_cm::Float64
end

function NativeResolvedFSIWorkflowSpec(;
    case_id::Union{Symbol,AbstractString,Real} = :sev23,
    resolution::NativeResolvedFSIMeshResolution = NativeResolvedFSIMeshResolution(axial=2, radial=2, angular=8),
    output_dir::AbstractString = "",
    output_time_s::Real = NATIVE_RESOLVED_FSI_DEFAULT_TIME_S,
    time_atol::Real = 1.0e-12,
    overwrite::Bool = false,
    inlet_umax_cm_s::Real = 45.0,
    pressure_drop_dyn_cm2::Real = 40.0,
    displacement_mode::Union{Symbol,AbstractString} = :zero,
    synthetic_lift_amplitude_cm::Real = 0.002,
)
    return NativeResolvedFSIWorkflowSpec(
        native_resolved_fsi_case_spec(case_id),
        resolution,
        String(output_dir),
        Float64(output_time_s),
        Float64(time_atol),
        overwrite,
        Float64(inlet_umax_cm_s),
        Float64(pressure_drop_dyn_cm2),
        native_resolved_fsi_displacement_mode(displacement_mode),
        Float64(synthetic_lift_amplitude_cm),
    )
end

"""
    NativeResolvedFSIWorkflowStatus

One readiness/status pair for the workflow skeleton handback.
"""
struct NativeResolvedFSIWorkflowStatus
    ready::Bool
    status::String
end

"""
    NativeResolvedFSIWorkflowResult

Return bundle for [`run_native_resolved_fsi_workflow`](@ref). The result keeps
the reloaded arrays, written file paths, and explicit readiness/status fields
for schema, geometry, time, field, and observation-operator follow-on work.
"""
struct NativeResolvedFSIWorkflowResult
    spec::NativeResolvedFSIWorkflowSpec
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
    loaded_coordinates::Matrix{Float64}
    loaded_topology::Matrix{Int}
    loaded_velocity::Matrix{Float64}
    loaded_pressure::Vector{Float64}
    loaded_displacement::Matrix{Float64}
    loaded_deformed_coordinates::Matrix{Float64}
    boundary_tag_names::NTuple{4,Symbol}
    boundary_face_counts::NamedTuple{(:inlet,:outlet,:wall,:interior),Tuple{Int,Int,Int,Int}}
    boundary_node_counts::NamedTuple{(:inlet,:outlet,:wall),Tuple{Int,Int,Int}}
    schema_status::NativeResolvedFSIWorkflowStatus
    geometry_status::NativeResolvedFSIWorkflowStatus
    time_status::NativeResolvedFSIWorkflowStatus
    field_status::NativeResolvedFSIWorkflowStatus
    operator_status::NativeResolvedFSIWorkflowStatus
end

workflow_kind(::NativeResolvedFSIWorkflowSpec) = "native_resolved_fsi_workflow"

function validate(spec::NativeResolvedFSIWorkflowSpec)
    spec.output_time_s >= 0.0 || throw(ArgumentError("native resolved-FSI output_time_s must be nonnegative"))
    spec.time_atol > 0.0 || throw(ArgumentError("native resolved-FSI time_atol must be positive"))
    spec.inlet_umax_cm_s > 0.0 || throw(ArgumentError("native resolved-FSI inlet_umax_cm_s must be positive"))
    isfinite(spec.pressure_drop_dyn_cm2) || throw(ArgumentError("native resolved-FSI pressure_drop_dyn_cm2 must be finite"))
    spec.synthetic_lift_amplitude_cm >= 0.0 ||
        throw(ArgumentError("native resolved-FSI synthetic_lift_amplitude_cm must be nonnegative"))
    spec.displacement_mode in NATIVE_RESOLVED_FSI_DISPLACEMENT_MODES ||
        throw(ArgumentError("unsupported native resolved-FSI displacement mode $(repr(spec.displacement_mode))"))
    return spec
end

"""
    default_native_resolved_fsi_output_dir(spec) -> String

Return the default scratch bundle directory under `tmp/simulations/output/`.
The path is deterministic so follow-on lanes can predict where schema-only
bundles land without searching generated data.
"""
function default_native_resolved_fsi_output_dir(spec::NativeResolvedFSIWorkflowSpec)
    resolution = spec.resolution
    mesh_token = "$(resolution.axial)x$(resolution.radial)x$(resolution.angular)"
    mode_token = native_resolved_fsi_displacement_mode_token(spec.displacement_mode)
    return joinpath(
        NATIVE_RESOLVED_FSI_DEFAULT_OUTPUT_ROOT,
        string(spec.case_spec.case_id),
        mesh_token,
        "$(mode_token)-t$(path_token(spec.output_time_s))",
    )
end

function default_output_paths(spec::NativeResolvedFSIWorkflowSpec)
    output_dir = isempty(spec.output_dir) ? default_native_resolved_fsi_output_dir(spec) : spec.output_dir
    return (
        output_dir=output_dir,
        mesh_h5=joinpath(output_dir, NATIVE_RESOLVED_FSI_DEFAULT_MESH_H5),
        velocity_xdmf=joinpath(output_dir, NATIVE_RESOLVED_FSI_DEFAULT_VELOCITY_XDMF),
        velocity_h5=joinpath(output_dir, NATIVE_RESOLVED_FSI_DEFAULT_VELOCITY_H5),
        pressure_xdmf=joinpath(output_dir, NATIVE_RESOLVED_FSI_DEFAULT_PRESSURE_XDMF),
        pressure_h5=joinpath(output_dir, NATIVE_RESOLVED_FSI_DEFAULT_PRESSURE_H5),
        displacement_xdmf=joinpath(output_dir, NATIVE_RESOLVED_FSI_DEFAULT_DISPLACEMENT_XDMF),
        displacement_h5=joinpath(output_dir, NATIVE_RESOLVED_FSI_DEFAULT_DISPLACEMENT_H5),
    )
end

"""
    native_resolved_fsi_zero_displacement(mesh) -> Matrix{Float64}

Return the fixed-wall displacement field used by the workflow skeleton and the
first smoke-stage handoff. This is explicit zero displacement, not an implicit
absence of a structure field.
"""
function native_resolved_fsi_zero_displacement(mesh::NativeResolvedFSIMesh)
    return zeros(Float64, size(mesh.coordinates, 1), 3)
end

"""
    native_resolved_fsi_synthetic_wall_lift(mesh; amplitude_cm=0.002) -> Vector{Float64}

Return a deterministic clamped radial wall profile over the native axial
stations. This is a schema-test surrogate only; it is not presented as a
physical FSI solution.
"""
function native_resolved_fsi_synthetic_wall_lift(mesh::NativeResolvedFSIMesh; amplitude_cm::Real = 0.002)
    amplitude = Float64(amplitude_cm)
    amplitude >= 0.0 || throw(ArgumentError("synthetic wall-lift amplitude must be nonnegative"))
    length_cm = mesh.case_spec.length_cm
    axial_coordinates = mesh.geometry.axial_coordinates_cm
    wall_lift = Float64[amplitude * sin(pi * z / length_cm) for z in axial_coordinates]
    wall_lift[1] = 0.0
    wall_lift[end] = 0.0
    return wall_lift
end

"""
    native_resolved_fsi_lifted_displacement(mesh, wall_lift_cm) -> Matrix{Float64}

Lift an axisymmetric radial wall state into a volumetric node-centered
displacement field using the Lane 2D linear-in-radius convention
`d = (r / R_ref(z)) eta(z) e_r`. Centerline nodes remain fixed and inlet/outlet
nodes are clamped to zero.
"""
function native_resolved_fsi_lifted_displacement(mesh::NativeResolvedFSIMesh, wall_lift_cm::AbstractVector)
    axial_coordinates = mesh.geometry.axial_coordinates_cm
    length(wall_lift_cm) == length(axial_coordinates) || throw(DimensionMismatch(
        "wall_lift_cm length $(length(wall_lift_cm)) does not match native axial station count $(length(axial_coordinates))",
    ))
    lift = Float64[Float64(value) for value in wall_lift_cm]
    all(isfinite, lift) || throw(ArgumentError("wall_lift_cm contains non-finite values"))
    lift[1] = 0.0
    lift[end] = 0.0

    displacement = zeros(Float64, size(mesh.coordinates, 1), 3)
    for node in axes(mesh.coordinates, 1)
        x = mesh.coordinates[node, 1]
        y = mesh.coordinates[node, 2]
        z = mesh.coordinates[node, 3]
        eta = native_resolved_fsi_interpolate_wall_lift(axial_coordinates, lift, z)
        radial_distance = hypot(x, y)
        radial_distance == 0.0 && continue
        reference_radius = native_resolved_fsi_radius(mesh.case_spec, z)
        reference_radius > 0.0 || continue
        radial_fraction = clamp(radial_distance / reference_radius, 0.0, 1.0)
        radial_scale = radial_fraction * eta / radial_distance
        displacement[node, 1] = radial_scale * x
        displacement[node, 2] = radial_scale * y
    end

    return displacement
end

"""
    run_native_resolved_fsi_workflow(spec=NativeResolvedFSIWorkflowSpec())

Generate a tiny native resolved-FSI three-field bundle, write it through the
resolved-3D writer, reload it through the existing importer with pressure and
displacement required, and report readiness for downstream solver/parity work.
"""
function run_native_resolved_fsi_workflow(spec::NativeResolvedFSIWorkflowSpec = NativeResolvedFSIWorkflowSpec())
    validate_workflow_spec(spec)
    mesh = native_resolved_fsi_mesh(spec.case_spec, spec.resolution)
    output_paths = default_output_paths(spec)

    velocity = native_resolved_fsi_synthetic_velocity(mesh; inlet_umax_cm_s=spec.inlet_umax_cm_s)
    pressure = native_resolved_fsi_synthetic_pressure(mesh; pressure_drop_dyn_cm2=spec.pressure_drop_dyn_cm2)
    displacement = native_resolved_fsi_displacement(mesh, spec)

    writer_result = write_resolved3d_field_bundle(
        output_paths.output_dir,
        mesh.coordinates,
        mesh.topology,
        velocity,
        pressure,
        displacement;
        time=spec.output_time_s,
        overwrite=spec.overwrite,
    )

    reloaded_case_spec = Resolved3DCaseSpec(
        native_resolved_fsi_case_label(spec),
        spec.case_spec.severity_percent,
        writer_result.paths.velocity_xdmf;
        pressure_xdmf=writer_result.paths.pressure_xdmf,
        displacement_xdmf=writer_result.paths.displacement_xdmf,
        target_time=spec.output_time_s,
        time_atol=spec.time_atol,
    )
    bundle = load_resolved3d_field_bundle(
        reloaded_case_spec;
        require_pressure=true,
        require_displacement=true,
    )
    deformed_field = resolved3d_velocity_field_from_bundle(bundle, "deformed")

    loaded_coordinates = Matrix{Float64}(bundle.velocity.coordinates)
    loaded_topology = Matrix{Int}(bundle.velocity.topology)
    loaded_velocity = Matrix{Float64}(bundle.velocity.velocity)
    loaded_pressure = Vector{Float64}(bundle.pressure)
    loaded_displacement = Matrix{Float64}(bundle.displacement)
    loaded_deformed_coordinates = Matrix{Float64}(deformed_field.coordinates)

    return NativeResolvedFSIWorkflowResult(
        spec,
        mesh,
        output_paths.output_dir,
        writer_result.paths.mesh_h5,
        writer_result.paths.velocity_xdmf,
        writer_result.paths.velocity_h5,
        writer_result.paths.pressure_xdmf,
        writer_result.paths.pressure_h5,
        writer_result.paths.displacement_xdmf,
        writer_result.paths.displacement_h5,
        writer_result.time,
        loaded_coordinates,
        loaded_topology,
        loaded_velocity,
        loaded_pressure,
        loaded_displacement,
        loaded_deformed_coordinates,
        native_resolved_fsi_boundary_tag_names(mesh),
        native_resolved_fsi_tag_counts(mesh),
        native_resolved_fsi_node_tag_counts(mesh),
        native_resolved_fsi_schema_status(bundle, writer_result, loaded_deformed_coordinates),
        native_resolved_fsi_geometry_status(mesh, loaded_coordinates, loaded_topology),
        native_resolved_fsi_time_status(spec, bundle, writer_result),
        native_resolved_fsi_field_status(spec, mesh, loaded_velocity, loaded_pressure, loaded_displacement, loaded_deformed_coordinates),
        native_resolved_fsi_operator_status(),
    )
end

run_native_resolved_fsi(spec::NativeResolvedFSIWorkflowSpec = NativeResolvedFSIWorkflowSpec()) =
    run_native_resolved_fsi_workflow(spec)

function native_resolved_fsi_displacement_mode(value::Symbol)
    value in NATIVE_RESOLVED_FSI_DISPLACEMENT_MODES ||
        throw(ArgumentError("unsupported native resolved-FSI displacement mode $(repr(value))"))
    return value
end

function native_resolved_fsi_displacement_mode(value::AbstractString)
    token = replace(lowercase(strip(String(value))), "-" => "_")
    if token in ("zero", "zero_displacement", "fixed_wall")
        return :zero
    elseif token in ("synthetic", "synthetic_radial_lift", "radial_lift", "lifted")
        return :synthetic_radial_lift
    end
    throw(ArgumentError("unsupported native resolved-FSI displacement mode $(repr(value))"))
end

function native_resolved_fsi_displacement_mode_token(mode::Symbol)
    return mode === :synthetic_radial_lift ? "synthetic-radial-lift" : "zero-displacement"
end

function native_resolved_fsi_case_label(spec::NativeResolvedFSIWorkflowSpec)
    resolution = spec.resolution
    mesh_token = "$(resolution.axial)x$(resolution.radial)x$(resolution.angular)"
    mode_token = native_resolved_fsi_displacement_mode_token(spec.displacement_mode)
    return "native-$(spec.case_spec.case_id)-$(mesh_token)-$(mode_token)"
end

function native_resolved_fsi_displacement(mesh::NativeResolvedFSIMesh, spec::NativeResolvedFSIWorkflowSpec)
    if spec.displacement_mode === :zero
        return native_resolved_fsi_zero_displacement(mesh)
    end
    wall_lift = native_resolved_fsi_synthetic_wall_lift(mesh; amplitude_cm=spec.synthetic_lift_amplitude_cm)
    return native_resolved_fsi_lifted_displacement(mesh, wall_lift)
end

function native_resolved_fsi_synthetic_velocity(mesh::NativeResolvedFSIMesh; inlet_umax_cm_s::Real = 45.0)
    umax = Float64(inlet_umax_cm_s)
    velocity = zeros(Float64, size(mesh.coordinates, 1), 3)
    for node in axes(mesh.coordinates, 1)
        x = mesh.coordinates[node, 1]
        y = mesh.coordinates[node, 2]
        z = mesh.coordinates[node, 3]
        reference_radius = native_resolved_fsi_radius(mesh.case_spec, z)
        radial_fraction = reference_radius == 0.0 ? 0.0 : clamp(hypot(x, y) / reference_radius, 0.0, 1.0)
        velocity[node, 3] = umax * max(0.0, 1.0 - radial_fraction^2)
    end
    return velocity
end

function native_resolved_fsi_synthetic_pressure(mesh::NativeResolvedFSIMesh; pressure_drop_dyn_cm2::Real = 40.0)
    drop = Float64(pressure_drop_dyn_cm2)
    length_cm = mesh.case_spec.length_cm
    pressure = zeros(Float64, size(mesh.coordinates, 1))
    for node in axes(mesh.coordinates, 1)
        z = mesh.coordinates[node, 3]
        pressure[node] = drop * (1.0 - z / length_cm)
    end
    return pressure
end

function native_resolved_fsi_interpolate_wall_lift(
    axial_coordinates_cm::Vector{Float64},
    wall_lift_cm::Vector{Float64},
    z_cm::Real,
)
    z = Float64(z_cm)
    z <= axial_coordinates_cm[1] && return wall_lift_cm[1]
    z >= axial_coordinates_cm[end] && return wall_lift_cm[end]

    upper = searchsortedfirst(axial_coordinates_cm, z)
    lower = upper - 1
    z0 = axial_coordinates_cm[lower]
    z1 = axial_coordinates_cm[upper]
    z1 == z0 && return wall_lift_cm[upper]
    alpha = (z - z0) / (z1 - z0)
    return (1.0 - alpha) * wall_lift_cm[lower] + alpha * wall_lift_cm[upper]
end

function native_resolved_fsi_schema_status(bundle, writer_result, deformed_coordinates::Matrix{Float64})
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
        "writer/importer round trip succeeded with required pressure, displacement, and deformed coordinates" :
        "writer/importer round trip is incomplete"
    return NativeResolvedFSIWorkflowStatus(ready, status)
end

function native_resolved_fsi_geometry_status(
    mesh::NativeResolvedFSIMesh,
    loaded_coordinates::Matrix{Float64},
    loaded_topology::Matrix{Int},
)
    same_geometry = loaded_coordinates == mesh.coordinates
    same_topology = loaded_topology == mesh.topology
    tag_counts = native_resolved_fsi_tag_counts(mesh)
    ready = same_geometry &&
            same_topology &&
            size(loaded_coordinates, 1) > 0 &&
            size(loaded_topology, 1) > 0 &&
            tag_counts.inlet > 0 &&
            tag_counts.outlet > 0 &&
            tag_counts.wall > 0
    status = ready ?
        "reference geometry/topology reloaded exactly with $(size(loaded_coordinates, 1)) nodes and $(size(loaded_topology, 1)) tetrahedra" :
        "reloaded geometry/topology does not match NativeResolvedFSIMesh"
    return NativeResolvedFSIWorkflowStatus(ready, status)
end

function native_resolved_fsi_time_status(spec::NativeResolvedFSIWorkflowSpec, bundle, writer_result)
    pressure_metadata = bundle.pressure_metadata
    displacement_metadata = bundle.displacement_metadata
    ready = abs(writer_result.time - spec.output_time_s) <= spec.time_atol &&
            abs(bundle.velocity.metadata.time - spec.output_time_s) <= spec.time_atol &&
            pressure_metadata !== nothing &&
            abs(pressure_metadata.time - spec.output_time_s) <= spec.time_atol &&
            displacement_metadata !== nothing &&
            abs(displacement_metadata.time - spec.output_time_s) <= spec.time_atol
    status = ready ?
        "native bundle written and reloaded at $(spec.output_time_s) s" :
        "native bundle time metadata does not match the requested output time"
    return NativeResolvedFSIWorkflowStatus(ready, status)
end

function native_resolved_fsi_field_status(
    spec::NativeResolvedFSIWorkflowSpec,
    mesh::NativeResolvedFSIMesh,
    velocity::Matrix{Float64},
    pressure::Vector{Float64},
    displacement::Matrix{Float64},
    deformed_coordinates::Matrix{Float64},
)
    finite_fields = all(isfinite, velocity) && all(isfinite, pressure) && all(isfinite, displacement)
    deformed_ok = deformed_coordinates == mesh.coordinates .+ displacement
    endpoint_clamp_ok = native_resolved_fsi_endpoint_clamp_ok(mesh, displacement)
    mode_ok = if spec.displacement_mode === :zero
        all(iszero, displacement)
    else
        maximum(abs, displacement) > 0.0 && endpoint_clamp_ok
    end
    ready = finite_fields && deformed_ok && endpoint_clamp_ok && mode_ok
    if spec.displacement_mode === :zero
        status = ready ?
            "synthetic velocity/pressure plus explicit zero displacement are finite and importer-compatible" :
            "field bundle failed the zero-displacement workflow checks"
    else
        status = ready ?
            "synthetic radial lift is finite, clamped at inlet/outlet, and marked as schema-only rather than a physical FSI solve" :
            "field bundle failed the synthetic radial-lift workflow checks"
    end
    return NativeResolvedFSIWorkflowStatus(ready, status)
end

function native_resolved_fsi_operator_status()
    return NativeResolvedFSIWorkflowStatus(
        false,
        "deferred: this skeleton does not run cross-sectional velocity/pressure operators or parity checks",
    )
end

function native_resolved_fsi_endpoint_clamp_ok(mesh::NativeResolvedFSIMesh, displacement::Matrix{Float64})
    for node in (mesh.tags.inlet_nodes..., mesh.tags.outlet_nodes...)
        for component in 1:3
            iszero(displacement[node, component]) || return false
        end
    end
    return true
end

include("native_resolved_fsi_workflow_production.jl")
