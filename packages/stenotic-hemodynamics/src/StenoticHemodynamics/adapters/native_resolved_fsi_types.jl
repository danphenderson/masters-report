const NATIVE_RESOLVED_FSI_SMOKE_DEFAULT_OUTPUT_ROOT =
    joinpath(DEFAULT_SIMULATION_OUTPUT_ROOT, "native-resolved-fsi-smoke")
const NATIVE_RESOLVED_FSI_SMOKE_DEFAULT_TIME_S = NATIVE_RESOLVED_FSI_DEFAULT_TIME_S
const NATIVE_RESOLVED_FSI_SMOKE_MAX_OUTPUT_BYTES = 1_073_741_824
const NATIVE_RESOLVED_FSI_SMOKE_STAGE = :fixed_wall_stokes
const NATIVE_RESOLVED_FSI_NAVIER_STOKES_SMOKE_DEFAULT_DT_S = 0.25
const NATIVE_RESOLVED_FSI_SECTION41_INLET_UMAX_CM_S = 45.0
const NATIVE_RESOLVED_FSI_NAVIER_STOKES_SMOKE_DEFAULT_PICARD_ITERATION_COUNT = 8
const NATIVE_RESOLVED_FSI_NAVIER_STOKES_SMOKE_DEFAULT_PICARD_TOLERANCE = 1.0e-8
const NATIVE_RESOLVED_FSI_NAVIER_STOKES_SMOKE_STAGE = :fixed_wall_navier_stokes_backward_euler_picard
const NATIVE_RESOLVED_FSI_PARTITIONED_SMOKE_DEFAULT_DT_S = 1.0e-4
const NATIVE_RESOLVED_FSI_PARTITIONED_SMOKE_DEFAULT_TFINAL_S = 1.0e-4
const NATIVE_RESOLVED_FSI_PARTITIONED_SMOKE_DEFAULT_WALL_DENSITY_G_CM3 = 1.0
const NATIVE_RESOLVED_FSI_PARTITIONED_SMOKE_DEFAULT_WALL_DAMPING_G_CM2_S = 0.0
const NATIVE_RESOLVED_FSI_PARTITIONED_SMOKE_STAGE = :partitioned_prescribed_wall_velocity_iterated_wall_output_smoke
const NATIVE_RESOLVED_FSI_PARTITIONED_SMOKE_FLUID_WALL_BOUNDARY_MODE = :prescribed_radial_wall_velocity
const NATIVE_RESOLVED_FSI_PARTITIONED_EXACT_FLUID_WALL_BOUNDARY_MODE = :stationary_wall_on_deformed_geometry
const NATIVE_RESOLVED_FSI_INLET_OUTLET_BOUNDARY_MODES = (
    :pressure_drop_weak_inlet_outlet_gauge_smoke,
    :poiseuille_inlet_zero_outlet_stress_section41,
)
const NATIVE_RESOLVED_FSI_DEFAULT_INLET_OUTLET_BOUNDARY_MODE =
    :pressure_drop_weak_inlet_outlet_gauge_smoke
const NATIVE_RESOLVED_FSI_PHASE_TIMING_KEYS = (
    :gridap_model_setup_s,
    :gridap_space_setup_s,
    :gridap_measure_setup_s,
    :gridap_operator_assembly_s,
    :gridap_affine_operator_s,
    :gridap_matrix_extraction_s,
    :gridap_rhs_extraction_s,
    :linear_symbolic_factorization_s,
    :linear_numeric_factorization_s,
    :linear_backsolve_s,
    :fluid_solve_total_s,
    :wall_pressure_sampling_s,
    :wall_update_s,
    :diagnostics_s,
    :checkpoint_output_s,
    :output_write_s,
    :step_total_s,
)
const NATIVE_RESOLVED_FSI_PHASE_TIMING_DERIVED_KEYS = (
    :gridap_operator_assembly_s,
)
const NATIVE_RESOLVED_FSI_SOLVER_DIAGNOSTIC_KEYS = (
    :gridap_rebuild_status,
    :gridap_reuse_status,
    :gridap_reuse_miss_reason,
    :gridap_matrix_rows,
    :gridap_matrix_cols,
    :gridap_matrix_nnz,
    :gridap_matrix_structure_digest,
    :gridap_matrix_value_digest,
    :gridap_rhs_digest,
    :gridap_boundary_mode,
    :gridap_pressure_constraint,
    :gridap_pressure_reference,
    :gridap_wall_boundary_mode,
    :gridap_dt_s,
    :gridap_time_step_index,
    :gridap_picard_iteration,
    :gridap_linear_solve_count,
    :gridap_rebuild_count,
)

function native_resolved_fsi_empty_solver_diagnostics()
    return (
        gridap_rebuild_status="not_evaluated",
        gridap_reuse_status="not_evaluated",
        gridap_reuse_miss_reason="not_evaluated",
        gridap_matrix_rows=0,
        gridap_matrix_cols=0,
        gridap_matrix_nnz=0,
        gridap_matrix_structure_digest="",
        gridap_matrix_value_digest="",
        gridap_rhs_digest="",
        gridap_boundary_mode="",
        gridap_pressure_constraint="",
        gridap_pressure_reference="",
        gridap_wall_boundary_mode="",
        gridap_dt_s=NaN,
        gridap_time_step_index=0,
        gridap_picard_iteration=0,
        gridap_linear_solve_count=0,
        gridap_rebuild_count=0,
    )
end

function native_resolved_fsi_empty_phase_timing()
    return NamedTuple{NATIVE_RESOLVED_FSI_PHASE_TIMING_KEYS}(
        ntuple(_ -> 0.0, length(NATIVE_RESOLVED_FSI_PHASE_TIMING_KEYS)),
    )
end

