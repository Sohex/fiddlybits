using Test
using CUDA
using Random
using Fiddlybits: Provenance, Backends, Verdicts

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

@testset "Provenance.rng" begin
    @testset "philox4x32_10 matches the Random123 reference implementation's known-answer vectors" begin
        cases = (
            (ctr = (0x00000000, 0x00000000, 0x00000000, 0x00000000), key = (0x00000000, 0x00000000),
             out = (0x6627e8d5, 0xe169c58d, 0xbc57ac4c, 0x9b00dbd8)),
            (ctr = (0xffffffff, 0xffffffff, 0xffffffff, 0xffffffff), key = (0xffffffff, 0xffffffff),
             out = (0x408f276d, 0x41c83b0e, 0xa20bc7c6, 0x6d5451fd)),
            (ctr = (0x243f6a88, 0x85a308d3, 0x13198a2e, 0x03707344), key = (0xa4093822, 0x299f31d0),
             out = (0xd16cfe09, 0x94fdcceb, 0x5001e420, 0x24126ea1)),
        )
        for c in cases
            @test Provenance.philox4x32_10(c.ctr, c.key) == c.out
        end

        @testset "positive control: one flipped counter bit is a different output" begin
            ctr, key, out = cases[1].ctr, cases[1].key, cases[1].out
            flipped = (ctr[1] ⊻ 0x00000001, ctr[2], ctr[3], ctr[4])
            @test Provenance.philox4x32_10(flipped, key) != out
        end
    end

    @testset "philox_draw refuses an identity word that does not fit a 32-bit counter" begin
        breaks = (("support id", (2^32, 1, 1, 1)), ("cell", (1, -1, 1, 1)),
                  ("process", (1, 1, 2^40, 1)), ("time index", (1, 1, 1, -3)))
        for (which, args) in breaks
            e = try
                Provenance.philox_draw(1, args...)
            catch err
                err
            end
            @test e isa Verdicts.Refusal
            @test e.quantity == which
        end

        @testset "positive control: every word in range draws" begin
            @test Provenance.philox_draw(1, 2, 3, 4, 5) isa NTuple{4,UInt32}
        end
    end

    @testset "repro.stochastic_identity" begin
        root_seed, support_id, process, time_index = UInt64(0x5EED), 3, 7, 11
        n = 4^5

        "One draw per cell 1:n, assembled from launches over `ranges`, each its
        own kernel launch at its own offset, on `backend`."
        function assembled(backend, ranges)
            out = Vector{NTuple{4,UInt32}}(undef, n)
            for r in ranges
                Provenance.philox_draw!(view(out, r), backend, root_seed, support_id,
                                         process, time_index; offset = first(r) - 1)
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
                correct_whole = [Provenance.philox_draw(root_seed, support_id, cell, process, time_index)
                                 for cell in 1:n]
                # the anti-pattern: each launch's own local index stands in for the
                # cell, so the second partition's local index 1 collides with the
                # first partition's cell 1 instead of naming cell h + 1
                broken_split = vcat(
                    [Provenance.philox_draw(root_seed, support_id, local_i, process, time_index) for local_i in 1:h],
                    [Provenance.philox_draw(root_seed, support_id, local_i, process, time_index) for local_i in 1:(n - h)],
                )
                @test broken_split != correct_whole
            end
        end

        @testset "adding draws to one process does not move another's stream" begin
            cell = 17
            other_process = process + 1
            other = Provenance.philox_draw(root_seed, support_id, cell, other_process, time_index)
            for extra in 0:4
                for t in time_index:(time_index + extra)
                    Provenance.philox_draw(root_seed, support_id, cell, process, t)
                end
                @test Provenance.philox_draw(root_seed, support_id, cell, other_process, time_index) == other
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
        root_seed, support_id, process, time_index = UInt64(99), 2, 5, 9

        cpu = Backends.CPU(16)
        out_cpu = Vector{NTuple{4,UInt32}}(undef, n)
        Provenance.philox_draw!(out_cpu, cpu, root_seed, support_id, process, time_index)

        @testset "reference agreement (decision 0027)" begin
            ref = Vector{NTuple{4,UInt32}}(undef, n)
            Provenance.philox_draw_reference!(ref, root_seed, support_id, process, time_index)
            @test out_cpu == ref
        end

        @test CUDA.functional()
        gpu = Backends.GPU(16)
        out_gpu = Backends.on(similar(out_cpu), gpu)
        Provenance.philox_draw!(out_gpu, gpu, root_seed, support_id, process, time_index)
        @test Backends.on(out_gpu, cpu) == out_cpu
    end
end
