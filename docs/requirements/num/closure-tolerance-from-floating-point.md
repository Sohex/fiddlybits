+++
id = "REQ-NUM-004"
title = "Closure tolerances derive from floating point and are computed on in-memory state, never on written output"
old_path = ["/home/cfutro/git/vesper/notes/audits/closure-tolerance-under-written-precision.md"]
old_commit = "6aa93489d233d4e9d531d6479d338c643e34bc5e"
status = "carried"
+++

## What is true

Measured on the predecessor's vegetation model output. A nitrogen closure differenced
a pool column written to four decimals in kg/m2 and converted it by 1e4 to kg/ha, so
one least-significant digit of the differenced column was 1.0 kg/ha and an exactly
conserving model reported up to 1.0 kg/ha against a floor of 2.0. Of 2,024,484
gridcell-years, 99.885 per cent fell inside the quantisation bound; the residual
series had a lag-1 autocorrelation of -0.40 pooled over all gridcells, near the -0.5
that a first difference of independent rounding errors has exactly. Of four refused
gridcells, two collapsed to well under the bound at every window but the one the
contract happened to choose, and two carried a residual flat in window length from
ten to twelve hundred cycles, which a leak cannot be and a stock omission must be:
the pool column omitted four of the six mineral pools the model's own conservation
identity was written over. The carbon and water tolerances were thin by the same
mechanism without inverting. The mainline code carried a switch adding two decimals
to these columns for benchmarking, which is the release conceding the shipped
precision cannot support a budget check. The replacement measured each column's
written quantum from the artifact it read, formed the residual an exact model would
report, and refused a tolerance under a declared multiple of it before judging any
gridcell.

## Why it carries

A ledger compares a stock difference against a flux integral. Any representation
step between the arithmetic and the ledger (writing at reduced precision, a unit
conversion, an export at `FT`) injects a residual with a known signature, and a
ledger judged on written data will either report that residual as a leak or hide a
leak under it. This system stores at `FT` and exports at declared precisions, so the
exposure is designed in unless the ledger is computed where the arithmetic is. The
time signature of a residual (linear in window for a leak, flat for a stock
omission, white with lag-1 near -0.5 in the differenced series for rounding) is a
property of arithmetic, not of the old model, and it is what turns a closure
failure into a named cause.

## What this system must do

1. Every operator returns `(field, ledger)` computed on in-memory state with Float64
   accumulators, at the moment of the operation; the state store refuses an open
   ledger (A2).
2. A ledger tolerance is derived, never typed: from the accumulator's epsilon, the
   term count and the magnitude of the terms (a summation error bound), with a
   declared margin. Where a ledger must be evaluated on written data (a replay or
   an audit of an export), the written quantum of each column is measured from the
   artifact, the tolerance floors at a declared multiple of the residual an exact
   model would report, and the quantum is recorded in the verdict.
3. A closure residual's time signature is classified by a tested function: leak
   (grows linearly with the window), stock omission (flat, independent of window),
   roundoff (magnitude at the quantum, lag-1 autocorrelation near -0.5 in the
   differenced series). The verdict names the class.
4. The stock side of a ledger spans the same inventory as the flux side by
   construction: a ledger is declared over a named set of arrays, and a registry
   test checks that the source and sink pool of every flux the ledger sums is in
   that set.
5. Every exported array carries its written precision as an attribute, and a
   consumer forming a budget from an export must read it.

## Enforced by

The `Ledger` type with a derived tolerance; the store's open-ledger refusal; the
signature classifier tested on synthetic series of each class; the registry test
over ledger declarations; the mutation run (C4), which includes a deliberate leak
and a deliberately omitted pool; decision records A2 and C3.

## References

- Higham, N. J. 1993. The Accuracy of Floating Point Summation. SIAM Journal on Scientific Computing 14(4). DOI: 10.1137/0914050
- Kahan, W. 1965. Pracniques: further remarks on reducing truncation errors. Communications of the ACM 8(1). DOI: 10.1145/363707.363723
- Goldberg, D. 1991. What every computer scientist should know about floating-point arithmetic. ACM Computing Surveys 23(1). DOI: 10.1145/103162.103163

## Amendments

- 2026-09-13: item 3's classifier names a fourth signature, `Unexplained`, for a series none of the leak, stock omission and roundoff models fits; `Fields.classify` returns it when a series within its tolerance at every window fails the successive-difference test, and when a series beyond its tolerance somewhere shows no trend and then fails the successive-difference test or does not pass the offset test; the choice and its alternatives are recorded in docs/plans/fiddlybits-52v.3-fields.md, section Ledgers
