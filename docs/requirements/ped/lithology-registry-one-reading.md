+++
id = "REQ-PED-004"
title = "One lithology registry with one reading per rock class for every derived property, self-checked, with unassigned classes left unassigned"
old_path = ["/home/cfutro/docs/world/pedology/README.md"]
old_commit = "6aa93489d233d4e9d531d6479d338c643e34bc5e"
status = "carried"
+++

## What is true

Three tables in the predecessor's pedology answered the same question in three
vocabularies: a pH-block supply category, a Meybeck (1987) row, and a rock-weathering
scheme's class. They disagreed about `melange` (gneiss chemistry to one, shale to the
other two: a factor of 4.29 in base-cation supply on six per cent of the land area) and
about `playa_clastic` (an evaporite to one, shale to the other two: a factor of 5.5 on
fourteen per cent), with nothing in the tree able to see either. One module now holds
the tables and checks them against each other on every build and per commit; a class
whose two readings differ must carry the argument for reading it two ways, and a
declaration for a class that has come to agree fails too. The permeability table
(Gleeson et al. 2011) keys on the Durr et al. (2005) classes through the same mapping
pedology used for Hartmann et al. (2014) phosphorus; evaporite is in Gleeson's
"not assigned" row and was carried as unassigned rather than filled from the nearest
class; carbonate's permeability increases with scale through karst and is a one-signed
underestimate. The twenty-to-ten class mapping for brine chemistry was written out in
full because a silent default would push every unmatched class to one side, and its
largest single judgment (whether shelf clastic behaves as shale or sandstone) was
tested and moved the alkaline area share by 0.6 points. Under a scheme whose runoff
exponent is per lithology, reassigning a class moves the effective exponent with no
change of scheme, so the mapping is part of the scheme bracket. `melange` is a forearc
province rather than a rock, with no serpentinite share the generator can size, so its
reading spans the composition's full range as a wide-by-construction bracket; a
carbonate endmember was excluded on the arithmetic of the row it would have used
(Ca + Mg 1740 against HCO3 1730 microequivalents per litre is a carbonate balance).

## Why it carries

Every lithology-keyed property in B8 and B5 (permeability, solute release, phosphorus
content and release, base-cation supply, erodibility, surface reflectance) reads a
mapping from the terrain's rock classes into some Earth compilation's vocabulary. A3
requires registries to be self-checking and one definition to have N doors; B1 makes
the rock class a per-cell stratigraphy state. The finding that three mappings drifted
apart unseen is general to any project that keys several properties on one categorical
field, and the cure is structural rather than careful.

## What this system must do

- One lithology registry: for each rock class the terrain seed can emit, one reading
  into each compilation vocabulary the system uses (GLiM and Durr classes, Meybeck rows,
  erodibility classes, modal mineralogy for REQ-PED-001), each reading with its
  disposition and, where a class maps to a mixture, the argument and the mixing
  Bracket.
- The registry is checked at build and per commit: a class reading differently across
  vocabularies must carry a declared argument, and an argument attached to readings
  that agree is refused as stale.
- A class a source does not assign stays unassigned, and each consumer declares its
  policy for unassigned classes (excluded from the conductive network; local seepage;
  no silicate weathering substrate) by name; nearest-class fill is refused.
- A province that is not a rock is a declared Bracketed mixture spanning its
  composition, reported as wide by construction.
- Where a scheme's constants are per lithology, the mapping is swept as part of the
  scheme's Bracket.

## Enforced by

A3 self-checking registries and dispositions on every table value; the per-commit
registry check; C4 mutation run (a silently defaulted class must be caught).

## References

- The new global lithological map database GLiM: A representation of rock properties
  at the Earth surface. Hartmann, Moosdorf (2012), Geochemistry, Geophysics,
  Geosystems 13, Q12004. DOI: 10.1029/2012GC004370
- Lithologic composition of the Earth's continental surfaces derived from a new digital
  map emphasizing riverine material transfer. Durr, Meybeck, Durr (2005), Global
  Biogeochemical Cycles 19, GB4S10. DOI: 10.1029/2005GB002515
- Mapping permeability over the surface of the Earth. Gleeson et al. (2011),
  Geophysical Research Letters 38, L02401. DOI: 10.1029/2010GL045565
- Global chemical weathering of surficial rocks estimated from river dissolved loads.
  Meybeck (1987), American Journal of Science 287, 401-428. DOI: 10.2475/ajs.287.5.401
- Global chemical weathering and associated P-release - The role of lithology,
  temperature and soil properties. Hartmann, Moosdorf, Lauerwald, Hinderer, West
  (2014), Chemical Geology 363, 145-163. DOI: 10.1016/j.chemgeo.2013.10.025
