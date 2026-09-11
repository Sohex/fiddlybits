# The answers: rule of decision 0029. The verdict is a function of four strings, so it
# is decided by a test rather than by reading the shell that gathers them.
#
#   julia --project tools/gate/answers.jl <path-to-commit-message>

module Answers

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

read_index(path) = try read(`git show $(":" * path)`, String) catch; "" end
read_head(path) = try read(`git show $("HEAD:" * path)`, String) catch; "" end

function main(args)
    if isempty(args)
        println(stderr, "usage: answers.jl <commit-message-file>")
        return 2
    end
    record = "bench/reference.toml"
    computed = get(ENV, "FB_REFERENCE_HASH") do
        chomp(read(`julia --startup-file=no --project=. tools/gate/reference.jl`, String))
    end
    staged = hash_of(read_index(record))
    head = hash_of(read_head(record))
    message = read(args[1], String)
    v = verdict(; computed, staged, head, message)
    v === :ok && return 0
    println(stderr, explain(v; computed, staged, head))
    return 1
end

end # module Answers

(abspath(PROGRAM_FILE) == @__FILE__) && exit(Answers.main(ARGS))
