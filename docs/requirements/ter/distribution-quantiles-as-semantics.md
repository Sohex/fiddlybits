+++
id = "REQ-TER-009"
title = "When a consumer asks what share of a cell lies past a threshold, or the law's curvature changes sign, the crossing carries the distribution, never a corrected mean"
old_path = ["/home/cfutro/docs/world/notes/audits/land-mosaic-support-reductions.md"]
old_commit = "6aa93489d233d4e9d531d6479d338c643e34bc5e"
status = "carried"
+++

## What is true

The predecessor's support vocabulary added `distribution_quantiles` as a field
semantics with this justification: "A table of values in the underlying field's
own units, resolved at a declared probability vector: what a cell's population
IS rather than one number summarising it. A consumer that asks what SHARE of a
cell lies past a threshold has no other term to declare, because no moment
answers that on a skewed cell and a cell mean is not a function of the answer."
The validator refused a quantile table without its probability vector, because
"a quantile vector states which part of the distribution a consumer needs
resolved" and the tails were where the ice and the abyssal floor were.

Measured on the predecessor's `canonical-10m-carve2` build at T21: the
mesh-to-grid crossing preserved the land mosaic (upland soil, lake, barren
shares partitioning the cell to 3.0e-8, float32 storage) and the CONSUMER
collapsed it, blending two capacities into one scalar read by two laws. The
runoff law `max(0, w + F dt - C)` is convex throughout, so a two-point mixture
through it is one-signed. The wetness factor `min(1, w / (0.4 C))` is flat then
convex with a concave knee, so the pre-registered one-signed invariant failed:
13.1 per cent of lake-area bins straddled the knee and carried the opposite
sign, the sign reversing within a single cell as the lake fraction varied. The
conclusion: "a correction term with one sign cannot track a gap with two, so if
this crossing is ever taken past the cell mean, what it must carry is the
DISTRIBUTION and not a corrected mean." Two further findings: the blend's
direction was inverted against the field that ran because its argument had
been written against a uniform default and never re-read against the derived
field that replaced it; and a capacity and a soil water paired across two
iterations produced 55 cells above capacity, the signature of mispairing, so
the instrument refused that pairing by name.

## Why it carries

The plan's mosaic tiles (decisions A1, B4: elevation bands by land-area
quantile plus lake, glacier, bare, wetland and island tiles, with area and
hypsometry from the fine level exactly) are the carrier of a distribution. The
evidence says why a mean cannot serve: two laws reading one cell have different
curvature, one law can change curvature along its own axis, and any question
of the form "what fraction is below freezing, above saturation, under ice" is
a question about a distribution's tail that no moment answers.

## What this system must do

- `distribution_quantiles` is a field semantics (REQ-TER-001). The probability
  vector travels with the table; a reader refuses a table without it, and an
  unordered vector is refused.
- Tiles carry the land column's distribution (B4); every tile advances its own
  state, and a law is evaluated per tile, never on a tile-weighted mean of its
  inputs.
- A consumer that needs a share past a threshold (freezing height for ice
  persistence, saturation for runoff, glaciation, inundation) reads quantiles
  at the terrain level or evaluates per tile; it never thresholds a cell mean.
- The quantile vector is chosen per consumer and names the tail it resolves.
- Paired state comes from one iteration by construction: one process, one
  `WorldState`, one declared writer per quantity (A5), so cross-iteration
  pairing is unrepresentable.
- A directional argument written against a default value is re-checked against
  the derived field that replaces it; the check is a test, not a comment.

## Enforced by

- Type-level semantics and reader refusal (A2, A6).
- B4 tile design; M5 gate: ledgers closed at the land seam; site-level
  benchmarks.
- Sign-invariant tests that report violation fractions rather than pass/fail.

## References

- Jensen, J. L. W. V. (1906). "Sur les fonctions convexes et les inegalites
  entre les valeurs moyennes". Acta Mathematica 30, 175-193.
  DOI: 10.1007/BF02418571.
- Koster, R. D., Suarez, M. J. (1992). "Modeling the land surface boundary in
  climate models as a composite of independent vegetation stands". Journal of
  Geophysical Research 97(D3), 2697-2715. DOI: 10.1029/91JD01696.
- Avissar, R., Pielke, R. A. (1989). "A Parameterization of Heterogeneous Land
  Surfaces for Atmospheric Numerical Models and Its Impact on Regional
  Meteorology". Monthly Weather Review 117, 2113-2136.
  DOI: 10.1175/1520-0493(1989)117<2113:APOHLS>2.0.CO;2.
- Lawrence, D. M. et al. (2019). "The Community Land Model Version 5:
  Description of New Features, Benchmarking, and Impact of Forcing
  Uncertainty". Journal of Advances in Modeling Earth Systems 11, 4245-4287.
  DOI: 10.1029/2018MS001583. The sub-grid hierarchy of tiles and columns.
