const DEFAULT_OPERATOR_VALIDATION_OUTPUT_DIR = joinpath("julia", "simulations", "output", "operator_validation")
const DEFAULT_OPERATOR_VALIDATION_Z_SAMPLES = Float64[0.25, 0.5, 0.75]
const DEFAULT_OPERATOR_VALIDATION_PLANE_SHIFTS = Float64[-0.05, 0.0, 0.05]
const DEFAULT_OPERATOR_VALIDATION_AFFINE_COEFFICIENTS = (2.0, 3.0, 5.0, 7.0)

"""
    OperatorValidationSpec(; output_dir, sample_z_cm, plane_shift_center_cm, ...)

Deterministic synthetic validation for `CrossSectionQuadratureOperator`. The
workflow uses an in-memory tetrahedral mesh with node-centered axial fields, so
it has no dependency on resolved-3D HDF5/XDMF data.
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

"""One row from the synthetic cross-section operator validation workflow."""
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

"""Return value from `run_operator_validation`."""
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

default_output_paths(spec::OperatorValidationSpec) = (
    summary_csv=operator_validation_csv_path(spec),
    summary_tex=operator_validation_tex_path(spec),
)

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

function synthetic_operator_validation_field(coefficients::NTuple{4,Float64})
    coordinates = [
        0.0 0.0 0.0
        1.0 0.0 0.0
        0.0 1.0 0.0
        0.0 0.0 1.0
    ]
    velocity = zeros(Float64, size(coordinates, 1), 3)
    for i in axes(coordinates, 1)
        velocity[i, 3] = affine_axial_value(
            coefficients,
            (coordinates[i, 1], coordinates[i, 2], coordinates[i, 3]),
        )
    end
    case = Resolved3DCaseSpec("operator-validation", 0.0, "synthetic://operator-validation"; target_time=0.0)
    metadata = XDMFVelocityMetadata(
        0.0,
        "synthetic",
        "/geometry",
        size(coordinates),
        "synthetic",
        "/topology",
        (1, 4),
        "synthetic",
        "/velocity",
        size(velocity),
    )
    return Resolved3DVelocityField(case, metadata, [1 2 3 4], coordinates, velocity)
end

function operator_validation_row(
    validation_case::String,
    field::Resolved3DVelocityField,
    coefficients::NTuple{4,Float64},
    z::Float64,
    shift::Float64,
    baseline,
    tolerance::Float64,
)
    observation = quadrature_section_observation(field, z)
    reference = operator_validation_reference(field, coefficients, z)
    area_error = abs_or_nan(observation.area_cm2, reference.area_cm2)
    flow_error = abs_or_nan(observation.flow_cm3_s, reference.flow_cm3_s)
    mean_error = abs_or_nan(observation.mean_velocity_cm_s, reference.mean_velocity_cm_s)
    area_delta = baseline === nothing ? NaN : observation.area_cm2 - baseline.area_cm2
    flow_delta = baseline === nothing ? NaN : observation.flow_cm3_s - baseline.flow_cm3_s
    mean_delta = baseline === nothing ? NaN : observation.mean_velocity_cm_s - baseline.mean_velocity_cm_s
    status = operator_validation_status(
        observation,
        (area_error, flow_error, mean_error, reference.max_triangle_mean_error_cm_s),
        tolerance,
    )
    return OperatorValidationRow(
        validation_case,
        z,
        shift,
        observation.area_cm2,
        reference.area_cm2,
        area_error,
        observation.flow_cm3_s,
        reference.flow_cm3_s,
        flow_error,
        observation.mean_velocity_cm_s,
        reference.mean_velocity_cm_s,
        mean_error,
        area_delta,
        flow_delta,
        mean_delta,
        observation.intersection_count,
        reference.max_triangle_mean_error_cm_s,
        observation.cut_status,
        status,
    )
end

function operator_validation_reference(
    field::Resolved3DVelocityField,
    coefficients::NTuple{4,Float64},
    z::Float64,
)
    area = 0.0
    flow = 0.0
    triangle_count = 0
    max_triangle_error = 0.0

    for tet in eachrow(field.topology)
        polygon = tetra_plane_polygon(field, tet, z)
        length(polygon) >= 3 || continue
        center = polygon_center(polygon)
        for i in eachindex(polygon)
            p1 = polygon[i]
            p2 = polygon[mod1(i + 1, length(polygon))]
            tri_area = triangle_area_xy(center, p1, p2)
            tri_area > 1.0e-14 || continue
            centroid = triangle_centroid_xyz(center, p1, p2)
            exact_mean = affine_axial_value(coefficients, centroid)
            observed_triangle_mean = (center[4] + p1[4] + p2[4]) / 3.0
            max_triangle_error = max(max_triangle_error, abs(observed_triangle_mean - exact_mean))
            area += tri_area
            flow += tri_area * exact_mean
            triangle_count += 1
        end
    end

    area_valid = area > 0.0 && isfinite(area)
    return (
        area_cm2=area_valid ? area : NaN,
        flow_cm3_s=area_valid ? flow : NaN,
        mean_velocity_cm_s=area_valid ? flow / area : NaN,
        intersection_count=triangle_count,
        max_triangle_mean_error_cm_s=triangle_count > 0 ? max_triangle_error : NaN,
    )
end

function triangle_centroid_xyz(center, p1, p2)
    return (
        (center[1] + p1[1] + p2[1]) / 3.0,
        (center[2] + p1[2] + p2[2]) / 3.0,
        (center[3] + p1[3] + p2[3]) / 3.0,
    )
end

function affine_axial_value(coefficients::NTuple{4,Float64}, point)
    return coefficients[1] + coefficients[2] * point[1] + coefficients[3] * point[2] + coefficients[4] * point[3]
end

function operator_validation_status(observation, errors, tolerance::Float64)
    observation.area_valid || return "fail"
    all(error -> isfinite(error) && error <= tolerance, errors) && return "pass"
    return "fail"
end

const OPERATOR_VALIDATION_HEADER = [
    "validation_case",
    "z_cm",
    "shift_cm",
    "area_cm2",
    "expected_area_cm2",
    "area_abs_error_cm2",
    "flow_cm3_s",
    "expected_flow_cm3_s",
    "flow_abs_error_cm3_s",
    "mean_velocity_cm_s",
    "expected_mean_velocity_cm_s",
    "mean_abs_error_cm_s",
    "area_delta_cm2",
    "flow_delta_cm3_s",
    "mean_velocity_delta_cm_s",
    "intersection_count",
    "max_triangle_mean_error_cm_s",
    "cut_status",
    "status",
]

function write_operator_validation_csv(path::String, rows::Vector{OperatorValidationRow}; overwrite::Bool = false)
    return write_csv_table(path, OPERATOR_VALIDATION_HEADER, (operator_validation_csv_values(row) for row in rows); overwrite)
end

function operator_validation_csv_values(row::OperatorValidationRow)
    return Any[
        row.validation_case,
        row.z_cm,
        row.shift_cm,
        row.area_cm2,
        row.expected_area_cm2,
        row.area_abs_error_cm2,
        row.flow_cm3_s,
        row.expected_flow_cm3_s,
        row.flow_abs_error_cm3_s,
        row.mean_velocity_cm_s,
        row.expected_mean_velocity_cm_s,
        row.mean_abs_error_cm_s,
        row.area_delta_cm2,
        row.flow_delta_cm3_s,
        row.mean_velocity_delta_cm_s,
        row.intersection_count,
        row.max_triangle_mean_error_cm_s,
        row.cut_status,
        row.status,
    ]
end

function write_operator_validation_tex(path::String, rows::Vector{OperatorValidationRow}; overwrite::Bool = false)
    guarded_open_write(path, overwrite) do io
        println(io, "% Generated by run_operator_validation; input mesh and fields are synthetic.")
        println(io, "\\begin{tabular}{lrrrrrrrl}")
        println(io, "\\toprule")
        println(io, "case & z & shift & area & flow err. & mean err. & shift \$\\Delta A\$ & shift \$\\Delta \\bar u\$ & status \\\\")
        println(io, "\\midrule")
        for row in rows
            println(io, operator_validation_latex_row(row))
        end
        println(io, "\\bottomrule")
        println(io, "\\end{tabular}")
    end
    return path
end

function operator_validation_latex_row(row::OperatorValidationRow)
    return join(
        [
            replace(row.validation_case, "_" => "\\_"),
            latex_number(row.z_cm),
            latex_number(row.shift_cm),
            latex_number(row.area_cm2),
            latex_number(row.flow_abs_error_cm3_s),
            latex_number(row.mean_abs_error_cm_s),
            latex_number(row.area_delta_cm2),
            latex_number(row.mean_velocity_delta_cm_s),
            row.status,
        ],
        " & ",
    ) * " \\\\"
end
