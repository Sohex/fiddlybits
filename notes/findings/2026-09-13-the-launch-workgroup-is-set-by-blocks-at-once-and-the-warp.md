# The launch workgroup's cost on the card is set by how many CUDA blocks the card runs at once and by the warp, not by the loop a work item runs, and choosing it per launch takes a quarter to two fifths off the level 7 block sums and the depth three segmented kernels with every result bitwise unchanged

Measured on 2026-09-13 on yggdrasil, NVIDIA GeForce RTX 4090, driver 610.57.04 (CUDA
driver and runtime 13.3), Julia 1.12.7, CUDA.jl 6.3.1, KernelAbstractions.jl 0.9.42. The
driver reports a warp size of 32, at most 1536 threads per streaming multiprocessor and at
most 1024 threads per block. The row is `fiddlybits-q09`; the decision it settles is
`docs/decisions/0058-a-launch-workgroup-is-chosen-per-launch-from-the-work-item-count.md`.

Probes 1 to 6 ran on `main` at `597fed1fe5af4de6d70676913ca4dc103db33289`, unpacked by `git
archive`, whose `src/Reductions/` and `src/Backends/` kernels are those of `c242ec0`, the
commit this branch was merged up to (the two differ in one docstring of
`src/Backends/certify.jl`). Probes 7 and 8 and the bench ran on the branch. The probe scripts
lived outside the tree; they launched the tree's own kernels through `Backends.launch!`,
except one kernel of probe 1 described where it is used.

GPU probes ran through `qrun -p gpu` (all four shares, 8 CPUs, 24G, 18G of vram). Every
timing row read no other job holding a share before it and after it, and no row was
skipped by its bound. The CPU probe ran through `qrun -p sim -c 8` (eight whole physical
cores, no share).

| probe | job | what | host load |
| --- | --- | --- | --- |
| 1 | 2027 | loop length, item count and per-iteration sweeps; bitwise over workgroups; occupancy API | 2.29 to 2.56 |
| 2 | 2038 | the queueing knee by threads per block; one block past the warp | 12.62 to 13.55 |
| 3 | 2040 | every per-lane reduction kernel at the bench's shapes over workgroups | 12.24 to 15.30 |
| 4 | 2044 | the knee by kernel at 1 and 4 threads per block; occupancy API by kernel | 8.44 to 9.12 |
| 5 | 2046 | the knee of every per-lane kernel at one thread per block, three rounds | 2.72 to 2.88 |
| 6 | 2045 | the CPU backend, three rounds | 1.98 to 2.77 |
| 7 | 2057 | each block-sum device form against its portable kernel under the rule, four rounds | 9.16 to 12.95 |
| 8 | 2130 | the bench's two slower cases through the door and through pins, six rounds | 8.57 to 10.17 |

The load in jobs 2038, 2040, 2044, 2057 and 2130 was a compile job of another project holding
16 CPUs and no share. Host time per launch was 3.3 to 4.4 us in every row of those jobs
except the busy-wait controls, as in the quiet ones.

## The instrument

The instrument of
`notes/findings/2026-09-13-the-per-lane-block-kernel-pays-for-one-thread-s-checked-serial-reads.md`,
in microseconds per call: **batch**, the minimum over 30 batches of 200 calls closed by one
`Backends.complete!` of the mean per call (20 batches in probe 5); **host**, the same
batches timed up to the completion. A row first times the fastest of five synchronised
calls and is skipped if that projects past its bound (20 s; 8 s in probe 5, 10 s in probe
7). A row launches the kernel into a preallocated result unless it says otherwise.

Positive controls, each job:

| job | control | batch | host |
| --- | --- | --- | --- |
| 2027 | segmented sum, 5120 segments of 64, workgroup 8, first row / last row | 25.510 / 4.635 | 3.612 / 3.579 |
| 2027 | the same with a 15 us host busy-wait | 18.757 | 18.720 |
| 2027 | the same shape at workgroup 1, first / last | 21.964 / 20.657 | 3.619 / 3.620 |
| 2027 | the same shape at workgroup 256, first / last | 7.553 / 7.541 | 3.603 / 3.607 |
| 2027 | segmented sum, one segment of `2^16` | 3049.633 | 3.832 |
| 2038 | workgroup 8 / 1 / 256, first rows | 4.992 / 22.253 / 7.498 | 3.322 / 3.364 / 3.408 |
| 2038 | the same, last rows | 4.624 / 20.671 / 7.571 | 3.615 / 3.562 / 3.553 |
| 2040 | workgroup 8 / 1 / 256, first rows | 4.976 / 22.252 / 7.486 | |
| 2040 | the same, last rows | 4.676 / 20.558 / 7.500 | |
| 2044 | workgroup 8 / 1 / 256, first rows; 8 / 1 last | 4.992 / 22.361 / 7.547; 4.641 / 20.627 | |
| 2046 | `pairwise_block_kernel!`, 512 blocks, workgroup 1 / 256 | 13.311 / 26.403 | 3.292 / 3.299 |
| 2057 | `pairwise_block_kernel!` at the rule, 20480 elements / with a 15 us busy-wait | 12.788 / 19.596 | 4.276 / 19.476 |

The busy-wait moves host and batch together and the long loop moves batch alone, so the
instrument separates time on the host from time on the card; workgroups 1, 8 and 256 on
one shape read apart by three to five times their drift between a job's first and last
rows. The first timed row of job 2027 read 25.5 and the same row at its end 4.6; every
later job ran a discarded warm-up row first.

