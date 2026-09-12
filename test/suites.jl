# What a suite is, for both doors that run them: `test/runtests.jl`, which runs them
# in one process in order, and `tools/gate/run.jl`, which runs them as concurrent
# processes. One definition, so a suite cannot exist for one door and not the other.

const NOT_A_SUITE = ("fixtures",)

"""
    suites(root)

The suite names under `root` and the directories that are not suites, as
`(found, missing)`. A directory is a suite when it holds a `runtests.jl`; a
directory named in `NOT_A_SUITE` holds inputs and is skipped. Names come back in
`sort` order, so both doors see the same list in the same order.
"""
function suites(root::AbstractString)
    found = String[]
    missing = String[]
    for name in sort(readdir(root))
        name in NOT_A_SUITE && continue
        dir = joinpath(root, name)
        isdir(dir) || continue
        entry = joinpath(dir, "runtests.jl")
        push!(isfile(entry) ? found : missing, name)
    end
    return found, missing
end
