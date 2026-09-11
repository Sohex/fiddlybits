# StaticArrays.jl

**What it is.** Arrays whose size is a type parameter and whose storage is a tuple, so
the compiler can keep them in registers: `SVector` and `SMatrix` immutable, `MVector` and
`MMatrix` mutable, `SizedArray` wrapping an existing array, plus a full linear-algebra
surface written as generated functions that unroll at the declared size.

**What of it is used.** `SVector` and `SMatrix` as per-cell state and small per-cell
operators inside kernels, their arithmetic, and the fixed-size constructors. Not the
mutable forms in a kernel, not the factorisations, not the BLAS paths, not the random
constructors.

**Licence.** MIT. **Version.** 1.9.20. **Read at.**
`8935f7091f8376314e482eb6c8c29d478b9ba38b`, committed 2026-09-01, in
`/home/cfutro/git/JuliaArrays/StaticArrays.jl`. Measured on the RTX 4090:
`notes/findings/2026-09-10-per-cell-state-on-the-device.md`.

**Verdict.** Adopt, with three things refused at the boundary rather than at the call
site: the mutable forms inside a kernel, the BLAS dispatch above the size threshold, and
the random constructors. Each is a specific function rather than a habit, so each is a
lint.

## What the measurement settled

The survey asked how long a per-cell state vector can be before an `SVector` stops fitting
in registers, because past that point the package stops being free and decision 0011's
claim that the atmosphere is bound by kernel launches rather than arithmetic needs
re-checking against register pressure.

Nothing spills below 256 elements. In a kernel making two passes over an
`SVector{L,Float32}`, the register count rises by about one per element and local memory
stays at zero through L = 192; at L = 256 the hardware cap of 255 registers per thread is
reached and the vector goes to local memory. So spilling is not the constraint for any
column state this project is likely to declare.

Occupancy is the constraint, and it binds an order of magnitude earlier. At 64 elements
the kernel holds 72 registers and seven blocks of 128 threads are resident per streaming
multiprocessor; at 128 elements, three; at 192, two. The kernel-shape rule therefore reads
off residency and not spilling, and the number to carry into the column physics design is
that a per-cell state beyond about sixty-four Float32 values costs residency in proportion.

The mutable form fails much earlier and silently. An `MVector` written element by element
goes to local memory in its entirety from 32 elements, and the register count then stops
rising because the state is no longer in registers. A mutable static array in a kernel is
a local-memory array with a stack-allocation name, which is exactly the sort of
performance cliff a declared layout is supposed to prevent.

## Assumptions it carries

**Earth defaults (A2, A3), calendar (A1).** Clean negatives. No physical content, no
`Dates`.

**Grid, mesh and index base (A6).** No grid. Sizes are type parameters and indexing is
1-based throughout, matching decision 0010's in-kernel convention. `SOneTo` and the
`SUnitRange` machinery keep axes static; nothing admits an arbitrary index base.

**Precision.** Parametric. The one place the package names a type is the `SA_F32` and
`SA_F64` construction aliases, which are opt-in spellings and not defaults.

**Threading and GPU model.** None of its own, which is the point: the types are `isbits`
tuples that pass into a device kernel like any other value. `MArray` is a mutable struct
wrapping a tuple, which is also `isbits`-adjacent enough to compile, and which the
measurement shows lands in local memory.

**Mutable global state (C5).** One real leak, and it is in the random constructors.
`rand(::Type{SA})`, `@SVector rand(n)` and their relatives call `Random.GLOBAL_RNG`
(`src/arraymath.jl`, `src/SArray.jl`). Decision 0029 keys every stochastic stream on
(root seed, support identity, cell, process, time index) and forbids a value that depends
on anything else, so the whole random-constructor family is banned here rather than
merely discouraged; a draw inside a kernel comes from the project's counter-based
generator and is placed into an `SVector` afterwards.

**Clamps and limiters (B5).** No numerical clamps. There are size thresholds that change
the algorithm, which is the next item.

