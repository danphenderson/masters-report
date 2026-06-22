@testset "StenoticHemodynamics scalar-generic packed state helpers" begin
    layout = StenoticHemodynamics.PackedStateLayout(3)

    A32 = Float32[0.04, 0.05, 0.06]
    Q32 = Float32[0.10, 0.20, 0.30]
    u32 = StenoticHemodynamics.pack_state(A32, Q32)
    area32, flow32 = StenoticHemodynamics.state_views(u32, layout)
    unpacked_A32, unpacked_Q32 = StenoticHemodynamics.unpack_state(u32, layout)

    @test u32 isa Vector{Float32}
    @test eltype(area32) === Float32
    @test eltype(flow32) === Float32
    @test collect(area32) == A32
    @test collect(flow32) == Q32
    @test unpacked_A32 == A32
    @test unpacked_Q32 == Q32
    @test unpacked_A32 isa Vector{Float32}
    @test unpacked_Q32 isa Vector{Float32}

    Abig = BigFloat[big"0.04", big"0.05", big"0.06"]
    Qbig = BigFloat[big"0.10", big"0.20", big"0.30"]
    ubig = StenoticHemodynamics.pack_state(Abig, Qbig)
    area_big, flow_big = StenoticHemodynamics.state_views(ubig, layout)
    unpacked_Abig, unpacked_Qbig = StenoticHemodynamics.unpack_state(ubig, layout)

    @test ubig isa Vector{BigFloat}
    @test eltype(area_big) === BigFloat
    @test eltype(flow_big) === BigFloat
    @test collect(area_big) == Abig
    @test collect(flow_big) == Qbig
    @test unpacked_Abig == Abig
    @test unpacked_Qbig == Qbig
    @test unpacked_Abig isa Vector{BigFloat}
    @test unpacked_Qbig isa Vector{BigFloat}

    rhs_default = StenoticHemodynamics.RHSCache(3)
    @test rhs_default isa StenoticHemodynamics.RHSCache{Float64}
    @test rhs_default.area_flux == zeros(4)
    @test rhs_default.area_slope == zeros(3)

    rhs32 = StenoticHemodynamics.RHSCache(Float32, 3)
    @test rhs32 isa StenoticHemodynamics.RHSCache{Float32}
    @test eltype(rhs32.area_flux) === Float32
    @test eltype(rhs32.flow_flux) === Float32
    @test eltype(rhs32.source) === Float32
    @test rhs32.flow_slope == zeros(Float32, 3)

    rhsbig = StenoticHemodynamics.RHSCache(BigFloat[big"0.1", big"0.2", big"0.3"])
    @test rhsbig isa StenoticHemodynamics.RHSCache{BigFloat}
    @test eltype(rhsbig.area_flux) === BigFloat
    @test rhsbig.area_flux == zeros(BigFloat, 4)

    native_default = StenoticHemodynamics.NativeStepCache(3)
    @test native_default isa StenoticHemodynamics.NativeStepCache{Float64}
    @test native_default.rhs isa StenoticHemodynamics.RHSCache{Float64}

    native32 = StenoticHemodynamics.NativeStepCache(Float32, 3)
    @test native32 isa StenoticHemodynamics.NativeStepCache{Float32}
    @test native32.rhs isa StenoticHemodynamics.RHSCache{Float32}
    @test eltype(native32.dA1) === Float32
    @test eltype(native32.Q3) === Float32

    nativebig = StenoticHemodynamics.NativeStepCache(BigFloat[big"0.1", big"0.2", big"0.3"])
    @test nativebig isa StenoticHemodynamics.NativeStepCache{BigFloat}
    @test nativebig.rhs isa StenoticHemodynamics.RHSCache{BigFloat}
    @test nativebig.A2 == zeros(BigFloat, 3)
end

@testset "StenoticHemodynamics scalar-generic limiter and basis helpers" begin
    @test typeof(minmod(Float32(2.0), Float32(3.0))) === Float32
    @test minmod(Float32(2.0), Float32(3.0)) == Float32(2.0)
    @test minmod(Float32(-2.0), Float32(3.0)) == zero(Float32)
    @test typeof(minmod(Float32(2.0), big"3.0")) === BigFloat
    @test minmod(Float32(2.0), big"3.0") == big"2.0"

    @test typeof(StenoticHemodynamics.vanleer(Float32(2.0), Float32(4.0))) === Float32
    @test StenoticHemodynamics.vanleer(Float32(2.0), Float32(4.0)) ≈ Float32(8.0 / 3.0)
    @test StenoticHemodynamics.vanleer(big"2.0", big"-4.0") == big"0.0"

    minmod_limiter = StenoticHemodynamics.MinmodLimiter()
    vanleer_limiter = StenoticHemodynamics.VanLeerLimiter()
    @test typeof(StenoticHemodynamics.limited_slope(Float32[1.0, 2.0, 4.0], 2, minmod_limiter)) === Float32
    @test StenoticHemodynamics.limited_slope(Float32[1.0, 2.0, 4.0], 2, minmod_limiter) == Float32(1.0)
    @test StenoticHemodynamics.limited_slope(Float32[1.0, 2.0, 4.0], 1, minmod_limiter) == zero(Float32)
    @test typeof(StenoticHemodynamics.limited_slope(BigFloat[big"1.0", big"2.0", big"4.0"], 2, vanleer_limiter)) === BigFloat
    @test StenoticHemodynamics.limited_slope(BigFloat[big"1.0", big"2.0", big"4.0"], 2, vanleer_limiter) == big"4.0" / big"3.0"

    @test typeof(StenoticHemodynamics.legendre_value(3, Float32(0.25))) === Float32
    @test StenoticHemodynamics.legendre_value(3, Float32(0.25)) ≈ Float32((5 * 0.25f0^3 - 3 * 0.25f0) / 2)
    @test typeof(StenoticHemodynamics.legendre_derivative(3, big"0.25")) === BigFloat
    @test StenoticHemodynamics.legendre_derivative(3, big"0.25") == (big"15.0" * big"0.25"^2 - big"3.0") / big"2.0"
