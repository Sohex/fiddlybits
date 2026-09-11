+++
epic = "fiddlybits-52v.7"
title = "The portable kernel layer, the partition-independent reductions, and the precision certification"
decisions = ["0011", "0027", "0029", "0038", "0044", "0045"]
requirements = ["REQ-NUM-001", "REQ-NUM-002", "REQ-NUM-004", "REQ-NUM-006"]
oracles = ["repro.thread_count_bitwise", "repro.backend_ulp_envelope", "repro.fp32_kernel_certification", "kernels.reduction_partition_independent", "kernels.segmented_quantile_exact", "kernels.memory_budget"]
status = "filed"
date = 2026-09-10
+++

## Scope

This plan builds the layer every physics kernel is written against: one device
abstraction with a CPU fallback that runs the same kernel text, the reductions whose
answer cannot depend on how the work was partitioned, the segmented quantiles the
mesh hierarchy needs, the memory budget a run refuses to start over, and the
ulp-ensemble harness that decides whether a single-precision kernel may enter a
production profile.

It builds no physics. Every kernel here is arithmetic over flat arrays with no
geometry, no field semantics and no planetary content, which is what lets `Backends`
and `Reductions` sit below `Mesh` and `Fields` in the skeleton's include order.

Two boundaries are drawn deliberately and are the plan's main decisions:

- **The memory budget takes a ceiling and a field declaration, not a `Profile` and
  not the field registry.** `Backends` sits below `Fields` and below `Systems`, so
  reaching into either would be the cycle the skeleton's oracle exists to catch. The
  budget takes a plain description of what a run will allocate, and the caller reads
  the ceiling off the profile. `Profile` is carried by `fiddlybits-52v.4.8`.
- **The reference path is not a separate row.** Decision 0027 requires a naive serial
  version beside every optimised kernel, never deleted, and that path is where
  correctness is decided. It is written in the same row as the kernel it specifies,
  because a reference written later is written against the optimisation rather than
  against the intent.

## Module boundaries

| path | holds | row |
| --- | --- | --- |
| `src/Backends/` | the device abstraction, `Adapt`, the layout convention, `on`, the budget, the reference kernels of decision 0027 | 52v.7.2, 52v.7.6, 52v.7.10 |
| `src/Backends/transcendentals.jl` | the project's own polynomial transcendentals for bitwise mode, `Float64` and `Float32` | 52v.7.8, 52v.7.13 |
| `src/Backends/certify.jl` | the envelope measurement, the per-case obligations, and the certification verdict | 52v.7.4, 52v.7.17, 52v.7.19 |
| `src/Reductions/` | fixed-order pairwise and compensated sums, segmented reductions, quantiles | 52v.7.3, 52v.7.5 |
| `test/backends/` | the backend suite, the bitwise mode, the budget suite | 52v.7.2, 52v.7.6, 52v.7.10 |
| `test/backends/transcendentals.jl` | the transcendentals suite: bitwise cross-backend grids and 300-bit reference error, both precisions | 52v.7.8, 52v.7.13 |
| `test/reductions/` | the reduction and quantile suites with their adversarial inputs | 52v.7.3, 52v.7.5 |
| `test/certify/` | the ulp-ensemble harness, its injected-error control, and the obligation suite | 52v.7.4, 52v.7.17, 52v.7.19 |

`Backends` references `Verdicts` and nothing else in the tree. `Reductions`
references `Backends` and `Verdicts`. Neither references `Mesh`, `Fields`, `Systems`
or `Dimensions`, and `build.module_order_acyclic` is what holds that.

## Types and functions

### The device layer

```
abstract type Backend end
struct CPU <: Backend   ...
struct GPU <: Backend   ...

on(array, backend)           move, recording it through Events.moved
adapt_for(x, backend)        Adapt.adapt_structure through to the device
launch!(kernel, backend, n)  one launch, workgroup size from the backend, queued
complete!(backend | array)   the wait, and the only wait in this module
queued(backend)              the kernels launched and not yet waited for
handoff(backend)             a point in this task's queue, for another task
after!(backend, handoff)     queue behind that point, waiting on the device
order_explicitly!(array)     leave the library's per-array ordering to these
```

