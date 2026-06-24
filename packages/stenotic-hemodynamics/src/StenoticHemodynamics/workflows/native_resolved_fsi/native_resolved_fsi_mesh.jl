const SECTION41_NATIVE_CASE_IDS = (:sev23, :sev40, :sev50)
const SECTION41_NATIVE_BOUNDARY_TAG_NAMES = (:inlet, :outlet, :wall, :interior)
const SECTION41_LENGTH_CM = 6.0
const SECTION41_RMAX_CM = 0.18
const SECTION41_IMPORTED_CASE_TO_NATIVE_CASE = Dict(
    "77" => :sev23,
    "60" => :sev40,
)

"""
    NativeResolvedFSICaseSpec

Geometry contract for one native Section 4.1 resolved-FSI case. The three
supported cases share the same length and asymmetric stenosis profile but differ
in `delta_r_cm` and therefore in the throat radius `rmin_cm`.
"""
struct NativeResolvedFSICaseSpec
    case_id::Symbol
    paper_label::String
    severity_percent::Float64
    length_cm::Float64
    rmax_cm::Float64
    delta_r_cm::Float64
    rmin_cm::Float64
end

function NativeResolvedFSICaseSpec(
    case_id::Symbol,
    paper_label::AbstractString,
    severity_percent::Real,
    delta_r_cm::Real;
    length_cm::Real = SECTION41_LENGTH_CM,
    rmax_cm::Real = SECTION41_RMAX_CM,
)
    length_value = Float64(length_cm)
    rmax_value = Float64(rmax_cm)
    delta_value = Float64(delta_r_cm)
    severity_value = Float64(severity_percent)
    length_value > 0.0 || throw(ArgumentError("length_cm must be positive"))
    rmax_value > 0.0 || throw(ArgumentError("rmax_cm must be positive"))
    delta_value >= 0.0 || throw(ArgumentError("delta_r_cm must be nonnegative"))
    delta_value < rmax_value || throw(ArgumentError("delta_r_cm must be smaller than rmax_cm"))
    return NativeResolvedFSICaseSpec(
        case_id,
        String(paper_label),
        severity_value,
        length_value,
        rmax_value,
        delta_value,
        rmax_value - delta_value,
    )
end

"""
    NativeResolvedFSIMeshResolution(; axial=12, radial=2, angular=12)

Deterministic structured resolution for the Section 4.1 tube mesh. `axial` is
the number of slabs along the vessel length, `radial` is the number of
concentric rings per cross-section, and `angular` is the number of sectors
around the circumference.
"""
struct NativeResolvedFSIMeshResolution
    axial::Int
    radial::Int
    angular::Int
end

function NativeResolvedFSIMeshResolution(; axial::Int = 12, radial::Int = 2, angular::Int = 12)
    axial >= 1 || throw(ArgumentError("axial resolution must be at least 1"))
    radial >= 1 || throw(ArgumentError("radial resolution must be at least 1"))
    angular >= 3 || throw(ArgumentError("angular resolution must be at least 3"))
    return NativeResolvedFSIMeshResolution(axial, radial, angular)
end

"""
    NativeResolvedFSIGeometry

Analytic geometry metadata used to build the backend-agnostic native Section
4.1 mesh contract.
"""
struct NativeResolvedFSIGeometry
    case_spec::NativeResolvedFSICaseSpec
    resolution::NativeResolvedFSIMeshResolution
    throat_z_cm::Float64
    axial_coordinates_cm::Vector{Float64}
    normalized_radial_coordinates::Vector{Float64}
    angular_coordinates_rad::Vector{Float64}
    reference_radii_cm::Vector{Float64}
    reference_areas_cm2::Vector{Float64}
end

"""
    NativeResolvedFSIMeshTags

Stable inlet, outlet, wall, and interior tags for the native structured tube
mesh. Boundary faces are stored as node triples; adapters may re-orient those
triples for backend-specific normal conventions later.
"""
struct NativeResolvedFSIMeshTags
    inlet_faces::Matrix{Int}
    outlet_faces::Matrix{Int}
    wall_faces::Matrix{Int}
    inlet_nodes::Vector{Int}
    outlet_nodes::Vector{Int}
    wall_nodes::Vector{Int}
    interior_cells::Vector{Int}
