const YAML_UUID = Base.UUID("ddb6d928-2868-570f-bddf-ab3f9cf99eb6")

struct OpenBFRunSpec
    project_name::String
    config_path::String
    inlet_file::String
    output_directory::String
    write_results::Vector{String}
    cycles::Int
    inlet_period_s::Float64
    convergence_tolerance::Float64
    jump::Int
    params::Params
    output::OutputSpec
end

function require_yaml()
    try
        return Base.require(Base.PkgId(YAML_UUID, "YAML"))
    catch
        throw(ArgumentError("YAML.jl is required for OpenBF-style input.yml support. Add YAML to the active Julia project."))
    end
end

function load_yaml_file(path::String)
    YAML = require_yaml()
    return Base.invokelatest(getproperty(YAML, :load_file), path)
end

key_name(key) = string(key)

has_config_key(config::AbstractDict, key::String) = haskey(config, key)

function require_config_key(config::AbstractDict, key::String, context::String)
    has_config_key(config, key) || throw(ArgumentError("$context requires '$key'"))
    return config[key]
end

optional_config_key(config::AbstractDict, key::String, default) = has_config_key(config, key) ? config[key] : default

function require_mapping(config::AbstractDict, key::String, context::String)
    value = require_config_key(config, key, context)
    value isa AbstractDict || throw(ArgumentError("$context '$key' must be a mapping"))
    return value
end

require_number(config::AbstractDict, key::String, context::String) = Float64(require_config_key(config, key, context))
optional_number(config::AbstractDict, key::String, default::Real) = Float64(optional_config_key(config, key, default))

function require_int(config::AbstractDict, key::String, context::String)
    value = require_config_key(config, key, context)
    int_value = Int(value)
    Float64(value) == Float64(int_value) || throw(ArgumentError("$context '$key' must be an integer"))
    return int_value
end

function optional_int(config::AbstractDict, key::String, default::Integer)
    has_config_key(config, key) || return Int(default)
    value = config[key]
    int_value = Int(value)
    Float64(value) == Float64(int_value) || throw(ArgumentError("'$key' must be an integer"))
    return int_value
end

function reject_unknown_keys(config::AbstractDict, allowed::Set{String}, context::String)
    unknown = sort([key_name(key) for key in keys(config) if !(key_name(key) in allowed)])
    isempty(unknown) ||
        throw(ArgumentError("$context has unsupported key(s): $(join(unknown, ", "))"))
    return nothing
end

function reject_present(config::AbstractDict, keys_to_reject, context::String)
    present = sort([key for key in keys_to_reject if has_config_key(config, key)])
    isempty(present) || throw(ArgumentError("$context does not support key(s): $(join(present, ", "))"))
    return nothing
end

function resolve_config_path(config_path::String, child_path::AbstractString)
    path = String(child_path)
    return isabspath(path) ? path : joinpath(dirname(abspath(config_path)), path)
end

meters_to_cm(value::Real) = 100.0 * Float64(value)
pa_to_dyn_cm2(value::Real) = 10.0 * Float64(value)
rho_kg_m3_to_g_cm3(value::Real) = Float64(value) / 1000.0
mu_pa_s_to_nu_cm2_s(mu::Real, rho::Real) = 1.0e4 * Float64(mu) / Float64(rho)

function parse_write_results(config::AbstractDict)
    raw = optional_config_key(config, "write_results", String[])
    raw isa AbstractVector || throw(ArgumentError("write_results must be a list"))
    values = [String(value) for value in raw]
    allowed = Set(["P", "Q", "A", "u"])
    unsupported = sort([value for value in values if !(value in allowed)])
    isempty(unsupported) ||
        throw(ArgumentError("write_results has unsupported value(s): $(join(unsupported, ", "))"))
    return values
end

function parse_openbf_initial_condition(canic::AbstractDict)
    ic = require_mapping(canic, "initial_condition", "canic")
    allowed = Set(["pressure_drop_pa", "pressure_drop_dyn_cm2", "mesh_nz", "mesh_nr", "mesh_ntheta"])
    reject_unknown_keys(ic, allowed, "canic.initial_condition")

    pressure_pa_set = has_config_key(ic, "pressure_drop_pa")
    pressure_dyn_set = has_config_key(ic, "pressure_drop_dyn_cm2")
    pressure_pa_set == pressure_dyn_set &&
        throw(ArgumentError("canic.initial_condition requires exactly one of pressure_drop_pa or pressure_drop_dyn_cm2"))

    return StationaryStokesIC(
        pressure_drop_pa=pressure_pa_set ? Float64(ic["pressure_drop_pa"]) : nothing,
        pressure_drop_dyn_cm2=pressure_dyn_set ? Float64(ic["pressure_drop_dyn_cm2"]) : nothing,
        mesh_nz=optional_int(ic, "mesh_nz", 64),
        mesh_nr=optional_int(ic, "mesh_nr", 6),
        mesh_ntheta=optional_int(ic, "mesh_ntheta", 32),
    )
