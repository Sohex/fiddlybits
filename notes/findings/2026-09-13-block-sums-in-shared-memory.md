# Summing each block from workgroup shared memory halves the small reductions on the card and leaves pairwise_sum at level 7 where it was

Measured on 2026-09-13 on yggdrasil through `qrun` with this repository's defaults
(profile `gpu-share`, one share of an NVIDIA GeForce RTX 4090, 8 CPUs, 16G), Julia
1.12.7, CUDA.jl 6.3.1, KernelAbstractions.jl 0.9.42, Adapt.jl 4.7.0. The base arm is
`1c7b601ec401e5b4667b74c59d45443ff8f35ca7`, the branch arm is `fiddlybits-2tg` at
`0cc32998ecf2d8ae095bbd8e0ffdd618ad139163`, and `bench/runbench.jl` is at sha256
`fccd602f9693e7146fe9b6c9e4b297297d80cde119aec16ca2fca5b2b57c5ddc` on both. The row is
`fiddlybits-2tg`.

## What changed

On `GPU`, `Reductions.pairwise_block_sums` and `Reductions.area_weighted_block_sums`
launch one workgroup per block over `n` work items: every lane copies its own element
(for the area-weighted sum, its selected area) into `@localmem`, and after the barrier
lane 1 accumulates that copy in index order. Before, one work item per block read its
block from global memory at `(i-1)*blocksize+1`. The CPU kernels are unchanged, and
the terms reach the accumulator in the same order on both paths.

## The arithmetic did not move

The block sums and the scalars of the four registered cases the change reaches
(`pairwise_sum` and `area_fraction_above` at levels 5 and 7; for `area_fraction_above`
both block-sum arrays and the fraction), written as raw bytes from a GPU run at each
arm, have the same sha256 on both:
`40945141838d84230f008916e93b1fc73d25562b7c16dc4547207a8acd8ce499`.

`test/reductions/shared_block_kernels.jl` keeps the control in the tree: the
shared-memory kernels against the per-lane kernels launched on the same card, and
against `CPU`, bitwise, with every block full, a partial last block, a single block
shorter than a block, one element, and a blocksize of 17; accumulated in `Float64`
from `Float64` and from `Float32`, and in `Float32`. Its positive control changes the
last lane of a full block and the last element of a partial last block and requires
exactly that block's sum to move.

## Before and after

The A/B protocol of `notes/findings/2026-09-12-reduction-bench-scatter.md`: twenty
samples per arm, interleaved base then branch, one fresh process per sample, each its
own `qrun` job. Every one of the forty samples was the sole holder of a share before
its first case and after its last. Host load 1.03 to 8.63; startup 3.15 to 3.82 s;
measuring 42.7 to 57.3 s on the base arm and 33.5 to 44.6 s on the branch arm, every
sample over the bed's floor.

Microseconds per call, the minimum statistic, mean and sd over twenty samples:

| case | base mean | base sd | branch mean | branch sd | branch less base | as pc of base |
| --- | --- | --- | --- | --- | --- | --- |
| pairwise_sum, level 5 | 34.698 | 0.124 | 18.994 | 0.344 | -15.705 | -45.26 |
| pairwise_sum, level 7 | 48.310 | 0.324 | 48.583 | 0.269 | +0.273 | +0.57 |
| area_fraction_above, level 5 | 71.273 | 0.250 | 28.793 | 0.150 | -42.480 | -59.60 |
| area_fraction_above, level 7 | 129.948 | 12.557 | 97.736 | 11.343 | -32.212 | -24.79 |
| segmented_sum, depth 2 | 4.386 | 0.416 | 4.317 | 0.082 | -0.068 | -1.56 |
| segmented_sum, depth 3 | 7.815 | 0.050 | 7.835 | 0.050 | +0.020 | +0.26 |
| segmented_weighted_sum, depth 2 | 5.341 | 0.017 | 5.338 | 0.014 | -0.003 | -0.06 |
| segmented_weighted_sum, depth 3 | 16.078 | 0.151 | 16.071 | 0.240 | -0.007 | -0.04 |
| segmented_mean, depth 2 | 52.951 | 0.339 | 33.617 | 0.386 | -19.333 | -36.51 |
| segmented_mean, depth 3 | 62.435 | 0.328 | 45.477 | 0.226 | -16.958 | -27.16 |
| segmented_quantile, depth 2 | 27.723 | 0.060 | 27.722 | 0.067 | -0.001 | -0.00 |
| segmented_quantile, depth 3 | 28.489 | 0.064 | 28.488 | 0.069 | -0.001 | -0.00 |

