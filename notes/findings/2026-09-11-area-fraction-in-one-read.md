# area_fraction_above in one read: the same bits, one move record, and one completion fewer

Measured on 2026-09-11 on yggdrasil through `qrun` with this repository's defaults
(profile `gpu-share`, one share of an NVIDIA GeForce RTX 4090, driver 610.57.04, 8
CPUs, 16G), nothing else on the card, Julia 1.12.7, CUDA.jl 6.3.1,
KernelAbstractions.jl 0.9.42, on branch `fiddlybits-52v.7.48`. The row is
`fiddlybits-52v.7.48`, raised by `fiddlybits-52v.7.44`.

## The two forms

`area_fraction_above` was a `pairwise_sum` of the areas and an `area_weighted_sum` of
the areas above the threshold, each reading its own block sums back to the host: two
`Events.moved` records and two completions per call on device-resident input.

The form measured against it computes the same two block-sum arrays, joins them on the
backend, moves the pair in one `Backends.on`, and combines each half on the host
afterwards. The block sums are the same values from the same kernels over the same
blocks, and `combine_tree` takes its shape from the length of what it is handed, so
each half is added by the same tree it was added by before.

## The bits

Every cell of both tables below was checked as raw bits, `reinterpret(UInt64, ...)`
on the two results: equal at every size, on both backends, for every threshold tried
(the smallest element, an interior element, the largest element, and a value above
them all). `test/reductions/quantiles.jl` carries that assertion, with the positive
control that the comparison separates a value from its `nextfloat`.

## The cost

Mean seconds per call over a batch of 200 calls, minimum and median over 10 batches,
the two forms measured in one alternating loop. Two independent jobs, reported as two
numbers per cell.

Device-resident input, minimum microseconds per call:

| terms | one read | two reads |
|---|---|---|
| 4096 | 62.89, 63.15 | 72.58, 73.13 |
| 16384 | 70.50, 71.11 | 79.93, 80.71 |
| 163842 | 105.70, 106.92 | 115.69, 116.12 |
| 655362 | 138.95, 139.40 | 148.73, 148.86 |
| 2621442 | 267.21, 272.05 | 282.54, 282.71 |

The one-read form is faster by 9.4 to 10.0 microseconds at every size in both jobs,
which is a constant and not a fraction: it is the completion and the copy that the
second read no longer pays. At 4096 terms that is 13 per cent of the call and at
2621442 terms it is 5 per cent, because the rest of the call grows with the input and
this saving does not.

Host-resident input, where `Backends.on` is a no-op and there is nothing to save:

| terms | one read | two reads |
|---|---|---|
| 4096 | 7.24, 7.45 | 7.13, 7.43 |
| 16384 | 20.76, 21.43 | 20.73, 21.28 |
| 163842 | 191.02, 197.75 | 190.74, 196.98 |
| 655362 | 755.52, 779.66 | 752.88, 777.57 |

The two forms are the same call on the host to within the scatter, and the join costs
nothing measurable there. This is the control on the device table: had the difference
above been an artefact of the measurement rather than the saved read, it would appear
here too.

The move records are what the change was for: one `Events.moved` per call instead of
two, asserted in `test/reductions/segment_moves.jl`, both in the per-call table and in
the repeated-call count.

## Why the measurement is batched

A single call timed on its own does not reproduce. `Backends.complete!` on an idle
stream costs under the clock's resolution, and immediately after a launch it costs
111.82 microseconds, because CUDA.jl's synchronization spins a bounded number of times
and then falls back to a round trip through a worker thread. Which of the two happens
is not stable from call to call: minimum-of-50 timings of a single
`area_fraction_above` call at 4096 terms came out at 304 and 479 microseconds in two
runs of the same binary, and the two forms could not be separated at that scatter. Over
a batch of 200 calls the two paths mix in the same proportion in both arms and the
numbers above reproduce to a few tenths of a microsecond across jobs.

## References

- Decision 0010, the device-move record; decision 0011, the explicit move.
- Decision 0029, reproducibility: the bits section is the assertion that nothing here
  touches the arithmetic.
- `notes/findings/2026-09-11-device-scalar-reduction-contract.md`, which measured the
  one-read shape as a probe and found it at parity, and named this row.
- `docs/plans/fiddlybits-52v.7-kernels.md`, section "The reductions".
