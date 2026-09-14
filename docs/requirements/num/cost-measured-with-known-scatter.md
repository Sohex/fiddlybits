+++
id = "REQ-NUM-006"
title = "Cost is measured with an instrument whose scatter is known, and a change that moves the answer is a numerics change, not a timing one"
old_path = ["/home/cfutro/git/vesper/notes/audits/pyburn-postprocessing-cost.md", "/home/cfutro/git/vesper/notes/audits/model-build-flags.md"]
old_commit = "6aa93489d233d4e9d531d6479d338c643e34bc5e"
status = "carried"
+++

## What is true

Measured on the predecessor's spectral GCM and its postprocessor. The specific flag
verdicts (an optimisation level, a loop-unrolling flag, a link-time flag) do not
carry; the method does. A flag whose removal left a byte-identical executable was
doing nothing, and that screen retired three candidates before any benchmark ran.
Arms run in blocks confounded the flag with the processor's boost state: one binary
measured 6 per cent apart in two sessions while every other arm reproduced to 0.5
per cent. Paired, interleaved arms with a warm-up run and a self-scatter floor of 5
per cent declared before any bar fixed that; arms whose own scatter exceeded the
floor were reported as refusals rather than as numbers. A refusal taken on one
profile reversed by eleven points when the hot path it named was replaced (a flag
that unrolled Legendre sums did nothing; the same flag unrolling the physics after
the transform migration gained 11 per cent, four of four rounds). A flag that
changed the checkpoint bytes was excluded from every timing comparison as a
numerics decision. Wall clock on a shared host varied 5 to 21 per cent between
windows by contamination alone; retired instructions per step reproduced to four
parts in ten thousand across a threefold load range, and still under-predicted the
top rung's wall clock by a third, because barrier and output wait retire nothing,
so both instruments were reported.

The postprocessor was quadratic in record count: an append that reallocated the
whole accumulated array per record cost 304 s of a 385 s orbit; collecting records
and concatenating once gave 29 s with every output bitwise identical. What remained
was the interpreter manufacturing float objects: decoding the payload as a typed
view gave 0.96 s against 30.5 s with value, shape and dtype identical. The profiler
had attributed the time to a function with two callers whose call counts differed
by three orders of magnitude, and sorting by self time pointed at the wrong one; a
profiled baseline against an unprofiled treatment then flattered the wrong fix. A
JIT was the wrong tool because the hot path was not arithmetic.

## Why it carries

Cost is a gate quantity here: the fast profile is defined by running the coupled
system end to end in hours on one card (A10), CI has a declared budget (E), and the
memory budget is computed rather than quoted (A7). C6 requires benchmarks with A/A
scatter measured before any bar. Julia has the same two failure shapes: a
super-linear reduction or export (`vcat` in a loop, a growing `Dict` of arrays) and
allocation manufacturing from type instability, and a profiler that attributes to a
function with many callers. A performance refusal recorded without its profile is a
decision that silently stops applying when the hot code moves.

## What this system must do

1. A benchmark is a registered oracle: a declared bed (level, profile, step count,
   initial state key), a declared instrument, A/A scatter measured first, and a bar
   fixed before the arm runs. Arms are paired and interleaved with a warm-up. A
   result whose self-scatter exceeds the declared floor is reported as no verdict.
2. At least one machine-state-independent cost unit (retired instructions, or device
   kernel time from events) is recorded beside wall clock, and on a shared host the
   load during every wall measurement is recorded with it.
3. A change is screened for identity before it is timed: if the state hash of the
   per-commit case is unchanged the change is a timing candidate; if it moves, the
   change is a numerics change under the `answers:` discipline (C6) and is never
   folded into a timing comparison.
4. Every adoption or refusal of an optimisation records the profile, level, backend
   and commit it was measured on and names the mechanism; it is re-opened when the
   hot path it named changes.
5. The scaling exponent of every reduction, export and reader in record count and
   cell count is measured at two sizes; a super-linear path is a defect. Allocations
   per step are tracked on the per-commit case; a profile attribution is checked
   against call counts before a fix is chosen.
6. The memory budget is computed from the field registry per profile and the
   measured high-water mark is compared against it (E).

## Enforced by

Benchmark rows in the oracle registry with `provisional` and `registered_at`; a CI
job running A/A on the short coupled case; an allocation-tracking test; scaling
tests for readers and writers; decision records A7, A10 and C6.

## References

- Mytkowicz, T., Diwan, A., Hauswirth, M., Sweeney, P. F. 2009. Producing wrong data without doing anything obviously wrong! Proceedings of the 14th International Conference on Architectural Support for Programming Languages and Operating Systems. DOI: 10.1145/1508244.1508275
- Hoefler, T., Belli, R. 2015. Scientific Benchmarking of Parallel Computing Systems: Twelve ways to tell the masses when reporting performance results. Proceedings of the International Conference for High Performance Computing, Networking, Storage and Analysis (SC '15). DOI: 10.1145/2807591.2807644
