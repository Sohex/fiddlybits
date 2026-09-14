+++
epic = "fiddlybits-52v.1"
title = "The Julia package skeleton: submodule set and include order, the lint suite, the import harness, and the budgets"
decisions = ["0011", "0012", "0029", "0036", "0037", "0039", "0042", "0043"]
requirements = ["REQ-SYS-101", "REQ-SYS-102", "REQ-NUM-001", "REQ-NUM-008"]
oracles = ["build.module_order_acyclic", "build.import_record_completeness", "build.manifest_exclusions", "build.lint_positive_controls", "build.load_latency"]
status = "filed"
date = 2026-09-10
+++

## Scope

This plan builds the package that every other M0 plan writes into: the manifest of
pinned dependencies, the one top-level module and the submodule files it includes,
the test tree and how a suite joins it, the benchmark tree, the precompilation
workload, and the checks that guard the boundary between this project and its
dependencies. It fixes the submodule set and the include order, and it fixes them as
a testable property rather than as a convention, because the include order of a
Julia module is its dependency order and nothing in the language enforces that the
two agree.

It does not write physics, geometry, fields or constants. Every submodule this plan
creates is a module declaration with nothing in it; the area plan named against each
one fills it. A submodule whose area has no M0 plan is not created here, and a
submodule a later plan finds it needs is added by a row of that plan rather than by a
second layout kept beside this table; `ShallowWater` arrived that way, through
`fiddlybits-52v.9.8`.

Three things are deliberately left:

- **The coupling layer of decision 0009** is carried by `fiddlybits-52v.11`, whose
  plan settled the milestone question this one left open: it belongs to M0, because
  decision 0010 states the store's central function as `plan(system, ladder, code)`
  and `Ladder` is a coupling type, so an M0 row's signature already reads one.
  Decision 0034 is amended accordingly, and `Coupling` joins the table above in
  group F ahead of `Provenance`, which reads it.
- **The two adopt candidacies of decision 0012**, ClimaTimeSteppers.jl and
  RootSolvers.jl, are not dependencies until their own decisions are taken, so
  neither appears in `Project.toml` here. `fiddlybits-52v.10` takes the second.
- **Where the per-commit gate runs**, and the benchmark bed decision 0029 wants
  beside it. The backend oracles need a device and a hosted runner has none, so this
  was a decision with alternatives, carried by `fiddlybits-52v.1.6` and settled by
  decision 0043: the gate runs on this machine through the scheduler, a hosted job
  answers only whether a clean checkout stands up, and the reference-hash rule is
  built now against the stand-in case named in `bench/reference.toml`. `bench/` holds
  the bed's entry point and no case until a row registers one.

## Module boundaries

One top-level module, `Fiddlybits`, in `src/Fiddlybits.jl`, which contains nothing
but its includes and the precompilation workload. Each submodule is one directory
under `src/` with a file of the same name as its entry point.

The include order below is a topological order of the reference graph. The groups
are the plan's reading of which modules are independent; the oracle checks only that
every reference points at an earlier include, which is what a topological order is,
and says nothing about groups.

