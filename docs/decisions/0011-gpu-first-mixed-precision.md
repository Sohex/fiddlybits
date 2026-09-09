+++
id = "0011"
title = "GPU-first through a portable kernel layer, CPU backend for sequential algorithms, and mixed precision by declaration"
status = "accepted"
date = 2026-09-08
+++

## Decision

Every physics kernel is written once against a portable kernel abstraction and runs on
the GPU backend in production and on the CPU backend as the fallback, the debugging
path and the host for algorithms that are sequential by nature. A component declares
its device. Structs passed to kernels are adapted for the device; the stripped
constants of decision 0007 are isbits. Arrays are laid out cells-first so that
consecutive threads touch consecutive addresses, with the vertical loop inside the
thread. Column physics is fused into few kernels per step, because at the column
counts a coupled global run uses, the atmosphere is bound by kernel launches rather
than by arithmetic.

Algorithms that are sequential or sparse (depression-hierarchy construction, the
box-constrained water-table solve, plate bookkeeping in the tectonic seed) run on the
CPU backend across the available cores with the same field types. The store moves a
field between devices explicitly and records the move.

### Mixed precision by declaration

The floating-point type is a type parameter end to end, so the same code runs at
single or double precision without a flag. Consumer graphics hardware runs double
precision at a small fraction of single-precision throughput, so production
profiles on such hardware run the fast prognostic fields and their kernels in
single precision. Independently of the profile's type:

- every ledger, every global reduction, and every accumulated reservoir (deep ocean
  heat and salt, soil carbon, ice volume, the salt inventory, the carbon balance)
  is held and accumulated in double precision or by compensated summation;
- a single-precision kernel enters a production profile only after it is certified
  by the ulp-ensemble test of decision 0029 against its own double-precision run;
- the double-precision instance of the same code is the reference and runs
  unchanged on hardware with real double-precision throughput.

A memory budget per profile is computed from the field registry at the profile's
levels, and the run refuses to start if its high-water estimate exceeds the
profile's declared ceiling. The ceiling is declared against the whole card; a
per-profile fraction is a data change if the shared scheduler needs one.

## Alternatives considered

- **CPU-first, GPU later.** Keeps the predecessor's cost regime, which put a
  commissioning at hours and each finer level at several times that. Lost; the
  reduction structure of decision 0005 exists to make the GPU natural.
- **A single precision for the whole model, chosen per build.** The predecessor's
  record has a precision set by a mis-parsed flag that built every production binary
  in single precision, and a stagnation analysis showing that a deep-ocean layer
  makes single precision unsound at once. Lost; precision is a type parameter, and
  reservoirs are never single.
- **Double precision everywhere on consumer hardware.** Correct and slow by a large
  factor. Lost as the default, kept as the reference instance and as the default on
  hardware that supports it.
- **Vendor-specific GPU code.** Lost to the portable layer, whose CPU backend is the
  fallback and the debug path.

## Consequences

- No atomics in the physics path, fixed-order reductions, and partition-independent
  loop order (decision 0029), so thread count cannot change an answer.
- Every optimised kernel keeps a naive serial reference path (decision 0027).
- Oracles implied: elementwise operations bitwise identical between backends in the
  bitwise debug mode; every single-precision production kernel inside its measured
  ulp envelope; no reservoir field of single type in any profile; the memory
  high-water of the short coupled case below the profile's ceiling; a benchmark
  regression beyond the measured A/A scatter fails.

## References

- The predecessor's audits on compiled precision and single-precision spin-up:
  `/home/cfutro/docs/world/notes/audits/compiled-precision.md`,
  `/home/cfutro/docs/world/notes/audits/single-precision-spin-up.md`.
- The predecessor's working-set target and the argument for it:
  `/home/cfutro/docs/world/docs/src/reference/environment.md`.
- Kahan, W. "Pracniques: further remarks on reducing truncation errors."
  Communications of the ACM 8 (1965). DOI: 10.1145/363707.363723
