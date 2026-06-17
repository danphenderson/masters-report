if VERSION < v"1.12"
    error(
        "test/runtests.jl requires Julia 1.12 or newer. " *
        "Run it with ./scripts/julia-release test/runtests.jl.",
    )
end

using Test
using Distributed
using HDF5
using LinearAlgebra
using Statistics

include(joinpath(@__DIR__, "..", "simulations", "canic_extended_1d", "CanicExtended1D.jl"))
using .CanicExtended1D
include(joinpath(@__DIR__, "..", "simulations", "export_stenosis_geometry_figures.jl"))

@testset "CanicExtended1D case worker configuration" begin
    @test CanicExtended1D.default_case_workers(Dict("JULIA_CASE_WORKERS" => "3")) == 3
    @test CanicExtended1D.default_case_workers(Dict("JULIA_CASE_WORKERS" => "")) == 1
    @test CanicExtended1D.effective_case_workers(3, 10) == 3
    @test CanicExtended1D.effective_case_workers(3, 0) == 0
    @test_throws ArgumentError CanicExtended1D.default_case_workers(Dict("JULIA_CASE_WORKERS" => "many"))
    @test parallel_case_map(x -> x + 1, [1, 2, 3]; parallel_workers=1) == [2, 3, 4]

    worker_rows = parallel_case_map([1, 2]; parallel_workers=2) do value
        (
            value=value,
            pid=Distributed.myid(),
            threads=Threads.nthreads(),
            blas_threads=LinearAlgebra.BLAS.get_num_threads(),
        )
    end

    @test [row.value for row in worker_rows] == [1, 2]
    @test all(row.pid != 1 for row in worker_rows)
    @test all(row.threads == 1 for row in worker_rows)
    @test all(row.blas_threads == 1 for row in worker_rows)
end

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

@testset "CanicExtended1D rheology closures" begin
    @test rheology_name(NewtonianRheology()) == "newtonian"
    @test effective_kinematic_viscosity(NewtonianRheology(), 25.0, 1.055, 0.04) ≈ 0.04

    carreau = CarreauRheology(eta0=0.10, eta_inf=0.02, lambda_s=2.0, n=0.5)
    expected_carreau = 0.02 + (0.10 - 0.02) * (1.0 + (2.0 * 3.0)^2)^((0.5 - 1.0) / 2.0)
    @test effective_dynamic_viscosity(carreau, 3.0, 1.055, 0.04) ≈ expected_carreau

    carreau_yasuda = CarreauYasudaRheology(eta0=0.10, eta_inf=0.02, lambda_s=2.0, a=1.5, n=0.5)
    expected_carreau_yasuda = 0.02 + (0.10 - 0.02) * (1.0 + (2.0 * 3.0)^1.5)^((0.5 - 1.0) / 1.5)
    @test effective_dynamic_viscosity(carreau_yasuda, 3.0, 1.055, 0.04) ≈ expected_carreau_yasuda

    casson = CassonRheology(yield_stress=0.09, plastic_viscosity=0.04)
    expected_casson = (sqrt(0.09 / 9.0) + sqrt(0.04))^2
    @test effective_dynamic_viscosity(casson, 9.0, 1.055, 0.04) ≈ expected_casson

    power_law = PowerLawRheology(consistency=0.12, n=0.75)
    @test effective_dynamic_viscosity(power_law, 16.0, 1.055, 0.04) ≈ 0.12 * 16.0^-0.25

    clamped = PowerLawRheology(consistency=10.0, n=0.5, max_eta=0.2)
    @test effective_dynamic_viscosity(clamped, 1.0e-4, 1.055, 0.04) ≈ 0.2

    legacy_alpha = Params(alpha=1.1, initial_condition=GeometryRestIC())
    @test legacy_alpha.velocity_profile isa PowerVelocityProfile
    @test legacy_alpha.alpha ≈ 1.1
    @test characteristic_shear_rate(0.04, 0.2, 0.2, legacy_alpha) > 0.0
    @test_throws ArgumentError CanicExtended1D.validate(CarreauRheology(eta0=0.01, eta_inf=0.02))
end

