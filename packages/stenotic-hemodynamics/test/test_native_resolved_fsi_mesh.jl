const NativeResolvedFSICaseSpec = StenoticHemodynamics.NativeResolvedFSICaseSpec
const NativeResolvedFSIMesh = StenoticHemodynamics.NativeResolvedFSIMesh
const NativeResolvedFSIMeshResolution = StenoticHemodynamics.NativeResolvedFSIMeshResolution
const native_resolved_fsi_boundary_tag_names = StenoticHemodynamics.native_resolved_fsi_boundary_tag_names
const native_resolved_fsi_case_spec = StenoticHemodynamics.native_resolved_fsi_case_spec
const native_resolved_fsi_geometry = StenoticHemodynamics.native_resolved_fsi_geometry
const native_resolved_fsi_mesh = StenoticHemodynamics.native_resolved_fsi_mesh
const native_resolved_fsi_node_tag_counts = StenoticHemodynamics.native_resolved_fsi_node_tag_counts
const native_resolved_fsi_plane_node_index = StenoticHemodynamics.native_resolved_fsi_plane_node_index
const native_resolved_fsi_radius = StenoticHemodynamics.native_resolved_fsi_radius
const native_resolved_fsi_section_area = StenoticHemodynamics.native_resolved_fsi_section_area
const native_resolved_fsi_tag_counts = StenoticHemodynamics.native_resolved_fsi_tag_counts
const native_resolved_fsi_throat_z = StenoticHemodynamics.native_resolved_fsi_throat_z
const tetrahedron_signed_volume6 = StenoticHemodynamics.tetrahedron_signed_volume6

function sorted_face_tuple(a::Int, b::Int, c::Int)
    face = sort([a, b, c])
    return (face[1], face[2], face[3])
end

function tetrahedron_face_histogram(topology::Matrix{Int})
    histogram = Dict{NTuple{3,Int},Int}()
    for row in axes(topology, 1)
        a = topology[row, 1]
        b = topology[row, 2]
        c = topology[row, 3]
        d = topology[row, 4]
        for face in (
            sorted_face_tuple(a, b, c),
            sorted_face_tuple(a, b, d),
            sorted_face_tuple(a, c, d),
            sorted_face_tuple(b, c, d),
        )
            histogram[face] = get(histogram, face, 0) + 1
        end
    end
    return histogram
end

function face_set(faces::Matrix{Int})
    return Set(sorted_face_tuple(faces[row, 1], faces[row, 2], faces[row, 3]) for row in axes(faces, 1))
end

@testset "StenoticHemodynamics native resolved-FSI case specs" begin
    spec23 = native_resolved_fsi_case_spec(:sev23)
    spec40 = native_resolved_fsi_case_spec("40%")
    spec50 = native_resolved_fsi_case_spec(50.0)

    @test spec23 isa NativeResolvedFSICaseSpec
    @test spec23.case_id == :sev23
    @test spec23.length_cm ≈ 6.0
    @test spec23.rmax_cm ≈ 0.18
    @test spec23.delta_r_cm ≈ 0.0406
    @test spec23.rmin_cm ≈ 0.1394
    @test abs(spec23.delta_r_cm - 0.23 * spec23.rmax_cm) > 1.0e-6

    throat_z = native_resolved_fsi_throat_z(spec23)
    @test 0.0 < throat_z < spec23.length_cm
    @test native_resolved_fsi_radius(spec23, throat_z) ≈ spec23.rmin_cm atol=1.0e-10
    @test native_resolved_fsi_section_area(spec23, throat_z) ≈ pi * spec23.rmin_cm^2 atol=1.0e-10

    @test spec40.case_id == :sev40
    @test spec40.delta_r_cm ≈ 0.4 * spec40.rmax_cm
    @test spec40.rmin_cm ≈ 0.108

    @test spec50.case_id == :sev50
    @test spec50.delta_r_cm ≈ 0.5 * spec50.rmax_cm
    @test spec50.rmin_cm ≈ 0.09

    @test_throws ArgumentError native_resolved_fsi_case_spec(:sev77)
end

