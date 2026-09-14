using Test
using CUDA
using KernelAbstractions: @kernel, @index, @Const
using Fiddlybits: Reductions, Backends, Events, Verdicts

# fiddlybits-52v.7.59: the column forms of segmented_sum, segmented_weighted_sum,
# segmented_mean, segmented_quantile and pairwise_sum over an array of cells by trailing
# axes (Backends.LAYOUT), docs/plans/fiddlybits-52v.7-kernels.md, section "The
# reductions". Each column of a result is compared as raw bytes with the vector form run
# on that column on the same backend; launches are read from Backends.queued_launches and
# host reads counted through Events.move_sink!.

"The raw bytes of `v`, read to the host through Backends.on."
column_bytes(v::AbstractArray) = collect(reinterpret(UInt8, vec(collect(Backends.on(v, Backends.CPU(1))))))
column_bytes(x::Number) = collect(reinterpret(UInt8, [x]))

"An array of `n` cells by `trailing` of type `T` from the suite's fixed formula."
column_field(::Type{T}, n::Integer, trailing::Tuple) where {T} =
    reshape(ReductionFixtures.seeded_vector(T, n * prod(trailing)), n, trailing...)

"An array of `n` cells by `trailing` of integers from a fixed formula, both signs."
column_integers(n::Integer, trailing::Tuple) =
    reshape(Int[mod(i * 7919 + 13, 251) - 125 for i in 1:(n * prod(trailing))], n, trailing...)

"`n` positive weights of type `T`, one per cell."
column_weights(::Type{T}, n::Integer) where {T} =
    T.(abs.(ReductionFixtures.seeded_vector(Float64, n)) .+ 0.1)

"Column `column` of the host array `xs`, as its own vector on `backend`."
column_on(xs::AbstractArray, column, backend) = Backends.on(collect(view(xs, :, column)), backend)

"""
For each column of `result`, of size `(m, trailing...)`, whether its bytes are the bytes
of `vector_result(column)`, as an array of the trailing shape.
"""
function columns_agree(result::AbstractArray, vector_result)
    host = Backends.on(result, Backends.CPU(1))
    return [column_bytes(collect(view(host, :, c))) == column_bytes(vector_result(c))
            for c in CartesianIndices(Base.tail(size(host)))]
end

"The number of Events.Moved records `f` produces."
function column_move_count(f)
    tally = Events.MoveTally()
    Events.move_sink!(tally)
    try
        f()
    finally
        Events.move_sink!(Events.noop_sink)
    end
    return Events.move_total(tally)
end

"The `(kernel, work items)` of each launch `f` queues on `gpu` from this task."
function column_launches(f, gpu)
    Backends.complete!(gpu)
    f()
    launches = [(launch.kernel, launch.n) for launch in Backends.queued_launches(gpu)]
    Backends.complete!(gpu)
    return launches
end

"The refusal `f` raises, or `nothing` when it returns."
function column_refusal(f)
    try
        f()
    catch e
        e isa Verdicts.Refusal && return e
        rethrow()
    end
    return nothing
end

@kernel function column_sum_one_cell_off_kernel!(out, @Const(xs), @Const(lo), @Const(hi), nseg, shifted)
    item = @index(Global)
    column = fld1(item, nseg)
    seg = mod1(item, nseg)
    T = eltype(out)
    acc = zero(T)
    for j in lo[seg]:hi[seg]
        acc += T(xs[ifelse(column == shifted && j < size(xs, 1), j + 1, j), column])
    end
    out[seg, column] = acc
end

const COLUMN_BACKENDS = (("CPU", Backends.CPU()), ("GPU", Backends.GPU()))
const COLUMN_TRAILING = [(1,), (5,), (3, 4)]
const COLUMN_STARTS = [1, 2, 17, 40, 65, 70]
const COLUMN_TYPES = [(Float64, Float64, Float64), (Float32, Float64, Float32), (Float64, Float32, Float64),
                      (Float32, Float32, Float32)]
const COLUMN_PAIRWISE_N = 2 * Reductions.BLOCKSIZE + 37
const COLUMN_QUANTILE_K = 2
const COLUMN_QUANTILE_NSEG = 6

