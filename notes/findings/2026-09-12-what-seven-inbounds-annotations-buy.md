# The seven @inbounds annotations in src/Mesh bought nothing measurable, and 96 per cent of what --check-bounds=yes costs is re-checking dependencies rather than this tree

Measured on 2026-09-12 on yggdrasil through `qrun` with this repository's defaults
(profile `gpu-share`, one share of an NVIDIA GeForce RTX 4090, 8 CPUs, 16G), Julia
1.12.7, on branch `fiddlybits-52v.1.16` cut from `428fc6b`. The row is
`fiddlybits-52v.1.16`. `certify` and `mesh` were run alone at eight threads rather
than under the gate, so the numbers are not contended by thirteen other suites.

`notes/findings/2026-09-12-what-the-gate-pays-for-each-of-pkg-test-s-flags.md`
measured that `--check-bounds=yes` costs the gate a factor of 2.2 and that essentially
all of it is `certify`. It did not separate two different things inside that number:
the checks the flag restores at this tree's own seven `@inbounds` sites, and the
checks it restores inside every dependency, because the flag overrides `@inbounds`
throughout the call graph and Base, StaticArrays and CUDA use it heavily.

## The three configurations

| configuration | certify | mesh |
|---|---|---|
| as tracked, checks elided at the seven sites | 70.2 s (4 runs, 65.7 to 74.3) | 7.5 s |
| the seven removed, nothing else changed | 70.8 s (3 runs, 69.8 to 71.4) | 7.4 s |
| as tracked, `--check-bounds=yes` | 169.3 s | 9.0 s |

The first two distributions overlap completely: the second's mean is 0.6 s above the
first's, inside the first's own 8.6 s spread. **The seven annotations buy nothing that
can be measured on this bed.**

Of the 99.1 s that `--check-bounds=yes` adds to `certify`, at most 0.6 s is
attributable to this tree's own annotations. The remaining 98.5 s, 96 per cent of it,
is bounds checking inside code this repository does not maintain.

## Where the seven were

All in `src/Mesh`. Three of them were unchecked writes in the refinement loop:

```julia
@inbounds vertices[1, idx] = mx
@inbounds vertices[2, idx] = my
@inbounds vertices[3, idx] = mz
```

`idx` comes from a running counter, so an error in the vertex-count formula for some
refinement level would have written past the end of the array: not a wrong number but
memory corruption, surfacing somewhere unrelated or not at all. The other four were
reads taking a caller-supplied index, in `column` and `midpoint`, so the exposure was
not confined to one function's own arithmetic.

Nothing in the tree argued for them. No decision record mentions them, and the
docstrings on those functions justify the static vectors and the tuple returns, which
are about allocation, and never the elided checks.

## What follows

The seven are removed. The shipped form of this tree is now bounds-checked at those
sites, on every run and not only under a test flag, which is a stronger position than
either door could give: `--check-bounds=yes` only ever protected the configuration it
ran in.

What `--check-bounds=yes` still buys is the 96 per cent: checks inside Base,
StaticArrays and CUDA. That is worth having and is worth much less per second than
checks in code being written here, which is why it sits on the nightly bed of
decision 0043 rather than on the per-commit gate. Decision 0050 records the placement.
