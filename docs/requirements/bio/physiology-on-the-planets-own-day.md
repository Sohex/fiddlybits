+++
id = "REQ-BIO-007"
title = "Assimilation, respiration and allocation run on the planet's own light and dark cycle at the column's pressure, with acclimation memories bracketed, tissue stoichiometry anchored so the applied ratio is the sourced one, an explicit reserve pool, and no ecosystem scalar tuned to another planet's totals"
old_path = ["/home/cfutro/docs/world/biosphere/notes/plant-physiology-carbon-allocation-audit.md"]
old_commit = "6aa93489d233d4e9d531d6479d338c643e34bc5e"
status = "carried"
+++

## What is true

Measured on the old world's port of an Earth vegetation model at the archived
commit, under a 30-hour rotation and 1.306 Earth gravity:

- The photosynthesis day was internally fixed at 24 hours: daylength as
  24 h times the lit fraction, and the light-use model's optimised Vmax,
  hourly Rubisco-limited rate and daytime respiration fraction all assumed the
  integration interval was one complete solar day. One 24-hour absolute step
  spanned 0.8 of a rotation, so a complete light-dark cycle could not be
  represented by changing an equinoctial photoperiod; the source derivation
  (Haxeltine and Prentice 1996) integrates absorbed light under a sinusoidal
  daylight curve with respiration over 24 minus daylength, on its own time
  base.
- Photosynthesis used a fixed sea-level pressure (1e5 Pa) and oxygen partial
  pressure (20900 Pa) and a psychrometric constant fixed near sea level while
  the atmosphere already resolved surface pressure; mountain cells kept
  sea-level gas physics.
- The acclimated-respiration routine was handed the current day's
  temperature as its growth temperature, so no acclimation was represented;
  the repair carried exponential running means with an e-folding time
  bracketed 7 to 30 absolute days, each end sourced (Gifford 2003 for how fast
  respiration adjusts; the QUINCY supplement's 30-day memory for the same
  relation), with no default, because a default is an undeclared
  physiological memory. The acclimated path was decided against because it
  carried two unsourced changes (a level change of 2 to 10 on sapwood
  respiration and a change of dependence from leaf longevity to temperature)
  inseparable from the sourced one.
- Fine-root and sapwood carbon-to-nitrogen windows had been anchored on the
  leaf window's MAXIMUM while the model applied a ratio of window MEANS, so
  the applied proportion was 1.79 times the sourced constant on nitrogen and
  2.22 on phosphorus; every carbon-nitrogen number produced under that anchor
  was worthless rather than stale. The check that has to pass is closed-form:
  after initialisation the applied tissue-to-leaf ratio equals the constant
  the source measured, for every tissue and phenology.
- A canopy scalar (0.6) was documented as chosen to make global carbon pools
  agree with Earth's published estimates: an ecosystem-level fit to Earth's
  realised carbon cycle, broader than the declared Earth physiology.
- The only carbon buffer was a retrospective sapwood loan; there was no
  non-structural carbon pool, no reserve draw for leaf-out and no
  disturbance recovery. Reproduction removed a fixed 10 percent of carbon and
  routed it to the atmosphere as nitrogen-free litter, so reproduction
  competed for carbon without competing for the nutrients required to build
  it.
- The retained outputs (aggregate GPP, NPP, biomass, LAI, cover) could not
  distinguish photon supply, biochemical capacity, stomatal limitation,
  respiration, allocation, storage and reproduction as explanations of the
  same aggregate.

## Why it carries

B4 places assimilation at the column step with the planet's day resolved,
Medlyn conductance and Farquhar assimilation; B7 declares acclimation of the
photosynthetic optimum to growth temperature. Each of the findings above is a
place where an Earth coincidence (24-hour day, sea level, Earth's global
carbon total) had been folded into physiology. A generic builder gets pressure
from the atmosphere, the day from the System, the spectrum from REQ-BIO-003,
and must leave nothing to a scalar fitted to another planet, because "Tuned"
is not a disposition (A3).

## What this system must do

