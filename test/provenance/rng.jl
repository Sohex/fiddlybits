using Test
using CUDA
using Random
using Fiddlybits: Provenance, Backends, Mesh, Verdicts

# repro.stochastic_identity and the generator of docs/plans/fiddlybits-52v.6-provenance.md,
# section "The generator". Decisions 0010 and 0029.

"""
    PerCellSeededControl

The anti-pattern decision 0010 rejects: a stream keyed on the cell alone and
advanced every time the cell is drawn from, whichever caller draws it. Used
only to demonstrate the two arms of `repro.stochastic_identity` below: this
generator passes the partition arm and fails the stream-independence arm.
"""
module PerCellSeededControl

using Random

const STREAMS = Dict{Int,Random.MersenneTwister}()

"The next `UInt32` from the stream seeded by `cell` alone, creating that stream on its first draw."
function draw!(cell::Integer)
    rng = get!(() -> Random.MersenneTwister(Int(cell)), STREAMS, Int(cell))
    return rand(rng, UInt32)
end

"Empties every per-cell stream."
reset!() = empty!(STREAMS)

end # module PerCellSeededControl

"A `Mesh.Support` at level 0 (the 20-cell base icosahedron), the cheapest one to build."
function fixture_support()
    level = Mesh.hierarchy(0).levels[1]
    geometry = Mesh.geometry(level, Mesh.stencils(level))
    return Mesh.Support(0, level, geometry; kind = :icosahedral_bisection, refinement = (),
                         radius = 1.0, element_type = :Float64, fractions = ())
end

"A fixture 32-byte digest, not the identity of anything, for tests that only need a digest shape."
fixture_digest() = ntuple(i -> UInt8(i), 32)

