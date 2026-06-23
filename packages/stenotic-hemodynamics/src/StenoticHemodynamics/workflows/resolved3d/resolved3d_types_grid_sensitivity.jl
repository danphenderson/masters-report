"""
    GridSensitivitySpec(; nxs=[200, 400, 800], ...)

Run the resolved-3D comparison at multiple 1D grid resolutions with a common
target time and section-plane definition, then aggregate compact per-grid
diagnostics.
"""
struct GridSensitivitySpec{B<:AbstractTimeBackend,O<:AbstractResolved3DOperator} <: AbstractStudySpec
    cases::Vector{Resolved3DCaseSpec}
    base_params::Params
    backend::B
    operator::O
    output_dir::String
    nxs::Vector{Int}
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
    summary_csv::String
    summary_tex::String
end

function GridSensitivitySpec(;
    cases = default_resolved3d_cases(),
    base_params::Params = Params(tfinal=0.9995, initial_condition=GeometryRestIC()),
    backend = NativeRK3Backend(),
    operator = CrossSectionQuadratureOperator(),
    output_dir::String = joinpath(DEFAULT_COMPARISON_OUTPUT_DIR, "grid_sensitivity"),
    nxs = DEFAULT_GRID_SENSITIVITY_NXS,
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
    summary_csv::String = "",
    summary_tex::String = "",
)
    backend isa AbstractTimeBackend || throw(ArgumentError("backend must subtype AbstractTimeBackend"))
    operator isa AbstractResolved3DOperator || throw(ArgumentError("operator must subtype AbstractResolved3DOperator"))
    case_values = Resolved3DCaseSpec[case for case in cases]
    isempty(case_values) && throw(ArgumentError("grid sensitivity spec must include at least one case"))
    nx_values = [Int(nx) for nx in nxs]
    isempty(nx_values) && throw(ArgumentError("grid sensitivity requires at least one nx value"))
    all(nx -> nx >= 3, nx_values) || throw(ArgumentError("all grid sensitivity sizes must be at least 3"))
    sort(nx_values) == nx_values || throw(ArgumentError("grid sensitivity sizes must be sorted ascending"))
    length(unique(nx_values)) == length(nx_values) || throw(ArgumentError("grid sensitivity sizes must be unique"))
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

    csv_path = isempty(summary_csv) ? joinpath(output_dir, "grid_sensitivity_summary.csv") : summary_csv
    tex_path = isempty(summary_tex) ? joinpath(output_dir, "grid_sensitivity_summary.tex") : summary_tex

    return GridSensitivitySpec{typeof(backend),typeof(operator)}(
        case_values,
        base_params,
        backend,
        operator,
        output_dir,
        nx_values,
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
        csv_path,
        tex_path,
    )
end

workflow_kind(::GridSensitivitySpec) = "resolved3d_grid_sensitivity"

function validate(spec::GridSensitivitySpec)
    isempty(spec.cases) && throw(ArgumentError("grid sensitivity spec must include at least one case"))
    validate(spec.base_params)
    assert_backend_supported(spec.base_params.space, spec.backend)
    !isempty(spec.nxs) || throw(ArgumentError("grid sensitivity requires at least one nx value"))
    all(nx -> nx >= 3, spec.nxs) || throw(ArgumentError("all grid sensitivity sizes must be at least 3"))
    sort(spec.nxs) == spec.nxs || throw(ArgumentError("grid sensitivity sizes must be sorted ascending"))
    length(unique(spec.nxs)) == length(spec.nxs) || throw(ArgumentError("grid sensitivity sizes must be unique"))
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

function default_output_paths(spec::GridSensitivitySpec)
    return (summary_csv=spec.summary_csv, summary_tex=spec.summary_tex)
end
