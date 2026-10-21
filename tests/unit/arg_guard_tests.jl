# arg_guard_tests.jl — the documented WORKING argument forms (a former argument guard was removed
# with its refusal witnesses).
#
# IS:   witnesses that every documented WORKING form stays PROCESS_OK, double-call byte-deterministic,
#       and render-pinned byte-exact; also [F]: the faults of the `ids` action meet Julia's own
#       error out of goMeta — the standing class, each class measured, two
#       beside a single-action control (I12 the arity, I13 the value); and a SINGLE action written with three values (I14, `cell(1, 2, 3)`)
#       meets the `ids` method's guard — the setter's own ArgumentError, its wording provisional, the creator's to re-word.
# DOES: drives the working twins through goMeta and pins status, determinism and the render bytes.
# REASONING: the guarded "invalid arguments" refusal at the former setter seam `_invoke_set` was removed
#       with its crash-leg and sole-exception-surface witnesses (the creator's words: the framework
#       before hardening; the original engine called the setter directly): a malformed argument meets Julia's own dispatch
#       or the setter's own error out of the `goMeta` call, measured before and after the change.
#       The QUERY-side condition-atom class
#       (`#~ cell(7) :label1{ cell(7) }`) meets the usual unknown-condition-key refusal (Id answers
#       no query — the registry's rule; witnessed in condition_tests.jl) — no witnesses here by design.
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

    @testset "[F] the faults of `ids` — the standing class, Julia's own error out of goMeta (the classes MEASURED on `…⏎x = 1` documents; here on this file's `# c` twins, by the testset's own run)" begin
        _err(s) = try; _run(s); nothing; catch e; e; end
        @test _err("#~ ids(1, 2)\n# c\n") isa MethodError                    # I04: two values — no method, as cell(1, 2) (I12)
        @test _err("#~ cell(1, 2)\n# c\n") isa MethodError                   # I12: the control
        @test _err("#~ ids(x, 2, 3)\n# c\n") isa ArgumentError               # I08: a non-parsable value, as cell(x) (I13)
        @test _err("#~ ids(70000, 1, 1)\n# c\n") isa OverflowError            # I09: an Int16 overflow
        e7 = _err("#~ ids(7)\n# c\n")                                        # I11: ONE value reaches the single-value method — Julia's FieldError on the field name
        @test e7 isa FieldError && occursin("ids", sprint(showerror, e7))
        eq = _err("#~ ids(\"7\", 2, 3)\n# c\n")                               # I05: a quoted value — the absorb's string-argument wall, as cell(\"7\")
        @test eq isa ErrorException && occursin("string argument not accepted", eq.msg)
        @test _err("#~ ids(1, 2, 3, 4)\n# c\n") isa MethodError              # I15: four values — no method
        @test _err("#~ ids()\n# c\n") isa MethodError                         # I16: no value — no method (`()` is no argument; a bare `ids` reaches the same call — traced, not measured)
        e3 = _err("#~ cell(1, 2, 3)\n# c\n")                                  # I14: THREE values to a SINGLE action reach the three-value method's guard —
        @test e3 isa ArgumentError && occursin("belong to the action `ids` alone", sprint(showerror, e3))   # the setter's ArgumentError where the tree before the `ids` action met Julia's MethodError
    end
end
