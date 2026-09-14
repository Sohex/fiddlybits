+++
id = "REQ-BIO-015"
title = "Fire has an ignition mechanism derived from the atmosphere's convection, lightning is not ignition, fire weather is a chronological sequence, and no prescribed burned-area, population or biome field enters the operator"
old_path = ["/home/cfutro/git/vesper/biosphere/notes/fire-model-audit.md"]
old_commit = "6aa93489d233d4e9d531d6479d338c643e34bc5e"
status = "carried"
+++

## What is true

The predecessor audited three fire schemes and the ingredients its climate
model could supply (measured on the old world's port at the archived commit,
and on LPJmL's SPITFIRE in /home/cfutro/git/vesper/notes/external-model-survey.md
section 51):

- A burned-area regression scheme (SIMFIRE-BLAZE) has no ignition model: its
  burned area is a biome coefficient times a cover power times a fire-danger
  power times an exponential in human population density, scaled by an
  observed monthly burned-area climatology, with the biome coefficients fitted
  to Earth's satellite fire record and the population from Earth history.
  Setting population to zero removes one driver and none of the calibration.
  The archive lookup keys on rounded coordinates, so a configuration's cell
  finds a valid Earth record at the same longitude and latitude and the run
  completes: the failure mode is silent success, and a test of the form "is the
  file present" passes exactly when it should refuse. What is testable is
  whether the QUANTITY is something the configuration has.
- SPITFIRE has a mechanistic spread model (Rothermel form) under a prescribed
  lightning climatology read from a file; there is no lightning
  parameterisation anywhere in the tree, and Rothermel's slope term is not
  implemented, so gravity has no entry point: a gravity-aware scheme means
  adding slope physics, not rescaling a constant.
- Lightning is not ignition. All-flash rate, cloud-to-ground flashes and
  successful starts are distinct; SPITFIRE assumes a 20 percent
  cloud-to-ground fraction and 4 percent ignition efficiency as Earth priors;
  INFERNO's assumption that every ground strike ignites did not map one-for-one
  to burned area because the same convection that supplies lightning supplies
  rain (the wet-lightning problem).
- A CAPE-times-precipitation flash proxy (Romps et al. 2014) was validated
  for the product of SPATIALLY AVERAGED fields and not pointwise; convection
  consumes CAPE, so a local scheme needs pre-convective or upstream CAPE at
  subdaily cadence, and the climate model's CAPE diagnostic was computed after
  the convection step. Cloud-ice flux at a fixed level (Finney et al. 2014)
  gave a better Earth distribution but needs cloud ice, updraught mass flux
  and cloud fraction and still needs normalisation to an observed global flash
  rate that is model- and resolution-dependent; it bounds the structural
  uncertainty of the simpler route.
- Fire depends on event ordering (wind and dryness before a start, rain
  coincident with a strike, drying after rain) that cannot be reconstructed
  from independent monthly means; the handoff dropped humidity, wind and
  pressure and binned the rest.
- Latitude bands selected fuel class and mortality functions; a Keetch-Byram
  drought index read a short-year rainfall total into an Earth-annual
  coefficient (0.46 to 0.69 of the intended drying, climate-dependent because
  the term is exponential); a Nesterov accumulator adds once per model day
  with no rate constant; the one-day fire duration of Li et al. (2012) is
  anchored to a diurnal drying cycle rather than to a count; a Canadian
  fire-weather block with month-indexed daylength tables was diagnostic only
  and deletable.
- A burn-probability floor of 0.001 per year carried "c.f. LPJF" as its whole
  justification; walking the chain to its end found two implementations and two
  papers and no derivation: the number is a reporting cap on the fire return
  interval applied to the state, at one per EARTH year. It bound on 59.7
  percent of gridcell-years, where the operator's own burned fraction was
  1.65e-10, and over the derived spin-up it replaced rather than perturbed the
  cohort age structure on about half the land. Rescaling a number with no
  derivation was refused; it was deleted, and the deletion registered as a
  declared divergence with the original line recorded beside the absence.
- Fire moved 11.7 percent of the simulated carbon turnover, unevenly (41
  percent of cells never burned; 3 percent routed more than a quarter of their
  carbon through fire), so every fire question is a question about a material
  term.

## Why it carries

B7 adopts SPITFIRE-class mechanism and B2 resolves convection with a
mass-flux plume and carries tracers, so an ignition field can be derived from
the system rather than prescribed: that is the first fire row a generic
builder opens, because a prescribed Earth field is the one input no
configuration has. The three-seam division (ignition and occurrence, spread
and area, effects) is what lets each Earth constant be bracketed at its own
seam; and "physics is not a knob" (design idea 17) is why a state floor with no
derivation is deleted rather than rescaled. FireMIP's evaluation warning
(correct burned area from compensating biases) is why acceptance is
mechanistic and comparative.

## What this system must do

