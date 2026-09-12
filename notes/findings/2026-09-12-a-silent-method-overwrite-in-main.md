# Julia 1.12.7 overwrites a method redefined in Main without saying anything, so the warning rows 52v.1.11 and 52v.1.13 were written around no longer fires

Measured on 2026-09-12 on yggdrasil through `qrun` with this repository's defaults,
Julia 1.12.7, on `1b2d0be`. The rows are `fiddlybits-52v.1.11` and
`fiddlybits-52v.1.13`, which both quote the warning as the symptom.

## What was measured

Both rows quote, as the thing a run prints:

```
WARNING: Method definition closed_set(Type, Any) in module Main at
test/events/runtests.jl:15 overwritten at test/verdicts/runtests.jl:15.
```

Loading the two suites into one process, which is what `test/runtests.jl` does:

```
julia --startup-file=no --project \
  -e 'include("test/events/runtests.jl"); include("test/verdicts/runtests.jl")'
```

prints no such line, and no other warning but CUDA.jl's note about a non-official
Julia build. The same holds for a reduced pair that defines a function in `Main`,
calls it, and then redefines it from a second file: the second definition is the one
that answers afterwards, and stderr is empty. That reduced pair is
`test/build/fixtures/shared_helper/inline_a.jl` and `inline_b.jl`, asserted by
`build.one_definition_per_helper`.

A module, unlike a method, is not replaced in silence: a second unguarded `include`
of a file defining `module SharedFixtureHelper` rebinds the name to a new module
object and Julia writes `ignoring conflicting import` to stderr for the names a
`using` then brings in.

## What follows

The defect the two rows describe is real and is worse than they say. The collision is
not a warning nobody reads in a passing run; on this Julia there is nothing to read.
A change to one suite's copy of a shared helper would change the other suite's
behaviour with no output at all, and the only reason nothing was wrong is that the
copies were identical byte for byte.

One redefinition is not silent. A name brought into `Main` by `using` and then
defined there raises, rather than taking the name:

```
ERROR: invalid method definition in Main: function VocabularyClosure.closed_set must
be explicitly imported to be extended
```

So the acceptance criterion both rows lead with, that a run prints no
method-overwritten warning, was already true before any work and cannot decide
either row. `fiddlybits-52v.1.11` records what replaced it.
