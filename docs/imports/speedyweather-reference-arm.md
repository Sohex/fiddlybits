# SpeedyWeather.jl as an independent reference arm

**What it is.** A spectral atmospheric general circulation model in Julia with a
composable parameterisation system and GPU work in progress. It runs on ring
grids (Gaussian, octahedral, HEALPix families) because its core is spectral.

**What of it is used.** Nothing in the model. It is run *beside* this system as an
independent implementation for dynamical-core comparisons: Held-Suarez and
aquaplanet configurations at the same planetary parameters, compared on
climatological statistics. It recovers the second implementation the predecessor
lost when it removed the reference arms it compared against.

**Why it is not a component.** Its grids are latitude rings, which would reinstate
the grid crossing this design exists to delete; its planet type carries a day
length in hours, a year length in days, an equinox as a calendar date, and Earth
defaults. Those are exactly the assumptions this project does not import.

**Assumptions it carries, as a reference arm.**

| assumption | present | how it is prevented from contaminating a comparison |
| --- | --- | --- |
| Earth defaults | yes, on its planet struct | the comparison harness constructs its planet from our `System` explicitly, every field, and asserts no default was used (`test/reference_arm/no_defaults.jl`) |
| calendar | a `DateTime` epoch and a day in hours | the harness converts from our SI clock and asserts the round trip |
| grid | ring grids | comparisons are on zonal-mean and global statistics only, never on a remapped field |
| precision | `Float32` default | run at `Float64` for the comparison |

**Licence.** MIT. **Version.** `to pin` at the release used for the first
comparison; `to verify` its GPU status is irrelevant to its use here.

**Checklist items applied.** A1 (day and year are stated on its planet type;
recorded), A2 (its planet block classified; all runtime, Earth-defaulted), A3
(literals `to verify` in the used surface), C3 (its non-Earth capability is
declared; the harness demonstrates it on our parameters), D2 (the boundary is
our harness; every field checked).