## The arithmetic did not move

Probe 1 launched `segmented_sum_kernel!` and `segmented_weighted_sum_kernel!` at
workgroups 1, 2, 4, 8, 16, 32, 64, 128, 256, 512 and 1024 over 5120 segments of 64, 20480
of 16, 80 of 256 and 1000 of 7: every result bitwise equal to the launch at 256. Control:
one element added to the last element moved exactly the last segment at workgroups 1 and
256, for both kernels on every shape.

Every reduction on the bench's registered cases and the type mixes of
`notes/findings/2026-09-13-the-block-sum-device-forms-against-one-inbounds-text.md`, 59 of
them, was written as raw bytes and hashed. On `main` at `Backends.CPU(256)`, `GPU(256)`,
`CPU(8)`, `GPU(8)`, `CPU(1)` and `GPU(1)`, each case's six hashes are one hash. On the
branch at `CPU()`, `GPU()`, `CPU(256)`, `GPU(256)`, `CPU(8)` and `GPU(8)`, each case
hashes to the same value as on `main`: 59 case-to-hash pairs on each side, identical.

## What sets the minimum on the card

### Blocks queue past a bound

`segmented_sum_kernel!` over segments of 256, launched at workgroups 1 to 32 over a
multiple of `512 * workgroup` segments, so each column holds one block count (job 2038):

| workgroup | 1/8 | 1/4 | 1/2 | 3/4 | 1 | 5/4 | 3/2 | 2 | 4 |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| blocks | 64 | 128 | 256 | 384 | 512 | 640 | 768 | 1024 | 2048 |
| 1 | 11.884 | 11.967 | 12.194 | 12.390 | 12.463 | 12.577 | 12.880 | 16.156 | 29.973 |
| 2 | 12.105 | 12.026 | 12.191 | 12.436 | 12.509 | 12.665 | 12.989 | 16.133 | 30.031 |
| 4 | 12.247 | 12.269 | 12.210 | 12.531 | 12.798 | 12.812 | 13.128 | 15.763 | 29.554 |
| 8 | 12.424 | 12.423 | 12.502 | 12.808 | 12.988 | 12.982 | 13.335 | 15.757 | 29.566 |
| 16 | 12.830 | 12.815 | 12.840 | 13.050 | 13.294 | 13.477 | 13.873 | 15.861 | 29.814 |
| 32 | 13.464 | 13.527 | 13.679 | 14.028 | 15.409 | 19.005 | 21.591 | 27.365 | 540.650 |

With segments of 64 (job 2038), 1024 blocks and 2048 blocks read 5.538 and 8.870 at
workgroup 1, 5.421 and 8.858 at workgroup 4, and 5.471 and 8.938 at workgroup 16.

- **A launch's cost is a function of its block count.** At 1024 blocks it is 15.8 to 16.2
  whether each block holds one thread or sixteen, and at 2048, 29.6 to 30.0. The same
  holds on another kernel: `area_fraction_block_kernel!` over 640 blocks of 256 read
  29.675 at one thread per block (job 2044) and 29.652 at two over 1280 (job 2040); over
  160 blocks, 16.661 and 16.758.
- Past the bound it grows in proportion to the block count, and below it it stays near
  one block's loop. Within the flat part, more threads per block costs a little more
  (11.9 at one thread, 13.5 at 32, at 64 blocks).

Where each kernel starts to queue, at one thread per block, median over three rounds (job
2046; every span under 0.19 except `pairwise_block_kernel!` at 32 blocks, 0.688):

| kernel | 32 | 64 | 96 | 128 | 192 | 256 | 384 | 512 | 768 | 1024 |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| `pairwise_block_kernel!` | 11.680 | 11.950 | 11.734 | 11.862 | 12.027 | 12.114 | 12.256 | 12.329 | 12.871 | 15.947 |
| `area_weighted_block_kernel!` | 14.558 | 14.754 | 14.607 | 14.715 | 15.679 | 15.715 | 17.926 | 16.963 | 23.430 | 30.269 |
| `area_fraction_block_kernel!` | 14.749 | 15.020 | 14.867 | 14.923 | 16.550 | 16.536 | 21.905 | 24.684 | 33.335 | 44.181 |
| `segmented_sum_kernel!`, segments of 64 | 4.170 | 4.176 | 4.209 | 4.208 | 4.324 | 4.269 | 4.384 | 4.592 | 4.700 | 5.519 |
| `segmented_weighted_sum_kernel!`, of 64 | 7.727 | 7.751 | 7.729 | 7.745 | 7.782 | 7.858 | 8.005 | 8.087 | 8.402 | 9.599 |
| `segmented_mean_kernel!`, of 16 | 3.998 | 4.084 | 3.996 | 3.971 | 3.953 | 4.054 | 3.940 | 4.055 | 4.355 | 4.987 |
| `segmented_mean_kernel!`, of 256 | 27.763 | 27.838 | 27.877 | 27.908 | 28.043 | 28.436 | 28.877 | 30.288 | 36.294 | 44.471 |

- **Every per-lane kernel of the tree runs at its floor through 128 blocks**, within 2.3
  per cent of its cost at 32 blocks. At 192 the area kernels read 7 and 11 per cent above
  it. 128 is `Backends.GPU_BLOCKS_AT_ONCE` for this card.
