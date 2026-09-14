# The answers: rule of decision 0029. The verdict is a function of four strings, so it
# is decided by a test rather than by reading the shell that gathers them.
#
#   julia --project tools/gate/answers.jl <path-to-commit-message>

module Answers

include(joinpath(@__DIR__, "depot.jl"))

"""
    verdict(; computed, staged, head, message)

One of:

  `:ok`                  nothing to refuse
  `:no_hash`             the staged record carries no hash
  `:stale_record`        the staged record disagrees with what the staged code produces
  `:undeclared_change`   the record moved and the message carries no mechanism line

`head` is empty when the record is new in this commit, which is not a change to declare.
"""
function verdict(; computed::AbstractString, staged::AbstractString,
                   head::AbstractString, message::AbstractString)
    isempty(staged) && return :no_hash
    computed == staged || return :stale_record
    isempty(head) && return :ok
    head == staged && return :ok
    return occursin(r"(?m)^answers: \S", message) ? :ok : :undeclared_change
end

"What to print for a verdict, with the hashes that decided it."
function explain(v::Symbol; computed, staged, head)
    v === :no_hash && return "gate: bench/reference.toml carries no hash; commit refused"
    v === :stale_record && return string(
        "gate: the reference record does not match what this commit's code produces.\n",
        "      recorded: ", staged, "\n",
        "      computed: ", computed, "\n",
        "      Update bench/reference.toml in this commit, and say what moved the answer.")
    v === :undeclared_change && return string(
        "gate: this commit moves the reference hash and carries no mechanism.\n",
        "      was: ", head, "\n",
        "      now: ", staged, "\n",
        "      Add a line to the commit message: answers: <what changed the answer>")
    return ""
end

"The hash a reference record carries, or an empty string."
function hash_of(text::AbstractString)
    m = match(r"(?m)^hash = \"([^\"]*)\"", text)
    return m === nothing ? "" : String(m.captures[1])
end

"""
    absent_path_failure(message)

Whether a failed `git show <rev>:<path>` failed because `path` is absent at `rev`,
recognised from the two families of message git writes for that case ("does not
exist ..." and "exists on disk, but not ..."). Any other message, including one from
a revision that does not resolve or a repository git cannot open, is not this.
"""
absent_path_failure(message::AbstractString) =
    occursin("does not exist", message) || occursin("exists on disk, but not", message)

"""
    at_revision(spec; dir)

The text `git show <spec>` writes, run in `dir` with `LC_ALL=C` and `LANGUAGE`
cleared, so the message `absent_path_failure` reads is always git's untranslated
English regardless of the caller's own locale. Returns an empty string when git
reports the named path absent there. Any other failure, including one where
`spec`'s revision itself does not resolve, throws rather than returning a value a
caller could read as "absent".
"""
function at_revision(spec::AbstractString; dir::AbstractString)
    out = IOBuffer()
    err = IOBuffer()
    cmd = addenv(Cmd(`git show $spec`; dir = dir), "LC_ALL" => "C", "LANGUAGE" => "")
    ok = success(pipeline(cmd; stdout = out, stderr = err))
    ok && return String(take!(out))
    message = String(take!(err))
    absent_path_failure(message) && return ""
    error("git show $spec failed in $dir:\n" * message)
end

read_index(path::AbstractString; dir::AbstractString) = at_revision(":" * path; dir = dir)
read_head(path::AbstractString; dir::AbstractString) = at_revision("HEAD:" * path; dir = dir)

"""
    staged_tree_hash(root, script)

Check out the git index at `root` into a fresh directory, run `script` (a path
relative to `root`) there with `julia --project=<the fresh directory>`, and return
its trimmed standard output. Every file the run reads, including `script` itself, is
the index's version, never the working tree's. The run compiles into a depot of its own,
`DEPOT_NAME` beside the checked-out files, through `in_depot`. The directory, and that
depot with it, is removed before returning, whether or not the run succeeded.
"""
function staged_tree_hash(root::AbstractString, script::AbstractString)
    tree = mktempdir()
    try
        checkout = addenv(Cmd(`git checkout-index -a --prefix=$(tree * "/")`; dir = root),
                           "LC_ALL" => "C", "LANGUAGE" => "")
        run(pipeline(checkout; stdout = devnull, stderr = devnull))
        cmd = in_depot(`julia --startup-file=no --project=$(tree) $(joinpath(tree, script))`,
                       joinpath(tree, DEPOT_NAME))
        return chomp(read(cmd, String))
    finally
        rm(tree; force = true, recursive = true)
    end
end

"""
    main(args; root)

The commit-msg entry point. `root` is the git worktree the commit is against and
defaults to the current directory, which is where the caller is expected to run
from. The reference hash comes from `staged_tree_hash`, never from `root`'s working
tree, unless `FB_REFERENCE_HASH` is set, in which case that value is used as is.
"""
function main(args; root::AbstractString = pwd())
    if isempty(args)
        println(stderr, "usage: answers.jl <commit-message-file>")
        return 2
    end
    record = "bench/reference.toml"
    computed = get(ENV, "FB_REFERENCE_HASH") do
        staged_tree_hash(root, joinpath("tools", "gate", "reference.jl"))
    end
    staged = hash_of(read_index(record; dir = root))
    head = hash_of(read_head(record; dir = root))
    message = read(args[1], String)
    v = verdict(; computed, staged, head, message)
    v === :ok && return 0
    println(stderr, explain(v; computed, staged, head))
    return 1
end

end # module Answers

(abspath(PROGRAM_FILE) == @__FILE__) && exit(Answers.main(ARGS))
