+++
id = "REQ-ATM-003"
title = "Radiation is spectrally resolved from the declared spectrum and composition; no fitted broadband absorptance is re-weighted per star; cost is measured in place against a criterion fixed first"
old_path = ["/home/cfutro/docs/world/exoplasim/notes/radiation-scheme-price.md"]
old_commit = "6aa93489d233d4e9d531d6479d338c643e34bc5e"
status = "carried"
+++

## What is true

Measured on the predecessor's two-band shortwave and broadband longwave scheme
(Lacis-Hansen and Sasamori fits) and on a correlated-k candidate priced against it.

- Keeping a fitted broadband scheme honest for one non-solar host needed ten
  per-star radiative re-derivations, seven of them multiplicative corrections onto
  fitted absorptances (water vapour, CO2, ozone in two bands, cloud co-albedo, a
  continuum bracket), one of which read a converged climatology and so needed a
  commissioning before it could be re-derived ("The maintenance half"). A
  band-resolved scheme re-weights its tables against a spectrum with no run at
  all.
- Three structural holes survived every re-weighting: the per-band attribution
  inside the CO2 total was wrong by two orders of magnitude at 2.7 um and
  survived by cancellation; 13 per cent of the CO2 shortwave absorption fell
  outside every band the fit had measured; there was no water-vapour continuum
  term ("The accuracy half"). A published user of the same model had recorded
  its band-2 water-vapour absorptance as tuned to the solar spectrum
  (`aerosol-particle-radius.md`, "The paper names the limitation").
- The broadband longwave was O(NLEV^2) in scalar `pow` behind masks; the
  candidate was O(NLEV) in vectorisable `exp`. An instruction count made the
  candidate cheaper at every corner; measured in place, per column per call, it
  was 8.6 times dearer, because the two-stream and adding algebra, k-table
  interpolation, per-band overlap and Planck integrals were most of the cost. "A
  count of one kind of operation is not a cost" was learnt twice on one row.
- A bed shorter than the model's own startup returned a confident number with
  the wrong sign; the measurement that held was a difference between two arms at
  46 times startup.
- The buy criterion (affordable below 1.5x, marginal to 3x, prohibitive above,
  at the rung where the answer changes; plus a working-set criterion with a
  disposition attached) was declared before the candidate was compiled, and the
  verdict was read against it and nothing else.
- Two greenhouse gases were absent and the absence was undeclared; adding the
  band and declaring Earth abundances as an assumption priced them at 0.8 W/m2
  (`absent-and-inherited-physics.md` finding 5).

## Why it carries

A generic builder cannot carry a ladder of per-star correction factors onto
Earth-fitted absorptances: the ladder is unbounded across stellar types and
compositions, and the holes it cannot close are structural. Decision 0016 chooses
line-by-line absorption from HITRAN and MT_CKD generated per composition and
spectrum, so the star and the gases enter as configuration. The cost discipline
carries unchanged: the GPU changes the arithmetic, not the rule that a cost is
measured in place on a bed many times its own startup against a criterion written
first.

## What this system must do

1. Gas absorption is generated once per (composition, spectrum, line-list version,
   pressure-temperature range) from the line data and continuum decision 0016 item 1
   specifies, on the device, into a k-distribution with a declared number of
   g-points per band; band edges are flux quantiles of the declared spectrum; every
   absorber in the declared composition is included and no absorber is silently
   absent (decision 0016). The pressure-temperature grid is `Derived` from the
   profile's state brackets, and an evaluation outside it during a run is written
   to the radiation ledger as an extrapolation with the fraction of columns it
   affected. What the sourced spectroscopy can carry is recorded per table: the
   database's default half-widths and the MT_CKD foreign continuum carry a
   nitrogen-oxygen bulk and nothing else, so for any other bulk the table's
   provenance names the per-perturber widths it used, the bands where the width is
   `Bracketed` by a perturber ratio, the continuum pairs it has, and the pairs that
   are declared absences (decision 0016 item 1, which owns those dispositions).
2. The pipeline accepts any stellar type and any sum of sources; there is no
   per-star correction factor anywhere in the scheme, and the surface albedo the
   scheme reads is N-band (REQ-ATM-002).
3. Generated tables are content-addressed on line-list version per absorber with
   its validity range, composition, the broadening-partner and continuum-pair set,
   the pressure-temperature grid, spectrum hash, band edges and g-point count
   (decision 0010).
