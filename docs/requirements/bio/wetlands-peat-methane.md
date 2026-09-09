+++
id = "REQ-BIO-017"
title = "Wetland extent is a tile partition closing on the land column's areas, saturation is an outcome and never a source term, methane production, oxidation and transport are separate fluxes, peat integrates on the terrain's clock, and a surface flux never sets an atmospheric abundance without the lifetime loop"
old_path = ["/home/cfutro/docs/world/biosphere/notes/wetland-activation-contract.md"]
old_commit = "6aa93489d233d4e9d531d6479d338c643e34bc5e"
status = "carried"
+++

## What is true

Two switches in an Earth vegetation model (`run_peatland`, `ifmethane`) were
four models: where wetlands are, how water reaches and leaves them, how peat
carbon and redox make and consume methane, and what an atmosphere does with
the flux. The predecessor found (measured on the old world's fork at the
archived commit):

- Extent was an externally prescribed land-cover fraction; a detailed northern
  peat model or a simplified inundated-mineral model was selected at exactly
  40 N (not absolute latitude), and the branch controlled hydrology, stress,
  decomposition and methane, not a parameter. Intercomparison spread in
  Earth wetland area alone was a factor near four (8.6 to 26.9 million km2
  sharing forcing) and propagated directly into emissions.
- The low-latitude wetland path filled every soil layer to capacity
  regardless of the rain that arrived, with the switch controlling only
  whether the created water was recorded; runon was a namelist scalar in
  mm/day applied planet-wide with no catchment. The repair bounded infiltration
  by the rain, removed the scalar, and left the exchange with routed and
  groundwater water a NAMED ABSENCE owned by the water ledger rather than a
  constant standing in for it: an absent term is one the ledger can name, a
  constant is a second account of where the water came from.
- The annual water-table average was guarded on an ordinal the calendar never
  produced, so it held zero for whole runs and pinned the acrotelm CO2 to the
  pore-water value everywhere; the prognostic peat hydrology was absent from
  the restart.
- Peat was a fixed column of three 0.1 m acrotelm over twelve 0.1 m catotelm
  layers with a 7.5 kgC/m2 transfer threshold from Earth northern peatlands;
  accumulated carbon never changed depth, hydraulics or the boundary. Peat
  depth is a rate integrated over a duration, and the terrain had no time
  axis, so a scalar peat age was a claim to a history and was refused in favour
  of a two-ended bracket.
- Methane production was a fixed CH4:CO2 fraction of bulk respiration (0.085
  from seven northern sites; 0.027 with a source comment saying it was changed
  to match global emissions) with oxidation folded in, so nothing it emitted
  was a production rate or an oxidation rate; transport fixed gravity at
  9.81, pressure at 101325 Pa, atmospheric CH4 and O2 at Earth values, 10 m
  wind at zero, 24 h in the gas-transfer velocity and 0.01 Earth-day substeps;
  ebullition was forced to the atmosphere even below an unsaturated layer;
  eleven methane parameters showed strong equifinality (the total improves
  while the diffusion, plant and ebullition partitions shift sharply). A
  plausible total can arise from compensating area, production, oxidation and
  transport errors, so acceptance is not a total.
- A table reporting a permanent zero is worse than an absent one, because it
  cannot be told from a measured zero; tables the reduced form could not
  produce were removed from the retained set rather than emitted as zeros.
- The atmosphere's methane was prescribed from a photochemical calculation
  holding modern Earth biogenic fluxes fixed; a surface flux from the
  configuration's own wetlands combined with that abundance is not one
  atmospheric state, and the gate refused the combination by name because
  nothing crashes when it is made.

## Why it carries

B7 declares wetland CH4 with a bracketed lifetime; A1's mosaic carries a
wetland tile with exact area from the fine level; B4 owns saturation-excess
runoff from the exact sub-grid index and a per-tile aquifer; B5 owns lake
level and overflow; B1 gives every cell an exposure age and rates on a real
clock; B2 carries tracers and chemistry. Each of the four models therefore has
an owner in the design, and this record states what the wetland subsystem
must read from them and what it may claim. The latitude branch, the source
term and the prescribed abundance are three forms of the same error, an Earth
boundary condition standing where a computed outcome belongs.

## What this system must do

1. Wetland extent is a partition of the tile's land (persistent peat-forming
   land, saturated non-inundated soil, seasonally inundated land, open water,
   dry mineral soil) derived from B4's saturation state on the exact sub-grid
   index, B5's lake cycle and B4's aquifer, closing on the tile's areas with
   the rootable and open-water fractions; no latitude, no prescribed fraction,
   no absolute index threshold (a topographic index transports as a rank
   statistic and shifts with mesh spacing). A class whose share is a
   convention bracket propagates as both arms or as neither; a class declared
   absent carries its reason and the record that licensed it.
2. Saturation is an outcome of the one water ledger (A5, B4): a wetland
   receives routed and groundwater water through the column's declared
   exchanges and returns every loss; there is no runon constant and no source
   term. Every hydrology member of the wetland state is restart-exact.
3. Production, oxidation and transport (diffusion, plant conduit, ebullition)
   are separate fluxes with separate diagnostics on a vertically resolved
   substrate, temperature, saturation and redox state shared with REQ-BIO-010
   and REQ-BIO-011; production reads electron-acceptor state, not a fixed
   fraction of bulk respiration; a reduced emission-factor form is a labelled
   bracket whose floor is the spread between the mechanistic and the fitted
   constants. Transport reads the system's gravity, the column's pressure, the
   declared atmospheric CH4 and O2 and the resolved wind; bubbles crossing an
   unsaturated layer are oxidised. The dry-soil aerobic sink and inland-water
   sources are terms of the same ledger.
