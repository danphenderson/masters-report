# Keep the resolved-3D contract surface as one include target for
# `workflows/resolved3d/resolved3d_compare.jl` and
# `workflows/resolved3d/resolved3d_outputs.jl` while
# splitting type-only responsibilities into smaller files.
include("resolved3d_types_core.jl")
include("resolved3d_types_comparison.jl")
include("resolved3d_types_grid_sensitivity.jl")
include("resolved3d_types_rows.jl")
include("resolved3d_types_contracts.jl")
