import HDF5

const RESOLVED3D_DEFAULT_BENCHMARK_TIME_S = 1.0
const RESOLVED3D_DEFAULT_MESH_H5 = "mesh.h5"
const RESOLVED3D_DEFAULT_VELOCITY_XDMF = "velocity.xdmf"
const RESOLVED3D_DEFAULT_VELOCITY_H5 = "velocity.h5"
const RESOLVED3D_DEFAULT_PRESSURE_XDMF = "pressure.xdmf"
const RESOLVED3D_DEFAULT_PRESSURE_H5 = "pressure.h5"
const RESOLVED3D_DEFAULT_DISPLACEMENT_XDMF = "displace.xdmf"
const RESOLVED3D_DEFAULT_DISPLACEMENT_H5 = "displace.h5"
const RESOLVED3D_GEOMETRY_DATASET = "/Mesh/0/mesh/geometry"
const RESOLVED3D_TOPOLOGY_DATASET = "/Mesh/0/mesh/topology"
const RESOLVED3D_FIELD_DATASET = "/VisualisationVector/0"

"""
    Resolved3DWriterPaths(output_dir; ...)

Default file layout for one importer-compatible resolved-3D bundle. Geometry and
tetrahedral connectivity live in `mesh.h5`; each XDMF references that shared
mesh file together with a companion HDF5 field file.
"""
struct Resolved3DWriterPaths
    output_dir::String
    mesh_h5::String
    velocity_xdmf::String
    velocity_h5::String
    pressure_xdmf::String
    pressure_h5::String
    displacement_xdmf::String
    displacement_h5::String
end

function Resolved3DWriterPaths(
    output_dir::AbstractString;
    mesh_h5::AbstractString = RESOLVED3D_DEFAULT_MESH_H5,
    velocity_xdmf::AbstractString = RESOLVED3D_DEFAULT_VELOCITY_XDMF,
    velocity_h5::AbstractString = RESOLVED3D_DEFAULT_VELOCITY_H5,
    pressure_xdmf::AbstractString = RESOLVED3D_DEFAULT_PRESSURE_XDMF,
    pressure_h5::AbstractString = RESOLVED3D_DEFAULT_PRESSURE_H5,
    displacement_xdmf::AbstractString = RESOLVED3D_DEFAULT_DISPLACEMENT_XDMF,
    displacement_h5::AbstractString = RESOLVED3D_DEFAULT_DISPLACEMENT_H5,
)
    base = String(output_dir)
    return Resolved3DWriterPaths(
        base,
        joinpath(base, String(mesh_h5)),
        joinpath(base, String(velocity_xdmf)),
        joinpath(base, String(velocity_h5)),
        joinpath(base, String(pressure_xdmf)),
        joinpath(base, String(pressure_h5)),
        joinpath(base, String(displacement_xdmf)),
        joinpath(base, String(displacement_h5)),
    )
end

"""
    Resolved3DWriterResult

Written file paths plus the time stamped into the companion XDMF files.
Dataset locations stay fixed at:

`$RESOLVED3D_GEOMETRY_DATASET`, `$RESOLVED3D_TOPOLOGY_DATASET`,
`$RESOLVED3D_FIELD_DATASET`.
"""
struct Resolved3DWriterResult
    paths::Resolved3DWriterPaths
    time::Float64
end

"""
    write_resolved3d_field_bundle(output_dir, coordinates, topology, velocity, pressure, displacement; time=1.0, overwrite=false, ...)
    write_resolved3d_field_bundle(paths, coordinates, topology, velocity, pressure, displacement; time=1.0, overwrite=false)

Write a production resolved-3D velocity/pressure/displacement bundle that
round-trips through `load_resolved3d_field_bundle`. Pressure is required and may
be given either as a length-`N` vector or an `N x 1` matrix. Tetrahedral
connectivity may be passed as zero- or one-based indices; the writer stores the
bundle in zero-based `UInt32` form for compatibility with existing upstream
style fixtures.
"""
function write_resolved3d_field_bundle(
    output_dir::AbstractString,
    coordinates,
    topology,
    velocity,
    pressure,
    displacement;
    time::Real = RESOLVED3D_DEFAULT_BENCHMARK_TIME_S,
    overwrite::Bool = false,
    mesh_h5::AbstractString = RESOLVED3D_DEFAULT_MESH_H5,
    velocity_xdmf::AbstractString = RESOLVED3D_DEFAULT_VELOCITY_XDMF,
    velocity_h5::AbstractString = RESOLVED3D_DEFAULT_VELOCITY_H5,
    pressure_xdmf::AbstractString = RESOLVED3D_DEFAULT_PRESSURE_XDMF,
    pressure_h5::AbstractString = RESOLVED3D_DEFAULT_PRESSURE_H5,
    displacement_xdmf::AbstractString = RESOLVED3D_DEFAULT_DISPLACEMENT_XDMF,
    displacement_h5::AbstractString = RESOLVED3D_DEFAULT_DISPLACEMENT_H5,
)
    paths = Resolved3DWriterPaths(
        output_dir;
        mesh_h5,
        velocity_xdmf,
        velocity_h5,
        pressure_xdmf,
        pressure_h5,
        displacement_xdmf,
        displacement_h5,
    )
    return write_resolved3d_field_bundle(
        paths,
        coordinates,
        topology,
        velocity,
        pressure,
        displacement;
        time,
        overwrite,
    )