end

"""
    NativeResolvedFSIMesh

Backend-agnostic tetrahedral mesh contract for the native Section 4.1 stenotic
tube cases.
"""
struct NativeResolvedFSIMesh
    case_spec::NativeResolvedFSICaseSpec
    geometry::NativeResolvedFSIGeometry
    coordinates::Matrix{Float64}
    topology::Matrix{Int}
    tags::NativeResolvedFSIMeshTags
end

"""
    native_resolved_fsi_case_spec(case_id) -> NativeResolvedFSICaseSpec

Return the locked Section 4.1 geometry case specification. The `sev23` case is
an exact paper override with `delta_r_cm = 0.0406` and `rmin_cm = 0.1394`; it
does not reuse the package's generic `severity / 100 * rmax` shorthand.
"""
function native_resolved_fsi_case_spec(case_id::Symbol)
    if case_id === :sev23
        return NativeResolvedFSICaseSpec(:sev23, "23% stenosis", 23.0, 0.0406)
    elseif case_id === :sev40
        return NativeResolvedFSICaseSpec(:sev40, "40% stenosis", 40.0, 0.4 * SECTION41_RMAX_CM)
    elseif case_id === :sev50
        return NativeResolvedFSICaseSpec(:sev50, "50% stenosis", 50.0, 0.5 * SECTION41_RMAX_CM)
    end
    throw(ArgumentError("unsupported native Section 4.1 case id $(repr(case_id)); expected one of $(SECTION41_NATIVE_CASE_IDS)"))
end

function native_resolved_fsi_case_spec(case_id::AbstractString)
    token = lowercase(strip(String(case_id)))
    if token in ("sev23", "23", "23%")
        return native_resolved_fsi_case_spec(:sev23)
    elseif token in ("sev40", "40", "40%")
        return native_resolved_fsi_case_spec(:sev40)
    elseif token in ("sev50", "50", "50%")
        return native_resolved_fsi_case_spec(:sev50)
    end
    throw(ArgumentError("unsupported native Section 4.1 case id $(repr(case_id))"))
end

function native_resolved_fsi_case_spec(severity::Real)
    severity_value = Float64(severity)
    if severity_value == 23.0
        return native_resolved_fsi_case_spec(:sev23)
    elseif severity_value == 40.0
        return native_resolved_fsi_case_spec(:sev40)
    elseif severity_value == 50.0
        return native_resolved_fsi_case_spec(:sev50)
    end
    throw(ArgumentError("unsupported native Section 4.1 severity $(repr(severity))"))
end

native_resolved_fsi_case_specs() = [native_resolved_fsi_case_spec(case_id) for case_id in SECTION41_NATIVE_CASE_IDS]

"""
    native_resolved_fsi_imported_case_spec(case_label) -> Union{NativeResolvedFSICaseSpec,Nothing}

Return the exact native Section 4.1 geometry associated with a known imported
resolved-3D case label. Unknown labels return `nothing` so generic comparison
fixtures keep their explicit severity contract.
"""
function native_resolved_fsi_imported_case_spec(case_label::AbstractString)
    token = strip(String(case_label))
    case_id = get(SECTION41_IMPORTED_CASE_TO_NATIVE_CASE, token, nothing)
    case_id === nothing && return nothing
    return native_resolved_fsi_case_spec(case_id)
end

"""
    native_resolved_fsi_reduced_geometry_severity(case_spec) -> Float64

Return the reduced-model severity value that reproduces the exact native
Canic geometry amplitude `delta_r_cm` through the legacy
`rmax * severity / 100` parameterization.
"""
function native_resolved_fsi_reduced_geometry_severity(case_spec::NativeResolvedFSICaseSpec)
    return 100.0 * case_spec.delta_r_cm / case_spec.rmax_cm
end

