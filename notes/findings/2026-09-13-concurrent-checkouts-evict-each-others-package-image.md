# Concurrent checkouts evict each other's Fiddlybits package image from the shared depot, so a process that has chosen an image finds its shared object gone; every julia the gate starts now compiles into a depot under the checkout's own git directory

Measured on 2026-09-13 on yggdrasil, Julia 1.12.7 (`/usr/bin/julia`), on branch
`fiddlybits-52v.1.19`, with the fixture runs through `qrun -p light` and the gate through
`tools/gate/gate.sh`. The row is `fiddlybits-52v.1.19`.

## The failure

The gate on `main` at `6cb0936`, during a fan-out of executors in parallel worktrees, failed
`test/backends/thread_bitwise.jl:38`, whose child `julia` died with:

```
Error opening package file /home/cfutro/.julia/compiled/v1.12/Fiddlybits/H019n_0sJDu.so:
cannot open shared object file: No such file or directory
```

The backends suite passed when run alone. A pre-push hook gating a push at the same time
failed the same way, and one executor's gate saw one `build.load_latency` error that its
rerun did not repeat.

At 19:03 the same day `~/.julia/compiled/v1.12/Fiddlybits/` held exactly ten images
(`H019n_*.ji` with their `.so`), with eight checkouts of the repository live
(`git worktree list`). Ten is Julia's default bound.

## What Julia does, read from the source and documentation on disk

- `/usr/share/doc/julia/html/en/manual/environment-variables.html`, section
  `JULIA_MAX_NUM_PRECOMPILE_FILES`: "Sets the maximum number of different instances of a
  single package that are to be stored in the precompile cache (default = 10)."
  `/usr/share/julia/base/Base.jl` lines 383-385 read it into `MAX_NUM_PRECOMPILE_FILES`.
- The same page, section `JULIA_DEPOT_PATH`: the variable populates `DEPOT_PATH`, which
  controls where code loading looks for "cached compiled package images"; an empty entry
  at the end expands to the bundled depots excluding the user depot, and at the start to
  the default including it. `/usr/share/julia/base/initdefs.jl` `init_depot_path`, lines
  105-139, is that expansion.
- `/usr/share/doc/julia/html/en/base/base.html`, `Base.compilecache`: "Cache files are
  stored in `DEPOT_PATH[1]/compiled`."
- `/usr/share/julia/base/loading.jl`:
  - `compilecache_path`, lines 3230-3252: an image's file name is a slug of the active
    project's path, the Julia binary and image, the cache flags (which include
    `--check-bounds`), the CPU target and the preferences hash. Each checkout therefore has
    its own image name per configuration, and the gate warms two configurations per
    checkout (`tools/gate/run.jl` `warm_both`).
  - `compilecache`, lines 3269 and 3347-3365: after compiling, when the package's
    directory in `DEPOT_PATH[1]` already holds `MAX_NUM_PRECOMPILE_FILES` or more images,
    the one with the oldest modification time is removed, `.ji` then shared object. Only
    the writer's first depot is pruned.
  - `find_all_in_cache_path`, lines 1212-1262: candidate images are collected from every
    depot in `DEPOT_PATH` and tried newest first, whatever depot they are in.
  - `_require_search_from_serialized`, lines 2076-2183: a candidate `.ji` is checked, its
    modification time is touched (line 2157), every dependency not yet loaded is loaded
    and its `__init__` run (lines 2164-2177), and only then is the package's own shared
    object opened (line 2182). For Fiddlybits that interval holds the load of CUDA and the
    rest of its dependencies.
- The error text is the runtime's: `Error opening package file %s: %s` in
  `/usr/lib/julia/libjulia-internal.so.1.12.7`.

So with eight checkouts each needing two images, and `tools/gate/answers.jl` adding one
more for a fresh temporary project on every commit that stages source, every compile in
any checkout found the directory at its bound and removed the oldest image, which was
sometimes one another process had chosen and was still loading dependencies for.

## The reproduction, and how it forces the eviction

`test/gate/eviction.jl`, `gate.eviction_reproduction`. Nothing waits for a race. Two
checkouts of a fixture package `Evictee` with differing source, the main checkout of a
scratch repository and a `git worktree` of it, share a scratch depot standing in for
`~/.julia`, and read nothing from the user's depot. `Evictee` depends on `Gatekeeper`,
whose `__init__` touches a ready file and waits for a release file. The reader loads
`Evictee` in one checkout and is held inside the interval above. The writer then loads
`Evictee` from its own changed source in the other checkout under
`JULIA_MAX_NUM_PRECOMPILE_FILES=1`, the bound at which one existing image in the
directory is enough to be pruned: the rule is `length >= bound`, and the directory holds
one other image. Then the reader is released.

"The tooling before this row" is each command carrying the depots its parent read and
none of its own, which is what `suite_command`, `warm_command` and `probe_command` built.

| arm | reader | writer | repetitions | reader verdict |
| --- | --- | --- | --- | --- |
| the tooling before this row | inherited depots, warm-up `using` only | inherited depots | 1 | FAIL |
| checkout depot | `in_checkout`, `warm_code` | `in_checkout` | 2 | PASS, PASS |
| image of the reader's source already in the shared depot | `in_checkout`, warm-up `using` only | inherited depots | 1 | FAIL |
| the same | `in_checkout`, `warm_code` | inherited depots | 2 | PASS, PASS |

