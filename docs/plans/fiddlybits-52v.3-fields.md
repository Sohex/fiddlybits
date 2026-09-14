+++
epic = "fiddlybits-52v.3"
title = "The typed field, the closed semantics vocabularies, the declared refusal table, and the ledgers"
decisions = ["0006", "0009", "0010", "0029", "0038"]
requirements = ["REQ-TER-001", "REQ-TER-009", "REQ-NUM-004", "REQ-SYS-103"]
oracles = ["mesh.constant_field_reduction", "mesh.vector_round_trip", "ledger.closure", "fields.semantics_closure", "fields.dimension_refusal", "fields.adapt_roundtrip",
           "fields.inference_tight", "kernels.body_types_concrete"]
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
| `src/Fields/reduce.jl` | `coarsen`, `refine`, `time_reduce`, `Measured`, the refusal table | 52v.3.3 |
| `src/Fields/vectors.jl` | the basis lifts and projections, edge-normal support | 52v.3.5 |
| `src/Fields/ledger.jl` | `Ledger{Q}`, `closed`, the loss inventory | 52v.3.6 |
| `test/dimensions/` | the dimension algebra suite and the door's refusals | 52v.3.2 |
| `test/fields/dimension_refusal.jl` | the leak test `docs/imports/dynamicquantities.md` names, at the path that record and the skeleton plan's owner table both give | 52v.3.2 |
| `test/fields/` | the field suites, the enumeration test, `adapt_roundtrip.jl` | 52v.3.2 to 52v.3.6 |
| `test/fields/inference.jl` | the `@inferred` walk riding the enumeration, on both backends | 52v.3.4, 52v.3.21 |
| `test/fields/static_pass.jl` | the nightly JET pass and its accepted-findings TOML | 52v.3.8 |
| `test/gate/inference_cost.jl` | the walk's wall time and its `Dim` signature count | 52v.3.9 |
| `test/backends/body_types.jl` | the typed code of every kernel body at the signatures its launches compile, and every kernel's device compilation | 52v.3.20 |

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
Field{S<:Semantics, T<:TimeSemantics, D<:Dim, L, A<:AbstractArray, P}
    data     (cells, levels, extra...) raw floats, device or host
    support  Support{L} from Mesh; shape is never identity
    time     TimeSupport{T,P} from Time, holding T and where T places it on the clock
    origin   Origin, carried by value
