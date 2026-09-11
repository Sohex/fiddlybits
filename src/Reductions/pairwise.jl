# Fixed-order pairwise summation: docs/plans/fiddlybits-52v.7-kernels.md,
# section "The reductions".

using ..Backends: Backend, CPU, backend_of, launch!, on
using ..Verdicts: refuse
using KernelAbstractions: @kernel, @index, @Const

"""
    BLOCKSIZE

The fixed, declared number of terms `pairwise_sum` accumulates per block
before the block sums are combined (decision 0038): a constant of this
module, never read from the thread count or a backend's workgroup size.
"""
const BLOCKSIZE = 256

@kernel function pairwise_block_kernel!(partials, @Const(xs), blocksize, n)
    i = @index(Global)
    lo = blocksize * i - blocksize + 1
    hi = min(i * blocksize, n)
    T = eltype(partials)
    acc = zero(T)
    for j in lo:hi
        acc += T(xs[j])
    end
    partials[i] = acc
end

"""
    pairwise_block_sums(::Type{A}, xs, backend; blocksize = BLOCKSIZE) where A

The `cld(length(xs), blocksize)` block sums of `xs`, accumulated in type
`A`: block `i` the fixed-order sum of `xs[(i-1)*blocksize+1:min(i*blocksize,
length(xs))]`, one block per launched work item, computed through
`Backends.launch!` on `backend`. `xs` must already live on `backend`.
Refuses when `blocksize` is not positive.
"""
function pairwise_block_sums(::Type{A}, xs::AbstractVector, backend::Backend;
                              blocksize::Integer = BLOCKSIZE) where {A<:Number}
    blocksize > 0 ||
        refuse("pairwise blocksize", "Reductions.pairwise_block_sums",
               "blocksize $blocksize is not positive")
    n = length(xs)
    nb = cld(n, blocksize)
    partials = similar(xs, A, nb)
    nb == 0 && return partials
    launch!(pairwise_block_kernel!, backend, nb, partials, xs, Int(blocksize), Int(n))
    return partials
end

"""
    combine_tree(v::AbstractVector{A}) where A

`v`'s entries added in a binary-tree order determined only by `length(v)`
(recursive halving of the index range), never by what computed each entry
or in what order those computations finished. `v` is read element by
element, so it must already live on the host; `combine_fixed_order` is the
door that checks that, and this function does not check it again on each
of its own recursive calls.
"""
function combine_tree(v::AbstractVector{A}) where {A<:Number}
    n = length(v)
    n == 0 && return zero(A)
    n == 1 && return v[1]
    mid = n ÷ 2
    return combine_tree(view(v, 1:mid)) + combine_tree(view(v, mid+1:n))
end

"""
    combine_fixed_order(v::AbstractVector{A}) where A

`v`'s entries added by `combine_tree`. Refuses, naming the backend, when
`v` does not live on the host (`Backends.backend_of`), rather than reading
device memory element by element. `pairwise_sum` moves the block sums to
the host through `Backends.on` before calling this.
"""
function combine_fixed_order(v::AbstractVector{A}) where {A<:Number}
    from = backend_of(v)
    from === :cpu ||
        refuse("combine operand backend", "Reductions.combine_fixed_order",
               "v lives on backend $from, not the host")
    return combine_tree(v)
end

"""
    pairwise_sum(::Type{A}, xs, backend = CPU(BLOCKSIZE); blocksize = BLOCKSIZE) where A

The fixed-order pairwise sum of `xs`, accumulated in type `A`: an explicit
argument rather than inferred from `eltype(xs)`. `xs` is split into blocks
of `blocksize` terms, each block's sum computed independently on
`backend`, and the block sums combined by `combine_fixed_order`. Never
atomic, never a library reduction (decision 0029): the result depends only
on `length(xs)`, `blocksize` and `A`, never on the thread count or how the
blocks were scheduled to workers.

The return is a host scalar, so the block sums are moved to the host on
every call, through `Backends.on` (decision 0011). On a device-resident
`xs` that is one `Events.moved` record per call, the device-move record of
decision 0010; it is not an event of decision 0042's journal vocabulary,
which carries no move kind. On a host-resident `xs` the move is a no-op
and records nothing.
"""
function pairwise_sum(::Type{A}, xs::AbstractVector, backend::Backend = CPU(BLOCKSIZE);
                       blocksize::Integer = BLOCKSIZE) where {A<:Number}
    partials = pairwise_block_sums(A, xs, backend; blocksize = blocksize)
    return combine_fixed_order(on(partials, CPU(1)))
end

"""
    pairwise_sum_reference(::Type{A}, xs) where A

The naive serial reference for `pairwise_sum` (decision 0027): `xs`
accumulated in type `A`, one term at a time in index order, with no
blocking of its own.
"""
function pairwise_sum_reference(::Type{A}, xs::AbstractVector) where {A<:Number}
    acc = zero(A)
    for x in xs
        acc += A(x)
    end
    return acc
end
