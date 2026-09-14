using Test
using CUDA
using Fiddlybits: Reductions, Backends, Verdicts

# Decision 0055: every kernel in src/Reductions/ reads and writes under @inbounds. Each is
# run here over the edge shapes on Backends.CPU and on Backends.GPU against its reference
# path (decision 0027), and each door that launches one refuses an argument one element
# short, naming the array and both lengths.

"The raw bytes of `v`, read on the host."
edge_bytes(v::AbstractArray) = collect(reinterpret(UInt8, vec(collect(Backends.on(v, Backends.CPU(1))))))
edge_bytes(x::Number) = collect(reinterpret(UInt8, [x]))

"`n` elements of type `T` from the suite's fixed formulas."
edge_elements(::Type{Bool}, n::Integer) = Bool[isodd(i ÷ 3) for i in 1:n]
edge_elements(::Type{T}, n::Integer) where {T<:Real} = ReductionFixtures.seeded_vector(T, n)

"`n` positive areas or weights of type `T` from the suite's fixed formula."
edge_areas(::Type{T}, n::Integer) where {T<:Real} =
    T.(abs.(ReductionFixtures.seeded_vector(Float64, n)) .+ 0.1)

"The block sums of `terms` in blocks of `blocksize`, each `pairwise_sum_reference` in `A`."
block_reference(::Type{A}, terms::AbstractVector, blocksize::Integer) where {A} =
    A[Reductions.pairwise_sum_reference(A, terms[(i - 1) * blocksize + 1:min(i * blocksize, length(terms))])
      for i in 1:cld(length(terms), blocksize)]

"`areas` where `xs` is at or above `x`, zero elsewhere."
selected(xs, areas, x) = ifelse.(xs .>= x, areas, zero(eltype(areas)))

"The refusal `f` raises, or `nothing` when it returns."
function refusal_of(f)
    try
        f()
    catch e
        e isa Verdicts.Refusal && return e
        rethrow()
    end
    return nothing
end

const EDGE_BACKENDS = (("CPU", Backends.CPU()), ("GPU", Backends.GPU()))
const EDGE_B = Reductions.BLOCKSIZE
const EDGE_SECOND_B = 17

# (name, element count, blocksize, whether every type runs it)
const BLOCK_SHAPES = [
    ("a single element", 1, EDGE_B, true),
    ("fewer elements than one block", EDGE_B - 3, EDGE_B, true),
    ("a partial last block", 4 * EDGE_B + 37, EDGE_B, true),
    ("every block full", 4 * EDGE_B, EDGE_B, true),
    ("a second block length with a partial last block", 5 * EDGE_SECOND_B + 3, EDGE_SECOND_B, false),
    ("a second block length with every block full", 5 * EDGE_SECOND_B, EDGE_SECOND_B, false),
]

# (element type, accumulator type); the first is the one every shape runs.
const PAIRWISE_TYPES = [(Float64, Float64), (Float32, Float64), (Float64, Float32),
                        (Float32, Float32), (Bool, Int)]

# (element type, area type, accumulator type); the first is the one every shape runs.
const AREA_TYPES = [(TX, TW, A) for A in (Float64, Float32) for TX in (Float64, Float32)
                    for TW in (Float64, Float32)]

# (name, boundary array, whether a mean is defined over it)
const SEGMENT_SHAPES = [
    ("a single element", [1, 2], true),
    ("an empty segment beside one-element segments", [1, 1, 2, 3, 3, 4], false),
    ("a partial last segment", [1, 17, 33, 49, 65, 70], true),
    ("every segment full", collect(1:16:81), true),
    ("a second segment length", collect(1:64:193), true),
    ("uneven segments", ReductionFixtures.segment_starts(ReductionFixtures.N, ReductionFixtures.NSEG), true),
]

const SUM_TYPES = [(T, A) for A in (Float64, Float32) for T in (Float64, Float32)]
const WEIGHTED_TYPES = AREA_TYPES

# The trailing shapes the column kernels run over: one column, several, and two trailing
# axes; the first is the one every element and accumulator type runs.
const EDGE_TRAILING = [(1,), (3,), (2, 3)]

# The trailing shapes, legend and (weight type, accumulator type) pairs the class kernels run
# over; the first trailing shape is the one every type pair runs.
const CLASS_EDGE_TRAILING = [(), (1,), (3,), (2, 3)]
const CLASS_EDGE_LEGEND = (:first, :second, :third)
const CLASS_EDGE_TYPES = [(TW, A) for A in (Float64, Float32) for TW in (Float64, Float32)]

"An array of cells by `trailing` of type `T`: the suite's fixed formula over every column."
edge_columns(::Type{T}, n::Integer, trailing::Tuple) where {T} =
    reshape(edge_elements(T, n * prod(trailing)), n, trailing...)

# (name, depth k, segment count)
const QUANTILE_SHAPES = [
    ("one segment at the smallest depth", 1, 1),
    ("several segments at the smallest depth", 1, 7),
    ("a second segment length", 2, 5),
    ("depth 3", 3, 2),
    ("depth 4", 4, 2),
    ("one segment at the largest depth", 5, 1),
    ("several segments at the largest depth", 5, 3),
]

