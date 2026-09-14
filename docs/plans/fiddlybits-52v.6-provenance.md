+++
epic = "fiddlybits-52v.6"
title = "Content-addressed artifacts, the Zarr store with TOML manifests, the counter-based generator, and the inert run journal"
decisions = ["0005", "0006", "0008", "0010", "0014", "0027", "0029", "0036", "0038", "0042", "0046"]
requirements = ["REQ-TER-002", "REQ-TER-010", "REQ-TER-011", "REQ-SYS-002", "REQ-SYS-003", "REQ-SYS-103", "REQ-PROV-002", "REQ-NUM-001"]
oracles = ["provenance.key_stability", "provenance.store_refuses_incomplete", "provenance.index_roundtrip", "provenance.support_geometry_held", "provenance.journal_is_inert", "provenance.event_vocabulary_closed", "repro.stochastic_identity", "provenance.pooled_write_is_reference", "provenance.write_order_independent", "provenance.write_ceiling_held"]
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
| `src/Provenance/store.jl` | the Zarr store, TOML manifests, the attribute refusal, the admission `put_field!` and `submit!` share, the `interval` keyword, `SUPPORT_ARRAYS`, `read_geometry`, `ElementIds`, `elements_per_chunk`, the `location` attribute | 52v.6.3, 52v.6.29, 52v.6.26, 52v.3.26, 52v.6.35 |
| `src/Provenance/writer.jl` | `Writer`, `open_writer`, `submit!`, `settle!`, `drain!` | 52v.6.26 |
| `src/Provenance/run.jl` | the run door, which empties the move tally and closes with it, opens the writer, settles it at the declared cadence and drains it | 52v.6.17, 52v.6.11, 52v.6.27, 52v.6.31 |
| `src/Backends/pool.jl` | `BytePool`, `charge!`, `release!` | 52v.6.23 |
| `src/Backends/move.jl` | `host_buffer` and `copy_to_host!` beside `on` | 52v.6.24 |
| `src/Provenance/plan.jl` | `plan`, `worthless`, the purge command | 52v.6.4 |
| `src/Provenance/rng.jl` | the counter-based generator | 52v.6.5 |
| `src/Events/` | the closed vocabulary, the typed payloads, `emit` with its no-op sink, `moved` | 52v.6.8 |
| `src/Provenance/journal.jl` | the sink that appends to the file, the path constant, installing the sink | 52v.6.7 |
| `src/Render/export.jl` | NetCDF export with declared geometry, the mesh topology variable and `UGRID_LOCATION`, and nothing else | 52v.6.3, 52v.6.36 |
| `test/provenance/` | one suite per row, including `key_stability.jl` and `support_geometry.jl` | 52v.6.2 to 52v.6.7, 52v.6.35 |
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

Arrays are Zarr version 2, chunked along their first axis so a chunk of a cell array is
a contiguous cell range at a declared coarse level, which is the same contiguity the
hierarchy numbering gives the reductions, and a chunk of a vertex or edge array is a
contiguous index range of the count given below. Every array carries its support id,
semantics, time semantics, dimension, owner, interval and location as attributes, **and
the store refuses to open an array missing any of them**. That refusal is the
requirement REQ-TER-002 states, and it is what stops an array from being read as
something it is not.

The store also refuses a field whose ledger is open, which is the other half of the
fields plan's ledger contract.

`Provenance.record_value` holds a `UInt64` (the root seed among them) as a `UInt64`,
never converted to `Int64`: `TOML.print` writes an unsigned integer as an unsigned
hexadecimal literal and `TOML.parse` reads that literal back as a `UInt64`, a form no
decimal `Int64` literal can take, so the two types never collide in one manifest or run
record. An integer of at most 32 bits, signed or unsigned, still becomes an `Int64`,
which holds every such value without loss; only `UInt64` needs its own form, because it
is the one width whose range exceeds `Int64`'s.