end

function write_resolved3d_field_bundle(
    paths::Resolved3DWriterPaths,
    coordinates,
    topology,
    velocity,
    pressure,
    displacement;
    time::Real = RESOLVED3D_DEFAULT_BENCHMARK_TIME_S,
    overwrite::Bool = false,
)
    time_value = Float64(time)
    isfinite(time_value) || throw(ArgumentError("resolved-3D writer time must be finite"))
    time_value >= 0.0 || throw(ArgumentError("resolved-3D writer time must be nonnegative"))

    coordinate_matrix = resolved3d_writer_matrix(coordinates, 3, "coordinates")
    node_count = size(coordinate_matrix, 1)
    velocity_matrix = resolved3d_writer_matrix(velocity, 3, "velocity"; rows=node_count)
    pressure_matrix = resolved3d_writer_pressure_matrix(pressure, node_count)
    displacement_matrix = resolved3d_writer_matrix(displacement, 3, "displacement"; rows=node_count)
    topology_matrix = resolved3d_writer_topology(topology, node_count)

    preflight_resolved3d_writer_paths(paths, overwrite)

    write_resolved3d_mesh_h5(paths.mesh_h5, coordinate_matrix, topology_matrix)
    write_resolved3d_field_h5(paths.velocity_h5, velocity_matrix)
    write_resolved3d_field_h5(paths.pressure_h5, pressure_matrix)
    write_resolved3d_field_h5(paths.displacement_h5, displacement_matrix)

    write_resolved3d_field_xdmf(
        paths.velocity_xdmf,
        paths.mesh_h5,
        RESOLVED3D_GEOMETRY_DATASET,
        RESOLVED3D_TOPOLOGY_DATASET,
        paths.velocity_h5,
        RESOLVED3D_FIELD_DATASET,
        "velocity",
        "Vector",
        size(coordinate_matrix),
        size(topology_matrix),
        size(velocity_matrix),
        time_value,
        overwrite,
    )
    write_resolved3d_field_xdmf(
        paths.pressure_xdmf,
        paths.mesh_h5,
        RESOLVED3D_GEOMETRY_DATASET,
        RESOLVED3D_TOPOLOGY_DATASET,
        paths.pressure_h5,
        RESOLVED3D_FIELD_DATASET,
        "pressure",
        "Scalar",
        size(coordinate_matrix),
        size(topology_matrix),
        size(pressure_matrix),
        time_value,
        overwrite,
    )
    write_resolved3d_field_xdmf(
        paths.displacement_xdmf,
        paths.mesh_h5,
        RESOLVED3D_GEOMETRY_DATASET,
        RESOLVED3D_TOPOLOGY_DATASET,
        paths.displacement_h5,
        RESOLVED3D_FIELD_DATASET,
        "displace",
        "Vector",
        size(coordinate_matrix),
        size(topology_matrix),
        size(displacement_matrix),
        time_value,
        overwrite,
    )

    return Resolved3DWriterResult(paths, time_value)
end

function preflight_resolved3d_writer_paths(paths::Resolved3DWriterPaths, overwrite::Bool)
    all_paths = resolved3d_writer_path_list(paths)
    length(unique(all_paths)) == length(all_paths) ||
        throw(ArgumentError("resolved-3D writer paths must be distinct"))

    for path in all_paths
        ensure_parent(path)
        if isfile(path) && !overwrite
            throw(ArgumentError("refusing to overwrite existing file '$path'; pass overwrite=true to allow replacement"))
        end
    end
    return nothing
end

function resolved3d_writer_path_list(paths::Resolved3DWriterPaths)
    return [
        paths.mesh_h5,
        paths.velocity_xdmf,
        paths.velocity_h5,
        paths.pressure_xdmf,
        paths.pressure_h5,
        paths.displacement_xdmf,
        paths.displacement_h5,
    ]
end

