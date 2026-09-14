+++
epic = "fiddlybits-52v.6"
title = "Content-addressed artifacts, the Zarr store with TOML manifests, the counter-based generator, and the inert run journal"
decisions = ["0008", "0010", "0014", "0027", "0029", "0036", "0038", "0042", "0046"]
requirements = ["REQ-TER-002", "REQ-SYS-002", "REQ-SYS-003", "REQ-SYS-103", "REQ-PROV-002", "REQ-NUM-001"]
oracles = ["provenance.key_stability", "provenance.store_refuses_incomplete", "provenance.index_roundtrip", "provenance.journal_is_inert", "provenance.event_vocabulary_closed", "repro.stochastic_identity", "provenance.pooled_write_is_reference", "provenance.write_order_independent", "provenance.write_ceiling_held"]
status = "filed"
date = 2026-09-10
+++

## Scope

This plan builds where a result goes and how it is named: the artifact key computed
from what produced it, the store that refuses an array missing any of its attributes,
the plan-without-running that makes "what does this change reach" a computed answer,
the counter-based generator keyed on physical identity, and the append-only journal of
what a run decided.

There is no derived name anywhere. A name built from parameters separates artifacts
only along the dimensions it happens to encode, and the predecessor's record has two
models whose runs collided that way. A human name is a detachable tag in a separate
table which may point at keys and may be deleted without touching data.

The purge command is in scope and the purging is not: `worthless` is a set
difference, and removing anything is a separate explicit command that prints the list
first. That is a neutral dependency property of the build, never a doctrine about
disposability.

## Module boundaries

| path | holds | row |
| --- | --- | --- |
| `src/Provenance/key.jl` | `ArtifactKey`, `CodeVersion` with its dirty flag, `RunID` | 52v.6.2, 52v.6.16 |
| `src/Provenance/store.jl` | the Zarr store, TOML manifests, the attribute refusal, the admission `put_field!` and `submit!` share | 52v.6.3, 52v.6.26 |
| `src/Provenance/writer.jl` | `Writer`, `open_writer`, `submit!`, `settle!`, `drain!` | 52v.6.26 |
| `src/Provenance/run.jl` | the run door, which opens the writer and drains it | 52v.6.17, 52v.6.27 |
| `src/Backends/pool.jl` | `BytePool`, `charge!`, `release!` | 52v.6.23 |
| `src/Backends/move.jl` | `host_buffer` and `copy_to_host!` beside `on` | 52v.6.24 |
| `src/Provenance/plan.jl` | `plan`, `worthless`, the purge command | 52v.6.4 |
| `src/Provenance/rng.jl` | the counter-based generator | 52v.6.5 |
| `src/Events/` | the closed vocabulary, the typed payloads, `emit` with its no-op sink, `moved` | 52v.6.8 |
| `src/Provenance/journal.jl` | the sink that appends to the file, the path constant, installing the sink | 52v.6.7 |
| `src/Render/export.jl` | NetCDF export with declared geometry, and nothing else | 52v.6.3 |
| `test/provenance/` | one suite per row, including `key_stability.jl` | 52v.6.2 to 52v.6.7 |
| `test/io/` | `index_roundtrip.jl`, which `docs/imports/zarr.md` names | 52v.6.3 |

`Provenance` references `Fields`, `Mesh`, `Systems`, `Time`, `Coupling` for `Ladder`,
`Events` for the sink it installs, and `Verdicts`. A file named on more than one row is
edited by those rows in their dependency order, and a row that finds work in a file
none of its dependencies names files a row rather than widening.

`Events` is a group A submodule and the plan review's one structural change. The
kernels plan, the coupling plan and the mesh plan each declared a hook of their own
for something this module fills, which was three definitions of one mechanism. Every
emitter sits below `Provenance`, so the front door is declared once and low: the ten
kinds as singleton types closed by a subtype check, a payload struct per kind, `emit`
handing to an installed sink, `moved` for the device-move record of decision 0010,
and a no-op default that is what inertness requires.

## Types and functions

### The key

```
ArtifactKey = hash(code version, declared parameter subset, declared profile subset,
                   inputs each beside its read, support id, interval,
                   operator: component, write, backend with its bitwise flag, operator version)
CodeVersion   with a dirty flag
RunID         a UUID
```

