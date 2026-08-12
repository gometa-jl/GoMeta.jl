# arg_guard_tests.jl — action-argument refusal witnesses
#
# IS:   witnesses for the typed argument guard at the apply-plane setAltInstance seam (`_invoke_set`).
# DOES: proves every guarded arg-wall crash class refuses with the stable "invalid arguments"
#       ErrorException (never raw MethodError/ArgumentError/OverflowError), that the refusal is the
#       SOLE exception surface (no `caused by:` chain — the flag-then-throw-outside-catch design),
#       and that every documented WORKING form stays PROCESS_OK, double-call byte-deterministic,
#       and render-pinned byte-exact.
# REASONING: the probe strings below enumerate the guarded crash forms. The QUERY-side
#       condition-atom class (`#~ cell(7) :label1{ cell(7) }`) is a DOCUMENTED CUT (the E-07 fence at the
#       closed condition interpreter — README SECURITY; docs/public-api.md §3.2) — no
#       witnesses here by design.
# PURPOSE: the "no raw stack-trace mysteries" bar, mechanically held at the argument surface.

using Test
import GoMeta as GM

@testset "arg_guard" begin

    _run(s) = GM.goMeta(Vector{UInt8}(codeunits(s)))
    _err(s) = try
        _run(s)
        nothing
    catch e
        e
    end

    @testset "crash legs → the stable refusal" begin
        for s in ["#~ cell(x)\n# c\n",        # value wall: parse(Int16, "x")
                  "#~ cell()\n# c\n",          # arity: value missing
                  "#~ cell(7, 9)\n# c\n",      # arity: too many
                  "#~ hide(a)\n# c\n",         # Visib takes no args
                  "#~ show(a)\n# c\n",         # Visib takes no args
                  "#~ cell(99999)\n# c\n",     # Int16 overflow
                  "#~ cell(\xff)\n# c\n",      # raw-byte value
                  "#~ cell\n# c\n"]            # bare action, value missing
            err = _err(s)
            @test err isa ErrorException
            @test occursin("invalid arguments", err.msg)
            @test occursin("GoMeta apply:", err.msg)
        end
    end

    @testset "the refusal is the sole exception surface (no caused-by chain)" begin
        depth = try
            _run("#~ cell(x)\n# c\n")
            -1
        catch
            length(Base.current_exceptions())
        end
        @test depth == 1
    end

    @testset "working twins PROCESS_OK + byte-deterministic" begin
        for (s, want) in [("#~ cell(7)\n# c\n", "#~ cell(7)\n# c\n"),
                  ("#~ file(2)\n# c\n", "#~ file(2)\n# c\n"),
                  ("#~ :(label1, label2)\n# c\n", "#~ :(label1, label2)\n# c\n"),
                  ("#~ :label1 :label2\n# c\n", "#~ :label1 :label2\n# c\n"),
                  ("#~ hide\n# c\n", "## #~ hide\n## # c\n"),
                  ("#~ hide()\n# c\n", "## #~ hide()\n## # c\n")]
            r1 = _run(s); r2 = _run(s)
            @test string(r1.status) == "PROCESS_OK"
            @test GM.outputs(r1) == GM.outputs(r2)
            @test String(copy(GM.outputs(r1)[2])) == want   # the working form's render, byte-pinned
        end
    end
end