**A launch queues and does not wait.** `launch!` compiles, launches and returns;
on the GPU backend the kernel may still be running when it does. `complete!` is the
only place in this module that waits, in two forms: on a `Backend`, for every kernel
this task queued on it, and on an array, for the stream that last held that array,
which is the kernel that wrote it even when another task queued it. `queued` is the
task-local record of what `launch!` has queued and no `complete!` has waited for,
bounded in length, and it is what a failed wait is named from, because an
asynchronous launch cannot put the faulting kernel on the host stack. `on` and
`adapt_for` call `complete!` before they read device memory on the host, so a host
read never reaches an unfinished write through this module. A barrier after every
launch is what decision 0038 rejects, and reintroducing one here would undo that; the
path-by-path argument for every route from a kernel to a read, marked where it is
checked and where it rests on the platform, is
`notes/findings/2026-09-11-a-launch-that-queues-and-a-completion-that-is-stated.md`.

**Two tasks are ordered by `handoff` and `after!` and by nothing else.** The
producing task takes a `handoff`, which is an event recorded on the stream it queues
on; the consuming task calls `after!` with it before its own launch, which waits on
the device and returns on the host at once. `order_explicitly!` takes an array out of
the library's per-array ownership bookkeeping, which would otherwise order the two
tasks by stopping the host inside the consumer's launch for the whole of the
producer's kernel, and which is one ordering too many for a module that states its
own. The measurement of both, and the race the control demonstrates, is
`notes/findings/2026-09-11-a-cross-task-ordering-door-in-the-backends-layer.md`.

Arrays are laid out cells-first, so consecutive threads touch consecutive addresses,
with the vertical loop inside the thread. The convention is `(cells, levels)` and it
is a declared constant of this module, read by `Fields` rather than restated there,
because a layout restated in two places is two conventions.

`on` records every move through `Events.moved`, which is declared in group A with a
no-op sink that `Provenance` installs (`fiddlybits-52v.6.8`). A move is a thing that
happened to a field and decision 0010 puts it in the provenance record; this module
does not declare a hook of its own, because the plan review found three plans each
declaring one and that is three definitions of one mechanism.

There is no `device(component)` here. Which backend a component runs on is part of
the component declaration, which is the coupling layer's and sits above this module;
the declaration holds a `Backend` value and this module only defines the type.

**The bitwise mode** is a backend property, not a flag read from the environment.
In bitwise mode both backends run the same pure-Julia arithmetic with no fast-math
and the project's own polynomial transcendentals, and the same reduction trees. A
difference in this mode is a kernel defect and not roundoff, which is what makes it
the debugging oracle rather than a tolerance.

**No bare multiply feeds a bare add.** Decision 0044 amends 0029 on the mechanism:
bitwise mode does not suppress the device's fusion, it writes the fused operation
explicitly. Every multiply that feeds an add, including a multiply accumulated into
a running sum, is written `fma(a, b, c)`, which is the once-rounded chain on both
backends because the device already contracts unconditionally; holding it back to a
barriered, twice-rounded value would only throw away accuracy the device produces
for nothing. `Backends.axpy_bitwise_kernel!` and
`Backends.stencil_gather_bitwise_kernel!` in `kernels.jl` are written this way.
`Backends.nofuse_mul` is not withdrawn; its role narrows to the one case `fma`
cannot cover, a product that has to be rounded on its own before whatever consumes
it sees it, which `transcendentals.jl`'s `cube_root_poly` uses for its residual step
at both precisions. `muladd` is used nowhere, because it is permitted to fuse
rather than required to, and a bitwise mode built on it would be bitwise only on a
target with the hardware instruction. The rule is a property of the source, checked
today by review; an AST lint over the source is filed as `fiddlybits-52v.7.22`,
open.

**The transcendentals** are `Backends.sine`, `cosine`, `sine_cosine`, `cube_root`,
`exponential` and `logarithm`, in `src/Backends/transcendentals.jl`
(`fiddlybits-52v.7.8`): the project's own polynomials in bitwise mode and the
platform library otherwise, dispatched on the argument's own type, `Float64` or
`Float32`, with no widening between them. `fiddlybits-52v.7.13` added the `Float32`
set beside the `Float64` one already there: two separate fits rather than one
converted to the other, because a coefficient table and an argument-reduction split
are bit patterns of the precision they were derived for, and a `Float64` truncation
degree or split rounded to `Float32` is not the `Float32` member of that set. This
is what decision 0045 turns on: the literal lint exempts these tables by naming
each constant in a `precision_pinned` list rather than exempting the file, so a
literal added outside a named table is still refused. Each function's measured
error against a 300-bit reference, and the argument for why it is enough, is a
dated finding rather than a number here:
`notes/findings/2026-09-11-polynomial-transcendentals-for-bitwise-mode.md` for
`Float64`, `notes/findings/2026-09-11-float32-polynomial-transcendentals.md` for
`Float32`.