end

function parse_single_openbf_vessel(network)
    network isa AbstractVector || throw(ArgumentError("network must be a list"))
    length(network) == 1 ||
        throw(ArgumentError("OpenBF adapter currently supports exactly one vessel, got $(length(network))"))
    vessel = network[1]
    vessel isa AbstractDict || throw(ArgumentError("network entries must be mappings"))

    allowed = Set([
        "label",
        "to_save",
        "sn",
        "tn",
        "L",
        "M",
        "E",
        "h0",
        "R0",
        "Pext",
        "gamma_profile",
        "Rt",
        "Rp",
        "Rd",
        "R1",
        "R2",
        "Cc",
        "inlet_impedance_matching",
    ])
    reject_unknown_keys(vessel, allowed, "network[1]")
    reject_present(vessel, ("Rp", "Rd"), "network[1]")
    reject_present(vessel, ("R1", "R2", "Cc", "inlet_impedance_matching"), "network[1]")

    require_config_key(vessel, "label", "network[1]")
    sn = require_int(vessel, "sn", "network[1]")
    tn = require_int(vessel, "tn", "network[1]")
    sn == 1 || throw(ArgumentError("OpenBF adapter requires the inlet vessel source node sn=1"))
    tn != sn || throw(ArgumentError("network[1] tn must differ from sn"))

    pext = optional_number(vessel, "Pext", 0.0)
    isapprox(pext, 0.0; rtol=0.0, atol=1.0e-12) ||
        throw(ArgumentError("OpenBF adapter does not support nonzero Pext"))

    return vessel
end

function openbf_output_directory(config::AbstractDict, config_path::String, project_name::String)
    raw = optional_config_key(config, "output_directory", "$(project_name)_results")
    return resolve_config_path(config_path, String(raw))
end

