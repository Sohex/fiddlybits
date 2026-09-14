+++
id = "REQ-PED-008"
title = "Closed-basin brine chemistry by the chemical divide, computed per basin from catchment release weighted by local runoff generation, with the evaporite mineralogy set by the catchment's rocks"
old_path = ["/home/cfutro/git/vesper/pedology/notes/derived-surface-classes.md"]
old_commit = "6aa93489d233d4e9d531d6479d338c643e34bc5e"
status = "carried"
+++

## What is true

Eugster and Jones (1979) sort the major solutes into five behaviours under
evaporative concentration (conserved; a cation-anion pair precipitating a mineral,
where the minor one crashes at the branching point; gradual removal; sigmoid removal
mid-range; constant once saturated with a solid). The branching point is the chemical
divide of Hardie and Eugster (1970): calcite removes Ca and CO3 in equal equivalents,
so whichever is in excess at saturation dominates every later step and nothing
downstream undoes it. Meybeck (1987) Table 2C gives the Ca, HCO3 and SO4 a lithology
releases, so release and fate compose with no intermediate step. Every silicate and
carbonate lithology in that table falls on the alkaline side (Ca/HCO3 from 0.11 for
peridotite to 0.80 for carbonate rock) and only the evaporites cross (1.50, 3.25),
which predicts soda lakes as the default closed-basin chemistry and gypsum only where
the catchment already drains evaporite. Measured 2026-08-17 on the predecessor's
generated world: 2,757 of 2,966 resolved basins alkaline, holding 94.6% of resolved
catchment area. Gypcrete fell from 7.30% of land (the climatic window alone) to 0.70%
under the ion gate, 19 times enriched in carbonate-poor catchments, a prediction before
it was a measurement; the calcrete gate did not bind because every lithology supplies
Ca and HCO3, and was kept so that a failing lithology would be visible.

The weighting is local runoff generation (`P - E` clamped at zero times cell area),
not accumulated discharge, which would count every upstream cell again at every
downstream one and let a few cells near the sink decide a basin, and not area, which
lets a dry interior contribute area and no solute; 109 basins changed side between the
two, and 655 basins with a catchment but no runoff were reported undetermined rather
than falling back, because a basin that receives no water has no brine to evolve. The
check that can fail is that a basin draining one rock class returns that class's own
row (108 basins, worst error 1.2e-15). The divide is decided by catchment lithology,
not by the basin floor's rock, so a basin's evaporite mineralogy is set by rock it does
not sit on. Not carried in that pass: Mg and dolomite; and Meybeck's values are
temperate-stream release, setting the ordering rather than absolute concentrations.
Dissolved silica: 68.4% of the world's release was delivered to closed basins by
routing, where an earlier figure of 21.6% was the share released on basin-floor cells
(one quantity, two meanings); silica saturation (type V) is what supplies silcrete and
diatomite, and the silica gate did not bind.

## Why it carries

B8 names the Hardie-Eugster brine divide writing evaporite cover into the
stratigraphy; B3 carries salinity as a budget with river solute and evaporite sinks;
B5 gives the lake volume that sets the concentration factor; REQ-HYD-010's lake tile
and REQ-PED-003's sump buffer read the result. The divide is equilibrium
thermodynamics and transfers to any water composition; the weighting rule is the
conservation-correct one for any routed solute; "undetermined" as a state and the
single-lithology identity are general.

## What this system must do

- Per closed basin, the inflow solute composition is the catchment's release from
  kinetic weathering (REQ-PED-001) per fine cell, weighted by that cell's generated
  runoff and routed on the drainage graph; Meybeck's rows are the Earth REPORT check of
  the resulting lithology ordering.
- The calcite divide, then gypsum, then the sigmoid removals are evaluated on the
  lake's concentration factor from the lake balance (REQ-HYD-011), and the resulting
  evaporite class is written into B1's cover stratigraphy on the sump tile; Mg and
  dolomite are a declared absence until carried.
- A basin with no inflow is undetermined, never defaulted.
- The single-lithology identity runs per commit.
- Delivered and released solute are two named quantities; silica saturation supplies
  the silcrete and diatomite gates (REQ-PED-009).
- Lake salinity and brine pH pass to the lake tile and to the sump's soil pH; the soda
  buffer is Bracketed by measured closed-basin lake water until a trona or nahcolite
  saturation solve at the run's `pCO2` with Pitzer activities exists.

## Enforced by

A5 ownership (brine chemistry has one writer); the single-lithology identity; the
salt ledger of B3; the gypcrete-enrichment prediction as a REPORT metric.

## References

- The evolution of closed-basin brines. Hardie, Eugster (1970), Mineralogical Society
  of America Special Paper 3, 273-290. Locator: MSA Special Paper 3 (pre-DOI)
- Behavior of major solutes during closed-basin brine evolution. Eugster, Jones (1979),
  American Journal of Science 279, 609-631. DOI: 10.2475/ajs.279.6.609
- Global chemical weathering of surficial rocks estimated from river dissolved loads.
  Meybeck (1987), American Journal of Science 287, 401-428. DOI: 10.2475/ajs.287.5.401
- Geochemistry of Saline Lakes. Deocampo, Jones (2014), Treatise on Geochemistry, 2nd
  edition, volume 7, 437-469. DOI: to confirm (10.1016/B978-0-08-095975-7.00515-5
  believed)
- Thermodynamics of electrolytes. I. Theoretical basis and general equations. Pitzer
  (1973), Journal of Physical Chemistry 77, 268-277. DOI: 10.1021/j100621a026
