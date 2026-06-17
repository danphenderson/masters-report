import EzXML
import HDF5
using Statistics

const DEFAULT_RESOLVED3D_DATA_ROOT = joinpath("simulations", "data", "3d", "canic_case3")
const DEFAULT_COMPARISON_OUTPUT_DIR = joinpath("simulations", "output", "3d_comparison")

"""
    Resolved3DCaseSpec(case_label, severity, velocity_xdmf; target_time=1.0, time_atol=1e-3)

Reference 3D velocity case to compare against a 1D run. `velocity_xdmf` points
to the XDMF metadata file; the HDF5 paths referenced inside it are resolved
relative to that XDMF file.
"""
struct Resolved3DCaseSpec
    case_label::String
    severity::Float64
    velocity_xdmf::String
    target_time::Float64
    time_atol::Float64
end

function Resolved3DCaseSpec(
    case_label,
    severity,
    velocity_xdmf;
    target_time::Real = 1.0,
    time_atol::Real = 1.0e-3,
)
    severity_value = Float64(severity)
    target_time_value = Float64(target_time)
    time_atol_value = Float64(time_atol)
    target_time_value >= 0.0 || throw(ArgumentError("target_time must be nonnegative"))
    time_atol_value >= 0.0 || throw(ArgumentError("time_atol must be nonnegative"))
    validate(Params(severity=severity_value, tfinal=target_time_value, initial_condition=GeometryRestIC()))
    return Resolved3DCaseSpec(
        string(case_label),
        severity_value,
        String(velocity_xdmf),
        target_time_value,
        time_atol_value,
    )
end

"""
Metadata parsed from an XDMF velocity file.
"""
struct XDMFVelocityMetadata
    time::Float64
    geometry_file::String
    geometry_path::String
    geometry_dims::Tuple{Int,Int}
    topology_file::String
    topology_path::String
    topology_dims::Tuple{Int,Int}
    velocity_file::String
    velocity_path::String
    velocity_dims::Tuple{Int,Int}
end

"""
Node-centered 3D coordinates and velocities loaded from HDF5.
"""
struct Resolved3DVelocityField
    case_spec::Resolved3DCaseSpec
    metadata::XDMFVelocityMetadata
    coordinates::Matrix{Float64}
    velocity::Matrix{Float64}
end

"""
Configuration for comparing one or more 3D reference cases against 1D runs.
"""
struct ComparisonSpec
    cases::Vector{Resolved3DCaseSpec}
    base_params::Params
    backend::AbstractTimeBackend
    output_dir::String
    section_count::Int
    profile_slices::Vector{Float64}
    radial_bins::Int
    overwrite::Bool
    progress_every::Int
    write_svg::Bool
end

function ComparisonSpec(;
    cases = default_resolved3d_cases(),
    base_params::Params = Params(tfinal=1.0, initial_condition=GeometryRestIC()),
    backend::AbstractTimeBackend = NativeRK3Backend(),
    output_dir::String = DEFAULT_COMPARISON_OUTPUT_DIR,
    section_count::Int = 200,
    profile_slices = nothing,
    radial_bins::Int = 20,
    overwrite::Bool = false,
    progress_every::Int = 0,
    write_svg::Bool = true,
)
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

    return ComparisonSpec(
        case_values,
        base_params,
        backend,
        output_dir,
        section_count,
        slices,
        radial_bins,
        overwrite,
        progress_every,
        write_svg,
    )
end

"""One section-mean axial-velocity comparison row."""
struct SectionComparisonRow
    case_label::String
    severity::Float64
    z_cm::Float64
    u1d_cm_s::Float64
    u3d_cm_s::Float64
    abs_error_cm_s::Float64
    rel_error::Float64
    node_count::Int
    observed_radius_cm::Float64
    xdmf_time_s::Float64
    time_error_s::Float64
end

"""One radial-bin profile comparison row."""
struct RadialProfileRow
    case_label::String
    severity::Float64
    z_slice_cm::Float64
    radial_bin::Int
    r_over_r0_mid::Float64
    u1d_cm_s::Float64
    u3d_cm_s::Float64
    abs_error_cm_s::Float64
    rel_error::Float64
    node_count::Int
    xdmf_time_s::Float64
    time_error_s::Float64
