# Fixed-order pairwise summation: docs/plans/fiddlybits-52v.7-kernels.md,
# section "The reductions".

using ..Backends: Backend, CPU, GPU, at_workgroup, backend_of, launch!, on
using ..Verdicts: refuse
using KernelAbstractions: @kernel, @index, @Const, @localmem, @synchronize

"""
    BLOCKSIZE

The fixed, declared number of terms `pairwise_sum` accumulates per block
before the block sums are combined (decision 0038): a constant of this
module, never read from the thread count or a launch's workgroup size.
"""
const BLOCKSIZE = 256

@kernel function pairwise_block_kernel!(partials, @Const(xs), blocksize, n)
    i = @index(Global)
    lo = blocksize * i - blocksize + 1
    hi = min(i * blocksize, n)
    T = eltype(partials)
    acc = zero(T)
    @inbounds for j in lo:hi
        acc += T(xs[j])
    end
    @inbounds partials[i] = acc
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
    @inbounds shared[lane] = xs[element]
    @synchronize
    if lane == 1
        T = eltype(partials)
        acc = zero(T)
        @inbounds for j in 1:(block == nb ? lastcount : block_width(width))
            acc += T(shared[j])
        end
        @inbounds partials[block] = acc
    end
end

"""
    launch_block_sums!(cpu_kernel, shared_kernel, backend, partials, n, blocksize, columns, inputs)

Queues the block sums of `n` elements into `partials` on `backend`, with the
values of the named tuple `inputs` as the kernel's arguments after
`partials`, in order. `partials` holds one row per block and `columns`
accumulators per row, as `area_fraction_block_sums` carries two.

Before the launch, on the host, refuses through `Verdicts.refuse`, naming
the array and both lengths, unless `blocksize` is positive, `partials` is
`cld(n, blocksize)` rows by `columns` columns, and every array among
`inputs` holds `n` elements: the lengths every index either kernel reads or
writes is derived from.

On `CPU`, `cpu_kernel` over one work item per block, each reading its block
of `inputs` from `(i-1)*blocksize+1` itself, at `Backends.launch_workgroup`.
On `GPU`, when `n` is at most `device_form_limit(shared_kernel)`,
`shared_kernel` over `n` work items pinned to a workgroup of `blocksize`
(`Backends.at_workgroup`), one workgroup per block: every lane copies its own
element of `inputs` into the workgroup's shared memory, and after the barrier
lane 1 accumulates that shared copy in index order; above that limit,
`cpu_kernel` as on `CPU`, at `Backends.launch_workgroup`.
The GPU kernel is a device form under
docs/decisions/0051-a-kernel-may-carry-a-device-form-beside-its-portable-one.md;
notes/findings/2026-09-13-block-sums-in-shared-memory.md measures the two on
the card with bounds checks,
notes/findings/2026-09-13-the-block-sum-device-forms-against-one-inbounds-text.md
with the reads under `@inbounds`, and
notes/findings/2026-09-13-the-launch-workgroup-is-set-by-blocks-at-once-and-the-warp.md
with the portable kernel at `Backends.launch_workgroup`, and is where each
limit is read from. On `GPU` below the limit the workgroup is `blocksize`, so a
`blocksize` above the device's threads per block raises at the launch.
"""
function launch_block_sums!(cpu_kernel, shared_kernel, backend::Backend, partials::AbstractArray,
                             n::Integer, blocksize::Integer, columns::Integer, inputs::NamedTuple)
    site = "Reductions.launch_block_sums!"
    blocksize > 0 ||
        refuse("pairwise blocksize", site, "blocksize $blocksize is not positive")
    nb = cld(n, blocksize)
    size(partials, 1) == nb ||
        refuse("block sums extent", site,
               "partials has $(size(partials, 1)) rows, $n elements in blocks of " *
               "$blocksize have $nb")
    (ndims(partials) <= 2 && size(partials, 2) == columns) ||
        refuse("block sums extent", site,
               "partials has size $(size(partials)), the kernel writes $columns " *
               "column(s) per block")
    for (name, input) in pairs(inputs)
        input isa AbstractArray || continue
        length(input) == n ||
            refuse("block sums extent", site,
                   "$name has length $(length(input)), the block sums read $n elements")
    end
    queue_block_sums!(cpu_kernel, shared_kernel, backend, partials, Int(n), Int(blocksize),
                      values(inputs)...)
    return partials
