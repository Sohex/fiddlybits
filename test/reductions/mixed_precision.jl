using Test
using CUDA
using Fiddlybits: Reductions, Backends, Verdicts

# Decision 0056 and decision 0027: segmented_weighted_sum and segmented_mean
# against their references at every mix of Float32 and Float64 elements,
# weights and accumulator, on the CPU and on the GPU, and the right answer of
# a single-term segment computed at 256 bits.

const MIX_FLOATS = (Float32, Float64)
const MIXES = [(TX, TW, A) for TX in MIX_FLOATS for TW in MIX_FLOATS for A in MIX_FLOATS]

"""
    other_order_weighted_sum(A, xs, weights, starts)
    other_order_mean(A, xs, weights, starts)

The same accumulations with each product formed at the promoted type of its two
operands and then converted to `A`, on the host, one term at a time.
"""
function other_order_weighted_sum(::Type{A}, xs, weights, starts) where {A}
    out = Vector{A}(undef, length(starts) - 1)
    for s in eachindex(out)
        acc = zero(A)
        for j in starts[s]:starts[s+1]-1
            acc += A(Backends.nofuse_mul(xs[j], weights[j]))
        end
        out[s] = acc
    end
    return out
end

function other_order_mean(::Type{A}, xs, weights, starts) where {A}
    num = other_order_weighted_sum(A, xs, weights, starts)
    den = Reductions.segmented_sum_reference(A, weights, starts)
    return num ./ den
end

"""
    designed_pair(TX, TW, A)

One element and one weight, of types `TX` and `TW`. Into a `Float64`
accumulator both are `1 + 2^-23`. Into a `Float32` accumulator the element is
`1 + 2^-24` and the weight `1 + 2^-23` when both are `Float64`; otherwise each
`Float64` operand is `1 + 2^-24` and each `Float32` operand `1 + 2^-23`.
"""
function designed_pair(::Type{TX}, ::Type{TW}, ::Type{A}) where {TX,TW,A}
    wide = 1 + 2.0^-24
    narrow = 1 + 2.0^-23
    A === Float64 && return TX(narrow), TW(narrow)
    TX === Float64 && TW === Float64 && return TX(wide), TW(narrow)
    return TX(TX === Float64 ? wide : narrow), TW(TW === Float64 ? wide : narrow)
end

"`A`'s value nearest the 256-bit product of `a` and `b`."
product_at(::Type{A}, a, b) where {A} =
    A(BigFloat(a; precision = 256) * BigFloat(b; precision = 256))

"`A`'s value nearest the 256-bit quotient of `a` by `b`."
quotient_at(::Type{A}, a, b) where {A} =
    A(BigFloat(a; precision = 256) / BigFloat(b; precision = 256))

"`true` when converting to `A` and promoting the two operands give different types for the product."
orders_differ(TX, TW, A) = promote_type(TX, TW) !== A

