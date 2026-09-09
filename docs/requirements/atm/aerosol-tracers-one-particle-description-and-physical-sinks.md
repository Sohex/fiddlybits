+++
id = "REQ-ATM-006"
title = "Aerosol tracers share one particle description between transport and radiation, remove mass by physical rates rather than per-step fractions, and carry every wind-driven species the surface can emit"
old_path = ["/home/cfutro/docs/world/notes/audits/aerosol-particle-radius.md", "/home/cfutro/docs/world/notes/audits/unpriced-terms.md"]
old_commit = "6aa93489d233d4e9d531d6479d338c643e34bc5e"
status = "carried"
+++

## What is true

Measured on the predecessor's vendored aerosol module and on its offline aerosol
components.

- The particle radius was declared twice, in transport and in radiation, and
  only the first reached the namelist, so optical depth went as
  `(r_radmod / r_true)^2`: about 1 per cent of intent for a 500 nm haze, and the
  published science using the module had used 500 nm (`aerosol-particle-radius.md`,
  "The mechanism"). Two integer divisions had deleted the viscosity's temperature
  dependence (settling 12 to 22 per cent fast) and made number density 33 per
  cent high. The grain radius and density were never written at all by the
  project's own driver, so dust would have settled about 1790 times too slowly
  (`model-earth-centrism.md`, dormant section).
- The bottom-layer sink was `mmr = 0.01 mmr` per step, an implied timescale of
  `dt / ln(100)` that scales with the timestep and nothing else physical; the
  settling flux was added at the surface where it should have been subtracted,
  so the only sink the paper named did not run and the sink that ran was not
  mentioned ("The paper's declared limitation cuts both ways"). The cheap
  diagnostic: re-run at a different timestep; if the burden moves, the sink is
  rate-limiting and timestep-dependent.
- There was no longwave aerosol term, so the model could cool with haze and
  could not warm with it.
- Mineral dust had been priced carefully at +0.34 to +0.61 W/m2 and stood second
  in the error budget; sea salt, never considered, measured -0.16 to -0.89 W/m2,
  the same size and the opposite sign, from wind over the 57 per cent of the
  planet that was ocean (`unpriced-terms.md` finding 2). Its single-scattering
  albedo was 1 to 1e-5 in both bands, so the sign could not come out positive.
  Passive volcanic sulfate was -0.02 W/m2 and bounded two sulfur sources the
  project could not compute. The Earth checks were ratios between two published
  source functions, agreeing to 3.5 per cent, and the burden sat inside the
  AeroCom spread.
- Two defects found on the way: a humidity field labelled as a fraction was a
  percentage (a factor of five on optical depth through the growth curve), and
  the offline transport was in advective rather than flux form, conserving mass
  only where the wind was non-divergent. The model carried one aerosol at a time
  by design.

## Why it carries

Decision 0016 carries dust and sea salt as in-line tracers and decision 0022
reaches their deposition into snow, soil and ocean. Every finding above is a
class a new tracer scheme reproduces unless the design forbids it: a second
declaration of a particle (REQ-SYS-103), a sink that is not a rate (a timestep
dependence any convergence oracle catches), an absent radiative term of one
sign, a units label trusted over the data, and an inventory that stops at the
first species someone thought of. The sea-salt finding is the generic one: a
seam between two correct components went unexamined because nobody asked what
else the same mechanism produced.

## What this system must do

1. Every aerosol species is an in-line tracer with one particle description
   (size distribution, density, hygroscopicity, refractive index per band)
   declared once and read by emission, transport, activation, deposition and
   radiation (REQ-SYS-103).
2. Sedimentation velocity comes from a drag law with slip correction in SI
   (decision 0016, "fall speeds from a drag law"), the viscosity and mean free
   path of the declared mixture read from REQ-ATM-017; dry deposition is a
   resistance form per surface class, with the aerodynamic resistance from the
   surface layer (decision 0016) and the surface resistance `Bracketed`
   (mechanisms: a wet vegetated surface at the low end, a dry bare surface at the
   high end) with the surface set it was fitted on (Wesely 1989); wet deposition is
   a scavenging rate tied to the precipitation the microphysics produces, its
   coefficient `Bracketed` (mechanisms: a drizzle raindrop spectrum at the low end,
   a convective raindrop spectrum at the high end) with the spectrum it was fitted
   on named (Slinn 1984). No
   sink is a per-step fraction, and a halving of the timestep moves every
   species' burden by less than the scheme's declared order.
3. Shortwave and longwave optics exist for every species; more than one species
   can act at once; the mass ledger closes per species at every exchange
   (decision 0009).
