# The counter-based generator: docs/plans/fiddlybits-52v.6-provenance.md, section
# "The generator", decisions 0010 and 0029.
#
# Salmon, J. K., Moraes, M. A., Dror, R. O., Shaw, D. E. "Parallel random numbers:
# as easy as 1, 2, 3." references/pdf/salmon2011-parallel-random-numbers-easy-1.pdf
# (references/text/salmon2011-parallel-random-numbers-easy-1/0006.txt and 0007.txt
# hold the OCR text cited below). Page 7 gives the Philox-4x32 multipliers and the
# N=4 box wiring (footnote 10); page 6 gives the general Weyl round-key sequence of
# its equation 6; page 9 recommends ten rounds for a GPU generator, three past the
# seven rounds its Crush battery finds sufficient on page 7. The Philox-4x32-10
# bijection below is checked against the Random123 reference implementation's
# published known-answer vectors in test/provenance/rng.jl.

using ..Verdicts: refuse
using ..Backends: Backend, launch!
using KernelAbstractions: @kernel, @index

"""
    PHILOX4X32_M0
    PHILOX4X32_M1

The two Philox-4x32 multipliers Salmon et al. 2011 report on page 7: the
pair their avalanche search converged to and their Crush battery confirmed
at seven rounds, applied to the first and third counter words respectively.
"""
const PHILOX4X32_M0 = 0xD2511F53
const PHILOX4X32_M1 = 0xCD9E8D57

"""
    PHILOX4X32_W0
    PHILOX4X32_W1

The two 32-bit Weyl round-key increments: the leading 32 bits of the
golden-ratio and sqrt(3)-1 constants Salmon et al. 2011 give on page 6 for
the general round-key sequence of their equation 6, truncated to the 32-bit
key half Philox-4x32 carries.
"""
const PHILOX4X32_W0 = 0x9E3779B9
const PHILOX4X32_W1 = 0xBB67AE85

"""
    PHILOX4X32_ROUNDS

Ten: the safety-margin round count Salmon et al. 2011 recommend for a GPU
generator on page 9, three more than the seven rounds their Crush battery
finds sufficient on page 7.
"""
const PHILOX4X32_ROUNDS = 10

"""
    mulhilo(a, b)

`(lo, hi)`, the low and high 32 bits of the 64-bit product of `a` and `b`.
"""
@inline function mulhilo(a::UInt32, b::UInt32)
    p = widemul(a, b)
    return (p % UInt32, (p >> 32) % UInt32)
end

"""
    philox4x32_round(ctr, key)

One Philox-4x32 round: the multiply-based S-box of Salmon et al. 2011's
equations for `Bk` and `Fk` (page 7), applied to both halves of `ctr` and
combined by the swap between the two S-boxes their footnote 10 names.
"""
@inline function philox4x32_round(ctr::NTuple{4,UInt32}, key::NTuple{2,UInt32})
    lo0, hi0 = mulhilo(PHILOX4X32_M0, ctr[1])
    lo1, hi1 = mulhilo(PHILOX4X32_M1, ctr[3])
    return (hi1 ⊻ ctr[2] ⊻ key[1], lo1, hi0 ⊻ ctr[4] ⊻ key[2], lo0)
end

"""
    philox4x32_bumpkey(key)

The Weyl round-key update of equation 6: each half of `key` advanced by its
own constant, `PHILOX4X32_W0` and `PHILOX4X32_W1`.
"""
@inline philox4x32_bumpkey(key::NTuple{2,UInt32}) =
    (key[1] + PHILOX4X32_W0, key[2] + PHILOX4X32_W1)

"""
    philox4x32_10(ctr, key)

The Philox-4x32-10 bijection: `PHILOX4X32_ROUNDS` rounds of
`philox4x32_round`, `key` advanced by `philox4x32_bumpkey` between rounds and
left unbumped after the last.
"""
@inline function philox4x32_10(ctr::NTuple{4,UInt32}, key::NTuple{2,UInt32})
    for round in 1:PHILOX4X32_ROUNDS
        ctr = philox4x32_round(ctr, key)
        round == PHILOX4X32_ROUNDS || (key = philox4x32_bumpkey(key))
    end
    return ctr