`ClimaComms.device()` reads environment variables when called with no argument, and
decision 0012 refuses that package partly for it. This layer takes the same lesson
one step further: there is no `device` function at all, so there is nothing to call
bare and nothing for `lint_no_env_device` to lint. The control is that no name
`device` is exported or defined in `Backends`, asserted by the suite.

### The reductions

```
pairwise_sum(::Type{A}, xs, backend; blocksize)         fixed-order, fixed block size, accumulator type explicit
compensated_sum(xs)                                     Kahan, FP64 accumulator regardless of eltype
segmented_sum(::Type{A}, xs, starts, backend)           one fixed-order tree per segment
segmented_mean(::Type{A}, xs, starts, weights, backend)
Segmentation(xs, starts)                                a boundary array checked once
segmented_sum(::Type{A}, xs, segmentation, backend)     the same reductions, nothing re-checked
segmented_mean(::Type{A}, xs, segmentation, weights, backend)
```

Every segmented reduction takes either a boundary array or a `Segmentation`. A
boundary array is checked on every call, which on a device-resident array means it
is copied to the host on every call. A `Segmentation` carries what the reduction
reads from it, the checked element count, the segment count, the boundaries on the
host and the per-segment `lo` and `hi` on the device they came from, so a caller
that holds one pays no host read per reduction. It is constructed and never looked
up, it holds its own copies, and it refuses at construction for exactly the four
conditions the per-call check refuses: an empty boundary array, one that is not
non-decreasing, one that does not begin at 1, and one that does not end at the
element count plus one. A malformed array is therefore refused on its first use
either way, and there is no memo that a later call could consult instead of
checking.

No atomics anywhere in the physics path, and no library reduction, because both
reassociate. The block size is fixed and declared, not chosen from the thread count,
which is what makes one-thread and sixteen-thread runs bitwise identical rather than
merely close. This is decision 0038's dividing line: dispatching independent items to
whichever worker is free is encouraged, and letting the order they finish in reach a
sum is forbidden.

The error bound is `k * N * eps * M` with `k` a small declared integer, `N` the term
count and `M` the magnitude, derived from floating point and never chosen
(REQ-NUM-004). `Fields` reads this bound for its ledger tolerances rather than
declaring its own, so a ledger's tolerance has one definition.

```
segmented_quantile(xs, starts, q, backend)    bitonic sort in shared memory, 4^k segments
segmented_quantile(xs, segmentation, q, backend)
area_fraction_above(xs, areas, x, backend)    the exact inverse
```

The segment count is `4^k` because that is the hierarchy's fan-out (decision 0005),
so a segment is a coarse cell's descendants at depth `k` and the sort fits shared
memory. `area_fraction_above` is the exact inverse of the quantile rather than an
interpolation of it: a hypsometric fraction that disagrees with the quantile it
inverts is two definitions of one quantity.

### Certification

```
envelope(case, steps)                          the sampled ulp-ensemble divergence envelope, over every usable site
exhaustive_envelope(case, steps, sites)         the same envelope, every one of `sites` perturbed and scored, none sampled
covers(envelope, sites, obligation)             whether envelope and a certification's own scope stand for one Obligation
certification(kernel, case, envelope; roundoff, sites = nothing)   the per-step numbers and verdict of one arm
certify(kernel, case, envelope; roundoff, sites = nothing)         PASS or FAIL from Verdicts, or a Refusal
case_certification(kernel, case, steps; roundoff)   every arm the case declares: the sampled envelope and one exhaustive arm per Obligation
certify_case(kernel, case, steps; roundoff)         PASS only when every arm case_certification runs is PASS
```

`envelope` runs a CPU ensemble whose members each have one field perturbed by one ulp
in one cell, and measures the divergence as a function of step count. A pair is not
an ensemble: the member count is declared and the registry states the miss rate that
count can detect, because a stochastic property tested by a pair is not tested.

