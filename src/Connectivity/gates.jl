# The connections between adjacent coarse cells. The ocean gate is read at the control
# section of the connection: Whitehead 1998, Reviews of Geophysics 36, 423-440, DOI
# 10.1029/98RG01014, p. 423 (flow between neighbouring deep basins over the saddle
# point), p. 424 (the sill depth of the deepest passage draining a basin), p. 426
# (the lip of a rectangular exit channel, eqs. 7-11) and p. 427 (the flux through a
# rectangular opening of width L with upstream height above sill depth, eqs. 12-13).
# The sill is found by the flood of Barnes, Lehman and Mulla 2014, Algorithm 1 (p. 119).

using ..Reductions: compensated_sum

"""
    OceanGate

The ocean connection between the two coarse cells sharing coarse edge `edge`, `cells`
in the coarse `edge_cell` order.

Each coarse cell's ocean body is its world-ocean terrain cell of least elevation, the
lowest cell index among equals. A connection path is a sequence of world-ocean terrain
cells of the two coarse cells, each an edge neighbour of the one before, from the body
of `cells[1]` to the body of `cells[2]`. The crest is the least, over connection paths,
of the greatest elevation along the path, and `sill_depth` is the datum less the crest.
A gate exists only where a connection path does.

The horizon is the set of world-ocean terrain cells of the two coarse cells at or below
the crest. A crest edge is a terrain edge joining two horizon cells, at least one of
them at the crest. `section` is the terrain edges, ascending, of the set of crest edges
of least total primal edge length whose removal leaves no path through the horizon
between the two bodies, taken as the one whose side reachable from the body of
`cells[1]` is least. `width` is the sum of the primal lengths of `section` at the
support's radius, accumulated in ascending edge order.
"""
struct OceanGate
    edge::Int32
    cells::NTuple{2,Int32}
    sill_depth::Float64
    width::Float64
    section::Vector{Int32}
end

"""
    LandGate

The land contiguity between the two coarse cells sharing coarse edge `edge`, `cells` in
the coarse `edge_cell` order.

Each coarse cell's land body is its component of non-ocean terrain cells, joined through
edge neighbours within the coarse cell, of greatest area, the one holding the lowest
cell index among equals. A gate exists only where the two land bodies are joined through
non-ocean terrain cells of the two coarse cells. A joined crossing is a terrain edge on
the coarse edge whose two cells are both in that joined set, and `crossings` counts them.
`width` is the sum of their primal lengths at the support's radius, accumulated in
ascending edge order.
"""
struct LandGate
    edge::Int32
    cells::NTuple{2,Int32}
    width::Float64
    crossings::Int
end

"""
    crossings(ocean, terrain, coarse, site)

`(wet, dry)`: every terrain edge lying on a coarse edge, as `(coarse edge, terrain
edge)`, split into those with an ocean cell on both sides and those with a non-ocean
cell on both sides, each sorted by coarse edge and then terrain edge. An edge with one
ocean side is in neither.
"""
function crossings(ocean::BitVector, terrain::LevelMesh, coarse::LevelMesh, site::AbstractString)
    depth = terrain.index - coarse.index
    st = terrain.stencils
    wet = Tuple{Int32,Int32}[]
    dry = Tuple{Int32,Int32}[]
    for e in axes(st.edge_cell, 2)
        i = Int(st.edge_cell[1, e])
        j = Int(st.edge_cell[2, e])
        a = coarse_cell(i, depth)
        b = coarse_cell(j, depth)
        a == b && continue
        if ocean[i] && ocean[j]
            push!(wet, (coarse_edge_between(coarse.stencils, a, b, site), Int32(e)))
        elseif !ocean[i] && !ocean[j]
            push!(dry, (coarse_edge_between(coarse.stencils, a, b, site), Int32(e)))
        end
    end
    return sort!(wet), sort!(dry)
end

"""
    edge_runs(pairs)

The index ranges of `pairs` holding one coarse edge each, in order.
"""
function edge_runs(pairs::Vector{Tuple{Int32,Int32}})
    runs = UnitRange{Int}[]
    start = 1
    for k in 2:(length(pairs) + 1)
        if k > length(pairs) || first(pairs[k]) != first(pairs[start])
            push!(runs, start:(k - 1))
            start = k
        end
    end
    return runs
