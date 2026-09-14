+++
id = "0010"
title = "Content-addressed artifacts, runs as UUIDs, one chunked store format, and the index base at each boundary"
status = "accepted"
date = 2026-09-08
+++

## Decision

Every artifact the system produces is addressed by the hash of what produced it: the
code version; the subset of the system struct the producing component declared it
depends on (decision 0007); the subset of the profile it declared it depends on
(decision 0014); the keys of its inputs, each beside the read that took it; the support
identity (decision 0005); the interval the component advanced over (decision 0008);
and the operator that made it, which is the component, the write, the backend with its
bitwise flag (decision 0029), and the version of the operator. A run is a UUID; a human name
is a detachable tag in a separate table that may point at keys and may be deleted
without touching data. There is no derived name anywhere: a name built from
parameters separates artifacts only along the dimensions it happens to encode, and
the predecessor's record has two models whose runs collided that way.

"What depends on this change" is a computed answer. `plan(system, profile, ladder, code)`
computes the full key set of a run without running anything, because keys depend
only on declared inputs; the artifacts in the store whose keys are not in that set
are the ones the change reaches. Purging them is a separate, explicit command that
prints the list. This is a neutral dependency property of the build, not a doctrine
about disposability.

### What the key names

The key names every determinant of an artifact's bits that is not content of an input.
It has two duties, and a key computed without running cannot always meet both: two
artifacts that differ in content never share a key, and two artifacts made alike share
one. Where the two part, the key splits rather than merges, because a split costs a
recomputation and a merge is a wrong answer read under a right name.

- **The interval.** Every step advances over an explicit `Interval` (decision 0008), so
  the interval is a field of every key, both bounds, each as its IEEE bit pattern at its
  width. A component whose output depends on its interval and on no state it reads, an
  instellation, has nothing else that tells two of its steps apart. The step's interval
  is hashed rather than the output's own placement on the clock: an instantaneous output
  at the end of a step taken from a declared start differs in its bits between two
  starts and agrees in its placement. An output with no time axis written on every step
  is therefore keyed per step, which is the split rule applied.
- **The profile subset.** A component declares the profile paths its output depends on,
  and the key reads the profile at those paths exactly as it reads the system at the
  parameter subset. The working precision of the fast fields, a vertical ladder, a count
  of g-points and a slow-tier acceleration are in a key when and only when its component
  declared them, so changing one profile setting moves exactly the keys of the
  components that declared it. The precision of the constants reaches the key through
  the width of every float of either subset. A component's own entry among the profile's
  components is reached by its name. The profile's label is a name, and a path to it is
  refused.
- **Each input's read.** Beside each input key the key hashes the read that took it: the
  level, the operator with its rule and measure, whether it is lagged, whether it moves.
  One input coarsened under two measures gives two outputs from one input key.
- **The write.** The write is hashed whole: its quantity, its semantics and the
  conserved quantities it carries, because the semantics is part of what the stored
  array is (decision 0006).
- **The root seed** is a field of the system (section Stochastic streams), so a
  stochastic output reaches its seed through the parameter subset of the component that
  draws; the process id is that component's code, and the time index follows from its
  interval.

The key does not name the following, each because it cannot move a bit or because a
named part already reaches it:

- the commit, which is a locator: two commits with one source tree and one manifest are
  one code version;
- the thread count and the launch workgroup, because every reduction is
  partition-independent (decision 0029);
- a loop's exit bracket, unless a component declares it: each iteration of a loop
  reaches a later instant than the one before and writes under its own interval, so the
  bracket decides how many artifacts a loop writes and which of them is final, which is
  a fact of the run record, and changes no artifact's bits;
- the end of a bracket a `Bracketed` constant is evaluated at: a declared path that
  reaches a disposition reaches its value and both ends, a sweep member evaluated at an
  end is a system whose value is that end, and an end the code chooses is in the code
  version; nothing outside the system and the profile selects an end;
- the device model: decision 0029 expects bitwise identity across devices in bitwise
  mode and bounds fast mode by its measured envelope, and a repeat is expected bitwise
  on the same backend only;
- the run id, and the run journal, which is inert (decision 0042).

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