end

@testset "StenoticHemodynamics scalar-generic velocity profile configs" begin
    flat_default = FlatVelocityProfile()
    @test flat_default isa FlatVelocityProfile{Float64}

    flat32 = FlatVelocityProfile(shear_rate_factor=Float32(5.0))
    @test flat32 isa FlatVelocityProfile{Float32}
    @test typeof(shear_rate_factor(flat32)) === Float32
    @test typeof(momentum_alpha(flat32)) === Float32
    @test typeof(mean_to_max_velocity_ratio(flat32)) === Float32
    @test radial_profile_velocity(Float32(3.0), Float32(1.5), Float32(2.0), flat32) === Float32(3.0)

    power32 = PowerVelocityProfile(exponent=Float32(2.0))
    @test power32 isa PowerVelocityProfile{Float32}
    @test typeof(momentum_alpha(power32)) === Float32
    @test typeof(shear_rate_factor(power32)) === Float32
    @test typeof(mean_to_max_velocity_ratio(power32)) === Float32
    @test momentum_alpha(power32) ≈ Float32(4.0 / 3.0)
    @test shear_rate_factor(power32) ≈ Float32(4.0)
    @test mean_to_max_velocity_ratio(power32) ≈ Float32(0.5)
    @test typeof(radial_profile_velocity(Float32(3.0), Float32(1.0), Float32(2.0), power32)) === Float32

    power_big = PowerVelocityProfile(alpha=big"1.1")
    @test power_big isa PowerVelocityProfile{BigFloat}
    @test typeof(power_big.exponent) === BigFloat
    @test typeof(momentum_alpha(power_big)) === BigFloat
    @test typeof(shear_rate_factor(power_big)) === BigFloat
    @test typeof(mean_to_max_velocity_ratio(power_big)) === BigFloat
    @test power_big.exponent == big"9.0"
    @test momentum_alpha(power_big) == big"1.1"
    @test shear_rate_factor(power_big) == big"11.0"
    @test mean_to_max_velocity_ratio(power_big) == big"9.0" / big"11.0"

    parabolic_velocity = radial_profile_velocity(big"3.0", big"1.0", big"2.0", ParabolicVelocityProfile())
    @test typeof(parabolic_velocity) === BigFloat
    @test parabolic_velocity == big"4.5"
end

@testset "StenoticHemodynamics scalar-generic rheology configs" begin
    carreau_default = CarreauRheology()
    @test carreau_default isa CarreauRheology{Float64}

    carreau32 = CarreauRheology(eta0=Float32(0.10), eta_inf=Float32(0.02), lambda_s=Float32(2.0), n=Float32(0.5))
    @test carreau32 isa CarreauRheology{Float32}
    @test typeof(carreau32.shear_rate_floor) === Float32
    carreau_eta32 = effective_dynamic_viscosity(carreau32, Float32(3.0), Float32(1.055), Float32(0.04))
    @test typeof(carreau_eta32) === Float32
    @test carreau_eta32 ≈ Float32(0.02 + (0.10 - 0.02) * (1.0 + (2.0 * 3.0)^2)^((0.5 - 1.0) / 2.0))

    carreau_yasuda_big = CarreauYasudaRheology(
        eta0=big"0.10",
        eta_inf=big"0.02",
        lambda_s=big"2.0",
        a=big"1.5",
        n=big"0.5",
    )
    @test carreau_yasuda_big isa CarreauYasudaRheology{BigFloat}
    carreau_yasuda_eta = effective_dynamic_viscosity(carreau_yasuda_big, big"3.0", big"1.055", big"0.04")
    @test typeof(carreau_yasuda_eta) === BigFloat
    @test carreau_yasuda_eta == big"0.02" + (big"0.10" - big"0.02") * (big"1.0" + (big"2.0" * big"3.0")^big"1.5")^((big"0.5" - big"1.0") / big"1.5")

    casson_big = CassonRheology(yield_stress=big"0.09", plastic_viscosity=big"0.04")
    @test casson_big isa CassonRheology{BigFloat}
    casson_eta = effective_dynamic_viscosity(casson_big, big"9.0", big"1.055", big"0.04")
    @test typeof(casson_eta) === BigFloat
    @test casson_eta == (sqrt(big"0.09" / big"9.0") + sqrt(big"0.04"))^2

    power_law32 = PowerLawRheology(consistency=Float32(0.12), n=Float32(0.75))
    @test power_law32 isa PowerLawRheology{Float32}
    power_law_eta32 = effective_dynamic_viscosity(power_law32, Float32(16.0), Float32(1.055), Float32(0.04))
    @test typeof(power_law_eta32) === Float32
    @test power_law_eta32 ≈ Float32(0.12 * 16.0^-0.25)

    newtonian_eta32 = effective_dynamic_viscosity(NewtonianRheology(), Float32(3.0), Float32(1.055), Float32(0.04))
    @test typeof(newtonian_eta32) === Float32
    @test newtonian_eta32 ≈ Float32(1.055 * 0.04)

    casson_nu_big = effective_kinematic_viscosity(casson_big, big"9.0", big"1.055", big"0.04")
    @test typeof(casson_nu_big) === BigFloat
    @test casson_nu_big == casson_eta / big"1.055"