Indices of cells, vertices and edges are 0-based on disk and 1-based in memory,
translated at the disk boundary through `Mesh.disk_id` and `Mesh.memory_index`, the
doors of `CellId`. `ElementIds(; location, level)` is the values form of an array whose
entries index one location's elements at one level, refused outside
`1:Mesh.element_count(location, level)`; it replaces `CellIds`, which was that form at
cells. `test/io/index_roundtrip.jl` is the leak test `docs/imports/zarr.md` names: known
fields of cell, vertex and edge ids written and read back.

**A support holds its geometry and its topology once, under its support id.**
`put_support!(store; support, level, chunk_level)` builds `Mesh.stencils(level)` and
`Mesh.geometry(level, stencils)` through the one constructor of each, refuses a level
whose coordinates, or whose measures at the support's radius, are not the ones the
support's digests cover, and holds every array of the table below under
`supports/<digest>/<name>/`. The caller hands in the level and nothing else that reaches
an array, so the arrays under a support id are what the mesh constructors give for the
coordinates that id covers. The table is `Provenance.SUPPORT_ARRAYS`, the one list of what
a support entry holds; `read_geometry(store; support, name, backend)` reads any array of
it and refuses a name the table does not hold, and `read_cell_area` goes, its callers
reading `cell_area` through it.

| name | location | element type | axes | semantics | dimension | values | from |
| --- | --- | --- | --- | --- | --- | --- | --- |
| `cell_area` | `Cells` | `Float64` | cells | `Extensive` | length squared | amounts | `geometry.cell_area` through `Mesh.at_radius`, power two |
| `dual_area` | `Vertices` | `Float64` | vertices | `Extensive` | length squared | amounts | `geometry.dual_area` through `Mesh.at_radius`, power two |
| `primal_edge_length` | `Edges` | `Float64` | edges | `Extensive` | length | amounts | `geometry.primal_edge_length` through `Mesh.at_radius`, power one |
| `dual_edge_length` | `Edges` | `Float64` | edges | `Extensive` | length | amounts | `geometry.dual_edge_length` through `Mesh.at_radius`, power one |
| `vertex_coordinates` | `Vertices` | `Float64` | vertices, component | `VectorComponent{:cartesian}` | dimensionless | amounts | `level.vertices` promoted to `Float64`, on the unit sphere |
| `dual_vertex` | `Cells` | `Float64` | cells, component | `VectorComponent{:cartesian}` | dimensionless | amounts | `geometry.dual_vertex`, each cell's circumcentre |
| `edge_midpoint` | `Edges` | `Float64` | edges, component | `VectorComponent{:cartesian}` | dimensionless | amounts | `geometry.edge_midpoint` |
| `edge_normal` | `Edges` | `Float64` | edges, component | `VectorComponent{:cartesian}` | dimensionless | amounts | `geometry.edge_normal`, from `edge_cells[e, 1]` toward `edge_cells[e, 2]` |
| `cell_vertices` | `Cells` | `Int32` | cells, corner | `Intensive` | dimensionless | `ElementIds` of `Vertices` | `level.cells`, counterclockwise seen from outside |
| `cell_edges` | `Cells` | `Int32` | cells, corner | `Intensive` | dimensionless | `ElementIds` of `Edges` | `stencils.cell_edge`, local edge `k` opposite corner `k` |
| `edge_cells` | `Edges` | `Int32` | edges, pair | `Intensive` | dimensionless | `ElementIds` of `Cells` | `stencils.edge_cell`, the creating cell first |
| `edge_vertices` | `Edges` | `Int32` | edges, pair | `Intensive` | dimensionless | `ElementIds` of `Vertices` | `Mesh.edge_vertices(level, stencils)` |

