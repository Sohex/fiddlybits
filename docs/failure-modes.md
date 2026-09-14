# Failure modes: dispositions

The predecessor project recorded how it went wrong as forty-one numbered classes and
three unnumbered sections in
`/home/cfutro/docs/world/docs/src/practice/failure-modes.md` (commit
`6aa93489d233d4e9d531d6479d338c643e34bc5e`). That file is the argument. This file is
the disposition: for each class, whether this project makes it unrepresentable,
checks for it statically, refuses it at runtime, tests for it with a right answer,
carries it as a rule of practice, or does not carry it because it was an artifact of
the old architecture. Nothing is carried because the old file says so; each class was
weighed for a generic exoplanet builder with one language, one mesh hierarchy, typed
field semantics, a `System` struct with five constant dispositions, content-addressed
artifacts, and coupling in one process.

Dispositions:

- `type`: made unrepresentable by a type or by the module system.
- `lint`: a static check in the smoke suite; a violation fails the build.
- `refusal`: a runtime check that raises a `Refusal` before a wrong answer is produced.
- `oracle`: a registered test with a right answer and a verdict fixed in advance.
- `process`: a rule for the practice book, in positive form, because the class
  survives any language.
- `not carried`: an artifact of the old architecture, with the reason.

A class may carry more than one disposition. A mechanism named below that the plan
does not yet name is listed at the end so M0 can decide it.

`old` in the table means the old file above; the number after it is the class heading
that holds the argument. Class names are restated in the positive: the old name
described a defect, the new name states the property this project holds.

## Table

