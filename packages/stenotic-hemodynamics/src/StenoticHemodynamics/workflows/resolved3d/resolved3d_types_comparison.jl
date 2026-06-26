"""
    ComparisonSpec(; cases, base_params, backend, operator, output_dir, ...)

Workflow spec for comparing imported resolved-3D reference cases against 1D
runs. The arrays consumed by comparison code are package-native matrices and
vectors; XDMF/HDF5 parsing stays outside this contract surface.
"""
struct ComparisonSpec{B<:AbstractTimeBackend,O<:AbstractResolved3DOperator} <: AbstractStudySpec
    cases::Vector{Resolved3DCaseSpec}
    base_params::Params
    backend::B
    case_workers::Int
    solver_threads::Int
    operator::O
    output_dir::String
    section_count::Int
    profile_slices::Vector{Float64}
    radial_bins::Int
    radial_bin_counts::Vector{Int}
    radial_radius_modes::Vector{String}
    node_slab_half_widths::Vector{Float64}
    coordinate_mode::String
    overwrite::Bool
    progress_every::Int
    write_svg::Bool
end

function ComparisonSpec(;
    cases = default_resolved3d_cases(),
    base_params::Params = Params(tfinal=0.9995, initial_condition=GeometryRestIC()),
    backend = NativeRK3Backend(),
    case_workers::Integer = default_case_workers(),
    solver_threads::Integer = solver_thread_count(backend),
    operator = CrossSectionQuadratureOperator(),
    output_dir::String = DEFAULT_COMPARISON_OUTPUT_DIR,
    section_count::Int = 200,
    profile_slices = nothing,
    radial_bins::Int = 20,
    radial_bin_counts = nothing,
    radial_radius_modes = nothing,
    node_slab_half_widths = nothing,
    coordinate_mode::AbstractString = "reference",
    overwrite::Bool = false,
    progress_every::Int = 0,
    write_svg::Bool = true,
)
    backend isa AbstractTimeBackend || throw(ArgumentError("backend must subtype AbstractTimeBackend"))
    case_workers >= 0 || throw(ArgumentError("case_workers must be nonnegative"))
    solver_threads >= 1 || throw(ArgumentError("solver_threads must be positive"))
    if solver_threads > 1 && !(backend isa NativeRK3Backend)
        throw(ArgumentError("solver_threads > 1 is only supported by the native backend"))
    end
    configured_backend = backend isa NativeRK3Backend ? NativeRK3Backend(; solver_threads=solver_threads) : backend
    operator isa AbstractResolved3DOperator || throw(ArgumentError("operator must subtype AbstractResolved3DOperator"))
    case_values = Resolved3DCaseSpec[case for case in cases]
    isempty(case_values) && throw(ArgumentError("comparison spec must include at least one case"))
    section_count >= 2 || throw(ArgumentError("section_count must be at least 2"))
    radial_bins >= 1 || throw(ArgumentError("radial_bins must be positive"))
    progress_every >= 0 || throw(ArgumentError("progress_every must be nonnegative"))
    validate(base_params)

    slices = if profile_slices === nothing
        default_profile_slices(base_params)
    else
        [Float64(z) for z in profile_slices]
    end
    isempty(slices) && throw(ArgumentError("profile_slices must include at least one z-location"))

    for z in slices
        0.0 <= z <= base_params.length_cm ||
            throw(ArgumentError("profile slice z=$(z) lies outside [0, $(base_params.length_cm)]"))
    end
    widths = if node_slab_half_widths === nothing
        current_half_width = max(0.5 * base_params.length_cm / (section_count - 1), DEFAULT_NODE_SLAB_HALF_WIDTH_CM)
        Float64[0.0075, current_half_width, 0.0301507538]
    else
        [Float64(width) for width in node_slab_half_widths]
    end
    all(>(0.0), widths) || throw(ArgumentError("node-slab half widths must be positive"))
    bin_counts = if radial_bin_counts === nothing
        Int[radial_bins]
    else
        sort!(unique([Int(value) for value in radial_bin_counts]))
    end
    !isempty(bin_counts) || throw(ArgumentError("radial_bin_counts must include at least one bin count"))
    all(count -> count >= 1, bin_counts) || throw(ArgumentError("all radial bin counts must be positive"))
    radius_modes = if radial_radius_modes === nothing
        String["current"]
    else
        [replace(lowercase(strip(string(mode))), "_" => "-") for mode in radial_radius_modes]
    end
    !isempty(radius_modes) || throw(ArgumentError("radial_radius_modes must include at least one mode"))
    all(mode -> mode in ("current", "reference"), radius_modes) ||
        throw(ArgumentError("radial_radius_modes must contain only current or reference"))
    coordinate_mode_value = replace(lowercase(strip(String(coordinate_mode))), "_" => "-")
    coordinate_mode_value in ("reference", "deformed") ||
        throw(ArgumentError("coordinate_mode must be reference or deformed"))

    return ComparisonSpec{typeof(configured_backend),typeof(operator)}(
        case_values,
        base_params,
        configured_backend,
        Int(case_workers),
        Int(solver_threads),
        operator,
        output_dir,
        section_count,
        slices,
        radial_bins,
        bin_counts,
        radius_modes,
        widths,
        coordinate_mode_value,
        overwrite,
        progress_every,
        write_svg,
    )
end

workflow_kind(::ComparisonSpec) = "resolved3d_comparison"

function validate(spec::ComparisonSpec)
    isempty(spec.cases) && throw(ArgumentError("comparison spec must include at least one case"))
    validate(spec.base_params)
    assert_backend_supported(spec.base_params.space, spec.backend)
    spec.case_workers >= 0 || throw(ArgumentError("case_workers must be nonnegative"))
    spec.solver_threads >= 1 || throw(ArgumentError("solver_threads must be positive"))
    if spec.solver_threads > 1 && !(spec.backend isa NativeRK3Backend)
        throw(ArgumentError("solver_threads > 1 is only supported by the native backend"))
    end
    spec.section_count >= 2 || throw(ArgumentError("section_count must be at least 2"))
    !isempty(spec.profile_slices) || throw(ArgumentError("profile_slices must include at least one z-location"))
    all(z -> 0.0 <= z <= spec.base_params.length_cm, spec.profile_slices) ||
        throw(ArgumentError("profile_slices must lie inside the base_params domain"))
    !isempty(spec.radial_bin_counts) || throw(ArgumentError("radial_bin_counts must include at least one bin count"))
    all(count -> count >= 1, spec.radial_bin_counts) || throw(ArgumentError("all radial bin counts must be positive"))
    !isempty(spec.radial_radius_modes) || throw(ArgumentError("radial_radius_modes must include at least one mode"))
    all(mode -> mode in ("current", "reference"), spec.radial_radius_modes) ||
        throw(ArgumentError("radial_radius_modes must contain only current or reference"))
    all(width -> width > 0.0, spec.node_slab_half_widths) ||
        throw(ArgumentError("node-slab half widths must be positive"))
    spec.coordinate_mode in ("reference", "deformed") ||
        throw(ArgumentError("coordinate_mode must be reference or deformed"))
    spec.progress_every >= 0 || throw(ArgumentError("progress_every must be nonnegative"))
    return spec
end

function default_output_paths(spec::ComparisonSpec)
    return (
        section_csvs=section_csv_paths(spec),
        profile_csvs=profile_csv_paths(spec),
        sensitivity_csv=sensitivity_csv_path(spec),
        summary_csv=comparison_summary_path(spec),
        overlay_svg=joinpath(spec.output_dir, "section_quadrature_overlay.svg"),
    )
end
