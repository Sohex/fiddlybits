+++
id = "REQ-PED-007"
title = "One derivation of the land column's hydraulic states, with gravity entering through field capacity and through the conductivity, a named retention closure, and correlated uncertainty"
old_path = ["/home/cfutro/docs/world/pedology/notes/land-column-property-contract.md"]
old_commit = "6aa93489d233d4e9d531d6479d338c643e34bc5e"
status = "carried"
+++

## What is true

One pedology artifact became two incompatible vadose-zone soils: the climate model
installed one column as a bucket depth, and the vegetation model re-derived
saturation, matric potential, wilting point and field capacity from the Cosby texture
regressions, mixed in an ideal organic soil down a fixed Earth profile, and scaled by
regolith depth; they were different numbers for the same soil, and the two column
extents disagreed by a factor of three across the map. The contract recorded
2026-08-24 became the only derivation: two geometries (a physical column where water
moves and a rootable column where uptake draws), four materials with their vertical
rules, four states whose ordering is checked (residual, wilting point, field capacity,
saturation), and one named retention closure (Clapp-Hornberger on Cosby Table 4, of
the Brooks-Corey family; van Genuchten differs in its tails, which matters where
wetting and drying through near-saturation is common).

Gravity enters the hydraulic states twice, each time with no free parameter, and the
record names both entries. The first is field capacity. Total potential per unit weight
is `H = psi / (rho_w g) + z`. Saturation is pore geometry and does not move; the
wilting point is a plant pressure and does not move; field capacity is an operational
drainage equilibrium over a stated length `L`, and its matric pressure `rho_w g L`
scales with gravity. `L = 1 m` reproduces Cosby's own field-capacity suction of 100 cm
of water under Earth gravity, which is what licenses stating it as a length, and the
check fails if it stops doing so. At higher gravity field capacity falls, the wilting
point does not, and plant-available water falls by more in relative terms; the adopted
value is an upper bound because the retention exponent is held fixed. The trap: Cosby's
parameters are recorded as heads on Earth, and air entry is a capillary pressure while
the wilting point is a plant pressure, so both are invariant and both heads scale
together; converting one and not the other moves the wilting point for a bookkeeping
reason. The script therefore works in pressure so a mixed frame cannot be written, and
checks two consistent frames agree exactly and the mixed one differs. The second entry
is hydraulic conductivity, and the published form cannot carry it: Cosby's saturated
conductivity is a velocity, `K = k rho_w g / mu(T)`, folding the gravity and the water
viscosity of the measurement into an intrinsic permeability `k` (dimension m2), so a
conductivity stored in m/s and used at another gravity or temperature is wrong by the
ratio of `g / mu`; what the regression carries is `k`, and what it cannot carry is any
`g` or `mu(T)` but the ones it was measured under. The air-entry clamp region is a line
in the texture simplex (`1.58 sand + 0.63 clay < 0.17`) and the map's margin from it is
reported, not a count. Uncertainty is correlated by declaration: low, central and high
cases applied coherently across every layer and property, never sampled per layer,
because independent draws average the spread away by the square root of the layer
count; the cases are an envelope over Cosby's own within-class spread, which is larger
than the gravity shift by more than an order of magnitude at the median cell. Aquifer
transmissivity is not owned by the vadose contract: a vadose-zone unsaturated
conductivity is not an aquifer permeability. Nine properties stayed undeclared with
owners (residual content, saturated and unsaturated conductivity, infiltration
capacity, frozen-pore impedance, thermal properties, organic profile, andic hydraulic
effect). A layer scaled to exactly zero capacity divided by zero in the vegetation
model and zeroed a cell's vegetation silently.

## Why it carries

B4's one land column (Richards soil water with a weathered-bedrock layer, soil heat
with phase change, infiltration-excess runoff) needs exactly these properties from
B8's pedology and makes two derivations unrepresentable; what remains is the
derivation rule, the gravity rule, the frame check and the correlated uncertainty. The
gravity rule is an A0 consequence with no free parameter and is expensive to retrofit
once a calibration has absorbed it. A3 dispositions map directly: Sourced (Cosby),
Derived (the states), Bracketed (the within-class spread, the drainage length).

