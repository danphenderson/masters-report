"""
    export_mesh_view_data(opts)

Write FEM and FVM mesh-view CSV assets for the default smooth stenosis geometry.
These files expose the fixed-wall stationary-Stokes mesh layout and a matching
1D control-volume view; they are geometry/report assets rather than transient
simulation outputs.
"""
function export_mesh_view_data(opts::GeometryExportOptions)
    severity = MESH_VIEW_SEVERITY
    params = validate(Params(severity=severity, initial_condition=GeometryRestIC()))
    ic = StationaryStokesIC(
        pressure_drop_pa=MESH_VIEW_PRESSURE_DROP_PA,
        mesh_nz=MESH_VIEW_FEM_NZ,
        mesh_nr=MESH_VIEW_FEM_NR,
        mesh_ntheta=MESH_VIEW_FEM_NTHETA,
    )
    mesh = generated_stokes_mesh(params, ic)
    severity_label = round(Int, severity)
    manifest_path = joinpath(opts.output_dir, "mesh_view_manifest.csv")
    fem_path = joinpath(opts.output_dir, "fem_mesh_view_sev$(severity_label).csv")
    fvm_path = joinpath(opts.output_dir, "fvm_mesh_view_sev$(severity_label).csv")
    fem_segments = write_fem_mesh_view_csv(fem_path, mesh, severity; overwrite=opts.overwrite)
    fvm_cells = write_fvm_mesh_view_csv(fvm_path, params; overwrite=opts.overwrite)

    guarded_open(manifest_path, opts.overwrite) do io
        println(io, "status,severity,length_cm,rbase_cm,fem_csv,fem_mesh_nz,fem_mesh_nr,fem_mesh_ntheta,fem_nodes,fem_cells,fem_view_segments,fvm_csv,fvm_method,fvm_nx,fvm_dx_cm,note")
        println(io, csv_row((
            "written",
            severity,
            params.length_cm,
            params.rmax,
            portable_project_path(fem_path),
            mesh.nz,
            mesh.nr,
            mesh.ntheta,
            length(mesh.coordinates),
            length(mesh.cells),
            fem_segments,
            portable_project_path(fvm_path),
            spatial_method_name(params.space),
            params.nx,
            params.length_cm / params.nx,
            "mesh views for the C-infinity default stenosis geometry",
        )))
    end

    return [manifest_path, fem_path, fvm_path]
end

function fem_mesh_local_node_id(k::Int, a::Int, ntheta::Int)
    return k == 0 ? 1 : 1 + (k - 1) * ntheta + a
end

function fem_mesh_node_id(mesh::GeneratedStokesMesh, j::Int, k::Int, a::Int)
    nlocal = 1 + mesh.nr * mesh.ntheta
    return j * nlocal + fem_mesh_local_node_id(k, a, mesh.ntheta)
end

"""
    write_fem_mesh_view_csv(path, mesh, severity; overwrite=false)

Write a line-segment view of the Gridap tetrahedral mesh. The output is a
visualization-oriented sampling of wall and cut lines rather than a full cell
connectivity dump.
"""
function write_fem_mesh_view_csv(
    path::String,
    mesh::GeneratedStokesMesh,
    severity::Float64;
    overwrite::Bool = false,
)
    segment_count = 0
    guarded_open(path, overwrite) do io
        println(io, "severity,mesh_kind,line_group,z1_cm,x1_cm,y1_cm,z2_cm,x2_cm,y2_cm,source_index")

        source_index = 1
        for j in 0:mesh.nz
            for a in 1:mesh.ntheta
                b = a == mesh.ntheta ? 1 : a + 1
                source_index = write_fem_mesh_segment!(
                    io,
                    mesh,
                    severity,
                    "wall-circumferential",
                    j,
                    mesh.nr,
                    a,
                    j,
                    mesh.nr,
                    b,
                    source_index,
                )
                segment_count += 1
            end
        end

        for j in 0:(mesh.nz - 1)
            for a in 1:mesh.ntheta
                source_index = write_fem_mesh_segment!(
                    io,
                    mesh,
                    severity,
                    "wall-axial",
                    j,
                    mesh.nr,
                    a,
                    j + 1,
                    mesh.nr,
                    a,
                    source_index,
                )
                segment_count += 1
            end
        end

        cut_angles = unique((1, max(1, mesh.ntheta ÷ 2 + 1)))
        cut_stride = max(1, mesh.nz ÷ 16)
        for a in cut_angles
            for j in 0:(mesh.nz - 1)
                for k in 0:mesh.nr
                    source_index = write_fem_mesh_segment!(
                        io,
                        mesh,
                        severity,
                        "cut-axial",
                        j,
                        k,
                        a,
                        j + 1,
                        k,
                        a,
                        source_index,
                    )
                    segment_count += 1
                end
            end

            for j in 0:cut_stride:mesh.nz
                for k in 0:(mesh.nr - 1)
                    source_index = write_fem_mesh_segment!(
                        io,
                        mesh,
                        severity,
                        "cut-radial",
                        j,
                        k,
                        a,
                        j,
                        k + 1,
                        a,
                        source_index,
                    )
                    segment_count += 1
                end
            end
        end
    end
    return segment_count
end

function write_fem_mesh_segment!(
    io,
    mesh::GeneratedStokesMesh,
    severity::Float64,
    line_group::String,
    j1::Int,
    k1::Int,
    a1::Int,
    j2::Int,
    k2::Int,
    a2::Int,
    source_index::Int,
)
    p1 = mesh.coordinates[fem_mesh_node_id(mesh, j1, k1, a1)]
    p2 = mesh.coordinates[fem_mesh_node_id(mesh, j2, k2, a2)]
    println(io, csv_row((
        severity,
        "fem-gridap-tetrahedral",
        line_group,
        p1[3],
        p1[1],
        p1[2],
        p2[3],
        p2[1],
        p2[2],
        source_index,
    )))
    return source_index + 1
end

"""
    write_fvm_mesh_view_csv(path, params; overwrite=false)

Write the 1D cell-center / cell-edge geometry view that pairs with the FEM
mesh-view asset.
"""
function write_fvm_mesh_view_csv(path::String, params::Params; overwrite::Bool = false)
    dx = params.length_cm / params.nx
    guarded_open(path, overwrite) do io
        println(io, "severity,method,nx,cell_index,z_left_cm,z_center_cm,z_right_cm,r_left_cm,r_center_cm,r_right_cm,dx_cm")
        for i in 1:params.nx
            z_left = (i - 1) * dx
            z_center = (i - 0.5) * dx
            z_right = i * dx
            r_left, _, _ = stenosis(z_left, params)
            r_center, _, _ = stenosis(z_center, params)
            r_right, _, _ = stenosis(z_right, params)
            println(io, csv_row((
                params.severity,
                spatial_method_name(params.space),
                params.nx,
                i,
                z_left,
                z_center,
                z_right,
                r_left,
                r_center,
                r_right,
                dx,
            )))
        end
    end
    return params.nx
end
