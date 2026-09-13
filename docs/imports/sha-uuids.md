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

**Ensemble draw byte layout.** `Backends.draw_key` computes the ensemble draw key as
the SHA-256 digest of the seed, field and cell, each written as eight little-endian
bytes (seed and field as `UInt64`, cell as `UInt64`), read as four big-endian
`UInt64` words in order. The key is a pure function of the site identity `(field,
cell)` and the seed alone, independent of the site's position in any list.

**Checklist items applied.** C5 (artifact key and ensemble draw key each computed
in exactly one function: `Provenance.Artifact` digest and `Backends.draw_key` for
the ensemble draw); certify.sampled_draw_is_unchanged asserts the stand-in envelope's
members and bit-for-bit layout unchanged, and certify.sampled_draw_is_seeded
confirms the miss frequency over an ensemble of seeds against the exact hypergeometric
probability.
