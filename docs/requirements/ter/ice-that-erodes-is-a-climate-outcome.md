+++
id = "REQ-TER-017"
title = "The ice that erodes terrain is a computed outcome of the declared climate evaluated at the terrain level, never a latitude-and-elevation ramp"
old_path = ["/home/cfutro/docs/world/source/README.md"]
old_commit = "6aa93489d233d4e9d531d6479d338c643e34bc5e"
status = "carried"
+++

## What is true

Evidence from `notes/audits/orogen-resolution.md`, `notes/audits/orogen-gravity.md`
and the "Ice is supplied, not inferred" section of the export README. The
predecessor's terrain generator placed the ice that carved its mountains and
fjords by a latitude-and-elevation ramp: an ice line at 58 degrees set by the
erosion slider, an altitude gate in the dimensionless elevation parameter,
consulting no temperature, spectrum, obliquity, eccentricity or rotation, and
not even its own temperature field, which ran later in the same pass. Every
declared parameter with leverage on an ice line differed from the Earth the
ramp was calibrated against and the three largest all pointed toward less polar ice.
Measured on the predecessor's baseline climatology at T42: the climate model's
own glacier field was identically zero over all 8,192 cells and twelve bins,
because a cell mean evaluates the high ground about 7.8 K too warm on average
and 21.9 K in the top tenth (sub-grid peak excess mean 1.065 km, maximum 5.27
km), and no ice survives that at any truncation the model could afford.
Lapse-correcting the warmest-interval surface temperature to each terrain
region's own elevation moved the land below freezing from 0.002 per cent to
1.657 per cent, nearly three orders: "T42 is sufficient for the climate and
insufficient for the mask, and those are not the same statement". The
thermal criterion says where ice can persist, not where a glacier forms, which
additionally needs accumulation. The mask was matched by region index with the
seed and region count in a sidecar and refused on mismatch. Two passes were
required, the first with glaciation off as "an honest null rather than an
Earth-calibrated guess", because glacial, hydraulic and thermal erosion shared
one loop and a later glacial pass would leave the overdeepenings it made
undrained. The dimensionless altitude gate was gravity-invariant because
strength-limited relief and the dry-adiabatic freezing height both go as 1/g,
so re-anchoring it to kilometres would have introduced an error; what the gate
lacked entirely was the temperature term.

## Why it carries

This is the plan's generalised lesson on couplings in its sharpest terrain
form: which latitudes and altitudes glaciate is a computed outcome of the
declared star, orbit, rotation and atmosphere, never a rule. Decision B1 reads
glacial erosion where the cryosphere's mask says so; B6 runs shallow ice at
the terrain level; B4 downscales forcing by the column's own lapse rate. The
evidence adds the two-scale structure (climate resolved at one level, ice
decided at a finer one), the ordering constraint on the erosion loop, and the
first-pass rule.

## What this system must do

- No terrain process reads latitude, or a fixed altitude, as a proxy for
  climate.
- Glacial erosion reads the cryosphere's ice thickness, sliding velocity and
  effective pressure (B6) on the terrain level through the two-limb law
  `E_g = K_g N^r |u_b|^l` of 0015, so the pressure it reads is used; surface mass balance is
  downscaled from the atmosphere level to the terrain level's elevation
  distribution by the column's own lapse rate and precipitation phase (B4),
  and freezing and accumulation are decided per fine cell or tile, never per
  cell mean (REQ-TER-009).
- Glacial, fluvial and hillslope erosion advance in one integration; a glacial
  overdeepening is a pit in the depression hierarchy (B5) and drains as
  physics.
- On a first pass with no climate, ice is a declared absence with its
  interface complete, not a calibrated guess; the coupling is asynchronous with
  a declared refresh criterion (B9).
- Ice state travels with its support identity and is matched by index
  (REQ-TER-010).
- The altitude at which ice persists is a computed height from the climate,
  and any dimensionless form of it is derived, with the cancellation it relies
  on stated.

## Enforced by

- A5 exchange ownership: the cryosphere is the one writer of ice state; the
  terrain reads it.
- Lint: latitude is unreadable in terrain physics modules.
- C3: Halfar dome; M1 gate: age times rate identity; M8: an obliquity or
  spectrum sweep moves ice extent in the direction the forcing implies.

## References

- Glen, J. W. (1955). "The creep of polycrystalline ice". Proceedings of the
  Royal Society A 228, 519-538. DOI: 10.1098/rspa.1955.0066.
- Halfar, P. (1983). "On the dynamics of the ice sheets 2". Journal of
  Geophysical Research 88(C10), 6043-6051. DOI: 10.1029/JC088iC10p06043.
- Braun, J., Zwartz, D., Tomkin, J. H. (1999). "A new surface-processes model
  combining glacial and fluvial erosion". Annals of Glaciology 28, 282-290.
  DOI: 10.3189/172756499781821797.
- Egholm, D. L., Nielsen, S. B., Pedersen, V. K., Lesemann, J.-E. (2009).
  "Glacial effects limiting mountain height". Nature 460, 884-887.
  DOI: 10.1038/nature08263. The climate-set altitude that ice enforces on
  relief.

## Amendments

- 2026-09-08: glacial erosion named as the two-limb law of 0015 so the effective pressure this record requires to be read is consumed (row 3), from notes/findings/2026-09-08-implicit-earth-audit.md
- 2026-09-08: cross-area review: the glacial-erosion pressure exponent renamed `r`, from notes/findings/2026-09-08-implicit-earth-audit.md
