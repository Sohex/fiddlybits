# MeshArrays.jl and ClimateModels.jl, read as rejected precedent

**What they are.** Two trees from the same author, read together because each is a
worked instance of a pattern this project has already decided against, and a precedent
is worth more when it is named than when it is merely avoided. `MeshArrays.jl` carries
gridded fields on a small enumeration of named global topologies and exchanges halos
between their faces. `ClimateModels.jl` is a run harness: it gives each run a directory,
a random identity and a git repository to journal itself into.

**What of either is used.** Nothing.

**Licence.** MIT, both. **Read at.** `MeshArrays.jl` at
`f812fc9` in `/home/cfutro/git/JuliaClimate/`, with the superseded personal fork at
`9105671` in `/home/cfutro/git/gaelforget/`; `ClimateModels.jl` at
`7b3b51e57454d166a38daf26d537b76f85fd93b8`, committed 2026-08-13, and
`CyclicArrays.jl` at `4c3ab9b16fbb6db2dcd4194186260673d6fdc5ba` beside it.

**Verdict.** Rejected precedent, both, each against a decision that already says so:
decision 0005's connectivity graph against the enumerated topology, decision 0010's
content address against the random run identity. One thing in the second is worth
keeping and is not currently anywhere in this project, and it is named at the end.

## The enumerated topology, and what a general one costs instead

`MeshArrays.jl`'s `gcmgrid` carries a `class::String` and `exchange!` branches on it:
`"LatLonCap"`, `"CubeSphere"`, `"PeriodicChannel"`, `"PeriodicDomain"`. Each branch has
its own file of hand-written face adjacency and rotation, 72 to 203 lines apiece. The
arrangement is coherent for a small fixed set of quadrilateral tilings and it makes a new
topology a new source file, which is precisely the shape decision 0005's connectivity
graph exists to avoid: a strait opening between two basins, or a graded refinement ring
appearing at a new boundary, is a change in data, and under an enumerated topology it
would be a change in code.

`CyclicArrays.jl`, by the same author and five years older, is the more general worked
alternative and is the useful half of this reading. Its `CyclicArray` holds the data and
a `connections` array indexed as `[face, dimension, side, 1:4]`, whose four entries are
the neighbouring face, the axis it joins on, the side of that axis, and whether the join
flips orientation, with `-1` marking an edge with no neighbour. The indexing code reads
that table; it does not branch on a topology name. Adding a topology is filling in a
table. That is the same move decision 0005 makes and it is worth recording that the
smaller, older, unmaintained package is the one that made it.

Where the analogy stops is worth stating too, because it sets the bar for this project's
own operator. `CyclicArrays` is still Cartesian underneath: a face is a rectangle, a side
is one of four, and the table's shape encodes that. A triangle connectivity graph has no
fixed valence at the twelve base vertices and no notion of a side, so the table becomes a
neighbour list with an orientation per edge rather than a four-index array. The generality
that carries is the principle, not the layout.

**The criterion this puts on the mesh plan.** The exchange operator reads the connectivity
graph and nothing else. A topology change, a strait opening or closing, a refinement
region appearing, changes the graph's contents and no code path: there is no dispatch on
a topology name, no branch per boundary kind, and no per-case file. The test that decides
it is a topology-change case run twice, once with a strait open and once closed, through
the same compiled operator, with the halo exchange giving the right answer both times and
the compiled method count unchanged. Without that test the criterion is a preference.

## The random run identity, and the journal beside it

`ClimateModels.jl`'s `ModelConfig` carries `ID :: UUID = UUIDs.uuid4()`, assigned at
construction, and `pathof(x)` makes that UUID the run's directory name. Two runs built
from identical inputs are two unrelated directories with no shared key, and nothing in
the tree asks whether a run's result already exists. Decision 0010 makes identity a hash
over the code version, the declared parameter subset, the input keys, the support
identity and the operator version, exactly so that the question can be asked without
running anything. The precedent is the counterexample: it is what the store looks like
when identity is assigned rather than derived.

