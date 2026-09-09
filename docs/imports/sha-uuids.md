# SHA.jl and UUIDs

**What it is.** SHA-2 digests (SHA.jl) and UUID generation (stdlib `UUIDs`).

**What of it is used.** SHA-256 over canonical serialisations for artifact keys
and support identities; UUID4 for run identifiers.

**Assumptions it carries.** None physical. The canonical serialisation is ours:
sorted keys, UTF-8, no floating-point formatting ambiguity (values serialised as
their IEEE bit patterns). Leak caught by `test/provenance/key_stability.jl`,
which asserts a key is stable across sessions and changes when any declared
input changes (a property test flips each field by reflection).

**Licence.** MIT (SHA.jl); Julia stdlib. **Version.** stdlib on Julia 1.12.

**Checklist items applied.** C5 (a key is computed in exactly one function).
