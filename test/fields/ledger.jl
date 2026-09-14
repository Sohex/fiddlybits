using Test
using Random
using Fiddlybits: Fields, Reductions
using Fiddlybits.Verdicts: Refusal

# ledger.closure: docs/oracles/registry.toml and
# docs/plans/fiddlybits-52v.3-fields.md, section "Ledgers", row 52v.3.6.

const L = Fields

raised(thunk) = try
    thunk()
catch e
    e
end

@testset "Fields.Ledger" begin
    @testset "an exactly closing ledger has a zero residual and is closed" begin
        l = L.Ledger{:mass}(Float64, 3, 100.0, 100.0, 100.0, 0.0; reservoir = false)
        @test L.quantity(l) === :mass
        @test L.residual(l) == 0.0
        @test L.closed(l)
    end

    @testset "positive control: a residual larger than the tolerance is open" begin
        l = L.Ledger{:mass}(Float64, 3, 100.0, 100.0, 100.0, 0.5; reservoir = false)
        @test L.residual(l) == -0.5
        @test !L.closed(l)
    end

    @testset "named losses enter the residual with the opposite sign from flux" begin
        l = L.Ledger{:water}(Float64, 4, 20.0, 10.0, 9.0, 0.0, (evaporation = 1.0,);
                             reservoir = false)
        @test L.residual(l) == 0.0
        @test L.losses(l) == (evaporation = 1.0,)
        @test L.closed(l)

        under = L.Ledger{:water}(Float64, 4, 20.0, 10.0, 9.0, 0.0,
                                 (evaporation = 0.7,); reservoir = false)
        @test L.residual(under) ≈ -0.3
        @test !L.closed(under)
    end

    @testset "the tolerance is read from Reductions, not declared here" begin
        for (n, magnitude) in ((3, 10.0), (5, 1.0e6))
            l = L.Ledger{:energy}(Float64, n, magnitude, magnitude, magnitude, 0.0;
                                  reservoir = false)
            expected = Float64(Reductions.error_bound(Float64, n, magnitude))
            @test L.tolerance(l) == expected
        end

        small = L.Ledger{:energy}(Float64, 3, 10.0, 10.0, 10.0, 0.0; reservoir = false)
        large = L.Ledger{:energy}(Float64, 3, 1.0e6, 1.0e6, 1.0e6, 0.0;
                                  reservoir = false)
        @test L.tolerance(large) > L.tolerance(small)
        @test L.tolerance(large) == Float64(Reductions.error_bound(Float64, 3, 1.0e6))
    end

    @testset "an FP32 accumulator for a declared reservoir refuses naming the quantity" begin
        err = raised(() -> L.Ledger{:soil_carbon}(Float32, 3, 1.0f0, 1.0f0, 1.0f0,
                                                  0.0f0; reservoir = true))
        @test err isa Refusal
        @test err.site == "Fields.Ledger"
        @test occursin("soil_carbon", err.reason)
        @test occursin("reservoir", err.reason)
    end

    @testset "control: a non-reservoir at FP32 is accepted" begin
        l = L.Ledger{:surface_soil_moisture}(Float32, 3, 1.0f0, 1.0f0, 1.0f0, 0.0f0;
                                             reservoir = false)
        @test l isa L.Ledger{:surface_soil_moisture}
        @test L.closed(l)
    end

    @testset "a declared reservoir at Float64 is accepted" begin
        l = L.Ledger{:soil_carbon}(Float64, 3, 100.0, 100.0, 100.0, 0.0;
                                   reservoir = true)
        @test l isa L.Ledger{:soil_carbon}
    end

    @testset "every field returns a concrete type" begin
        @test @inferred(L.Ledger{:mass}(Float64, 3, 1.0, 1.0, 1.0, 0.0;
                                        reservoir = false)) isa L.Ledger{:mass}
        l = L.Ledger{:mass}(Float64, 3, 1.0, 1.0, 1.0, 0.0; reservoir = false)
        @test @inferred(L.closed(l)) isa Bool
        @test @inferred(L.residual(l)) isa Float64
        @test @inferred(L.tolerance(l)) isa Float64
        @test @inferred(L.quantity(l)) === :mass
    end

    @testset "the losses field is concretely typed" begin
        l = L.Ledger{:water}(Float64, 4, 20.0, 10.0, 9.0, 0.0, (evaporation = 1.0,);
                             reservoir = false)
        @test isconcretetype(fieldtype(typeof(l), :losses))
        @test isconcretetype(typeof(l))
    end
