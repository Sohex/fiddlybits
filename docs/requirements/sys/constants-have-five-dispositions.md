+++
id = "REQ-SYS-001"
title = "Every constant carries exactly one of five dispositions, and \"tuned\" is not one of them"
old_path = ["/home/cfutro/git/vesper/notes/audits/tuned-values.md"]
old_commit = "6aa93489d233d4e9d531d6479d338c643e34bc5e"
status = "carried"
+++

## What is true

The predecessor defined a tuned value as a constant whose only justification is that
it was fitted, calibrated or adjusted until a comparison came out, and separated it
from two neighbours that look similar and need different repairs: an opaque constant
(a derivation exists somewhere a reader cannot reach; repair by walking the chain) and
an implicit-Earth constant (the derivation is sound and is for the wrong planet; a
diagnosis, never an endorsement). Its disposition space for a tuned value was exactly
four: source it, derive it, declare it with a bracket that gets swept, or record it as
irreducible with the argument for why no sourced form exists. "Leave it as it is" was
not in the space, and the cost of removing one was never counted against the output it
invalidated, because that counts a sunk cost and biases every decision toward keeping
the tuning.

The audit of 2026-08-25 (`tuned-values.md`) enumerated nineteen rows on the
predecessor's tree and dispositioned each. What it measured, on that configuration:

- The design stellar flux had been solved backwards: a free cap was fitted so that a
  comfort criterion reproduced a flux already in the file. At the flux-to-kelvin slope
  then in use the difference between the chosen and the unconstrained value was 14.6 K
  of global-mean surface temperature, an order of magnitude above the largest entry in
  the whole error budget (about 1.2 W/m2). Measured on `config/planet.yaml` and
  `scripts/error_budget.py`, 2026-08-25.
- A canopy absorption scalar chosen "to give pools and flux values that agree with
  published estimates" of Earth's carbon budget was irreducible: no observation of the
  modelled world could replace it, so its influence was bounded rather than fixed.
- An incision coefficient absorbing a relaxation window the terrain generator could not
  define was irreducible, and the undeclared lever was the size floor on the Earth
  sample it was calibrated against: across the derived span the solved coefficient
  moved by a factor of 8.2 and the marginal class by 9.2, against 1.8 for the Poisson
  error on the Earth count. Measured on build `precarve-craton-10m`.
- A hyperdiffusion eddy wind declared at 5.94 m/s was a reduction of the time-mean
  output stream; the instantaneous stream gives 10.05 to 10.18 m/s over five runs, and
  nothing is advected by a time average. Every damping timescale shortened by 1.699x.
- A longwave cloud absorption coefficient shipped at 0.100 sat above the ceiling its
  own source's liquid-only limit sets (0.090361 m2/g), which is the check that could
  have failed and did not.
- The land roughness field's orographic term was bisected until the land mean landed
  on Earth's namelist fallback; the relation it sat in took an amplitude where the drag
  law takes a slope, which is why the coefficient could not be sourced and drifted with
  the support. Derived from the mesh's own slope through Wood and Mason (1993),
  Beljaars, Brown and Wood (2004) and Mason (1988), nothing was left to solve; the
  derived land mean moved by 0.9 per cent across four rungs where the solved
  coefficient had moved by 1.98x.
- A precipitation re-evaporation fraction of 0.01 with "no derivation on either side"
  derived, from Kessler (1969), into a form proportional to the timestep and to
  precipitation to the 0.578 power and carrying gravity to the -0.289 power; the
  constant sat below the whole span the form reaches.
- The stratiform cloud onset threshold encodes the width of a sub-grid humidity
  distribution: `(1 - rcrit)` scales as the grid spacing to the one third by the
  Kolmogorov-Obukhov-Corrsin argument, and the convective cloud fraction pair could not
  be given an exponent because the model carried no convective area fraction, so a
  written exponent would have been "a fit wearing a derivation's clothes".
- A tuning that names itself is still a tuning: the model manual recommended arming a
  "tuning opportunity" factor at 0.15 where the compiled source shipped it at 1.00.
- Fitting is not the offence; opacity is. A solstice-offset fit by grid search against
  the climatology's own declination, reporting rms and maximum residuals into its
  artifact and re-deriving per planet, is not a tuned value.
- Four of five expectations written against unread papers were wrong; the papers
  supplied forms and brackets where constants had been expected.

