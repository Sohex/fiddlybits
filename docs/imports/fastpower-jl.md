# FastPower.jl

**What it is.** One function, `fastpower(x, y)`, computing an approximate `x^y` through a
single-precision logarithm: a three-coefficient rational fit to the logarithm of the
significand, multiplied by the exponent, exponentiated under `@fastmath`. Seventy-nine
lines, one runtime dependency, and six package extensions teaching the differentiation
frameworks how to differentiate through it.

**What of it is used.** Nothing, and the point of this record is that it stays that way.

**Licence.** MIT. **Version.** 1.5.0. **Read at.**
`674cbaaa414a5dc56d7b3207bd95d5f6422f0182`, committed 2026-09-07, in
`/home/cfutro/git/SciML/FastPower.jl`. Measured:
`notes/findings/2026-09-10-fastpower-accuracy.md`.

**Verdict.** Excluded, by a manifest check rather than by a call-site rule, because the
way it would enter this project is not by anyone calling it. It is a direct dependency of
`OrdinaryDiffEqCore`, and any future adoption from that organisation carries it silently.
There is no version of "pinned" or "certified" that helps: the function's accuracy is
three to four digits by construction, in single precision, whatever the caller's type,
and decision 0011's ulp-ensemble certification is a procedure for admitting a kernel whose
single-precision output stays inside its own double-precision envelope, not for admitting
a function that is single precision on the inside while presenting a double-precision
signature.

## The three options the row named, decided

**Certified.** Not available. Certification under decision 0029 compares a kernel's FP32
output against the ulp-ensemble envelope of its FP64 self. This function has no FP64 self:
`fastpower(x::Float64, y::Float64)` converts both arguments to Float32 before doing any
work. There is nothing to certify it against but the exact power, which it misses by
eleven orders.

**Pinned.** Not sufficient. Pinning a version fixes which approximation is used and leaves
the approximation in the answer. The measured effect is a part in ten million on an
adaptive step size, which is a different trajectory rather than a different rounding.

**Excluded.** The decision, with the mechanism named below, because exclusion by
discipline is not exclusion: nobody in this project would write `fastpower` by hand, and
that is not how it would arrive.

## The leak test

A manifest check in the lint suite (`fiddlybits-52v.1.3`): the resolved `Manifest.toml`
is read and the build refuses if `FastPower` appears anywhere in it, direct or transitive.
This is a different shape from the other lints, which read source; a dependency hazard is
caught in the dependency graph. The same check is the natural home for any other package
this project decides never to link, and its positive control is a test fixture manifest
that contains the name and must be refused.

## Assumptions it carries

**Earth defaults (A2, A3), calendar (A1), grid (A6).** Clean negatives. One function.

**Precision.** The whole record. The function is single precision internally and its
signature is not: `fastpower(::Float64, ::Float64)` returns a Float64 carrying four
correct digits. Nothing in the call site says so.

**Threading and GPU model.** None. The function is branch-light and would compile in a
kernel, which is a reason to name it here rather than to trust it.

**Mutable global state (C5).** None.

**Clamps and limiters (B5).** Two guards, on a zero base and on infinity to infinity.

**Comment against value (B4).** The README states two different accuracies for the same
function: "approximately 10 digits of accuracy" in its opening paragraph and "about 3-4
digits of accuracy" in a later section. The measurement supports the second. A reader who
reads only the first paragraph gets a number that is six orders wrong, which is the exact
failure mode the review method's rule about comments is aimed at.

**Declared against demonstrated (C3).** The speed claim is not examined here; this project
has no use for the function at any speed.

**Fail-open branches (C4).** The `@fastmath` on the `exp2`, which sets the LLVM `nnan` and
`ninf` flags. A neighbouring SciML package documents, in a code comment, that exactly
those flags let the optimiser delete an `isfinite` guard and report a diverged solve as
converged. Here they sit on a value that sets a step size.

## Checklist

| item | result |
| --- | --- |
| A1 day and year | clean negative |
| A2 planetary constant block | clean negative |
| A3 Earth literals | clean negative |
| A6 grid and index base | clean negative |
| B4 comment against value | the README contradicts itself on the accuracy, by six orders; the measurement settles it |
| B5 clamps and limiters | zero base and infinity guards |
| C1 use site of every constant | the three fit coefficients, read at the only site that uses them |
| C3 declared against demonstrated | not examined; the package is excluded on accuracy alone |
| C4 fail-open branches | `@fastmath` on the exponential, the flag combination a sibling package documents as having silently deleted a divergence guard |
| C5 duplicate state and second constant sets | clean negative |
| D2 boundary field by field | two reals in, one real out, and the boundary is the whole problem: a double-precision signature over a single-precision computation |
| D4 conservation identity | not applicable; the identity run instead is the power against a 200-bit reference, in the finding |

## References

- The measurements: `notes/findings/2026-09-10-fastpower-accuracy.md`.
- The survey entries: `docs/surveys/sciml.md`, the `FastPower.jl` and `OrdinaryDiffEq.jl`
  closer looks; `docs/surveys/gpu-and-arrays.md` dismisses the unrelated `FastPow.jl`
  macro from JuliaMath for the same reason.
- Decision 0011 (precision by declaration; the ulp-ensemble certification), decision 0012
  (an import review for every dependency), decision 0029 (answer-changing commits).
- The row that carries the manifest check: `fiddlybits-52v.1.3`.
