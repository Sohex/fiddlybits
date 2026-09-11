# Both dual measures: docs/plans/fiddlybits-52v.2-mesh.md, section "Both
# measures". REQ-TER-011 requires every measure named and never an
# unqualified "area" or "length". The absolute per-cell floor and the
# vector-form/l'Huilier factor are measured in
# notes/findings/2026-09-10-chordal-bisection-and-spherical-area.md.

using LinearAlgebra: cross, dot, norm, normalize

"""
    Geometry{T}

Both dual measures of one `Level`, on the unit sphere, in `T`.

`cell_area` is `ncells`, the primal cell area. `dual_area` is `nvertices`,
the dual cell area around each primal vertex. `dual_vertex` is 3 by
`ncells`, the circumcentre of each primal cell. `primal_edge_length` and
`dual_edge_length` are `nedges`. `edge_midpoint` is 3 by `nedges`, the
great-circle midpoint of the edge's two primal vertices. `edge_normal` is 3
by `nedges`, the unit tangent vector at the edge midpoint, perpendicular to
the primal edge, pointing from `edge_cell[1, e]` toward `edge_cell[2, e]`.
"""
struct Geometry{T}
    cell_area::Vector{T}
    dual_area::Vector{T}
    dual_vertex::Matrix{T}
    primal_edge_length::Vector{T}
    dual_edge_length::Vector{T}
    edge_midpoint::Matrix{T}
    edge_normal::Matrix{T}
end

"""
    cell_area_vector_form(a, b, c)

The Van Oosterom and Strackee vector form of the spherical excess of the
triangle `(a, b, c)` on the unit sphere: `2 * atan(abs(dot(a, cross(b, c))),
1 + dot(a,b) + dot(b,c) + dot(c,a))`. `geometry`'s primary arm for cell area.
"""
function cell_area_vector_form(a::AbstractVector{T}, b::AbstractVector{T}, c::AbstractVector{T}) where {T}
    triple = dot(a, cross(b, c))
    denom = one(T) + dot(a, b) + dot(b, c) + dot(c, a)
    return 2 * atan(abs(triple), denom)
end

"""
    cell_area_lhuilier(a, b, c)

L'Huilier's theorem, the second arm of the cell-area identity: with the
three arc sides `A = arc_length(b, c)`, `B = arc_length(c, a)`,
`C = arc_length(a, b)` and `s = (A + B + C) / 2`, the spherical excess `E`
solves `tan(E/4) = sqrt(tan(s/2) tan((s-A)/2) tan((s-B)/2) tan((s-C)/2))`.
"""
function cell_area_lhuilier(a::AbstractVector{T}, b::AbstractVector{T}, c::AbstractVector{T}) where {T}
    A = arc_length(b, c)
    B = arc_length(c, a)
    C = arc_length(a, b)
    s = (A + B + C) / 2
    t = tan(s / 2) * tan((s - A) / 2) * tan((s - B) / 2) * tan((s - C) / 2)
    return 4 * atan(sqrt(t))
end

"""
    arc_length(u, v)

The great-circle angle between unit vectors `u` and `v`, `atan(norm(cross(u,
v)), dot(u, v))`.
"""
arc_length(u::AbstractVector{T}, v::AbstractVector{T}) where {T} = atan(norm(cross(u, v)), dot(u, v))

"""
    great_circle_midpoint(u, v)

The great-circle midpoint of unit vectors `u` and `v`: the normalised chord
midpoint, which lies on the great circle through them
(notes/findings/2026-09-10-chordal-bisection-and-spherical-area.md).
"""
great_circle_midpoint(u::AbstractVector{T}, v::AbstractVector{T}) where {T} = normalize(u .+ v)

"""
    circumcentre(a, b, c)

The dual vertex of the spherical triangle `(a, b, c)`: the normalised
`cross(b - a, c - a)`, signed to point away from the sphere's centre.
"""
function circumcentre(a::AbstractVector{T}, b::AbstractVector{T}, c::AbstractVector{T}) where {T}
    n = cross(b .- a, c .- a)
    dot(n, a .+ b .+ c) < zero(T) && (n = .-n)
    return normalize(n)
end

"""
    at_radius(value, radius, power)

The one door a mesh measure reaches a radius through (REQ-TER-011,
REQ-SYS-103): the unit-sphere `value` scaled by `radius^power`, `power` one
for a length and two for an area. Nothing else in this module multiplies a
measure by a radius.
"""
at_radius(value::T, radius::T, power::Integer) where {T} = value * radius^power

