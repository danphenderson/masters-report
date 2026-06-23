"""
    run_manufactured_verification(spec=ManufacturedVerificationSpec())

Run the manufactured-solution verification workflow, write its summary tables,
and return the in-memory rows and output paths.
"""
function run_manufactured_verification(spec::ManufacturedVerificationSpec = ManufacturedVerificationSpec())
    validate_workflow_spec(spec)
    spatial_rows = manufactured_group_rows(
        "spatial",
        spec,
        [(nx=nx, dt=minimum(spec.dt_values)) for nx in sort(spec.nxs)],
    )
    temporal_rows = manufactured_group_rows(
        "temporal",
        spec,
        [(nx=maximum(spec.nxs), dt=dt) for dt in sort(spec.dt_values; rev=true)],
    )
    rows = vcat(spatial_rows, temporal_rows)
    paths = default_output_paths(spec)
    csv_path = paths.summary_csv
    tex_path = paths.summary_tex
    write_manufactured_verification_csv(csv_path, rows; overwrite=spec.overwrite)
    write_manufactured_verification_tex(tex_path, rows; overwrite=spec.overwrite)
    return ManufacturedVerificationResult(spec, rows, csv_path, tex_path)
end

function manufactured_group_rows(study_kind::String, spec::ManufacturedVerificationSpec, cases)
    scratch = ManufacturedVerificationRow[]
    for case in cases
        push!(scratch, manufactured_verification_case(study_kind, spec, case.nx, case.dt))
    end
    return assign_manufactured_orders(scratch)
end

function manufactured_verification_case(study_kind::String, spec::ManufacturedVerificationSpec, nx::Int, dt::Float64)
    params = params_with(spec.base_params; nx=nx, dt=dt)
    try
        result = simulate(params, spec.backend; progress_every=spec.progress_every)
        exact_A = [manufactured_area(params.forcing, zi, result.completed_time, params) for zi in result.z]
        exact_Q = [manufactured_flow(params.forcing, zi, result.completed_time, params) for zi in result.z]
        forcing_audit = manufactured_forcing_residual_audit(params)
        return ManufacturedVerificationRow(
            study_kind=study_kind,
            nx=nx,
            dx=params.length_cm / nx,
            dt=dt,
            tfinal=params.tfinal,
            area_l1_error=l1_error(result.area, exact_A),
            area_l2_error=l2_error(result.area, exact_A),
            area_linf_error=linf_error(result.area, exact_A),
            area_observed_order=NaN,
            flow_l1_error=l1_error(result.flow, exact_Q),
            flow_l2_error=l2_error(result.flow, exact_Q),
            flow_linf_error=linf_error(result.flow, exact_Q),
            flow_observed_order=NaN,
            accepted_dt_min=result.diagnostics.dt_min,
            accepted_dt_max=result.diagnostics.dt_max,
            realized_cfl_max=result.diagnostics.cfl_max,
            independent_mass_forcing_max_abs_diff=forcing_audit.mass_max_abs_diff,
            independent_momentum_forcing_max_abs_diff=forcing_audit.momentum_max_abs_diff,
            status="ok",
            error_message="",
        )
    catch err
        return ManufacturedVerificationRow(
            study_kind=study_kind,
            nx=nx,
            dx=params.length_cm / nx,
            dt=dt,
            tfinal=params.tfinal,
            area_l1_error=NaN,
            area_l2_error=NaN,
            area_linf_error=NaN,
            area_observed_order=NaN,
            flow_l1_error=NaN,
            flow_l2_error=NaN,
            flow_linf_error=NaN,
            flow_observed_order=NaN,
            accepted_dt_min=NaN,
            accepted_dt_max=NaN,
            realized_cfl_max=NaN,
            independent_mass_forcing_max_abs_diff=NaN,
            independent_momentum_forcing_max_abs_diff=NaN,
            status="error",
            error_message=sprint(showerror, err),
        )
    end
end

function assign_manufactured_orders(rows::Vector{ManufacturedVerificationRow})
    output = ManufacturedVerificationRow[]
    for i in eachindex(rows)
        current = rows[i]
        next_row = i < lastindex(rows) ? rows[i + 1] : nothing
        ratio = if next_row === nothing
            NaN
        elseif current.study_kind == "spatial"
            current.dx / next_row.dx
        else
            current.dt / next_row.dt
        end
        area_order = next_row === nothing ? NaN : observed_order_ratio(current.area_l2_error, next_row.area_l2_error, ratio)
        flow_order = next_row === nothing ? NaN : observed_order_ratio(current.flow_l2_error, next_row.flow_l2_error, ratio)
        if current.study_kind != "spatial"
            area_order = NaN
            flow_order = NaN
        end
        push!(
            output,
            ManufacturedVerificationRow(
                study_kind=current.study_kind,
                nx=current.nx,
                dx=current.dx,
                dt=current.dt,
                tfinal=current.tfinal,
                area_l1_error=current.area_l1_error,
                area_l2_error=current.area_l2_error,
                area_linf_error=current.area_linf_error,
                area_observed_order=area_order,
                flow_l1_error=current.flow_l1_error,
                flow_l2_error=current.flow_l2_error,
                flow_linf_error=current.flow_linf_error,
                flow_observed_order=flow_order,
                accepted_dt_min=current.accepted_dt_min,
                accepted_dt_max=current.accepted_dt_max,
                realized_cfl_max=current.realized_cfl_max,
                independent_mass_forcing_max_abs_diff=current.independent_mass_forcing_max_abs_diff,
                independent_momentum_forcing_max_abs_diff=current.independent_momentum_forcing_max_abs_diff,
                status=current.status,
                error_message=current.error_message,
            ),
        )
    end
    return output
end

function l1_error(values::AbstractVector{Float64}, references::AbstractVector{Float64})
    check_error_vectors(values, references)
    return mean(abs(values[i] - references[i]) for i in eachindex(values))
end

function l2_error(values::AbstractVector{Float64}, references::AbstractVector{Float64})
    check_error_vectors(values, references)
    return sqrt(mean((values[i] - references[i])^2 for i in eachindex(values)))
end

function linf_error(values::AbstractVector{Float64}, references::AbstractVector{Float64})
    check_error_vectors(values, references)
    return maximum(abs(values[i] - references[i]) for i in eachindex(values))
end

function check_error_vectors(values::AbstractVector{Float64}, references::AbstractVector{Float64})
    length(values) == length(references) || throw(DimensionMismatch("error vectors must have matching length"))
    !isempty(values) || throw(ArgumentError("error vectors must be nonempty"))
    return nothing
end