| group | submodule | holds | filled by |
| --- | --- | --- | --- |
| A | `Verdicts` | the closed verdict vocabularies and the refusal type | 52v.1.2 (complete here) |
| A | `Events` | the closed journal vocabulary, typed payloads, `emit` with a no-op sink, the device-move record | 52v.6.8 |
| A | `Dimensions` | `Dim{M,L,T,Theta,N}` and its algebra over DynamicQuantities | 52v.3 |
| A | `Time` | `SimTime`, `Interval`, `duration`, `TimeSupport`, the `TimeSemantics` types | 52v.5 |
| B | `Dispositions` | `Sourced`, `Derived`, `Bracketed`, `Irreducible`, `Closure` | 52v.4 |
| C | `EarthRatios` | the quarantined unit denominators, as `Sourced` values | 52v.4 |
| B | `Backends` | the KernelAbstractions device layer, `Adapt`, `on`, the memory budget | 52v.7 |
| C | `Reductions` | fixed-order pairwise and compensated sums, segmented reductions, quantiles, `error_bound` | 52v.7 |
| C | `Systems` | `System{FT}`, `strip`, `TrackingSystem`, `affected`; reads `Reductions.error_bound` | 52v.4 |
| D | `Orbit` | the Kepler solve, true anomaly, declination, hour angle, the epoch rule | 52v.5 |
| D | `Mesh` | `Support{L}`, bisection, numbering, geometry, stencils, local refinement | 52v.2 |
| E | `Fields` | `Field{S,T,D,L,A}`, `Semantics`, `coarsen`, `refine`, `time_reduce`, `Ledger` | 52v.3 |
| F | `Instellation` | per-cell flux from every declared star, eclipse geometry | 52v.5 |
| F | `Connectivity` | the connectivity graph derived from a terrain-level field | 52v.2 |
| F | `Coupling` | `WorldState`, `assemble`, `Exchange`, `FixedPointLoop`, `Ladder` | 52v.11 |
| F | `Provenance` | `ArtifactKey`, `CodeVersion`, `RunID`, the Zarr store, the journal, the RNG | 52v.6 |
| G | `ShallowWater` | the triangle C-grid discretisation, the step, the standard cases | 52v.9 |
| G | `Oracles` | the registry loader, the runner, the mutation harness | 52v.8 |
| G | `Render` | calendar rendering and NetCDF export, and nothing else | 52v.5, 52v.6 |

A submodule references another only by the relative form `..Name`; that is the form
the oracle recovers, and a reference written any other way is invisible to it. The
oracle reads the source as text rather than parsing it, so the form is the contract.

Three of these boundaries are decisions rather than transcriptions, and each is
made to break a cycle that the row titles do not show:

- **`Time` is below `Fields`, and `Instellation` is above it.** The row titles put
  `SimTime` and per-cell instellation in one area. Held in one module they form a
  cycle, because `Fields` needs `TimeSupport` for `time_reduce` and per-cell
  instellation needs `Field`. `Time` therefore carries the clock types and no field,
  `time_reduce` lives in `Fields` and dispatches on the `TimeSemantics` types `Time`
  declares, and `Instellation` carries everything that is per cell.
- **`Connectivity` is a submodule, not part of `Mesh`.** The connectivity graph is
  derived from a terrain-level field, so a `Mesh` that built it would depend on
  `Fields`, which depends on `Mesh`. The file boundary of `fiddlybits-52v.2.7` moves
  to `src/Connectivity/` accordingly.
- **`Mesh` does not reference `Systems`.** The mesh is on the unit sphere and no
  radius reaches it, which is decision 0005 and is what CGDycore.jl's stored radius
  cost (`docs/imports/cgdycore-jl.md`). The acyclicity oracle sees only that there
  is no reference; the area identity against `4 pi R^2` at more than one radius is
  what makes the absence mean something, and belongs to `fiddlybits-52v.2`.

`Verdicts` is filled here rather than by an area plan because it holds no design
judgement: its two vocabularies are transcribed from decisions 0009 and 0025, and
every module above it raises the one refusal type it declares.

`Events` sits beside it in group A for the same reason in the other direction: every
module that emits a journal event or records a device move sits below `Provenance`,
which writes them, so the front door is declared low and once, with a no-op sink that
`Provenance` replaces. The plan review found three plans each declaring a hook of
their own for this, which was three definitions of one mechanism.

### The test tree

Each test directory is a suite with its own entry point, `test/<dir>/runtests.jl`,
and `test/runtests.jl` discovers and includes every such entry point in sorted
order. A row adding a suite therefore touches only its own directory, which is what
keeps `test/runtests.jl` outside every implementation row's boundary. A directory
under `test/` with no entry point fails the run rather than being skipped; `fixtures`
directories are the exception, since they hold inputs and not tests.

