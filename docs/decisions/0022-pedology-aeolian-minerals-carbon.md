+++
id = "0022"
title = "Pedology with a clock, dust in line, minerals as an age-aware overlay, and pCO2 solved"
status = "accepted"
date = 2026-09-08
+++

## Decision

**Pedology, with the terrain's ages available.**

- *Regolith* is prognostic: production decaying with thickness, minus the terrain's
  own denudation rate at the cell, plus catena transport at tile scale from the
  sub-grid slope distribution. Production constants `Sourced` with their spread
  `Bracketed`; the production function's form is a `Closure`, because its calibration
  climate is Earth's frost and root regime and it stands for frost cracking, root
  wedging and chemical loosening until the column's freeze-thaw crossings
  (REQ-PED-006) and the vegetation's root state supply the rate (REQ-PED-001).
- *Chemical weathering* is kinetic mineral dissolution per mineral: laboratory rate
  constants (`Sourced`; not river-chemistry fits), reactive surface area
  (`Bracketed`), water throughput from the column's drainage, pH and pCO2
  dependence, integrated over the cell's exposure age from the terrain (0015).
  Outputs: mineralogy and texture (quartz tracked separately because it does not
  weather to clay), chemical depletion, pH via calcite, gibbsite and soda buffers
  solved at the run's pCO2 (`Sourced` equilibria), solute fluxes per element,
  phosphorus release from apatite as its own mineral, and the hydraulic and thermal
  properties the land column reads (0018).
- *Brine chemistry* in closed basins: the chemical divide (first calcite saturation
  deciding the carbonate-rich or carbonate-poor path) with an activity model
  (`Sourced`); evaporite class and precipitation mass per basin per slow step are
  written into the terrain's cover stratigraphy with thickness and age.
- Runs at the slow tier on land cells of the terrain level.

**Aeolian, in line.** Dust is an atmospheric tracer in size bins: emission in the
land column's bare tiles (0018), transport by the core, settling with `g`, dry
deposition, below-cloud scavenging by the microphysics and in-cloud removal for the
soluble species; sea salt from a whitecap source in bins, the whitecap fraction
read from its one definition in the atmosphere's surface layer (0016, a function of
the friction velocity and gravity) through the source of REQ-ATM-006; volcanic
sulfate scaled
from the declared outgassing. Deposition reaches snow (impurity load), soil
(phosphorus and, above a declared deposition-rate threshold, loess as a cover
class), and the ocean (iron and phosphorus for the marine community, 0017). The dust
loop is closed because the burden feeds radiation and activation in the same step.
Refractive indices `Sourced`; roughness per surface class `Bracketed`.

**Minerals.** A prospectivity overlay keyed on the tectonic seed's provinces and
their ages, so age-controlled deposit classes are expressible. It is a field of
likelihood, never a deposit list, and never a lithology or an erodibility modifier:
anything entering the substrate enters the climate path, and a mine must not move the
planet's energy balance.

**Carbon: pCO2 solved, not declared.** A global balance stepped with the slow tier:
the change in atmospheric plus ocean carbon equals outgassing minus silicate
weathering (the kinetic dissolution flux of REQ-PED-001 and never a published
runoff-temperature form, which survive only as the REPORT bracket of thermostat
strength, REQ-PED-011; summed over exorheic land only, because alkalinity that
reaches a closed basin precipitates on its floor and never reaches the ocean) minus
carbonate burial (from the ocean's DIC and alkalinity with a lysocline
parameterisation, `Bracketed`) plus the net land carbon change. Outgassing is
`Bracketed` with a mass-scaling argument recorded. The climate refresh criterion
includes pCO2 drift (0023), so the fixed point is where weathering balances
outgassing under the climate it produces. Two caveats travel with the balance: the
requirement is driven by land area (a large-land configuration is a high-outgassing
configuration or a cold one), and carbonate buried in closed basins on stable crust
is not recycled, so outgassing is a one-way draw on the interior over secular time.
Both are reported; neither is modelled beyond the snapshot balance.

**Exchanges.** Pedology owns regolith, mineralogy, texture, pH, solute fluxes,
phosphorus supply, brine class, hydraulic and thermal properties. Aeolian burden and
deposition are owned by the atmosphere as tracers; emission by the land column.
Minerals own the prospectivity field. Carbon owns pCO2 and the outgassing budget.
Reads: exposure age, denudation and stratigraphy (terrain), drainage and temperature
(land column), organic matter (vegetation), DIC and alkalinity (ocean). Writes:
land column, vegetation, ocean (solute), terrain (evaporite cover), atmosphere
(pCO2).

