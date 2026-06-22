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

"""
    RHSCache{T}

Scratch arrays for one finite-volume RHS evaluation.

`RHSCache(nx)` preserves the package's current `Float64` behavior. Typed
constructors such as `RHSCache{Float32}(nx)`, `RHSCache(Float32, nx)`, and
`RHSCache(values)` allocate the same cache layout for another
`T<:AbstractFloat`.

The current solver entry points still operate on `Float64` state arrays and
`Params`, so non-`Float64` caches are preparation for staged genericization
rather than full solver support.
"""
struct RHSCache{T<:AbstractFloat}
    area_flux::Vector{T}
    flow_flux::Vector{T}
    source::Vector{T}
    area_slope::Vector{T}
    flow_slope::Vector{T}
end

function RHSCache{T}(nx::Int) where {T<:AbstractFloat}
    nx > 0 || throw(ArgumentError("nx must be positive"))
    return RHSCache{T}(
        zeros(T, nx + 1),
        zeros(T, nx + 1),
        zeros(T, nx),
        zeros(T, nx),
        zeros(T, nx),
    )
end

RHSCache(nx::Int) = RHSCache{Float64}(nx)
RHSCache(::Type{T}, nx::Int) where {T<:AbstractFloat} = RHSCache{T}(nx)
RHSCache(values::AbstractVector{T}) where {T<:AbstractFloat} = RHSCache{T}(length(values))

"""
    NativeStepCache{T}

Scratch arrays for native fixed-step steppers.

`NativeStepCache(nx)` preserves the current `Float64` allocation path. Typed
constructors mirror `RHSCache` so stepper scratch state can be allocated for
`Float32` or `BigFloat` experiments without changing the default solver
behavior.
"""
struct NativeStepCache{T<:AbstractFloat}
    rhs::RHSCache{T}
    dA1::Vector{T}
    dQ1::Vector{T}
    dA2::Vector{T}
    dQ2::Vector{T}
    dA3::Vector{T}
    dQ3::Vector{T}
    A1::Vector{T}
    Q1::Vector{T}
    A2::Vector{T}
    Q2::Vector{T}
    A3::Vector{T}
    Q3::Vector{T}
end

function NativeStepCache{T}(nx::Int) where {T<:AbstractFloat}
    nx > 0 || throw(ArgumentError("nx must be positive"))
    return NativeStepCache{T}(
        RHSCache{T}(nx),
        zeros(T, nx),
        zeros(T, nx),
        zeros(T, nx),
        zeros(T, nx),
        zeros(T, nx),
        zeros(T, nx),
        zeros(T, nx),
        zeros(T, nx),
        zeros(T, nx),
        zeros(T, nx),
        zeros(T, nx),
        zeros(T, nx),
    )
end

NativeStepCache(nx::Int) = NativeStepCache{Float64}(nx)
NativeStepCache(::Type{T}, nx::Int) where {T<:AbstractFloat} = NativeStepCache{T}(nx)
NativeStepCache(values::AbstractVector{T}) where {T<:AbstractFloat} = NativeStepCache{T}(length(values))

"""
Semi-discrete finite-volume system and reusable RHS cache for one `Params`
case.

`SemiDiscreteSimulation` owns mutable cache arrays for fluxes and source terms;
do not share one instance across concurrent solves. `semidiscretize(params)`
still builds a `Float64` grid and `RHSCache{Float64}` because `Params`,
`initial_state_result`, and the solver entry points remain `Float64`-bound.
"""
struct SemiDiscreteSimulation
    params::Params
    z::Vector{Float64}
    dx::Float64
    layout::PackedStateLayout
    cache::RHSCache{Float64}
end

"""
    semidiscretize(params) -> SemiDiscreteSimulation

Build the `Float64` grid, packed-state layout, and default `RHSCache{Float64}`
for a `Params` case.
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

The packed-state helpers themselves preserve non-`Float64` vector eltypes, but
`initial_condition(sim)` stays `Float64` today because `initial_state_result`
still returns `Float64` arrays.
"""
function initial_condition(sim::SemiDiscreteSimulation)
    state = initial_state_result(sim.params)
    return pack_state(state.area, state.flow)
end
