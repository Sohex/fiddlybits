# DoubleFloats.jl

**What it is.** Extended-precision arithmetic from pairs of hardware floats.
`DoubleFloat{T}` is an immutable `isbits` pair of magnitude-ordered, non-overlapping
values of type `T`, with `Double64`, `Double32` and `Double16` as the aliases. Arithmetic
is built from error-free transforms on the component type, and above that the package
provides the elementary functions, comparison, printing, random generation and a linear
algebra surface for the pair types.

**What of it is used.** Nothing. This record declines the dependency.

**Licence.** MIT. **Version.** 1.11.2. **Read at.**
`9b37877d0f54ec8792d8954cf9e0e2dec59460d6`, committed 2026-07-28, in
`/home/cfutro/git/JuliaMath/DoubleFloats.jl`. Measured on the RTX 4090:
`notes/findings/2026-09-10-compensated-accumulation-in-a-kernel.md`.

**Verdict.** Do not adopt. The type is device-safe and the arithmetic is correct; the
package loses on its own premise. Decision 0011 wants compensated accumulation because a
consumer card throttles double precision, and on the card this project runs, `Double32`
accumulates at 3.69e-11 s per add against 1.95e-11 for the plain Float64 it was supposed
to replace. A hand-written pair accumulator built on the same error-free transform costs
7.2e-12, spills nothing where `Double32` spills 104 bytes, and lands on the same answer to
the last bit. The kernel library writes its own accumulator, in about ten lines, and the
dependency does not enter.

This is a verdict about an accumulator in a kernel and not about the package, which is
careful, well documented and the right answer for extended-precision work on a processor.

## Why the type is fine and the package is not

`DoubleFloat{T}` is `struct DoubleFloat{T} (hi::T, lo::T)`, immutable and `isbits`, so it
passes into a kernel like any other value and compiles there. That was confirmed by
running it: the `Double32` accumulation kernel compiled and produced the double-precision
answer exactly.

What it costs is in the operator. `add_dbdb_db` (`src/math/ops/op_dbdb_db.jl`) tests both
operands for non-finiteness, calls the two-double addition, tests the result for
finiteness again and recomputes through a slower path if it overflowed, then constructs a
renormalised pair. Two data-dependent branches per addition is warp divergence in a kernel
and a data-dependent cost in a design that wants every lane to do the same work; the
renormalisation on every operation is work an accumulator needs only once, at the end.
The measurement shows the total: five and a half times a naive single-precision add, and
nearly twice a double-precision one.

The dependency weight is the second argument and the smaller one. `Project.toml` pulls
`Quadmath` (a `libquadmath` binding), `SpecialFunctions`, `GenericLinearAlgebra` and
`GenericSchur` for the elementary-function and linear-algebra surface. None of that is
reachable from a kernel and none of it is needed for `+`, but all of it enters the
dependency graph, the precompile time and the environment manifest that decision 0029
hashes into the run identity.

## What is taken instead

The error-free transform itself, which is not the package's invention and is four
operations:

    s = a + b
    v = s - a
    e = (a - (s - v)) + (b - v)

with `(s, e)` exact. The project's accumulator keeps `hi` and a running `lo` of the
errors, renormalises once at the end, and converts to the wide type there. That is the
whole of what decision 0011 asks for in a ledger. `AccurateArithmetic.jl`
(`src/errorfree.jl`) is the cleaner reading of the same primitives and is an algorithmic
reference for the `two_prod` form when a compensated product is needed.

The identity that decides the accumulator is in the finding and belongs in the test suite:
a stock eight orders larger than its increment, a million unit increments, and the
assertion that the stock moved by exactly a million. Naive single precision accumulates
none of them, which is what makes the test a test.

## Assumptions it carries

Recorded because the survey asked for the review, even though the verdict is no.

**Earth defaults (A2, A3), calendar (A1).** Clean negatives. No physical constant, no
`Dates`.

**Grid, mesh and index base (A6).** No grid notion; the package is scalar and matrix
arithmetic.

**Precision.** The subject of the package. `DoubleFloat{T}` roughly doubles the
significand of `T` and does not extend its exponent range, so a `Double32` overflows where
a Float32 overflows. A reservoir accumulated as a `Double32` therefore has the dynamic
range of single precision with the resolution of double, which is not the same guarantee
as Float64 and is a distinction a ledger tolerance has to state.

**Threading and GPU model.** None of its own. The type compiles in a device kernel; the
elementary functions and linear algebra do not and were not tried.

**Mutable global state (C5).** None in the arithmetic core.

**Clamps and limiters (B5).** The non-finite guards in each operator, which substitute a
saturated value with a zero error rather than refusing. In `two_sum` the guard is
documented at length and deliberate: on overflow it returns the infinite sum with a zero
error so that a compensating caller sees an infinity rather than a NaN. That is a
defensible choice and it is a silent one, and a ledger that overflows should refuse rather
than close on an infinity.

**Declared against demonstrated (C3).** Tested upstream on the processor. No GPU test, no
kernel test; the device behaviour recorded here was measured here.

**Fail-open branches (C4).** The non-finite paths above, in every operator.

## Checklist

| item | result |
| --- | --- |
| A1 day and year | clean negative |
| A2 planetary constant block | clean negative |
| A3 Earth literals | clean negative |
| A6 grid and index base | no grid notion |
| B4 comment against value | no mismatch; the `two_sum` overflow comment matches its code and explains it |
| B5 clamps and limiters | non-finite guards in every operator, returning a saturated value with zero error |
| C1 use site of every constant | no physical constants; the only constants are splitting factors inside the error-free transforms |
| C3 declared against demonstrated | processor tests upstream; device behaviour demonstrated only in the finding here |
| C4 fail-open branches | the non-finite and overflow-recompute paths, two data-dependent branches per operation |
| C5 duplicate state and second constant sets | clean negative |
| D2 boundary field by field | the type is `isbits` and crosses the device boundary intact; the exponent range is the component type's, not the doubled type's |
| D4 conservation identity | run here: a stock of 1e8 taking a million unit increments, exact in advance; the pair forms are exact, naive single precision accumulates none of it |

## References

- The measurements: `notes/findings/2026-09-10-compensated-accumulation-in-a-kernel.md`.
- The survey entry: `docs/surveys/gpu-and-arrays.md`, JuliaMath.
- Decision 0011 (ledgers and reservoirs in double precision or compensated summation),
  decision 0029 (precision certified per kernel; the stagnation argument).
- `AccurateArithmetic.jl` and `KahanSummation.jl`, the algorithmic references for the same
  primitives, surveyed in the same record.
- The row that consumes this: `fiddlybits-52v.7.3` (fixed-order pairwise reductions and
  compensated sums) and `fiddlybits-52v.3.6` (the ledger type and its tolerance).
