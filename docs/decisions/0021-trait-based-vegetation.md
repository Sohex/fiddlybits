+++
id = "0021"
title = "Vegetation as a trait-based community filtered by the planet, with the biology assumption declared"
status = "accepted"
date = 2026-09-08
+++

## Decision

**Strategy space generated from the system, not from a table.** Each land tile carries
a population of plant strategies, each a vector of continuous traits sampled at build
time from declared ranges; the community is what survives the tile's climate, soil and
water under competition for light, water and nutrients. Traits: leaf mass per area
with its lifespan trade-off, wood density, height allometry and maximum height,
rooting depth, allocation fractions, leaf-out and leaf-drop cues (temperature,
photoperiod as a lit fraction of the rotation period, soil water), photosynthetic
pathway (C3, or C4 as a CO2-concentrating mechanism with its own leakiness and energy
cost reading the same O2 and CO2 partial pressures as C3, so the pathway's advantage
is `Derived` and never a fixed ratio), the marginal water cost of carbon (the stomatal
optimality slope is `Derived` from it at the column's CO2 compensation point and CO2
partial pressure, 0018), nitrogen fixation investment (the fixation rate saturating in
the declared N2 partial pressure with a `Sourced` half-saturation pressure, dimension
Pa), bark thickness, seed mass, frost tolerance with its carbon cost, and a
storage-organ fraction. The last is the trait the predecessor found a fixed type table
could not express for a strongly seasonal configuration.

**Derived from the system rather than from another planet's covariance.** The
photosynthetic temperature optimum acclimates to growth temperature as a
physiological response, so a strategy can survive deep cold below ground and
assimilate in a hot season; phenology cues are thresholds the environment filters,
not calendar indices; the photosynthetic pigment window is a declared property of
the biology (`Bracketed` around the window edge) with the photon flux integrated
from the declared spectrum in the radiation's own bands. The trade-off *forms* are
treated as mechanical constraints; their coefficients are in the irreducible list
below.

**Demography.** Aggregated abundance per strategy with a light-competition closure
first. Cohort-in-patch demography is a declared absence with its interface (a
strategy population that can carry an age structure) complete; it is bought if
forest structure matters to the albedo and roughness the atmosphere reads.

**Physiology and cycles.** Farquhar-von Caemmerer-Berry photosynthesis with
temperature responses, sunlit and shaded, computed in the land column at the column
step (0018) so the system's day and diurnal range are resolved. Growth, allocation and
turnover on the daily tier's step (0023); establishment at the seasonal event the
orbital tier fires (0023); mortality a hazard per second integrated over the interval
since that event and applied at it (REQ-BIO-001). Soil carbon, nitrogen and phosphorus
in first-order pools with an explicit phosphorus weathering source from pedology
(0022), sorption and occlusion pools, nitrogen fixation as a trait cost, nitrogen
deposition from a lightning source (the atmosphere's lightning-potential diagnostic of
REQ-BIO-015, a pre-convective or updraught-based proxy whose normalisation is
`Bracketed` with the cloud-ice flux form as the other end; energy per flash
`Bracketed` with its pressure scaling, and the fixation yield composition-aware, per
REQ-BIO-012). Fire: fuel from litter pools and their moisture (from the column),
ignition rate as lightning flash density times an ignition efficiency (`Bracketed`),
spread by a physical rate of spread in wind and fuel bulk density with gravity
entering through a Froude scaling of the wind and slope factors and air density from
REQ-ATM-017 (REQ-BIO-015), combustion confined to a `Sourced` oxygen flammability
window with the O2 and pressure scalings of REQ-BIO-015 and REQ-BIO-016, intensity to
mortality through bark thickness. Wetlands from hydrology's wetness classes (0019);
methane as a soil-carbon flux entering the atmosphere's tracers, its abundance a
derived state of the atmosphere's oxidant loop (REQ-BIO-017); where the atmosphere
carries no hydroxyl chemistry the lifetime is `Bracketed` (dimension s) with both ends
scaling with the declared ultraviolet photolysis rate, one end the hydroxyl-limited
and the other the photolysis-limited sink, and the Earth value only an `EarthRatios`
denominator.