Every array's owner is `mesh_geometry`, its time semantics `Static` and its placement
none; its axes are named by `Mesh.axis_name` of its location and by Mesh's
`COMPONENT_AXIS`, `CORNER_AXIS` and `PAIR_AXIS` (the mesh plan, section Locations). The
four measures are held at the support's radius because the support digest covers them at
that radius, so the bytes under a support id are the values its identity names.
Coordinates, dual vertices, midpoints and normals are held on the unit sphere, as the
coordinate digest covers them, because a radius multiplied into a stored direction is the
stored radius the mesh plan refuses. Every array is written element axis first, the
layout of every stored array: `Mesh` holds its matrices component first, and
`put_support!` permutes each once at the write. The index tables are dimensionless
`Intensive` arrays of `ElementIds`, the form every index field takes.

Two things are not held. The neighbour tables of `Stencils` (`edge_neighbour`,
`vertex_neighbour`, `vertex_weight`) are set relations over `cell_vertices`, `cell_edges`
and `edge_cells`, and a kernel reads them from `Mesh.stencils` in the run, never from the
store. And `Mesh` builds no geometry for the leaves of a `RefinedMesh`: a support's arrays
are those of its level, which is what its digests cover, and a refined mesh's own
geometry, when the mesh builds one, enters this table under the same location rule.

Three routes lost.

- Rebuilding every array beyond `cell_area` from the manifest's declaration through
  `Mesh.hierarchy` and `Mesh.geometry`, held to the support digest, as
  `Render.read_netcdf` rebuilds a support. It holds nothing twice and loses three ways: a
  store outlives the code that wrote it, and once `GEOMETRY_CONSTRUCTOR_VERSION` moves the
  declaration rebuilds another support, so every artifact under the old id loses its
  geometry; a support with refinement regions or fractions has no declaration a reader can
  rebuild from, which is why `read_netcdf` refuses one; and the container is
  language-neutral (decision 0010) where the rebuild is a Julia call, so a reader outside
  the package would carry a second definition of every measure.
- Holding the measures the digest covers and rebuilding the directions and the tables. It
  keeps all three losses for the arrays it does not hold.
- `put_support!` taking the geometry from its caller. The digests cover the coordinates
  and the four measures and not the directions or the tables, so a geometry whose
  measures agree and whose normals do not would be held under the id; building both
  inside the call leaves no such case.

**Where an array's values sit is a seventh required attribute, `location`.** Every stored
array carries `location`, the name of its `Mesh.Location` type (`Cells`, `Vertices` or
`Edges`), beside the six, built by `array_attributes` with them, and the store refuses to
open an array missing it, naming it. A field's location is on its type (the fields plan,
section Location), and a write declares the location of its quantity (the coupling plan,
section Exchanges), so `put_field!` and `submit!` write `Fields.location(field)` and
refuse a field whose location is not its write's, naming both, as the semantics is
already refused. `read_field` takes `location` as a required keyword, compares it before
the other attributes, and refuses a manifest attribute or an array attribute that
differs, naming `location`; the field it returns carries the location on its type.

Four routes lost.

- Folding the location into `support_id`, one support per location. Every key names its
  support (decision 0010), so one mesh's identity would split three ways, every key would
  move with it, and one level's geometry would sit under three ids where decision 0010
  holds it once; a cell field and an edge field on one mesh would read as fields on two
  meshes.
- Folding it into `semantics`, `VectorComponent{:edge_normal}` standing for edges. The
  location is not a function of the semantics: the dual area is `Extensive` at vertices,
  an edge length `Extensive` at edges, and the triangle C-grid holds vorticity on the dual
  around vertices (REQ-TER-011), so one semantics name would have to carry two things.
- Folding it into the axis names `_ARRAY_DIMENSIONS` records. That attribute is written
  from the layout and is not among the required attributes, so an array missing it is
  not refused by name; the first axis name is written from the location instead, a record
  of it rather than a second definition.
- Inferring it from the element count. `ncells`, `nvertices` and `nedges` differ at every
  level, so a count does name a location, but it is shape standing for identity, which
  decision 0006 refuses, and a count cannot be refused as absent.