end

"""Compact per-case comparison summary."""
struct ComparisonSummaryRow
    case_label::String
    severity::Float64
    section_count::Int
    profile_count::Int
    mean_abs_error_cm_s::Float64
    max_abs_error_cm_s::Float64
    mean_rel_error::Float64
    max_rel_error::Float64
    profile_mean_abs_error_cm_s::Float64
    profile_max_abs_error_cm_s::Float64
    min_section_nodes::Int
    xdmf_time_s::Float64
    time_error_s::Float64
end

"""Return value from `run_comparison`."""
struct ComparisonResult
    spec::ComparisonSpec
    section_rows::Vector{SectionComparisonRow}
    profile_rows::Vector{RadialProfileRow}
    summary_rows::Vector{ComparisonSummaryRow}
    section_csvs::Vector{String}
    profile_csvs::Vector{String}
    summary_csv::String
    svg_paths::Vector{String}
end

default_resolved3d_data_root() = DEFAULT_RESOLVED3D_DATA_ROOT

function default_resolved3d_cases(data_root::String = default_resolved3d_data_root())
    return Resolved3DCaseSpec[
        Resolved3DCaseSpec("77", 23.0, joinpath(data_root, "77", "velocity.xdmf")),
        Resolved3DCaseSpec("60", 40.0, joinpath(data_root, "60", "velocity.xdmf")),
    ]
end

function available_resolved3d_cases(data_root::String = default_resolved3d_data_root())
    cases = [case for case in default_resolved3d_cases(data_root) if isfile(case.velocity_xdmf)]
    if isempty(cases)
        @info "skipping resolved 3D comparison because no case XDMF files were found" data_root expected_layout=[
            joinpath(data_root, "77", "velocity.xdmf"),
            joinpath(data_root, "60", "velocity.xdmf"),
        ]
    end
    return cases
end

function run_available_resolved3d_comparison(;
    data_root::String = default_resolved3d_data_root(),
    kwargs...,
)
    cases = available_resolved3d_cases(data_root)
    isempty(cases) && return nothing
    return run_comparison(ComparisonSpec(; cases=cases, kwargs...))
end

"""
    parse_xdmf_velocity(path) -> XDMFVelocityMetadata

Parse the time, topology, geometry, and node-centered vector attribute HDF5
references from a Canic upstream XDMF velocity file.
"""
function parse_xdmf_velocity(path::String)
    isfile(path) || throw(ArgumentError("XDMF file not found: $path"))
    EzXML.readxml(path)

    text = read(path, String)
    time_match = match(r"<Time\b[^>]*Value\s*=\s*\"([^\"]+)\""s, text)
    time_match === nothing && throw(ArgumentError("XDMF file '$path' does not contain a Time Value"))
    time = parse(Float64, time_match.captures[1])

    topology_dims, topology_file, topology_path = parse_xdmf_dataitem(text, "Topology", path)
    geometry_dims, geometry_file, geometry_path = parse_xdmf_dataitem(text, "Geometry", path)
    velocity_dims, velocity_file, velocity_path = parse_xdmf_vector_attribute(text, path)

    return XDMFVelocityMetadata(
        time,
        geometry_file,
        geometry_path,
        geometry_dims,
        topology_file,
        topology_path,
        topology_dims,
        velocity_file,
        velocity_path,
        velocity_dims,
    )
end

function parse_xdmf_dataitem(text::String, element::String, source_path::String)
    block_match = match(Regex("<$(element)\\b[^>]*>.*?</$(element)>", "s"), text)
    block_match === nothing && throw(ArgumentError("XDMF file '$source_path' does not contain a $element block"))
    return parse_dataitem_block(block_match.match, "$element block in '$source_path'")
end

function parse_xdmf_vector_attribute(text::String, source_path::String)
    for attribute in eachmatch(r"<Attribute\b[^>]*>.*?</Attribute>"s, text)
        block = attribute.match
        if occursin(r"AttributeType\s*=\s*\"Vector\"", block) &&
           occursin(r"Center\s*=\s*\"Node\"", block)
            return parse_dataitem_block(block, "node-centered vector Attribute in '$source_path'")
        end
    end

    throw(ArgumentError("XDMF file '$source_path' does not contain a node-centered vector Attribute"))