function resolved3d_writer_matrix(values, expected_cols::Int, label::String; rows::Union{Nothing,Int} = nothing)
    ndims(values) == 2 || throw(DimensionMismatch("$label must be a 2D matrix"))
    matrix = Matrix{Float64}(values)
    size(matrix, 2) == expected_cols ||
        throw(DimensionMismatch("$label must have $expected_cols columns, got $(size(matrix, 2))"))
    rows === nothing || size(matrix, 1) == rows ||
        throw(DimensionMismatch("$label row count $(size(matrix, 1)) does not match expected node count $rows"))
    isempty(matrix) && throw(ArgumentError("$label must not be empty"))
    all(isfinite, matrix) || throw(ArgumentError("$label contains non-finite values"))
    return matrix
end

function resolved3d_writer_pressure_matrix(pressure, node_count::Int)
    matrix = if ndims(pressure) == 1
        reshape(Vector{Float64}(pressure), :, 1)
    elseif ndims(pressure) == 2
        Matrix{Float64}(pressure)
    else
        throw(DimensionMismatch("pressure must be a vector or an N x 1 matrix"))
    end

    size(matrix, 1) == node_count ||
        throw(DimensionMismatch("pressure row count $(size(matrix, 1)) does not match expected node count $node_count"))
    size(matrix, 2) == 1 || throw(DimensionMismatch("pressure must have exactly 1 column"))
    isempty(matrix) && throw(ArgumentError("pressure must not be empty"))
    all(isfinite, matrix) || throw(ArgumentError("pressure contains non-finite values"))
    return matrix
end

function resolved3d_writer_topology(topology, node_count::Int)
    ndims(topology) == 2 || throw(DimensionMismatch("topology must be a 2D matrix"))
    topology_matrix = Matrix{Int}(topology)
    size(topology_matrix, 2) == 4 || throw(DimensionMismatch("topology must have 4 tetrahedral columns"))
    isempty(topology_matrix) && throw(ArgumentError("topology must not be empty"))

    normalized = normalized_tetra_topology(topology_matrix)
    validate_tetra_topology(normalized, node_count)
    return UInt32.(normalized .- 1)
end

function write_resolved3d_mesh_h5(path::String, coordinates::Matrix{Float64}, topology::Matrix{UInt32})
    HDF5.h5open(path, "w") do file
        mesh = HDF5.create_group(HDF5.create_group(HDF5.create_group(file, "Mesh"), "0"), "mesh")
        mesh["geometry"] = coordinates
        mesh["topology"] = topology
    end
    return path
end

function write_resolved3d_field_h5(path::String, values::Matrix{Float64})
    HDF5.h5open(path, "w") do file
        vector_group = HDF5.create_group(file, "VisualisationVector")
        vector_group["0"] = values
    end
    return path
end

function write_resolved3d_field_xdmf(
    xdmf_path::String,
    mesh_h5_path::String,
    geometry_dataset::String,
    topology_dataset::String,
    field_h5_path::String,
    field_dataset::String,
    attribute_name::String,
    attribute_type::String,
    geometry_dims::Tuple{Int,Int},
    topology_dims::Tuple{Int,Int},
    field_dims::Tuple{Int,Int},
    time::Float64,
    overwrite::Bool,
)
    mesh_ref = resolved3d_xdmf_hdf_reference(xdmf_path, mesh_h5_path, topology_dataset)
    geometry_ref = resolved3d_xdmf_hdf_reference(xdmf_path, mesh_h5_path, geometry_dataset)
    field_ref = resolved3d_xdmf_hdf_reference(xdmf_path, field_h5_path, field_dataset)
    guarded_open_write(xdmf_path, overwrite) do io
        write(
            io,
            """
            <?xml version="1.0"?>
            <Xdmf Version="3.0">
              <Domain>
                <Grid Name="mesh" GridType="Uniform">
                  <Topology NumberOfElements="$(topology_dims[1])" TopologyType="Tetrahedron" NodesPerElement="4">
                    <DataItem Dimensions="$(topology_dims[1]) $(topology_dims[2])" NumberType="UInt" Format="HDF">$mesh_ref</DataItem>
                  </Topology>
                  <Geometry GeometryType="XYZ">
                    <DataItem Dimensions="$(geometry_dims[1]) $(geometry_dims[2])" Format="HDF">$geometry_ref</DataItem>
                  </Geometry>
                  <Time Value="$time" />
                  <Attribute Name="$attribute_name" AttributeType="$attribute_type" Center="Node">
                    <DataItem Dimensions="$(field_dims[1]) $(field_dims[2])" Format="HDF">$field_ref</DataItem>
                  </Attribute>
                </Grid>
              </Domain>
            </Xdmf>
            """,
        )
    end
    return xdmf_path
end

function resolved3d_xdmf_hdf_reference(xdmf_path::String, h5_path::String, dataset_path::String)
    relative_h5 = relpath(h5_path, dirname(xdmf_path))
    return "$(relative_h5):$(dataset_path)"
end
