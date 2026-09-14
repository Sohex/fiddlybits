# Segmented reductions of a class indicator: docs/plans/fiddlybits-52v.7-kernels.md,
# section "The reductions".

using ..Backends: Backend, CPU, launch!, on, nofuse_mul
using ..Verdicts: refuse
using KernelAbstractions: @kernel, @index, @Const
import KernelAbstractions

"""
    class_position_type(nclass)

The narrowest of `UInt8`, `UInt16` and `UInt32` whose largest value is at least `nclass`.
"""
class_position_type(nclass::Integer) =
    nclass <= typemax(UInt8) ? UInt8 : nclass <= typemax(UInt16) ? UInt16 : UInt32

"""
    class_positions(labels, legend, P, site)

A host array of the shape of `labels` holding, in `P`, the position in `legend` of each
label. Refuses at `site` a label `legend` does not name, naming its index.
"""
function class_positions(labels::AbstractArray, legend::Tuple, ::Type{P},
                         site::AbstractString) where {P<:Unsigned}
    positions = Array{P}(undef, size(labels))
    for i in CartesianIndices(labels)
        k = findfirst(==(labels[i]), legend)
        k === nothing && refuse(
            "class label", site,
            "labels[$(join(Tuple(i), ", "))] holds $(repr(labels[i])), which the legend " *
            "$(join(map(repr, legend), ", ")) does not name")
        positions[i] = P(k)
    end
    return positions
end

"""
    ClassIndicator{T}(labels, legend, backend)

The one-hot class fractions of `labels` over `legend` in `T`: an array of size
`(size(labels)..., length(legend))` whose entry `[i..., k]` is `one(T)` where `labels[i...]`
equals `legend[k]` and `zero(T)` elsewhere. It is never materialised: it holds `legend`
and, on `backend`, each label's position in `legend` in
`class_position_type(length(legend))`, and its entries are read only as that indicator, by
`getindex` when the positions live on the host and by the class forms of `segmented_mean`
and `segmented_weighted_sum` on either backend.

`labels` is a host array whose cells lie on its first axis (`Backends.LAYOUT`). Refuses an
empty `legend`, a `legend` naming one class more than once, and a label `legend` does not
name, naming its index.
"""
struct ClassIndicator{T,N,P<:AbstractArray{<:Unsigned},L<:Tuple} <: AbstractArray{T,N}
    positions::P
    legend::L

    function ClassIndicator{T}(labels::AbstractArray, legend::Tuple,
                               backend::Backend) where {T<:Number}
        site = "Reductions.ClassIndicator"
        isempty(legend) && refuse("class legend", site, "the legend is empty")
        allunique(legend) || refuse(
            "class legend", site,
            "the legend $(join(map(repr, legend), ", ")) names a class more than once")
        host = class_positions(labels, legend, class_position_type(length(legend)), site)
        positions = on(host, backend)
        return new{T,ndims(labels) + 1,typeof(positions),typeof(legend)}(positions, legend)
    end
end

Base.size(c::ClassIndicator) = (size(c.positions)..., length(c.legend))

function Base.getindex(c::ClassIndicator{T,N}, i::Vararg{Int,N}) where {T,N}
    checkbounds(c, i...)
    return c.positions[Base.front(i)...] == i[N] ? one(T) : zero(T)
end

KernelAbstractions.get_backend(c::ClassIndicator) = KernelAbstractions.get_backend(c.positions)

"""
    AbsoluteValues(values)

The absolute values of the vector `values`, never materialised: entry `i` is
`abs(values[i])`. The class forms of `segmented_mean` and `segmented_weighted_sum` read it
as weights on either backend.
"""
struct AbsoluteValues{T,V<:AbstractVector{T}} <: AbstractVector{T}
    values::V
end

Base.size(a::AbsoluteValues) = size(a.values)
Base.getindex(a::AbsoluteValues, i::Int) = abs(a.values[i])

