+++
id = "REQ-PED-005"
title = "The moisture driver of weathering is runoff, meaning P minus E from the closed water balance and never a routed-runoff diagnostic, and land means hide a skewed distribution"
old_path = ["/home/cfutro/git/vesper/pedology/README.md"]
old_commit = "6aa93489d233d4e9d531d6479d338c643e34bc5e"
status = "carried"
+++

## What is true

Weathering is limited by water passing through the profile and carrying solutes away,
not by water that falls and evaporates; the Walker-Hays-Kasting law is defined on river
runoff and its 0.65 exponent traces to Dunne (1978) and Peters (1984), both fitted
against runoff, so precipitation was never a co-equal alternative. The predecessor's
runoff-versus-precipitation spread (3.41x on weathering intensity, 2.83x on water
capacity, 2.74x on land-mean regolith depth) was therefore a sensitivity to report
where a result turns on it, not an uncertainty to present as an equally likely world.

The climate model's routed-runoff diagnostic read 25 mm per Earth year, a runoff ratio
of 2.8%, and was blamed on the land bucket. Both halves were wrong. The diagnostic is
river-routed net divergence rather than local generation; `P - E` gave 168 mm; the
global water budget closed to one part in ten thousand; an offline reimplementation
of the bucket reproduced the land budget at a ratio of 0.89 inside a band fixed
beforehand; and shrinking the bucket 3.75-fold moved runoff by 1.06x, because the
bucket sat at a median 15% of capacity and overflow came from the wettest cells and
seasons, which saturate at either depth. The low ratio (a sixth, against Earth's
roughly a third) was a property of the climate. Land runoff averaged 130 mm per Earth
year with a median of 3.8, and two thirds of the land was under 50 mm/yr (measured
2026-08-17 on the predecessor's generated world under its bootstrap climatology), so a
mean runoff ratio described almost none of the surface and the same skew ran through
every derived field (plant-available capacity mean 151 mm against median 84; regolith
depth 1.16 m against 0.66). Within one configuration, depth is set by terrain
(r-squared 0.006 on runoff, 0.027 on temperature); between configurations the
moisture driver moves the whole field.

## Why it carries

B4 makes runoff a prognostic term of the one land column, and REQ-HYD-012 closes the
ledger at the model step, so `P - E - dS/dt = runoff` is an identity rather than a
choice between diagnostics. The generic lesson is that a diagnostic whose definition
differs from the quantity a law was fitted on cannot drive that law, and that the
fitted variable is the one to supply. The M5 gate (land `P - E` against runoff) is
this identity. Reporting distributions beside means for skewed land fields is a rule
for every land artifact.

## What this system must do

- Weathering, regolith production and the pH leaching index read the column's own
  generated runoff (infiltration-excess plus saturation-excess plus drainage to the
  aquifer that leaves as baseflow) accumulated over a closed cycle from the ledger.
- Identity test: over a closed cycle, generated runoff equals `P - E - dS` at every
  column to the ledger's tolerance; a routed discharge divided by an area never stands
  in for local generation.
- Sensitivity to the moisture variable is reported where a result depends on it and is
  never presented as an alternative configuration.
- Land artifacts carry quantiles and area shares beside means; a report of a skewed
  field that quotes a mean alone fails its schema.

## Enforced by

The ledger identity (REQ-HYD-012); A2 field semantics (a flux density is not an
extensive discharge); the M5 gate; the artifact schema requiring quantiles.

## References

- A negative feedback mechanism for the long-term stabilization of Earth's surface
  temperature. Walker, Hays, Kasting (1981), Journal of Geophysical Research 86,
  9776-9782. DOI: 10.1029/JC086iC10p09776
- The carbonate-silicate geochemical cycle and its effect on atmospheric carbon dioxide
  over the past 100 million years. Berner, Lasaga, Garrels (1983), American Journal of
  Science 283, 641-683. DOI: 10.2475/ajs.283.7.641
- Field studies of hillslope flow processes. Dunne (1978), in Hillslope Hydrology
  (Kirkby, ed.), Wiley, 227-293. Locator: ISBN 0-471-99510-X (978-0-471-99510-4)
- Evaluation of environmental factors affecting yields of major dissolved ions of
  streams in the United States. Peters (1984), U.S. Geological Survey Water-Supply
  Paper 2228. DOI: 10.3133/wsp2228