end

function parse_dataitem_block(block::AbstractString, label::String)
    dataitem_match = match(r"<DataItem\b([^>]*)>(.*?)</DataItem>"s, block)
    dataitem_match === nothing && throw(ArgumentError("$label does not contain a DataItem"))

    attrs = dataitem_match.captures[1]
    dims_match = match(r"Dimensions\s*=\s*\"([^\"]+)\"", attrs)
    dims_match === nothing && throw(ArgumentError("$label DataItem does not declare Dimensions"))
    dims = parse_xdmf_dims(dims_match.captures[1], label)

    hdf_ref = replace(strip(dataitem_match.captures[2]), r"\s+" => "")
    h5_file, dataset_path = split_hdf_reference(hdf_ref, label)
    return dims, h5_file, dataset_path
end

function parse_xdmf_dims(raw::AbstractString, label::String)
    values = split(strip(raw))
    length(values) == 2 || throw(ArgumentError("$label Dimensions must have two entries, got '$raw'"))
    dims = (parse(Int, values[1]), parse(Int, values[2]))
    all(>(0), dims) || throw(ArgumentError("$label Dimensions must be positive, got '$raw'"))
    return dims
end

function split_hdf_reference(raw::AbstractString, label::String)
    parts = split(String(raw), ":", limit=2)
    length(parts) == 2 || throw(ArgumentError("$label HDF reference must look like file.h5:/dataset, got '$raw'"))
    file = strip(parts[1])
    dataset = strip(parts[2])
    !isempty(file) || throw(ArgumentError("$label HDF reference has an empty file name"))
    startswith(dataset, "/") || throw(ArgumentError("$label HDF dataset path must be absolute, got '$dataset'"))
    return file, dataset
end

"""
    load_resolved3d_velocity(case_spec) -> Resolved3DVelocityField

Load node coordinates and node-centered velocity vectors after checking the XDMF
time against `case_spec.target_time`.
"""
function load_resolved3d_velocity(case_spec::Resolved3DCaseSpec)
    metadata = parse_xdmf_velocity(case_spec.velocity_xdmf)
    time_error = abs(metadata.time - case_spec.target_time)
    if time_error > case_spec.time_atol
        throw(ArgumentError(
            "XDMF time $(metadata.time) in '$(case_spec.velocity_xdmf)' differs from target_time " *
            "$(case_spec.target_time) by $(time_error), exceeding time_atol $(case_spec.time_atol)",
        ))
    end

    xdmf_dir = dirname(case_spec.velocity_xdmf)
    topology_file = resolve_xdmf_hdf_path(xdmf_dir, metadata.topology_file)
    geometry_file = resolve_xdmf_hdf_path(xdmf_dir, metadata.geometry_file)
    velocity_file = resolve_xdmf_hdf_path(xdmf_dir, metadata.velocity_file)

    topology = read_hdf_matrix(topology_file, metadata.topology_path, metadata.topology_dims, 4, "topology")
    size(topology, 2) == 4 || throw(DimensionMismatch("topology dataset must have 4 columns"))

    coordinates = Matrix{Float64}(
        read_hdf_matrix(geometry_file, metadata.geometry_path, metadata.geometry_dims, 3, "geometry"),
    )
    velocity = Matrix{Float64}(
        read_hdf_matrix(velocity_file, metadata.velocity_path, metadata.velocity_dims, 3, "velocity"),
    )

    size(coordinates, 1) == size(velocity, 1) ||
        throw(DimensionMismatch("geometry node count $(size(coordinates, 1)) does not match velocity node count $(size(velocity, 1))"))

    return Resolved3DVelocityField(case_spec, metadata, coordinates, velocity)
end

function resolve_xdmf_hdf_path(xdmf_dir::String, h5_file::String)
    return isabspath(h5_file) ? h5_file : joinpath(xdmf_dir, h5_file)
end