The scatter finding puts what a difference has to clear at about one per cent on the
mean of twenty. Five cases clear it by more than twenty per cent. The six cases that
call neither changed kernel move by under a third of a per cent, except
`segmented_sum` at depth two, where one base sample of 6.146, against 4.232 to 4.374
for the other nineteen, carries the whole difference: without it the base mean is
4.293 and the branch arm sits 0.6 per cent above it.
`segmented_mean` calls `pairwise_sum` over its per-segment zero-weight indicator, one
element per segment, so it moves with `pairwise_sum` at the small size.

## area_fraction_above at level 7 settles into one of two levels per process

Per sample, in the order run:

- base: 141.8 114.3 119.7 114.3 115.1 114.7 116.7 117.4 141.4 139.6 139.0 117.2 119.4
  139.4 141.0 141.7 142.8 141.4 140.5 141.7
- branch: 84.2 98.7 84.8 83.9 84.3 84.7 106.9 84.8 107.0 110.8 84.3 84.4 106.9 107.0
  107.0 105.6 107.2 107.4 107.1 107.5

Both arms show two levels about a fifth apart, and the level a sample takes holds for
its two hundred batches, so it is set per process. The mean of twenty therefore
measures the mix of levels as much as the kernel. Within a level the change is
116 to 84 (-27 pc) and 141 to 107 (-24 pc), which is the difference this finding
reports for the case. The 20.9 per cent full range
`notes/findings/2026-09-12-reduction-bench-occupancy.md` recorded for this case is the
same split, unremarked there. `fiddlybits-6nh` carries what sets the level.

## Where pairwise_sum spends its time

One process on the branch arm, alone on its share: batches of 400 calls closed by one
`Backends.complete!`, the minimum over 60 batches of the mean per call, in
microseconds. The per-lane kernel is `Reductions.pairwise_block_kernel!` launched on
the card through `Backends.launch!` at a workgroup of 256, the path the base arm took.

| stage | level 5, 80 blocks | level 7, 1280 blocks |
| --- | --- | --- |
| block sums, per-lane kernel | 22.095 | 25.695 |
| block sums, shared-memory kernel | 6.145 | 25.738 |
| per-lane kernel and read back | 33.921 | 38.411 |
| shared-memory kernel and read back | 17.383 | 38.298 |
| `pairwise_sum` | 18.642 | 48.644 |
| `combine_fixed_order` on the host alone | 0.614 | 9.467 |

The per-lane kernel at level 5, launched at other workgroups on the same 80 blocks:

| workgroup | divides 80 | per call |
| --- | --- | --- |
| 256 | no | 22.027 |
| 80 | yes | 21.999 |
| 79 | no | 22.013 |
| 64 | no | 21.859 |
| 16 | yes | 18.618 |
| 1024 | no | 22.002 |

What these license:

- **The stride is not what the change removed.** The per-lane kernel reads sixteen
  times the elements at level 7 as at level 5 and costs 16 per cent more, so at level 5
  its 22 us is not spent on the reads. The shared-memory kernel costs 6.1 us there and
  the same 25.7 us as the per-lane kernel at level 7. What the per-lane kernel spends at
  level 5 was not identified here.
- **Nor is it a partial workgroup.** Whether the workgroup divides the ndrange does not
  move the per-lane kernel: 22.0 us dividing at 80 and 22.0 us partial at 79. Only a
  workgroup of 16 moved it, to 18.6.
- **At level 7 the kernel is half the call.** Of `pairwise_sum`'s 48.6 us, 25.7 is
  the kernel, 12.6 is reading 1280 block sums back to the host with its completion, and
  9.5 is `combine_fixed_order` on the host. The last two do not depend on which kernel
  wrote the block sums, which is why this case did not move.
- `area_fraction_above` at level 7 did move, by a quarter within each of its levels,
  while `pairwise_sum` at level 7 did not. This table times `pairwise_sum` alone and
  does not say where the area-weighted kernel's difference comes from.

## The device's thread limit

Launching the per-lane kernel at a workgroup of 1280 is refused by the device: `Number
of threads in x-dimension exceeds device limit (1280 > 1024)`. The shared-memory kernels
launch at a workgroup of `blocksize`, so on `GPU` a blocksize above 1024 raises that at
launch where the per-lane kernel ran it. `BLOCKSIZE` is 256, and nothing in the tree
passes another blocksize on `GPU`.

`fiddlybits-zgh` is the same transplant for the segmented kernels. Its premise is the
stride this finding did not find, and the largest segment decision 0005 declares for a
quantile, 1024 elements, is exactly the device limit.