"""
    native_resolved_fsi_throat_z(case_spec; atol=1e-12, maxiter=256) -> Float64

Locate the unique Section 4.1 throat by solving the shared analytic
`g(z) = 0` condition from Figure 3.
"""
function native_resolved_fsi_throat_z(case_spec::NativeResolvedFSICaseSpec; atol::Real = 1.0e-12, maxiter::Int = 256)
    atol_value = Float64(atol)
    atol_value > 0.0 || throw(ArgumentError("atol must be positive"))
    maxiter >= 1 || throw(ArgumentError("maxiter must be at least 1"))
    lo = 0.0
    hi = case_spec.length_cm
    g_lo = asymmetric_geometry_terms(lo)[1]
    g_hi = asymmetric_geometry_terms(hi)[1]
    g_lo <= 0.0 || throw(ArgumentError("expected g(0) <= 0 for the Section 4.1 profile"))
    g_hi >= 0.0 || throw(ArgumentError("expected g(L) >= 0 for the Section 4.1 profile"))

    for _ in 1:maxiter
        mid = 0.5 * (lo + hi)
        g_mid = asymmetric_geometry_terms(mid)[1]
        abs(g_mid) <= atol_value && return mid
        if g_mid < 0.0
            lo = mid
        else
            hi = mid
        end
    end
    return 0.5 * (lo + hi)
end

"""
    native_resolved_fsi_radius(case_spec, z_cm) -> Float64

Section 4.1 reference radius at one axial coordinate. The asymmetric kernel is
shared with `core/geometry.jl`, but the 23% case keeps the exact paper delta
instead of deriving it from `severity_percent`.
"""
function native_resolved_fsi_radius(case_spec::NativeResolvedFSICaseSpec, z_cm::Real)
    z_value = Float64(z_cm)
    0.0 <= z_value <= case_spec.length_cm ||
        throw(ArgumentError("z_cm must lie in [0, $(case_spec.length_cm)]"))
    _, _, _, kernel = asymmetric_geometry_terms(z_value)
    return case_spec.rmax_cm - case_spec.delta_r_cm * kernel
end

"""
    native_resolved_fsi_section_area(case_spec, z_cm) -> Float64

Analytic circular cross-section area corresponding to
`native_resolved_fsi_radius(case_spec, z_cm)`.
"""
function native_resolved_fsi_section_area(case_spec::NativeResolvedFSICaseSpec, z_cm::Real)
    radius = native_resolved_fsi_radius(case_spec, z_cm)
    return pi * radius^2
end

"""
    native_resolved_fsi_geometry(case_spec, resolution=NativeResolvedFSIMeshResolution())

Build the deterministic analytic metadata for one native Section 4.1 case and
structured resolution.
"""
function native_resolved_fsi_geometry(
    case_spec::NativeResolvedFSICaseSpec,
    resolution::NativeResolvedFSIMeshResolution = NativeResolvedFSIMeshResolution(),
)
    axial_coordinates_cm = collect(range(0.0, case_spec.length_cm; length=resolution.axial + 1))
    normalized_radial_coordinates = collect(range(0.0, 1.0; length=resolution.radial + 1))
    angular_coordinates_rad = [2.0 * pi * (sector - 1) / resolution.angular for sector in 1:resolution.angular]
    reference_radii_cm = [native_resolved_fsi_radius(case_spec, z) for z in axial_coordinates_cm]
    reference_areas_cm2 = [pi * radius^2 for radius in reference_radii_cm]
    return NativeResolvedFSIGeometry(
        case_spec,
        resolution,
        native_resolved_fsi_throat_z(case_spec),
        axial_coordinates_cm,
        normalized_radial_coordinates,
        angular_coordinates_rad,
        reference_radii_cm,
        reference_areas_cm2,
    )
end

"""
    native_resolved_fsi_boundary_tag_names(mesh_or_tags) -> (:inlet, :outlet, :wall, :interior)

Return the stable boundary tag names for the native mesh contract.
"""
native_resolved_fsi_boundary_tag_names(::NativeResolvedFSIMesh) = SECTION41_NATIVE_BOUNDARY_TAG_NAMES
native_resolved_fsi_boundary_tag_names(::NativeResolvedFSIMeshTags) = SECTION41_NATIVE_BOUNDARY_TAG_NAMES

