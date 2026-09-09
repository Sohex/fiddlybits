+++
id = "REQ-OCN-003"
title = "Depth becomes pressure through the declared gravity and the modelled density, never through a literal"
old_path = ["/home/cfutro/docs/world/notes/audits/ocean-tier-implicit-earth.md"]
old_commit = "6aa93489d233d4e9d531d6479d338c643e34bc5e"
status = "carried"
+++

## What is true

In the candidate ocean host's carbonate chemistry, `gem_carbchem.f90:99`
converts depth to pressure as `loc_P = dum_D/10.0` under the comment "1 m
depth approx = 1 dbar". That is seawater density times Earth gravity with
neither on the line, and it reaches every pressure-corrected equilibrium
constant: K1, K2, KB, KW, KSi, KHF, KHSO4, KP1-3, calcite and aragonite
solubility, KHS, KNH4. Measured on the predecessor's configured planet (gravity
12.81 m s-2) the conversion is 0.13156 bar per metre against the model's 0.1,
and through the model's own pressure correction at 2 C the calcite solubility
is 1.066 times the model's at 1000 m, 1.200 at 3000 m, 1.266 at 4000 m and
1.331 at 5000 m (lower bounds, ignoring compressibility), so the lysocline and
carbonate compensation depth sit substantially shallower than the model would
place them, with saturation states that look ordinary.

The survey found the same form in a second model's equation of state,
`p = 0.1*(-z)` in all three branches (`notes/external-model-survey.md` section
43c), and in an ice model: a Clausius-Clapeyron gradient of 8.7e-4 K per metre
of ice, which is dTm/dp times rho_i g, and a sub-shelf freezing-point gradient
of 7.64e-4 K per metre of depth, which is dT/dp times rho_w g (section 45b).
Neither line contains a gravity, a density or the letter g. A third candidate
(MARBL) took pressure as a driver-supplied forcing and hardcoded no conversion,
which is the clean form. The same audit recorded an equation of state fitted
to Earth seawater with its stated domain (-1 < T < 6 C, S = 34.9) and a
salinity clamp (26 to 43) applied in the chemistry with no warning when it
substitutes.

## Why it carries

Pressure is the variable that the equation of state, the carbonate system, the
freezing point, gas solubility, ice-shelf basal melt and the pressure-melting
point of ice all depend on, and on any planet it is the hydrostatic integral
of rho g dz with the declared g and the modelled rho. A constant stated "per
metre" that is physically "per pascal" carries an Earth gravity and an Earth
density that no search for constants finds. The class generalises to every
coefficient expressed per unit length that is physically per unit pressure or
per unit weight.

## What this system must do

- Pressure at depth is a field integrated hydrostatically from the modelled
  density and the system's gravity, and it is what every consumer reads: the
  equation of state, carbonate chemistry, the freezing point, gas solubility,
  the pressure-melting point of ice and any sub-shelf melt law. No conversion
  literal exists anywhere.
- Dimensions are carried on the type (A2): a gradient physically per pascal
  has dimension K Pa-1, not K m-1, and a coefficient's declared dimension is
  checked when it enters a kernel. A "per metre" pressure surrogate is a
  dimension error at build time.
- The equation of state is TEOS-10, or a polynomial approximation to it,
  evaluated at the local pressure; its validity domain in (S, T, p) is
  declared, a state outside the domain is refused or reported `Bracketed`,
  there is no silent clamp on salinity or temperature, and the pressure
  ceiling of the fit is the refusal boundary for a deep ocean.
- The domain has a fourth axis the fit cannot deliver. TEOS-10 carries the
  pure-water part for any composition and the saline part only for the
  Reference Composition it was fitted to (Millero et al. 2008); Absolute
  Salinity is itself defined against that composition; and the function cannot
  be re-derived for another solute. The equation of state, the freezing point,
  the vapour pressure, the viscosity and the molecular diffusivities are
  therefore `Irreducible` inside the Reference-Composition anomaly tolerance of
  the ionic composition declared in the ocean solute inventory (0004) and
  refused beyond it, by name; the general form, an ion-specific Gibbs or Pitzer
  model, is a declared absence with its interface. All of them are read through
  the one seawater-properties door of B3.
- The freezing point of seawater is computed from local salinity and pressure
  (TEOS-10) by one component that both the ocean and the sea ice read, under the
  same composition fence; the liquidus slope the sea-ice thermodynamics uses is
  the derivative of this function, not a second constant; the dissolved-air
  argument of the freezing-point function reads the declared atmosphere's
  dissolved-gas state or is declared zero, never the air of one planet.
- The carbonate equilibrium constants (gas solubility, the two carbonic-acid
  dissociations, borate, water, sulfate, fluoride, calcite and aragonite
  solubility) are `Sourced` with a declared validity domain in (S, T, p) and
  refused outside it, by the same rule as the equation of state; the total
  boron, sulfate and fluoride that set the borate share of alkalinity and the
  pH scale are `Derived` from the declared composition, never ratios to
  salinity; gas solubility and the fugacity conversion take the local surface
  pressure from the atmosphere, not a fixed reference pressure (B3).

## Enforced by

- A2: `Field` dimensions via `DynamicQuantities` `Dim`; a dimension mismatch
  is a JET failure in CI.
