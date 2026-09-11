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
| mutable global state | a per-package preference read at load time turns the workload off; the value is stored in `LocalPreferences.toml` | `LocalPreferences.toml` is not tracked and the load measurement is taken with no preferences file present, which `build.load_latency` records beside its number |
| fail-open branches | a workload that throws is reported as a warning and the precompile continues | the workload is empty of anything that can throw; the load-time measurement is the check that the cache exists |

**Licence.** MIT. **Version.** 1.3.4, pinned in `Project.toml` compat.

**Checklist items applied.** A1, A2, A3, A6 clean negatives (two macros, no
constants). C4 the warning-not-error on a throwing workload, recorded above. C5
the preference switch, recorded above.