end

"""
    round2_classify(windows, residuals, tolerances)

The second-round `Fields.classify`, kept as a fixture: `Leak` when `round2_leak_signal`,
otherwise `Rounding` when the mean absolute residual is at most the mean tolerance and
the lag-1 autocorrelation `r1` of the first differences satisfies
`abs(r1 + 1/2) <= sqrt(n) / sqrt(n - 1)`, otherwise `StockOmission`.
"""
function round2_classify(windows, residuals, tolerances)
    round2_leak_signal(windows, residuals) && return L.Leak()
    n = length(residuals)
    d = diff(Float64.(residuals))
    m = length(d)
    dbar = sum(d) / m
    numerator = sum((d[i] - dbar) * (d[i + 1] - dbar) for i in 1:(m - 1))
    denominator = sum((di - dbar)^2 for di in d)
    r1 = denominator == 0 ? 0.0 : numerator / denominator
    band = sqrt(n) / sqrt(m)
    mean_residual = sum(abs, residuals) / n
    mean_tolerance = sum(tolerances) / n
    mean_residual <= mean_tolerance && abs(r1 + 0.5) <= band && return L.Rounding()
    return L.StockOmission()
end

"""
    round2_leak_signal(windows, residuals)

The second-round leak test: the least-squares slope's `t` statistic against
`sqrt(n^2 * df / (df - 2))`, `df = n - 2`, `false` at `df <= 2`.
"""
function round2_leak_signal(windows, residuals)
    x = Float64.(windows)
    y = Float64.(residuals)
    n = length(x)
    xm = sum(x) / n
    ym = sum(y) / n
    sxx = sum((xi - xm)^2 for xi in x)
    b = sum((x[i] - xm) * (y[i] - ym) for i in 1:n) / sxx
    a = ym - b * xm
    rss = sum((y[i] - a - b * x[i])^2 for i in 1:n)
    rss == 0 && return b != 0
    df = n - 2
    df > 2 || return false
    t = b / sqrt((rss / df) / sxx)
    return abs(t) > sqrt(n^2 * df / (df - 2))
end

"""
    binomial_critical_count(k, p, level)

The smallest count `c` with `P(X >= c) <= level` for `X ~ Binomial(k, p)`, computed
exactly over rational `p` and `level`.
"""
function binomial_critical_count(k::Integer, p::Rational, level::Rational)
    num = big(numerator(p))
    den = big(denominator(p))
    bound = Rational{BigInt}(level) * den^k
    tail = big(0)
    c = k + 1
    for j in k:-1:0
        term = binomial(big(k), j) * num^j * (den - num)^(k - j)
        tail + term <= bound || break
        tail += term
        c = j
    end
    return c
end

"`n` errors drawn uniformly within nine tenths of each tolerance of `tolerances`."
rounding_noise(rng, tolerances) = [0.9 * (2 * rand(rng) - 1) * t for t in tolerances]

"A `draw` for `Fields.classify`: each call the next `UInt64` of a `Xoshiro(seed)` stream."
stream_draw(seed) = let rng = Random.Xoshiro(seed)
    _ -> rand(rng, UInt64)
end

"Every ordering of `values`, by recursive swaps: the test's own reference enumeration."
function all_orderings(values)
    out = Vector{Vector{Int}}()
    work = collect(values)
    function visit(k)
        if k > length(work)
            push!(out, copy(work))
            return
        end
        for j in k:length(work)
            work[k], work[j] = work[j], work[k]
            visit(k + 1)
            work[k], work[j] = work[j], work[k]
        end
    end
    visit(1)
    return out
end

"The number of pairs `i < j` with `w[i] > w[j]`."
function inversions(w)
    k = 0
    for i in eachindex(w), j in (i + 1):lastindex(w)
        w[i] > w[j] && (k += 1)
    end
    return k
end

"Every composition of `n`: the ordered tuples of positive sizes summing to `n`."
compositions(n) = n == 0 ? [Int[]] :
    [vcat(first, rest) for first in 1:n for rest in compositions(n - first)]

