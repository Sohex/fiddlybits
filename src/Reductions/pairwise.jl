# Fixed-order pairwise summation: docs/plans/fiddlybits-52v.7-kernels.md,
# section "The reductions".

using ..Backends: Backend, CPU, GPU, backend_of, launch!, on
using ..Verdicts: refuse
using KernelAbstractions: @kernel, @index, @Const, @localmem, @synchronize

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
    block_width(::Val{B})

`B`, the block length a shared-memory block kernel was launched with, as a
constant its `@localmem` size is fixed by at compile time.
"""
block_width(::Val{B}) where {B} = B

@kernel function pairwise_block_shared_kernel!(partials, @Const(xs), width, nb, lastcount)
    block = @index(Group, Linear)
    lane = @index(Local, Linear)
    element = @index(Global, Linear)
    shared = @localmem eltype(xs) (block_width(width),)
    shared[lane] = xs[element]
    @synchronize
    if lane == 1
        T = eltype(partials)
        acc = zero(T)
        for j in 1:(block == nb ? lastcount : block_width(width))
            acc += T(shared[j])
        end
        partials[block] = acc
    end
end

"""
    launch_block_sums!(cpu_kernel, shared_kernel, backend, partials, n, blocksize, inputs...)

Queues the block sums of `n` elements into `partials` (length
`cld(n, blocksize)`) on `backend`. On `CPU`, `cpu_kernel` over one work
item per block, each reading its block of `inputs` from `(i-1)*blocksize+1`
itself. On `GPU`, `shared_kernel` over `n` work items at a workgroup of
`blocksize` (`at_workgroup`), one workgroup per block: every lane copies
its own element of `inputs` into the workgroup's shared memory, and after
the barrier lane 1 accumulates that shared copy in index order. The
accumulation order is the same on both; notes/findings/2026-09-13-block-sums-in-shared-memory.md
measures the two on the card. On `GPU` the workgroup is `blocksize`, so a
`blocksize` above the device's threads per block raises at the launch.
"""
function launch_block_sums!(cpu_kernel, shared_kernel, backend::CPU, partials, n::Integer,
                             blocksize::Integer, inputs...)
    launch!(cpu_kernel, backend, length(partials), partials, inputs..., Int(blocksize), Int(n))
    return partials
end

function launch_block_sums!(cpu_kernel, shared_kernel, backend::GPU, partials, n::Integer,
                             blocksize::Integer, inputs...)
    nb = length(partials)
    lastcount = mod1(n, blocksize)
    launch!(shared_kernel, at_workgroup(backend, blocksize), n,
            partials, inputs..., Val(Int(blocksize)), Int(nb), Int(lastcount))
    return partials
end

"""
    pairwise_block_sums(::Type{A}, xs, backend; blocksize = BLOCKSIZE) where A

The `cld(length(xs), blocksize)` block sums of `xs`, accumulated in type
`A`: block `i` the fixed-order sum of `xs[(i-1)*blocksize+1:min(i*blocksize,
length(xs))]`, computed through `Backends.launch!` on `backend` by
`launch_block_sums!`: one work item per block on `CPU`, one workgroup per
block on `GPU`. `xs` must already live on `backend`. Refuses when
`blocksize` is not positive.
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
    return launch_block_sums!(pairwise_block_kernel!, pairwise_block_shared_kernel!, backend,
                              partials, n, blocksize, xs)
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

A device-scalar form beside this one, walking the same fixed-order tree on
the device and returning a one-element device array, was built and measured
in notes/findings/2026-09-11-device-scalar-reduction-contract.md.
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