1. Ignition is derived. The atmosphere (B2) emits a lightning-potential
   diagnostic synchronous with convective precipitation at the fast step,
   from a pre-convective or updraught-based proxy whose normalisation is a
   `Bracketed` constant with the structural alternative (cloud-ice flux)
   registered as the other end; the diagnostic keeps subdaily accumulation
   semantics across the exchange (REQ-BIO-002). Cloud-to-ground fraction and
   successful-ignition efficiency are explicit `Bracketed` priors, and the
   wet-lightning filter (rain coincident with the strike) is exposed. Human
   ignition and suppression are absent unless B10's driven mode declares
   them. A ubiquitous-ignition case is a labelled model-form control.
2. Three seams, separable as model form: ignition and occurrence; spread and
   burned area with a Rothermel-family rate of spread including the slope term
   and wind from the column's resolved surface wind at a declared height; effects
   (REQ-BIO-016). What the Rothermel form carries and what it cannot: its slope
   factor is a function of the tangent of the slope alone and its wind factor an
   empirical function of wind speed, so neither contains gravity or air density,
   and a gravity change leaves the published form unmoved. Gravity enters spread
   through a Froude scaling of the wind and slope factors (flame tilt and
   buoyancy), `Bracketed` (dimensionless) between the published flame-tilt
   relations (Albini 1976; Nelson 2002), and through the air density of
   REQ-ATM-017 in the convective heat-transfer terms; fuel geometry carries none
   of it. Every Earth coefficient at each seam carries a disposition;
   a constant whose only provenance is a restatement in another code is not
   `Sourced`.
3. Fire weather is the chronological sequence of the daily tier's step
   (0023): temperature, humidity, wind, pressure and precipitation phase with
   event order preserved; drought and danger indices are integrals on the
   system clock with every rate constant classified (REQ-BIO-001); a fire
   duration anchored to a drying cycle carries the rotation period; a memory
   expressed as a count of days is declared as absolute time or as a fraction
   of the seasonal cycle.
4. No prescribed burned-area climatology, population history or biome map
   enters the operator; fuel class and every regime are selected by vegetation
   and fuel state (REQ-BIO-005). A capability the configuration cannot supply
   refuses by name; a file being present is never the test.
5. No floor, cap or minimum on a state variable exists without a derivation;
   a diagnostic reporting cap is applied to the diagnostic. Every divergence
   from a community-model form is registered with the original line beside the
   change and a check that the original is absent from the compiled source.
6. Acceptance is mechanistic and comparative: no-fire, ubiquitous-ignition and
   lightning-driven arms under identical forcing; retained ignitions,
   flammability, area per fire, burned fraction, return interval, intensity
   and mortality; model choice reported as uncertainty in productivity,
   albedo, soil and smoke, never collapsed to one tuned answer.
7. The oxygen and pressure rule of 0021 applies to every combustion quantity.
   Fire runs only inside a `Sourced` oxygen flammability window (the lower limit
   of flame propagation in cellulosic fuel and the upper limit above which wet
   fuel ignites; Watson et al. 1978; Belcher et al. 2010), evaluated on the
   declared O2 partial pressure and total pressure from B2; a configuration
   outside the window refuses fire by name rather than burning. Reaction
   intensity and moisture of extinction carry `Bracketed` (dimensionless)
   scalings in O2 partial pressure about the calibration atmosphere of their
   source, the ends being the flame-propagation-limited and the
   fuel-drying-limited mechanisms, with the calibration values as `EarthRatios`
   denominators.

## Enforced by

- Type: the fire operator is constructed only with a lightning `Field` from
  the atmosphere and a fuel state from the vegetation; a prescribed ignition
  or burned-area field has no constructor.
- Oracle: Rothermel spread against its published test cases including a
  slope; the Earth instance's burned fraction and flash-rate pattern as
  REPORT metrics (C1); a gravity sweep must move spread through the Froude scaling
  of the wind and slope factors and through air density, and the oracle names
  those terms as the ones expected to move; an oxygen sweep must cross the
  flammability window and refuse outside it.
- Registry: every `Bracketed` fire constant swept (M8 gate); the divergence
  register checked per commit; the C4 mutation run restores a state floor and
  must be caught.

## References

- Thonicke, K. et al. (2010). The influence of vegetation, fire spread and
  fire behaviour on biomass burning and trace gas emissions: results from a
  process-based model SPITFIRE. Biogeosciences 7, 1991-2011.
  DOI: 10.5194/bg-7-1991-2010.
- Rothermel, R. C. (1972). A mathematical model for predicting fire spread in
  wildland fuels. USDA Forest Service Research Paper INT-115, Intermountain
  Forest and Range Experiment Station, Ogden, Utah. DOI: 10.2737/INT-RP-115.
  The spread model including the slope term.
- Li, F., Zeng, X. D. and Levis, S. (2012). A process-based fire
  parameterization of intermediate complexity in a Dynamic Global Vegetation
  Model. Biogeosciences 9, 2761-2780. DOI: 10.5194/bg-9-2761-2012. The
  count-to-area seam and the diurnally anchored fire duration.