| path | holds |
| --- | --- |
| `test/build/` | the module-order check |
| `test/verdicts/` | the closed-set check on the two vocabularies |
| `test/lint/` | the source lints, their fixtures, the word and exclusion lists, and the manifest check |
| `test/imports/` | the import-record harness |
| `test/gate/` | the reference-hash rule of decision 0043 and the load measurement |
| `test/<area>/` | the area suites, one directory per submodule, created by its own row |
| `test/planets/` | the system test instances (`fiddlybits-52v.4.5`) |

Every lint lives in `test/lint/`, under the name the import record that declared it
carries, so a record and a suite name one file. The records are live documents and
the review is repeated when a pin moves, so a path that moves is rewritten in the
record rather than recorded beside it.

`Test` is a test-time dependency in `[extras]` and `[targets]`, not a runtime one in
`[deps]`, so that `using Fiddlybits` loads nothing a run does not use; one
`Manifest.toml` still resolves both, and it is tracked because the environment
manifest is part of the run identity (decision 0029).

## Types and functions

`src/Fiddlybits.jl` declares `module Fiddlybits`, includes each submodule file in
the order of the table, and declares the PrecompileTools workload. No submodule is
re-exported: a caller names the module it reads from, so that a quantity has one
door and the door says where it leads. `Verdicts.Bracketed` and
`Dispositions.Bracketed` are two names for two things, and that is why.

`Verdicts` declares:

- `LoopVerdict`, with the singleton subtypes `Converged`, `Bracketed`, `Refused`,
  `NotEvaluable`, `BudgetExhausted` (decision 0009), enumerated by `loop_verdicts()`.
- `OracleVerdict`, with the singleton subtypes `FAIL`, `REPORT`, `PASS` (decision
  0025), enumerated by `oracle_verdicts()`.
- `Refusal(quantity, site, reason)`, an exception naming what was read, where, and
  why it was refused, and `refuse(quantity, site, reason)` which raises it. A
  refusal never carries a substitute value.

The vocabularies are closed by a test rather than by the language: `test/verdicts/`
asserts that the subtypes of each abstract type are exactly the enumeration, so a
subtype added anywhere fails the suite until the enumeration and the decision that
declares it move together.

`test/lint/` declares one function per lint, each taking a root path and returning
the offending sites, so that a lint is called on a fixture and on the tree by the
same function. The suite carries a table of lints, each with a dirty fixture and a
clean fixture; a lint that returns sites on its clean fixture, or none on its dirty
one, fails, and a lint in the table with either fixture missing fails rather than
passing vacuously. Word lists, literal lists, exclusion lists and exemptions are
TOML files beside the suite, never literals in the lint. The lints:

| lint | refuses | how it sees | declared by |
| --- | --- | --- | --- |
| `lint_earth` | an import of the DynamicQuantities constants registry or a qualified reference into it, a read of `EarthRatios` outside `EarthRatios` and `Render`, and any literal from the A3 list of `docs/imports/README.md` | the door, not the name: the registry's constants include `c`, `e`, `h`, `R`, `F`, `G` and `u`, which collide with ordinary variables, so a bare-name lint would be noise and the import is what it watches. A constant still enters only through a `Sourced` disposition. The A3 list is copied into TOML beside the suite and the copy is checked against the record's table | REQ-SYS-101, `docs/imports/dynamicquantities.md` |
| `lint_literals` | an untyped float literal inside a `@kernel` body or a physics submodule | a literal not wrapped in `FT(...)` or an equivalent typed constructor | REQ-NUM-001, `docs/imports/julia-1.12.md` |
| `lint_index_base` | `+ 1` or `- 1` applied to a name bound by `@index` inside a `@kernel` body, and to any `CellId` at the host boundary | the bound names are read from the kernel's own `@index` lines | `docs/imports/kernelabstractions.md` |
| `lint_calendar` | `using Dates`, `import Dates` or a qualified `Dates.` name in any `src/` submodule other than `Render` | textual | REQ-SYS-102, `docs/imports/ncdatasets.md` |
| `lint_journal_emitter` | any open, write or append against the journal path outside `src/Provenance/journal.jl` | the path is the one constant `Provenance` declares for it, and the lint reads that constant's name from the source rather than carrying its own | decision 0042 |
| `lint_effort` | a phrase from the effort list under `docs/` | the list is TOML beside the suite and holds only phrases with no other sense in this tree; `schedule` is not among them, because the tree carries a checkpointing schedule, a damping schedule and the machine's job scheduler, and a lint cannot tell those from a plan with dates. A record that states the rule is exempted by path with its reason, and the suite checks the exempted record still contains a listed phrase | `docs/practice.md` |
| `lint_front_matter` | a record under `docs/decisions/`, `docs/requirements/` or `docs/plans/` whose header does not parse as TOML between `+++` fences, or lacks a key its directory requires | the required keys per directory are TOML beside the suite; `README.md`, `INDEX.md` and `TEMPLATE.md` are not records | decision 0036 |
| `lint_manifest` | a package named in the exclusion list appearing anywhere in the resolved `Manifest.toml` | the exclusion list is TOML beside the suite, one entry per package naming the import record that excluded it; an entry with no record fails | `docs/imports/fastpower-jl.md` |