| # | Class (as a property this project holds) | Disposition | Mechanism | Argument |
|---|---|---|---|---|
| 1 | One definition of a quantity, read by every consumer | type, lint | `WorldState` single writer checked at `assemble`; consumers read the store, not a private recomputation; measured dependency graph | old 1 |
| 2 | A parameter that decides the answer is required | type | `System{FT}` keyword-only with no defaults; `coarsen` on an intensive `Field` has no fallback method; JET in CI | old 2 |
| 3 | Artifacts pair only with the lineage they share | type, refusal | `Field` carries support id and level in its type; `Exchange` refuses two fields whose support ids or input keys differ | old 3 |
| 4 | Everything physical that changes the answer is in the identity | refusal, oracle | artifact key hashes the *measured* parameter subset; recorded-within-declared test; runs are UUIDs, never value-derived names | old 4 |
| 5 | Provenance is computed from the artifact by its writer | type, lint | Zarr attributes written by the store from the `Field` value; store refuses an array missing any; findings carry a date and measured-on | old 5 |
| 6 | A conclusion travels with the configuration it was measured on | process, oracle | dated findings with measured-on; every `Bracketed` swept per configuration (M8 gate) | old 6 |
| 7 | A quantity is bounded where it is defined | type, refusal | one owner writes runoff as a flux from the land column; bounded quantities refuse out-of-domain values at the owner's write; the water ledger closes at the exchange | old 7 |
| P | Every component arrives with the cross-check that can catch it | oracle, process | tier-1 identity oracles; ledgers on in-memory state; naive serial reference per kernel; weekly mutation run | old, "The pattern behind the pattern" |
| 8 | A number is quoted with the state of the loop that produced it | type, process | `FixedPointLoop` and `Ladder` exits are values (`Converged`, `Bracketed`, `Refused`, `NotEvaluable`); a result carries run UUID, profile and exit state | old 8 |
| 9 | A sourced number comes from the table it was printed in, labelled by the equation it enters | lint, process | `Sourced` requires DOI plus table or equation; a `Sourced` value whose reference is not `read` is refused by the doc lint; the record names the equation the value multiplies | old 9 |
| 10 | A bound names the mechanism on both sides | type, process | `Bracketed` is a pair with an argument per end; there is no one-sided disposition; the UV weight is derived from the declared spectrum, not estimated | old 10 |
| D | Settled negatives are recorded once, with their evidence | not carried, process | the five items are facts about vendored code that does not exist here; the form (a dated negative finding, an import-review record for a dependency) carries | old, "Things already checked and disproved" |
| E | Two measurements are two names | type | a `WorldState` name is one quantity with one semantics; basin-floor area and drained area are different fields; the connectivity graph makes drained-to-basin a state | old, "One quantity, two meanings" |
| 11 | One code, compiled from the version in the key | not carried, type, oracle | no binaries on disk; level and thread count are `Profile` values; `strip(system)` gives every kernel the same constants; thread-count invariance is tested | old 11 |
| 12 | A continuation continues from the stored system | type, refusal | `continue(run_id)` takes no physics arguments; the stored `System` hash is the truth; a caller value that disagrees refuses; inputs are keys, not names | old 12 |
| 13 | Every quantity has one source: input or state | type, refusal | the owner registry marks each quantity `Input` (read from a key every run) or `Prognostic` (restored from a checkpoint); a restore refuses to write an `Input` | old 13 |
| 14 | A reduced field is checked along the axis it loses | type, refusal, oracle | time semantics `T` on the `Field` type; `time_reduce` returns a ledger; store refuses an open ledger; per-interval identity oracle at ingest | old 14 |
| 15 | Measure the chain before correcting a term | process, oracle | the mutation run makes a compensating pair visible; the practice rule for the case the run cannot see | old 15 |
| 16 | Physics is not a knob; a metric moves only with a mechanism | type, lint, process | no `Tuned` disposition exists; `answers:` commit line required when a registered metric moves; hold-out set; a process is added or removed only with a decision record | old 16 |
| 17 | A check has a right answer and can fail | oracle, lint, process | registry entries require a bar with a source or the verdict `REPORT`; the mutation run proves each oracle can fail | old 17 |
| 18 | Shapes are values and counts travel with their data | type, oracle | Julia array shapes are checked; `Field{...,L,A}` fixes the size in the type; `Accumulated{Interval}` carries its own count; checkpoint round-trip is a tier-1 identity | old 18 |
| 19 | A defect has a fix; a decision needs a conflict | process, lint | decision records' alternatives may not include leaving a known defect; a declared dependency never recorded is flagged | old 19 |
| 20 | Stale state is unreachable, not reconciled | type | content-addressed artifacts: a changed input is a different key, the old artifact is simply no longer named | old 20 |
| 21 | Wait on the artifact | not carried, type | one process; `fetch(key)` blocks on the artifact itself; long work goes through `qrun`, which blocks | old 21 |
| 22 | One statement of what a run applies | type | immutable `System` stored with the run; no re-apply step, no second list; one definition, N doors | old 22 |
| 23 | A conceptual question is argued, not measured | process | practice rule; a bar is fixed before the value it judges has been seen, and the oracle runner refuses an unregistered entry's value on a model result | old 23 |
| 24 | A count is recomputed by the tool that reports it | lint, process | doc lint computes the counts the verification list asserts; a hand-typed count is a finding, not a fact | old 24 |
| 25 | A passage earns its place by the decision it can change | process | the findings rule; git holds the history | old 25 |
| 26 | Rules are stated in positive form with specifics behind a pointer | process | practice book as positive one-liners citing arguments by path; open loops are `bd` issues or deleted | old 26 |
| 27 | A with A before A with B | type, oracle | `System` requires a seed; RNG is counter-based on physical identity; every registered comparison runs its A/A arm first and records the scatter | old 27 |
| 28 | A component is compared with the computed whole | refusal, process | `budget(profile, registry)` is the only source of a memory figure; a profile above its ceiling refuses | old 28 |
| 29 | A check certifies the configuration the model runs | type, oracle | no defaults, so a driver states every value; registry records the `System` and `Profile` of each oracle; component check and model check are both required | old 29 |
| 30 | A distributional property is tested with a sample that can see its rate | oracle, lint | registry entries tagged `distributional` declare `repeats` and the miss rate; the ulp envelope is an ensemble by construction | old 30 |
| 31 | An axis that can carry variation carries it, or says why not | type, lint | band values are `Derived` from reflectance spectra and the declared stellar spectrum; an all-equal axis is flagged unless marked `Uniform` with an argument | old 31 |
| 32 | A value has one write and it is at construction | type, lint | `System` is immutable; `strip(system)` is what kernels see; no physical literal in a physics module outside a disposition record | old 32 |
| 33 | A reader dispatches on the record's own description | type, oracle | self-describing arrays; operator version in the key; a previous-format fixture round-trips in tier 1 | old 33 |
| 34 | An instrument reports the scatter beside its number, or declines | oracle, type | A/A scatter measured before any bar; `NotEvaluable` is a verdict; a result is labelled with its profile | old 34 |
| 35 | Identity covers what was read, so a refactor of the unread changes nothing | type | the key hashes the *measured* read subset; a run in flight keeps its stored `System` | old 35 |
| 36 | One series has one instrument; a join is a type change | type, refusal | `T` distinguishes accumulated from instantaneous; concatenation across `T`, profile or code version needs a declared operator; a verdict window spanning a join refuses | old 36 |
| 37 | A bar names its donor and the donor's exit state | lint, process | registry bars for paired experiments carry `donor` and are refused unless the donor's exit was `Converged` | old 37 |
| 38 | A gate asks nearer the thing and reads the reason as a type | type, not carried | `Refusal <: Exception` distinct from errors; CI loads the package and runs JET; no script gate to proxy | old 38 |
| 39 | Writes land at content keys, never over a shared file | not carried, refusal | store is write-once per key; an existing key with different bytes refuses; `references/pdf/` is read-only payload | old 39 |
| 40 | Meaning travels in the type, never as a sentinel | type | `SimTime` and `Interval{t0,t1}` in SI seconds; `Dates` lint-banned; `CellId` refuses arithmetic at the disk boundary | old 40 |
| 41 | A probe ships with a control that fires | oracle, process | the mutation run is the standing positive control; diagnostics are store fields, not prints; kernels cannot print | old 41 |

## Dispositions with their arguments

### 1. One definition of a quantity, read by every consumer

`type`, `lint`. The old class was four scripts each deciding what runoff meant, so a
correction reached some of them. Here a quantity exists once, in `WorldState`, with
exactly one declared writer checked at `assemble`; a consumer that wants runoff reads
the store's runoff and has nothing of its own to fall behind. The measured dependency
graph (the tracking wrapper that records which parameters and fields each component
read) answers "who consumes this" mechanically, so the old rule "grep for the symbol"
becomes a query on a graph the build already holds. The residual is a consumer that
recomputes a store quantity privately from primitives; a lint that flags a physics
module computing a name the store already owns closes that.
Argument: `/home/cfutro/docs/world/docs/src/practice/failure-modes.md` class 1.

### 2. A parameter that decides the answer is required