function native_resolved_fsi_phase_timing_accumulator()
    return Dict{Symbol,Float64}(key => 0.0 for key in NATIVE_RESOLVED_FSI_PHASE_TIMING_KEYS)
end

native_resolved_fsi_phase_elapsed_s(start_ns::UInt64) =
    Float64(time_ns() - start_ns) / 1.0e9

function native_resolved_fsi_phase_timing_named_tuple(timings::AbstractDict{Symbol,<:Real})
    return NamedTuple{NATIVE_RESOLVED_FSI_PHASE_TIMING_KEYS}(
        ntuple(
            index -> Float64(get(timings, NATIVE_RESOLVED_FSI_PHASE_TIMING_KEYS[index], 0.0)),
            length(NATIVE_RESOLVED_FSI_PHASE_TIMING_KEYS),
        ),
    )
end

function native_resolved_fsi_add_phase_timing!(
    timings::AbstractDict{Symbol,Float64},
    key::Symbol,
    elapsed_s::Real,
)
    key in NATIVE_RESOLVED_FSI_PHASE_TIMING_KEYS ||
        throw(ArgumentError("native resolved-FSI phase timing key is not recognized: $(repr(key))"))
    value = Float64(elapsed_s)
    isfinite(value) && value >= 0.0 ||
        throw(ArgumentError("native resolved-FSI phase timing values must be finite and nonnegative"))
    timings[key] = get(timings, key, 0.0) + value
    return timings
end

function native_resolved_fsi_record_phase_elapsed!(key::Symbol, start_ns::UInt64, timings...)
    elapsed_s = native_resolved_fsi_phase_elapsed_s(start_ns)
    for timing in timings
        native_resolved_fsi_add_phase_timing!(timing, key, elapsed_s)
    end
    return elapsed_s
end

function native_resolved_fsi_merge_phase_timing!(
    timings::AbstractDict{Symbol,Float64},
    phase_timing::NamedTuple;
    exclude = (),
)
    for key in NATIVE_RESOLVED_FSI_PHASE_TIMING_KEYS
        key in exclude && continue
        native_resolved_fsi_add_phase_timing!(timings, key, get(phase_timing, key, 0.0))
    end
    return timings
end

function native_resolved_fsi_record_fluid_solve_phase_timing!(fluid_phase_timing::NamedTuple, start_ns::UInt64, timings...)
    elapsed_s = native_resolved_fsi_phase_elapsed_s(start_ns)
    for timing in timings
        native_resolved_fsi_merge_phase_timing!(timing, fluid_phase_timing; exclude=(:fluid_solve_total_s,))
        native_resolved_fsi_add_phase_timing!(timing, :fluid_solve_total_s, elapsed_s)
    end
    return elapsed_s
end

function native_resolved_fsi_phase_timing_total_s(phase_timing::NamedTuple)
    total = 0.0
    for key in NATIVE_RESOLVED_FSI_PHASE_TIMING_KEYS
        key in NATIVE_RESOLVED_FSI_PHASE_TIMING_DERIVED_KEYS && continue
        total += Float64(get(phase_timing, key, 0.0))
    end
    return total
end

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
    NativeResolvedFSINavierStokesSmokeSpec(; kwargs...)

Typed configuration for the first fixed-wall incompressible Navier-Stokes smoke
solve. This stage advances a fixed-wall `NativeResolvedFSIMesh` from rest with
backward-Euler time stepping and Picard-linearized convection. It does not move
the wall and does not include membrane coupling.
"""
struct NativeResolvedFSINavierStokesSmokeSpec
    case_spec::NativeResolvedFSICaseSpec
    resolution::NativeResolvedFSIMeshResolution
    output_dir::String
    dt_s::Float64
    tfinal_s::Float64
    time_atol::Float64
    overwrite::Bool
    pressure_drop_dyn_cm2::Float64
    picard_iteration_count::Int
    picard_tolerance::Float64
end

function NativeResolvedFSINavierStokesSmokeSpec(;
    case_id::Union{Symbol,AbstractString,Real} = :sev23,
    resolution::NativeResolvedFSIMeshResolution = NativeResolvedFSIMeshResolution(axial=2, radial=1, angular=6),
    output_dir::AbstractString = "",
    dt_s::Real = NATIVE_RESOLVED_FSI_NAVIER_STOKES_SMOKE_DEFAULT_DT_S,
    tfinal_s::Real = NATIVE_RESOLVED_FSI_SMOKE_DEFAULT_TIME_S,
    time_atol::Real = 1.0e-12,
    overwrite::Bool = false,
    pressure_drop_dyn_cm2::Real = 40.0,
    picard_iteration_count::Integer = NATIVE_RESOLVED_FSI_NAVIER_STOKES_SMOKE_DEFAULT_PICARD_ITERATION_COUNT,
    picard_tolerance::Real = NATIVE_RESOLVED_FSI_NAVIER_STOKES_SMOKE_DEFAULT_PICARD_TOLERANCE,
)
    return validate(NativeResolvedFSINavierStokesSmokeSpec(
        native_resolved_fsi_case_spec(case_id),
        resolution,
        String(output_dir),
        Float64(dt_s),
        Float64(tfinal_s),
        Float64(time_atol),
        overwrite,
        Float64(pressure_drop_dyn_cm2),
        Int(picard_iteration_count),
        Float64(picard_tolerance),
    ))
end

native_resolved_fsi_navier_stokes_smoke_spec(; kwargs...) = NativeResolvedFSINavierStokesSmokeSpec(; kwargs...)

"""
    NativeResolvedFSIPartitionedSmokeSpec(; kwargs...)

