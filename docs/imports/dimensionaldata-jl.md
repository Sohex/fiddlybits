# DimensionalData.jl

**What it is.** An array wrapper carrying named, looked-up dimensions: `DimArray` holds
a parent array plus a tuple of `Dimension` objects, each with a lookup of coordinate
values, a sampling and span description, a name and a metadata bag. Indexing, selection,
reduction, broadcasting and matrix multiplication are all defined to carry the dimensions
through.

**What of it is used.** Nothing. This is a reading record, for two mechanisms decision
0006 needs and one it must avoid: how a wrapper threads its own type through Julia's
broadcast pipeline without losing the inner array's style, how its device-adapt path
strips what a kernel cannot use, and what a global switch over a dimension check costs.

**Licence.** MIT. **Version.** 0.30.2. **Read at.**
`66659c528828a892e19cd241712505a3721e918b`, committed 2026-09-05, in
`/home/cfutro/git/DimensionalData.jl`. Read `src/array/broadcast.jl`,
`ext/DimensionalDataAdaptExt.jl`, `src/array/matmul.jl`.

**Verdict.** Algorithmic reference. The broadcast pattern is worth copying and the
metadata-stripping adapt is worth copying; the package is not a dependency, because
`Field` carries in its type what a `DimArray` carries in a runtime tuple, which is the
whole of decision 0006.

## The broadcast pattern, and the one thing it does not do

`DimensionalStyle{S<:AbstractArrayStyle, N} <: AbstractArrayStyle{N}` wraps the inner
array's own broadcast style as a type parameter:

    BroadcastStyle(::Type{<:AbstractDimArray{T,N,D,A}}) where {T,N,D,A} =
        DimensionalStyle(BroadcastStyle(A))

so a `DimArray` over a device array gets `DimensionalStyle{CuArrayStyle{N},N}` and every
broadcast still resolves to the device kernel underneath. Three methods carry the wrapper
through: `Broadcast.instantiate` checks the dimensions and builds output axes,
`Base.similar` allocates through the inner style and rebuilds the wrapper, and `Base.copy`
does the same for the out-of-place path. Combination rules are written for the pairs that
can occur, and a combination whose inner styles do not combine returns `Unknown()` so the
error comes from Base rather than from a wrong answer.

The important observation is what the style does not carry. `DimensionalStyle` holds the
inner style and the dimensionality and nothing else: the dimension identity is not in the
type. It is recovered at `instantiate` time by `_firstdimarray(bc)`, which walks the
broadcast arguments for the first `DimArray` and asks it, and the agreement of the
operands is then a runtime comparison, `_comparedims_broadcast`, which throws. So
`DimensionalData` answers the question this project is asking by not asking it: its
metadata never enters dispatch.

## Whether `Field`'s four parameters survive the same pattern

They do, and the pattern has to be changed in one place to make them do it. A working
prototype was built and run on the host and on the device.

Folding the parameters into the style, `FieldStyle{S,T,D,L,Inner,N} <:
AbstractArrayStyle{N}`, with `BroadcastStyle(::Type{Field{S,T,D,L,A}})` constructing it
from the inner array's style, gives:

- `f .+ f` returns `Field{Extensive,Instantaneous,Dim{1,0,0},4,Vector{Float64}}`, every
  parameter intact, and `f .* 2.0` likewise.
- The same over a `CuArray` returns the same wrapper over a `CuArray`, and a fused chain
  under `CUDA.allowscalar(false)` runs to completion, so the inner style is genuinely
  preserved and the device path is not lost to a scalar fallback.
- Combining two fields whose parameters differ has no rule. Left alone, Julia reports
  `conflicting broadcast rules defined`, which is a refusal with nothing in it. Adding one
  method for the unequal case, less specific than the equal case and therefore not
  ambiguous with it, replaces that with a named refusal: which two parameter sets, and
  which operator to use instead. Both the legal host and legal device cases still work
  with that method present.

So the answer to the survey's question is that `Field` does not have to fold its
parameters into one packed style type and does not have to give them up: the style takes
them as extra parameters and the only cost is that each legal combination needs its own
combination rule, which is the point rather than the price. A rule that is not written is
a combination that does not broadcast.

The difference from `DimensionalData` is worth stating plainly, because it is the
difference decision 0006 exists to make. There, mismatched dimensions are a value
comparison inside `instantiate` that throws; here, mismatched semantics are a method that
does not exist. The first is checkable only by running the broadcast; the second is
visible to the enumeration test decision 0006 already requires, which walks the semantics
types and asserts each combination has a method or a declared refusal.