4. Oracles: line-by-line reference profiles for the Sun (RFMIP-class) and
   generated line-by-line references for every declared (composition, spectrum,
   pressure-temperature range), computed on profiles drawn from the declared
   system's own brackets rather than from the RFMIP set; grey and Guillot
   analytics; blackbody and photon-currency identities (decision 0026). The
   line-by-line oracle shares its spectroscopy with the table generator, so it
   validates the k-distribution reduction and cannot judge that spectroscopy's
   applicability to the declared bulk gas; the registry says so, and the
   broadening-partner identity (a table built for a nitrogen-oxygen bulk reproduces
   the air-broadened reference, and the same absorber under a CO2 bulk with
   per-perturber widths differs from it by more than the tolerance) is the
   positive control for that gap.
5. The cost of the scheme is measured per column per call in place, on a bed at
   least an order of magnitude longer than the startup it subtracts, with A/A
   scatter measured before any bar (decision 0029); profile budgets for g-points
   and call interval are set from that measurement (decision 0014).
6. Any change to the scheme is judged against a criterion registered before the
   measurement, including a memory-budget criterion computed from the field
   registry (decision 0011).

## Enforced by

- Decision 0016 and decision 0010; the oracle registry rows for radiation
  (decision 0026); the M4 gate (decision 0034).
- The benchmark discipline of decision 0029: bed length against startup and A/A
  scatter are recorded with every cost number.
- Decision 0002: a scheme whose accuracy argument rests on an unsourced figure is
  not adopted; the 40-per-cent claim that motivated a swap was traced to general
  knowledge and retracted.

## References

- Gordon, I. E., et al. (2022). *The HITRAN2020 molecular spectroscopic database.*
  J. Quant. Spectrosc. Radiat. Transfer 277, 107949.
  DOI: 10.1016/j.jqsrt.2021.107949 (to confirm).
- Mlawer, E. J., Payne, V. H., Moncet, J.-L., Delamere, J. S., Alvarado, M. J.,
  Tobin, D. C. (2012). *Development and recent evaluation of the MT_CKD model of
  continuum absorption.* Phil. Trans. R. Soc. A 370(1968), 2520-2556.
  DOI: 10.1098/rsta.2011.0295.
- Edwards, J. M., Slingo, A. (1996). *Studies with a flexible new radiation code.
  I: Choosing a configuration for a large-scale model.* Q. J. R. Meteorol. Soc.
  122(531), 689-719. DOI: 10.1002/qj.49712253107 (to confirm). The pipeline shape
  (SOCRATES) decision 0016 names.
- Lacis, A. A., Hansen, J. E. (1974). *A Parameterization for the Absorption of
  Solar Radiation in the Earth's Atmosphere.* J. Atmos. Sci. 31(1), 118-133.
  DOI: 10.1175/1520-0469(1974)031<0118:APFTAO>2.0.CO;2. The fitted scheme the
  cost of per-star correction was measured on.
- Sasamori, T. (1968). *The Radiative Cooling Calculation for Application to
  General Circulation Experiments.* J. Appl. Meteor. 7(5), 721-729.
  DOI: 10.1175/1520-0450(1968)007<0721:TRCCFA>2.0.CO;2 (to confirm). The
  broadband longwave whose level-pair structure was the O(NLEV^2) cost.
- Rugheimer, S., Kaltenegger, L., Zsom, A., Segura, A., Sasselov, D. (2013).
  *Spectral Fingerprints of Earth-like Planets Around FGK Stars.* Astrobiology
  13(3), 251-269. DOI: 10.1089/ast.2012.0888. Trace-gas abundances as a function
  of host star, the source the undeclared absence was priced from.

## Amendments

- 2026-09-08: made the k-table build per pressure-temperature range Derived from the state brackets, with out-of-grid evaluations ledgered (audit row 4), from notes/findings/2026-09-08-implicit-earth-audit.md
- 2026-09-08: recorded per table what the air-broadened widths and the air continuum can carry, pointing to decision 0016 for the dispositions (audit rows 2, 3), from notes/findings/2026-09-08-implicit-earth-audit.md
- 2026-09-08: added the line-list range, perturber set and grid to the content address (audit row 4), from notes/findings/2026-09-08-implicit-earth-audit.md
- 2026-09-08: made the line-by-line reference per composition and pressure range on profiles from the declared brackets, and stated that it validates the reduction and not the spectroscopy, with the broadening-partner identity as positive control (audit row 5), from notes/findings/2026-09-08-implicit-earth-audit.md
