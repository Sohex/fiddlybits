+++
id = "0047"
title = "A kernel's own constant table is not a device move: the recorded move is for data a run carries, not for the tables a kernel is built from"
status = "accepted"
date = 2026-09-11
amends = [
  { record = "0011", what = "what an explicit, recorded move covers: a run's data crossing between devices, and not a table a kernel reads that is a function of its own shape" },
]
+++

## Decision

`Reductions.device_bitonic_network` copies `(partner, ascending)` to the card with
`array_type(backend)` rather than through `Backends.on`, so the copy produces no
`Events.Moved` record and adds nothing to the tally of decision 0046. The audit that
routed the last unrecorded host reads in `Reductions` through the recorded door found
it and asked whether it is the same kind of gap.

**It is not. A kernel's own constant table is not a device move, and it does not go
through `Backends.on`.** The recorded move of decision 0011 is a run's data changing
device: a field, a boundary array, a reduction's block sums, something a run computed
or was given and will read again. `(partner, ascending)` is none of those. It is
`bitonic_network(4^k)`, a function of `k` alone, computed at module load from the shape
of the sort and not from anything a run declares; every run at that `k` gets the same
bits; nothing reads it back to the host; and it exists only because the kernel of
decision F7 indexes its comparisons by position instead of computing them. It is part
of how the kernel is built, in the same way the kernel's compiled code is, and nobody
records a `Moved` for that.

**Three things follow from that and each of them is checkable.**

The tally would stop meaning what decision 0046 says it means. That record separates
host-to-device counts, which are staging paid once per field at the start of a run,
from device-to-host counts, which are synchronisation paid per call. A constant of `k`
staged once per process is neither: it does not scale with the run's fields and it does
not scale with its calls. Counting it puts a number in the staging column that no
declaration of the system accounts for.

The count would depend on call order. `QUANTILE_BITONIC_NETWORK_DEVICE` caches the copy
per `(array_type, k)` for the life of the process, so a recorded copy would cost the
first call of a process two records and every later call none. A per-call assertion in
`test/reductions/segment_moves.jl` would then be a statement about which test ran first,
and making it stable would mean giving the cache an eviction door it has no other reason
to have.

The door does not fit the tables. `ascending` is a `BitMatrix`, and
`Backends.backend_of` cannot name a backend for one: `KernelAbstractions.get_backend`
has no method for `BitArray` and no parent to fall back to. Routing this copy through
`Backends.on` means first changing what the table is, from a bit matrix to a `Bool`
array, to satisfy a record that was not going to be read.

**Where the line is.** A copy to a device goes through `Backends.on` and is recorded
when what crosses is data the run carries: anything derived from the system, the
profile, the mesh or a field, and anything that will be read back. A copy is outside the
recorded path when what crosses is a constant of the kernel's own shape, computed inside
this module from nothing a run declares, cached for the process and never read back.
`device_bitonic_network` names this record by path, and
`test/reductions/segment_moves.jl` asserts the rule with the control that the same bytes
handed to `Backends.on` are counted.

## Alternatives considered

- *Route the copy through `Backends.on` and state the first-call and steady-state counts
  separately.* The faithful reading of decision 0011, and the option the row was filed
  with. Lost on all three points above, and most concretely on the second: a suite whose
  move counts depend on which file ran first is a suite that will break on a reordering
  that changed nothing, and the fix for that is an eviction door on a cache whose whole
  contract is that it never evicts. The staging number it would add is two arrays per
  `(array type, k)` per process, which no reader of the tally can interpret.
- *Route it through `Backends.on` and exclude it from the tally with a flag on the call.*
  Lost on decision 0039's sibling rule for code: a door with an argument that says "do
  not count this one" is a second definition of what a move is, written as a parameter
  rather than as a rule, and every caller then has to decide. The rule belongs in one
  place, which is this record, and in the code as the absence of a call.
- *Record it and let the tests assert only the steady state.* Lost on the positive
  control. A count that is asserted only after the cache is warm cannot distinguish a
  copy that is cached from a copy that never happened, which is the thing the assertion
  is for.
- *Delete the cache so the copy happens once per call and is honestly recorded every
  time.* Lost on the cost with nothing bought: it makes a constant of `k` a per-call
  host-to-device copy of two matrices, to produce a number that scales with the call
  count in a column decision 0046 says is staging.

## Consequences

- `Reductions.device_bitonic_network` is unchanged in behaviour and names this record by
  path. `QUANTILE_BITONIC_NETWORK_DEVICE` keeps its contract, including that it never
  evicts.
- `test/reductions/segment_moves.jl` states the rule: the call that builds the copy
  records nothing, the cached call records nothing, and the positive control is that
  `Backends.on` handed the same table does record. The per-call counts for
  `segmented_quantile` through a `Segmentation` stay at zero and no longer depend on
  whether the cache was warm, because they never counted this copy and now say so.
- The line above is the test any later copy to a device is read against. A table derived
  from the mesh, from a profile or from a system is data and goes through the door; a
  table that is a function of a kernel's own shape does not.
- A stated residual: the bytes are still copied and the tally does not see them. A run
  that wants every byte that crossed the bus, rather than every move of its data, is not
  asking the tally a question it answers, and decision 0046 already says the tally is a
  count of moves and not of bytes.
- `Backends.backend_of` raises `KernelAbstractions`' own `ArgumentError` rather than a
  `Verdicts.Refusal` for a `BitMatrix`, which its docstring says it refuses. That is a
  separate defect in the backend layer and is filed as `fiddlybits-52v.7.55`.

## References

- Decision 0011 (the explicit, recorded device move), decision 0010 (the provenance
  record the move belongs to), decision 0046 (the tally, its two directions, and what
  each column means), decision 0029 (why the network exists as a table at all, through
  decision F7's rule that the sort kernel does no arithmetic on its position).
- `docs/plans/fiddlybits-52v.7-kernels.md`, section "The reductions".
- `fiddlybits-52v.7.47`, the audit of every read and write in `Reductions` that found the
  copy, and `fiddlybits-52v.7.51`, the row that carries this judgement.
- `fiddlybits-52v.7.44`, which routed the last unrecorded host reads in `Reductions`
  through the recorded move.
