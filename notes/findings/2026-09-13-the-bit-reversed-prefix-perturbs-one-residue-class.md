# The bit-reversed prefix perturbs one residue class of the site position, and a seeded draw reaches every one

Measured on 2026-09-13 on yggdrasil through `qrun -p light` (two threads, no GPU share),
Julia 1.12.7, Fiddlybits on branch `fiddlybits-wcv` cut from
`313cf97`. Every number below is exhaustive or deterministic except the miss frequencies,
which are counts over a named range of seeds and are stated against their exact
probability. The row is `fiddlybits-wcv`; the decision it informs is
`docs/decisions/0052-the-sampled-ensemble-is-a-seeded-draw.md`.

`notes/findings/2026-09-11-ulp-ensemble-member-count.md` sized the ensemble by
`(1 - p)^m`, a probability over a random draw, and took the members in the radix-2 van
der Corput order of the site position, which is not a draw. That record said the
probability was then over the position of the sub-population, which must not be
correlated with the order. This record measures where that condition fails, and what the
seeded draw that replaced the order does instead. It supersedes, in that finding, the row
"the member order" of the table "Every constant, with its disposition", and the last
paragraph of the section "What the ensemble cannot see", whose largest-gap numbers
describe the order and not the draw. It supersedes, in
`notes/findings/2026-09-12-ulp-ensemble-amplitude-and-injection-step.md`, the 20 values
recorded as the declared draw's signature in the section "The stand-in case at the two
amplitudes", and the draw column of the section "The sampling shortfall at the right
amplitude".

## Why the order has residue classes

For `n` sites the bit-reversed order sorts the zero-based positions `0:(n - 1)` by their
reversed bit pattern. Every even position sorts before every odd one, every position
divisible by four before the other even ones, and so on down. The first `m` entries are
therefore every position divisible by `2^k`, for the largest `k` that leaves at least `m`
of them, followed by part of the positions that are `2^(k - 1)` modulo `2^k`. That is an
identity of the order, and the table below is it evaluated.

## What each member set reaches

`m = 766` members. The stand-in case (`test/certify/fixtures.jl`) has 2048 usable sites
at `Float32`, two fields of 1024 cells. The real-mesh case (`test/certify/mesh_fixture.jl`,
level 5) has 20484, two fields of 10242 vertices. "Residues" is the number of residue
classes of the zero-based site position the member set holds a site of; the seeded draw
is `Backends.sampled_sites` under `Backends.ENSEMBLE_SEED = 0`.

| case | modulus | residues, bit-reversed prefix | residues, seeded draw |
|---|---|---|---|
| stand-in | 2 | 1 | 2 |
| stand-in | 4 | 2 | 4 |
| stand-in | 8 | 3 | 8 |
| stand-in | 16 | 6 | 16 |
| stand-in | 64 | 24 | 64 |
| mesh level 5 | 2 | 1 | 2 |
| mesh level 5 | 4 | 1 | 4 |
| mesh level 5 | 8 | 1 | 8 |
| mesh level 5 | 16 | 1 | 16 |
| mesh level 5 | 32 | 2 | 32 |
| mesh level 5 | 64 | 3 | 64 |

| case | distinct cells perturbed in any field, bit-reversed | seeded | largest gap in site position, bit-reversed | seeded |
|---|---|---|---|---|
| stand-in | 383 of 1024 | 625 of 1024 | 4 | 20 |
| mesh level 5 | 766 of 10242 | 749 of 10242 | 32 | 188 |

On the mesh case the bit-reversed prefix perturbs only site positions divisible by 16.
The second field starts at position 10242, which is 2 modulo 16, so in that field it
perturbs only the vertices at zero-based index 14 modulo 16. A sub-population on any other
residue class modulo 16, fifteen sixteenths of the case, is missed with certainty. On the
stand-in case the prefix perturbs only even positions, so neither field ever has a
vertex at an odd zero-based index perturbed, which in the `4^k` layout is the second and
fourth position of every quad.

The prefix bounds the largest gap and the draw does not. That is the one property the
order had that the draw gives up, and it is a statement about runs of consecutive
positions, which the draw covers as it covers any other sub-population.

## The miss frequency of the draw against its exact probability

The stand-in's 2048 usable sites, and a sub-population of the 8 sites at positions 1
modulo 256, which is relative size `1/256`, the declared `1 / ENSEMBLE_MISS_RATE_RECIPROCAL`,
placed where the bit-reversed prefix never reaches. A draw of `m` sites without
replacement misses 8 given sites with the hypergeometric probability
`prod_{k=0}^{7} (2048 - m - k) / (2048 - k)`.