What sits beside that UUID is more interesting. `git_log_init` makes a `log/` subfolder
inside the run directory into its own git repository; `git_log_msg`, `git_log_fil` and
`git_log_prm` commit messages, output files and a `tracked_parameters.toml` to it as the
run proceeds, and `log(x)` reads the history back. The result is a chronological,
human-readable account of what happened during one run, with diffs.

**The question the row asks: does a readable per-run journal belong beside a content
address?** Yes, and not as a git repository.

The half that is already covered: decision 0010's manifests are TOML and readable,
decision 0029 makes run records append-only and forbids rebuilding them by scanning a
directory, and decision 0036 makes every record a person edits or reads TOML. A hash plus
a manifest answers "what is this object and what produced it".

The half that is not covered anywhere: what happened during the run, in order. Which
exits fired and with which verdict, which loop returned `Bracketed` at which iteration,
which ledger closed and what it lost, which refusal was raised and by which component,
when a topology-change event moved the connectivity graph. Decision 0009 produces every
one of those as a value and decision 0010 stores the artifacts they produced, and neither
of them keeps the sequence. A reader asking why a run ended where it did is currently
expected to reconstruct it from the artifacts, which is the reconstruction decision 0029
forbids for run records.

So the recommendation, for the store row to carry: **an append-only per-run event journal
in TOML, written beside the run record, keyed by the run identity, carrying no identity of
its own and never read back by the model.** One line per event, each with the simulated
instant, the emitting component, the event kind and its verdict. It is a report, not a
store: nothing in the model may branch on it, which is what keeps it from becoming a
second source of truth. And it is not git. A repository per run puts a second identity
next to the first, invites a reader to diff two runs that have no common ancestor, and
makes the journal's own history a thing to reason about.

## Assumptions they carry

Recorded briefly, since nothing is proposed for adoption from either.

**Earth defaults and calendar.** `MeshArrays.jl` ships Earth grid configurations and
reads their binary files; `ClimateModels.jl` is a harness around models with their own
calendars. Both are Earth-shaped by purpose, which is why neither is a candidate.

**Grid, mesh and index base (A6).** The whole subject of the first: four named classes,
each with its own hand-written adjacency, and a per-face size table.

**Mutable global state (C5).** `ClimateModels.jl`'s run directory and its git repository
are process-external state that the harness mutates as it runs.

**Fail-open branches (C4).** The `class` dispatch in `exchange!` is the one to name: a
class the enumeration does not know falls through the `if`/`elseif` chain, and what
happens then depends on the branch structure rather than on a declared refusal.

## Checklist

| item | result |
| --- | --- |
| A1 day and year | not examined; neither is a candidate and both are calendar-bearing by purpose |
| A2 planetary constant block | Earth grids shipped as configuration in `MeshArrays.jl` |
| A3 Earth literals | not examined |
| A6 grid and index base | four hardcoded topology classes with per-class adjacency files; a per-face size table; faces are `(i,j)` rectangles |
| B4 comment against value | not examined |
| B5 clamps and limiters | not applicable |
| C1 use site of every constant | not examined |
| C3 declared against demonstrated | not examined |
| C4 fail-open branches | the `class` string dispatch with no declared refusal for an unknown class |
| C5 duplicate state and second constant sets | the run directory and its git repository in `ClimateModels.jl` |
| D2 boundary field by field | not applicable; nothing is exchanged with either |
| D4 conservation identity | not applicable |

## References

- The survey entries: `docs/surveys/dycores-and-frameworks.md`, the `MeshArrays.jl` and
  `ClimateModels.jl` closer looks.
- Decision 0005 (one mesh, the connectivity graph), decision 0009 (verdicts as values),
  decision 0010 (content-addressed artifacts, runs as UUIDs), decision 0013 (the
  dynamical core the exchange operator serves), decision 0029 (append-only run records),
  decision 0031 (local refinement and topology change), decision 0036 (TOML throughout).
- The rows that consume this: `fiddlybits-52v.2.7` (the connectivity graph and its
  topology-change events), `fiddlybits-52v.2.1` (the mesh plan, which carries the
  criterion above), `fiddlybits-52v.6.3` (the store and its manifests, which carries the
  journal recommendation).
