+++
id = "0058"
title = "A kernel's launch workgroup is chosen per launch at Backends.launch_workgroup from the work item count: on the card the fewest threads per CUDA block that keeps the launch within the blocks the card runs at once and never past its warp, on the CPU one work item per block, and a kernel whose layout fixes its workgroup pins it"
status = "accepted"
date = 2026-09-13
+++

## Decision

**Who chooses.** The workgroup a kernel launched through `Backends.launch!` runs at is
chosen at one door, `Backends.launch_workgroup(backend, n)`, from the backend's kind
and the launch's work item count `n`. The caller does not choose it: `Backends.GPU()`
and `Backends.CPU()` carry no workgroup, and every caller in `Reductions` and the bench
bed hands one of them. `Backends.launch!` records the workgroup each launch ran at in
`Backends.queued_launches`.

A backend may be pinned to a workgroup, `GPU(w)` or `Backends.at_workgroup(backend, w)`,
and a pinned backend launches at its pin. A pin is for two things: a kernel whose layout
fixes its workgroup, and an oracle or probe that varies the launch partition on purpose.

**The rule on the card.** The smallest power of two `w` whose block count `cld(n, w)` is
at most the card's blocks-at-once bound, and never more than the card's warp size. The
warp size is read from the driver (`CUDA.warpsize`). The bound is a property of the card,
held per card name in `Backends.GPU_BLOCKS_AT_ONCE` with the finding that measured it; a
card with no entry refuses its first unpinned launch, naming itself, rather than borrow
another card's bound.

**What sets the minimum.** Two mechanisms of how the card runs a launch, each moved on
demand by a sweep in
`notes/findings/2026-09-13-the-launch-workgroup-is-set-by-blocks-at-once-and-the-warp.md`:

1. **Blocks queue past a bound.** A launch's cost is a function of its CUDA block count.
   The same number of blocks costs the same whether each holds one thread or sixteen; the
   cost stays at one block's loop up to a count, and grows in proportion to the block
   count past it. The bound is the largest power-of-two block count at which every
   per-lane kernel of `Reductions`, launched one thread per block, still runs at that
   floor.
2. **Threads of one block cost each other.** Under the bound, more threads per block is
   never cheaper: a little dearer up to the warp size, a step dearer past it, and in
   proportion to the thread count once a block holds more threads than the card runs of
   one block at once. The kernels with the most work per iteration pay the most.

Fewer threads per block than the rule gives puts blocks in the queue of (1); more buys
nothing from (1) and pays (2). Past the item count at which a warp per block still leaves
more blocks than the bound, a wider block would shorten the queue, and the sweeps show it
within the run's spread of the warp at the lightest kernel and dearer at the heavier
ones, and dearer at every kernel once a block holds more threads than the card runs of
one block at once: the cap is the warp.

**Why the rule transfers.** It reads the item count, which every launch knows, and two
properties of the device; no bench case enters it. The loop length a work item runs is
not an input: it sets the cost of one block, and the sweeps over loop lengths show both
mechanisms scaling that cost without moving where it is least. The warp size is what the
driver of any CUDA card reports. The bound is a card property with a named sweep that
measures it, and a new card is refused until that sweep has been run on it. A kernel
added to `Reductions` whose queue starts below the bound lowers the entry: the sweep is
run over it too.

**What the rule gives up.** It is not the fastest workgroup on every shape. For a kernel
whose threads cost each other most, a launch that lets a few blocks queue at a smaller
workgroup can be faster; choosing that trade needs the kernel's own costs of queueing and
of lockstep, which is a per-kernel fit to one card. The rule takes the side whose error
is small: a launch under the bound's workgroup costs a multiple, one over it within the
warp costs a fraction.

**Quantile kernels and the shared-memory device forms.** Their workgroup is their layout:
one workgroup per segment of `4^k` for `segmented_bitonic_kernel_*!`, one per block of
`blocksize` for the block-sum device forms, because the barrier and the `@localmem` apply
across exactly one workgroup. They launch pinned through `Backends.at_workgroup` and the
rule is not consulted. What the rule says about them is their cost: those workgroups are
past the warp, so they pay mechanism (2) as their lane count grows, and that is what
bounds a block-sum device form's advantage. Each device form's limit
(`Reductions.device_form_limit`) is measured against its portable kernel launched under
this rule, and is re-measured whenever either moves.

