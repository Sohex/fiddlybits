# FastPower loses eleven orders on every power it computes, and moves an adaptive step by a part in ten million

Measured on 2026-09-10 on yggdrasil, through `qrun -p build`, Julia 1.12.7,
`FastPower.jl` 1.5.0 at commit `674cbaaa414a5dc56d7b3207bd95d5f6422f0182` in
`/home/cfutro/git/SciML/FastPower.jl`. The reference is the same power at 200 bits.

`FastPower.fastpower` is a direct dependency of `OrdinaryDiffEqCore`. It computes `x^y`
as `exp2(Float32(y) * fastlog2(Float32(x)))` under `@fastmath`, where `fastlog2` is a
three-coefficient rational fit to the logarithm of the significand. Everything about it
is single precision, so its accuracy has nothing to do with the precision of its
arguments.

| argument range | fastpower, max relative error | rms | Julia's `^`, max |
|---|---|---|---|
| x in 1e-8 to 10, y in 0.1 to 0.5 | 4.36e-05 | 1.21e-05 | 1.07e-16 |
| x in 0.5 to 2, y in 0 to 4 | 3.13e-04 | 9.41e-05 | 1.09e-16 |
| x in 1 to 1000, y in 0 to 1 | 7.83e-05 | 2.27e-05 | 1.10e-16 |
| x in 1e2 to 1e6, y in 1 to 3 | 2.39e-04 | 8.54e-05 | 1.46e-16 |

Three to four correct digits, against sixteen. The package's own README says both: its
opening paragraph claims "approximately 10 digits of accuracy" and a later section says
it "loses about 12 digits of accuracy on Float64, so it's about 3-4 digits of accuracy".
The measurement agrees with the second.

## Where it is called, and what it moves

Grepping `OrdinaryDiffEqCore` for the symbol finds eight call sites and all eight are in
`src/integrators/controllers.jl`, in the proportional, proportional-integral and Gustafsson
step-size controllers, computing the step ratio from the error estimate. None is in a
state update. The survey's guess was right and is now a grep rather than a guess.

That placement makes it less bad and not harmless. The step ratio decides the next step
size, and the step size decides the state:

| error estimate | exponent | fastpower | exact | relative change in the step |
|---|---|---|---|---|
| 0.5 | 0.2 | 0.870550572872 | 0.870550563296 | 1.10e-08 |
| 1e-3 | 0.2 | 0.251188784838 | 0.251188643151 | 5.64e-07 |
| 1e-6 | 0.125 | 0.177827998996 | 0.177827941004 | 3.26e-07 |
| 2 | 0.25 | 1.189207077026 | 1.189207115003 | 3.19e-08 |

A part in ten million on the step size is nine orders above double-precision rounding. A
run with this power and a run without it take different steps and reach different states,
and the difference grows with the step count. Under decision 0029 that is an
answer-changing difference and not a tolerance.

## The `@fastmath` beside it

The implementation wraps its `exp2` in `@fastmath`, which sets the LLVM `nnan` and `ninf`
flags. `NonlinearSolveBase`'s `L2_NORM` carries a comment recording what that does in a
neighbouring package: `@fastmath` was removed from the termination check because those
flags let the optimiser constant-fold away the `isfinite`/`isnan` guard, so a diverged
solve was reported as converged. The same flags are in this function, three levels down a
dependency graph, on a value that decides a step size.

## What this changes

`docs/imports/fastpower-jl.md` excludes it. The lint suite gains a dependency-graph check:
no package in the manifest may list `FastPower` among its dependencies, direct or
transitive, which is a cheap grep of the resolved manifest and catches the hazard riding
in under a future adoption rather than under this one.
