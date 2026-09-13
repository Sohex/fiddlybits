# The bodies of each coarse cell and the connections between bodies of adjacent coarse
# cells. The ocean gate is read at the control section of the connection: Whitehead
# 1998, Reviews of Geophysics 36, 423-440, DOI 10.1029/98RG01014, p. 423 (flow between
# neighbouring deep basins over the saddle point), p. 424 (the sill depth of the deepest
# passage draining a basin), p. 426 (the lip of a rectangular exit channel, eqs. 7-11)
# and p. 427 (the flux through a rectangular opening of width L with upstream height
# above sill depth, eqs. 12-13). The sill is found by the flood of Barnes, Lehman and
# Mulla 2014, Algorithm 1 (p. 119). One gate is kept per pair of bodies meeting across a
# coarse edge, as one outlet is kept per pair of depressions that meet in Barnes,
# Callaghan and Wickert 2020, Earth Surface Dynamics 8, 431-445, DOI
# 10.5194/esurf-8-431-2020, section 3.3 (p. 438). The representation is decision 0031,
# amendment of 2026-09-13.

using ..Reductions: compensated_sum

"""
    Body

The body of a terrain cell: `nothing` on a cell of no body, and otherwise the body's
label, the lowest memory index at the terrain level of the cells it holds.
"""
const Body = Union{Nothing,Int32}

"""
    OceanGate

The ocean connection across coarse edge `edge` between ocean body `bodies[1]` of coarse
cell `cells[1]` and ocean body `bodies[2]` of coarse cell `cells[2]`, `cells` in the
coarse `edge_cell` order. A gate exists for every such pair of bodies joined by a
terrain edge lying on `edge`.

Each body's source cell is its cell of least elevation, the lowest cell index among
equals. A connection path is a sequence of cells of the two bodies, each an edge
neighbour of the one before, from the source cell of `bodies[1]` to that of
`bodies[2]`. The crest is the least, over connection paths, of the greatest elevation
along the path, and `sill_depth` is the datum less the crest.

The horizon is the set of cells of the two bodies at or below the crest. A crest edge is
a terrain edge joining two horizon cells, at least one of them at the crest. `section`
is the terrain edges, ascending, of the set of crest edges of least total primal edge
length whose removal leaves no path through the horizon between the two source cells,
taken as the one whose side reachable from the source cell of `bodies[1]` is least.
`width` is the sum of the primal lengths of `section` at the support's radius,
accumulated in ascending edge order.
"""
struct OceanGate
    edge::Int32
    cells::NTuple{2,Int32}
    bodies::NTuple{2,Int32}
    sill_depth::Float64
    width::Float64
    section::Vector{Int32}
end

"""
    LandGate

The land contiguity across coarse edge `edge` between land body `bodies[1]` of coarse
cell `cells[1]` and land body `bodies[2]` of coarse cell `cells[2]`, `cells` in the
coarse `edge_cell` order. A gate exists for every such pair of bodies joined by a
terrain edge lying on `edge`; `crossings` counts those terrain edges, and `width` is the
sum of their primal lengths at the support's radius, accumulated in ascending edge
order.
"""
struct LandGate
    edge::Int32
    cells::NTuple{2,Int32}
    bodies::NTuple{2,Int32}
    width::Float64
    crossings::Int
end

"""
    coarse_bodies(mask, stencils, depth)

The `Body` of each terrain cell: `nothing` where `mask` does not hold, and elsewhere the
lowest cell index of the set of cells where `mask` holds joined to it through edge
neighbours lying in the same cell `depth` levels coarser.
"""
function coarse_bodies(mask::BitVector, stencils::Mesh.Stencils, depth::Integer)
    n = length(mask)
    body = Vector{Body}(nothing, n)
    queue = Vector{Int}(undef, n)
    for start in 1:n
        (mask[start] && body[start] === nothing) || continue
        label = Int32(start)
        owner = coarse_cell(start, depth)
        body[start] = label
        queue[1] = start
        head = 1
        tail = 1
        while head <= tail
            i = queue[head]
            head += 1
            for k in 1:3
                j = Int(stencils.edge_neighbour[k, i])
                (mask[j] && body[j] === nothing && coarse_cell(j, depth) == owner) || continue
                body[j] = label
                tail += 1
                queue[tail] = j
            end
        end
    end
    return body
end

"""
    coarse_cell_bodies(ocean, depth)

The positive control of the connectivity bodies suite: the `Body` of each terrain cell
with every ocean cell labelled by the first terrain cell of its coarse cell `depth`
levels coarser, so each coarse cell holds one ocean body whatever joins its cells.
"""
function coarse_cell_bodies(ocean::BitVector, depth::Integer)
    body = Vector{Body}(nothing, length(ocean))
    for i in eachindex(ocean)
        ocean[i] && (body[i] = Int32(first(Mesh.descendants(coarse_cell(i, depth), depth))))
    end
    return body