@testset "column forms of the segmented and pairwise reductions (fiddlybits-52v.7.59)" begin
    @test CUDA.functional()

    @testset "each column is bitwise the vector form on that column" begin
        for (bname, backend) in COLUMN_BACKENDS, trailing in COLUMN_TRAILING
            @testset "$bname, trailing shape $trailing" begin
                starts = COLUMN_STARTS
                n, nseg = last(starts) - 1, length(starts) - 1
                starts_b = Backends.on(starts, backend)

                @testset "segmented_sum, segmented_weighted_sum and segmented_mean: $TX elements, $TW weights, $A accumulator" for
                        (TX, TW, A) in COLUMN_TYPES
                    xs, weights = column_field(TX, n, trailing), column_weights(TW, n)
                    xs_b, weights_b = Backends.on(xs, backend), Backends.on(weights, backend)
                    segmentation = Reductions.Segmentation(xs_b, starts_b)
                    vector_segmentation(c) = Reductions.Segmentation(column_on(xs, c, backend), starts_b)

                    sums = Reductions.segmented_sum(A, xs_b, segmentation, backend)
                    @test size(sums) == (nseg, trailing...)
                    @test eltype(sums) === A
                    @test Backends.backend_of(sums) === Backends.backend_of(xs_b)
                    @test all(columns_agree(sums, c -> Reductions.segmented_sum(A, column_on(xs, c, backend),
                                                                                  vector_segmentation(c), backend)))
                    @test column_bytes(Reductions.segmented_sum(A, xs_b, starts_b, backend)) == column_bytes(sums)
                    @test column_bytes(sums) == column_bytes(Reductions.segmented_sum_reference(A, xs, starts))

                    weighted = Reductions.segmented_weighted_sum(A, xs_b, weights_b, segmentation, backend)
                    @test size(weighted) == (nseg, trailing...)
                    @test eltype(weighted) === A
                    @test all(columns_agree(weighted, c -> Reductions.segmented_weighted_sum(A, column_on(xs, c, backend),
                                                                                              weights_b, vector_segmentation(c),
                                                                                              backend)))
                    @test column_bytes(weighted) ==
                          column_bytes(Reductions.segmented_weighted_sum_reference(A, xs, weights, starts))

                    means = Reductions.segmented_mean(A, xs_b, segmentation, weights_b, backend)
                    @test size(means) == (nseg, trailing...)
                    @test eltype(means) === A
                    @test all(columns_agree(means, c -> Reductions.segmented_mean(A, column_on(xs, c, backend),
                                                                                    vector_segmentation(c), weights_b,
                                                                                    backend)))
                    @test column_bytes(Reductions.segmented_mean(A, xs_b, starts_b, weights_b, backend)) ==
                          column_bytes(means)
                    @test column_bytes(means) == column_bytes(Reductions.segmented_mean_reference(A, xs, starts, weights))
                end

                @testset "pairwise_sum and pairwise_block_sums: $T into $A, blocksize $bs" for
                        (T, A) in ((Float64, Float64), (Float32, Float64), (Float64, Float32)),
                        bs in (Reductions.BLOCKSIZE, 17)
                    xs = column_field(T, COLUMN_PAIRWISE_N, trailing)
                    xs_b = Backends.on(xs, backend)

                    totals = Reductions.pairwise_sum(A, xs_b, backend; blocksize = bs)
                    @test totals isa Array{A}
                    @test size(totals) == trailing
                    @test all(column_bytes(totals[c]) ==
                              column_bytes(Reductions.pairwise_sum(A, column_on(xs, c, backend), backend; blocksize = bs))
                              for c in CartesianIndices(trailing))

                    blocks = Reductions.pairwise_block_sums(A, xs_b, backend; blocksize = bs)
                    @test size(blocks) == (cld(COLUMN_PAIRWISE_N, bs), trailing...)
                    @test all(columns_agree(blocks, c -> Reductions.pairwise_block_sums(A, column_on(xs, c, backend),
                                                                                          backend; blocksize = bs)))
                end

                @testset "pairwise_sum and its reference lie within error_bound of each column's exact sum" begin
                    xs = column_field(Float64, COLUMN_PAIRWISE_N, trailing)
                    totals = Reductions.pairwise_sum(Float64, Backends.on(xs, backend), backend)
                    reference = Reductions.pairwise_sum_reference(Float64, xs)
                    @test size(reference) == trailing
                    for c in CartesianIndices(trailing)
                        column = xs[:, c]
                        exact = ReductionFixtures.exact_sum(column)
                        tol = Reductions.error_bound(Float64, length(column), ReductionFixtures.term_magnitude(column))
                        @test abs(totals[c] - exact) <= tol
                        @test abs(reference[c] - exact) <= tol
                    end
                end

                @testset "segmented_quantile: $T, q=$q" for T in (Float64, Float32, Int), q in (0.0, 0.37, 1.0)
                    seglen = 4^COLUMN_QUANTILE_K
                    qn = COLUMN_QUANTILE_NSEG * seglen
                    qstarts = collect(1:seglen:(qn + 1))
                    qstarts_b = Backends.on(qstarts, backend)
                    xs = T === Int ? column_integers(qn, trailing) : column_field(T, qn, trailing)
                    xs_b = Backends.on(xs, backend)
                    segmentation = Reductions.Segmentation(xs_b, qstarts_b)

                    selected = Reductions.segmented_quantile(xs_b, segmentation, q, backend)
                    @test size(selected) == (COLUMN_QUANTILE_NSEG, trailing...)
                    @test eltype(selected) === T
                    @test all(columns_agree(selected, c -> Reductions.segmented_quantile(column_on(xs, c, backend),
                                                                                           qstarts_b, q, backend)))
                    @test column_bytes(Reductions.segmented_quantile(xs_b, qstarts_b, q, backend)) ==
                          column_bytes(selected)
                    @test column_bytes(selected) == column_bytes(Reductions.segmented_quantile_reference(xs, qstarts, q))
                end
            end
        end
    end

    @testset "a trailing extent of zero reduces to an empty result and launches nothing" begin
        starts = COLUMN_STARTS
        n, nseg = last(starts) - 1, length(starts) - 1
        xs = zeros(n, 0)
        segmentation = Reductions.Segmentation(xs, starts)
        @test size(Reductions.segmented_sum(Float64, xs, segmentation)) == (nseg, 0)
        @test size(Reductions.segmented_mean(Float64, xs, segmentation, column_weights(Float64, n))) == (nseg, 0)
        @test size(Reductions.pairwise_sum(Float64, xs)) == (0,)
        @test size(Reductions.pairwise_sum_reference(Float64, xs)) == (0,)
    end

    @testset "positive control: a kernel reading one column one cell off fails the per-column identity in that column alone" begin
        for (bname, backend) in COLUMN_BACKENDS
            @testset "$bname" begin
                starts = COLUMN_STARTS
                n, nseg = last(starts) - 1, length(starts) - 1
                trailing, shifted = (5,), 3
                xs = column_field(Float64, n, trailing)
                xs_b = Backends.on(xs, backend)
                starts_b = Backends.on(starts, backend)
                segmentation = Reductions.Segmentation(xs_b, starts_b)
                vector_sum(c) = Reductions.segmented_sum(Float64, column_on(xs, c, backend),
                                                         Reductions.Segmentation(column_on(xs, c, backend), starts_b), backend)

                off = similar(xs_b, Float64, nseg, 5)
                Backends.launch!(column_sum_one_cell_off_kernel!, backend, nseg * 5, off, xs_b,
                                 segmentation.lo, segmentation.hi, nseg, shifted)
                @test findall(!, columns_agree(off, vector_sum)) == [shifted]

                own = similar(xs_b, Float64, nseg, 5)
                Backends.launch!(Reductions.segmented_column_sum_kernel!, backend, nseg * 5, own, xs_b,
                                 segmentation.lo, segmentation.hi, nseg)
                @test all(columns_agree(own, vector_sum))
            end
        end
    end

    @testset "each column form queues one launch whatever the trailing extent" begin
        gpu = Backends.GPU()
        starts = COLUMN_STARTS
        n, nseg = last(starts) - 1, length(starts) - 1
        seglen = 4^COLUMN_QUANTILE_K
        qn = COLUMN_QUANTILE_NSEG * seglen
        for trailing in ((1,), (5,), (3, 4), (64,))
            ncol = prod(trailing)
            xs_b = Backends.on(column_field(Float64, n, trailing), gpu)
            weights_b = Backends.on(column_weights(Float64, n), gpu)
            segmentation = Reductions.Segmentation(xs_b, Backends.on(starts, gpu))
            qxs_b = Backends.on(column_field(Float64, qn, trailing), gpu)
            qsegmentation = Reductions.Segmentation(qxs_b, Backends.on(collect(1:seglen:(qn + 1)), gpu))
            pxs_b = Backends.on(column_field(Float64, COLUMN_PAIRWISE_N, trailing), gpu)
            nb = cld(COLUMN_PAIRWISE_N, Reductions.BLOCKSIZE)

            for (name, kernel, items, call) in (
                    ("segmented_sum", Reductions.segmented_column_sum_kernel!, nseg * ncol,
                     () -> Reductions.segmented_sum(Float64, xs_b, segmentation, gpu)),
                    ("segmented_weighted_sum", Reductions.segmented_column_weighted_sum_kernel!, nseg * ncol,
                     () -> Reductions.segmented_weighted_sum(Float64, xs_b, weights_b, segmentation, gpu)),
                    ("segmented_mean, before its one read", Reductions.segmented_column_mean_kernel!, nseg * ncol,
                     () -> Reductions.segmented_mean_columns(Float64, xs_b, segmentation, weights_b, gpu)),
                    ("segmented_quantile", Reductions.quantile_kernel(Val(COLUMN_QUANTILE_K)),
                     COLUMN_QUANTILE_NSEG * ncol * seglen,
                     () -> Reductions.segmented_quantile(qxs_b, qsegmentation, 0.5, gpu)),
                    ("pairwise_sum, before its one read", Reductions.pairwise_column_block_kernel!, nb * ncol,
                     () -> Reductions.pairwise_block_sums(Float64, pxs_b, gpu)))
                @testset "$name over trailing shape $trailing queues one launch of $items work items" begin
                    @test column_launches(call, gpu) == [(kernel, items)]
                end
            end
        end

        @testset "positive control: a loop over columns fails the one-launch assertion" begin
            trailing = (5,)
            xs_b = Backends.on(column_field(Float64, n, trailing), gpu)
            segmentation = Reductions.Segmentation(xs_b, Backends.on(starts, gpu))
            loop() = [Reductions.segmented_sum(Float64, xs_b[:, c], segmentation, gpu) for c in 1:5]
            launches = column_launches(loop, gpu)
            @test length(launches) == 5
            @test launches != [(Reductions.segmented_column_sum_kernel!, nseg * 5)]
            @test launches != [(Reductions.segmented_sum_kernel!, nseg)]
        end
    end

    @testset "pairwise_sum and segmented_mean's zero-weight refusal each read the device once whatever the trailing extent" begin
        gpu = Backends.GPU()
        starts = COLUMN_STARTS
        n, nseg = last(starts) - 1, length(starts) - 1
        starts_b = Backends.on(starts, gpu)
        weights = column_weights(Float64, n)
        weights_b = Backends.on(weights, gpu)
        zero_weights_b = Backends.on(zeros(n), gpu)
        seglen = 4^COLUMN_QUANTILE_K
        qn = COLUMN_QUANTILE_NSEG * seglen

        for trailing in ((1,), (5,), (3, 4), (64,))
            ncol = prod(trailing)
            @testset "trailing shape $trailing" begin
                xs = column_field(Float64, n, trailing)
                xs_b = Backends.on(xs, gpu)
                segmentation = Reductions.Segmentation(xs_b, starts_b)
                pxs = column_field(Float64, COLUMN_PAIRWISE_N, trailing)
                pxs_b = Backends.on(pxs, gpu)
                qxs_b = Backends.on(column_field(Float64, qn, trailing), gpu)
                qsegmentation = Reductions.Segmentation(qxs_b, Backends.on(collect(1:seglen:(qn + 1)), gpu))

                @test column_move_count(() -> Reductions.pairwise_sum(Float64, pxs_b, gpu)) == 1
                @test column_move_count(() -> Reductions.segmented_mean(Float64, xs_b, segmentation, weights_b, gpu)) == 1
                @test column_move_count(() -> Reductions.segmented_mean(Float64, xs_b, starts_b, weights_b, gpu)) == 2
                @test column_move_count(() -> Reductions.segmented_sum(Float64, xs_b, segmentation, gpu)) == 0
                @test column_move_count(() -> Reductions.segmented_weighted_sum(Float64, xs_b, weights_b,
                                                                               segmentation, gpu)) == 0
                @test column_move_count(() -> Reductions.segmented_quantile(qxs_b, qsegmentation, 0.5, gpu)) == 0

                refused = Ref{Any}(nothing)
                @test column_move_count(() -> (refused[] = column_refusal(() ->
                    Reductions.segmented_mean(Float64, xs_b, segmentation, zero_weights_b, gpu)))) == 1
                @test refused[] isa Verdicts.Refusal
                @test occursin("$(nseg * ncol) of $(nseg * ncol) segment columns", refused[].reason)

                @test column_move_count(() -> Reductions.pairwise_sum(Float64, pxs, Backends.CPU())) == 0
                @test column_move_count(() -> Reductions.segmented_mean(Float64, xs, starts, weights, Backends.CPU())) == 0
            end
        end

        @testset "positive control: a loop over columns fails the one-read assertions" begin
            trailing = (5,)
            pxs_b = Backends.on(column_field(Float64, COLUMN_PAIRWISE_N, trailing), gpu)
            xs_b = Backends.on(column_field(Float64, n, trailing), gpu)
            segmentation = Reductions.Segmentation(xs_b, starts_b)
            @test column_move_count(() -> [Reductions.pairwise_sum(Float64, pxs_b[:, c], gpu) for c in 1:5]) == 5
            @test column_move_count(() -> [Reductions.segmented_mean(Float64, xs_b[:, c], segmentation, weights_b, gpu)
                                           for c in 1:5]) == 5
        end
    end

    @testset "the column forms refuse by name" begin
        starts = COLUMN_STARTS
        n = last(starts) - 1
        xs = column_field(Float64, n, (3,))
        weights = column_weights(Float64, n)
        segmentation = Reductions.Segmentation(xs, starts)

        @testset "weights one short of the cells" begin
            for call in (() -> Reductions.segmented_weighted_sum(Float64, xs, weights[1:n-1], segmentation),
                         () -> Reductions.segmented_mean(Float64, xs, segmentation, weights[1:n-1]),
                         () -> Reductions.segmented_weighted_sum_reference(Float64, xs, weights[1:n-1], starts),
                         () -> Reductions.segmented_mean_reference(Float64, xs, starts, weights[1:n-1]))
                caught = column_refusal(call)
                @test caught isa Verdicts.Refusal
                @test occursin("xs has $n cells along its first axis", caught.reason)
                @test occursin("weights has length $(n - 1)", caught.reason)
            end
        end

        @testset "a field one cell short of the segmentation" begin
            short = xs[1:n-1, :]
            for call in (() -> Reductions.segmented_sum(Float64, short, segmentation),
                         () -> Reductions.segmented_quantile(short, segmentation, 0.5),
                         () -> Reductions.segmented_sum_reference(Float64, short, segmentation))
                caught = column_refusal(call)
                @test caught isa Verdicts.Refusal
                @test occursin("checked against $n elements", caught.reason)
                @test occursin("xs has $(n - 1) cells", caught.reason)
            end
            @test column_refusal(() -> Reductions.segmented_sum(Float64, short, starts)) isa Verdicts.Refusal
        end

        @testset "an array with no trailing axis" begin
            caught = column_refusal(() -> Reductions.pairwise_sum(Float64, fill(1.0)))
            @test caught isa Verdicts.Refusal
            @test caught.quantity == "column reduction shape"
        end

        @testset "positive control: matched arguments do not refuse" begin
            @test column_refusal(() -> Reductions.segmented_weighted_sum(Float64, xs, weights, segmentation)) === nothing
            @test column_refusal(() -> Reductions.segmented_mean(Float64, xs, segmentation, weights)) === nothing
            @test column_refusal(() -> Reductions.segmented_sum(Float64, xs, starts)) === nothing
            @test column_refusal(() -> Reductions.pairwise_sum(Float64, xs)) === nothing
        end
    end
end