KernelAbstractions.get_backend(a::AbsoluteValues) = KernelAbstractions.get_backend(a.values)

"""
    kernel_weights(weights)

`(values, absolute)`: the array a class kernel reads its weights from, and whether it reads
their absolute values. `weights` itself and `false` for a plain vector, the wrapped vector
and `true` for `AbsoluteValues`.
"""
kernel_weights(weights::AbstractVector) = (weights, false)
kernel_weights(weights::AbsoluteValues) = (weights.values, true)

"""
    launch_segment_classes!(kernel, backend, nelement, nseg, ncol, nclass, outputs, positions, weights, lo, hi, absolute, site)

Queues `kernel` on `backend` over one work item per segment, column and class,
`nseg * ncol * nclass` of them, at `Backends.launch_workgroup`, with the values of the named
tuple `outputs`, then `positions`, `weights`, `lo`, `hi`, `nseg`, `nseg * ncol` and
`absolute`, as its arguments in that order. Work item `g` is class `fld1(g, nseg * ncol)`,
and with `r = mod1(g, nseg * ncol)`, column `fld1(r, nseg)` and segment `mod1(r, nseg)`;
segment `s` of a column reads that column's cells `lo[s]:hi[s]`.

Before the launch, on the host, refuses at `site` through `Verdicts.refuse`, naming the
array and both shapes, unless every array of `outputs` has size `(nseg, ncol, nclass)`,
`positions` has size `(nelement, ncol)`, `weights` holds `nelement` elements, and `lo` and
`hi` each hold `nseg`: the extents every index the kernel reads or writes is derived from.
The values of `lo` and `hi` lie inside `1:nelement` because a `Segmentation` is built only
by its checked constructor. The kernel compares each position with its work item's class
and indexes nothing by a position.
"""
function launch_segment_classes!(kernel, backend::Backend, nelement::Integer, nseg::Integer,
                                 ncol::Integer, nclass::Integer, outputs::NamedTuple,
                                 positions::AbstractArray, weights::AbstractVector,
                                 lo::AbstractVector{<:Integer}, hi::AbstractVector{<:Integer},
                                 absolute::Bool, site::AbstractString)
    for (name, array) in pairs(outputs)
        size(array) == (nseg, ncol, nclass) ||
            refuse("segment kernel extent", site,
                   "$name has size $(size(array)), the segmentation has $nseg segments " *
                   "of $ncol column(s) and $nclass class(es)")
    end
    size(positions) == (nelement, ncol) ||
        refuse("segment kernel extent", site,
               "positions has size $(size(positions)), the segmentation covers $nelement " *
               "elements of $ncol column(s)")
    length(weights) == nelement ||
        refuse("segment kernel extent", site,
               "weights has length $(length(weights)), the segmentation covers " *
               "$nelement elements")
    for (name, array) in (("lo", lo), ("hi", hi))
        length(array) == nseg ||
            refuse("segment kernel extent", site,
                   "$name has length $(length(array)), the segmentation has $nseg segments")
    end
    launch!(kernel, backend, nseg * ncol * nclass, values(outputs)..., positions, weights, lo, hi,
            Int(nseg), Int(nseg * ncol), absolute)
    return nothing
end

@kernel function segmented_class_weighted_sum_kernel!(out, @Const(positions), @Const(weights),
                                                      @Const(lo), @Const(hi), nseg, nplane,
                                                      absolute)
    item = @index(Global)
    class = fld1(item, nplane)
    within = mod1(item, nplane)
    column = fld1(within, nseg)
    seg = mod1(within, nseg)
    T = eltype(out)
    acc = zero(T)
    @inbounds for j in lo[seg]:hi[seg]
        w = weights[j]
        acc += nofuse_mul(ifelse(positions[j, column] == class, one(T), zero(T)),
                          T(ifelse(absolute, abs(w), w)))
    end
    @inbounds out[seg, column, class] = acc
end