- The knee differs by kernel: the pairwise, sum, weighted-sum and short mean kernels stay
  within 5 per cent of their floor to 512 blocks, and the area kernels leave it at 192.

### Threads of one block cost each other

One block of `n` threads, each over a segment of 256 (job 2038):

| threads | 16 | 32 | 48 | 64 | 96 | 128 | 192 | 256 | 384 | 512 | 1024 |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| batch | 12.423 | 13.236 | 14.350 | 14.586 | 14.624 | 14.750 | 19.084 | 24.885 | 36.445 | 48.041 | 94.375 |

- A step between 32 and 48 threads, flat to 128, and in proportion to the thread count
  from 192.

At 80 blocks, well under the bound, over workgroups (job 2040):

| kernel, level 5 | 1 | 2 | 4 | 8 | 16 | 32 | 64 | 128 to 512 |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| `pairwise_block_kernel!` | 11.847 | 11.959 | 11.972 | 12.198 | 12.386 | 13.056 | 14.318 | 14.433 to 14.439 |
| `area_weighted_block_kernel!` | 14.595 | 14.807 | 14.981 | 15.374 | 16.766 | 20.032 | 19.274 | 20.470 to 20.491 |
| `area_fraction_block_kernel!` | 14.847 | 14.993 | 15.126 | 15.411 | 16.646 | 19.923 | 21.879 | 23.571 to 23.586 |

- With nothing queued, one thread per block is the cheapest launch, and a warp per block
  costs the area kernels a third more.

### The loop a work item runs does not move the minimum

`segmented_sum_kernel!` over 5120 segments at five loop lengths, and over segments of 64
at five segment counts; then three kernels over 5120 segments of 64 (job 2027):

| shape | 1 | 2 | 4 | 8 | 16 | 32 | 64 | 128 | 256 | 512 | 1024 |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| 5120 of 1 | 3.976 | 3.587 | 3.591 | 3.548 | 3.582 | 3.606 | 3.548 | 3.557 | 3.580 | 3.603 | 3.618 |
| 5120 of 4 | 4.007 | 3.585 | 3.609 | 3.570 | 3.660 | 3.699 | 3.631 | 3.717 | 3.666 | 3.681 | 3.667 |
| 5120 of 16 | 6.528 | 4.125 | 3.617 | 3.616 | 3.669 | 3.687 | 3.638 | 3.637 | 3.611 | 4.662 | 7.564 |
| 5120 of 64 | 20.616 | 10.619 | 6.316 | 4.588 | 4.651 | 4.637 | 4.954 | 5.082 | 7.529 | 13.343 | 24.945 |
| 5120 of 256 | 78.294 | 36.957 | 19.364 | 12.994 | 13.043 | 13.484 | 14.830 | 14.978 | 24.944 | 48.127 | 94.388 |
| 320 of 64 | 4.439 | 4.088 | 4.219 | 4.295 | 4.324 | 4.535 | 4.813 | 4.957 | 7.458 | 8.939 | 8.931 |
| 1280 of 64 | 6.292 | 4.502 | 4.435 | 4.299 | 4.270 | 4.565 | 4.834 | 5.000 | 7.553 | 13.352 | 24.820 |
| 20480 of 64 | 72.922 | 38.075 | 20.504 | 10.625 | 6.439 | 6.070 | 6.188 | 7.643 | 7.637 | 13.361 | 24.971 |
| 81920 of 64 | 289.776 | 143.244 | 71.977 | 38.255 | 20.475 | 18.135 | 18.473 | 18.591 | 19.850 | 25.662 | 25.296 |
| 80 of 256 | 11.941 | 12.049 | 12.093 | 12.311 | 12.463 | 13.207 | 14.473 | 14.522 | 14.512 | 14.529 | 13.322 |
| 1280 of 256 | 19.355 | 12.559 | 12.588 | 12.340 | 12.710 | 13.361 | 14.699 | 14.897 | 24.894 | 48.093 | 94.341 |
| 1280 of 16 | 3.749 | 3.701 | 3.690 | 3.629 | 3.698 | 3.730 | 3.676 | 3.686 | 3.724 | 4.675 | 7.465 |
| 81920 of 16 | 75.360 | 38.672 | 20.228 | 11.160 | 6.568 | 6.357 | 6.399 | 6.343 | 6.804 | 8.266 | 7.904 |
| a loop with no read, 5120 of 64 | 35.254 | 18.456 | 9.969 | 5.865 | 4.173 | 3.695 | 3.710 | 4.889 | 8.228 | 14.977 | 28.405 |
| `segmented_weighted_sum_kernel!`, 5120 of 64 | 39.962 | 19.601 | 11.080 | 8.699 | 9.230 | 10.501 | 10.602 | 10.885 | 15.479 | 25.786 | 48.287 |
| `segmented_mean_kernel!`, 5120 of 64 | 56.883 | 29.829 | 15.606 | 10.263 | 10.026 | 11.226 | 11.246 | 11.718 | 16.067 | 26.804 | 49.978 |

The loop with no read is `segmented_sum_kernel!` with `acc += T(j)` in place of the read.

- **At 5120 segments the cheapest workgroups are 8 to 32 at every loop length from 16 to
  256**; below 16 reads nothing measurable happens on the card. The loop length scales the
  whole row and does not move its minimum.
- **The item count moves it**: 2 at 320 segments, 8 to 16 at 1280, 32 at 20480, 32 to 128
  at 81920, and one thread per block at 80.
