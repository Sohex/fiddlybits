+++
id = "REQ-SYS-101"
title = "A planetary constant with no declaration cannot exist; a group that follows from the declared system is Derived; an absent input is never filled from Earth"
old_path = ["/home/cfutro/git/vesper/notes/audits/model-earth-centrism.md"]
old_commit = "6aa93489d233d4e9d531d6479d338c643e34bc5e"
status = "carried"
+++

## What is true

Measured on the predecessor's vendored spectral GCM, a ~50,000-line Fortran model
whose only planet module was Earth's, configured for a planet of 1.2 Earth radii,
1.306 Earth gravities and a 30-hour rotation. A sweep of the whole fork opened 29
findings, and the individual constants mattered less than the four mechanisms that
kept producing them (`model-earth-centrism.md`, "The four mechanisms"):

- The build compiled Earth's planet module and nothing else, so the run's own
  log printed Earth's mass, radii, Bond albedo and orbit above the correct gravity
  (finding 28).
- Many constants sat in `parameter` statements or module variables in no namelist
  group, so they could not be bracketed, swept or declared without a source edit
  and a rebuild (mechanism IV). The ocean's horizontal diffusion divided by a
  compiled Earth radius squared while the planet's radius reached every other
  module, so every diffusivity arm ran 1.44 times what its label said (finding 3).
  The cloud liquid-water scale height was 700 Earth metres against layer heights
  that scaled as 1/g, putting 31 per cent more liquid water in the column and 10.9
  times more at the top level (finding 5). The ozone profile sat at a fixed
  geometric 20 km, 3.6 scale heights instead of 2.7, moving the top-layer share of
  the ozone column from 0.616 to 0.794 (finding 11). The free-convection transfer
  coefficient 0.0016 was the group (g/theta)^(1/3) evaluated at 9.81, 9.3 per cent
  low (finding 13). Runoff velocity constants took the slope in geopotential, a
  hidden g^0.18, and their pit-filling increment was 1 m2/s2 (finding 27). Snow and
  glacier densities were Earth compaction values under a gravity 1.306 times larger
  (finding 25). Earth's 6.5 K/km lapse rate appeared in three project scripts and
  the postprocessor (`inherited-earth-constants.md` finding 3, `opaque-constants.md`
  finding 11); the measured rate was 6.8 to 7.8 K/km, below the 8.5 that scaling by
  gravity predicted, so a declared corrected constant would have been wrong too.
- Deleting Earth's input files did not yield a neutral default (mechanism III).
  With no sea-surface climatology the cold start built an Earth Arctic sea-ice
  thickness field from a -999 sentinel, 18:1 north to south, with zero ice cover
  on top of it, and clipped an uninitialised ocean temperature to the freezing
  point (finding 1). The initial profile was 288 K, 6.5 K/km and a 12 km tropopause
  on a planet whose dry adiabat was 12.8 K/km (finding 17). The semi-implicit
  reference temperature was 250 K on every level, identified afterwards as the
  mass-weighted mean of Earth's initial profile (`opaque-constants.md` finding 3).
  The vertical grid and model top reached the model from a library subclass
  default that the configuration file did not name (`opaque-constants.md` finding
  12).
- A constant that had been copied into the configuration read as a decision:
  the longitude of perihelion was ExoPlaSim's Earth default inside a block every
  other key of which had a rationale (`inherited-earth-constants.md` finding 4).

What the repairs did, one by one, was turn each literal into a declared key at the
value it carried, and where the value followed from gravity, radius or composition,
into a derivation that reproduces the Earth number on an Earth configuration and
the planet's own otherwise.

## Why it carries

Any physics written or imported for this builder carries the same four mechanisms
unless the design makes them unrepresentable. A generic exoplanet builder has no
"the planet" to compile in and no Earth climatology to fall back on, so every
number a kernel reads must be reachable from the declared system, and every
absence must refuse or be declared. The lesson is the class, not the 29 fixes:
a constant without a declaration, a derived group frozen at one planet's value,
a constructed default in an absent input, and a copied default that reads as a
choice are four shapes of one defect. The old world appears here only as the
place the cost was measured.

## What this system must do

1. Every constant read by any kernel is a field of `System{FT}` or of a component
   parameter struct, carrying one of the five dispositions of decision 0007. No
   literal with a physical dimension appears in physics code other than
   mathematical constants and Sourced universal constants (Boltzmann, Stefan-
   Boltzmann, the gravitational constant, the speed of light), each declared once;
   nor does a dimensionless ratio that encodes a composition (the vapour-to-air
   molar mass ratio, kappa, gamma, the Exner reference written as a ratio, the
   ratio of two specific heats), because such a ratio is a planetary constant in
   dimensionless clothing and is `Derived` from the gas-mixture property group.
