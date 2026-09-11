# StructArrays.jl

**What it is.** A struct-of-arrays container with array-of-structs syntax.
`StructArray{T,N,C,I} <: AbstractArray{T,N}` holds one array per field of `T` in a tuple
or named tuple, and `getindex` reconstructs a `T` from the corresponding element of each
component array. `getproperty` returns the component array itself, so the same object is
addressed either way round.

**What of it is used.** The container for the column state and for any other per-cell
record with named fields: construction, `getindex` inside a kernel, `getproperty` for a
component array, `replace_storage`, and the Adapt and `KernelAbstractions` extensions.
Not the Tables.jl interface, not `collect`/`append!` growth, not the lazy or sorting
helpers.

**Licence.** MIT. **Version.** 0.7.3. **Read at.**
`54d754578858e0d37e1d7b54c0455fce2fada1df`, committed 2026-06-08, in
`/home/cfutro/git/JuliaArrays/StructArrays.jl`. Measured on the RTX 4090:
`notes/findings/2026-09-10-per-cell-state-on-the-device.md`.

**Verdict.** Adopt. It is the cells-first layout of decision 0011 with no cost measured
against writing the component arrays out by hand, and the device integration decision 0011
needs is already in the tree and now demonstrated here rather than declared. The adoption
is narrow: the container and its device path, not the table or collection surface.

## What the measurement settled

The survey asked whether a `StructArray` of an `isbits` column state compiles inside a
portable kernel with the same generated code as flat arrays and manual field offsets, and
whether the Adapt round trip survives. Both yes, and the third result is the one that
matters for the design.

A kernel that reads two of eight fields through the whole-struct `getindex` compiles to
twelve registers, no local memory, and two float loads in the optimised device IR. The
same kernel written over two flat device arrays compiles to twelve registers and two
loads. Reconstructing the struct is free: the loads for fields the body does not use are
eliminated before code generation. That removes the only real argument for hand-writing
the component arrays, which was that `c = s[i]` would pull the whole record.

`Adapt.adapt(CuArray, ...)` moves every component and the round trip back compares equal
field by field. `KernelAbstractions.get_backend` on the whole array agrees with its
components and throws if they disagree, which is the refusal this project would otherwise
have to write. Mixed element types work unchanged: a struct of Float32, Int32, Bool and
UInt8 adapts to four device arrays of four types and a kernel branching on the Bool field
matches a host computation bitwise.

## Assumptions it carries

**Earth defaults (A2, A3), calendar (A1).** Clean negatives. No physical content, no
`Dates`, no constants; the package is a container.

**Grid, mesh and index base (A6).** No grid notion. The index type is computed from the
component arrays: `index_type` walks them and returns `CartesianIndex{N}` if any component
prefers Cartesian indexing, `Int` otherwise, and that choice is a type parameter. For flat
1-based component vectors, which is what this project builds, the answer is always `Int`
linear indexing. Nothing here assumes a base; the base is whatever the components have,
which is one more reason the components are constructed here rather than accepted from
elsewhere.

**Precision.** None of its own. Every element type comes from the struct.

**Threading and GPU model.** No threading. The device model is the two extension modules:
`StructArraysAdaptExt` defines `adapt_structure` for the whole array in one line, and
`StructArraysGPUArraysCoreExt` defines `get_backend` and sets
`always_struct_broadcast(::AbstractGPUArrayStyle) = true` so a broadcast over a
`StructArray` of device arrays stays struct-shaped rather than decomposing per field.
Both are weak dependencies, so the device behaviour appears only when `Adapt`,
`GPUArraysCore` and `KernelAbstractions` are loaded, which they are here.

**Mutable global state (C5).** One module-scope instance, `default_initializer`, used by
the collection path this project does not use. No cache and no configuration.

**Clamps and limiters (B5).** None. The constructor throws on components of inconsistent
shape and on an element type with no fields, both of which are refusals rather than
fallbacks.

**Declared against demonstrated (C3).** Tested upstream, and the device path is now
demonstrated here: the adapt round trip, the backend agreement, bitwise equality against
flat arrays in a `KernelAbstractions` kernel, and the register and load counts.

**Fail-open branches (C4).** None found in the used surface. The one place worth naming is
`always_struct_broadcast`, which changes how a broadcast decomposes depending on the
component array type. This project's operators are not broadcasts, so it does not bind
here, and a broadcast over a `Field` whose storage is a `StructArray` would be the place to
check it.

## The wrapper an adoption needs

Small, because the container is honest.

1. **The column state struct is `isbits` and its fields are declared once**, in the field
   registry decision 0011's memory budget is computed from. A field whose type is not
   `isbits` is a refusal at construction, not at the device boundary.
2. **Components are constructed here**, as 1-based flat arrays of the working type, never
   accepted from a caller, so the index type parameter is always `Int`.
3. **No collection growth.** `push!`, `append!` and the `collect` path are not used;
   per-level arrays are allocated once at their declared length.

Leak tests, each named:

- **The adapt round trip.** The same test pattern `docs/imports/adapt.md` already names for
  `Field` and `Geometry`, extended to the column-state `StructArray`: adapt to the device,
  adapt back, compare every component bitwise.
- **The backend agreement refusal.** Construct a `StructArray` with one component left on
  the host and assert `get_backend` throws. This is the positive control for the check the
  extension provides; without it the check is untested here.
- **The isbits lint.** A test over the declared column-state struct asserting
  `isbitstype`, which catches a field type that quietly becomes a boxed value.

## Checklist

| item | result |
| --- | --- |
| A1 day and year | clean negative |
| A2 planetary constant block | clean negative |
| A3 Earth literals | clean negative |
| A6 grid and index base | no grid; the index type is derived from the components and is `Int` for this project's flat arrays |
| B4 comment against value | no constants to check |
| B5 clamps and limiters | none; two constructor refusals |
| C1 use site of every constant | no constants |
| C3 declared against demonstrated | upstream tests plus the device measurements in the finding |
| C4 fail-open branches | none in the used surface; `always_struct_broadcast` noted as a dispatch that changes with component type |
| C5 duplicate state and second constant sets | one collection-path initializer instance, unused here |
| D2 boundary field by field | the boundary is the component arrays: element type, length and backend, all checked at construction and by `get_backend` |
| D4 conservation identity | not applicable; the container conserves by being a container, and the adapt round trip is the identity that stands in its place |

## References

- The measurements: `notes/findings/2026-09-10-per-cell-state-on-the-device.md`.
- The survey entry: `docs/surveys/gpu-and-arrays.md`, JuliaArrays.
- Decision 0006 (`Field` and its type parameters), decision 0011 (cells-first layout,
  portable kernels, the memory budget from the field registry).
- `docs/imports/adapt.md` (the device boundary and its round-trip test),
  `docs/imports/kernelabstractions.md`, `docs/imports/staticarrays-jl.md` (the per-cell
  state vector inside the kernel, read together with this).