- Past `128 * 32` items a wider block than the warp would hold fewer blocks: at 81920
  segments 64 and 128 read within 0.5 of 32 for the sum, and at 20480 segments of 16 the
  weighted sum and the mean read 7.654 and 8.322 at 64 against 4.973 and 5.354 at 32
  (job 2040).

### What the driver's occupancy API reports

`CUDA.launch_configuration` and the active blocks per multiprocessor, for
`pairwise_block_kernel!`, `area_weighted_block_kernel!`, `area_fraction_block_kernel!`,
`segmented_sum_kernel!` and `segmented_mean_kernel!` compiled as each launch compiles them
(job 2044): 24 active blocks per multiprocessor at 1 to 64 threads per block, 12 at 128, 6
at 256 and 1 at 1024, the same for all five, and a suggestion of 768 threads per block for
all five. It does not see what separates the kernels' knees, and its width is past the
point where every per-lane kernel above reads slower.

## The rule against the sweeps

`Backends.launch_workgroup` on this card: the smallest power of two whose block count is
at most 128, and at most 32. At the bench's shapes (job 2040), the rule's workgroup
against the cheapest measured and the bench's former 256:

| kernel, shape | rule | rule's cost | cheapest (workgroup) | at 256 |
| --- | --- | --- | --- | --- |
| `pairwise_block_kernel!`, 80 blocks | 1 | 11.847 | the rule | 14.439 |
| `area_weighted_block_kernel!`, 80 blocks | 1 | 14.595 | the rule | 20.473 |
| `area_fraction_block_kernel!`, 80 blocks | 1 | 14.847 | the rule | 23.571 |
| `pairwise_block_kernel!`, 320 blocks | 4 | 11.984 | 11.845 (2) | 24.685 |
| `area_weighted_block_kernel!`, 320 blocks | 4 | 14.917 | the rule | 47.875 |
| `area_fraction_block_kernel!`, 320 blocks | 4 | 15.236 | the rule | 48.021 |
| `pairwise_block_kernel!`, 1280 blocks | 16 | 12.545 | 12.284 (8) | 24.754 |
| `area_weighted_block_kernel!`, 1280 blocks | 16 | 17.049 | 16.257 (8) | 47.939 |
| `area_fraction_block_kernel!`, 1280 blocks | 16 | 16.915 | 16.758 (8) | 48.216 |
| `segmented_sum_kernel!`, 20480 of 16 | 32 | 3.650 | 3.535 (64) | 5.136 |
| `segmented_weighted_sum_kernel!`, 20480 of 16 | 32 | 4.973 | 4.974 (16) | 6.689 |
| `segmented_mean_kernel!`, 20480 of 16 | 32 | 5.354 | the rule | 7.166 |
| `segmented_sum_kernel!`, 5120 of 64 | 32 | 4.611 | the rule | 7.512 |
| `segmented_weighted_sum_kernel!`, 5120 of 64 | 32 | 10.583 | 8.757 (8) | 15.452 |
| `segmented_mean_kernel!`, 5120 of 64 | 32 | 11.266 | 10.074 (16) | 16.104 |

- The rule is within 5 per cent of the cheapest measured workgroup on every shape but two,
  the weighted sum and the mean over 5120 segments of 64, where it is 21 and 12 per cent
  above: those kernels' threads cost each other more than their blocks queue at 320 to 640
  blocks. It is below the former 256 on every shape, by 18 to 69 per cent.
- On the sweeps of job 2027 the same rule is within 4 per cent of the cheapest on every
  row except the weighted sum and the mean over 5120 segments of 64, 21 and 12 per cent
  above, as in job 2040.

## The CPU backend

The kernels launched on `Backends.CPU(w)` in a process with eight Julia threads on eight
cores, the minimum over 15 batches of 20 calls of the mean per call, median over three
rounds and the span of the three (job 2045). Controls: `pairwise_block_kernel!` at level 7
and workgroup 64 read 33.251, with a 150 us busy-wait 184.371, and at one block 154.359.