function read_hdf_matrix(
    file_path::String,
    dataset_path::String,
    expected_dims::Tuple{Int,Int},
    expected_cols::Int,
    label::String,
)
    isfile(file_path) || throw(ArgumentError("HDF5 file not found for $label: $file_path"))

    data = HDF5.h5open(file_path, "r") do file
        try
            read(file[dataset_path])
        catch err
            throw(ArgumentError("missing $label dataset '$dataset_path' in '$file_path': $(err)"))
        end
    end

    return matrix_with_expected_shape(data, expected_dims, expected_cols, label)
end

function matrix_with_expected_shape(data, expected_dims::Tuple{Int,Int}, expected_cols::Int, label::String)
    ndims(data) == 2 || throw(DimensionMismatch("$label dataset must be 2D, got $(ndims(data)) dimensions"))

    matrix = if size(data, 1) == expected_dims[1] && size(data, 2) == expected_dims[2]
        Matrix(data)
    elseif size(data, 1) == expected_dims[2] && size(data, 2) == expected_dims[1]
        Matrix(permutedims(data))
    else
        throw(DimensionMismatch(
            "$label dataset shape $(size(data)) does not match XDMF Dimensions $(expected_dims)",
        ))
    end

    size(matrix, 2) == expected_cols ||
        throw(DimensionMismatch("$label dataset must have $(expected_cols) columns, got $(size(matrix, 2))"))
    return matrix
end

function default_profile_slices(p::Params)
    throat = stenosis_throat_z(p)
    return clamp.([throat - 0.5, throat, throat + 0.5], 0.0, p.length_cm)
end

function stenosis_throat_z(p::Params; samples::Int = 2001)
    samples >= 3 || throw(ArgumentError("samples must be at least 3"))
    best_z = 0.0
    best_r = Inf
    for z in range(0.0, p.length_cm; length=samples)
        r0, _, _ = stenosis(Float64(z), p)
        if r0 < best_r
            best_r = r0
            best_z = Float64(z)
        end
    end
    return best_z
end

function run_comparison(spec::ComparisonSpec)
    section_rows = SectionComparisonRow[]
    profile_rows = RadialProfileRow[]
    summary_rows = ComparisonSummaryRow[]

    for case in spec.cases
        field = load_resolved3d_velocity(case)
        params = params_with(spec.base_params; severity=case.severity, tfinal=case.target_time)
        result = simulate(params, spec.backend; progress_every=spec.progress_every)

        case_sections = compare_section_means(field, result, params, spec)
        case_profiles = compare_radial_profiles(field, result, params, spec)
        append!(section_rows, case_sections)
        append!(profile_rows, case_profiles)
        push!(summary_rows, summarize_comparison(case, field.metadata, case_sections, case_profiles))
    end

    result = ComparisonResult(
        spec,
        section_rows,
        profile_rows,
        summary_rows,
        section_csv_paths(spec),
        profile_csv_paths(spec),
        comparison_summary_path(spec),
        String[],
    )
    write_comparison_csvs(result; overwrite=spec.overwrite)

    svg_paths = String[]
    if spec.write_svg
        path = joinpath(spec.output_dir, "section_mean_overlay.svg")
        write_section_comparison_svg(path, section_rows; overwrite=spec.overwrite)
        push!(svg_paths, path)
    end

    return ComparisonResult(
        spec,
        section_rows,
        profile_rows,
        summary_rows,
        result.section_csvs,
        result.profile_csvs,
        result.summary_csv,
        svg_paths,
    )
end

function compare_section_means(
    field::Resolved3DVelocityField,
    result::SimulationResult,
    params::Params,
    spec::ComparisonSpec,
)
    z_targets = collect(range(0.0, params.length_cm; length=spec.section_count))
    half_width = section_half_width(z_targets)
    u1d = velocity(result)
    rows = SectionComparisonRow[]
    time_error = abs(field.metadata.time - field.case_spec.target_time)

    for z in z_targets
        node_ids = slab_node_indices(field.coordinates, Float64(z), half_width)
        u3d = mean_velocity_or_nan(field.velocity, node_ids)
        u1d_at_z = interpolate_linear(result.z, u1d, Float64(z))
        abs_error = abs_or_nan(u1d_at_z, u3d)
        rel_error = relative_error(abs_error, u3d)
        observed_radius = observed_radius_or_nan(field.coordinates, node_ids)

        push!(
            rows,
            SectionComparisonRow(
                field.case_spec.case_label,
                field.case_spec.severity,
                Float64(z),
                u1d_at_z,
                u3d,
                abs_error,
                rel_error,
                length(node_ids),
                observed_radius,
                field.metadata.time,
                time_error,
            ),
        )
    end

    return rows
