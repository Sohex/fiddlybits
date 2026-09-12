using Test
using CUDA
using Fiddlybits: Fields, Backends, Dimensions, Time
import Adapt

# fields.adapt_roundtrip: docs/oracles/registry.toml. The leak test
# docs/imports/adapt.md names, and the acceptance of row 52v.3.2.
#
# A Field is a host-side wrapper whose array may live on either device, and the wrapper
# never enters a kernel: every kernel here takes bare arrays. So the crossing drops
# nothing and this oracle can assert equality in every member rather than a subset.

const FA = Fields
const FXA = FieldFixtures

"The field types this oracle walks: one per semantics, with a static arm for the time."
registered_fields() = (
    FXA.field(semantics = FA.Extensive(), dimension = Dimensions.MASS),
    FXA.field(semantics = FA.Intensive(), dimension = Dimensions.TEMPERATURE),
    FXA.field(semantics = FA.FluxDensity(), dimension = Dimensions.MASS),
    FXA.field(semantics = FA.Fraction(), dimension = Dimensions.DIMENSIONLESS),
    FXA.field(semantics = FA.CategoricalLabel{:rock}(),
              dimension = Dimensions.DIMENSIONLESS),
    FXA.field(semantics = FA.CategoricalFraction{:rock}(),
              dimension = Dimensions.DIMENSIONLESS),
    FXA.field(semantics = FA.VectorComponent{:cartesian}(),
              dimension = Dimensions.LENGTH / Dimensions.TIME),
    FXA.field(semantics = FA.Quantiles{(0.5, 0.9)}(),
              dimension = Dimensions.TEMPERATURE),
    FXA.field(time = FXA.static_support()),
    FXA.field(data = ones(Float32, FXA.NCELLS)),
    FXA.field(origin = FA.stamped(:writer, FXA.RUN, ntuple(UInt8, 32),
                                  ntuple(i -> UInt8(32 - i), 32))),
)

"Every member of a field compared one at a time, so a drop is named rather than missed."
function same_in_every_member(a, b)
    return (data = FA.data(a) == FA.data(b),
            support = FA.support(a) == FA.support(b),
            time = FA.time_support(a) == FA.time_support(b),
            origin = FA.origin(a) == FA.origin(b),
            semantics = FA.semantics(a) === FA.semantics(b),
            time_semantics = FA.time_semantics(a) === FA.time_semantics(b),
            dimension = FA.dimension(a) === FA.dimension(b),
            level = FA.level(a) === FA.level(b))
end

# The positive control: an adapt rule that carries the data and drops the support,
# which must be caught by a member-by-member comparison and would not be by comparing
# the data alone.
struct DroppingField{A}
    data::A
    support::Any
end

Adapt.adapt_structure(to, f::DroppingField) =
    DroppingField(Adapt.adapt(to, f.data), nothing)

@testset "fields.adapt_roundtrip" begin
    @test CUDA.functional()

    @testset "the host round trip changes nothing in any member" begin
        for f in registered_fields()
            there = Adapt.adapt(Array, f)
            @test typeof(there) === typeof(f)
            for (name, same) in pairs(same_in_every_member(f, there))
                @test same
            end
        end
    end

    @testset "the device round trip changes only where the array lives" begin
        for f in registered_fields()
            there = Adapt.adapt(CuArray, f)
            @test FA.data(there) isa CuArray
            @test FA.semantics(there) === FA.semantics(f)
            @test FA.time_semantics(there) === FA.time_semantics(f)
            @test FA.dimension(there) === FA.dimension(f)
            @test FA.level(there) === FA.level(f)
            @test FA.support(there) == FA.support(f)
            @test FA.time_support(there) == FA.time_support(f)
            @test FA.origin(there) == FA.origin(f)

            back = Adapt.adapt(Array, there)
            @test typeof(back) === typeof(f)
            @test back == f
        end
    end

    @testset "the wrapper carries its declarations, and the kernel takes the array" begin
        f = FXA.field()
        @test !isbitstype(typeof(f))
        @test isbitstype(eltype(FA.data(f)))
        @test isconcretetype(fieldtype(typeof(f), :support))
    end

    @testset "positive control: an adapt rule that drops the support is caught" begin
        f = DroppingField(ones(FXA.NCELLS), FXA.SUPPORT)
        there = Adapt.adapt(Array, f)
        @test there.data == f.data
        @test there.support != f.support
        @test there.support === nothing
    end
end