end

"""
    queue_block_sums!(cpu_kernel, shared_kernel, backend, partials, n, blocksize, inputs...)

The launch `launch_block_sums!` makes once its checks hold, by backend type.
"""
function queue_block_sums!(cpu_kernel, shared_kernel, backend::CPU, partials, n::Int,
                            blocksize::Int, inputs...)
    launch!(cpu_kernel, backend, size(partials, 1), partials, inputs..., blocksize, n)
    return nothing
end

function queue_block_sums!(cpu_kernel, shared_kernel, backend::GPU, partials, n::Int,
                            blocksize::Int, inputs...)
    nb = size(partials, 1)
    if n > device_form_limit(shared_kernel)
        launch!(cpu_kernel, backend, nb, partials, inputs..., blocksize, n)
        return nothing
    end
    lastcount = mod1(n, blocksize)
    launch!(shared_kernel, at_workgroup(backend, blocksize), n,
            partials, inputs..., Val(blocksize), nb, lastcount)
    return nothing
end

"""
    PAIRWISE_DEVICE_FORM_MAX

The largest element count `launch_block_sums!` launches
`pairwise_block_shared_kernel!` over on `GPU`; above it the portable
`pairwise_block_kernel!` runs there instead. The largest count at which
notes/findings/2026-09-13-the-launch-workgroup-is-set-by-blocks-at-once-and-the-warp.md
measured the device form faster than the portable text on the card, at
`BLOCKSIZE` and the portable text at `Backends.launch_workgroup`.
"""
const PAIRWISE_DEVICE_FORM_MAX = 184320

"""
    device_form_limit(shared_kernel)

The largest element count `launch_block_sums!` launches `shared_kernel`, a
block-sum device form, over on `GPU`. One method per device form, each
naming the finding its limit is read from; a device form without one raises
a `MethodError` at its first launch on `GPU`.
"""
device_form_limit(::typeof(pairwise_block_shared_kernel!)) = PAIRWISE_DEVICE_FORM_MAX

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
                              partials, n, blocksize, 1, (xs = xs,))
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
    return combine_range(v, firstindex(v), n)
end

