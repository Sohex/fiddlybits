# The ulp ensemble's site ordering is under a fiftieth of a per cent of the envelope it feeds, and sorting the whole site space to take 766 entries costs nothing worth removing

Measured on 2026-09-11 on yggdrasil, through `qrun -p light` (no GPU: `envelope` is a CPU
ensemble by decision 0029), Julia 1.12.7, Fiddlybits at branch `fiddlybits-52v.7.41`,
commit `b44da67c4094f499dad9ab3faaa52c66928630e0`.

`Backends.bit_reversed_order(n)` is `sortperm` over a vector of `n` reversed bit patterns,
and `Backends.envelope` then takes the first `ENSEMBLE_MEMBERS` of it. An external review
of the kernel layer observed that this allocates and sorts the whole site space to use 766
entries, and asked whether a site space of order a million makes that a cost. It does not.

## The ordering alone

| sites | time (s) | bytes allocated |
| --- | --- | --- |
| 20484 | 0.000673 | 491928 |
| 163842 | 0.007867 | 3944424 |
| 655362 | 0.040668 | 15729048 |
| 1310724 | 0.091907 | 31457688 |
| 10485762 | 1.053871 | 251670504 |

## Against the envelope it feeds

`Backends.envelope` on the icosahedral mesh case of `test/certify/mesh_fixture.jl`, at its
declared level, with the ordering's own time taken on the same site count:

| level | vertices | sites | envelope (s) | ordering (s) | ordering share |
| --- | --- | --- | --- | --- | --- |
| 5 | 10242 | 20484 | 2.969 | 0.000577 | 0.0194 per cent |

## Why the differing growth rates do not bite

`envelope` reruns the case's whole step `ENSEMBLE_MEMBERS` times per step of the envelope,
which is 766 by 20 for this case, and its cost grows with the site count through that
constant. The ordering is `n log n`. The ratio therefore moves only as `log n` against a
constant of 15320, so `log2(n)` would have to approach 15320 before the ordering's growth
rate could matter, and no mesh this project builds comes near that. At the largest site
count measured above, 10485762, the ordering takes 1.05 s where the same case's envelope
would take on the order of an hour by the measured scaling.

## What was not changed, and why

Nothing. The row that carries this observation, `fiddlybits-52v.7.37`, has two admissible
outcomes and this is the second: the cost is negligible at every site count this project
reaches, so the ordering stands as written.

There is also a trap in the change that was proposed. Sorting by the reversed bit pattern
is the bit-reversal permutation, with a closed form for the `k`-th element, only when `n`
is a power of two. A case's usable site count is whatever the case has and is not generally
a power of two, so a direct formula is not a drop-in replacement: it would have to
reproduce the existing order exactly or the sampled draw moves. The draw is asserted
bit for bit against the amplification vector recorded in
`notes/findings/2026-09-11-ulp-ensemble-member-count.md`, so moving it would mean
superseding that record, which is cheap but is not free and buys nothing here.
