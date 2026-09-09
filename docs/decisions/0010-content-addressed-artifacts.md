+++
id = "0010"
title = "Content-addressed artifacts, runs as UUIDs, one chunked store format, and the index base at each boundary"
status = "accepted"
date = 2026-09-08
+++

## Decision

Every artifact the system produces is addressed by the hash of what produced it: the
code version, the subset of the system struct the producing component declared it
depends on (decision 0007), the keys of its inputs, the support identity (decision
0005), and the version of the operator that made it. A run is a UUID; a human name
is a detachable tag in a separate table that may point at keys and may be deleted
without touching data. There is no derived name anywhere: a name built from
parameters separates artifacts only along the dimensions it happens to encode, and
the predecessor's record has two models whose runs collided that way.

"What depends on this change" is a computed answer. `plan(system, ladder, code)`
computes the full key set of a run without running anything, because keys depend
only on declared inputs; the artifacts in the store whose keys are not in that set
are the ones the change reaches. Purging them is a separate, explicit command that
prints the list. This is a neutral dependency property of the build, not a doctrine
about disposability.

### Store layout and format

Objects live under their hash with a manifest (kind, input keys, the parameter
subset with dispositions, support id, semantics per array, ledgers, inventories,
code version, run id). Runs live under their UUID with the plan they produced and the
system struct they used. Mesh geometry per level lives once under its support id and
is pointed at, never copied, by every artifact on it.

Arrays are stored in a chunked, compressed, language-neutral container (Zarr, version
2 until the Julia implementation's version 3 path is complete), chunked by hierarchy
ranges so that a chunk is a contiguous cell range at a declared coarse level. Every
array carries its support id, semantics, time semantics, dimension, owner and
interval as attributes, and the store refuses to open an array missing any of them.
NetCDF is a rendering for export to conventional tools only, written with the
geometry declared in the file (the sphere's radius, the cell boundaries, the weight
an integrator needs), so no reader can substitute Earth's without saying so.

A code version with uncommitted changes may write only scratch runs, never keyed
artifacts.

### Stochastic streams

Random draws come from a counter-based generator keyed on the root seed, the support
id, the cell index, the process id and the time index, and never on a thread, a
partition or a traversal order. Adding draws to one process cannot advance another's
stream; changing the thread count cannot change a draw.

### The index base

Cell indices are 0-based on disk and in the conceptual hierarchy (the Zarr container
and every Python reader are 0-based, and the container's Julia implementation
translates at the disk boundary), and natively 1-based in memory and in kernels,
because the kernel abstraction layer, the GPU array library and broadcasting are
1-based, and forcing 0-based indexing into kernels invites silent bounds failures and
breaks library calls. The parent-child relation is just as cheap 1-based:
`parent(i) = (i + 3) >> 2` and `children(i) = 4i - 3 : 4i`. A `CellId` type that
refuses arithmetic carries an index across the host boundary, so a mixed-base bug is
a type error rather than an off-by-one.

## Alternatives considered

- **Derived run names** (the predecessor's first practice). Lost on the recorded
  collisions.
- **A run index rebuilt by scanning a directory.** The predecessor lost the identity
  of forty cited runs that way. Lost; run records are an append-only ledger.
- **NetCDF as the primary store.** Conventional tools assume an Earth sphere, an
  Earth calendar and an unweighted mean over rows; the predecessor recorded the three
  traps. Lost as primary, kept as export with a declared geometry.
- **0-based indices in kernels** (an earlier draft of this decision). Reviewed and
  rejected on the friction with the 1-based ecosystem; the bit-shift argument for
  0-based holds only for the shift form and the 1-based form is one addition more.
- **Stochastic streams seeded per thread or per rank.** The predecessor's record has
  the reproducibility failure. Lost.

## Consequences

- A run is reproducible from its UUID: the system struct, the code version, the
  profile and every input key are in its record.
- A repeat of a run with the same identity is expected to be bitwise identical on the
  same backend (decision 0029).
- Oracles implied: flipping any field of the system struct by reflection changes the
  key of at least one artifact and of exactly the artifacts whose components declared
  that field; a manifest is regenerated from its object and matches; a checkpoint
  round-trips bitwise; a reseeded run under a different partition produces bitwise
  identical stochastic fields; a `CellId` cannot be added to an integer.

## References

- The predecessor's audits on run identity, executable provenance and the build
  driver: `/home/cfutro/docs/world/notes/audits/run-identity.md`,
  `/home/cfutro/docs/world/notes/audits/executable-provenance-at-the-consumer.md`,
  `/home/cfutro/docs/world/notes/audits/model-build-driver.md`.
- The predecessor's declared-geometry reader for NetCDF and the three Earth traps:
  `/home/cfutro/docs/world/lib/nc_geometry.py`,
  `/home/cfutro/docs/world/docs/src/reference/environment.md`.
- The predecessor's stochastic substream derivation:
  `/home/cfutro/docs/world/lib/stochastic_seeds.py`.
- Salmon, J. K., Moraes, M. A., Dror, R. O., Shaw, D. E. "Parallel random numbers:
  as easy as 1, 2, 3." Proceedings of 2011 International Conference for High
  Performance Computing, Networking, Storage and Analysis (2011).
  DOI: 10.1145/2063384.2063405