"""
    native_resolved_fsi_tag_counts(mesh_or_tags)

Return boundary-face counts for `:inlet`, `:outlet`, and `:wall`, plus the
interior cell count.
"""
function native_resolved_fsi_tag_counts(tags::NativeResolvedFSIMeshTags)
    return (
        inlet=size(tags.inlet_faces, 1),
        outlet=size(tags.outlet_faces, 1),
        wall=size(tags.wall_faces, 1),
        interior=length(tags.interior_cells),
    )
end

native_resolved_fsi_tag_counts(mesh::NativeResolvedFSIMesh) = native_resolved_fsi_tag_counts(mesh.tags)

"""
    native_resolved_fsi_node_tag_counts(mesh_or_tags)

Return node-set sizes for the three boundary tags.
"""
function native_resolved_fsi_node_tag_counts(tags::NativeResolvedFSIMeshTags)
    return (inlet=length(tags.inlet_nodes), outlet=length(tags.outlet_nodes), wall=length(tags.wall_nodes))
end

native_resolved_fsi_node_tag_counts(mesh::NativeResolvedFSIMesh) = native_resolved_fsi_node_tag_counts(mesh.tags)

"""
    native_resolved_fsi_mesh(case_spec, resolution=NativeResolvedFSIMeshResolution()) -> NativeResolvedFSIMesh

Build a deterministic tetrahedral tube mesh for the locked Section 4.1 radius
law. The mesh is purely geometric and tagging-focused; it does not assume any
solver backend.
"""
function native_resolved_fsi_mesh(
    case_spec::NativeResolvedFSICaseSpec,
    resolution::NativeResolvedFSIMeshResolution = NativeResolvedFSIMeshResolution(),
)
    geometry = native_resolved_fsi_geometry(case_spec, resolution)
    coordinates = native_resolved_fsi_coordinates(geometry)
    cross_section_triangles = native_resolved_fsi_cross_section_triangles(resolution)
    topology = native_resolved_fsi_topology(cross_section_triangles, coordinates, resolution)
    tags = native_resolved_fsi_tags(cross_section_triangles, geometry, topology)
    return NativeResolvedFSIMesh(case_spec, geometry, coordinates, topology, tags)
end

function native_resolved_fsi_mesh(
    case_id::Union{Symbol,AbstractString,Real},
    resolution::NativeResolvedFSIMeshResolution = NativeResolvedFSIMeshResolution(),
)
    return native_resolved_fsi_mesh(native_resolved_fsi_case_spec(case_id), resolution)
end

function native_resolved_fsi_nodes_per_plane(resolution::NativeResolvedFSIMeshResolution)
    return 1 + resolution.radial * resolution.angular
end

function native_resolved_fsi_plane_node_index(resolution::NativeResolvedFSIMeshResolution, ring::Int, sector::Int)
    ring == 0 && return 1
    return 1 + (ring - 1) * resolution.angular + sector
end

function native_resolved_fsi_next_sector(resolution::NativeResolvedFSIMeshResolution, sector::Int)
    return sector == resolution.angular ? 1 : sector + 1
end

function native_resolved_fsi_coordinates(geometry::NativeResolvedFSIGeometry)
    resolution = geometry.resolution
    plane_node_count = native_resolved_fsi_nodes_per_plane(resolution)
    node_count = length(geometry.axial_coordinates_cm) * plane_node_count
    coordinates = zeros(Float64, node_count, 3)

    for plane in eachindex(geometry.axial_coordinates_cm)
        offset = (plane - 1) * plane_node_count
        z = geometry.axial_coordinates_cm[plane]
        radius = geometry.reference_radii_cm[plane]
        coordinates[offset + 1, 3] = z
        for ring in 1:resolution.radial
            radius_fraction = geometry.normalized_radial_coordinates[ring + 1]
            ring_radius = radius_fraction * radius
            for sector in 1:resolution.angular
                idx = offset + native_resolved_fsi_plane_node_index(resolution, ring, sector)
                theta = geometry.angular_coordinates_rad[sector]
                coordinates[idx, 1] = ring_radius * cos(theta)
                coordinates[idx, 2] = ring_radius * sin(theta)
                coordinates[idx, 3] = z
            end
        end
    end

    return coordinates
