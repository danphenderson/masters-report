"""
    parse_xdmf_velocity(path) -> XDMFVelocityMetadata

Parse the time, topology, geometry, and node-centered vector attribute HDF5
references from a Canic upstream XDMF velocity file. XDMF/HDF5 assumptions are
isolated in this adapter so resolved-3D workflow code consumes only
`Resolved3DVelocityField` arrays and metadata.
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

    topology = normalized_tetra_topology(
        read_hdf_matrix(topology_file, metadata.topology_path, metadata.topology_dims, 4, "topology"),
    )
    size(topology, 2) == 4 || throw(DimensionMismatch("topology dataset must have 4 columns"))

    coordinates = Matrix{Float64}(
        read_hdf_matrix(geometry_file, metadata.geometry_path, metadata.geometry_dims, 3, "geometry"),
    )
    velocity = Matrix{Float64}(
        read_hdf_matrix(velocity_file, metadata.velocity_path, metadata.velocity_dims, 3, "velocity"),
    )

    size(coordinates, 1) == size(velocity, 1) ||
        throw(DimensionMismatch("geometry node count $(size(coordinates, 1)) does not match velocity node count $(size(velocity, 1))"))
    validate_tetra_topology(topology, size(coordinates, 1))

    return Resolved3DVelocityField(case_spec, metadata, topology, coordinates, velocity)
end

function normalized_tetra_topology(raw_topology)
    topology = Matrix{Int}(raw_topology)
    isempty(topology) && throw(ArgumentError("topology dataset is empty"))
    min_index = minimum(topology)
    if min_index == 0
        return topology .+ 1
    elseif min_index == 1
        return topology
    end
    throw(ArgumentError("tetra topology must be zero- or one-based; minimum index is $min_index"))
end

function validate_tetra_topology(topology::Matrix{Int}, node_count::Int)
    size(topology, 2) == 4 || throw(DimensionMismatch("tetra topology must have 4 columns"))
    min_index = minimum(topology)
    max_index = maximum(topology)
    min_index >= 1 || throw(ArgumentError("tetra topology contains an index below 1 after normalization"))
    max_index <= node_count || throw(ArgumentError("tetra topology max index $max_index exceeds node count $node_count"))
    return topology
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
