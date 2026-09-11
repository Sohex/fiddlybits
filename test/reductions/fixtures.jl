# Shared synthetic inputs for the Reductions suite: fixed formulas so every
# run sees the same numbers, and no dependency on Mesh, which sits above
# this module.

module ReductionFixtures

const N = 4096
const NSEG = 64

"A vector of `n` values of type `T` from a fixed formula, not a random
draw, both signs, magnitude under 3."
seeded_vector(::Type{T}, n::Integer) where {T} = T[T(mod(i * 7919 + 13, 251)) / T(50) - T(2.5) for i in 1:n]

"`length(xs)` split into `nseg` contiguous, equal-as-possible segments as a
1-based CSR boundary array of length `nseg + 1`, `starts[1] == 1` and
`starts[end] == length(xs) + 1`."
function segment_starts(n::Integer, nseg::Integer)
    starts = Vector{Int}(undef, nseg + 1)
    for s in 1:(nseg + 1)
        starts[s] = 1 + round(Int, (s - 1) * n / nseg)
    end
    return starts
end

"The exact sum of `xs`, computed at 256-bit precision and rounded back to
`Float64`, the right answer `error_bound` is checked against."
exact_sum(xs::AbstractVector) = Float64(sum(BigFloat.(xs; precision = 256)))

"The `magnitude` `error_bound` requires (Higham 1993, eq. 2.6): the sum of
`xs`'s entries' absolute values, an upper bound on the same sum over any
sub-sequence of `xs`."
term_magnitude(xs::AbstractVector) = sum(abs, xs)

"A sequence of `nblocks` repeats of `(1.0e16, 1.0, -1.0e16, -1.0)`, whose
exact sum is `0.0`: every quadruple cancels. A single running accumulator
absorbs the `1.0` and `-1.0e16 - 1.0` in the same block, so its sequential
sum is `-1.0` regardless of `nblocks`, which makes any different result a
sign that the terms reached the accumulator in a different order."
function cancelling_quadruples(nblocks::Integer)
    xs = Vector{Float64}(undef, 4 * nblocks)
    for b in 0:(nblocks - 1)
        xs[4b + 1] = 1.0e16
        xs[4b + 2] = 1.0
        xs[4b + 3] = -1.0e16
        xs[4b + 4] = -1.0
    end
    return xs
end

"A `Float32` stock of `1.0f8` followed by `n` unit increments: the
stagnation case of decision 0029, whose exact total is `1.0e8 + n`."
stock_and_increments(::Type{T}, n::Integer) where {T} = vcat(T[T(1.0e8)], fill(T(1), n))

end # module ReductionFixtures
