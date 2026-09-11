# A three-line compensated accumulator is as accurate as double precision and as fast as single; double-double is slower than both

Measured on 2026-09-10 on yggdrasil, through `qrun -p gpu-share` (one share of the RTX
4090, nothing else on the card), Julia 1.12.7, `CUDA.jl` 6.3.1, `DoubleFloats.jl` 1.11.2
at `9b37877d0f54ec8792d8954cf9e0e2dec59460d6`. Timings are the mean of three launches,
and the whole table was run three times: the run-to-run spread is under two per cent,
against differences of two to six times.

Decision 0011 holds every ledger and accumulated reservoir in double precision or by
compensated summation, because a consumer card throttles double precision. The question
was whether `DoubleFloats.jl`'s `Double32`, a pair of Float32s giving roughly twice
single precision in single-precision instructions, is usable inside a kernel and what it
costs against compensated summation.

## The accumulation

Each thread accumulates its own stream of 1048576 Float32 increments, all near 1.0 and
varying in the third decimal, which is the shape of a reservoir taking small deposits.
Four thousand and ninety-six threads each run their own accumulator; the reference is the
same sum at 300 bits. The increment is integer arithmetic converted to Float32, with no
transcendental in it, so the host and the device compute identical increments: the
positive control is that a host Float32 accumulation reproduces the device Float32
accumulation exactly, `1572340.125` both sides, which rules out a host-device difference
masquerading as an accumulator difference.

| accumulator | registers | local bytes | time per add | relative error |
|---|---|---|---|---|
| Float32 naive | 40 | 0 | 6.6e-12 s | 1.394e-07 |
| Float32 Kahan | 40 | 0 | 6.8e-12 s | 2.870e-08 |
| Float32 two_sum pair | 38 | 0 | 7.2e-12 s | 5.566e-10 |
| `Double32` | 37 | 104 | 3.69e-11 s | 5.566e-10 |
| Float64 naive | 40 | 0 | 1.95e-11 s | 5.566e-10 |

The bottom three are the same answer to the last bit, `1572340.34500015`, so 5.566e-10 is
the floor of the comparison and not a property of any of them.

Three results follow.

**The three-line accumulator wins.** A `two_sum` returning the rounded sum and its exact
error, with the errors accumulated in a second Float32, costs nine per cent over naive
single precision, spills nothing, and lands on the double-precision answer. It needs no
dependency: the error-free transform is four floating-point operations, the same
`(s, (a - (s - v)) + (b - v))` that `AccurateArithmetic.jl` and `DoubleFloats.jl` both
build on.

**Double-double is slower than the double precision it was meant to avoid.** `Double32`
took 3.69e-11 s per add against 1.95e-11 for a plain Float64 accumulation on the same
card, so the argument for the package, that it sidesteps the consumer-card
double-precision throttle, does not survive contact with the throttle. It also spilled 104
bytes to local memory where the hand-written pair spilled nothing. The cause is visible in
the source: `add_dbdb_db` carries two data-dependent branches, one for non-finite inputs
and one that recomputes through a slower path when the fast one overflows, and it
renormalises the pair on every operation, where an accumulator only needs to renormalise
at the end.

**Kahan is worth five times, not five orders.** Classical Kahan compensation improves the
single-precision sum by a factor of five here and no more, because the compensation term
is carried but the result is still returned as one Float32. The pair form keeps both
halves to the end and converts once, which is the difference between a compensated sum
and a double-length accumulator.

## The stagnation control

Decision 0029 names the failure this is all for: a reservoir accumulating small increments
at single precision stagnates, because the increment falls below the ulp of the stock. A
stock of 1e8 taking a million increments of exactly 1.0, all in one thread:

| accumulator | accumulated, of 1000000 |
|---|---|
| Float32 | 0.0 |
| Float32 two_sum pair | 1000000.0 |
| `Double32` | 1000000.0 |
| Float64 | 1000000.0 |

Single precision accumulates none of it. Not some of it: the ulp of 1e8 in Float32 is 8,
every increment rounds away, and after a million additions the stock is unchanged. The
three compensated or wide accumulators are exact.

## What this changes

`docs/imports/doublefloats-jl.md` declines the dependency. The kernel library owns a
`two_sum`-based accumulator type of its own, used by every ledger, reservoir and global
reduction, and the stagnation case above becomes its positive control: a test that adds a
million unit increments to a stock eight orders larger and asserts the stock moved by
exactly a million. It fails for a naive single-precision accumulator, which is what makes
it a check.