Random draws come from a counter-based generator keyed on the root seed, which is a
field of the system, the support id, the cell index, the process id and the time
index, and never on a thread, a
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
- **The interval as a declared dependency**, named only by the components that say they
  read the clock. It keeps the key of an output with no time axis across steps, and
  loses: every step is handed its interval, so a declaration left out is a merge that
  nothing at the key can see.
- **The interval as an input key**, the clock treated as an artifact. Lost: it mints
  keys for things the store does not hold, and a plan would enumerate artifacts that do
  not exist.
- **The output's placement on the clock in place of the step's interval.** Lost on the
  instantaneous output taken from two declared starts.
- **The chain of lagged input keys alone.** It tells apart the steps of a component that
  reads its own previous state, and nothing else: a first step, and every output that
  depends on its interval alone, would collide.
- **The whole profile in every key.** It never merges, and loses: a memory ceiling or a
  label edited moves every key, "what does this change reach" answers everything for
  any profile edit, and a label in a key is a derived name.
- **The working precision as a field of every key.** It never merges on precision, and
  loses to the declared path: it splits every slow and reservoir artifact between two
  profiles that differ only in the precision of the fast fields, and it hard-wires one
  profile field where precision is declared per field class and per kernel (REQ-NUM-001,
  item 1), which a declared path carries with no change to the key.
- **A precision per write on the declaration.** It states each element type exactly,
  and loses because the profile is the one definition of the fast precision (decision
  0014) and a copy on every write is a second definition that nothing reconciles with
  it.
- **The exit bracket in the key of a loop's writes.** Lost: two profiles that stop one
  loop at different iterations write bitwise identical artifacts up to the earlier stop,
  and would key them apart.
- **The root seed as a field of every key, or as a profile setting.** A field of every
  key splits every deterministic artifact across the members of a seed ensemble. A
  profile setting puts a realisation among the resolutions a profile names, so fast
  against full on one system (decision 0014) would compare two seeds. Lost to a field
  of the system, which is what a sweep member already is.

## Consequences

- A run is reproducible from its UUID: the system struct, the code version, the
  profile and every input key are in its record.
- A repeat of a run with the same identity is expected to be bitwise identical on the
  same backend (decision 0029).
- The profile subset is measured as the parameter subset is: a tracked run records every
  profile read, and a read no declared path covers fails, which is what catches a
  component computing at the fast precision without declaring it.
- Oracles implied: flipping any field of the system struct by reflection changes the
  key of at least one artifact and of exactly the artifacts whose components declared
  that field, and flipping any field of the profile changes exactly the keys of the
  artifacts whose components declared it; two intervals, and one input read through two
  operators, give two keys from identical inputs; the profile paths a component reads
  are a subset of those it declares; a manifest is regenerated from its object and
  matches; a checkpoint round-trips bitwise; a reseeded run under a different partition produces bitwise
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
- Precision declared per field class and per kernel, and named in the artifact key:
  `docs/requirements/num/precision-is-a-type-parameter.md` (REQ-NUM-001), items 1 and 7.

## Amendments

- 2026-09-13: the key names the interval a component advanced over, the profile subset its component declares (the working precision of the fast fields among them, a component's own profile entry reached by its name, the label refused), each input's read beside its key, and the write whole; the root seed is a field of the system and reaches a key through the parameter subset; the commit, the thread count and workgroup, a loop's exit bracket, a bracket end, the device model and the journal are placed outside the key, each with its argument; `plan` takes the profile. From fiddlybits-52v.6.15; carried by fiddlybits-52v.6.16 (the key), fiddlybits-52v.4.19 (the root seed) and fiddlybits-52v.4.20 (the profile reads measured).
- 2026-09-13: the interval a component advanced over reaches the store as a required `interval` keyword of `put_field!` and `submit!`, the key's interval for every field and refused where it is not identical to an interval-placed field's own; the sentence on instantaneous outputs and on outputs with no time axis is carried at the store by that route, which replaces the refusal of a `Static` or `Instantaneous` field. From fiddlybits-52v.6.21 (docs/plans/fiddlybits-52v.6-provenance.md, section The store); carried by fiddlybits-52v.6.29.
