+++
id = "REQ-BIO-011"
title = "The soil nitrogen transformation operator reads the declared atmosphere and the column's own porosity and redox state, every response function is bounded on its declared domain, it cannot create nitrogen, and the gases it emits reach the atmosphere or a declared boundary"
old_path = ["/home/cfutro/docs/world/biosphere/notes/soil-nitrogen-transformation-parameterisation.md"]
old_commit = "6aa93489d233d4e9d531d6479d338c643e34bc5e"
status = "carried"
+++

## What is true

Nitrification, denitrification and ammonia volatilisation set how much
mineral nitrogen a plant can reach, so the operator is on the path from
litter to productivity whether or not anything reads its gas fluxes. The
predecessor read every constant in a stock DyN-family operator back to its
calibration (measured on the old world's fork at the archived commit, against
the held papers):

- Twelve of twenty registered constants and forms agreed with their sources;
  one was outside its source's range; seven were in neither paper. A gas
  share applied as a straight multiplier had been read from the wrong
  constant (0.33 against a bracket of 0.2 to 4.2 percent) and was worth a
  factor of 1.46 on mineral nitrogen per unit gross nitrification; a
  temperature clamp the paper does not carry held warm-soil denitrification at
  its 22 C rate; a pH dependence had been applied twice.
- The moisture variable was a fraction of available capacity where the
  source's axis is water-filled pore space; at a fixed 0.50 WFPS the aerobic
  share ranged 0.071 to 0.874 across textures for a quantity that should have
  read 0.500 everywhere. The column's upper layer stopped at field capacity, so
  the operator could never see water above it, and on half the map the dry
  threshold below which nothing denitrified never closed even at wilting
  point.
- The nitrification water response's falling limb was a double count with the
  aeration partition and its zero was one decade above where the primary
  measurement (Greaves and Carter 1920) puts it; the rising limb was checkable
  against a water-potential measurement only because the land column's
  retention closure (Cosby et al. 1984) turns pore space into a pressure axis
  per cell.
- Two Earth calibrations disagree on the N2 share of denitrification gas (a
  scheme's partition at 0.978 against incubations whose interquartile union is
  0.333 to 0.938); the partition is not separable from the reduction sequence
  that produces it, so the disagreement was declared a model boundary with both
  ends, not resolved by mixing terms.
- Pedology's pH never reached the operator: the input path dropped it and the
  fallback regression evaluated a precipitation sum nothing assigned,
  returning one constant everywhere. The operator's only conservation check
  was an `assert` compiled out of every release build.
- Five preconditions had no representation and no default: surface pressure,
  oxygen partial pressure, soil gas diffusivity, a water table and the reduced
  zone below it, and an atmospheric boundary for the emitted gases. The
  declared boundary that followed: any nitrogen-limitation result is a result
  for an Earth gas and redox environment driven by the configuration's own
  water and pH.
- A matched arm between the corrected and the stock operator moved plant
  mineral-nitrogen uptake by 0.343 percent while gross denitrification moved
  209-fold, so what the plants reach is buffered by the Michaelis-Menten
  terms and pool clamps and a coefficient's worth cannot be read by hand.

## Why it carries

B7 adopts CENTURY-family biogeochemistry with lightning nitrogen, B2 declares
the atmosphere's composition and pressure and carries tracers, and B4 resolves
soil water including saturation and a tile aquifer. The operator's Earth
assumptions are therefore inputs the system already has; the requirement is
that it read them. The bounding, conservation and boundary-declaration rules
are the general disposition and ledger discipline (A3, C3) stated for a
multi-step chemical operator with a known history of silent double counts.

## What this system must do

1. Every response function multiplying a pool is bounded in [0, 1] over the
   declared domain of the state it reads, and every chain of factors is
   bounded by the pool it draws on with an explicit clamp; the constructor
   sweeps each function over its domain and each chain as a product of maxima.
   The pH domain is pedology's declared range, so the bound is a joint
   property of the operator and the soil state that feeds it.
2. Every rate constant is `Sourced` with the temperature it was stated at, and
   a constant stated at one temperature and applied at the peak of a response
   normalised to another is recorded as a `Bracketed` pair, never silently one
   of them.
