+++
id = "REQ-ATM-010"
title = "Snow and ice material properties follow density and temperature through one relation per material shared by every component; a volumetric heat capacity is the density of the substance in the volume times its specific heat; what needs a state the model lacks is Declared with its bound"
old_path = ["/home/cfutro/git/vesper/notes/audits/cryosphere-material-properties.md"]
old_commit = "6aa93489d233d4e9d531d6479d338c643e34bc5e"
status = "carried"
+++

## What is true

Derived offline from laboratory standards and published relations, checked
against the predecessor's climate column, sea-ice module, glacier module and
vegetation model, which between them carried twelve thermal constants of snow and
ice.

- A namelist snow density stood beside a fixed snow conductivity, so a bracket
  on the density moved the pack's thickness and thermal mass and left the heat
  flux through it, which goes as k/z, on a value belonging to some other snow.
  The dependence was the defect, not the value: at the shipped density the
  adopted relation returned within a few per cent of what the model carried,
  and the relation the row had named (a needle-probe regression with a stated
  0.1 W/m/K uncertainty comparable to the value) returned half of it and would
  have made the model worse while appearing to fix a defect ("The snow
  conductivity").
- The climate column and the vegetation model computed one snowfall's
  conductivity from two published relations a factor of two apart, so the same
  snow insulated the ecology column's soil twice as well; their specific heats
  were 2090 J/kg/K (a correlation evaluated above its own stated range and above
  the melting point) and a temperature-dependent line, 16.7 per cent apart at
  -40 C. Both were replaced by one declaration each, a quadratic in temperature
  derived from the IAPWS-06 Gibbs function within 0.55 J/kg/K, restated in each
  compiled model under a check that runs ("A cross-component finding"; "two
  specific heats of one ice").
- Three volumetric heat capacities were the specific heat of ice times the wrong
  density: liquid water's for glacial ice, solid ice's for a snowpack whose
  prognostic density sat three lines above, and a fixed pack density beside a
  moving one. At fixed water equivalent a pack's thermal mass should not depend
  on density at all; pinning the capacity broke the cancellation and left the
  modelled pack 1.8 to 3.7 times too slow to warm and cool.
- Glacial ice conductivity is pure ice's reduced for the air its density
  implies; sea ice conducts less than pure ice by a brine term that needs an
  ice salinity per cell, which the model did not carry. Its density, specific
  heat and conductivity were therefore declared at the zero-salinity limit with
  the published band (nearly a factor of two across ordinary sea-ice salinities)
  as the size of what was not carried. Deduplicating the glacial and sea-ice
  conductivities would have asserted that the glaciers were salty.
- Gravity reaches ice properties through overburden compressibility at parts per
  million, and snow properties through compaction. A prognostic density was
  worth a factor of six on the pack's conductive resistance; the gravity term
  inside it was worth 14 per cent, smaller than the open fast-versus-slow
  vapour-kinetics bracket on the conductivity (53 per cent), so a run bought to
  measure the gravity term could not separate it. The compaction rate ran 1.306
  times Earth's and the density it produced 1.06 times, because the pack relaxed
  toward fresh snow at a rate set by snowfall: a rate ratio is not a state ratio.
  Density reached the surface albedo through nothing, because snow cover was
  taken in water equivalent.

## Why it carries

Decision 0018 gives the land column multilayer snow with compaction, prognostic
grain size and a soil column with phase change, and decision 0017 a three-layer
sea ice with a freezing point from local salinity; decision 0020 grows glacier
ice. Every material property those schemes read is a function of a state they
now carry, and a laboratory relation for a material transfers to any star and
any gravity except through the states gravity sets. The lessons are three: the
dependence is the constant; a volumetric capacity is dimensionally forced; and
a property that needs a state the scheme lacks is declared with the published
band as the size of the omission, not derived from a salinity nobody declared.

## What this system must do

1. Snow layer conductivity is a function of density and temperature (the
   fast-kinetics vertical effective conductivity), with the slow-kinetics
   relation as its declared bracket arm; specific heat of ice from the IAPWS-06
   equation of state in a closed form with its residual stated; melting
   enthalpy from the same standard. One implementation, read by the land column,
   the sea-ice snow layer and any other consumer (decision 0018, REQ-SYS-103).
2. Every volumetric heat capacity is the density of the substance occupying the
   volume, at the site that sets that density, times the substance's specific
   heat; a literal density inside a capacity is a lint failure.
3. Glacial ice conductivity is pure ice's exponential in temperature reduced by
   the Maxwell-Schwerdtfeger bubble term at the ice's own density; sea-ice
   properties are computed from the scheme's salinity and temperature where it
   carries them (decision 0017) and otherwise `Declared` at the zero-salinity
   limit with the published band recorded as the omission's size.
4. Snow density is prognostic with compaction under the planet's gravity and
   fresh-snow density from the tile's temperature; the compaction viscosity
   constants are `Bracketed` (mechanisms: dry cold snow at the low end, wet warm
   snow at the high end) and swept, and the pricing of any gravity-dependent rate
   is done on the state it produces, not on the rate ratio. The fresh-snow density
   relation is an empirical fit in temperature alone that hides crystal habit and
   the fall through one planet's atmosphere; it is `Bracketed` between the source
   fit in air temperature (Anderson 1976), with its site and temperature range,
   and a wet-bulb form, as decision 0018 states.
5. The snow-cover fraction the radiation reads and the canopy burial depth carry
   the physical depth from the prognostic density where the physics depends on
   depth.
6. Oracles: the Stefan problem for ice growth; the diurnal damping depth of a
   snow layer, with the period read from the system's solar-day function
   (decision 0008) and the oracle run at two declared rotation periods so a
   hard-coded day is caught; a snow-thermal gate holding every restated literal
   to the one declaration (decision 0026).

## Enforced by

- Decisions 0017, 0018, 0020; decision 0007 (`Sourced` with equation;
  `Declared` here is `Bracketed` with the band as bracket); REQ-SYS-103 (one
  declaration).
- A lint on density literals inside capacity expressions.
- The bracket sweep of decision 0007 for the kinetics arms and the compaction
  constants; the M6 Stefan gate (decision 0034).

## References

- IAPWS R10-06(2009). *Revised Release on the Equation of State 2006 for H2O Ice
  Ih.* International Association for the Properties of Water and Steam; locator:
  IAPWS release R10-06(2009), no DOI. Eq. (1), Table 2, Table 6.
- Feistel, R., Wagner, W. (2006). *A New Equation of State for H2O Ice Ih.*
  J. Phys. Chem. Ref. Data 35(2), 1021-1047. DOI: 10.1063/1.2183324.
- Fourteau, K., Domine, F., Hagenmuller, P. (2021). *Impact of water vapor
  diffusion and latent heat on the effective thermal conductivity of snow.* The
  Cryosphere 15, 2739-2755. DOI: 10.5194/tc-15-2739-2021. Eq. (18); the adopted
  fast-kinetics arm.
- Calonne, N., Flin, F., Morin, S., Lesaffre, B., Rolland du Roscoat, S.,
  Geindreau, C. (2011). *Numerical and experimental investigations of the
  effective thermal conductivity of snow.* Geophys. Res. Lett. 38, L23501.
  DOI: 10.1029/2011GL049234. Eq. (12); the slow-kinetics arm.
- Yen, Y.-C. (1981). *Review of Thermal Properties of Snow, Ice and Sea Ice.*
  CRREL Report 81-10; locator: US Army Cold Regions Research and Engineering
  Laboratory, Hanover NH, no DOI. Eqs. (33), (37), (70)-(72), Figures 22 and 23.
- Sturm, M., Holmgren, J., Konig, M., Morris, K. (1997). *The thermal conductivity
  of seasonal snow.* J. Glaciol. 43(143), 26-41. DOI: 10.3189/S0022143000002781.
  Read and not adopted.
- Riche, F., Schneebeli, M. (2013). *Thermal conductivity of snow measured by
  three independent methods and anisotropy considerations.* The Cryosphere 7,
  217-227. DOI: 10.5194/tc-7-217-2013.
- Fukusako, S. (1990). *Thermophysical Properties of Ice, Snow, and Sea Ice.*
  International Journal of Thermophysics 11(2), 353-372.
  DOI: 10.1007/BF01133567.
- Anderson, E. A. (1976). *A Point Energy and Mass Balance Model of a Snow Cover.*
  NOAA Technical Report NWS 19, Office of Hydrology, Silver Spring MD. No DOI.
  The fresh-snow density relation in air temperature and its measurement site.
- Willeit, M., Ganopolski, A. (2016). *PALADYN v1.0, a comprehensive land
  surface-vegetation-carbon cycle model of intermediate complexity.* Geosci.
  Model Dev. 9, 3817-3857. DOI: 10.5194/gmd-9-3817-2016. Eqs. (46)-(48), the
  compaction scheme and its unsourced viscosity constants.

## Amendments

- 2026-09-08: dispositioned the fresh-snow density fit as Bracketed with its site and range (audit row 21), from notes/findings/2026-09-08-implicit-earth-audit.md
- 2026-09-08: made the diurnal damping-depth oracle read its period from the system and run at two rotation periods (audit row 20), from notes/findings/2026-09-08-implicit-earth-audit.md
- 2026-09-08: cross-area review: fresh-snow density `Bracketed` between the air-temperature fit and a wet-bulb form as in decision 0018; both ends named for the compaction constants, from notes/findings/2026-09-08-implicit-earth-audit.md
