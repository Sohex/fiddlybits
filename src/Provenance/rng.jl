# The counter-based generator: docs/plans/fiddlybits-52v.6-provenance.md, section
# "The generator", decisions 0010 and 0029.
#
# Salmon, J. K., Moraes, M. A., Dror, R. O., Shaw, D. E. "Parallel random numbers:
# as easy as 1, 2, 3." references/pdf/salmon2011-parallel-random-numbers-easy-1.pdf
# (references/text/salmon2011-parallel-random-numbers-easy-1/0006.txt, 0007.txt and
# 0008.txt hold the OCR text cited below). Page 7 gives the Philox-4x64 multipliers
# and the N=4 box wiring (footnote 10); page 6 gives the general Weyl round-key
# sequence of its equation 6, with the golden-ratio and sqrt(3)-1 constants at the
# same 64-bit width the Philox-4x64 key halves carry; page 8, Table 2, lists
# Philox4x64-10 as the safety-margin variant, three rounds past the seven the same
# table and page 7 give as the minimum for Crush-resistance. The Philox-4x64-10
# bijection below is checked against the Random123 reference implementation's
# published known-answer vectors in test/provenance/rng.jl.

using SHA: sha256
using ..Verdicts: refuse
using ..Backends: Backend, launch!
using ..Mesh: Support
using KernelAbstractions: @kernel, @index

"""
    PHILOX4X64_M0
    PHILOX4X64_M1

The two Philox-4x64 multipliers Salmon et al. 2011 report on page 7: the
pair their avalanche search converged to and their Crush battery confirmed
at seven rounds, applied to the first and third counter words respectively.
"""
const PHILOX4X64_M0 = 0xD2E7470EE14C6C93
const PHILOX4X64_M1 = 0xCA5A826395121157

"""
    PHILOX4X64_W0
    PHILOX4X64_W1

The two 64-bit Weyl round-key increments: the golden-ratio and sqrt(3)-1
constants Salmon et al. 2011 give on page 6 for the general round-key
sequence of their equation 6, at the 64-bit width Philox-4x64's key halves
carry.
"""
const PHILOX4X64_W0 = 0x9E3779B97F4A7C15
const PHILOX4X64_W1 = 0xBB67AE8584CAA73B

"""
    PHILOX4X64_ROUNDS

Ten: the safety-margin round count Table 2 on page 8 of Salmon et al. 2011
lists for Philox4x64-10, three more than the seven rounds the same table and
page 7 give as the minimum for Crush-resistance.
"""
const PHILOX4X64_ROUNDS = 10

"""
    mulhilo64(a, b)

`(lo, hi)`, the low and high 64 bits of the 128-bit product of `a` and `b`,
from the four 32-by-32-bit partial products of the schoolbook multiply.
"""
@inline function mulhilo64(a::UInt64, b::UInt64)
    a_lo, a_hi = a % UInt32, (a >> 32) % UInt32
    b_lo, b_hi = b % UInt32, (b >> 32) % UInt32
    lo_lo = UInt64(a_lo) * UInt64(b_lo)
    hi_lo = UInt64(a_hi) * UInt64(b_lo)
    lo_hi = UInt64(a_lo) * UInt64(b_hi)
    hi_hi = UInt64(a_hi) * UInt64(b_hi)
    mid = (lo_lo >> 32) + (hi_lo & 0x00000000ffffffff) + (lo_hi & 0x00000000ffffffff)
    lo = (lo_lo & 0x00000000ffffffff) | (mid << 32)
    hi = hi_hi + (hi_lo >> 32) + (lo_hi >> 32) + (mid >> 32)
    return (lo, hi)
end

"""
    philox4x64_round(ctr, key)

One Philox-4x64 round: the multiply-based S-box of Salmon et al. 2011's
equations for `Bk` and `Fk` (page 7, stated there for N=2 and carried to
64-bit words), applied to both halves of `ctr` and combined by the swap
between the two S-boxes their footnote 10 names.
"""
@inline function philox4x64_round(ctr::NTuple{4,UInt64}, key::NTuple{2,UInt64})
    lo0, hi0 = mulhilo64(PHILOX4X64_M0, ctr[1])
    lo1, hi1 = mulhilo64(PHILOX4X64_M1, ctr[3])
    return (hi1 ⊻ ctr[2] ⊻ key[1], lo1, hi0 ⊻ ctr[4] ⊻ key[2], lo0)
end

"""
    philox4x64_bumpkey(key)

The Weyl round-key update of equation 6: each half of `key` advanced by its
own constant, `PHILOX4X64_W0` and `PHILOX4X64_W1`.
"""
@inline philox4x64_bumpkey(key::NTuple{2,UInt64}) =
    (key[1] + PHILOX4X64_W0, key[2] + PHILOX4X64_W1)

"""
    philox4x64_10(ctr, key)

The Philox-4x64-10 bijection: `PHILOX4X64_ROUNDS` rounds of
`philox4x64_round`, `key` advanced by `philox4x64_bumpkey` between rounds and
left unbumped after the last.
"""
@inline function philox4x64_10(ctr::NTuple{4,UInt64}, key::NTuple{2,UInt64})
    for round in 1:PHILOX4X64_ROUNDS
        ctr = philox4x64_round(ctr, key)
        round == PHILOX4X64_ROUNDS || (key = philox4x64_bumpkey(key))
    end
    return ctr
end

"""
    checked_word(value, name, site)

`UInt64(value)`. Refuses at `site`, quantity `name`, when `value` is
negative.
"""
function checked_word(value::Integer, name::AbstractString, site::AbstractString)
    value >= 0 || refuse(name, site, "$name $value is negative")
    return UInt64(value)
end

