+++
epic = "fiddlybits-52v.3"
title = "The typed field, the closed semantics vocabularies, the declared refusal table, and the ledgers"
decisions = ["0006", "0009", "0010", "0029", "0038"]
requirements = ["REQ-TER-001", "REQ-TER-009", "REQ-NUM-004", "REQ-SYS-103"]
oracles = ["mesh.constant_field_reduction", "mesh.vector_round_trip", "ledger.closure", "fields.semantics_closure", "fields.dimension_refusal", "fields.adapt_roundtrip",
           "fields.inference_tight"]
status = "filed"
date = 2026-09-10
+++

## Scope

This plan builds the value every component reads and writes: `Field{S,T,D,L,A}` with
its semantics, time semantics and dimension on the type, the operators that dispatch
on them, the refusal table for the combinations that have no meaning, and the ledger
every operator returns beside its result.

The design claim it has to make true is that an undeclared reduction is a red build
rather than a runtime surprise. Julia gives a missing method as a `MethodError` at
call time, which is exactly the failure this design exists to prevent, so the
enumeration test and the static pass are not extras here: they are what raises a
convention to a rule.

It does not build the store, which reads a field's provenance and refuses an open
ledger; that is `fiddlybits-52v.6`. It does not build the mesh or the reductions it
calls, and it declares neither: `Fields` reads the layout convention from `Backends`
and the error bound from `Reductions` rather than restating either, because a
convention restated in two places is two conventions.

## Module boundaries

| path | holds | row |
| --- | --- | --- |
| `src/Dimensions/` | `Dim{M,L,T,Theta,N}`, its algebra, the DynamicQuantities door | 52v.3.2 |
| `src/Fields/field.jl` | `Field`, the two closed vocabularies, `Origin` by value | 52v.3.2 |
| `src/Fields/reduce.jl` | `coarsen`, `refine`, `time_reduce`, the refusal table | 52v.3.3 |
| `src/Fields/vectors.jl` | the basis lifts and projections, edge-normal support | 52v.3.5 |
| `src/Fields/ledger.jl` | `Ledger{Q}`, `closed`, the loss inventory | 52v.3.6 |
| `test/dimensions/` | the dimension algebra suite and the door's refusals | 52v.3.2 |
| `test/fields/dimension_refusal.jl` | the leak test `docs/imports/dynamicquantities.md` names, at the path that record and the skeleton plan's owner table both give | 52v.3.2 |
| `test/fields/` | the field suites, the enumeration test, `adapt_roundtrip.jl` | 52v.3.2 to 52v.3.6 |
| `test/fields/inference.jl` | the `@inferred` walk riding the enumeration | 52v.3.4 |
| `test/fields/static_pass.jl` | the nightly JET pass and its accepted-findings TOML | 52v.3.8 |
| `test/gate/inference_cost.jl` | the walk's wall time and its `Dim` signature count | 52v.3.9 |

`Dimensions` is its own submodule rather than a file of `Fields` because the skeleton
plan put it in group A, below everything that reads it, and `Systems` reads it for the
dimension a disposition carries. It references `Verdicts` and nothing else, which is
what every module does for the one refusal type. `Fields` references `Mesh`, `Backends`,
`Reductions`, `Dimensions`, `Time` and `Verdicts`.

`TimeSupport` is declared in `src/Time/support.jl` and not here. It is built from
`Interval` and the `TimeSemantics` types, both of which `Time` owns, and `Time` sits
below `Fields`, so declaring it here would be a second definition of it rather than a
reading of the one that exists. `Fields` carries one in every `Field` and declares
none. Filled by `fiddlybits-52v.5.2`.

## Types and functions

```
Field{S<:Semantics, T<:TimeSemantics, D<:Dim, L, A<:AbstractArray}
    data     (ncells(L), extra...) raw floats, device or host
    support  Support{L} from Mesh; shape is never identity
    time     TimeSupport from Time, holding T and where T places it on the clock
    origin   Origin, carried by value
```

