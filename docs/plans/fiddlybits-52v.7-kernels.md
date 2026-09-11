+++
epic = "fiddlybits-52v.7"
title = "The portable kernel layer, the partition-independent reductions, and the precision certification"
decisions = ["0011", "0027", "0029", "0038"]
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
| `src/Backends/` | the device abstraction, `Adapt`, the layout convention, `on`, the budget | 52v.7.2, 52v.7.6 |
| `src/Backends/certify.jl` | the envelope measurement and the certification verdict | 52v.7.4 |
| `src/Reductions/` | fixed-order pairwise and compensated sums, segmented reductions, quantiles | 52v.7.3, 52v.7.5 |
| `test/backends/` | the backend suite, the bitwise mode, the budget suite | 52v.7.2, 52v.7.6 |
| `test/reductions/` | the reduction and quantile suites with their adversarial inputs | 52v.7.3, 52v.7.5 |
| `test/certify/` | the ulp-ensemble harness and its injected-error control | 52v.7.4 |

`Backends` references `Verdicts` and nothing else in the tree. `Reductions`
references `Backends` and `Verdicts`. Neither references `Mesh`, `Fields`, `Systems`
or `Dimensions`, and `build.module_order_acyclic` is what holds that.

## Types and functions

### The device layer

```
abstract type Backend end
struct CPU <: Backend   ...
struct GPU <: Backend   ...

device(component)            the backend a component declares
on(array, backend)           move, recording the move
adapt_for(x, backend)        Adapt.adapt_structure through to the device
launch!(kernel, backend, n)  one launch, workgroup size from the backend
```

Arrays are laid out cells-first, so consecutive threads touch consecutive addresses,
with the vertical loop inside the thread. The convention is `(cells, levels)` and it
is a declared constant of this module, read by `Fields` rather than restated there,
because a layout restated in two places is two conventions.

`on` records every move. A move is a thing that happened to a field, and decision
0010 puts it in the provenance record, so the recording hook is declared here and
`Provenance` fills it; the hook's default is a no-op and the no-op is what the
inertness of decision 0042 requires.

**The bitwise mode** is a backend property, not a flag read from the environment.
In bitwise mode both backends use the same pure-Julia arithmetic with no fast-math,
no implicit fused multiply-add, the project's own polynomial transcendentals where
needed, and the same reduction trees. A difference in this mode is a kernel defect
and not roundoff, which is what makes it the debugging oracle rather than a
tolerance.

`ClimaComms.device()` reads environment variables when called with no argument, and
decision 0012 refuses that package partly for it. This layer takes the same lesson:
`device` is a function of the component's declaration, there is no zero-argument
form, and `lint_no_env_device` is not needed here because no such call exists to
lint. The control is that `device()` with no argument is a `MethodError`.

### The reductions

```
pairwise_sum(xs; blocksize)      fixed-order, fixed block size
compensated_sum(xs)              Kahan, FP64 accumulator regardless of eltype
segmented_sum(xs, segments)      one fixed-order tree per segment
segmented_mean(xs, segments, weights)
```

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
segmented_quantile(xs, segments, q)    bitonic sort in shared memory, 4^k segments
area_fraction_above(xs, areas, x)      the exact inverse
```

The segment count is `4^k` because that is the hierarchy's fan-out (decision 0005),
so a segment is a coarse cell's descendants at depth `k` and the sort fits shared
memory. `area_fraction_above` is the exact inverse of the quantile rather than an
interpolation of it: a hypsometric fraction that disagrees with the quantile it
inverts is two definitions of one quantity.

### Certification

```
envelope(case, steps)              the ulp-ensemble divergence envelope per step
certify(kernel, case, envelope)    PASS, FAIL or NotEvaluable, by name
```

`envelope` runs a CPU ensemble whose members each have one field perturbed by one ulp
in one cell, and measures the divergence as a function of step count. A pair is not
an ensemble: the member count is declared and the registry states the miss rate that
count can detect, because a stochastic property tested by a pair is not tested.

`certify` returns the verdict vocabulary of `Verdicts`, never a boolean, so a case
whose envelope could not be measured says `NotEvaluable` rather than passing.

A kernel enters a production profile at FP32 only when its FP32 output stays inside
the envelope of its FP64 self. Ledgers, accumulated reservoirs and global reductions
run in FP64 accumulators or compensated summation whatever the working precision,
because a reservoir accumulating small increments at FP32 stagnates: the increment
falls below the ulp of the stock and is dropped in silence. That is a refusal here,
not a warning: `Reductions` refuses an FP32 accumulator for a quantity declared a
reservoir.

### The budget

```
budget(declarations)               bytes, from declared element type and extent
refuse_over(budget, ceiling)       refuses before a run starts, naming the overage
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
case, which does not exist until a later milestone. Until it does, both run on the
largest case this milestone has, a stencil sweep over a refined mesh, and the verify
row records that the case is a stand-in and which oracle rows still await theirs.
That is REPORT rather than PASS, and the distinction is the point: a bitwise claim
evidenced on arithmetic alone is not the claim the registry row states.

The reference path of decision 0027 is not an oracle row of its own. Every optimised
kernel here is checked against its own naive serial version to a tolerance derived
from floating point, inside the row that writes both.

## Rows filed

| row | tier | boundary | acceptance |
| --- | --- | --- | --- |
| 52v.7.2 | sonnet | `src/Backends/` except `certify.jl` and `budget.jl`, `test/backends/` | the same kernel is bitwise identical on CPU at 1 and 16 threads; CPU and GPU agree elementwise for pure arithmetic; bitwise mode is bitwise across backends; `device()` with no argument is a `MethodError` |
| 52v.7.3 | sonnet | `src/Reductions/` except `quantiles.jl`, `test/reductions/` | `kernels.reduction_partition_independent` passes with both controls firing; an FP32 accumulator for a declared reservoir refuses |
| 52v.7.4 | frontier | `src/Backends/certify.jl`, `test/certify/` | a correct FP32 kernel certifies; a kernel with an injected error fails; an unmeasurable envelope returns `NotEvaluable` by name; the ensemble member count and its detectable miss rate are declared |
| 52v.7.5 | sonnet | `src/Reductions/quantiles.jl`, `test/reductions/quantiles.jl` | `kernels.segmented_quantile_exact` passes with its control firing |
| 52v.7.6 | local | `src/Backends/budget.jl`, `test/backends/budget.jl` | `kernels.memory_budget` passes; the refusal names the fields in descending size |
| 52v.7.7 | sonnet | none; reports only | all six oracles ran; verdicts by name; the two that ran on a stand-in case recorded as REPORT with the case named |

52v.7.3 and 52v.7.6 depend on 52v.7.2; 52v.7.5 depends on 52v.7.3; 52v.7.4 depends on
52v.7.2 and 52v.7.3.
