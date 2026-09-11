# The dense stencil tables: docs/plans/fiddlybits-52v.2-mesh.md, section
# "Stencils".

"""
    Stencils

The dense neighbour tables built from one `Level`'s `cells` alone.

Local edge `k` of a cell is the edge opposite its local vertex `k`: local
edge 1 joins the cell's vertices 2 and 3, local edge 2 joins vertices 3 and
1, local edge 3 joins vertices 1 and 2. Global edges are numbered by first
appearance, scanning cells in index order and local edges 1, 2, 3 within a
cell, which makes the numbering a function of the cells table alone.

`cell_edge` is 3 by `ncells`: the global edge index of each cell's local
edge. `edge_cell` is 2 by `nedges`: the two cells sharing each edge, with
`edge_cell[1, e]` the cell that created edge `e` by first appearance and
`edge_cell[2, e]` the other one. `edge_neighbour` is 3 by `ncells`: the cell
across each local edge.

`vertex_neighbour` is 12 by `ncells`: every cell sharing at least one vertex
with a given cell, excluding the cell itself, which includes the three edge
neighbours too. From level 1 up every cell has twelve such neighbours except
the sixty cells touching one of the twelve base vertices, which have eleven;
on the base icosahedron itself every vertex is a base vertex and every cell
has nine. A missing slot is padded with the cell itself and `vertex_weight`
carries zero there and one everywhere else, so a kernel multiplies through
the padding instead of branching on it. Neighbours are ordered ascending by
cell index, with the padding last.
"""
struct Stencils
    cell_edge::Matrix{Int32}
    edge_cell::Matrix{Int32}
    edge_neighbour::Matrix{Int32}
    vertex_neighbour::Matrix{Int32}
    vertex_weight::Matrix{Int32}
end

"""
    edge_local_vertices(cells, i, k)

The pair of global vertex indices bounding cell `i`'s local edge `k`: edge 1
joins vertices 2 and 3, edge 2 joins vertices 3 and 1, edge 3 joins vertices
1 and 2, so edge `k` is opposite local vertex `k`.
"""
function edge_local_vertices(cells::AbstractMatrix{Int32}, i::Integer, k::Integer)
    k == 1 && return cells[2, i], cells[3, i]
    k == 2 && return cells[3, i], cells[1, i]
    return cells[1, i], cells[2, i]
end

"""
    build_edges(cells)

`cell_edge` and `edge_cell`, with global edges numbered by first appearance
scanning cells in index order and local edges 1, 2, 3 within a cell.
`edge_cell[1, e]` is the cell that created edge `e`, `edge_cell[2, e]` the
other cell sharing it.
"""
function build_edges(cells::Matrix{Int32})
    nc = size(cells, 2)
    cell_edge = Matrix{Int32}(undef, 3, nc)
    seen = Dict{Tuple{Int32,Int32},Int32}()
    first_cell = Int32[]
    second_cell = Int32[]
    for i in 1:nc
        for k in 1:3
            a, b = edge_local_vertices(cells, i, k)
            key = a < b ? (a, b) : (b, a)
            e = get(seen, key, Int32(0))
            if e == 0
                push!(first_cell, Int32(i))
                push!(second_cell, Int32(0))
                e = Int32(length(first_cell))
                seen[key] = e
            else
                second_cell[e] = Int32(i)
            end
            cell_edge[k, i] = e
        end
    end
    ne = length(first_cell)
    edge_cell = Matrix{Int32}(undef, 2, ne)
    edge_cell[1, :] .= first_cell
    edge_cell[2, :] .= second_cell
    return cell_edge, edge_cell
end

"""
    build_edge_neighbour(cell_edge, edge_cell)

`edge_neighbour`: the cell across each local edge, read off `edge_cell` for
the global edge `cell_edge` names at that local edge.
"""
function build_edge_neighbour(cell_edge::Matrix{Int32}, edge_cell::Matrix{Int32})
    nc = size(cell_edge, 2)
    edge_neighbour = Matrix{Int32}(undef, 3, nc)
    for i in 1:nc
        for k in 1:3
            e = cell_edge[k, i]
            a, b = edge_cell[1, e], edge_cell[2, e]
            edge_neighbour[k, i] = a == i ? b : a
        end
    end
    return edge_neighbour
end

"""
    build_vertex_neighbour(cells, nvertices)

`vertex_neighbour` and `vertex_weight`: every cell sharing at least one
vertex with a given cell, excluding the cell itself, ordered ascending by
cell index. A cell with fewer than twelve such neighbours is padded with
itself at the remaining slots, at zero weight.
"""
function build_vertex_neighbour(cells::Matrix{Int32}, nvertices::Integer)
    nc = size(cells, 2)
    stars = [Int32[] for _ in 1:nvertices]
    for i in 1:nc, k in 1:3
        push!(stars[cells[k, i]], Int32(i))
    end
    vertex_neighbour = Matrix{Int32}(undef, 12, nc)
    vertex_weight = Matrix{Int32}(undef, 12, nc)
    neighbours = Set{Int32}()
    for i in 1:nc
        empty!(neighbours)
        for k in 1:3, c in stars[cells[k, i]]
            c == i || push!(neighbours, c)
        end
        sorted = sort!(collect(neighbours))
        n = length(sorted)
        for j in 1:n
            vertex_neighbour[j, i] = sorted[j]
            vertex_weight[j, i] = 1
        end
        for j in (n + 1):12
            vertex_neighbour[j, i] = Int32(i)
            vertex_weight[j, i] = 0
        end
    end
    return vertex_neighbour, vertex_weight
end

"""
    stencils(level)

The `Stencils` of `level`, built from `level.cells` alone.
"""
function stencils(level::Level)::Stencils
    cell_edge, edge_cell = build_edges(level.cells)
    edge_neighbour = build_edge_neighbour(cell_edge, edge_cell)
    vertex_neighbour, vertex_weight = build_vertex_neighbour(level.cells, size(level.vertices, 2))
    return Stencils(cell_edge, edge_cell, edge_neighbour, vertex_neighbour, vertex_weight)
end