An `EnsembleCase` carries an `Obligation` list beside its fields and its step
function: a named sub-population of `(field, cell)` sites that a certification of
that case must cover exhaustively, in addition to the sampled draw. `obligations`
has no default: a case with no sub-population the sampled draw is too coarse to
reach declares `Obligation[]` at its own construction site, so the emptiness is a
statement the case makes rather than a value this module supplied on its behalf.
The instance is the twelve degree-five vertices decision 0005 puts at every level of
an icosahedral mesh: their relative share falls below the ensemble's declared miss
rate as the mesh refines, so a sampled draw alone cannot see them
(`notes/findings/2026-09-11-ulp-ensemble-member-count.md`, section "What the
ensemble cannot see"), and `exhaustive_envelope` checks them in full instead
(`fiddlybits-52v.7.17`). `covers` decides whether one `Envelope` and one
certification's own site scope stand for a given `Obligation`: exact agreement
between the sites the envelope perturbed, the sites it scored, the certification's
own scope, and the obligation's own list.

`certify` returns an `OracleVerdict`, never a boolean, and refuses rather than
returning one when the envelope and scope it was given leave any of the case's
declared obligations uncovered, naming each by `covers`: a verdict reached over
part of a case's sites must not be read as a verdict on the case
(`fiddlybits-52v.7.19`). A case whose envelope could not be measured is a `Refusal`
naming what could not be measured, not a verdict, the same way: `NotEvaluable` is a
loop verdict and does not belong to this vocabulary, and a certification that
cannot be evaluated must not be readable as a pass.

`case_certification` and `certify_case` are the door that cannot omit an
obligation: given a case and a step count rather than a caller-built envelope, they
run the sampled arm and the exhaustive arm of every `Obligation` the case declares,
and the case-level verdict is `PASS` only when every arm is. The two registry rows
this certification serves, `repro.backend_ulp_envelope` and
`repro.fp32_kernel_certification`, now carry that requirement in their own threshold
text (`fiddlybits-52v.7.24`): a certification of a case that declares an
`Obligation` is not admissible from the sampled arm alone.

A kernel enters a production profile at FP32 only when its FP32 output stays inside
the envelope of its FP64 self. Ledgers, accumulated reservoirs and global reductions
run in FP64 accumulators or compensated summation whatever the working precision,
because a reservoir accumulating small increments at FP32 stagnates: the increment
falls below the ulp of the stock and is dropped in silence. Which quantities are
reservoirs is a field-level declaration this module cannot see, so the refusal of an
FP32 accumulator for a reservoir lives in the fields plan's ledger
(`fiddlybits-52v.3.6`). What this module provides is the choice: `compensated_sum`
always accumulates in FP64, and `pairwise_sum` takes its accumulator type as an
explicit argument rather than inferring it from the element type.

### The budget

```
budget(declarations)                   bytes, from declared element type and extent
refuse_over(declarations, ceiling)     refuses before a run starts, naming the overage
```

`declarations` is a plain description of what a run will allocate, one entry per
field with its element type and extent. The run refuses to start when the high-water
estimate exceeds the ceiling, rather than failing partway, and the refusal names the
fields in descending size so the reader sees what to cut.

## Oracles

Three registry entries already exist and are this plan's spine:
`repro.thread_count_bitwise`, `repro.backend_ulp_envelope` and
`repro.fp32_kernel_certification`. Three are added under a `kernels` subsystem, all
tier 1, all provisional.

| id | right answer | the mutation that must make it fail |
| --- | --- | --- |
| `kernels.reduction_partition_independent` | every reduction is bitwise identical across thread counts and across block partitions, and the error bound holds on adversarial inputs | an atomic accumulation substituted for the fixed-order tree, which must differ across thread counts; a sequence of alternating magnitudes that breaks a naive sum but not a compensated one |
| `kernels.segmented_quantile_exact` | the segmented quantile equals the exactly sorted answer bitwise for every `k` in the declared range, and `area_fraction_above` is its exact inverse | a quantile interpolated rather than selected, which must break the inverse identity |
| `kernels.memory_budget` | the budget equals the sum of declared field sizes, and a declaration over the ceiling refuses before allocation | a ceiling one byte below the estimate, which must refuse |

`repro.thread_count_bitwise` and `repro.backend_ulp_envelope` name the short coupled
case, which does not exist until a later milestone. Until it does, both run on a
stand-in this area can build without the mesh, which sits above it: a segmented
reduction over a synthetic `4^k` layout with a stencil-shaped gather over flat index
tables. The verify row records that the case is a stand-in and which oracle rows
still await theirs.
That is REPORT rather than PASS, and the distinction is the point: a bitwise claim
evidenced on arithmetic alone is not the claim the registry row states.

The reference path of decision 0027 is not an oracle row of its own. Every optimised
kernel here is checked against its own naive serial version to a tolerance derived
from floating point, inside the row that writes both.

## Rows filed

| row | tier | boundary | acceptance |
| --- | --- | --- | --- |
| 52v.7.2 | sonnet | `src/Backends/` except `certify.jl`, `budget.jl` and `transcendentals.jl`, `test/backends/` except `budget.jl` and `transcendentals.jl` | the same kernel is bitwise identical on CPU at 1 and 16 threads; CPU and GPU agree elementwise for pure arithmetic; bitwise mode is bitwise across backends for arithmetic and stencils; no name `device` is defined in the module; `on` records through `Events.moved` |
| 52v.7.8 | frontier | `src/Backends/transcendentals.jl`, `test/backends/transcendentals.jl` | each function bitwise between backends over a declared grid; each function's error against a 300-bit reference recorded with the argument for its bound; the Kepler solve bitwise between backends in bitwise mode, and not in fast mode, which is the control |
| 52v.7.3 | sonnet | `src/Reductions/` except `quantiles.jl`, `test/reductions/` | `kernels.reduction_partition_independent` passes with both controls firing; `pairwise_sum` takes its accumulator type explicitly and `compensated_sum` accumulates in FP64 whatever the element type |
| 52v.7.4 | frontier | `src/Backends/certify.jl`, `test/certify/` | a correct FP32 kernel certifies; a kernel with an injected error fails; an unmeasurable envelope is a `Refusal` naming what could not be measured, never a verdict; the ensemble member count and its detectable miss rate are declared |
| 52v.7.5 | sonnet | `src/Reductions/quantiles.jl`, `test/reductions/quantiles.jl` | `kernels.segmented_quantile_exact` passes with its control firing |
| 52v.7.6 | local | `src/Backends/budget.jl`, `test/backends/budget.jl` | `kernels.memory_budget` passes; the refusal names the fields in descending size |
| 52v.7.10 | frontier | `src/Backends/kernels.jl`, `test/backends/bitwise_mode.jl` | decision 0044: every multiply that feeds an add in bitwise mode is an explicit `fma`; the bitwise kernels agree bit for bit with the same chain evaluated at 256 bits, with the twice-rounded chain as the control that must disagree |
| 52v.7.13 | frontier | `src/Backends/transcendentals.jl`, `test/backends/transcendentals.jl` | a `Float32` coefficient set and reduction split beside the `Float64` one, each function bitwise between backends over a declared grid at `Float32`, each function's error against a 300-bit reference recorded with the argument for it, the `Float64` bounds already recorded unmoved |
| 52v.7.17 | sonnet | `src/Backends/certify.jl`, `test/certify/` | a certification of a case on a real mesh perturbs every degree-five vertex beside the sampled ensemble (`exhaustive_envelope`); a defect planted at one degree-five vertex alone is caught by the scoped check and shown missed by the sampled one alone |
| 52v.7.19 | frontier | `src/Backends/certify.jl`, `test/certify/` | a certification covering only the sampled sites cannot return `PASS` without the omission named (`Obligation`, `covers`, `certify`'s refusal, `case_certification`); the old-way positive control no longer reads as a clean pass; `test/certify/degree_five.jl` passes unchanged and the sampled envelope's own draw is unchanged |
| 52v.7.7 | sonnet | none; reports only | all six oracles ran; verdicts by name; the two that ran on a stand-in case recorded as REPORT with the case named |

52v.7.3, 52v.7.6 and 52v.7.8 depend on 52v.7.2; 52v.7.5 depends on 52v.7.3; 52v.7.4
depends on 52v.7.2 and 52v.7.3; 52v.7.2 depends on `fiddlybits-52v.6.8` for
`Events.moved`. 52v.7.10 depends on 52v.7.2, the row whose kernels it moved off the
fusion barrier. 52v.7.17 and 52v.7.19 both extend 52v.7.4's `certify.jl` and were
filed once it had already merged; neither carries a dependency edge of its own in
the tracker beyond the parent epic. 52v.7.13 depends on 52v.7.15, outside this
plan's own file boundary (`test/lint/lists/literals.toml`, decision 0045's
`precision_pinned` entry), for the lint room its `Float32` constants need.

Several rows were filed against the same epic once a defect or a design question
turned up during implementation, and stay out of this table because they name no
function or type this plan states and their own file boundary is not
`src/Backends/` or `src/Reductions/`: 52v.7.14 and 52v.7.21 route
`src/Orbit/kepler.jl` through these transcendentals and through `fma`; 52v.7.9,
52v.7.11, 52v.7.12, 52v.7.15, 52v.7.16, 52v.7.18, 52v.7.20, 52v.7.23, 52v.7.24 and
52v.7.26 are findings, registry text, a lint list entry, a gate call-site fix and a
reference-index status. One of them is cited above because this plan's own prose
still depends on what it will carry: 52v.7.22, open, is the lint that will check
the fusion rule this plan states as decision 0044's rule.