@kernel function segmented_class_mean_kernel!(out, zeroflag, @Const(positions), @Const(weights),
                                              @Const(lo), @Const(hi), nseg, nplane, absolute)
    item = @index(Global)
    class = fld1(item, nplane)
    within = mod1(item, nplane)
    column = fld1(within, nseg)
    seg = mod1(within, nseg)
    T = eltype(out)
    num = zero(T)
    den = zero(T)
    @inbounds for j in lo[seg]:hi[seg]
        w = weights[j]
        tw = T(ifelse(absolute, abs(w), w))
        num += nofuse_mul(ifelse(positions[j, column] == class, one(T), zero(T)), tw)
        den += tw
    end
    @inbounds out[seg, column, class] = num / den
    @inbounds zeroflag[seg, column, class] = iszero(den)
end

"""
    class_result(A, xs, segmentation)

`(nseg, ncol, nclass, out)`: the extents a class form of a segmented reduction of `xs` over
`segmentation` launches over, and its result array, uninitialised, of size
`(nseg, trailing..., nclass)` with element type `A` on the backend `xs`'s positions live on.
"""
function class_result(::Type{A}, xs::ClassIndicator, segmentation::Segmentation) where {A}
    positions = xs.positions
    nseg, ncol, nclass = segmentation.nseg, column_extent(positions), length(xs.legend)
    return nseg, ncol, nclass, similar(positions, A, nseg, trailing_shape(positions)..., nclass)
end

"""
    segmented_weighted_sum(::Type{A}, xs::ClassIndicator, weights, segmentation, backend = CPU()) where A

The class form of `segmented_weighted_sum`: the column form's result on the one-hot `xs`
stands for, bit for bit, without the one-hot. The result, on `backend`, has size
`(nseg, trailing..., nclass)`, and its entry `[s, c..., k]` is the fixed-order sum over the
cells `j` of segment `s` of `nofuse_mul(A(xs[j, c..., k]), A(weights[j]))`. `weights` is a
vector of one value per cell, or `AbsoluteValues` of one, read without being materialised.
One launch over every segment, column and class (`launch_segment_classes!`), whatever the
legend length; nothing is read back. Refuses when `weights` does not hold one value per
cell, or when `size(xs, 1)` is not the element count `segmentation` was checked against.
"""
function segmented_weighted_sum(::Type{A}, xs::ClassIndicator, weights::AbstractVector,
                                 segmentation::Segmentation, backend::Backend = CPU()) where {A<:Number}
    site = "Reductions.segmented_weighted_sum"
    require_extent(segmentation, xs, site)
    require_cell_weights(xs, weights, "segmented weighted sum extent", site)
    nseg, ncol, nclass, out = class_result(A, xs, segmentation)
    (nseg == 0 || ncol == 0) && return out
    values, absolute = kernel_weights(weights)
    launch_segment_classes!(segmented_class_weighted_sum_kernel!, backend, segmentation.nelement,
                            nseg, ncol, nclass, (out = reshape(out, nseg, ncol, nclass),),
                            by_columns(xs.positions), values, segmentation.lo, segmentation.hi,
                            absolute, site)
    return out
end

"""
    segmented_weighted_sum_reference(::Type{A}, xs::ClassIndicator, weights, starts) where A

The naive serial reference for the class form of `segmented_weighted_sum` (decision 0027):
the column reference over the one-hot `xs` stands for and the weights, both materialised on
the host. `xs` must hold its positions on the host and `weights` must be a host vector.
"""
segmented_weighted_sum_reference(::Type{A}, xs::ClassIndicator, weights::AbstractVector,
                                 starts::AbstractVector{<:Integer}) where {A<:Number} =
    segmented_weighted_sum_reference(A, collect(xs), collect(weights), starts)

