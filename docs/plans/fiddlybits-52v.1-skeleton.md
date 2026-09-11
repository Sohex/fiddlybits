+++
epic = "fiddlybits-52v.1"
title = "The Julia package skeleton: submodule set and include order, the lint suite, the import harness, and the budgets"
decisions = ["0011", "0012", "0029", "0036", "0037", "0039", "0042"]
requirements = ["REQ-SYS-101", "REQ-SYS-102", "REQ-NUM-001", "REQ-NUM-008"]
oracles = ["build.module_order_acyclic", "build.import_record_completeness", "build.manifest_exclusions", "build.lint_positive_controls", "build.load_latency"]
status = "filed"
date = 2026-09-10
+++

## Scope

This plan builds the package that every other M0 plan writes into: the manifest of
pinned dependencies, the one top-level module and the submodule files it includes,
the test tree, the benchmark tree, the precompilation workload, and the three checks
that guard the boundary between this project and its dependencies. It fixes the
submodule set and the include order, and it fixes them as a testable property rather
than as a convention, because the include order of a Julia module is its dependency
order and nothing in the language enforces that the two agree.

It does not write physics, geometry, fields or constants. Every submodule this plan
creates is a module declaration with nothing in it; the area plan named against each
one fills it. A submodule whose area has no M0 plan is not created here.

Two things are deliberately left:

- **The coupling layer of decision 0009** (`WorldState`, `assemble`, `Exchange`,
  `FixedPointLoop`, `Ladder`) has no row anywhere on the board and no submodule here.
  It is an interface every component reaches, so it wants to exist before the first
  component does, but the M0 deliverable of decision 0034 does not name it and this
  plan does not add it to a milestone on its own authority. Carried by
  `fiddlybits-52v.11`.
- **The two adopt candidacies of decision 0012**, ClimaTimeSteppers.jl and
  RootSolvers.jl, are not dependencies until their own decisions are taken, so
  neither appears in `Project.toml` here. `fiddlybits-52v.10` takes the second.

## Module boundaries

One top-level module, `Fiddlybits`, in `src/Fiddlybits.jl`, which contains nothing
but its includes. Each submodule is one directory under `src/` with a file of the
same name as its entry point.

The include order below is a topological order of the reference graph. Modules
within one group do not reference each other, and their relative order is free.

| group | submodule | holds | filled by |
| --- | --- | --- | --- |
| A | `Verdicts` | the closed verdict vocabularies and the refusal type | 52v.1.2 (complete here) |
| A | `Dimensions` | `Dim{M,L,T,Theta,N}` and its algebra over DynamicQuantities | 52v.3 |
| A | `Time` | `SimTime`, `Interval`, `duration`, `TimeSupport`, the `TimeSemantics` types | 52v.5 |
| A | `EarthRatios` | the quarantined unit denominators | 52v.4 |
| B | `Dispositions` | `Sourced`, `Derived`, `Bracketed`, `Irreducible`, `Closure` | 52v.4 |
| B | `Backends` | the KernelAbstractions device layer, `Adapt`, `on`, the memory budget | 52v.7 |
| C | `Systems` | `System{FT}`, `strip`, `TrackingSystem`, `affected` | 52v.4 |
| C | `Reductions` | fixed-order pairwise and compensated sums, segmented reductions, quantiles | 52v.7 |
| D | `Orbit` | the Kepler solve, true anomaly, declination, hour angle, the epoch rule | 52v.5 |
| D | `Mesh` | `Support{L}`, bisection, numbering, geometry, stencils, local refinement | 52v.2 |
| E | `Fields` | `Field{S,T,D,L,A}`, `Semantics`, `coarsen`, `refine`, `time_reduce`, `Ledger` | 52v.3 |
| F | `Instellation` | per-cell flux from every declared star, eclipse geometry | 52v.5 |
| F | `Connectivity` | the connectivity graph derived from a terrain-level field | 52v.2 |
| F | `Provenance` | `ArtifactKey`, `CodeVersion`, `RunID`, the Zarr store, the journal, the RNG | 52v.6 |
| G | `Oracles` | the registry loader, the identity oracles, the mutation harness | 52v.8 |
| G | `Render` | calendar rendering and NetCDF export, and nothing else | 52v.5, 52v.6 |

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

`Verdicts` is filled here rather than by an area plan because the lint suite and the
import harness are the first callers that must refuse, and every later module raises
the same refusal type.

### The test tree

`test/runtests.jl` includes one file per group below. A test file lives beside the
area it tests, and the leak tests the import records name are the paths those
records already carry.

| path | holds |
| --- | --- |
| `test/lint/` | the source lints, their fixtures, and the manifest check |
| `test/imports/` | the import-record harness |
| `test/<area>/` | the area suites, one directory per submodule, created by its own row |
| `test/planets/` | the system test instances (`fiddlybits-52v.4.5`) |

Every lint lives in `test/lint/`, under the name the import record that declared it
carries, so a record and a suite name one file. The records are live documents and
the review is repeated when a pin moves, so a path that moves is rewritten in the
record rather than recorded beside it.

## Types and functions

