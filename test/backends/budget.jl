using Test
using Fiddlybits: Backends, Verdicts

# The memory budget computed from a field declaration: docs/plans/
# fiddlybits-52v.7-kernels.md, section "The budget".

@testset "budget computes bytes exactly from declared element types and extents" begin
    declarations = [
        ("field_a", Float32, 100),
        ("field_b", Float64, 50),
        ("field_c", Int32, 200),
    ]

    # Expected: 4*100 + 8*50 + 4*200 = 400 + 400 + 800 = 1600
    expected_bytes = sizeof(Float32) * 100 + sizeof(Float64) * 50 + sizeof(Int32) * 200
    @test Backends.budget(declarations) == expected_bytes
    @test Backends.budget(declarations) == 1600
end

@testset "refuse_over accepts budget within ceiling" begin
    declarations = [
        ("field_a", Float32, 100),
        ("field_b", Float64, 50),
    ]

    estimated_bytes = Backends.budget(declarations)
    # Should not throw when ceiling is at or above the estimate
    @test_nowarn Backends.refuse_over(declarations, estimated_bytes)
    @test_nowarn Backends.refuse_over(declarations, estimated_bytes + 1000)
end

@testset "refuse_over names fields in descending size with byte counts when rejecting" begin
    declarations = [
        ("small_field", Float32, 10),
        ("large_field", Float64, 100),
        ("medium_field", Int32, 50),
    ]

    estimated_bytes = Backends.budget(declarations)

    # Sizes: large_field = 8*100 = 800; medium_field = 4*50 = 200; small_field = 4*10 = 40
    # Expected order: large_field, medium_field, small_field

    # Positive control: ceiling one byte below estimate must refuse
    refusal_ceiling = estimated_bytes - 1
    @test_throws Verdicts.Refusal Backends.refuse_over(declarations, refusal_ceiling)

    try
        Backends.refuse_over(declarations, refusal_ceiling)
    catch err
        @test err isa Verdicts.Refusal
        @test occursin("large_field", err.reason)
        @test occursin("medium_field", err.reason)
        @test occursin("small_field", err.reason)

        # Verify byte counts are included
        @test occursin("800 bytes", err.reason)
        @test occursin("200 bytes", err.reason)
        @test occursin("40 bytes", err.reason)

        # Verify the order: large_field should appear before medium_field before small_field
        pos_large = findfirst("large_field", err.reason)
        pos_medium = findfirst("medium_field", err.reason)
        pos_small = findfirst("small_field", err.reason)
        @test pos_large < pos_medium < pos_small
    end
end

@testset "refuse_over message includes budget and ceiling" begin
    declarations = [
        ("field_a", Float32, 100),
    ]

    estimated_bytes = Backends.budget(declarations)
    refusal_ceiling = estimated_bytes - 1

    try
        Backends.refuse_over(declarations, refusal_ceiling)
    catch err
        @test err isa Verdicts.Refusal
        @test occursin(string(estimated_bytes), err.reason)
        @test occursin(string(refusal_ceiling), err.reason)
    end
end

@testset "budget is exact sum of individual field sizes" begin
    # Multiple test cases with different types and extents
    test_cases = [
        ([("a", Float32, 1), ("b", Float64, 1)], sizeof(Float32) + sizeof(Float64)),
        ([("x", Int8, 1000)], sizeof(Int8) * 1000),
        ([("p", Float32, 0), ("q", Float64, 0)], 0),
        ([("m", UInt32, 5), ("n", UInt64, 3)], sizeof(UInt32) * 5 + sizeof(UInt64) * 3),
    ]

    for (decls, expected) in test_cases
        @test Backends.budget(decls) == expected
    end
end

@testset "budget refuses negative extent: positive control fires" begin
    # Negative extent cancels a real field and buys false headroom
    @test_throws Verdicts.Refusal Backends.budget([("field", Float64, -1000)])

    try
        Backends.budget([("field", Float64, -1000)])
    catch err
        @test err isa Verdicts.Refusal
        @test occursin("field", err.reason)
        @test occursin("-1000", err.reason)
        @test occursin("non-negative", err.reason)
    end

    # Positive control: valid declaration of same shape does not refuse
    @test_nowarn Backends.budget([("field", Float64, 1000)])
    @test Backends.budget([("field", Float64, 1000)]) == 8000
end

@testset "budget refuses when extent is negative and another field is valid" begin
    # Negative extent anywhere in the declaration must refuse before checking
    @test_throws Verdicts.Refusal Backends.budget([
        ("field_a", Float64, 1000),
        ("field_b", Float64, -2000),
    ])

    try
        Backends.budget([
            ("field_a", Float64, 1000),
            ("field_b", Float64, -2000),
        ])
    catch err
        @test err isa Verdicts.Refusal
        @test occursin("field_b", err.reason)
        @test occursin("-2000", err.reason)
    end

    # Positive control: all valid extents do not refuse
    @test_nowarn Backends.budget([
        ("field_a", Float64, 1000),
        ("field_b", Float64, 2000),
    ])
end
