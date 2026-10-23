# error_message_tests.jl — stable-message witnesses for GoMeta.goMeta errors.
#
# IS:   witnesses for the stabilized error messages that a plain input can trigger.
# DOES: proves those messages carry their stable substrings on real triggers (since 0.4.3 the unknown label is no refusal —
#       its witness reads the warning rows of the delivery, the run proceeding). The deep-state
#       loci (duplicate-conditions; the condition-key family — witnessed in condition_tests.jl) and the
#       internal-invariant messages ship unwitnessed here, as does the unknown-action message.
# REASONING: the spaced `#~ : x` form reads as TWO metaStatements since 0.4.0: the lone `:`
#       with zero arguments is the Labels Alterant's (the creator's decision) and `x` meets the registry's unknown-action
#       refusal at absorb (the parser-quality battery's r13; the former "misplaced one-word label" refusal was removed),
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

    @testset "unknown label → a warning diagnostic per affected Component, the run proceeding (since 0.4.3; the apply-stage refusal before it)" begin
        # MEASURED (the FULL delivery view and the trace): PROCESS_OK, 0 evals rows; 2 rows LABEL_NOT_APPLIED_UNKNOWN (warning) — the metaBlock
        # and the Text Block attached to it — each naming the token and the remedy
        r = GM.goMeta(Vector{UInt8}(codeunits("#~ :zznotalabel\n# content\n")))
        @test r isa GM.GoMetaDelivery && r.status === GM.PROCESS_OK && isempty(GM.readAltValuesEvals(r.altValues_evals))
        @test length(r.diagnostics) == 2 && all(d -> d.code === :LABEL_NOT_APPLIED_UNKNOWN && d.severity === :warning, r.diagnostics)
        @test all(d -> occursin("`:zznotalabel`", d.message) && occursin("not in the Labels Alterant's vocabulary", d.message) && occursin("correct the spelling", d.message), r.diagnostics)
        @test _err("#~ :zznotalabel\n# content\n") === nothing
    end

    @testset "a second argument list → the grammar's one refusal names the '('" begin
        err = _err("#~ hide(a)(b)\n# content\n")
        @test err isa ErrorException
        @test occursin("unexpected character '('", err.msg)
        @test occursin("after the metaStatement \"hide(a)\"", err.msg)
    end

    @testset "unknown label queried in a CONDITION → no refusal: the query answers false (the original engine's checker)" begin
        r = GM.goMeta(Vector{UInt8}(codeunits("#~ :label1 hide{ :zznotalabel }\n# content\n")))
        @test r isa GM.GoMetaDelivery && r.status === GM.PROCESS_OK
        @test _err("#~ :label1 hide{ :zznotalabel }\n# content\n") === nothing
        # MEASURED by the devtools printout: PROCESS_OK,
        # 2 evals rows on 2 cells — label_label1 => true on Block #2 (the metaLine) and Block #3 (the content); NO visib row: the
        # hide{ … } did not fire — the query of the unknown label answered false
        rows = GM.readAltValuesEvals(r.altValues_evals)
        @test [a for (h, a, v, p) in rows] == [:label_label1, :label_label1] && all(v === true for (h, a, v, p) in rows) &&
              all(x -> x.attr !== :visib, r.altValues_evals.records)   # the values pinned too
    end
end
