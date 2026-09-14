+++
id = "REQ-NUM-002"
title = "Reproducibility across thread counts is a design property tested with repeats; CPU/GPU agreement has a measured tolerance"
old_path = ["/home/cfutro/git/vesper/notes/audits/model-reproducibility.md", "/home/cfutro/git/vesper/notes/audits/implicit-save-under-threads.md", "/home/cfutro/git/vesper/notes/audits/shared-diagnostics-unit-under-threads.md"]
old_commit = "6aa93489d233d4e9d531d6479d338c643e34bc5e"
status = "carried"
+++

## What is true

Measured on the predecessor's spectral GCM. At a fixed decomposition count the
model was bit-reproducible: eight configurations, three repeats each, every state
and output file identical. Across decomposition counts it was not: 8 against 16
workers integrated one checkpoint to answers differing in 83 of 199 state records
after 56 steps, all at round-off (largest relative difference 3.7e-10), the
signature of partial sums grouped differently. Benign per step and unbounded per
run because the flow is chaotic, so every A/B had to hold the worker count fixed.
The finding survived the move from processes to threads unchanged, because the
latitude decomposition divided by the same count either way. A control offered as
evidence of reproducibility had compared output over a window in which no output
was written, and so could not have failed.

Under the threaded port two classes of shared state appeared that the process
build had made private by construction. A local variable declared with an
initialiser acquired static storage and became one copy for the whole thread team:
eight threads writing their own id into such an array and reading it back, seven
read another thread's value; the compiler reported nothing at any warning level.
Sixty-six such sites were safe only because each was written before it was read on
every call, a property of the code re-established by a lexical pass and not of the
declaration. The process-wide diagnostics unit was one file for every thread; of
928 write sites, thirteen were reachable by every thread, and a fourteenth was
found only when the search was widened to a second spelling of the write. The rule
that held: a quantity the same on every thread has one writer; a thread's own chunk
is serialised with the thread id in the record; a kernel with no thread identity
does not gain a dependency on the parallel layer to get one. The predecessor's
stochastic streams were keyed by hashing the physical cell, the ecological
replicate and the process name, so a stream never depended on rank or traversal
order and draws in one process could not advance another
(`/home/cfutro/git/vesper/lib/stochastic_seeds.py`). A cold start with no declared
seed drew from the system clock, making two cold starts two experiments. A
configuration scalar read by one worker and never shared with the others corrupted
60 of 64 latitude rows in 26 output fields while every collective count still
matched (`/home/cfutro/git/vesper/notes/audits/nlowio-collective-deadlock.md`).

## Why it carries

This system runs the same kernels through KernelAbstractions on CPU threads and on
GPU lanes (a kernel with a device form under decision 0051 runs a second text on the
GPU, held bitwise to the first there), and the worker count is never fixed for the life of a run: the fast
profile, the full profile, the reference arm and the CI case all differ in it. If
the answer depends on the count, no A/B is controlled, the per-commit state-hash
gate is meaningless, and a CPU/GPU disagreement cannot be separated from a bug. The
static-state class exists in Julia in a different dress: mutable globals, module
`Ref`s, closures capturing a scratch array, memoisation caches guarded by a flag,
`Threads.@threads` over a shared buffer. Diagnostic writes from many lanes share
the shape of the shared unit. Stochastic streams keyed on order or worker are the
same defect in the random arm. The counter-based RNG keyed on physical identity is
what makes a stochastic process reproducible across decompositions (A6).

## What this system must do

1. Thread-count invariance is a design property: every reduction is a fixed-order
   pairwise or tree reduction whose partition does not depend on the worker count;
   no atomics in physics; no floating-point accumulation into a shared value across
   workers; loop order independent of partition.
2. Physics modules hold no mutable state outside `WorldState`: no mutable globals,
   no module-scope `Ref`, no closure capturing a mutable buffer, no static caches.
   Scratch buffers are preallocated per work item and written before read
   (REQ-NUM-003). Kernels perform no I/O and raise no exceptions (F8).
3. Every diagnostic record emitted from parallel work carries the cell id and has
   exactly one owner; a quantity that is the same on every worker is written once.
4. Configuration is one immutable `System{FT}` value, and every worker sees
   `strip(system)` by value; there is no per-worker copy that could diverge.
5. Stochastic streams use a counter-based generator keyed on (root seed, support id,
   cell, process, time index). A run containing any stochastic process refuses to
   start without a declared root seed. Draws in one process never advance another,
   and adding a process does not move an existing stream.
6. CPU/GPU agreement has two tiers: a bitwise debug mode in which elementwise
   kernels agree exactly between backends, and a production mode whose tolerance is
   the measured 1-ulp-ensemble divergence envelope (C6). The same envelope
   certifies each FP32 kernel against its FP64 self.
7. Tests with repeats, per commit on the short coupled case: a repeated run at a
   fixed thread count is bitwise; runs at thread counts 1, 2 and the profile's
   count are bitwise in debug mode; a control comparison is refused unless the
   window it compares contains observations (REQ-NUM-008). The state hash of the
   per-commit case may change only with an `answers:` line.

## Enforced by

Decision record C6; the M0 gate "elementwise CPU/GPU bitwise" and the M3 gate
"thread bitwise; ulp envelope"; lints banning mutable globals, atomics in physics
modules and I/O in kernels; a `CellId`-keyed RNG type with no order-dependent
constructor; the mutation run (C4), which includes a mutation that introduces an
order-dependent reduction and must be caught by the thread-count test.

## References

- Salmon, J. K., Moraes, M. A., Dror, R. O., Shaw, D. E. 2011. Parallel random numbers: as easy as 1, 2, 3. Proceedings of 2011 International Conference for High Performance Computing, Networking, Storage and Analysis (SC '11). DOI: 10.1145/2063384.2063405
- Baker, A. H., et al. 2015. A new ensemble-based consistency test for the Community Earth System Model (pyCECT v1.0). Geoscientific Model Development 8. DOI: 10.5194/gmd-8-2829-2015
- Demmel, J., Nguyen, H. D. 2013. Fast Reproducible Floating-Point Summation. 2013 IEEE 21st Symposium on Computer Arithmetic. DOI: to confirm
- Arteaga, A., Fuhrer, O., Hoefler, T. 2014. Designing Bit-Reproducible Portable High-Performance Applications. 2014 IEEE 28th International Parallel and Distributed Processing Symposium. DOI: to confirm
- Higham, N. J. 1993. The Accuracy of Floating Point Summation. SIAM Journal on Scientific Computing 14(4). DOI: 10.1137/0914050
- Lorenz, E. N. 1963. Deterministic Nonperiodic Flow. Journal of the Atmospheric Sciences 20(2). DOI: 10.1175/1520-0469(1963)020<0130:DNF>2.0.CO;2