`src/Fiddlybits.jl` declares `module Fiddlybits`, includes each submodule file in
the order of the table, and declares nothing else. No submodule is re-exported: a
caller names the module it reads from, so that a quantity has one door and the door
says where it leads.

`Verdicts` declares, as closed sets with no fallback constructor:

- `LoopVerdict`: `Converged`, `Bracketed`, `Refused`, `NotEvaluable`, `BudgetExhausted`
  (decision 0009).
- `OracleVerdict`: `FAIL`, `REPORT`, `PASS` (decision 0025).
- `Refusal`, carrying the quantity, the reading site and the reason, and
  `refuse(reason, site)` which raises it. A refusal names what was read and where;
  it never carries a substitute value.

`test/lint/` declares one function per lint, each taking a root path and returning
the offending sites, so that a lint is called on a fixture and on the tree by the
same function. A lint that returns sites on the clean fixture, or none on the dirty
one, fails the suite. The lints:

| lint | refuses | declared by |
| --- | --- | --- |
| `lint_earth` | a named physical constant of the DynamicQuantities registry, and any member of `EarthRatios`, outside `EarthRatios` and `Render` | REQ-SYS-101, `docs/imports/dynamicquantities.md` |
| `lint_literals` | an untyped float literal in a kernel or a physics module | REQ-NUM-001, `docs/imports/julia-1.12.md` |
| `lint_index_base` | `+ 1` or `- 1` applied to a cell index, at the host boundary or in a kernel | `docs/imports/kernelabstractions.md` |
| `lint_calendar` | any `Dates` type reaching a physics module or the store writer | REQ-SYS-102, `docs/imports/ncdatasets.md` |
| `lint_journal_emitter` | a write to the run journal path from outside `src/Provenance/journal.jl` | decision 0042 |
| `lint_effort` | schedule, person-week, line-count or MVP framing anywhere under `docs/` | `docs/practice.md` |
| `lint_front_matter` | a record under `docs/` whose header is not TOML, or lacks a required key | decision 0036 |
| `lint_manifest` | a package named in the exclusion list appearing anywhere in the resolved `Manifest.toml` | `docs/imports/fastpower-jl.md` |

`lint_manifest` reads the dependency graph rather than the source, because the
hazard it catches arrives transitively and no call site would show it. Its exclusion
list is a TOML file beside the suite, one entry per excluded package naming the
import record that excluded it; an entry with no record fails.

`test/imports/` declares `import_records()`, which reads the non-stdlib entries of
`Project.toml`, and asserts of each that a record exists at
`docs/imports/<name>.md`, that the record names a leak test, and that the named
test file exists and runs. The direction matters: the check reads the dependency
list and looks for records, never the reverse, because `docs/imports/` also holds
records of packages that were surveyed and refused, and those have nothing to test.

## Oracles

Five entries, added to `docs/oracles/registry.toml` by this plan under a new
`build` subsystem, all tier 1, all provisional until this plan's rows merge.

| id | right answer | the mutation that must make it fail |
| --- | --- | --- |
| `build.module_order_acyclic` | the include order of `src/Fiddlybits.jl` is a topological order of the actual inter-module reference graph, recovered by parsing each submodule for references to the others | a fixture pair of modules with a back reference, which must be refused |
| `build.import_record_completeness` | every non-stdlib entry of `Project.toml` has a record naming a leak test that exists and runs | a fixture project entry with no record, and a record naming a test file that does not exist |
| `build.manifest_exclusions` | no excluded package name appears in the resolved `Manifest.toml` | a fixture manifest containing an excluded name, which must be refused |
| `build.lint_positive_controls` | every lint flags its dirty fixture and passes its clean fixture | a lint whose dirty fixture is removed, which must fail rather than pass vacuously |
| `build.load_latency` | `using Fiddlybits` completes inside the declared ceiling on the recorded host | the ceiling is not registered until the A/A scatter of the measurement is known (decision 0029) |

`build.load_latency` is the only one of the five that measures rather than decides,
and it carries the registry's own rule: its threshold stays provisional until the
scatter of the measurement on the recorded host is a dated finding, because a bar
narrower than its instrument's scatter is refused at registration.

## Rows filed

| row | tier | boundary | acceptance |
| --- | --- | --- | --- |
| 52v.1.2 | local | `Project.toml`, `Manifest.toml`, `src/Fiddlybits.jl`, `src/<submodule>/<submodule>.jl` for each row of the table, `src/Verdicts/`, `test/runtests.jl`, `bench/` | `using Fiddlybits` succeeds under the pinned Julia; the empty suite runs; `build.module_order_acyclic` passes with its fixture refused |
| 52v.1.3 | sonnet | `test/lint/` | `build.lint_positive_controls` and `build.manifest_exclusions` pass, each fixture named |
| 52v.1.4 | sonnet | `test/imports/` | `build.import_record_completeness` passes, both fixtures refused |
| 52v.1.5 | sonnet | none; reports only | all five oracles ran; verdicts by name; a dated finding for `build.load_latency` |
| 52v.11 | frontier | filed against the epic, not this plan | see the row |