"""
    big_endian_word(bytes, start)

The `UInt64` read from the eight bytes of `bytes` starting at the 1-based
index `start`, most significant byte first.
"""
function big_endian_word(bytes::AbstractVector{UInt8}, start::Integer)
    w = zero(UInt64)
    for i in start:(start + 7)
        w = (w << 8) | UInt64(bytes[i])
    end
    return w
end

"""
    philox_key128(root_seed, support_digest, process)
    philox_key128(root_seed, support::Support, process)

The 128-bit Philox-4x64 key: the first two big-endian `UInt64` words of the
SHA-256 digest over eight little-endian bytes of `UInt64(root_seed)`, the 32
bytes of `support_digest` (or `support.digest`), and eight little-endian
bytes of `UInt64(process)`. Refuses, quantity the one that failed, when
`root_seed` or `process` is negative.
"""
function philox_key128(root_seed::Integer, support_digest::NTuple{32,UInt8}, process::Integer)
    site = "Provenance.philox_key128"
    seed = checked_word(root_seed, "root seed", site)
    proc = checked_word(process, "process", site)
    io = IOBuffer()
    write(io, htol(seed))
    for b in support_digest
        write(io, b)
    end
    write(io, htol(proc))
    digest = sha256(take!(io))
    return (big_endian_word(digest, 1), big_endian_word(digest, 9))
end

philox_key128(root_seed::Integer, support::Support, process::Integer) =
    philox_key128(root_seed, support.digest, process)

"""
    philox_draw(root_seed, support_digest, cell, process, time_index, draw_index)
    philox_draw(root_seed, support::Support, cell, process, time_index, draw_index)

The Philox-4x64-10 output keyed on the physical identity of decision 0010:
the 128-bit key of `philox_key128` from `root_seed`, `support_digest` (or
`support.digest`) and `process`, and the counter `(cell, time_index,
draw_index, 0)`. A pure function: the same arguments give the same four
64-bit words whatever thread, partition or traversal order called it.
`draw_index` is the n-th draw within one cell and time index, so a caller
taking more than one draw there moves neither another caller's stream nor
another draw index of its own. Refuses, quantity the one that failed, when
`cell`, `time_index` or `draw_index` is negative.
"""
function philox_draw(root_seed::Integer, support_digest::NTuple{32,UInt8}, cell::Integer,
                      process::Integer, time_index::Integer, draw_index::Integer)
    site = "Provenance.philox_draw"
    ctr = (checked_word(cell, "cell", site), checked_word(time_index, "time index", site),
           checked_word(draw_index, "draw index", site), zero(UInt64))
    return philox4x64_10(ctr, philox_key128(root_seed, support_digest, process))
end

philox_draw(root_seed::Integer, support::Support, cell::Integer, process::Integer,
            time_index::Integer, draw_index::Integer) =
    philox_draw(root_seed, support.digest, cell, process, time_index, draw_index)

"""
    philox_draw_kernel!(out, key, time_index, draw_index, offset)

`out[i]` the Philox-4x64-10 output at counter word `cell = offset + i`, key
`key`, and the fixed counter words `time_index` and `draw_index`. The device
form `philox_draw!` launches.
"""
@kernel function philox_draw_kernel!(out, key, time_index, draw_index, offset)
    i = @index(Global)
    ctr = (offset + UInt64(i), time_index, draw_index, zero(UInt64))
    out[i] = philox4x64_10(ctr, key)
end

"""
    philox_draw!(out, backend, root_seed, support_digest, process, time_index, draw_index; offset = 0)
    philox_draw!(out, backend, root_seed, support::Support, process, time_index, draw_index; offset = 0)

`out[i]` set to `philox_draw(root_seed, support_digest, offset + i, process,
time_index, draw_index)` for every `i` in `1:length(out)`, launched on
`backend` with the key computed once on the host before the launch. The
same values whatever `backend`, `offset` or `length(out)` are, because each
entry is a pure function of its own global cell index and nothing else:
splitting the range differently, or running it on the other backend, cannot
move a single entry. Refuses, quantity the one that failed, when
`process`, `time_index`, `draw_index` or `offset` is negative.
"""
function philox_draw!(out::AbstractVector{NTuple{4,UInt64}}, backend::Backend,
                       root_seed::Integer, support_digest::NTuple{32,UInt8}, process::Integer,
                       time_index::Integer, draw_index::Integer; offset::Integer = 0)
    site = "Provenance.philox_draw!"
    n = length(out)
    key = philox_key128(root_seed, support_digest, process)
    time_word = checked_word(time_index, "time index", site)
    draw_word = checked_word(draw_index, "draw index", site)
    offset_word = checked_word(offset, "cell", site)
    launch!(philox_draw_kernel!, backend, n, out, key, time_word, draw_word, offset_word)
    return out
end

philox_draw!(out::AbstractVector{NTuple{4,UInt64}}, backend::Backend, root_seed::Integer,
             support::Support, process::Integer, time_index::Integer, draw_index::Integer;
             offset::Integer = 0) =
    philox_draw!(out, backend, root_seed, support.digest, process, time_index, draw_index; offset = offset)

"""
    philox_draw_reference!(out, root_seed, support_digest, process, time_index, draw_index; offset = 0)

The naive serial reference for `philox_draw!` (decision 0027): the same
values, one cell at a time in index order, computed by `philox_draw`.
"""
function philox_draw_reference!(out::AbstractVector{NTuple{4,UInt64}}, root_seed::Integer,
                                 support_digest::NTuple{32,UInt8}, process::Integer,
                                 time_index::Integer, draw_index::Integer; offset::Integer = 0)
    for i in eachindex(out)
        out[i] = philox_draw(root_seed, support_digest, offset + i, process, time_index, draw_index)
    end
    return out
end
