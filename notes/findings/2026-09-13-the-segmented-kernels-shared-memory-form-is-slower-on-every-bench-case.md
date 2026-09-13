# The segmented kernels' shared-memory device form is bitwise identical and slower on every bench case, and the launch workgroup is what moves them

Measured on 2026-09-13 on yggdrasil through `qrun -p gpu` (all four shares of the NVIDIA
GeForce RTX 4090, 8 CPUs, 16G, 18G of vram), Julia 1.12.7, CUDA.jl 6.3.1 (CUDACore
6.3.1), KernelAbstractions.jl 0.9.42, CUDA driver and runtime 13.3, on branch
`fiddlybits-zgh` at `18bc588faecdb02ad8c17edf96a3281a1fb0f68e`, with
`src/Reductions/segmented.jl` at sha256
`0802b41f7dc41d522763f60b457885c0385c61c7ec46cd1ffb7dd49889871874` and `bench/runbench.jl`
at sha256 `fccd602f9693e7146fe9b6c9e4b297297d80cde119aec16ca2fca5b2b57c5ddc`. The row is
`fiddlybits-zgh`; nothing under `src/` was changed.

Two timing jobs, 1763 and 1766, each holding all four shares. Every one of the 206 timing
rows read no other running job holding a share before it and after it, and no row was
skipped by its bound. Host load 1.88 to 3.97. The probe scripts lived outside the tree;
the kernels they launched are described below by what they change against
`Reductions.segmented_sum_kernel!` and `Reductions.segmented_weighted_sum_kernel!`.

## The cases and the kernels

The bench bed's segmented cases: the 327680 cells of level 7, segmented at level 5 (depth
two, 20480 segments of 16) and at level 4 (depth three, 5120 segments of 64), with the
bed's own fixture elements, weights and `Segmentation`.

- **(a)** the kernels as merged: one work item per segment, reading `lo[seg]:hi[seg]`
  from global memory, launched at the bed's workgroup of 256.
- **(b)** a device form in the shape of `Reductions.pairwise_block_shared_kernel!`: `n`
  work items at a workgroup of the segment length, one workgroup per segment. Every lane
  copies its element into `@localmem` (for the weighted sum, its product
  `Backends.nofuse_mul(xs[j], weights[j])`, as `area_weighted_block_shared_kernel!` copies
  its selected area), and after the barrier lane 1 accumulates the copy in index order.
  It reads no `lo` or `hi`, so it serves only a segmentation whose segments share one
  length; every level crossing of decision 0005 does.
- **(c)** the as-merged text with its loop and its write under `@inbounds`, for the
  pending decision on bounds-check elision
  (`docs/decisions/0050-the-gate-reports-what-pkg-test-reports.md` records that the tree
  elides none).

## The instrument

The instrument of
`notes/findings/2026-09-13-the-per-lane-block-kernel-pays-for-one-thread-s-checked-serial-reads.md`,
in microseconds per call: **batch**, the minimum over 60 batches of 400 calls closed by one
`Backends.complete!` of the mean per call; **host**, the same batches timed up to the
completion; **device**, `CUDA.CuEvent` pairs over 200 calls, quoted only to confirm. Each
row first times the fastest of five synchronised calls, and is skipped if that projected
over its calls exceeds 30 s.

A **call** row is what the bed times: allocate the result with `similar` and launch. A
**kernel** row launches into a preallocated result. The call row through
`Reductions.segmented_sum` or `Reductions.segmented_weighted_sum` itself is beside them,
and agrees with the call row of (a) within 0.14 on every case.

Positive controls, both jobs:

| control | job | host | batch |
| --- | --- | --- | --- |
| `pairwise_block_kernel!`, level 5, wg 256 | 1763 | 3.472 | 22.038 |
| `pairwise_block_shared_kernel!`, level 5 | 1763 | 3.636 | 6.138 |
| (b) sum call at depth two with a 15 us host busy-wait | 1763 | 19.604 | 19.663 |
| (a) sum kernel over one segment of `2^16` | 1763 | 5.541 | 3944.351 |
| `pairwise_block_kernel!`, level 5, wg 256 | 1766 | 3.479 | 22.072 |
| `pairwise_block_shared_kernel!`, level 5 | 1766 | 3.550 | 6.142 |
| (b) sum call at depth two with a 15 us host busy-wait | 1766 | 19.768 | 19.840 |
| (a) sum kernel over one segment of `2^16` | 1766 | 4.458 | 3854.346 |

