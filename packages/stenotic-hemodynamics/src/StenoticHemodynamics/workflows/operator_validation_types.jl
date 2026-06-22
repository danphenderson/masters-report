const DEFAULT_OPERATOR_VALIDATION_OUTPUT_DIR = joinpath(DEFAULT_SIMULATION_OUTPUT_ROOT, "operator_validation")
const DEFAULT_OPERATOR_VALIDATION_Z_SAMPLES = Float64[0.25, 0.5, 0.75]
const DEFAULT_OPERATOR_VALIDATION_PLANE_SHIFTS = Float64[-0.05, 0.0, 0.05]
const DEFAULT_OPERATOR_VALIDATION_AFFINE_COEFFICIENTS = (2.0, 3.0, 5.0, 7.0)

"""
    OperatorValidationSpec(; output_dir, sample_z_cm, plane_shift_center_cm, ...)

Deterministic synthetic validation for `CrossSectionQuadratureOperator`. The
workflow uses an in-memory tetrahedral field with node-centered axial velocity,
so it does not depend on resolved-3D XDMF/HDF5 inputs.
"""
struct OperatorValidationSpec <: AbstractStudySpec
    output_dir::String
    summary_csv::String
    summary_tex::String
    sample_z_cm::Vector{Float64}
    plane_shift_center_cm::Float64
    plane_shifts_cm::Vector{Float64}
    constant_value_cm_s::Float64
    affine_coefficients::NTuple{4,Float64}
    tolerance::Float64
    overwrite::Bool
end

function OperatorValidationSpec(;
    output_dir::String = DEFAULT_OPERATOR_VALIDATION_OUTPUT_DIR,
    summary_csv::String = "",
    summary_tex::String = "",
    sample_z_cm = DEFAULT_OPERATOR_VALIDATION_Z_SAMPLES,
    plane_shift_center_cm::Real = 0.5,
    plane_shifts_cm = DEFAULT_OPERATOR_VALIDATION_PLANE_SHIFTS,
    constant_value_cm_s::Real = 12.25,
    affine_coefficients = DEFAULT_OPERATOR_VALIDATION_AFFINE_COEFFICIENTS,
    tolerance::Real = 1.0e-11,
    overwrite::Bool = false,
)
    return OperatorValidationSpec(
        output_dir,
        summary_csv,
        summary_tex,
        [Float64(z) for z in sample_z_cm],
        Float64(plane_shift_center_cm),
        [Float64(shift) for shift in plane_shifts_cm],
        Float64(constant_value_cm_s),
        operator_validation_coefficients(affine_coefficients),
        Float64(tolerance),
        overwrite,
    )
end

"""
    OperatorValidationRow

One output row from the synthetic cross-section operator validation workflow.
Each row records observed values, analytic references, and bounded pass/fail
status for one validation case and plane location.
"""
struct OperatorValidationRow
    validation_case::String
    z_cm::Float64
    shift_cm::Float64
    area_cm2::Float64
    expected_area_cm2::Float64
    area_abs_error_cm2::Float64
    flow_cm3_s::Float64
    expected_flow_cm3_s::Float64
    flow_abs_error_cm3_s::Float64
    mean_velocity_cm_s::Float64
    expected_mean_velocity_cm_s::Float64
    mean_abs_error_cm_s::Float64
    area_delta_cm2::Float64
    flow_delta_cm3_s::Float64
    mean_velocity_delta_cm_s::Float64
    intersection_count::Int
    max_triangle_mean_error_cm_s::Float64
    cut_status::String
    status::String
end

"""
    OperatorValidationResult

Return value from `run_operator_validation`, including the materialized CSV and
TeX summary artifact paths.
"""
struct OperatorValidationResult{S<:OperatorValidationSpec}
    spec::S
    rows::Vector{OperatorValidationRow}
    summary_csv::String
    summary_tex::String
end

workflow_kind(::OperatorValidationSpec) = "cross_section_operator_validation"

function validate(spec::OperatorValidationSpec)
    !isempty(spec.sample_z_cm) || throw(ArgumentError("operator validation requires at least one sample z-location"))
    !isempty(spec.plane_shifts_cm) || throw(ArgumentError("operator validation requires at least one plane shift"))
    all(isfinite, spec.sample_z_cm) || throw(ArgumentError("all sample z-locations must be finite"))
    all(isfinite, spec.plane_shifts_cm) || throw(ArgumentError("all plane shifts must be finite"))
    all(z -> 0.0 <= z < 1.0, spec.sample_z_cm) ||
        throw(ArgumentError("synthetic operator-validation sample z-locations must lie in [0, 1)"))
    all(shift -> 0.0 <= spec.plane_shift_center_cm + shift < 1.0, spec.plane_shifts_cm) ||
        throw(ArgumentError("plane_shift_center_cm + shift must lie in [0, 1) for every shift"))
    isfinite(spec.constant_value_cm_s) || throw(ArgumentError("constant_value_cm_s must be finite"))
    all(isfinite, spec.affine_coefficients) || throw(ArgumentError("affine coefficients must be finite"))
    spec.tolerance > 0.0 || throw(ArgumentError("operator validation tolerance must be positive"))
    return spec
end

function operator_validation_coefficients(values)
    coeffs = collect(values)
    length(coeffs) == 4 || throw(ArgumentError("affine_coefficients must contain c0,cx,cy,cz"))
    return ntuple(i -> Float64(coeffs[i]), 4)
end

function operator_validation_csv_path(spec::OperatorValidationSpec)
    !isempty(spec.summary_csv) && return spec.summary_csv
    return joinpath(spec.output_dir, "cross_section_operator_validation.csv")
end

function operator_validation_tex_path(spec::OperatorValidationSpec)
    !isempty(spec.summary_tex) && return spec.summary_tex
    return joinpath(spec.output_dir, "cross_section_operator_validation.tex")
end

function operator_validation_spec_from_values(values::Dict{String,String}, flags::Set{String})
    return OperatorValidationSpec(;
        output_dir=get(values, "output-dir", DEFAULT_OPERATOR_VALIDATION_OUTPUT_DIR),
        summary_csv=get(values, "summary-csv", ""),
        summary_tex=get(values, "summary-tex", ""),
        sample_z_cm=parse_float_list(get(values, "sample-z", join(DEFAULT_OPERATOR_VALIDATION_Z_SAMPLES, ","))),
        plane_shift_center_cm=parse(Float64, get(values, "plane-center", "0.5")),
        plane_shifts_cm=parse_float_list(get(values, "plane-shifts", join(DEFAULT_OPERATOR_VALIDATION_PLANE_SHIFTS, ","))),
        constant_value_cm_s=parse(Float64, get(values, "constant-value", "12.25")),
        affine_coefficients=parse_float_list(
            get(values, "affine-coefficients", join(DEFAULT_OPERATOR_VALIDATION_AFFINE_COEFFICIENTS, ",")),
        ),
        tolerance=parse(Float64, get(values, "tolerance", "1.0e-11")),
        overwrite=("overwrite" in flags),
    )
end

default_output_paths(spec::OperatorValidationSpec) = (
    summary_csv=operator_validation_csv_path(spec),
    summary_tex=operator_validation_tex_path(spec),
)
