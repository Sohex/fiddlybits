+++
id = "REQ-BIO-018"
title = "A biogenic volatile organic source is a declared absence with a complete interface: emitted carbon debits a plant pool, activation refuses rather than defaults, and a biosphere-derived trace-gas flux never coexists with a prescribed atmospheric abundance of the same species"
old_path = ["/home/cfutro/git/vesper/biosphere/notes/bvoc-activation-contract.md", "/home/cfutro/git/vesper/biosphere/notes/bvoc-soa-atmospheric-coupling-audit.md", "/home/cfutro/git/vesper/biosphere/notes/bvoc-cloud-sensitivity-preregistration.md"]
old_commit = "6aa93489d233d4e9d531d6479d338c643e34bc5e"
status = "carried"
+++

## What is true

One switch in an Earth vegetation model (`ifbvoc`) read as one model and was
four: plant production and emission of speciated volatile carbon, its
oxidation by radicals in an atmosphere whose oxidant state the project had not
derived, the formation, growth, transport and removal of the organic aerosol
that oxidation would make, and what that aerosol would do to radiation and
clouds. Only the first existed in the source (measured on the old world's fork
at the archived commit):

- Emitted carbon was reported and never removed from assimilation, NPP, a
  labile pool or the storage pool's parent stock: the model could emit carbon
  without lowering biomass. The synthesis also spends electron transport, so a
  coupled run must charge the carbon and its declared energetic cost exactly
  once. Six orders of magnitude separated the emission units from the plant
  pools they had to be subtracted from.
- The output layer collapsed nine monoterpene compounds to two classes, and
  the chemistry those compounds feed is branch-dependent on exactly the
  identity that collapse destroys (alpha- and beta-pinene have different
  highly-oxidised-molecule yields; isoprene suppresses monoterpene nucleation in
  some regimes).
- The emission capacities were Earth measurements at standard laboratory
  conditions (370 ppm CO2, 30 C, 1000 umol photons, 12 h daylight), converted
  through the Earth photon constant; several entries said in the source they
  had been copied from another type. Species aggregation alone moves apparent
  capacity by about 50 percent for isoprene and 40 percent for monoterpenes in
  opposite directions, so brackets carry a FLOOR read from the global
  emissions framework, and a declared bracket narrower than its floor is
  refused: a narrow bracket is a claim to know the flora better than Earth
  studies know Earth's, and it arrives looking like progress.
- The environmental response mapped daylength to radians with a literal 24,
  assumed a 12 h light period, and fixed air density at 1.204 kg/m3; storage
  used 2, 80 and 365 DAY time constants.
- The atmosphere prescribed methane and ozone from a photochemical calculation
  holding modern Earth biogenic surface fluxes fixed. A volatile source from
  the configuration's own vegetation combined with that state is not one
  atmospheric state, because the volatile flux consumes the radicals that set
  methane's lifetime and forms or destroys ozone depending on nitrogen oxides;
  nothing crashes when the two are combined, so the gate refused the
  combination by name.
- Mass and optical depth do not determine particle number, and the climate
  model had no pathway from aerosol to droplet; the cloud question was
  therefore structural, pre-registered as three arms with a decision rule
  fixed before any arm ran, and any arm carried on an optical-depth multiplier
  was refused because an optical depth silently averages over size,
  hygroscopicity, ion production, seed surface and supersaturation.
- Secondary organic aerosol is not generically absorbing: most is nearly
  white, and brown carbon depends on precursor, nitrogen oxides, ammonia,
  aqueous processing and ageing; pyrogenic carbon is a distinct absorbing
  source.

## Why it carries

The founding principle F2 says a subsystem may be a declared absence but its
interface may not. B2 carries tracers, aerosol activation from droplet number
and Chapman ozone driven by the declared ultraviolet, so the atmosphere half
of this loop has an owner in the design and the biosphere half must present
its flux in the form that owner needs: speciated, mass-conserving, chargeable
to a plant pool, on the system's photon currency and rotation. The
prescribed-abundance refusal generalises to every biosphere-derived trace gas
(methane in REQ-BIO-017, nitrogen oxides in REQ-BIO-011): a flux from a
computed biosphere and an abundance from another planet's biosphere are two
accounts of one quantity.

## What this system must do

