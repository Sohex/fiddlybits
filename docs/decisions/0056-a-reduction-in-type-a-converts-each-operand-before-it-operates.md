+++
id = "0055"
title = "A reduction accumulated in type A converts every operand to A where it reads it, so each term's product is formed in A and not in the operands' own type"
status = "accepted"
date = 2026-09-13
+++

## Decision

**"Accumulated in type `A`" means every arithmetic operation of the accumulation is an
operation in `A`.** A reduction reads each input element and converts it to `A` at the
read; the terms it forms from those elements, and the sum, are then operations on
values of type `A` only. A weighted term is the product of the two converted operands,
`A(x) * A(w)`, and not the product at the operands' promoted type converted afterwards,
`A(x * w)`. A kernel spells that product `Backends.nofuse_mul(A(x), A(w))` where its
product has to be rounded on its own before the add (decision 0044); its naive reference
spells it `A(x) * A(w)` (decision 0027). Both forms are the same rounding chain.

The two orders agree whenever the operands' promoted type is `A`. They differ when both
operands are narrower than `A`, where `A(x * w)` rounds the product at the narrow type
and `A(x) * A(w)` does not, and when either operand is wider than `A`, where `A(x * w)`
forms the product at the wide type and `A(x) * A(w)` rounds each operand into `A` first.

Three arguments decide it.

**The precision of a result is the one its call declares.** Decision 0011 makes the
floating-point type a type parameter end to end, so that a declaration fixes precision
and no flag or input does. Under `A(x * w)` the precision at which a term is rounded is
the promoted element type of the arrays passed in, which is a property of the caller's
storage and not of the call: a reduction declared `Float64` over two `Float32` arrays
would round every term at `Float32` and say `Float64`. Under `A(x) * A(w)` the result
of a call at `A` depends on its inputs only through their values in `A`, so passing
arrays of another type and converting them first give the same answer.

**Decision 0011's reductions in double precision are double precision in each term.**
Every ledger and global reduction is accumulated in double precision independently of
the profile's type. A `Float32` field reduced against `Float32` weights into `Float64`
under `A(x * w)` carries one `Float32` rounding per term into the double accumulator,
which is the per-term error the rule exists to keep out. Under `A(x) * A(w)` the
product of two `Float32` values is exact in `Float64`, because it needs at most 48
significant bits, so the only rounding left is the double accumulation itself, and
`Reductions.error_bound` at `Float64` bounds the result against the exact sum of the
exact products.

**A reduction's `Float32` instance is the one the certification runs.** The certification
of decision 0029, `repro.fp32_kernel_certification`, runs a kernel at `Float32` against
its own `Float64` run, with the fields narrowed to `Float32` before the first step, and
its per-step roundoff is read from `Reductions.error_bound` at the certified type. Under
`A(x) * A(w)` a reduction called at `Float32` over `Float64` inputs is that narrowed
instance exactly. Under `A(x * w)` it is a third computation, part double and part
single, that neither run of the certification measured. One mean under `A(x * w)` would
also be two precisions at once: its numerator's product formed at the wide type and its
denominator's weights, `A(w)`, rounded into `A` first.

`segmented_sum`, `pairwise_sum` and `area_fraction_above` already convert each element
to `A` before adding, and a weighted mean's denominator already converts each weight to
`A` before adding. This decision states the same rule for a term with a product in it.

## Alternatives considered

- **`A(x * w)`, the product at the operands' promoted type.** It is the chain a
  materialised `xs .* weights` array followed by a plain summation in `A` produced, and
  it was the fused kernels' expression. Lost on all three arguments above: the precision
  of a term becomes a property of the caller's arrays, a double reduction over single
  fields carries a single rounding per term, and a `Float32` call over double inputs is a
  computation the certification never ran. The materialised identity survives in the
  form `A.(xs) .* A.(weights)`, which is the same array whenever the inputs are already of
  type `A`.
- **The product at the widest of `A` and the two operand types, converted to `A`.** The
  most accurate of the three at every mix: exact when `A` is wider, one rounding at the
  wide type and one narrowing when `A` is narrower. Lost because its extra accuracy is
  confined to a narrow accumulator over wide inputs, which is precision the call did not
  declare, and there it reproduces the third computation the certification never ran. Its
  definition also has two cases where this one has none.
- **Refuse a mixed-type call.** Leaves nothing to define. Lost because `Fields.coarsen`
  calls `segmented_mean` at the field's element type with the measure's values as
  weights, and a `Float32` field over a `Float64` mesh geometry is a configuration
  decision 0011 anticipates rather than an error.

## Consequences

- `Reductions.segmented_weighted_sum_kernel!` and `Reductions.segmented_mean_kernel!`
  accumulate `nofuse_mul(T(xs[j]), T(weights[j]))`. On inputs already of type `A` the
  expression is the one they had, and no result moves; on mixed inputs the result moves to
  this definition on both backends.
- `Reductions.segmented_weighted_sum_reference` is the naive reference beside
  `segmented_weighted_sum`, and `segmented_mean_reference` keeps its
  `A(xs[j]) * A(weights[j])`.
- `test/reductions/mixed_precision.jl` holds each kernel bitwise to its reference at every
  mix of `Float32` and `Float64` elements, weights and accumulator on both backends, holds
  a single-term segment to its product computed at 256 bits, and carries the other order
  as a positive control that differs at every mix where the two orders do.
- A reduction added later that forms a term from more than one input converts each input
  to `A` before the term's first operation.
- A wider multiply is paid on the device by a double reduction over single inputs. No
  measured cost would change this decision, because the argument is about what the result
  is; the bench cases measure the unmixed `Float64` case.

## References

- Decision 0011, section "Mixed precision by declaration": the type parameter end to end,
  and reductions accumulated in double precision independently of the profile's type.
- Decision 0027: the naive reference path and its agreement with the kernel.
- Decision 0029 and `repro.fp32_kernel_certification` in `docs/oracles/registry.toml`:
  the `Float32` instance is certified against its own `Float64` run;
  `Backends.certification` in `src/Backends/certify.jl` narrows the fields to `Float32`
  before the first step.
- Decision 0044: `Backends.nofuse_mul` for a product rounded on its own, and the naive
  reference left unfused.
- IEEE Std 754-2019, "IEEE Standard for Floating-Point Arithmetic", clause 3.6
  "Interchange format parameters", Table 3.5 "Binary interchange format parameters", row
  "p, precision in bits": binary32 has `p = 24` and binary64 has `p = 53`, so the exact
  product of two binary32 values has at most 48 significant bits and is representable in
  binary64.
  `references/pdf/ieee2019-standard-floating-point-arithmetic-754.pdf`.
  DOI: 10.1109/IEEESTD.2019.8766229.