1. Assimilation is Farquhar-family biochemistry with the temperature
   functions of Bernacchi et al. (2001), evaluated at the column step (B4) on
   the photon flux per band of REQ-BIO-003, with CO2 and O2 partial pressures
   from the column's surface pressure and the declared composition. The
   oxygen and pressure rule of 0021 applies: Bernacchi's kinetic constants
   are mole fractions measured at one oxygen mole fraction and one pressure,
   so they are converted once to partial pressures (dimension Pa) at their
   calibration pressure inside `EarthRatios`, and the CO2 compensation point
   is computed as half the O2 partial pressure over the Rubisco specificity
   factor (`Derived` from the carboxylation and oxygenation constants and the
   oxygenation-to-carboxylation capacity ratio, which are `Irreducible`
   biology), never from the published direct temperature fit of the
   compensation point, which holds only at its measurement oxygen. C4 is a
   CO2-concentrating mechanism (von Caemmerer 2000 form) with its own
   leakiness and energy cost reading the same partial pressures, so the
   pathway's advantage is `Derived`. Stomatal conductance is the Medlyn et
   al. (2011) relation with its slope `Derived` from the marginal water-cost
   trait at the column's compensation point and CO2 partial pressure (0018);
   the water-to-CO2 diffusivity ratio in that relation and the saturation
   curve behind its vapour pressure deficit are read from REQ-ATM-017 for the
   declared gas mixture. Light and dark periods are integrated over the
   planet's own rotation with phase carried across steps; the radiative
   energy integral is conserved; no 24-hour constant appears.
2. Photosynthetic (Vcmax, Jmax optima, Kattge and Knorr 2007) and
   respiratory (Atkin et al. 2014 form) temperature responses acclimate to a
   growth temperature carried as an exponential running mean whose e-folding
   time is `Bracketed` in absolute seconds with both ends sourced, no default,
   and serialised with the state. The acute response and the acclimation
   multiplier read different variables by construction.
3. Tissue stoichiometry windows are constructed so that the ratio the model
   applies equals the sourced quantity (a ratio of tissue means where the
   source measured means), with a closed-form test per tissue and element. A
   phosphorus proportion is a phosphorus measurement or is `Bracketed` and says
   so; it is never nitrogen's constant (REQ-BIO-010).
4. An explicit non-structural carbon and nutrient reserve pool exists, mass
   conserving, with a minimum functional reserve, phenological pull,
   maintenance priority and storage push; carbon debt is not a substitute.
   Reproduction is a carbon-nitrogen-phosphorus allocation to a named
   propagule pool that establishment (REQ-BIO-009) consumes.
5. Growth and maintenance respiration are per organ with living versus
   structural tissue distinguished, the root layers of REQ-BIO-008, and the
   structural carbon of gravity-aware allometry propagated through
   construction cost. A canopy-scale coefficient that stands for sub-canopy
   variance is a `Closure` (scaling law in canopy structure with a bracketed
   coefficient swept across levels) or it does not exist; no scalar carries a
   fit to another planet's totals.
6. Retained diagnostics per tile and strategy: absorbed photons and energy,
   light and dark intervals, Vcmax with its nitrogen and phosphorus limits,
   stomatal and water limitation, respiration by organ, allocation increments,
   reserve stock, reproductive allocation, and element closure per step and at the
   seasonal event the orbital tier fires (0023).

## Enforced by

- Oracle: C3 Farquhar A-Ci steady state with the fixture's O2 partial pressure,
  total pressure and temperature declared, and a second fixture at another O2
  partial pressure in which the compensation point moves in proportion; a fixture
  in which the rotation equals 24 hours reproduces the standard daily integral to
  floating-point tolerance; the closed-form stoichiometry check per tissue.
- Type: `System`-derived day and pressure fields are the only inputs the
  kernel accepts (A3, A4); the disposition refusal on any coefficient without
  one of the five dispositions; the acclimation memory a required keyword
  with no default.
- Ledgers: carbon, nitrogen and phosphorus closure at the plant level per step
  (C3), in FP64 accumulators (A7).

## References

- Farquhar, G. D., von Caemmerer, S. and Berry, J. A. (1980). A biochemical
  model of photosynthetic CO2 assimilation in leaves of C3 species. Planta
  149, 78-90. DOI: 10.1007/BF00386231.