@testset "CanicExtended1D velocity profiles" begin
    parabolic = ParabolicVelocityProfile()
    @test profile_name(parabolic) == "parabolic"
    @test momentum_alpha(parabolic) ≈ 4.0 / 3.0
    @test shear_rate_factor(parabolic) ≈ 4.0
    @test mean_to_max_velocity_ratio(parabolic) ≈ 0.5
    @test radial_profile_velocity(3.0, 0.0, 2.0, parabolic) ≈ 6.0
    @test radial_profile_velocity(3.0, 2.0, 2.0, parabolic) ≈ 0.0

    flat = FlatVelocityProfile(shear_rate_factor=5.0)
    @test profile_name(flat) == "flat"
    @test momentum_alpha(flat) ≈ 1.0
    @test shear_rate_factor(flat) ≈ 5.0
    @test mean_to_max_velocity_ratio(flat) ≈ 1.0
    @test radial_profile_velocity(3.0, 1.5, 2.0, flat) ≈ 3.0

    power = PowerVelocityProfile(exponent=2.0)
    @test momentum_alpha(power) ≈ 4.0 / 3.0
    @test shear_rate_factor(power) ≈ 4.0
    @test mean_to_max_velocity_ratio(power) ≈ 0.5

    legacy_power = PowerVelocityProfile(alpha=1.1)
    @test legacy_power.exponent ≈ 9.0
    @test momentum_alpha(legacy_power) ≈ 1.1
    @test shear_rate_factor(legacy_power) ≈ 11.0

    default_params = Params(initial_condition=GeometryRestIC())
    @test default_params.velocity_profile isa ParabolicVelocityProfile
    @test default_params.alpha ≈ 4.0 / 3.0
    @test CanicExtended1D.inlet_uavg(default_params) ≈ 22.5
    @test CanicExtended1D.inlet_uavg(Params(initial_condition=GeometryRestIC(), velocity_profile=flat)) ≈ 45.0
    @test default_output_stub(Params()) == "simulations/output/canic_extended_1d_severity50_vp_parabolic"
    @test occursin("vp_parabolic", default_output_stub(default_params))
    @test default_output_stub(default_params) != default_output_stub(Params(alpha=1.1, initial_condition=GeometryRestIC()))
    @test default_output_stub(Params(initial_condition=GeometryRestIC(), velocity_profile=PowerVelocityProfile(exponent=4.0))) !=
          default_output_stub(Params(initial_condition=GeometryRestIC(), velocity_profile=PowerVelocityProfile(exponent=9.0)))
    @test default_output_stub(Params(initial_condition=GeometryRestIC(), velocity_profile=FlatVelocityProfile(shear_rate_factor=4.0))) !=
          default_output_stub(Params(initial_condition=GeometryRestIC(), velocity_profile=FlatVelocityProfile(shear_rate_factor=8.0)))
    @test_throws ArgumentError Params(alpha=1.1, velocity_profile=ParabolicVelocityProfile())
    @test_throws ArgumentError CanicExtended1D.params_with(default_params; velocity_profile=flat, alpha=1.1)
    @test_throws ArgumentError CanicExtended1D.validate(FlatVelocityProfile(shear_rate_factor=0.0))
    @test_throws ArgumentError PowerVelocityProfile(alpha=1.0)
end

@testset "CanicExtended1D inlet and outlet boundaries" begin
    waveform = FlowWaveformInlet([0.0, 1.0], [0.0, 10.0])
    waveform_params = Params(initial_condition=GeometryRestIC(), inlet_boundary=waveform)
    @test inlet_boundary_name(waveform_params.inlet_boundary) == "flow-waveform"
    @test inlet_flow(waveform_params, 0.5) ≈ 5.0
    @test inlet_flow(waveform_params, 1.25) ≈ 2.5

    steady_params = Params(initial_condition=GeometryRestIC(), inlet_boundary=SteadyVelocityInlet(20.0))
    r0_in, _, _ = CanicExtended1D.stenosis(0.0, steady_params)
    @test inlet_boundary_name(steady_params.inlet_boundary) == "steady-velocity"
    @test inlet_flow(steady_params, 10.0) ≈ r0_in^2 * 10.0

    rt_params = Params(
        nx=4,
        severity=0.0,
        initial_condition=GeometryRestIC(),
        outlet_boundary=ReflectionCoefficientOutlet(0.0),
    )
    _, _, Aout, Qout = CanicExtended1D.boundary_states([0.04, 0.04, 0.04, 0.04], [0.0, 0.0, 0.0, 0.01], rt_params, 0.0)
    r0_out, _, _ = CanicExtended1D.stenosis(rt_params.length_cm, rt_params)
    @test CanicExtended1D.invariant_minus(Aout, Qout, rt_params) ≈ CanicExtended1D.invariant_minus(r0_out^2, 0.0, rt_params)
    @test_throws ArgumentError CanicExtended1D.validate(ReflectionCoefficientOutlet(1.5))
