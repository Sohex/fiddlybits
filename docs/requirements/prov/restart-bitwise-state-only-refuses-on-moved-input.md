+++
id = "REQ-PROV-001"
title = "A restart is bitwise, carries only state, and refuses if any input hash moved"
old_path = ["/home/cfutro/git/vesper/notes/audits/absent-restart-records.md", "/home/cfutro/git/vesper/notes/audits/ecological-stream-restart-continuity.md", "/home/cfutro/git/vesper/notes/audits/zsolars-restart-overread.md"]
old_commit = "6aa93489d233d4e9d531d6479d338c643e34bc5e"
status = "carried"
+++

## What is true

Measured on the predecessor's spectral GCM. Per-call reproducibility (the same
bytes twice from one checkpoint) held while segment continuity (N steps as one call
equal to k plus N-k as two) failed from the first post-restart step: 1.19 K in
near-surface air temperature and 1341 Pa in surface pressure at that step, 60 of 222
state records differing after 24 steps as 12 plus 12. The cause was one
initialisation routine that overwrote the leapfrog t-dt level with the current
level on the restart path, guarded on a cold start elsewhere and not there. It was
never a property of any tree: the same round trip on the main branch 238 commits
earlier lost the same record. The instrument that named it was a round trip with
zero steps (checkpoint, load, integrate nothing, checkpoint), in which every record
that differs is state the checkpoint does not carry. With the guard, a run split
at any point was bitwise identical to the whole run in every record. Every
climatology and forcing block assembled from more than one call before the guard
was a different experiment from the one it was taken to be. A cold start with no
declared seed drew from the clock.

A record a checkpoint might not carry had two classes. The silent one: a reader
scattered its unfilled buffer over the caller's array whichever way the lookup went,
so a sentinel written to decide a rebuild was destroyed and the rebuild test was
decided on stack contents. The verdict per record turned on what an absent record
costs: an accumulator over an output window costs one partial window and may be
optional; a prognostic costs state the cell integrates from, unbounded and
invisible, and is required, with a loud stop naming the record. The one prognostic
clock in the state (a snow-persistence counter that turns a cell into glacier) was
the whole of the argument: a run whose clock restarts at zero looks exactly like a
run whose glaciers form late. The checkpoint format's record limit was below the
record count, so the second segment refused after the first had written a file that
looked complete.

A two-element global pair was written through a gather sized for a distributed
field, so the checkpoint record held 8192 values of which 8190 were buffer
contents; nothing read the record back, the integration was untouched, and the
checkpoint's content hash was stable only because a compiler flag zeroed the buffer,
which a link-time flag then stopped doing (five runs, five hashes, one binary).
The write was a configuration fingerprint living in the state file; nine other
writes at initialisation went to a unit nothing had opened. The checkpoint carried
its grid dimensions and no reader compared them.

## Why it carries

Long coupled loops in this system run in segments across profiles and hardware
(B9), and asynchronous terrain coupling with warm climate refreshes makes
checkpoint-and-continue the normal mode rather than an exception. Artifacts are
content-addressed (A6), so a checkpoint's identity is its bytes: a checkpoint that
carries anything but state, or whose bytes depend on anything but state, has no
stable identity, and a segment boundary that perturbs the trajectory makes every
downstream climatology an experiment nobody designed. The absent-record verdict
(a prognostic is never defaulted) is design idea 13, refuse rather than backfill,
applied to state.

## What this system must do

1. A checkpoint is the `WorldState`'s prognostic state plus the loop's own state
   (the SI time, the exit-predicate accumulators of A5) and nothing else: no
   diagnostics, no configuration copy, no derived field (recomputed from `System` at
   load), no accumulator unless it is declared prognostic. Accumulated diagnostics
   live in the store as separate arrays with their `Interval`.
2. Segment continuity is bitwise: N steps as one call equal k plus N-k as two in
   every state array, at every level, on both backends in debug mode; and the
   zero-step round trip is byte-identical. Both run per commit on the short coupled
   case with the production profile's diagnostics on.
3. Every array in a checkpoint is self-describing (name, support id, semantics,
   time semantics, dimension, owner, interval, `FT`) and the store refuses an array
   missing any (A6). Shape lives in the array, so a reader cannot over-run or
   under-run a record.
4. Load refuses by name. A missing prognostic array is a refusal; there is no
   default, no sentinel and no optional prognostic. The checkpoint key includes the
   hash of `System`, the `Profile`, the code version and every input artifact key;
   loading under any moved hash refuses and names the hash. Continuing deliberately
   across a change is a declared state-conversion operator returning a ledger, under
   a new run id.
5. A run containing any stochastic process refuses to start without a declared
   root seed (REQ-NUM-002).
6. A checkpoint on the wrong support is a type error (A2).

## Enforced by

The per-commit continuity and round-trip tests; the store's attribute-schema
refusal; the checkpoint-key composition test; a keyword-only loader with no
defaults; decision records A5, A6 and C6.

## References

- Baker, A. H., et al. 2015. A new ensemble-based consistency test for the Community Earth System Model (pyCECT v1.0). Geoscientific Model Development 8. DOI: 10.5194/gmd-8-2829-2015
- Secure Hash Standard (SHS). FIPS PUB 180-4. DOI: 10.6028/NIST.FIPS.180-4
- Zarr core specification, version 3. Locator: https://zarr-specs.readthedocs.io/en/latest/v3/core/index.html
