# error_message_tests.jl — stable-message witnesses for GoMeta.goMeta errors.
#
# IS:   witnesses for the stabilized error messages that a plain input can trigger.
# DOES: proves those messages carry their stable substrings on real triggers. The deep-state
#       loci (duplicate-conditions, condition-key family) and the internal-invariant messages
#       ship unwitnessed here, as does the unknown-action message.
# REASONING: the spaced `#~ : x` form is rejected before label handling by the absorb grammar's "misplaced
#       one-word label" refusal (MEASURED by stage 5's E6 probe of the v0.4 build, its J5 — not by the set-invocation
#       seam the first draft of this line named, left at E6),
#       so the unspaced form is the true label path exercised below.
# PURPOSE: no bare stack traces — every user-triggerable failure names what went wrong.

using Test
import GoMeta as GM

@testset "error_message_stables" begin

    _err(s) = try
        GM.goMeta(Vector{UInt8}(codeunits(s)))
        nothing
    catch e
        e
    end

    @testset "unknown label → the apply-stage whitelist message" begin
        err = _err("#~ :zznotalabel\n# content\n")
        @test err isa ErrorException
        @test occursin("unknown label", err.msg)
        @test occursin("zznotalabel", err.msg)
    end

    @testset "duplicate argument list → the absorb-stage message" begin
        err = _err("#~ hide(a)(b)\n# content\n")
        @test err isa ErrorException
        @test occursin("duplicate argument list", err.msg)
    end

    @testset "unknown label queried in a CONDITION → no refusal: the query answers false (the legacy's checker; stage 5's E9 of the v0.4 build, census row 55)" begin
        r = GM.goMeta(Vector{UInt8}(codeunits("#~ :label1 hide{ :zznotalabel }\n# content\n")))
        @test r isa GM.GoMetaDelivery && r.status === GM.PROCESS_OK
        @test _err("#~ :label1 hide{ :zznotalabel }\n# content\n") === nothing
        # MEASURED by the devtools printout on the E9 scratch (receipts/S8-branch/PROBES-e9-query-role_on-841707af.txt; R4b): PROCESS_OK,
        # 2 evals rows on 2 cells — label_label1 => true on Block #2 (the metaLine) and Block #3 (the content); NO visib row: the
        # hide{ … } did not fire — the query of the unknown label answered false
        rows = GM.readAltValuesEvals(r.altValues_evals)
        @test [a for (h, a, v, p) in rows] == [:label_label1, :label_label1] && all(v === true for (h, a, v, p) in rows) &&
              all(x -> x.attr !== :visib, r.altValues_evals.records)   # the values pinned too (the seat's F-10)
    end
end
