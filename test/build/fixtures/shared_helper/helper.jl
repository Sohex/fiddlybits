# Stands in for test/closure.jl: a helper in a module of its own, reached by more
# than one door. Nothing here is under test; what is under test is what happens to
# it when a second door loads it.

module SharedFixtureHelper
answer() = :shared
end
