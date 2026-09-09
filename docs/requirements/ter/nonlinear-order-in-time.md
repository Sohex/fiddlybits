+++
id = "REQ-TER-008"
title = "A nonlinear function of a time-varying state is evaluated per interval and reduced afterward, except where the interval integral is itself the conserved quantity"
old_path = ["/home/cfutro/docs/world/notes/audits/annual-mean-of-a-nonlinear-function.md"]
old_commit = "6aa93489d233d4e9d531d6479d338c643e34bc5e"
status = "carried"
+++

## What is true

Measured on the predecessor's baseline climatology: a Penman combination
evaluated once on annual-mean air, against the same evaluation per time bin
then reduced, differed by 1.170x at basin sinks and 1.569x over land, one-signed
because the curvature is. A weathering intensity `exp(T) * Q^beta` gave a
bin-arm over annual-arm ratio of 1.215 over all land, up to 23.9x on one cell,
and never below one across 33,367 gated cells, as convexity requires; on the
cells a consumer actually selected (wet, warm, small seasonal swing) it was
1.008, two orders inside the law's own published uncertainty, so it was carried
as a bracket rather than applied as a fix. An environmental lapse rate fitted
on the annual-mean profile differed from the mean of per-bin fits by 0.53 per
cent, inside the per-bin scatter, and was declared rather than changed. The
audit's method is to search for the OPERATION rather than the symptom:
exponentials, powers other than one, products of two varying fields, divisions
by a varying field, clamps, thresholds, interpolation onto a curved table,
iterative solves. Two adjacent defects: time means taken with an unweighted
`.mean(axis=0)` over unequal bins, and a bin index passed where bin centres
belong, asserting even bins instead of measuring them.

The exception is a physical identity, not a preference. Over a closed cycle at
steady state a land cell's storage returns to where it started, so the annual
integral of `P - E` IS the runoff the cell generated; clamping per bin counts
the wet season's supply twice. Measured, per-bin clamping raised catchment-mean
runoff from 161.2 to 266.1 mm/yr, 1.92x at the land mean, and the model's own
soil water said so: the ratio of its seasonal storage range to the discarded
deficit had a median of 0.988.

## Why it carries

One clock in SI seconds with intervals of any length (decision A4) means every
slow-tier quantity is a time reduction of fast-tier state, and every
parameterisation that reads a mean of a varying state faces this. The design
(B9) accumulates climate statistics as distributions over declared cycle
periods for exactly this reason. The exception, where the integral is the
conserved quantity, has to be declared as an identity with its closed-cycle
condition, or the two orders get confused in both directions.

## What this system must do

- `time_reduce` dispatches on the time semantics (`instantaneous`,
  `interval_mean`, `interval_accumulation`, `interval_endpoint_state`) and
  weights by interval length from `Interval{t0,t1}`, never by record count and
  never by an index standing in for a time axis.
- A nonlinear function of a time-varying state is evaluated at the tier where
  the state varies and accumulated (B9: overflow time fractions and
  temperature exceedances are distributions), never evaluated on a mean.
- Where the interval integral is the conserved quantity (runoff as the closed-
  cycle integral of `P - E - dS`), the aggregate-then-process order is declared
  with the identity that justifies it, and the closed-cycle condition (storage
  returns within tolerance) is checked by a ledger.
- Wherever a law is `Bracketed`, both arms are evaluated and the ratio is
  reported beside the value, so the next reader does not re-derive that it was
  considered.
- A consumer declares the interval floor it needs; the producer meets it or
  the read refuses.

## Enforced by

- A4 `SimTime` and `Interval` types; `Dates` lint-banned from physics.
- A lint refusing a bare mean over a time axis outside `time_reduce`.
- The operator-order test in time with the identical-bins control
  (REQ-TER-004).
- The land water ledger closing over a declared cycle (M5 gate: land `P - E`
  versus runoff).

## References

- Jensen, J. L. W. V. (1906). "Sur les fonctions convexes et les inegalites
  entre les valeurs moyennes". Acta Mathematica 30, 175-193.
  DOI: 10.1007/BF02418571.
- Penman, H. L. (1948). "Natural evaporation from open water, bare soil and
  grass". Proceedings of the Royal Society A 193, 120-145.
  DOI: 10.1098/rspa.1948.0037.
- Walker, J. C. G., Hays, P. B., Kasting, J. F. (1981). "A negative feedback
  mechanism for the long-term stabilization of Earth's surface temperature".
  Journal of Geophysical Research 86(C10), 9776-9782.
  DOI: 10.1029/JC086iC10p09776. The exponential the measurement was taken on.