@testset "segmented weighted reductions at every mix of Float32 and Float64 (decision 0056)" begin
    xs64 = ReductionFixtures.seeded_vector(Float64, ReductionFixtures.N)
    weights64 = abs.(xs64) .+ 0.1
    starts = ReductionFixtures.segment_starts(ReductionFixtures.N, ReductionFixtures.NSEG)
    cpu = Backends.CPU(8)

    @testset "a single-term segment is the 256-bit product rounded once in A" begin
        for (TX, TW, A) in MIXES
            x, w = designed_pair(TX, TW, A)
            xs, weights, one_seg = [x], [w], [1, 2]
            term = product_at(A, A(x), A(w))
            other_term = A(product_at(promote_type(TX, TW), x, w))
            mean = quotient_at(A, term, A(w))

            @testset "$TX elements, $TW weights, $A accumulator" begin
                @test Reductions.segmented_weighted_sum(A, xs, weights,
                                                       Reductions.Segmentation(xs, one_seg), cpu) == [term]
                @test Reductions.segmented_weighted_sum_reference(A, xs, weights, one_seg) == [term]
                @test Reductions.segmented_mean(A, xs, one_seg, weights, cpu) == [mean]
                @test Reductions.segmented_mean_reference(A, xs, one_seg, weights) == [mean]

                if orders_differ(TX, TW, A)
                    @testset "positive control: the other conversion order is a different answer" begin
                        @test other_term != term
                        @test other_order_weighted_sum(A, xs, weights, one_seg) == [other_term]
                        @test other_order_weighted_sum(A, xs, weights, one_seg) !=
                              Reductions.segmented_weighted_sum_reference(A, xs, weights, one_seg)
                        @test quotient_at(A, other_term, A(w)) != mean
                        @test other_order_mean(A, xs, weights, one_seg) !=
                              Reductions.segmented_mean_reference(A, xs, one_seg, weights)
                    end
                else
                    @test other_term == term
                end
            end
        end
    end

    @testset "CPU: each kernel is bitwise its reference" begin
        for (TX, TW, A) in MIXES
            xs, weights = TX.(xs64), TW.(weights64)
            segmentation = Reductions.Segmentation(xs, starts)
            @testset "$TX elements, $TW weights, $A accumulator" begin
                weighted = Reductions.segmented_weighted_sum(A, xs, weights, segmentation, cpu)
                weighted_reference = Reductions.segmented_weighted_sum_reference(A, xs, weights, starts)
                @test eltype(weighted) === A
                @test weighted == weighted_reference
                @test Reductions.segmented_weighted_sum_reference(A, xs, weights, segmentation) ==
                      weighted_reference

                mean = Reductions.segmented_mean(A, xs, segmentation, weights, cpu)
                mean_reference = Reductions.segmented_mean_reference(A, xs, starts, weights)
                @test eltype(mean) === A
                @test mean == mean_reference

                if orders_differ(TX, TW, A)
                    @testset "positive control: the other conversion order differs from the reference" begin
                        @test other_order_weighted_sum(A, xs, weights, starts) != weighted_reference
                        @test other_order_mean(A, xs, weights, starts) != mean_reference
                    end
                end
            end
        end
    end

    @testset "GPU: each kernel is bitwise its reference" begin
        @test CUDA.functional()
        gpu = Backends.GPU(8)
        for (TX, TW, A) in MIXES
            xs, weights = TX.(xs64), TW.(weights64)
            xs_gpu, weights_gpu = Backends.on(xs, gpu), Backends.on(weights, gpu)
            segmentation_gpu = Reductions.Segmentation(xs_gpu, Backends.on(starts, gpu))
            @testset "$TX elements, $TW weights, $A accumulator" begin
                weighted = Reductions.segmented_weighted_sum(A, xs_gpu, weights_gpu, segmentation_gpu, gpu)
                @test Backends.backend_of(weighted) === :gpu
                @test Backends.on(weighted, cpu) ==
                      Reductions.segmented_weighted_sum_reference(A, xs, weights, starts)

                mean = Reductions.segmented_mean(A, xs_gpu, segmentation_gpu, weights_gpu, gpu)
                @test Backends.backend_of(mean) === :gpu
                @test Backends.on(mean, cpu) == Reductions.segmented_mean_reference(A, xs, starts, weights)

                if orders_differ(TX, TW, A)
                    @testset "positive control: the other conversion order differs from the device result" begin
                        @test other_order_weighted_sum(A, xs, weights, starts) != Backends.on(weighted, cpu)
                        @test other_order_mean(A, xs, weights, starts) != Backends.on(mean, cpu)
                    end
                end
            end

            x, w = designed_pair(TX, TW, A)
            x_gpu, w_gpu = Backends.on([x], gpu), Backends.on([w], gpu)
            one_seg = Reductions.Segmentation(x_gpu, Backends.on([1, 2], gpu))
            term = product_at(A, A(x), A(w))
            @testset "$TX elements, $TW weights, $A accumulator: a single-term segment on the device" begin
                @test Backends.on(Reductions.segmented_weighted_sum(A, x_gpu, w_gpu, one_seg, gpu), cpu) == [term]
                @test Backends.on(Reductions.segmented_mean(A, x_gpu, one_seg, w_gpu, gpu), cpu) ==
                      [quotient_at(A, term, A(w))]
            end
        end
    end

    @testset "segmented_weighted_sum_reference refuses weights of another length" begin
        @test_throws Verdicts.Refusal Reductions.segmented_weighted_sum_reference(
            Float64, xs64, weights64[1:end-1], starts)
        @testset "positive control: weights of the same length do not refuse" begin
            @test Reductions.segmented_weighted_sum_reference(Float64, xs64, weights64, starts) isa Vector{Float64}
        end
    end
end