end

function compare_radial_profiles(
    field::Resolved3DVelocityField,
    result::SimulationResult,
    params::Params,
    spec::ComparisonSpec,
)
    z_targets = collect(range(0.0, params.length_cm; length=spec.section_count))
    half_width = section_half_width(z_targets)
    u1d = velocity(result)
    rows = RadialProfileRow[]
    time_error = abs(field.metadata.time - field.case_spec.target_time)

    for z_slice in spec.profile_slices
        r0, _, _ = stenosis(z_slice, params)
        area_at_z = interpolate_linear(result.z, result.area, z_slice)
        radius_at_z = sqrt(positive_area(area_at_z))
        uavg_at_z = interpolate_linear(result.z, u1d, z_slice)
        node_ids = slab_node_indices(field.coordinates, z_slice, half_width)
        bins = radial_bins(field.coordinates, node_ids, r0, spec.radial_bins)

        for bin in 1:spec.radial_bins
            ids = bins[bin]
            r_over_r0_mid = (bin - 0.5) / spec.radial_bins
            u3d = mean_velocity_or_nan(field.velocity, ids)
            u1d_profile = one_dimensional_profile_velocity(uavg_at_z, r_over_r0_mid * r0, radius_at_z, params)
            abs_error = abs_or_nan(u1d_profile, u3d)
            rel_error = relative_error(abs_error, u3d)

            push!(
                rows,
                RadialProfileRow(
                    field.case_spec.case_label,
                    field.case_spec.severity,
                    z_slice,
                    bin,
                    r_over_r0_mid,
                    u1d_profile,
                    u3d,
                    abs_error,
                    rel_error,
                    length(ids),
                    field.metadata.time,
                    time_error,
                ),
            )
        end
    end

    return rows
end

function section_half_width(z_targets::Vector{Float64})
    dz = length(z_targets) <= 1 ? 0.0 : minimum(diff(z_targets))
    return max(0.5 * dz, 0.015)
end

function slab_node_indices(coordinates::Matrix{Float64}, z::Float64, half_width::Float64)
    ids = Int[]
    for i in axes(coordinates, 1)
        if abs(coordinates[i, 3] - z) <= half_width
            push!(ids, i)
        end
    end
    return ids
end

function mean_velocity_or_nan(velocity::Matrix{Float64}, ids::Vector{Int})
    isempty(ids) && return NaN
    return mean(view(velocity, ids, 3))
end

function observed_radius_or_nan(coordinates::Matrix{Float64}, ids::Vector{Int})
    isempty(ids) && return NaN
    radius = 0.0
    for i in ids
        radius = max(radius, hypot(coordinates[i, 1], coordinates[i, 2]))
    end
    return radius
end

function radial_bins(coordinates::Matrix{Float64}, ids::Vector{Int}, r0::Float64, bin_count::Int)
    bins = [Int[] for _ in 1:bin_count]
    r0 > 0.0 || throw(ArgumentError("reference radius must be positive"))

    for i in ids
        rho = hypot(coordinates[i, 1], coordinates[i, 2]) / r0
        if 0.0 <= rho <= 1.05
            bin = clamp(floor(Int, min(rho, 1.0) * bin_count) + 1, 1, bin_count)
            push!(bins[bin], i)
        end
    end

    return bins
end

function one_dimensional_profile_velocity(uavg::Float64, radius::Float64, section_radius::Float64, p::Params)
    return radial_profile_velocity(uavg, radius, section_radius, p.velocity_profile)
end

function interpolate_linear(x::Vector{Float64}, y::Vector{Float64}, x0::Float64)
    length(x) == length(y) || throw(DimensionMismatch("interpolation vectors must have matching lengths"))
    isempty(x) && throw(ArgumentError("cannot interpolate empty vectors"))
    x0 <= x[begin] && return y[begin]
    x0 >= x[end] && return y[end]

    hi = searchsortedfirst(x, x0)
    lo = hi - 1
    weight = (x0 - x[lo]) / (x[hi] - x[lo])
    return (1.0 - weight) * y[lo] + weight * y[hi]