The busy-wait moves host and batch together; the long loop moves batch alone. The two
pairwise rows reproduce the ewx pair (22.085 and 6.166), and rerun at the end of each job
read 22.121 and 6.162, then 22.249 and 6.163.

## The arithmetic did not move

On the card, (b) and (c) against (a), bitwise, for both kernels, over segments of 16, 64,
4 and 1024 elements at level 7 (level 5, 4, 6 and 2), one element per segment at level 5,
80 elements in segments of 4, and at depth two and three with `Float32` elements into a
`Float64` accumulator, `Float32` throughout, `Float64` elements with `Float32` weights and
accumulator, and `Float32` elements with `Float32` weights into `Float64`: every
comparison equal. On every shape (a) was also bitwise equal to the tree's public
`segmented_sum` and `segmented_weighted_sum` and to `segmented_sum_reference`.

Positive control on every shape: the last element and the first element of segment 2
changed, and in (a) and (b), for both kernels, exactly segments 2 and the last moved, with
(a) and (b) still bitwise equal on the changed input. An order control, (b) with lane 1's
loop reversed, differed from (a) in 417 to 12643 bytes on the level 7 `Float64` shapes, and
in 0 bytes on one-element segments and on `Float32` elements summed in `Float64`, where
every order gives the exact sum.

(a) and (c) launched at workgroups 64, 32, 16, 8 and 4 were bitwise equal to (a) at 256 on
both bench cases, for both kernels.

## Before and after

Job 1763, the median over three interleaved rounds of the batch statistic, call rows:

| case | (a) | (b) | (b) less (a) | pc | (c) | (c) less (a) | pc |
| --- | --- | --- | --- | --- | --- | --- | --- |
| segmented_sum, depth 2 | 4.378 | 18.945 | +14.567 | +333 | 4.529 | +0.151 | +3.4 |
| segmented_sum, depth 3 | 7.789 | 19.639 | +11.850 | +152 | 7.515 | -0.274 | -3.5 |
| segmented_weighted_sum, depth 2 | 5.335 | 20.178 | +14.843 | +278 | 5.214 | -0.121 | -2.3 |
| segmented_weighted_sum, depth 3 | 16.184 | 20.531 | +4.347 | +27 | 15.656 | -0.528 | -3.3 |

Kernel rows give the same differences within 0.02, except (c) at depth two of the sum,
+0.130. The three rounds of each call row span at most 0.177 (the sum at depth two), and
at most 0.013 on the other three cases.

What a difference has to clear, from `notes/findings/2026-09-12-reduction-bench-scatter.md`
in the units above:

| case | bed mean | full range of one run | as us | one pc of the mean |
| --- | --- | --- | --- | --- |
| segmented_sum, depth 2 | 4.345 | 5.6 pc | 0.24 | 0.04 |
| segmented_sum, depth 3 | 7.827 | 2.7 pc | 0.21 | 0.08 |
| segmented_weighted_sum, depth 2 | 5.347 | 4.2 pc | 0.22 | 0.05 |
| segmented_weighted_sum, depth 3 | 16.393 | 15.2 pc | 2.49 | 0.16 |

The probe's call rows of (a) sit within 3.5 pc of the bed means. Between the two jobs the
(a) kernel rows agree within 0.06, except the weighted sum at depth three, 16.170 against
15.519, 4.0 pc apart, the case whose one-run range on the bed is also the widest.

- **(b) clears the A/A range on every case, as a loss**: by 11.9 to 14.8 us on three cases
  and 4.3 us on the weighted sum at depth three, against one-run ranges of 0.21 to 2.49.
  It is slower than (a) by between a quarter and more than four times.
- **(c) moves by 0.12 to 0.53 us at depth three and on the weighted sum at depth two**, 2.3
  to 3.5 pc: over the one per cent the mean of twenty resolves and over the probe's own
  round spread, and over the bed's one-run range only for the sum at depth three. At
  depth two of the sum it does not move; job 1766 put that difference at -0.031.

