using Test

# build.load_latency. The entry is provisional with no registered threshold, so this
# measures and reports and does not judge. Decision 0029 fixes a bar only once the
# A/A scatter of the measurement is a dated finding, and a bar narrower than its
# instrument's scatter is refused at registration.
#
# The load is recorded beside the timing because the scheduler gives a job its cores,
# not the memory bandwidth around them.

const ROOT = normpath(joinpath(@__DIR__, "..", ".."))
const REPEATS = 5

"Wall time of `using Fiddlybits` in a fresh process, in milliseconds, `REPEATS` times."
function load_times()
    code = "t = @elapsed using Fiddlybits; print(t * 1000)"
    return [parse(Float64, read(`julia --startup-file=no --project=$ROOT -e $code`, String))
            for _ in 1:REPEATS]
end

host() = try chomp(read(`hostname`, String)) catch; "unknown" end
load1() = try parse(Float64, split(read("/proc/loadavg", String))[1]) catch; NaN end

@testset "build.load_latency" begin
    times = load_times()
    warm = times[2:end]

    @info "build.load_latency" host = host() load = load1() first_ms = round(times[1], digits = 1) warm_ms = round.(warm, digits = 1) spread_ms = round(maximum(warm) - minimum(warm), digits = 1)

    # The measurement happened and is a measurement. No bar: the entry is provisional.
    @test length(times) == REPEATS
    @test all(isfinite, times)
    @test all(>(0), times)
end