end

"""
    body_members(body)

A map from each label of `body` to its cells, ascending.
"""
function body_members(body::Vector{Body})
    members = Dict{Int32,Vector{Int}}()
    for i in eachindex(body)
        label = body[i]
        label === nothing || push!(get!(Vector{Int}, members, label), i)
    end
    return members
end

"""
    crossings(mask, body, terrain, coarse, site)

Every terrain edge lying on a coarse edge whose two cells both hold `mask`, as `(coarse
edge, body of the cell in the coarse edge's first cell, body of the cell in its second
cell, terrain edge)`, sorted.
"""
function crossings(mask::BitVector, body::Vector{Body}, terrain::LevelMesh, coarse::LevelMesh,
                   site::AbstractString)
    depth = terrain.index - coarse.index
    st = terrain.stencils
    cst = coarse.stencils
    found = NTuple{4,Int32}[]
    for e in axes(st.edge_cell, 2)
        i = Int(st.edge_cell[1, e])
        j = Int(st.edge_cell[2, e])
        (mask[i] && mask[j]) || continue
        a = coarse_cell(i, depth)
        b = coarse_cell(j, depth)
        a == b && continue
        edge = coarse_edge_between(cst, a, b, site)
        inner, outer = cst.edge_cell[1, edge] == a ? (i, j) : (j, i)
        push!(found, (edge, something(body[inner]), something(body[outer]), Int32(e)))
    end
    return sort!(found)
end

"""
    connection_runs(found)

The index ranges of `found`, as `crossings` returns it, holding one coarse edge and one
pair of bodies each, in order.
"""
function connection_runs(found::Vector{NTuple{4,Int32}})
    runs = UnitRange{Int}[]
    start = 1
    for k in 2:(length(found) + 1)
        if k > length(found) || found[k][1:3] != found[start][1:3]
            push!(runs, start:(k - 1))
            start = k
        end
    end
    return runs
end

"""
    BodyPair

The terrain cells of two bodies: `labels` the two labels, `body` the `Body` of every
terrain cell they are read from, and `cells` the cells of both, ascending.
"""
struct BodyPair
    labels::NTuple{2,Int32}
    body::Vector{Body}
    cells::Vector{Int}
end

"Whether terrain cell `i` lies in either body of `pair`."
function inside(pair::BodyPair, i::Integer)
    label = pair.body[i]
    return label !== nothing && (label == pair.labels[1] || label == pair.labels[2])
end

"""
    source_cell(elevation, cells)

The cell of `cells`, ascending, of least elevation, the first among equals.
"""
function source_cell(elevation::Vector{Float64}, cells::Vector{Int})
    source = first(cells)
    for i in cells
        elevation[i] < elevation[source] && (source = i)
    end
    return source
end

"""
    crest(elevation, stencils, pair, source, sink)

The least, over paths of cells of `pair` from `source` to `sink`, of the greatest
elevation along the path, or `nothing` when no path exists. Every cell reached is pushed
at the greater of its own elevation and the popped priority and closed when pushed, so
the priority it is pushed at is its value.
"""
function crest(elevation::Vector{Float64}, stencils::Mesh.Stencils, pair::BodyPair,
               source::Int, sink::Int)
    reached = Set{Int}(source)
    queue = FloodQueue()
    order = 1
    push_flood!(queue, (elevation[source], order, Int32(source)))
    while !isempty(queue.entries)
        priority, _, c = pop_flood!(queue)
        c == sink && return priority
        for k in 1:3
            j = Int(stencils.edge_neighbour[k, c])
            (inside(pair, j) && !(j in reached)) || continue
            push!(reached, j)
            order += 1
            push_flood!(queue, (max(elevation[j], priority), order, Int32(j)))
        end
    end
    return nothing
end

"""
    horizon_nodes(elevation, stencils, pair, level)

The flow network's nodes over the horizon at `level`: a map from each cell of `pair` at
or below `level` to a node, where every set of cells strictly below `level` joined
through edge neighbours strictly below it shares one node and every cell at `level` has
its own, numbered in ascending order of each node's lowest cell; and the node count.
"""
function horizon_nodes(elevation::Vector{Float64}, stencils::Mesh.Stencils, pair::BodyPair,
                       level::Float64)
    node = Dict{Int,Int}()
    count = 0
    queue = Int[]
    for c in pair.cells
        (elevation[c] <= level && !haskey(node, c)) || continue
        count += 1
        node[c] = count
        elevation[c] < level || continue
        empty!(queue)
        push!(queue, c)
        head = 1
        while head <= length(queue)
            i = queue[head]
            head += 1
            for k in 1:3
                j = Int(stencils.edge_neighbour[k, i])
                (inside(pair, j) && elevation[j] < level && !haskey(node, j)) || continue
                node[j] = count
                push!(queue, j)
            end
        end
    end
    return node, count
