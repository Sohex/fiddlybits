+++
id = "0032"
title = "Moons and multiple stars are in the system struct from the start; light is derived now, tides declared absences with complete interfaces"
status = "accepted"
date = 2026-09-08
+++

## Decision

The system struct admits one or more stars and zero or more moons as foundational
free parameters (decision 0003). This record decides which derived effects are
computed in the first version and which are declared absences whose interfaces are
nevertheless complete.

**Derived from the start:** everything that touches every radiation timestep.
Multi-source instellation (each star's spectrum, luminosity and geometry summed at
the top of the atmosphere per cell per interval), eclipses and transits by moons or
companion stars, reflected light from moons, and the phase geometry of all of it, are
pure functions of the system struct and the clock. They read the fields decision
0004 declares for that purpose: each star's radius, each moon's radius, reflectance
spectrum and orbit orientation (node, argument of periapsis, named reference plane),
and the orbit hierarchy; none of those carries a default. The radiation pipeline
builds its shortwave k-tables per source, against each source's spectrum (decision
0016); the band edges are the flux quantiles of the sum of the declared spectra
weighted by each source's orbit-mean flux at the planet, and a configuration whose
flux ratio between sources varies over an orbit by more than a declared bracket is
REPORT for every radiation metric until per-interval band weights exist.

**Declared absences with complete interfaces:** the slow physics. Ocean and solid-body
tides and the tidal mixing they drive, rotation-state evolution and tidal locking,
obliquity stability under the moons' torques, and moon-induced orbital perturbations
are each a named component with its reads and writes declared, its ledgers
declared, and a body that refuses with the record's identifier. A configuration with a
large moon therefore runs without tidal mixing until the component is written, and
the run's report says so by name. No later addition changes the clock, the struct or
any interface.

**The general principle** (the first founding principle): nail every interface out of
the gate so extension is painless later. A subsystem may be a declared absence; its
interface may not.

## Alternatives considered

- *Full derivation of every effect in the first version.* Rejected: tidal forcing,
  rotation evolution and obliquity dynamics belong with the ocean and the slow tier,
  and building them before the first coupled run puts more physics in front of the
  first gates without changing what the gates test.
- *Single star, no moons, in the first version.* Rejected: it contradicts the generic
  framing and would bake single-source assumptions into the clock and the radiation
  pipeline that a later retrofit would have to find one by one.
- *Moons as a perturbation applied after the fact.* Rejected: eclipses, moonlight and
  tides are not small for every configuration, and an after-the-fact term has no
  ledger.

## Consequences

- The clock module's instellation, declination and hour-angle functions take a
  source list, and a single-star configuration is the one-element case.
- The offline radiation build (decision 0016) runs per source, and the band edges
  are flux quantiles of the orbit-mean-weighted sum.
- The ocean scope (decision 0017) names tidal forcing and mixing as declared
  absences with interfaces, and the parameter for background mixing is `Bracketed`
  until tides supply it.
- A run report lists every declared absence its configuration would have exercised.

## References

- Murray, C. D., and S. F. Dermott. Solar System Dynamics. Cambridge University
  Press, 1999. DOI: 10.1017/CBO9781139174817. (tidal torques, rotation and
  obliquity evolution; the formulation the declared-absence interfaces are shaped by)
- Laskar, J., F. Joutel, and P. Robutel. "Stabilization of the Earth's obliquity by
  the Moon." Nature 361 (1993). DOI: 10.1038/361615a0.
- Egbert, G. D., and R. D. Ray. "Significant dissipation of tidal energy in the deep
  ocean inferred from satellite altimeter data." Nature 405 (2000).
  DOI: 10.1038/35015531. (the tidal-mixing coupling the ocean interface must admit)

## Amendments

- 2026-09-08: the light functions name the decision 0004 fields they read (star and moon radii, moon reflectance and orbit orientation); k-tables are per source with band edges from the orbit-mean flux-weighted sum and a REPORT when the flux ratio varies beyond a bracket; the cross-references to the radiation build (0016) and the ocean scope (0017) are corrected, from notes/findings/2026-09-08-implicit-earth-audit.md.