end

function abs_or_nan(a::Float64, b::Float64)
    return isfinite(a) && isfinite(b) ? abs(a - b) : NaN
end

function relative_error(abs_error::Float64, reference::Float64)
    return isfinite(abs_error) && isfinite(reference) ? abs_error / max(abs(reference), eps()) : NaN
end

function summarize_comparison(
    case::Resolved3DCaseSpec,
    metadata::XDMFVelocityMetadata,
    section_rows::Vector{SectionComparisonRow},
    profile_rows::Vector{RadialProfileRow},
)
    section_abs = finite_values(row.abs_error_cm_s for row in section_rows)
    section_rel = finite_values(row.rel_error for row in section_rows)
    profile_abs = finite_values(row.abs_error_cm_s for row in profile_rows)
    node_counts = [row.node_count for row in section_rows]
    time_error = abs(metadata.time - case.target_time)

    return ComparisonSummaryRow(
        case.case_label,
        case.severity,
        length(section_rows),
        length(profile_rows),
        mean_or_nan(section_abs),
        maximum_or_nan(section_abs),
        mean_or_nan(section_rel),
        maximum_or_nan(section_rel),
        mean_or_nan(profile_abs),
        maximum_or_nan(profile_abs),
        isempty(node_counts) ? 0 : minimum(node_counts),
        metadata.time,
        time_error,
    )
end

function finite_values(values)
    return [Float64(value) for value in values if isfinite(Float64(value))]
end

mean_or_nan(values::Vector{Float64}) = isempty(values) ? NaN : mean(values)
maximum_or_nan(values::Vector{Float64}) = isempty(values) ? NaN : maximum(values)

function section_csv_paths(spec::ComparisonSpec)
    return [section_csv_path(spec, case) for case in spec.cases]
end

function profile_csv_paths(spec::ComparisonSpec)
    return [profile_csv_path(spec, case) for case in spec.cases]
end

function section_csv_path(spec::ComparisonSpec, case::Resolved3DCaseSpec)
    return joinpath(spec.output_dir, "section_mean_$(comparison_case_token(case)).csv")
end

function profile_csv_path(spec::ComparisonSpec, case::Resolved3DCaseSpec)
    return joinpath(spec.output_dir, "radial_profile_$(comparison_case_token(case)).csv")
end

function comparison_summary_path(spec::ComparisonSpec)
    return joinpath(spec.output_dir, "comparison_summary.csv")
end

function comparison_case_token(case::Resolved3DCaseSpec)
    return "case$(case.case_label)_sev$(round(Int, case.severity))"
end

function write_comparison_csvs(result::ComparisonResult; overwrite::Bool = false)
    mkpath(result.spec.output_dir)

    for (case, path) in zip(result.spec.cases, result.section_csvs)
        rows = [row for row in result.section_rows if row.case_label == case.case_label]
        write_section_comparison_csv(path, rows; overwrite=overwrite)
    end

    for (case, path) in zip(result.spec.cases, result.profile_csvs)
        rows = [row for row in result.profile_rows if row.case_label == case.case_label]
        write_radial_profile_csv(path, rows; overwrite=overwrite)
    end

    write_comparison_summary_csv(result.summary_csv, result.summary_rows; overwrite=overwrite)
    return result
end

function guarded_open_write(writer, path::String, overwrite::Bool)
    ensure_parent(path)
    if isfile(path) && !overwrite
        throw(ArgumentError("refusing to overwrite existing file '$path'; pass overwrite=true to allow replacement"))
    end
    open(path, "w") do io
        writer(io)
    end
    return path
end

function write_section_comparison_csv(
    path::String,
    rows::Vector{SectionComparisonRow};
    overwrite::Bool = false,
)
    guarded_open_write(path, overwrite) do io
        println(io, section_comparison_header())
        for row in rows
            println(io, section_comparison_csv_row(row))
        end
    end
end