`type`. `System{FT}` is keyword-only with no defaults, so a constructor call that
omits a physical input is a method error at the call site. On the operator side an
intensive `Field` has no plain `coarsen`: the reduction must name its operator, and a
call that does not is a missing method, which JET turns into a build failure before
any run. The old class's specific shape, an optional argument whose absence selects
the wrong branch, has no place to live when the type system is asked to enumerate the
branches. The practice rule that remains is the plan's own: no silent default across
a component boundary, checked at the read.
Argument: old file, class 2.

### 3. Artifacts pair only with the lineage they share

`type`, `refusal`. Two per-terrain artifacts were paired by directory position. Here a
`Field` carries its support id and level as type parameters, and every stored array
carries its support id and its input keys as attributes the store refuses to omit. An
`Exchange` between two fields dispatches on support id, so pairing two supports is a
method error, and a pairing of two artifacts of the same support from different
terrain keys refuses at the exchange because the input keys disagree. The old
mechanism, a `terrain_hash` checked by a consistency script, is the same idea moved
from a script into the value.
Argument: old file, class 3.

### 4. Everything physical that changes the answer is in the identity

`refusal`, `oracle`. The old identity omitted the stellar spectrum and rounded the
flux. The artifact key here is a hash of the code version, the parameter subset the
component declared, the input keys, the support id and the operator version; the
declared subset is checked against the subset the tracking wrapper *measured*, and
the recorded-within-declared test runs per commit, so a component that reads a parameter it did not
declare fails before its artifact is written. Runs are UUIDs with detachable tags, so
no value is ever rounded into a name and two nearby values cannot collide. The
converse gap (a read that escapes the wrapper) is listed under classes this project
expects to add.
Argument: old file, class 4.

### 5. Provenance is computed from the artifact by its writer

`type`, `lint`. Headers went stale because a person typed a number into them. Here the
store writes each array's support id, semantics, time semantics, dimension, owner and
interval from the `Field` value it is given and refuses an array missing any; there is
no header a human writes. Derived quantities are computed at call time from the
artifact the configuration names rather than copied into a second place. For prose,
the findings rule carries the residual: a number in `notes/findings/` is dated and
says what it was measured on, and a decision record holds no current values at all.
Argument: old file, class 5.

### 6. A conclusion travels with the configuration it was measured on

`process`, `oracle`. This class survives any language: a settled claim is evidence
about the cases it was measured on, and only a re-measurement says whether a new
configuration is inside that envelope. The positive rule for the practice book: a
recorded conclusion states its configuration and is re-measured before it is used
outside it. The mechanical half is the `Bracketed` disposition: a bracket is a claim
with a range, and the M8 gate requires every bracket swept on the configuration it is
used for, so an inherited bracket cannot stand in for a measured one.
Argument: old file, class 6.

### 7. A quantity is bounded where it is defined

`type`, `refusal`. The old instance was a catchment delivering negative water because
runoff had been redefined as a residual. Here runoff is not a residual: the land
column owns it, writes it as a flux from its own water balance, and the water ledger
at the exchange closes by construction, so a negative delivery would be a ledger
failure rather than a plausible input. Quantities with a physical domain (area,
thickness, a fraction, a delivery) refuse an out-of-domain value at the owner's write,
which is the old rule "clamp where it is defined, not where it is used" with the
clamp replaced by a refusal, because the plan refuses rather than snaps.
Argument: old file, class 7.

### P. Every component arrives with the cross-check that can catch it

`oracle`, `process`. The old file's unnumbered "pattern behind the pattern": every bug
surfaced where two computations of one quantity could be compared. That is the
verification strategy here, stated as machinery. Tier-1 identity oracles run per
commit; ledgers close at every exchange on in-memory state with a floating-point
tolerance and a classified residual; every optimised kernel keeps a naive serial
reference it must agree with; and a weekly mutation run executes the suite against
named deliberate breaks and fails if any goes uncaught. The practice rule is the old
one made positive: a component is merged with the oracle that would have caught its
last bug, and the mutation run holds a break that proves the oracle fires.
Argument: old file, "The pattern behind the pattern" (between classes 7 and 8).

### 8. A number is quoted with the state of the loop that produced it

`type`, `process`. The old class quoted a pre-carve build as a state. Here the carve is
a process inside the coupled loop, not an intermediate artifact, so there is no
uncarved build to quote; and every `FixedPointLoop` and `Ladder` exit is a value
(`Converged`, `Bracketed`, `Refused`, `NotEvaluable`) re-evaluated by a finalizer at
the final state. A result therefore carries the run UUID, the profile, and the exit
state of each loop, and a result from the fast profile is labelled as such wherever
it appears. The epistemic residual, reasoning from one transport pathway where two run
in opposite directions, is a practice rule: every coupling is a computed outcome of
the declared system, and a conclusion about one pathway states which others it did
not follow.
Argument: old file, class 8.

### 9. A sourced number comes from the table it was printed in, labelled by the equation it enters

`lint`, `process`. This survives any language and is the reason the fourth founding
principle exists. A `Sourced` constant requires a DOI and the table or equation it was
taken from; the references index records `read` only where someone opened the paper
and took the value, and the doc lint refuses a `Sourced` value whose reference is
`held` or `requested`. The second half of the old class, the right numbers under the
wrong description, is met by the record naming the equation the value multiplies:
which row is correct depends on what consumes it, so the disposition record carries
the use, not only the source. A caveat from delegated work is closed or is an open
`bd` issue; it is not carried forward verbatim.
Argument: old file, class 9.

