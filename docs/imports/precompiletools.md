# PrecompileTools.jl

**What it is.** Two macros, `@setup_workload` and `@compile_workload`, that run a
declared workload during package precompilation so its compiled methods are cached
in the package image; and a per-package switch that turns the workload off.

**What of it is used.** The two macros, in `src/Fiddlybits.jl`, around a workload
that is what a run actually does and that each area extends as it gains code.
Nothing else.

**Assumptions it carries.**

| assumption | present | how a leak is caught |
| --- | --- | --- |
| Earth defaults | none | n/a |
| calendar or time | none | n/a |
| grid or mesh | none | n/a |
| index base | none | n/a |
| precision | none; the workload's own literals are the project's | `test/lint/lint_literals.jl` runs over `src/Fiddlybits.jl` like any other source |
| threading and GPU model | the workload runs at precompile time on the host with no device; a workload that touches a device fails the precompile | the workload is kept device-free; a device-touching call in it is caught by the precompile itself, which refuses rather than skipping |
| mutable global state | two preferences turn the workload off, `precompile_workloads` under PrecompileTools itself and `precompile_workload` under the package being precompiled; both are stored in `LocalPreferences.toml` | `build.load_latency` refuses a preferences file that turns either switch off and records the preference state beside its number. Its clean fixture is a preferences file that turns neither off, so the check is shown to refuse the switch and not the file |
| fail-open branches | a workload that throws is reported as a warning and the precompile continues, leaving a cache with the calls after the throw missing from it | `build.load_latency` asserts the package image exists, with a package on the load path that nothing loads as its dirty arm, and asserts the workload landed in it: a method the workload calls carries a specialization on a fresh load and `Verdicts.refuse`, which it does not call, carries none. The second arm is what reads the warning nobody would otherwise read, and it holds as the workload grows |

**Licence.** MIT. **Version.** 1.3.4, pinned in `Project.toml` compat.

**Checklist items applied.** A1, A2, A3, A6 clean negatives (two macros, no
constants). C4 the warning-not-error on a throwing workload, recorded above. C5
the preference switch, recorded above.