"""
    segmented_mean_classes(::Type{A}, xs::ClassIndicator, segmentation, weights, backend) where A

The launch of the class form of `segmented_mean`, with nothing read back: `(out, zeroflag)`,
both on `backend`, `out` of size `(nseg, trailing..., nclass)` holding each segment's weighted
mean of each class's indicator in every column, and `zeroflag` of size `(nseg, ncol, nclass)`
whether that segment's total weight in that column is zero. One launch over every segment,
column and class. Refuses as `segmented_mean`'s class form does, except for a zero total
weight.
"""
function segmented_mean_classes(::Type{A}, xs::ClassIndicator, segmentation::Segmentation,
                                 weights::AbstractVector, backend::Backend) where {A<:Number}
    site = "Reductions.segmented_mean"
    require_cell_weights(xs, weights, "segmented mean extent", site)
    require_extent(segmentation, xs, site)
    nseg, ncol, nclass, out = class_result(A, xs, segmentation)
    zeroflag = similar(xs.positions, Bool, nseg, ncol, nclass)
    (nseg == 0 || ncol == 0) && return out, zeroflag
    values, absolute = kernel_weights(weights)
    launch_segment_classes!(segmented_class_mean_kernel!, backend, segmentation.nelement, nseg,
                            ncol, nclass, (out = reshape(out, nseg, ncol, nclass), zeroflag = zeroflag),
                            by_columns(xs.positions), values, segmentation.lo, segmentation.hi,
                            absolute, site)
    return out, zeroflag
end

"""
    segmented_mean(::Type{A}, xs::ClassIndicator, starts, weights, backend = CPU()) where A
    segmented_mean(::Type{A}, xs::ClassIndicator, segmentation, weights, backend = CPU()) where A

The class form of `segmented_mean`: the column form's result on the one-hot `xs` stands for,
bit for bit, without the one-hot. The result, on `backend`, has size
`(nseg, trailing..., nclass)`, and its entry `[s, c..., k]` is the weighted mean over segment
`s` of column `c` of class `k`'s indicator, numerator terms
`nofuse_mul(A(xs[j, c..., k]), A(weights[j]))` and denominator terms `A(weights[j])`
accumulated in the same fixed order. `weights` is a vector of one value per cell, or
`AbsoluteValues` of one, read without being materialised. One launch over every segment,
column and class (`segmented_mean_classes`), whatever the legend length, then the zero-weight
refusal's one read, as the column form makes it. Refuses when `weights` does not hold one
value per cell, when `size(xs, 1)` is not the element count the segmentation was checked
against, or when any segment's total weight is zero, naming how many segment columns of the
one-hot.
"""
function segmented_mean(::Type{A}, xs::ClassIndicator, segmentation::Segmentation,
                         weights::AbstractVector, backend::Backend = CPU()) where {A<:Number}
    out, zeroflag = segmented_mean_classes(A, xs, segmentation, weights, backend)
    isempty(zeroflag) && return out
    nzero = pairwise_sum(Int, vec(zeroflag), backend)
    nzero == 0 ||
        refuse("segmented mean weight", "Reductions.segmented_mean",
               "$nzero of $(length(zeroflag)) segment columns have zero total weight")
    return out
end

function segmented_mean(::Type{A}, xs::ClassIndicator, starts::AbstractVector{<:Integer},
                         weights::AbstractVector, backend::Backend = CPU()) where {A<:Number}
    return segmented_mean(A, xs, Segmentation(xs, starts), weights, backend)
end

"""
    segmented_mean_reference(::Type{A}, xs::ClassIndicator, starts, weights) where A

The naive serial reference for the class form of `segmented_mean` (decision 0027): the
column reference over the one-hot `xs` stands for and the weights, both materialised on the
host. `xs` must hold its positions on the host and `weights` must be a host vector.
"""
segmented_mean_reference(::Type{A}, xs::ClassIndicator, starts::AbstractVector{<:Integer},
                         weights::AbstractVector) where {A<:Number} =
    segmented_mean_reference(A, collect(xs), starts, collect(weights))
