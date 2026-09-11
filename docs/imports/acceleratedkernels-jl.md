# AcceleratedKernels.jl

**What it is.** Cross-backend parallel primitives written once against
`KernelAbstractions.jl` and dispatched to CUDA, ROCm, oneAPI, Metal, OpenCL or the
processor: `map`, `foreachindex`, `reduce`, `mapreduce`, `accumulate`, `sort`,
`searchsorted`, `reverse`, `findall` and the any/all predicates. Each entry point takes
the partition as keyword arguments rather than choosing it internally, and the same
source runs on every backend.

**What of it is used.** Nothing yet, and the recommendation below is a narrow yes. The
surface this project would depend on is the device `reduce`/`mapreduce` and possibly
`accumulate`, called with the partition pinned at every call site. Decision 0029 puts the
reduction primitives in the kernel library and has every component use them, so what is at
stake is whether that library wraps this package or is written here.

**Licence.** MIT. **Version.** 0.4.3. **Read at.**
`0287c81c3b4d06f90258cffee44de87325bcf069`, committed 2026-09-09, in
`/home/cfutro/git/AcceleratedKernels.jl`. Measured on the RTX 4090 and on 16 cores:
`notes/findings/2026-09-10-acceleratedkernels-reductions.md`.

**Verdict.** Adopt narrowly, subject to a wrapper, and not for the reduction decision 0029
declares. Two defects decide the shape. The processor path's default partition is the
thread count, so its default reduction answers differently at one, four and sixteen
threads, which decision 0029 makes a design property rather than a tolerance. And the
device path returns half the sum at `block_size = 1024`, a value its own argument check
admits. Both were measured here rather than inferred; the second is an upstream bug with a
located cause. Neither rules the package out, because both are reachable only through
defaults and both are closed by pinning, but a bare call to this package is a defect in
this project and the lint below says so.

## The two defects, and what closes each

**The processor default is the thread count.** `mapreduce_1d_cpu` partitions the input
with `TaskPartitioner(length(src), max_tasks, min_elems)`, reduces each chunk with
`Base.mapreduce` and folds the chunk results with `Base.reduce`. Every public entry point
defaults `max_tasks = Threads.nthreads()` and `min_elems = 1`. For a floating-point `+`
the chunk count is the association order, so the answer moves with the thread count. The
finding measures three different answers at one, four and sixteen threads, and three
identical repeats within the sixteen-thread configuration, so it is the thread count and
not the run. Passing `max_tasks` explicitly makes the result identical at every thread
count; the value chosen is then part of the definition of the reduction, not a
performance knob, and changing it is an answer-changing commit.

**The device path is wrong at the top of its declared range.** `reduce_group!`
(`src/reduce/utilities.jl`) folds the block's shared array by halves and its ladder starts
at `if N >= 512`. There is no rung for 1024, so a block holding 1024 partial sums never
adds its upper half. `mapreduce_1d_gpu` accepts the value under `@argcheck 1 <= block_size
<= 1024` and the package's reduction tests exercise `block_size = 64` only, so the top half
of the declared range is untested. A vector of ones reduces to exactly half its length at
that setting, at every length tried. Every other power of two from 32 to 512 is right to
roundoff against a 300-bit reference.

Both are closed by the same rule: **every call passes `max_tasks`, `min_elems`,
`block_size` and `items_per_thread` explicitly, and no call passes `block_size = 1024`
until the upstream ladder gains its missing rung.**

## What the device path gets right

Worth recording, because it is the reason the package is worth wrapping at all. The device
reduction is a fixed tree with no atomics: `block_size` and `items_per_thread` are explicit
arguments, the block count is derived from the input length, each block reduces its own
slice in shared memory, and the driver loop recurses over the block results. Three launches
of the same call agreed bitwise, which is what decision 0029 asks of two launches on the
same GPU. The geometry does not consult the device: `default_items_per_thread(backend)`
returns 1 for every backend in the tree, so nothing in the answer depends on which card it
runs on, though the hook exists for a backend to override it and that is a further reason
to pass the value rather than take it.

Atomics appear in exactly one place, the radix sort's shared-memory histogram
(`src/sort/radix_sort.jl`), and they accumulate integer counts, whose sum is order
independent. That is deterministic in result while still being an atomic in a kernel, which
decision 0029 forbids by shape in the physics path. The segmented quantiles this project
needs are planned as a bitonic sort of its own, so the question does not arise unless the
sort path is adopted later.

## Assumptions it carries

**Earth defaults (A2, A3).** Clean negative. No physical constant of any kind; a grep of
`src/` for the Earth literal list returns nothing. The package has no physical content.

**Calendar and time (A1).** Clean negative. No `Dates`, no day, no year.

**Grid, mesh and index base (A6).** No grid notion. Internally the kernels compute in
zero-based indices and convert at the point of memory access, with a comment saying so,
which is the discipline decision 0010 asks for at a boundary. The public surface is
1-based Julia indexing throughout.

