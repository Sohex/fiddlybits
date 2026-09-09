+++
id = "REQ-CRY-003"
title = "Where ice sits is a derived outcome of the surface mass balance on the terrain level's hypsometry, never a latitude rule or a fixed lapse rate; a thermal criterion without mass balance is an upper bound"
old_path = ["/home/cfutro/docs/world/notes/glacier-rough-pass.md"]
old_commit = "6aa93489d233d4e9d531d6479d338c643e34bc5e"
status = "carried"
+++

## What is true

`notes/glacier-rough-pass.md`, measured on the predecessor's configured planet
(radius 1.20 Earth, 32 degree obliquity, K star): the atmosphere at T42 (cells
about 300 km across, up to 4.4 km of relief invisible inside them) reported no
glaciers anywhere, and the sub-grid peak excess (1.065 km on land average,
2.97 km at the 90th percentile against a 7.6 km terrain mesh) stays sub-grid
at every rung of the ladder to T170 (94 km cells), so the atmosphere's answer
was a permanent property of its orography and not a statement about the world.
A freezing-height criterion evaluated on the mesh (warmest-month temperature
below freezing, extrapolated by a lapse rate) admitted 1.2 per cent of land on
the model's own orography and 7.1 per cent corrected to the mesh. The lapse
rate measured from the model's own profile (6.8 K/km annual, 8.4 K/km in the
warmest bin, 12.7 K/km dry adiabat from the configured composition) moved the
area by a factor of seven against an assumed 6.5, and the assumed bracket (5.5
to 6.5) sat entirely on one side of the measurement; a 5 K margin halved the
area and a 10 K margin quartered it. The terrain generator's latitude ramp
glaciated 33.7 per cent of land where the thermal criterion glaciated 0.97 per
cent on the same ground, at the same mean latitude (54.8 against 56.2 degrees)
and a different mean elevation (0.84 against 2.28 km): the ramp's error was
altitude, not latitude, and the dimensionless altitude gate is the
gravity-invariant form because the relief ceiling and a dry-adiabatic
freezing height both scale as 1/g. Without a mass balance a cold dry peak
glaciates in the criterion and would not in fact, so every thermal-criterion
area is an upper bound. On that configuration the mean glacier latitude fell
as the world cooled because lower-latitude peaks came in, ice reached the
tropics, and there was no polar cap; successive stellar-cycle minima of
different depth produced advances of different reach.

## Why it carries

The lesson is not that relief controls glaciers (that is one configuration's
outcome) but that ice placement is a computed outcome of accumulation minus
ablation evaluated on the terrain level's hypsometry under the planet's
insolation, obliquity, composition and lapse rate, and that any rule keyed on
latitude, a fixed lapse rate, or a temperature-only criterion is an
Earth-normative shortcut whose direction of error cannot be known in advance.
A generic builder can invert every coupling Earth exhibits, including ice
against relief and ice against latitude.

## What this system must do

- Glacier and ice-sheet extent is a prognostic outcome of B4's glacier
  surface mass balance (accumulation with precipitation phase, melt from the
  surface energy balance, sublimation) computed per elevation band and per
  tile from B4's downscaled forcing on the terrain level's exact hypsometry
  (A1 mosaic tiles), coupled to B6 flow. There is no placement rule keyed on
  latitude, hemisphere or a fixed lapse rate.
- The lapse rate used for downscaling is the column's own (B4), a diagnostic
  of the atmosphere's state per column and per season; it is never a declared
  constant.
- Sub-grid glaciers are tile ice stores with the volume-area scaling of Bahr et
  al. (1997) (B6), whose exponent and coefficient are `Derived` from Glen's `n`,
  the solver's `Gamma` (so from `(rho_i g)^n`) and the column's own mass-balance
  gradient by Bahr's dimensional argument; the published Earth coefficient is the
  reported distance, never the value; the tile's area and hypsometry come from the
  fine level exactly.
- A thermal-only proxy (a freezing-height mask) is permitted only as a
  diagnostic labelled an upper bound; it is never state and never a boundary
  condition for another component.
- The glaciated set feeds back to terrain (glacial erosion, load), albedo and
  hydrology (B6); its extent, volume and area-weighted mean latitude and
  elevation are reported diagnostics; ice volume drift is an exit criterion
  (B9).
- The insolation forcing carries the stellar cycle explicitly (B9), so that
  advance and retreat are distributions across cycle periods and glacial
  erosion reads a distribution rather than a single state.

## Enforced by

- B4, B6 and B9 decision records; A1 (tiles and exact sub-grid hypsometry).
- C3 oracles: an elevation-band mass-balance identity (a prescribed analytic
  climate yields a closed-form equilibrium-line altitude and accumulation
  area ratio); the Halfar dome for flow.
- C1 tier 2: glacier area and equilibrium-line altitude by region on Earth as
  a REPORT distance metric.
- C5 failure-modes row for latitude-as-classifier.
- M10 gate.

## References

- Cuffey, K. M. and Paterson, W. S. B. (2010). "The Physics of Glaciers", 4th
  edition, Butterworth-Heinemann, chapter 4 (mass balance) and chapter 5
  (equilibrium line and climate). ISBN 978-0-12-369461-4. Held as
  `cuffey2010-physics-glaciers.pdf`. (Mass balance and the equilibrium line as
  functions of climate; replaces the Oerlemans 2001 monograph, which was cited
  for the same background and carried nothing this requirement takes.)
- Hock, R. (2005). "Glacier melt: a review of processes and their modelling".
  Progress in Physical Geography 29, 362-391. DOI: 10.1191/0309133305pp453ra.
- Bahr, D. B., Meier, M. F. and Peckham, S. D. (1997). "The physical basis of
  glacier volume-area scaling". Journal of Geophysical Research 102(B9),
  20355-20362. DOI: 10.1029/97JB01696.
- Ohmura, A., Kasser, P. and Funk, M. (1992). "Climate at the equilibrium line
  of glaciers". Journal of Glaciology 38(130), 397-411. DOI: to confirm. (The
  accumulation-temperature relation at the equilibrium line, an Earth oracle.)

## Amendments

- 2026-09-08: volume-area scaling exponent and coefficient made Derived from `n`, `Gamma` and the column's mass-balance gradient (row 19), from notes/findings/2026-09-08-implicit-earth-audit.md