@testset "Fields.classify" begin
    alpha = 1 // 100
    permutations = 10_000
    windows = [10.0, 30.0, 100.0, 200.0, 400.0, 700.0, 1000.0, 1200.0]
    tolerances = fill(1.0, length(windows))

    @testset "the review's two series are never Leak" begin
        review_windows = [10.0, 100.0, 500.0, 1200.0]
        review_tolerances = fill(1.0, 4)
        within = [-0.9, -0.5, 0.5, 0.9]
        offset = [4.1, 5.2, 4.7, 5.9]
        draw = stream_draw(1)

        err = raised(() -> L.classify(review_windows, within, review_tolerances;
                                      false_alarm = alpha, permutations, draw))
        @test err isa Refusal
        @test occursin("successive-difference", err.reason)
        @test occursin("at least 6 windows", err.reason)

        err = raised(() -> L.classify(review_windows, offset, review_tolerances;
                                      false_alarm = alpha, permutations, draw))
        @test err isa Refusal
        @test occursin("trend", err.reason)
        @test occursin("at least 6 windows", err.reason)

        admitting = 1 // 8
        @test L.exchangeable_minimum_length(admitting) == 4
        @test L.offset_minimum_length(admitting) == 4
        @test L.exchangeable_minimum_length(1 // 12) == 4
        @test L.exchangeable_minimum_length(1 // 13) == 5
        @test L.offset_minimum_length(1 // 9) == 5
        @test L.classify(review_windows, within, review_tolerances;
                         false_alarm = admitting, permutations, draw) == L.Unexplained()
        @test L.classify(review_windows, offset, review_tolerances;
                         false_alarm = admitting, permutations, draw) ==
              L.StockOmission()
    end

    @testset "a leak under one tolerance unit at the shortest window is Leak" begin
        rate = 0.5 / windows[1]
        for seed in (1, 2, 3)
            rng = Random.Xoshiro(seed)
            draw = stream_draw(seed)
            noise = 0.4 .* (2 .* rand(rng, length(windows)) .- 1)
            residuals = rate .* windows .+ noise
            @test abs(residuals[1]) < tolerances[1]
            @test L.classify(windows, residuals, tolerances; false_alarm = alpha,
                             permutations, draw) == L.Leak()
            @test L.classify(windows, noise, tolerances; false_alarm = alpha,
                             permutations, draw) != L.Leak()
        end
    end

    @testset "stock omissions carrying rounding noise are StockOmission" begin
        series = 200
        rng = Random.Xoshiro(20)
        draw = stream_draw(21)
        classes = [L.classify(windows, 5.0 .+ rounding_noise(rng, tolerances), tolerances;
                              false_alarm = alpha, permutations, draw) for _ in 1:series]
        @test all(c -> c in (L.StockOmission(), L.Leak(), L.Unexplained()), classes)
        @test count(!=(L.StockOmission()), classes) <
              binomial_critical_count(series, 2 * alpha, alpha)
        @test count(==(L.Leak()), classes) < binomial_critical_count(series, alpha, alpha)
    end

    @testset "random walks within the quantum are told apart from rounding" begin
        series = 200
        rng = Random.Xoshiro(30)
        draw = stream_draw(31)
        walks = map(1:series) do _
            walk = cumsum(randn(rng, length(windows)))
            0.9 .* walk ./ maximum(abs, walk)
        end
        @test all(w -> all(abs.(w) .<= tolerances), walks)
        new = [L.classify(windows, w, tolerances; false_alarm = alpha, permutations, draw)
               for w in walks]
        old = [round2_classify(windows, w, tolerances) for w in walks]
        @test all(c -> c in (L.Rounding(), L.Unexplained()), new)
        @test count(!=(L.Rounding()), new) >= binomial_critical_count(series, alpha, alpha)
        @test count(==(L.Rounding()), old) > count(==(L.Rounding()), new)
        @test any(i -> old[i] == L.Rounding() && new[i] != L.Rounding(), 1:series)
    end

    @testset "the false-alarm rate on rounding noise is at most the declared probability" begin
        series = 2000
        critical = binomial_critical_count(series, alpha, alpha)
        # enumerated: factorial(8) orderings do not exceed the declared count
        rng = Random.Xoshiro(40)
        draw = stream_draw(41)
        alarms = count(1:series) do _
            L.classify(windows, rounding_noise(rng, tolerances), tolerances;
                       false_alarm = alpha, permutations = factorial(8), draw) !=
            L.Rounding()
        end
        @test alarms < critical
        # random: a declared count below factorial(8)
        rng = Random.Xoshiro(50)
        draw = stream_draw(51)
        alarms = count(1:series) do _
            L.classify(windows, rounding_noise(rng, tolerances), tolerances;
                       false_alarm = alpha, permutations = 1000, draw) != L.Rounding()
        end
        @test alarms < critical
    end

    @testset "a series of 20 windows classifies" begin
        long_windows = collect(10.0:10.0:200.0)
        long_tolerances = fill(1.0, 20)
        rng = Random.Xoshiro(60)
        draw = stream_draw(61)
        leak = (0.5 / long_windows[1]) .* long_windows .+
               0.4 .* (2 .* rand(rng, 20) .- 1)
        @test L.classify(long_windows, leak, long_tolerances; false_alarm = alpha,
                         permutations, draw) == L.Leak()
        noise = rounding_noise(rng, long_tolerances)
        @test L.classify(long_windows, noise, long_tolerances; false_alarm = alpha,
                         permutations, draw) in (L.Rounding(), L.Unexplained())
        stock = 5.0 .+ rounding_noise(rng, long_tolerances)
        @test L.classify(long_windows, stock, long_tolerances; false_alarm = alpha,
                         permutations, draw) in L.residual_signatures()
    end

    @testset "zero residuals at zero tolerance are Rounding" begin
        zeros_n = zeros(length(windows))
        @test L.classify(windows, zeros_n, zeros_n; false_alarm = alpha, permutations,
                         draw = stream_draw(2)) == L.Rounding()
    end

    @testset "minimum lengths and permutation counts" begin
        draw = stream_draw(3)
        @test L.exchangeable_minimum_length(alpha) == 6
        @test L.offset_minimum_length(alpha) == 8
        @test L.random_permutation_minimum(alpha) == 100
        @test L.random_permutation_minimum(1 // 8) == 8
        @test L.random_permutation_minimum(0.3) == 4
        for n in 2:8
            @test L.count_at_least(L.trend_statistic, collect(1:n)) ==
                  (2, factorial(big(n)))
            @test L.trend_tail(collect(1:n)) == (2, factorial(big(n)))
            @test L.count_at_least(L.successive_difference_statistic, collect(1:n)) ==
                  (2, factorial(big(n)))
        end

        err = raised(() -> L.classify(windows[1:5], zeros(5), ones(5);
                                      false_alarm = alpha, permutations, draw))
        @test err isa Refusal
        @test occursin("successive-difference", err.reason)
        @test L.classify(windows[1:6], zeros(6), ones(6); false_alarm = alpha,
                         permutations, draw) == L.Rounding()

        err = raised(() -> L.classify(windows, zeros(8), ones(8); false_alarm = alpha,
                                      permutations = 99, draw))
        @test err isa Refusal
        @test occursin("successive-difference", err.reason)
        @test occursin("at least 100 random permutations", err.reason)
        @test L.classify(windows, zeros(8), ones(8); false_alarm = alpha,
                         permutations = 100, draw) == L.Rounding()

        unordered = [5.3, 4.8, 5.9, 4.6, 5.5, 5.0, 5.7]
        err = raised(() -> L.classify(windows[1:7], unordered, ones(7);
                                      false_alarm = alpha, permutations, draw))
        @test err isa Refusal
        @test occursin("offset", err.reason)
        @test occursin("at least 8 windows", err.reason)
    end

    @testset "inversion_counts matches enumeration for every tie structure up to 8" begin
        for n in 1:8, sizes in compositions(n)
            values = reduce(vcat, [fill(g, a) for (g, a) in enumerate(sizes)])
            histogram = zeros(BigInt, binomial(n, 2) + 1)
            for w in all_orderings(values)
                histogram[inversions(w) + 1] += 1
            end
            counts = L.inversion_counts(sizes)
            repeats = prod(factorial(big(a)) for a in sizes)
            padded = zeros(BigInt, length(histogram))
            padded[1:length(counts)] .= counts
            @test histogram == padded .* repeats
        end
    end

    @testset "trend_tail matches count_at_least with ties up to 7" begin
        rng = Random.Xoshiro(70)
        for n in 1:7, sizes in compositions(n)
            values = reduce(vcat, [fill(2g, a) for (g, a) in enumerate(sizes)])
            for arrangement in (values, reverse(values), Random.shuffle(rng, values))
                d, total = L.trend_tail(arrangement)
                de, te = L.count_at_least(L.trend_statistic, arrangement)
                @test d // total == de // te
            end
        end
    end

    @testset "q_binomial" begin
        @test L.q_binomial(4, 2) == BigInt[1, 1, 2, 1, 1]
        @test L.q_binomial(5, 0) == BigInt[1]
        @test L.q_binomial(5, 5) == BigInt[1]
        @test sum(L.q_binomial(10, 4)) == binomial(10, 4)
        @test raised(() -> L.q_binomial(3, 4)) isa Refusal
    end

    @testset "count_at_least visits every ordering once" begin
        orderings = [[a, b, c, d] for a in 1:4, b in 1:4, c in 1:4, d in 1:4
                     if allunique((a, b, c, d))]
        code(v) = foldl((acc, x) -> 10 * acc + x, v; init = 0)
        ds = [L.count_at_least(code, o)[1] for o in orderings]
        @test sort(ds) == collect(1:24)
    end

    @testset "uniform_index reads words from an accepted range divisible by i" begin
        for i in 1:12
            m = UInt64(i)
            lowest = (typemax(UInt64) - m + 1) % m
            @test (UInt128(typemax(UInt64)) + 1 - lowest) % i == 0
        end
        words = UInt64[0, 1]
        @test L.uniform_index(c -> words[c], 0, 3) == (2, 2)
        @test L.uniform_index(c -> words[c + 1], 0, 3) == (2, 1)
    end

    @testset "shuffle_with_draws! reaches each ordering once over all index choices" begin
        n = 5
        top = typemax(UInt64)
        word_for(choice, i) = top - (((top % UInt64(i)) - UInt64(choice - 1) + UInt64(i)) %
                                     UInt64(i))
        reached = Set{Vector{Int}}()
        for choices in Iterators.product((1:i for i in n:-1:2)...)
            steps = collect(zip(choices, n:-1:2))
            work = collect(1:n)
            counter = L.shuffle_with_draws!(work, c -> word_for(steps[c]...), 0)
            @test counter == n - 1
            push!(reached, work)
        end
        @test length(reached) == factorial(n)
    end

    @testset "random_count_at_least counts the identity" begin
        @test L.random_count_at_least(L.successive_difference_statistic, collect(1:6), 1,
                                      stream_draw(4)) == 1
        @test L.random_count_at_least(L.successive_difference_statistic, fill(3, 6), 50,
                                      stream_draw(4)) == 50
    end

    @testset "binomial_upper_tail counts sign patterns" begin
        for n in 0:6, k in 0:(n + 1)
            patterns = count(p -> count_ones(p) >= k, 0:(2^n - 1))
            @test L.binomial_upper_tail(n, k) == patterns
        end
    end

    @testset "doubled_midranks" begin
        @test L.doubled_midranks([3.0, 1.0, 3.0, 2.0]) == [7, 2, 7, 4]
    end

    @testset "classify refuses malformed input and requires its keywords" begin
        draw = stream_draw(5)
        ok = (windows, zeros(8), ones(8))
        for bad in ((windows[1:7], zeros(8), ones(8)),
                    (reverse(windows), zeros(8), ones(8)),
                    (windows, [NaN; zeros(7)], ones(8)),
                    (windows, zeros(8), [-1.0; ones(7)]))
            err = raised(() -> L.classify(bad...; false_alarm = alpha, permutations, draw))
            @test err isa Refusal
            @test err.site == "Fields.classify"
        end
        for a in (0, 1, NaN, -0.5, 1.5)
            @test raised(() -> L.classify(ok...; false_alarm = a, permutations, draw)) isa
                  Refusal
        end
        @test raised(() -> L.classify(ok...; false_alarm = alpha, permutations = 0,
                                      draw)) isa Refusal
        @test raised(() -> L.classify(ok...; permutations, draw)) isa UndefKeywordError
        @test raised(() -> L.classify(ok...; false_alarm = alpha, draw)) isa
              UndefKeywordError
        @test raised(() -> L.classify(ok...; false_alarm = alpha, permutations)) isa
              UndefKeywordError
    end

    @testset "residual_signatures enumerates the closed set" begin
        @test L.residual_signatures() ==
              (L.Leak(), L.StockOmission(), L.Rounding(), L.Unexplained())
    end

    @testset "classify reads a series of ledgers" begin
        ledgers = [L.Ledger{:mass}(Float64, 8, 10.0, 10.0, 10.0, 0.0; reservoir = false)
                   for _ in windows]
        @test L.classify(ledgers, windows; false_alarm = alpha, permutations,
                         draw = stream_draw(6)) == L.Rounding()
    end

    @testset "classify infers a ResidualSignature" begin
        draw = stream_draw(7)
        keywords = (false_alarm = 0.01, permutations = 100, draw = draw)
        rt = Base.return_types(Core.kwcall,
                               (typeof(keywords), typeof(L.classify),
                                Vector{Float64}, Vector{Float64}, Vector{Float64}))
        @test length(rt) == 1
        @test rt[1] <: L.ResidualSignature
    end
end