end

"""
    PairRegion

The terrain cells of two coarse cells: `first` and `second` are their contiguous index
ranges, and `cells` both, ascending.
"""
struct PairRegion
    first::UnitRange{Int}
    second::UnitRange{Int}
    cells::Vector{Int}
end

function PairRegion(a::Integer, b::Integer, depth::Integer)
    ra = Mesh.descendants(a, depth)
    rb = Mesh.descendants(b, depth)
    return PairRegion(ra, rb, sort!(vcat(collect(ra), collect(rb))))
end

"Whether terrain cell `i` lies in `region`."
inside(region::PairRegion, i::Integer) = i in region.first || i in region.second

"""
    ocean_body(elevation, ocean, range)

The world-ocean cell of `range` of least elevation, the lowest index among equals, or
`nothing` when `range` holds no ocean.
"""
function ocean_body(elevation::Vector{Float64}, ocean::BitVector, range::UnitRange{Int})
    body = nothing
    for i in range
        ocean[i] || continue
        (body === nothing || elevation[i] < elevation[body]) && (body = i)
    end
    return body
end

"""
    crest(elevation, ocean, stencils, region, source, sink)

The least, over paths of world-ocean cells of `region` from `source` to `sink`, of the
greatest elevation along the path, or `nothing` when no path exists. Every cell reached
is pushed at the greater of its own elevation and the popped priority and closed when
pushed, so the priority it is pushed at is its value.
"""
function crest(elevation::Vector{Float64}, ocean::BitVector, stencils::Mesh.Stencils,
               region::PairRegion, source::Int, sink::Int)
    reached = Set{Int}(source)
    queue = FloodQueue()
    order = 1
    push_flood!(queue, (elevation[source], order, Int32(source)))
    while !isempty(queue.entries)
        priority, _, c = pop_flood!(queue)
        c == sink && return priority
        for k in 1:3
            j = Int(stencils.edge_neighbour[k, c])
            (ocean[j] && inside(region, j) && !(j in reached)) || continue
            push!(reached, j)
            order += 1
            push_flood!(queue, (max(elevation[j], priority), order, Int32(j)))
        end
    end
    return nothing
end

"""
    horizon_nodes(elevation, ocean, stencils, region, level)

The flow network's nodes over the horizon at `level`: a map from each world-ocean cell
of `region` at or below `level` to a node, where every set of cells strictly below
`level` joined through edge neighbours strictly below it shares one node and every cell
at `level` has its own, numbered in ascending order of each node's lowest cell; and the
node count.
"""
function horizon_nodes(elevation::Vector{Float64}, ocean::BitVector, stencils::Mesh.Stencils,
                       region::PairRegion, level::Float64)
    node = Dict{Int,Int}()
    count = 0
    queue = Int[]
    for c in region.cells
        (ocean[c] && elevation[c] <= level && !haskey(node, c)) || continue
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
                (ocean[j] && inside(region, j) && elevation[j] < level && !haskey(node, j)) || continue
                node[j] = count
                push!(queue, j)
            end
        end
    end
    return node, count
end

"""
    control_section(elevation, ocean, terrain, region, source, sink, level, radius)

`(section, width)` of the `OceanGate` between the bodies `source` and `sink` whose crest
is `level`. Every crest edge is a pair of arcs of capacity its primal length at `radius`
between the nodes of `horizon_nodes`, built in ascending order of cell and local edge.
Augmenting paths are found breadth first from the source node in that order until none
remains; the section is the crest edges joining a node reachable from the source node
through arcs of positive residual capacity to one that is not.
"""
function control_section(elevation::Vector{Float64}, ocean::BitVector, terrain::LevelMesh,
                         region::PairRegion, source::Int, sink::Int, level::Float64,
                         radius::Float64)
    st = terrain.stencils
    lengths = terrain.geometry.primal_edge_length
    node, count = horizon_nodes(elevation, ocean, st, region, level)
    head = Int[]
    residual = Float64[]
    edge_of = Int32[]
    arcs = [Int[] for _ in 1:count]
    for c in region.cells, k in 1:3
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
    land_body(ocean, terrain, range, radius)

