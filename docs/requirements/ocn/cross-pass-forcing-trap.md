+++
id = "REQ-OCN-006"
title = "The cross-pass forcing trap: a transport partition that emerges from resolved dynamics cannot be found by iterating frozen climatologies, so the atmosphere and ocean are coupled synchronously from the first orbit"
old_path = ["/home/cfutro/git/vesper/notes/external-model-survey.md"]
old_commit = "6aa93489d233d4e9d531d6479d338c643e34bc5e"
status = "carried"
+++

## What is true

`notes/external-model-survey.md` section 28 derived the mechanism behind the
predecessor's ocean loop. Poleward heat transport is shared between the
atmosphere and the ocean. In an intermediate-complexity model the atmospheric
transport is a parameterised object (a diffusion amplitude, a latitudinal
width, a linear term, per-tracer advection scalings) calibrated so that
atmosphere and ocean together produce a sensible total; the partition is a
tuned quantity. A resolved atmosphere run over a non-transporting ocean
carries the entire poleward load through emergent primitive-equation dynamics.
Hand that run's surface fluxes to a dynamic ocean and the ocean transports
too: the total is an atmosphere already carrying the full load plus an ocean
carrying more, and there is no coefficient to turn down (28b). The opposite
sign is the restored case: an ocean relaxed toward that climatology's SST
returns zero transport by construction (`ocean-and-marine-biosphere.md`
section 7). The predecessor's only remedy was an outer loop returning the
ocean's heat-flux convergence to the next atmospheric run, bounded at eight
iterations with refusal (28e, `transport_loop.yaml`). Section 59 recorded that
a geared online coupling replays a stored seasonal cycle, and that "geared
hard enough to be affordable it is offline coupling with a shorter iteration":
the property being paid for degrades in proportion to the affordability
bought. The cost argument that drove the offline choice (an atmosphere whose
cost climbed a spectral resolution ladder while the ocean needed thousands of
years) was a property of that stack.

## Why it carries

Any system in which the transport partition between two fluids emerges from
resolved dynamics has this property: the partition is a fixed point of the
coupled system, and an iteration over frozen forcing converges slowly or to
the wrong sign because each frozen pass encodes the previous pass's absence of
the other fluid. On a generic planet, with its own rotation, obliquity, land
fraction and ocean geometry, the partition is unknown in advance and there is
no Earth ratio to fall back on. The evidence supports synchronous coupling
from the first orbit, with acceleration of the slow reservoir done in a way
that never freezes the atmosphere's transport as a boundary condition.

## What this system must do

- The atmosphere, the land column, the sea ice and the ocean are stepped
  together from orbit one of any coupled run (B3, B9). No production path
  forces one fluid with a frozen climatology of the other.
- Deep-ocean acceleration (ocean-only segments, extended tracer timesteps,
  distorted physics) is a declared operation: the atmospheric forcing during
  the segment follows REQ-OCN-004's rule (temperature-dependent terms live
  against the ocean, evaporation replayed as one number); the segment has a
  declared drift criterion; a coupled re-adjustment segment precedes any exit
  evaluation; the acceleration factor is `Bracketed` and swept (B9).
- The transport partition (atmospheric and oceanic meridional heat transport
  as functions of latitude, and their sum against the TOA constraint) is a
  reported diagnostic of every coupled run, and its change across the last two
  windows is an exit axis (REQ-OCN-005).
- No transport coefficient of either fluid is adjusted to make the total or
  the partition come out (C2).

## Enforced by

- B3 decision record (synchronous coupling; alternating coupled and
  accelerated segments with a declared drift criterion) and B9 (tiers and
  exits).
- C2 anti-tuning: one parameter set by hash; physics is not a knob.
- C3 identity: the sum of the two transports integrates to the TOA imbalance
  profile to float tolerance (an energy ledger by latitude band).
- C1 tier 2: the Earth transport partition as a distance report with a bar
  from published inter-model spread; tier 3: aquaplanet and rotation-sweep
  partitions.
- M7 and M8 gates: the partition diagnostic present and the exit converged.

## References

- Stone, P. H. (1978). "Constraints on dynamical transports of energy on a
  spherical planet". Dynamics of Atmospheres and Oceans 2, 123-139.
  DOI: 10.1016/0377-0265(78)90006-4. (The total transport is set by the
  radiative constraint; the partition is not.)
- Held, I. M. (2001). "The Partitioning of the Poleward Energy Transport
  between the Tropical Ocean and Atmosphere". Journal of the Atmospheric
  Sciences 58, 943-948. DOI: to confirm.
- Holden, P. B., Edwards, N. R., Fraedrich, K., Kirk, E., Lunkeit, F. and
  Zhu, X. (2016). "PLASIM-GENIE v1.0: a new intermediate complexity AOGCM".
  Geoscientific Model Development 9, 3347-3361.
  DOI: 10.5194/gmd-9-3347-2016. (The geared coupling whose limit is the
  offline iteration.)
- Edwards, N. R. and Marsh, R. (2005). "Uncertainties due to
  transport-parameter sensitivity in an efficient 3-D ocean-climate model".
  Climate Dynamics 24, 415-433. DOI: 10.1007/s00382-004-0508-8. (The tuned
  partition the mechanism was read from.)