The key names every determinant of an artifact's bits that is not content of an input,
and where its two duties part (two contents never under one key, two alike makings
under one) it splits rather than merges. Decision 0010, section What the key names,
carries the argument for each part and for each determinant left out.

| part | read from | why it is in the key | control in `provenance.key_stability` |
| --- | --- | --- | --- |
| code version | `CodeVersion`: the `src` tree id, the manifest id, the Julia version, the dirty flag | the code is what computes | each moves the key; the commit alone does not |
| parameter subset | the `System` at `Declaration.system_fields` | a constant the component reads; the root seed is one (`fiddlybits-52v.4.19`) | a leaf flipped by reflection moves exactly the declaring components' keys |
| profile subset | the `Profile` at `Declaration.profile_fields`, a component's own entry of `Profile.components` by its name, never a path to `:label` | a setting the component reads: the working precision of the fast fields, a vertical ladder, a count of g-points | two fast precisions give two keys for a component declaring `(:fast_precision,)` and one key for a component that does not; a profile leaf flipped moves exactly the declaring components' keys |
| inputs | each input key, beside the declaration's `Read` of that quantity (level, operator with rule and measure, lagged, move) | a state read, and how it was reached | one input key through two operators, two measures, or lagged and not, gives two keys |
| support id | `Mesh.Support.digest` | where the output sits | two radii give two keys |
| interval | the `Time.Interval` `step!` advanced over, both bounds as IEEE bit patterns at their width | the clock every step is handed | two intervals, and two sharing their end, give two keys; one rebuilt from its bits gives one |
| operator | the component's name, `Coupling.write_of(declaration, quantity)` whole, the backend's kind and `bitwise` flag, the operator version | what made the artifact and what the array is | each moves the key; a second write on the declaration and the workgroup pin do not |

Not in the key: the commit, a locator; the thread count and the launch workgroup, which
partition independence (decision 0029) keeps from any bit; a loop's exit bracket unless
a component declares it, since every iteration writes under its own later interval and
the bracket decides only which artifact is final, a fact of the run record; the end a
`Bracketed` constant is evaluated at, which reaches the key through the disposition a
declared path reaches or through the code; the device model; the run id and the journal.

Both declared subsets come from the component's declaration, which is the coupling
layer's (`fiddlybits-52v.11.1`). `fiddlybits-52v.4.6`'s tracking makes the system paths
a measured property rather than a claim, and `fiddlybits-52v.4.20` does the same for
the profile paths. That is the whole mechanism behind "changing one field changes the
keys of exactly the artifacts whose components declared it": the key reads the
declaration, and the tracking test is what keeps the declaration honest.
`fiddlybits-52v.6.2` built the code version, the parameter subset, the input keys, the
support id and the operator's name, backend and version; `fiddlybits-52v.6.16` adds the
profile subset, the reads, the interval and the write whole.

The hash is over the IEEE bit patterns of the floats, so a key is stable across
machines and does not move when a value is printed and re-parsed.
`docs/imports/sha-uuids.md` names `test/provenance/key_stability.jl` as its leak test,
which is one of the checks the import harness reports unresolved.

**A code version with uncommitted changes may write only scratch runs, never keyed
artifacts.** That is a refusal at the store, not a warning, because a keyed artifact
from a dirty tree is a key that names nothing reproducible.

### The store

Objects under their hash with a TOML manifest naming kind, input keys, the parameter
subset with its dispositions, support id, semantics per array, ledgers, inventories,
code version and run id. Runs under their UUID with the plan they produced and the
system struct they used. Mesh geometry per level lives once under its support id and
is pointed at, never copied, by every artifact on it.

Arrays are Zarr version 2, chunked by hierarchy ranges so a chunk is a contiguous cell
range at a declared coarse level, which is the same contiguity the hierarchy numbering
gives the reductions. Every array carries its support id, semantics, time semantics,
dimension, owner and interval as attributes, **and the store refuses to open an array
missing any of them**. That refusal is the requirement REQ-TER-002 states, and it is
what stops an array from being read as something it is not.

The store also refuses a field whose ledger is open, which is the other half of the
fields plan's ledger contract.