end

@testset "CanicExtended1D spatial methods and steppers" begin
    @test minmod(2.0, 3.0) == 2.0
    @test minmod(-2.0, -3.0) == -2.0
    @test minmod(-2.0, 3.0) == 0.0

    @test CanicExtended1D.reconstructed_area(0.02, -0.01, 1.0) > 0.0
    @test CanicExtended1D.reconstructed_area(1.0e-14, -1.0, 1.0) >= CanicExtended1D.AREA_LIMITER_FLOOR

    xis, weights = dg_quadrature()
    @test sum(weights) ≈ 2.0
    @test sum(w * legendre_value(1, xi) for (xi, w) in zip(xis, weights)) ≈ 0.0 atol=1.0e-14
    @test sum(w * legendre_value(2, xi) for (xi, w) in zip(xis, weights)) ≈ 0.0 atol=1.0e-14
    @test sum(w * xi^4 for (xi, w) in zip(xis, weights)) ≈ 2.0 / 5.0

    @test observed_order(0.25, 0.125) ≈ 1.0
    @test isnan(observed_order(0.0, 0.125))
end

function write_openbf_fixture(dir::String; project_name::String = "strict_one", extra_vessel::String = "", include_canic::Bool = true)
    inlet_path = joinpath(dir, "inlet.dat")
    write(
        inlet_path,
        """
        0.0 1.0e-6
        1.0e-5 2.0e-6
        """,
    )

    canic_block = include_canic ? """
    canic:
      severity_percent: 30.0
      dt: 1.0e-5
      initial_condition:
        pressure_drop_pa: 40.0
        mesh_nz: 1
        mesh_nr: 1
        mesh_ntheta: 4
    """ : ""

    config_path = joinpath(dir, "input.yml")
    write(
        config_path,
        """
        project_name: $project_name
        inlet_file: "inlet.dat"
        output_directory: "out"
        write_results: ["P", "Q", "A", "u"]
        blood:
          rho: 1060.0
          mu: 0.004
        solver:
          Ccfl: 0.45
          cycles: 2
          jump: 5
          convergence_tolerance: 1.0
        network:
          - label: vessel
            sn: 1
            tn: 2
            L: 0.06
            M: 8
            E: 5.02e5
            R0: 0.0018
            h0: 0.0006
            gamma_profile: 9
            Rt: 0.25
            $extra_vessel
        $canic_block
        """,
    )
    return config_path, inlet_path
end

