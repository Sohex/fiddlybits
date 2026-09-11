# Local refinement: docs/plans/fiddlybits-52v.2-mesh.md, section "Refinement".
# The grading rule and the abrupt boundary the damped components take are
# decision 0005.

using ..Verdicts: refuse

"""
    RefinedMesh

A variable-level mesh over one base level. `target[c]` is the number of levels
base cell `c` is refined by, so its leaves are the descendants of `c` at level
`base_level + target[c]`, and the leaves of every base cell together tile the
sphere.

`ring_width` is the width in cells of each transition ring. It is an argument of
`refine` and is never read from a profile here, because `Mesh` references no
configuration; the caller passes the width it read. A width of one steps a level
at every cell, which is the abrupt boundary; a wider ring is the graded one.
"""
struct RefinedMesh
    base_level::Int
    depth::Int
    ring_width::Int
    target::Vector{Int}
end

"""
    descendants(i, t)

The contiguous range of indices cell `i`'s descendants occupy `t` levels finer.
`t` of zero is `i` itself.
"""
descendants(i::Integer, t::Integer) = (4^t * (i - 1) + 1):(4^t * i)

"""
    ancestor(i, t)

The index of the cell `t` levels coarser that cell `i` descends from.
"""
ancestor(i::Integer, t::Integer) = (i - 1) ÷ 4^t + 1

"""
    ring_distance(st, seeds, nc)

The number of edge crossings from the nearest cell of `seeds` to every one of
the `nc` cells, by breadth-first search over `st.edge_neighbour`.
"""
function ring_distance(st::Stencils, seeds, nc::Integer)
    distance = fill(typemax(Int), nc)
    # Every cell enters the queue at most once, so one flat vector of the cell
    # count holds the whole search and no ring allocates a frontier of its own.
    queue = Vector{Int}(undef, nc)
    head = 1
    tail = 1
    for s in seeds
        1 <= s <= nc || refuse("refinement seed", "Mesh.ring_distance",
                               "seed $s is not a cell of a level of $nc cells")
        distance[s] == 0 && continue
        distance[s] = 0
        queue[tail] = Int(s)
        tail += 1
    end
    tail == 1 && refuse("refinement region", "Mesh.ring_distance",
                        "no seed cell was given, so the region the caller meant is not recoverable")
    while head < tail
        i = queue[head]
        head += 1
        for k in 1:3
            j = Int(st.edge_neighbour[k, i])
            if distance[j] == typemax(Int)
                distance[j] = distance[i] + 1
                queue[tail] = j
                tail += 1
            end
        end
    end
    return distance
end

"""
    refine(base_level, st, seeds, depth; ring_width)

The `RefinedMesh` that runs `depth` levels finer inside `seeds` and steps down
one level per ring of `ring_width` cells outside them, where `st` is the
stencils of `base_level`.

The target level of a cell at ring distance `d` is `depth - div(d, ring_width)`,
floored at zero. Two cells sharing an edge differ in distance by at most one and
so in target level by at most one, which is 2:1 balance by construction rather
than by a repair pass.
"""
function refine(base_level::Integer, st::Stencils, seeds, depth::Integer; ring_width::Integer)
    depth >= 0 || refuse("refinement depth", "Mesh.refine",
                         "a depth of $depth is not a number of levels")
    ring_width >= 1 || refuse("ring width", "Mesh.refine",
                              "a ring width of $ring_width would step more than one level between cells sharing an edge, which 2:1 balance forbids")
    nc = size(st.edge_neighbour, 2)
    distance = ring_distance(st, seeds, nc)
    target = [max(0, depth - div(d, ring_width)) for d in distance]
    return RefinedMesh(Int(base_level), Int(depth), Int(ring_width), target)
end

"""
    finest_level(m)

The level of the most refined leaf of `m`.
"""
finest_level(m::RefinedMesh) = m.base_level + m.depth

"""
    leaf_level(m, base_cell)

The level of the leaves that cover base cell `base_cell`.
"""
leaf_level(m::RefinedMesh, base_cell::Integer) = m.base_level + m.target[base_cell]

"""
    nleaves(m)

The number of leaf cells of `m`.
"""
nleaves(m::RefinedMesh) = sum(4^t for t in m.target)

"""
    transition_ring(m)

The transition ring each base cell sits in: zero inside the fully refined
region and rising outward, which is the index a fluid component reads to place
divergence damping inside the transition.
"""
transition_ring(m::RefinedMesh) = [m.depth - t for t in m.target]

"""
    leaves(m)

Every leaf of `m` as `(level, index)`, ordered by base cell and by descendant
order within a base cell.
"""
function leaves(m::RefinedMesh)
    out = Tuple{Int,Int}[]
    for c in eachindex(m.target)
        t = m.target[c]
        for leaf in descendants(c, t)
            push!(out, (m.base_level + t, leaf))
        end
    end
    return out
end