| kernel, work items | blocks per thread, workgroup: median (span) |
| --- | --- |
| `pairwise_block_kernel!`, 80 | 10, 1: 7.117 (1.710); 5, 2: 8.195 (1.982); 2.5, 4: 7.025 (1.533); 1.25, 8: 8.081 (1.692); 0.62, 16: 7.897 (2.455); 0.12, 128: 11.045 (0.324) |
| `area_fraction_block_kernel!`, 80 | 10, 1: 9.812 (0.897); 5, 2: 9.309 (1.306); 2.5, 4: 8.652 (0.409); 1.25, 8: 9.135 (0.860); 0.62, 16: 10.732 (4.324); 0.12, 128: 13.018 (0.226) |
| `pairwise_block_kernel!`, 1280 | 160, 1: 28.233 (2.687); 40, 4: 27.365 (1.704); 20, 8: 30.852 (3.186); 10, 16: 30.958 (3.509); 5, 32: 31.556 (3.776); 2.5, 64: 34.158 (3.430); 1.25, 128: 40.586 (0.918); 0.12, 2048: 157.736 (6.607) |
| `area_fraction_block_kernel!`, 1280 | 160, 1: 33.486 (0.053); 40, 4: 32.521 (0.551); 20, 8: 33.811 (0.673); 10, 16: 34.138 (1.020); 5, 32: 33.384 (1.064); 2.5, 64: 37.094 (0.331); 1.25, 128: 46.441 (0.361); 0.12, 2048: 188.715 (5.682) |
| `segmented_sum_kernel!`, 20480 of 16 | 2560, 1: 20.204 (0.638); 640, 4: 20.898 (0.724); 160, 16: 20.664 (0.660); 40, 64: 20.733 (1.461); 20, 128: 20.832 (2.674); 10, 256: 20.157 (1.669); 2.5, 1024: 21.454 (4.561); 1.25, 2048: 19.858 (2.428); 0.12, 32768: 54.502 (6.515) |
| `segmented_mean_kernel!`, 20480 of 16 | 2560, 1: 157.113 (45.859); 640, 4: 158.413 (29.510); 160, 16: 157.216 (26.507); 40, 64: 181.121 (27.722); 20, 128: 181.100 (0.874); 10, 256: 181.814 (1.694); 2.5, 1024: 200.797 (20.182); 1.25, 2048: 248.170 (8.659); 0.12, 32768: 1159.959 (12.855) |
| `segmented_sum_kernel!`, 5120 of 64 | 640, 1: 22.448 (6.978); 160, 4: 23.036 (6.466); 40, 16: 23.318 (6.608); 20, 32: 19.818 (5.830); 10, 64: 17.867 (6.118); 5, 128: 17.947 (5.176); 2.5, 256: 19.152 (3.184); 1.25, 512: 22.896 (1.638); 0.12, 8192: 75.367 (2.584) |
| `segmented_mean_kernel!`, 5120 of 64 | 640, 1: 176.425 (2.601); 160, 4: 177.612 (2.332); 40, 16: 177.807 (17.242); 20, 32: 194.959 (18.376); 10, 64: 194.579 (18.877); 5, 128: 194.647 (11.630); 2.5, 256: 223.832 (6.070); 1.25, 512: 277.750 (3.327); 0.12, 8192: 1303.121 (38.819) |
| `axpy_fused_kernel!`, 327680 | 40960, 1: 41.251 (14.323); 10240, 4: 57.565 (30.480); 2560, 16: 49.168 (13.333); 40, 1024: 46.167 (12.081); 20, 2048: 53.265 (30.712); 10, 4096: 51.648 (33.043); 5, 8192: 61.712 (12.887); 2.5, 16384: 43.702 (19.377); 1.25, 32768: 43.271 (21.745); 0.12, 524288: 324.167 (23.658) |

- **Fewer blocks per thread is slower or no faster on every kernel, and one work item per
  block is within the three rounds' span of the cheapest median on every kernel.** The
  cheapest medians of `pairwise_block_kernel!` over 80 and 1280 blocks, of
  `area_fraction_block_kernel!` over 1280 and of both means are at workgroups 1 to 4.
  `axpy_fused_kernel!`'s spans are wider than any difference between its rows short of one
  block.
- An earlier CPU probe in job 2038, beside the compile job, is not counted; it read
  `axpy_fused_kernel!` at workgroup 1 as 43 per cent above its cheapest row, which this
  quiet run does not reproduce.

## The block-sum device forms against the portable kernels under the rule

Each device form pinned to `BLOCKSIZE` against its portable kernel at `Backends.GPU()`,
each call allocating its result as the public function does (job 2057, branch). Median and
span over four rounds, the arm order reversed on even rounds; the portable kernel's
workgroup is the rule's at `cld(n, 256)` blocks. Every count was bitwise identical between
the two forms, and each arm's launch was read back from `Backends.queued_launches`.

| elements | blocks, rule | pairwise device | portable | area-weighted device | portable | area-fraction device | portable |
| --- | --- | --- | --- | --- | --- | --- | --- |
| 20480 | 80, 1 | 6.194 | 11.866 | 6.255 | 14.687 | 7.225 | 14.892 |
| 40960 | 160, 2 | 6.240 | 11.974 | 6.394 | 14.899 | 9.136 | 15.099 |
| 61440 | 240, 2 | 6.269 | 11.855 | 6.436 | 14.763 | 9.196 | 15.031 |
| 81920 | 320, 4 | 7.108 | 12.133 | 7.286 | 15.153 | 12.330 | 15.296 |
| 102400 | 400, 4 | 8.685 | 12.052 | 8.862 | 15.072 | 15.749 | 15.295 |
| 122880 | 480, 4 | 8.712 | 12.132 | 8.930 | 15.077 | 15.806 | 15.298 |
| 143360 | 560, 8 | 10.882 | 12.277 | 11.147 | 15.383 | 19.574 | 15.531 |
| 163840 | 640, 8 | 10.992 | 12.273 | 11.305 | 15.480 | 19.660 | 15.439 |
| 184320 | 720, 8 | 12.173 | 12.251 | 12.542 | 15.495 | 22.912 | 15.514 |
| 204800 | 800, 8 | 20.265 | 12.292 | 21.207 | 15.502 | 40.071 | 15.499 |
| 245760 | 960, 8 | 20.125 | 12.282 | 21.366 | 15.428 | 40.246 | 15.451 |
| 327680 | 1280, 16 | 25.577 | 12.562 | 21.681 | 17.080 | 40.680 | 16.952 |
| 655360 | 2560, 32 | 46.972 | 13.391 | 44.498 | 20.392 | 76.251 | 20.291 |
| 1310720 | 5120, 32 | 78.267 | 13.392 | 78.185 | 20.806 | 142.902 | 21.723 |