function section_comparison_header()
    return join((
        "case_label",
        "severity",
        "z_cm",
        "u1d_cm_s",
        "u3d_cm_s",
        "abs_error_cm_s",
        "rel_error",
        "node_count",
        "observed_radius_cm",
        "xdmf_time_s",
        "time_error_s",
    ), ",")
end

function section_comparison_csv_row(row::SectionComparisonRow)
    return join((
        row.case_label,
        row.severity,
        row.z_cm,
        row.u1d_cm_s,
        row.u3d_cm_s,
        row.abs_error_cm_s,
        row.rel_error,
        row.node_count,
        row.observed_radius_cm,
        row.xdmf_time_s,
        row.time_error_s,
    ), ",")
end

function write_radial_profile_csv(
    path::String,
    rows::Vector{RadialProfileRow};
    overwrite::Bool = false,
)
    guarded_open_write(path, overwrite) do io
        println(io, radial_profile_header())
        for row in rows
            println(io, radial_profile_csv_row(row))
        end
    end
end

function radial_profile_header()
    return join((
        "case_label",
        "severity",
        "z_slice_cm",
        "radial_bin",
        "r_over_r0_mid",
        "u1d_cm_s",
        "u3d_cm_s",
        "abs_error_cm_s",
        "rel_error",
        "node_count",
        "xdmf_time_s",
        "time_error_s",
    ), ",")
end

function radial_profile_csv_row(row::RadialProfileRow)
    return join((
        row.case_label,
        row.severity,
        row.z_slice_cm,
        row.radial_bin,
        row.r_over_r0_mid,
        row.u1d_cm_s,
        row.u3d_cm_s,
        row.abs_error_cm_s,
        row.rel_error,
        row.node_count,
        row.xdmf_time_s,
        row.time_error_s,
    ), ",")
end

function write_comparison_summary_csv(
    path::String,
    rows::Vector{ComparisonSummaryRow};
    overwrite::Bool = false,
)
    guarded_open_write(path, overwrite) do io
        println(io, comparison_summary_header())
        for row in rows
            println(io, comparison_summary_csv_row(row))
        end
    end
end

function comparison_summary_header()
    return join((
        "case_label",
        "severity",
        "section_count",
        "profile_count",
        "mean_abs_error_cm_s",
        "max_abs_error_cm_s",
        "mean_rel_error",
        "max_rel_error",
        "profile_mean_abs_error_cm_s",
        "profile_max_abs_error_cm_s",
        "min_section_nodes",
        "xdmf_time_s",
        "time_error_s",
    ), ",")
end

function comparison_summary_csv_row(row::ComparisonSummaryRow)
    return join((
        row.case_label,
        row.severity,
        row.section_count,
        row.profile_count,
        row.mean_abs_error_cm_s,
        row.max_abs_error_cm_s,
        row.mean_rel_error,
        row.max_rel_error,
        row.profile_mean_abs_error_cm_s,
        row.profile_max_abs_error_cm_s,
        row.min_section_nodes,
        row.xdmf_time_s,
        row.time_error_s,
    ), ",")
end