1. The biogenic volatile organic source is a component with its interface
   complete from the start: per tile and strategy, a speciated emission flux
   (compound identity preserved to the class the chemistry branches on), the
   storage pool as prognostic restart-exact state, and the carbon and
   energetic cost debited from a named plant pool exactly once (REQ-BIO-007
   ledgers). Whether the component is active is a declared absence or presence
   per configuration; the absent case refuses, it does not default to zero.
2. Emission capacities and storage strategies are traits in the strategy space
   (REQ-BIO-006) with `Bracketed` ranges whose floors come from the measured
   spread of the source studies; the Earth means are one named transplanted
   baseline. The environmental response reads the photon flux of REQ-BIO-003,
   the planet's rotation and photoperiod (REQ-BIO-001), and the column's
   temperature, pressure, humidity and wind (REQ-BIO-002); no literal 24, 12 or
   365 and no Earth air density.
3. The unrepresented volatile classes (oxygenates, sesquiterpenes and other
   high-yield organics, stress-induced emissions) are a named lower model plus
   a lumped `Bracketed` source, kept separate from pyrogenic smoke.
4. The emitted flux enters the atmosphere's tracers (B2), where oxidation,
   partitioning, particle formation and removal are the atmosphere's and the
   organic aerosol reaches activation as particle number with size and
   hygroscopicity, never as an optical-depth multiplier; the direct optical
   properties of the organic aerosol are a `Bracketed` range spanning
   scattering to weakly absorbing.
5. A configuration in which any species' atmospheric abundance is prescribed
   while a biosphere-derived source or sink of that species is active is
   refused at `assemble` (A5) by name; the abundance is a derived state of the
   loop or the source is a declared absence.
6. The aerosol-cloud response of the biogenic source is a registered model-form
   sensitivity with its decision rule fixed before any arm runs (C2), scored
   on whether a decision the system makes moves beyond the run's own scatter.

## Enforced by

- Type: the emission component's constructor requires the plant pool it
  debits and the tracer it feeds; a "diagnostic-only" emission has no
  constructor.
- Ledgers: plant carbon closure including emitted volatile carbon (C3);
  restart round trip of the storage pool.
- `assemble` refusal on prescribed-abundance-with-active-source; the bracket
  floor check in the strategy registry.

## References

- Arneth, A. et al. (2007). Process-based estimates of terrestrial ecosystem
  isoprene emissions: incorporating the effects of a direct CO2-isoprene
  interaction. Atmospheric Chemistry and Physics 7, 31-53.
  DOI: 10.5194/acp-7-31-2007.
- Schurgers, G., Arneth, A., Holzinger, R. and Goldstein, A. H. (2009).
  Process-based modelling of biogenic monoterpene emissions combining
  production and release from storage. Atmospheric Chemistry and Physics 9,
  3409-3423. DOI: 10.5194/acp-9-3409-2009.
- Schurgers, G., Arneth, A. and Hickler, T. (2011). Effect of climate-driven
  changes in species composition on regional emission capacities of biogenic
  compounds. Journal of Geophysical Research 116, D22304.
  DOI: 10.1029/2011JD016278. The aggregation effect that sets bracket floors.
- Guenther, A. B. et al. (2012). The Model of Emissions of Gases and Aerosols
  from Nature version 2.1 (MEGAN2.1): an extended and updated framework for
  modeling biogenic emissions. Geoscientific Model Development 5, 1471-1492.
  DOI: 10.5194/gmd-5-1471-2012.
- Shrivastava, M. et al. (2017). Recent advances in understanding secondary
  organic aerosol: Implications for global climate forcing. Reviews of
  Geophysics 55, 509-559. DOI: 10.1002/2016RG000540.
- Tsigaridis, K. et al. (2014). The AeroCom evaluation and intercomparison of
  organic aerosol in global models. Atmospheric Chemistry and Physics 14,
  10845-10895. DOI: 10.5194/acp-14-10845-2014.
- Kirkby, J. et al. (2016). Ion-induced nucleation of pure biogenic particles.
  Nature 533, 521-526. DOI: 10.1038/nature17953.
- Gordon, H. et al. (2016). Reduced anthropogenic aerosol radiative forcing
  caused by biogenic new particle formation. Proceedings of the National
  Academy of Sciences 113, 12053-12058. DOI: 10.1073/pnas.1602360113.
- Carslaw, K. S. et al. (2013). Large contribution of natural aerosols to
  uncertainty in indirect forcing. Nature 503, 67-71.
  DOI: 10.1038/nature12674.