end

function native_resolved_fsi_cross_section_triangles(resolution::NativeResolvedFSIMeshResolution)
    triangles = Matrix{Int}(undef, resolution.angular * (2 * resolution.radial - 1), 3)
    row = 1

    for sector in 1:resolution.angular
        next_sector = native_resolved_fsi_next_sector(resolution, sector)
        row = write_triangle_row!(
            triangles,
            row,
            sorted_triangle(
                1,
                native_resolved_fsi_plane_node_index(resolution, 1, sector),
                native_resolved_fsi_plane_node_index(resolution, 1, next_sector),
            ),
        )
    end

    for ring in 2:resolution.radial
        for sector in 1:resolution.angular
            next_sector = native_resolved_fsi_next_sector(resolution, sector)
            inner_sector = native_resolved_fsi_plane_node_index(resolution, ring - 1, sector)
            inner_next = native_resolved_fsi_plane_node_index(resolution, ring - 1, next_sector)
            outer_sector = native_resolved_fsi_plane_node_index(resolution, ring, sector)
            outer_next = native_resolved_fsi_plane_node_index(resolution, ring, next_sector)
            row = write_triangle_row!(triangles, row, sorted_triangle(inner_sector, outer_sector, outer_next))
            row = write_triangle_row!(triangles, row, sorted_triangle(inner_sector, inner_next, outer_next))
        end
    end

    return triangles
end

function native_resolved_fsi_topology(
    cross_section_triangles::Matrix{Int},
    coordinates::Matrix{Float64},
    resolution::NativeResolvedFSIMeshResolution,
)
    plane_node_count = native_resolved_fsi_nodes_per_plane(resolution)
    tetrahedra = Matrix{Int}(undef, resolution.axial * size(cross_section_triangles, 1) * 3, 4)
    row_out = 1

    for slab in 0:(resolution.axial - 1)
        lower_offset = slab * plane_node_count
        upper_offset = lower_offset + plane_node_count
        for row in axes(cross_section_triangles, 1)
            a_local = cross_section_triangles[row, 1]
            b_local = cross_section_triangles[row, 2]
            c_local = cross_section_triangles[row, 3]

            a = lower_offset + a_local
            b = lower_offset + b_local
            c = lower_offset + c_local
            A = upper_offset + a_local
            B = upper_offset + b_local
            C = upper_offset + c_local

            row_out = write_tetrahedron_row!(tetrahedra, row_out, oriented_tetrahedron(a, b, c, C, coordinates))
            row_out = write_tetrahedron_row!(tetrahedra, row_out, oriented_tetrahedron(a, b, B, C, coordinates))
            row_out = write_tetrahedron_row!(tetrahedra, row_out, oriented_tetrahedron(a, A, B, C, coordinates))
        end
    end

    return tetrahedra
end

