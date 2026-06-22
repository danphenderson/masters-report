"""
    run_operator_validation(spec=OperatorValidationSpec())

Run the synthetic cross-section operator validation workflow and write the CSV
and TeX summary artifacts declared by `default_output_paths(spec)`.
"""
function run_operator_validation(spec::OperatorValidationSpec = OperatorValidationSpec())
    validate_workflow_spec(spec)
    constant_coefficients = (spec.constant_value_cm_s, 0.0, 0.0, 0.0)
    constant_field = synthetic_operator_validation_field(constant_coefficients)
    affine_field = synthetic_operator_validation_field(spec.affine_coefficients)

    rows = OperatorValidationRow[]
    for z in spec.sample_z_cm
        push!(rows, operator_validation_row("constant", constant_field, constant_coefficients, z, 0.0, nothing, spec.tolerance))
    end
    for z in spec.sample_z_cm
        push!(rows, operator_validation_row("affine", affine_field, spec.affine_coefficients, z, 0.0, nothing, spec.tolerance))
    end

    baseline_z = spec.plane_shift_center_cm
    baseline = quadrature_section_observation(affine_field, baseline_z)
    for shift in spec.plane_shifts_cm
        z = baseline_z + shift
        push!(
            rows,
            operator_validation_row("plane_shift", affine_field, spec.affine_coefficients, z, shift, baseline, spec.tolerance),
        )
    end

    paths = default_output_paths(spec)
    write_operator_validation_csv(paths.summary_csv, rows; overwrite=spec.overwrite)
    write_operator_validation_tex(paths.summary_tex, rows; overwrite=spec.overwrite)
    return OperatorValidationResult(spec, rows, paths.summary_csv, paths.summary_tex)
end
