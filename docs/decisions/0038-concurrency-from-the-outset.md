+++
id = "0038"
title = "Concurrency is designed in from the outset, and a stage is never the unit of waiting"
status = "accepted"
date = 2026-09-10
+++

## Decision

Anything that moves work through more than one kind of resource is built concurrent
from its first version, not serial with concurrency added when it proves slow. The
shape is the same wherever it appears:

1. **Name the stages by the resource they consume**, not by the order they happen in.
   Reading a scanned paper is cores (render, deskew), then the card (the model), then
   disk (write). A mesh step is host, then device, then host. Stages that consume
   different resources have no reason to wait for each other.
2. **Size each stage to its own resource.** One worker per core for a core-bound stage,
   from `$SLURM_CPUS_PER_TASK` and never `nproc`; for a device stage, as many requests
   or streams in flight as the device schedules well. The two numbers are unrelated and
   neither should be spelled `1` by default.
3. **Put a pool between the stages, not a barrier.** A stage takes the next item the
   moment it is free. It does not wait for a batch, a file, a level or a tile to finish,
   because those are units of how the work was described, not of how it executes.
4. **Bound the queue in the resource it consumes**, which is bytes for anything holding
   rendered pages, arrays or fields. A count of items is not a bound when the items
   differ by three orders of magnitude, and in this project they do: one unit of work is
   two pages of a paper and the next is a 966-page book; one is a level-3 mesh and the
   next is level-9.

The serial version still has to exist, because decision 0027 requires a naive reference
path for every optimised kernel and that path is where correctness is decided. What this
record rejects is shipping the serial version as the working one and treating concurrency
as an optimisation to be justified later.

**This does not licence order-dependent results.** Decision 0029 makes thread-count
invariance a design property: no reduction in the physics path may depend on how the work
was partitioned, and a one-thread and a sixteen-thread run are bitwise identical. The two
records divide cleanly on what the concurrency is over. Dispatching independent items to
whichever worker is free is what this record asks for; letting the order they finish in
reach a sum, a ledger or a stored field is what 0029 forbids. Where a stage both fans out
and reduces, the fan-out is free and the reduction is ordered by the partition-independent
rule, not by arrival.

## Alternatives considered

**Serial first, parallelise when measured.** The usual advice, and it is wrong here for
a specific reason: the serial structure is not a slower version of the concurrent one,
it is a different decomposition, and replacing it late means rewriting the stage
boundaries rather than tuning a constant. The OCR reader is the worked example. It was
written as one file end to end, and 84 of the 88 files in a repair pass held fewer pages
than the reader's fan-out, so the card ran four or five requests deep where it had room
for sixteen. Fixing it was not a parameter change; it was the removal of the file as the
unit of work, and it invalidated the measurement that had been taken to justify the
serial version in the first place.

**Parallelise everything.** Rejected. The rule is where more than one resource is in
play, or where a stage is embarrassingly parallel over independent items. A reduction
whose parts are genuinely dependent stays as it is, and a step that is neither is not
worth the threads.

**A fixed worker count in a configuration file.** Rejected as the default. A number
someone has to remember to raise is wrong on the next machine, and this one already
arbitrates cores centrally; the count comes from the allocation. A flag to override it
is fine, and there is one.

## Consequences

- Every stage boundary is a queue with a resource bound, so a slow stage backs pressure
  up rather than either blocking the machine or exhausting it.
- Arrival order is no longer meaningful. Work comes out as it finishes, and anything that
  needs an order has to say so and pay for it. Nothing in the tooling did. In the physics
  path the answer is always that it needs one, under decision 0029, and the order is the
  partition-independent one rather than whatever the queue produced.
- Two failure modes arrive with the design and have to be reasoned about rather than
  discovered: a consumer that waits for a full batch while holding items deadlocks
  against the queue's own bound, and an item of zero units is never completed by a loop
  that only checks completion after doing work. Both were written into the OCR reader
  and both were found by reasoning about the bound, not by a test.
- A concurrent stage cannot be a correctness argument on its own. The reference path of
  decision 0027 is what a result is checked against, and a concurrent kernel that cannot
  be reduced to it is not finished.
- Heavy work still goes through the scheduler, and the parallelism a job asks for is the
  parallelism it was allocated. Aggressive here means filling the allocation, never
  taking more than it.

## References

- Decision 0027, every optimised kernel keeps a naive reference path.
- Decision 0029, reproducibility across threads: thread-count invariance is a design
  property, and it bounds what this record permits.
- Decision 0011, GPU-first through a portable kernel layer.
- `~/.claude/CLAUDE.md`, resource scheduling: whole physical cores, `$SLURM_CPUS_PER_TASK`
  rather than `nproc`, and one share of the card per job.
- `tools/references/chandra_pages.py`, `read_files`: the worked example, with the
  deadlock and the empty-item case written out where they occur.
- `notes/findings/2026-09-10-rerank-stage-on-the-cpu.md`, for what a stage costs when it
  lands on the wrong resource.