**A vertex or edge array is chunked by index range.** Only cells nest by range (the mesh
plan, section Locations): a level's vertices are a prefix of every finer level's, and the
edges a range of cells created are contiguous in number and vary in count from one
coarse cell to the next. A Zarr version 2 array has one chunk extent per axis, the last
chunk short (`MetadataV2` holds `chunks::NTuple{N, Int}`, Zarr.jl 0.10.2,
`src/metadata.jl` line 114), so no chunk can be the elements a coarse cell owns. Every
array is chunked along its first axis in contiguous index ranges of

```
elements_per_chunk(location, level, chunk_level) =
    cld(Mesh.element_count(location, level), Mesh.ncells(chunk_level))
```

elements, from the `chunk_level` keyword a cell array already takes, and the manifest's
`elements_per_chunk` replaces `cells_per_chunk`. At cells the division is exact and a
chunk is the descendants of one cell of `chunk_level`, the hierarchy range. At vertices
and edges a chunk is an index range and nothing reads it as more: no reduction runs over
vertices or edges (the fields plan refuses `coarsen` and `refine` there), and the
writer's stages need only that chunks are disjoint. Two routes lost: renumbering vertices
and edges on disk so each coarse cell's are contiguous and of one count, which is a second
numbering with a permutation at the boundary, a translation layer; and one chunk per
array, which hands the writer's encode stage one item the size of the whole array under
one charge, against decision 0038.

**The export declares its mesh.** NetCDF is a rendering for export only, written with the
geometry declared in the file (the radius, the cell boundaries, the weight an integrator
needs), so no reader can substitute Earth's without saying so. It lives in `Render`
because it is a rendering, and `lint_calendar` already refuses a date type reaching it.
The file declares the mesh as a mesh topology variable of the CF conventions, which
incorporate UGRID 1.0 (Eaton et al. 2025, CF Metadata Conventions 1.13, section 1.6,
p. 15, and section 5.9 with Example 5.21, pp. 75-76), and each field's location through
its `mesh` and `location` attributes (Table K.1, pp. 249-250, which also gives
`start_index` and the 0-based default for connectivity). `Render.UGRID_LOCATION` is the
one table from `Cells`, `Vertices` and `Edges` to the convention's `face`, `node` and
`edge`, read in both directions. Every file holds the whole topology (`cell_vertices`,
`cell_edges`, `edge_vertices` and `edge_cells`, 0-based with `start_index = 0`, the disk
base of decision 0010) and every location's coordinates and measures, whatever the
field's location, so one reader and one comparison serve every file. Cells keep their
latitude and longitude. Vertices and edges declare their unit positions as three
Cartesian components each, in the coordinates the file's `spin_axis` and
`prime_meridian` are declared in: from level one a vertex sits on each pole, and at level
zero an edge midpoint lies on the spin axis (decision 0005), where longitude has no value
and `Mesh.longitude` refuses. A field at cells names `cell_area` as its cell measure and
one at vertices `dual_area`; one at edges names none, because CF's cell measure is an
area or a volume and an edge carries two lengths, neither the measure of every integral
over edges (REQ-TER-011). `read_netcdf(path; name, location)` rebuilds the support from
the declaration as before, compares every topology, coordinate and measure variable with
the rebuild, and refuses a field variable whose `location` is not the convention's name
for the location read, naming `location`.

`put_field!` writes an artifact inline. It is the reference path of the writer below,
which is how a run writes.

**The step's interval reaches the key as a required keyword.** `interval` is a required
keyword of `put_field!` and of `submit!`, a `Time.Interval`: the interval the caller
handed the `step!` that wrote the field, which in a run is the driver that steps the
components and submits what they wrote. It is the key's interval for every field. For a
field placed over an interval (`IntervalMean`, `IntervalAccumulation`, `EndpointState`)
the keyword must be identical to `Time.interval` of the field's time support, the same
float width and both bounds the same IEEE bit patterns, which is the equality the key
hashes; otherwise the admission refuses the quantity `interval`, naming both intervals
and the field's time semantics. For an `Instantaneous` or `Static` field, whose time
support carries no interval, the keyword is the key's interval and nothing is checked
against it. The array's `interval` attribute stays the field's own placement,
`placement_record` of its time support, so placement and the interval of the making
remain two records. There is no fallback: a call without `interval` is refused as
missing, an interval-placed field included, so no field is keyed over an interval its
caller did not name.

