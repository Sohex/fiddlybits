+++
id = "REQ-ATM-017"
title = "The declared gas mixture has one Derived property group owned by the atmosphere, read by every kernel that needs air; the condensable is a declared species with Sourced property functions; no composition ratio is a literal"
old_path = []
old_commit = ""
status = "carried"
+++

## What is true

Measured on this project's own founding records at the implicit-Earth audit, and
on the predecessor's compiled model behind them.

- Every atmosphere record named its laws in the standard form, and the standard
  form of every moist-thermodynamic quantity carries one atmosphere's composition
  as a number rather than as a variable: the ratio of the water molar mass to the
  molar mass of a nitrogen-oxygen mixture inside the saturation mixing ratio and
  the virtual temperature, the ratio of gas constant to heat capacity of a
  diatomic gas inside the potential temperature, the reference pressure of the
  Exner function, the dry-air gas constant and heat capacity themselves. The
  dynamical-core decision named its prognostic variables without their
  definitions, the physics decision wrote the convective buoyancy in a virtual
  potential temperature it never defined, and no record anywhere said what the
  mixture's molar mass was a function of.
- The same audit found the gas's transport properties in five places and
  sourced in none: the viscosity and mean free path in the sedimentation and slip
  correction of the aerosol record, the vapour diffusivity and thermal
  conductivity in the activation record's growth coefficient, the viscosity and
  Schmidt number in the surface layer's scalar roughness, the vapour diffusivity
  in snow metamorphism. Each record reached for "air density" and stopped, and
  "air" meant one planet's mixture at one pressure.
- The one existing fence, the rule that no literal with a physical dimension
  appears in physics code (REQ-SYS-101), cannot see this class: every one of the
  composition ratios above is dimensionless, and the reference pressure is a
  convention rather than a measurement. A lint built for kilometres and kelvin
  passes a diatomic exponent without comment.
- The condensable species was water everywhere by silence: the optics, the
  Koehler theory, the Stefan problem and the equation of state all read water's
  properties, and no record declared that they did, so a configuration whose
  inventory made another species the condensable would have run water's
  relations with no refusal.
- On the predecessor, the same shape had already cost a run: the diagnostic cloud
  profile carried one planet's scale height as a length in metres, and deriving
  the length from the gas constant, temperature and gravity moved column liquid
  water by a third (REQ-ATM-004). A scale height is the first quantity this group
  produces.

## Why it carries

Decision 0004 makes the atmosphere's composition a declared inventory or a state
of the run, and decision 0016 says every scheme depends on that composition
through its own physics. That can only hold if the composition's consequences
are computed once and read everywhere: a gas constant, a heat capacity, a
viscosity or a diffusivity that each scheme carried for itself would be the
predecessor's four copies of one lapse rate (decision 0007) rebuilt for a dozen
quantities. One owner, one derivation rule per property, per-gas values
`Sourced` from laboratory standards, and a mixing rule `Sourced` from kinetic
theory, is the form in which a laboratory relation transfers to any star and any
gravity (REQ-ATM-010). The class is dimensional analysis, not any planet's
value: a quantity that is a function of the declared composition is `Derived`
(REQ-SYS-101 item 2), and this record is the atmosphere's instance of that rule.

## What this system must do

1. The atmosphere owns one `Derived` property group of the declared gas mixture,
   evaluated from the declared composition (mole fractions) and the local
   temperature and pressure, and every kernel that needs a property of the air
   reads it there: the dynamical core's thermodynamic variables (decision 0013),
   sedimentation and slip correction (REQ-ATM-006), the activation growth
   coefficient (REQ-ATM-005), scalar roughness and bulk fluxes (decision 0016),
   snow metamorphism (REQ-ATM-011), soil aeration and the stomatal diffusivity
   ratio (decisions 0018, 0021, 0022), the stability ceiling's wave speeds
   (REQ-NUM-005), and the scale height that places the vertical ladder
   (decision 0005). No scheme carries its own value of any member.
2. The group's members and their rules: the mixture's molar mass
   (mole-fraction weighted); the specific gas constant (the universal constant
   over that molar mass); the isobaric and isochoric heat capacities (per gas
   `Sourced` with temperature dependence from the standard thermochemical tables,
   mole-fraction mixed); `kappa` and `gamma` from those; `epsilon`, the ratio of
   the condensable's molar mass to the mixture's; the dynamic viscosity and
   thermal conductivity (per gas `Sourced` with temperature dependence, mixed by
   the Wilke rule); the binary diffusivities of the condensable, of molecular
   oxygen and of carbon dioxide in the mixture (Chapman-Enskog with the
   Fuller-Schettler-Giddings volumes, `Sourced` per pair, Blanc's law for the
   mixture); and the mean free path from the viscosity, pressure, temperature and
   molar mass. Each per-gas relation carries its validity range and the margin
   test of REQ-NUM-003 item 4 evaluates it over the profile's brackets.
