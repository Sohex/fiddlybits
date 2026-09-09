+++
id = "REQ-BIO-013"
title = "A biosphere closure ledger is generated from the declared state so its stock and flux sides span the same inventory, the residual's time signature is classified, and conservation bounds derived from the input side are acceptance criteria"
old_path = ["/home/cfutro/docs/world/notes/audits/closure-stocks-are-incomplete.md"]
old_commit = "6aa93489d233d4e9d531d6479d338c643e34bc5e"
status = "carried"
+++

## What is true

A conservation check is a right answer only when its stock side and its flux
side account for the same inventory. The predecessor found two of its three
element closures differencing quantities that never spanned the same budget
(measured on the old world's LPJ-GUESS-CNP runs at the archived commit, over
2,024,484 gridcell-cycles on 1617 cells):

- The nitrogen stock omitted four of the model's six soil mineral pools (NO2,
  NO, N2O, N2), which are persistent state serialised across restarts, while
  the flux side reported gas only when it LEFT those pools. The residual was
  therefore the change in the omitted pools, telescoping over any window to an
  endpoint difference: bounded in window length, which is exactly the
  signature an earlier audit had measured and could not attribute. With the
  pools included, every gridcell-cycle landed inside the bound an exactly
  conserving model reports at the written precision (largest 1.0019 kgN/ha
  against a 1.045 quantum).
- The water check had no column for soil evaporation or canopy interception
  and read a transpiration column that summed only the survivors of that
  year's mortality. The residual GREW LINEARLY with window length (+3417 mm at
  ten cycles, +330709 at 1252), which is what separates a missing flux from a
  storage change: a store telescopes and cannot grow; a missing flux of rate F
  gives F times the window. After all four losses were read from the right
  columns the residual grew as the square root of the window (a bounded store
  visited at increasing separations: factor 5.20 measured over a thirtyfold
  range against 5.48 predicted, 30 for linear growth), and the refusal count
  FELL as the window lengthened because the limit scaled with the window while
  the store did not. A conservation test whose refusal count falls as it is
  given more record is answering a question about the declared window.
- Reading the store (soil water, ice and snowpack in the terms the hydrology
  balances) closed the water residual to 0.0276 mm against a 0.1806 mm
  written-precision bound, an order of magnitude INSIDE what an exactly
  conserving model reports at that precision; the margin between the
  resolution bound and the floor was measured from the artifact on every
  assessment so a precision that drops back refuses rather than passing.
- Reading the store exposed a physical cap: the snowpack saturated at
  10000 mm on 17 cells and the surplus was delivered to the soil as liquid at
  sub-zero temperature, conserving and unphysical, because the model had no
  ice sheet to receive it.
- On the fire nitrogen flux two bounds with right answers were derived from
  the INPUT side so the observed distribution could not reach them: in one
  year a cell cannot lose more nitrogen to fire than it holds, and over an
  equilibrium record mean fire loss must be strictly below mean input because
  fire is one of at least three loss pathways. Both passed on every
  gridcell-year (worst stock ratio 0.0712; worst rate ratio 0.981), which is a
  real answer: a flux that removes what the model had closes whatever its
  size, so a closing ledger is necessary and not sufficient.

## Why it carries

Design idea 3 ("a finite output is not acceptance: every conversion carries
closure ledgers") is only true when the ledger spans the inventory, and the
way a hand-listed ledger fails is by omitting a pool that exists. A5's state
store declares every pool with one writer, so the ledger can be generated from
the declaration rather than typed; C3 fixes tolerances from floating point
rather than from a window and classifies the residual's time signature as
leak, stock omission or roundoff, which is the measurement above turned into
a rule. The input-side bounds are the cheap acceptance criteria that catch
what closure cannot.

## What this system must do

1. Every element and water ledger in the biosphere is generated from the state
   store's declared pools (A5), never hand-listed: the stock side is the sum
   over every pool of the element on the tile, and the flux side is every
   exchange leaving or entering that set. A pool with residence across a step
   boundary is a stock; a flux is booked when it leaves a pool, and the ledger
   refuses a flux booked at production while the mass is still resident.
2. The residual is computed on in-memory state in FP64 (A7), against a
   tolerance derived from floating point (C3), never from a window length or
   a declared millimetre, and its time signature over the retained record is
   classified: linear growth is a leak (refused), a bounded or square-root
   signature is a stock omission (refused, naming the store), roundoff is
   inside the derived bound (pass). A ledger whose refusal count falls as the
   record lengthens is a defective instrument and fails its own check.
3. Written precision is never between a ledger and its verdict: ledgers close
   on state, and an exported table's quantisation is reported beside any
   check that uses it, with the margin measured from the artifact.
4. No physical cap silently converts one store into another (a snowpack
   maximum spilling to soil water); an overflowing store is a declared
   exchange to the component that owns the destination (a glacier tile, B6)
   or a refusal.
5. Input-side conservation bounds are acceptance criteria for every loss
   process: a loss in one interval cannot exceed the stock it draws on; over an
   accepted equilibrium record the mean of one loss pathway is strictly below
   mean supply when other pathways exist. They are evaluated on every tile and
   interval, cost one pass, and are registered before the first artifact they
   judge (C2).

## Enforced by

- Type: ledgers derived from the `WorldState` declaration at `assemble` (A5);
  an `Exchange` that does not name both pools is refused.
- Oracle: C3 ledgers at every exchange with residual-signature classification;
  the C4 mutation run omits one pool from a ledger and must be caught by the
  telescoping signature.
- Registered thresholds: the input-side bounds in the oracle registry with
  `provisional = true` until the first artifact.

## References

- The residual-signature argument is the predecessor's own measurement; no
  external source is claimed for it. Primary sources for the conservation
  identities are the component references (REQ-BIO-010, REQ-BIO-011,
  REQ-BIO-016).
- /home/cfutro/docs/world/biosphere/notes/fire-nitrogen-range.md (the
  input-side stock and rate bounds and their first application).
- /home/cfutro/docs/world/notes/audits/closure-stocks-are-incomplete.md (the
  measurements above).