**Vegetation writes to the terrain** (0015): root cohesion, cover fraction and litter
enter the incision threshold, hillslope erodibility and regolith production.

**The biology assumption, declared `Irreducible`.** Rubisco kinetics and their
temperature responses; the nitrogen cost of Rubisco and the Vcmax-nitrogen relation;
respiration temperature responses; the coefficients of the leaf-economics and
wood-density trade-offs; carbon-nitrogen-phosphorus stoichiometry ranges;
decomposition rate constants (the pigment window is not on this list; it stays
`Bracketed` per REQ-BIO-003). Together these are "an Earth-like
biochemistry in a planet-filtered strategy space", and the record names them so that a
configuration declaring a different biochemistry knows exactly what to replace.
Everything else a type table carried (bioclimatic limits, phenology dates, allometry
per type) is gone.

**The oxygen and pressure rule, companion to the biology assumption.** The biology
assumption fences biochemistry; it does not fence the atmosphere that biochemistry was
measured in. Any Earth-measured quantity that varies with oxygen partial pressure or
with total pressure carries the pressure it was measured at in its source entry and is
scaled by a named relation, or refused, away from it; a source entry without that
pressure is not `Sourced` for a configuration whose atmosphere differs. Applied: the
CO2 compensation point is computed from the Rubisco specificity factor and the O2
partial pressure, with the mole-fraction kinetic constants of Bernacchi et al. (2001)
converted once to partial pressures at their calibration pressure inside `EarthRatios`
(REQ-BIO-007); C4 is a CO2-concentrating mechanism reading the same partial pressures
(von Caemmerer 2000 form; REQ-BIO-007); nitrogenase saturates in the declared N2
partial pressure with a `Sourced` half-saturation pressure; fire runs inside a
`Sourced` flammability window with `Bracketed` O2 scalings of reaction intensity,
moisture of extinction, combustion completeness and emission factors (REQ-BIO-015,
REQ-BIO-016); the decomposition multiplier's moisture axis is the column's pore-space
state and not a potential-evaporation ratio (REQ-BIO-010); every temperature response
in the irreducible list carries the temperature range it was fitted over. The gas
properties a kernel needs (air density, diffusivities, the saturation curve) come from
REQ-ATM-017 and are never held in the biosphere.

**Exchanges (vegetation owns leaf area, canopy height, leaf optics, root profile,
stomatal slope, litter, soil carbon-nitrogen-phosphorus, fire regime, wetland methane
source, cover and root cohesion).** Reads: assimilation, soil water and temperature,
photon flux (land column), phosphorus supply and texture (pedology), wetness
(hydrology). Writes: land column, pedology (organic matter), carbon (land stocks,
methane), terrain (cohesion, cover), aeolian (cover fraction), managed biosphere
(strategy space).

## Alternatives considered