function write_section_comparison_svg(
    path::String,
    rows::Vector{SectionComparisonRow};
    overwrite::Bool = false,
)
    guarded_open_write(path, overwrite) do io
        width = 920
        height = 560
        margin = 58
        mid = 285
        colors = ("#a51f2d", "#1d5f8f", "#2d7a36", "#6f4a8e")
        cases = unique(row.case_label for row in rows)
        finite_u = finite_values(Iterators.flatten((row.u1d_cm_s, row.u3d_cm_s) for row in rows))
        finite_e = finite_values(row.abs_error_cm_s for row in rows)
        z_values = finite_values(row.z_cm for row in rows)
        xmin = isempty(z_values) ? 0.0 : minimum(z_values)
        xmax = isempty(z_values) ? 1.0 : maximum(z_values)
        umin, umax = padded_limits(finite_u)
        emin, emax = padded_limits(finite_e; lower_zero=true)

        println(io, """<svg xmlns="http://www.w3.org/2000/svg" width="$width" height="$height" viewBox="0 0 $width $height">""")
        println(io, """<rect width="100%" height="100%" fill="white"/>""")
        println(io, """<text x="$margin" y="32" font-family="Arial" font-size="18" fill="#111">Resolved 3D vs 1D section mean velocity</text>""")
        svg_panel_axes(io, margin, 58, width - margin, mid - 28, "mean axial velocity (cm/s)", xmin, xmax, umin, umax)
        svg_panel_axes(io, margin, mid + 26, width - margin, height - margin, "absolute error (cm/s)", xmin, xmax, emin, emax)

        for (case_index, case_label) in enumerate(cases)
            color = colors[mod1(case_index, length(colors))]
            case_rows = [row for row in rows if row.case_label == case_label]
            svg_polyline(io, case_rows, xmin, xmax, umin, umax, margin, 58, width - margin, mid - 28, color, row -> row.u3d_cm_s)
            svg_polyline(io, case_rows, xmin, xmax, umin, umax, margin, 58, width - margin, mid - 28, color, row -> row.u1d_cm_s; dash=true)
            svg_polyline(io, case_rows, xmin, xmax, emin, emax, margin, mid + 26, width - margin, height - margin, color, row -> row.abs_error_cm_s)
            println(io, """<text x="$(margin + 12 + 110 * (case_index - 1))" y="54" font-family="Arial" font-size="12" fill="$color">case $case_label solid=3D dashed=1D</text>""")
        end

        println(io, "</svg>")
    end
end

function padded_limits(values::Vector{Float64}; lower_zero::Bool = false)
    isempty(values) && return (0.0, 1.0)
    ymin = lower_zero ? 0.0 : minimum(values)
    ymax = maximum(values)
    pad = 0.08 * max(ymax - ymin, 1.0e-9)
    return ymin - (lower_zero ? 0.0 : pad), ymax + pad
end

function svg_panel_axes(io, xleft, ytop, xright, ybot, title, xmin, xmax, ymin, ymax)
    println(io, """<line x1="$xleft" y1="$ybot" x2="$xright" y2="$ybot" stroke="#333" stroke-width="1"/>""")
    println(io, """<line x1="$xleft" y1="$ytop" x2="$xleft" y2="$ybot" stroke="#333" stroke-width="1"/>""")
    println(io, """<text x="$xleft" y="$(ytop - 12)" font-family="Arial" font-size="14" fill="#111">$title</text>""")
    println(io, """<text x="$(xright - 40)" y="$(ybot + 28)" font-family="Arial" font-size="12" fill="#333">z (cm)</text>""")
    println(io, """<text x="$(xleft + 4)" y="$(ytop + 14)" font-family="Arial" font-size="11" fill="#555">$(round(ymax, sigdigits=4))</text>""")
    println(io, """<text x="$(xleft + 4)" y="$(ybot - 4)" font-family="Arial" font-size="11" fill="#555">$(round(ymin, sigdigits=4))</text>""")
    println(io, """<text x="$xleft" y="$(ybot + 28)" font-family="Arial" font-size="11" fill="#555">$(round(xmin, sigdigits=4))</text>""")
    println(io, """<text x="$(xright - 88)" y="$(ybot + 28)" font-family="Arial" font-size="11" fill="#555">$(round(xmax, sigdigits=4))</text>""")
end

function svg_polyline(
    io,
    rows::Vector{SectionComparisonRow},
    xmin,
    xmax,
    ymin,
    ymax,
    xleft,
    ytop,
    xright,
    ybot,
    color,
    value_fn;
    dash::Bool = false,
)
    points = String[]
    for row in rows
        y = Float64(value_fn(row))
        if isfinite(row.z_cm) && isfinite(y)
            sx = xleft + (row.z_cm - xmin) / max(xmax - xmin, eps()) * (xright - xleft)
            sy = ybot - (y - ymin) / max(ymax - ymin, eps()) * (ybot - ytop)
            push!(points, string(round(sx, digits=2), ",", round(sy, digits=2)))
        end
    end

    isempty(points) && return nothing
    dash_attr = dash ? " stroke-dasharray=\"7 5\"" : ""
    println(io, """<polyline points="$(join(points, " "))" fill="none" stroke="$color" stroke-width="2"$dash_attr/>""")
    return nothing
end