**On the CPU, one work item per block.** KernelAbstractions' CPU launch hands each Julia
thread a contiguous run of blocks. Fewer blocks per thread is measured slower, never
faster, and one block per work item is as fast as any, so there is nothing to trade and
the rule there is 1: every unpinned CPU launch also compiles one variant of its kernel.

## Alternatives considered

- **The Backend's one workgroup, chosen by the caller**, as the tree had it. Lost: the
  cheapest workgroup moves with the item count across the reductions' own shapes by the
  whole range from one thread to a warp, and a caller holds one value for every launch.
  The bench bed's value was past the warp, and cost the level 7 block sums and the
  segmented kernels a large share of their time.
- **A per-kernel method the launch door calls**, deriving the workgroup from what one
  work item reads. Lost: the loop length does not move the minimum, and what does differ
  between kernels, how steeply they queue and how much their threads cost each other, is
  a fit of each kernel to one card, repeated per kernel.
- **The driver's occupancy API**, `CUDA.launch_configuration`, which KernelAbstractions
  consults when no workgroup is given. Lost: it reports the same active blocks per
  multiprocessor for every kernel of the tree and suggests a block width past the warp
  for all of them, at which every per-lane kernel measured slower.
- **The warp size alone, with no bound.** Lost at small item counts, where one thread per
  block costs the heavier kernels measurably less than a warp per block.
- **A calibration timed at the first launch of each process.** Lost: it puts a timing,
  with its scatter, inside a run, and lets the choice differ between two processes of the
  same configuration; the bound is measured once per card, with controls, where its
  scatter can be read.
- **No pin at all.** Not taken: a kernel whose shared memory spans one workgroup needs
  its workgroup fixed, and `kernels.reduction_partition_independent` launches the same
  reduction at different workgroups to show the result does not move.

## Consequences

- Decision 0029's partition independence keeps this out of every result: every reduction
  is bitwise identical before and after on the registered cases, and
  `kernels.reduction_partition_independent` compares unpinned launches against pinned
  ones and reads back the workgroups they ran at.
- `Reductions.PAIRWISE_DEVICE_FORM_MAX` is re-measured against the portable kernel under
  this rule, and the area-weighted and area-fraction device forms, which had no limit,
  gain `Reductions.AREA_WEIGHTED_DEVICE_FORM_MAX` and
  `Reductions.AREA_FRACTION_DEVICE_FORM_MAX` from the same measurement.
- The bench bed hands `Backends.GPU()` and records the door rather than a number.
- A card other than the one measured refuses every unpinned launch until its entry in
  `Backends.GPU_BLOCKS_AT_ONCE` is measured.
- A backend pinned outside `Reductions`, in a test that chose a workgroup, keeps launching
  at its pin.
- `docs/plans/fiddlybits-52v.7-kernels.md` states that `launch!` takes its workgroup from
  the backend; `fiddlybits-xe8` carries the correction there.

## References

- `notes/findings/2026-09-13-the-launch-workgroup-is-set-by-blocks-at-once-and-the-warp.md`:
  the sweeps that separate the two mechanisms, their positive controls, the bound, the CPU
  backend, the device-form limits and the bench before and after.
- `notes/findings/2026-09-13-the-segmented-kernels-shared-memory-form-is-slower-on-every-bench-case.md`,
  section "The launch workgroup", and
  `notes/findings/2026-09-13-the-per-lane-block-kernel-pays-for-one-thread-s-checked-serial-reads.md`:
  the sweeps that raised the question.
- `notes/findings/2026-09-13-the-block-sum-device-forms-against-one-inbounds-text.md`: the
  device-form limits measured at the bench's former workgroup.
- Decision 0029, partition independence; decision 0038, a stage sized to its own
  resource; decision 0051, device forms and their limits; decision 0055, the kernel texts
  measured here.
- `KernelAbstractions/src/cpu.jl`, `__run` and `__thread_run`, the CPU launch's split of
  blocks across threads; `CUDACore/src/CUDAKernels.jl`, the CUDA launch of `cld(n, w)`
  blocks of `w` threads and the dynamic path through `launch_configuration`;
  `CUDACore/lib/cudadrv/occupancy.jl` and `CUDACore/lib/cudadrv/devices.jl`, the occupancy
  API and `warpsize`.
