# The real-mesh certification case: docs/plans/fiddlybits-52v.7-kernels.md,
# section "Certification", and notes/findings/2026-09-11-ulp-ensemble-member-
# count.md, "What the ensemble cannot see". A per-vertex stencil-shaped gather
# over one level of Mesh.hierarchy, built the same way CertifyFixtures builds
# the synthetic stand-in case, so decision 0005's twelve degree-five cells sit
# inside a case the sampled ensemble was actually sized against.

using Fiddlybits: Backends, Mesh, Reductions

module CertifyMeshFixture

using Fiddlybits: Backends, Mesh, Reductions

const LEVEL = 5
const STEPS = 20
const COUPLING = 1 / 64
const MAX_VALENCE = Mesh.MAX_VALENCE

"Every term one vertex's step sums: the padded MAX_VALENCE the gather reads,
some at zero weight, and the one the field coupling adds."
const TERMS = MAX_VALENCE + 1

"""
    vertex_valence(level)

The number of cells incident to each vertex of `level`, counted from
`level.cells` alone: for a closed triangulated surface this equals both the
vertex's edge degree and the number of distinct vertices it shares a cell
edge with, the same count `Mesh.build_vertex_neighbour` accumulates
internally while building the per-cell `vertex_neighbour` table.
"""
function vertex_valence(level::Mesh.Level)
    nc = size(level.cells, 2)
    nv = size(level.vertices, 2)
    valence = zeros(Int32, nv)
    for i in 1:nc, k in 1:3
        valence[level.cells[k, i]] += Int32(1)
    end
    return valence
end

"""
    vertex_neighbours(level, valence)

The vertex-to-vertex adjacency of `level`, dense `MAX_VALENCE` by
`nvertices`: every other vertex a vertex shares a cell edge with, ascending,
padded with the vertex itself where `valence` falls short of `MAX_VALENCE`.
`Mesh.Stencils` documents exactly this padding convention for its own
per-cell tables; this is the per-vertex analogue, built from `level.cells`
the way `Stencils` is. Errors if a vertex's distinct-neighbour count does not
match `valence`, which would mean the surface is not the closed triangulation
`vertex_valence` assumes.
"""
function vertex_neighbours(level::Mesh.Level, valence::Vector{Int32})
    nc = size(level.cells, 2)
    nv = size(level.vertices, 2)
    incident = [Int32[] for _ in 1:nv]
    for i in 1:nc
        a, b, c = level.cells[1, i], level.cells[2, i], level.cells[3, i]
        push!(incident[a], i)
        push!(incident[b], i)
        push!(incident[c], i)
    end
    neighbour = zeros(Int32, MAX_VALENCE, nv)
    for v in 1:nv
        others = Int32[]
        for i in incident[v], k in 1:3
            u = level.cells[k, i]
            (u == v || u in others) && continue
            push!(others, u)
        end
        sort!(others)
        length(others) == valence[v] ||
            error("vertex $v: $(length(others)) distinct neighbours against a valence of $(valence[v])")
        for (j, u) in enumerate(others)
            neighbour[j, v] = u
        end
        for j in (length(others) + 1):MAX_VALENCE
            neighbour[j, v] = v
        end
    end
    return neighbour
end

"""
    vertex_weights(T, n, valence)

The gather weights, `MAX_VALENCE` by `n`, every column's nonzero entries
summing to one, from a fixed formula rather than a draw. The padded slots
carry zero weight, so the gather multiplies through them without branching.
"""
function vertex_weights(::Type{T}, n::Integer, valence::Vector{Int32}) where {T}
    w = zeros(T, MAX_VALENCE, n)
    for i in 1:n
        d = valence[i]
        raw = [Float64(mod(i * 7 + k * 13, 17) + 1) for k in 1:d]
        s = sum(raw)
        for k in 1:d
            w[k, i] = T(raw[k] / s)
        end
    end
    return w
end

field_u(::Type{T}, n::Integer) where {T} = T[T(mod(i * 31 + 7, 97)) / T(20) - T(2) for i in 1:n]
field_v(::Type{T}, n::Integer) where {T} = T[T(mod(i * 53 + 11, 89)) / T(30) - T(1) for i in 1:n]