4. The inventory is derived from the declared surface: dust from bare tiles,
   sea salt from open water, sulfate from the declared outgassing, carbonaceous
   from fire (decision 0021), with any species not carried a declared absence
   with its interface and sign (REQ-ATM-013). The published sea-salt source
   functions are fits in the ten-metre wind alone and carry neither gravity nor
   the air and water densities nor surface tension, so they cannot deliver the
   dependence on the declared system by themselves. The emission is therefore
   written as the whitecap fraction decision 0016 defines once (a function of the
   friction velocity and gravity, `Bracketed` there between the re-expressed wind
   power law and a breaking-threshold form; this record restates no form) times a
   per-whitecap production spectrum (Monahan et al. 1986; Grythe et al. 2014), the
   spectrum `Bracketed` (mechanisms: the cold, fresh end and the warm, saline end
   of the seawater temperature and salinity dependence its source carries); the
   gap to a form explicit in densities and surface tension is a declared absence
   with its sign and bound priced per REQ-ATM-013.
5. Field units are types, so a percentage cannot be read as a fraction
   (decision 0006); transport is in flux form and conserves mass by
   construction.
6. Earth oracle: emission, burden and lifetime per species against the AeroCom
   spread as REPORT rows (decision 0025).

## Enforced by

- Decisions 0006, 0009, 0016, 0022; the per-species mass ledger.
- A timestep-halving oracle per tracer in the registry (decision 0026).
- The mutation run (decision 0027): a per-step fractional sink and a second
  radius declaration must both be caught.

## References

- Parmentier, V., Showman, A. P., Lian, Y. (2013). *3D mixing in hot Jupiter
  atmospheres I: application to the day/night cold trap in HD 209458b.* Astron.
  Astrophys. 558, A91. DOI: 10.1051/0004-6361/201321132. Appendix A, the
  settling velocity from a drag balance with tabulated drag coefficients.
- Steinrueck, M. E., Showman, A. P., Lavvas, P., Koskinen, T., Tan, X., Zhang, X.
  (2021). *3D simulations of photochemical hazes in the atmosphere of hot Jupiter
  HD 189733b.* MNRAS 504(2), 2783-2799. DOI: 10.1093/mnras/stab1053. The sink
  stated as a rate with an explicit timescale, the positive example.
- Grythe, H., Strom, J., Krejci, R., Quinn, P., Stohl, A. (2014). *A review of
  sea-spray aerosol source functions using a large global set of sea salt aerosol
  concentration measurements.* Atmos. Chem. Phys. 14, 1277-1297.
  DOI: 10.5194/acp-14-1277-2014.
- Textor, C., et al. (2006). *Analysis and quantification of the diversities of
  aerosol life cycles within AeroCom.* Atmos. Chem. Phys. 6, 1777-1813.
  DOI: 10.5194/acp-6-1777-2006. The inter-model spread that is the Earth bar.
- Kok, J. F. (2011). *A scaling theory for the size distribution of emitted dust
  aerosols suggests climate models underestimate the size of the global dust
  cycle.* Proc. Natl. Acad. Sci. 108(3), 1016-1021.
  DOI: 10.1073/pnas.1014798108. The emitted size distribution the particle
  description of dust rests on.
- Wesely, M. L. (1989). *Parameterization of surface resistances to gaseous dry
  deposition in regional-scale numerical models.* Atmos. Environ. 23(6),
  1293-1304. DOI: 10.1016/0004-6981(89)90153-4. The resistance form the surface
  resistance bracket is declared in.
- Slinn, W. G. N. (1984). *Precipitation scavenging.* In Randerson, D. (ed.),
  Atmospheric Science and Power Production, DOE/TIC-27601, ch. 11. No DOI. The
  below-cloud scavenging coefficient's dependence on the raindrop spectrum.
- Monahan, E. C., Spiel, D. E., Davidson, K. L. (1986). *A model of marine aerosol
  generation via whitecaps and wave disruption.* In Monahan, E. C. and Mac
  Niocaill, G. (eds), Oceanic Whitecaps, Reidel, 167-174.
  DOI: 10.1007/978-94-009-4668-2_16. The whitecap-fraction form the source
  function is factored into.
- Carn, S. A., Fioletov, V. E., McLinden, C. A., Li, C., Krotkov, N. A. (2017).
  *A decade of global volcanic SO2 emissions measured from space.* Sci. Rep. 7,
  44095. DOI: 10.1038/srep44095. The passive volcanic flux the sulfate bound
  was scaled from.

## Amendments

- 2026-09-08: routed slip correction through REQ-ATM-017 and dispositioned dry and wet deposition coefficients as Bracketed with their provenance (audit rows 9, 18), from notes/findings/2026-09-08-implicit-earth-audit.md
- 2026-09-08: stated that published sea-salt source functions carry only the ten-metre wind, factored the emission into a Bracketed whitecap fraction and production spectrum, and priced the remaining gap as a declared absence (audit row 6), from notes/findings/2026-09-08-implicit-earth-audit.md
- 2026-09-08: cross-area review: the whitecap fraction read from its one definition in decision 0016; both ends named for the surface resistance, the scavenging coefficient and the production spectrum, from notes/findings/2026-09-08-implicit-earth-audit.md
