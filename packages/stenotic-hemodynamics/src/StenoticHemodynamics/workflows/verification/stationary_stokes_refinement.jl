# Keep the stationary Stokes refinement workflow split local to this include
# layer so other workflow entrypoints do not need to know its internal file map.
include("stationary_stokes_refinement_spec.jl")
include("stationary_stokes_refinement_gridap.jl")
include("stationary_stokes_refinement_rows.jl")
include("stationary_stokes_refinement_outputs.jl")
include("stationary_stokes_refinement_runner.jl")
