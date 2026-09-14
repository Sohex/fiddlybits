# JET.jl

**What it is.** A static analyser that runs the compiler's abstract interpreter over a
call signature or a method instance and reports what it infers can go wrong. Its error
mode, `report_call`, reports a call no method matches, an undefined global and a
non-boolean condition. Its optimisation mode, `report_opt`, reports a call dispatched at
runtime, a captured variable that is boxed and an optimisation that failed.

**What of it is used.** In `test/fields/static_pass.jl` only, in a process of its own that
the nightly bed starts: `report_call` on a `MethodInstance` with `ignore_throws`,
`ignore_missing_comparison` and `target_modules`; `report_opt` on a zero-argument call with
`target_modules`; `get_reports`, `get_result`, `print_report_message`, `JET_AVAILABLE` and
`JET_DEV_MODE`. A report is read by its type's name and by its `vst` field. Not
`report_package`, not the `@test_call` family, not its printing or editor interfaces. It is
an `[extras]` entry of the `test` target; the package never loads it.

**Assumptions it carries.**

| assumption | present | how a leak is caught |
| --- | --- | --- |
| Earth defaults | none | n/a |
| calendar or time | none | n/a |
| grid or mesh | none | n/a |
| index base | none | n/a |
| precision | none | n/a |
| threading and GPU model | it analyses host inference; the device function `KernelAbstractions.@kernel` generates is compiled by the device compiler, and analysed at its declared signature it reports every index call inside it as a call no method matches | the pass leaves out exactly the methods `device_kernel` names and counts them in its result; its fixture holds one generated kernel that must be left out and one hand-written function named like one that must not |
| compiler internals | it reads the compiler's internal data structures, so a Julia version can move its findings with no change to this tree; on a Julia outside the range it supports it loads stubs, with a warning, that raise when called | the Julia and JET versions are written beside every result in the night's record; the pass refuses when `JET_AVAILABLE` is false |
| mutable global state | two preferences read at load, `JET_DEV_MODE` and `use_fixed_world`, from any `LocalPreferences.toml` on the load path; loading it loads Revise, which tracks the files of packages loaded after it | the pass refuses when `JET_DEV_MODE` is set; it runs in a process nothing else shares, in an environment built for the run |
| fail-open branches | `target_modules` keeps a report only when its innermost frame lies in the module named, so an error inside a dependency reached from this tree is not reported; `ignore_throws` drops what a `throw` raises; `report_opt` does not report inside a call that is not compileable; the error mode reports a call only when no method can match it, so a call on an abstract argument some method might accept is not reported | recorded here as the scope of the pass rather than caught; the fixture's four findings are the pass's positive controls and run before the tree every night |
| report identity | a report carries a line, and generated names carry counters, both of which move with an unrelated edit | a finding is named without its line and with the counters removed (`report_finding`), so two reports that differ only in line are one finding |

**How each leak is caught.** `test/fields/static_pass.jl` runs its controls on the fixture
every night before the tree and refuses when any comes out otherwise, and refuses a run on
a JET without its analyses or in development mode. `test/nightly/runtests.jl` asserts that
every `julia` the pass starts compiles into the checkout's depot and that the fields suite
does not include the pass.

**Licence.** MIT, as are Revise, JuliaInterpreter, LoweredCodeUtils, CodeTracking and
JuliaSyntax, which it brings. **Version.** 0.12.1, pinned in `Project.toml` compat; the
environment the pass runs in refuses to move a version `Manifest.toml` records.

**Checklist items applied.** A1, A2, A3, A6 clean negatives (an analyser, with no physical
constant, calendar or grid). B5 the three report filters, each with where it binds, above.
C3 every capability relied on (a call no method matches, a runtime dispatch, a return that
is not concrete, a generated device kernel) has a control in the pass. C4 the stubs on an
unsupported Julia and the report filters, above. C5 the two preferences, above.
