using Test
using Fiddlybits: EarthRatios, Dispositions, Dimensions

# EarthRatios.rotation_rate_unit: docs/plans/fiddlybits-52v.4-system.md, section "The
# quarantine". The value is Moritz (2000)'s GRS80 defining angular velocity of the
# Earth, references/text/moritz2000-geodetic-reference-system-1980/0004.txt, p.131,
# "Defining Constants (exact)": x = 7 292 115 x 10^-11 rad s^-1.

@testset "EarthRatios.rotation_rate_unit" begin
    d = EarthRatios.rotation_rate_unit()

    @testset "the value is the one Moritz prints" begin
        @test Dispositions.value(d) == 7.292115e-5
    end

    @testset "the dimension is inverse time" begin
        @test Dispositions.dimension(d) == inv(Dimensions.TIME)
    end

    @testset "the locator names Moritz 2000, not IERS Conventions (2010) TN36" begin
        @test d.locator.identifier == "10.1007/s001900050278"
    end
end
