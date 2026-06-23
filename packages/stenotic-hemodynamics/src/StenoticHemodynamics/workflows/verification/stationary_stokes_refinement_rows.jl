"""
    stationary_stokes_row_from_scratch(item, reference)

Convert one scratch result bundle into the stable row schema written to CSV/TEX.
The `reference` row is the largest successful mesh for the same severity and is
used only for the finest-mesh relative discrepancy columns.
"""
function stationary_stokes_row_from_scratch(item, reference)
    finest_u_error = item.status == "ok" && reference !== nothing ? relative_l2_error(item.fe_u, reference.fe_u) : NaN
    finest_pressure_error =
        item.status == "ok" && reference !== nothing ? relative_l2_error(item.fe_pressure, reference.fe_pressure) : NaN
    return StationaryStokesRefinementRow(
        case_id=item.case_id,
        severity=item.severity,
        pressure_drop_pa=item.pressure_drop_pa,
        mesh_nz=item.mesh_nz,
        mesh_nr=item.mesh_nr,
        mesh_ntheta=item.mesh_ntheta,
        projection_nr=item.projection_nr,
        projection_ntheta=item.projection_ntheta,
        mesh_nodes=item.mesh_nodes,
        mesh_cells=item.mesh_cells,
        velocity_dofs=item.velocity_dofs,
        pressure_dofs=item.pressure_dofs,
        elapsed_s=item.elapsed_s,
        mean_flow=item.mean_flow,
        fe_uavg_min=finite_min(item.fe_u),
        fe_uavg_max=finite_max(item.fe_u),
        projection_uavg_min=finite_min(item.projected_u),
        projection_uavg_max=finite_max(item.projected_u),
        fe_pressure_min=finite_min(item.fe_pressure),
        fe_pressure_max=finite_max(item.fe_pressure),
        projection_pressure_min=finite_min(item.projected_pressure),
        projection_pressure_max=finite_max(item.projected_pressure),
        fe_projection_u_l2_relative_error=item.fe_projection_u_l2_relative_error,
        fe_projection_pressure_l2_relative_error=item.fe_projection_pressure_l2_relative_error,
        finest_u_l2_relative_error=finest_u_error,
        finest_pressure_l2_relative_error=finest_pressure_error,
        traction_samples=item.traction.samples,
        wall_traction_mean=item.traction.traction_mean,
        wall_traction_max=item.traction.traction_max,
        wss_mean=item.traction.wss_mean,
        wss_max=item.traction.wss_max,
        status=item.status,
        error_message=item.error_message,
    )
end

function stationary_stokes_case_id(severity::Float64, mesh::NTuple{3,Int})
    nz, nr, ntheta = mesh
    return "stokes-s$(path_token(severity))-$(nz)x$(nr)x$(ntheta)"
end

"""
    relative_l2_error(values, reference)

Return the root-mean-square relative L2 discrepancy between two vectors.
Mismatched or empty inputs return `NaN`.
"""
function relative_l2_error(values::Vector{Float64}, reference::Vector{Float64})
    length(values) == length(reference) || return NaN
    isempty(values) && return NaN
    error_accum = 0.0
    reference_accum = 0.0
    for (value, ref) in zip(values, reference)
        error_accum += (value - ref)^2
        reference_accum += ref^2
    end
    error_norm = sqrt(error_accum / length(values))
    reference_norm = sqrt(reference_accum / length(values))
    reference_norm > 0.0 || return error_norm
    return error_norm / reference_norm
end

finite_mean(values::Vector{Float64}) = isempty(values) ? NaN : sum(values) / length(values)
finite_min(values::Vector{Float64}) = isempty(values) ? NaN : minimum(values)
finite_max(values::Vector{Float64}) = isempty(values) ? NaN : maximum(values)
