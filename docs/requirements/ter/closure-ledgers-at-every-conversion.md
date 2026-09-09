+++
id = "REQ-TER-003"
title = "Every conversion returns a closure ledger per conserved quantity, carrying both signed halves of any rounding, not only the net"
old_path = ["/home/cfutro/docs/world/config/spatial_conversion.yaml"]
old_commit = "6aa93489d233d4e9d531d6479d338c643e34bc5e"
status = "carried"
+++

## What is true

The predecessor's conversion envelope declared eight closure ledgers (area,
ocean volume, water, salt, energy, carbon, nitrogen, phosphorus), each with a
comparator, and required every applicable one to pass. What the ledgers had to
carry was learned from the coastline. Measured on the predecessor's
`canonical-10m-carve2` build across five truncations, the binary land mask's
NET land-area error ran from -1.14 per cent at T21 to -0.76 per cent at T170,
nearly flat, while the land actually dropped into the ocean ran 11.58 to 3.67
per cent and the water promoted to land 10.56 to 2.93 per cent: two one-signed
errors partly cancelling, the net hiding the rounding by a factor of 4.5 to 10.
A convergence claim read off the net would have reported the coastline
insensitive to support. The extensive closure that carried the sign was land
volume (area times elevation about the datum), +2.77 per cent at T21 falling to
+0.31 per cent, because the terrain the rounding flooded sat below the datum.
Where a ledger was kept in the right precision it closed: land draining to sinks
plus land draining to ocean plus non-land summed to the planet's area with
relative error 0.00e+00; the mosaic shares summed to one within 3.0e-8, which
was the float32 they were stored at, while the areas in float64 closed to zero.
The export's two dual areas differed in their sum by 0.068 per cent
(REQ-TER-011), an error a ledger with a floating-point-derived tolerance would
have caught on the first artifact.

## Why it carries

Exact nesting (decision A1) is what lets ledgers close identically at every
crossing, but only if every operator returns one and the store refuses an open
one. A net residual is the right number for a mass budget and the wrong one for
a convergence or acceptance claim, because compensating errors pass it. A
volume-type closure carries sign where an area closure does not. And the
tolerance a ledger is judged against has to be derived from the arithmetic, not
chosen, or a leak and a roundoff are indistinguishable.

## What this system must do

- Every operator returns `(field, ledger)` (decision A2); every `Exchange`
  closes ledgers at the component boundary (decision A5).
- A ledger exists per conserved quantity the operator touches, from a declared
  list per component (area, volume, water, salt, energy, carbon, nitrogen,
  phosphorus, momentum where applicable).
- A ledger carries the two signed halves (lost from source, invented at
  destination), the net, the tolerance derived from the floating-point type
  and the summation order, and the residual's classification by its time
  signature: leak, stock omission, or roundoff (decision C3).
- Ledgers and every accumulated reservoir are computed in FP64 accumulators or
  compensated summation regardless of the profile's `FT` (decision A7).
- The state store refuses an open ledger.
- Extensive closures that carry a sign the area does not (land volume, ocean
  volume, ice volume) are ledgers in their own right, not diagnostics.

## Enforced by

- A2 operator return type; A5 `Exchange`; A7 FP64 accumulators.
- C3: ledgers at every exchange on in-memory state with derived tolerance.
- M0 gate: area and nesting identities at every level; M5 gate: ledgers closed
  at the land seam; M7 gate: ledgers over a year.
- The weekly mutation run (C4) perturbs one weight and requires the ledger to
  fail.

## References

- Kahan, W. (1965). "Pracniques: Further Remarks on Reducing Truncation
  Errors". Communications of the ACM 8(1), 40. DOI: 10.1145/363707.363723.
- Higham, N. J. (1993). "The Accuracy of Floating Point Summation". SIAM
  Journal on Scientific Computing 14(4), 783-799. DOI: 10.1137/0914050. The
  bound a derived tolerance is computed from.
- Jones, P. W. (1999). "First- and Second-Order Conservative Remapping Schemes
  for Grids in Spherical Coordinates". Monthly Weather Review 127, 2204-2210.
  DOI: 10.1175/1520-0493(1999)127<2204:FASOCR>2.0.CO;2.