### 10. A bound names the mechanism on both sides

`type`, `process`. The old instance, a blackbody UV weight recorded as a floor, is
unrepresentable here because the radiation pipeline is generated from the declared
stellar spectrum and the weight is `Derived`, so nothing estimates it. The class
itself survives: an estimate called a bound discourages the check that would correct
it. The `Bracketed` disposition is a pair with an argument per end and there is no
one-sided disposition, so a floor without a ceiling has no place to be declared. The
practice rule: before calling an estimate a bound, enumerate what pushes it the other
way; if that cannot be done, write "estimate" and leave it undefended.
Argument: old file, class 10.

### D. Settled negatives are recorded once, with their evidence

`not carried`, `process`. The old file's "Things already checked and disproved" lists
five facts about vendored code (a daylength ratio in a canopy routine, a survival
threshold's averaging window, the meaning of a routed runoff field, a bedrock water
share, a soil-capacity path) that do not exist in this project; none carries. The form
carries: a disproved claim is a dated negative finding in `notes/findings/` with its
evidence, and a claim about a dependency's behaviour lives in that dependency's
import-review record with the test that would catch it changing. Two lessons inside
that section stand on their own. A layer scaled to exactly zero producing a silent
NaN is the `refusal` at the owner's write of class 7 plus the ledger. "Trust a
controlled sweep, never one cell" is the sweep discipline of class 6.
Argument: old file, "Things already checked and disproved" (after class 10).

### E. Two measurements are two names

`type`. The old file's unnumbered "One quantity, two meanings": the share of land
inside closed basins and the share of land draining to them differ by a large factor
and were both called the endorheic share. Here a `WorldState` name is one quantity
with one declared semantics and one owner; the basin-floor mask is a categorical
field whose area sum is one number, and the drained share is a property of the
connectivity graph, which is state, so they cannot share a name or be confused by an
operator. The practice residual is the old one: quote the store name, never the
phrase.
Argument: old file, "One quantity, two meanings, several times the value" (after the
disproved section).

### 11. One code, compiled from the version in the key

`not carried`, `type`, `oracle`. The class was one executable per (resolution, layers,
ranks) built at different times from patched Fortran. It does not carry: there is one
language, compiled per session from the code version that is part of every artifact
key; mesh level, vertical ladder and precision are `Profile` values, and thread count
is not part of the answer at all. Three sub-findings do carry. A namelist value never
broadcast to other ranks is unrepresentable because `strip(system)` hands every kernel
the same isbits constants in one process (`type`). Changing the rank count changing
the answer is met by thread-count invariance as a design property, fixed-order
pairwise reductions and no atomics in physics, tested with repeats (`oracle`). A
binary whose identity did not record its source is met by the key: a run from a dirty
working tree is labelled `dirty` in its identity and the registry refuses it for any
registered threshold.
Argument: old file, class 11.

### 12. A continuation continues from the stored system

`type`, `refusal`. A continuation that re-derived its flux from a configuration file
integrated the wrong star. Here `System` is immutable and stored with the run under
the run's key; `continue(run_id)` takes no physics arguments, and a caller that
supplies a `System` whose hash disagrees with the stored one is refused, not
overridden. The second shape in the old class, a guard comparing a name while the
file behind it moved, is met by inputs being content keys: the stellar spectrum is an
artifact with a hash in the run's input keys, and regenerating it produces a new key,
so nothing can change under a stable name.
Argument: old file, class 12.

### 13. Every quantity has one source: input or state

`type`, `refusal`. A checkpoint that restored surface fields the inputs had changed
reproduced its parent silently. Here the owner registry marks each `WorldState`
quantity as `Input` (read from an artifact key at every start) or `Prognostic`
(restored from a checkpoint), and there is no third kind; a checkpoint restore refuses
to write an `Input` quantity, and a start whose input keys differ from the
checkpoint's recorded input keys is a new run rather than a seeded one, unless the
caller declares which `Input` keys are allowed to differ. That declaration is the old
lesson in positive form: restarts are valid exactly when the state is unchanged and
the forcing differs, and the system says which is which instead of a person
remembering.
Argument: old file, class 13.

### 14. A reduced field is checked along the axis it loses

`type`, `refusal`, `oracle`. One corrupt output bin, averaged into a wind that three
consumers read, biased a terrain decision. Two things here remove the mechanism and
one keeps the lesson. Time semantics `T` is on the `Field` type, so an
interval-accumulated field and an instantaneous sample are different types and
`time_reduce` dispatches on that difference; every reduction returns a ledger, and the
store refuses an array with an open ledger, so a reduction that lost something says
so. The lesson is an oracle at ingest: an accumulated output is compared per interval
with its instantaneous sibling (mean of a sampled speed against the accumulated
speed, within the sampling error), which is the old "check the field along the axis
you reduce" with a right answer attached.
Argument: old file, class 14.

### 15. Measure the chain before correcting a term

