# The depot every `julia` the gate, the nightly bed and the answers: rule start writes its
# package images into: a directory owned by the source tree being compiled, placed ahead
# of the depots the starting process reads.
# notes/findings/2026-09-13-concurrent-checkouts-evict-each-others-package-image.md has
# the failure this replaces and the alternatives weighed.

"The name of a tree's own depot directory."
const DEPOT_NAME = "julia-depot"

"""
    depot_path(depot; inherited)

The value of `JULIA_DEPOT_PATH` for a process that compiles into `depot`: `depot`, then
every entry of `inherited` other than `depot`, in order, joined by `:`.
"""
depot_path(depot::AbstractString; inherited::Vector{String} = DEPOT_PATH) =
    join([depot; filter(!=(depot), inherited)], ':')

"""
    in_depot(cmd, depot; inherited)

`cmd` with `JULIA_DEPOT_PATH` set to `depot_path(depot; inherited)`.
"""
in_depot(cmd::Cmd, depot::AbstractString; inherited::Vector{String} = DEPOT_PATH) =
    addenv(cmd, "JULIA_DEPOT_PATH" => depot_path(depot; inherited = inherited))
