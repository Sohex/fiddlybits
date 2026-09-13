# The per-lane block kernel's fixed cost on the card is one thread's serial loop of bounds-checked reads, and no kernel text that keeps its bounds checks reaches the shared-memory form

Measured on 2026-09-13 on yggdrasil through `qrun -p gpu` (all four shares of the NVIDIA
GeForce RTX 4090, 8 CPUs, 24G, 18G of vram), Julia 1.12.7, CUDA.jl 6.3.1 (CUDACore
6.3.1), KernelAbstractions.jl 0.9.42, CUDA driver and runtime 13.3, on branch
`fiddlybits-ewx` at `e8cdc1a96388e8552ab86b7b5181a4d9770b231c`, with the kernels of
`src/Reductions/pairwise.jl` as merged there. The row is `fiddlybits-ewx`; the question
is the one `notes/findings/2026-09-13-block-sums-in-shared-memory.md` left open in
"Where pairwise_sum spends its time".

Two timing jobs, each holding all four shares, so no other job could reach the card while
either ran. Every row was bracketed by `squeue`, and every row of both jobs read no other
running job holding a share before it or after it. Host load 3.8 to 6.7. The probe
scripts lived outside the tree; the kernels they launched are described below by what
they change against `Reductions.pairwise_block_kernel!`.

## The instrument

Every row reports three numbers, in microseconds per call:

- **batch**: the statistic of the 2026-09-13 block-sum finding. Batches of 400 calls
  closed by one `Backends.complete!`, the minimum over 60 batches of the mean per call.
- **host**: the same batches timed from the first launch to the last, before the
  completion, so only what `Backends.launch!` costs the host.
- **device**: a timing `CUDA.CuEvent` recorded on the stream before and after each of
  200 calls. It reads in steps of 1.024 us and, when the host is slower than the card,
  measures the host too; it is quoted only to confirm the other two.

When the card finishes a kernel faster than the host can launch the next, batch equals
host. When it does not, batch minus host is time on the card.

Positive controls, both run in each job:

| control | host | batch |
| --- | --- | --- |
| shared-memory kernel, level 5, as is | 3.404 | 6.166 |
| the same with a 15 us host busy-wait before each launch | 18.524 | 18.545 |
| per-lane kernel, one block of `2^16` elements, one active thread | 4.365 | 3929.835 |

The busy-wait moves host by 15.1 and batch with it; the long loop leaves host where it
is and moves batch by three orders of magnitude. The instrument separates the two.

Host was between 3.33 and 3.59 in every row of both jobs except the busy-wait control,
whatever the kernel, element count or workgroup. **Nothing on the launch path differs
between the kernels.** The host side of KernelAbstractions' CUDA launch is the same
code for all of them (`CUDACore/src/CUDAKernels.jl`, the `KA.Kernel{CUDABackend}` call),
and it costs about 3.4 us.

The level 5 and level 7 pair of the block-sum finding reproduces: per-lane 22.085 and
25.416, shared-memory 6.166 and 25.689. Rerun at the end of the first job: 22.013,
25.591, 6.163, 25.533.

## What moves it: the length of one thread's loop

The per-lane kernel over 80 blocks, varying only the blocksize, so the loop each thread
runs, at the tree's workgroup of 256 (one CUDA block of 256 threads) and at a workgroup
of 1 (80 blocks of one thread):

| blocksize | batch at wg 256 | batch at wg 1 |
| --- | --- | --- |
| 1 | 3.450 | 3.543 |
| 4 | 3.498 | 3.555 |
| 16 | 3.535 | 3.573 |
| 64 | 6.580 | 5.010 |
| 256 | 22.067 | 15.949 |
| 1024 | 84.343 | 58.608 |

Up to sixteen reads per thread the kernel costs the host's launch and nothing
measurable on the card. From 64 it grows with the loop: at a workgroup of 256 the excess
over sixteen reads is 3.0, 18.5 and 80.8 us at 64, 256 and 1024, and at a workgroup of 1
it is 1.4, 12.4 and 55.0.

The block count at a blocksize of 256, so every thread runs the same 256-iteration loop:

| blocks | batch at wg 256 | CUDA blocks x threads | batch at wg 1 |
| --- | --- | --- | --- |
| 1 | 15.673 | 1 x 256 | 15.671 |
| 5 | 16.504 | 1 x 256 | 15.666 |
| 20 | 19.538 | 1 x 256 | 15.938 |
| 80 | 22.044 | 1 x 256 | 15.946 |
| 320 | 25.371 | 2 x 256 | 16.131 |
| 1280 | 25.421 | 5 x 256 | 19.194 |
| 5120 | 25.533 | 20 x 256 | 74.369 |

**One thread running one 256-iteration loop costs 15.7 us**, and eighty of them in
parallel cost the same when each has its own CUDA block. That is the fixed cost: the
kernel's wall time is the time one thread takes to walk its block, and the reads are
serial inside the thread whatever their number across threads. At level 7 the per-lane
kernel costs 16 per cent more than at level 5 for sixteen times the reads because the
reads are sixteen times as many threads, not a longer loop.

## What the loop spends: checked reads first, then the reads, then lockstep in one block

Over the same 80 blocks of 256 elements, kernels that each remove one thing:

| kernel | wg | batch |
| --- | --- | --- |
| `pairwise_block_kernel!` as merged | 256 | 22.105 |
| the same | 1 | 16.071 |
| the loop under `@inbounds`, the write too | 256 | 14.353 |
| the same | 1 | 11.793 |
| the `@inbounds` loop without `@Const` on `xs` | 1 | 12.866 |
| the loop kept, `acc += T(j)` in place of the read | 1 | 6.308 |
| the loop removed, the block's first element read once | 1 | 3.441 |
| `pairwise_block_shared_kernel!` as merged | 256 | 6.166 |

