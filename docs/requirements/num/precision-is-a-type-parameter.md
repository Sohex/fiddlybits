+++
id = "REQ-NUM-001"
title = "Precision is a type parameter, never a flag; an accumulated reservoir never stagnates"
old_path = ["/home/cfutro/docs/world/notes/audits/single-precision-spin-up.md", "/home/cfutro/docs/world/notes/audits/compiled-precision.md"]
old_commit = "6aa93489d233d4e9d531d6479d338c643e34bc5e"
status = "carried"
+++

## What is true

Measured on the predecessor's spectral GCM, a Fortran build whose precision was a
compiler flag. An additive update whose increment is below half an ulp of the value
it is added to rounds back to that value and the increment is lost entirely
(stagnation). Every reservoir in that model was updated that way and held an
absolute temperature near 290 K, where the Float32 ulp is 3.05e-5 K. The net flux
below which one 2700 s step changed a 50 m slab not at all was 1.16 W/m2, and the
threshold scaled linearly with the reservoir's heat capacity: 4.65 W/m2 at 200 m,
46.5 W/m2 at 2000 m. No time-mean surface flux reaches the deeper thresholds, so any
deep reservoir made single precision unsound at once. Elapsed-time counters that
accumulated sub-millisecond increments in Float32 stopped advancing near 1e4 s.

The stagnation deadband cannot be bounded from the source: its size depends on how
much time the net flux spends near zero, which is a model output. The strict
one-sided worst case over one spin-up was 0.026 to 0.156 K, against a convergence
criterion worth 0.009 to 0.050 K.

Two precisions are not the same trajectory. The flow is chaotic and the two arms
decorrelate within model days, so a state-by-state comparison means nothing; only
the climate can be compared. Measured on two arms at the coarsest level: at 40
orbits the four-byte arm was 0.077 K cooler at a nominal 2.04 sigma; at 85 orbits it
was 0.187 K warmer at a nominal 7.24 sigma. The sign reversed. With a lag-1
autocorrelation of 0.615 the 85 orbits held about twenty independent samples and the
whole-run difference was +0.014 +- 0.035 K, four tenths of a standard error; the
sigma figures had been computed on the raw orbit count. The four-byte arm was 27 to
40 per cent faster, the gain growing with resolution because it buys memory
bandwidth.

Precision as a flag failed in the other direction too. A build script passed a rank
count where the driver expected bytes; the driver matched neither 4 nor 8 and fell
through to a default of 4, so every sixteen-worker binary in the registry was
single precision while the manifest recorded eight. No result moved, because a
rebuild-on-first-use path silently replaced the binary before any orbit ran; the
provenance record described an executable that never integrated anything. A
four-byte binary could not read an eight-byte checkpoint, and nothing converted
state between precisions.

## Why it carries

This system is GPU-first on consumer hardware where FP64 runs at a small fraction of
FP32 throughput, so production profiles run fast fields at FP32 (A7). Stagnation is
a property of IEEE arithmetic and not of the old model: any reservoir integrated by
repeated small additions at a working precision stalls where the increment falls
below half an ulp of the stored value, and the threshold scales with the reservoir's
capacity. The slow reservoirs of a generic builder (deep ocean heat and salt, soil
carbon, ice volume, regolith) are exactly the long accumulations where the loss is
silent and unbounded. The flag lesson is that a precision carried as a string can be
misparsed, mis-recorded and silently rebuilt around; a precision that is a type
parameter is checked by the compiler, named in the artifact key, and cannot differ
from what the code ran.

## What this system must do

1. `FT` is a type parameter end to end: `System{FT}`, every `Field`, every kernel.
   There is no runtime flag, environment variable or string that sets precision.
   Mixed precision inside a profile is declared per field class and per kernel,
   never inferred from the hardware.
2. Every ledger, every accumulated reservoir and every global reduction is computed
   in Float64 accumulators or with compensated summation regardless of `FT`. Time
   accumulators are integers on the SI clock (A4), never floats.
3. A stagnation test is derived from the field registry and the profile: for each
   accumulated field, the flux threshold below which one step at the profile's
   timestep changes the stored value by less than half an ulp of its typical
   magnitude is computed, and a profile in which that threshold exceeds a declared
   fraction of the field's forcing scale is refused. The refusal names the field
   and the required precision.
4. An FP32 kernel is admitted to a production profile only after the ulp-ensemble
   certification against its `FT = Float64` self (C6); a reservoir is never at
   FP32.
5. A comparison between precisions is climatological: a window sized by the
   autocorrelation-corrected standard error, on a stationary span, with the criterion
   fixed before the run. A state-by-state comparison between precisions is not an
   oracle and the comparison tool refuses it.
6. A checkpoint records the `FT` it was written at; loading it into a different `FT`
   is an explicit conversion operator with its own ledger and a new run id, never an
   implicit cast.
7. Backend and precision are part of the run identity (C6, REQ-PROV-002).

## Enforced by

The type system (`Field{S,T,D,L,A}` with the array eltype fixed to the profile's
`FT`); a lint banning Float32 literals and `FT` arrays in ledger and reservoir
modules; the stagnation test over the field registry at M0; the ulp-ensemble
certification job (C6); run identity composition (A6); decision records A7 and C6.

## References

- IEEE Standard for Floating-Point Arithmetic (IEEE Std 754-2019). DOI: 10.1109/IEEESTD.2019.8766229
- Goldberg, D. 1991. What every computer scientist should know about floating-point arithmetic. ACM Computing Surveys 23(1). DOI: 10.1145/103162.103163
- Higham, N. J. 1993. The Accuracy of Floating Point Summation. SIAM Journal on Scientific Computing 14(4). DOI: 10.1137/0914050
- Kahan, W. 1965. Pracniques: further remarks on reducing truncation errors. Communications of the ACM 8(1). DOI: 10.1145/363707.363723
- Madras, N., Sokal, A. D. 1988. The pivot algorithm: A highly efficient Monte Carlo method for the self-avoiding walk. Journal of Statistical Physics 50. DOI: 10.1007/BF01022990 (autocorrelation-corrected standard error, section 2.2)
- Lorenz, E. N. 1963. Deterministic Nonperiodic Flow. Journal of the Atmospheric Sciences 20(2). DOI: 10.1175/1520-0469(1963)020<0130:DNF>2.0.CO;2