`lint_manifest` reads the dependency graph rather than the source, because the
hazard it catches arrives transitively and no call site would show it.

`lint_effort` cannot tell framing from mention, which is why its exemptions carry
reasons: the practice book states the rule in the words the rule forbids, and
decision 0034 records the rejected alternative by its name. What a lint can decide
it decides, and the rest is the reviewer's.

Every tree run asserts what its root holds before asserting the lint finds nothing
in it, so a lint pointed at a directory that has moved fails rather than passing.

`test/imports/` reads the entries of `Project.toml` and its `[extras]`, drops the
names Julia ships, and matches each of the rest against the first-line heading of
the records in `docs/imports/`, with a trailing `.jl` dropped, so the match is by
the package's name and not by a file name. Which names are shipped is read from
the resolved manifest, where a registered package carries a tree hash and a
shipped one does not; the manifest is what the environment resolved, and `Pkg` is
not on the test target. Of each it asserts that a record exists, that the
record names at least one leak check, and that every named check resolves: a path
under `test/` that exists, or an oracle id present in `docs/oracles/registry.toml`,
since some records catch their leak with an oracle rather than a file. The
direction matters: the check reads the dependency list and looks for records, never
the reverse, because `docs/imports/` also holds records of packages that were
surveyed and refused, and those have nothing to test.

The check has two halves. The structural half, that every dependency has a record
and the record names at least one leak check, holds whatever the board's state and
is asserted on the tree. The resolution half is reported rather than asserted,
because most of the leak tests the adopted records name are written by the area
rows and test the area's code. The harness therefore passes in full only once those
rows have merged, and the verify row of this plan depends on their verify rows for
exactly that reason; meanwhile the suite checks every unresolved name against this
table. The named tests and their owners:

| named check | record | owner |
| --- | --- | --- |
| `test/lint/lint_index_base.jl`, `test/lint/lint_earth.jl`, `test/lint/lint_literals.jl` | kernelabstractions, dynamicquantities, julia-1.12 | 52v.1.3 |
| `test/mesh/stencil_valence.jl` | kernelabstractions | 52v.2 |
| `repro.thread_count_bitwise`, `repro.fp32_kernel_certification` | kernelabstractions, julia-1.12 | 52v.7 |
| `test/fields/dimension_refusal.jl`, `test/fields/adapt_roundtrip.jl` | dynamicquantities, adapt | 52v.3 |
| `test/render/no_calendar.jl` | ncdatasets | 52v.5 |
| `test/io/index_roundtrip.jl` | zarr | 52v.6 |
| `repro.backend_ulp_envelope` | cuda | 52v.7 |
| `build.load_latency` | precompiletools | 52v.1.5 |

## Oracles

Five entries in `docs/oracles/registry.toml` under the `build` subsystem, all tier
1, all provisional with an empty `registered_at`. This plan's verify row runs them on
the merged result and reports the verdicts; it does not register them. Registration is
at the milestone that registers an entry and nowhere else (`docs/oracles/README.md`,
Registration), and the rule that a bar is fixed before the value it judges has been
seen is checked by `fiddlybits-52v.8.2`. A tier-1 entry is judged by the testset named
by its id on every commit whether or not it is registered, and a provisional entry
blocks no milestone gate.