## What the device form costs

(b) costs 18.9 to 20.5 in all four cases: about the same at 16 and at 64 elements per
segment, and for the sum and the weighted sum, over 3.4 to 3.6 of host. The sum's device
form over segments of 16, at three element counts (job 1766, kernel rows):

| crossing | elements | (a) | (b) |
| --- | --- | --- | --- |
| level 5 over level 3 | 20480 | 3.618 | 3.452 |
| level 6 over level 4 | 81920 | 3.697 | 6.000 |
| level 7 over level 5 | 327680 | 3.705 | 18.880 |

The device form's time on the card grows with the lanes it launches, from nothing
measurable at 20480 to 2.6 at 81920 and 15.5 at 327680, while (a) at the same segment
length stays at the launch floor. At the bench's element count the per-lane kernels have
between nothing and 12 us on the card to remove, and the device form adds 15 or more of
its own. The block-sum device form paid at level 5 of `pairwise_sum` because its 20480
lanes sit below that growth and its per-lane rival ran 256-read loops; here the lanes are
sixteen times as many and the loops 16 or 64 reads.

## The launch workgroup

For information, (a) and (c) as kernel rows at other workgroups, job 1766, median of three
rounds (each spanning at most 0.15). The CUDA launch is `cld(nseg, wg)` blocks of `wg`
threads. The workgroup 1 rows are job 1763, one sample each.

| kernel, case | 256 | 64 | 32 | 16 | 8 | 4 | 1 |
| --- | --- | --- | --- | --- | --- | --- | --- |
| (a) sum, depth 2 | 3.736 | 3.723 | 3.774 | 3.690 | 4.093 | 6.403 | 19.307 |
| (a) sum, depth 3 | 7.762 | 6.831 | 6.808 | 6.231 | 5.805 | 6.484 | 20.100 |
| (a) weighted, depth 2 | 5.328 | 4.916 | 4.795 | 5.077 | 6.613 | 11.379 | 37.804 |
| (a) weighted, depth 3 | 15.519 | 11.577 | 11.567 | 10.233 | 9.683 | 11.750 | 40.173 |
| (c) sum, depth 2 | 3.705 | | | 3.662 | | | |
| (c) sum, depth 3 | 7.454 | | | 4.630 | | | |
| (c) weighted, depth 2 | 5.207 | | | 4.806 | | | |
| (c) weighted, depth 3 | 15.080 | | | 9.250 | | | |

- **The as-merged text at a smaller workgroup takes a quarter to two fifths off at depth
  three**, bitwise unchanged: the sum from 7.762 to 5.805 at 8 (-25 pc) and the weighted
  sum from 15.519 to 9.683 at 8 (-38 pc); at depth two the weighted sum from 5.328 to
  4.795 at 32 (-10 pc). Each clears the bed's one-run range of its case. Host is 3.64 to
  3.89 in every row, so the change is on the card.
- **The best workgroup differs by case**: 8 at depth three, 32 for the weighted sum at
  depth two, and nothing below 64 helps the sum at depth two, which is at the launch floor
  at every workgroup from 256 to 16. Workgroup 1 is the slowest measured on all four.
- **Under `@inbounds` the gain at workgroup 16 is larger than at 256**: the sum at depth
  three 6.231 to 4.630 (-1.60) against 7.762 to 7.454 (-0.31), the weighted sum 10.233 to
  9.250 (-0.98) against 15.519 to 15.080 (-0.44).
- `Reductions.segmented_sum` and `segmented_weighted_sum` launch at the workgroup of the
  backend they are handed, and the bed hands them 256.

## Anomalies not explained here

- (b)'s time on the card grows faster than its lane count between 81920 and 327680
  elements, six times for four times the lanes.
- (a) for the weighted sum at depth two is faster at 32 than at 16, and at 8 slower than
  at 64; the sum at depth three is fastest at 8 and slower at 4. The sweep does not say
  what sets the minimum.
- The weighted sum at depth three read 16.170 in job 1763 and 15.519 in job 1766 at
  workgroup 256, each over three rounds spanning under 0.02.