`process`, `oracle`. This survives any language: a compensating pair of errors is
invisible to any check on the sum, and a mechanism that explains the number you
selected it to explain is the weakest evidence for itself. Two practice rules carry.
When a bug is found in one term of a chain, measure the chain before correcting the
term. A mechanism is tested where it predicts something different, not where it
reproduces the number that motivated it. The mechanical half is the mutation run: a
deliberate break in one term must be caught by an oracle, so a pair that cancels on
the sum is exposed when either half is mutated alone. The old instance itself (a
speed accumulated as a vector) is unrepresentable because a vector `Field` and a
scalar speed have different semantics and different reductions.
Argument: old file, class 15.

### 16. Physics is not a knob; a metric moves only with a mechanism

`type`, `lint`, `process`. A correct stability term was removed because a comparison
loosened. Anti-tuning is mechanised here: the disposition type has no `Tuned` member;
a commit that moves a registered Earth metric in either direction must carry an
`answers: <mechanism>` line, checked in CI; a pre-registered hold-out set is scored
only at gates; one parameter set is shared by every configuration by hash; and the
verdict `REPORT` marks a comparison that has no non-preference bar, so it cannot be
optimised against. A process enters or leaves the model only with a decision record
that says why it exists or why it is a declared absence. The practice rule is the
plan's: a process is in the model because it exists.
Argument: old file, class 16.

### 17. A check has a right answer and can fail

`oracle`, `lint`, `process`. A validation that returned two literals was quoted for
months. Here an oracle is a registry entry with a bar, the bar's source, and one of
three verdicts fixed before the run; a comparison with no bar is registered as
`REPORT` and can only report, never pass. The registry lint refuses an entry with a
`PASS` verdict and no bar. The mutation run is the standing proof that each oracle can
fail. The practice rule for the checks that are not oracles: state in advance what
result would mean "wrong", and if nothing would, the thing is a number, not a test.
Argument: old file, class 17.

### 18. Shapes are values and counts travel with their data

`type`, `oracle`. A Fortran dummy argument reinterpreted an array and moved the wrong
element count while its scalar counter survived. In Julia the shape of an array is a
checked value; `Field{S,T,D,L,A}` fixes the size through the level parameter, so an
array of another level cannot be stored into it; and an `Accumulated{Interval}` field
carries its interval and count as part of the value, so there is no separate scalar
to survive. The checkpoint round trip (`restore(save(state)) == state`, bitwise) is a
tier-1 identity, which is the old rule "check the transferred size against the
declared shape" with the check done by the language. The GPU version of this class,
a kernel reading past a padded stencil, is a new class listed at the end.
Argument: old file, class 18.

### 19. A defect has a fix; a decision needs a conflict

`process`, `lint`. Two defects were put up as decisions with menus. This survives any
language, and the practice rule is the old distinction made positive: a question is a
decision when declared truths conflict or when a threshold nothing has fixed is
needed; otherwise it is a defect and has a fix. A decision record's alternatives may
not include leaving a known defect in place. The old instance, a scheme that ignored
the declared spectrum, gets a lint: a component that declares a dependency the
tracking wrapper never records reading is flagged, because a declared input nothing
reads is a defect against the declaration.
Argument: old file, class 19.

### 20. Stale state is unreachable, not reconciled

`type`. After an upstream change the old project asked which artifacts needed
updating. With content-addressed artifacts the question does not arise: a changed
input or code version is a different key, the artifact under the new key does not
exist until it is computed, and the artifact under the old key is not wrong, merely no
longer named by anything. The practice residual is already the findings rule: a number
lives in a dated finding, a mechanism lives in a decision record, and only the
mechanism survives an iteration.
Argument: old file, class 20.

### 21. Wait on the artifact

`not carried`, `type`. A shell loop that grepped for its own pattern waited forever. No
component here is a process to poll: coupling is in one process, long work goes
through `qrun`, which blocks and returns the exit code, and `fetch(key)` on the
content store returns the artifact or computes it. The durable half of the old rule
(wait on the output, not a proxy for it) is the store's own semantics.
Argument: old file, class 21.

### 22. One statement of what a run applies

`type`. Two copies of the list of namelist keys a segment must re-apply diverged, and
the physics changed partway through a run. Here there is no re-apply step: `System` is
immutable and stored with the run, a segment reads it, and a namelist does not exist.
The general form, duplicated declarations diverging, is the plan's "one definition, N
doors" and is made unrepresentable by there being one struct that everything reads.
Argument: old file, class 22.

### 23. A conceptual question is argued, not measured

`process`. This survives any language. The practice rule: before measuring to decide
whether something should exist, state the value that would change the conclusion; if
no value would, the question is not empirical and the argument is written instead.
The registry's rule that a bar is fixed before the value it judges has been seen, with
the oracle runner refusing an unregistered entry's value on a model result, is the
same discipline for the questions that are empirical.
Argument: old file, class 23.

### 24. A count is recomputed by the tool that reports it

`lint`, `process`. A summary asserted without its primitives survives every review
that does not recompute it. The verification list for this pass asserts counts (every
old audit with one disposition, every class with a row); those counts are produced by
the doc lint that walks the tree, not typed by hand. The practice rule: a derived claim
in a document states what it is derived from and is kept only if it changes a
decision; a count without a recomputation path is a finding with a date.
Argument: old file, class 24.

### 25. A passage earns its place by the decision it can change

`process`. Survives any language. The practice rule is the brief's own: a sentence is
kept for the future work it can inform; the history of how a section became right is
in git; a dated finding, a measured-on, a pre-registered threshold and a status label
are the exceptions because each changes how a reader acts.
Argument: old file, class 25.