Typed configuration for the staged partitioned native resolved-FSI smoke. Each
coupling step advances Navier-Stokes subproblems on iterated lifted geometries
with the current reduced wall velocity prescribed as a radial wall Dirichlet
condition, projects wall pressure onto the native axial stations, updates a
reduced radial membrane state explicitly with under-relaxation, and refreshes
the fluid on the saved geometry for output. This is not a monolithic transient
3D FSI solve. `inlet_outlet_boundary_mode` distinguishes the local pressure-drop
smoke loading from the exact Section 4.1 Poiseuille-inlet / zero-outlet-stress
boundary mode.
"""
struct NativeResolvedFSIPartitionedSmokeSpec
    case_spec::NativeResolvedFSICaseSpec
    resolution::NativeResolvedFSIMeshResolution
    output_dir::String
    dt_s::Float64
    tfinal_s::Float64
    time_atol::Float64
    overwrite::Bool
    inlet_outlet_boundary_mode::Symbol
    inlet_umax_cm_s::Float64
    pressure_drop_dyn_cm2::Float64
    picard_iteration_count::Int
    picard_tolerance::Float64
    wall_density_g_cm3::Float64
    wall_damping_g_cm2_s::Float64
    coupling_iteration_count::Int
    coupling_tolerance::Float64
    coupling_under_relaxation::Float64
end

function NativeResolvedFSIPartitionedSmokeSpec(;
    case_id::Union{Symbol,AbstractString,Real} = :sev23,
    resolution::NativeResolvedFSIMeshResolution = NativeResolvedFSIMeshResolution(axial=2, radial=1, angular=6),
    output_dir::AbstractString = "",
    dt_s::Real = NATIVE_RESOLVED_FSI_PARTITIONED_SMOKE_DEFAULT_DT_S,
    tfinal_s::Real = NATIVE_RESOLVED_FSI_PARTITIONED_SMOKE_DEFAULT_TFINAL_S,
    time_atol::Real = 1.0e-12,
    overwrite::Bool = false,
    inlet_outlet_boundary_mode::Union{Symbol,AbstractString} = NATIVE_RESOLVED_FSI_DEFAULT_INLET_OUTLET_BOUNDARY_MODE,
    inlet_umax_cm_s::Real = NATIVE_RESOLVED_FSI_SECTION41_INLET_UMAX_CM_S,
    pressure_drop_dyn_cm2::Real = 40.0,
    picard_iteration_count::Integer = NATIVE_RESOLVED_FSI_NAVIER_STOKES_SMOKE_DEFAULT_PICARD_ITERATION_COUNT,
    picard_tolerance::Real = NATIVE_RESOLVED_FSI_NAVIER_STOKES_SMOKE_DEFAULT_PICARD_TOLERANCE,
    wall_density_g_cm3::Real = NATIVE_RESOLVED_FSI_PARTITIONED_SMOKE_DEFAULT_WALL_DENSITY_G_CM3,
    wall_damping_g_cm2_s::Real = NATIVE_RESOLVED_FSI_PARTITIONED_SMOKE_DEFAULT_WALL_DAMPING_G_CM2_S,
    coupling_iteration_count::Integer = 1,
    coupling_tolerance::Real = 1.0e-8,
    coupling_under_relaxation::Real = 1.0,
)
    return validate(NativeResolvedFSIPartitionedSmokeSpec(
        native_resolved_fsi_case_spec(case_id),
        resolution,
        String(output_dir),
        Float64(dt_s),
        Float64(tfinal_s),
        Float64(time_atol),
        overwrite,
        Symbol(inlet_outlet_boundary_mode),
        Float64(inlet_umax_cm_s),
        Float64(pressure_drop_dyn_cm2),
        Int(picard_iteration_count),
        Float64(picard_tolerance),
        Float64(wall_density_g_cm3),
        Float64(wall_damping_g_cm2_s),
        Int(coupling_iteration_count),
        Float64(coupling_tolerance),
        Float64(coupling_under_relaxation),
    ))
end

native_resolved_fsi_partitioned_smoke_spec(; kwargs...) = NativeResolvedFSIPartitionedSmokeSpec(; kwargs...)

"""
    NativeResolvedFSISmokeResult

Bundle returned by [`run_native_resolved_fsi_smoke`](@ref). It records the
solver-backed field round trip together with schema, geometry, time, and field
status for the staged fixed-wall smoke target. `inlet_outlet_boundary_mode`
records the package-local smoke boundary realization, while
`section41_boundary_status` reports whether that realization is exact Section
4.1 inlet/outlet boundary reproduction.
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
    inlet_outlet_boundary_mode::Symbol
    section41_boundary_status::NativeResolvedFSIWorkflowStatus
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

"""
    NativeResolvedFSINavierStokesSmokeResult

Bundle returned by [`run_native_resolved_fsi_navier_stokes_smoke`](@ref). It
records the final fixed-wall bundle round trip together with the coarse
backward-Euler/Picard stepper summary used to reach the saved state and the
bounded Section 4.1 inlet/outlet boundary status.
"""
struct NativeResolvedFSINavierStokesSmokeResult
    spec::NativeResolvedFSINavierStokesSmokeSpec
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
    inlet_outlet_boundary_mode::Symbol
    section41_boundary_status::NativeResolvedFSIWorkflowStatus
    velocity_dofs::Int
    pressure_dofs::Int
    time_step_count::Int
    max_picard_iterations_used::Int
    final_picard_update_norm::Float64
    picard_converged::Bool
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

struct NativeResolvedFSINavierStokesSmokeSolve
    velocity
    pressure
    velocity_dofs::Int
    pressure_dofs::Int
    time_step_count::Int
    max_picard_iterations_used::Int
    final_picard_update_norm::Float64
    picard_converged::Bool
    inlet_outlet_boundary_mode::Symbol
    inlet_umax_cm_s::Float64
    inlet_outlet_boundary_status::String
    solver_diagnostics::NamedTuple
    phase_timing_s::NamedTuple