@testset "CanicExtended1D OpenBF protocol adapter" begin
    mktempdir() do dir
        config_path, inlet_path = write_openbf_fixture(dir)
        spec = load_openbf_config(config_path)
        params, output, backend, returned_spec = params_from_openbf_config(config_path)

        @test returned_spec.project_name == spec.project_name
        @test spec.inlet_file == inlet_path
        @test spec.output_directory == joinpath(dir, "out")
        @test spec.write_results == ["P", "Q", "A", "u"]
        @test spec.cycles == 2
        @test spec.inlet_period_s ≈ 1.0e-5
        @test spec.params.tfinal ≈ 2.0e-5
        @test spec.params.length_cm ≈ 6.0
        @test spec.params.rmax ≈ 0.18
        @test spec.params.young ≈ 5.02e6
        @test spec.params.wall_h ≈ 0.06
        @test spec.params.rho ≈ 1.06
        @test spec.params.nu ≈ 1.0e4 * 0.004 / 1060.0
        @test spec.params.velocity_profile isa PowerVelocityProfile
        @test spec.params.inlet_boundary isa FlowWaveformInlet
        @test inlet_flow(spec.params, 5.0e-6) ≈ 1.5
        @test spec.params.outlet_boundary isa ReflectionCoefficientOutlet
        @test spec.params.outlet_boundary.rt ≈ 0.25
        @test params.tfinal ≈ spec.params.tfinal
        @test output.csv == spec.output.csv
        @test backend isa NativeRK3Backend
    end

    mktempdir() do dir
        config_path, _ = write_openbf_fixture(dir; project_name="smoke")
        result = run_simulation(config_path; save_stats=true)
        @test result.completed_time ≈ 2.0e-5
        @test isfile(joinpath(dir, "out", "smoke.csv"))
        @test isfile(joinpath(dir, "out", "smoke.svg"))
        @test isfile(joinpath(dir, "out", "smoke.conv"))
    end

    mktempdir() do dir
        config_path, _ = write_openbf_fixture(dir; include_canic=false)
        @test_throws ArgumentError load_openbf_config(config_path)
    end

    mktempdir() do dir
        config_path, _ = write_openbf_fixture(dir; extra_vessel="R1: 1.0e7")
        @test_throws ArgumentError load_openbf_config(config_path)
    end

    mktempdir() do dir
        bad_inlet = joinpath(dir, "bad.dat")
        write(bad_inlet, "0.0 1.0 2.0\n")
        @test_throws ArgumentError FlowWaveformInlet(bad_inlet)
    end
end

@testset "CanicExtended1D stationary Stokes initial conditions" begin
    @test_throws ArgumentError CanicExtended1D.validate(Params(nx=8, tfinal=0.0, severity=0.0))
    @test_throws ArgumentError StationaryStokesIC(pressure_drop_pa=40.0, pressure_drop_dyn_cm2=400.0)

    ic = StationaryStokesIC(
        pressure_drop_pa=40.0,
        mesh_nz=2,
        mesh_nr=2,
        mesh_ntheta=8,
        projection_nr=2,
        projection_ntheta=8,
    )
    params = Params(nx=6, tfinal=0.0, severity=0.0, initial_condition=ic)
    mesh = generated_stokes_mesh(params, ic)
    @test length(mesh.coordinates) == (ic.mesh_nz + 1) * (1 + ic.mesh_nr * ic.mesh_ntheta)
    @test length(mesh.cells) == ic.mesh_nz * ic.mesh_ntheta * (1 + 2 * (ic.mesh_nr - 1)) * 3
    @test mesh.inlet_nodes == 1 + ic.mesh_nr * ic.mesh_ntheta
    @test mesh.outlet_nodes == mesh.inlet_nodes
    @test mesh.wall_nodes == (ic.mesh_nz + 1) * ic.mesh_ntheta

    state = initial_state_result(params)
    @test state.summary.kind == "stationary-stokes"
    @test state.summary.mesh_nodes == length(mesh.coordinates)
    @test state.summary.mesh_cells == length(mesh.cells)
    @test state.summary.velocity_dofs > 0
    @test state.summary.pressure_dofs > 0
    @test all(isfinite, state.area)
    @test all(isfinite, state.flow)
    @test minimum(state.area) > 0.0

    projected_pressure = pressure(state.area, state.flow, state.z, params)
    @test maximum(abs.(projected_pressure .- range(maximum(projected_pressure), minimum(projected_pressure); length=length(projected_pressure)))) < ic.pressure_drop_dyn_cm2

    u_mean = mean(velocity(SimulationResult(state.z, state.area, state.flow, 0.0, 0)))
    mu = params.rho * params.nu
    analytic_u = ic.pressure_drop_dyn_cm2 * params.rmax^2 / (8.0 * mu * params.length_cm)
    @test isapprox(u_mean, analytic_u; rtol=0.45)

    repeat_state = initial_state_result(params)
    @test repeat_state.summary.projection_hash == state.summary.projection_hash
    @test repeat_state.area ≈ state.area
    @test repeat_state.flow ≈ state.flow
end