"""
    combine_range(v, first, count)

The `count` entries of `v` from index `first`, `count` at least one, added
as `combine_tree` adds a vector of `count` entries: the first `count ÷ 2`
combined, then the remaining `count - count ÷ 2`, and the two added. Every
recursive call takes `v` itself and two `Int`s.
"""
function combine_range(v::AbstractVector{A}, first::Int, count::Int) where {A<:Number}
    count == 1 && return v[first]
    mid = count ÷ 2
    return combine_range(v, first, mid) + combine_range(v, first + mid, count - mid)
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
    pairwise_sum(::Type{A}, xs, backend = CPU(); blocksize = BLOCKSIZE) where A

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
function pairwise_sum(::Type{A}, xs::AbstractVector, backend::Backend = CPU();
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

@kernel function pairwise_column_block_kernel!(partials, @Const(xs), firsts, blocksize, n, nb)
    item = @index(Global)
    column = fld1(item, nb)
    i = mod1(item, nb)
    @inbounds lo = firsts[i]
    hi = min(lo + blocksize - 1, n)
    T = eltype(partials)
    acc = zero(T)
    @inbounds for j in lo:hi
        acc += T(xs[j, column])
    end
    @inbounds partials[i, column] = acc
end

"""
    launch_column_block_sums!(backend, partials, xs, blocksize)

Queues the block sums of every column of the `(n, ncol)` array `xs` into
the `(cld(n, blocksize), ncol)` array `partials` on `backend`:
`pairwise_column_block_kernel!` over one work item per block and column,
`nb * ncol` of them, at `Backends.launch_workgroup`. Work item `g` is column
`fld1(g, nb)` and block `mod1(g, nb)`, whose first element is
`(1:blocksize:n)[block]` and whose last is `min(first + blocksize - 1, n)`.

Before the launch, on the host, refuses through `Verdicts.refuse`, naming
the array and both shapes, unless `blocksize` is positive, `xs` has two
dimensions and `partials` has size `(cld(n, blocksize), ncol)`: the extents
every index the kernel reads or writes is derived from.
"""
function launch_column_block_sums!(backend::Backend, partials::AbstractArray, xs::AbstractArray,
                                    blocksize::Integer)
    site = "Reductions.launch_column_block_sums!"
    blocksize > 0 ||
        refuse("pairwise blocksize", site, "blocksize $blocksize is not positive")
    ndims(xs) == 2 ||
        refuse("block sums extent", site, "xs has size $(size(xs)), not (elements, columns)")
    n, ncol = size(xs)
    nb = cld(n, blocksize)
    size(partials) == (nb, ncol) ||
        refuse("block sums extent", site,
               "partials has size $(size(partials)), $n elements of $ncol column(s) in blocks " *
               "of $blocksize have ($nb, $ncol)")
    firsts = 1:Int(blocksize):n
    launch!(pairwise_column_block_kernel!, backend, nb * ncol, partials, xs, firsts,
            Int(blocksize), n, nb)
    return partials
end

"""
    pairwise_block_sums(::Type{A}, xs::AbstractArray, backend; blocksize = BLOCKSIZE) where A

The column form of `pairwise_block_sums`: `xs` is an array of cells by
trailing axes (`Backends.LAYOUT`), and the result, left on `backend`, has
size `(cld(size(xs, 1), blocksize), trailing...)`, its column `c` the
vector form's block sums of `xs`'s column `c`, each accumulated in `A` in
the same fixed order, bit for bit. One launch over every block of every
column (`launch_column_block_sums!`). Refuses when `blocksize` is not
positive or `xs` has fewer than two dimensions.
"""
function pairwise_block_sums(::Type{A}, xs::AbstractArray, backend::Backend;
                              blocksize::Integer = BLOCKSIZE) where {A<:Number}
    site = "Reductions.pairwise_block_sums"
    blocksize > 0 ||
        refuse("pairwise blocksize", site, "blocksize $blocksize is not positive")
    require_columns(xs, site)
    nb = cld(cell_extent(xs), blocksize)
    partials = similar(xs, A, nb, trailing_shape(xs)...)
    (nb == 0 || column_extent(xs) == 0) && return partials
    launch_column_block_sums!(backend, by_columns(partials), by_columns(xs), blocksize)
    return partials
end

"""
    pairwise_sum(::Type{A}, xs::AbstractArray, backend = CPU(); blocksize = BLOCKSIZE) where A

The column form of `pairwise_sum`: the fixed-order pairwise sum of each
column of `xs`, an array of cells by trailing axes, returned as one host
`Array{A}` of the trailing shape, its entry `c` the vector form's sum of
`xs`'s column `c`, bit for bit. The block sums of every column come from one
launch (`pairwise_block_sums`'s column form) and are read to the host in one
move through `Backends.on`, one `Events.moved` record per call on
device-resident `xs` whatever the trailing extent and none on host-resident
`xs`; each column is then combined on its own by `combine_fixed_order`.
Refuses when `blocksize` is not positive or `xs` has fewer than two
dimensions.
"""
function pairwise_sum(::Type{A}, xs::AbstractArray, backend::Backend = CPU();
                       blocksize::Integer = BLOCKSIZE) where {A<:Number}
    blocks = on(pairwise_block_sums(A, xs, backend; blocksize = blocksize), CPU(1))
    totals = Array{A}(undef, trailing_shape(xs)...)
    for column in CartesianIndices(trailing_shape(xs))
        totals[column] = combine_fixed_order(view(blocks, :, column))
    end
    return totals
end

"""
    pairwise_sum_reference(::Type{A}, xs::AbstractArray) where A

The naive serial reference for the column form of `pairwise_sum` (decision
0027): the vector reference over each column of `xs` in turn, into an
`Array{A}` of the trailing shape. `xs` must be a host array. Refuses when
`xs` has fewer than two dimensions.
"""
function pairwise_sum_reference(::Type{A}, xs::AbstractArray) where {A<:Number}
    require_columns(xs, "Reductions.pairwise_sum_reference")
    totals = Array{A}(undef, trailing_shape(xs)...)
    for column in CartesianIndices(trailing_shape(xs))
        totals[column] = pairwise_sum_reference(A, view(xs, :, column))
    end
    return totals
end
