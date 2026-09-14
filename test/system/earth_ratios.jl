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

# EarthRatios.radius_unit: the volume-equivalent radius (a^2 b)^(1/3) of Archinal et al.
# (2018) Table 4's Earth equatorial radius a = 6378.1366 km and polar radius
# b = 6356.7519 km, references/text/archinal2018-iau-cartographic-coordinates-and-rotational-elements/0028.txt.

@testset "EarthRatios.radius_unit" begin
    a, b = EarthRatios.equatorial_radius_unit(), EarthRatios.polar_radius_unit()
    r = EarthRatios.radius_unit()

    @testset "the two radii are the ones Table 4 prints" begin
        @test Dispositions.value(a) == 6_378_136.6
        @test Dispositions.value(b) == 6_356_751.9
        @test a.locator.identifier == b.locator.identifier == "10.1007/s10569-017-9805-5"
    end

    @testset "the radius is Derived as the volume-equivalent radius of the two" begin
        @test r isa Dispositions.Derived
        @test r.from == (:equatorial_radius_unit, :polar_radius_unit)
        @test r.rule == :volume_equivalent_radius
        exact = setprecision(BigFloat, 256) do
            cbrt(big"6378136.6"^2 * big"6356751.9")
        end
        @test abs(Dispositions.value(r) - exact) <= 4 * eps(Dispositions.value(r))
        @test Dispositions.dimension(r) == Dimensions.LENGTH
    end

    @testset "positive control: the volume-equivalent radius is not Table 4's arithmetic mean radius" begin
        @test abs(Dispositions.value(r) - 6_371_008.4) > 1.0
    end
end