`Origin` is a plain value type declared here: a content key as bytes, the one writer
as a symbol, the parameter-subset hash as bytes, and the run id. It holds no type
from `Provenance`, which sits above this module and would close a cycle, and it is
not named `Provenance`, because a struct sharing a name with the module that fills
it is a reader's trap. `Provenance` computes the values and stamps them; `Fields`
only carries them.

A `Field` cannot be constructed without all four of semantics, time semantics,
dimension and support. There is no positional constructor that takes an array alone,
because the whole design is that those four travel with the numbers.

### The closed vocabularies

`Semantics`: `Extensive`, `Intensive`, `FluxDensity`, `Fraction`,
`CategoricalLabel{Legend}`, `CategoricalFraction{Legend}`, `VectorComponent{Basis}`,
`Quantiles{P}`.

`TimeSemantics`: `Static`, `Instantaneous`, `IntervalMean`, `IntervalAccumulation`,
`EndpointState`.

Both are closed the way the verdict vocabularies and the dispositions are closed, by
an enumeration a test checks. `Time` declares the `TimeSemantics` types and `Fields`
declares `time_reduce` over them, which is the split the skeleton plan made to break
the cycle; the enumeration test therefore reads `Time`'s enumeration and asserts it
against the methods declared here.

A `CategoricalLabel` reads its legend from the artifact and never an integer code,
and is never centre-sampled. A `Quantiles{P}` table is a table and not a moment: it
cannot be re-aggregated or refined, and the share of a cell past a threshold is read
out of it through `area_fraction_above`, which `Reductions` owns as the exact inverse
of the quantile rather than an interpolation of it.

### The operators and the refusal table

Every operator that changes support, time support or dimension dispatches on the type
parameters, and a combination that has no meaning has no method. The refusal table is
declared data, not scattered `error` calls, so that the enumeration test can read it:

| combination | refusal |
| --- | --- |
| `coarsen(Intensive)` with no rule named | the caller names what a coarse cell is: an area mean, a masked mean, or a quantile table |
| `coarsen(VectorComponent{:east_north})` | lift to `:cartesian` at the source frames first, because east at one longitude is not east at another |
| `coarsen(Quantiles)` | a quantile table is not re-aggregable; recompute from the fine field |
| `refine(Quantiles)` | the same |
| `refine(CategoricalFraction)` | a histogram does not carry which child held which class |
| `time_reduce(Instantaneous)` with no sampling rule | an instantaneous value has no interval to reduce over |
| any binary operation across mismatched `Support` | `Mesh` raises it, naming both identities |
| any binary operation across mismatched `Dim` | the dimension algebra raises it, naming both signatures |

`coarsen(Extensive)` is a segmented sum; `coarsen(FluxDensity)` and
`coarsen(Fraction)` are area-weighted means so the integral is conserved;
`coarsen(CategoricalLabel)` is a histogram into `CategoricalFraction`. Each calls
`Reductions` and names the measure it integrates over, per REQ-TER-011: no call here
passes an unqualified "area".

**Making a missing method a build failure.** The enumeration test walks every
`Semantics` subtype against `coarsen`, `refine`, `time_reduce` and `remap_vector`,
and asserts each pair either has a method or appears in the refusal table. Its
positive control is a fixture semantics type added with neither, which must fail. A
static analysis pass over the component code paths reports unresolved calls, and that
pass is wired into the suite rather than run by hand.

The static pass is JET.jl, which is not a dependency today and has no import record.
It does not run per commit and it is not wired by the enumeration's row; both are
settled in the next section, and `fiddlybits-52v.3.8` carries it.

### Inference, and what it costs

Four parameters on a wrapper is the shape that goes wrong twice: as compiler latency,
and as a silent drop to a non-concrete return that costs nothing visible on the host
and everything on the device. Both are named here rather than left to the reader.

