# The positive control of kernels.reduction_partition_independent fires by construction: the block kernel with its block length read from the partition gives minus the number of blocks on the cancelling quadruples, at every load, and the fixed-order tree substituted for it fails the control

Measured on 2026-09-13 on yggdrasil through `qrun` with this repository's defaults
(profile `gpu-share`, 8 CPUs, 16G, one share of the RTX 4090), Julia 1.12.7, on branch
`fiddlybits-52v.7.56` cut from `0dc99c8`. The row is `fiddlybits-52v.7.56`; the control
is the testset "positive control: an accumulation whose blocks follow the thread count or
the workgroup, substituted for the fixed-order tree, differs across both" in
`test/reductions/partition_independent.jl`.

## The control

The input is `ReductionFixtures.cancelling_quadruples(1024)`: 4096 terms, the quadruple
`(1.0e16, 1.0, -1.0e16, -1.0)` repeated. The accumulation is
`Reductions.pairwise_block_sums(Float64, xs, backend; blocksize = b)` followed by
`Reductions.combine_fixed_order`: each block summed left to right from `0.0` by
`pairwise_block_kernel!`, the block sums combined by the length-only tree. The block
length `b` is read from the partition instead of `Reductions.BLOCKSIZE`:

- thread count: `b = length(xs) / Threads.nthreads()` in a fresh process started with
  `-t 1`, `-t 4` and `-t 16`, giving 1, 4 and 16 blocks;
- workgroup: `b = Backends.workgroup(backend)` on `Backends.CPU(4)` and `Backends.CPU(16)`
  in one process, giving 1024 and 256 blocks.

`Reductions.pairwise_sum` runs beside it on the same sequence and partitions.

## The arithmetic

Float64 values in `[2^53, 2^54)` are spaced by 2, and `1.0e16` lies in that range, so
its neighbours are `1.0e16 - 2` and `1.0e16 + 2`. Written as `2k`, `1.0e16` has
`k = 5.0e15`, even; both neighbours have odd `k`. Round-to-nearest-even therefore sends
both `1.0e16 - 1` and `1.0e16 + 1` to `1.0e16`.

A running accumulator `a` entering a quadruple with `a` equal to `0.0` or `-1.0`:

| step | exact | stored |
| --- | --- | --- |
| `a + 1.0e16` | `1.0e16` or `1.0e16 - 1` | `1.0e16` |
| `+ 1.0` | `1.0e16 + 1` | `1.0e16` |
| `+ (-1.0e16)` | `0.0` | `0.0` |
| `+ (-1.0)` | `-1.0` | `-1.0` |

So the accumulator leaves every quadruple at `-1.0`, and by induction a block of any
positive whole number of quadruples, started at `0.0`, sums to `-1.0`. Every block length
the control uses (4096, 1024, 256, and the workgroups 4 and 16) is a whole number of
quadruples; the child process refuses when `length(xs)` is not a multiple of
`4 * nthreads`. The block sums are `c` copies of `-1.0`, and any sum of small negative
integers is exact in Float64, so the tree gives `-c` whatever its shape. The totals are
`-1`, `-4`, `-16` at 1, 4 and 16 threads and `-1024`, `-256` at workgroups 4 and 16:
pairwise distinct, from the partition alone. No step depends on which thread ran which
block or in what order the blocks finished, so no scheduling can make two partitions
agree, and no scheduling can make one partition give two answers.

The test asserts the check's own form (`!(one == four == sixteen)` on the raw bytes, and
`wg4 != wg16`), the exact totals, and that `pairwise_sum` is equal across the same
partitions. With `Reductions.BLOCKSIZE` (256) in place of the partition, the 4096 terms
split into 16 blocks at every partition and every total is `-16`.

## The runs

| run | load | reductions suite | this oracle | its wall |
| --- | --- | --- | --- | --- |
| plain, 1 | load average 10.6 at submit | pass | 19 of 19 | 19.1 s |
| plain, 2 | load average 18.1 at submit, 12.5 after | pass | 19 of 19 | 16.9 s |
| loaded | a 16-thread spinning job on 8 CPUs beside it, and 32 spinning threads inside the suite's own 8-CPU allocation; load average 17.5 at the suite's start, 42.0 at its end | pass, 90 s | 19 of 19 | 30.6 s |
| door pair, plain | the plain and `--check-bounds=yes` suites at once in one 8-CPU allocation; load average 29.1 at submit | pass | 19 of 19 | 18.5 s |
| door pair, `--check-bounds=yes` | same job | pass | 19 of 19 | 17.4 s |

In the loaded job, under the same 32-thread burner, the atomic accumulation this control
replaces (80000 terms of the same quadruples, `Threads.@threads` over an `@atomic` add)
gave `-1.0` at one thread and `-625`, `-1`, `-105`, `-289`, `-673` at sixteen: one of the
five equal to the one-thread total, the outcome that failed the gate of
`notes/findings/2026-09-13-check-bounds-reaches-kernels-on-the-card.md` when all five were.

## The substitution control

A scratch copy of the file with both block lengths replaced by `Reductions.BLOCKSIZE`,
run through `qrun` beside the worktree's `fixtures.jl` and `thread_bitwise.jl`: the
process exited 1 with `kernels.reduction_partition_independent` at 13 pass, 6 fail of 19.
The failures were the check `!(partitioned(1) == partitioned(4) == partitioned(16))`
(all three bytes of `-16.0`), `partitioned(1) == -1.0` and `partitioned(4) == -4.0`
(each `-16.0`), `wg4 != wg16` (`-16.0` both), and `wg4 == -1024.0`, `wg16 == -256.0`.
`partitioned(16) == -16.0` held, as the arithmetic says it must.

The registry threshold of `kernels.reduction_partition_independent` still names an atomic
accumulation as this control; rewording it is `fiddlybits-52v.7.57`.

## The gate at this revision

`./tools/gate/gate.sh` from the worktree: every suite passed, wall 95.3 s, sum of suites
422.2 s, `reductions` 73.1 s; load average 17.5 at the start and 10.8 at the end. The
branch elides no bounds check, so the door ran no checked pass:

```
gate: bounds door against main at 0dc99c8ce43a: no changed .jl file elides a bounds check; no checked pass
```

The door's checked pass over this suite is the door pair above.