3. The moisture variable is water-filled pore space from the column's own
   porosity and water content including water above field capacity and the
   saturated zone above the tile's water table (B4, B5). Aeration is derived
   from the declared oxygen partial pressure and surface pressure through the
   column's gas diffusivity, whose free-air part is the binary diffusivity of
   oxygen in the declared gas mixture from REQ-ATM-017 and whose tortuosity
   model is `Sourced`, with the WFPS-only partition as the labelled Earth
   reduced form (`Bracketed` midpoint and shape); the reduced zone below the
   water table is a redox state the operator reads.
4. Soil pH comes from the pedology state (B8); an input path that supplies
   none makes the operator refuse rather than substitute.
5. Where two calibrations of the same quantity disagree and the quantity is
   not separable from the sequence it belongs to, the operator runs one and
   declares the other end as a `boundary` on the parameter with an owner; the
   reported partition is labelled as that scheme's, and the build lists every
   boundary on every run.
6. Conservation is compiled in every build, per step, in FP64 accumulators,
   against a floating-point-derived bar (C3). The operator's emitted NO, N2O
   and N2 enter the atmosphere's tracers (B2) or a declared boundary node of
   the nutrient ledger (REQ-BIO-012); no gas vanishes at the soil surface.
7. Any change to a community-model form is registered as a divergence with the
   original line beside the changed one and a check that the original is
   absent from the compiled source, so it can become neither a silent fork nor a
   silent revert; whether a divergence has been executed is a property of the
   entry, not of the register.

## Enforced by

- Constructor domain sweeps; the refusal on an absent pH; the compiled-in
  balance test.
- Oracle: linear pool steady states (C3); the matched-arm construction as a
  registered sensitivity, run only on accepted equilibria (REQ-BIO-014).
- Ledger: the nitrogen ledger's gas boundary term closes against the
  atmosphere's tracer source (A5).

## References

- Xu-Ri and Prentice, I. C. (2008). Terrestrial nitrogen cycle simulation
  with a dynamic global vegetation model. Global Change Biology 14,
  1745-1764. DOI: 10.1111/j.1365-2486.2008.01625.x. The DyN scheme: tables 5,
  8, 9, 10 and 11.
- Li, C., Frolking, S. and Frolking, T. A. (1992). A model of nitrous oxide
  evolution from soil driven by rainfall events: 1. Model structure and
  sensitivity. Journal of Geophysical Research 97, 9759-9776.
  DOI: 10.1029/92JD00509. The substrate definition and the Michaelis-Menten
  constants.
- Weier, K. L., Doran, J. W., Power, J. F. and Walters, D. T. (1993).
  Denitrification and the Dinitrogen/Nitrous Oxide Ratio as Affected by Soil
  Water, Available Carbon, and Nitrate. Soil Science Society of America
  Journal 57, 66-72. DOI: 10.2136/sssaj1993.03615995005700010013x.
- Linn, D. M. and Doran, J. W. (1984). Effect of Water-Filled Pore Space on
  Carbon Dioxide and Nitrous Oxide Production in Tilled and Nontilled Soils.
  Soil Science Society of America Journal 48, 1267-1272.
  DOI: 10.2136/sssaj1984.03615995004800060013x.
- Greaves, J. E. and Carter, E. G. (1920). Influence of Moisture on the
  Bacterial Activities of the Soil. Soil Science 10, 361-387.
  DOI: 10.1097/00010694-192011000-00004. The primary nitrification-moisture
  measurement.
- Stark, J. M. and Firestone, M. K. (1995). Mechanisms for soil moisture
  effects on activity of nitrifying bacteria. Applied and Environmental
  Microbiology 61, 218-221. DOI: 10.1128/aem.61.1.218-221.1995.
- Cosby, B. J., Hornberger, G. M., Clapp, R. B. and Ginn, T. R. (1984). A
  Statistical Exploration of the Relationships of Soil Moisture Characteristics
  to the Physical Properties of Soils. Water Resources Research 20, 682-690.
  DOI: 10.1029/WR020i006p00682. The bridge from pore space to a pressure
  axis.
- Pilegaard, K. (2013). Processes regulating nitric oxide emissions from
  soils. Philosophical Transactions of the Royal Society B 368, 20130126.
  DOI: 10.1098/rstb.2013.0126.
- /home/cfutro/docs/world/biosphere/notes/soil-decomposition-biogeochemistry-audit.md
  finding 8.

## Amendments

- 2026-09-08: free-air diffusivity of oxygen read from REQ-ATM-017 (audit row
  30), from notes/findings/2026-09-08-implicit-earth-audit.md
