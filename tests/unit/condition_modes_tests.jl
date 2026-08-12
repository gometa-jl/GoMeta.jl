# tests/unit/condition_modes_tests.jl — the dual-mode DUAL-MODE law (safe default + opt-in).
#
# IS:   the shipped pin of the ruling: "Next to the restricted / safe parser there MUST be an
#       OPT-IN to use the FULL Julia parser … BOTH MUST BE AVAILABLE." Two laws are pinned
#       together and neither may drift: (1) the default is CLOSED and stays closed even after
#       the opt-in extension is loaded; (2) the opt-in EXISTS and is reachable — by two
#       explicit OPERATOR acts, never by document content.
# DOES: [M1] the closed default + the mode field · [M2] the two-act law (naming an opt-in
#       profile without the extension REFUSES, naming an unknown profile refuses differently)
#       · [M3] after the explicit include: both opt-in modes resolve, and both produce
#       BYTE-IDENTICAL output to the closed mode on shared input (opting in widens accepted
#       TEXT, never changes what an existing document MEANS) · [M4] the full-parse mode
#       accepts what the closed grammar refuses while still executing NOTHING · [M5] the
#       full-eval mode is a STRICT SUPERSET (safe grammar first, evaluation only beyond it).
# PURPOSE: the user's dual-mode ruling, mechanically enforced from here on.

using Test
import GoMeta as GM

const _MODES_DOC = "#~1 :label1 hide{ :label1 }\n# a region\n"
_mode_run(cfg) = redirect_stdout(
    () -> GM.goMeta(Vector{UInt8}(codeunits(_MODES_DOC)); config = cfg), devnull)