**What the design already refuses.** The element type is a plain float. Decision 0006
lost units on the element type on exactly these grounds, so a kernel body receives a
bare device array and never a parameterised scalar, which is the thing that would
refuse to compile at all. Broadcast is a narrow door that closes only over identical
parameters, so no expression carries a parameter change through the broadcast
machinery; an operation that changes dimension or support is a named operator
returning a field and a ledger. `docs/imports/dimensionaldata-jl.md` records the
prototype that showed the four parameters surviving host and device broadcast, and the
one less-specific combination method that turns a mismatch into a named refusal rather
than an `Unknown()` style. A prototype that is not a test is a claim that decays, so
the assertion below is what carries it forward.

**What is asserted, and where.** Every operator's return type is concrete, asserted
with `@inferred` over the pairs the semantics-closure walk already produces. Riding
that walk rather than a hand-written list is the whole point: completeness is by
construction, and a semantics type added later carries the assertion without anyone
remembering to add it. The positive control is a fixture operator that selects its
semantics from a runtime value, which must fail. `@inferred` costs the inference the
first call was going to pay anyway, so this arm stays on the per-commit gate.

**The suite's own cost is the instrument.** Walking the enumeration compiles every
combination it asserts on, which is the combinatorial cost of the four parameters paid
deliberately in one place where it is visible rather than spread across a run. Its
wall time is therefore the specialisation measurement, and one thing is built, not
two. That number is an instrument before it is a bar, so it follows
`build.load_latency`: a recorded measurement with its host, its load and its A/A
scatter, and no threshold until the scatter is known, because a bar narrower than its
instrument's scatter is refused at registration (decision 0029). The combinatorial
source is not either closed vocabulary, both of which are small and enumerable. It is
`Dim{M,L,T,Theta,N}`, whose five integer exponents are open, so the count to report
beside the time is the number of distinct dimension signatures the walk instantiates.

**The static pass is the expensive half and does not run per commit.** JET's
optimisation mode runs its own abstract interpreter outside Julia's native inference
cache. It runs on the nightly row of decision 0043, which exists for whatever is too
slow per commit, and two conditions hold on wiring it, both because it reads compiler
internals. The Julia version it was run against is recorded beside its result, since a
version bump can move its findings with no change to this code. And its
accepted-findings list is ruled before the pass exists, because the mode flags benign
things: dispatch on error paths, printing, boxed closure variables. An unruled
allowlist is the shape this project already refused once, in `strict_broadcast!`:
state that makes a check pass without the thing being checked. The rule is that no
entry joins the list without a named reason and the row that removes it, the list is
TOML beside the pass rather than code, and a list that cannot be held to that means
the pass is scoped too widely. Whether that rule generalises past JET, and so wants a
decision record rather than a paragraph here, is open and is not settled by this plan.

**The device arm degrades loudly.** The GPU compiler refuses dynamic dispatch outright
rather than falling back to it, so the failure this section guards against is
host-side and the device needs no equivalent instrument. That behaviour is relied on
and is recorded in neither `docs/imports/cuda.md` nor `docs/imports/kernelabstractions.md`;
`fiddlybits-52v.3.10` anchors it, and if the refusal turns out narrower than this
argument needs, that row says so and files what changes the argument.

### Vectors

Only the Cartesian basis may change support. An east-north field is lifted to
Cartesian at the source geometry's local frames and projected at the destination's.
The edge-normal basis exists for the C-grid of decision 0013 and is where the
dynamical core's prognostic velocity lives.

`transform` is the strict conversion and `project` the lossy one, named separately so
that dropping a component has to be asked for by name. That pairing is borrowed from
ClimaCore.jl (`docs/imports/climacore-jl.md`), which is the only thing borrowed here.

### Ledgers

`Ledger{Q}` carries the balance of one conserved quantity across one operation, with
an inventory of what was lost and to where. Every operator returns `(field, ledger)`,
and the store refuses a field whose ledger is open.