end

@testset "StenoticHemodynamics scalar-generic boundary configs" begin
    steady_default = SteadyVelocityInlet()
    @test steady_default isa SteadyVelocityInlet{Float64}

    steady32 = SteadyVelocityInlet(umax=Float32(37.5))
    @test steady32 isa SteadyVelocityInlet{Float32}
    @test typeof(steady32.umax) === Float32
    @test StenoticHemodynamics.validate(steady32) === steady32

    waveform32 = FlowWaveformInlet(
        Float32[0.0, 0.2, 0.5],
        Float32[4.0, 6.0, 5.0];
        period_s=Float32(0.6),
        source_path="float32-waveform",
    )
    @test waveform32 isa FlowWaveformInlet{Float32}
    @test eltype(waveform32.time_s) === Float32
    @test eltype(waveform32.flow_cm3_s) === Float32
    @test typeof(waveform32.period_s) === Float32
    @test StenoticHemodynamics.validate(waveform32) === waveform32
    @test typeof(inlet_flow(waveform32, nothing, Float32(0.35))) === Float32
    @test inlet_flow(waveform32, nothing, Float32(0.35)) ≈ Float32(5.5)
    @test inlet_flow(waveform32, nothing, Float32(0.65)) ≈ Float32(4.5)

    waveform_big = FlowWaveformInlet(
        BigFloat[big"0.0", big"0.3", big"0.6"],
        BigFloat[big"8.0", big"5.0", big"8.0"],
    )
    @test waveform_big isa FlowWaveformInlet{BigFloat}
    @test typeof(inlet_flow(waveform_big, nothing, big"0.75")) === BigFloat
    @test inlet_flow(waveform_big, nothing, big"0.75") == big"6.5"

    outlet_default = ReflectionCoefficientOutlet(0.25)
    @test outlet_default isa ReflectionCoefficientOutlet{Float64}

    outlet_big = ReflectionCoefficientOutlet(big"0.2"; reference_flow=big"1.5")
    @test outlet_big isa ReflectionCoefficientOutlet{BigFloat}
    @test typeof(outlet_big.rt) === BigFloat
    @test typeof(outlet_big.reference_flow) === BigFloat
    @test StenoticHemodynamics.validate(outlet_big) === outlet_big

    mktemp() do path, io
        write(io, "0.0 2.0\n0.5 4.0\n1.0 2.0\n")
        close(io)
        waveform_path = FlowWaveformInlet(path; flow_scale=2.0)
        @test waveform_path isa FlowWaveformInlet{Float64}
        @test waveform_path.source_path == path
        @test waveform_path.flow_cm3_s == [4.0, 8.0, 4.0]
    end
end

@testset "StenoticHemodynamics scalar-generic initial condition configs" begin
    ic_default = StationaryStokesIC()
    @test ic_default isa StationaryStokesIC{Float64}

    ic32 = StationaryStokesIC(
        pressure_drop_pa=Float32(12.5),
        mesh_nz=8,
        mesh_nr=4,
        mesh_ntheta=12,
        projection_nr=3,
        projection_ntheta=8,
    )
    @test ic32 isa StationaryStokesIC{Float32}
    @test typeof(ic32.pressure_drop_dyn_cm2) === Float32
    @test ic32.pressure_drop_dyn_cm2 == Float32(125.0)
    @test StenoticHemodynamics.validate(ic32) === ic32

    ic_big = StationaryStokesIC(
        pressure_drop_dyn_cm2=big"123.5",
        mesh_nz=10,
        mesh_nr=5,
        mesh_ntheta=16,
        diagnostics_path="bigfloat-ic",
    )
    @test ic_big isa StationaryStokesIC{BigFloat}
    @test typeof(ic_big.pressure_drop_dyn_cm2) === BigFloat
    @test ic_big.pressure_drop_dyn_cm2 == big"123.5"
    @test ic_big.diagnostics_path == "bigfloat-ic"
    @test StenoticHemodynamics.validate(ic_big) === ic_big
end
