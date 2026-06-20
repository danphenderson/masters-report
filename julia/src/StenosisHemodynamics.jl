if VERSION < v"1.12"
    error(
        "StenosisHemodynamics requires Julia 1.12 or newer. " *
        "Run it with bin/julia-release ... or julia +release --project=....",
    )
end

"""
Finite-volume Canic extended 1D stenotic artery simulation.

Public protocol:

`Params` plus an optional time backend/`SolveSpec` -> `simulate` ->
`SimulationResult` -> diagnostics and core query helpers.

The package is organized into explicit architecture layers:

- core physical/data model definitions;
- numerical kernels and backend dispatch;
- shared I/O and manifest helpers;
- adapters for external ecosystems and data formats;
- reproducible research workflows;
- a thin command-line interface.

The native backend is the default fixed-step SSP RK3 path. Optional external
ecosystem support is isolated in adapter and workflow files so the core model
can remain small, testable, and extension-friendly.
"""
module StenosisHemodynamics

using SHA
using Statistics

export AbstractTimeBackend,
       AbstractAlgorithmPolicy,
       AbstractInletBoundary,
       AbstractOutletBoundary,
       AbstractRheology,
       AbstractLimiter,
       AbstractInitialConditionSpec,
       AbstractForwardModel,
       AbstractForcingTerm,
       AbstractNativeTimeStepper,
       AbstractSpatialMethod,
       AbstractVelocityProfile,
       AbstractWallLaw,
       AutoPolicy,
       CanicKoiterWallLaw,
       CanicExtendedOneDModel,
       CarreauRheology,
       CarreauYasudaRheology,
       CassonRheology,
       ClassicalNoSlip1DModel,
       DGMethod,
       FVFirstOrderMethod,
       FVLaxWendroffMethod,
       FVMUSCLMethod,
       FVWENO3Method,
       FixedAreaCharacteristicOutlet,
       FlatVelocityProfile,
       FlowWaveformInlet,
       ForwardEulerStepper,
       GeometryRestIC,
       InitialConditionSummary,
       MinmodLimiter,
       ManufacturedForcing,
       ManufacturedSolutionIC,
       NativeSSPRKPolicy,
       NativeRK3Backend,
       NoForcing,
       NewtonianRheology,
       Params,
       ParabolicVelocityProfile,
       PowerLawRheology,
       PowerVelocityProfile,
       ReflectionCoefficientOutlet,
       Rodas5PPolicy,
       SciMLTimeBackend,
       SimulationResult,
       SimulationDiagnostics,
       SolveSpec,
       SSPRK2Stepper,
       SSPRK3Stepper,
       SSPRK54Stepper,
       StationaryStokesIC,
       SteadyVelocityInlet,
       Tsit5Policy,
       Vern7Policy,
       Vern9Policy,
       algorithm_name,
       algorithm_policy,
       backend_algorithm_name,
       backend_name,
       characteristic_shear_rate,
       characteristic_speeds,
       degrees_of_freedom,
       effective_dynamic_viscosity,
       effective_kinematic_viscosity,
       forcing_name,
       forward_model,
       forward_model_name,
       initial_condition,
       initial_condition_name,
       initial_condition_values,
       initial_state_result,
       inlet_boundary_name,
       inlet_flow,
       limiter_name,
       mean_to_max_velocity_ratio,
       minmod,
       model_name,
       momentum_alpha,
       outlet_boundary_name,
       pressure,
       profile_exponent,
       profile_name,
       radial_profile_velocity,
       rheology_name,
       shear_rate_factor,
       simulate,
       spatial_method_name,
       stenosis_throat_z,
       time_stepper_name,
       variable_radius_terms_enabled,
       velocity,
       wall_boundary_condition,
       wall_law_name

include("StenosisHemodynamics/layers.jl")

include("StenosisHemodynamics/core/logging.jl")
include("StenosisHemodynamics/numerics/methods.jl")
include("StenosisHemodynamics/core/rheology.jl")
include("StenosisHemodynamics/core/initial_conditions.jl")
include("StenosisHemodynamics/core/profiles.jl")
include("StenosisHemodynamics/core/forward_models.jl")
include("StenosisHemodynamics/core/wall_laws.jl")
include("StenosisHemodynamics/core/boundaries.jl")
include("StenosisHemodynamics/core/verification_types.jl")
include("StenosisHemodynamics/core/types.jl")
include("StenosisHemodynamics/workflows/parallel.jl")
include("StenosisHemodynamics/numerics/policies.jl")
include("StenosisHemodynamics/core/geometry.jl")
include("StenosisHemodynamics/numerics/state.jl")
include("StenosisHemodynamics/numerics/model.jl")
include("StenosisHemodynamics/core/diagnostics.jl")
include("StenosisHemodynamics/adapters/stokes_ic.jl")
include("StenosisHemodynamics/numerics/solver.jl")
include("StenosisHemodynamics/numerics/dg.jl")
include("StenosisHemodynamics/adapters/sciml_problem.jl")
include("StenosisHemodynamics/numerics/backends.jl")
include("StenosisHemodynamics/io/writers.jl")
include("StenosisHemodynamics/io/outputs.jl")
include("StenosisHemodynamics/adapters/openbf_protocol.jl")
include("StenosisHemodynamics/workflows/studies.jl")
include("StenosisHemodynamics/workflows/refinement.jl")
include("StenosisHemodynamics/workflows/resolved3d_types.jl")
include("StenosisHemodynamics/adapters/resolved3d_io.jl")
include("StenosisHemodynamics/workflows/resolved3d_compare.jl")
include("StenosisHemodynamics/workflows/operator_validation.jl")
include("StenosisHemodynamics/workflows/resolved3d_outputs.jl")
include("StenosisHemodynamics/workflows/stationary_stokes_refinement.jl")
include("StenosisHemodynamics/workflows/verification.jl")
include("StenosisHemodynamics/workflows/geometry_exports.jl")
include("StenosisHemodynamics/workflows/benchmarks.jl")
include("StenosisHemodynamics/cli/cli.jl")

end