@testset "the eliding reduction kernels over their edge shapes, on both backends (decision 0055)" begin
    @test CUDA.functional()

    for (bname, backend) in EDGE_BACKENDS
        @testset "$bname" begin
            @testset "pairwise_block_sums and pairwise_sum: $shape, $T into $A" for
                    (shape, n, bs, every_type) in BLOCK_SHAPES, (T, A) in PAIRWISE_TYPES
                (every_type || (T, A) == first(PAIRWISE_TYPES)) || continue
                xs = edge_elements(T, n)
                reference = block_reference(A, xs, bs)
                xs_b = Backends.on(xs, backend)
                partials = Reductions.pairwise_block_sums(A, xs_b, backend; blocksize = bs)
                @test eltype(partials) === A
                @test edge_bytes(partials) == edge_bytes(reference)
                @test edge_bytes(Reductions.pairwise_sum(A, xs_b, backend; blocksize = bs)) ==
                      edge_bytes(Reductions.combine_tree(reference))
            end

            @testset "area_weighted_block_sums and area_weighted_sum: $shape, $TX and $TW into $A" for
                    (shape, n, bs, every_type) in BLOCK_SHAPES, (TX, TW, A) in AREA_TYPES
                (every_type || (TX, TW, A) == first(AREA_TYPES)) || continue
                xs, areas, x = edge_elements(TX, n), edge_areas(TW, n), 0.0
                reference = block_reference(A, selected(xs, areas, x), bs)
                xs_b, areas_b = Backends.on(xs, backend), Backends.on(areas, backend)
                partials = Reductions.area_weighted_block_sums(A, xs_b, areas_b, x, backend; blocksize = bs)
                @test edge_bytes(partials) == edge_bytes(reference)
                @test edge_bytes(Reductions.area_weighted_sum(A, xs_b, areas_b, x, backend; blocksize = bs)) ==
                      edge_bytes(Reductions.combine_tree(reference))
            end

            @testset "area_fraction_block_sums and area_fraction_above: $shape, $TX and $TW into $A" for
                    (shape, n, bs, every_type) in BLOCK_SHAPES, (TX, TW, A) in AREA_TYPES
                (every_type || (TX, TW, A) == first(AREA_TYPES)) || continue
                xs, areas, x = edge_elements(TX, n), edge_areas(TW, n), 0.0
                total = block_reference(A, areas, bs)
                above = block_reference(A, selected(xs, areas, x), bs)
                xs_b, areas_b = Backends.on(xs, backend), Backends.on(areas, backend)
                partials = Reductions.area_fraction_block_sums(A, xs_b, areas_b, x, backend; blocksize = bs)
                @test size(partials) == (cld(n, bs), 2)
                @test edge_bytes(partials) == edge_bytes(hcat(total, above))
                if bs == EDGE_B && A === Float64
                    fraction = Reductions.area_fraction_above(xs_b, areas_b, x, backend)
                    @test edge_bytes(fraction) ==
                          edge_bytes(Reductions.combine_tree(above) / Reductions.combine_tree(total))
                    tol = 2 * Reductions.error_bound(Float64, n, sum(Float64, areas)) / sum(Float64, areas)
                    @test abs(fraction - Reductions.area_fraction_above_reference(xs, areas, x)) <= tol
                end
            end

            @testset "positive control: the first element of a block and the last element each move exactly their own block" begin
                n = 4 * EDGE_B + 37
                xs = edge_elements(Float64, n)
                areas = edge_areas(Float64, n)
                x = -3.0
                nb = cld(n, EDGE_B)
                sums(v, a) = (Backends.on(Reductions.pairwise_block_sums(Float64, Backends.on(v, backend), backend), Backends.CPU(1)),
                              Backends.on(Reductions.area_weighted_block_sums(Float64, Backends.on(v, backend),
                                                                              Backends.on(a, backend), x, backend), Backends.CPU(1)),
                              Backends.on(Reductions.area_fraction_block_sums(Float64, Backends.on(v, backend),
                                                                              Backends.on(a, backend), x, backend), Backends.CPU(1)))
                base = sums(xs, areas)
                for (index, block) in ((EDGE_B + 1, 2), (n, nb))
                    moved_xs, moved_areas = copy(xs), copy(areas)
                    moved_xs[index] += 1.0
                    moved_areas[index] += 1.0
                    moved = sums(moved_xs, moved_areas)
                    @test findall(moved[1] .!= base[1]) == [block]
                    @test findall(sums(xs, moved_areas)[2] .!= base[2]) == [block]
                    @test findall(vec(any(sums(xs, moved_areas)[3] .!= base[3]; dims = 2))) == [block]
                end
            end

            @testset "segmented_sum: $shape, $T into $A" for
                    (shape, starts, _) in SEGMENT_SHAPES, (T, A) in SUM_TYPES
                n = last(starts) - 1
                xs = edge_elements(T, n)
                xs_b = Backends.on(xs, backend)
                segmentation = Reductions.Segmentation(xs_b, Backends.on(starts, backend))
                result = Reductions.segmented_sum(A, xs_b, segmentation, backend)
                @test eltype(result) === A
                @test edge_bytes(result) == edge_bytes(Reductions.segmented_sum_reference(A, xs, starts))
            end

            @testset "segmented_weighted_sum and segmented_mean: $shape, $TX and $TW into $A" for
                    (shape, starts, has_mean) in SEGMENT_SHAPES, (TX, TW, A) in WEIGHTED_TYPES
                n = last(starts) - 1
                xs, weights = edge_elements(TX, n), edge_areas(TW, n)
                xs_b, weights_b = Backends.on(xs, backend), Backends.on(weights, backend)
                segmentation = Reductions.Segmentation(xs_b, Backends.on(starts, backend))
                @test edge_bytes(Reductions.segmented_weighted_sum(A, xs_b, weights_b, segmentation, backend)) ==
                      edge_bytes(Reductions.segmented_weighted_sum_reference(A, xs, weights, starts))
                if has_mean
                    @test edge_bytes(Reductions.segmented_mean(A, xs_b, segmentation, weights_b, backend)) ==
                          edge_bytes(Reductions.segmented_mean_reference(A, xs, starts, weights))
                else
                    @test_throws Verdicts.Refusal Reductions.segmented_mean(A, xs_b, segmentation, weights_b, backend)
                end
            end

            @testset "positive control: the first element of a segment and the last element each move exactly their own segment" begin
                starts = [1, 17, 33, 49, 65, 70]
                n = last(starts) - 1
                xs, weights = edge_elements(Float64, n), edge_areas(Float64, n)
                reduce_all(v, w) = begin
                    v_b, w_b = Backends.on(v, backend), Backends.on(w, backend)
                    seg = Reductions.Segmentation(v_b, Backends.on(starts, backend))
                    [Backends.on(r, Backends.CPU(1)) for r in (Reductions.segmented_sum(Float64, v_b, seg, backend),
                                                               Reductions.segmented_weighted_sum(Float64, v_b, w_b, seg, backend),
                                                               Reductions.segmented_mean(Float64, v_b, seg, w_b, backend))]
                end
                base = reduce_all(xs, weights)
                for (index, segment) in ((starts[2], 2), (n, length(starts) - 1))
                    moved_xs = copy(xs)
                    moved_xs[index] += 1.0
                    for (b, m) in zip(base, reduce_all(moved_xs, weights))
                        @test findall(m .!= b) == [segment]
                    end
                end
            end

            @testset "segmented_quantile: $shape, $T, q=$q" for
                    (shape, k, nseg) in QUANTILE_SHAPES, T in (Float64, Float32, Int), q in (0.0, 0.5, 1.0)
                seglen = 4^k
                n = nseg * seglen
                xs = T === Int ? Int[mod(i * 7919 + 13, 251) - 125 for i in 1:n] : edge_elements(T, n)
                starts = collect(1:seglen:(n + 1))
                xs_b = Backends.on(xs, backend)
                segmentation = Reductions.Segmentation(xs_b, Backends.on(starts, backend))
                result = Reductions.segmented_quantile(xs_b, segmentation, q, backend)
                @test eltype(result) === T
                @test edge_bytes(result) == edge_bytes(Reductions.segmented_quantile_reference(xs, starts, q))
            end

            @testset "positive control: the first element of a segment and the last element each move exactly their own segment's maximum" begin
                k, nseg = 2, 4
                seglen = 4^k
                n = nseg * seglen
                xs = edge_elements(Float64, n)
                starts = collect(1:seglen:(n + 1))
                top(v) = Backends.on(Reductions.segmented_quantile(Backends.on(v, backend),
                                                                    Backends.on(starts, backend), 1.0, backend),
                                     Backends.CPU(1))
                base = top(xs)
                for (index, segment) in ((seglen + 1, 2), (n, nseg))
                    moved = copy(xs)
                    moved[index] = 10.0
                    @test findall(top(moved) .!= base) == [segment]
                end
            end

            @testset "segmented column kernels: $shape, trailing $trailing, $TX and $TW into $A" for
                    (shape, starts, has_mean) in SEGMENT_SHAPES, trailing in EDGE_TRAILING, (TX, TW, A) in WEIGHTED_TYPES
                (trailing == first(EDGE_TRAILING) || (TX, TW, A) == first(WEIGHTED_TYPES)) || continue
                n = last(starts) - 1
                xs, weights = edge_columns(TX, n, trailing), edge_areas(TW, n)
                xs_b, weights_b = Backends.on(xs, backend), Backends.on(weights, backend)
                segmentation = Reductions.Segmentation(xs_b, Backends.on(starts, backend))
                sums = Reductions.segmented_sum(A, xs_b, segmentation, backend)
                @test eltype(sums) === A
                @test size(sums) == (length(starts) - 1, trailing...)
                @test edge_bytes(sums) == edge_bytes(Reductions.segmented_sum_reference(A, xs, starts))
                @test edge_bytes(Reductions.segmented_weighted_sum(A, xs_b, weights_b, segmentation, backend)) ==
                      edge_bytes(Reductions.segmented_weighted_sum_reference(A, xs, weights, starts))
                if has_mean
                    @test edge_bytes(Reductions.segmented_mean(A, xs_b, segmentation, weights_b, backend)) ==
                          edge_bytes(Reductions.segmented_mean_reference(A, xs, starts, weights))
                else
                    @test_throws Verdicts.Refusal Reductions.segmented_mean(A, xs_b, segmentation, weights_b, backend)
                end
            end

            @testset "pairwise column block sums and pairwise_sum: $shape, trailing $trailing, $T into $A" for
                    (shape, n, bs, every_type) in BLOCK_SHAPES, trailing in EDGE_TRAILING, (T, A) in PAIRWISE_TYPES
                ((every_type && trailing == first(EDGE_TRAILING)) || (T, A) == first(PAIRWISE_TYPES)) || continue
                xs = edge_columns(T, n, trailing)
                reference = Array{A}(undef, cld(n, bs), trailing...)
                for c in CartesianIndices(trailing)
                    reference[:, c] = block_reference(A, xs[:, c], bs)
                end
                xs_b = Backends.on(xs, backend)
                partials = Reductions.pairwise_block_sums(A, xs_b, backend; blocksize = bs)
                @test eltype(partials) === A
                @test edge_bytes(partials) == edge_bytes(reference)
                @test edge_bytes(Reductions.pairwise_sum(A, xs_b, backend; blocksize = bs)) ==
                      edge_bytes([Reductions.combine_tree(reference[:, c]) for c in CartesianIndices(trailing)])
            end

            @testset "positive control: the first element of a segment and the last cell of a column each move exactly their own segment of their own column" begin
                starts = [1, 17, 33, 49, 65, 70]
                n, nseg = last(starts) - 1, length(starts) - 1
                xs, weights = edge_columns(Float64, n, (3,)), edge_areas(Float64, n)
                reduce_columns(v) = begin
                    v_b, w_b = Backends.on(v, backend), Backends.on(weights, backend)
                    seg = Reductions.Segmentation(v_b, Backends.on(starts, backend))
                    [Backends.on(r, Backends.CPU(1)) for r in (Reductions.segmented_sum(Float64, v_b, seg, backend),
                                                               Reductions.segmented_weighted_sum(Float64, v_b, w_b, seg, backend),
                                                               Reductions.segmented_mean(Float64, v_b, seg, w_b, backend),
                                                               Reductions.pairwise_block_sums(Float64, v_b, backend; blocksize = 16))]
                end
                base = reduce_columns(xs)
                for (index, column, segment) in ((starts[2], 2, 2), (n, 3, nseg))
                    moved = copy(xs)
                    moved[index, column] += 1.0
                    for (b, m) in zip(base, reduce_columns(moved))
                        @test findall(m .!= b) == [CartesianIndex(segment, column)]
                    end
                end
            end

            @testset "segmented_quantile over columns: $shape, trailing $trailing, $T" for
                    (shape, k, nseg) in QUANTILE_SHAPES, trailing in EDGE_TRAILING[2:end], T in (Float64, Int)
                seglen = 4^k
                n = nseg * seglen
                xs = T === Int ? reshape(Int[mod(i * 7919 + 13, 251) - 125 for i in 1:(n * prod(trailing))], n, trailing...) :
                     edge_columns(T, n, trailing)
                starts = collect(1:seglen:(n + 1))
                xs_b = Backends.on(xs, backend)
                segmentation = Reductions.Segmentation(xs_b, Backends.on(starts, backend))
                result = Reductions.segmented_quantile(xs_b, segmentation, 0.5, backend)
                @test eltype(result) === T
                @test size(result) == (nseg, trailing...)
                @test edge_bytes(result) == edge_bytes(Reductions.segmented_quantile_reference(xs, starts, 0.5))
            end

            @testset "positive control: the first element of a segment and the last cell of a column each move exactly their own segment's maximum in their own column" begin
                k, nseg = 2, 4
                seglen = 4^k
                n = nseg * seglen
                xs = edge_columns(Float64, n, (3,))
                starts = collect(1:seglen:(n + 1))
                top(v) = Backends.on(Reductions.segmented_quantile(Backends.on(v, backend),
                                                                    Backends.on(starts, backend), 1.0, backend),
                                     Backends.CPU(1))
                base = top(xs)
                for (index, column, segment) in ((seglen + 1, 2, 2), (n, 3, nseg))
                    moved = copy(xs)
                    moved[index, column] = 10.0
                    @test findall(top(moved) .!= base) == [CartesianIndex(segment, column)]
                end
            end

            @testset "segmented class kernels: $shape, labels of trailing shape $trailing, $TW weights into $A" for
                    (shape, starts, has_mean) in SEGMENT_SHAPES, trailing in CLASS_EDGE_TRAILING, (TW, A) in CLASS_EDGE_TYPES
                (trailing == first(CLASS_EDGE_TRAILING) || (TW, A) == first(CLASS_EDGE_TYPES)) || continue
                n = last(starts) - 1
                legend = CLASS_EDGE_LEGEND
                labels = ReductionFixtures.seeded_labels(n, trailing, legend)
                weights, signed = edge_areas(TW, n), edge_elements(TW, n)
                host = Reductions.ClassIndicator{A}(labels, legend, Backends.CPU())
                indicator = Reductions.ClassIndicator{A}(labels, legend, backend)
                segmentation = Reductions.Segmentation(indicator, Backends.on(starts, backend))
                signed_b = Backends.on(signed, backend)
                sums = Reductions.segmented_weighted_sum(A, indicator, signed_b, segmentation, backend)
                @test eltype(sums) === A
                @test size(sums) == (length(starts) - 1, trailing..., length(legend))
                @test edge_bytes(sums) == edge_bytes(Reductions.segmented_weighted_sum_reference(A, host, signed, starts))
                @test edge_bytes(Reductions.segmented_weighted_sum(A, indicator, Reductions.AbsoluteValues(signed_b),
                                                                  segmentation, backend)) ==
                      edge_bytes(Reductions.segmented_weighted_sum_reference(A, host, Reductions.AbsoluteValues(signed),
                                                                            starts))
                if has_mean
                    @test edge_bytes(Reductions.segmented_mean(A, indicator, segmentation, Backends.on(weights, backend),
                                                               backend)) ==
                          edge_bytes(Reductions.segmented_mean_reference(A, host, starts, weights))
                else
                    @test_throws Verdicts.Refusal Reductions.segmented_mean(A, indicator, segmentation,
                                                                             Backends.on(weights, backend), backend)
                end
            end

            @testset "positive control: a label changed at the first cell of a segment or the last cell of a column moves exactly its own segment of its own column in the class it left and the class it joined" begin
                starts = [1, 17, 33, 49, 65, 70]
                n, nseg = last(starts) - 1, length(starts) - 1
                legend = CLASS_EDGE_LEGEND
                weights = edge_areas(Float64, n)
                labels = ReductionFixtures.seeded_labels(n, (3,), legend)
                reduce_classes(l) = begin
                    indicator = Reductions.ClassIndicator{Float64}(l, legend, backend)
                    w_b = Backends.on(weights, backend)
                    seg = Reductions.Segmentation(indicator, Backends.on(starts, backend))
                    [Backends.on(r, Backends.CPU(1)) for r in (Reductions.segmented_weighted_sum(Float64, indicator, w_b, seg, backend),
                                                               Reductions.segmented_mean(Float64, indicator, seg, w_b, backend))]
                end
                base = reduce_classes(labels)
                for (index, column, segment) in ((starts[2], 2, 2), (n, 3, nseg))
                    left = findfirst(==(labels[index, column]), legend)
                    joined = mod1(left + 1, length(legend))
                    moved = copy(labels)
                    moved[index, column] = legend[joined]
                    for (b, m) in zip(base, reduce_classes(moved))
                        @test findall(m .!= b) ==
                              sort([CartesianIndex(segment, column, left), CartesianIndex(segment, column, joined)])
                    end
                end
            end
        end
    end