@testset "StenoticHemodynamics native resolved-FSI geometry metadata" begin
    spec23 = native_resolved_fsi_case_spec(:sev23)
    resolution = NativeResolvedFSIMeshResolution(axial=2, radial=2, angular=8)
    geometry = native_resolved_fsi_geometry(spec23, resolution)

    @test geometry.case_spec.case_id == :sev23
    @test geometry.resolution.axial == 2
    @test geometry.resolution.radial == 2
    @test geometry.resolution.angular == 8
    @test geometry.axial_coordinates_cm == [0.0, 3.0, 6.0]
    @test geometry.normalized_radial_coordinates == [0.0, 0.5, 1.0]
    @test length(geometry.angular_coordinates_rad) == 8
    @test geometry.throat_z_cm ≈ native_resolved_fsi_throat_z(spec23) atol=1.0e-12
    @test geometry.reference_radii_cm[1] ≈ spec23.rmax_cm atol=1.0e-12
    @test geometry.reference_radii_cm[end] ≈ spec23.rmax_cm atol=1.0e-12
    @test all(area ≈ pi * radius^2 for (area, radius) in zip(geometry.reference_areas_cm2, geometry.reference_radii_cm))
end

@testset "StenoticHemodynamics native resolved-FSI mesh and boundary tags" begin
    resolution = NativeResolvedFSIMeshResolution(axial=2, radial=2, angular=8)
    mesh = native_resolved_fsi_mesh(:sev23, resolution)

    @test mesh isa NativeResolvedFSIMesh
    @test mesh.case_spec.case_id == :sev23
    @test native_resolved_fsi_boundary_tag_names(mesh) == (:inlet, :outlet, :wall, :interior)

    expected_nodes_per_plane = 1 + resolution.radial * resolution.angular
    expected_cross_section_faces = resolution.angular * (2 * resolution.radial - 1)
    expected_node_count = (resolution.axial + 1) * expected_nodes_per_plane
    expected_cell_count = 3 * resolution.axial * expected_cross_section_faces
    expected_wall_faces = 2 * resolution.axial * resolution.angular

    @test size(mesh.coordinates) == (expected_node_count, 3)
    @test size(mesh.topology) == (expected_cell_count, 4)
    @test native_resolved_fsi_tag_counts(mesh) == (
        inlet=expected_cross_section_faces,
        outlet=expected_cross_section_faces,
        wall=expected_wall_faces,
        interior=expected_cell_count,
    )
    @test native_resolved_fsi_node_tag_counts(mesh) == (
        inlet=expected_nodes_per_plane,
        outlet=expected_nodes_per_plane,
        wall=(resolution.axial + 1) * resolution.angular,
    )
    @test mesh.tags.interior_cells == collect(1:expected_cell_count)

    plane_node_count = expected_nodes_per_plane
    for plane in 1:(resolution.axial + 1)
        plane_radius = mesh.geometry.reference_radii_cm[plane]
        for sector in 1:resolution.angular
            node_index = (plane - 1) * plane_node_count +
                         native_resolved_fsi_plane_node_index(resolution, resolution.radial, sector)
            @test hypot(mesh.coordinates[node_index, 1], mesh.coordinates[node_index, 2]) ≈ plane_radius atol=1.0e-12
        end
    end

    @test all(mesh.coordinates[node, 3] ≈ 0.0 for node in mesh.tags.inlet_nodes)
    @test all(mesh.coordinates[node, 3] ≈ mesh.case_spec.length_cm for node in mesh.tags.outlet_nodes)
    @test length(unique(mesh.tags.wall_nodes)) == length(mesh.tags.wall_nodes)

    for row in axes(mesh.topology, 1)
        @test tetrahedron_signed_volume6(
            mesh.topology[row, 1],
            mesh.topology[row, 2],
            mesh.topology[row, 3],
            mesh.topology[row, 4],
            mesh.coordinates,
        ) > 0.0
    end

    histogram = tetrahedron_face_histogram(mesh.topology)
    @test all(count == 1 || count == 2 for count in values(histogram))

    boundary_faces_from_cells = Set(face for (face, count) in histogram if count == 1)
    boundary_faces_from_tags = union(face_set(mesh.tags.inlet_faces), face_set(mesh.tags.outlet_faces), face_set(mesh.tags.wall_faces))

    @test length(boundary_faces_from_cells) ==
          native_resolved_fsi_tag_counts(mesh).inlet +
          native_resolved_fsi_tag_counts(mesh).outlet +
          native_resolved_fsi_tag_counts(mesh).wall
    @test boundary_faces_from_tags == boundary_faces_from_cells
end