@testset "condition MODES — the dual-mode dual-mode law (safe default + explicit opt-in)" begin

    @testset "M1 :: the default is the CLOSED safe intake" begin
        prof = GM.resolve_profile(GM.GoMetaConfig())
        @test prof.mode === :closed_v1
        @test GM.parse_condition("cell(a . b) ") isa GM.Diagnostic   # a safe-grammar refusal
    end

    @testset "M2 :: the TWO-ACT law — naming a mode is not opting in" begin
        for p in (:jl_share_v1_full_parse, :jl_share_v1_full_eval)
            # the config guard ACCEPTS the name (it is a real profile) …
            @test isempty(GM.validate_config(GM.GoMetaConfig(profile = p)))
            # … but resolution REFUSES until the operator includes the extension, and the
            # refusal NAMES the required act (a dead end with no instructions is a defect)
            err = try GM.resolve_profile(GM.GoMetaConfig(profile = p)); nothing catch e; e end
            @test err isa ErrorException
            @test occursin("OPT-IN mode", err.msg) &&
                  occursin("condition_modes_opt_in.jl", err.msg)
        end
        # an unknown profile is a DIFFERENT (config-time) refusal — the two must not merge
        d = GM.validate_config(GM.GoMetaConfig(profile = :nope))
        @test !isempty(d) && d[1].code === :ERR_UNKNOWN_PROFILE
    end

    @testset "M3 :: after the explicit include — both modes live; the M-law holds on this corpus" begin
        # SCOPE (review-found; an earlier title claimed blanket semantics-identity): the law
        # is pinned on THIS document corpus. TWO divergence classes on closed-ACCEPTED text
        # are KNOWN and recorded OPEN: (1) the full-parse mode DROPS a settribute call's
        # arguments where the closed scanner PENDS them (K3 leak) — verdict-inert on the
        # current registry, divergent in decision records; the in-repo record is the K3
        # register note in src/condition.jl's header plus the extension's settribute-call
        # arm comment; (2) the full-parse mode REFUSES the word-less label-paren forms
        # (':(:label1)', ':()') the closed default accepts — surfaced at the K6-retirement
        # reconfirm, pinned at its current fate in M6's boundary rows. This corpus
        # contains neither class.
        ext = joinpath(@__DIR__, "..", "..", "extensions", "condition_modes_opt_in.jl")
        @test isfile(ext)                       # the opt-in ships (the ruling: BOTH available)
        redirect_stdout(() -> Base.include(Main, abspath(ext)), devnull)
        base = _mode_run(GM.GoMetaConfig())
        @test base.status == GM.PROCESS_OK
        for p in (:jl_share_v1_full_parse, :jl_share_v1_full_eval)
            prof = GM.resolve_profile(GM.GoMetaConfig(profile = p))
            @test prof.mode !== :closed_v1
            r = _mode_run(GM.GoMetaConfig(profile = p))
            @test r.status == GM.PROCESS_OK
            # THE LAW: opting in must not change what an existing document MEANS
            @test GM.outputs(r).blsStructure_bytes == GM.outputs(base).blsStructure_bytes
            @test GM.outputs(r).render_bytes == GM.outputs(base).render_bytes
        end
        # and the DEFAULT is untouched by the extension being loaded (no ambient widening)
        @test GM.resolve_profile(GM.GoMetaConfig()).mode === :closed_v1
        @test GM.parse_condition("cell(a . b) ") isa GM.Diagnostic
    end

    @testset "M4 :: :full_julia_parse_v1 — wider ACCEPTANCE, zero execution" begin
        prof = GM.resolve_profile(GM.GoMetaConfig(profile = :jl_share_v1_full_parse))
        fn = GM.condition_mode_fn(prof.mode)
        # shapes the closed grammar refuses at intake are ACCEPTED here …
        for body in ("isCode & isText", "!isCode", ":label1", "isCode, :label1")
            @test fn(body, GM.DEFAULT_REGISTRY, prof) isa GM.ConditionAST
        end
        # … but only the engine's own algebra survives the whitelist: code shapes REFUSE,
        # and the sentinel proves nothing ran
        @eval Main const __gometa_mode_sentinel__ = Ref(false)
        for body in ("run(`touch /tmp/gometa_mode_probe`)",
                     "Main.__gometa_mode_sentinel__[] = true",
                     "ccall(:system, Cint, (Cstring,), \"id\")")
            @test fn(body, GM.DEFAULT_REGISTRY, prof) isa GM.Diagnostic
        end
        @test Main.__gometa_mode_sentinel__[] === false
        @test fn("nosuchkey", GM.DEFAULT_REGISTRY, prof) isa GM.Diagnostic   # closed vocabulary
    end

    @testset "M5 :: :full_eval_v1 — a STRICT SUPERSET of the safe grammar" begin
        prof = GM.resolve_profile(GM.GoMetaConfig(profile = :jl_share_v1_full_eval))
        fn = GM.condition_mode_fn(prof.mode)
        # every safe-grammar-accepted body HERE returns the SAFE AST itself (NOT an eval
        # marker) — identical semantics for these bodies; the known K3-leak divergence
        # class is recorded OPEN and pinned nowhere as identical
        for body in ("isCode & isText", ":label1", "cell(:label1) ", "isCode && isText")
            r = fn(body, GM.DEFAULT_REGISTRY, prof)
            @test r isa GM.ConditionAST
            @test GM.print_condition(r) == GM.print_condition(GM.parse_condition(body))
        end
        # RIDER B's PURPOSE, pinned: text the non-executing rung can handle must NOT reach
        # the executing rung. A SETTRIBUTE key used as a call (isCode(ab)) was the class that
        # falsified this — unlowerable by that rung, it fell through to execution, so reach
        # GREW for it where the pre-cure engine had evaluated nothing at all.
        for body in ("isCode(ab) ", "comment(xy) ", "isCode(ab) & cell ")
            @test !(fn(body, GM.DEFAULT_REGISTRY, prof) isa GM.FullEvalCondition)
        end
        # …while a PARTIAL lowering (one still carrying a raw argument) must still reach it —
        # the operator opted into this mode precisely to have such text evaluated.
        for body in ("cell(myvar) ", "cell(xy) ")
            @test fn(body, GM.DEFAULT_REGISTRY, prof) isa GM.FullEvalCondition
        end
        # THE RAW-BYTE WALL BINDS ON THE EXECUTING RUNG TOO. Rungs 1 and 2 only return on
        # SUCCESS, so their cap refusals used to fall through to UNBOUNDED evaluation —
        # byte-confirmed on a 5008-byte body before this was closed.
        toolong = "cell(:" * repeat("a", 5000) * ") "
        d = fn(toolong, GM.DEFAULT_REGISTRY, prof)
        @test d isa GM.Diagnostic && d.code === :ERR_CONDITION_CAP
        # HONEST REACH: against the pre-v0.2 engine this mode executes MORE, not less — that
        # engine refused unknown vocabulary at its own scan and evaluated nothing for it.
        # This is the intended un-restriction; it is pinned so the header's
        # (corrected) statement of it cannot drift back.
        for body in ("rm(\"x\") ", "run(`id`) ")
            @test fn(body, GM.DEFAULT_REGISTRY, prof) isa GM.FullEvalCondition
        end
        # only BEYOND the safe grammar does the eval hatch engage (the marker type)
        @test fn("1 == 1", GM.DEFAULT_REGISTRY, prof) isa GM.FullEvalCondition
        # THE MARKER IS A CONDITION CARRIER LIKE ANY OTHER: every consumer of the carried
        # type must accept it. The apply phase renders EVERY carried condition into its
        # decision records, so a missing renderer method aborted an opt-in run as soon as
        # those records were collected (review-found, byte-confirmed). The method itself is
        # the defect and is pinned directly; its canonical form is the source text, the only
        # faithful rendering for a mode that never lowers the text into the closed algebra.
        @test GM.print_condition(GM.FullEvalCondition("1 == 1")) == "1 == 1"
        # and text that neither the safe grammar nor Julia accepts is still a typed refusal
        # (totality is NOT relaxed by opting in). NB `a &&& b` DOES parse in Julia — the
        # probe that taught this row — so the witness must be genuinely unparseable.
        for bad in ("a )( b", "(", "a ? ")
            @test fn(bad, GM.DEFAULT_REGISTRY, prof) isa GM.Diagnostic
        end
    end

    @testset "M6 :: THE LADDER LAW — where a safe-rung narrowing sends the affected inputs" begin
        # External review finding on the retirement of the one-character drop, byte-confirmed:
        # rung 1's refusals ADVANCE to rung 2, and reach HOST EVALUATION only when rung 2
        # cannot lower them completely — both outcomes occurred across the retirements so
        # far (one-char class → rung 3 and EXECUTED; wall-truncation class → rung 2 as
        # DATA; label-paren-discard class (K6, retired at the stage-2 close) → rung 3
        # and EXECUTED).
        # A second external lens corrected the earlier universal wording ("a narrowing
        # widens execution reach"), which this file's own rows falsify. These rows PIN
        # today's reach for REPRESENTATIVE members of each affected class: a narrowing that
        # moves a PINNED member trips this test; one that moves only UNPINNED members of a
        # class passes — a tripwire, not a coverage proof. The exhaustive form (a generated
        # per-input reach ledger, committed and diffed) is recorded as the follow-on.
        # Rung is distinguished by TYPE:
        # FullEvalCondition == rung 3 (executes at evaluate time); ConditionAST == data.
        cap = GM.DEFAULT_GRAMMAR_PROFILE.inner_scan_cap
        # the retired one-char class REACHES EXECUTION in the executing mode (the widening) …
        for body in ("cell(x)", "cell(7)", "cell(:)")
            @test _optin_full_eval(body, GM.DEFAULT_REGISTRY, GM.DEFAULT_GRAMMAR_PROFILE) isa
                  GM.FullEvalCondition
            # … while the NON-executing full-syntax mode carries the same text as DATA
            @test _optin_full_parse(body, GM.DEFAULT_REGISTRY, GM.DEFAULT_GRAMMAR_PROFILE) isa
                  GM.ConditionAST
        end
        # the retired wall-truncation class did NOT shift: complete lowering, data everywhere
        for body in (":" * repeat("a", cap), ":" * repeat("a", cap + 1))
            @test _optin_full_eval(body, GM.DEFAULT_REGISTRY, GM.DEFAULT_GRAMMAR_PROFILE) isa
                  GM.ConditionAST
            @test _optin_full_parse(body, GM.DEFAULT_REGISTRY, GM.DEFAULT_GRAMMAR_PROFILE) isa
                  GM.ConditionAST
        end
        # the retired label-paren-discard class (K6, retired at the stage-2 close)
        # REACHES EXECUTION in the
        # executing mode: the full-syntax rung cannot lower a call on a quoted symbol —
        # Meta.parse(":abc(:label1)") is (:abc)(:label1), a :call whose CALLEE slot
        # (args[1]) is a QuoteNode, outside the whitelist — so the input falls through to
        # rung 3, where host evaluation of the quoted-symbol call raises a MethodError at
        # apply time UNDER AN UNMODIFIED HOST (loud, per the executing rung's contract;
        # external-lens caveat, recorded: this mode executes document-supplied code, so a
        # document may first make the quoted-symbol type callable and the same form then
        # RESOLVES to a verdict — that is the executing mode's accepted threat model, not
        # a new capability of this class) …
        for body in (":abc(:label1)", ":abc()")
            @test _optin_full_eval(body, GM.DEFAULT_REGISTRY, GM.DEFAULT_GRAMMAR_PROFILE) isa
                  GM.FullEvalCondition
            # … while the NON-executing full-syntax mode refuses the shape as a typed
            # Diagnostic (data-rung refusal, nothing executed)
            @test _optin_full_parse(body, GM.DEFAULT_REGISTRY, GM.DEFAULT_GRAMMAR_PROFILE) isa
                  GM.Diagnostic
        end
        # boundary control: the WORD-LESS label-paren forms are NOT retired and never
        # leave the safe rung in the executing mode …
        for body in (":(:label1)", ":()")
            @test _optin_full_eval(body, GM.DEFAULT_REGISTRY, GM.DEFAULT_GRAMMAR_PROFILE) isa
                  GM.ConditionAST
            # … while the STANDALONE full-parse mode REFUSES these same forms the closed
            # default accepts (Meta.parse of ':(:label1)' is a quote wrapper no whitelist
            # arm lowers) — a SECOND known divergence class on closed-ACCEPTED text,
            # sibling of the K3 drop recorded in M3's scope note; recorded OPEN, pinned
            # here at its CURRENT fate so it cannot drift silently (review-found at the
            # K6 reconfirm; pre-existing, not introduced by the retirement)
            @test _optin_full_parse(body, GM.DEFAULT_REGISTRY, GM.DEFAULT_GRAMMAR_PROFILE) isa
                  GM.Diagnostic
        end
        # controls: in-grammar text lowers to the same closed DATA in both modes — the
        # executing mode via its safe rung, the standalone full-parse mode via its
        # whitelist (that mode has NO safe rung in its chain; an earlier revision of this
        # comment said "never leaves the safe rung in either mode" and asserted only one)
        for body in ("cell(:label1)", "isCode")
            @test _optin_full_eval(body, GM.DEFAULT_REGISTRY, GM.DEFAULT_GRAMMAR_PROFILE) isa
                  GM.ConditionAST
            @test _optin_full_parse(body, GM.DEFAULT_REGISTRY, GM.DEFAULT_GRAMMAR_PROFILE) isa
                  GM.ConditionAST
        end
    end

    @testset "M7 :: HEADING × executing rung — the reserved intersection (fresh-eyes cure)" begin
        # Under the opt-in executing profile, a HEADING condition that would EXECUTE
        # (text beyond the safe rung ⇒ a full-eval marker) meets a typed refusal:
        # the heading surface postdates the dual-mode ruling, and executing at the
        # absorb seam is a context the opt-in contract predates (its state reads
        # would see the previous apply's residue — the same hazard the query-atom
        # reservation closes). RESERVED, not defined — a compatible widening later.
        cfgE = GM.GoMetaConfig(profile = :jl_share_v1_full_eval)
        eh = try
            redirect_stdout(() -> GM.goMeta(
                Vector{UInt8}(codeunits("#~ \"T\"{ 1 + 1 == 2 }\nx = 1\n"));
                config = cfgE), devnull)
            nothing
        catch e; e end
        @test eh isa ErrorException && occursin("full-eval condition on a heading", eh.msg)
        # …while a SETTRIBUTE heading condition under the SAME profile still arrives
        # as closed DATA via the safe rung and works (the strict-superset law holds
        # on the heading surface too)
        rh = redirect_stdout(() -> GM.goMeta(
            Vector{UInt8}(codeunits("#~ \"T\"{ isMeta }\nx = 1\n"));
            config = cfgE), devnull)
        @test string(rh.status) == "PROCESS_OK"
        @test any(a === :head_1 for (_, a, _, _) in GM.altValues_evals(rh))
        # …and a QUEUED action's executing condition keeps the mode's full
        # contracted behavior (the reservation is heading-scoped, not mode-wide) —
        # DISCRIMINATED at the render (delta-seat cure: PROCESS_OK alone could not
        # tell execution from a silently dropped condition). Probed semantics: hide
        # renders the governed region COMMENTED OUT ('## ' prefix), it does not
        # remove it — the TRUE twin comments the region, the FALSE twin passes it
        # through verbatim
        rq = redirect_stdout(() -> GM.goMeta(
            Vector{UInt8}(codeunits("#~ hide{ 1 + 1 == 2 }\nx = 1\n"));
            config = cfgE), devnull)
        @test string(rq.status) == "PROCESS_OK"
        @test occursin("## x = 1", String(copy(GM.outputs(rq).render_bytes)))
        rqf = redirect_stdout(() -> GM.goMeta(
            Vector{UInt8}(codeunits("#~ hide{ 1 + 1 == 3 }\nx = 1\n"));
            config = cfgE), devnull)
        @test string(rqf.status) == "PROCESS_OK"
        @test String(copy(GM.outputs(rqf).render_bytes)) ==
              "#~ hide{ 1 + 1 == 3 }\nx = 1\n"
        # …and the wall holds on the EXPLICIT-canonical and userMH routes too
        # (delta-seat NIT; all routes funnel through the one delivery call site,
        # witnessed here so the funnel claim cannot drift silently)
        ec = try
            redirect_stdout(() -> GM.goMeta(
                Vector{UInt8}(codeunits("#~ head(\"T\", 2){ 1 + 1 == 2 }\nx = 1\n"));
                config = cfgE), devnull)
            nothing
        catch e; e end
        @test ec isa ErrorException && occursin("full-eval condition on a heading", ec.msg)
        eu = try
            redirect_stdout(() -> GM.goMeta(
                Vector{UInt8}(codeunits("x = 1\n"));
                config = GM.GoMetaConfig(profile = :jl_share_v1_full_eval,
                    user_mh_profile = "head(\"U\", 3){ 1 + 1 == 2 }")), devnull)
            nothing
        catch e; e end
        @test eu isa ErrorException && occursin("full-eval condition on a heading", eu.msg)
    end
end