- *A plant functional type table* (the predecessor's vendored model). Rejected: the
  predecessor found the table's cold and heat tolerances anticorrelated because
  Earth's climates are, that a polar type existed only by accident of one row, and
  that its cold limit imported both a number and the statistic relating it to
  physiology. A type table is a covariance structure of one planet.
- *Cohort-in-patch demography from the start.* Deferred: it is the more faithful and
  the larger structure; the aggregated community is built first with the age-structure
  interface complete.
- *A different biochemistry.* Out of scope: the biology assumption is declared so it
  can be replaced, not so it can be invented here.

## Consequences

- The vegetation subsystem has no validation history; its first oracle is the Earth
  distance report (0025) on biome extent, leaf area and productivity, and every
  disagreement is reported, never tuned away.
- The managed biosphere (0024) draws its crop and pasture analogues from the same
  strategy space.
- Fire, methane and nitrogen deposition each carry a bracketed coefficient named as
  such, and each reads the declared atmosphere's oxygen, pressure and ultraviolet
  where its physics depends on them.

## References

- Pavlick, R., Drewry, D. T., Bohn, K., Reu, B. and Kleidon, A., "The Jena Diversity-Dynamic Global Vegetation Model (JeDi-DGVM): a diverse approach to representing terrestrial biogeography and biogeochemistry based on plant functional trade-offs", Biogeosciences 10 (2013). DOI: 10.5194/bg-10-4137-2013
- Farquhar, G. D., von Caemmerer, S. and Berry, J. A., "A biochemical model of photosynthetic CO2 assimilation in leaves of C3 species", Planta 149 (1980). DOI: 10.1007/BF00386231
- Bernacchi, C. J., Singsaas, E. L., Pimentel, C., Portis, A. R. and Long, S. P., "Improved temperature response functions for models of Rubisco-limited photosynthesis", Plant, Cell and Environment 24 (2001). DOI: 10.1111/j.1365-3040.2001.00668.x
- Kattge, J. and Knorr, W., "Temperature acclimation in a biochemical model of photosynthesis: a reanalysis of data from 36 species", Plant, Cell and Environment 30 (2007). DOI: 10.1111/j.1365-3040.2007.01690.x
- Medlyn, B. E. et al., "Reconciling the optimal and empirical approaches to modelling stomatal conductance", Global Change Biology 17 (2011). DOI: 10.1111/j.1365-2486.2010.02375.x
- Wright, I. J. et al., "The worldwide leaf economics spectrum", Nature 428 (2004). DOI: 10.1038/nature02403
- Parton, W. J., Schimel, D. S., Cole, C. V. and Ojima, D. S., "Analysis of Factors Controlling Soil Organic Matter Levels in Great Plains Grasslands", Soil Science Society of America Journal 51 (1987). DOI: 10.2136/sssaj1987.03615995005100050015x
- Thonicke, K. et al., "The influence of vegetation, fire spread and fire behaviour on biomass burning and trace gas emissions: results from a process-based model", Biogeosciences 7 (2010). DOI: 10.5194/bg-7-1991-2010
- Rothermel, R. C., "A mathematical model for predicting fire spread in wildland fuels", USDA Forest Service Research Paper INT-115 (1972). Locator: USDA FS RP INT-115
- Lehmer, O. R., Catling, D. C., Parenteau, M. N., Kiang, N. Y. and Hoehler, T. M., "The Peak Absorbance Wavelength of Photosynthetic Pigments Around Other Stars From Spectral Optimization", Frontiers in Astronomy and Space Sciences 8 (2021). DOI: 10.3389/fspas.2021.689441
- von Caemmerer, S., "Biochemical Models of Leaf Photosynthesis", CSIRO Publishing (2000). DOI: 10.1071/9780643103405 (the C4 CO2-concentrating form)

## Amendments

- 2026-09-08: trait list: photoperiod cue as a lit fraction of the rotation period, C4
  as a CO2-concentrating mechanism, marginal water cost replacing the stomatal slope
  as the trait, nitrogen fixation saturating in the declared pN2 (audit rows 12, 15,
  16, 25), from notes/findings/2026-09-08-implicit-earth-audit.md
- 2026-09-08: cadence wording replaced by the tiers of 0023 and the mortality hazard
  made per second integrated to the seasonal event (audit row 34), from
  notes/findings/2026-09-08-implicit-earth-audit.md
- 2026-09-08: lightning source aligned with REQ-BIO-015 and energy per flash named
  (audit rows 17, 26), from notes/findings/2026-09-08-implicit-earth-audit.md
- 2026-09-08: fire sentence carries the flammability window and the Froude and
  air-density entries (audit rows 1, 4), from
  notes/findings/2026-09-08-implicit-earth-audit.md
- 2026-09-08: methane lifetime aligned with REQ-BIO-017's derived abundance, with the
  Bracketed fallback's ends scaling with the declared ultraviolet (audit row 2), from
  notes/findings/2026-09-08-implicit-earth-audit.md
- 2026-09-08: oxygen and pressure rule added beside the biology assumption and applied
  to Gamma*, C4, nitrogenase, fire and decomposition (audit rows 1, 5, 13, 15, 16),
  from notes/findings/2026-09-08-implicit-earth-audit.md
- 2026-09-08: cross-area review: the pigment window removed from the Irreducible list, staying Bracketed per REQ-BIO-003; von Caemmerer 2000 added to the references, from notes/findings/2026-09-08-implicit-earth-audit.md