"""
    make_step(n, neighbour, w64; scale = 1)

One step of the real-mesh case, at whatever floating point type the state
carries: each field gathered over the vertex stencil in ascending neighbour
order, then the two gathered fields mixed by a rotation of angle `COUPLING`,
the same recipe `CertifyFixtures.make_step` uses on the synthetic case.
`scale` multiplies every weight, which is how a test injects a defect over
the whole mesh.
"""
function make_step(n::Integer, neighbour::AbstractMatrix, w64::AbstractMatrix; scale::Real = 1)
    function step!(state::Vector{Vector{T}}) where {T}
        u, v = state[1], state[2]
        w = T.(w64) .* T(scale)
        ut = Vector{T}(undef, n)
        vt = Vector{T}(undef, n)
        for i in 1:n
            au = zero(T)
            av = zero(T)
            for k in 1:MAX_VALENCE
                au += u[neighbour[k, i]] * w[k, i]
                av += v[neighbour[k, i]] * w[k, i]
            end
            ut[i] = au + T(COUPLING) * av
            vt[i] = av - T(COUPLING) * au
        end
        copyto!(u, ut)
        copyto!(v, vt)
        return state
    end
    return step!
end

"""
    localized_defect(n, neighbour, w64, cell, relative)

A candidate whose `Float32` path scales the weights of `cell` alone by `1 +
relative` and whose `Float64` path does not, so the defect is confined to the
one named cell rather than spread over every weight the way
`CertifyFixtures.injected` scales every weight of the synthetic case.
"""
function localized_defect(n::Integer, neighbour::AbstractMatrix, w64::AbstractMatrix,
                          cell::Integer, relative::Real)
    good = make_step(n, neighbour, w64)
    defective = copy(w64)
    defective[:, cell] .*= (1 + relative)
    bad = make_step(n, neighbour, defective)
    return function (state::Vector{Vector{T}}) where {T}
        return T === Float32 ? bad(state) : good(state)
    end
end

"""
    real_mesh_case()

The real-mesh certification case at `LEVEL`: the `Backends.EnsembleCase`, its
neighbour table, its weight table, its per-vertex valence, and the vertices
of valence five decision 0005 puts at every level, identified from `valence`
alone rather than assumed.
"""
function real_mesh_case()
    hierarchy = Mesh.hierarchy(LEVEL)
    level = hierarchy.levels[LEVEL + 1]
    valence = vertex_valence(level)
    neighbour = vertex_neighbours(level, valence)
    nv = size(level.vertices, 2)
    w64 = vertex_weights(Float64, nv, valence)
    fields = [field_u(Float64, nv), field_v(Float64, nv)]
    case = Backends.EnsembleCase("icosahedral-mesh-level-$LEVEL", fields,
                                 make_step(nv, neighbour, w64))
    pentagon = findall(==(Int32(5)), valence)
    return case, neighbour, w64, valence, pentagon
end

"""
    roundoff(case; sites = nothing)

The divergence one step of a candidate at `Float32` injects, in the one norm
`Backends.divergence` returns, scoped to `sites` the same way
`Backends.certification` is: the per-cell bound of `Reductions.error_bound`
at `TERMS` terms and the case's own largest absolute value scaled by `1 +
COUPLING`, summed over every field and cell `sites` names, or over the whole
case when `sites` is `nothing`. The term count is checked against
`Reductions.validity_limit` before it is read.
"""
function roundoff(case::Backends.EnsembleCase; sites::Union{Nothing,Vector{Tuple{Int,Int}}} = nothing)
    TERMS < Reductions.validity_limit(Float32) ||
        error("the real-mesh case sums $(TERMS) terms per cell, which Reductions.error_bound " *
              "refuses at Float32")
    magnitude = maximum(maximum(abs, f) for f in case.fields) * (1 + COUPLING)
    n = sites === nothing ? sum(length, case.fields) : length(sites)
    return n * Reductions.error_bound(Float32, TERMS, magnitude)
end

end # module CertifyMeshFixture