Cell indices are 0-based on disk and 1-based in memory, translated at the disk
boundary by `CellId`. `test/io/index_roundtrip.jl` is the leak test
`docs/imports/zarr.md` names: a known index field written and read back.

NetCDF is a rendering for export only, written with the geometry declared in the file
(the radius, the cell boundaries, the weight an integrator needs), so no reader can
substitute Earth's without saying so. It lives in `Render` because it is a rendering,
and `lint_calendar` already refuses a date type reaching it.

`put_field!` writes an artifact inline. It is the reference path of the writer below,
which is how a run writes.

### The writer

`put_field!` admits a field and lands it before it returns: the move to the host, the
translation, the compression and the disk write all happen on the caller's task, one
artifact at a time. It is the reference path of decision 0027 and stays. A run writes
through the writer, which decision 0038 shapes: the admission stays on the submitting
task, and the landing crosses the card, the cores and the filesystem through stages
sized to each, with one pool bounded in bytes between them.

```
Backends.BytePool(; ceiling)            bytes a stage charges whole and releases
Backends.charge!(pool, bytes)           waits for the bytes, behind every earlier waiter
Backends.release!(pool, bytes)          returns bytes to the pool
Backends.host_buffer(backend, T, n)     host memory a device copy lands in without a host wait
Backends.copy_to_host!(host, array)     -> Handoff; the copy queued behind the kernels that wrote array
open_writer(store; run, profile)        -> Writer, its stages started
submit!(writer, run | scratch; kw...)   -> (key, stamped); put_field!'s keywords, admitted inline
settle!(writer)                         every submission so far committed, refused or discarded
drain!(writer)                          closed to submissions, settled, its stages stopped
```

**Admission is inline, and both doors run the same admission.** `write_field!` is split
into the admission and the landing. The admission is everything that needs no element
of the field's data: the placement over an interval; the `ArtifactKey` and `admit`; the
declared semantics; the origin; `ledger_records`, which refuses an open ledger by its
conserved quantity; the values form and the chunk level; the run recorded under the
code version; the support held; the key not already stored; the element type, axes and
cell count, which a device array reports without a move; and the manifest, every entry
of which is metadata. `put_field!` admits and lands inline. `submit!` admits, and then
refuses before it returns a key this writer has in flight, a submission after `drain!`
began, a submission from a task other than the one that opened the writer, and a charge
above the ceiling. An open ledger, a dirty code version, a missing support and a key
already stored are therefore refused on the submitting task, in the call that handed
over the field, exactly where `put_field!` refuses them.

**The stages, each sized to its own resource.**

| stage | resource | width | work |
| --- | --- | --- | --- |
| host copy | the card, on the stream of the task that wrote the field | that stream; there is no worker to count | at submission, once the charge is taken: `copy_to_host!` into a `host_buffer`, queued behind the kernels that wrote the field and recorded through `Events.moved`; `submit!` returns without a host wait. On `CPU` the copy is taken at the call |
| encode | cores | the tasks the default thread pool runs at once, which is the allocation the process was launched with (`-t` from `$SLURM_CPUS_PER_TASK`); nothing is declared | once the copy's handoff completes: `to_disk` on the writer's own copy, the cells cut into chunks by hierarchy range, each chunk compressed through `Zarr.zcompress` with `compressor()`, the call the reference path's array write reaches; then the copy's charge released |
| disk | the store's filesystem | `profile.store_writers` | the array metadata, each compressed chunk under the chunk key the reference path gives it, and the manifest text, written into a staging directory beside the key's place; then the compressed charge released |
| commit | one rename | none | the staging directory renamed into place, in submission order |

The copy is taken at submission, rather than a reference to the field held until
encode, because `Coupling.write_quantity!` refuses only a write into the array its
quantity held when the step began: a component may alternate two arrays, and a
reference held past its next write into the first would land the later field under the
earlier key. The queued copy's place on the stream is the snapshot, so nothing is asked
of how a component reuses its arrays. A task waiting on the handoff yields its thread
while the card finishes, so the wait between the host copy and the encode stage holds
no core.

