+++
id = "REQ-ATM-012"
title = "A lake is a tile with a water column, ice with latent heat, a freezing point from its own salinity, and open-water evaporation of the water routed to it"
old_path = ["/home/cfutro/git/vesper/notes/audits/lake-energy-omission-bound.md"]
old_commit = "6aa93489d233d4e9d531d6479d338c643e34bc5e"
status = "carried"
+++

## What is true

Computed in closed form from the predecessor's own constants and orbital period,
then thresholded against a baseline climatology and a solved lake set, on a
planet where three quarters of the land drained internally.

- The model had no lake; a lake cell got the soil column, a semi-infinite solid
  of thermal inertia about 2063 J/m2/K/s^0.5 at the orbital frequency, whose
  surface admittance was equivalent to 0.79 m of well-mixed water ("What the
  surrogate is").
- Freezing was absent and dominant: freezing one metre of ice released the heat
  the surrogate exchanged over a 93 K seasonal swing. 56 to 64 per cent of lake
  area (51 to 56 per cent of all land, so the verdict did not rest on where the
  lakes sat) had a seasonal minimum below the fresh freezing point; the
  equivalent ice thickness at which phase dominated the sensible term was 0.58 m
  at the median over the freezing area (finding "Term 1").
- The water column's sensible heat was bounded from the radiative damping
  alone: a 2 m lake was represented exactly, a shallower one over-damped, a 10 m
  lake's amplitude 0.3 to 0.7 of the surrogate's, and the phase could be wrong by
  at most 40.6 days, saturating by 30 m, so a depth class finer than about ten
  metres bought nothing on that axis. The solved population straddled that
  boundary at 45/55 per cent.
- The fresh-to-brine property bracket was not a driver (under 1.2 on `rho c`
  against a factor of 200 on depth); salinity mattered through the freezing
  point instead, deciding whether the dominant term switched on over 24 per
  cent of lake area.
- All of it sat inside a larger mass omission: routed runoff discharged to the
  ocean and nothing evaporated from it, so a closed basin's lake could not
  evaporate its catchment's delivery. Measured on the same climatology, the net
  moisture source of the lakes was -0.9 per cent of land precipitation, negative
  because that model's rough land evaporated more than a smooth water surface
  would over the same ground (`unpriced-terms.md` finding 1); the estimator was
  biased against the lake by using catchment means. The model's pit-filling
  routing, which looked like the defect, was what kept its water budget closed.
- The instruction that followed: do not choose a lake implementation on depth
  classes; the ranking is freezing, then the column's sensible heat, then
  salinity as a property, and the mass term first of all.

## Why it carries

Decision 0018 gives every column lake tiles with 1-D lakes and ice, fed by
decision 0019's fill-spill-merge lake level, area and volume, with bulk
aerodynamic evaporation everywhere. This audit is the evidence that the phase
term is the first thing a lake tile must carry, that the mass term (open water
evaporating routed water) is larger than the whole energy question, and that a
surrogate solid can never be a bound on either. The method carries too: bound the
omission in closed form before choosing an implementation, and rank the levers
by what the bound says rather than by the axis the row was filed under.

## What this system must do

1. Every column with lake area from the hydrology component carries a lake tile
   with a 1-D thermal column (mixed layer over a stratified profile with
   eddy-diffusive mixing), ice cover with latent heat of freezing and melting,
   snow on ice, and a freezing point from the lake's own salinity through the
   water-property door of 0017 at that salinity inside the Reference-Composition
   tolerance; a closed-basin brine beyond the tolerance reads its density and
   freezing point from the brine activity model of 0022 (decisions 0017, 0018,
   0019, 0022).
2. Lake area, depth and volume come from the solved basin hypsometry and water
   balance (decision 0019); the lake evaporates from its surface with the open-
   water roughness form decision 0016 owns (Charnock with `g` explicit) and the
   condensable's saturation vapour pressure from REQ-ATM-017, and receives its
   catchment's routed discharge, so a closed basin at equilibrium evaporates its
   delivery from the lake (decision 0018, "bulk aerodynamic evaporation
   everywhere").
3. Lake salinity is a state fed by river solute and evaporation (decision
   0022's brine divide); the freezing point reads it.
4. The water and energy ledgers close at the lake exchange, and the lake's
   phase term appears in the column energy balance the atmosphere reads.
5. Oracles: the Stefan problem for ice growth; the closed-form seasonal
   response of a mixed column of declared depth against the tile's, with the
   period read from the system's orbital-period function (decision 0008) and run
   at two declared orbital periods; the closed-form lake cascade; the HydroLAKES
   equilibrium test on the Earth instance (decisions 0026, 0034).

## Enforced by

- Decisions 0018, 0019, 0022; decision 0009 (ledgers at the exchange).
- The M2 and M5 gates (decision 0034): basin discharge, land P-E against runoff,
  ledgers closed at the seam.

## References

- Hostetler, S. W., Bartlein, P. J. (1990). *Simulation of lake evaporation with
  application to modeling lake level variations of Harney-Malheur Lake, Oregon.*
  Water Resour. Res. 26(10), 2603-2612. DOI: 10.1029/WR026i010p02603 (to
  confirm). The 1-D eddy-diffusion lake thermal model with ice.
- Subin, Z. M., Riley, W. J., Mironov, D. (2012). *An improved lake model for
  climate simulations: Model structure, evaluation, and sensitivity analyses in
  CESM1.* J. Adv. Model. Earth Syst. 4, M02001. DOI: 10.1029/2011MS000072 (to
  confirm). The lake tile structure inside a land column, the reference
  decision 0018 models on.

## Amendments

- 2026-09-08: pointed the freezing point to the ocean's relation and the evaporation to the open-water roughness of decision 0016 and the saturation relation of REQ-ATM-017 (audit rows 10, 38), from notes/findings/2026-09-08-implicit-earth-audit.md
- 2026-09-08: made the seasonal-response oracle read its period from the system and run at two orbital periods (audit row 20), from notes/findings/2026-09-08-implicit-earth-audit.md
- 2026-09-08: cross-area review: the freezing point read from the 0017 door at the lake's salinity inside the Reference-Composition tolerance and from 0022's brine activity model beyond it, from notes/findings/2026-09-08-implicit-earth-audit.md