end

"""
    NativeResolvedFSIPartitionedSmokeResult

Bundle returned by [`run_native_resolved_fsi_partitioned_smoke`](@ref). It
records the staged partitioned coupling summary, including the reduced wall
state on native axial stations and the final three-field writer/importer round
trip. The inlet/outlet boundary status is separate from the wall-velocity mode
because the current smoke path couples the wall radially while retaining
pressure-drop-driven inlet/outlet loading.
"""
struct NativeResolvedFSIPartitionedSmokeResult
    spec::NativeResolvedFSIPartitionedSmokeSpec
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
    inlet_outlet_boundary_mode::Symbol
    section41_boundary_status::NativeResolvedFSIWorkflowStatus
    velocity_dofs::Int
    pressure_dofs::Int
    time_step_count::Int
    max_picard_iterations_used::Int
    final_picard_update_norm::Float64
    picard_converged::Bool
    max_coupling_iterations_used::Int
    final_coupling_displacement_residual_cm::Float64
    coupling_converged::Bool
    fluid_wall_boundary_mode::Symbol
    coupling_residual_history::Vector{NamedTuple}
    post_update_fluid_refresh::Bool
    wall_axial_coordinates_cm::Vector{Float64}
    wall_displacement_cm::Vector{Float64}
    wall_velocity_cm_s::Vector{Float64}
    wall_pressure_dyn_cm2::Vector{Float64}
    current_radii_cm::Vector{Float64}
    wall_mass_g_cm2::Float64
    wall_stiffness_c0_dyn_cm3::Float64
    wall_damping_g_cm2_s::Float64
    stability_dt_limit_s::Float64
    minimum_current_radius_cm::Float64
    minimum_signed_tetra_volume6::Float64
    pressure_projection_fallback_count::Int
    sampling_fallback_count::Int
    pressure_gauge_offset_dyn_cm2::Float64
    solver_diagnostics::NamedTuple
    phase_timing_s::NamedTuple
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

struct NativeResolvedFSIPartitionedSmokeSolve
    velocity
    pressure
    velocity_dofs::Int
    pressure_dofs::Int
    inlet_outlet_boundary_mode::Symbol
    inlet_umax_cm_s::Float64
    inlet_outlet_boundary_status::String
    time_step_count::Int
    max_picard_iterations_used::Int
    final_picard_update_norm::Float64
    picard_converged::Bool
    max_coupling_iterations_used::Int
    final_coupling_displacement_residual_cm::Float64
    coupling_converged::Bool
    fluid_wall_boundary_mode::Symbol
    coupling_residual_history::Vector{NamedTuple}
    post_update_fluid_refresh::Bool
    wall_axial_coordinates_cm::Vector{Float64}
    wall_displacement_cm::Vector{Float64}
    wall_velocity_cm_s::Vector{Float64}
    wall_pressure_dyn_cm2::Vector{Float64}
    current_radii_cm::Vector{Float64}
    wall_mass_g_cm2::Float64
    wall_stiffness_c0_dyn_cm3::Float64
    stability_dt_limit_s::Float64
    minimum_signed_tetra_volume6::Float64
    pressure_projection_fallback_count::Int
    solver_diagnostics::NamedTuple
    phase_timing_s::NamedTuple
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

function validate(spec::NativeResolvedFSINavierStokesSmokeSpec)
    isfinite(spec.dt_s) || throw(ArgumentError("native resolved-FSI Navier-Stokes smoke dt_s must be finite"))
    spec.dt_s > 0.0 || throw(ArgumentError("native resolved-FSI Navier-Stokes smoke dt_s must be positive"))
    isfinite(spec.tfinal_s) || throw(ArgumentError("native resolved-FSI Navier-Stokes smoke tfinal_s must be finite"))
    spec.tfinal_s > 0.0 || throw(ArgumentError("native resolved-FSI Navier-Stokes smoke tfinal_s must be positive"))
    spec.time_atol > 0.0 || throw(ArgumentError("native resolved-FSI Navier-Stokes smoke time_atol must be positive"))
    isfinite(spec.pressure_drop_dyn_cm2) ||
        throw(ArgumentError("native resolved-FSI Navier-Stokes smoke pressure_drop_dyn_cm2 must be finite"))
    spec.pressure_drop_dyn_cm2 > 0.0 ||
        throw(ArgumentError("native resolved-FSI Navier-Stokes smoke pressure_drop_dyn_cm2 must be positive"))
    spec.picard_iteration_count > 0 ||
        throw(ArgumentError("native resolved-FSI Navier-Stokes smoke picard_iteration_count must be positive"))
    isfinite(spec.picard_tolerance) ||
        throw(ArgumentError("native resolved-FSI Navier-Stokes smoke picard_tolerance must be finite"))
    spec.picard_tolerance > 0.0 ||
        throw(ArgumentError("native resolved-FSI Navier-Stokes smoke picard_tolerance must be positive"))
    return spec
end