The scheduler allocates cores and a share of the card, and not the filesystem, so the
disk stage has no allocation to take its width from. It is declared in the profile
beside `memory_ceiling`, the declared bytes of the card, with a disposition from the
same set. A disk write is a blocking call that holds the thread it runs on while the
filesystem takes it, so the encode stage's width at any moment is the allocation less
the disk tasks blocked in a write, and a timing of the writer records that load beside
it.

**One pool between the stages, bounded in bytes.** The queue from the host copy to
encode and the queue from encode to disk are unbounded in items and bounded together in
bytes: an item's bytes are held only under a charge taken from one `Backends.BytePool`
whose ceiling is `profile.write_ceiling`, a declared count of bytes with a disposition
from `Systems.DECLARED`. `BytePool` sits in `Backends` beside the memory budget, so every
stage the tree builds charges it rather than declaring a second pool. A stage takes the
next item the moment it is free; nothing waits for a step, a level, a quantity or an
artifact's siblings. An item's charge is taken whole at submission: the host copy's
bytes, and each chunk's worst-case compressed size, its bytes plus `Blosc.MAX_OVERHEAD`,
the destination size `Blosc.compress` allocates, reached through `Zarr`. The encode stage
releases the copy's part and the disk stage the compressed part. Only a submitter waits
on the pool, and no stage holds a charge while it waits for another: a charge taken in
parts, one part held while the next is waited for, is the deadlock decision 0038 names,
and a stage that only releases cannot meet it.

**When the ceiling is reached, the submitter waits.** `submit!` blocks the submitting
task until the whole charge is free and every submitter that began waiting before it
has been served, so a slow filesystem backs pressure up to the component that writes,
and a large write is never passed indefinitely by smaller ones behind it. A charge above
the ceiling could never be served, and `submit!` refuses it at once, naming both counts,
before anything is queued.

**Arrival order reaches no key, manifest or artifact.** The key and the manifest are
computed at admission, before the item enters a queue. A chunk's bytes are the
compressor's function of that chunk's cells, written under that chunk's key. The commit
renames in submission order: a staging directory is renamed into place only once every
earlier submission is committed or refused. Submission order is the order of `submit!`
calls on the one task that opened the writer, which is the run's evaluation order and
not the order the stages finish in. The stages finish in whatever order they finish;
the rename is the only step that waits, and it holds no charge. The writer keeps the
order its disk stage finished submissions in, and that record reaches nothing written:
it is what `provenance.write_order_independent` reads to show that its stages ran out of
order.

**A refusal found after `submit!` returned belongs to its submission, and `settle!`
raises it.** These are found only late: a kernel fault on the producing stream,
surfacing at the copy's handoff as `Backends.complete!` carries one; a `CellIds` entry
outside its level, which `to_disk` finds in the data; a key another process stored
between admission and rename, which `write_directory!` refuses; and a filesystem error
writing or renaming the staging directory, carried as a `Verdicts.Refusal` from the disk
stage whose reason holds the error's message. A late refusal marks its submission
refused and every later submission discarded: nothing submitted after a refused write
is committed, and the discarded staging directories are removed. The store after a
refusal therefore holds every submission before the earliest refused one, whatever
order the stages met their failures in. `settle!` waits on each submission's own state
and never on a byte count reaching zero, so a writer with no submissions settles at
once. It returns when every submission made so far is committed, refused or discarded,
and refuses naming the earliest-submitted refused write, its key and quantity, and how
many later submissions it discarded. Its caller runs it inside the run's `journalled`
wrapper, which emits the `refusal` event under that caller's header, as
`Coupling.exchange!` journals its refusals.

**A run's end drains the stages.** `drain!` closes the writer to submissions, settles,
stops the encode and disk tasks once their queues are closed and empty, and removes
every discarded staging directory. The run door (`fiddlybits-52v.6.17`) opens the writer
from the run's profile after the journal is installed, and drains it in the close it
runs whether the run was refused or not (`fiddlybits-52v.6.27`): a run unwound by a
component's refusal still commits every write submitted before that refusal, the
component's refusal is the one rethrown, and the drain's own refusal is journalled
beside it. A process killed before its drain leaves staging directories beside their
places; a read goes by the key's directory, which a staging name never is, and `purge`
lists them (`fiddlybits-52v.6.4`). The run record's move tally (`fiddlybits-52v.6.11`)
is written after the drain; every move was recorded at its submission, so the drain
does not change it.