Every span is under 0.14, except the device forms at 655360 and 1310720 elements (0.119 to
0.593).

- **`pairwise_block_shared_kernel!` is faster through 184320 elements**, by 0.078 there
  against spans of 0.016 and 0.005, and slower from 204800 by 8.0.
  `Reductions.PAIRWISE_DEVICE_FORM_MAX` is 184320.
- **`area_weighted_block_shared_kernel!` is faster through 184320**, by 2.953, and slower
  from 204800 by 5.7. `Reductions.AREA_WEIGHTED_DEVICE_FORM_MAX` is 184320.
- **`area_fraction_block_shared_kernel!` is faster through 81920**, by 2.966, and slower
  from 102400 by 0.454 against spans of 0.007 and 0.008. `Reductions.AREA_FRACTION_DEVICE_FORM_MAX`
  is 81920.
- Counts between the last measured faster and the first measured slower were not measured,
  and the dispatch gives them the portable text. Every device form's cost jumps between
  184320 and 204800 elements, 720 and 800 blocks of 256 threads.
- At both bench levels the dispatch is now the device form at level 5 and the portable
  kernel at level 7 for all three.

`test/reductions/shared_block_kernels.jl` holds each dispatch from both sides by the launch
`Backends.queued_launches` records, kernel and workgroup.

## The door's host cost

`Backends.launch_workgroup` and the launch record `Backends.launch!` keeps, timed on the
host in a `qrun -p gpu-share` job on the branch: the minimum over 15 repetitions of `10^6`
calls of the mean per call, in nanoseconds. Control: an empty closure read 0.00001 and a
200-iteration integer loop behind an inference barrier 14.1, so the timer resolves ten
nanoseconds.

| call | first form | as committed |
| --- | --- | --- |
| `launch_workgroup(GPU(), 20480)` | 34.0 | 18.1 |
| `launch_workgroup(GPU(256), 20480)` | 6.6 | 5.9 |
| `gpu_launch_shape()` | 23.4 | 9.5 |
| one launch's record, then emptied | 213.0, 96 bytes | 65.3, 0 bytes |
| a kernel pushed to and emptied from a `Vector{Any}`, the record before this row | 69.6 | 87.7 |

The first form read the launch shape through a lock and a `Dict` on every launch and kept
each launch's record as a boxed named tuple. As committed, the shape is read from one
`Threads.Atomic{Int}` holding the device it was read for, with the lock taken only on a
miss, and the record keeps its kernels, workgroups and counts in three vectors of one
`QueuedTrace`. A bench of twenty pairs on the first form read `segmented_sum` at depth two
+0.060 us and `pairwise_sum` at level 5 +0.170, paired medians, the branch faster in 5 and 7
of the 20.

## Before and after on the registered bench (fiddlybits-hth)

Twenty pairs, each one `qrun -p gpu` job running `main` at `c242ec0` (unpacked by `git
archive`) and the branch as two fresh processes, base first in odd pairs and branch first in
even ones, `bench/runbench.jl` of each tree. Every sample read `held_all_shards = true` and
exited 0. Base arm: load 2.16 to 3.40, startup 3.37 to 3.48 s, measuring 28.3 to 39.1 s,
`workgroup = 256`. Branch arm: load 2.25 to 3.12, startup 3.38 to 3.53 s, measuring 24.6
to 31.4 s, `workgroup = "Backends.launch_workgroup"`. The branch had
`src/Reductions/pairwise.jl` at sha256
`efa7c25e38c4e2bff6a2cdc8a5fbff1ea2e8bf545309cba58b28d00709eb99b1`, `quantiles.jl` at
`a8c7e2d9a02283194d7f1a0b8618cc85d319558d8dab05b39124aa2a2778ec74`, `segmented.jl` at
`4e04b86b2bf1284021e3f8d528d1524bf87d6af0047dfc4d8f6266626409a80f`,
`src/Backends/backend.jl` at `a7c11ce0b95f269498bd8f5bf42c2d9dca90b58661b86c4f5295c9a4833383a3`,
`src/Backends/launch.jl` at `1e2b4897513be36c8718ada395e57726d3a5f4b667648359cf102ab1dda835cb`
and `bench/runbench.jl` at `5ecbccfb6be9b4ab114c7a2010846c139f530e0e2696f478ba444fca9fe2329d`.

Microseconds per call, the minimum statistic. "paired" is the median over the twenty pairs of
branch less base within the same job, and "faster" counts the pairs where the branch was:

| case | base mean | base sd | branch mean | branch sd | base median | branch median | paired | pc of base median | faster |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| pairwise_sum, level 5 | 19.197 | 1.269 | 19.083 | 0.428 | 18.864 | 18.910 | +0.101 | +0.53 | 6/20 |
| pairwise_sum, level 7 | 49.356 | 5.212 | 35.635 | 0.845 | 47.486 | 35.342 | -12.187 | -25.66 | 20/20 |
| area_fraction_above, level 5 | 21.908 | 1.751 | 21.436 | 0.605 | 21.281 | 21.221 | -0.070 | -0.33 | 11/20 |
| area_fraction_above, level 7 | 82.201 | 9.780 | 55.411 | 1.009 | 78.192 | 55.115 | -23.355 | -29.87 | 20/20 |
| segmented_sum, depth 2 | 4.326 | 0.036 | 4.416 | 0.091 | 4.337 | 4.418 | +0.084 | +1.95 | 4/20 |
| segmented_sum, depth 3 | 7.554 | 0.200 | 4.613 | 0.028 | 7.489 | 4.621 | -2.871 | -38.34 | 20/20 |
| segmented_weighted_sum, depth 2 | 5.236 | 0.007 | 5.089 | 0.156 | 5.236 | 5.071 | -0.173 | -3.30 | 14/20 |
| segmented_weighted_sum, depth 3 | 15.658 | 0.658 | 10.611 | 0.270 | 15.542 | 10.537 | -4.993 | -32.13 | 20/20 |
| segmented_mean, depth 2 | 23.506 | 1.525 | 23.238 | 0.722 | 23.051 | 23.085 | -0.120 | -0.52 | 11/20 |
| segmented_mean, depth 3 | 33.765 | 2.526 | 28.790 | 2.347 | 33.057 | 28.206 | -4.849 | -14.67 | 19/20 |
| segmented_quantile, depth 2 | 27.138 | 2.072 | 26.824 | 1.735 | 26.374 | 26.393 | +0.016 | +0.06 | 6/20 |
| segmented_quantile, depth 3 | 28.074 | 1.530 | 28.066 | 1.763 | 27.664 | 27.608 | -0.011 | -0.04 | 13/20 |

- **Six cases move by 14.7 to 38.3 per cent, the branch faster in 19 or 20 of the twenty
  pairs**: `pairwise_sum` and `area_fraction_above` at level 7, where the dispatch now
  launches the portable kernel at workgroup 16 in place of the device form, and the
  segmented sum, weighted sum and mean at depth three, launched at 32 in place of 256.
- `segmented_weighted_sum` at depth two moves by -3.30 per cent, faster in 14 of 20.
- The segmented quantiles, whose launch is their layout, `segmented_mean` at depth two and
  `area_fraction_above` at level 5 move by 0.52 per cent or less, faster in 6 to 13 of 20.
- **`segmented_sum` at depth two reads +1.95 per cent, the branch faster in 4 of 20, and
  `pairwise_sum` at level 5 +0.53 per cent, in 6 of 20.** Probe 8 below does not resolve
  either within one process.
- Pairs 2 and 3 of the base arm ran slow on every case that reads back to the host, and
  pair 2 of the branch arm on `segmented_mean` and `segmented_quantile`, the pattern
  `fiddlybits-3gt` carries; the means and standard deviations carry them, and the paired
  medians are what the verdicts above read.

### Probe 8: the two cases the bench reads slower, within one process

The bench's own fixture shapes and statistic (the minimum over 60 batches of 400 calls, each
call allocating its result), on the branch, six rounds with the arm order reversed on even
rounds (job 2130, host load 8.57 to 10.17, no other job holding a share at any of its 38
rows). Control: the first arm with a 15 us host busy-wait read 19.562, host 19.548. Median
and span over the six rounds:

| call | batch | span | host |
| --- | --- | --- | --- |
| `segmented_sum` at depth two, `GPU()` | 4.280 | 0.179 | 4.266 |
| the same, `GPU(32)` | 4.256 | 0.179 | 4.237 |
| the same, `GPU(64)` | 4.248 | 0.141 | 4.234 |
| the same, `GPU(256)` | 4.243 | 0.227 | 4.228 |
| `pairwise_sum` at level 5, `GPU()` | 18.817 | 0.127 | 18.815 |
| the same, `GPU(256)` | 18.853 | 0.402 | 18.852 |

- Batch equals host within 0.02 on every row: both calls are bound by the host's launch,
  not by the card.
- Within one process the unpinned launch and the pins read within 0.04 of each other on
  both cases, against spans of 0.13 to 0.40. The bench's difference on these two cases is
  between the processes of two trees at the host floor, and is not attributed here.

Per sample, in pair order, for every case (base, then branch):