| members | exact miss probability | seeds | misses | frequency | standard errors from exact |
|---|---|---|---|---|---|
| 766 | 0.023383286027824055 | 1 to 400 | 7 | 0.01750 | -0.78 |
| 766 | 0.023383286027824055 | 1 to 4000 | 89 | 0.02225 | -0.47 |
| 2 | 0.9922008579628724 | 1 to 400 | 394 | 0.9850 | |
| 2 | 0.9922008579628724 | 1 to 4000 | 3966 | 0.9915 | |

The bit-reversed prefix of 766 holds none of the 8, at every seed, because it has no
seed. The declared confidence is `1/20`; the with-replacement bound `(1 - 1/256)^766` sits
under it, and the exact without-replacement probability sits under that. The first row is
what `certify.sampled_draw_is_seeded` asserts, with a band of four standard errors, and
the two-member row is its positive control. One sub-population at one size is what this
measures of the assumption that digest order behaves as a uniform random permutation; it
is a check of that assumption's consequence and not a proof of it.

## What the seed moves

The stand-in case, 20 steps, at one `Float32` ulp. The exhaustive envelope over all 2048
sites divided by the envelope of each member set, worst over every entry, and worst over
the gains from step 0 alone. The two columns agree at every row because the case is linear
and stationary.

| member set | worst shortfall, gains from step 0 | worst shortfall, every injection step |
|---|---|---|
| bit-reversed prefix | 1.0872 | 1.0872 |
| seed 0, the declared seed | 1.0000 | 1.0000 |
| seed 1 | 1.0000 | 1.0000 |
| seed 2 | 1.0000 | 1.0000 |
| seed 3 | 1.0005 | 1.0005 |
| seed 4 | 1.0005 | 1.0005 |
| seed 5 | 1.0000 | 1.0000 |
| seed 6 | 1.0005 | 1.0005 |
| seed 7 | 1.0005 | 1.0005 |
| seed 8 | 1.0000 | 1.0000 |

On this case the seed moves the envelope by at most 5 parts in 10000 over nine seeds, and
every seed does better than the bit-reversed prefix, whose shortfall of 1.087 recorded in
the 2026-09-12 finding is reproduced here. The stand-in's high-amplification sites sit on
cells the prefix does not reach.

On the mesh case the declared draw holds none of the 24 degree-five sites and the
bit-reversed prefix held one. Neither is what covers them: the `DEGREE_FIVE` obligation's
exhaustive arm does, unchanged.

## The declared draw's signature

The stand-in case's gains from the initial state, `amplification[1, s]` for `s` from 1 to
20, under `ENSEMBLE_SEED`, which `certify.sampled_draw_is_unchanged` asserts bit for bit:

    1.537073343526572,  1.5369850533315912, 1.6662453915341757, 1.700109020457603,
    1.7335024176863953, 1.7417272574966773, 1.745736060431227,  1.7488743663416244,
    1.754974546842277,  1.764291615691036,  1.7780310197267681, 1.7947989981621504,
    1.8142512016929686, 1.8351148362271488, 1.856626014225185,  1.8779181980062276,
    1.8984275262337178, 1.9177005665842444, 1.935503300279379,  1.9527521666605026

Two envelopes measured one after the other on the case are bitwise identical.

## The cost

`Backends.sampled_sites` over the mesh case's 20484 usable sites takes 0.0106 s after a
warm call: one digest per site and one sort. A seeded envelope of the stand-in's 766
members over 20 steps took between 1.32 s and 1.74 s at two threads, and the exhaustive
one over 2048 sites 3.7 s, the first call carrying compilation. The draw is not where an
envelope's time goes.

## What was run

A probe in the session scratchpad, invoked from the worktree root as
`qrun -p light -- sh -c 'julia --startup-file=no --project=. -t "$SLURM_CPUS_PER_TASK" probe_draw.jl "$PWD"'`.
It includes `test/certify/fixtures.jl` and `test/certify/mesh_fixture.jl`, takes the
bit-reversed prefix as `sortperm([bitreverse(UInt64(j)) for j in 0:(n - 1)])[1:m]` (kept in
the suite as `CertifyFixtures.bit_reversed_prefix`), measures each envelope with
`Backends.measure_envelope` over the member set named, and counts misses with
`Backends.sampled_sites(usable, 2048, UInt64(s))` read at a prefix of 766 and of 2.