## What this system must do

- Hydraulic states per tile layer (saturation, air entry, retention exponent,
  saturated and unsaturated conductivity, residual, field capacity, wilting point) are
  derived once from texture, organic and andic fractions and bulk density by a named
  closure with its family declared, in pressure units, at the system's gravity; every
  consumer reads the same states.
- Field capacity is a drainage equilibrium over a Bracketed length; saturation and the
  wilting point are gravity-invariant, and the wilting point the artifact carries is a
  reference pressure labelled as convention, the plant-side limit being the strategy's
  own critical potential (REQ-BIO-008); the frame check (two consistent frames agree,
  the mixed frame differs) is a test.
- Saturated conductivity is stored as intrinsic permeability `k` (dimension m2),
  `Derived` once from Cosby's conductivity by dividing out `rho_w g_Earth / mu(T_ref)`
  inside `EarthRatios`; the conductivity the Richards solver uses is
  `K = k rho_w g / mu(T)` evaluated at the system's gravity and the layer's resolved
  temperature, with `mu(T)` the liquid-water viscosity from the water-property door of 0017 (pure-water limb); the
  unsaturated relative conductivity is dimensionless and unchanged. The frame check
  covers `K`: two consistent frames agree, and a conductivity carried in m/s across a
  change of gravity or temperature differs.
- Uncertainty cases are coherent across layers and properties and form an envelope
  from the source's own within-class spread; a per-layer draw is refused.
- The weathered-bedrock layer has its own porosity and retention (B4), never a rescaled
  soil layer.
- Infiltration capacity exists so infiltration-excess runoff is representable; a layer
  with zero capacity is a refusal at assemble, not a division.
- Aquifer properties are owned by the groundwater component (REQ-HYD-003) and joined at
  the declared contact through the ledger's drainage and capillary-rise terms only.

## Enforced by

A5 ownership at assemble; the declaration check with its named mutations; the frame
check; A3 dispositions; C3 Richards oracles.

## References

- A Statistical Exploration of the Relationships of Soil Moisture Characteristics to
  the Physical Properties of Soils. Cosby, Hornberger, Clapp, Ginn (1984), Water
  Resources Research 20, 682-690. DOI: 10.1029/WR020i006p00682
- Empirical equations for some soil hydraulic properties. Clapp, Hornberger (1978),
  Water Resources Research 14, 601-604. DOI: 10.1029/WR014i004p00601
- A Closed-form Equation for Predicting the Hydraulic Conductivity of Unsaturated
  Soils. van Genuchten (1980), Soil Science Society of America Journal 44, 892-898.
  DOI: 10.2136/sssaj1980.03615995004400050002x
- Soil Water Characteristic Estimates by Texture and Organic Matter for Hydrologic
  Solutions. Saxton, Rawls (2006), Soil Science Society of America Journal 70,
  1569-1578. DOI: 10.2136/sssaj2005.0117
- Hydraulic Properties of Porous Media. Brooks, Corey (1964), Hydrology Paper 3,
  Colorado State University. Locator: CSU Hydrology Paper No. 3
- Direct observations of rock moisture, a hidden component of the hydrologic cycle.
  Rempe, Dietrich (2018), Proceedings of the National Academy of Sciences 115,
  2664-2669. DOI: 10.1073/pnas.1800141115

## Amendments

- 2026-09-08: second gravity entry named: saturated conductivity stored as intrinsic
  permeability and evaluated as k rho_w g / mu(T) at the system's gravity and layer
  temperature, added to the frame check; the title names both gravity entries
  (audit row 3), from notes/findings/2026-09-08-implicit-earth-audit.md
- 2026-09-08: wilting point labelled a reporting convention with the plant limit owned
  by REQ-BIO-008 (audit row 35), from
  notes/findings/2026-09-08-implicit-earth-audit.md
- 2026-09-08: cross-area review: `mu(T)` pointed at the water-property door of 0017 (pure-water limb), from notes/findings/2026-09-08-implicit-earth-audit.md
