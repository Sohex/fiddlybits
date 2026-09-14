# SHA.jl and UUIDs

**What it is.** SHA-2 digests (SHA.jl) and UUID generation (stdlib `UUIDs`).

**What of it is used.** SHA-256 over canonical serialisations for artifact keys
and support identities; SHA-256 over the seeded draw of the ulp ensemble,
keyed on site identity; UUID4 for run identifiers.

**Assumptions it carries.** None physical. The canonical serialisation is ours:
sorted keys, UTF-8, no floating-point formatting ambiguity (values serialised as
their IEEE bit patterns) for artifact keys. The ensemble draw assumes the SHA-256
digest orders sites as a uniformly random permutation would with respect to any
sub-population fixed without reference to the digest, stated in
docs/decisions/0052-the-sampled-ensemble-is-a-seeded-draw.md. Leaks caught by
`test/provenance/key_stability.jl` (artifact keys stable across sessions and
changed by declared input changes, a property test flips each field by reflection)
and `test/certify/member_count.jl` and `test/certify/obligation.jl` (ensemble
draw digest and byte layout).

**Licence.** MIT (SHA.jl); Julia stdlib. **Version.** stdlib on Julia 1.12.

**Ensemble draw byte layout.** `Backends.draw_key` orders a site `(field, cell)`
under a seed by the SHA-256 digest of the seed, the field and the cell, each written
as the eight little-endian bytes of a `UInt64`, read as four big-endian `UInt64`
words and followed by `field` and `cell`. The key depends on the seed and the site
alone, not on the site's position in any list.

**Checklist items applied.** C5 (a key is computed in exactly one function; the
ensemble draw key in `Backends.draw_key`). A changed digest or byte layout is caught
by `test/certify/obligation.jl`, whose sampled_draw_is_unchanged testset holds the
stand-in case's envelope and its members bit for bit to the recorded finding, and
`test/certify/member_count.jl`, whose sampled_draw_is_seeded testset asserts a
repeated seed repeats the draw, a changed seed changes it, and a site's key does
not depend on the rest of the list or its order.
