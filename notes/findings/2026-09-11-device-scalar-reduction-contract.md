# A device-scalar pairwise_sum keeps the fixed-order tree bitwise but costs more than the host read it removes, and removes no synchronisation at all

Measured on 2026-09-11 on yggdrasil through `qrun` with this repository's defaults
(profile `gpu-share`, one share of an NVIDIA GeForce RTX 4090, driver 610.57.04, 8
CPUs, 16G), nothing else on the card, Julia 1.12.7, CUDA.jl 6.3.1,
KernelAbstractions.jl 0.9.42, Adapt.jl 4.7.0, on branch `fiddlybits-52v.7.47`.

`Reductions.pairwise_sum` returns a host scalar, so it moves the block sums to the
host on every call (`Backends.on`, one `Events.Moved` record on device-resident
input). `fiddlybits-52v.7.47` asks whether the contract should change: a device-scalar
form would let a caller chain reductions and pay one host read at the end, where a
refusal, a verdict or a ledger line genuinely needs a host value.

Two things were measured: whether the fixed-order tree survives being moved onto the
device, and what the move costs. The first passes. The second is why the contract
stays.

## What a device-scalar form has to be

`combine_fixed_order` is what makes the sum partition-independent (decision 0029): the
result depends only on the term count, the block size and the accumulator type, never
on the thread count or on how blocks were scheduled. It runs `combine_tree`, an
indexed recursion over the block sums with `mid = n div 2`, on the host.

That tree is not a stride-doubling loop and is not a left- or right-biased bottom-up
pairing. For `n = 5` it is `(v1 + v2) + (v3 + (v4 + v5))`, which no local greedy
merge rule over adjacent partials reproduces. A device form therefore has to walk the
same recursion, and a GPU kernel has no dynamic stack, so the candidate measured here
is the same depth-first walk with an explicit frame stack in shared memory, run by one
work item:

    frames (lo, hi, state) and a value stack, both depth 64;
    a leaf pushes v[lo]; a state-2 frame pops two values and pushes left + right.

The addition order is `combine_tree`'s by construction: the left child is fully
evaluated, then the right, then `left + right`. The whole combine is additions only,
so there is no multiply for the GPU to contract into a fused multiply-add, and IEEE
754 double addition is correctly rounded on both devices.

## Partition independence and cross-backend agreement survive it

The candidate's result was compared as a raw bit pattern against
`Reductions.pairwise_sum` at five term counts and four workgroup sizes, on the
processor and on the card, twenty configurations in all. The block size was the
declared `BLOCKSIZE = 256` throughout, so every row is the same tree reached through a
different partition of work items.

| n | nb | bit pattern, all of host/device combine x CPU/GPU x workgroup 8, 64, 256, 1024 |
|---|---|---|
| 4096 | 16 | `0x400a6666666666ba` |
| 40962 | 161 | `0x4009c28f5c28f9b2` |
| 163842 | 641 | `0x401b333333333a7c` |
| 655362 | 2561 | `0x3fe0a3d70a3e52e0` |
| 2621442 | 10241 | `0x4001c28f5c29d7c5` |

One pattern per row across every configuration. So the constraint the row named as the
thing that decides it is not the thing that refuses the change: the tree does move onto
the device, and thread count, block partition and backend all leave it bitwise
unmoved. The refusal is the cost.

## The floor: an empty kernel launch already costs more than the read

`Backends.launch!` synchronizes after every kernel
(`KernelAbstractions.synchronize(dev)`, unconditional). A device-scalar
`pairwise_sum` therefore does not remove a synchronisation from the call; it adds a
second kernel launch, each of which synchronizes, and defers only the memory copy.
The two floors, minimum and median of 200 repeats, over two independent jobs:

| operation | min (us) | median (us) |
|---|---|---|
| one-item kernel launch + synchronize | 5.95, 5.89 | 6.32, 6.27 |
| one-element device-to-host read | 4.84, 4.50 | 5.21, 5.15 |

A device combine that did no arithmetic at all would already cost more than the
one-element read it is meant to replace. Everything below is that gap widening.

## The cost of finishing one global sum

The finish of a global sum is either a copy of the `nb` block sums plus the host tree,
or the device combine. Minimum and median of 200 repeats, microseconds, two
independent jobs reported as two numbers per cell:

| n | nb | copy | host tree | copy + tree | device combine |
|---|---|---|---|---|---|
| 4096 | 16 | 6.94 / 7.41 | 0.11 / 0.11 | 6.89 / 7.42 | 59.11 / 76.07 |
| 40962 | 161 | 7.30 / 7.39 | 1.28 / 1.20 | 8.92 / 8.85 | 506.64 / 506.33 |
| 163842 | 641 | 8.89 / 8.55 | 5.31 / 4.98 | 13.80 / 13.25 | 241.16 / 241.16 |
| 655362 | 2561 | 7.15 / 6.48 | 18.87 / 19.97 | 27.61 / 31.77 | 866.33 / 865.90 |
| 2621442 | 10241 | 13.66 / 11.99 | 75.54 / 83.76 | 88.97 / 117.73 | 3427.45 / 3430.38 |

The device combine is between 8 and 39 times the cost of the copy and the host tree
together, at every size measured. The `nb = 161` cell is out of order against `nb =
641` and reproduces to within 0.1 per cent across both jobs, so it is a property of
the kernel at that size and not clock scatter; it was not chased, because the smallest
device-combine number on the table is still 8.6 times the host finish it replaces and
no explanation of the outlier moves that.

The whole call, same protocol:

| n | nb | host scalar (us) | device scalar (us) |
|---|---|---|---|
| 4096 | 16 | 30.51 / 30.87 | 37.76 / 38.26 |
| 40962 | 161 | 36.25 / 36.91 | 90.37 / 91.47 |
| 163842 | 641 | 42.57 / 43.59 | 257.31 / 257.95 |
| 655362 | 2561 | 60.97 / 59.60 | 899.41 / 900.01 |
| 2621442 | 10241 | 120.63 / 126.81 | 3464.05 / 3468.15 |

The reason is structural rather than an artefact of this kernel. One work item walking
the tree is `nb - 1` dependent additions in sequence, and a GPU lane executes a
dependent chain of scalar work far slower than a host core does; the host tree column
above is that same chain on the processor and is the cheapest column on the table. A
parallel device tree that reproduced `combine_tree`'s shape would need either one
kernel launch per level (about `log2(nb)` launches, at the 5.9 us floor each, which is
already worse than the copy by `nb = 161`) or a precomputed comparison network in
shared memory in the manner of `QUANTILE_BITONIC_NETWORK`, bounded to one workgroup
and so to a `nb` the block sums exceed at the mesh levels a run uses.

## The chain the row named

`area_fraction_above` is the one consumer in the tree that takes two sums for one
fraction, and pays two reads. Three shapes, all returning the same `Float64` bit for
bit (asserted in the probe against `area_fraction_above` itself), minimum of 50
repeats, microseconds:

| n | nb | two reads (today) | device scalars, one read | one read, two host trees |
|---|---|---|---|---|
| 4096 | 16 | 65.93 | 86.40 | 70.83 |
| 40962 | 161 | 77.17 | 191.40 | 82.61 |
| 163842 | 641 | 89.52 | 526.36 | 95.27 |
| 655362 | 2561 | 117.84 | 1812.80 | 121.82 |
| 2621442 | 10241 | 277.33 | 7004.93 | 267.77 |

The chaining argument is the case for the contract change, and this is the chain: it
is slower than what it replaces at every size, by between 1.3 and 25 times. The third
column is the shape `fiddlybits-52v.7.48` carries, which concatenates the two block-sum
arrays and reads once with no device combine at all; it is at parity with today within
the scatter of the measurement, which is that row's number to act on and not this
one's.

## The answer

The contract stays. `pairwise_sum` returns a host scalar and no device-scalar door is
added beside it.

The three reasons, in the order they bind:

1. The synchronisation a device scalar is supposed to save is not the host read's.
   `Backends.launch!` synchronizes after every kernel, so a chained device-scalar
   reduction synchronizes once per kernel exactly as the host-scalar form does, and
   the contract change would defer a memory copy and nothing else. Whether the launch
   should be asynchronous is a question about `src/Backends/`, filed as
   `fiddlybits-52v.7.50`; until it is answered there is no synchronisation in
   `Reductions` for a contract change to remove.
2. What it would defer costs less than what it would add. The one-element read is
   4.5 to 4.8 us and the kernel launch that would replace it is 5.9 us before any
   arithmetic.
3. The fixed-order tree is serial by shape, and the processor is the right device for
   a serial dependent chain. This is not a defect of the candidate kernel; it is the
   same reason `compensated_sum` has no backend argument.

Partition independence is not the reason, and the measurement above is what says so:
the tree moves to the device bitwise intact. Recording that matters, because the next
session to ask this question should not have to re-derive the explicit-stack walk to
find out that it works and is simply not worth running.
