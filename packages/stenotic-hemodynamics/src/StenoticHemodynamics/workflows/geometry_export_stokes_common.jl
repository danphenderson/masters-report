# Keep Gridap and Distributed usage local to the stationary-Stokes export
# surface. These helpers drive fixed-wall geometry assets, not transient or FSI
# flow generation.
using Distributed
using Gridap: Point

"""
    initialize_stenosis_export_workers!(worker_ids)

Ensure parallel workers used by the stationary-Stokes export surface have the
package loaded before remote trajectory cases are evaluated.
"""
function initialize_stenosis_export_workers!(worker_ids)
    isempty(worker_ids) && return worker_ids

    for worker_id in worker_ids
        fetch(remotecall_eval(Main, worker_id, quote
            using StenoticHemodynamics
        end
        ))
    end

    return worker_ids
end