## Why it carries

A generic exoplanet builder has no observation of its world to tune against, so a
tuned number is not merely undesirable, it is undefined: there is nothing for the fit
to land on. Every other unsatisfying number has a route back to something that can be
checked and carried to another star. The predecessor's evidence is that the largest
single distortion in its whole budget was the one number that could not be inspected,
and that the sub-grid closures anchored to one mesh rung were the class its four
dispositions could not hold honestly across a resolution ladder. The plan's fifth
disposition, `Closure`, exists for exactly that class: a coefficient representing
truncated sub-grid variance is declared as a sourced scaling law in grid spacing and
resolved state, with a bracketed dimensionless coefficient swept across at least two
mesh levels against a convergence-with-level oracle.

## What this system must do

- Every constant in `System` and in every component carries exactly one of `Sourced`,
  `Derived`, `Bracketed`, `Irreducible`, `Closure`. There is no sixth and no default.
- `Sourced` requires a DOI or stable locator, the table or equation the value is taken
  from, and a reference row in the index marked `read`; a value quoted from a
  secondhand citation is not `Sourced`.
- `Derived` values are computed from their inputs at construction and refuse a caller
  who supplies a disagreeing value.
- `Bracketed` values name both ends, the argument for each end, and the sweep artifact
  that reports the system's response across the bracket; a bracket's direction is a
  claim with its own argument.
- `Irreducible` values carry the argument for why no sourced form exists and a bounded
  sensitivity; growth in their count is reviewed at every milestone.
- `Closure` values are a scaling law in mesh spacing and resolved state with a
  bracketed coefficient, swept across at least two levels with a convergence-with-level
  oracle; a closure that changes its answer with level beyond its bracket fails.
- A fit is admissible only when what was fitted, to what, and how well are reported in
  the artifact, and the fit re-derives per system; a value whose only justification is
  agreement with a comparison is refused at declaration, and the cost of replacing it
  never counts invalidated output.
- At the point a scheme is chosen, the form with fewer unconstrained coefficients is
  preferred, and the choice records why.
- Two coefficients that enter only through their ratio are declared as one; a joint
  constraint between keys is declared as a relation and checked as one.

## Enforced by

The `System{FT}` disposition type (decision A3); a lint that refuses any numeric
literal in a physics module without a disposition; the reference index rule that a
`Sourced` value whose row is not `read` is refused; the sweep artifacts required for
every `Bracketed` value at the M8 gate; the convergence-with-level oracle for every
`Closure`; the `answers: <mechanism>` commit discipline of C2.

## References

- /home/cfutro/git/vesper/notes/audits/tuned-values.md (the enumeration and its dispositions)
- /home/cfutro/git/vesper/docs/src/practice/conventions.md, section "No tuned values"
- /home/cfutro/git/vesper/docs/src/reference/vocabulary.md (tuned, opaque, implicit-Earth)
- Kok et al. (2014). *An improved dust emission model - Part 1: Model description and comparison against measurements.* DOI 10.5194/acp-14-13023-2014 (a scheme chosen for one fewer unconstrained coefficient)
- Kok (2011). *A scaling theory for the size distribution of emitted dust aerosols suggests climate models underestimate the size of the global dust cycle.* DOI 10.1073/pnas.1014798108, eq. 6 (the emitted size distribution from brittle fragmentation that the scheme above takes, Kok et al. 2014 p. 13031)
- Kessler (1969). *On the Distribution and Continuity of Water Substance in Atmospheric Circulations.* DOI 10.1007/978-1-935704-36-2 (a constant that derived into a form)
- Louis (1979). *A parametric model of vertical eddy fluxes in the atmosphere.* DOI 10.1007/BF00117978 (a fitted set that does not transfer on its authority)
- Blackadar (1962). *The vertical distribution of wind and turbulent exchange in a neutral atmosphere.* DOI 10.1029/JZ067i008p03095 (a scaling that transfers where the value does not)
- Wood and Mason (1993). *The pressure force induced by neutral, turbulent flow over hills.* DOI 10.1002/qj.49711951402
- Beljaars, Brown and Wood (2004). *A new parametrization of turbulent orographic form drag.* DOI 10.1256/qj.03.73
- Plan decisions A3, C2.
- Related: REQ-SYS-104 (the `Closure` scaling law in grid spacing), REQ-SYS-103 (one declaration per quantity).