- Bernacchi, C. J., Singsaas, E. L., Pimentel, C., Portis Jr, A. R. and Long,
  S. P. (2001). Improved temperature response functions for models of
  Rubisco-limited photosynthesis. Plant, Cell and Environment 24, 253-259.
  DOI: 10.1111/j.1365-3040.2001.00668.x.
- Medlyn, B. E. et al. (2011). Reconciling the optimal and empirical
  approaches to modelling stomatal conductance. Global Change Biology 17,
  2134-2144. DOI: 10.1111/j.1365-2486.2010.02375.x.
- Kattge, J. and Knorr, W. (2007). Temperature acclimation in a biochemical
  model of photosynthesis: a reanalysis of data from 36 species. Plant, Cell
  and Environment 30, 1176-1190. DOI: 10.1111/j.1365-3040.2007.01690.x.
- Atkin, O. K. et al. (2014). Improving representation of leaf respiration in
  large-scale predictive climate-vegetation models. New Phytologist 202,
  743-748. DOI: 10.1111/nph.12686.
- Gifford, R. M. (2003). Plant respiration in productivity models:
  conceptualisation, representation and issues for global terrestrial
  carbon-cycle research. Functional Plant Biology 30, 171-186.
  DOI: 10.1071/FP02083.
- Thum, T. et al. (2019). A new model of the coupled carbon, nitrogen, and
  phosphorus cycles in the terrestrial biosphere (QUINCY v1.0; revision 1996).
  Geoscientific Model Development 12, 4781-4802.
  DOI: 10.5194/gmd-12-4781-2019. Process-specific memory time scales; labile
  and reserve pools.
- Haxeltine, A. and Prentice, I. C. (1996). A general model for the light-use
  efficiency of primary production. Functional Ecology 10, 551-561.
  DOI: 10.2307/2390165. The 24-hour daily integral that does not transfer.
- Dietze, M. C. et al. (2014). Nonstructural Carbon in Woody Plants. Annual
  Review of Plant Biology 65, 667-687.
  DOI: 10.1146/annurev-arplant-050213-040054.
- Friend, A. D., Stevens, A. K., Knox, R. G. and Cannell, M. G. R. (1997). A
  process-based, terrestrial biosphere model of ecosystem dynamics (Hybrid
  v3.0). Ecological Modelling 95, 249-287.
  DOI: 10.1016/S0304-3800(96)00034-8. The tissue proportions measured as
  means, which the anchoring check is against.
- Franklin, O. et al. (2012). Modeling carbon allocation in trees: a search
  for principles. Tree Physiology 32, 648-666.
  DOI: 10.1093/treephys/tpr138. Allocation model classes as competing
  hypotheses.
- Walker, A. P. et al. (2014). The relationship of leaf photosynthetic traits
  - Vcmax and Jmax - to leaf nitrogen, leaf phosphorus, and specific leaf area:
  a meta-analysis and modeling study. Ecology and Evolution 4, 3218-3235.
  DOI: 10.1002/ece3.1173. Joint nitrogen-phosphorus control of capacity.
- von Caemmerer, S. (2000). Biochemical Models of Leaf Photosynthesis. CSIRO
  Publishing, Collingwood. DOI: 10.1071/9780643103405. The C4 CO2-concentrating
  form.
- /home/cfutro/docs/world/biosphere/notes/implicit-earth-assumptions.md
  findings 3 and 6 (pressure; the Earth-tuned canopy scalar).

## Amendments

- 2026-09-08: item 1: compensation point from the specificity factor and O2
  partial pressure with Bernacchi's mole-fraction constants converted once
  inside EarthRatios; C4 as a CO2-concentrating mechanism; Medlyn slope
  Derived from the marginal water cost with the diffusivity ratio and
  saturation curve from REQ-ATM-017 (audit rows 5, 12, 15), from
  notes/findings/2026-09-08-implicit-earth-audit.md
- 2026-09-08: item 6 and the A-Ci oracle: cadence on the orbital tier of
  0023; the fixture declares its atmosphere and a second O2 fixture is named
  (audit rows 32, 34), from notes/findings/2026-09-08-implicit-earth-audit.md
- 2026-09-08: cross-area review: von Caemmerer 2000 added to the references, from notes/findings/2026-09-08-implicit-earth-audit.md