**What callers see.** `put_field!` is unchanged, and a test or any caller holding no
writer keeps it. `submit!` takes `put_field!`'s keywords and returns the same
`(key, stamped)` at once. The stamped field names a key that is in flight until a
settle, and a read of an in-flight key refuses it as absent, which nothing in a run
meets because a run reads its own fields from the `WorldState` rather than back from
the store. `Coupling` cannot reach `Provenance` (the coupling plan, section Module
boundaries), so no component calls `submit!`: the run's driver, which steps the
components and holds the run door, submits the fields a step wrote. The pool is
`fiddlybits-52v.6.23`, the host copy `fiddlybits-52v.6.24`, the two profile settings
`fiddlybits-52v.6.25`, and the writer with its stages and commit order
`fiddlybits-52v.6.26`.

**Where `settle!` is called during a run is open.** Under every answer the stored set,
the keys and the manifests are the ones above. What the answer decides is the step at
which a run meets a late refusal, and so how much the run computes after a refused
write and under which header the journal records the refusal. The answers on the table
are: settle at the end of every step, settle at a declared cadence, and settle only at
the drain. Raising a refusal at whatever point first follows its discovery is not among
them, because it lets the order the stages finish in choose the step at which a run
stops. `fiddlybits-52v.6.20` holds the question; its answer is a decision record and the
row that calls `settle!`.

### Plan without running

```
plan(system, profile, ladder, code)    the full key set of a run, computed without running it
worthless(store, plan)                 the set difference
purge(list)                            a separate explicit command that prints first
```

Keys depend only on declared inputs, which is why the key set can be computed without
running anything. For every write the ladder schedules, `plan` enumerates each part of
the table in The key: the code version it is given; the parameter subset and the
profile subset, read from `system` and `profile` at the declaration's paths; each
input's key beside its read; the support at the declaration's level; the interval from
the step schedule; and the operator. A read of a quantity placed by an initial condition
takes the content key its initial field's `Fields.Origin` carries, and an unstamped
initial field has no key, which `plan` refuses by name. The artifacts whose keys are not in that set are the ones a change
reaches. Status is therefore a query against the store at the time of asking, and no
document or tracker cell is a source of it (REQ-SYS-008).

### The generator

A counter-based generator (Philox) keyed on the root seed, the support id, the cell
index, the process id and the time index, and never on a thread, a partition or a
traversal order. The time index is the process's own step count on its declared
cadence, never a day or an orbit number, so a configuration with no day has the same
key shape as one with a day.

`repro.stochastic_identity` is the identity: adding draws to one process cannot
advance another's stream, and changing the partition cannot change a draw. Both arms
are needed, because a generator that is merely seeded per cell passes the second and
fails the first.

### The journal

An append-only TOML journal under the run UUID. Every event has the same header,
which is the sequence number, the simulated instant in SI seconds, the tier that was
advancing, the emitting component and the kind; and a payload whose shape is fixed
per kind. A reader filters on the header without knowing any payload, and a query
written against one kind keeps working when another is added.

The vocabulary is closed at ten kinds: `verdict`, `refusal`, `ledger_open`,
`refresh`, `topology_change`, `level_change`, `artifact`, `checkpoint`, `oracle`,
`budget`. Adding a kind is a deliberate act with a test, the way the semantics and
verdict vocabularies are closed.

**It records decisions and exceptions, never the passage of time.** A ledger that
closes inside its tolerance is not an event; one that does not is. A step that
advances normally is not an event; a refresh, a level change, a topology change, a
verdict, an oracle result or a refusal is. Anything emitted once per step is a
diagnostic series, and a series belongs in the store as a field with its own support
and semantics. That rule is what keeps the journal bounded: its length scales with
the number of decisions a run took, not with its step count.

**One writer, and the lint decides it.** The front door is `Events.emit`; the one
function that appends to the file is the sink this row writes and installs, and no
component writes the file. `lint_journal_emitter` already exists and refuses any
other file naming the path constant; this row adds the constant and the sink, and the
lint then has something to protect.