@testset "Provenance.rng" begin
    @testset "philox4x64_10 matches the Random123 reference implementation's known-answer vectors" begin
        cases = (
            (ctr = (0x0000000000000000, 0x0000000000000000, 0x0000000000000000, 0x0000000000000000),
             key = (0x0000000000000000, 0x0000000000000000),
             out = (0x16554d9eca36314c, 0xdb20fe9d672d0fdc, 0xd7e772cee186176b, 0x7e68b68aec7ba23b)),
            (ctr = (0xffffffffffffffff, 0xffffffffffffffff, 0xffffffffffffffff, 0xffffffffffffffff),
             key = (0xffffffffffffffff, 0xffffffffffffffff),
             out = (0x87b092c3013fe90b, 0x438c3c67be8d0224, 0x9cc7d7c69cd777b6, 0xa09caebf594f0ba0)),
            (ctr = (0x243f6a8885a308d3, 0x13198a2e03707344, 0xa4093822299f31d0, 0x082efa98ec4e6c89),
             key = (0x452821e638d01377, 0xbe5466cf34e90c6c),
             out = (0xa528f45403e61d95, 0x38c72dbd566e9788, 0xa5a1610e72fd18b5, 0x57bd43b5e52b7fe6)),
        )
        for c in cases
            @test Provenance.philox4x64_10(c.ctr, c.key) == c.out
        end

        @testset "positive control: one flipped counter bit is a different output" begin
            ctr, key, out = cases[1].ctr, cases[1].key, cases[1].out
            flipped = (ctr[1] ⊻ 0x0000000000000001, ctr[2], ctr[3], ctr[4])
            @test Provenance.philox4x64_10(flipped, key) != out
        end
    end

    @testset "mulhilo64 matches widemul bit for bit" begin
        edge = UInt64[0, 1, typemax(UInt64), Provenance.PHILOX4X64_M0, Provenance.PHILOX4X64_M1,
                      0x123456789abcdef0, 0xffffffff00000001]
        for a in edge, b in edge
            w = widemul(a, b)
            expected = (w % UInt64, (w >> 64) % UInt64)
            @test Provenance.mulhilo64(a, b) == expected
        end

        @testset "positive control: the two halves are not interchangeable" begin
            lo, hi = Provenance.mulhilo64(Provenance.PHILOX4X64_M0, Provenance.PHILOX4X64_M1)
            @test lo != hi
        end
    end

    @testset "philox_key128" begin
        seed, digest, process = UInt64(11), fixture_digest(), 4
        key = Provenance.philox_key128(seed, digest, process)
        @test key isa NTuple{2,UInt64}
        @test Provenance.philox_key128(seed, digest, process) == key

        @testset "positive control: each input moves the key" begin
            @test Provenance.philox_key128(seed + 1, digest, process) != key
            @test Provenance.philox_key128(seed, (digest[1] ⊻ 0x01, digest[2:end]...), process) != key
            @test Provenance.philox_key128(seed, digest, process + 1) != key
        end

        @testset "the Mesh.Support overload reads its digest" begin
            support = fixture_support()
            @test Provenance.philox_key128(seed, support, process) ==
                  Provenance.philox_key128(seed, support.digest, process)
        end
    end

    @testset "philox_draw refuses a negative identity word" begin
        digest = fixture_digest()
        breaks = (("cell", (-1, 1, 1, 1)), ("process", (1, -1, 1, 1)),
                  ("time index", (1, 1, -1, 1)), ("draw index", (1, 1, 1, -1)))
        for (which, (cell, process, time_index, draw_index)) in breaks
            e = try
                Provenance.philox_draw(UInt64(1), digest, cell, process, time_index, draw_index)
            catch err
                err
            end
            @test e isa Verdicts.Refusal
            @test e.quantity == which
        end

        @testset "positive control: every word non-negative draws" begin
            @test Provenance.philox_draw(UInt64(1), digest, 1, 1, 1, 1) isa NTuple{4,UInt64}
        end
    end

    @testset "repro.stochastic_identity" begin
        root_seed, digest, process, time_index, draw_index = UInt64(0x5EED), fixture_digest(), 7, 11, 0
        n = 4^5

        "One draw per cell 1:n, assembled from launches over `ranges`, each its
        own kernel launch at its own offset, on `backend`."
        function assembled(backend, ranges)
            out = Vector{NTuple{4,UInt64}}(undef, n)
            for r in ranges
                Provenance.philox_draw!(view(out, r), backend, root_seed, digest, process,
                                         time_index, draw_index; offset = first(r) - 1)
            end
            Backends.complete!(backend)
            return out
        end

        whole = assembled(Backends.CPU(16), (1:n,))

        @testset "changing the partition does not change a draw" begin
            h = n ÷ 3
            split_forward = assembled(Backends.CPU(4), (1:h, (h + 1):n))
            split_reverse = assembled(Backends.CPU(8), ((h + 1):n, 1:h))
            @test split_forward == whole
            @test split_reverse == whole

            @testset "positive control: keying on the launch-local index instead of the global cell fails this arm" begin
                correct_whole = [Provenance.philox_draw(root_seed, digest, cell, process, time_index, draw_index)
                                 for cell in 1:n]
                # the anti-pattern: each launch's own local index stands in for the
                # cell, so the second partition's local index 1 collides with the
                # first partition's cell 1 instead of naming cell h + 1
                broken_split = vcat(
                    [Provenance.philox_draw(root_seed, digest, local_i, process, time_index, draw_index)
                     for local_i in 1:h],
                    [Provenance.philox_draw(root_seed, digest, local_i, process, time_index, draw_index)
                     for local_i in 1:(n - h)],
                )
                @test broken_split != correct_whole
            end
        end

        @testset "adding draws to one process does not move another's stream" begin
            cell = 17
            other_process = process + 1
            other = Provenance.philox_draw(root_seed, digest, cell, other_process, time_index, draw_index)
            for extra in 0:4
                for t in time_index:(time_index + extra)
                    Provenance.philox_draw(root_seed, digest, cell, process, t, draw_index)
                end
                @test Provenance.philox_draw(root_seed, digest, cell, other_process, time_index, draw_index) == other
            end
        end

        @testset "more draws within a cell and step move no other draw index" begin
            cell = 23
            first_draw = Provenance.philox_draw(root_seed, digest, cell, process, time_index, 0)
            for extra_draws in 1:4
                for d in 1:extra_draws
                    Provenance.philox_draw(root_seed, digest, cell, process, time_index, d)
                end
                @test Provenance.philox_draw(root_seed, digest, cell, process, time_index, 0) == first_draw
            end

            @testset "positive control: two draw indices at the same cell and step are different draws" begin
                @test Provenance.philox_draw(root_seed, digest, cell, process, time_index, 0) !=
                      Provenance.philox_draw(root_seed, digest, cell, process, time_index, 1)
            end
        end

        @testset "positive control: a generator merely seeded per cell passes the partition arm and fails the stream-independence arm" begin
            @testset "passes the partition arm" begin
                PerCellSeededControl.reset!()
                m = 200
                seeded_whole = [PerCellSeededControl.draw!(cell) for cell in 1:m]

                PerCellSeededControl.reset!()
                h = m ÷ 3
                seeded_split = vcat([PerCellSeededControl.draw!(cell) for cell in 1:h],
                                     [PerCellSeededControl.draw!(cell) for cell in (h + 1):m])
                @test seeded_split == seeded_whole
            end

            @testset "fails the stream-independence arm" begin
                cell = 42
                PerCellSeededControl.reset!()
                PerCellSeededControl.draw!(cell)                 # process A's one draw
                b_after_one = PerCellSeededControl.draw!(cell)   # process B's draw

                PerCellSeededControl.reset!()
                PerCellSeededControl.draw!(cell)                 # process A's first draw
                PerCellSeededControl.draw!(cell)                 # process A adds a second draw
                b_after_two = PerCellSeededControl.draw!(cell)   # process B's draw, unchanged in A

                @test b_after_one != b_after_two
            end
        end
    end

    @testset "the generator runs inside a portable KernelAbstractions kernel on both backends" begin
        n = 4^4
        root_seed, digest, process, time_index, draw_index = UInt64(99), fixture_digest(), 5, 9, 2

        cpu = Backends.CPU(16)
        out_cpu = Vector{NTuple{4,UInt64}}(undef, n)
        Provenance.philox_draw!(out_cpu, cpu, root_seed, digest, process, time_index, draw_index)

        @testset "reference agreement (decision 0027)" begin
            ref = Vector{NTuple{4,UInt64}}(undef, n)
            Provenance.philox_draw_reference!(ref, root_seed, digest, process, time_index, draw_index)
            @test out_cpu == ref
        end

        @testset "the Mesh.Support overload of philox_draw! agrees with the raw-digest form" begin
            support = fixture_support()
            via_support = Vector{NTuple{4,UInt64}}(undef, n)
            Provenance.philox_draw!(via_support, cpu, root_seed, support, process, time_index, draw_index)
            via_digest = Vector{NTuple{4,UInt64}}(undef, n)
            Provenance.philox_draw!(via_digest, cpu, root_seed, support.digest, process, time_index, draw_index)
            @test via_support == via_digest
        end

        @test CUDA.functional()
        gpu = Backends.GPU(16)
        out_gpu = Backends.on(similar(out_cpu), gpu)
        Provenance.philox_draw!(out_gpu, gpu, root_seed, digest, process, time_index, draw_index)
        @test Backends.on(out_gpu, cpu) == out_cpu
    end
end
