+++
id = "0045"
title = "The literal lint is widened for named constants of a pinned precision, never for a whole file"
status = "accepted"
date = 2026-09-11
+++

## Decision

REQ-NUM-001 makes precision a type parameter, and `lint_literals` enforces it by
refusing a float literal that is not the argument of a typed constructor. Two kinds of
code sit outside that rule for a reason, and this record fixes which.

**A coefficient table is a bit pattern of its precision.** A truncated Taylor series,
a minimax fit, a Chebyshev interpolant, and the two- or three-part split of a constant
used in argument reduction are all chosen against the mantissa and the ulp of one
format. The truncation degree is fixed by where the next term falls below a fraction
of that format's ulp; the split's parts carry a bit count chosen so their products are
exact in that format. `FT(0.16666666666666666)` would not be the Float32 member of
such a set, it would be the Float64 member rounded, with a truncation degree chosen
for the wrong format and a split whose exactness condition no longer holds. A second
precision needs a second fit, not a conversion. So the literals of such a table are
not a defect the requirement is aimed at, and no typed constructor can express them.

**A module pinned to one format by method signature has no caller to take a type
from.** Where `f(x::Float64)` is the declaration, the precision is already in the type
system, which is what the requirement asks for; the `0.5` and `2.0` of its arithmetic
are not a precision the caller did not choose.

The exemption is therefore declared in `test/lint/lists/literals.toml` as a
`precision_pinned` entry naming one file, the constants of that file whose literals
are the format's bit patterns, and this record. Inside such a file a literal is
accepted on exactly two grounds:

1. it stands in the right-hand side of one of the constants the entry names; or
2. a round trip through Float32 returns its value unchanged, so it is the same number
   at either precision and carries no format.

Everything else in the file is refused exactly as it is anywhere else in `src`. A new
constant is refused until it is named, and a literal that is a format's bit pattern is
refused wherever it is written outside a named constant. Adding a second precision's
tables to a pinned file means naming them, which is the reach of the requirement being
decided again rather than inherited.

Clause 2 is stated against Float32 because Float32 is the narrowest format the project
runs (decision 0011, REQ-NUM-001 point 4): a value unchanged by that round trip is
unchanged by every wider one. It is not a general licence for exact literals. It holds
only inside a pinned file, and a pinned file is one whose methods declare a concrete
format.

## Alternatives considered

- *Exempt the file, which is what stood.* `Backends/transcendentals.jl` was added whole
  to the lint's `exempt` list. Lost on the positive control: an exemption that covers
  every line of a file has no case it refuses, so it cannot fail, and the project's rule
  is that a check that cannot fail is not a check. It also grows silently. The file is
  to gain a second precision's tables, and a per-file exemption covers whatever arrives
  with them, including a defect with nothing to do with a coefficient table.
- *Match constant names by pattern rather than naming them.* A pattern over `_SERIES`,
  `PIO2_*`, `CBRT_*` reads compactly. Lost: the module's constants do not share a shape.
  A pattern wide enough to reach `SQRT_TWO` and `EXPONENTIAL_MAX` reaches every
  screaming-case binding in the file, which is the per-file exemption again under
  another name. A pattern is also a promise about names not yet written, and the whole
  point of the narrower mechanism is that the next table has to be declared.
- *An explicit marker in the source, a comment or a macro above each table.* This is the
  form that keeps the declaration next to the thing declared, and it is the strongest of
  the losers. Lost on two counts. The marker would have to be added to
  `src/Backends/transcendentals.jl`, and a lint that can only be satisfied by editing
  the code it judges cannot be introduced without touching every file it will ever
  cover. And a marker is granted by the file being judged: the same source both writes
  the literal and declares it exempt, so nothing outside the file records what was
  widened. The list and this record are outside it.
- *Refuse the bodies too and require every arithmetic literal wrapped.* `FT(0.5)` in a
  method declared `::Float64` names a type parameter that does not exist, so it would
  have to be `Float64(0.5)`, which is the same bits with more characters. Lost: it
  refuses code the requirement is satisfied by, and the cost is paid in every line of
  every pinned module.
- *Drop the constants clause and keep only the Float32 round trip.* Lost outright: the
  coefficients are exactly the values that fail that test, which is what makes them
  coefficients. It would exempt the arithmetic and refuse the tables.

## Consequences

- `lint_literals` reads a `precision_pinned` array from its list, blanks the right-hand
  side of each named constant across the lines its brackets span, and applies the
  Float32 round trip to what is left. `Backends/transcendentals.jl` leaves the `exempt`
  list, which now holds only `Render` and `EarthRatios`.
- The lint refuses when an entry names a record that is not on disk, so the pointer this
  record is reached by cannot rot into a string.
- `fiddlybits-52v.7.13` adds a Float32 coefficient set to the pinned file. Its constants
  have to be added to the entry or the gate refuses them, and the row's file boundary
  has to carry `test/lint/lists/literals.toml` for that. This is the mechanism working:
  the widening is re-declared with each set rather than inherited from the first.
- The positive control the per-file exemption could not have now exists and runs in
  `build.lint_positive_controls`: the dirty fixture of `lint_literals` carries a pinned
  file with a literal outside every named constant, and the clean fixture carries the
  same file without it.
- A residual gap, stated rather than closed: a method added to a pinned file with a type
  parameter rather than a concrete format may use a Float32-exact literal without being
  refused. Closing it needs the lint to attribute each line to the method that encloses
  it, which is block tracking over Julia source, and the other lints of the suite are
  line scanners over blanked text. The pinned files are declared one at a time and each
  is a module of concrete-format methods; a generic method arriving in one is a change
  to what the entry claims, and it is caught by review rather than by the lint.
- Decision 0039's division is restored for this argument: the list carries what the lint
  does and a path, and the case for the reach is here.

## References

- `docs/requirements/num/precision-is-a-type-parameter.md` (REQ-NUM-001), the obligation
  the lint enforces, and point 4 on where Float32 is admitted.
- Decision 0039, which puts an argument in a record and leaves a comment a path.
- Decision 0011 (backends and precisions) and decision 0029 (bitwise mode), which are
  why the project's own polynomial transcendentals exist at all.
- `notes/findings/2026-09-11-polynomial-transcendentals-for-bitwise-mode.md`, the
  derivation and disposition of every constant the entry names, and the statement that
  the truncation degrees and the reduction splits do not carry to Float32.
- IEEE Standard for Floating-Point Arithmetic (IEEE Std 754-2019). DOI:
  10.1109/IEEESTD.2019.8766229, clause 5.4.2 on conversion between formats, which is
  the operation clause 2 round trips through.