- Mangeon, S. et al. (2016). INFERNO: a fire and emissions scheme for the UK
  Met Office's Unified Model. Geoscientific Model Development 9, 2685-2700.
  DOI: 10.5194/gmd-9-2685-2016. The reduced occurrence layer and the
  wet-lightning result.
- Knorr, W., Kaminski, T., Arneth, A. and Weber, U. (2014). Impact of human
  population density on fire frequency at the global scale. Biogeosciences 11,
  1085-1102. DOI: 10.5194/bg-11-1085-2014. The burned-area regression whose
  calibration does not transfer.
- Romps, D. M., Seeley, J. T., Vollaro, D. and Molinari, J. (2014). Projected
  increase in lightning strikes in the United States due to global warming.
  Science 346, 851-854. DOI: 10.1126/science.1259100. The CAPE-times-
  precipitation proxy and its spatial-average caveat.
- Finney, D. L., Doherty, R. M., Wild, O., Huntrieser, H., Pumphrey, H. C.
  and Blyth, A. M. (2014). Using cloud ice flux to parametrise large-scale
  lightning. Atmospheric Chemistry and Physics 14, 12665-12682.
  DOI: 10.5194/acp-14-12665-2014.
- Price, C. and Rind, D. (1992). A simple lightning parameterization for
  calculating global lightning distributions. Journal of Geophysical Research
  97, 9919-9933. DOI: 10.1029/92JD00719. The cloud-top-height alternative
  and the cloud-to-ground fraction.
- Rabin, S. S. et al. (2017). The Fire Modeling Intercomparison Project
  (FireMIP), phase 1: experimental and analytical protocols with detailed model
  descriptions. Geoscientific Model Development 10, 1175-1197.
  DOI: 10.5194/gmd-10-1175-2017. The three-seam division and the
  compensating-bias warning.
- Hantson, S. et al. (2016). The status and challenge of global fire
  modelling. Biogeosciences 13, 3359-3375. DOI: 10.5194/bg-13-3359-2016.
- Thonicke, K., Venevsky, S., Sitch, S. and Cramer, W. (2001). The role of
  fire disturbance for global vegetation dynamics: coupling fire into a
  Dynamic Global Vegetation Model. Global Ecology and Biogeography 10,
  661-677. DOI: to confirm. States no minimum burned fraction; the source
  the deleted floor was walked back to.
- Keetch, J. J. and Byram, G. M. (1968). A drought index for forest fire
  control. USDA Forest Service Research Paper SE-38, Southeastern Forest
  Experiment Station, Asheville. Locator: USDA FS SE-38.
- /home/cfutro/git/vesper/biosphere/config/fire.yaml (the register of fire
  operator divergences and the deleted floor's argument).
- Albini, F. A. (1976). Estimating wildfire behavior and effects. USDA Forest
  Service General Technical Report INT-30, Intermountain Forest and Range
  Experiment Station, Ogden, Utah. No DOI. The flame-tilt relation at one end of
  the Froude scaling.
- Nelson, R. M. (2002). An effective wind speed for models of fire spread.
  International Journal of Wildland Fire 11, 153-161. DOI: 10.1071/WF02031. The
  flame-tilt relation at the other end.
- Watson, A., Lovelock, J. E. and Margulis, L. (1978). Methanogenesis, fires and
  the regulation of atmospheric oxygen. BioSystems 10, 293-298.
  DOI: 10.1016/0303-2647(78)90012-6. The lower limit of the oxygen flammability
  window.
- Belcher, C. M., Yearsley, J. M., Hadden, R. M., McElwain, J. C. and Rein, G.
  (2010). Baseline intrinsic flammability of Earth's ecosystems estimated from
  paleoatmospheric oxygen over the past 350 million years. Proceedings of the
  National Academy of Sciences 107, 22448-22453. DOI: 10.1073/pnas.1011974107.
  The window's measured limits.
- /home/cfutro/git/vesper/notes/external-model-survey.md section 51.

## Amendments

- 2026-09-08: item 2 states what Rothermel's slope and wind factors carry (no
  gravity, no air density) and where gravity enters (Froude scaling Bracketed
  on Albini 1976 and Nelson 2002; air density from REQ-ATM-017); the
  gravity-sweep oracle names the term (audit row 4), from
  notes/findings/2026-09-08-implicit-earth-audit.md
- 2026-09-08: item 7 adds the Sourced oxygen flammability window and the
  Bracketed O2 scalings of reaction intensity and moisture of extinction
  (audit row 1), from notes/findings/2026-09-08-implicit-earth-audit.md
- 2026-09-08: cadence wording replaced by the daily tier of 0023, from
  notes/findings/2026-09-08-implicit-earth-audit.md
- 2026-09-08: cross-area review: Albini 1976, Nelson 2002, Watson, Lovelock and Margulis 1978 and Belcher et al. 2010 added to the references, from notes/findings/2026-09-08-implicit-earth-audit.md