| id | right answer | the mutation that must make it fail |
| --- | --- | --- |
| `build.module_order_acyclic` | the include order of `src/Fiddlybits.jl` is a topological order of the inter-module reference graph recovered from the source | a fixture pair of modules with a back reference, which must be reported; a clean fixture with a forward reference, which must not, so the check is non-vacuous in both directions |
| `build.import_record_completeness` | every non-stdlib entry of `Project.toml` has a record naming at least one leak check, and every named check resolves | a fixture project entry with no record, and a fixture record naming a test file that does not exist |
| `build.manifest_exclusions` | no excluded package name appears in the resolved `Manifest.toml` | a fixture manifest containing an excluded name, which must be refused |
| `build.lint_positive_controls` | every lint in the table flags its dirty fixture and passes its clean fixture | a table entry whose dirty fixture is absent, which must fail rather than pass vacuously |
| `build.load_latency` | `using Fiddlybits` completes inside the registered ceiling on the recorded host, the load and the preference state recorded beside it, with no preference turning the precompilation workload off and the workload landed in the image | the measurement judged against a ceiling below the measured value, which must FAIL; a preferences file turning a workload switch off, which must be refused, and one turning neither off, which must not be; a package on the load path that nothing loads, which must read as not precompiled; a method the workload does not call, which must carry no cached specialization |

`build.load_latency` is the only one of the five that measures rather than decides,
and it carries the registry's own rule: its threshold stays provisional until the
scatter of the measurement on the recorded host is a dated finding, because a bar
narrower than its instrument's scatter is refused at registration. That scatter is
`notes/findings/2026-09-11-load-latency-instrument.md`, and it found a second reason
beside the empty package: neighbours on the memory system move the number by many
times the quiet range, so what the recorded load licenses has to be settled before a
bar applies. That is `fiddlybits-52v.1.8`.

## Rows filed

| row | tier | boundary | acceptance |
| --- | --- | --- | --- |
| 52v.1.2 | local | `Project.toml`, `Manifest.toml`, `src/Fiddlybits.jl`, `src/<submodule>/<submodule>.jl` for each row of the table, `src/Verdicts/`, `test/runtests.jl`, `test/build/`, `bench/` | `using Fiddlybits` succeeds under the pinned Julia; the empty suite runs; `build.module_order_acyclic` passes with both fixtures deciding it |
| 52v.1.7 | local | `Project.toml`, `Manifest.toml`, `test/runtests.jl`, `test/build/`, `test/verdicts/` | the corrections of this plan's review applied to the merged skeleton: suite discovery, `Test` as an extra, the closed-set check; the suite runs green |
| 52v.1.3 | sonnet | `test/lint/` | `build.lint_positive_controls` and `build.manifest_exclusions` pass, each fixture named; the tree passes every lint or each site it flags is filed as a row |
| 52v.1.4 | sonnet | `test/imports/` | `build.import_record_completeness` runs with both fixtures refused; the checks that do not yet resolve are listed by name against the owner table above, and every listed one has an owning row |
| 52v.1.5 | sonnet | none; reports only | all five oracles ran on the merged result with every area verify row it depends on closed; verdicts by name; a dated finding for `build.load_latency` with the A/A scatter and the host |
| 52v.1.6 | frontier | the CI configuration and any runner scripts | see the row |
| 52v.1.8 | frontier | `docs/oracles/`, `test/gate/` | a stated rule for what the load recorded beside `build.load_latency` licenses, with its positive control; the entry carries a threshold whose condition is stated, or is declared REPORT with the argument in it |
| 52v.1.9 | local | `test/gate/`, `docs/imports/precompiletools.md`, the workload comment in `src/Fiddlybits.jl` | `build.load_latency` performs the three checks the PrecompileTools record names it for, each with a clean and a dirty arm, and the record states what it does |
| 52v.11 | frontier | filed against the epic, not this plan | see the row |
