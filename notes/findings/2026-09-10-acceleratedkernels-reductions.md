# AcceleratedKernels' reductions: the processor default answers by thread count, and the top declared block size drops half the data

Measured on 2026-09-10 on yggdrasil, through `qrun -p build` (16 CPUs, 16G) for the
processor path and `qrun -p gpu-share` (one share of the RTX 4090) for the device path,
nothing else on the machine, Julia 1.12.7, `AcceleratedKernels.jl` 0.4.3 at commit
`0287c81c3b4d06f90258cffee44de87325bcf069` in `/home/cfutro/git/`, with
`KernelAbstractions.jl` 0.9.42 and `CUDA.jl` 6.3.1.

The question is decision 0029's first sentence: thread-count invariance is a design
property, so a one-thread and a sixteen-thread run are bitwise identical. The survey read
`mapreduce_1d_cpu` and predicted the default would fail that. It does.

## What was run

Four million Float64 values from a deterministic linear congruential sequence, each scaled
by `exp(10 sin(i/1000))` so the summands span some nine decades and association order is
visible in the result. The sum is about -5.47e7. Every result is printed as the bit
pattern of the Float64, so the comparison carries no tolerance. The whole script is one
file and each configuration is a fresh process, differing only in `JULIA_NUM_THREADS`.

| reduction | 1 thread | 4 threads | 16 threads |
|---|---|---|---|
| `Base.sum` | `0xc18a1721def41159` | `0xc18a1721def41159` | `0xc18a1721def41159` |
| fixed-order pairwise, block 128 | `0xc18a1721def41158` | `0xc18a1721def41158` | `0xc18a1721def41158` |
| `AK.sum`, defaults | `0xc18a1721def4114a` | `0xc18a1721def411be` | `0xc18a1721def4117d` |
| `AK.reduce`, defaults | `0xc18a1721def4114a` | `0xc18a1721def411be` | `0xc18a1721def4117d` |
| `AK.mapreduce`, defaults | `0xc18a1721def4114a` | `0xc18a1721def411be` | `0xc18a1721def4117d` |
| `AK.reduce`, `max_tasks=1` | `0xc18a1721def4114a` | `0xc18a1721def4114a` | `0xc18a1721def4114a` |
| `AK.reduce`, `max_tasks=8` | `0xc18a1721def41164` | `0xc18a1721def41164` | `0xc18a1721def41164` |
| `AK.reduce`, `max_tasks=16` | `0xc18a1721def4117d` | `0xc18a1721def4117d` | `0xc18a1721def4117d` |
| `AK.reduce`, `max_tasks=64` | `0xc18a1721def41157` | `0xc18a1721def41157` | `0xc18a1721def41157` |
| `AK.reduce`, `min_elems` = length | `0xc18a1721def4114a` | `0xc18a1721def4114a` | `0xc18a1721def4114a` |

The default rows are the finding: three thread counts, three answers. The spread between
the extremes is 116 ulps, 8.6e-07 absolute and 1.6e-14 relative, which is unremarkable as
roundoff and disqualifying as an identity.

The positive control is the repeat. Three further sixteen-thread runs, in three fresh
processes, all returned `0xc18a1721def4117d`, so the difference tracks the thread count
and not the run. Without that control the table would be equally consistent with a
reduction that is simply non-deterministic, which would be a different defect with a
different fix.

The pinned rows are the answer. With `max_tasks` given explicitly the result is identical
at every thread count, so the package's own API is sufficient and no patch is needed.
`max_tasks=16` and sixteen threads agree, as they must: the default is
`max_tasks = Threads.nthreads()` and nothing else in the path depends on the thread count.
Note that the pinned value selects which answer, so `max_tasks` is part of the
definition of the reduction and not a performance knob: changing it changes the tree, and
the change is an answer-changing commit under decision 0029.

`min_elems` reaches the same place by another door. Setting it to the length of the input
forces a single task whatever `max_tasks` says, and gives the one-task answer. That is the
safer pin of the two for a reduction whose partition must not move, and the more wasteful.

`Base.sum` and the fixed-order pairwise sum differ from each other by one ulp and from
every AcceleratedKernels answer, which is the ordinary consequence of three different
association orders and is recorded here only so that no future comparison reads it as a
defect.

## On the device, repeats agree and the top declared block size is wrong

The device reduction takes its geometry from two explicit arguments, `block_size` and
`items_per_thread`, and derives the block count from the input length, so two launches of
the same call should agree bitwise. They do: three launches of the default
`AK.reduce(+, ::CuArray)` over the same four million values all returned
`0xc18a1721def41158`.

Sweeping the geometry found something else. Against a 300-bit sum of the same data, every
block size from 32 to 512 returns the right answer to roundoff, and `block_size=1024`
does not:

| length | block size | relative error at `items_per_thread=2` | at 8 |
|---|---|---|---|
| 1000 | 32 to 512 | 1.5e-15 or better | 2.7e-16 or better |
| 1000 | 1024 | 1.342e+00 | 1.342e+00 |
| 100000 | 32 to 512 | 1.5e-16 or better | 1.5e-16 or better |
| 100000 | 1024 | 5.030e-01 | 5.030e-01 |
| 4000000 | 32 to 512 | 8.3e-17 or better | 5.3e-17 or better |
| 4000000 | 1024 | 7.036e-01 | 4.974e-01 |

The positive control is a vector of ones, where the right answer is an integer and no
argument about association order can be made:

| length | block size 256 | 512 | 1024 |
|---|---|---|---|
| 1024 | 1024.0 | 1024.0 | 512.0 |
| 4096 | 4096.0 | 4096.0 | 2048.0 |
| 1000000 | 1000000.0 | 1000000.0 | 500224.0 |

Half the data is dropped, silently, with no error and no warning. The cause is one missing
rung. `reduce_group!` in `src/reduce/utilities.jl` folds the shared array by halves and
its ladder begins at `if N >= 512`, which pairs element 1 with element 257 and so on; there
is no `N >= 1024` rung, so when the block holds 1024 partial sums the upper 512 are never
added. `mapreduce_1d_gpu` admits the value explicitly, `@argcheck 1 <= block_size <= 1024`,
and the package's own reduction tests pass `block_size=64` and nothing above it, so the top
half of the declared range is untested and its endpoint is broken. This is an upstream
defect, not a configuration error here.

## What this changes

`docs/imports/acceleratedkernels-jl.md` carries the pin as a checklist item with the leak
test that catches a bare call. The reduction that decision 0029 says is written once in
the kernel library is a fixed-order pairwise tree of this project's own, not
`AK.reduce`: the pin makes the library's reduction invariant under thread count, and it
does not make its tree the tree the project declares. Where `AcceleratedKernels` is called
at all, `max_tasks` and `min_elems` are supplied at the call site and the values are part
of the recorded operator version, and `block_size` is pinned below the broken endpoint by
the same rule.

The wider lesson is the positive control. The block-size defect is invisible in a
floating-point comparison, where a wrong answer and a differently associated answer look
alike until one is checked against something that knows the truth. A vector of ones turns
a plausible number into an obvious one at no cost at all.
Decision 0027's mutation run asks for that property of every oracle, and this is what
its absence looks like in a library that is otherwise carefully written.