end

@testset "each eliding kernel's door refuses an argument one element short (decision 0055)" begin
    @test CUDA.functional()

    for (bname, backend) in EDGE_BACKENDS
        @testset "$bname" begin
            on_b(v) = Backends.on(v, backend)

            @testset "Reductions.launch_block_sums!" begin
                n = 2 * EDGE_B + 5
                nb = cld(n, EDGE_B)
                xs, areas, x = on_b(edge_elements(Float64, n)), on_b(edge_areas(Float64, n)), 0.0
                pairwise(partials, inputs) =
                    () -> Reductions.launch_block_sums!(Reductions.pairwise_block_kernel!,
                                                        Reductions.pairwise_block_shared_kernel!, backend,
                                                        partials, n, EDGE_B, 1, inputs)
                weighted(partials, inputs) =
                    () -> Reductions.launch_block_sums!(Reductions.area_weighted_block_kernel!,
                                                        Reductions.area_weighted_block_shared_kernel!, backend,
                                                        partials, n, EDGE_B, 1, inputs)
                fraction(partials, inputs) =
                    () -> Reductions.launch_block_sums!(Reductions.area_fraction_block_kernel!,
                                                        Reductions.area_fraction_block_shared_kernel!, backend,
                                                        partials, n, EDGE_B, 2, inputs)

                @testset "matched arguments launch and agree with the reference" begin
                    partials = similar(xs, Float64, nb)
                    @test refusal_of(pairwise(partials, (xs = xs,))) === nothing
                    @test edge_bytes(partials) ==
                          edge_bytes(block_reference(Float64, Backends.on(xs, Backends.CPU(1)), EDGE_B))
                    @test refusal_of(weighted(similar(xs, Float64, nb), (xs = xs, areas = areas, x = x))) === nothing
                    @test refusal_of(fraction(similar(xs, Float64, nb, 2), (xs = xs, areas = areas, x = x))) === nothing
                end

                for (what, call, name, got, expected) in (
                        ("partials one row short", pairwise(similar(xs, Float64, nb - 1), (xs = xs,)),
                         "partials", "$(nb - 1) rows", "have $nb"),
                        ("xs one element short", pairwise(similar(xs, Float64, nb), (xs = xs[1:n-1],)),
                         "xs", "length $(n - 1)", "read $n"),
                        ("areas one element short", weighted(similar(xs, Float64, nb), (xs = xs, areas = areas[1:n-1], x = x)),
                         "areas", "length $(n - 1)", "read $n"),
                        ("xs one element short beside areas", fraction(similar(xs, Float64, nb, 2), (xs = xs[1:n-1], areas = areas, x = x)),
                         "xs", "length $(n - 1)", "read $n"),
                        ("partials one column short", fraction(similar(xs, Float64, nb, 1), (xs = xs, areas = areas, x = x)),
                         "partials", "size ($nb, 1)", "2 column(s)"))
                    @testset "$what refuses, naming the array and both lengths" begin
                        caught = refusal_of(call)
                        @test caught isa Verdicts.Refusal
                        @test caught.site == "Reductions.launch_block_sums!"
                        @test occursin("$name has", caught.reason)
                        @test occursin(got, caught.reason)
                        @test occursin(expected, caught.reason)
                    end
                end
            end

            @testset "Reductions.launch_segments!" begin
                starts = [1, 17, 33, 49, 65, 70]
                n, nseg = last(starts) - 1, length(starts) - 1
                xs_h, weights_h = edge_elements(Float64, n), edge_areas(Float64, n)
                xs, weights = on_b(xs_h), on_b(weights_h)
                segmentation = Reductions.Segmentation(xs, on_b(starts))
                lo, hi = segmentation.lo, segmentation.hi
                mean_call(out, zeroflag, xs, weights, lo, hi) =
                    () -> Reductions.launch_segments!(Reductions.segmented_mean_kernel!, backend, n, nseg,
                                                      (out = out, zeroflag = zeroflag), (xs = xs, weights = weights),
                                                      lo, hi, "edge shapes")

                @testset "matched arguments launch and agree with the reference" begin
                    out, zeroflag = similar(xs, Float64, nseg), similar(xs, Bool, nseg)
                    @test refusal_of(mean_call(out, zeroflag, xs, weights, lo, hi)) === nothing
                    @test edge_bytes(out) == edge_bytes(Reductions.segmented_mean_reference(Float64, xs_h, starts, weights_h))
                end

                for (name, args, got, expected) in (
                        ("out", (similar(xs, Float64, nseg - 1), similar(xs, Bool, nseg), xs, weights, lo, hi),
                         nseg - 1, "$nseg segments"),
                        ("zeroflag", (similar(xs, Float64, nseg), similar(xs, Bool, nseg - 1), xs, weights, lo, hi),
                         nseg - 1, "$nseg segments"),
                        ("xs", (similar(xs, Float64, nseg), similar(xs, Bool, nseg), xs[1:n-1], weights, lo, hi),
                         n - 1, "$n elements"),
                        ("weights", (similar(xs, Float64, nseg), similar(xs, Bool, nseg), xs, weights[1:n-1], lo, hi),
                         n - 1, "$n elements"),
                        ("lo", (similar(xs, Float64, nseg), similar(xs, Bool, nseg), xs, weights, lo[1:nseg-1], hi),
                         nseg - 1, "$nseg segments"),
                        ("hi", (similar(xs, Float64, nseg), similar(xs, Bool, nseg), xs, weights, lo, hi[1:nseg-1]),
                         nseg - 1, "$nseg segments"))
                    @testset "$name one element short refuses, naming the array and both lengths" begin
                        caught = refusal_of(mean_call(args...))
                        @test caught isa Verdicts.Refusal
                        @test caught.site == "edge shapes"
                        @test occursin("$name has length $got", caught.reason)
                        @test occursin(expected, caught.reason)
                    end
                end
            end

            @testset "Reductions.launch_segment_columns!" begin
                starts = [1, 17, 33, 49, 65, 70]
                n, nseg, ncol = last(starts) - 1, length(starts) - 1, 3
                xs_h, weights_h = edge_columns(Float64, n, (ncol,)), edge_areas(Float64, n)
                xs, weights = on_b(xs_h), on_b(weights_h)
                segmentation = Reductions.Segmentation(xs, on_b(starts))
                lo, hi = segmentation.lo, segmentation.hi
                column_mean_call(out, zeroflag, xs, weights, lo, hi) =
                    () -> Reductions.launch_segment_columns!(Reductions.segmented_column_mean_kernel!, backend, n, nseg,
                                                             ncol, (out = out, zeroflag = zeroflag), (xs = xs,),
                                                             (weights = weights,), lo, hi, "edge shapes")

                @testset "matched arguments launch and agree with the reference" begin
                    out, zeroflag = similar(xs, Float64, nseg, ncol), similar(xs, Bool, nseg, ncol)
                    @test refusal_of(column_mean_call(out, zeroflag, xs, weights, lo, hi)) === nothing
                    @test edge_bytes(out) ==
                          edge_bytes(Reductions.segmented_mean_reference(Float64, xs_h, starts, weights_h))
                end

                out, zeroflag = similar(xs, Float64, nseg, ncol), similar(xs, Bool, nseg, ncol)
                for (what, args, got, expected) in (
                        ("out one row short", (similar(xs, Float64, nseg - 1, ncol), zeroflag, xs, weights, lo, hi),
                         "out has size ($(nseg - 1), $ncol)", "$nseg segments of $ncol column(s)"),
                        ("out one column short", (similar(xs, Float64, nseg, ncol - 1), zeroflag, xs, weights, lo, hi),
                         "out has size ($nseg, $(ncol - 1))", "$nseg segments of $ncol column(s)"),
                        ("zeroflag one row short", (out, similar(xs, Bool, nseg - 1, ncol), xs, weights, lo, hi),
                         "zeroflag has size ($(nseg - 1), $ncol)", "$nseg segments of $ncol column(s)"),
                        ("xs one row short", (out, zeroflag, xs[1:n-1, :], weights, lo, hi),
                         "xs has size ($(n - 1), $ncol)", "$n elements of $ncol column(s)"),
                        ("xs one column short", (out, zeroflag, xs[:, 1:ncol-1], weights, lo, hi),
                         "xs has size ($n, $(ncol - 1))", "$n elements of $ncol column(s)"),
                        ("weights one element short", (out, zeroflag, xs, weights[1:n-1], lo, hi),
                         "weights has length $(n - 1)", "$n elements"),
                        ("lo one element short", (out, zeroflag, xs, weights, lo[1:nseg-1], hi),
                         "lo has length $(nseg - 1)", "$nseg segments"),
                        ("hi one element short", (out, zeroflag, xs, weights, lo, hi[1:nseg-1]),
                         "hi has length $(nseg - 1)", "$nseg segments"))
                    @testset "$what refuses, naming the array and both extents" begin
                        caught = refusal_of(column_mean_call(args...))
                        @test caught isa Verdicts.Refusal
                        @test caught.site == "edge shapes"
                        @test occursin(got, caught.reason)
                        @test occursin(expected, caught.reason)
                    end
                end
            end

            @testset "Reductions.launch_column_block_sums!" begin
                n, ncol = 2 * EDGE_B + 5, 3
                nb = cld(n, EDGE_B)
                xs_h = edge_columns(Float64, n, (ncol,))
                xs = on_b(xs_h)
                column_blocks_call(partials, xs, blocksize) =
                    () -> Reductions.launch_column_block_sums!(backend, partials, xs, blocksize)

                @testset "matched arguments launch and agree with the reference" begin
                    partials = similar(xs, Float64, nb, ncol)
                    @test refusal_of(column_blocks_call(partials, xs, EDGE_B)) === nothing
                    @test edge_bytes(partials) ==
                          edge_bytes(reduce(hcat, [block_reference(Float64, xs_h[:, c], EDGE_B) for c in 1:ncol]))
                end

                for (what, args, got, expected) in (
                        ("partials one row short", (similar(xs, Float64, nb - 1, ncol), xs, EDGE_B),
                         "partials has size ($(nb - 1), $ncol)", "have ($nb, $ncol)"),
                        ("partials one column short", (similar(xs, Float64, nb, ncol - 1), xs, EDGE_B),
                         "partials has size ($nb, $(ncol - 1))", "have ($nb, $ncol)"),
                        ("xs one column short of partials", (similar(xs, Float64, nb, ncol), xs[:, 1:ncol-1], EDGE_B),
                         "partials has size ($nb, $ncol)", "have ($nb, $(ncol - 1))"),
                        ("xs without a column axis", (similar(xs, Float64, nb, ncol), vec(xs), EDGE_B),
                         "xs has size ($(n * ncol),)", "not (elements, columns)"),
                        ("a blocksize of zero", (similar(xs, Float64, nb, ncol), xs, 0),
                         "blocksize 0", "not positive"))
                    @testset "$what refuses, naming the array and both extents" begin
                        caught = refusal_of(column_blocks_call(args...))
                        @test caught isa Verdicts.Refusal
                        @test caught.site == "Reductions.launch_column_block_sums!"
                        @test occursin(got, caught.reason)
                        @test occursin(expected, caught.reason)
                    end
                end
            end

            @testset "Reductions.launch_quantiles!" begin
                k, nseg, ncol = 1, 3, 2
                seglen = 4^k
                n = nseg * seglen
                xs_h = edge_columns(Float64, n, (ncol,))
                starts = collect(1:seglen:(n + 1))
                xs = on_b(xs_h)
                base = Reductions.Segmentation(xs, on_b(starts)).lo .- 1
                partner, ascending = Reductions.device_bitonic_network(backend, k)
                rank = Reductions.quantile_rank(seglen, 0.5)
                call(k, out, xs, base, rank, partner, ascending) =
                    () -> Reductions.launch_quantiles!(backend, k, nseg, out, xs, base, rank, partner, ascending)

                @testset "matched arguments launch and agree with the reference" begin
                    out = similar(xs, nseg, ncol)
                    @test refusal_of(call(k, out, xs, base, rank, partner, ascending)) === nothing
                    @test edge_bytes(out) == edge_bytes(Reductions.segmented_quantile_reference(xs_h, starts, 0.5))
                end

                out = similar(xs, nseg, ncol)
                for (what, args, expected) in (
                        ("out one row short", (k, similar(xs, nseg - 1, ncol), xs, base, rank, partner, ascending),
                         ["out has size ($(nseg - 1), $ncol)", "need ($nseg, $ncol)"]),
                        ("out one column short", (k, similar(xs, nseg, ncol - 1), xs, base, rank, partner, ascending),
                         ["out has size ($nseg, $(ncol - 1))", "need ($nseg, $ncol)"]),
                        ("base one element short", (k, out, xs, base[1:nseg-1], rank, partner, ascending),
                         ["base has length $(nseg - 1)", "need $nseg"]),
                        ("xs one row short", (k, out, xs[1:n-1, :], base, rank, partner, ascending),
                         ["xs has size ($(n - 1), $ncol)", "need ($n, $ncol)"]),
                        ("xs without a column axis", (k, out, vec(xs), base, rank, partner, ascending),
                         ["xs has size ($(n * ncol),)", "not (elements, columns)"]),
                        ("partner one row short", (k, out, xs, base, rank, partner[1:seglen-1, :], ascending),
                         ["partner has size ($(seglen - 1), ", "size ($seglen, "]),
                        ("ascending one row short", (k, out, xs, base, rank, partner, ascending[1:seglen-1, :]),
                         ["ascending has size ($(seglen - 1), ", "size ($seglen, "]),
                        ("rank one past the segment", (k, out, xs, base, seglen + 1, partner, ascending),
                         ["rank $(seglen + 1)", "1:$seglen"]),
                        ("rank one below the segment", (k, out, xs, base, 0, partner, ascending),
                         ["rank 0", "1:$seglen"]),
                        ("k above the declared range", (Reductions.QUANTILE_K_MAX + 1, out, xs, base, rank,
                                                        partner, ascending),
                         ["k=$(Reductions.QUANTILE_K_MAX + 1)"]))
                    @testset "$what refuses, naming it and both bounds" begin
                        caught = refusal_of(call(args...))
                        @test caught isa Verdicts.Refusal
                        @test caught.site == "Reductions.launch_quantiles!"
                        for text in expected
                            @test occursin(text, caught.reason)
                        end
                    end
                end
            end

            @testset "Reductions.launch_segment_classes!" begin
                starts = [1, 17, 33, 49, 65, 70]
                n, nseg, ncol = last(starts) - 1, length(starts) - 1, 3
                legend = CLASS_EDGE_LEGEND
                nclass = length(legend)
                labels = ReductionFixtures.seeded_labels(n, (ncol,), legend)
                weights_h = edge_areas(Float64, n)
                indicator = Reductions.ClassIndicator{Float64}(labels, legend, backend)
                positions, weights = indicator.positions, on_b(weights_h)
                segmentation = Reductions.Segmentation(indicator, on_b(starts))
                lo, hi = segmentation.lo, segmentation.hi
                class_mean_call(out, zeroflag, positions, weights, lo, hi) =
                    () -> Reductions.launch_segment_classes!(Reductions.segmented_class_mean_kernel!, backend, n, nseg,
                                                             ncol, nclass, (out = out, zeroflag = zeroflag), positions,
                                                             weights, lo, hi, false, "edge shapes")

                @testset "matched arguments launch and agree with the reference" begin
                    out = similar(positions, Float64, nseg, ncol, nclass)
                    zeroflag = similar(positions, Bool, nseg, ncol, nclass)
                    @test refusal_of(class_mean_call(out, zeroflag, positions, weights, lo, hi)) === nothing
                    @test edge_bytes(out) ==
                          edge_bytes(Reductions.segmented_mean_reference(
                              Float64, Reductions.ClassIndicator{Float64}(labels, legend, Backends.CPU()), starts, weights_h))
                end

                out = similar(positions, Float64, nseg, ncol, nclass)
                zeroflag = similar(positions, Bool, nseg, ncol, nclass)
                outputs = "$nseg segments of $ncol column(s) and $nclass class(es)"
                for (what, args, got, expected) in (
                        ("out one row short", (similar(positions, Float64, nseg - 1, ncol, nclass), zeroflag, positions,
                                               weights, lo, hi),
                         "out has size ($(nseg - 1), $ncol, $nclass)", outputs),
                        ("out one column short", (similar(positions, Float64, nseg, ncol - 1, nclass), zeroflag, positions,
                                                  weights, lo, hi),
                         "out has size ($nseg, $(ncol - 1), $nclass)", outputs),
                        ("out one class short", (similar(positions, Float64, nseg, ncol, nclass - 1), zeroflag, positions,
                                                 weights, lo, hi),
                         "out has size ($nseg, $ncol, $(nclass - 1))", outputs),
                        ("zeroflag one class short", (out, similar(positions, Bool, nseg, ncol, nclass - 1), positions,
                                                      weights, lo, hi),
                         "zeroflag has size ($nseg, $ncol, $(nclass - 1))", outputs),
                        ("positions one row short", (out, zeroflag, positions[1:n-1, :], weights, lo, hi),
                         "positions has size ($(n - 1), $ncol)", "$n elements of $ncol column(s)"),
                        ("positions one column short", (out, zeroflag, positions[:, 1:ncol-1], weights, lo, hi),
                         "positions has size ($n, $(ncol - 1))", "$n elements of $ncol column(s)"),
                        ("weights one element short", (out, zeroflag, positions, weights[1:n-1], lo, hi),
                         "weights has length $(n - 1)", "$n elements"),
                        ("lo one element short", (out, zeroflag, positions, weights, lo[1:nseg-1], hi),
                         "lo has length $(nseg - 1)", "$nseg segments"),
                        ("hi one element short", (out, zeroflag, positions, weights, lo, hi[1:nseg-1]),
                         "hi has length $(nseg - 1)", "$nseg segments"))
                    @testset "$what refuses, naming the array and both extents" begin
                        caught = refusal_of(class_mean_call(args...))
                        @test caught isa Verdicts.Refusal
                        @test caught.site == "edge shapes"
                        @test occursin(got, caught.reason)
                        @test occursin(expected, caught.reason)
                    end
                end
            end
        end
    end
end