This replaces the refusal `fiddlybits-52v.6.16` put in `put_field!`, which refused a
`Static` or `Instantaneous` field rather than invent an interval. That refusal was right
while the time support was the only source, and it leaves every instantaneous and
static output of a run unstorable; with the interval named at the call nothing is
invented, and decision 0010's sentence on instantaneous outputs, that two steps from two
declared starts differ in their bits and agree in their placement, and that an output
with no time axis written on every step is keyed per step, is carried at the store.

Two routes lost. The run driver handing the interval to the writer from context, a
current step the writer reads rather than an argument at the call, is a value crossing a
component boundary that no call site shows, and a context left over from another step
keys a field under it without a word. Placing every field over its step's interval, a
change to `Fields` so every time support carries one, merges placement with provenance:
an instant would carry an interval it is not a mean or an accumulation over, and every
reader of a time support would meet a bound that says how the field was made rather
than what it means on the clock. The keyword states the interval twice for an
interval-placed field, and the check makes that redundancy a refusal rather than a
second definition.

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
open_arena(capacity)                    -> Arena; every host buffer of one writer, page-locked once
place!(arena, n) / release_range!       one contiguous block per submission, first fit, coalesced on release
open_writer(store; run, profile)        -> Writer, its arena and stages started, held until drained
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
| host copy | the card, on the stream of the task that wrote the field | that stream; there is no worker to count | at submission, once the charge is taken and placed as one block of the writer's arena: `copy_to_host!` into the block's first bytes, queued behind the kernels that wrote the field and recorded through `Events.moved`; `submit!` returns without a host wait. On `CPU` the copy is taken at the call |
| encode | cores | the tasks the default thread pool runs at once, which is the allocation the process was launched with (`-t` from `$SLURM_CPUS_PER_TASK`); nothing is declared | once the copy's handoff completes: `to_disk!` of the writer's own copy into the block's translated range for cell ids, the cells cut into chunks by hierarchy range through the block's chunk buffer, each chunk compressed into the block's compressed range through `Blosc.compress!` after `Blosc.set_compressor`, with the codec name, level and shuffle the `BloscCompressor` `compressor()` holds, the parameters and call `Zarr.zcompress` makes on the reference path; then the copy, translated and buffer ranges and their charge released |
| disk | the store's filesystem | `profile.store_writers` | the array metadata, each compressed chunk's arena bytes under the chunk key the reference path gives it, and the manifest text, written into a staging directory beside the key's place; then the compressed range and its charge released |
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
artifact's siblings. An item's charge is taken whole at submission, each part rounded up
to a multiple of eight bytes: the host copy's bytes; the translated cell-id array's bytes,
none for amounts; one chunk's bytes for the chunk buffer; and each chunk's worst-case
compressed size, its bytes plus `Blosc.MAX_OVERHEAD`, the destination size `Blosc.compress`
allocates. The encode stage releases the first three parts and the disk stage the compressed
part. Only a submitter waits on the pool, and no stage holds a charge while it waits for
another: a charge taken in parts, one part held while the next is waited for, is the
deadlock decision 0038 names, and a stage that only releases cannot meet it.