**It is inert.** No component reads it, nothing branches on it, and it is in no
content key. A run with journaling switched off produces bitwise identical artifacts,
and that is `provenance.journal_is_inert`. That test is what keeps the journal from
becoming a second source of truth beside the store.

## Oracles

`provenance.journal_is_inert`, `provenance.event_vocabulary_closed` and
`repro.stochastic_identity` carry their own registry rows. The table states the others,
each registered by the row that builds it.

| id | right answer | the mutation that must make it fail |
| --- | --- | --- |
| `provenance.key_stability` | the key of one artifact is identical across machines and across a print-and-reparse of every float in the declared subsets and the interval; two intervals, two values at a declared profile path, or two reads of one input give two keys | a hash taken over printed decimal rather than IEEE bit patterns, which a round trip through text must move; the interval, or the profile subset, left out of the key, which two intervals, or two fast precisions, must expose |
| `provenance.store_refuses_incomplete` | the store refuses an array missing any of support id, semantics, time semantics, dimension, owner or interval, and refuses a field whose ledger is open | each attribute dropped in turn, every one of which must refuse; and a dirty code version writing a keyed artifact, which must refuse |
| `provenance.index_roundtrip` | a known index field written 0-based and read back 1-based is unchanged | an off-by-one at the disk boundary, which the known field must expose rather than a symmetric error hiding |
| `provenance.pooled_write_is_reference` | fields of amounts and of cell ids, in several element types and chunk levels, on `CPU` and on the card, submitted and drained into one store and put through `put_field!` into another: the two trees hold the same paths and byte-identical files | chunks compressed at another level; two chunks written under each other's chunk keys, which a comparison of decoded totals would pass; the host copy deferred to the encode stage while the component overwrites its array after submission, which lands the overwrite |
| `provenance.write_order_independent` | submissions of unequal size, so that later small ones finish before earlier large ones, drained at `store_writers` of one and of more: byte-identical trees, each equal to the reference path's; and with a rename collided and a cell id outside its level injected, exactly the submissions before the earliest refused one stored, no staging directory left, and `settle!` naming that write | the commit renaming in finish order, which stores a later submission; the manifest recording the finish order; an arm whose finish record shows no later submission finishing first fails rather than passes |
| `provenance.write_ceiling_held` | a burst of submissions whose charges sum far above the ceiling, with the disk stage behind the submitter: the pool's high water and the host buffer bytes alive never exceed `write_ceiling`; a charge above the ceiling refused at once, naming both counts | a submission that takes no charge, whose host bytes exceed the ceiling; the oversize check removed, which leaves the submitting task waiting on an idle writer |

`provenance.journal_is_inert` is the one that carries the design claim, and it is
already written to compare artifact by artifact with journaling on and off. Its arm
that the journal appears in no content key is the part a reader should look for: an
inert record that nonetheless entered a key would not be inert.

## Rows filed