### 26. Rules are stated in positive form with specifics behind a pointer

`process`. Survives any language. The practice book is written as positive one-liners
each citing its argument by absolute path, which is the old file's own defusal list
applied to itself: a prohibition does not print what it forbids; an exception is
fenced by the condition that licenses it; an open loop is a `bd` issue or is deleted;
tool output states what it is and is not. This file's own restatement of every class
name in the positive is an instance.
Argument: old file, class 26.

### 27. A with A before A with B

`type`, `oracle`. A comparison on a clock-seeded bed reported ninety-four wrong
records against a correct rewrite. Here `System` requires a seed and the RNG is
counter-based on (root seed, support id, cell, process, time index), so a clock can
never enter a run and one configuration run twice is one answer by construction.
Every registered comparison runs its A/A arm first and records the scatter as the bar
the A/B is judged against (C6: A/A scatter measured before any bar). The practice
residual: when a metadata record such as the RNG state is among the differences, the
runs are not comparable and no physics is read out of them.
Argument: old file, class 27.

### 28. A component is compared with the computed whole

`refusal`, `process`. One array's size was compared with a cache as though the array
were the working set. Here the memory budget is a function of the field registry at
the profile's levels, `budget(profile, registry)`, and is the only source of a memory
figure; a profile whose computed high-water exceeds its declared ceiling refuses to
start. The practice rule generalises past memory: a claim about a term of a total
cites the computed total beside it.
Argument: old file, class 28.

### 29. A check certifies the configuration the model runs

`type`, `oracle`. Nine green arms certified a non-rotating unfiltered case no run
used. Two mechanisms. `System` has no defaults, so a test driver cannot take a value
it did not state, and the registry records the `System` instance and `Profile` every
oracle ran on, with tier-1 kernel oracles run across a declared spread of planetary
parameters rather than one convenient point. And two checks are required per kernel:
the naive-reference comparison certifies the operator, and the per-commit short
coupled case certifies the model reaching it; neither substitutes for the other. The
practice residual: a term a driver never mentions came from somewhere, and the
somewhere is named.
Argument: old file, class 29.

### 30. A distributional property is tested with a sample that can see its rate

`oracle`, `lint`. Bit identity twice was read as reproducible while the model had
several outcomes. A registry entry tagged `distributional` (run-to-run identity, a
race, a convergence rate) declares `repeats` and the miss rate that sample can
detect, and the registry lint refuses `repeats` below three for that tag. The
thread-count invariance test runs with repeats by design, and the CPU/GPU production
tolerance is a measured ulp-ensemble envelope, which is an ensemble by construction.
Argument: old file, class 30.

### 31. An axis that can carry variation carries it, or says why not

`type`, `lint`. Seven two-band albedos held one value in both bands, so a correct
spectral fix did nothing for ice. Here band values are not declared: surface albedo is
`Derived` per band from a reflectance spectrum per surface class and from band edges
that are flux quantiles of the declared stellar spectrum, and a `Derived` refuses a
caller value. The general lint carries: a constant declared with a physical axis
(band, level, size class, phase) whose elements are all equal is flagged unless it is
marked `Uniform` with the argument for why the variation is absent.
Argument: old file, class 31.

### 32. A value has one write and it is at construction

`type`, `lint`. A constant described from its declaration was overwritten by a planet
module before the namelist was read; a predicate hid a latitude threshold. `System` is
immutable, so a value is written once, at construction, and `strip(system)` is what
every kernel sees; the run's artifact records the stripped constants, which is the old
"read the echo" with the echo made the only path. The predicate case is a lint: a
physics module holds no numeric literal with physical meaning outside a disposition
record, so a latitude threshold cannot hide in a branch. The measured dependency
graph then says which components read a value, which is the "last write and every
read" the old rule asked for.
Argument: old file, class 32.

### 33. A reader dispatches on the record's own description

`type`, `oracle`. A parser matched on a header position and broke when the header
grew. Store arrays are self-describing (support id, semantics, time semantics,
dimension, owner, interval), the reader dispatches on those attributes, and the
operator version is part of the key so a format change is a new key rather than a
silently reinterpreted old one. The old check, run the new reader over the old
capture, is a tier-1 oracle: a fixture from each previous store version must round
trip under the current reader.
Argument: old file, class 33.

### 34. An instrument reports the scatter beside its number, or declines

`oracle`, `type`. Four plausible numbers in one day came from instruments that could
not resolve the effect. Every registered bar is preceded by its A/A scatter, and an
effect below the scatter is `REPORT`, not `PASS` or `FAIL`. Loop exits and gate
checks have `NotEvaluable` as a value, so an instrument that cannot answer says so
rather than returning an ordinary number. The old sub-case of a refusal outliving its
profile is met by every result carrying its profile in its identity. The practice
rule: work out what the effect is worth in the instrument's own units before reading
the number.

The scatter is necessary and not sufficient, because it is measured on one bed and
the bar judges results taken on another. An instrument can repeat to a part in a
hundred and still move by more than half its own value when the machine around it is
busy, and a bar set from the quiet scatter then fires on a neighbour rather than on
the thing it names. A bar therefore states the condition its bed was held to, and a
result taken outside that condition is `REPORT`. Measured for the load instrument in
`notes/findings/2026-09-11-load-latency-instrument.md`.
Argument: old file, class 34.

### 35. Identity covers what was read, so a refactor of the unread changes nothing

