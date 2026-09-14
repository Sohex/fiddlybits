+++
id = "REQ-SYS-103"
title = "One declaration per quantity; a value's derivation is reachable from the value; nothing is retyped from an artifact; a gate's bound is derived"
old_path = ["/home/cfutro/git/vesper/notes/audits/opaque-constants.md"]
old_commit = "6aa93489d233d4e9d531d6479d338c643e34bc5e"
status = "carried"
+++

## What is true

Measured on the predecessor's vendored GCM fork (46 changed files), its driver
component and its instruments, asking where a number reached the model without the
code or any document being able to say why it was that number.

- Two declarations of one quantity diverged silently. The aerosol particle radius
  was declared in the transport module and again in the radiation module, only
  the first in a namelist, so the number density was right for the particle asked
  for and the cross-section used the compiled default: optical depth off by
  `(r_radmod / r_true)^2`, about 1 per cent of intent for a 500 nm haze
  (`aerosol-particle-radius.md`). Sea-water density, specific heat and fusion
  enthalpy were compiled in two modules; the specific heat was fresh water's
  (`model-earth-centrism.md` finding 10). Runoff velocity constants lived in two
  modules and the later assignment won (finding 27). The snow conductivity on sea
  ice and on soil were two statements of one material property, and the climate
  column and the vegetation column computed it from two different published
  relations, one of which insulates twice as well
  (`cryosphere-material-properties.md`). A CO2 shortwave fit existed in three
  places with two values, and the generator reasserted the superseded one on every
  run (finding 5). Earth's lapse rate was in four places (finding 11). The
  flux-to-kelvin slope existed twice, 11 per cent apart, and the copy outside the
  canonical module fed a pass/fail verdict (finding 19).
- A derivation existed somewhere the reader of the value could not reach.
  `t0 = 250 K` on every level was cited a dozen times as a given and turned out to
  be the mass-weighted mean of Earth's initial profile (finding 3). Three
  sixteen-digit literals had no comment and no source (smaller findings).
- Hand transcription drifted. Configuration values retyped from generator
  artifacts had drifted twice, and dust notes and a JSON artifact carried albedos
  the code no longer used, so a forcing quoted at +4.3 W/m2 was +0.8 by the
  current numbers (finding 20a).
- A scalar assigned to a per-level array set element 1 only: the derived
  hyperdiffusion reached one level of ten, and at T42 level 1 was in days and
  levels 2 to 10 in seconds, so the top level was damped about 23,000 times more
  than the rest (finding 1).
- Gates carried bounds decades from anything observed (1e-11 and 1e4 against an
  observed 5.4; 1e-10 against a double-precision roundoff of 1e-14), so they could
  not fail; one check had no comparison in it at all (finding 20b).

## Why it carries

"One definition, N doors, never N definitions" is design idea 4 of the plan, and
this audit is its evidence: every one of the divergences above was a second
declaration of a quantity that already had one, and the cost ranged from a
mislabelled bracket to a factor of 23,000 in a damping. The class is independent
of language; a multi-component builder with per-component parameter structs
reproduces it unless the type system forbids the second declaration and the
artifact store forbids the retyped copy. The derivation-reachability half is the
`Sourced` and `Derived` dispositions of decision 0007 read as a documentation
requirement.

## What this system must do

1. Every physical quantity has exactly one declaration site. A constant needed by
   two components is declared in one place and read through a door; a relation
   needed by two components (a snow conductivity, a saturation vapour pressure)
   is one function.
2. A constant restated in another language or artifact (a generated table, an
   exported header, a test fixture) is held to its declaration by a check that
   runs in CI and refuses on divergence.
3. A `Sourced` value carries its source and the table or equation it came from; a
   `Derived` value carries its rule as executable code; a `Bracketed` value
   carries the observable its bracket was taken from. A reader of the value can
   reach the reason from the value (decisions 0007, 0030).
4. No configuration value is retyped from an artifact: a derived value is written
   by the deriving step into the content-addressed store and read by hash
   (decision 0010). A document quoting a derived number cites the artifact.
5. A scalar assigned to a per-level or per-cell parameter is a type error; a
   per-level parameter is a vector of the ladder's length (decision 0006).
6. Every threshold in a gate or oracle is derived from a measured quantity
   (floating-point precision, a measured A/A scatter, a published residual) and
   carries the derivation; a bound that no plausible defect can reach is refused
   at registration (decisions 0025, 0026).
7. A conversion used in any verdict (flux to kelvin, forcing to temperature) is
   imported from its one declaration.

## Enforced by

- Decision 0006 (typed fields with dimension and level) and decision 0009 (one
  declared writer per quantity, checked at `assemble`).
- A lint that fails on two declarations of one parameter name across modules,
  and on a dimensioned literal in physics code (shared with REQ-SYS-101).
- Decision 0010: artifact keys include the parameter subset; a config value that
  should come from an artifact is a hash reference, and the doc lint flags a
  number quoted without an artifact.
- Decision 0026: tolerances derived from floating point; the registry refuses a
  threshold without a derivation and an oracle without a positive control.
- The mutation run (decision 0027): a mutation that introduces a second copy of a
  constant must be caught.

## References

- Fukusako, S. (1990). *Thermophysical Properties of Ice, Snow, and Sea Ice.*
  International Journal of Thermophysics 11(2), 353-372. DOI: 10.1007/BF01133567.
  The specific-heat correlation whose value at 276.49 K, above its own stated
  range, was the second of two specific heats of one ice.
- IAPWS R10-06(2009). *Revised Release on the Equation of State 2006 for H2O Ice
  Ih.* International Association for the Properties of Water and Steam; locator:
  IAPWS release R10-06(2009), no DOI. The one declaration both restatements are
  now held to.
- Sturm, M., Holmgren, J., Konig, M., Morris, K. (1997). *The thermal conductivity
  of seasonal snow.* J. Glaciol. 43(143), 26-41. DOI: 10.3189/S0022143000002781.
- Fourteau, K., Domine, F., Hagenmuller, P. (2021). *Impact of water vapor
  diffusion and latent heat on the effective thermal conductivity of snow.* The
  Cryosphere 15, 2739-2755. DOI: 10.5194/tc-15-2739-2021. The two relations one
  snowfall was computed with in two components.
