+++
id = "REQ-HYD-002"
title = "Water-table skill test against observed depths: bars from the published model's own residuals, and a constant must not pass"
old_path = ["/home/cfutro/docs/world/hydrography/notes/earth-calibration-criterion.md"]
old_commit = "6aa93489d233d4e9d531d6479d338c643e34bc5e"
status = "carried"
+++

## What is true

The predecessor ran its steady groundwater solver unchanged on Earth (Australia as an
island with an ocean boundary, ETOPO 2022 land, Berghuijs et al. 2022 recharge, GLHYMPS
permeability whose Australian percentiles are exactly Gleeson et al. 2011's class
means, conductivity `K = k rho g / mu` at Earth's gravity) and declared the criterion
before scoring (2026-08-20): residual is `model - observed` depth at observation
locations only; PASS requires residual standard deviation at or below 24.56 m and
absolute mean at or below 8.92 m, which are Fan et al. 2013's own Australia-and-Asia
figures under the worse of their two recharge forcings. The result was a miss on both:
mean -14.74 m, standard deviation 40.06 m against an observed 40.05 m. The model put
the water table at the surface on 99.2% of sites; a constant explains none of the
variance.

Three corrections to the instrument followed, each declared before its rescore. A bore
screened well below the water table reads a confined potentiometric head, so
construction data must filter the set; 5.2% of sites recorded a water level below the
bottom of their own bore (keying and unit errors) and dominated the spread, and the
one-sided filter first declared selected FOR them, so a filter must be bounded on both
sides. Filtered sets then met Fan's bars while residual standard deviation still
equalled observed standard deviation at every filter level (40.06 against 40.05, 18.26
against 18.36, 11.07 against 11.20): the bar moved with the data and the failure did
not, so an absolute scatter bar from a published model means something only against a
set as noisy as that model's. The replacement criterion was skill: `R^2 > 0.07` on
depth-consistent bores, set by what the single best free predictor (distance to the
coast, Spearman +0.268) explains on its own; beside it the between-cell ceiling 0.857
and a flexible statistical fit over every resolvable field at 0.21. That last number
had been quoted as 0.28 from a harness written inline and lost; re-derived, it ranges
0.14 to 0.24 with the predictor set, so a target ships with its script or it is not a
target.

Running the same case at 15.19, 10.74 and 7.60 km separated resolution from
formulation: the ceiling rose and the model's spread doubled while the correlation did
not move (+0.070, +0.067, +0.071); the model's depth was a monotone function of
recharge (Spearman -0.90 to -0.93) where the observed field is not (-0.27). On bores
the USGS labels unconfined the same solver reached Pearson +0.26 with model spread 20.7
against 28.9 m observed; on Australia +0.07 with 1.9 against 18.4 m. The model has a
regime: where the evapotranspiration sink sets the depth the flow solve carries no
variance, and where lateral flow sets the head it carries some. Held-out R^2 with an
affine correction straddled the bar (0.068 +/- 0.014 over twenty splits): a single
favourable split would have been a pass on a coin toss. Bores sit a mean 8.4 m below
their cell's mean elevation; hanging the depth from the DEM at the bore nearly doubled
Pearson, but the bore's position within its cell alone predicted better than the model
(+0.129 against +0.070), so the gain was a geometric covariate and the default scoring
stayed at the cell mean with the alternative labelled. Mixing a surveyed bore elevation
with a DEM-anchored head added 52 m of datum scatter.

## Why it carries

This is the second Earth oracle of the M2 gate and every lesson in it is about how an
oracle is built rather than about the old solver: a published model's residual bars are
REPORT metrics, not PASS bars, unless the observation set is the same; the minimal
skill statement is that residual spread falls below observed spread; the real bar is
what free geography gives away; filters are two-sided; the scoring surface is part of
the criterion; a sub-grid covariate folded into a score credits the physics with
geometry; verdicts are per regime, so the model must emit the regime per cell; and the
resolution confound is separated by running the same case at more than one level,
which the hierarchy makes native. The one-run harness that was lost is the C4 rule that
a reference path is never deleted.

## What this system must do

- Register the water-table oracle before Earth data is fetched with: the observation
  set and its two-sided consistency filter (`0 < depth <= bore depth`, confinement from
  the source's own labels where they exist); the scoring surface (cell mean of the
  terrain level, with the DEM-at-bore variant labelled and reported, never default);
  FAIL if residual standard deviation is at or above observed standard deviation on the
  consistent set, or if `R^2` on cell means falls below the free-geography baseline
  computed in the same run; REPORT for Fan et al. 2013's own residual statistics and
  for the between-cell ceiling and the statistical-fit target, each recomputed by the
  harness, never typed in.
- Report the verdict per regime, and require the solver to emit the regime per cell
  (sink-dominated, pinned and seeping, lateral-flow-dominated; REQ-HYD-003) so that
  every consumer of a depth reads which of the three it holds.
- Run the same Earth case at two or more hierarchy levels; a correlation that does not
  move with level while the ceiling rises is attributed to formulation, not resolution.
- Keep the harness as a tracked script with cached, hashed data extracts; a threshold
  or target that is not reproducible from the tree is not registered.
- Never mix an observation's own elevation datum with a head anchored to the model's
  terrain.

## Enforced by

Oracle registry (M2 gate) with `provisional = true` until registered; C4 reference-path
rule; a schema test that the water-table artifact carries the regime fields; the
convergence-with-level run as part of the M2 suite.

## References

- Global Patterns of Groundwater Table Depth. Fan, Li, Miguez-Macho (2013), Science 339,
  940-943. DOI: 10.1126/science.1229881
- Mapping permeability over the surface of the Earth. Gleeson, Smith, Moosdorf,
  Hartmann, Durr, Manning, van Beek, Jellinek (2011), Geophysical Research Letters 38,
  L02401. DOI: 10.1029/2010GL045565
- Global Recharge Data Set Indicates Strengthened Groundwater Connection to Surface
  Fluxes. Berghuijs, Luijendijk, Moeck, van der Velde, Allen (2022), Geophysical
  Research Letters 49, e2022GL099010. DOI: to confirm (10.1029/2022GL099010 believed)
- ETOPO 2022 15 Arc-Second Global Relief Model. NOAA National Centers for Environmental
  Information (2022). DOI: to confirm (10.25921/fd45-gt74 believed)
- USGS National Water Information System, groundwater levels (parameter 72019).
  Locator: https://waterdata.usgs.gov/nwis
