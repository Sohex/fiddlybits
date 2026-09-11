# The benchmark bed. Decision 0029 makes a benchmark a failing test, and a bar is
# applied only after the bed's own A/A scatter is measured, so the bed measures
# before it judges. No case is registered yet.

using Fiddlybits

const CASES = ()

function main()
    isempty(CASES) && return println("no benchmark case is registered")
end

abspath(PROGRAM_FILE) == @__FILE__ && main()
