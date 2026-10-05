# tests/unit/registration_tests.jl — v0.2 registration build: the registration record + the
# runtime arming guard (APPEND-ONLY; the clash law with its disposition switch, the reflection
# cross-check, the value-algebra and reachability refusals, the candidacy diagnostic and the record
# shape law were CONSCIOUSLY RETIRED with their subjects at stage 5's E4 of the v0.4 build —
# census rows 3 and 51, OWNER-WORDS §317; the retirement notes stand where the testsets stood).
#
# IS:   the witnesses of the DECLARED registration record as the Engine still reads it: the
#       remaining checks wired at `validate` (source order), the FIRST-wins derived tables, the
#       operator-token spelling, the commissioned capability consults, the dispatch-boundary
#       RETURN-TYPE validation rows (the declared return types verified against real invocations)
#       and the full-arming guard at the set-invocation seam.
# PURPOSE: plan row 11's gate — "registration + atomicity tests green" (re-scoped at E4).

using Test
import GoMeta as GM

@testset "the registration build — the record + the remaining checks" begin

    # (test_clash_check_always_fires was CONSCIOUSLY RETIRED at stage 5's E4 of the v0.4 build with its
    # subject: the clash law and its disposition switch left — census rows 3 and 51, OWNER-WORDS §317;
    # a duplicate action name resolves FIRST-wins in `_derive_tables`, witnessed below.)

    @testset "test_operator_token_spelling — ad-4: the live record's operator tag" begin
        # (the clash arm over operator tokens left with the clash law at stage 5's E4)
        # the live record declares the colon action with the OPERATOR tag
        colon_spec = GM.DEFAULT_REGISTRY.action_specs[
            GM.DEFAULT_REGISTRY.spec_index[Symbol(":")]]
        @test colon_spec.spelling === :operator
    end

    # (the reflection cross-check testset was CONSCIOUSLY RETIRED at stage 5's E4 with its subject —
    # census row 3: a declared signature is the author's statement; a drifted one meets the live seam's
    # INTERNAL drift arm, witnessed in test_drift_and_return_guard_internal_arms below.)

    # (test_value_algebra_refusal + test_reachability_refusal were CONSCIOUSLY RETIRED at stage 5's E4
    # with their subjects — census row 3; the live seam's return-type guard stands, witnessed below.)

    @testset "the activated grants — the live register's two" begin
        # (the candidacy diagnostic left at stage 5's E4: a :candidate without activation publishes
        # silently — witnessed in registry_lifecycle_tests)
        # the LIVE register stays closed at exactly TWO activated grants
        activated = [s.name for s in GM.DEFAULT_REGISTRY.action_specs
                     if s.sugar_candidacy === :activated]
        @test sort(activated) == sort([Symbol(":"), :head])
    end

    @testset "the remaining checks precede construction; the record is total" begin
        # (re-scoped at stage 5's E4 — the validation chain of v0.4 T2–T4 left, census row 3, OWNER-WORDS
        # §317; the referents moved — recorded, not silently re-pinned) two source-order assertions:
        # (i) the three remaining collectors are wired inside `_validate_registration` and the retired
        # ones never return; (ii) `publish` calls `validate(` before `return AlterantRegistry(` and
        # derives its tables through `_derive_tables`, whose spec index is FIRST-wins (the clash law
        # that refused a duplicate left; the legacy's Dict assignment was last-wins).
        src = read(joinpath(dirname(dirname(@__DIR__)), "src", "alterants",
            "registry.jl"), String)
        chain = src[findfirst("function _validate_registration", src)[1]:end]
        chain = chain[1:findfirst("return diags", chain)[1]]
        for checkname in ("_encodability_collect!", "_mode_gate_collect!")
            @test occursin(checkname, chain)   # every remaining check is wired
        end
        for gone in ("_record_wellformed_collect!", "_dependency_collect!", "_inventory_collect!",
                     "_register_actions_collect!", "_reflection_collect!", "_value_algebra_collect!",
                     "_reachability_collect!", "_candidacy_collect!", "_CLASH_DISPOSITION",
                     "_vocabulary_collect!")   # stage 5's E9: the vocabulary check left with the record's vocabulary slot
            @test !occursin(gone, src)         # the retired names never return
        end
        pub = src[findfirst("function publish(", src)[1]:end]
        pub = pub[1:findfirst("return AlterantRegistry(", pub)[1]]
        @test occursin("validate(b)", pub)              # the checks run BEFORE the constructor
        @test occursin("_derive_tables(", pub)          # the tables come from the declarations
        derive = src[findfirst("function _derive_tables", src)[1]:end]
        derive = derive[1:findfirst("\nend", derive)[1]]
        @test occursin("haskey(spec_index, s.name) || (spec_index[s.name] = i)", derive)   # first-wins, pinned at the use site
        # the LIVE record is total: every registered action has its spec
        for a in GM.DEFAULT_REGISTRY.sorted_alt_actions
            @test haskey(GM.DEFAULT_REGISTRY.spec_index, a)
        end
    end

    @testset "a duplicate action name resolves FIRST-wins at publish (stage 5's E4; the legacy was last-wins)" begin
        # (replaces arm-W consistency, retired with the clash law; measured on the E4 scratch —
        # PROBES-e4-validate_stage1-src-cut_on-1c9d013f.txt [4])
        b = GM.RegistryBuilder()
        GM.register!(b, GM.PlugIn(:bag, :accumulate, Dict{Symbol,Bool}, GM.Alterants.setLabels, GM.Alterants.checkLabels, nothing),
            GM.ActionSpec(; name = :alpha, spelling = :identifier, plugin = Int8(1),
                overloads = [GM.ActionOverload(; sig_types = Type[Dict{Symbol,Bool}, Symbol], vararg_kind = :symbol, queryable = true)]),
            GM.ActionSpec(; name = :alpha, spelling = :identifier, plugin = Int8(1),
                overloads = [GM.ActionOverload(; sig_types = Type[Dict{Symbol,Bool}, Symbol], vararg_kind = :symbol, queryable = false)]))
        @test isempty(GM.validate(b))                        # no clash law refuses it
        R = GM.publish(b)
        @test R.spec_index[:alpha] == 1                      # the FIRST declaration is the one dispatched
        @test R.action_specs[R.spec_index[:alpha]].overloads[1].queryable === true
        @test R.sorted_alt_actions == [:alpha] && R.action_to_plugin == Int8[1]
    end

    # (the record shape law testset was CONSCIOUSLY RETIRED at stage 5's E4 with its subject — census
    # row 3; the domain probe, the law's one remaining row, is witnessed in registry_lifecycle_tests and
    # snapshot_property_tests.)

    @testset "the commissioned capability consults — literals retired" begin
        # the head spec carries the accepting slot + the validate seam
        hs = GM.DEFAULT_REGISTRY.action_specs[GM.DEFAULT_REGISTRY.spec_index[:head]]
        @test hs.accepts_string_slot == 1
        @test hs.validate === GM.Alterants._heading_validate_text
        @test all(ov.phase === :absorb for ov in hs.overloads)
        # behavior THROUGH the record is unchanged: the slot law + validation
        r = GM.goMeta(Vector{UInt8}(codeunits("#~ \"T\"\nx = 1\n")))
        @test any(a === :head_1 for (_, a, _, _) in GM.readAltValuesEvals(r.altValues_evals))
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

        # (test_dispatch_target_uniqueness_law was CONSCIOUSLY RETIRED at stage 5's E4 with its subject,
        # the record shape law's uniqueness row — census row 3.)

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
            # a hand-built registry carries the drifted shapes on purpose. Since stage 5's E4 the
            # remaining checks at `validate` refuse neither: a declared-but-unimplemented signature
            # and a lying return type both publish and are caught ONLY here, at the live seam — the
            # two INTERNAL arms are production walls (the dispatch-boundary tests measure the four
            # SHIPPED setters, a test-time fact).
            # v0.4 T2: positional `AlterantRegistry(...)` is GATED (route U compares the hand-built
            # tables) — the witness rides the INTERNAL `_unchecked_registry` test seam (unsealed;
            # never a consumer route).
            _mini(specs) = GM._unchecked_registry(GM.PlugIn[], Symbol[], Int8[],
                Dict{Symbol,Int8}(), Dict{Symbol,Int8}(), Int8[], Int8[],
                Dict{Symbol,Symbol}(), specs, Dict{Symbol,Int}(sp.name => i for (i, sp) in enumerate(specs)))
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
