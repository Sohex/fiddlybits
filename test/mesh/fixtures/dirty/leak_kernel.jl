using KernelAbstractions

# The dirty fixture test/mesh/stencil_valence.jl must flag: it reaches for a
# vertex coordinate directly instead of a stencil table. The values[end]
# indexing ahead of the leak is the control on the block scanner: an end
# counted as a block close would truncate the span before the leaking line.

"""
    neighbour_sum_kernel!(out, values, cells, vertices)

`out[i]` is the sum of `values` at cell `i`'s three edge neighbours, found by
indexing the raw `cells` and `vertices` arrays instead of a stencil table.
"""
@kernel function neighbour_sum_kernel!(out, @Const(values), @Const(cells), @Const(vertices))
    i = @index(Global)
    total = values[end] - values[end]
    for k in 1:3
        v = vertices[:, cells[k, i]]
        total += v[1]
    end
    out[i] = total
end