```

`L` and `P` are there for one reason between them, and it is the reason decision 0006
already carries `L`. A `Field` holds a `Support{L}` and a `TimeSupport{T,P}`, and a
struct member whose type is not concrete is an inference hole at the centre of every
operator, which is what the inference section below exists to prevent. `L` makes the
first member concrete and `P` is the identical move for the second. `P` is fixed by `T`
through `Time.time_support_kind`, so no signature names it and `Field{S,T,D,L,A}` stays
what dispatch is written against: `coarsen(f::Field{Extensive,T,D,L}, ...)` is
unchanged. A sixth slot rather than folding the placement into `T`, because the two
parameters that carry almost every dispatch are the semantics and the time semantics,
and those stay top-level and positional.

`Origin` is a plain value type declared here: a content key as bytes, the one writer
as a symbol, the parameter-subset hash as bytes, and the run id. A field an operator has
just computed has a writer and a run and no key, so `Origin` carries its state as a
closed pair of names, and the key and the parameter hash of an unstamped origin are
refused rather than returned as the zeros it holds. That is where the declared absence
with a name that `docs/imports/dimensionaldata-jl.md` argued for belongs: on the state
that genuinely lacks a value, not at the device boundary, which turns out not to lack
one. It holds no type
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
| `refine(VectorComponent{:east_north})` | project at the destination frames instead, for the reason coarsening refuses them |
| `time_reduce(Instantaneous)` with no sampling rule | an instantaneous value has no interval to reduce over |
| `time_reduce(Static)` | a quantity with no time axis has no interval to reduce over, as `Time` already refuses it a duration |
| any binary operation across mismatched `Support` | `Mesh` raises it, naming both identities |
| any binary operation across mismatched `Dim` | the dimension algebra raises it, naming both signatures |
| any binary operation across mismatched `Semantics` | `Fields` raises it, naming what each side declares, with the parameter of a parametric one |
| any binary operation across mismatched `TimeSemantics` | the same |

`coarsen(Extensive)` is a segmented sum; `coarsen(FluxDensity)` and
`coarsen(Fraction)` are area-weighted means so the integral is conserved;
`coarsen(CategoricalFraction)` is the area-weighted mean of each class column, the
legend on the data's last axis, which conserves each class's area;
`coarsen(CategoricalLabel)` is a histogram into `CategoricalFraction` over the legend
the call names: the class-fraction coarsening of the labels' `Reductions.ClassIndicator`,
the one-hot of the labels over that legend, taken through the class shares and
class-area totals the fraction coarsening uses, so the two are doors to one definition.
The indicator is evaluated per cell inside one launch over every segment, column and
class, and neither the one-hot nor one class's indicator is ever built; the legend
positions a kernel compares exist only inside that type, for the length of one call
(`docs/plans/fiddlybits-52v.7-kernels.md`, section The reductions).
Each calls `Reductions` and names the measure it integrates over, per
REQ-TER-011: no call here passes an unqualified "area". The naming is a type,
`Measured{Name}`, which is a measure's values together with which measure they are,
from a closed pair. A reduction takes one of those and never a bare vector of weights,
so the requirement is carried by the signature rather than by a convention.

**An operator takes the destination support, not a level.** Decision 0006 sketches
`coarsen(f, ::Level{L2})`, and that cannot be built: the result is a `Field` and a
`Field` carries a `Support`, which needs the `Level`, the `Geometry` and the radius that
`Mesh` owns and this module does not. The destination support carries its level in its
type, so `coarsen(f::Field{Extensive}, to::Support{L2})` dispatches exactly as the
sketch does and the result's identity is the one the caller already built. What a
support cannot carry is ancestry, so the crossing compares what two levels of one
hierarchy share and `fiddlybits-52v.2.14` asks `Mesh` for a check that can.

**`time_reduce` runs over a contiguous series.** It reduces a `Time.Forcing` whose
values are fields: the contiguity of the intervals is checked where it is declared
rather than restated here, and the single value type a `Forcing` carries is what makes
every field in the series agree in semantics, dimension and support by construction. An
`IntervalMean` reduces by a duration-weighted mean, an `IntervalAccumulation` by a sum,
an `EndpointState` to the state at the last interval's end.

**A field carrying levels or components reduces every column in one launch.** Cells
are the first axis (`Backends.LAYOUT`), so a coarsening or refinement runs down the cell
axis of each column independently and keeps the trailing axes: `(cells, levels)` goes to
`(coarse cells, levels)` and `(cells, 3)` to `(coarse cells, 3)`. The reduction is a
segmented or pairwise reduction in `Reductions` that takes the cells-first array and
reduces every column in one launch, with the measure one value per cell, and it is not a
loop over columns at this boundary. Three forms were weighed. A loop over columns
calling the vector reductions launches one kernel per column and reads a host total per
column for every ledger total, so its launches and synchronisations grow with the
trailing extent; decision 0011 names launches as what binds a coupled run at its column
counts, and lays arrays out cells first so the vertical loop sits inside the thread,
which a loop outside the launch undoes. Nothing a caller sees would change on replacing
it, and that locality is its whole case. The vector reductions over the column-major
flattening of the array, with the block segmentation repeated once per column, launch
once and give each column the vector form's own bits, but a measure-weighted reduction
then needs the measure repeated to the size of the field, the temporary the size of its
input that `test/reductions/no_input_sized_temporary.jl` refuses, and a column's ledger
total is still one pairwise sum per column. The form taken costs new kernels with their
reference paths and edge-shape tests, and is the one whose launches, host reads and
temporaries stay fixed as the trailing extent grows; `fiddlybits-52v.7.59` built it. An
array whose cell count along its first axis is not the level's is refused by name rather
than reduced along another axis.

**Every mismatch refuses by name; none is left to be a `MethodError`.** A declared
refusal carrying a sentence is what this table is made of, and an absent method is the
table's failure state rather than its shape. A binary operator therefore checks its four
declarations in the order they sit on the type and names the first that differs, sending
the dimension to the algebra and the support to `Mesh` because each identity belongs to
the module that declares it.

That is one method per operator with the check at the top, and not a matching method
beside a less specific one. The two-method form was written first and does not work: a
signature naming only the parameters that must agree describes the same type as one
naming none, so the two carry equal specificity and the later definition wins whatever
the intent. It sent two identical fields to the refusing method. The broadcast case in
`docs/imports/dimensionaldata-jl.md` is genuinely different and keeps its two rules,
because there the two are not the same type: the equal-parameter rule constrains the
style's parameters and the unequal one does not.

**Making a missing method a build failure.** The refusal table is a tuple of entries
keyed by operator, semantics and time semantics, and every refusing method raises the
sentence it looks up rather than one written at the call. A method that refuses without
an entry is itself refused, which is what stops the table being bypassed by a method
that carries its own words. The enumeration test walks every
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
and as a silent drop to a type that is not concrete. The second still computes the
answer and reports nothing. Where the drop sits decides what it costs: in host code it is a dispatch per
call, and inside a kernel body it is paid per work item on whichever backend runs the
kernel. Both are named here rather than left to the reader.

**What the design already refuses.** The element type is a plain float. Decision 0006
lost units on the element type because mixed-unit arithmetic inside kernels multiplies
compile time and breaks library calls, so a kernel body receives a bare array of floats
and never a parameterised scalar. Broadcast is a narrow door that closes only over identical
parameters, so no expression carries a parameter change through the broadcast
machinery; an operation that changes dimension or support is a named operator
returning a field and a ledger. `docs/imports/dimensionaldata-jl.md` records the
prototype that showed the four parameters surviving host and device broadcast, and the
one less-specific combination method that turns a mismatch into a named refusal rather
than an `Unknown()` style. A prototype that is not a test is a claim that decays, so
the assertion below is what carries it forward.

**What is asserted, and where.** Every operator's return type is concrete, asserted
with `@inferred` over the pairs the semantics-closure walk already produces, each call
made on `Backends.CPU` and on `Backends.GPU`, because an operator on device arrays is
the same operator compiled at another array type (`fiddlybits-52v.3.21`). Riding
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

**What the device compiler refuses.** A launch on `Backends.GPU` compiles its kernel
for the device, and the compilation refuses a call left to runtime dispatch in the
device code, on the host and before anything is queued. What it refuses, what it
compiles, and the locators for both are in `docs/imports/cuda.md` and
`docs/imports/kernelabstractions.md`, section "Dynamic dispatch".
`test/backends/dispatch_refusal.jl` holds the refusal: its refused arms fail if the
device compiles such a call instead. That refusal is the one part of the device arm
that degrades loudly.

**What it does not refuse, and what catches each case.** The refusal judges the code
host inference hands it, at the signatures a device launch compiled. A drop to a type
that is not concrete therefore reaches it only as a dispatch that survives
optimisation. Every other case compiles, and none of them changes a value: in the
leak test every arm that compiles or runs on the CPU backend writes the known answer.
What they cost is time and allocation. That is why neither the reference-path
comparison of decision 0027 nor the backend agreement tests is named below, since
neither can fail on any of them. The cases are the ones the two records list under
"What is not refused".

- *A union that inference splits.* It compiles as branches taken per work item.
  `kernels.body_types_concrete` (`fiddlybits-52v.3.20`) reads the typed code of every
  kernel body at the signatures its launches compiled and fails on any value whose
  type is not concrete. A split union is its positive control.
- *A call that constant propagation folds.* No instrument is needed: once folded, the
  compiled code holds a constant of a concrete type, and nothing is left to cost
  anything. The same call at a site that does not fold is the split union above.
  `kernels.body_types_concrete` carries a folded call as a control that must pass.
- *A `Core.Box` that no call reads.* It compiles, and where the box survives
  optimisation the device allocates it per work item. `kernels.body_types_concrete`
  fails on the box's contents, and such a box is its second positive control.
- *Non-concreteness on the host side of a launch, a `Field` operator's return
  included.* The launch compiles at the runtime types of its arguments, so the device
  compiler never sees this case; it costs a host dispatch per call.
  `fields.inference_tight` catches it on both backends: the `@inferred` walk in
  `test/fields/inference.jl` per commit, and the static pass in
  `test/fields/static_pass.jl` nightly. The nightly pass has already failed on a case
  of this shape: `Backends.launch!`'s own dispatch, now carried by
  `fiddlybits-52v.3.19`.
- *A kernel launched only on `Backends.CPU`, or at a signature no device launch
  compiles.* The CPU backend runs a dispatch without validating anything, and the
  device refusal exists only where a device compilation happened.
  `kernels.body_types_concrete` reads the CPU function's typed code at the signatures
  CPU launches compiled, as well as the device function's, so a dispatch, a split
  union or a box fails it on either backend. It also fails when its test compiles a
  kernel the package defines for the device at no signature, and it launches each
  kernel at each precision that kernel is certified for. A signature a run launches
  and no test launches gets no instrument here. Its values are then checked by no test
  either, and decision 0027's comparison test for every kernel on every certified
  backend and precision is what closes that gap. A dispatch at such a signature is
  still refused at that launch.

### The device boundary, and why nothing is stripped

A `Field` is a host-side wrapper. Its array may live on either device and the wrapper
itself never enters a kernel: every kernel in this package takes bare arrays, and the
one struct decision 0011 passes to a kernel is the stripped constant block of decision
0007. An operator unwraps to the array at the launch, having discharged the four
declarations at compile time, because a kernel body never branches on whether a field is
`Extensive`.

So `Adapt.adapt_structure` for a `Field` converts the array and carries every other
member across unchanged, and `fields.adapt_roundtrip` asserts equality in every member
rather than in a subset. Nothing is dropped, so nothing has to be declared absent.

This supersedes the recommendation in `docs/imports/dimensionaldata-jl.md`, which
reasoned about a wrapper that crosses into the kernel and proposed a device field whose
provenance is a declared absence with a name. The reading in that record stands; the
recommendation does not apply here because its premise does not hold. Three members of a
`Field` could not cross in any case: `Mesh.Support` holds its kind and its element type
as symbols, and an `Origin` holds its writer as one. The conclusion is not to strip them
but to keep the wrapper on the host, where they cost nothing.

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

What sits beside the field is decided by what the semantics conserves across the
crossing, and is built in `src/Fields/reduce.jl` from `Float64` totals the operator takes
on the field's backend when it runs. An `Extensive` coarsening or refinement and an
`IntervalAccumulation` conserve the total and return `Ledger{:total}`, the source's total
against the result's. A `FluxDensity` or `Fraction` coarsening or refinement and an
`Intensive` coarsening under `AreaMean` conserve the integral under the named measure and
return `Ledger{:primal_cell_area_integral}` or `Ledger{:dual_area_integral}`, a coarse
cell holding the sum of its children's measure. An `IntervalMean` conserves the integral
over the duration and returns `Ledger{:duration_integral}`. A `CategoricalLabel`
coarsening or refinement conserves the area of each class and returns `ClassLedgers`
under the measure's name, one ledger per legend class, and refuses a label the legend
does not name. A quantile table, a spread `Intensive` or `VectorComponent{:cartesian}`
refinement and an `EndpointState` reduction conserve nothing a ledger closes and return
`NotConserved`, carrying the sentence `NOT_CONSERVED_TABLE` declares, which `closed`
refuses with. Every operator that returns a ledger takes `reservoir` as a required
keyword. Three alternatives were weighed. One ledger over a histogram's total area
closes whatever the histogram weighted by or dropped, since each coarse cell's shares
sum to one, so it could not fail on the breaks it exists for. `nothing` in the ledger
position of a non-conserving operator would make the store's check a `MethodError`
rather than a named refusal. Returning the field alone from those operators would give
two return shapes and let a caller of a conserving operator reach for the shape without
the ledger. `ClassLedgers` costs a consumer a third form beside `Ledger` and
`NotConserved`.

A field carrying levels or components conserves its quantity in each column, and an
operator on one returns `ColumnLedgers{Q}`: one `Ledger{Q}` per column in column-major
order with the trailing shape, each column's tolerance `error_bound` over that column's
own terms and magnitude, closed when every column is. A `CategoricalFraction` holds its
legend on its last axis, so its coarsening returns `ClassLedgers`, one per class, each
class's entry a `ColumnLedgers` when the field carries levels besides its legend. A
`time_reduce` over a series of such fields returns the same form as a crossing of them.
A field of one value per cell keeps its `Ledger`. Two alternatives were weighed. One
ledger over every column lets an error confined to one column hide under a tolerance
whose magnitude and term count grow with every column while the error does not. A total
ledger beside the column ledgers adds nothing a consumer can act on: every column
closing bounds the total's residual by the sum of the column tolerances, which is within
the total's own bound because `error_bound` is linear in the magnitude, so the total is a
derived summary of the columns. `ColumnLedgers` costs a consumer a fourth form beside
`Ledger`, `ClassLedgers` and `NotConserved`.

The tolerance is `error_bound(T, n, M)` over the reduction the operator ran: `T` its
accumulator, `n` its term count, the fine cells of a crossing or the cells times the
intervals of a time reduction, and `M` the `Float64` total of its terms' absolute
values. A refinement by spread runs no reduction, and its ledger's is its own `Float64`
sum over the fine cells. The residual is two evaluations of one exact total, so in the
model of Higham (1993, eq. 1.2, with 2.2 and 3.3) it is at most `gamma_D * M`, `D` the
rounded operations the two evaluations take a term through. A crossing of `b >= 4`
children under each of `Nc >= 20` coarse cells gives `D <= n + b + Nc + 2`, a mean's
coarse measure summed in the mean's own accumulator and order so its denominator cancels
from `after`; a time reduction over `K >= 2` intervals gives `D <= 2 * (cells + K)`, and
over one interval its two totals are one sum. `n * eps(T) = 2 * n * u(T)` exceeds
`gamma_D` for `T = Float64` while `n * u <= 1/4`, and for `T = Float32`, whose own steps
are at most `b + 3` per term in a crossing and `K + 1` in a time reduction with every
`Float64` step at `u(Float64)`, wherever `error_bound` is valid. `ledger.closure`'s operator arm and
`mesh.constant_field_reduction` in `test/fields/reduce.jl` hold every conserving
operator to it, on `Backends.CPU` and `Backends.GPU` at two crossings.

A quantity declared a reservoir is accumulated in FP64 or by compensated summation
whatever the working precision, and a ledger given an FP32 accumulator for a
reservoir refuses naming the quantity. The declaration is a field-level one, so the
refusal is here and not in `Reductions`, which cannot see it; `Reductions` provides
the choice by taking the accumulator type explicitly. A tolerance chosen per ledger is what let the
predecessor's nitrogen closure be judged against a bar larger than the quantum of the
column it differenced.

A residual's time signature is classified rather than reported as a number: a trend in
the window that reaches beyond the tolerance is a leak, a constant offset beyond the
tolerance is a stock omitted from the inventory, and independent errors within the
tolerance are rounding. The three have different fixes, and the report names the
class. Each is a model of the series, each test runs under a stated null model at a
false-alarm probability the caller declares, and a series too short for a test to
reach that probability refuses naming the test. A series none of the three models
fits, such as a random walk or a trend confined within the tolerance, is classified
`Unexplained`, a fourth member of the closed set. Three alternatives were weighed.
Forcing it into the nearest class names a fix the series gives no evidence for, which
is how an accumulating walk came to be called rounding. Refusing it would make a
measured outcome indistinguishable from an input the classifier cannot judge, and the
ledger that produced it would stop a run instead of reporting what it found. Returning
no signature keeps the outcome but leaves every consumer to name it separately. A
fourth signature costs a class with no single fix and a consumer that handles four
signatures rather than three. The successive-difference test has no exact recursion for
its null distribution, so beyond the length at which enumerating every ordering stays
within the permutation count its caller declares, it draws that many random orderings,
and it reads their randomness from a counter-indexed function the caller passes rather
than holding a generator of its own. A classification is then a pure function of its
series and the caller's key, and the caller keys it on the ledger's identity through
the counter-based generator of decision 0010, which sits above Fields. A seeded stream
inside Fields was the alternative: every classification in a run would draw the same
orderings, so an ordering set that favoured one pattern would favour it at every
ledger, and the bits would be a stream a Julia release may change. Moving the
generator's bijection below Fields was the other: it buys nothing the passed function
does not, at the cost of a prerequisite row.

## Oracles

Three registry entries exist and belong to this plan rather than to the mesh's:
`mesh.constant_field_reduction`, `mesh.vector_round_trip` and `ledger.closure`. The
rest are added, two of them the leak tests the import records name and the harness
currently reports unresolved. `kernels.body_types_concrete` sits in the registry's
kernels section, because its subject is every kernel body, and belongs to this plan
because the inference argument above is what calls for it.

| id | right answer | the mutation that must make it fail |
| --- | --- | --- |
| `mesh.constant_field_reduction` | a constant field coarsens to the constant; an extensive integral is preserved | a sum weighted by cell count rather than by area, which the 1.3 to 1.4 area variation of decision 0005 must expose |
| `mesh.vector_round_trip` | solid-body rotation lifted at the source and projected at the destination returns itself | a coarsen applied to east-north components directly, which must refuse rather than return a plausible field |
| `ledger.closure` | every ledger's residual within one derived bound unit, with its signature classified | a flux counted twice, whose residual must grow linearly and be classified a leak |
| `fields.semantics_closure` | every semantics type against every operator has a method or a declared refusal | a fixture semantics type with neither, which must fail the enumeration |
| `fields.dimension_refusal` | a binary operation across mismatched dimensions refuses, naming both signatures | an addition of a length to a time, which must refuse rather than promote |
| `fields.adapt_roundtrip` | every registered field type adapts to the device and back unchanged | a struct whose adapt rule drops its support, which must be caught |
| `fields.inference_tight` | every operator over every enumerated pair returns a concrete type | a fixture operator that picks its semantics from a runtime value, which must fail `@inferred`; and an accepted-findings entry with neither a reason nor a row, which must fail the nightly pass |
| `kernels.body_types_concrete` | every kernel body the package defines holds only concrete types in its typed code, on the device and on the CPU backend, at the signatures its launches compile, and every kernel is compiled for the device | a fixture kernel calling a union inference splits, and one holding a box no call reads, each of which must fail; a kernel no launch compiles for the device, which must fail the coverage check |
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
| 52v.3.7 | sonnet | none; reports only | every oracle of the plan ran, `fields.inference_tight` on both arms; verdicts by name; `build.inference_suite_cost` reports its number beside them rather than a verdict, being an instrument |
| 52v.3.8 | sonnet | `docs/imports/jet-jl.md`, `test/fields/static_pass.jl` and its accepted-findings TOML, the JET entry in `Project.toml` extras and `Manifest.toml` | JET has an import record naming a leak test that exists, so `build.import_record_completeness` stays whole; `report_call` reports no unresolved call and `report_opt` no non-concrete return on the operators; the accepted-findings list is TOML with a reason and a row per entry, and an entry with neither fails the pass; the pass is on the nightly row and the Julia version is recorded beside its result |
| 52v.3.9 | sonnet | `test/gate/inference_cost.jl`, the finding it writes, the `threshold` field of the `build.inference_suite_cost` entry | the A/A scatter of the instrument is measured and written as a dated finding with its host, its load and its sample count; the distinct `Dim` signature count is reported beside the time; the entry carries the finding by path and still carries no threshold |
| 52v.3.10 | local | `docs/imports/cuda.md`, `docs/imports/kernelabstractions.md`, the leak test those records name | both records state what the device compiler refuses and what it does not, with the locator read; the leak test exists and fails on a kernel with a deliberately non-concrete call |
| 52v.3.20 | frontier | `test/backends/body_types.jl` and its include line, the `kernels.body_types_concrete` registry entry, section "Dynamic dispatch" of `docs/imports/cuda.md` and `docs/imports/kernelabstractions.md`, and the `@kernel` bodies in `src/` the check finds non-concrete | `kernels.body_types_concrete` passes with no accepted-findings list; a split union and a surviving box fail it on both backends; a folded call and a concrete call pass; a kernel no launch compiles for the device fails the coverage check; the reflection entry it reads is anchored in `docs/imports/cuda.md` |
| 52v.3.21 | sonnet | `test/fields/inference.jl`, `test/fields/static_pass.toml`, the `fields.inference_tight` registry entry | the per-commit arm passes with every call on `Backends.CPU` and `Backends.GPU` from one table; the runtime-dispatch control still fails; the nightly pass reports nothing new or stale; the entry names both backends and carries no device-arm clause |

52v.3.3, 52v.3.5 and 52v.3.6 depend on 52v.3.2; 52v.3.4 depends on 52v.3.3 and
52v.3.5; 52v.3.8, 52v.3.9 and 52v.3.10 depend on 52v.3.4, and 52v.3.7 depends on
52v.3.8 because the nightly arm of `fields.inference_tight` is part of the set it
reports. 52v.3.20 depends on 52v.3.8, whose `device_kernel` is the one definition of
which methods are device kernels, and on 52v.3.19, which holds
`src/Reductions/pairwise.jl`. 52v.3.21 depends on 52v.3.8, whose pass reads the walk.
52v.3.9 depends on 52v.3.21 so that it measures the walk as it will stand, and 52v.3.7
depends on both new rows. 52v.3.10 touches two records the closed `fiddlybits-52v.7` wrote, which is
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