@testset "CanicExtended1D simulation backends" begin
    native_params = Params(nx=8, tfinal=5.0e-5, severity=30.0, initial_condition=GeometryRestIC())

    @testset "native short run" begin
        result = simulate(native_params, NativeRK3Backend(); progress_every=0)
        assert_finite_positive_state(result, native_params)
    end

    @testset "native short run with Carreau-Yasuda rheology" begin
        rheology_params = Params(
            nx=8,
            tfinal=2.0e-5,
            severity=30.0,
            rheology=CarreauYasudaRheology(max_eta=0.5),
            initial_condition=GeometryRestIC(),
        )
        result = simulate(rheology_params, NativeRK3Backend(); progress_every=0)
        assert_finite_positive_state(result, rheology_params)
    end

    @testset "native spatial method smoke runs" begin
        for method in (FVMUSCLMethod(), FVLaxWendroffMethod(), DGMethod(0), DGMethod(1), DGMethod(2))
            params = Params(nx=8, tfinal=1.0e-5, severity=30.0, space=method, initial_condition=GeometryRestIC())
            result = simulate(params, NativeRK3Backend(); progress_every=0)
            assert_finite_positive_state(result, params)
        end
    end

    @testset "native time stepper smoke runs" begin
        for stepper in (ForwardEulerStepper(), SSPRK2Stepper(), SSPRK3Stepper())
            params = Params(nx=8, tfinal=1.0e-5, severity=30.0, time_stepper=stepper, initial_condition=GeometryRestIC())
            result = simulate(params, NativeRK3Backend(); progress_every=0)
            assert_finite_positive_state(result, params)
        end
    end

    @testset "native velocity profile smoke runs" begin
        for profile in (FlatVelocityProfile(), ParabolicVelocityProfile(), PowerVelocityProfile(exponent=9.0))
            params = Params(nx=8, tfinal=1.0e-5, severity=30.0, velocity_profile=profile, initial_condition=GeometryRestIC())
            result = simulate(params, NativeRK3Backend(); progress_every=0)
            assert_finite_positive_state(result, params)
        end
    end

    @testset "DG p0 finite-volume equivalence" begin
        fv_params = Params(nx=8, tfinal=1.0e-5, severity=30.0, space=FVFirstOrderMethod(), initial_condition=GeometryRestIC())
        dg_params = Params(nx=8, tfinal=1.0e-5, severity=30.0, space=DGMethod(0), initial_condition=GeometryRestIC())
        fv = simulate(fv_params, NativeRK3Backend(); progress_every=0)
        dg = simulate(dg_params, NativeRK3Backend(); progress_every=0)
        @test maximum(abs.(fv.area .- dg.area)) <= 1.0e-12
        @test maximum(abs.(fv.flow .- dg.flow)) <= 1.0e-12
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
            base_params=Params(nx=8, tfinal=5.0e-5, severity=23.0, initial_condition=GeometryRestIC()),
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

