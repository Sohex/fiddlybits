# The drainage terminal of every terrain cell, by a labelled priority flood from the
# world ocean and from every minimum plateau: Barnes, Lehman and Mulla 2014,
# Computers & Geosciences 62, 117-127, DOI 10.1016/j.cageo.2013.04.024. Algorithm 1
# (p. 119) is the flood; section 7.3 and Algorithm 5 (pp. 125-126) carry a label with
# it; section 4 (p. 121) is the total order; section 3.1 (p. 119) states the seeding
# from every local minimum after Beucher and Meyer 1992.

"""
    WorldOcean

The terminal of a cell that drains to the world ocean. `WORLD_OCEAN` is its one value.
"""
struct WorldOcean end

"The terminal of a cell that drains to the world ocean."
const WORLD_OCEAN = WorldOcean()

"""
    Terminal

Where a cell drains: `WORLD_OCEAN`, or the closed basin named by the lowest cell index
of its minimum plateau, as an `Int32`.
"""
const Terminal = Union{WorldOcean,Int32}

"""
    FloodQueue

A binary min-heap of `(priority, order, cell)` entries, compared lexicographically, so
entries of equal priority leave in the order they were pushed.
"""
struct FloodQueue
    entries::Vector{Tuple{Float64,Int,Int32}}
end

FloodQueue() = FloodQueue(Tuple{Float64,Int,Int32}[])

"""
    push_flood!(queue, entry)

Push `entry` onto `queue`.
"""
function push_flood!(queue::FloodQueue, entry::Tuple{Float64,Int,Int32})
    e = queue.entries
    push!(e, entry)
    i = length(e)
    while i > 1
        p = i >> 1
        isless(e[i], e[p]) || break
        e[i], e[p] = e[p], e[i]
        i = p
    end
    return queue
end

"""
    pop_flood!(queue)

Remove and return the least entry of `queue`.
"""
function pop_flood!(queue::FloodQueue)
    e = queue.entries
    top = e[1]
    last_entry = pop!(e)
    n = length(e)
    n == 0 && return top
    e[1] = last_entry
    i = 1
    while true
        left = i + i
        right = left + 1
        least = i
        left <= n && isless(e[left], e[least]) && (least = left)
        right <= n && isless(e[right], e[least]) && (least = right)
        least == i && break
        e[i], e[least] = e[least], e[i]
        i = least
    end
    return top
end

"""
    minimum_plateaus(elevation, ocean, stencils)

For each non-ocean cell, the lowest cell index of its minimum plateau, or zero when it
lies on none. A plateau is a set of non-ocean cells of exactly equal elevation joined
through edge neighbours; it is a minimum when no cell of it has an edge neighbour, of
any class, lying strictly lower.
"""
function minimum_plateaus(elevation::Vector{Float64}, ocean::BitVector, stencils::Mesh.Stencils)
    n = length(elevation)
    plateau = zeros(Int32, n)
    visited = falses(n)
    members = Vector{Int}(undef, n)
    for start in 1:n
        (ocean[start] || visited[start]) && continue
        visited[start] = true
        members[1] = start
        head = 1
        tail = 1
        lowest = true
        while head <= tail
            i = members[head]
            head += 1
            for k in 1:3
                j = Int(stencils.edge_neighbour[k, i])
                elevation[j] < elevation[i] && (lowest = false)
                (ocean[j] || visited[j] || elevation[j] != elevation[i]) && continue
                visited[j] = true
                tail += 1
                members[tail] = j
            end
        end
        if lowest
            for m in 1:tail
                plateau[members[m]] = Int32(start)
            end
        end
    end
    return plateau
end

"""
    drainage_terminals(elevation, ocean, stencils)

The `Terminal` of every cell. Every ocean cell is seeded with `WORLD_OCEAN` and every
cell of a minimum plateau with that plateau's label, in ascending cell order, each at
its own elevation. The least entry is popped, and each edge neighbour not yet reached
takes the popped cell's terminal and is pushed at the greater of its own elevation and
the popped priority. Entries of equal priority leave in push order.
"""
function drainage_terminals(elevation::Vector{Float64}, ocean::BitVector, stencils::Mesh.Stencils)
    n = length(elevation)
    plateau = minimum_plateaus(elevation, ocean, stencils)
    terminal = Vector{Terminal}(undef, n)
    reached = falses(n)
    queue = FloodQueue()
    order = 0
    for i in 1:n
        if ocean[i]
            terminal[i] = WORLD_OCEAN
        elseif plateau[i] != 0
            terminal[i] = plateau[i]
        else
            continue
        end
        reached[i] = true
        order += 1
        push_flood!(queue, (elevation[i], order, Int32(i)))
    end
    while !isempty(queue.entries)
        priority, _, c = pop_flood!(queue)
        for k in 1:3
            j = Int(stencils.edge_neighbour[k, c])
            reached[j] && continue
            reached[j] = true
            terminal[j] = terminal[c]
            order += 1
            push_flood!(queue, (max(elevation[j], priority), order, Int32(j)))
        end
    end
    return terminal
end