**Every host buffer of the writer is carved from one arena.** `open_writer` makes one
`Vector{UInt8}` of `write_ceiling` bytes rounded down to a multiple of eight, page-locked
through `Backends.host_buffer(GPU(), UInt8, n)` when CUDA reports a functional device and
plain otherwise, and a `BytePool` of that capacity. Page-locking happens once, when the
writer opens. A submission's charge is placed as one contiguous block of the arena, first fit
in index order, laid out as the host copy, the translated array, the chunk buffer and the
compressed chunks; the encode stage writes the translation with `to_disk!` and compresses into
the block, the disk stage writes each chunk's bytes from it, and the writer's host memory is
the arena and nothing beside it, so `write_ceiling` bounds it exactly. A released range merges
with the free ranges it adjoins. A charge the pool admits waits for placement only while no
free range is long enough, and is then served once the placed ranges return: the pool admitted
it, so the free bytes are at least its size; the one opener task is the only one that places;
every placed range belongs to a submission already queued to stages that never wait on the
arena and release every range on every path, success, refusal or discard; and once none is
placed, coalescing leaves the whole arena as one free range, long enough for any charge the
pool admits. The compression parameters are read from the compressor object at each chunk,
never kept beside it, and `provenance.pooled_write_is_reference` holds the bytes to the
reference path's Zarr write.

Four routes lost. Pinning a buffer per submission and unregistering it when the copy has been
encoded puts `cuMemHostUnregister` inside the encode stage, and registered memory reaching a
finalizer inside any allocation, `submit!`'s included, where it waits for whatever kernel is
running (`notes/findings/2026-09-14-unregistering-page-locked-host-memory-waits-on-a-running-kernel.md`);
a stage or a submitter then waits on device work. A pool of pinned buffers in size classes,
kept for the writer's life with every pinned byte charged, can wait forever: every pinned
buffer idle, none long enough, and the free charge below the size a new one needs. An arena
sized by its own profile setting beside `write_ceiling` avoids that, and adds a declared
constant whose value moves nothing but which writes are refused. Refusing a submission when
the pool is fragmented refuses a write that fits the ceiling, depending on what was written
before it. Splitting one host copy across several idle buffers needs a range copy in
`Backends.copy_to_host!` and a reassembly the encode stage would charge again.

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
raises it.** These are found only late: a kernel fault on the producing stream, which
`after!(CPU(), point)` does not raise, since neither form of `after!` reads CUDA's
kernel-exception flag and the host holds what the faulted kernel left; a `CellIds`
entry outside its level, which `to_disk` finds in the data; a key another process
stored between admission and rename, which `write_directory!` refuses; and a
filesystem error writing or renaming the staging directory, carried as a
`Verdicts.Refusal` from the disk stage whose reason holds the error's message. A
kernel fault is raised deterministically, at the settle point decision 0060 declares:
`settle!` calls `Backends.complete!` on the task that submitted the write before it
reads the submissions' states, and that call is where the fault surfaces, on the same
task every run. CUDA's kernel-exception flag is one per context and cleared by the
first read that finds it set, so a read of it anywhere else would let arrival order
choose which task the fault is raised on, against decision 0029; `docs/imports/cuda.md`,
section "Page-locked memory and the queued copy", carries the contract. A late refusal
marks its submission refused and every later submission discarded: nothing submitted
after a refused write is committed, and the discarded staging directories are removed,
so the writes submitted after the faulting kernel are discarded exactly as any other
late refusal's are. The store after a refusal therefore holds every submission before
the earliest refused one, whatever order the stages met their failures in. `settle!`
waits on each submission's own state
and never on a byte count reaching zero, so a writer with no submissions settles at
once. It returns when every submission made so far is committed, refused or discarded,
and refuses naming the earliest-submitted refused write, its key and quantity, and how
many later submissions it discarded. Its caller runs it inside the run's `journalled`
wrapper, which emits the `refusal` event under that caller's header, as
`Coupling.exchange!` journals its refusals.

**A run's end drains the stages.** `drain!` closes the writer to submissions, settles,
stops the encode and disk tasks once their queues are closed and empty, and removes
every discarded staging directory. It then calls `Backends.complete!` on the opener and
releases the arena's page lock, whether the settle refused or not; nothing else unregisters
host memory, and no writer's arena reaches a finalizer, because `open_writer` holds every
writer in a module registry until its drain removes it. A writer never drained is reported
by name by an exit hook that unregisters nothing, and the run door's close refuses a run
whose writer is still registered (`fiddlybits-52v.6.27`). The run door (`fiddlybits-52v.6.17`) opens the writer
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