@testset "stenosis geometry figure trajectory exports" begin
    mktempdir() do dir
        opts = ExportOptions(output_dir=dir, z_samples=31, theta_samples=12, overwrite=true)
        export_analytic_summary(opts)
        summary_rows = read_simple_csv(joinpath(dir, "analytic_summary.csv"))
        sev73 = only(row for row in summary_rows if parse(Float64, row["severity"]) == 73.0)
        @test parse(Float64, sev73["rmin_over_rbase"]) ≈ 0.27 atol=5.0e-4

        paths = export_stokes_particle_trajectories(
            opts;
            ic=StationaryStokesIC(
                pressure_drop_pa=40.0,
                mesh_nz=2,
                mesh_nr=2,
                mesh_ntheta=8,
            ),
            z_samples=13,
            parallel_workers=1,
        )
        trajectory_rows = read_simple_csv(paths[1])
        @test length(trajectory_rows) == 3 * 5 * 13

        grouped = Dict{Tuple{Int,Int},Vector{Dict{String,String}}}()
        for row in trajectory_rows
            severity = round(Int, parse(Float64, row["severity"]))
            particle_id = parse(Int, row["particle_id"])
            key = (severity, particle_id)
            push!(get!(grouped, key, Dict{String,String}[]), row)

            z = parse(Float64, row["z_cm"])
            x = parse(Float64, row["x_cm"])
            y = parse(Float64, row["y_cm"])
            r_over_r0 = parse(Float64, row["r_over_r0"])
            t = parse(Float64, row["t_s"])
            ux = parse(Float64, row["ux_cm_s"])
            uy = parse(Float64, row["uy_cm_s"])
            uz = parse(Float64, row["uz_cm_s"])
            @test all(isfinite, (z, x, y, r_over_r0, t, ux, uy, uz))
            @test r_over_r0 <= 1.0001

            params = Params(severity=severity, initial_condition=GeometryRestIC())
            r0, _, _ = CanicExtended1D.stenosis(z, params)
            @test hypot(x, y) <= 1.0001 * r0
        end

        @test sort(unique(first(key) for key in keys(grouped))) == [23, 50, 73]
        @test all(length(rows) == 13 for rows in values(grouped))
        for rows in values(grouped)
            sort!(rows; by=row -> parse(Int, row["sample_index"]))
            z_values = [parse(Float64, row["z_cm"]) for row in rows]
            @test all(z_values[i] < z_values[i + 1] for i in 1:(length(z_values) - 1))
        end
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
            "--ic-pressure-drop-pa", "40",
        ])

        @test params.tfinal == 5.0e-5
        @test params.nx == 8
        @test params.space isa FVMUSCLMethod
        @test params.time_stepper isa SSPRK3Stepper
        @test params.rheology isa NewtonianRheology
        @test params.velocity_profile isa ParabolicVelocityProfile
        @test params.alpha ≈ 4.0 / 3.0
        @test params.initial_condition isa StationaryStokesIC
        @test params.initial_condition.pressure_drop_dyn_cm2 == 400.0
        @test output.progress_every == 0
        @test output.write_svg == false
        @test backend isa NativeRK3Backend
    end

    @testset "rheology flags" begin
        params, output, backend = parse_args([
            "--rheology", "carreau-yasuda",
            "--eta0", "0.2",
            "--eta-inf", "0.03",
            "--lambda-s", "1.5",
            "--yasuda-a", "1.25",
            "--flow-index", "0.6",
            "--shear-floor", "1e-6",
            "--min-eta", "0.02",
            "--max-eta", "0.4",
            "--nu", "0.05",
            "--tfinal", "5e-5",
            "--nx", "8",
            "--progress-every", "0",
            "--no-svg",
            "--ic", "geometry-rest",
        ])

        @test output.write_svg == false
        @test backend isa NativeRK3Backend
        @test params.nu == 0.05
        @test params.rheology isa CarreauYasudaRheology
        @test params.rheology.eta0 == 0.2
        @test params.rheology.eta_inf == 0.03
        @test params.rheology.lambda_s == 1.5
        @test params.rheology.a == 1.25
        @test params.rheology.n == 0.6
        @test params.rheology.shear_rate_floor == 1.0e-6
        @test params.rheology.min_eta == 0.02
        @test params.rheology.max_eta == 0.4
    end

    @testset "spatial and time-stepper flags" begin
        params, _, backend = parse_args([
            "--space", "dg",
            "--degree", "2",
            "--time-stepper", "ssprk2",
            "--limiter", "minmod",
            "--tfinal", "5e-5",
            "--nx", "8",
            "--progress-every", "0",
            "--no-svg",
            "--ic", "geometry-rest",
        ])

        @test params.space isa DGMethod
        @test params.space.degree == 2
        @test params.time_stepper isa SSPRK2Stepper
        @test backend isa NativeRK3Backend
    end

    @testset "velocity profile flags" begin
        flat_params, _, _ = parse_args([
            "--velocity-profile", "flat",
            "--profile-shear-factor", "4",
            "--tfinal", "5e-5",
            "--nx", "8",
            "--progress-every", "0",
            "--no-svg",
            "--ic", "geometry-rest",
        ])
        @test flat_params.velocity_profile isa FlatVelocityProfile
        @test flat_params.alpha ≈ 1.0
        @test shear_rate_factor(flat_params.velocity_profile) ≈ 4.0

        power_params, _, _ = parse_args([
            "--velocity-profile", "power",
            "--profile-exponent", "9",
            "--tfinal", "5e-5",
            "--nx", "8",
            "--progress-every", "0",
            "--no-svg",
            "--ic", "geometry-rest",
        ])
        @test power_params.velocity_profile isa PowerVelocityProfile
        @test power_params.velocity_profile.exponent ≈ 9.0
        @test power_params.alpha ≈ 1.1

        alpha_params, _, _ = parse_args([
            "--alpha", "1.1",
            "--tfinal", "5e-5",
            "--nx", "8",
            "--progress-every", "0",
            "--no-svg",
            "--ic", "geometry-rest",
        ])
        @test alpha_params.velocity_profile isa PowerVelocityProfile
        @test alpha_params.velocity_profile.exponent ≈ 9.0
        @test alpha_params.alpha ≈ power_params.alpha
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
            "--ic", "geometry-rest",
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
        @test_throws ArgumentError parse_args(["--tfinal", "5e-5", "--nx", "8"])
        @test_throws ArgumentError parse_args(["--ic-pressure-drop-pa", "40", "--ic-pressure-drop-dyn-cm2", "400"])
        @test_throws ArgumentError parse_args(["--ic", "geometry-rest", "--ic-pressure-drop-pa", "40"])
        @test_throws ArgumentError parse_args(["--backend", "sciml", "--alg", "ssprk"])
        @test_throws ArgumentError parse_args(["--abstol", "1e-8"])
        @test_throws ArgumentError parse_args(["--backend", "sciml", "--alg", "not-a-policy"])
        @test_throws ArgumentError parse_args(["--eta0", "0.2"])
        @test_throws ArgumentError parse_args(["--rheology", "casson", "--eta0", "0.2"])
        @test_throws ArgumentError parse_args(["--rheology", "not-a-model"])
        @test_throws ArgumentError parse_args(["--space", "fv-muscl", "--degree", "1"])
        @test_throws ArgumentError parse_args(["--limiter", "not-a-limiter"])
        @test_throws ArgumentError parse_args(["--time-stepper", "rk4"])
        @test_throws ArgumentError parse_args(["--velocity-profile", "power", "--ic", "geometry-rest"])
        @test_throws ArgumentError parse_args(["--velocity-profile", "flat", "--profile-shear-factor", "0", "--ic", "geometry-rest"])
        @test_throws ArgumentError parse_args(["--velocity-profile", "parabolic", "--profile-shear-factor", "4", "--ic", "geometry-rest"])
        @test_throws ArgumentError parse_args(["--alpha", "1.1", "--velocity-profile", "power", "--profile-exponent", "9", "--ic", "geometry-rest"])
    end