| row | tier | boundary | acceptance |
| --- | --- | --- | --- |
| 52v.6.2 | sonnet | `src/Provenance/key.jl`, `test/provenance/key_stability.jl` | `provenance.key_stability` passes with its control; a dirty code version refuses a keyed artifact |
| 52v.6.3 | sonnet | `src/Provenance/store.jl`, `src/Render/export.jl`, `test/provenance/store.jl`, `test/io/` | `provenance.store_refuses_incomplete` and `provenance.index_roundtrip` pass, every attribute dropped in turn refusing; a NetCDF export carries its declared geometry |
| 52v.6.4 | sonnet | `src/Provenance/plan.jl`, `test/provenance/plan.jl` | `plan` computes a run's key set without running it and the set matches what running produces; `worthless` is the set difference; purge prints before removing anything |
| 52v.6.5 | sonnet | `src/Provenance/rng.jl`, `test/provenance/rng.jl` | `repro.stochastic_identity` passes on both arms; the generator runs inside a kernel on both backends |
| 52v.6.8 | sonnet | `src/Events/`, `test/events/`, the `Events` include in `src/Fiddlybits.jl` | the ten kinds enumerate and close with a fixture eleventh reported; a payload with a field missing refuses; `emit` with no sink is a no-op and with a fixture sink delivers one event per call |
| 52v.6.7 | sonnet | `src/Provenance/journal.jl`, `test/provenance/journal.jl` | `provenance.journal_is_inert` and `provenance.event_vocabulary_closed` pass; the sink installs into `Events` and is the only sink the tree installs; `lint_journal_emitter` now has a constant to protect and still decides |
| 52v.6.16 | sonnet | `src/Provenance/key.jl`, `test/provenance/key_stability.jl`, the `Declaration` keyword `profile_fields` in `src/Coupling/state.jl`, `Profile.components` by name in `src/Systems/profile.jl`, `holds_declaration` in `src/Systems/tracking.jl`, and the coupling and system tests those break | `provenance.key_stability` passes with an arm and a control for each of the interval, the profile subset, the component's entry by name, the reads and the write, and a break of each failing its arm |
| 52v.4.19 | frontier | `src/Systems/system.jl`, `src/Systems/strip.jl`, `test/system/`, the `declared()` fixture of `test/provenance/key_stability.jl`, the system plan's section The struct | the root seed is a required field of the system with its disposition, carried by `strip`, and moves the key of a component declaring it and of no other |
| 52v.4.20 | sonnet | `src/Systems/tracking.jl`, `declared_graph` and its profile counterpart in `src/Coupling/state.jl`, `test/system/graph.jl`, `test/coupling/state.jl` | recorded profile reads are a subset of the declared profile paths, a control reader reading an undeclared path failing; `affected` over the profile graph matches the key's profile reflection arm |
| 52v.6.23 | sonnet | `src/Backends/pool.jl` and its include, `test/backends/byte_pool.jl` | a burst of concurrent charges never holds more than the ceiling; a charge above it refuses naming both counts; a waiting large charge is served before a smaller one that began waiting after it; each control fires |
| 52v.6.24 | frontier | `src/Backends/move.jl`, `test/backends/host_copy.jl`, `docs/imports/cuda.md`, the kernels plan's section The device layer | a copy queued between two kernels writing one array holds the first kernel's values; the door leaves the preceding kernel queued; one move counted per copy; a task waiting on the handoff yields its thread; each control fires |
| 52v.6.25 | sonnet | `src/Systems/profile.jl`, the profile construction sites in `test/`, the Amendments section of decision 0014 | `write_ceiling` and `store_writers` refuse absent, below one, and outside `DECLARED`; `fast_profile` and `full_profile` require both; `provenance.key_stability` passes |
| 52v.6.26 | frontier | `src/Provenance/writer.jl`, `src/Provenance/store.jl`, `test/provenance/writer.jl`, `test/io/store_fixtures.jl`, three entries of `docs/oracles/registry.toml`, `docs/imports/zarr.md` | `provenance.pooled_write_is_reference`, `provenance.write_order_independent` and `provenance.write_ceiling_held` pass with their controls; the store's two oracles pass through `put_field!` and their admission refusals refuse at `submit!`; a collided rename and an out-of-level cell id leave exactly the earlier submissions stored |
| 52v.6.27 | sonnet | `src/Provenance/run.jl`, `test/provenance/run.jl` | a run refused after its submissions leaves them stored and rethrows the component's refusal; a refused drain is journalled; the door is the only caller of `open_writer` |
| 52v.6.6 | sonnet | none; reports only | every oracle this plan's front matter names ran; verdicts by name |

52v.6.16 depends on nothing unmerged and blocks 52v.6.4 and 52v.6.6; 52v.4.19 and
52v.4.20 depend on 52v.6.16. 52v.6.3, 52v.6.4 and 52v.6.7 depend on 52v.6.2; 52v.6.4 depends on 52v.6.3 and on the
coupling plan's `Ladder`; 52v.6.7 depends on 52v.6.8, which depends only on the
skeleton. 52v.6.23, 52v.6.24 and 52v.6.25 block 52v.6.26, which with 52v.6.17 blocks
52v.6.27; 52v.6.25 depends on 52v.4.19, whose boundary holds `test/system/` and the
`key_stability` fixture; 52v.6.21 is related to 52v.6.26, since its route lands on the
admission both doors share; 52v.6.6 depends on all five. The row that calls `settle!`
during a run is filed by 52v.6.20 once its question is answered. The area
depends on the fields plan for the ledger and on the system plan for the declared
parameter subset.
