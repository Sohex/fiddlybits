+++
epic = "fiddlybits-52v.6"
title = "Content-addressed artifacts, the Zarr store with TOML manifests, the counter-based generator, and the inert run journal"
decisions = ["0010", "0029", "0036", "0042"]
requirements = ["REQ-TER-002", "REQ-SYS-002", "REQ-SYS-003", "REQ-SYS-103"]
oracles = ["provenance.key_stability", "provenance.store_refuses_incomplete", "provenance.index_roundtrip", "provenance.journal_is_inert", "provenance.event_vocabulary_closed", "repro.stochastic_identity"]
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
| `src/Provenance/key.jl` | `ArtifactKey`, `CodeVersion` with its dirty flag, `RunID` | 52v.6.2 |
| `src/Provenance/store.jl` | the Zarr store, TOML manifests, the attribute refusal | 52v.6.3 |
| `src/Provenance/plan.jl` | `plan`, `worthless`, the purge command | 52v.6.4 |
| `src/Provenance/rng.jl` | the counter-based generator | 52v.6.5 |
| `src/Events/` | the closed vocabulary, the typed payloads, `emit` with its no-op sink, `moved` | 52v.6.8 |
| `src/Provenance/journal.jl` | the sink that appends to the file, the path constant, installing the sink | 52v.6.7 |
| `src/Render/export.jl` | NetCDF export with declared geometry, and nothing else | 52v.6.3 |
| `test/provenance/` | one suite per row, including `key_stability.jl` | 52v.6.2 to 52v.6.7 |
| `test/io/` | `index_roundtrip.jl`, which `docs/imports/zarr.md` names | 52v.6.3 |

`Provenance` references `Fields`, `Mesh`, `Systems`, `Time`, `Coupling` for `Ladder`,
`Events` for the sink it installs, and `Verdicts`. Five rows write into
`src/Provenance/`, so every file is named on exactly one row and a row that finds work
in another's file files a row rather than widening.

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
ArtifactKey = hash(code version, declared parameter subset, input keys, support id, operator version)
CodeVersion   with a dirty flag
RunID         a UUID
```

The declared parameter subset comes from the component's declaration, which is the
coupling layer's (`fiddlybits-52v.11.1`), and which `fiddlybits-52v.4.6`'s tracking
makes a measured property rather than a claim. That is the whole
mechanism behind "changing one field changes the keys of exactly the artifacts whose
components declared it": the key reads the declaration, and the tracking test is what
keeps the declaration honest.

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

### Plan without running

```
plan(system, ladder, code)    the full key set of a run, computed without running it
worthless(store, plan)        the set difference
purge(list)                   a separate explicit command that prints first
```

Keys depend only on declared inputs, which is why the key set can be computed without
running anything. The artifacts whose keys are not in that set are the ones a change
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

Two registry entries exist, `provenance.journal_is_inert` and
`provenance.event_vocabulary_closed`, and `repro.stochastic_identity` is in the
reproducibility section. Three are added.

| id | right answer | the mutation that must make it fail |
| --- | --- | --- |
| `provenance.key_stability` | the key of one artifact is identical across machines and across a print-and-reparse of every float in the parameter subset | a hash taken over printed decimal rather than IEEE bit patterns, which a round trip through text must move |
| `provenance.store_refuses_incomplete` | the store refuses an array missing any of support id, semantics, time semantics, dimension, owner or interval, and refuses a field whose ledger is open | each attribute dropped in turn, every one of which must refuse; and a dirty code version writing a keyed artifact, which must refuse |
| `provenance.index_roundtrip` | a known index field written 0-based and read back 1-based is unchanged | an off-by-one at the disk boundary, which the known field must expose rather than a symmetric error hiding |

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
| 52v.6.6 | sonnet | none; reports only | all six oracles ran; verdicts by name |

52v.6.3, 52v.6.4 and 52v.6.7 depend on 52v.6.2; 52v.6.4 depends on 52v.6.3 and on the
coupling plan's `Ladder`; 52v.6.7 depends on 52v.6.8, which depends only on the
skeleton. The area
depends on the fields plan for the ledger and on the system plan for the declared
parameter subset.
