+++
id = "0029"
title = "Reproducibility policy across threads, backends and precisions"
status = "accepted"
date = 2026-09-08
+++

## Decision

**Thread-count invariance is a design property, not a measurement.** No reduction
whose order depends on the partition: fixed-order pairwise summation with a fixed
block size for every global and per-column reduction; no atomic operations in the
physics path; no BLAS in the hot path unless single-threaded and deterministic;
partition-independent loop order for every stencil. With that, one-thread and
sixteen-thread CPU runs are bitwise identical, and so are two launches on the same
GPU. A nightly oracle runs the short coupled case at one, four and sixteen threads
and twice on the GPU, with several repeats per configuration (a stochastic property
tested by a pair is not tested; the registry states the miss rate the repeat count
can detect). Wrong: any bit differs within a configuration. The short coupled case,
the certification case and the per-commit case are registry rows that name their
`System` and `Profile`; the set includes `Earth()` and at least one synthetic
non-Earth instance with closed-form derived quantities (retrograde spin, high
eccentricity, two sources), so no discipline in this record is evidenced on one
configuration alone, and the stagnation refusal of REQ-NUM-001 is evaluated per
(`System`, `Profile`) because the forcing scale it compares against is the
configuration's instellation.

**CPU versus GPU has two modes, and the tolerance of the fast mode is measured.**
Bitwise identity across backends is not achievable in general: fused multiply-add
contraction differs, transcendental implementations differ by ulps, and a chaotic
model amplifies a one-ulp difference to order one within the predictability horizon.

- *Bitwise mode* (the debugging oracle): both backends use the same pure-Julia
  arithmetic (no fast-math, no implicit fused multiply-add, the project's own
  polynomial transcendentals where needed) and the same reduction trees. This mode is
  expected to be bitwise across backends on the short case, and a nightly test asserts
  it. A difference in this mode is a kernel bug, not roundoff.
- *Fast mode* (production): the tolerance is the **ulp-ensemble envelope**. A CPU
  ensemble of several members, each with one field perturbed by one ulp in one cell,
  measures the divergence envelope as a function of step count. The CPU-versus-GPU
  divergence must stay inside that envelope at every step. Wrong: divergence outside
  the envelope at any step, or a different growth rate. Beyond the predictability
  horizon agreement is statistical: climatological means agree within the
  autocorrelation-aware standard error, and the ledgers close identically.

**Precision is certified per kernel by the same envelope.** The working precision is
a type parameter end to end (decision 0010). A kernel is admitted to a production
profile at FP32 only when its FP32 output stays inside the ulp-ensemble envelope of
its FP64 self on the certification case. Ledgers, accumulated reservoirs (deep ocean,
soil carbon, ice volume, salt inventory) and global reductions run in FP64
accumulators or compensated summation regardless of the working precision, because a
reservoir accumulating small increments at FP32 stagnates: the increment falls below
the ulp of the stock and is silently dropped.

**Stochastic streams key on physical identity.** A counter-based generator: the value
is a pure function of (root seed, support identity, cell, process, time index), never
of thread, partition or traversal order; the time index is the process's own step
count on its declared cadence, never a day or orbit number, so a configuration with
no day has the same key shape as one with a day. Test: rerun with a different partition and
assert the stochastic fields are bitwise identical; add draws to one process and
assert no other process's stream moves.

**Every run is content-addressed.** The run identity is the hash of the parameter
set, the profile (decision 0014), the input artifact keys, the code version, the
environment manifest, the backend and the precision mode. Thread count is not in the identity because
invariance makes it irrelevant; backend and precision are, because they carry a
tolerance rather than identity. A run whose identity exists is refused unless
declared a repeat, and a repeat is expected bitwise. Run records are append-only and
never rebuilt by scanning a directory.

**Answer-changing commits are declared.** A short coupled case runs per commit and
its final state hash is a tracked reference. A commit that changes the hash must
carry a commit-message line `answers: <mechanism>` and update the reference in the
same commit; a changed hash without the line fails. This is the bit-for-bit
discipline that replaces comparison against a vendored binary.

**Benchmarks are failing tests.** Time per step per kernel, total step time at two
mesh levels, and GPU high-water memory are recorded per commit, keyed by hardware.
Before any bar is applied the A/A scatter of the bench is measured, and the bed
refuses if shorter than a declared multiple of its startup. A regression beyond the
scatter fails; a waiver is a `performance: <cause>` line in the commit message.

## Alternatives considered

- *Bitwise CPU/GPU identity as a requirement.* Rejected as unachievable in fast mode;
  achievable only in the bitwise mode, which is kept as the oracle.
- *A declared CPU/GPU tolerance.* Rejected: a chosen tolerance can be widened when a
  test fails; the ulp-ensemble envelope is measured and cannot.
- *FP32 everywhere for throughput.* Rejected by the stagnation argument for
  reservoirs; FP32 is a certified per-kernel option, never a global switch.
- *Thread count in the run identity.* Rejected: it would admit thread-dependent
  answers as different runs rather than as defects.

## Consequences

- The reduction primitives are written once, in the kernel library, and every
  component uses them; a hand-written reduction in physics code is a lint failure.
- The certification case, the ensemble size and the miss rates are registry entries
  with a registration commit.
- The per-commit case, its reference hash and the `answers:` check exist from the
  first coupled column onward.
- The design forgoes some GPU library routines whose reduction order is not
  deterministic; where one is used it is wrapped with a deterministic alternative
  for the bitwise mode.

## References

- Predecessor records of thread-dependent answers and of single-precision
  stagnation: `/home/cfutro/docs/world/notes/audits/model-reproducibility.md`,
  `/home/cfutro/docs/world/notes/audits/single-precision-spin-up.md`,
  `/home/cfutro/docs/world/notes/audits/run-identity.md`,
  `/home/cfutro/docs/world/lib/stochastic_seeds.py`.
- Salmon, J. K., M. A. Moraes, R. O. Dror, and D. E. Shaw. "Parallel random numbers:
  as easy as 1, 2, 3." Proceedings of 2011 International Conference for High
  Performance Computing, Networking, Storage and Analysis (2011).
  DOI: 10.1145/2063384.2063405.
- Higham, N. J. "The accuracy of floating point summation." SIAM Journal on
  Scientific Computing 14 (1993). DOI: 10.1137/0914050.
- Kahan, W. "Pracniques: further remarks on reducing truncation errors."
  Communications of the ACM 8 (1965). DOI: 10.1145/363707.363723.

## Amendments

- 2026-09-08: the profile is named in the run identity; the short coupled, certification and per-commit cases are registry rows naming their System and Profile and include a synthetic non-Earth instance; the RNG time index is the process's own step count, from notes/findings/2026-09-08-implicit-earth-audit.md.
- 2026-09-13: the archive this record cites now resolves at /home/cfutro/git/vesper; /home/cfutro/docs/world no longer exists on disk, from notes/findings/2026-09-13-predecessor-archive-relocated-to-vesper.md.
