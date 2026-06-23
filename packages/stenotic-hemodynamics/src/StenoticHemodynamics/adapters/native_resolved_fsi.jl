using Gridap
using Gridap.Arrays
using Gridap.Geometry
using Gridap.ReferenceFEs
using Gridap.TensorValues

import Gridap: ∇
import Gridap.Geometry: face_labeling_from_vertex_filter, get_grid_topology

include("native_resolved_fsi_types.jl")
include("native_resolved_fsi_gridap.jl")
include("native_resolved_fsi_sampling.jl")
include("native_resolved_fsi_partitioned.jl")
include("native_resolved_fsi_roundtrip.jl")