**A run settles at a declared cadence, at a step boundary, and always at the drain**
(`docs/decisions/0060-the-writer-settles-at-a-declared-interval-of-the-model-clock.md`).
The profile declares `settle_interval`, a duration in SI seconds of simulated time with
a disposition from `Systems.DECLARED` and no default (`fiddlybits-52v.6.30`). The driver
calls `end_step!(ctx; interval, sequence, tier)` at the end of every step; the door
settles when the step's end is at or after the next multiple of `settle_interval` since
the run epoch, runs `settle!` inside `journalled` under that step's header, and takes
the first multiple after that end as the next (`fiddlybits-52v.6.31`). Its decision
reads the interval and the cadence and never the writer's state, so the step at which a
run meets a late refusal is fixed by the step schedule and the profile and not by the
order the stages found the failure. Between a refused write and that settle the run
computes and submits as before, `submit!` refuses nothing on the late refusal's account,
and every submission after the refused one is discarded; the stored set, the keys and
the manifests are the ones above under every cadence. A refusal a settle raised is not
raised again by a later settle or by the drain.

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
| `provenance.store_refuses_incomplete` | the store refuses an array missing any of support id, semantics, time semantics, dimension, owner, interval or location, on a field array and on a support array at each location; refuses a field whose ledger is open; and refuses a read under a location other than the array's, naming `location` | each attribute dropped in turn, every one of which must refuse; a dirty code version writing a keyed artifact, which must refuse; and the same read under the array's own location, which must return the field, since a read that refuses every location is not a check |
| `provenance.index_roundtrip` | known fields of cell, vertex and edge ids written 0-based and read back 1-based are unchanged | an off-by-one at the disk boundary, which each known field must expose rather than a symmetric error hiding |
| `provenance.support_geometry_held` | every array of `SUPPORT_ARRAYS` read back through `read_geometry` is bitwise the Mesh array it is named for, each measure through `Mesh.at_radius` at the support's radius, each index table translated from disk, each element axis first; every array's location, semantics and dimension are the table's | `primal_edge_length` and `dual_edge_length` written under each other's names, which share location, semantics, dimension and size, so only the element comparison exposes them; `cell_vertices` written without the 0-based translation |
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
| 52v.6.29 | sonnet | `src/Provenance/store.jl`, `test/provenance/store.jl`, `test/io/store_fixtures.jl` | `provenance.store_refuses_incomplete` passes with arms for two `Instantaneous` fields at one instant from two steps over identical inputs keyed apart; a `Static` field keyed over its keyword; an interval-placed field refused naming both intervals when its keyword differs, and when it is equal under `==` at another float width; the agreeing keyword storing as the positive control; and a call without `interval` refused as missing |
| 52v.6.26 | frontier | `src/Provenance/writer.jl`, `src/Provenance/store.jl`, `test/provenance/writer.jl`, `test/io/store_fixtures.jl`, three entries of `docs/oracles/registry.toml`, `docs/imports/zarr.md` | `provenance.pooled_write_is_reference`, `provenance.write_order_independent` and `provenance.write_ceiling_held` pass with their controls; the store's two oracles pass through `put_field!` and their admission refusals refuse at `submit!`; a collided rename and an out-of-level cell id leave exactly the earlier submissions stored |
| 52v.6.27 | sonnet | `src/Provenance/run.jl`, `test/provenance/run.jl` | a run refused after its submissions leaves them stored and rethrows the component's refusal; a refused drain is journalled; the door is the only caller of `open_writer` |
| 52v.6.30 | sonnet | `src/Systems/profile.jl`, the profile construction sites in `test/`, the Amendments section of decision 0014 | `settle_interval` refuses absent, zero and below, a `Closure` disposition, a dimension other than time and an `Absent`; `fast_profile` and `full_profile` require it; `strip` carries it; `provenance.key_stability` passes; each control fires |
| 52v.6.31 | sonnet | `src/Provenance/run.jl`, `test/provenance/run.jl` | `end_step!` raises a late refusal at the end of the first step reaching the next multiple of `settle_interval` since the run epoch and not before, journalled under that step's header, with later submissions absent; a step ending exactly on a multiple settles; a continued run settles on the epoch grid; each control fires |
| 52v.6.35 | sonnet | `src/Provenance/store.jl`, `src/Provenance/writer.jl`, `test/provenance/store.jl`, `test/provenance/writer.jl`, `test/provenance/support_geometry.jl` and its include, `test/io/store_fixtures.jl`, `test/io/index_roundtrip.jl`, the grid or mesh and index base rows of `docs/imports/zarr.md`, the Amendments section of decision 0010 | `provenance.store_refuses_incomplete` passes with the seven attributes dropped in turn on a field array and a support array of each location, and a read under another location refused naming `location` while the read under its own returns the field; `provenance.index_roundtrip` passes on cell, vertex and edge ids; `provenance.support_geometry_held` passes with both controls firing; a vertex and an edge field store and read back with a short last chunk; `provenance.pooled_write_is_reference` and `provenance.write_order_independent` pass with an edge field among the submissions |
| 52v.6.36 | sonnet | `src/Render/export.jl`, `test/io/netcdf_export.jl`, the grid or mesh row of `docs/imports/ncdatasets.md`, the eaton2025 row of `docs/references/INDEX.md` | a field at each location is written and read back under its own; a read under either other location refuses naming `location`; each topology, coordinate and measure variable altered in one element refuses naming it; connectivity written 1-based under `start_index = 0` refuses; the `mesh` variable with each attribute dropped refuses naming it; `build.import_record_completeness` passes |
| 52v.6.6 | sonnet | none; reports only | every oracle this plan's front matter names ran; verdicts by name |

