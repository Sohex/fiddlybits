+++
epic = "fiddlybits-52v.3"
title = "The typed field, the closed semantics vocabularies, the declared refusal table, and the ledgers"
decisions = ["0006", "0009", "0010", "0029", "0038"]
requirements = ["REQ-TER-001", "REQ-TER-009", "REQ-NUM-004", "REQ-SYS-103"]
oracles = ["mesh.constant_field_reduction", "mesh.vector_round_trip", "ledger.closure", "fields.semantics_closure", "fields.dimension_refusal", "fields.adapt_roundtrip"]
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
| `src/Fields/field.jl` | `Field`, the two closed vocabularies, `TimeSupport`, `Origin` by value | 52v.3.2 |
| `src/Fields/reduce.jl` | `coarsen`, `refine`, `time_reduce`, the refusal table | 52v.3.3 |
| `src/Fields/vectors.jl` | the basis lifts and projections, edge-normal support | 52v.3.5 |
| `src/Fields/ledger.jl` | `Ledger{Q}`, `closed`, the loss inventory | 52v.3.6 |
| `test/dimensions/` | the dimension suite and `dimension_refusal.jl` | 52v.3.2 |
| `test/fields/` | the field suites, the enumeration test, `adapt_roundtrip.jl` | 52v.3.2 to 52v.3.6 |

`Dimensions` is its own submodule rather than a file of `Fields` because the skeleton
plan put it in group A: it references nothing, and `Systems` reads it for the
dimension a disposition carries. `Fields` references `Mesh`, `Backends`,
`Reductions`, `Dimensions`, `Time` and `Verdicts`.

## Types and functions

```
Field{S<:Semantics, T<:TimeSemantics, D<:Dim, L, A<:AbstractArray}
    data     (ncells(L), extra...) raw floats, device or host
    support  Support{L} from Mesh; shape is never identity
    time     TimeSupport{T}, t0 and t1 in SI seconds
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
It enters as a test-time extra, and the import harness checks extras, so the row that
wires it writes `docs/imports/jet-jl.md` first with the leak test the record names.
That makes the row a survey with judgement rather than a transcription, so it is
sonnet tier and not local.

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

`fields.dimension_refusal` and `fields.adapt_roundtrip` are named by
`docs/imports/dynamicquantities.md` and `docs/imports/adapt.md` as their leak tests,
so closing this plan's rows is what makes `build.import_record_completeness` resolve
for those two dependencies.

## Rows filed

| row | tier | boundary | acceptance |
| --- | --- | --- | --- |
| 52v.3.2 | sonnet | `src/Dimensions/`, `src/Fields/field.jl`, `test/dimensions/`, `test/fields/field.jl`, `test/fields/adapt_roundtrip.jl` | a `Field` cannot be constructed without all four parameters; the dimension algebra identities hold; `fields.dimension_refusal` and `fields.adapt_roundtrip` pass with their controls |
| 52v.3.3 | sonnet | `src/Fields/reduce.jl`, `test/fields/reduce.jl` | `mesh.constant_field_reduction` passes with its control; every refusal in the table raises with its sentence |
| 52v.3.4 | sonnet | `test/fields/semantics_closure.jl`, `docs/imports/jet-jl.md`, the JET entry in `Project.toml` extras and `Manifest.toml` | `fields.semantics_closure` passes; the fixture type with neither method nor refusal fails it; the static pass is wired into the suite; JET.jl has an import record naming a leak test that exists, so `build.import_record_completeness` stays whole |
| 52v.3.5 | sonnet | `src/Fields/vectors.jl`, `test/fields/vectors.jl` | `mesh.vector_round_trip` passes with its control; `transform` and `project` are separate names and the lossy one is never reached implicitly |
| 52v.3.6 | sonnet | `src/Fields/ledger.jl`, `test/fields/ledger.jl` | `ledger.closure` passes; an injected leak is detected and classified a leak rather than rounding; the tolerance is read from `Reductions` and not declared here; an FP32 accumulator for a declared reservoir refuses naming the quantity |
| 52v.3.7 | sonnet | none; reports only | all six oracles ran; verdicts by name |

52v.3.3, 52v.3.5 and 52v.3.6 depend on 52v.3.2; 52v.3.4 depends on 52v.3.3 and
52v.3.5. The whole area depends on the mesh's `Support` and on the kernel layer's
reductions.
