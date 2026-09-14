+++
id = "REQ-OCN-001"
title = "Every physical scale an ocean solver uses is a named field of the system struct, stated once"
old_path = ["/home/cfutro/git/vesper/notes/audits/ocean-tier-implicit-earth.md"]
old_commit = "6aa93489d233d4e9d531d6479d338c643e34bc5e"
status = "carried"
+++

## What is true

The predecessor audited a frictional-geostrophic ocean (GOLDSTEIN inside
cGENIE.muffin v0.9.50) as a candidate circulation host. The solver is entirely
non-dimensional: `initialise_goldstein.F` sets a planetary radius of 6.37e6 m
and a gravity of 9.81 m s-2 as compile-time literals and derives every other
scale from them (a density scale, a time scale `rsc/usc`, an overturning scale,
a heat-flux scale, a freshwater-to-salinity scale). Measured on the
predecessor's configured planet (radius 1.20 Earth, gravity 12.81 m s-2) the
derived scales were wrong by 1.20 (time, overturning, heat flux, freshwater)
and 0.92 (density): a reported overturning about 20 per cent low and the
buoyancy-to-Coriolis ratio 8 per cent off, with every output a plausible
number. The audit's own phrase: "a wrong scale does not produce a wrong-looking
number; it produces a plausible one." The source carried its own record of a
scale having been wrong before and corrected offline.

The same radius was stated a second time as an independent `PARAMETER` in the
geochemistry (`gem_cmn.f90:802`), from which four other modules compute their
own cell areas; correcting one leaves the other, and nothing compared them.
Cell area scales as radius squared, so every tracer inventory was 30.6 per
cent low. Namelist-reachable diffusivities were non-dimensionalised by the
unreachable scales, so a reachable parameter carried an unreachable error. In
the tier that actually ran, the melting point was stated as a namelist key and
as a compile-time parameter on the same ice, and the sea-ice density was
declared twice in two modules; a run that moved the key would have left no
line carrying the melting point at all.

## Why it carries

A generic builder takes radius, gravity and rotation from the declared system
(A0). Any solver that carries a reference scale of its own reintroduces a
second, silent statement of a planetary constant, and non-dimensionalisation is
the sharpest form because it converts a wrong scale into ordinary-looking
output rather than into a wrong magnitude. Two statements of one quantity is
the general class; whether they agree today is not a defence, because the
first configuration change splits them.

## What this system must do

- Every scale used by an ocean or sea-ice kernel (radius, gravity, rotation
  rate, reference density, depth scale, velocity scale, time scale, salinity
  reference) is either a field of `System` or `Derived` from those fields at
  call time with its dependency declared. No kernel, module or configuration
  file states a planetary constant of its own. The Boussinesq reference
  density in particular is `Derived` from the equation of state as B3 states,
  never a literal for one ocean.
- If a solver is non-dimensionalised internally, its scales are `Derived`
  values computed from `System`; the state store holds dimensional fields and
  diagnostics report dimensional values; non-dimensional numbers never leave
  the kernel.
- Each quantity is stated once. Two declarations of the same physical constant
  in the tree is a build failure. Where two components consume one constant,
  both read it through the one door (idea 4: one definition, N doors).
- A reachable parameter is never scaled by an unreachable one: every factor on
  a parameter's path into a kernel is itself a declared, dispositioned value.
- The ocean's cell areas and volumes come from the mesh module for the
  declared radius (A1); the ocean component computes no geometry of its own.

## Enforced by

- A3 decision record: keyword-only `System{FT}` with no defaults; `Derived`
  refuses a disagreeing caller value; `strip(system)` is the only source of
  constants a kernel sees; Earth values exist only in `EarthRatios` and the
  Earth test instance.
- Lint: a numeric literal matching a planetary constant (radius, gravity,
  rotation rate, day, year) in a physics module fails the build.
- M0 gate: mesh area sum equals 4 pi R^2 for the declared R at every level;
  the ocean volume ledger reproduces the terrain-level bathymetry volume.
- Dispositions test: every constant in the ocean and sea-ice components
  carries exactly one of `Sourced`, `Derived`, `Bracketed`, `Irreducible`,
  `Closure`.
- The dependency-tracking wrapper's test that the recorded parameter set is a
  subset of the declared set (A3).

## References

- Edwards, N. R. and Marsh, R. (2005). "Uncertainties due to
  transport-parameter sensitivity in an efficient 3-D ocean-climate model".
  Climate Dynamics 24, 415-433. DOI: 10.1007/s00382-004-0508-8. (The source of
  the non-dimensional formulation the finding was measured on.)
- Vallis, G. K. (2017). "Atmospheric and Oceanic Fluid Dynamics: Fundamentals
  and Large-Scale Circulation", 2nd edition. Cambridge University Press.
  DOI: 10.1017/9781107588417. (Scaling and non-dimensionalisation of the
  primitive equations.)

## Amendments

- 2026-09-08: reference density named as `Derived` from the equation of state (row 19), from notes/findings/2026-09-08-implicit-earth-audit.md