- pairwise_sum, level 5: 20.024 19.026 24.382 19.349 19.202 18.852 18.573 19.077 18.816 18.920 18.824 18.672 18.503 18.740 18.635 18.720 19.153 19.070 18.876 18.524; 20.080 19.936 19.504 19.475 18.847 18.573 18.914 18.860 18.892 18.931 18.424 18.828 18.896 18.906 19.218 18.758 19.391 18.820 19.421 18.987
- pairwise_sum, level 7: 50.404 64.757 64.045 47.504 49.562 47.428 47.519 47.395 46.835 47.459 47.098 47.548 47.631 47.578 47.653 47.247 47.153 47.468 47.422 47.410; 37.794 37.758 36.308 36.348 35.177 35.283 35.356 35.592 35.004 35.181 35.168 35.328 35.164 35.137 34.474 35.663 35.448 35.471 35.855 35.199
- area_fraction_above, level 5: 22.793 26.930 26.636 22.577 22.046 21.297 20.945 21.096 21.314 21.266 20.730 21.407 20.937 20.844 21.163 21.200 20.928 21.182 21.344 21.533; 22.797 22.992 22.253 21.773 20.898 21.161 21.148 21.312 21.064 20.953 20.857 21.201 21.240 20.973 21.121 21.509 21.365 20.949 21.722 21.434
- area_fraction_above, level 7: 83.474 110.429 110.129 81.923 82.706 78.352 78.233 78.025 82.241 78.306 78.740 78.009 77.981 77.917 77.988 78.151 77.848 77.911 78.144 77.518; 57.790 56.745 56.618 56.928 55.267 56.009 54.879 54.341 54.081 55.105 54.425 55.125 54.473 54.754 55.032 55.190 56.183 54.556 55.895 54.828
- segmented_sum, depth 2: 4.348 4.331 4.384 4.348 4.358 4.300 4.362 4.352 4.326 4.270 4.299 4.342 4.309 4.310 4.359 4.292 4.243 4.353 4.290 4.348; 4.470 4.439 4.433 4.651 4.444 4.352 4.475 4.307 4.412 4.409 4.305 4.424 4.488 4.571 4.325 4.375 4.311 4.344 4.462 4.320
- segmented_sum, depth 3: 7.522 8.105 8.168 7.520 7.488 7.479 7.469 7.478 7.489 7.501 7.485 7.486 7.490 7.475 7.471 7.471 7.473 7.496 7.494 7.524; 4.582 4.629 4.637 4.616 4.619 4.623 4.615 4.619 4.637 4.620 4.627 4.641 4.548 4.634 4.550 4.623 4.616 4.623 4.573 4.636
- segmented_weighted_sum, depth 2: 5.256 5.239 5.231 5.231 5.240 5.243 5.223 5.237 5.231 5.243 5.239 5.228 5.240 5.227 5.239 5.230 5.233 5.232 5.239 5.236; 5.056 4.825 5.086 4.806 5.303 4.967 5.309 5.291 4.935 4.984 5.246 5.144 5.026 5.253 5.036 4.960 5.265 5.115 5.186 4.995
- segmented_weighted_sum, depth 3: 16.176 16.094 18.149 15.729 15.435 15.545 15.449 15.580 15.646 15.320 15.539 15.798 15.213 15.640 15.015 15.516 15.179 15.460 15.030 15.647; 10.602 10.545 10.523 10.534 10.560 10.537 10.502 10.538 10.668 11.742 10.512 10.528 10.550 10.636 10.609 10.533 10.532 10.528 10.507 10.537
- segmented_mean, depth 2: 24.626 23.394 29.637 24.340 22.966 22.906 22.730 22.874 23.242 23.511 23.088 22.992 22.651 22.911 23.124 22.792 23.068 22.979 23.035 23.260; 24.425 25.792 23.111 23.308 23.463 22.944 23.362 23.080 22.885 23.067 23.115 23.272 22.577 22.745 22.716 23.420 22.725 23.091 22.867 22.801
- segmented_mean, depth 3: 34.798 32.658 44.177 34.649 32.995 32.610 32.807 32.664 32.852 33.352 32.935 33.476 33.114 32.531 33.554 32.996 33.168 33.000 33.133 33.831; 29.520 38.656 28.383 28.362 28.285 28.185 28.360 28.283 28.059 28.062 28.219 28.067 28.028 27.884 28.031 28.141 28.194 28.157 28.655 28.273
- segmented_quantile, depth 2: 27.602 32.908 33.329 27.181 26.303 26.291 26.340 26.286 26.367 26.299 26.278 26.454 26.432 26.459 26.381 26.346 26.356 26.337 26.404 26.410; 27.747 34.072 26.437 26.284 26.305 26.329 26.358 26.397 26.304 26.301 26.303 26.436 26.446 26.294 26.274 26.443 26.389 26.485 26.465 26.412
- segmented_quantile, depth 3: 28.723 34.448 27.687 28.489 27.635 27.579 27.592 27.573 27.596 27.595 27.586 27.694 27.671 27.679 27.658 27.685 27.692 27.591 27.680 27.633; 28.539 35.502 27.686 27.579 27.581 27.585 27.579 27.596 27.598 27.587 27.571 27.675 27.722 27.616 27.754 27.585 27.668 27.617 27.671 27.600

## The gate's door on this branch

`tools/gate/gate.sh` from the worktree, before the commit, printed at its start and again at
its end:

```
gate: bounds door against main at c242ec05268c: 3 changed .jl file(s) elide a bounds check; every suite also runs under --check-bounds=yes
gate:   src/Reductions/pairwise.jl at line(s) 23, 26, 42, 47, 50
gate:   src/Reductions/quantiles.jl at line(s) 156, 159, 174, 355, 358, 367, 372, 375, 456, 460, 461, 471, 472, 478, 482, 483
gate:   src/Reductions/segmented.jl at line(s) 169, 172, 239, 242, 318, 322, 323
gate: the door's 7 controls came out as stated
gate: under --check-bounds=yes kernels under @inbounds read checked on cpu and checked on gpu
```

All 17 suites passed in both passes: wall 279.4 s, sum of suites 1406.7 s, `certify+bounds`
279.3 s, `certify` 173.9 s, `backends+bounds` 136.0 s, `backends` 129.4 s,
`reductions+bounds` 126.4 s, `reductions` 119.5 s.

## Anomalies not explained here

- The first timed row of job 2027 read 25.5 and the same row at its end 4.6.
- `area_weighted_block_kernel!` at one thread per block read 17.926 at 384 blocks and 16.963
  at 512 (job 2046, spans 0.065 and 0.092).
- `segmented_sum_kernel!` at workgroup 32 over 65536 segments of 256, 2048 blocks, read
  540.650, eighteen times the same block count at workgroups 1 to 16 (job 2038).
- Every block-sum device form's cost steps up between 720 and 800 blocks of 256 threads
  (job 2057), by 1.66 to 1.75 times.
- `segmented_sum` at depth two and `pairwise_sum` at level 5 read slower on the bench and not
  within one process (probe 8).
