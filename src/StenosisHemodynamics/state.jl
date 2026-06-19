"""
Packed `[A; Q]` state layout for SciML-compatible in-place RHS calls.
"""
struct PackedStateLayout
    nx::Int

    function PackedStateLayout(nx::Int)
        nx > 0 || throw(ArgumentError("nx must be positive"))
        return new(nx)
    end
end

state_length(layout::PackedStateLayout) = 2 * layout.nx
area_range(layout::PackedStateLayout) = 1:layout.nx
flow_range(layout::PackedStateLayout) = (layout.nx + 1):state_length(layout)

function assert_state_length(u::AbstractVector, layout::PackedStateLayout)
    length(u) == state_length(layout) ||
        throw(DimensionMismatch("expected packed state length $(state_length(layout)), got $(length(u))"))
    return nothing
end

function area_view(u::AbstractVector, layout::PackedStateLayout)
    assert_state_length(u, layout)
    return view(u, area_range(layout))
end

function flow_view(u::AbstractVector, layout::PackedStateLayout)
    assert_state_length(u, layout)
    return view(u, flow_range(layout))
end

function state_views(u::AbstractVector, layout::PackedStateLayout)
    assert_state_length(u, layout)
    return area_view(u, layout), flow_view(u, layout)
end

function pack_state(A::AbstractVector, Q::AbstractVector)
    length(A) == length(Q) ||
        throw(DimensionMismatch("area and flow vectors must have the same length"))

    layout = PackedStateLayout(length(A))
    u = Vector{promote_type(eltype(A), eltype(Q))}(undef, state_length(layout))
    copyto!(area_view(u, layout), A)
    copyto!(flow_view(u, layout), Q)
    return u
end

function unpack_state(u::AbstractVector, layout::PackedStateLayout)
    return copy(area_view(u, layout)), copy(flow_view(u, layout))
end

struct RHSCache
    area_flux::Vector{Float64}
    flow_flux::Vector{Float64}
    source::Vector{Float64}
    area_slope::Vector{Float64}
    flow_slope::Vector{Float64}
end

function RHSCache(nx::Int)
    nx > 0 || throw(ArgumentError("nx must be positive"))
    return RHSCache(
        zeros(Float64, nx + 1),
        zeros(Float64, nx + 1),
        zeros(Float64, nx),
        zeros(Float64, nx),
        zeros(Float64, nx),
    )
end

struct NativeStepCache
    rhs::RHSCache
    dA1::Vector{Float64}
    dQ1::Vector{Float64}
    dA2::Vector{Float64}
    dQ2::Vector{Float64}
    dA3::Vector{Float64}
    dQ3::Vector{Float64}
    A1::Vector{Float64}
    Q1::Vector{Float64}
    A2::Vector{Float64}
    Q2::Vector{Float64}
    A3::Vector{Float64}
    Q3::Vector{Float64}
end

function NativeStepCache(nx::Int)
    nx > 0 || throw(ArgumentError("nx must be positive"))
    return NativeStepCache(
        RHSCache(nx),
        zeros(Float64, nx),
        zeros(Float64, nx),
        zeros(Float64, nx),
        zeros(Float64, nx),
        zeros(Float64, nx),
        zeros(Float64, nx),
        zeros(Float64, nx),
        zeros(Float64, nx),
        zeros(Float64, nx),
        zeros(Float64, nx),
        zeros(Float64, nx),
        zeros(Float64, nx),
    )
end

"""
Semi-discrete finite-volume system and reusable RHS cache for one `Params`
case.

`SemiDiscreteSimulation` owns mutable cache arrays for fluxes and source terms;
do not share one instance across concurrent solves.
"""
struct SemiDiscreteSimulation
    params::Params
    z::Vector{Float64}
    dx::Float64
    layout::PackedStateLayout
    cache::RHSCache
end

"""
    semidiscretize(params) -> SemiDiscreteSimulation

Build the grid, packed-state layout, and RHS cache for a `Params` case.
"""
function semidiscretize(p::Params)
    validate(p)
    dx = p.length_cm / p.nx
    z = [(i - 0.5) * dx for i in 1:p.nx]
    layout = PackedStateLayout(p.nx)
    return SemiDiscreteSimulation(p, z, dx, layout, RHSCache(p.nx))
end

"""
    initial_condition(sim) -> Vector{Float64}

Return packed initial state `[A; Q]` for `sim`.
"""
function initial_condition(sim::SemiDiscreteSimulation)
    state = initial_state_result(sim.params)
    return pack_state(state.area, state.flow)
end