- Lint: any constant with dimension K m-1 or mol m-1 in a chemistry or
  cryosphere module must be declared per pascal.
- C3 oracles: the hydrostatic pressure identity (the column integral of
  rho g dz reproduces p to float tolerance), which is where g enters; TEOS-10
  check values at stated (S_A, T, p); the freezing-point check values at stated
  (S_A, p); the carbonate-system reference values of the chemistry package at
  stated (S, T, p) (registry: ocean.hydrostatic_pressure_identity,
  ocean.teos10_check_values, ocean.freezing_point_check_values,
  ocean.carbonate_check_values).
- Refusal table: a declared composition outside the Reference-Composition
  tolerance, or a state outside a declared (S, T, p) domain, refuses by name;
  the refusal has a positive control in the mutation run (a composition planted
  outside the tolerance must refuse).
- A8 import review: any equation-of-state, chemistry or gas-solubility
  library is read for a hidden depth-to-pressure conversion before adoption.

## References

- IOC, SCOR and IAPSO (2010). "The international thermodynamic equation of
  seawater - 2010: Calculation and use of thermodynamic properties".
  Intergovernmental Oceanographic Commission, Manuals and Guides No. 56,
  UNESCO (English), 196 pp. Locator: UNESCO Manuals and Guides 56; no DOI.
- Roquet, F., Madec, G., McDougall, T. J. and Barker, P. M. (2015). "Accurate
  polynomial expressions for the density and specific volume of seawater
  using the TEOS-10 standard". Ocean Modelling 90, 29-43.
  DOI: 10.1016/j.ocemod.2015.04.002.
- Zeebe, R. E. and Wolf-Gladrow, D. (2001). "CO2 in Seawater: Equilibrium,
  Kinetics, Isotopes". Elsevier Oceanography Series 65, chapter 1 (Equilibrium),
  which carries the pressure dependence of the carbonate equilibrium constants.
  DOI: 10.1016/S0422-9894(01)80002-7. Held as chapter 1 only
  (`zeebe2001-co2-in-seawater-chapter-1-equilibrium.pdf`); Millero (1995), held,
  gives the same pressure dependence directly.
- Millero, F. J. (1995). "Thermodynamics of the carbon dioxide system in the
  oceans". Geochimica et Cosmochimica Acta 59, 661-677.
  DOI: 10.1016/0016-7037(94)00354-O. (The pressure corrections the old model
  applied; to be read for the per-pascal form.)
- Millero, F. J., Feistel, R., Wright, D. G. and McDougall, T. J. (2008). "The
  composition of Standard Seawater and the definition of the
  Reference-Composition Salinity Scale". Deep-Sea Research I 55, 50-72.
  DOI: 10.1016/j.dsr.2007.10.001. (The composition TEOS-10 is fitted to and the
  anomaly tolerance the fence is stated against.)
- Lueker, T. J., Dickson, A. G. and Keeling, C. D. (2000). "Ocean pCO2
  calculated from dissolved inorganic carbon, alkalinity, and equations for K1
  and K2". Marine Chemistry 70, 105-119. DOI: 10.1016/S0304-4203(00)00022-0.
  (The dissociation constants and their stated (S, T) domain.)
- Mucci, A. (1983). "The solubility of calcite and aragonite in seawater at
  various salinities, temperatures, and one atmosphere total pressure".
  American Journal of Science 283, 780-799. DOI: 10.2475/ajs.283.7.780. (Solubility
  products and their stated domain.)
- Weiss, R. F. (1974). "Carbon dioxide in water and seawater: the solubility of
  a non-ideal gas". Marine Chemistry 2, 203-215.
  DOI: 10.1016/0304-4203(74)90015-2. (Gas solubility; its reference-pressure
  form is what the local-surface-pressure rule replaces.)

## Amendments

- 2026-09-08: equation-of-state bullet: pressure ceiling as the deep-ocean refusal boundary; new bullet stating what TEOS-10 carries and cannot, the composition axis read from the ionic composition declared in the ocean solute inventory (0004), `Irreducible` inside the Reference-Composition tolerance and refused beyond (row 1), from notes/findings/2026-09-08-implicit-earth-audit.md
- 2026-09-08: freezing-point bullet: composition fence, liquidus slope as the derivative of the one function, dissolved-air argument from the declared atmosphere (rows 7, 12), from notes/findings/2026-09-08-implicit-earth-audit.md
- 2026-09-08: new bullet: carbonate equilibria `Sourced` with declared domains, total boron, sulfate and fluoride `Derived` from composition, solubility at local surface pressure (row 2), from notes/findings/2026-09-08-implicit-earth-audit.md
- 2026-09-08: Enforced by: check values at stated (S_A, T, p) with g entering through the hydrostatic identity; registry ids named; composition refusal with a positive control (rows 31, 32), from notes/findings/2026-09-08-implicit-earth-audit.md
- 2026-09-08: References: Millero et al. 2008, Lueker et al. 2000, Mucci 1983, Weiss 1974, from notes/findings/2026-09-08-implicit-earth-audit.md
- 2026-09-08: cross-area review: Mucci 1983 identifier filled, from notes/findings/2026-09-08-implicit-earth-audit.md
