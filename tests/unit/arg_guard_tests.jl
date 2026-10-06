# arg_guard_tests.jl — the documented WORKING argument forms (the typed argument guard left at stage 5's E6
# of the v0.4 build with its refusal witnesses — census row 14).
#
# IS:   witnesses that every documented WORKING form stays PROCESS_OK, double-call byte-deterministic,
#       and render-pinned byte-exact.
# DOES: drives the working twins through goMeta and pins status, determinism and the render bytes.
# REASONING: the typed "invalid arguments" refusal at the setter seam `_invoke_set` left at stage 5's E6 of the
#       v0.4 build with its crash-leg and sole-exception-surface witnesses (census row 14 — his §120, the framework
#       before hardening; his legacy called the setter directly): a malformed argument meets Julia's own dispatch
#       or the setter's own error out of the `goMeta` call, measured on both trees by the build's probe
#       (the build record's receipts/S8-branch/PROBES-e6-edges-*). The QUERY-side condition-atom class
#       (`#~ cell(7) :label1{ cell(7) }`) is a DOCUMENTED CUT (the E-07 fence at the closed condition
#       interpreter — README SECURITY; docs/public-api.md §3.2) — no witnesses here by design.
# PURPOSE: the working forms' contract (docs/public-api.md §2), mechanically held.

using Test
import GoMeta as GM

@testset "arg_guard" begin

    _run(s) = GM.goMeta(Vector{UInt8}(codeunits(s)))

    @testset "working twins PROCESS_OK + byte-deterministic" begin
        for (s, want) in [("#~ cell(7)\n# c\n", "#~ cell(7)\n# c\n"),
                  ("#~ file(2)\n# c\n", "#~ file(2)\n# c\n"),
                  ("#~ :(label1, label2)\n# c\n", "#~ :(label1, label2)\n# c\n"),
                  ("#~ :label1 :label2\n# c\n", "#~ :label1 :label2\n# c\n"),
                  ("#~ hide\n# c\n", "## #~ hide\n## # c\n"),
                  ("#~ hide()\n# c\n", "## #~ hide()\n## # c\n")]
            r1 = _run(s); r2 = _run(s)
            @test string(r1.status) == "PROCESS_OK"
            @test Main.BasicRenderer.outputs(r1) == Main.BasicRenderer.outputs(r2)
            @test String(copy(Main.BasicRenderer.outputs(r1)[2])) == want   # the working form's render, byte-pinned
        end
    end
end
