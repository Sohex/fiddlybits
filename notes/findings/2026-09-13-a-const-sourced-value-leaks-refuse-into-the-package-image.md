# A top-level `const Sourced(...)` value leaks `Verdicts.refuse` into the precompiled package image

Measured on 2026-09-13 on yggdrasil through `qrun`, Julia 1.12.7, on branch
`fiddlybits-52v.4.4`, working `src/EarthRatios/EarthRatios.jl` (row
`fiddlybits-52v.4.4`).

## What was measured

`test/gate/load_latency.jl`'s "the workload landed in the image" arm counts
`sum(m -> length(Base.specializations(m)), methods(Verdicts.refuse))` after a fresh
`using Fiddlybits`, and asserts it is zero: `Verdicts.refuse` is never called by the
declared `@compile_workload` block in `src/Fiddlybits.jl`, so a nonzero count means
some other code landed in the cached package image.

Before populating `EarthRatios`, this count was 0. Writing its four members as
`const GRAVITY_UNIT = Sourced(value = ..., dim = ..., locator = Locator(identifier =
..., table = ...))` (a `Dispositions.Locator` build, in turn calling
`Dispositions.Sourced`) raised it to 1: `Dispositions.Locator`'s inner constructor
carries `isempty(identifier) && refuse(...)` and `isempty(table) && refuse(...)`, and
building the four `Locator`s as a `const` at module scope runs that code while the
package is being precompiled, which is enough for the package image to carry a
compiled specialization of `refuse` for the call even though the refusal branch is
never taken. Rewriting the same four members as zero-argument functions
(`gravity_unit() = Sourced(...)`, called only from a caller's own call, never at
package load) returned the count to 0, with the same values as the `const` form on
a call.

## Where else this applies

Any future module that builds a `Dispositions.Sourced`, `Derived`, `Bracketed`,
`Irreducible` or `Closure` value as a top-level `const` rather than inside a
function will reproduce this, since every one of the five carries a refusal branch in
its inner constructor. `test/planets/` (`fiddlybits-52v.4.5`) already avoids it by
declaring `Earth()` as a constructor call rather than a top-level instance
(decision 0007: "Earth exists as a constructor call in a test file"); the same
pattern, a zero-argument function rather than a `const`, is what any future `Sourced`
et al. table needs to stay out of the image.
