+++
id = "REQ-SYS-006"
title = "The land column that produces runoff carries every process that moves land water, and runoff is budgeted as the residual it is"
old_path = ["/home/cfutro/git/vesper/notes/audits/missed-couplings.md"]
old_commit = "6aa93489d233d4e9d531d6479d338c643e34bc5e"
status = "carried"
+++

## What is true

The audit of 2026-08-17 hunted for seams between two correct components that nobody
had priced. Its largest finding (finding 4) was verified in the vendored climate
model's source: land evaporation's entire dependence on the land surface was one
coefficient, a bucket wetness factor times a turbulent transfer coefficient assembled
from wind, stability and roughness. Nothing in the land, flux or surface modules
mentioned a root, a canopy, an interception store or a transpiration term; forest
fraction reached only the snow albedo; the vegetation module that could be switched on
carried a "stomatal conductance" that was a prescribed field never assigned again and a
leaf area index computed and used nowhere but output. So a vegetated cell and a bare
cell holding the same soil water evaporated identically apart from roughness. The
biosphere reached the climate through albedo (priced at 4.28 K, the largest item in the
error budget) and roughness, and not through water.

Meanwhile the pedology component recorded, from Lapides et al. (2024), that adding a
bedrock vadose zone to the vegetation model raised annual transpiration by a median of
100 to 150 mm. Against that configuration's land runoff of 126.4 mm per Earth year that
is the entire residual: the biosphere component knew transpiration was worth about one
runoff, and none of it was represented in the model that produced the runoff. The
direction is not obvious (stomatal closure reduces evaporation relative to a wet
bucket; deep roots reaching water the bucket cannot hold increase it); the magnitude is
what matters.

Finding 1 supplies the amplification. On the baseline (measured on
`baseline_regular_climatology.nc`, build `precarve-craton`): land precipitation 816.4,
land evaporation 690.0, runoff 126.4 mm per Earth year, 15.5 per cent of
precipitation. Runoff is the difference of two numbers five to six times its own size,
so a fractional error in precipitation is amplified 6.5x and in evaporation 5.5x into
runoff; a 10 per cent error in land evaporation is 55 per cent of the runoff. The error
budget priced every item in kelvin or W/m2 and not one in runoff, evaporation or
basins, while the one irreversible decision (the carve list, which leaves the project
and changes the terrain) reads runoff as its denominator. A kelvin-priced item nearly
cancels in runoff (about one per cent per kelvin, because a warmer world raises land
evaporation slightly faster than precipitation); a perturbation that changes the water
cycle without changing the temperature is amplified by the full P/R. The fourth
channel, soil water capacity carrying vegetation carbon, was measured near-inert: a
3.75-fold change in bucket capacity moved land runoff by 1.06x because the bucket sat
at a median 15 per cent of capacity.

## Why it carries

Any builder produces runoff as precipitation minus evaporation over land, and wherever
evaporation is large relative to runoff the residual amplifies every error in either
term. A coupling that exists in the physics but is absent from the model producing a
decision is a structural one-way coupling, and it is silent: the bucket model's
evaporation is a plausible number. The plan's verdict names this as the largest known
physics hole in the predecessor and the reason a single shared land column is the
design (A5, B4). The specific magnitudes are that configuration's; what carries is the
structure of the residual and the requirement that the model producing runoff carries
every process that moves land water.

## What this system must do

- One land column (B4) is read by both the climate and the vegetation, with exactly
  one declared writer per water store (canopy, snow, soil layers, weathered bedrock,
  aquifer, lake).
- Land evaporation is partitioned into soil evaporation, transpiration through a
  stomatal conductance driven by the vegetation state and the column's water, canopy
  interception, open-water evaporation and snow sublimation, each a named term in the
  column's water ledger; rooting depth is a trait reaching a weathered-bedrock store.
- Where a configuration has no vegetation, the transpiration term is a declared zero
  with the same interface, not an absent channel.
- The runoff amplification factor P/R over land is reported per configuration as a
  standing diagnostic, and any error budget that gates a decision reading runoff
  prices its items in runoff (REQ-PROC-005).
- The vegetation-to-climate coupling is reported in both its radiative and its
  hydrological currency, and a coupling that exists in physics but is absent from a
  profile is a declared absence with its magnitude bracketed against runoff.
- Land P minus E against routed discharge closes as a ledger at the land-hydrology
  seam and at the coast.

## Enforced by

Decision A5 (`WorldState` single writer, `Exchange` ledgers); B4; the M5 gate "land
P-E vs runoff; ledgers closed at the seam"; C3 water-budget oracles; declared-absence
records.

## References

- /home/cfutro/git/vesper/notes/audits/missed-couplings.md, findings 1 and 4
- /home/cfutro/git/vesper/docs/src/pipeline/loops.md ("That coupling is radiative and aerodynamic, and it is not hydrological")
- Lapides et al. (2024), Biogeosciences: the bedrock vadose zone added to LPJ-GUESS raising annual transpiration by 100 to 150 mm. Verbatim title and DOI: to confirm (cited secondhand in /home/cfutro/git/vesper/pedology/README.md; the number is not carried as sourced)
- Plan decisions A5, B4, B5.
