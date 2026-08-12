# condition_cap_tests.jl — the condition-scan-cap guarded refusal (E-02)
#
# IS:   the witness set for the condition scanner's cap guard: an over-cap condition (the scan
#       cap admits 29 steps; one step is one operator, one space, or one whole atom) refuses
#       with a stable message instead of silently evaluating a truncated condition.
# DOES: proves (1) an over-cap condition whose DECIDING atom sits past the cap raises the stable
#       ErrorException "condition too complex" — never a silent PROCESS_OK with a wrong render;
#       (2) the same semantics under the cap stay PROCESS_OK with the deciding atom applied;
#       (3) the boundary is exact: a cap-hit whose remainder is ONLY whitespace is semantically
#       complete and stays accepted, while the same prefix with one trailing non-whitespace
#       char refuses — the pair pins the cap arithmetic inside the suite;
#       (4) refusal and acceptance are byte-deterministic across repeated calls.
# REASONING: the guard refuses exactly the lossy class (non-whitespace input left unconsumed);
#       every fully-scanned condition — including whitespace-tail cap-hits — is untouched.
# PURPOSE: a too-long condition meets an explanatory refusal naming the unscanned tail, never a
#       silently wrong render.

using Test
import GoMeta as GM

const _CC_PAD9  = join(fill("isText", 9), ", ")    # 9 pad atoms (with a 10th atom: 30 steps)
const _CC_PAD12 = join(fill("isText", 12), ", ")   # 12 pad atoms (with a 13th: far over cap)
_cc_mk(cond) = Vector{UInt8}(codeunits("#~ hide{ $cond }\nx = 1\n"))
_cc_hidden(r) = occursin("## x = 1", String(copy(GM.outputs(r)[2])))
_cc_refusal(bytes) = try
    GM.goMeta(bytes)
    nothing
catch e
    e
end

@testset "condition_cap_guard (E-02)" begin

    @testset "over-cap: stable refusal, never a silent wrong render" begin
        err = _cc_refusal(_cc_mk("$_CC_PAD12, isCode"))   # 13 atoms; deciding isCode past the cap
        @test err isa ErrorException
        @test occursin("condition too complex", err.msg)
        @test occursin("isCode", err.msg)                 # the refusal names the unscanned tail
    end

    @testset "under-cap control: same shape, deciding atom applied" begin
        r = GM.goMeta(_cc_mk(join(fill("isText", 8), ", ") * ", isCode"))   # 9 atoms = 27 steps
        @test r.status == GM.PROCESS_OK
        @test _cc_hidden(r)                               # isCode reached ⇒ the code line hides
        # the FALSE-condition twin: a truly under-cap shape (9 atoms = 27 steps), every atom
        # false on a TEXT line — under-cap evaluation must yield FALSE with the byte-exact
        # passthrough render.
        rf = GM.goMeta(Vector{UInt8}(codeunits("#~ hide{ " * join(fill("isCode", 8), ", ") * ", isCode }\n# t\n")))
        @test rf.status == GM.PROCESS_OK
        @test !occursin("## # t", String(copy(GM.outputs(rf)[2])))   # the text line is NOT hidden…
        @test String(copy(GM.outputs(rf)[2])) == "#~ hide{ isCode, isCode, isCode, isCode, isCode, isCode, isCode, isCode, isCode }\n# t\n"   # …and the whole render is the byte-exact passthrough
    end

    @testset "exact boundary: whitespace-only remainder accepted; one more char refuses" begin
        # 10 comma-joined 6-char atoms = 30 steps: the 29-step scan leaves ONLY the trailing
        # space unconsumed — semantically complete, so it must stay accepted AND correct…
        ok = GM.goMeta(_cc_mk("$_CC_PAD9, isCode"))
        @test ok.status == GM.PROCESS_OK
        @test _cc_hidden(ok)
        # …while the SAME prefix with one trailing non-whitespace char must refuse. Together the
        # pair pins the cap boundary: a mis-derived step count cannot green both.
        err = _cc_refusal(_cc_mk("$_CC_PAD9, isCode !"))
        @test err isa ErrorException
        @test occursin("condition too complex", err.msg)
    end

    @testset "deterministic: refusal and acceptance stable across calls" begin
        b_ref = _cc_mk("$_CC_PAD12, isCode")
        e1 = _cc_refusal(b_ref)
        e2 = _cc_refusal(b_ref)
        @test e1 isa ErrorException && e2 isa ErrorException
        @test e1.msg == e2.msg
        b_ok = _cc_mk("$_CC_PAD9, isCode")
        (t1, o1) = GM.outputs(GM.goMeta(b_ok))
        (t2, o2) = GM.outputs(GM.goMeta(b_ok))
        @test t1 == t2
        @test o1 == o2
    end
end
