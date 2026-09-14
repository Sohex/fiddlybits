+++
id = "REQ-HYD-005"
title = "Sub-grid information reaches a cell-scale parameter only as a statistic of the cell's own distribution, and a closure earns its place against the scatter of its support"
old_path = ["/home/cfutro/git/vesper/notes/audits/saturated-fraction-revival-support.md"]
old_commit = "6aa93489d233d4e9d531d6479d338c643e34bc5e"
status = "carried"
+++

## What is true

The rule and its arithmetic are in
`/home/cfutro/git/vesper/hydrography/notes/subgrid-water-table.md`. Expanding any
parameterisation `P(h)` about the cell mean with within-cell spread `sigma` gives
`E[P(h)] = P(hbar) + (1/2) P''(hbar) sigma^2 + ...`. A form linear in the state has an
exact cell mean at any spacing; a convex or concave one carries a correction that must
be computed and compared with the effect the term is added for. Fan's exponential
transmissivity carried `exp(200)` to `exp(5000)` and was inadmissible; the unconfined
column `T = K max(h - z_b, b_min)` is linear above its floor, admissible where the
saturated column is about three times the sub-grid relief and not beyond, which is why
a thickness floor exists and why a cell on it must be flagged (its depth is a bound,
not a value). The second clause: sub-grid information may reach a cell-scale
parameter only as a fraction, a rank or a quantile of the distribution the cell
contains, never as a resolved gradient or a position within the cell. Folding a bore's
position within its cell into a score nearly doubled the model's Pearson, and the term
doing the work was geometry with no physics in it.

The saturated-fraction closure `f_sat = min(f_sat_max exp(-f_grad z_wt), 1)` (SIMTOP,
Niu et al. 2005) is the statistic form: `f_sat_max` is the share of a cell's land AREA
whose topographic index exceeds the cell's area-weighted mean. Area and region count
are different populations on an unequal-area mesh (moving to area weights shifted the
cell-mean index by a median of 0.19). Absolute index thresholds do not transport: the
index carries a length in its contributing area, so its whole distribution shifts by
about `ln 2` per halving of cell size (measured 0.80 to 0.86 between 15.19 and 7.60
km), and Earth's own topography sampled at 15 km sits far above the range the published
thresholds were tabulated on. `f_grad` is a convention bracket (two published forms
differ by exactly a factor of two per metre), and at its upper end the closure's
ranking is the depth's ranking exactly: one arm of the bracket erases the quantity.
Most of the index's variance is within cells (2.22 against 1.82 between), which is the
case for computing it.

The score was declared before any fraction was computed: the area under the ROC curve
for an observed table within a metre of the surface must exceed the cell-mean depth's
own AUC at the same support, and the attribution identity (constant `f_sat_max`
reproduces the depth's ranking) held to 0.00e+00. The United States unconfined arms
passed by +0.003 to +0.007; Australia missed because the depth it multiplies was itself
below chance there. The independent units of a cell-scale score are cells, and the two
sets reached their verdicts through 34 and 37 of them; resampling the cells put every
gain at or below its own scatter, and a criterion restricted to the good regime runs on
fewer cells still. The closure was withdrawn. The audit records that the support to
revive it exists (GIEMS-MC, WAD2M, Tootchi et al. 2019, GLWD v2 supply 10^3 to 10^4
cells over the same windows) and that four things block the route, none a download:
the criterion must be declared before fetching; an areal observation is a different
instrument (per-cell fraction skill, no AUC) whose bar, comparator and attribution must
be written anew; the predictor half must exist; and the depth needs a regime. A class
whose share is a convention bracket propagates through every downstream ledger as both
arms or as neither.

## Why it carries

A3 defines the `Closure` disposition as a coefficient standing for truncated sub-grid
variance, declared as a scaling law in the grid spacing with a bracketed coefficient
swept across at least two levels; the cell-mean test above is the admissibility check
for any such closure. A1 makes the fine-level distribution inside every coarse cell
exact by nesting, so the statistic form is exact rather than parameterised. B4 takes
saturation-excess runoff from the exact sub-grid index. C1 and C2 fix how an Earth
score is registered. The rules about support, paired gain and convention brackets apply
to every sub-grid closure in every component.

## What this system must do

- A tile or cell parameter derived from a finer level must be a declared reduction
  (fraction, quantile, moment) of that level's distribution through the hierarchy's
  segmented reduction; a kernel that consumes a within-cell position or gradient does
  not type-check.
- Any parameterisation evaluated at a coarse state declares its curvature class; if
  nonlinear, the correction is computed from the hierarchy's exact within-cell variance
  and reported against the effect, and a term whose correction exceeds its effect is
  refused at that level.
- The saturated-fraction closure takes `f_sat_max` exactly from the hierarchy by area,
  `f_grad` as a Bracketed coefficient whose ends are the two published conventions,
  swept across two levels; no absolute index threshold exists. `f_grad` is a
  per-metre soil length scale (the depth over which saturated area decays), not a
  per-pascal quantity in disguise, so it carries no gravity and needs no conversion
  by `g`; it is stated as such so REQ-CRY-002's per-metre rule is seen to have been
  applied.
- Every Earth score of a sub-grid closure registers, before data is fetched: the
  support, the comparator (the coarse state alone), the attribution identity, the
  statistic appropriate to the observation (fraction skill for areal products,
  discrimination for point depths), and the resampling over the independent units; a
  gain is reported beside the scatter of its support, and a bracket arm that erases the
  quantity is reported as such.
- A bracketed class propagates both arms or neither into downstream ledgers.

## Enforced by

A2 refusal table (an intensive field has no plain `coarsen`; JET in CI); the
convergence-with-level oracle for every `Closure`; the oracle registry; a self-test
negative control (a cell deep everywhere except a narrow shallow strip must return the
strip's area share, which a mean fails).

## References

- A simple TOPMODEL-based runoff parameterization (SIMTOP) for use in global climate
  models. Niu, Yang, Dickinson, Gulden (2005), Journal of Geophysical Research 110,
  D21106. DOI: 10.1029/2005JD006111
- A physically based, variable contributing area model of basin hydrology. Beven,
  Kirkby (1979), Hydrological Sciences Bulletin 24, 43-69.
  DOI: 10.1080/02626667909491834
- Global Patterns of Groundwater Table Depth. Fan, Li, Miguez-Macho (2013), Science 339,
  940-943. DOI: 10.1126/science.1229881
- Incorporating water table dynamics in climate modeling: 1. Water table observations
  and equilibrium water table simulations. Fan et al. (2007), Journal of Geophysical
  Research 112, D10125. DOI: 10.1029/2006JD008111
- Multi-source global wetland maps combining surface water imagery and groundwater
  constraints. Tootchi, Jost, Ducharne (2019), Earth System Science Data 11, 189-220.
  DOI: 10.5194/essd-11-189-2019
- Development and validation of a global database of lakes, reservoirs and wetlands.
  Lehner, Doll (2004), Journal of Hydrology 296, 1-22.
  DOI: 10.1016/j.jhydrol.2004.03.028
- Development of the global dataset of Wetland Area and Dynamics for Methane Modeling
  (WAD2M). Zhang et al. (2021), Earth System Science Data 13, 2001-2023.
  DOI: to confirm (10.5194/essd-13-2001-2021 believed)
- Sur les fonctions convexes et les inegalites entre les valeurs moyennes. Jensen
  (1906), Acta Mathematica 30, 175-193. DOI: 10.1007/BF02418571

## Amendments

- 2026-09-08: `f_grad` stated as a soil length scale carrying no gravity (row 36), from notes/findings/2026-09-08-implicit-earth-audit.md