"""
    kahan_add!(total, compensation, idx, value)

Adds `value` into `total[idx]`, compensated (Kahan summation) against the
running error carried in `compensation[idx]`, so a vertex accumulating many
cell contributions in traversal order does not lose more than one rounding
to the order they arrive in.
"""
function kahan_add!(total::Vector{T}, compensation::Vector{T}, idx::Integer, value::T) where {T}
    y = value - compensation[idx]
    t = total[idx] + y
    compensation[idx] = (t - total[idx]) - y
    total[idx] = t
    return total
end

"""
    geometry(level, st)

Both dual measures of `level`, using `st` for connectivity. Returned as
`Geometry{Float64}` whatever `level`'s own working type, by promoting its
vertex coordinates to `Float64` before every computation
(notes/findings/2026-09-10-chordal-bisection-and-spherical-area.md).

Cell area is `cell_area_vector_form`. The dual cell area at a primal vertex
is accumulated from the two spherical triangles each incident cell
contributes at that vertex, bounded by the vertex itself, the great-circle
midpoint of each adjacent primal edge, and the cell's circumcentre; the
three vertices of a cell between them receive the whole of it, so the dual
areas tile the same sphere the primal areas do.
"""
function geometry(level::Level, st::Stencils)::Geometry{Float64}
    vertices = Matrix{Float64}(level.vertices)
    cells = level.cells
    nc = size(cells, 2)
    nv = size(vertices, 2)
    ne = size(st.edge_cell, 2)

    cell_area = Vector{Float64}(undef, nc)
    dual_vertex = Matrix{Float64}(undef, 3, nc)
    dual_area = zeros(Float64, nv)
    dual_area_compensation = zeros(Float64, nv)

    for i in 1:nc
        v1, v2, v3 = cells[1, i], cells[2, i], cells[3, i]
        p1 = @view vertices[:, v1]
        p2 = @view vertices[:, v2]
        p3 = @view vertices[:, v3]

        cell_area[i] = cell_area_vector_form(p1, p2, p3)

        cc = circumcentre(p1, p2, p3)
        dual_vertex[:, i] .= cc

        m12 = great_circle_midpoint(p1, p2)
        m23 = great_circle_midpoint(p2, p3)
        m31 = great_circle_midpoint(p3, p1)

        # Each of the six sub-triangles is evaluated on its own, so the dual
        # measure is independent of the primal one and the two closures are two
        # checks rather than one.
        a_p1_m12_cc = cell_area_vector_form(p1, m12, cc)
        a_p1_cc_m31 = cell_area_vector_form(p1, cc, m31)
        a_p2_m23_cc = cell_area_vector_form(p2, m23, cc)
        a_p2_cc_m12 = cell_area_vector_form(p2, cc, m12)
        a_p3_m31_cc = cell_area_vector_form(p3, m31, cc)
        a_p3_cc_m23 = cell_area_vector_form(p3, cc, m23)

        piece1 = a_p1_m12_cc + a_p1_cc_m31
        piece2 = a_p2_m23_cc + a_p2_cc_m12
        piece3 = a_p3_m31_cc + a_p3_cc_m23
        kahan_add!(dual_area, dual_area_compensation, v1, piece1)
        kahan_add!(dual_area, dual_area_compensation, v2, piece2)
        kahan_add!(dual_area, dual_area_compensation, v3, piece3)
    end

    primal_edge_length = Vector{Float64}(undef, ne)
    dual_edge_length = Vector{Float64}(undef, ne)
    edge_midpoint = Matrix{Float64}(undef, 3, ne)
    edge_normal = Matrix{Float64}(undef, 3, ne)
    recorded = falses(ne)

    for i in 1:nc, k in 1:3
        e = st.cell_edge[k, i]
        recorded[e] && continue
        recorded[e] = true

        a, b = edge_local_vertices(cells, i, k)
        pa = @view vertices[:, a]
        pb = @view vertices[:, b]
        primal_edge_length[e] = arc_length(pa, pb)
        edge_midpoint[:, e] .= great_circle_midpoint(pa, pb)

        c1, c2 = st.edge_cell[1, e], st.edge_cell[2, e]
        cc1 = @view dual_vertex[:, c1]
        cc2 = @view dual_vertex[:, c2]
        dual_edge_length[e] = arc_length(cc1, cc2)

        n = normalize(cross(pa, pb))
        dot(n, cc2 .- cc1) < zero(Float64) && (n = .-n)
        edge_normal[:, e] .= n
    end

    return Geometry{Float64}(cell_area, dual_area, dual_vertex, primal_edge_length,
                              dual_edge_length, edge_midpoint, edge_normal)
end
