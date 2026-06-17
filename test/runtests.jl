if VERSION < v"1.12"
    error(
        "test/runtests.jl requires Julia 1.12 or newer. " *
        "Run it with ./scripts/julia-release test/runtests.jl.",
    )
end

using Test
using HDF5

include(joinpath(@__DIR__, "..", "simulations", "canic_extended_1d", "CanicExtended1D.jl"))
using .CanicExtended1D

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

@testset "CanicExtended1D simulation backends" begin
    native_params = Params(nx=8, tfinal=5.0e-5, severity=30.0)

    @testset "native short run" begin
        result = simulate(native_params, NativeRK3Backend(); progress_every=0)
        assert_finite_positive_state(result, native_params)
    end

    @testset "SciML short run" begin
        backend = SciMLTimeBackend(
            solve=SolveSpec(
                algorithm=Tsit5Policy(),
                abstol=1.0e-9,
                reltol=1.0e-9,
            ),
        )
        result = simulate(native_params, backend; progress_every=0)
        assert_finite_positive_state(result, native_params)
    end

    @testset "native and SciML tiny-run agreement" begin
        backend = SciMLTimeBackend(
            solve=SolveSpec(
                algorithm=Tsit5Policy(),
                abstol=1.0e-9,
                reltol=1.0e-9,
            ),
        )
        native = simulate(native_params, NativeRK3Backend(); progress_every=0)
        sciml = simulate(native_params, backend; progress_every=0)

        # Different time integrators are expected to diverge on longer runs;
        # this smoke comparison only checks the shared semi-discrete RHS on a
        # tiny horizon where RK3 and tight-tolerance Tsit5 agree closely.
        @test maximum(abs.(native.area .- sciml.area)) <= 1.0e-8
        @test maximum(abs.(native.flow .- sciml.flow)) <= 1.0e-5
        @test maximum(abs.(velocity(native) .- velocity(sciml))) <= 1.0e-3
    end
end

@testset "CanicExtended1D resolved 3D parsing and loading" begin
    mktempdir() do dir
        xdmf_path, coords, velocity_values = write_synthetic_xdmf_hdf5_case(joinpath(dir, "synthetic"))

        metadata = parse_xdmf_velocity(xdmf_path)
        @test metadata.time ≈ 5.0e-5
        @test metadata.geometry_file == "velocity.h5"
        @test metadata.geometry_path == "/Mesh/0/mesh/geometry"
        @test metadata.geometry_dims == (size(coords, 1), 3)
        @test metadata.topology_path == "/Mesh/0/mesh/topology"
        @test metadata.topology_dims == (2, 4)
        @test metadata.velocity_path == "/VisualisationVector/0"
        @test metadata.velocity_dims == (size(velocity_values, 1), 3)

        case_spec = Resolved3DCaseSpec("synthetic", 23.0, xdmf_path; target_time=5.0e-5)
        field = load_resolved3d_velocity(case_spec)
        @test size(field.coordinates) == size(coords)
        @test size(field.velocity) == size(velocity_values)
        @test field.metadata.time ≈ 5.0e-5

        mismatched_time = Resolved3DCaseSpec("synthetic", 23.0, xdmf_path; target_time=1.0, time_atol=1.0e-8)
        @test_throws ArgumentError load_resolved3d_velocity(mismatched_time)

        missing_xdmf_path, _, _ = write_synthetic_xdmf_hdf5_case(
            joinpath(dir, "missing_velocity");
            omit_velocity_dataset=true,
        )
        missing_velocity = Resolved3DCaseSpec("missing", 23.0, missing_xdmf_path; target_time=5.0e-5)
        @test_throws ArgumentError load_resolved3d_velocity(missing_velocity)
    end
end

@testset "CanicExtended1D resolved 3D comparison diagnostics" begin
    mktempdir() do dir
        xdmf_path, _, _ = write_synthetic_xdmf_hdf5_case(joinpath(dir, "case77"))
        case_spec = Resolved3DCaseSpec("77", 23.0, xdmf_path; target_time=5.0e-5)
        output_dir = joinpath(dir, "out")
        spec = ComparisonSpec(
            cases=[case_spec],
            base_params=Params(nx=8, tfinal=5.0e-5, severity=23.0),
            output_dir=output_dir,
            section_count=3,
            profile_slices=[3.0],
            radial_bins=5,
            overwrite=true,
            write_svg=false,
        )

        result = run_comparison(spec)
        @test length(result.section_rows) == 3
        @test length(result.profile_rows) == 5
        @test length(result.summary_rows) == 1
        @test isfile(result.section_csvs[1])
        @test isfile(result.profile_csvs[1])
        @test isfile(result.summary_csv)

        for row in result.section_rows
            @test row.node_count > 0
            @test row.u3d_cm_s ≈ 10.0 + row.z_cm
            @test isfinite(row.u1d_cm_s)
            @test isfinite(row.abs_error_cm_s)
            @test isfinite(row.rel_error)
        end

        populated_profiles = [row for row in result.profile_rows if row.node_count > 0]
        @test !isempty(populated_profiles)
        @test all(isfinite(row.u1d_cm_s) for row in result.profile_rows)
        @test all(isfinite(row.u3d_cm_s) for row in populated_profiles)
        @test all(isfinite(row.abs_error_cm_s) for row in populated_profiles)
    end
end

@testset "CanicExtended1D resolved 3D absent-data skip" begin
    mktempdir() do dir
        missing_root = joinpath(dir, "not_present")
        @test isempty(available_resolved3d_cases(missing_root))
        @test run_available_resolved3d_comparison(data_root=missing_root, write_svg=false) === nothing
    end
end

@testset "CanicExtended1D CLI parsing" begin
    @test parse_args(["--help"]) === nothing

    @testset "native defaults" begin
        params, output, backend = parse_args([
            "--tfinal", "5e-5",
            "--nx", "8",
            "--progress-every", "0",
            "--no-svg",
        ])

        @test params.tfinal == 5.0e-5
        @test params.nx == 8
        @test output.progress_every == 0
        @test output.write_svg == false
        @test backend isa NativeRK3Backend
    end

    @testset "SciML flags" begin
        params, output, backend = parse_args([
            "--backend", "sciml",
            "--alg", "tsit5",
            "--abstol", "1e-8",
            "--reltol=1e-7",
            "--save-everystep",
            "--maxiters", "123",
            "--tfinal", "5e-5",
            "--nx", "8",
            "--progress-every", "0",
            "--no-svg",
        ])

        @test params.tfinal == 5.0e-5
        @test output.write_svg == false
        @test backend isa SciMLTimeBackend
        @test backend.solve.algorithm isa Tsit5Policy
        @test backend.solve.abstol == 1.0e-8
        @test backend.solve.reltol == 1.0e-7
        @test backend.solve.save_everystep == true
        @test backend.solve.maxiters == 123
    end

    @testset "invalid combinations" begin
        @test_throws ArgumentError parse_args(["--backend", "native", "--alg", "tsit5"])
        @test_throws ArgumentError parse_args(["--backend", "sciml", "--alg", "ssprk"])
        @test_throws ArgumentError parse_args(["--abstol", "1e-8"])
        @test_throws ArgumentError parse_args(["--backend", "sciml", "--alg", "not-a-policy"])
    end
end
