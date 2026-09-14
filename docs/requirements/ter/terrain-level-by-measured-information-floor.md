+++
id = "REQ-TER-016"
title = "The terrain level is chosen by a measured information floor with a convergence test and a realisation-noise control, never fixed"
old_path = ["/home/cfutro/git/vesper/notes/audits/orogen-resolution.md"]
old_commit = "6aa93489d233d4e9d531d6479d338c643e34bc5e"
status = "carried"
+++

## What is true

Measured on the predecessor's generator from 100,000 to 25,000,001 regions of
one planet code. The designed terrain noise sat at fixed physical wavelengths
with the finest near 20 km, so on the pre-erosion surface the semivariance
gained 8 per cent per lag doubling below 10 km against 26 per cent at 50 km;
everything below about 15 km on the finished surface was erosion texture cut
at the mesh scale, placed by Voronoi jitter. Relief at fixed separation rose at
most 12 per cent for four times the regions and sat inside the realisation
scatter at every lag but two: "a finer generation does not unlock a reservoir
of sub-grid relief, because the generator does not have one to unlock". The
basin catalogue had a physical floor (area) and a numerical floor (twelve
cells); while the cell floor bound the catalogue grew with the mesh (3,621,
6,345, 9,419 preserved), and once the area floor took over it converged (9,649
at 2.5 times more regions, plus 2.4 per cent for 3.5 times the cost); the
crossover was predicted from the arithmetic and moved when the area floor
moved. The largest basin, polar, grew 80 per cent by delineation. Channel
threshold went from a third of land counted as channel to 15.5 per cent.

A realisation-noise control (three runs within 8 per cent in region count,
where the first plate seed's longitude moves and nothing else) killed two
claims: mean land elevation and area above 1 km moved LESS under four times
the regions than under 4 per cent; drainage concavity 0.392 to 0.444 sat inside
a noise floor of 0.119 and was withdrawn as evidence. "On a generator whose
mesh moves when its resolution does, a resolution claim needs a
same-resolution control before it is a claim at all." Two mechanism
hypotheses about glaciation, both plausible from the code, were refuted by a
control that switched glaciation off, in minutes. Statistics that carry a
mesh length do not transport: a one-edge gradient's quantile ratio between two
builds ran 1.41 at p50 to 1.70 at p99 (self-affine, no single factor removes
it); a compound topographic index shifted by exactly ln 2 (dimensional,
removable); a within-cell spread divided by the mesh spacing doubled while the
spread moved 1.6 per cent, the residual exactly one once the spacing was
divided out. The relief estimator that transported (all quantiles within a
1.15x bar fixed first) was a mean, not a minimum (an extreme-value statistic
biased by how many regions a ball holds), over a 90 km baseline above the
floor, anchored to a measured Earth escarpment block-averaged to both
spacings. A one-kilometre mean edge would have needed about 577 million
regions; the cost was superlinear in time and memory. The glacial accumulator
summed cells where the hydraulic one summed areas, so the same valley
collected four times the ice at four times the regions.

## Why it carries

Decision A1 makes levels a profile setting derived from the radius; B1's
snapshot must sit at a level where the terrain's designed content is resolved
and the derived structure (drainage, basins, scarps) has converged; the
`Closure` disposition (A3) requires a two-level sweep; and the plan expects
terrain "that looks coarser than a procedural generator's until the sub-grid
closure is proven". The evidence supplies the method: an information floor to
choose against, statistics whose change cell size predicts, a noise control,
and the rule that no physical statistic carries a mesh length.

## What this system must do

- The terrain level's spacing is chosen against a measured information floor:
  the variogram of the tectonic seed and of each process's designed
  wavelength, oversampled by a declared factor; the profile (A10) computes the
  level from that and the radius.
- Every derived catalogue declares its physical floor and its numerical floor
  and names which binds; the level is chosen so that the physical floor binds.
- Convergence is tested across two levels on statistics whose change cell size
  predicts (basin count above the physical floor, channel threshold, relief at
  fixed separation, scarp fraction), each with a bar registered before the
  measurement; a statistic inferred rather than predicted is not evidence for
  a level.
- A realisation-noise control (same level, perturbed seed stream) is run and
  its spread recorded before any level claim; a claim inside the spread is
  withdrawn.
- No statistic consumed by physics carries a mesh length: gradients over a
  declared baseline above the floor, indices normalised by a declared area,
  accumulation along the drainage graph in area never in cells; a statistic on
  a self-affine field declares its baseline.
- Sub-floor structure (glacial valleys, hillslopes, roughness) is a declared
  closure or tile statistic conditioned on the resolved terrain and matched to
  the measured variogram, never a refinement target.
- The Earth-landscape statistics of the M1 gate (scale-matched hypsometry in
  absolute height, concavity, drainage density, endorheic share,
  denudation-versus-relief) are FAIL bars only on the Earth test instance (the
  same constructor at Earth's parameters, 0025); on any other configuration they
  are REPORT distances, because REQ-TER-013 rejects rescaling relief by gravity
  and no other transport of an Earth landscape bar exists. The convergence-
  with-level test and the noise-floor control are what a level claim rests on
  under every configuration.
- A mechanism hypothesis is tested by switching the mechanism off before it is
  written down.

## Enforced by

- A10 profile: level derived from floor and radius; A3 `Closure` sweep.
- M1 gate: scale-matched hypsometry, concavity, drainage density and
  denudation-versus-relief with a noise-floor control at two levels, as FAIL on
  the Earth test instance and REPORT elsewhere.
- Oracle registry bars before measurement (C2).
- Lint: cell counts never enter a physical accumulation; every gradient
  operator takes a baseline argument.

## References

- Matheron, G. (1963). "Principles of geostatistics". Economic Geology 58,
  1246-1266. DOI: 10.2113/gsecongeo.58.8.1246. The variogram.
- Dodds, P. S., Rothman, D. H. (2000). "Scaling, Universality, and
  Geomorphology". Annual Review of Earth and Planetary Sciences 28, 571-610.
  DOI: 10.1146/annurev.earth.28.1.571. Self-affine topography and why a
  gradient depends on its sampling interval.
- Flint, J. J. (1974). "Stream gradient as a function of order, magnitude, and
  discharge". Water Resources Research 10, 969-973.
  DOI: 10.1029/WR010i005p00969. The concavity relation.
- Beven, K. J., Kirkby, M. J. (1979). "A physically based, variable contributing
  area model of basin hydrology". Hydrological Sciences Bulletin 24, 43-69.
  DOI: 10.1080/02626667909491834. The topographic index and the length it
  carries.
- Barnes, R., Callaghan, K. L., Wickert, A. D. (2020). "Computing water flow
  through complex landscapes - Part 2: Finding hierarchies in depressions and
  morphological segmentations". Earth Surface Dynamics 8, 431-445.
  DOI: 10.5194/esurf-8-431-2020.
- European Space Agency. "Copernicus DEM - Global and European Digital Elevation
  Model". DOI: to confirm. The measured escarpment anchor.

## Amendments

- 2026-09-08: the M1 Earth-landscape statistics scoped to the Earth test instance as FAIL bars and to REPORT on every other configuration (rows 11 to 15), from notes/findings/2026-09-08-implicit-earth-audit.md