The tolerance is `k * N * eps * M`, derived from floating point and read from
`Reductions` rather than declared here, so a ledger tolerance has one definition
(REQ-NUM-004, REQ-SYS-103).

A quantity declared a reservoir is accumulated in FP64 or by compensated summation
whatever the working precision, and a ledger given an FP32 accumulator for a
reservoir refuses naming the quantity. The declaration is a field-level one, so the
refusal is here and not in `Reductions`, which cannot see it; `Reductions` provides
the choice by taking the accumulator type explicitly. A tolerance chosen per ledger is what let the
predecessor's nitrogen closure be judged against a bar larger than the quantum of the
column it differenced.

A residual's time signature is classified rather than reported as a number: linear
growth is a leak, a constant offset is a stock omitted from the inventory, and a
random walk of rounding size is rounding. The three have different fixes, and the
report names the class.

## Oracles

Three registry entries exist and belong to this plan rather than to the mesh's:
`mesh.constant_field_reduction`, `mesh.vector_round_trip` and `ledger.closure`. Three
are added, two of them the leak tests the import records name and the harness
currently reports unresolved.

| id | right answer | the mutation that must make it fail |
| --- | --- | --- |
| `mesh.constant_field_reduction` | a constant field coarsens to the constant; an extensive integral is preserved | a sum weighted by cell count rather than by area, which the 1.3 to 1.4 area variation of decision 0005 must expose |
| `mesh.vector_round_trip` | solid-body rotation lifted at the source and projected at the destination returns itself | a coarsen applied to east-north components directly, which must refuse rather than return a plausible field |
| `ledger.closure` | every ledger's residual within one derived bound unit, with its signature classified | a flux counted twice, whose residual must grow linearly and be classified a leak |
| `fields.semantics_closure` | every semantics type against every operator has a method or a declared refusal | a fixture semantics type with neither, which must fail the enumeration |
| `fields.dimension_refusal` | a binary operation across mismatched dimensions refuses, naming both signatures | an addition of a length to a time, which must refuse rather than promote |
| `fields.adapt_roundtrip` | every registered field type adapts to the device and back unchanged | a struct whose adapt rule drops its support, which must be caught |
| `fields.inference_tight` | every operator over every enumerated pair returns a concrete type | a fixture operator that picks its semantics from a runtime value, which must fail `@inferred`; and an accepted-findings entry with neither a reason nor a row, which must fail the nightly pass |
| `build.inference_suite_cost` | no right answer yet: a recorded measurement of the enumerated walk with its host, its load and its distinct `Dim` signature count | the measurement judged against a ceiling below the measured value, which must FAIL |

`fields.inference_tight` carries two arms in one entry, a per-commit `@inferred` walk
and a nightly static pass, because they assert the same thing at two costs and
splitting them would make one of them look optional. `build.inference_suite_cost` is
an instrument rather than a bar and sits in the build section beside
`build.load_latency`, which it follows in shape.

`fields.dimension_refusal` and `fields.adapt_roundtrip` are named by
`docs/imports/dynamicquantities.md` and `docs/imports/adapt.md` as their leak tests,
so closing this plan's rows is what makes `build.import_record_completeness` resolve
for those two dependencies.

## Rows filed