"""
    leaf_owner(m)

The leaf covering every cell of the finest level, and the level of every leaf.
Leaves are numbered in the order `leaves` returns them.
"""
function leaf_owner(m::RefinedMesh)
    owner = Vector{Int32}(undef, ncells(finest_level(m)))
    level_of = Int[]
    id = 0
    for c in eachindex(m.target)
        t = m.target[c]
        for leaf in descendants(c, t)
            id += 1
            push!(level_of, m.base_level + t)
            for f in descendants(leaf, m.depth - t)
                owner[f] = Int32(id)
            end
        end
    end
    return owner, level_of
end

"""
    balanced(m, st_finest)

Whether every two leaves sharing an edge are within one level of each other,
read off the finest level's edge neighbours.
"""
function balanced(m::RefinedMesh, st_finest::Stencils)
    owner, level_of = leaf_owner(m)
    for f in eachindex(owner), k in 1:3
        g = Int(st_finest.edge_neighbour[k, f])
        abs(level_of[owner[f]] - level_of[owner[g]]) <= 1 || return false
    end
    return true
end

"""
    HangingEdge

A coarse leaf's edge that the finer side splits in two. `coarse_cell` is the
index at `coarse_level`, `coarse_local_edge` the local edge that hangs, and
`fine_cells` with `fine_local_edges` the two cells one level finer that cover
it.
"""
struct HangingEdge
    coarse_level::Int
    coarse_cell::Int32
    coarse_local_edge::Int
    fine_cells::NTuple{2,Int32}
    fine_local_edges::NTuple{2,Int}
end

"""
    matching_local_edge(cells, cell, other, k)

The local edge of `cell` spanning the same vertex pair as local edge `k` of
`other`.
"""
function matching_local_edge(cells::AbstractMatrix{Int32}, cell::Integer, other::Integer, k::Integer)
    a, b = edge_local_vertices(cells, other, k)
    for kk in 1:3
        u, v = edge_local_vertices(cells, cell, kk)
        ((u == a && v == b) || (u == b && v == a)) && return kk
    end
    return refuse("shared edge", "Mesh.matching_local_edge",
                  "cells $cell and $other do not span a common edge")
end

"""
    split_of(hier, level, cell, k)

The two children of `cell` at `level + 1` covering its local edge `k`, and the
local edge of each lying on it. Found by matching vertex pairs, so it does not
restate the child order `bisect` writes.
"""
function split_of(hier::Hierarchy, level::Integer, cell::Integer, k::Integer)
    coarse = hier.levels[level+1].cells
    fine = hier.levels[level+2].cells
    a, b = edge_local_vertices(coarse, cell, k)
    at_a = Tuple{Int,Int,Int32}[]
    at_b = Tuple{Int,Int,Int32}[]
    for child in children(cell), kk in 1:3
        u, v = edge_local_vertices(fine, child, kk)
        if u == a || v == a
            push!(at_a, (Int(child), kk, u == a ? v : u))
        elseif u == b || v == b
            push!(at_b, (Int(child), kk, u == b ? v : u))
        end
    end
    for (ca, ka, ma) in at_a, (cb, kb, mb) in at_b
        ma == mb && return (Int32(ca), ka), (Int32(cb), kb)
    end
    return refuse("hanging edge", "Mesh.split_of",
                  "local edge $k of cell $cell at level $level is covered by no two children sharing its midpoint")
end

"""
    hanging_edges(m, hier, sts)

Every hanging edge of `m`, where `sts[l + 1]` is the stencils of level `l`.
A leaf's edge hangs when the leaf across it is one level finer.
"""
function hanging_edges(m::RefinedMesh, hier::Hierarchy, sts::AbstractVector{Stencils})
    out = HangingEdge[]
    for c in eachindex(m.target)
        t = m.target[c]
        l = m.base_level + t
        st = sts[l+1]
        for cell in descendants(c, t), k in 1:3
            neighbour = Int(st.edge_neighbour[k, cell])
            across = ancestor(neighbour, l - m.base_level)
            m.target[across] > t || continue
            kn = matching_local_edge(hier.levels[l+1].cells, neighbour, cell, k)
            (fa, ka), (fb, kb) = split_of(hier, l, neighbour, kn)
            push!(out, HangingEdge(l, Int32(cell), k, (fa, fb), (ka, kb)))
        end
    end
    return out
end

"""
    hanging_flux(density, length)

The flux a coarse edge receives from the two children covering it: each child's
normal flux density times that child's own edge length.
"""
hanging_flux(density::NTuple{2,T}, length::NTuple{2,T}) where {T} =
    fma(density[1], length[1], density[2] * length[2])

"""
    coarse_measure_flux(density, coarse_length)

The positive control of `mesh.refinement_balance`: each child given the coarse
edge's own measure in place of its own. It must fail the identity a constant
density holds `hanging_flux` to.
"""
coarse_measure_flux(density::NTuple{2,T}, coarse_length::T) where {T} =
    (density[1] + density[2]) * coarse_length