function native_resolved_fsi_tags(
    cross_section_triangles::Matrix{Int},
    geometry::NativeResolvedFSIGeometry,
    topology::Matrix{Int},
)
    resolution = geometry.resolution
    plane_node_count = native_resolved_fsi_nodes_per_plane(resolution)
    inlet_faces = Matrix{Int}(undef, size(cross_section_triangles, 1), 3)
    outlet_faces = Matrix{Int}(undef, size(cross_section_triangles, 1), 3)
    last_plane_offset = resolution.axial * plane_node_count

    for row in axes(cross_section_triangles, 1)
        inlet_faces[row, 1] = cross_section_triangles[row, 1]
        inlet_faces[row, 2] = cross_section_triangles[row, 2]
        inlet_faces[row, 3] = cross_section_triangles[row, 3]
        outlet_faces[row, 1] = last_plane_offset + cross_section_triangles[row, 1]
        outlet_faces[row, 2] = last_plane_offset + cross_section_triangles[row, 2]
        outlet_faces[row, 3] = last_plane_offset + cross_section_triangles[row, 3]
    end

    wall_faces = Matrix{Int}(undef, 2 * resolution.axial * resolution.angular, 3)
    wall_face_row = 1
    for slab in 0:(resolution.axial - 1)
        lower_offset = slab * plane_node_count
        upper_offset = lower_offset + plane_node_count
        for sector in 1:resolution.angular
            next_sector = native_resolved_fsi_next_sector(resolution, sector)
            u_local, v_local = sorted_edge(
                native_resolved_fsi_plane_node_index(resolution, resolution.radial, sector),
                native_resolved_fsi_plane_node_index(resolution, resolution.radial, next_sector),
            )
            u = lower_offset + u_local
            v = lower_offset + v_local
            U = upper_offset + u_local
            V = upper_offset + v_local
            wall_face_row = write_triangle_row!(wall_faces, wall_face_row, sorted_triangle(u, v, V))
            wall_face_row = write_triangle_row!(wall_faces, wall_face_row, sorted_triangle(u, U, V))
        end
    end

    inlet_nodes = collect(1:plane_node_count)
    outlet_nodes = collect((last_plane_offset + 1):(last_plane_offset + plane_node_count))
    wall_nodes = Vector{Int}(undef, (resolution.axial + 1) * resolution.angular)
    wall_node_row = 1
    for plane in 0:resolution.axial
        offset = plane * plane_node_count
        for sector in 1:resolution.angular
            wall_nodes[wall_node_row] = offset + native_resolved_fsi_plane_node_index(resolution, resolution.radial, sector)
            wall_node_row += 1
        end
    end

    return NativeResolvedFSIMeshTags(
        inlet_faces,
        outlet_faces,
        wall_faces,
        inlet_nodes,
        outlet_nodes,
        wall_nodes,
        collect(1:size(topology, 1)),
    )
end

function sorted_edge(a::Int, b::Int)
    if a <= b
        return (a, b)
    end
    return (b, a)
end

function sorted_triangle(a::Int, b::Int, c::Int)
    if a > b
        a, b = b, a
    end
    if b > c
        b, c = c, b
    end
    if a > b
        a, b = b, a
    end
    return (a, b, c)
end

function write_triangle_row!(matrix::Matrix{Int}, row::Int, triangle::NTuple{3,Int})
    matrix[row, 1] = triangle[1]
    matrix[row, 2] = triangle[2]
    matrix[row, 3] = triangle[3]
    return row + 1
end

function write_tetrahedron_row!(matrix::Matrix{Int}, row::Int, tetrahedron::NTuple{4,Int})
    matrix[row, 1] = tetrahedron[1]
    matrix[row, 2] = tetrahedron[2]
    matrix[row, 3] = tetrahedron[3]
    matrix[row, 4] = tetrahedron[4]
    return row + 1
end

function oriented_tetrahedron(a::Int, b::Int, c::Int, d::Int, coordinates::Matrix{Float64})
    signed_volume6 = tetrahedron_signed_volume6(a, b, c, d, coordinates)
    abs(signed_volume6) > 1.0e-14 ||
        throw(ArgumentError("degenerate native resolved-FSI tetrahedron at nodes ($(a), $(b), $(c), $(d))"))
    if signed_volume6 > 0.0
        return (a, b, c, d)
    end
    return (a, c, b, d)
end

function tetrahedron_signed_volume6(a::Int, b::Int, c::Int, d::Int, coordinates::Matrix{Float64})
    adx = coordinates[a, 1] - coordinates[d, 1]
    ady = coordinates[a, 2] - coordinates[d, 2]
    adz = coordinates[a, 3] - coordinates[d, 3]
    bdx = coordinates[b, 1] - coordinates[d, 1]
    bdy = coordinates[b, 2] - coordinates[d, 2]
    bdz = coordinates[b, 3] - coordinates[d, 3]
    cdx = coordinates[c, 1] - coordinates[d, 1]
    cdy = coordinates[c, 2] - coordinates[d, 2]
    cdz = coordinates[c, 3] - coordinates[d, 3]
    return adx * (bdy * cdz - bdz * cdy) -
           ady * (bdx * cdz - bdz * cdx) +
           adz * (bdx * cdy - bdy * cdx)
end