| row | tier | boundary | acceptance |
| --- | --- | --- | --- |
| 52v.3.2 | sonnet | `src/Dimensions/`, `src/Fields/field.jl`, `test/dimensions/`, `test/fields/field.jl`, `test/fields/dimension_refusal.jl`, `test/fields/adapt_roundtrip.jl` | a `Field` cannot be constructed without all four parameters; the dimension algebra identities hold; `fields.dimension_refusal` and `fields.adapt_roundtrip` pass with their controls; every constructor and every dimension-algebra operation returns a concrete type under `@inferred` |
| 52v.3.3 | sonnet | `src/Fields/reduce.jl`, `test/fields/reduce.jl` | `mesh.constant_field_reduction` passes with its control; every refusal in the table raises with its sentence; every method of `coarsen`, `refine` and `time_reduce` returns a concrete type under `@inferred` |
| 52v.3.4 | sonnet | `test/fields/semantics_closure.jl`, `test/fields/inference.jl` | `fields.semantics_closure` passes and the fixture type with neither method nor refusal fails it; `fields.inference_tight` passes on its per-commit arm and the fixture operator that picks its semantics from a runtime value fails it; both walks read the same enumeration and neither carries a hand-written list of pairs |
| 52v.3.5 | sonnet | `src/Fields/vectors.jl`, `test/fields/vectors.jl` | `mesh.vector_round_trip` passes with its control; `transform` and `project` are separate names and the lossy one is never reached implicitly; both return concrete types under `@inferred` |
| 52v.3.6 | sonnet | `src/Fields/ledger.jl`, `test/fields/ledger.jl` | `ledger.closure` passes; an injected leak is detected and classified a leak rather than rounding; the tolerance is read from `Reductions` and not declared here; an FP32 accumulator for a declared reservoir refuses naming the quantity; the `(field, ledger)` pair every operator returns is concrete under `@inferred` |
| 52v.3.7 | sonnet | none; reports only | all seven oracles ran; verdicts by name; `build.inference_suite_cost` reports its number beside them rather than a verdict, being an instrument |
| 52v.3.8 | sonnet | `docs/imports/jet-jl.md`, `test/fields/static_pass.jl` and its accepted-findings TOML, the JET entry in `Project.toml` extras and `Manifest.toml` | JET has an import record naming a leak test that exists, so `build.import_record_completeness` stays whole; `report_call` reports no unresolved call and `report_opt` no non-concrete return on the operators; the accepted-findings list is TOML with a reason and a row per entry, and an entry with neither fails the pass; the pass is on the nightly row and the Julia version is recorded beside its result |
| 52v.3.9 | sonnet | `test/gate/inference_cost.jl`, the finding it writes, the `threshold` field of the `build.inference_suite_cost` entry | the A/A scatter of the instrument is measured and written as a dated finding with its host, its load and its sample count; the distinct `Dim` signature count is reported beside the time; the entry carries the finding by path and still carries no threshold |
| 52v.3.10 | local | `docs/imports/cuda.md`, `docs/imports/kernelabstractions.md`, the leak test those records name | both records state what the device compiler refuses and what it does not, with the locator read; the leak test exists and fails on a kernel with a deliberately non-concrete call |

52v.3.3, 52v.3.5 and 52v.3.6 depend on 52v.3.2; 52v.3.4 depends on 52v.3.3 and
52v.3.5; 52v.3.8, 52v.3.9 and 52v.3.10 depend on 52v.3.4, and 52v.3.7 depends on
52v.3.8 because the nightly arm of `fields.inference_tight` is part of the set it
reports. 52v.3.10 touches two records the closed `fiddlybits-52v.7` wrote, which is
why it is a row here rather than a reopening there: the claim is relied on by this
plan's argument, and the records are live documents.

The area's own rows are not the whole order. 52v.3.2 depends on
`fiddlybits-52v.5.2`, which declares the `TimeSemantics` enumeration this module
dispatches over, and on `fiddlybits-52v.7.2`, which declares the `(cells, levels)`
layout convention and the `Adapt` rules `fields.adapt_roundtrip` exercises. 52v.3.3
depends on `fiddlybits-52v.7.3` for the segmented sum and mean and on
`fiddlybits-52v.7.5` for the segmented quantile and `area_fraction_above`. 52v.3.6
depends on `fiddlybits-52v.7.3` for the `k * N * eps * M` bound and for the explicit
accumulator type the reservoir refusal is written against. The mesh's `Support` is
already merged. The board carries the same edges.