Read top to bottom at a workgroup of 1, 16.1 us is about 3.4 of launch, 2.9 of a
256-iteration loop with no read, 5.5 of 256 reads with no bounds check, and 4.3 of the
bounds checks on those reads. Putting the 80 threads in one CUDA block adds 6.0 with the
checks and 2.6 without them, so the lockstep cost scales with what each iteration costs
and the parts do not add independently. `@Const` is not a cost: without it the
`@inbounds` kernel is 1.1 slower, not faster.

At the element counts `pairwise_sum` and the segmented kernels read, then, the per-lane
kernel's cost is one thread's serial loop over device global memory, and the largest
single part of that loop is the bounds check on each read. What the check costs on the
device at the instruction level was not measured.

The workgroup sweep of the block-sum finding is the lockstep part: at 80 blocks, 22.1 us
for every workgroup from 1024 down to 32 (one to three CUDA blocks), 18.7 at 16, 17.4 at
8, 16.5 at 4, 15.9 at 2 and 16.1 at 1.

## Why the shared-memory form costs 6.2

Its accumulation is the same 256-iteration serial loop, over the workgroup's `@localmem`
copy rather than global memory, and it costs 6.166 against 6.308 for a loop with no read
at all. The copies into shared memory are one read per lane, and one read per thread
costs nothing measurable (the one-read row). So the form removes the checked global reads
from the serial loop by moving each to its own lane.

It is not the layout that pays. A kernel with the shared-memory form's layout, one
workgroup of 256 lanes per block with lane 1 accumulating, that reads its block from
global memory in lane 1 instead of from `@localmem`, is bitwise identical on the card to
`pairwise_block_kernel!` and costs 15.937, the same as the per-lane kernel at a workgroup
of 1 (15.933).

## One kernel text

Kernels bitwise identical on the card to `pairwise_block_kernel!` at 20480 and 327680
elements (and, for the one-workgroup-per-block kernel reading global memory, also at
327717, 100 and 1 elements, a blocksize of 17, and `Float32` elements and accumulator,
each with a positive control that changes the last element and requires exactly the
last block to move):

| kernel | level 5 | level 7 |
| --- | --- | --- |
| `pairwise_block_kernel!` at wg 256, as merged | 22.085 | 25.416 |
| `pairwise_block_shared_kernel!`, the device form | 6.166 | 25.689 |
| one workgroup per block, lane 1 reads global memory | 15.937 | 37.834 |
| the same with the loop and write under `@inbounds` | 7.366 | 26.263 |
| per-lane under `@inbounds` at wg 16 | 12.321 | 12.479 |
| per-lane under `@inbounds` at wg 1 | 11.793 | 19.154 |
| per-lane as merged at wg 16 | 18.746 | 18.896 |
| per-lane as merged at wg 1 | 15.933 | 19.195 |

(The level 7 rows of the second job's anchors were 25.432 and 25.569; its level 5 anchor
rows were skipped by the probe's per-row bound, and the level 5 anchors above are the
first job's.)

- **No kernel text that keeps its bounds checks reaches the device form at level 5.**
  The fastest checked text measured is the per-lane kernel at a workgroup of 1, 15.9,
  which is a launch parameter and not a text, and 2.6 times the device form.
- **The fastest text measured at all is 1.2 us above the device form at level 5**: one
  workgroup per block with lane 1's global reads under `@inbounds`, 7.366 against 6.166,
  about 19 per cent. Its cost is the bounds check this tree does not elide:
  `docs/decisions/0050-the-gate-reports-what-pkg-test-reports.md` records that the tree
  elides no bounds check of its own and has `nightly` assert it.
- **At level 7 a single text beats the device form.** Per-lane under `@inbounds` at a
  workgroup of 16 costs 12.5 against 25.7; without `@inbounds`, per-lane at 16 costs
  18.9. Which workgroup is fastest depends on the block count: a workgroup of 1 costs
  15.9 at 80 blocks and 74.4 at 5120.
- The CPU cost of the single-text candidates was not measured: none reaches the device
  form at level 5, so none meets the removal condition of decision 0051 whatever it costs
  on the CPU backend.

## The long-loop control that outlived its job

A first probe job, holding one share, ran its device control at a `2^20`-element block
with the same 400-call, 60-batch statistic as every other row, and reached its 30-minute
walltime inside that row having printed nothing after the row before. A diagnostic job
beside the gate's share (so its absolute numbers are not counted) timed single calls of
that kernel over loops of `2^8` to `2^20` iterations: 93 ms per call at `2^20`, 40 to 90
ns per iteration across the range, bitwise equal to `pairwise_sum_reference` at each.
Nothing hung: 24000 calls at 93 ms is 37 minutes. It is the same per-iteration cost as
the tables above, carried to a million iterations. The counted jobs ran the control at
`2^16` with 20 calls in 10 batches, and every row first timed one synchronised call
against a bound.

## Anomalies not explained here

- The loop with no read, at 1280 blocks of one thread, costs 34.6, above the loop with
  checked reads at the same launch, 19.2. The three-part split above is quoted at 80
  blocks only.
- One workgroup per block with lane 1 under `@inbounds` costs 7.4 at level 5 against
  11.8 for per-lane under `@inbounds` at a workgroup of 1, the same unchecked reads in
  the same number of one-thread loops. The two differ in the loop's bounds (`1:cnt` at an
  offset against `lo:min(i*blocksize, n)`) and in 255 idle lanes per block.