2. A quantity that follows from declared inputs is `Derived`: computed from the
   inputs at construction, and refusing a caller-supplied value that disagrees.
   The free-convection group, a condensate scale height, the pressure-placed
   ozone layer, the hypsometric reference height of the lowest level, any
   velocity that carries sqrt(g) or a geopotential slope, gravity as `g(r, phi)`
   with the centrifugal term and the figure of the planet (decision 0004), the
   solar and mean solar day (decision 0008), and the gas-mixture property group of
   REQ-ATM-017 (molar mass, specific heats, kappa, gamma, the vapour-to-air molar
   mass ratio, the Exner reference, the scale height at a stated temperature)
   are of this kind.
3. A parameterisation fitted on Earth whose value does not follow from the
   system (a mixing length in metres, a critical humidity, a lead-closing scale)
   is `Bracketed` or `Irreducible`, never silently Earth's, and its bracket is
   swept (decision 0007).
4. An absent input is never filled from an Earth climatology or from memory:
   the reader refuses, or the value is a declared initial condition of the run.
   A cold start derives its initial state from the declared system: the initial
   column from the declared surface temperature, the system's gravity and heat
   capacity and a declared or radiative-convective lapse structure; the ocean and
   ice from a declared initial condition whose default is ice-free; the semi-
   implicit reference temperature from that profile. Every such default is named
   in the run's identity.
5. Earth's values exist only in the `Earth()` test instance and in `EarthRatios`
   denominators whose names forbid physical use (decision 0007). A configuration
   value that equals an Earth value is not thereby suspect, but it carries a
   disposition and a source like any other.
6. Any diagnostic the system prints about the planet it runs is derived from the
   struct it ran with.

## Enforced by

- Decision 0007 (keyword-only `System{FT}` with no defaults; five dispositions;
  `Derived` refuses a disagreeing value) and decision 0004 (which parameters are
  free).
- A lint that fails the build on a dimensioned numeric literal inside a physics
  module, with an allowlist of the universal constants and their declaration site,
  and on a dimensionless composition ratio written as a literal (the ratios named
  in item 1), with an allowlist of exactly the `Derived` accessors of REQ-ATM-017.
- The M0 gate "every `Derived` field from its own inputs": `Earth()` built from
  mass, radius and composition reproduces its known gravity, scale height at the
  temperature the known value is quoted for, dry adiabat and moist constants inside
  stated tolerances, and a synthetic non-Earth test instance with closed-form
  derived quantities (retrograde spin, high eccentricity, two sources, zero
  obliquity, a non-Earth composition) reproduces those closed forms through the
  same code path (decision 0034; the registry's `system.*` section), so that a
  derivation right on one configuration by coincidence has a test that can fail.
- The measured-dependency test `recorded is a subset of declared` per component, so a kernel
  cannot read a constant its component did not declare (decision 0007).
- A mutation in the weekly run (decision 0027) that substitutes an Earth value
  for one `Derived` field on a non-Earth configuration and requires the affected
  oracle to fail.
- The failure-classes review (decision 0028), rows for "constant with no key",
  "constructed Earth field in an absent input", and "copied default reads as a
  decision".

## References

- Miller, M. J., Beljaars, A. C. M., Palmer, T. N. (1992). *The Sensitivity of the
  ECMWF Model to the Parameterization of Evaporation from the Tropical Oceans.*
  J. Climate 5(5), 418-434. DOI: 10.1175/1520-0442(1992)005<0418:TSOTEM>2.0.CO;2
  (to confirm). The free-convection enhancement whose coefficient folds
  (g/theta)^(1/3) at Earth's gravity.
- Kiehl, J. T., Hack, J. J., Bonan, G. B., Boville, B. A., Williamson, D. L., Rasch,
  P. J. (1998). *The National Center for Atmospheric Research Community Climate
  Model: CCM3.* J. Climate 11(6), 1131-1149.
  DOI: 10.1175/1520-0442(1998)011<1131:TNCFAR>2.0.CO;2. Eq. 4, the 700 m
  liquid-water scale height, a length in Earth metres.
- Louis, J.-F. (1979). *A parametric model of vertical eddy fluxes in the
  atmosphere.* Boundary-Layer Meteorology 17, 187-202. DOI: 10.1007/BF00117978.
  The stability functions whose coefficients were kept at ECHAM's values because
  nothing had measured a replacement.
- Charnock, H. (1955). *Wind stress on a water surface.* Q. J. R. Meteorol. Soc.
  81(350), 639-640. DOI: 10.1002/qj.49708135027 (to confirm). The one surface
  relation the old model carried with its gravity explicit, recorded as the
  positive example.

## Amendments

- 2026-09-08: the derived groups name gravity as g(r, phi), the solar day and the gas-mixture property group of REQ-ATM-017; the lint extends to dimensionless composition ratios; the M0 gate validates every Derived field on a synthetic non-Earth instance as well as Earth(), from notes/findings/2026-09-08-implicit-earth-audit.md.
- 2026-09-14: "the Exner reference" in item 2's gas-mixture group is the Exner function's dependence on the declared composition through kappa; the reference pressure of the Exner function is `Irreducible`, not `Derived` and not `Sourced` (decision 0013, amendment of 2026-09-14). User decision of 2026-09-14, raised by notes/findings/2026-09-14-an-audit-of-source-fitness.md.