function load_openbf_config(path::String)
    config_path = abspath(path)
    config = load_yaml_file(config_path)
    config isa AbstractDict || throw(ArgumentError("OpenBF config must be a YAML mapping"))

    allowed_top = Set(["project_name", "inlet_file", "output_directory", "write_results", "solver", "blood", "network", "canic"])
    reject_unknown_keys(config, allowed_top, "OpenBF config")

    project_name = String(require_config_key(config, "project_name", "OpenBF config"))
    inlet_path = resolve_config_path(config_path, String(require_config_key(config, "inlet_file", "OpenBF config")))
    isfile(inlet_path) || throw(ArgumentError("inlet_file does not exist: $inlet_path"))
    output_directory = openbf_output_directory(config, config_path, project_name)
    write_results = parse_write_results(config)

    solver = require_mapping(config, "solver", "OpenBF config")
    reject_unknown_keys(solver, Set(["Ccfl", "cycles", "convergence_tolerance", "jump"]), "solver")
    cfl = require_number(solver, "Ccfl", "solver")
    cycles = require_int(solver, "cycles", "solver")
    cycles > 0 || throw(ArgumentError("solver.cycles must be positive"))
    jump = optional_int(solver, "jump", 100)
    jump > 0 || throw(ArgumentError("solver.jump must be positive"))
    convergence_tolerance = optional_number(solver, "convergence_tolerance", NaN)

    blood = require_mapping(config, "blood", "OpenBF config")
    reject_unknown_keys(blood, Set(["rho", "mu"]), "blood")
    rho_si = require_number(blood, "rho", "blood")
    mu_si = require_number(blood, "mu", "blood")
    rho_si > 0.0 || throw(ArgumentError("blood.rho must be positive"))
    mu_si >= 0.0 || throw(ArgumentError("blood.mu must be nonnegative"))

    vessel = parse_single_openbf_vessel(require_config_key(config, "network", "OpenBF config"))
    length_cm = meters_to_cm(require_number(vessel, "L", "network[1]"))
    rmax_cm = meters_to_cm(require_number(vessel, "R0", "network[1]"))
    young_dyn_cm2 = pa_to_dyn_cm2(require_number(vessel, "E", "network[1]"))
    wall_h_cm = has_config_key(vessel, "h0") ? meters_to_cm(vessel["h0"]) : 0.06
    nx = has_config_key(vessel, "M") ? require_int(vessel, "M", "network[1]") : max(5, ceil(Int, length_cm / 0.1))
    nx >= 5 || throw(ArgumentError("network[1].M must be at least 5"))

    gamma_profile = optional_number(vessel, "gamma_profile", 2.0)
    gamma_profile > 0.0 || throw(ArgumentError("network[1].gamma_profile must be positive"))
    velocity_profile = isapprox(gamma_profile, 2.0; rtol=0.0, atol=1.0e-12) ?
                       ParabolicVelocityProfile() :
                       PowerVelocityProfile(exponent=gamma_profile)

    canic = require_mapping(config, "canic", "OpenBF config")
    reject_unknown_keys(canic, Set(["severity_percent", "initial_condition", "dt"]), "canic")
    severity = optional_number(canic, "severity_percent", 0.0)
    initial_condition = parse_openbf_initial_condition(canic)
    dt_cap = optional_number(canic, "dt", Inf)

    inlet = FlowWaveformInlet(inlet_path; flow_scale=1.0e6)
    outlet = ReflectionCoefficientOutlet(optional_number(vessel, "Rt", 0.0))
    tfinal = cycles * inlet.period_s

    params = Params(
        nx=nx,
        length_cm=length_cm,
        tfinal=tfinal,
        dt=dt_cap,
        cfl=cfl,
        severity=severity,
        rmax=rmax_cm,
        rho=rho_kg_m3_to_g_cm3(rho_si),
        nu=mu_pa_s_to_nu_cm2_s(mu_si, rho_si),
        initial_condition=initial_condition,
        velocity_profile=velocity_profile,
        inlet_boundary=inlet,
        outlet_boundary=outlet,
        young=young_dyn_cm2,
        wall_h=wall_h_cm,
    )
    validate(params)

    output = OutputSpec(
        csv=joinpath(output_directory, "$(project_name).csv"),
        svg=joinpath(output_directory, "$(project_name).svg"),
        write_svg=true,
        progress_every=0,
    )

    return OpenBFRunSpec(
        project_name,
        config_path,
        inlet_path,
        output_directory,
        write_results,
        cycles,
        inlet.period_s,
        convergence_tolerance,
        jump,
        params,
        output,
    )
end

function params_from_openbf_config(path::String)
    spec = load_openbf_config(path)
    return spec.params, spec.output, NativeRK3Backend(), spec
end

function write_openbf_stats(
    path::String,
    spec::OpenBFRunSpec,
    result::SimulationResult,
    elapsed::Float64,
    bytes::Int64,
    gc_time::Float64,
)
    passed_cycles = floor(Int, result.completed_time / spec.inlet_period_s)
    gc_percent = elapsed > 0.0 ? 100.0 * gc_time / elapsed : 0.0
    guarded_open_write(path, true) do io
        println(io, "false")
        println(io, passed_cycles)
        println(io, elapsed)
        println(io, bytes)
        println(io, gc_percent)
    end
    return path
end

function run_simulation(
    yaml_config_path::String;
    verbose::Bool = false,
    out_files::Bool = false,
    save_stats::Bool = false,
)
    out_files && throw(ArgumentError("OpenBF .out history files are not supported by this adapter"))

    spec = load_openbf_config(yaml_config_path)
    verbose && @info "running OpenBF-style StenosisHemodynamics simulation" project_name=spec.project_name cycles=spec.cycles inlet_period_s=spec.inlet_period_s output_directory=spec.output_directory

    timed = @timed begin
        result = simulate(spec.params, NativeRK3Backend(); progress_every=spec.output.progress_every)
        write_csv(spec.output.csv, result, spec.params)
        spec.output.write_svg && write_svg(spec.output.svg, result, spec.params)
        result
    end

    result = timed.value
    if save_stats
        write_openbf_stats(
            joinpath(spec.output_directory, "$(spec.project_name).conv"),
            spec,
            result,
            timed.time,
            timed.bytes,
            timed.gctime,
        )
    end

    if verbose
        for line in summary_lines(result, spec.params, spec.output)
            println(line)
        end
    end

    return result
end
