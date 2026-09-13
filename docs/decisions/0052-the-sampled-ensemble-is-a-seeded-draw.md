+++
id = "0052"
title = "The sampled ulp ensemble is a seeded draw without replacement, keyed on site identity through SHA-256, and the envelope carries its seed"
status = "accepted"
date = 2026-09-13
amends = [{ record = "0029", what = "what the ulp ensemble's miss rate is a probability over: the members are a seeded draw, and the seed is stated in the registry beside the ensemble size and the miss rate" }]
+++

## Decision

**The miss rate is made true rather than re-described.** `Backends.detectable_miss_rate`
inverts `(1 - p)^m`, the probability that `m` sites drawn at random all miss a
sub-population of relative size `p`. A probability needs a draw to be over. The sampled
members of `Backends.envelope` are therefore drawn, not taken in a fixed order: the
usable sites are ordered by a key that is a pseudo-random function of a seed and of the
site, and the `m` sites with the smallest keys are the members. The miss rate is then a
probability over the seed, and it holds for every sub-population fixed without reference
to the seed.

**The key is the SHA-256 digest of the seed, the field and the cell.** The key is a
function of the site's identity and not of its position in the list, which is decision
0029's rule for stochastic streams applied to the draw: a site's key does not move when
another site becomes usable or unusable, and the order the list is built in cannot reach
the draw. The claim rests on one assumption, that ordering sites by digest behaves as a
uniformly random permutation would with respect to any sub-population not defined through
the digest. FIPS 180-4 does not state that property; it is the ordinary assumption on a
cryptographic digest, and the suite checks its consequence rather than resting on it:
`certify.sampled_draw_is_seeded` compares the miss frequency over an ensemble of seeds
with the exact hypergeometric probability.

**One declared seed, carried by the envelope and stated in the registry.** `ENSEMBLE_SEED`
is a module constant and the `Envelope` records it in a `seed` field, beside `perturbed`,
so an envelope carries both the member set and what reproduces it. The seed is
Irreducible in the sense of decision 0007: any value fixed independently of the cases it
serves is as good as any other, so no derivation exists, and what a different seed moves
is measured in
`notes/findings/2026-09-13-the-bit-reversed-prefix-perturbs-one-residue-class.md`. The
seed is not changed to move a verdict: a changed seed is a changed answer, and a seed
chosen after a certification was seen is a tuned value.

**The condition the probability carries is stated wherever the number is.** For one
fixed seed a given sub-population is held or missed; the probability is over the seed.
The condition that remains, that neither the case nor its sub-population is built from
the seed, is the anti-tuning condition decision 0025 already imposes, and it is stated in
`src/Backends/certify.jl` and in the registry rows the envelope serves.

## Alternatives considered

- *Keep the radix-2 van der Corput order and call the number a coverage heuristic, with
  its exchangeability condition stated.* This is the smaller change and its condition is
  honest. Lost, because the condition is one the project's own site lists break by
  construction. The first `m` positions of the bit-reversed order over `n` sites are the
  positions divisible by the largest power of two that leaves at least `m` of them,
  followed by part of the next residue class. A sub-population aligned with a power-of-two
  stride of the site list is therefore missed with certainty however large it is, and
  site lists have such strides because of how they are built: the fields of a case sit end
  to end at an offset of the cell count, a flattened column puts its layers at a fixed
  stride, and a `4^k` layout puts the positions within a quad at a stride of four. The
  finding measures the prefix reaching one residue class of the site position on the
  level-5 mesh case and only the even positions on the stand-in case. Re-describing the
  number would describe it correctly and leave the ensemble blind in exactly those
  places. The bounded largest gap the order gave, which is exact, is a statement about
  runs of consecutive sites; the draw covers such a run the way it covers any other
  sub-population, and a sub-population fixed in count rather than in share is an
  `Obligation`'s, unchanged by this record.