The two repetitions are the two ordered (reader, writer) pairs of the two checkouts, so each
git directory shape, `.git` and `.git/worktrees/<name>`, holds the depot in each role; the
forcing has no timing in it, so a repetition repeats the same sequence.

The first arm's reader, verbatim:

```
ERROR: Error opening package file /tmp/jl_5O0CAm/compiled/v1.12/Evictee/vUbkg_FuBGH.so:
/tmp/jl_5O0CAm/compiled/v1.12/Evictee/vUbkg_FuBGH.so: cannot open shared object file:
No such file or directory
```

with the shared directory holding `vUbkg_FuBGH.ji` before the writer and only
`vUbkg_8jxKk.ji` after it. In the checkout depot arm the reader's own depot held the same
image before and after the writer and the reader printed its own value. The test runs in
the `gate` suite; standalone it took 9.2 s for 34 assertions.

The third arm is the case a depot layered ahead of the shared one does not close by itself:
a session in the checkout that loaded the package without the rule leaves a valid image of
the checkout's source in the shared depot, a plain `using` in the warm-up loads that image
rather than compiling, every suite then chooses it, and any writer outside the rule can
prune it. `warm_code` checks where the loaded image came from
(`Base.pkgorigins[id].cachepath`) and, when it is not the first depot, compiles one there
with `Base.compilecache`; that image is then the newest and is chosen first.

## What changed

- `tools/gate/depot.jl`: `DEPOT_NAME`, `depot_path(depot; inherited)` and
  `in_depot(cmd, depot; inherited)`, one definition, included by `tools/gate/run.jl` and
  `tools/gate/answers.jl`.
- `tools/gate/run.jl`: `checkout_depot(root)` is `julia-depot` under
  `git rev-parse --absolute-git-dir`; `in_checkout` applies it; `suite_command`,
  `warm_command` and `probe_command` all pass through it; the warm-up runs
  `warm_code("Fiddlybits")`. Every child a suite starts inherits the variable.
- The nightly bed builds its commands only through those builders, and the pre-push hook
  runs only `tools/gate/gate.sh`; `gate.checkout_depot` checks, from the parsed source and
  the shell text with positive controls, that no door builds a `julia` outside the rule.
- `tools/gate/answers.jl`: the index checkout compiles into a depot inside its own
  temporary tree, removed with it, so a commit no longer leaves an image in the shared
  depot.

After the change the gate on this branch passed, 22 suites, 181.5 s wall, with both of
its warm-ups at 7.9 s, and left two Fiddlybits images, 14 MB in all, in
`.git/worktrees/fiddlybits-52v.1.19/julia-depot/compiled/v1.12/Fiddlybits/`.

## The alternatives weighed

- **A depot under the checkout's git directory, ahead of the shared one (chosen).** A
  writer prunes only its own first depot, so no checkout's compile can remove another's
  image; dependency images, packages and artifacts are still read from the shared depot,
  so only Fiddlybits is compiled per checkout, which each checkout's differing source
  already required. The directory lives in `.git/worktrees/<name>`, which
  `git worktree remove` deletes, so a removed worktree takes its images with it. Costs:
  one compile per checkout per configuration on its first gate, and the disk above.
- **A raised `JULIA_MAX_NUM_PRECOMPILE_FILES` derived from the fan-out.** The count to
  cover is checkouts times configurations, plus one image per commit that stages source
  from `answers.jl`, plus the images of every worktree already removed, which nothing
  deletes except pruning. That sum has no bound, so no derived value is enough, and any
  value above it stops pruning, which is an unbounded directory by another name. The bound
  is also applied by the writer, so every process that compiles Fiddlybits would have to
  carry it, including sessions and hooks that never pass through the gate; one without it
  prunes at ten.
- **A depot per checkout replacing the shared one** (`JULIA_DEPOT_PATH="<depot>:"`, which
  the documentation says drops the user depot). Complete isolation, and every dependency,
  CUDA included, compiled per checkout and per configuration on its first gate, against a
  pre-push hook bounded by the remote's idle timeout (decision 0049).
- **A depot per checkout keyed by path under `$XDG_CACHE_HOME`.** The same isolation as
  the chosen one, and nothing removes it when the worktree goes.
- **Serialising compiles across checkouts with a lock.** Not a mechanism the Julia
  documentation offers, and it makes every checkout's gate wait on every other's
  (decision 0038); it would also not stop a reader from being pruned by a writer outside
  the lock.
- **`--compiled-modules=existing` on the suites.** Stops a suite from writing, and a suite
  is not the writer that prunes; the reader stays exposed to every other writer.

## What stays open

- Dependency images in the shared depot are pruned by the same rule when a writer outside
  the rule compiles a new one of the same package, which follows a manifest change being
  compiled in another checkout. The gate reads those images and does not write them.
- A session loading the package without the rule in the same checkout while its gate runs
  touches the shared image, which makes it the newest and so the one later suites choose.
- The pre-commit hook's lint and build load runs outside the rule: `fiddlybits-52v.1.21`.