function validate(spec::NativeResolvedFSIPartitionedSmokeSpec)
    isfinite(spec.dt_s) || throw(ArgumentError("native resolved-FSI partitioned smoke dt_s must be finite"))
    spec.dt_s > 0.0 || throw(ArgumentError("native resolved-FSI partitioned smoke dt_s must be positive"))
    isfinite(spec.tfinal_s) || throw(ArgumentError("native resolved-FSI partitioned smoke tfinal_s must be finite"))
    spec.tfinal_s > 0.0 || throw(ArgumentError("native resolved-FSI partitioned smoke tfinal_s must be positive"))
    spec.time_atol > 0.0 || throw(ArgumentError("native resolved-FSI partitioned smoke time_atol must be positive"))
    spec.inlet_outlet_boundary_mode in NATIVE_RESOLVED_FSI_INLET_OUTLET_BOUNDARY_MODES || throw(ArgumentError(
        "native resolved-FSI partitioned smoke inlet_outlet_boundary_mode must be one of $(NATIVE_RESOLVED_FSI_INLET_OUTLET_BOUNDARY_MODES)",
    ))
    isfinite(spec.inlet_umax_cm_s) ||
        throw(ArgumentError("native resolved-FSI partitioned smoke inlet_umax_cm_s must be finite"))
    if spec.inlet_outlet_boundary_mode === :poiseuille_inlet_zero_outlet_stress_section41
        spec.inlet_umax_cm_s > 0.0 ||
            throw(ArgumentError("native resolved-FSI partitioned smoke inlet_umax_cm_s must be positive for exact Section 4.1 mode"))
    end
    isfinite(spec.pressure_drop_dyn_cm2) ||
        throw(ArgumentError("native resolved-FSI partitioned smoke pressure_drop_dyn_cm2 must be finite"))
    if spec.inlet_outlet_boundary_mode === :pressure_drop_weak_inlet_outlet_gauge_smoke
        spec.pressure_drop_dyn_cm2 > 0.0 ||
            throw(ArgumentError("native resolved-FSI partitioned smoke pressure_drop_dyn_cm2 must be positive"))
    end
    spec.picard_iteration_count > 0 ||
        throw(ArgumentError("native resolved-FSI partitioned smoke picard_iteration_count must be positive"))
    isfinite(spec.picard_tolerance) ||
        throw(ArgumentError("native resolved-FSI partitioned smoke picard_tolerance must be finite"))
    spec.picard_tolerance > 0.0 ||
        throw(ArgumentError("native resolved-FSI partitioned smoke picard_tolerance must be positive"))
    isfinite(spec.wall_density_g_cm3) ||
        throw(ArgumentError("native resolved-FSI partitioned smoke wall_density_g_cm3 must be finite"))
    spec.wall_density_g_cm3 > 0.0 ||
        throw(ArgumentError("native resolved-FSI partitioned smoke wall_density_g_cm3 must be positive"))
    isfinite(spec.wall_damping_g_cm2_s) ||
        throw(ArgumentError("native resolved-FSI partitioned smoke wall_damping_g_cm2_s must be finite"))
    spec.wall_damping_g_cm2_s >= 0.0 ||
        throw(ArgumentError("native resolved-FSI partitioned smoke wall_damping_g_cm2_s must be nonnegative"))
    spec.coupling_iteration_count > 0 ||
        throw(ArgumentError("native resolved-FSI partitioned smoke coupling_iteration_count must be positive"))
    isfinite(spec.coupling_tolerance) ||
        throw(ArgumentError("native resolved-FSI partitioned smoke coupling_tolerance must be finite"))
    spec.coupling_tolerance > 0.0 ||
        throw(ArgumentError("native resolved-FSI partitioned smoke coupling_tolerance must be positive"))
    isfinite(spec.coupling_under_relaxation) ||
        throw(ArgumentError("native resolved-FSI partitioned smoke coupling_under_relaxation must be finite"))
    0.0 < spec.coupling_under_relaxation <= 1.0 ||
        throw(ArgumentError("native resolved-FSI partitioned smoke coupling_under_relaxation must lie in (0, 1]"))
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
    default_native_resolved_fsi_navier_stokes_smoke_output_dir(spec) -> String

Return the default ignored scratch directory for the staged fixed-wall
Navier-Stokes smoke bundle.
"""
function default_native_resolved_fsi_navier_stokes_smoke_output_dir(spec::NativeResolvedFSINavierStokesSmokeSpec)
    resolution = spec.resolution
    mesh_token = "$(resolution.axial)x$(resolution.radial)x$(resolution.angular)"
    return joinpath(
        NATIVE_RESOLVED_FSI_SMOKE_DEFAULT_OUTPUT_ROOT,
        string(spec.case_spec.case_id),
        mesh_token,
        "fixed-wall-navier-stokes-dt$(path_token(spec.dt_s))-tfinal$(path_token(spec.tfinal_s))",
    )
end

"""
    default_native_resolved_fsi_partitioned_smoke_output_dir(spec) -> String

