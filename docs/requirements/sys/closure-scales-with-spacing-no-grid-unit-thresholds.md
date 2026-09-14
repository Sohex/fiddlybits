+++
id = "REQ-SYS-104"
title = "A sub-grid coefficient is a Closure with a scaling law in grid spacing; nothing is declared in cells, steps or truncation number; a dormant Earth-fitted process names its re-derivation at the switch"
old_path = ["/home/cfutro/git/vesper/notes/audits/dormant-exoplasim-modules.md"]
old_commit = "6aa93489d233d4e9d531d6479d338c643e34bc5e"
status = "carried"
+++

## What is true

Measured on the predecessor's vendored spectral GCM, on a planet of 1.2 Earth radii
so that a given truncation bought 20 per cent coarser spacing in kilometres.

- A storm-capture diagnostic hunted a resolved vortex over at least 30 grid cells
  sustained at least 256 timesteps, with an absolute-vorticity threshold that was
  25 per cent too strict at 0.8 of Earth's rotation rate and a cell-count
  threshold that was a 44 per cent larger storm on the larger planet. The
  resolution at which cyclone-like vortices reach realistic intensity, about
  50 km, was off the resolution ladder entirely (this audit, section 3). Two of
  its eight index fields carried Earth cyclogenesis normalisations inside
  continuous expressions no namelist could reach, so "wanting the diagnostic" was
  a re-derivation and not a switch.
- The stratiform cloud threshold `rcrit = 0.85` encoded sub-grid humidity
  variance for a T21 Earth grid box and had no term in cell area; at the interior
  levels `1/(1-rcrit)^2 = 44`, so 0.01 in the threshold moved cloud fraction by
  0.01 to 0.03 absolute (`model-earth-centrism.md` finding 8).
- Snow masked the surface at 0.01 m water equivalent regardless of cell size or
  of the roughness of what it buried, on a surface whose roughness spanned 0.004
  to 7.6 m (finding 22). Convective cloud cover was a regression on a cell-mean
  rain rate, so the cloud fraction of a convecting region depended on the rung
  through that pair alone (finding 23).
- A precipitation re-evaporation constant took a 43 per cent step on a truncation
  branch with no derivation on either side, while its physical content depended
  on the step length and not the truncation (`opaque-constants.md` finding 13).
  A per-(truncation, level-count) table of radiation tunings was dead code, so
  every rung ran the T21 row (`model-earth-centrism.md`, dormant section). A
  roughness-tuning constant carried its own admission that it was tuned to T21.
- The derived hyperdiffusion rule was the positive example: `pi R / (N U)` in
  radius, truncation and a wind speed, with no Earth day in it.
- Nine compiled modules never executed. Three were settled decisions; the ones
  that were one key away carried Earth weathering constants, Earth biome fits and
  Earth cyclogenesis thresholds, so enabling any of them was an inheritance rather
  than a free mechanism, and nothing said so at the switch until the audit put it
  there (sections 2 and 3; `model-earth-centrism.md`, "Dormant, and what each
  waits on").

## Why it carries

A coefficient that stands in for truncated sub-grid variance is a function of
what is truncated, so it is a function of grid spacing and of the resolved state;
a number anchored to one truncation on one planet is a tuning by construction.
This is the `Closure` disposition of decision 0007, and this audit is its evidence
across cloud, snow, precipitation and diagnostics. The second lesson is the
founding principle that a subsystem may be a declared absence but its interface
may not (decision 0003): a dormant process with Earth constants inside it must
state, where the switch is, what enabling it re-derives. Thresholds in cells or
steps are the same class in integer clothing.

## What this system must do

1. Every coefficient representing truncated sub-grid variance (eddy diffusivity,
   hyperdiffusion, a sub-grid humidity or cloud PDF width, snow-cover fraction
   against sub-grid relief and roughness, a convective trigger area, hillslope
   diffusion) is declared `Closure`: a sourced scaling law in the grid spacing
   and the resolved state, with a bracketed dimensionless coefficient, swept
   across at least two mesh levels with a convergence-with-level oracle
   (decision 0007).
2. No parameter is declared in grid cells, timesteps, truncation number or
   levels. A threshold with a physical meaning is declared in SI (an area, a
   duration, a vorticity), and the conversion to the profile's discretisation
   happens at the read (decision 0014).
3. A per-resolution table of constants is refused; a branch on truncation or
   level count in physics code is a lint failure.
4. A diagnostic or process that requires a resolution the running profile does
   not have reports `NotEvaluable` by name rather than a number (decision 0025).
5. A process that is a declared absence has its interface complete; every
   Earth-fitted constant inside a dormant process carries its disposition before
   the process can be enabled, and the switch's documentation names what a
   configuration must re-derive (decision 0003, decision 0002).
6. Thresholds inside continuous expressions are parameters like any other: a
   normalisation folded into a formula is declared beside the formula.

## Enforced by

- The `Closure` type requiring a `scaling(dx, state)` method; a coefficient
  without one does not construct.
- The convergence-with-level oracle in the registry, run across the profile
  ladder (decisions 0014, 0026).
- A lint on integer thresholds with cell or step units and on branches keyed to
  a level count or truncation.
- The failure-classes review (decision 0028), row "tuned to one resolution".
- The scope decision 0002 and the risk tripwire "a process added without a
  record" (decision 0035).

## References

- Sundqvist, H. (1978). *A parameterization scheme for non-convective condensation
  including prediction of cloud water content.* Q. J. R. Meteorol. Soc. 104(441),
  677-690. DOI: 10.1002/qj.49710444110 (to confirm). The critical-humidity form
  whose threshold encodes sub-grid variance.
- Smagorinsky, J. (1963). *General circulation experiments with the primitive
  equations: I. The basic experiment.* Mon. Wea. Rev. 91(3), 99-164.
  DOI: 10.1175/1520-0493(1963)091<0099:GCEWTP>2.3.CO;2 (to confirm). The
  original statement of a sub-grid diffusivity as a scaling law in grid spacing
  and resolved strain, which is the shape every `Closure` takes.