end

"""
    control_section(elevation, terrain, pair, source, sink, level, radius)

`(section, width)` of the `OceanGate` between the source cells `source` and `sink` of
`pair` whose crest is `level`. Every crest edge is a pair of arcs of capacity its primal
length at `radius` between the nodes of `horizon_nodes`, built in ascending order of cell
and local edge. Augmenting paths are found breadth first from the source node in that
order until none remains; the section is the crest edges joining a node reachable from
the source node through arcs of positive residual capacity to one that is not.
"""
function control_section(elevation::Vector{Float64}, terrain::LevelMesh, pair::BodyPair,
                         source::Int, sink::Int, level::Float64, radius::Float64)
    st = terrain.stencils
    lengths = terrain.geometry.primal_edge_length
    node, count = horizon_nodes(elevation, st, pair, level)
    head = Int[]
    residual = Float64[]
    edge_of = Int32[]
    arcs = [Int[] for _ in 1:count]
    for c in pair.cells, k in 1:3
        haskey(node, c) || continue
        j = Int(st.edge_neighbour[k, c])
        (j > c && haskey(node, j) && max(elevation[c], elevation[j]) == level) || continue
        capacity = Mesh.at_radius(lengths[st.cell_edge[k, c]], radius, 1)
        push!(head, node[j], node[c])
        push!(residual, capacity, capacity)
        push!(edge_of, st.cell_edge[k, c])
        push!(arcs[node[c]], length(head) - 1)
        push!(arcs[node[j]], length(head))
    end
    partner(arc) = isodd(arc) ? arc + 1 : arc - 1
    s = node[source]
    t = node[sink]
    through = zeros(Int, count)
    reachable = falses(count)
    queue = Int[]
    while true
        fill!(through, 0)
        fill!(reachable, false)
        reachable[s] = true
        empty!(queue)
        push!(queue, s)
        front = 1
        while front <= length(queue) && !reachable[t]
            u = queue[front]
            front += 1
            for arc in arcs[u]
                v = head[arc]
                (residual[arc] > 0 && !reachable[v]) || continue
                reachable[v] = true
                through[v] = arc
                push!(queue, v)
            end
        end
        reachable[t] || break
        bottleneck = Inf
        v = t
        while v != s
            bottleneck = min(bottleneck, residual[through[v]])
            v = head[partner(through[v])]
        end
        v = t
        while v != s
            residual[through[v]] -= bottleneck
            residual[partner(through[v])] += bottleneck
            v = head[partner(through[v])]
        end
    end
    section = sort!(Int32[edge_of[m] for m in eachindex(edge_of)
                          if reachable[head[m + m]] != reachable[head[m + m - 1]]])
    width = compensated_sum(Float64[Mesh.at_radius(lengths[e], radius, 1) for e in section])
    return section, width
end

"""
    gates(elevation, datum, ocean, ocean_body, land_body, terrain, coarse, radius, site)

`(ocean_gates, land_gates)`: one `OceanGate` for every pair of bodies of `ocean_body`
joined by a terrain edge on a coarse edge, where a connection path joins their source
cells, and one `LandGate` for every pair of bodies of `land_body` joined by a terrain
edge on a coarse edge, each sorted by coarse edge and then by the pair of bodies.
"""
function gates(elevation::Vector{Float64}, datum::Float64, ocean::BitVector,
               ocean_body::Vector{Body}, land_body::Vector{Body}, terrain::LevelMesh,
               coarse::LevelMesh, radius::Float64, site::AbstractString)
    lengths = terrain.geometry.primal_edge_length
    cells_of(edge) = (coarse.stencils.edge_cell[1, edge], coarse.stencils.edge_cell[2, edge])

    ocean_gates = OceanGate[]
    members = body_members(ocean_body)
    wet = crossings(ocean, ocean_body, terrain, coarse, site)
    for run in connection_runs(wet)
        edge, p, q, _ = wet[first(run)]
        pair = BodyPair((p, q), ocean_body, sort!(vcat(members[p], members[q])))
        source = source_cell(elevation, members[p])
        sink = source_cell(elevation, members[q])
        level = crest(elevation, terrain.stencils, pair, source, sink)
        level === nothing && continue
        section, width = control_section(elevation, terrain, pair, source, sink, level, radius)
        push!(ocean_gates, OceanGate(edge, cells_of(edge), (p, q), datum - level, width, section))
    end

    land_gates = LandGate[]
    dry = crossings(.!ocean, land_body, terrain, coarse, site)
    for run in connection_runs(dry)
        edge, p, q, _ = dry[first(run)]
        section = Int32[dry[k][4] for k in run]
        width = compensated_sum(Float64[Mesh.at_radius(lengths[e], radius, 1) for e in section])
        push!(land_gates, LandGate(edge, cells_of(edge), (p, q), width, length(section)))
    end
    return ocean_gates, land_gates
end