Return the default ignored scratch directory for the staged partitioned native
resolved-FSI smoke bundle.
"""
function default_native_resolved_fsi_partitioned_smoke_output_dir(spec::NativeResolvedFSIPartitionedSmokeSpec)
    resolution = spec.resolution
    mesh_token = "$(resolution.axial)x$(resolution.radial)x$(resolution.angular)"
    return joinpath(
        NATIVE_RESOLVED_FSI_SMOKE_DEFAULT_OUTPUT_ROOT,
        string(spec.case_spec.case_id),
        mesh_token,
        "partitioned-dt$(path_token(spec.dt_s))-tfinal$(path_token(spec.tfinal_s))",
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
    native_resolved_fsi_smoke_validate_finite_fields("fixed-wall Stokes smoke", velocity, pressure, displacement)

    output_dir = isempty(spec.output_dir) ? default_native_resolved_fsi_smoke_output_dir(spec) : spec.output_dir
    roundtrip = native_resolved_fsi_smoke_roundtrip_bundle(
        mesh,
        output_dir,
        native_resolved_fsi_smoke_case_label(spec),
        velocity,
        pressure,
        displacement;
        saved_time_s=spec.saved_time_s,
        time_atol=spec.time_atol,
        overwrite=spec.overwrite,
    )

    return NativeResolvedFSISmokeResult(
        spec,
        mesh,
        output_dir,
        roundtrip.writer_result.paths.mesh_h5,
        roundtrip.writer_result.paths.velocity_xdmf,
        roundtrip.writer_result.paths.velocity_h5,
        roundtrip.writer_result.paths.pressure_xdmf,
        roundtrip.writer_result.paths.pressure_h5,
        roundtrip.writer_result.paths.displacement_xdmf,
        roundtrip.writer_result.paths.displacement_h5,
        roundtrip.writer_result.time,
        NATIVE_RESOLVED_FSI_SMOKE_STAGE,
        :pressure_drop_weak_inlet_outlet_gauge_smoke,
        NativeResolvedFSIWorkflowStatus(
            false,
            "local smoke boundary evidence only: Gridap solve uses pressure-drop weak inlet/outlet loading with outlet-gauge pressure; not exact Section 4.1 Poiseuille inlet / zero-outlet-stress reproduction",
        ),
        solve_result.velocity_dofs,
        solve_result.pressure_dofs,
        sampling_fallback_count,
        pressure_gauge_offset_dyn_cm2,
        estimated_field_payload_bytes,
        roundtrip.loaded_coordinates,
        roundtrip.loaded_topology,
        roundtrip.loaded_velocity,
        roundtrip.loaded_pressure,
        roundtrip.loaded_displacement,
        roundtrip.loaded_deformed_coordinates,
        native_resolved_fsi_smoke_schema_status(roundtrip.bundle, roundtrip.writer_result, roundtrip.loaded_deformed_coordinates),
        native_resolved_fsi_smoke_geometry_status(mesh, roundtrip.loaded_coordinates, roundtrip.loaded_topology),
        native_resolved_fsi_smoke_time_status(spec, roundtrip.bundle, roundtrip.writer_result),
        native_resolved_fsi_smoke_field_status(
            mesh,
            roundtrip.loaded_velocity,
            roundtrip.loaded_pressure,
            roundtrip.loaded_displacement,
            roundtrip.loaded_deformed_coordinates,
            sampling_fallback_count,
        ),
    )
end

run_native_resolved_fsi(spec::NativeResolvedFSISmokeSpec) = run_native_resolved_fsi_smoke(spec)

"""
    run_native_resolved_fsi_navier_stokes_smoke(spec=NativeResolvedFSINavierStokesSmokeSpec())

Run a coarse fixed-wall incompressible Navier-Stokes smoke on
`NativeResolvedFSIMesh`, advancing from rest with backward-Euler time stepping
and Picard-linearized convection. The stage writes velocity, pressure, and
explicit zero displacement through the resolved-3D writer, reloads the bundle
through the importer, and reports schema, geometry, time, and field status.
This lane does not move the wall and does not include membrane coupling.
"""
function run_native_resolved_fsi_navier_stokes_smoke(
    spec::NativeResolvedFSINavierStokesSmokeSpec = NativeResolvedFSINavierStokesSmokeSpec(),
)
    validate(spec)

    mesh = native_resolved_fsi_mesh(spec.case_spec, spec.resolution)
    native_resolved_fsi_smoke_validate_mesh(mesh)
    estimated_field_payload_bytes = native_resolved_fsi_smoke_estimated_field_payload_bytes(mesh)
    estimated_field_payload_bytes <= NATIVE_RESOLVED_FSI_SMOKE_MAX_OUTPUT_BYTES || throw(ArgumentError(
        "native resolved-FSI Navier-Stokes smoke estimated raw field payload $(estimated_field_payload_bytes) bytes exceeds the $(NATIVE_RESOLVED_FSI_SMOKE_MAX_OUTPUT_BYTES)-byte cap",
    ))

    solve_result = native_resolved_fsi_solve_fixed_wall_navier_stokes(mesh, spec)
    velocity, pressure, sampling_fallback_count = native_resolved_fsi_sample_smoke_fields(
        mesh,
        solve_result.velocity,
        solve_result.pressure,
    )
    pressure, pressure_gauge_offset_dyn_cm2 = native_resolved_fsi_outlet_gauge_pressure(pressure, mesh.tags.outlet_nodes)
    displacement = native_resolved_fsi_zero_displacement(mesh)
    native_resolved_fsi_smoke_validate_finite_fields("fixed-wall Navier-Stokes smoke", velocity, pressure, displacement)

    output_dir = isempty(spec.output_dir) ? default_native_resolved_fsi_navier_stokes_smoke_output_dir(spec) : spec.output_dir
    roundtrip = native_resolved_fsi_smoke_roundtrip_bundle(
        mesh,
        output_dir,
        native_resolved_fsi_navier_stokes_smoke_case_label(spec),
        velocity,
        pressure,
        displacement;
        saved_time_s=spec.tfinal_s,
        time_atol=spec.time_atol,
        overwrite=spec.overwrite,
    )

    return NativeResolvedFSINavierStokesSmokeResult(
        spec,
        mesh,
        output_dir,
        roundtrip.writer_result.paths.mesh_h5,
        roundtrip.writer_result.paths.velocity_xdmf,
        roundtrip.writer_result.paths.velocity_h5,
        roundtrip.writer_result.paths.pressure_xdmf,
        roundtrip.writer_result.paths.pressure_h5,
        roundtrip.writer_result.paths.displacement_xdmf,
        roundtrip.writer_result.paths.displacement_h5,
        roundtrip.writer_result.time,
        NATIVE_RESOLVED_FSI_NAVIER_STOKES_SMOKE_STAGE,
        :pressure_drop_weak_inlet_outlet_gauge_smoke,
        NativeResolvedFSIWorkflowStatus(
            false,
            "local smoke boundary evidence only: Gridap solve uses pressure-drop weak inlet/outlet loading with outlet-gauge pressure; not exact Section 4.1 Poiseuille inlet / zero-outlet-stress reproduction",
        ),
        solve_result.velocity_dofs,
        solve_result.pressure_dofs,
        solve_result.time_step_count,
        solve_result.max_picard_iterations_used,
        solve_result.final_picard_update_norm,
        solve_result.picard_converged,
        sampling_fallback_count,
        pressure_gauge_offset_dyn_cm2,
        estimated_field_payload_bytes,
        roundtrip.loaded_coordinates,
        roundtrip.loaded_topology,
        roundtrip.loaded_velocity,
        roundtrip.loaded_pressure,
        roundtrip.loaded_displacement,
        roundtrip.loaded_deformed_coordinates,
        native_resolved_fsi_smoke_schema_status(roundtrip.bundle, roundtrip.writer_result, roundtrip.loaded_deformed_coordinates),
        native_resolved_fsi_smoke_geometry_status(mesh, roundtrip.loaded_coordinates, roundtrip.loaded_topology),
        native_resolved_fsi_navier_stokes_smoke_time_status(spec, roundtrip.bundle, roundtrip.writer_result),
        native_resolved_fsi_navier_stokes_smoke_field_status(
            mesh,
            roundtrip.loaded_velocity,
            roundtrip.loaded_pressure,
            roundtrip.loaded_displacement,
            roundtrip.loaded_deformed_coordinates,
            sampling_fallback_count,
            solve_result.time_step_count,
            solve_result.max_picard_iterations_used,
            solve_result.final_picard_update_norm,
            solve_result.picard_converged,
        ),
    )
end

run_native_resolved_fsi(spec::NativeResolvedFSINavierStokesSmokeSpec) = run_native_resolved_fsi_navier_stokes_smoke(spec)

"""
    run_native_resolved_fsi_partitioned_smoke(spec=NativeResolvedFSIPartitionedSmokeSpec())