## Alternatives considered

- *A weathering intensity normalised to a reference land mean* (the predecessor's
  form). Rejected: it folded time away because no age existed; with exposure age as
  state the kinetic form is the honest one.
- *Offline dust at steady state, prescribed to the next climate run.* Rejected: it
  cut the dust loop one iteration deep, and the predecessor's reopening test fired.
- *Declared pCO2.* Rejected for the operating profiles: the carbon loop can close
  once weathering, ocean chemistry and outgassing exist. A configuration may still
  declare pCO2 as a `Bracketed` initial condition, and the record says the loop is then
  open.
- *Minerals as a lithology class.* Rejected on the energy-balance argument.

## Consequences

- Soil age, regolith and weathering read a real clock.
- Dust reaches snow, soil and ocean, which the predecessor's audit found had nowhere
  to receive it.
- pCO2 is a result of the configuration, with its caveats attached.

## References

- Heimsath, A. M., Dietrich, W. E., Nishiizumi, K. and Finkel, R. C., "The soil production function and landscape equilibrium", Nature 388 (1997). DOI: 10.1038/41056
- Palandri, J. L. and Kharaka, Y. K., "A compilation of rate parameters of water-mineral interaction kinetics for application to geochemical modeling", U.S. Geological Survey Open-File Report 2004-1068 (2004). DOI: to confirm; locator USGS OFR 2004-1068
- Maher, K. and Chamberlain, C. P., "Hydrologic Regulation of Chemical Weathering and the Geologic Carbon Cycle", Science 343 (2014). DOI: 10.1126/science.1250770
- Walker, J. C. G., Hays, P. B. and Kasting, J. F., "A negative feedback mechanism for the long-term stabilization of Earth's surface temperature", Journal of Geophysical Research 86 (1981). DOI: 10.1029/JC086iC10p09776
- Kump, L. R., Brantley, S. L. and Arthur, M. A., "Chemical Weathering, Atmospheric CO2, and Climate", Annual Review of Earth and Planetary Sciences 28 (2000). DOI: 10.1146/annurev.earth.28.1.611
- Lenton, T. M., Daines, S. J. and Mills, B. J. W., "COPSE reloaded: An improved model of biogeochemical cycling over Phanerozoic time", Earth-Science Reviews 178 (2018). DOI: 10.1016/j.earscirev.2017.12.004
- Hardie, L. A. and Eugster, H. P., "The evolution of closed-basin brines", Mineralogical Society of America Special Paper 3 (1970). Locator: Mineral. Soc. Am. Spec. Pap. 3, 273-290
- Kok, J. F., "A scaling theory for the size distribution of emitted dust aerosols suggests climate models underestimate the size of the global dust cycle", Proceedings of the National Academy of Sciences 108 (2011). DOI: 10.1073/pnas.1014798108
- Kok, J. F. et al., "An improved dust emission model - Part 1: Model description and comparison against measurements", Atmospheric Chemistry and Physics 14 (2014). DOI: 10.5194/acp-14-13023-2014
- Grythe, H., Stroem, J., Krejci, R., Quinn, P. and Stohl, A., "A review of sea-spray aerosol source functions using a large global set of sea salt aerosol concentration measurements", Atmospheric Chemistry and Physics 14 (2014). DOI: 10.5194/acp-14-1277-2014
- Sillitoe, R. H., "Porphyry Copper Systems", Economic Geology 105 (2010). DOI: 10.2113/gsecongeo.105.1.3
- Groves, D. I., Goldfarb, R. J., Gebre-Mariam, M., Hagemann, S. G. and Robert, F., "Orogenic gold deposits: A proposed classification in the context of their crustal distribution and relationship to other gold deposit types", Ore Geology Reviews 13 (1998). DOI: 10.1016/S0169-1368(97)00012-7

## Amendments

- 2026-09-08: regolith production function declared a Closure with its Earth
  calibration climate named (audit row 31), from
  notes/findings/2026-09-08-implicit-earth-audit.md
- 2026-09-08: sea-salt whitecap fraction Bracketed between the wind-speed fit and a
  Froude-number form (audit row 23), from
  notes/findings/2026-09-08-implicit-earth-audit.md
- 2026-09-08: carbon balance consumes the kinetic weathering flux of REQ-PED-001;
  published forms are the REPORT bracket (audit row 14), from
  notes/findings/2026-09-08-implicit-earth-audit.md
- 2026-09-08: cross-area review: the whitecap fraction read from its one definition in decision 0016 rather than bracketed here, from notes/findings/2026-09-08-implicit-earth-audit.md
