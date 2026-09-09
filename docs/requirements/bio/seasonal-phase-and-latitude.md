+++
id = "REQ-BIO-005"
title = "Seasonal landmarks are derived per cell from the resolved forcing on the system clock, and latitude is geometry, never an ecological regime selector"
old_path = ["/home/cfutro/docs/world/biosphere/notes/implicit-earth-assumptions.md"]
old_commit = "6aa93489d233d4e9d531d6479d338c643e34bc5e"
status = "carried"
+++

## What is true

Earth vegetation models carry their seasons as ordinal dates and their
regimes as latitude bands, and neither survives a change of orbit or
obliquity (measured on the old world's port at the archived commit, and on
FATES in /home/cfutro/docs/world/notes/external-model-survey.md section 54):

- The northern coldest day was 15 January and the southern 15 July, aliasing
  each hemisphere's warmest day to the other's coldest; on a year shorter than
  195 days the southern date named a day the calendar did not have, so the
  southern degree-day and leaf-on resets never fired, and chilling detection
  in the north was switched off at the coldest day and never back on. A
  chilling counter then advanced one index past the end of its table on any
  cell whose monthly mean never crossed the base from above.
- FATES resets its chilling counter on day 270 and its degree-day counter on
  day 181 and holds 365.0 as a compile-time constant; on a 145-day year the
  counters are never reset and accumulate without bound.
- The repair derived the two landmarks per cell from a running day-of-year
  mean of the air temperature forcing, smoothed over one of the planet's
  months and searched circularly for its extremum; no hemisphere test, no
  thermal-lag assumption, and the two can never coincide, so each reset fires
  exactly once per orbit on every cell, the equator included.
- Latitude selected physics in several places: a peat model versus a
  simplified wetland at exactly 40 N (not absolute latitude, so 60 S took the
  low-latitude path), crop types at 30 degrees, barren versus shrub versus
  tundra at 50 degrees, and fire-mortality and litter-tuning functions in 30
  and 50 degree bands. The defect is not any one boundary: no static latitude
  or hemisphere flag can stand in for temperature, season, wetness,
  permafrost, vegetation, productivity, fuel or disturbance regime.
- A 32-degree obliquity put a cold trough at 45 to 60 degrees latitude, colder
  in degree-days than the pole (197 against 844 growing degree-days above
  5 C), because that band lies past the solstice subsolar point and short of
  polar day; every registered prediction that assumed an Earth-shaped
  gradient (the cold band is the high-latitude band) missed.

## Why it carries

Obliquity, orbit and rotation are free (A0), so the mapping from latitude and
date to season is a computed outcome of the declared system, never a rule
(the generalised coupling lesson). A4 makes the calendar a render concern and
bans `Dates` from physics; this record is that decision applied to phenology
and to every regime switch in the biosphere. Latitude's remaining legitimate
uses are the geometric ones the mesh and the orbit already own.

## What this system must do

1. Phenological landmarks (the coldest and warmest points of the seasonal
   cycle, thaw, the start and end of the growing season, the dormant period a
   chilling requirement accumulates over) are derived per tile from the
   resolved forcing and column state on the system clock (A4), with the
   smoothing window declared as a fraction of the orbit. No ordinal date and
   no hemisphere test appears anywhere in the biosphere.
2. Every accumulator with a seasonal reset resets on a derived landmark, and
   every such accumulator is tested for bounded behaviour across many orbits on
   configurations whose orbit is shorter than any Earth ordinal date.
3. Latitude enters the biosphere only through quantities the mesh and orbit
   derive (cell area, instellation, day length) and through labelled
   diagnostics. Every regime selection (wetland model form, fuel class,
   mortality response, biome for any lookup) is selected by resolved state:
   temperature, wetness, permafrost, vegetation, fuel and disturbance history.
   The allowlist of latitude uses is per module and lint-enforced.
4. The Earth test instance is a configuration, not a template: the seasonal
   phase of an Earth cell must come out of the same derivation, and a change of
   obliquity in a sweep (M4b) must move the growing-season structure without
   any biosphere code reading a date.

## Enforced by

- Lint: `Dates` banned from biosphere modules (A4); latitude reads outside the
  per-module allowlist fail the build.
- Fixtures: northern, southern, equatorial and flat forcings, a multi-orbit
  forcing, a cell that never reaches the chilling base, a short-orbit
  configuration; each landmark must fire exactly once per cycle of the orbital
  tier (0023); each seasonal
  accumulator must be bounded.
- Oracle: obliquity sweep (M4b) reproduces the growing-season restructuring as
  a derived outcome; the Earth instance's seasonal phase against observed
  phenology as a REPORT metric.

## References

- Sitch, S. et al. (2003). Evaluation of ecosystem dynamics, plant geography
  and terrestrial carbon cycling in the LPJ dynamic global vegetation model.
  Global Change Biology 9, 161-185. DOI: 10.1046/j.1365-2486.2003.00569.x.
  The phenology formulation carrying the ordinal dates.
- Koven, C. D. et al. (2020). Benchmarking and parameter sensitivity of
  physiological and vegetation dynamics using the Functionally Assembled
  Terrestrial Ecosystem Simulator (FATES) at Barro Colorado Island, Panama.
  Biogeosciences 17, 3017-3044. DOI: 10.5194/bg-17-3017-2020. The demography
  model whose day-of-year resets were found unreachable on a short year.
- /home/cfutro/docs/world/notes/external-model-survey.md section 54.
- /home/cfutro/docs/world/biosphere/notes/productivity-prediction.md, section
  "The mechanism behind the five structural misses" (the obliquity cold
  trough).
- /home/cfutro/docs/world/biosphere/README.md, section "The seasonal
  landmarks are derived, not dated".

## Amendments

- 2026-09-08: cadence wording replaced by the orbital tier of 0023, from
  notes/findings/2026-09-08-implicit-earth-audit.md