end

@testset "CanicExtended1D study output provenance" begin
    parabolic_spec = SeveritySweepSpec(
        base_params=Params(nx=8, tfinal=1.0e-5, initial_condition=GeometryRestIC()),
        severities=[23.0, 50.0],
        progress_every=0,
        parallel_workers=1,
    )
    legacy_power_spec = SeveritySweepSpec(
        base_params=Params(nx=8, tfinal=1.0e-5, initial_condition=GeometryRestIC(), alpha=1.1),
        severities=[23.0, 50.0],
        progress_every=0,
        parallel_workers=1,
    )
    flat_grid_spec = GridConvergenceStudySpec(
        base_params=Params(
            nx=8,
            tfinal=1.0e-5,
            severity=50.0,
            initial_condition=GeometryRestIC(),
            velocity_profile=FlatVelocityProfile(shear_rate_factor=8.0),
        ),
        nxs=[8, 16],
        progress_every=0,
        parallel_workers=1,
    )

    @test occursin("_vp_parabolic_", study_summary_path(parabolic_spec))
    @test study_summary_path(parabolic_spec) != study_summary_path(legacy_power_spec)
    @test occursin("_vp_power_g_9_", study_summary_path(legacy_power_spec))
    @test occursin("_vp_flat_sf_8_", study_summary_path(flat_grid_spec))

    mktempdir() do dir
        flat_spec = SeveritySweepSpec(
            base_params=Params(
                nx=8,
                tfinal=1.0e-5,
                initial_condition=GeometryRestIC(),
                velocity_profile=FlatVelocityProfile(shear_rate_factor=8.0),
            ),
            severities=[23.0],
            summary_csv=joinpath(dir, "flat.csv"),
            overwrite=true,
            progress_every=0,
            parallel_workers=1,
        )
        flat_result = run_study(flat_spec)
        flat_row = only(flat_result.summaries)
        @test flat_row.velocity_profile == "flat"
        @test flat_row.alpha ≈ 1.0
        @test isnan(flat_row.profile_exponent)
        @test flat_row.shear_rate_factor ≈ 8.0
        flat_csv = read(flat_result.summary_csv, String)
        @test occursin("velocity_profile,alpha,profile_exponent,shear_rate_factor", flat_csv)
        flat_csv_row = only(read_simple_csv(flat_result.summary_csv))
        @test flat_csv_row["velocity_profile"] == "flat"
        @test parse(Float64, flat_csv_row["alpha"]) ≈ 1.0
        @test isnan(parse(Float64, flat_csv_row["profile_exponent"]))
        @test parse(Float64, flat_csv_row["shear_rate_factor"]) ≈ 8.0

        power_spec = GridConvergenceStudySpec(
            base_params=Params(
                nx=8,
                tfinal=1.0e-5,
                severity=50.0,
                initial_condition=GeometryRestIC(),
                velocity_profile=PowerVelocityProfile(exponent=9.0),
            ),
            nxs=[8],
            summary_csv=joinpath(dir, "power.csv"),
            overwrite=true,
            progress_every=0,
            parallel_workers=1,
        )
        power_result = run_study(power_spec)
        power_row = only(power_result.summaries)
        @test power_row.velocity_profile == "power"
        @test power_row.alpha ≈ 1.1
        @test power_row.profile_exponent ≈ 9.0
        @test power_row.shear_rate_factor ≈ 11.0
        power_csv_row = only(read_simple_csv(power_result.summary_csv))
        @test power_csv_row["velocity_profile"] == "power"
        @test parse(Float64, power_csv_row["alpha"]) ≈ 1.1
        @test parse(Float64, power_csv_row["profile_exponent"]) ≈ 9.0
        @test parse(Float64, power_csv_row["shear_rate_factor"]) ≈ 11.0
    end
