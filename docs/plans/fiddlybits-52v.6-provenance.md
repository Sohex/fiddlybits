+++
epic = "fiddlybits-52v.6"
title = "Content-addressed artifacts, the Zarr store with TOML manifests, the counter-based generator, and the inert run journal"
decisions = ["0008", "0010", "0014", "0029", "0036", "0042"]
requirements = ["REQ-TER-002", "REQ-SYS-002", "REQ-SYS-003", "REQ-SYS-103", "REQ-PROV-002", "REQ-NUM-001"]
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
| `src/Provenance/key.jl` | `ArtifactKey`, `CodeVersion` with its dirty flag, `RunID` | 52v.6.2, 52v.6.16 |
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

Two registry entries exist, `provenance.journal_is_inert` and
`provenance.event_vocabulary_closed`, and `repro.stochastic_identity` is in the
reproducibility section. Three are added.

| id | right answer | the mutation that must make it fail |
| --- | --- | --- |
| `provenance.key_stability` | the key of one artifact is identical across machines and across a print-and-reparse of every float in the declared subsets and the interval; two intervals, two values at a declared profile path, or two reads of one input give two keys | a hash taken over printed decimal rather than IEEE bit patterns, which a round trip through text must move; the interval, or the profile subset, left out of the key, which two intervals, or two fast precisions, must expose |
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
| 52v.6.16 | sonnet | `src/Provenance/key.jl`, `test/provenance/key_stability.jl`, the `Declaration` keyword `profile_fields` in `src/Coupling/state.jl`, `Profile.components` by name in `src/Systems/profile.jl`, `holds_declaration` in `src/Systems/tracking.jl`, and the coupling and system tests those break | `provenance.key_stability` passes with an arm and a control for each of the interval, the profile subset, the component's entry by name, the reads and the write, and a break of each failing its arm |
| 52v.4.19 | frontier | `src/Systems/system.jl`, `src/Systems/strip.jl`, `test/system/`, the `declared()` fixture of `test/provenance/key_stability.jl`, the system plan's section The struct | the root seed is a required field of the system with its disposition, carried by `strip`, and moves the key of a component declaring it and of no other |
| 52v.4.20 | sonnet | `src/Systems/tracking.jl`, `declared_graph` and its profile counterpart in `src/Coupling/state.jl`, `test/system/graph.jl`, `test/coupling/state.jl` | recorded profile reads are a subset of the declared profile paths, a control reader reading an undeclared path failing; `affected` over the profile graph matches the key's profile reflection arm |
| 52v.6.6 | sonnet | none; reports only | all six oracles ran; verdicts by name |

52v.6.16 depends on nothing unmerged and blocks 52v.6.4 and 52v.6.6; 52v.4.19 and
52v.4.20 depend on 52v.6.16. 52v.6.3, 52v.6.4 and 52v.6.7 depend on 52v.6.2; 52v.6.4 depends on 52v.6.3 and on the
coupling plan's `Ladder`; 52v.6.7 depends on 52v.6.8, which depends only on the
skeleton. The area
depends on the fields plan for the ledger and on the system plan for the declared
parameter subset.
