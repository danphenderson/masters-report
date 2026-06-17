function assert_finite_positive_state(result::SimulationResult, params::Params)
    @test result.completed_time ≈ params.tfinal
    @test result.steps >= 0
    @test length(result.area) == params.nx
    @test length(result.flow) == params.nx
    @test all(isfinite, result.area)
    @test all(isfinite, result.flow)
    @test minimum(result.area) > 0.0

    pressure_values = pressure(result, params)
    @test length(pressure_values) == params.nx
    @test all(isfinite, pressure_values)
end

function synthetic_coordinates()
    z_planes = [0.0, 3.0, 6.0]
    radii = [0.0, 0.025, 0.05, 0.075, 0.10]
    angles = [0.0, pi / 2.0, pi, 3.0 * pi / 2.0]
    rows = Tuple{Float64,Float64,Float64}[]

    for z in z_planes
        for r in radii
            if r == 0.0
                push!(rows, (0.0, 0.0, z))
            else
                for theta in angles
                    push!(rows, (r * cos(theta), r * sin(theta), z))
                end
            end
        end
    end

    coords = zeros(Float64, length(rows), 3)
    for (i, row) in enumerate(rows)
        coords[i, 1] = row[1]
        coords[i, 2] = row[2]
        coords[i, 3] = row[3]
    end
    return coords
end

function write_synthetic_xdmf_hdf5_case(
    case_dir::String;
    time::Float64 = 5.0e-5,
    omit_velocity_dataset::Bool = false,
)
    mkpath(case_dir)
    coords = synthetic_coordinates()
    velocity_values = zeros(Float64, size(coords, 1), 3)
    for i in axes(coords, 1)
        velocity_values[i, 3] = 10.0 + coords[i, 3]
    end
    topology = Int32[
        0 1 2 3
        4 5 6 7
    ]

    h5_path = joinpath(case_dir, "velocity.h5")
    h5open(h5_path, "w") do file
        mesh = create_group(create_group(create_group(file, "Mesh"), "0"), "mesh")
        mesh["geometry"] = coords
        mesh["topology"] = topology
        if !omit_velocity_dataset
            vector_group = create_group(file, "VisualisationVector")
            vector_group["0"] = velocity_values
        end
    end

    xdmf_path = joinpath(case_dir, "velocity.xdmf")
    write(
        xdmf_path,
        """
        <?xml version="1.0"?>
        <Xdmf Version="3.0">
          <Domain>
            <Grid Name="mesh" GridType="Uniform">
              <Topology NumberOfElements="$(size(topology, 1))" TopologyType="Tetrahedron" NodesPerElement="4">
                <DataItem Dimensions="$(size(topology, 1)) 4" NumberType="UInt" Format="HDF">velocity.h5:/Mesh/0/mesh/topology</DataItem>
              </Topology>
              <Geometry GeometryType="XYZ">
                <DataItem Dimensions="$(size(coords, 1)) 3" Format="HDF">velocity.h5:/Mesh/0/mesh/geometry</DataItem>
              </Geometry>
              <Time Value="$time" />
              <Attribute Name="velocity" AttributeType="Vector" Center="Node">
                <DataItem Dimensions="$(size(coords, 1)) 3" Format="HDF">velocity.h5:/VisualisationVector/0</DataItem>
              </Attribute>
            </Grid>
          </Domain>
        </Xdmf>
        """,
    )

    return xdmf_path, coords, velocity_values
end

function read_simple_csv(path::String)
    lines = readlines(path)
    headers = split(lines[1], ",")
    rows = Dict{String,String}[]
    for line in lines[2:end]
        isempty(strip(line)) && continue
        startswith(line, "#") && continue
        values = split(line, ",")
        push!(rows, Dict(header => value for (header, value) in zip(headers, values)))
    end
    return rows
end
