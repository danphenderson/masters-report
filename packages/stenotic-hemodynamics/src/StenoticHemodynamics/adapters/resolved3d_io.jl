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

function parse_xdmf_field(path::String, attribute_type::AbstractString)
    isfile(path) || throw(ArgumentError("XDMF file not found: $path"))
    EzXML.readxml(path)

    text = read(path, String)
    time_match = match(r"<Time\b[^>]*Value\s*=\s*\"([^\"]+)\""s, text)
    time_match === nothing && throw(ArgumentError("XDMF file '$path' does not contain a Time Value"))
    time = parse(Float64, time_match.captures[1])

    topology_dims, topology_file, topology_path = parse_xdmf_dataitem(text, "Topology", path)
    geometry_dims, geometry_file, geometry_path = parse_xdmf_dataitem(text, "Geometry", path)
    field_dims, field_file, field_path = parse_xdmf_attribute(text, path, String(attribute_type))

    return XDMFFieldMetadata(
        time,
        geometry_file,
        geometry_path,
        geometry_dims,
        topology_file,
        topology_path,
        topology_dims,
        field_file,
        field_path,
        field_dims,
        String(attribute_type),
    )
end

function parse_xdmf_dataitem(text::String, element::String, source_path::String)
    block_match = match(Regex("<$(element)\\b[^>]*>.*?</$(element)>", "s"), text)
    block_match === nothing && throw(ArgumentError("XDMF file '$source_path' does not contain a $element block"))
    return parse_dataitem_block(block_match.match, "$element block in '$source_path'")
end

function parse_xdmf_vector_attribute(text::String, source_path::String)
    return parse_xdmf_attribute(text, source_path, "Vector")
end

function parse_xdmf_scalar_attribute(text::String, source_path::String)
    return parse_xdmf_attribute(text, source_path, "Scalar")
end

function parse_xdmf_attribute(text::String, source_path::String, attribute_type::String)
    for attribute in eachmatch(r"<Attribute\b[^>]*>.*?</Attribute>"s, text)
        block = attribute.match
        attribute_pattern = Regex("AttributeType\\s*=\\s*\\\"$(attribute_type)\\\"")
        if occursin(attribute_pattern, block) &&
           occursin(r"Center\s*=\s*\"Node\"", block)
            return parse_dataitem_block(block, "node-centered $(lowercase(attribute_type)) Attribute in '$source_path'")
        end
    end

    throw(ArgumentError("XDMF file '$source_path' does not contain a node-centered $(lowercase(attribute_type)) Attribute"))
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

function load_resolved3d_field_bundle(case_spec::Resolved3DCaseSpec; require_pressure::Bool = false, require_displacement::Bool = false)
    velocity_field = load_resolved3d_velocity(case_spec)
    pressure_metadata = nothing
    displacement_metadata = nothing
    pressure = nothing
    displacement = nothing
    deformed_coordinates = nothing

    if !isempty(case_spec.pressure_xdmf) && isfile(case_spec.pressure_xdmf)
        pressure_metadata = parse_xdmf_field(case_spec.pressure_xdmf, "Scalar")
        assert_compatible_xdmf_field(velocity_field, pressure_metadata, case_spec.pressure_xdmf)
        pressure_matrix = load_xdmf_field_matrix(case_spec.pressure_xdmf, pressure_metadata, 1, "pressure")
        pressure = vec(pressure_matrix[:, 1])
    elseif require_pressure
        throw(ArgumentError("resolved-FSI case '$(case_spec.case_label)' requires pressure XDMF: $(case_spec.pressure_xdmf)"))
    end

    if !isempty(case_spec.displacement_xdmf) && isfile(case_spec.displacement_xdmf)
        displacement_metadata = parse_xdmf_field(case_spec.displacement_xdmf, "Vector")
        assert_compatible_xdmf_field(velocity_field, displacement_metadata, case_spec.displacement_xdmf)
        displacement = Matrix{Float64}(
            load_xdmf_field_matrix(case_spec.displacement_xdmf, displacement_metadata, 3, "displacement"),
        )
        deformed_coordinates = velocity_field.coordinates .+ displacement
    elseif require_displacement
        throw(ArgumentError("resolved-FSI case '$(case_spec.case_label)' requires displacement XDMF: $(case_spec.displacement_xdmf)"))
    end

    return Resolved3DFieldBundle(
        case_spec,
        velocity_field,
        pressure_metadata,
        displacement_metadata,
        pressure,
        displacement,
        deformed_coordinates,
    )
end

function assert_compatible_xdmf_field(
    velocity_field::Resolved3DVelocityField,
    metadata::XDMFFieldMetadata,
    source_path::String,
)
    velocity_meta = velocity_field.metadata
    abs(metadata.time - velocity_meta.time) <= velocity_field.case_spec.time_atol ||
        throw(ArgumentError("XDMF time in '$source_path' does not match velocity time $(velocity_meta.time)"))
    metadata.geometry_dims == velocity_meta.geometry_dims ||
        throw(DimensionMismatch("geometry Dimensions in '$source_path' do not match velocity geometry"))
    metadata.topology_dims == velocity_meta.topology_dims ||
        throw(DimensionMismatch("topology Dimensions in '$source_path' do not match velocity topology"))
    xdmf_dir = dirname(source_path)
    topology_file = resolve_xdmf_hdf_path(xdmf_dir, metadata.topology_file)
    geometry_file = resolve_xdmf_hdf_path(xdmf_dir, metadata.geometry_file)
    topology = normalized_tetra_topology(
        read_hdf_matrix(topology_file, metadata.topology_path, metadata.topology_dims, 4, "topology"),
    )
    coordinates = Matrix{Float64}(
        read_hdf_matrix(geometry_file, metadata.geometry_path, metadata.geometry_dims, 3, "geometry"),
    )
    topology == velocity_field.topology ||
        throw(DimensionMismatch("topology values in '$source_path' do not match velocity topology"))
    coordinates == velocity_field.coordinates ||
        throw(DimensionMismatch("geometry coordinates in '$source_path' do not match velocity geometry"))
    return nothing
end

function load_xdmf_field_matrix(
    xdmf_path::String,
    metadata::XDMFFieldMetadata,
    expected_cols::Int,
    label::String,
)
    xdmf_dir = dirname(xdmf_path)
    file_path = resolve_xdmf_hdf_path(xdmf_dir, metadata.field_file)
    return read_hdf_matrix(file_path, metadata.field_path, metadata.field_dims, expected_cols, label)
end

function resolved3d_velocity_field_from_bundle(bundle::Resolved3DFieldBundle, coordinate_mode::AbstractString)
    mode = replace(lowercase(strip(String(coordinate_mode))), "_" => "-")
    if mode == "reference"
        return bundle.velocity
    elseif mode == "deformed"
        bundle.deformed_coordinates !== nothing ||
            throw(ArgumentError("coordinate_mode=deformed requires a loaded displacement field"))
        return Resolved3DVelocityField(
            bundle.velocity.case_spec,
            bundle.velocity.metadata,
            bundle.velocity.topology,
            bundle.deformed_coordinates,
            bundle.velocity.velocity,
        )
    end
    throw(ArgumentError("coordinate_mode must be reference or deformed"))
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