52v.6.16 depends on nothing unmerged and blocks 52v.6.4 and 52v.6.6; 52v.4.19 and
52v.4.20 depend on 52v.6.16. 52v.6.3, 52v.6.4 and 52v.6.7 depend on 52v.6.2; 52v.6.4 depends on 52v.6.3 and on the
coupling plan's `Ladder`; 52v.6.7 depends on 52v.6.8, which depends only on the
skeleton. 52v.6.23, 52v.6.24 and 52v.6.25 block 52v.6.26, which with 52v.6.17 blocks
52v.6.27; 52v.6.25 depends on 52v.4.19, whose boundary holds `test/system/` and the
`key_stability` fixture. 52v.6.29 depends on nothing unmerged and blocks 52v.6.26: the
interval check lands in `write_field!` before 52v.6.26 splits it into the admission both
doors share, so `submit!` inherits the keyword with the rest of `put_field!`'s, rather
than a small change to the store waiting on the host copy 52v.6.26 waits on and then
reaching into the writer's tests. 52v.6.30 depends on 52v.6.25, and 52v.6.31 depends on
52v.6.30, 52v.6.26, 52v.6.27 and 52v.6.11. 52v.6.35 depends on `fiddlybits-52v.2.20`
for `Mesh.Location` and `edge_vertices`, on `fiddlybits-52v.3.26` for the location on the
field's type, on `fiddlybits-52v.11.7` for the location on the write, and on 52v.6.26 and
52v.6.29: it renames forms the writer's stages use and extends the admission both doors
share, so it lands on the store as those two left it rather than 52v.6.26 being rebuilt
over it. 52v.6.36 depends on `fiddlybits-52v.2.20` and `fiddlybits-52v.3.26` and on
nothing in the store. 52v.6.6 depends on 52v.6.23 to 52v.6.27, on 52v.6.29 to 52v.6.31,
and on 52v.6.35 and 52v.6.36. The area
depends on the fields plan for the ledger and on the system plan for the declared
parameter subset.
