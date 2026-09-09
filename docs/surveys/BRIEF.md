+++
epic = "fiddlybits-bon"
title = "The reference-tree triage: groups, method and output"
status = "filed"
date = 2026-09-09
+++

## What a surveyor does

For every repository in the group, in one pass: read enough to say what it is (the
README and the package's own summary is enough for most; the source only where a
verdict turns on it), decide whether it bears on anything this project has decided,
give it a verdict and a time.

Most repositories in a large organisation will be `not pertinent`, and saying so in one
clause is the point: a tree dismissed silently is a tree nobody can tell was examined.
The value of the survey is in the few that are not, and in the reasons attached to the
many that are.

## The record

One file per group, `docs/surveys/<group>.md`, with a TOML header carrying `epic`,
`title`, `trees` (the paths surveyed), `status` and `date`, then:

- A short prose opening: what this group of trees is, and the two or three findings a
  reader should take away.
- A table of every repository: `repo`, `what it is` (one clause), `bears on` (decision or
  requirement ids, or `-`), `verdict`, `when`.
- A section per repository that earned a verdict other than `not pertinent`, in prose:
  what specifically is worth reading, why it bears on the decision named, and what the
  closer look should answer. Name files and functions where they are known.
- A closing list of the rows the surveyor recommends, each with a title, the verdict it
  serves, and the milestone it is timed to.

## Rules

- Nothing is adopted, nothing is vendored, nothing is copied into this repository.
- A claim about what a tree does cites the file it came from where it matters.
- Timing is against decision 0034's build order. `now` is reserved for what bears on an
  open decision or on M0.
- Earth appears only as a comparison or as the thing a tree assumes.
- ASCII punctuation, no effort estimates, no current values in prose.

## Groups

| group | trees |
| --- | --- |
| gpu-and-arrays | CUDA.jl, KernelAbstractions.jl, GPUArrays.jl, AcceleratedKernels.jl, JuliaArrays, JuliaMath, JuliaLinearAlgebra, DimensionalData.jl, StaticCompiler.jl, Bumper.jl |
| mesh-and-discretisation | AlgebraicJulia, JuliaApproximation, WIAS-PDELib |
| dycores-and-frameworks | SpeedyWeather.jl, FourierFlows, ShallowWaters.jl, gaelforget, JuliaClimate |
| orbits-and-stellar | JuliaAstro, starry, Korg.jl, vplanet |
| terrain-ice-and-solvers | JuliaGeodynamics, ParallelStencil.jl, ImplicitGlobalGrid.jl, ODINN-SciML, fastflow, whitebox_next_gen, PATHSolver.jl |
| biogeochemistry-and-conceptual | PALEOtoolkit, JuliaOcean, OceanBioME, JuliaDynamics, CellularPotts.jl, Mimi.jl |
| sciml | SciML |

CliMA is surveyed already, in `docs/imports/` and decision 0012, and is not repeated here.
