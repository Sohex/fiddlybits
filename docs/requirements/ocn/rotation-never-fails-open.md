+++
id = "REQ-OCN-002"
title = "Rotation never fails open: no branch, floor or fallback may substitute a planetary constant"
old_path = ["/home/cfutro/docs/world/notes/audits/ocean-tier-implicit-earth.md"]
old_commit = "6aa93489d233d4e9d531d6479d338c643e34bc5e"
status = "carried"
+++

## What is true

In the candidate ocean host, `initialise_goldstein.F:380-386` computes the
Coriolis scale from the sidereal day only when the solar and sidereal day
lengths differ by more than one millisecond; if an author who has not met the
distinction sets them equal, the code silently reverts to Earth's
`2*7.2921e-5` s-1. Measured on the predecessor's configured planet (a 30-hour
day, the two day lengths differing by 733.5 s) the correct branch gives
1.17151e-4 s-1 and the fallback 1.45842e-4, 1.245 times too strong, and the
error does not scale with how wrong the input is. The value is printed only
under a debug flag. The drag timescale beside it used the sidereal day
correctly, so the fail-open sat in the one planetary constant the source had
parameterised.

The survey found the same class elsewhere (`notes/external-model-survey.md`
section 43c, 43d): three different Coriolis floors in three components of one
model (5e-5, 1e-5, 5e-6 s-1), the largest of which binds equatorward of about
20 degrees at Earth rotation and so replaces the Coriolis parameter over a
fifth of the globe; a statistical-dynamical atmosphere with a hard-wired
three-cell-per-hemisphere circulation whose cell count can never change; and
a synoptic eddy production scaled by `2*omega*|sin(lat)|` through an
Earth-tuned coefficient, so changing rotation alone rescales the whole eddy
transport with nothing compensating.

## Why it carries

Rotation state is a foundational free parameter (A0). A planet may have a day
length, a solar-sidereal difference, a rotation sense, a synchronous state or a
Coriolis magnitude that Earth-shaped code treats as degenerate, and a fallback
branch is a second statement of a constant that activates exactly on the
configuration its author did not expect. A Coriolis floor is the same class in
regularisation form: a literal that binds on a slow rotator or near the equator
and replaces physics with a number. A structural assumption about circulation
cells is the same class in topology form.

## What this system must do

- The Coriolis parameter and every rotation-derived quantity (sidereal day,
  solar day, f, beta, inertial period, Rossby radius, Ekman depth) are pure
  functions of `System` (A4). There is no fallback value and no equality test
  that selects a constant.
- A configuration for which a derived quantity is undefined (zero rotation,
  synchronous rotation, a retrograde spin) is handled by the physics of that
  limit, refused with a named reason, or reported `NotEvaluable`; it is never
  substituted.
- No Coriolis floor. Where a scheme is singular as f tends to zero, the
  regularisation is derived from resolved physics (friction, the mixed-layer
  depth, the boundary-layer depth) with a disposition, and the set of cells
  where it binds is a reported diagnostic field.
- No structural assumption about the number or width of circulation cells,
  the location of jets, the sign or direction of any transport, or the
  latitude of any regime. These are outcomes of the declared system.

## Enforced by

- A4 decision record: one clock in SI seconds; day, solar day, year and
  rotation-derived quantities are pure functions of `System`; `Dates` is
  lint-banned from physics modules.
- Refusal table (A2, A5): rotation-derived quantities undefined for a
  configuration return `NotEvaluable` rather than a value.
- Lint: no numeric literal in an expression that computes or bounds the
  Coriolis parameter.
- C1 tier 3 and M4b: rotation sweeps including slow and synchronous rotators;
  the second oracle's spread is the bar.
- C4 mutation run: a planted fallback constant and a planted Coriolis floor
  are named breaks the sweep must catch.
- C2: physics is not a knob; a moved metric requires an `answers:` mechanism.

## References

- Vallis, G. K. (2017). "Atmospheric and Oceanic Fluid Dynamics: Fundamentals
  and Large-Scale Circulation", 2nd edition. Cambridge University Press.
  DOI: 10.1017/9781107588417. (Rotating-frame dynamics; the f-plane, beta-plane
  and equatorial limits.)
- Held, I. M. and Hou, A. Y. (1980). "Nonlinear Axially Symmetric Circulations
  in a Nearly Inviscid Atmosphere". Journal of the Atmospheric Sciences 37,
  515-533. DOI: to confirm. (Hadley cell width as a function of rotation rate;
  the reason cell count is an outcome.)