Broadcast remains the narrow door. It is elementwise and closes only over identical
parameters: a product of two fields changes the dimension signature and so is a named
operator, not `.*`, and anything that changes support goes through `coarsen` and `refine`,
which return a ledger as well as a field.

## The adapt boundary, and what to copy from it

`ext/DimensionalDataAdaptExt.jl` is a worked answer to the question `Provenance` will
face. `Adapt.adapt_structure(to, m::Metadata) = NoMetadata()`, with the comment "Metadata
nearly always contains strings, which break GPU compat", and the lookup and dimension
adaptations recurse into their data while dropping their own metadata the same way. The
array adaptation additionally converts the name to a type-domain value, `name=Name(name(A))`,
so an identifying string survives as a type parameter where a string field would not
survive at all.

Two things to copy and one to refuse. Copy the rule that adapt strips what a kernel
cannot use rather than refusing to adapt, so the host object stays whole and the device
object is the subset a kernel can touch. Copy the name-to-type-parameter move for the
parts of `Provenance` that must remain identifiable on the device side. Refuse the
silence: dropping provenance on the way to the device is exactly the kind of thing that
should be visible.

**The conclusion drawn here for `Field` was wrong, and `fiddlybits-52v.3.2` corrected
it.** This section assumed the wrapper crosses into the kernel, and it does not. Every
kernel in this package takes bare arrays and the one struct decision 0011 passes to a
kernel is the stripped constant block of decision 0007, so a `Field` is a host-side
wrapper whose array may live on either device, its adapt rule drops nothing, and
`fields.adapt_roundtrip` asserts equality in every member. The declared absence with a
name is still the right instrument and it moved to the state that genuinely lacks a
value: an `Origin` an operator has just written has no content key and says so, and the
accessor refuses rather than returning the zeros it holds. The paragraph above stands
for any struct that does cross, which is what `Provenance` will face; it does not stand
for `Field`. The argument is in `docs/plans/fiddlybits-52v.3-fields.md`, section "The
device boundary, and why nothing is stripped".

## What must not be copied

`const STRICT_BROADCAST_CHECKS = Ref(true)` in `src/array/broadcast.jl`, with
`strict_broadcast!(x::Bool)` to set it, and the same pattern for matrix multiplication in
`src/array/matmul.jl`. A global, mutable switch that turns the dimension check off for
every array in the session is a fail-open branch of the widest possible scope: the
operation still succeeds, on data that was not checked, and nothing in the result records
that the check was skipped. Decision 0006 has no such switch and no such state; a
combination either has a method or does not.

## Checklist

Recorded for the read surface, though no dependency is proposed.

| item | result |
| --- | --- |
| A1 day and year | not clean, and not relevant here: the package has a full time-dimension and calendar surface through its lookups, which is one more reason it is not the carrier for a field whose clock is SI seconds (decision 0008) |
| A2 planetary constant block | clean negative |
| A3 Earth literals | clean negative in the read surface |
| A6 grid and index base | dimensions carry their own lookups and orders; index base is the parent array's |
| B4 comment against value | the adapt extension's metadata comment matches its code and explains it |
| B5 clamps and limiters | none in the read surface |
| C1 use site of every constant | the two strictness `Ref`s, read at every broadcast and matmul |
| C3 declared against demonstrated | broadcast and adapt are tested upstream; the four-parameter question was demonstrated here, in the prototype |
| C4 fail-open branches | `strict_broadcast!(false)` and `strict_matmul!(false)`, both global and both silent |
| C5 duplicate state and second constant sets | the two strictness `Ref`s are the package's only mutable global state |
| D2 boundary field by field | the device boundary is the adapt path: parent array adapted, metadata replaced by `NoMetadata`, name moved into the type |
| D4 conservation identity | not applicable |

## References

- The survey entry: `docs/surveys/gpu-and-arrays.md`, direct trees.
- Decision 0006 (`Field{S,T,D,L,A}`, the closed semantics vocabulary, the enumeration
  test), decision 0008 (one clock in SI seconds), decision 0010 (provenance and content
  addressing), decision 0011 (the device boundary).
- `docs/imports/adapt.md`, the mechanism this record's adapt discussion sits on.
- The rows that consume this: `fiddlybits-52v.3.2` (the `Field` type and its parameters)
  and `fiddlybits-52v.3.4` (the semantics-closure enumeration test, which also carries
  the `@inferred` assertion that turns the prototype above from a claim into a check).
- The section of the plan that reads this record for its inference argument:
  `docs/plans/fiddlybits-52v.3-fields.md`, "Inference, and what it costs". The refusal
  of `strict_broadcast!` recorded here is the shape the accepted-findings rule of
  `fiddlybits-52v.3.8` is written against.