end

@testset "CanicExtended1D process-parallel studies" begin
    mktempdir() do dir
        spec = SeveritySweepSpec(
            base_params=Params(nx=8, tfinal=1.0e-5, initial_condition=GeometryRestIC()),
            severities=[23.0, 50.0],
            summary_csv=joinpath(dir, "parallel_severity.csv"),
            overwrite=true,
            progress_every=0,
            parallel_workers=2,
        )
        result = run_study(spec)

        @test length(result.summaries) == 2
        @test [row.severity for row in result.summaries] == [23.0, 50.0]
        @test all(row.velocity_profile == "parabolic" for row in result.summaries)
        @test all(row.alpha ≈ 4.0 / 3.0 for row in result.summaries)
        @test all(row.profile_exponent ≈ 2.0 for row in result.summaries)
        @test all(row.shear_rate_factor ≈ 4.0 for row in result.summaries)
        @test isfile(result.summary_csv)
        @test occursin("severity_sweep", read(result.summary_csv, String))
    end
end

@testset "CanicExtended1D refinement studies" begin
    mktempdir() do dir
        @test SeveritySweepSpec(severities=[23.0]).base_params.initial_condition isa GeometryRestIC
        @test GridConvergenceStudySpec(nxs=[8, 16]).base_params.initial_condition isa GeometryRestIC
        @test RefinementStudySpec().base_params.initial_condition isa GeometryRestIC

        spec = RefinementStudySpec(
            base_params=Params(nx=8, tfinal=1.0e-5, severity=30.0, initial_condition=GeometryRestIC()),
            nxs=[8, 16],
            degrees=[0, 1, 2],
            h_methods=AbstractSpatialMethod[FVMUSCLMethod()],
            output_dir=dir,
            overwrite=true,
            progress_every=0,
            parallel_workers=1,
        )
        result = run_refinement_study(spec)

        @test length(result.h_rows) == 2
        @test length(result.p_rows) == 6
        @test all(isfile, result.csv_paths)
        @test all(isfile, result.tex_paths)
        @test occursin("error_A_l2", read(result.csv_paths[1], String))
        @test occursin("\\begin{table}", read(result.tex_paths[1], String))
        @test all(row.expected_order == row.degree + 1 for row in result.p_rows if row.degree >= 0)
    end
end
