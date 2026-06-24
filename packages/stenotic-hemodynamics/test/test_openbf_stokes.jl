isdefined(@__MODULE__, :write_openbf_fixture) || include("test_helpers.jl")
using Statistics: mean

const generated_stokes_mesh = StenoticHemodynamics.generated_stokes_mesh

@testset "StenoticHemodynamics OpenBF protocol adapter" begin
    mktempdir() do dir
        config_path, inlet_path = write_openbf_fixture(dir)
        spec = StenoticHemodynamics.load_openbf_config(config_path)
        params, output, backend, returned_spec = StenoticHemodynamics.params_from_openbf_config(config_path)

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
        result = StenoticHemodynamics.run_simulation(config_path; save_stats=true)
        @test result.completed_time ≈ 2.0e-5
        @test isfile(joinpath(dir, "out", "smoke.csv"))
        @test isfile(joinpath(dir, "out", "smoke.svg"))
        @test isfile(joinpath(dir, "out", "smoke.conv"))
    end

    mktempdir() do dir
        config_path, _ = write_openbf_fixture(dir; include_canic=false)
        @test_throws ArgumentError StenoticHemodynamics.load_openbf_config(config_path)
    end

    mktempdir() do dir
        config_path, _ = write_openbf_fixture(dir; extra_vessel="R1: 1.0e7")
        @test_throws ArgumentError StenoticHemodynamics.load_openbf_config(config_path)
    end

    mktempdir() do dir
        bad_inlet = joinpath(dir, "bad.dat")
        write(bad_inlet, "0.0 1.0 2.0\n")
        @test_throws ArgumentError FlowWaveformInlet(bad_inlet)
    end
end
@testset "StenoticHemodynamics stationary Stokes initial conditions" begin
    @test_throws ArgumentError StenoticHemodynamics.validate(Params(nx=8, tfinal=0.0, severity=0.0))
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

    projected_pressure = diagnostic_pressure(state.area, state.flow, state.z, params)
    @test maximum(abs.(projected_pressure .- range(maximum(projected_pressure), minimum(projected_pressure); length=length(projected_pressure)))) < ic.pressure_drop_dyn_cm2

    u_mean = mean(velocity(SimulationResult(state.z, state.area, state.flow, 0.0, 0)))
    mu = params.rho * params.nu
    analytic_u = ic.pressure_drop_dyn_cm2 * params.rmax^2 / (8.0 * mu * params.length_cm)
    @test isapprox(u_mean, analytic_u; rtol=0.45)

    field_that_errors = _ -> error("stationary Stokes projection should not evaluate FE fields")
    fake_solution = StenoticHemodynamics.StationaryStokesSolution(
        mesh,
        field_that_errors,
        field_that_errors,
        -1,
        -1,
        NaN,
    )
    fake_area, fake_flow, fake_uavg, fake_pavg =
        StenoticHemodynamics.project_stationary_stokes(fake_solution, params, ic, state.z)
    @test fake_area ≈ state.area
    @test fake_flow ≈ state.flow
    @test all(isfinite, fake_uavg)
    @test all(isfinite, fake_pavg)

    repeat_state = initial_state_result(params)
    @test repeat_state.summary.projection_hash == state.summary.projection_hash
    @test repeat_state.area ≈ state.area
    @test repeat_state.flow ≈ state.flow
end