**Fail-open branches and size thresholds (C4).** `mul!` on static matrices dispatches by
the product of the dimensions (`src/matrix_multiply_add.jl`): fully unrolled below
`4*4*4`, chunked below `14*14*14`, and above that, for element types BLAS handles, a
direct BLAS call. Decision 0029 forbids BLAS in the hot path unless it is single-threaded
and deterministic, so the threshold is a silent boundary at which this project's own rule
is broken by a call that looks identical on both sides of it. The `*` operator has no BLAS
branch at all, only unrolled and chunked paths, so the leak is `mul!` specifically. This
project's per-cell operators are far below the threshold, which makes the lint cheap
rather than unnecessary: the threshold is a property of the library, not of the call, and
a future 16-element-square operator would cross it without a word.

**Comment against value (B4).** One mismatch worth recording, at the same threshold:
`# Something seems broken for this one with large matrices (becomes allocating)`. The
comment records a known defect in the chunked path as the reason for the boundary, which
makes the boundary itself provisional upstream.

**Declared against demonstrated (C3).** A large upstream test suite. The device behaviour
is demonstrated here, in the finding, and not upstream: the package has no GPU dependency
and no device test.

## The wrapper and its leak tests

1. **`SVector` for per-cell state, always immutable.** State is rebuilt functionally
   between stages rather than mutated in place.
2. **No `MVector` or `MMatrix` inside a kernel.** A scratch buffer that must be mutable is
   a device array slice or an arena allocation, both of which are declared, not a mutable
   static array that silently becomes local memory.
3. **No `mul!` on static matrices.** Per-cell matrix products use `*`, which has no BLAS
   branch.
4. **No random constructors.** Every draw comes from the project's counter-based
   generator.

Leak tests:

- **A lint over the source** refusing `MVector`, `MMatrix`, `@MVector`, `@MMatrix`,
  `mul!` on a static operand, and the `rand`/`randn` static constructors, in any module
  that compiles to a kernel. Same suite as the earth-constant quarantine and the
  calendar-import lint, `fiddlybits-52v.1.3`.
- **A resource assertion** on the compiled column-physics kernels: local memory is zero
  and the register count is under the declared budget, read from the compiled kernel the
  way the finding reads it. This is the test that would catch an `SVector` grown past the
  budget, which the source lint cannot see.
- **The stochastic-stream test** decision 0029 already names, rerunning with a different
  partition and asserting bitwise identity, which is the positive control for the
  random-constructor ban.

## Checklist

| item | result |
| --- | --- |
| A1 day and year | clean negative |
| A2 planetary constant block | clean negative |
| A3 Earth literals | clean negative |
| A6 grid and index base | no grid; 1-based throughout, sizes as type parameters |
| B4 comment against value | the chunked-multiplication comment records an upstream defect as the reason for the BLAS threshold |
| B5 clamps and limiters | none numerical; three size thresholds in matrix multiplication |
| C1 use site of every constant | the size thresholds are the only constants that change an answer; each read at its dispatch site in `matrix_multiply_add.jl` |
| C3 declared against demonstrated | large upstream suite; no device test upstream, so the register and spilling behaviour is demonstrated in the finding here |
| C4 fail-open branches | the BLAS dispatch above `14*14*14` in `mul!`; the global-RNG random constructors |
| C5 duplicate state and second constant sets | `Random.GLOBAL_RNG` in the random constructors, banned here |
| D2 boundary field by field | the boundary is a value, not an array: element type and length are type parameters and are checked by construction |
| D4 conservation identity | not applicable; the resource assertion on the compiled kernel stands in its place |

## References

- The measurements: `notes/findings/2026-09-10-per-cell-state-on-the-device.md`.
- The survey entry: `docs/surveys/gpu-and-arrays.md`, JuliaArrays.
- Decision 0010 (the index base at each boundary), decision 0011 (column physics fused
  into few kernels, precision by declaration), decision 0029 (no nondeterministic BLAS in
  the hot path, stochastic streams keyed on physical identity).
- `docs/imports/structarrays-jl.md`, the container the state lives in outside the kernel,
  read together with this.
