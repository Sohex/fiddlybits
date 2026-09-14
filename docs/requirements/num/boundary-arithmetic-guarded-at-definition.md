+++
id = "REQ-NUM-003"
title = "Arithmetic at a physical boundary is guarded at the definition, and a kernel reads only what it wrote"
old_path = ["/home/cfutro/git/vesper/notes/audits/masked-where-blocks.md", "/home/cfutro/git/vesper/notes/audits/uninitialised-reads-and-implicit-save.md"]
old_commit = "6aa93489d233d4e9d531d6479d338c643e34bc5e"
status = "carried"
+++

## What is true

Measured on the predecessor's spectral GCM. A masked array block protected the
store and not the evaluation: a vectorising compilation computed every lane and
blended, and with floating-point traps unmasked a discarded lane whose argument was
out of domain raised a fault. A run died eight orbits in; clamping the site that
faulted moved the fault to a second site and then a third. A lexical pass found 56
domain-sensitive intrinsics and 345 divisions inside masked blocks. The larger class
was not the intrinsic but the operand: 53 locals in one shortwave routine were
written only under a "sun is up" mask and then divided by, exponentiated and
logarithmed on night lanes, where they held whatever the stack held; nine soil
locals were written under a land mask and divided on sea lanes. The repair that
held was to preset every lane to the value the physics produces on the excluded
lane (a transparent atmosphere over a black surface, the unchanged state, zero
flux) and to floor each argument at the point the quantity is defined, each floor
argued a no-op on the lanes the mask keeps, with a positive control: removing one
floor made exactly one site reappear. A full orbit at the optimisation level that
had woken the class then ran with traps unmasked and took no fault.

Nine transmissivity denominators of the form 1 - A(u)/S_band were safe on the Sun
by five orders of magnitude and safe on the configured K star by a factor of ten,
because the band split and two re-weightings of the absorptance depended on the
star. A formula's safety margin was a property of the host star, not of the
formula.

Uninitialised reads were untrappable in production because the build filled them
with zero, a valid operand; filling with a signalling NaN trapped only at low
optimisation because the compiler folded the signalling pattern to a quiet one
before any instruction ran. The gate that worked at production optimisation was the
propagating one: initialise to NaN, mask the trap, compare the checkpoint bitwise
against the production build, with a positive control that reaches a temperature
tendency.

## Why it carries

A GPU lane has no branch in the scalar sense: a warp evaluates both sides of a
divergent branch and masks the store, `ifelse` evaluates both arms, and a
broadcast over a mask evaluates the whole array. The class "a mask is not a guard"
is exactly the GPU-first class, and on the device there is no trap at all: a read of
an unwritten lane or a domain violation produces a number silently. Julia's
`Array{T}(undef, n)` is a read of unwritten memory the moment it is consumed. The
stellar finding generalises: this builder declares arbitrary stars, gravities and
surface pressures, so any expression whose domain was guaranteed by an Earth or
solar range must be guarded by construction, with the margin measured on the
declared system rather than assumed from the reference implementation.

## What this system must do

1. A domain-sensitive operation (square root, logarithm, division, a real power of a
   base that can be negative, inverse trigonometry, an exponential that can
   overflow) is guarded where the quantity is defined: the argument is floored or
   clamped at its definition, the value on the excluded set is stated and argued to
   be a no-op on the included set, and the guard is never a mask around the store.
2. A kernel writes every element of every output and scratch buffer it touches
   before reading it. `undef` allocation in physics modules is permitted only for
   buffers a kernel fully overwrites, and a poison mode fills every `undef` buffer
   with NaN, disables traps, and requires the state hash to equal the production
   run's. The poison job carries a positive control that reaches a tendency.
3. The store performs a per-step finiteness check on prognostic state and refuses,
   naming the field and the cell; debug mode additionally traps per kernel.
4. The domain bounds of every parameterisation are stated against the declared
   system's state brackets and the declared spectra, not Earth's. A registered test
   evaluates each guarded expression over the profile's brackets and the declared
   stars, reports the margin to the nearest singularity, and refuses a margin below
   a declared factor. The same test covers the validity range of every `Sourced`
   table and fit the atmosphere reads: the k-table pressure-temperature grid, each
   line list's temperature range, each continuum pair's range, the activation fit's
   updraught and pressure range, and the gas-mixture property relations of
   REQ-ATM-017; a bracket that leaves a range is a refusal naming the table.
5. A lint over kernel sources flags masked arithmetic (`ifelse`, masked broadcast,
   `@inbounds` conditional stores) over a domain-sensitive function whose argument
   is not guarded, and flags any read of a buffer no prior statement in the kernel
   wrote.

## Enforced by

The kernel lint; the poison-mode CI job with its positive control; the finiteness
refusal in the state store; the margin test in the oracle registry; the mutation
run (C4), which includes removing one floor and must catch it; decision records A7
and C3.

## References

- IEEE Standard for Floating-Point Arithmetic (IEEE Std 754-2019). DOI: 10.1109/IEEESTD.2019.8766229
- Goldberg, D. 1991. What every computer scientist should know about floating-point arithmetic. ACM Computing Surveys 23(1). DOI: 10.1145/103162.103163
- Muller, J.-M., et al. 2018. Handbook of Floating-Point Arithmetic, second edition. Birkhauser. DOI: 10.1007/978-3-319-76526-6

## Amendments

- 2026-09-08: extended the registered margin test to the validity ranges of every Sourced table and fit the atmosphere reads (audit rows 4, 13, 19, 40), from notes/findings/2026-09-08-implicit-earth-audit.md