`type`. Removing a configuration key nothing read killed every run in flight because a
textual guard could not tell removal from drift. Here the artifact key hashes the
parameter subset the component declared and was measured to read, so a key nothing
reads is in no artifact's identity and its removal changes nothing; a read key that
moves changes the key, and that is correct. A run in flight keeps the `System` stored
with it, so a source change cannot kill it. The honest cost: the code version is in
every key, so any commit renames every artifact; that is the price of never pairing
an artifact with code that did not produce it.
Argument: old file, class 35.

### 36. One series has one instrument; a join is a type change

`type`, `refusal`. An autocorrelation time fitted across a change of output regime
measured the seam. Here the accumulated and the instantaneous field are different
types through `T`, and a series is a list of `Interval` values each carrying its
`T`, profile and code version; concatenating across a change in any of them needs a
declared operator, and the convergence-window predicate refuses a verdict window that
spans one. Standard errors account for autocorrelation (B9 exit criteria). The old
provision for an unavoidable span, measure the step against the criterion it would
decide, is the same predicate returning `NotEvaluable` with the step size.
Argument: old file, class 36.

### 37. A bar names its donor and the donor's exit state

`lint`, `process`. A resolution bar inherited from arms seeded off an unsettled
control overstated the noise by a factor of twenty. A registry bar for a paired
experiment carries the donor run's UUID, and the registry lint refuses a bar whose
donor did not return `Converged` on the criterion the bar judges. The practice rule
carries: a paired experiment's power depends on the donor as much as on the arm
length, and an unresolvable term is a claim about the instrument until the donor is
known to be settled.
Argument: old file, class 37.

### 38. A gate asks nearer the thing and reads the reason as a type

`type`, `not carried`. A script gate probed entry points with `--help` and an exit
status, and rewrote nine tracked artifacts. The gate does not carry: there are no
scripts to probe, the package loads under precompilation and JET in CI, and that is
the whole of "does it start". The lesson carries in the type system: `Refusal` is an
exception type distinct from an error, so any harness reads the reason as a type and
never infers it from a number, and a `catch` that swallows a `Refusal` without
rethrowing is lint-banned.
Argument: old file, class 38.

### 39. Writes land at content keys, never over a shared file

`not carried`, `refusal`. A worktree's per-file symlinks let a regeneration write
through into the main checkout. There is no linked payload of generated artifacts to
write through: the store is write-once per key, and a write of an existing key with
different bytes refuses, which is the "door" the old class wanted at every generator
and could not build. `references/pdf/` is the one linked directory and it is
read-only payload with a tracked index.
Argument: old file, class 39.

### 40. Meaning travels in the type, never as a sentinel

`type`. A `-1` meaning "year end" became `0` in a cast across a language boundary,
and every check on the near side agreed. There is no language boundary here and there
are no sentinels: time is `SimTime` and `Interval{t0,t1}` in SI seconds, a year
boundary is an interval computed from `System`, and `Dates` is lint-banned from
physics modules. The one boundary that remains is the disk (0-based on disk, 1-based
in memory), where `CellId` refuses arithmetic so a mixed-base index is a type error,
and where the store round trip is a tier-1 identity.
Argument: old file, class 40.

### 41. A probe ships with a control that fires

`oracle`, `process`. Four instrumented builds printed to a stream nobody read, and
four zeros were recorded as measured eliminations. Diagnostics here are fields written
to the store, which refuses an unlabelled array, and kernels cannot print (F8), so a
probe's output has one place to arrive. The mutation run is the standing positive
control: a probe or oracle that cannot fire fails to catch its named break. The
practice rule survives any language: an instrument whose null result would change a
decision is shown to deliver a non-null result first.
Argument: old file, class 41.

## Classes this project expects to add

Failure shapes the new architecture invites that the old one did not, one line each
with the prevention that should exist. Each becomes an entry in the failure-mode suite
when its mechanism is built.

- A GPU kernel reads past a padded stencil or a refinement halo without error.
  Prevention: the CPU backend of the same kernel runs bounds-checked in the
  per-commit suite; the bitwise CPU/GPU debug mode fills padding with a NaN sentinel
  so a stray read poisons a ledger.
- A `Closure` disposition whose scaling law was never swept across levels.
  Prevention: `System` construction refuses a `Closure` with no registered
  convergence-with-level oracle spanning at least two mesh levels.
- A refinement boundary reflects gravity or acoustic waves and seeds grid-scale
  storms. Prevention: a fluid component refuses an abrupt 2:1 boundary; the M3 gate
  "graded refinement region with no reflected-wave growth" is a tier-1 oracle per
  transition-ring width.
- A mosaic tile with zero or negative area. Prevention: a tile exists only for
  `0 < land fraction < 1`, its area is an extensive `Field` whose constructor refuses a
  non-positive value, and the area ledger closes at every crossing.
- A `Field` type parameter erased by a broadcast, returning a bare array.
  Prevention: `Base.broadcastable` on `Field` refuses unless the semantics of all
  operands agree, and a lint asserts every operator on a `Field` returns a `Field`.
- A content-addressed key that omitted a dependency because a read escaped the
  tracking wrapper (a module-level constant, a `Ref`, a file read). Prevention: lint
  bans non-const globals and I/O in physics modules; a mutation-run entry changes an
  undeclared value and expects the key to move.