Run the first staged partitioned native resolved-FSI smoke on
`NativeResolvedFSIMesh`. The fluid stage reuses the 2H backward-Euler/Picard
Navier-Stokes solve on the current lifted geometry with the reduced wall
velocity prescribed radially on the wall boundary; wall pressure is projected
onto the native axial stations, a reduced radial membrane state is updated
explicitly with clamped endpoints, the established linear volumetric lift
generates a nonzero displacement field, and a post-update fluid refresh is
performed on the saved geometry for bundle output. This is a coarse partitioned
smoke, not a monolithic paper-grade transient 3D FSI solve.
"""
function run_native_resolved_fsi_partitioned_smoke(
    spec::NativeResolvedFSIPartitionedSmokeSpec = NativeResolvedFSIPartitionedSmokeSpec(),
)
    validate(spec)

    mesh = native_resolved_fsi_mesh(spec.case_spec, spec.resolution)
    native_resolved_fsi_smoke_validate_mesh(mesh)
    estimated_field_payload_bytes = native_resolved_fsi_smoke_estimated_field_payload_bytes(mesh)
    estimated_field_payload_bytes <= NATIVE_RESOLVED_FSI_SMOKE_MAX_OUTPUT_BYTES || throw(ArgumentError(
        "native resolved-FSI partitioned smoke estimated raw field payload $(estimated_field_payload_bytes) bytes exceeds the $(NATIVE_RESOLVED_FSI_SMOKE_MAX_OUTPUT_BYTES)-byte cap",
    ))

    solve_result = native_resolved_fsi_solve_partitioned_smoke(mesh, spec)
    output_dir = isempty(spec.output_dir) ? default_native_resolved_fsi_partitioned_smoke_output_dir(spec) : spec.output_dir
    return native_resolved_fsi_partitioned_smoke_result(
        mesh,
        spec,
        solve_result;
        output_dir=output_dir,
        saved_time_s=spec.tfinal_s,
        estimated_field_payload_bytes=estimated_field_payload_bytes,
    )
end

function native_resolved_fsi_partitioned_smoke_result(
    mesh::NativeResolvedFSIMesh,
    spec::NativeResolvedFSIPartitionedSmokeSpec,
    solve_result::NativeResolvedFSIPartitionedSmokeSolve;
    output_dir::AbstractString,
    saved_time_s::Real,
    estimated_field_payload_bytes::Integer,
)
    displacement = native_resolved_fsi_lifted_displacement(mesh, solve_result.wall_displacement_cm)
    deformed_coordinates = mesh.coordinates .+ displacement
    wall_radius_at_z = native_resolved_fsi_partitioned_radius_profile(
        solve_result.wall_axial_coordinates_cm,
        solve_result.current_radii_cm,
    )
    solve_result.inlet_outlet_boundary_mode == spec.inlet_outlet_boundary_mode || throw(ArgumentError(
        "native resolved-FSI partitioned smoke solve/result inlet_outlet_boundary_mode mismatch: " *
        "spec=$(repr(spec.inlet_outlet_boundary_mode)), solve=$(repr(solve_result.inlet_outlet_boundary_mode))",
    ))
    if solve_result.inlet_outlet_boundary_mode === :poiseuille_inlet_zero_outlet_stress_section41
        isapprox(solve_result.inlet_umax_cm_s, spec.inlet_umax_cm_s; atol=0.0, rtol=1.0e-12) || throw(ArgumentError(
            "native resolved-FSI partitioned smoke solve/result inlet_umax_cm_s mismatch: " *
            "spec=$(spec.inlet_umax_cm_s), solve=$(solve_result.inlet_umax_cm_s)",
        ))
    end

    velocity, pressure, sampling_fallback_count = native_resolved_fsi_sample_smoke_fields(
        mesh,
        solve_result.velocity,
        solve_result.pressure;
        coordinates=deformed_coordinates,
        wall_radius_at_z=wall_radius_at_z,
    )
    pressure, pressure_gauge_offset_dyn_cm2 = native_resolved_fsi_outlet_gauge_pressure(pressure, mesh.tags.outlet_nodes)
    native_resolved_fsi_smoke_validate_finite_fields("partitioned native resolved-FSI smoke", velocity, pressure, displacement)

    phase_timing = native_resolved_fsi_phase_timing_accumulator()
    native_resolved_fsi_merge_phase_timing!(phase_timing, solve_result.phase_timing_s)
    output_start_ns = time_ns()
    roundtrip = native_resolved_fsi_smoke_roundtrip_bundle(
        mesh,
        output_dir,
        native_resolved_fsi_partitioned_smoke_case_label(spec),
        velocity,
        pressure,
        displacement;
        saved_time_s=Float64(saved_time_s),
        time_atol=spec.time_atol,
        overwrite=spec.overwrite,
    )
    native_resolved_fsi_add_phase_timing!(
        phase_timing,
        :output_write_s,
        native_resolved_fsi_phase_elapsed_s(output_start_ns),
    )

    minimum_current_radius_cm = minimum(solve_result.current_radii_cm)

    return NativeResolvedFSIPartitionedSmokeResult(
        spec,
        mesh,
        output_dir,
        roundtrip.writer_result.paths.mesh_h5,
        roundtrip.writer_result.paths.velocity_xdmf,
        roundtrip.writer_result.paths.velocity_h5,
        roundtrip.writer_result.paths.pressure_xdmf,
        roundtrip.writer_result.paths.pressure_h5,
        roundtrip.writer_result.paths.displacement_xdmf,
        roundtrip.writer_result.paths.displacement_h5,
        roundtrip.writer_result.time,
        NATIVE_RESOLVED_FSI_PARTITIONED_SMOKE_STAGE,
        solve_result.inlet_outlet_boundary_mode,
        NativeResolvedFSIWorkflowStatus(
            solve_result.inlet_outlet_boundary_mode === :poiseuille_inlet_zero_outlet_stress_section41,
            solve_result.inlet_outlet_boundary_status,
        ),
        solve_result.velocity_dofs,
        solve_result.pressure_dofs,
        solve_result.time_step_count,
        solve_result.max_picard_iterations_used,
        solve_result.final_picard_update_norm,
        solve_result.picard_converged,
        solve_result.max_coupling_iterations_used,
        solve_result.final_coupling_displacement_residual_cm,
        solve_result.coupling_converged,
        solve_result.fluid_wall_boundary_mode,
        solve_result.coupling_residual_history,
        solve_result.post_update_fluid_refresh,
        solve_result.wall_axial_coordinates_cm,
        solve_result.wall_displacement_cm,
        solve_result.wall_velocity_cm_s,
        solve_result.wall_pressure_dyn_cm2,
        solve_result.current_radii_cm,
        solve_result.wall_mass_g_cm2,
        solve_result.wall_stiffness_c0_dyn_cm3,
        spec.wall_damping_g_cm2_s,
        solve_result.stability_dt_limit_s,
        minimum_current_radius_cm,
        solve_result.minimum_signed_tetra_volume6,
        solve_result.pressure_projection_fallback_count,
        sampling_fallback_count,
        pressure_gauge_offset_dyn_cm2,
        solve_result.solver_diagnostics,
        native_resolved_fsi_phase_timing_named_tuple(phase_timing),
        Int(estimated_field_payload_bytes),
        roundtrip.loaded_coordinates,
        roundtrip.loaded_topology,
        roundtrip.loaded_velocity,
        roundtrip.loaded_pressure,
        roundtrip.loaded_displacement,
        roundtrip.loaded_deformed_coordinates,
        native_resolved_fsi_smoke_schema_status(roundtrip.bundle, roundtrip.writer_result, roundtrip.loaded_deformed_coordinates),
        native_resolved_fsi_smoke_geometry_status(mesh, roundtrip.loaded_coordinates, roundtrip.loaded_topology),
        native_resolved_fsi_partitioned_smoke_time_status(spec, roundtrip.bundle, roundtrip.writer_result),
        native_resolved_fsi_partitioned_smoke_field_status(
            mesh,
            roundtrip.loaded_velocity,
            roundtrip.loaded_pressure,
            roundtrip.loaded_displacement,
            roundtrip.loaded_deformed_coordinates,
            solve_result.wall_displacement_cm,
            solve_result.wall_velocity_cm_s,
            solve_result.wall_pressure_dyn_cm2,
            solve_result.current_radii_cm,
            sampling_fallback_count,
            solve_result.pressure_projection_fallback_count,
            solve_result.time_step_count,
            solve_result.max_picard_iterations_used,
            solve_result.final_picard_update_norm,
            solve_result.picard_converged,
            solve_result.max_coupling_iterations_used,
            solve_result.final_coupling_displacement_residual_cm,
            solve_result.coupling_converged,
            solve_result.fluid_wall_boundary_mode,
            minimum_current_radius_cm,
            solve_result.minimum_signed_tetra_volume6,
            solve_result.post_update_fluid_refresh,
        ),
    )
end

run_native_resolved_fsi(spec::NativeResolvedFSIPartitionedSmokeSpec) = run_native_resolved_fsi_partitioned_smoke(spec)

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

function native_resolved_fsi_navier_stokes_smoke_case_label(spec::NativeResolvedFSINavierStokesSmokeSpec)
    resolution = spec.resolution
    mesh_token = "$(resolution.axial)x$(resolution.radial)x$(resolution.angular)"
    return "native-$(spec.case_spec.case_id)-$(mesh_token)-fixed-wall-navier-stokes-smoke"
end

function native_resolved_fsi_partitioned_smoke_case_label(spec::NativeResolvedFSIPartitionedSmokeSpec)
    resolution = spec.resolution
    mesh_token = "$(resolution.axial)x$(resolution.radial)x$(resolution.angular)"
    return "native-$(spec.case_spec.case_id)-$(mesh_token)-partitioned-smoke"
end