end

"""
    checked_word(value, name, site)

`UInt32(value)`. Refuses at `site`, quantity `name`, when `value` is
negative or does not fit 32 bits.
"""
function checked_word(value::Integer, name::AbstractString, site::AbstractString)
    (0 <= value <= typemax(UInt32)) ||
        refuse(name, site, "$name $value does not fit the Philox-4x32 counter word 0 to $(typemax(UInt32))")
    return UInt32(value)
end

"""
    philox_key(root_seed)

The root seed folded into the two Philox-4x32 key words: the high and low 32
bits of `UInt64(root_seed)`.
"""
philox_key(root_seed::Integer) = ((UInt64(root_seed) >> 32) % UInt32, UInt64(root_seed) % UInt32)

"""
    philox_draw(root_seed, support_id, cell, process, time_index)

The Philox-4x32-10 output keyed on the five physical-identity integers of
decision 0010: `root_seed` folded into the key by `philox_key`, and
`support_id`, `cell`, `process` and `time_index` each one counter word, in
that order. A pure function: the same five integers give the same four
32-bit words whatever thread, partition or traversal order called it.
Refuses, quantity the one that failed, when `support_id`, `cell`, `process`
or `time_index` is negative or does not fit 32 bits.
"""
function philox_draw(root_seed::Integer, support_id::Integer, cell::Integer,
                      process::Integer, time_index::Integer)
    site = "Provenance.philox_draw"
    ctr = (checked_word(support_id, "support id", site), checked_word(cell, "cell", site),
           checked_word(process, "process", site), checked_word(time_index, "time index", site))
    return philox4x32_10(ctr, philox_key(root_seed))
end

"""
    philox_draw_kernel!(out, key, support_id, process, time_index, offset)

`out[i]` the Philox-4x32-10 output at counter word `cell = offset + i`, key
`key`, and the fixed counter words `support_id`, `process` and
`time_index`. The device form `philox_draw!` launches.
"""
@kernel function philox_draw_kernel!(out, key, support_id, process, time_index, offset)
    i = @index(Global)
    ctr = (support_id, UInt32(offset + i), process, time_index)
    out[i] = philox4x32_10(ctr, key)
end

"""
    philox_draw!(out, backend, root_seed, support_id, process, time_index; offset = 0)

`out[i]` set to `philox_draw(root_seed, support_id, offset + i, process,
time_index)` for every `i` in `1:length(out)`, launched on `backend`. The
same values whatever `backend`, `offset` or `length(out)` are, because each
entry is a pure function of its own global cell index and nothing else:
splitting the range differently, or running it on the other backend, cannot
move a single entry. Refuses, quantity the one that failed, when
`support_id`, `process`, `time_index`, `offset` or the highest cell index
`offset + length(out)` is negative or does not fit 32 bits.
"""
function philox_draw!(out::AbstractVector{NTuple{4,UInt32}}, backend::Backend,
                       root_seed::Integer, support_id::Integer, process::Integer,
                       time_index::Integer; offset::Integer = 0)
    site = "Provenance.philox_draw!"
    n = length(out)
    key = philox_key(root_seed)
    support_word = checked_word(support_id, "support id", site)
    process_word = checked_word(process, "process", site)
    time_word = checked_word(time_index, "time index", site)
    checked_word(offset, "cell", site)
    checked_word(offset + n, "cell", site)
    launch!(philox_draw_kernel!, backend, n, out, key, support_word, process_word, time_word, Int(offset))
    return out
end

"""
    philox_draw_reference!(out, root_seed, support_id, process, time_index; offset = 0)

The naive serial reference for `philox_draw!` (decision 0027): the same
values, one cell at a time in index order, computed by `philox_draw`.
"""
function philox_draw_reference!(out::AbstractVector{NTuple{4,UInt32}}, root_seed::Integer,
                                 support_id::Integer, process::Integer, time_index::Integer;
                                 offset::Integer = 0)
    for i in eachindex(out)
        out[i] = philox_draw(root_seed, support_id, offset + i, process, time_index)
    end
    return out
end
