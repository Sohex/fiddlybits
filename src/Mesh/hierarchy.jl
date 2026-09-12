# The base icosahedron and its bisection: docs/plans/fiddlybits-52v.2-mesh.md,
# section "The hierarchy". The renormalisation below is measured in
# notes/findings/2026-09-10-chordal-bisection-and-spherical-area.md.

using LinearAlgebra: cross, dot

"""
    CellId

The type that crosses the disk boundary. Wraps a 0-based disk index and
defines no arithmetic, so a mixed-base defect is a `MethodError` rather than
a wrong answer. `memory_index` and `disk_id` are the only doors between it
and the 1-based index used in memory.
"""
struct CellId
    value::Int
    CellId(i::Integer) = new(Int(i))
end

# A struct with no iterate method would otherwise be collected by the default
# broadcastable, which raises on length rather than on the arithmetic this type
# refuses.
Base.broadcastable(c::CellId) = Ref(c)

"""
    memory_index(c::CellId)

The 1-based memory index for the 0-based disk id `c`.
"""
memory_index(c::CellId) = Int(c.value) + 1

"""
    disk_id(i::Integer)

The 0-based `CellId` for the 1-based memory index `i`.
"""
disk_id(i::Integer) = CellId(i - 1)

"""
    ncells(L)

The cell count at level `L`.
"""
ncells(L::Integer) = 20 * 4^L

"""
    nedges(L)

The edge count at level `L`.
"""
nedges(L::Integer) = 30 * 4^L

"""
    nvertices(L)

The vertex count at level `L`.
"""
nvertices(L::Integer) = 10 * 4^L + 2

"""
    children(i)

The 1-based memory indices of cell `i`'s four children at the next level, a
contiguous `UnitRange` so a coarsening is a segmented reduction.
"""
children(i::Integer) = (4i - 3):(4i)

"""
    parent(i)

The 1-based memory index of the cell at the previous level that cell `i`
descends from.
"""
parent(i::Integer) = (i + 3) >> 2

"""
    Level{T}

One refinement depth of the hierarchy. `vertices` is 3 by `nvertices(l)`,
columns unit-sphere xyz in `T`. `cells` is 3 by `ncells(l)`, each column three
vertex indices wound counterclockwise seen from outside the sphere.
"""
struct Level{T}
    vertices::Matrix{T}
    cells::Matrix{Int32}
    function Level{T}(vertices::Matrix{T}, cells::Matrix{Int32}) where {T}
        size(vertices, 1) == 3 || throw(ArgumentError("vertices must be 3 by n"))
        size(cells, 1) == 3 || throw(ArgumentError("cells must be 3 by n"))
        return new{T}(vertices, cells)
    end
end

"""
    Hierarchy{T}

The nested levels of the mesh. `levels[l + 1]` holds level `l`.
"""
struct Hierarchy{T}
    levels::Vector{Level{T}}
end

"""
    fix_winding!(cells, vertices)

Swap a cell's last two vertex indices where the triple is wound clockwise
seen from outside, so every column of `cells` ends up counterclockwise seen
from outside the sphere.
"""
function fix_winding!(cells::AbstractMatrix{Int32}, vertices::AbstractMatrix{T}) where {T}
    for j in axes(cells, 2)
        a = @view vertices[:, cells[1, j]]
        b = @view vertices[:, cells[2, j]]
        c = @view vertices[:, cells[3, j]]
        normal = cross(b .- a, c .- a)
        centroid = a .+ b .+ c
        if dot(normal, centroid) < zero(T)
            cells[2, j], cells[3, j] = cells[3, j], cells[2, j]
        end
    end
    return cells
end

"""
    base_icosahedron(T)

The level-0 icosahedron in the working type `T`: 12 vertices from the golden
ratio, normalised to the unit sphere, and 20 faces wound counterclockwise
seen from outside.
"""
function base_icosahedron(::Type{T}) where {T<:AbstractFloat}
    phi = (one(T) + sqrt(T(5))) / 2
    corners = (
        (-one(T), phi, zero(T)), (one(T), phi, zero(T)),
        (-one(T), -phi, zero(T)), (one(T), -phi, zero(T)),
        (zero(T), -one(T), phi), (zero(T), one(T), phi),
        (zero(T), -one(T), -phi), (zero(T), one(T), -phi),
        (phi, zero(T), -one(T)), (phi, zero(T), one(T)),
        (-phi, zero(T), -one(T)), (-phi, zero(T), one(T)),
    )
    vertices = Matrix{T}(undef, 3, 12)
    for (i, v) in enumerate(corners)
        n = sqrt(v[1]^2 + v[2]^2 + v[3]^2)
        vertices[1, i] = v[1] / n
        vertices[2, i] = v[2] / n
        vertices[3, i] = v[3] / n
    end
    cells = Int32[
        1 12 6; 1 6 2; 1 2 8; 1 8 11; 1 11 12;
        2 6 10; 6 12 5; 12 11 3; 11 8 7; 8 2 9;
        4 10 5; 4 5 3; 4 3 7; 4 7 9; 4 9 10;
        5 10 6; 3 5 12; 7 3 11; 9 7 8; 10 9 2;
    ]'
    cells = Matrix{Int32}(cells)
    fix_winding!(cells, vertices)
    return vertices, cells
