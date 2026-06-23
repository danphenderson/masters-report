if VERSION < v"1.12"
    error(
        "StenoticHemodynamics requires Julia 1.12 or newer. " *
        "Run it with packages/stenotic-hemodynamics/bin/julia-release ... or julia +release --project=....",
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
module StenoticHemodynamics

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

include("StenoticHemodynamics/layers.jl")

include("StenoticHemodynamics/core/logging.jl")
include("StenoticHemodynamics/numerics/methods.jl")
include("StenoticHemodynamics/core/rheology.jl")
include("StenoticHemodynamics/core/initial_conditions.jl")
include("StenoticHemodynamics/core/profiles.jl")
include("StenoticHemodynamics/core/forward_models.jl")
include("StenoticHemodynamics/core/wall_laws.jl")
include("StenoticHemodynamics/core/boundaries.jl")
include("StenoticHemodynamics/core/verification_types.jl")
include("StenoticHemodynamics/core/types.jl")
include("StenoticHemodynamics/workflows/parallel.jl")
include("StenoticHemodynamics/numerics/policies.jl")
include("StenoticHemodynamics/core/geometry.jl")
include("StenoticHemodynamics/numerics/state.jl")
include("StenoticHemodynamics/numerics/model.jl")
include("StenoticHemodynamics/core/diagnostics.jl")
include("StenoticHemodynamics/adapters/stokes_ic.jl")
include("StenoticHemodynamics/adapters/membrane_fsi.jl")
include("StenoticHemodynamics/numerics/solver.jl")
include("StenoticHemodynamics/numerics/dg.jl")
include("StenoticHemodynamics/adapters/sciml_problem.jl")
include("StenoticHemodynamics/numerics/backends.jl")
include("StenoticHemodynamics/io/writers.jl")
include("StenoticHemodynamics/io/outputs.jl")
include("StenoticHemodynamics/io/waveforms.jl")
include("StenoticHemodynamics/adapters/openbf_protocol.jl")
include("StenoticHemodynamics/workflows/workflow_values.jl")
include("StenoticHemodynamics/workflows/studies.jl")
include("StenoticHemodynamics/workflows/refinement.jl")
include("StenoticHemodynamics/workflows/native_resolved_fsi_mesh.jl")
include("StenoticHemodynamics/workflows/native_resolved_fsi_workflow.jl")
include("StenoticHemodynamics/workflows/resolved3d_types.jl")
include("StenoticHemodynamics/adapters/resolved3d_io.jl")
include("StenoticHemodynamics/adapters/resolved3d_writer.jl")
include("StenoticHemodynamics/adapters/native_resolved_fsi.jl")
include("StenoticHemodynamics/workflows/resolved3d_compare.jl")
include("StenoticHemodynamics/workflows/native_resolved_fsi_parity.jl")
include("StenoticHemodynamics/workflows/operator_validation.jl")
include("StenoticHemodynamics/workflows/resolved3d_outputs.jl")
include("StenoticHemodynamics/workflows/stationary_stokes_refinement.jl")
include("StenoticHemodynamics/workflows/membrane_fsi_validation.jl")
include("StenoticHemodynamics/workflows/verification.jl")
include("StenoticHemodynamics/workflows/geometry_exports.jl")
include("StenoticHemodynamics/workflows/benchmarks.jl")
include("StenoticHemodynamics/cli/cli.jl")

end
