using KernelAbstractions

# The clean fixture test/mesh/stencil_valence.jl must pass: it reaches its
# cell's three edge neighbours through the edge_neighbour stencil table and
# names no other mesh geometry.

"""
    neighbour_sum_kernel!(out, values, edge_neighbour)

`out[i]` is the sum of `values` at cell `i`'s three edge neighbours, read
through the `edge_neighbour` stencil table.
"""
@kernel function neighbour_sum_kernel!(out, @Const(values), @Const(edge_neighbour))
    i = @index(Global)
    total = zero(eltype(out))
    for k in 1:3
        total += values[edge_neighbour[k, i]]
    end
    out[i] = total
end