- *Draw through the project's counter-based generator (Philox, `fiddlybits-52v.6.5`).*
  Lost on placement and on need. The generator is planned in `Provenance`, which the
  skeleton plan's include order puts above `Backends`, so `src/Backends/certify.jl`
  cannot read it; moving the generator is that plan's question. And the draw needs no
  stream: one key per site, computed once per envelope, is what a digest already gives.
  SHA-256 is already a dependency of the package, used for the support identity and the
  artifact keys.
- *Draw with the `Random` standard library (`Xoshiro`, `randperm`).* Lost on
  reproducibility: the `Random` documentation reserves the right to change the stream a
  seed produces between Julia versions, so an envelope would move with a toolchain upgrade
  and no declared change. A SHA-256 digest is fixed by its standard.
- *Randomise the low-discrepancy order instead, by a random shift or a random digit
  scrambling.* Lost: either leaves the prefix a union of residue classes, so a
  sub-population on one residue class is still missed for a fixed share of seeds however
  large the class is, and the `(1 - p)^m` statement is still false.
- *A seed per case, derived from the case name.* Lost: renaming a case would move its
  envelope, and a name is not a declared input.
- *A seed as a required argument of `envelope` and `case_certification`.* Lost: every
  caller would choose a seed, which reopens the choice after a result has been seen at
  every call site. One declared seed, recorded in the envelope, keeps it a single visible
  input.
- *Store the sampled sites alone, without a seed.* Lost: `perturbed` already stores the
  sites, and a site list alone does not say what distribution it came from, which is the
  whole content of the miss rate.

## Consequences

- `src/Backends/certify.jl` carries `ENSEMBLE_SEED`, `draw_key`, `sampled_sites` and an
  `Envelope.seed` field that is `nothing` when no draw was taken; `bit_reversed_order` is
  removed, and the test fixtures keep the bit-reversed prefix as the control the draw is
  held against.
- `ENSEMBLE_MISS_RATE`, `detectable_miss_rate`, `ENSEMBLE_CONFIDENCE_RECIPROCAL` and
  `ensemble_members` state the probability as one over the seed, with its condition, and
  so do the `repro.backend_ulp_envelope` and `repro.fp32_kernel_certification` rows of
  `docs/oracles/registry.toml`, which also state the seed.
- The member count, its brackets and the obligations are unchanged. The sampled envelope
  of every case moves, because its members do; the stand-in's new signature is recorded
  in the finding and asserted by `certify.sampled_draw_is_unchanged`.
- A change to `ENSEMBLE_SEED`, to the key's byte layout or to the digest is a change to
  every sampled envelope and is made by a record, never to move a verdict.
- `docs/imports/sha-uuids.md` lists the uses of SHA-256 in the tree and does not yet list
  this one; `fiddlybits-52v.1.18` carries the addition.

## References

- National Institute of Standards and Technology. "Secure Hash Standard (SHS)." FIPS PUB
  180-4 (2015). DOI: 10.6028/NIST.FIPS.180-4. The digest the key is taken from.
- Salmon, J. K., M. A. Moraes, R. O. Dror, and D. E. Shaw. "Parallel random numbers: as
  easy as 1, 2, 3." Proceedings of 2011 International Conference for High Performance
  Computing, Networking, Storage and Analysis (2011). DOI: 10.1145/2063384.2063405.
  Section 4.3, the Philox generator the second alternative names.
- `notes/findings/2026-09-11-ulp-ensemble-member-count.md`, section "The member count":
  the count rule and the with-replacement bound this record makes true.
- `notes/findings/2026-09-13-the-bit-reversed-prefix-perturbs-one-residue-class.md`: the
  residue classes the order reached, the miss frequency of the draw, and what the seed
  moves.
- `docs/plans/fiddlybits-52v.1-skeleton.md`, the include order table: `Backends` in
  group B, `Provenance` in group F.
- Decisions 0007 (the Irreducible disposition), 0025 (anti-tuning), 0029 (streams keyed
  on physical identity; the ensemble's registry entries) and 0039 (the argument lives
  here, not in the docstrings).
