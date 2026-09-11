# The load instrument repeats to a part in a hundred, and a busy memory system moves it by three fifths

Measured on 2026-09-11 on yggdrasil, through `qrun`, Julia 1.12.7, Fiddlybits at commit
`d4e56587c935e86ac36bac2f2ce48d7a5d54ba22`. The instrument is the one
`test/gate/load_latency.jl` runs: one fresh process per sample, each reporting its own
`@elapsed using Fiddlybits`, so process startup is outside the number.

`build.load_latency` carries no threshold and an empty `registered_at`. Decision 0029
fixes a bar only once the A/A scatter of the measurement is known, because a bar
narrower than its instrument's scatter is refused at registration. This is that
scatter, and two reasons the bar stays unset beyond it.

## The A/A pair

Two arms differing in nothing, interleaved sample by sample so that drift in the host
falls on both. Twenty samples each, host load average 0.43 at the start and 0.60 at the
end, four CPUs reserved.

| arm | n | mean | median | sd | min | max |
| --- | --- | --- | --- | --- | --- | --- |
| A | 20 | 12.515 ms | 12.516 ms | 0.143 ms | 12.213 ms | 12.768 ms |
| B | 20 | 12.493 ms | 12.473 ms | 0.121 ms | 12.336 ms | 12.783 ms |
| both | 40 | 12.504 ms | | 0.131 ms | 12.213 ms | 12.783 ms |

| quantity | value |
| --- | --- |
| arm A mean less arm B mean | 0.022 ms |
| the same, as a fraction of arm A | 0.18 per cent |
| pooled sd over pooled mean | 1.05 per cent |
| full range over both arms | 0.57 ms, 4.56 per cent of the mean |

Two runs of the same thing agree in the mean to better than a part in five hundred, and
a single sample carries about one per cent. A bar on a single sample is refused below a
few per cent; a bar on the mean of twenty is refused below about a fifth of one per cent.

## The process around it

Bare process startup, wall time of `julia --startup-file=no --project=. -e "print(0)"`
measured from outside, over the same twenty rounds:

| n | mean | sd | min | max |
| --- | --- | --- | --- | --- |
| 20 | 90.4 ms | 1.3 ms | 88.2 ms | 93.9 ms |

The quantity measured is 0.138 of the startup that surrounds it. Timed from outside the
process instead, the reported number would be about 103 ms with the load one eighth of
it, and the startup's own sd of 1.3 ms is ten times the in-process scatter of 0.13 ms,
so the bar would sit mostly on Julia's startup. The in-process timer is not a
convenience here; it is the only arm that measures the thing named.

## The memory system beside it

The same instrument, twenty samples, against six neighbours inside the same eight-CPU
allocation, each a Julia process streaming a 256 MB array in a `@simd` loop. The
neighbours took no core the measurement needed; they took the bandwidth around it.

| arm | neighbours | load average | mean | sd | relative sd |
| --- | --- | --- | --- | --- | --- |
| quiet | 0 | 0.43 to 0.60 | 12.504 ms | 0.131 ms | 1.05 per cent |
| busy | 6 | 2.11 | 19.807 ms | 0.265 ms | 1.34 per cent |

The number rose by 7.30 ms, which is 58 per cent, while its own repeatability barely
moved. That rise is 12.8 times the full range of the quiet arm.

## What `using Fiddlybits` loads

Eighteen entries in `Base.loaded_modules` after the load, of which three are not in the
default system image: `Fiddlybits`, `PrecompileTools` and `Preferences`. None of CUDA,
KernelAbstractions, DynamicQuantities, Adapt, Zarr or NCDatasets is loaded. Each is a
declared dependency that no submodule reads yet. Fourteen of the sixteen submodules are
a module declaration and nothing else; `Verdicts` and `Orbit` hold the only code, and
neither reads a dependency outside the system image.

## What this changes

Two independent reasons `build.load_latency` keeps an empty `registered_at`, and only
the first of them ends when the areas merge.

- **The package is almost all empty declarations.** The number describes a load of
  three modules. The first area that reads a heavy dependency moves it by more than any bar
  set here, so a bar set now would be a bar on a package that no longer exists.
- **The bed does not hold the memory system still.** Under the scheduler a job owns its
  cores and not the bandwidth around them, and 58 per cent is 12.8 times the quiet
  range. A bar narrow enough to catch a package regression fires on a neighbour's
  array instead.

The gate records the host and the load beside every number, which is the half of this
that exists. The half that does not is a rule about what the recorded load licenses:
either it becomes a condition on the measurement rather than a note under it, or the
measurement moves to an arm the bed can hold quiet. That question is `fiddlybits-52v.1.8`.

The instrument itself needs no change. `REPEATS = 5` with the first sample dropped
costs nothing and no first-sample effect appeared in these conditions, with the depot
already warm from a suite run in the same allocation; that is a statement about these
conditions and not about a cold depot.