**Precision.** Parametric. The reduction's accumulator type comes from `init`, so an `init`
of `0.0` accumulates a Float32 source in Float64, which is the door decision 0029 needs for
a ledger that must not accumulate at the working precision. Nothing in the package chooses
a precision on its own behalf.

**Threading and GPU model.** `KernelAbstractions` for the device, Julia tasks for the
processor. The partition is always a keyword argument and never a global.

**Mutable global state (C5).** Clean negative for state. Module-scope constants are type
wrappers, one cached `CPU_BACKEND` sentinel, and four tuning constants in the
multidimensional reduction (`TARGET_BLOCKS`, `GS_DST_CUTOFF`, `MIN_ITEMS_PER_THREAD`,
`TILED_STRIDED_ROWS_PER_BLOCK`) that select a kernel shape by input size. Those four are a
second partition rule that call-site keywords do not reach, so the multidimensional path is
outside the wrapper until each is pinned or the path is reimplemented.

**Clamps and limiters (B5).** None numerical. The limits are the argument checks on
`block_size` (power of two, at most 1024) and `items_per_thread`.

**Declared against demonstrated (C3).** A real test suite across backends, and two gaps
that matter: the reduction tests use one block size, and nothing tests that a reduction is
invariant to the thread count. Both gaps are exactly where the defects are.

**Fail-open branches (C4).** Three, all defaults.
`max_tasks = Threads.nthreads()` returns a different number per machine and per session.
`switch_below` copies the array to the host and finishes with `Base.reduce` when the
remaining length falls under it, so the association order changes discontinuously with
input length; it defaults to 0, which is off, and pinning it to 0 explicitly keeps it off.
And `block_size = 1024` returns half the answer, which is the worst shape a fail-open
branch can have: a plausible number rather than a refusal.

## The wrapper and its leak tests

1. **One call site shape.** Every reduction this project performs through the package goes
   through a single wrapper that supplies `max_tasks`, `min_elems`, `block_size`,
   `items_per_thread` and `switch_below`, and there is no other call.
2. **The lint.** A source lint refuses any direct call to an `AcceleratedKernels` entry
   point outside that wrapper, and refuses the wrapper itself if any of the five keywords
   is absent. Same suite as the earth-constant quarantine and calendar-import lints,
   `fiddlybits-52v.1.3`.
3. **The thread-count oracle.** The reduction runs at one, four and sixteen threads with
   several repeats and the results are compared bitwise; decision 0029 already declares
   this as a nightly oracle, and this package's default is the mutation that proves the
   oracle can fail.
4. **The ones control.** Every reduction primitive, project-owned or wrapped, is tested on
   a vector of ones and on a vector of alternating magnitudes where the exact sum is known
   in advance, at every block size the wrapper is allowed to pass. This is the check that
   found the upstream defect and it costs nothing.
5. **The reference path.** Decision 0027's naive serial reduction beside the fast one, with
   the fixed-order pairwise tree as the project's declared answer. Where the two disagree
   beyond the pairwise tree's own error bound, the fast path is wrong.

## Checklist

| item | result |
| --- | --- |
| A1 day and year | clean negative |
| A2 planetary constant block | clean negative; no physical content |
| A3 Earth literals | clean negative |
| A6 grid and index base | no grid; zero-based internally by declared convention, 1-based at the surface |
| B4 comment against value | no mismatch found; the zero-indexing comment matches the code |
| B5 clamps and limiters | argument checks on `block_size` and `items_per_thread` only; the `block_size` upper bound admits a value that is wrong |
| C1 use site of every constant | the four multidimensional tuning constants are the only constants with a use site that changes an answer; each selects a kernel shape by input size and none is reachable from a call-site keyword |
| C3 declared against demonstrated | tested across backends; not demonstrated: any block size above 64 in the reduction tests, and thread-count invariance anywhere |
| C4 fail-open branches | `max_tasks = Threads.nthreads()`; `switch_below` changing association by length; `block_size = 1024` returning half the sum |
| C5 duplicate state and second constant sets | clean negative for state; the multidimensional tuning constants are a second partition rule |
| D2 boundary field by field | the exchanged objects are arrays and scalars with no units, no calendar and no index-base translation; the accumulator type is the caller's through `init` |
| D4 conservation identity | run here: the sum of a vector of ones, exact in advance, at every admitted block size; this is the check that found the defect |

## References

- The measurements: `notes/findings/2026-09-10-acceleratedkernels-reductions.md`.
- The survey entry this record answers: `docs/surveys/gpu-and-arrays.md`, direct trees.
- Decision 0011 (portable kernels, precision by declaration), decision 0027 (reference
  paths and the mutation run), decision 0029 (thread-count invariance, fixed-order
  reductions, no atomics in the physics path).
- `docs/imports/kernelabstractions.md`, the layer this package is written against.
- The rows that consume this: `fiddlybits-52v.7.3` (fixed-order reductions),
  `fiddlybits-52v.7.5` (segmented quantiles), `fiddlybits-52v.1.3` (the lint suite).
