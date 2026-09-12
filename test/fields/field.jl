using Test
using InteractiveUtils: subtypes
using Fiddlybits: Fields, Dimensions, Time, Mesh
using Fiddlybits.Verdicts: Refusal
using UUIDs: UUID

const OTHER_RUN = UUID("9b3c0000-0000-4000-8000-000000000001")

# The Field type, the closed Semantics vocabulary and Origin:
# docs/plans/fiddlybits-52v.3-fields.md, row 52v.3.2.

const F = Fields
const FX = FieldFixtures

@testset "Fields.field" begin
    @testset "the Semantics enumeration is complete and is decision 0006's set" begin
        declared = Set(F.semantics_types())
        present = Set(subtypes(F.Semantics))
        @test setdiff(present, declared) |> isempty
        @test setdiff(declared, present) |> isempty
        @test length(F.semantics_types()) == 8
        @test F.semantics_types() == (F.Extensive, F.Intensive, F.FluxDensity,
                                      F.Fraction, F.CategoricalLabel,
                                      F.CategoricalFraction, F.VectorComponent,
                                      F.Quantiles)
    end

    @testset "a field cannot be built without all four declarations" begin
        @test_throws MethodError F.Field(FX.NCELLS |> ones)
        for missing_one in (:semantics, :dimension, :data, :support, :time, :origin)
            kwargs = Dict(:semantics => F.Extensive(), :dimension => Dimensions.MASS,
                          :data => ones(FX.NCELLS), :support => FX.SUPPORT,
                          :time => FX.interval_support(),
                          :origin => F.unstamped(:test, FX.RUN))
            delete!(kwargs, missing_one)
            @test_throws UndefKeywordError F.Field(; kwargs...)
        end
    end

    @testset "the four declarations are read back off the type" begin
        f = FX.field(semantics = F.Fraction(), dimension = Dimensions.DIMENSIONLESS)
        @test F.semantics(f) === F.Fraction()
        @test F.time_semantics(f) === Time.IntervalMean()
        @test F.dimension(f) === Dimensions.DIMENSIONLESS
        @test F.level(f) === FX.LEVEL_INDEX
        @test F.support(f) == FX.SUPPORT
        @test F.data(f) == ones(FX.NCELLS)
        @test F.cell_count(f) == FX.NCELLS
        @test F.CELL_AXIS == 1
    end

    @testset "a parametric semantics travels on the type" begin
        f = FX.field(semantics = F.VectorComponent{:cartesian}())
        @test F.semantics(f) === F.VectorComponent{:cartesian}()
        @test typeof(f) !== typeof(FX.field(semantics = F.VectorComponent{:east_north}()))
    end

    @testset "every member of the struct is concrete, whatever the time semantics" begin
        for f in (FX.field(), FX.field(time = FX.static_support()))
            for name in fieldnames(typeof(f))
                @test isconcretetype(fieldtype(typeof(f), name))
            end
        end
        @test F.time_semantics(FX.field()) === Time.IntervalMean()
        @test F.time_semantics(FX.field(time = FX.static_support())) === Time.Static()
        @test fieldtype(typeof(FX.field()), :time) ===
              Time.TimeSupport{Time.IntervalMean,Time.Interval{Float64}}
        @test fieldtype(typeof(FX.field(time = FX.static_support())), :time) ===
              Time.TimeSupport{Time.Static,Nothing}
    end

    @testset "an array that is not one-based is refused" begin
        @test_throws ArgumentError FX.field(data = FX.ShiftedOnes(FX.NCELLS))
    end

    @testset "an unstamped origin names its absence rather than returning zeros" begin
        o = F.unstamped(:writer_name, FX.RUN)
        @test !F.is_stamped(o)
        for door in (F.content_key, F.parameter_digest)
            err = try
                door(o)
            catch e
                e
            end
            @test err isa Refusal
            @test occursin("writer_name", err.reason)
            @test occursin("unstamped", err.reason)
        end
    end

    @testset "a stamped origin returns what it was stamped with" begin
        key = ntuple(i -> UInt8(i), 32)
        params = ntuple(i -> UInt8(32 - i), 32)
        o = F.stamped(:writer_name, FX.RUN, key, params)
        @test F.is_stamped(o)
        @test F.content_key(o) === key
        @test F.parameter_digest(o) === params
        @test o == F.stamped(:writer_name, FX.RUN, key, params)
        @test o != F.unstamped(:writer_name, FX.RUN)
    end

    @testset "an origin state outside the closed pair is refused" begin
        err = try
            F.Origin(:keyed, :writer_name, FX.RUN, F.NO_DIGEST, F.NO_DIGEST)
        catch e
            e
        end
        @test err isa Refusal
        @test err.site == "Fields.Origin"
        @test occursin("keyed", err.reason)
    end

    @testset "addition carries the declarations and an unstamped origin" begin
        a, b = FX.field(), FX.field()
        c = a + b
        @test F.data(c) == fill(2.0, FX.NCELLS)
        @test typeof(c) === typeof(a)
        @test !F.is_stamped(F.origin(c))
        @test F.origin(c).writer === :+
        @test F.origin(c).run == FX.RUN
        @test F.data(a - b) == zeros(FX.NCELLS)
    end

    @testset "a pair whose semantics differ is refused naming both sides" begin
        a = FX.field(semantics = F.Extensive())
        b = FX.field(semantics = F.Intensive())
        err = try
            a + b
        catch e
            e
        end
        @test err isa Refusal
        @test err.site == "Fields.+"
        @test occursin("Extensive", err.reason)
        @test occursin("Intensive", err.reason)
        @test occursin("semantics", err.reason)
        @test !occursin("time semantics", err.reason)
    end

    @testset "a parametric semantics is named with its parameter, not just its head" begin
        a = FX.field(semantics = F.VectorComponent{:cartesian}())
        b = FX.field(semantics = F.VectorComponent{:east_north}())
        err = try
            a + b
        catch e
            e
        end
        @test err isa Refusal
        @test occursin(":cartesian", err.reason)
        @test occursin(":east_north", err.reason)
    end

    @testset "a pair whose time semantics differ is refused naming both sides" begin
        a = FX.field()
        b = FX.field(time = FX.static_support())
        err = try
            a - b
        catch e
            e
        end
        @test err isa Refusal
        @test err.site == "Fields.-"
        @test occursin("IntervalMean", err.reason)
        @test occursin("Static", err.reason)
        @test occursin("time semantics", err.reason)
    end

    @testset "no mismatch arrives as a MethodError" begin
        base = FX.field()
        for other in (FX.field(semantics = F.Intensive()),
                      FX.field(time = FX.static_support()),
                      FX.field(time = FX.interval_support(t1 = 7200.0)),
                      FX.field(dimension = Dimensions.TIME),
                      FX.field(support = FX.support(level_index = 3)),
                      FX.field(support = FX.support(radius = 2.0)),
                      FX.field(origin = F.unstamped(:fixture, OTHER_RUN)))
            for op in (+, -)
                @test_throws Refusal op(base, other)
            end
        end
    end

    @testset "two fields at different places on the clock are refused" begin
        a = FX.field()
        b = FX.field(time = FX.interval_support(t1 = 7200.0))
        @test F.time_semantics(a) === F.time_semantics(b)
        err = try
            a + b
        catch e
            e
        end
        @test err isa Refusal
        @test err.site == "Fields.+"
        @test occursin("different places on the clock", err.reason)
        @test occursin("3600", err.reason)
        @test occursin("7200", err.reason)
    end

    @testset "two fields from different runs are refused naming both" begin
        a = FX.field()
        b = FX.field(origin = F.unstamped(:fixture, OTHER_RUN))
        err = try
            a - b
        catch e
            e
        end
        @test err isa Refusal
        @test err.site == "Fields.-"
        @test occursin(string(FX.RUN), err.reason)
        @test occursin(string(OTHER_RUN), err.reason)
    end

    @testset "addition is commutative in every member, not only in its data" begin
        a = FX.field(data = collect(1.0:FX.NCELLS))
        b = FX.field(data = fill(0.5, FX.NCELLS))
        @test a + b == b + a
        @test F.data(a + b) == F.data(b + a)
        @test F.time_support(a + b) == F.time_support(b + a)
        @test F.origin(a + b) == F.origin(b + a)
    end

    @testset "a pair across mismatched levels is refused, not a MethodError" begin
        a = FX.field()
        b = FX.field(support = FX.support(level_index = 3))
        err = try
            a + b
        catch e
            e
        end
        @test err isa Refusal
        @test err.site == "Fields.+"
    end

    @testset "a pair across mismatched supports is refused naming both" begin
        a = FX.field()
        b = FX.field(support = FX.support(radius = 2.0))
        err = try
            a + b
        catch e
            e
        end
        @test err isa Refusal
        @test err.site == "Fields.+"
        @test occursin(bytes2hex(FX.SUPPORT.digest), err.reason)
    end

    @testset "the accessors and the operators are inferrable" begin
        f = FX.field()
        @test @inferred(F.semantics(f)) === F.Extensive()
        @test @inferred(F.time_semantics(f)) === Time.IntervalMean()
        @test @inferred(F.dimension(f)) === Dimensions.MASS
        @test @inferred(F.level(f)) === FX.LEVEL_INDEX
        @test @inferred(F.data(f)) === F.data(f)
        @test @inferred(F.support(f)) == FX.SUPPORT
        @test @inferred(F.time_support(f)) == F.time_support(f)
        @test @inferred(F.origin(f)) == F.origin(f)
        @test @inferred(f + f) == f + f
        @test @inferred(f - f) == f - f
        @test @inferred(F.require_combinable(f, f, "test")) === nothing
        @test @inferred(F.is_stamped(F.origin(f))) === false
    end

    @testset "a field prints its declarations" begin
        text = sprint(show, FX.field())
        @test occursin("Extensive", text)
        @test occursin("IntervalMean", text)
        @test occursin("mass", text)
    end
end
