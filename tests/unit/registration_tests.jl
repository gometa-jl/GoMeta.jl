# tests/unit/registration_tests.jl — v0.2 registration build: the registration record + the
# clash law + the atomic load-time refusals (APPEND-ONLY).
#
# IS:   the witnesses of the DECLARED registration machinery: the clash law
#       (both arms behind the disposition switch — the terminal disposition itself
#       is the owner's owed confirmation), the reflection cross-check
#       (verify-not-derive: declared ≡ executable, both directions), the
#       value-algebra + reachability refusals, the unactivated-candidacy
#       diagnostic, ATOMICITY (a failing build leaves no partial registry), the
#       operator-token spelling parity, the commissioned capability
#       consults, and the dispatch-boundary RETURN-TYPE validation rows (the
#       declared return types verified against real invocations).
# PURPOSE: plan row 11's gate — "registration + atomicity tests green".

using Test
import GoMeta as GM

@testset "the registration build — record + clash law" begin

    _mkspec(name, plugin; spelling = :identifier) = GM.ActionSpec(
        name, spelling, Int8(plugin),
        [GM.ActionOverload(Type[GM.Alterants.Visib, Symbol], Symbol[], Symbol[],
            nothing, Bool, :set, false, :context_free, :apply, true)],
        0, :none, nothing, nothing)

    @testset "test_clash_check_always_fires — both arms behind the one-line switch" begin
        dup = [_mkspec(:alpha, 1), _mkspec(:alpha, 2)]
        # ARM R (refusal — the LIVE arm): the typed refusal names BOTH owners
        eR = try
            GM._register_actions!(Dict{Symbol,Int8}(), dup; disposition = :refuse)
            nothing
        catch er; er end
        @test eR isa ErrorException
        @test occursin("duplicate alterant action name", eR.msg)
        @test occursin("plugin index 1", eR.msg) && occursin("plugin index 2", eR.msg)
        @test occursin("remedy", eR.msg)
        # ARM W (warning + deterministic FIRST-writer-wins): the check still fires
        # (the warning names both owners) and the FIRST declaration survives
        owners = @test_logs (:warn, r"duplicate alterant action name.*first.*wins"i) begin
            GM._register_actions!(Dict{Symbol,Int8}(), dup; disposition = :warn)
        end
        @test owners[:alpha] == Int8(1)
        # the clean fill assigns declaration-order owners (the retired interim
        # assert's positive half, carried forward)
        m = GM._register_actions!(Dict{Symbol,Int8}(),
            [_mkspec(:a, 1), _mkspec(:b, 2)]; disposition = :refuse)
        @test m[:a] == Int8(1) && m[:b] == Int8(2)
    end

    @testset "test_operator_token_spelling — ad-4: identical collision checks over both kinds" begin
        dup = [_mkspec(Symbol(":"), 1; spelling = :operator),
               _mkspec(Symbol(":"), 2; spelling = :operator)]
        eO = try
            GM._register_actions!(Dict{Symbol,Int8}(), dup; disposition = :refuse)
            nothing
        catch er; er end
        @test eO isa ErrorException && occursin("duplicate alterant action name", eO.msg)
        # the live record declares the colon action with the OPERATOR tag
        colon_spec = GM.DEFAULT_REGISTRY.action_specs[
            GM.DEFAULT_REGISTRY.spec_index[Symbol(":")]]
        @test colon_spec.spelling === :operator
    end

    @testset "the reflection cross-check — declared ≡ executable, both directions" begin
        # (a) declared-but-unimplemented refuses: a spec declaring a signature no
        # method carries
        ghost = GM.ActionSpec(:ghost, :identifier, Int8(2),
            [GM.ActionOverload(Type[GM.Alterants.Visib, Symbol, Float64],
                Symbol[], Symbol[], nothing, Bool, :set, false,
                :context_free, :apply, true)],
            0, :none, nothing, nothing)
        eA = try
            GM._reflection_cross_check([ghost], GM.DEFAULT_REGISTRY.plugins)
            nothing
        catch er; er end
        @test eA isa ErrorException && occursin("no executable method", eA.msg)
        # (b) implemented-but-undeclared raises the loud drift refusal: declaring
        # ONLY the Symbol overload of setVisib leaves the inherited SubString method
        # unmatched
        partial = [_mkspec(:hide, 2)]
        eB = try
            GM._reflection_cross_check(partial, GM.DEFAULT_REGISTRY.plugins)
            nothing
        catch er; er end
        @test eB isa ErrorException && occursin("no declared overload", eB.msg)
        # (c) kind/type agreement: a :symbol kind against an AbstractString slot
        bad = GM.ActionSpec(:head, :identifier, Int8(4),
            [GM.ActionOverload(Type[GM.Alterants.Heading, Symbol, AbstractString],
                Symbol[:symbol], Symbol[:declared], nothing, Nothing, :set,
                false, :context_required, :absorb, true)],
            1, :activated, nothing, nothing)
        eC = try
            GM._reflection_cross_check([bad], GM.DEFAULT_REGISTRY.plugins)
            nothing
        catch er; er end
        @test eC isa ErrorException && occursin("literal-kind/type disagreement", eC.msg)
        # …and the LIVE inventory passes the whole chain (it built — but assert
        # directly so the witness is self-contained)
        @test GM._reflection_cross_check(GM.DEFAULT_REGISTRY.action_specs,
            GM.DEFAULT_REGISTRY.plugins) === nothing
    end

    @testset "test_value_algebra_refusal + test_reachability_refusal" begin
        badrt = GM.ActionSpec(:bad, :identifier, Int8(2),
            [GM.ActionOverload(Type[GM.Alterants.Visib, Symbol], Symbol[],
                Symbol[], nothing, Vector{UInt8}, :set, false,
                :context_free, :apply, true)],
            0, :none, nothing, nothing)
        eV = try GM._value_algebra_check([badrt]); nothing catch er; er end
        @test eV isa ErrorException && occursin("closed", eV.msg) &&
              occursin("serializable", eV.msg)
        badk = GM.ActionSpec(:bad, :identifier, Int8(2),
            [GM.ActionOverload(Type[GM.Alterants.Visib, Symbol, Any],
                Symbol[:integer], Symbol[:declared], nothing, Bool, :set, false,
                :context_free, :apply, true)],
            0, :none, nothing, nothing)
        eK = try GM._reachability_check([badk]); nothing catch er; er end
        @test eK isa ErrorException && occursin("unreachable", eK.msg)
        # internal (grammar=false) rows are OUTSIDE the reachability law
        internal = GM.ActionSpec(:inherited_row, :identifier, Int8(2),
            [GM.ActionOverload(Type[GM.Alterants.Visib, SubString{String}],
                Symbol[:raw], Symbol[:declared], nothing, Bool, :set, false,
                :context_free, :apply, false)],
            0, :none, nothing, nothing)
        @test GM._reachability_check([internal]) === nothing
    end

    @testset "test_unactivated_candidacy_diagnostic — x-8, loud not silent" begin
        cand = GM.ActionSpec(:wish, :identifier, Int8(2),
            [GM.ActionOverload(Type[GM.Alterants.Visib, Symbol], Symbol[],
                Symbol[], nothing, Bool, :set, false, :context_free, :apply, true)],
            0, :candidate, nothing, nothing)
        @test_logs (:warn, r"sugar CANDIDACY without user activation") GM._candidacy_check([cand])
        # the LIVE register stays closed at exactly TWO activated grants
        activated = [s.name for s in GM.DEFAULT_REGISTRY.action_specs
                     if s.sugar_candidacy === :activated]
        @test sort(activated) == sort([Symbol(":"), :head])
    end

    @testset "atomicity — checks precede construction; the record is total" begin
        # HONESTLY RE-SCOPED (a review round graded the first version vacuous for
        # its named property — the standalone check call never touched the const):
        # atomicity here is STRUCTURAL — every check runs before the registry
        # constructor, so no partial registry can exist — witnessed by a
        # source-ORDER assertion (crude but discriminating against a reordering
        # regression), plus the refusal-throws half and the record-totality half.
        src = read(joinpath(dirname(dirname(@__DIR__)), "src", "alterants",
            "registry.jl"), String)
        body = src[findfirst("function build_default_registry", src)[1]:end]
        body = body[1:findfirst("return AlterantRegistry", body)[1]]
        for checkname in ("_register_actions!", "_record_wellformed_check",
                          "_reflection_cross_check", "_value_algebra_check",
                          "_reachability_check", "_candidacy_check",
                          "_first_wins_spec_index")   # the USE-SITE wiring pinned
                                                      # (delta-caught: reverting to
                                                      # a naive comprehension was
                                                      # battery-invisible)
            @test occursin(checkname, body)   # every check sits BEFORE the constructor
        end
        # a failing check THROWS (nothing constructed) …
        dup = [_mkspec(:alpha, 1), _mkspec(:alpha, 2)]
        @test (try
            GM._register_actions!(Dict{Symbol,Int8}(), dup; disposition = :refuse)
            false
        catch; true end)
        # … and the LIVE record is total: every registered action has its spec
        for a in GM.DEFAULT_REGISTRY.sorted_alt_actions
            @test haskey(GM.DEFAULT_REGISTRY.spec_index, a)
        end
    end

    @testset "arm-W consistency — spec_index is FIRST-writer-wins (the convergent cure)" begin
        dup = [_mkspec(:alpha, 1), _mkspec(:alpha, 2), _mkspec(:beta, 2)]
        idx = GM._first_wins_spec_index(dup)
        @test idx[:alpha] == 1                 # the FIRST declaration — matching
        @test idx[:beta] == 3                  # the arm-W owner survivor
        owners = @test_logs (:warn, r"duplicate") begin
            GM._register_actions!(Dict{Symbol,Int8}(), dup; disposition = :warn)
        end
        @test owners[:alpha] == Int8(dup[idx[:alpha]].plugin)   # index ≡ owner tables
    end

    @testset "the record shape law — closed enums refuse loudly (panel cure)" begin
        typo = GM.ActionSpec(:oops, :identifer, Int8(2),      # mis-spelled tag
            [GM.ActionOverload(Type[GM.Alterants.Visib, Symbol], Symbol[],
                Symbol[], nothing, Bool, :set, false, :context_free, :apply, true)],
            0, :none, nothing, nothing)
        eT = try GM._record_wellformed_check([typo], GM.DEFAULT_REGISTRY.plugins); nothing catch er; er end
        @test eT isa ErrorException && occursin("unknown spelling tag", eT.msg)
        # queryable=true without a plugin getter refuses (the query-seam crash class)
        qbad = GM.ActionSpec(:qbad, :identifier, Int8(2),
            [GM.ActionOverload(Type[GM.Alterants.Visib, Symbol], Symbol[],
                Symbol[], nothing, Bool, :set, true, :context_free, :apply, true)],
            0, :none, nothing, nothing)
        eQ = try GM._record_wellformed_check([qbad], GM.DEFAULT_REGISTRY.plugins); nothing catch er; er end
        @test eQ isa ErrorException && occursin("no getter", eQ.msg)
        # the LIVE inventory is wellformed
        @test GM._record_wellformed_check(GM.DEFAULT_REGISTRY.action_specs,
            GM.DEFAULT_REGISTRY.plugins) === nothing
        # the live disposition switch is the refusal arm (this pin flips WITH the
        # owner's ad-6 ruling — deliberately)
        @test GM._CLASH_DISPOSITION === :refuse
    end

    @testset "the commissioned capability consults — literals retired" begin
        # the head spec carries the accepting slot + the validate seam
        hs = GM.DEFAULT_REGISTRY.action_specs[GM.DEFAULT_REGISTRY.spec_index[:head]]
        @test hs.accepts_string_slot == 1
        @test hs.validate === GM.Alterants._heading_validate_text
        @test all(ov.phase === :absorb for ov in hs.overloads)
        # behavior THROUGH the record is unchanged: the slot law + validation
        r = GM.goMeta(Vector{UInt8}(codeunits("#~ \"T\"\nx = 1\n")))
        @test any(a === :head_1 for (_, a, _, _) in GM.altValues_evals(r))
        eq = try
            GM.goMeta(Vector{UInt8}(codeunits("#~ head(\"T\", \"2\")\nx = 1\n")))
            nothing
        catch er; er end
        @test eq isa ErrorException && occursin("string argument not accepted", eq.msg)
        ee = try
            GM.goMeta(Vector{UInt8}(codeunits("#~ \"\"\nx = 1\n")))
            nothing
        catch er; er end
        @test ee isa ErrorException && occursin("empty heading text", ee.msg)
        # the delivery path carries no hard-coded action/plugin literal (the
        # retirement grep-witness — the mode divert + spec consults only)
        src = read(joinpath(dirname(dirname(@__DIR__)), "src", "absorb",
            "absorb_meta.jl"), String)
        fn = src[findfirst("function _absorb_local_only!", src)[1]:end]
        fn = fn[1:findfirst("\nend\n", fn)[1]]
        @test !occursin("=== :head", fn) && !occursin("_heading_validate_text(", fn)
    end

    @testset "dispatch-boundary return-type validation — declared ≡ measured" begin
        # every GRAMMAR overload's declared return type matches a REAL invocation
        # (the value algebra's ground truth; per-plugin representative calls)
        @test typeof(GM.Alterants.setLabels(Dict{Symbol,Bool}(), Symbol(":"), :label1)) === Nothing
        @test typeof(GM.Alterants.setVisib(GM.Alterants.Visib(), :hide)) === Bool
        @test typeof(GM.Alterants.setId(GM.Alterants.Id(), :cell, Symbol("7"))) === Int16
        @test typeof(GM.Alterants.setHead(GM.Alterants.Heading(), :head, "T")) === Nothing
        @test typeof(GM.Alterants.setHead(GM.Alterants.Heading(), :head, "T", Symbol("2"))) === Nothing
        # …and each matches its DECLARED row — EVERY spec incl. the remaining
        # grammar rows and the internal (inherited-shape) rows (panel-found
        # coverage gap: representatives only left :show/:discard/:parent/:file and
        # both SubString rows unmeasured)
        for (name, fn, args) in ((Symbol(":"), GM.Alterants.setLabels, (Dict{Symbol,Bool}(), Symbol(":"), :label1)),
                                 (:hide, GM.Alterants.setVisib, (GM.Alterants.Visib(), :hide)),
                                 (:show, GM.Alterants.setVisib, (GM.Alterants.Visib(), :show)),
                                 (:discard, GM.Alterants.setVisib, (GM.Alterants.Visib(), :discard)),
                                 (:cell, GM.Alterants.setId, (GM.Alterants.Id(), :cell, Symbol("7"))),
                                 (:parent, GM.Alterants.setId, (GM.Alterants.Id(), :parent, Symbol("8"))),
                                 (:file, GM.Alterants.setId, (GM.Alterants.Id(), :file, Symbol("9"))),
                                 (:head, GM.Alterants.setHead, (GM.Alterants.Heading(), :head, "T", Symbol("2"))))
            spec = GM.DEFAULT_REGISTRY.action_specs[GM.DEFAULT_REGISTRY.spec_index[name]]
            @test typeof(fn(args...)) in [ov.return_type for ov in spec.overloads]
        end
        # the internal (grammar=false) inherited rows, measured too
        @test typeof(GM.Alterants.setVisib(GM.Alterants.Visib(),
            SubString{String}("hide"))) === Bool
        @test typeof(GM.Alterants.setId(GM.Alterants.Id(),
            SubString{String}("cell"), SubString{String}("7"))) === Int16
    end

    # ── the FULL-ARMING witnesses (the arming continuation: the declared record now
    # guards every live set invocation at the sole seam) ────────────────────────────────
    @testset "full arming — the set-invocation guard consults the record" begin
        _reg = GM.DEFAULT_REGISTRY
        _err(f) = (try f(); nothing catch e; e end)

        @testset "test_dispatch_target_uniqueness_law" begin
            # the external-review-commissioned law: per action, at most ONE
            # Symbol-addressable declared row per reachable arity — the guard's
            # arity-compatible set is a singleton, so dispatch can never select a
            # form-rejected row and the return guard checks the selected row's own
            # declaration. The check runs inside _record_wellformed_check.
            _plugs = GM.DEFAULT_REGISTRY.plugins
            _row(sig; vk = nothing) = GM.ActionOverload(sig, Symbol[], Symbol[],
                vk, Bool, :set, false, :context_free, :apply, true)
            _spec2(rows) = [GM.ActionSpec(:zz, :identifier, Int8(2), rows,
                0, :none, nothing, nothing)]
            # two fixed rows, SAME arity ⇒ refuse ( _err = the enclosing testset's)
            e = _err(() -> GM._record_wellformed_check(_spec2(
                [_row(Type[GM.Alterants.Visib, Symbol, Symbol]),
                 _row(Type[GM.Alterants.Visib, Symbol, Any])]), _plugs))
            @test e isa ErrorException && occursin("uniqueness law", e.msg)
            # a fixed row at/above a vararg base ⇒ refuse (the vararg covers it)
            e = _err(() -> GM._record_wellformed_check(_spec2(
                [_row(Type[GM.Alterants.Visib, Symbol]; vk = :symbol),
                 _row(Type[GM.Alterants.Visib, Symbol, Symbol])]), _plugs))
            @test e isa ErrorException && occursin("uniqueness law", e.msg)
            # two vararg rows always overlap ⇒ refuse
            e = _err(() -> GM._record_wellformed_check(_spec2(
                [_row(Type[GM.Alterants.Visib, Symbol]; vk = :symbol),
                 _row(Type[GM.Alterants.Visib, Symbol, Symbol]; vk = :symbol)]),
                _plugs))
            @test e isa ErrorException && occursin("uniqueness law", e.msg)
            # DISJOINT arities pass; a non-addressable (inherited-shape) row never
            # collides with an addressable one — the SHIPPED record is the standing
            # positive witness (build_default_registry runs the chain and is green)
            @test GM._record_wellformed_check(_spec2(
                [_row(Type[GM.Alterants.Visib, Symbol, Symbol]),
                 _row(Type[GM.Alterants.Visib, Symbol, Any, Any])]), _plugs) === nothing
            # a fixed row STRICTLY BELOW a vararg base passes (the law's green side
            # for the mixed pair — delta-commissioned witness)
            @test GM._record_wellformed_check(_spec2(
                [_row(Type[GM.Alterants.Visib, Symbol]),
                 _row(Type[GM.Alterants.Visib, Symbol, Symbol]; vk = :symbol)]),
                _plugs) === nothing
            @test GM._record_wellformed_check(_spec2(
                [_row(Type[GM.Alterants.Visib, Symbol, Symbol]),
                 _row(Type[GM.Alterants.Visib, SubString{String}, Symbol])]),
                _plugs) === nothing
        end

        @testset "test_kind_type_shared_map_total" begin
            # total over the closed kind set — the one map both consults share
            @test GM._kind_type(:symbol) === Symbol
            @test GM._kind_type(:string) === AbstractString
            @test GM._kind_type(:raw)    === SubString{String}
            e = _err(() -> GM._kind_type(:nope))
            @test e isa ErrorException && occursin("unknown literal kind", e.msg)
        end

        @testset "test_user_arity_convention" begin
            # the (alterant, actionName) preamble convention, pinned against real rows
            head = _reg.action_specs[_reg.spec_index[:head]]
            @test GM._user_arity(head.overloads[1]) == 1     # deriving: (text)
            @test GM._user_arity(head.overloads[2]) == 2     # explicit: (text, level)
            labels = _reg.action_specs[_reg.spec_index[Symbol(":")]]
            @test GM._user_arity(labels.overloads[1]) == 0   # vararg tail only
        end

        @testset "test_unregistered_action_refusal" begin
            e = _err(() -> GM._invoke_set(_reg, GM.Alterants.setVisib,
                GM.Alterants.Visib(), :nope, ()))
            @test e isa ErrorException && occursin("unregistered alterant action", e.msg)
        end

        @testset "test_arity_refusal_typed_not_methoderror" begin
            # :hide declares ZERO user args (the internal SubString row is unreachable
            # from the Symbol-actionName seam and must not widen the envelope)
            e = _err(() -> GM._invoke_set(_reg, GM.Alterants.setVisib,
                GM.Alterants.Visib(), :hide, (:x,)))
            @test e isa ErrorException && occursin("invalid arguments", e.msg) &&
                  occursin("no declared form", e.msg)
        end

        @testset "test_form_refusal_declared_kind_on_untyped_slot" begin
            # :head explicit level slot is `Any` in the signature — the DECLARED
            # :symbol kind is the only law there; a String level must refuse
            e = _err(() -> GM._invoke_set(_reg, GM.Alterants.setHead,
                GM.Alterants.Heading(), :head, ("Title", "2")))
            @test e isa ErrorException && occursin("invalid arguments", e.msg)
        end

        @testset "test_pass_paths_still_deliver" begin
            v = GM.Alterants.Visib()
            @test GM._invoke_set(_reg, GM.Alterants.setVisib, v, :hide, ()) === nothing
            h = GM.Alterants.Heading()
            @test GM._invoke_set(_reg, GM.Alterants.setHead, h, :head,
                ("Title", Symbol("2"))) === nothing
            @test h.entries == [("Title", 2)]
            d = Dict{Symbol,Bool}()
            @test GM._invoke_set(_reg, GM.Alterants.setLabels, d, Symbol(":"),
                (:label1, :label2)) === nothing        # the vararg tail, kind-checked
            @test haskey(d, :label1) && haskey(d, :label2)
        end

        @testset "test_value_arm_survives_as_backstop" begin
            # arity+form PASS (a Symbol in the id slot is the declared form); the VALUE
            # fails at parse — the stable catalogued refusal, not a raw ArgumentError
            e = _err(() -> GM._invoke_set(_reg, GM.Alterants.setId,
                GM.Alterants.Id(), :cell, (Symbol("xx"),)))
            @test e isa ErrorException && occursin("invalid arguments", e.msg) &&
                  occursin("ArgumentError", e.msg)
        end

        @testset "test_drift_and_return_guard_internal_arms" begin
            # a hand-built registry BYPASSES the load-time check chain on purpose. The
            # two arms differ in reachability (panel-trued): the MethodError-drift arm
            # is unreachable through `build_default_registry` (the (a) cross-check
            # refuses a declared-but-unimplemented signature first) — the bypass is the
            # only road to it. The RETURN-guard arm is a LIVE production wall: the
            # load-time checks verify the DECLARED return type's membership and the
            # signature's existence, never the setter's actual return behavior — a
            # setter lying about its return type passes load fully and is caught ONLY
            # here (the dispatch-boundary tests measure the four SHIPPED setters, which
            # is a test-time fact, not a load-time refusal).
            _mini(specs) = GM.AlterantRegistry(GM.PlugIn[], Symbol[], Int8[],
                Dict{Symbol,Int8}(), Dict{Symbol,Int8}(), Int8[], Int8[],
                Dict{Symbol,Symbol}(), specs, GM._first_wins_spec_index(specs))
            _row(sig, rt) = GM.ActionOverload(sig, Symbol[], Symbol[], nothing, rt,
                :set, false, :context_free, :apply, true)
            # (1) declared-but-unimplemented shape ⇒ the pre-checks pass, dispatch
            # MethodErrors ⇒ the INTERNAL drift error (never the stranger refusal)
            _narrow(v::GM.Alterants.Visib, n::Symbol) = true
            drifted = _mini([GM.ActionSpec(:zz, :identifier, Int8(1),
                [_row(Type[GM.Alterants.Visib, Symbol, Symbol], Bool)],
                0, :none, nothing, nothing)])
            e = _err(() -> GM._invoke_set(drifted, _narrow,
                GM.Alterants.Visib(), :zz, (:a,)))
            @test e isa ErrorException &&
                  occursin("internal invariant violated", e.msg) &&
                  occursin("drift", e.msg)
            # (2) an off-declaration RETURN ⇒ the value-algebra guard at the live seam
            _lies(v::GM.Alterants.Visib, n::Symbol) = Int64(7)   # declares Bool below
            lying = _mini([GM.ActionSpec(:zz, :identifier, Int8(1),
                [_row(Type[GM.Alterants.Visib, Symbol], Bool)],
                0, :none, nothing, nothing)])
            e = _err(() -> GM._invoke_set(lying, _lies, GM.Alterants.Visib(), :zz, ()))
            @test e isa ErrorException &&
                  occursin("internal invariant violated", e.msg) &&
                  occursin("DECLARED return type", e.msg)
        end
    end
end
