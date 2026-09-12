# Julia's method-overwrite warning is off unless --warn-overwrite=yes is passed, which Pkg.test does and the gate does not, so the duplicate closed_set was loud through one door and silent through the other

Measured on 2026-09-12 on yggdrasil through `qrun` with this repository's defaults,
Julia 1.12.7, on branch `fiddlybits-52v.1.14`. The rows are `fiddlybits-52v.1.11` and
`fiddlybits-52v.1.13`, which quote the warning as the symptom of the duplicate
definition.

**This record replaces an earlier version of itself that said the warning does not
exist on this Julia.** That was measured with a bare `julia -e`, which does not carry
the flag, and was wrong. It was merged in `de7ce56` and is corrected here.

## What was measured

The same two files, loaded in the same order, differ only by the flag:

```
julia --startup-file=no -e '<include inline_a.jl; answer(); include inline_b.jl>'
second

julia --startup-file=no --warn-overwrite=yes -e '<the same>'
WARNING: Method definition answer() in module Main at .../inline_a.jl:3
overwritten at .../inline_b.jl:1.
second
```

The two files are `test/build/fixtures/shared_helper/inline_a.jl` and `inline_b.jl`.
The call between the two includes is needed: the warning is raised where the earlier
method is replaced, not where the file is read.

`Pkg.test()` passes the flag. It prints the configuration it precompiles for at the
top of every run:

```
Precompiling for configuration --code-coverage=none --color=auto --check-bounds=yes
--warn-overwrite=yes --depwarn=yes --inline=yes --startup-file=no
--track-allocation=none
```

`tools/gate/run.jl` does not. Its `suite_command` builds
`julia --startup-file=no --project=<root> -t <threads> -e <include>`, so a suite run
as a process by the gate carries the default, which is off.

## What follows

Both rows were right that the suite printed the warning: through `Pkg.test()`, which
is the door `test/runtests.jl` serves, it did. Through the gate, which decision 0049
made the door every commit and every push goes through, it printed nothing, and the
gate is the door a session runs.

So the class of defect the two rows name is visible only on the slower door, and only
if someone runs it. That is a question about what flags the gate's processes carry,
which is `fiddlybits-52v.1.15`.

One redefinition is loud whatever the flag. A name brought into `Main` by `using` and
then defined there raises rather than taking the name:

```
ERROR: invalid method definition in Main: function VocabularyClosure.closed_set must
be explicitly imported to be extended
```

That is the door `test/closure.jl` puts every suite behind, and it is why the fix
does not rest on a warning being read.
