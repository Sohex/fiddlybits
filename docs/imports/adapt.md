# Adapt.jl

**What it is.** The mechanism that converts host structs holding arrays into their
device counterparts (`adapt_structure`).

**What of it is used.** `Adapt.adapt_structure` for `Field`, `Geometry` and the
stencil tables so a struct can be passed to a kernel on either backend.

**Assumptions it carries.** None physical. It assumes the struct's fields are
either arrays or isbits; a field holding a `Dict` or a closure will not adapt.
Leak caught by `test/fields/adapt_roundtrip.jl`, which adapts every registered
struct to CPU and back and asserts equality.

**Licence.** MIT. **Version.** `to pin`.

**Checklist items applied.** C3 (every struct we pass to a kernel has an adapt
test), C5 (an adapted copy is a second copy of state; the store records which is
authoritative and moves are explicit).