end

"""
    edge_key(a, b)

The sorted pair `(a, b)` and `(b, a)` collapse to, so a midpoint shared by
two adjacent triangles is looked up once.
"""
edge_key(a::Int32, b::Int32) = a < b ? (a, b) : (b, a)

"""
    midpoint(vertices, a, b, project)

The three components of the chord midpoint of vertices `a` and `b`,
renormalised to the unit sphere unless `project` is false, which leaves it at
the chord midpoint
(notes/findings/2026-09-10-chordal-bisection-and-spherical-area.md).

Returned as a tuple rather than a column, so bisection allocates nothing per
edge.
"""
@inline function midpoint(vertices::AbstractMatrix{T}, a::Int32, b::Int32, project::Bool) where {T}
    mx = (vertices[1, a] + vertices[1, b]) / 2
    my = (vertices[2, a] + vertices[2, b]) / 2
    mz = (vertices[3, a] + vertices[3, b]) / 2
    project || return (mx, my, mz)
    n = sqrt(mx^2 + my^2 + mz^2)
    return (mx / n, my / n, mz / n)
end

"""
    get_or_create_midpoint!(vertices, cache, counter, a, b, project)

The vertex index of the midpoint of `a` and `b`, from `cache` if the other
triangle sharing this edge already created it, otherwise a new column of
`vertices` at `counter`, advancing `counter`.
"""
function get_or_create_midpoint!(vertices::Matrix{T}, cache::Dict{Tuple{Int32,Int32},Int32},
                                  counter::Ref{Int}, a::Int32, b::Int32, project::Bool) where {T}
    key = edge_key(a, b)
    haskey(cache, key) && return cache[key]
    idx = counter[]
    mx, my, mz = midpoint(vertices, a, b, project)
    vertices[1, idx] = mx
    vertices[2, idx] = my
    vertices[3, idx] = mz
    result = Int32(idx)
    cache[key] = result
    counter[] = idx + 1
    return result
end

"""
    bisect(level, project)

The next `Level` from `level`: every vertex kept at its index, one new
vertex per edge shared by adjacent triangles, and each parent's four
children placed at its `children` range: the three corner triangles at the
parent's three vertices, in the parent's vertex order, then the central
triangle of the three edge midpoints.

`project` renormalises every new vertex to the unit sphere. `project =
false` is the positive control: the new vertex is left at the chord
midpoint, which is the path
notes/findings/2026-09-10-chordal-bisection-and-spherical-area.md measures.
"""
function bisect(level::Level{T}, project::Bool) where {T}
    nv = size(level.vertices, 2)
    nc = size(level.cells, 2)
    vertices = Matrix{T}(undef, 3, nv + ((3 * nc) >> 1))
    vertices[:, 1:nv] .= level.vertices
    cells = Matrix{Int32}(undef, 3, 4 * nc)
    cache = Dict{Tuple{Int32,Int32},Int32}()
    counter = Ref(nv + 1)
    for i in 1:nc
        v0, v1, v2 = level.cells[1, i], level.cells[2, i], level.cells[3, i]
        m01 = get_or_create_midpoint!(vertices, cache, counter, v0, v1, project)
        m12 = get_or_create_midpoint!(vertices, cache, counter, v1, v2, project)
        m20 = get_or_create_midpoint!(vertices, cache, counter, v2, v0, project)
        base = 4 * (i - 1)
        cells[:, base + 1] .= (v0, m01, m20)
        cells[:, base + 2] .= (v1, m12, m01)
        cells[:, base + 3] .= (v2, m20, m12)
        cells[:, base + 4] .= (m01, m12, m20)
    end
    return Level{T}(vertices, cells)
end

"""
    hierarchy(L; T = Float64, project = true)

The nested `Hierarchy{T}` from level 0 through level `L`, each level built by
bisecting the one before, starting from `base_icosahedron(T)`.

`project = false` is the positive control: every new vertex is the chord
midpoint with no renormalisation. It exists so the oracles of the geometry
row have a positive control that must fail.
"""
function hierarchy(L::Integer; T = Float64, project::Bool = true)
    v0, c0 = base_icosahedron(T)
    levels = Vector{Level{T}}(undef, L + 1)
    levels[1] = Level{T}(v0, c0)
    for l in 1:L
        levels[l + 1] = bisect(levels[l], project)
    end
    return Hierarchy{T}(levels)
end