The cells of the land body of the coarse cell whose terrain cells are `range`, as a
set, or `nothing` when it holds no land.
"""
function land_body(ocean::BitVector, terrain::LevelMesh, range::UnitRange{Int}, radius::Float64)
    st = terrain.stencils
    area = terrain.geometry.cell_area
    seen = Set{Int}()
    best = nothing
    best_area = zero(Float64)
    for c in range
        (ocean[c] || c in seen) && continue
        members = [c]
        push!(seen, c)
        head = 1
        while head <= length(members)
            i = members[head]
            head += 1
            for k in 1:3
                j = Int(st.edge_neighbour[k, i])
                (j in range && !ocean[j] && !(j in seen)) || continue
                push!(seen, j)
                push!(members, j)
            end
        end
        total = compensated_sum(Float64[Mesh.at_radius(area[i], radius, 2) for i in sort!(members)])
        if best === nothing || total > best_area
            best = Set(members)
            best_area = total
        end
    end
    return best
end

"""
    joined_land(ocean, stencils, region, body)

The non-ocean cells of `region` joined to the cells of `body` through edge neighbours
that are non-ocean cells of `region`.
"""
function joined_land(ocean::BitVector, stencils::Mesh.Stencils, region::PairRegion, body::Set{Int})
    joined = copy(body)
    queue = sort!(collect(body))
    head = 1
    while head <= length(queue)
        i = queue[head]
        head += 1
        for k in 1:3
            j = Int(stencils.edge_neighbour[k, i])
            (!ocean[j] && inside(region, j) && !(j in joined)) || continue
            push!(joined, j)
            push!(queue, j)
        end
    end
    return joined
end

"""
    gates(elevation, datum, ocean, terrain, coarse, radius, site)

`(ocean_gates, land_gates)`: one `OceanGate` for every coarse edge carrying a wet
crossing whose two coarse cells' ocean bodies are joined by a connection path, and one
`LandGate` for every coarse edge carrying a dry crossing whose two coarse cells' land
bodies are joined, each sorted by coarse edge.
"""
function gates(elevation::Vector{Float64}, datum::Float64, ocean::BitVector,
               terrain::LevelMesh, coarse::LevelMesh, radius::Float64, site::AbstractString)
    depth = terrain.index - coarse.index
    wet, dry = crossings(ocean, terrain, coarse, site)
    lengths = terrain.geometry.primal_edge_length
    cells_of(edge) = (coarse.stencils.edge_cell[1, edge], coarse.stencils.edge_cell[2, edge])

    ocean_gates = OceanGate[]
    for run in edge_runs(wet)
        edge = first(wet[first(run)])
        a, b = cells_of(edge)
        region = PairRegion(a, b, depth)
        source = something(ocean_body(elevation, ocean, region.first))
        sink = something(ocean_body(elevation, ocean, region.second))
        level = crest(elevation, ocean, terrain.stencils, region, source, sink)
        level === nothing && continue
        section, width = control_section(elevation, ocean, terrain, region, source, sink,
                                         level, radius)
        push!(ocean_gates, OceanGate(edge, (a, b), datum - level, width, section))
    end

    land_gates = LandGate[]
    bodies = Dict{Int32,Union{Nothing,Set{Int}}}()
    body_of(c) = get!(() -> land_body(ocean, terrain, Mesh.descendants(c, depth), radius), bodies, c)
    for run in edge_runs(dry)
        edge = first(dry[first(run)])
        a, b = cells_of(edge)
        body_a = something(body_of(a))
        body_b = something(body_of(b))
        region = PairRegion(a, b, depth)
        joined = joined_land(ocean, terrain.stencils, region, body_a)
        first(body_b) in joined || continue
        section = Int32[last(dry[k]) for k in run
                        if Int(terrain.stencils.edge_cell[1, last(dry[k])]) in joined]
        width = compensated_sum(Float64[Mesh.at_radius(lengths[e], radius, 1) for e in section])
        push!(land_gates, LandGate(edge, (a, b), width, length(section)))
    end
    return ocean_gates, land_gates
end