3. The condensable species is a declared field of the system struct, water by
   declaration. Its latent heats of vaporisation and sublimation, saturation
   vapour pressure over liquid and over ice, and surface tension are `Sourced`
   functions of temperature from the IAPWS formulations, declared once here and
   read by every phase-change, cloud, activation, lake, snow and soil relation.
   A configuration declaring another condensable is a priced declared absence
   with its interface complete (REQ-ATM-013) until that species' functions are
   `Sourced`.
4. The dimensionless members (`kappa`, `gamma`, `epsilon` and any ratio derived
   from them) are lint-banned as literals in physics modules, alongside the
   dimensional literals REQ-SYS-101 bans, because a lint on dimensions cannot see
   them; the Exner reference pressure is a declared field of the system struct,
   never a literal (decision 0013).
5. The group is evaluated per column at call time from the local state where a
   member depends on temperature or pressure, and at construction where it does
   not; a member evaluated outside a per-gas relation's range is a refusal naming
   the gas and the relation, not an extrapolation.
6. Oracles (tier 1, identity): the group evaluated on the `Earth()` test instance
   reproduces the known dry-air values of every member within the source
   relations' stated uncertainty; evaluated on a synthetic instance whose bulk is
   carbon dioxide and on one whose bulk is a hydrogen-helium mixture, it
   reproduces the tabulated pure-gas and binary values of the same standards; the
   Wilke and Blanc mixing rules reproduce the pure-gas limit at unit mole
   fraction to roundoff; the condensable's saturation vapour pressure integrates
   the Clausius-Clapeyron relation with the same latent heat to the source's
   stated residual. A mutation that replaces any member by an air value must be
   caught by the carbon-dioxide instance (decision 0027).

## Enforced by

- Decision 0007 (`Derived` refuses a caller-supplied disagreeing value;
  `Sourced` requires the equation and its range); decision 0009 (one owner);
  REQ-SYS-101 (a group that follows from the declared system is `Derived`);
  REQ-SYS-103 (one declaration per quantity).
- The dimensionless-literal lint of item 4 over atmosphere, land, ocean and
  cryosphere physics modules.
- The registry rows of item 6 and the margin test of REQ-NUM-003 item 4; the
  mutation run (decision 0027).

## References

- Wagner, W., Pruss, A. (2002). *The IAPWS Formulation 1995 for the Thermodynamic
  Properties of Ordinary Water Substance for General and Scientific Use.* J. Phys.
  Chem. Ref. Data 31(2), 387-535. DOI: 10.1063/1.1461829. Latent heat of
  vaporisation and saturation vapour pressure over liquid water.
- IAPWS R10-06(2009). *Revised Release on the Equation of State 2006 for H2O Ice
  Ih.* No DOI. Sublimation enthalpy and vapour pressure over ice, shared with
  REQ-ATM-010.
- IAPWS R1-76(2014). *Revised Release on Surface Tension of Ordinary Water
  Substance.* No DOI. The condensable's surface tension as a function of
  temperature.
- Chase, M. W. (1998). *NIST-JANAF Thermochemical Tables, Fourth Edition.* J. Phys.
  Chem. Ref. Data Monograph 9. DOI: to confirm. Per-gas heat capacities with
  temperature dependence.
- Lemmon, E. W., Jacobsen, R. T. (2004). *Viscosity and Thermal Conductivity
  Equations for Nitrogen, Oxygen, Argon, and Air.* Int. J. Thermophys. 25(1),
  21-69. DOI: 10.1023/B:IJOT.0000022327.04529.f3. Per-gas viscosity and
  conductivity for the diatomic and noble gases, and the air values the Earth
  instance must reproduce.
- Wilke, C. R. (1950). *A Viscosity Equation for Gas Mixtures.* J. Chem. Phys.
  18(4), 517-519. DOI: 10.1063/1.1747673. The mixing rule for viscosity and
  conductivity.
- Chapman, S., Cowling, T. G. (1970). *The Mathematical Theory of Non-Uniform
  Gases.* 3rd ed., Cambridge University Press. ISBN 978-0-521-40844-8. The
  kinetic-theory forms of viscosity, conductivity, diffusivity and mean free path.
- Fuller, E. N., Schettler, P. D., Giddings, J. C. (1966). *A New Method for
  Prediction of Binary Gas-Phase Diffusion Coefficients.* Ind. Eng. Chem. 58(5),
  18-27. DOI: 10.1021/ie50677a007. The binary diffusivity correlation and its
  diffusion volumes per gas.
- Poling, B. E., Prausnitz, J. M., O'Connell, J. P. (2001). *The Properties of
  Gases and Liquids.* 5th ed., McGraw-Hill. ISBN 978-0-07-011682-5. The tabulated
  pure-gas and binary values the carbon-dioxide and hydrogen-helium oracle
  instances are checked against; a compilation, cited for its tables and not as
  a primary source of any relation.

## Amendments

- 2026-09-08: record created to close the gas-mixture and condensable findings of the implicit-Earth audit (rows 1, 8, 9), from notes/findings/2026-09-08-implicit-earth-audit.md