- An FP32 kernel certified once and never re-certified after an edit.
  Prevention: the ulp-envelope certificate is stored under the kernel's code hash, and
  a production profile refuses an FP32 kernel whose certificate hash does not match.
- An FP64 accumulator demoted to `FT` by a promotion rule (a reservoir initialised
  with `zero(FT)`). Prevention: reservoirs are `Reservoir{Float64}` with an explicit
  widening `accumulate!`, and `FT` is lint-banned in reservoir modules.
- A hanging-edge flux at a 2:1 boundary that does not conserve. Prevention: the
  refinement balance identity (M0 gate) and constant-field preservation across a
  refined boundary run per commit.
- A refined region written by two components at different levels. Prevention: the
  single-writer check at `assemble` includes refined regions and levels.
- A segmented reduction assuming a full sibling range where a refinement region has
  hanging levels. Prevention: the extensive-integral preservation oracle runs on a
  mesh with an active refinement region, not only on a uniform level.
- An RNG key that changes when a region is refined, so a stochastic process is not
  reproducible across refinement. Prevention: the counter key uses the hierarchy cell
  path, which is stable under refinement, never a local index.
- A connectivity-graph topology change that does not force a climate refresh.
  Prevention: a synthetic seaway-closure test must emit the refresh event.
- An atomic added to a kernel, breaking thread-count invariance. Prevention: atomics
  are lint-banned in physics modules; the invariance test runs with repeats.
- A fast-profile number quoted as a full-profile result. Prevention: the result's
  identity carries the profile, and a document lint flags a number quoted without a
  run identity.
- A registered result taken from a `Revise` session where a redefined method is
  stale, or from a dirty working tree. Prevention: registered results come only from
  a fresh process on a clean tree; a `dirty` identity is refused by the registry.
- A `Refusal` swallowed by a `try`/`catch` in a driver. Prevention: lint bans a
  `catch` that does not rethrow `Refusal`.
- A dimension error invisible inside a kernel because `strip` removed the units.
  Prevention: dimensions are checked at every `Exchange` at `assemble`, and a test
  asserts `strip` is the only door from `System` to a kernel.
- A vertical ladder derived from the planet that places no level inside the
  boundary layer for a slowly rotating or low-gravity configuration. Prevention:
  ladder construction refuses when the declared minimum count inside the lowest
  scale-height fraction is not met.
- A `Derived` value cached outside the content store and stale against its inputs.
  Prevention: there is no cache outside the store; a `Derived` is computed at call
  time or keyed by its inputs.
- A tier cadence or a window declared as a count of days, orbits or cycles for a
  configuration that has no such period (a synchronous rotator, a zero-amplitude
  stellar cycle, an orbit shorter than the relaxation time it is meant to span).
  Prevention: every step and window is a `Derived` duration in seconds from a named
  timescale (decision 0023); the constructor refuses a cadence whose period is
  undefined and records the fallback branch in the run identity.
- A `Derived` field of `System` validated only on `Earth()`, so a derivation that is
  right on one configuration by coincidence (prograde-only, single-source,
  spherical, small-eccentricity) has no test that can fail. Prevention: the M0 gate
  and the registry's `system.*` section run every derived identity on a synthetic
  non-Earth instance with closed forms as well (decision 0034).
- A verification bar stated in the units of one configuration (a tolerance in watts
  per square metre, an elapsed time in days, a relief cut in kilometres) applied to
  another. Prevention: exits are dimensionless (decision 0023), registry statistics
  are in seconds with a spread-arm rule, and a tier-3 bar applies only to its named
  protocol system (`docs/oracles/README.md`).

## Mechanisms named here that the plan does not yet name

For M0 to accept or replace: the `Input` versus `Prognostic` marking in the owner
registry (13); the per-interval ingest identity for accumulated fields (14); the
registry tags `distributional` with `repeats` (30) and `donor` (37) and the lint that
enforces them; the `Uniform` annotation for an all-equal physical axis (31); the
`Refusal` exception type and the no-swallow lint (38); the `dirty` label in a run
identity (11, and the added classes); the lint that flags a declared dependency never
recorded (19) and a physics module recomputing a store-owned name (1); the
`budget(profile, registry)` refusal (28); the store fixture round trip per format
version (33); the `Reservoir{Float64}` type (added classes).

## Counts

Recomputable from the table; a class with several dispositions is counted under each.
Forty-four entries: forty-one numbered classes and three unnumbered sections (P, D, E).

| Disposition | Entries |
|---|---|
| type | 27 |
| lint | 11 |
| refusal | 9 |
| oracle | 14 |
| process | 17 |
| not carried | 5 |

Entries that survive any language and carry `process` alone: 23, 25, 26.
Entries whose old mechanism is not carried, with only a residual form kept: D, 11,
21, 38, 39.

## Amendments

- 2026-09-08: three classes added to the expected list (a cadence declared in periods a configuration lacks; a Derived field validated on one configuration; a bar in another configuration's units), from notes/findings/2026-09-08-implicit-earth-audit.md.
- 2026-09-11: class 34 gains its second half, that an A/A scatter measured on a quiet bed does not license a bar unless the bar states the condition the bed was held to, from notes/findings/2026-09-11-load-latency-instrument.md.
- 2026-09-13: class 23's registry mechanism is a bar fixed before the value it judges has been seen, with the runner refusing an unregistered entry's value on a model result, from docs/decisions/0025-three-oracle-tiers.md (amendment of 2026-09-13).