4. Peat is a stock that integrates litter input against decomposition over the
   tile's exposure age on B1's clock, changing depth, hydraulic properties and
   the active-layer boundary; where a configuration declares an age bracket
   instead, both ends run. The active methane-producing column and the total
   peat inventory are distinct quantities.
5. Wetland vegetation is a set of strategies in the trait space (REQ-BIO-006)
   distinguishing at least bog and fen nutrient strategies, peat moss, emergent
   aerenchymatous plants, wet mineral-soil vegetation, and non-vegetated
   inundation as a state with area and no plants.
6. A surface methane flux enters the atmosphere's tracers and chemistry (B2,
   REQ-BIO-018) and the atmospheric abundance is a derived state of that loop;
   no surface flux moves a prescribed abundance, and a configuration running a
   prescribed methane with an active wetland source is refused by name. Where the
   atmosphere's chemistry carries no hydroxyl sink, the lifetime is `Bracketed`
   (dimension s) with both ends scaling with the declared ultraviolet photolysis
   rate, one the hydroxyl-limited and the other the photolysis-limited sink, and
   its Earth value is an `EarthRatios` denominator, never the bracket's centre
   (0021).
7. A retained output the current form cannot produce is absent, never a
   permanent zero. Acceptance retains area by class at native and tile
   support, the water table and its exchanges, peat stock and age bracket, the
   five methane fluxes, the sinks and sources, and water, element and
   atmospheric residuals together; matched arms (no methane, source only,
   extent bracket, redox, transport partition, feedback) are registered before
   any runs.

## Enforced by

- Type: the wetland tile is constructed from B4's saturation `Field` and B5's
  lake cycle; a constructor taking a prescribed fraction does not exist; a
  runon scalar has no keyword.
- Ledgers: water closure at the wetland exchange (A5); methane ledger with the
  five fluxes summing to the net exchange; element closure across peat
  transitions.
- Lint: latitude allowlist (REQ-BIO-005); `Dates` banned.
- Registry: bracket floors from intercomparison spread; a declared bracket
  narrower than its floor refused; a prescribed-abundance-with-active-source
  configuration refused at `assemble`.

## References

- Wania, R., Ross, I. and Prentice, I. C. (2009). Integrating peatlands and
  permafrost into a dynamic global vegetation model: 1. Evaluation and
  sensitivity of physical land surface processes. Global Biogeochemical
  Cycles 23, GB3014. DOI: 10.1029/2008GB003412.
- Wania, R., Ross, I. and Prentice, I. C. (2009). Integrating peatlands and
  permafrost into a dynamic global vegetation model: 2. Evaluation and
  sensitivity of vegetation and carbon cycle processes. Global Biogeochemical
  Cycles 23, GB3015. DOI: 10.1029/2008GB003413.
- Wania, R., Ross, I. and Prentice, I. C. (2010). Implementation and
  evaluation of a new methane model within a dynamic global vegetation model:
  LPJ-WHyMe v1.3.1. Geoscientific Model Development 3, 565-584.
  DOI: 10.5194/gmd-3-565-2010.
- Spahni, R. et al. (2011). Constraining global methane emissions and uptake
  by ecosystems. Biogeosciences 8, 1643-1665. DOI: 10.5194/bg-8-1643-2011.
- Kleinen, T., Brovkin, V. and Schuldt, R. J. (2012). A dynamic model of
  wetland extent and peat accumulation: results for the Holocene.
  Biogeosciences 9, 235-248. DOI: 10.5194/bg-9-235-2012. Peat stock as an
  integral over a history.
- Melton, J. R. et al. (2013). Present state of global wetland extent and
  wetland methane modelling: conclusions from a model inter-comparison project
  (WETCHIMP). Biogeosciences 10, 753-788. DOI: 10.5194/bg-10-753-2013. The
  extent and flux spreads that set bracket floors.
- Kallingal, J. T. et al. (2024). Optimising CH4 simulations from the
  LPJ-GUESS model v4.1 using an adaptive Markov chain Monte Carlo algorithm.
  Geoscientific Model Development 17, 2299-2324.
  DOI: 10.5194/gmd-17-2299-2024. Equifinality among production, oxidation and
  transport.
- Curry, C. L. (2007). Modeling the soil consumption of atmospheric methane
  at the global scale. Global Biogeochemical Cycles 21, GB4012.
  DOI: 10.1029/2006GB002818. The dry-soil sink.
- Rosentreter, J. A. et al. (2021). Half of global methane emissions come from
  highly variable aquatic ecosystem sources. Nature Geoscience 14, 225-230.
  DOI: 10.1038/s41561-021-00715-2.
- Saunois, M. et al. (2020). The Global Methane Budget 2000-2017. Earth System
  Science Data 12, 1561-1623. DOI: 10.5194/essd-12-1561-2020. Why a surface
  flux does not determine an abundance.
- /home/cfutro/docs/world/biosphere/notes/wetlands-peat-methane-audit.md,
  /home/cfutro/docs/world/biosphere/notes/reduced-wetland-form.md.

## Amendments

- 2026-09-08: Bracketed lifetime fallback named with ends scaling on the
  declared ultraviolet, reconciled with 0021 (audit row 2), from
  notes/findings/2026-09-08-implicit-earth-audit.md
