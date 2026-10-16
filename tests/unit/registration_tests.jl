# tests/unit/registration_tests.jl — v0.2 registration build: the registration record (the runtime
# arming guard's witnesses left at stage 5's E6 of the v0.4 build — census row 14; APPEND-ONLY; the clash law with its disposition switch, the reflection
# cross-check, the value-algebra and reachability refusals, the candidacy diagnostic and the record
# shape law were CONSCIOUSLY RETIRED with their subjects at stage 5's E4 of the v0.4 build —
# census rows 3 and 51, OWNER-WORDS §317; the retirement notes stand where the testsets stood).
#
# IS:   the witnesses of the DECLARED registration record as the Engine still reads it: the
#       remaining checks wired at `validate` (source order), the FIRST-wins derived tables and the
#       commissioned capability consults; the operator-token tag's witness, the activated-grants register's and the
#       dispatch-boundary return-type rows left with the overload rows at stage 5's E11 of the v0.4 build (census row 16);
#       the full-arming guard's witnesses left with the set-invocation seam at stage 5's E6 of the v0.4 build.
# PURPOSE: plan row 11's gate — "registration + atomicity tests green" (re-scoped at E4).

using Test
import GoMeta as GM

@testset "the registration build — the record + the remaining checks" begin

    # (test_clash_check_always_fires was CONSCIOUSLY RETIRED at stage 5's E4 of the v0.4 build with its
    # subject: the clash law and its disposition switch left — census rows 3 and 51, OWNER-WORDS §317;
    # a duplicate action name resolves FIRST-wins in `_derive_tables`, witnessed below.)

    # (test_operator_token_spelling was CONSCIOUSLY RETIRED at stage 5's E11 of the v0.4 build with its subject — the
    # record's spelling tag, census row 16.)

    # (the reflection cross-check testset was CONSCIOUSLY RETIRED at stage 5's E4 with its subject —
    # census row 3: a declared signature is the author's statement; a drifted one is Julia's own MethodError at the
    # bare setter call since stage 5's E6 of the v0.4 build — census row 14, the build's probe, its I1; the seam's
    # drift arm and its witness test_drift_and_return_guard_internal_arms left at stage 5's E6.)

    # (test_value_algebra_refusal + test_reachability_refusal were CONSCIOUSLY RETIRED at stage 5's E4
    # with their subjects — census row 3; the live seam's return-type guard left at stage 5's E6 with its witness —
    # census row 14: a setter's return is not checked.)

    # (the activated-grants testset was CONSCIOUSLY RETIRED at stage 5's E11 of the v0.4 build with its subject — the
    # record's sugar-candidacy register, census row 16; the two sugars — the Labels colon, the quoted-first heading —
    # are the absorb grammar's, witnessed by the corpus and the heading tests.)

    @testset "the remaining checks precede construction; the record is total" begin
        # (re-scoped at stage 5's E4 — the validation chain of v0.4 T2–T4 left, census row 3, OWNER-WORDS
        # §317; the referents moved — recorded, not silently re-pinned) two source-order assertions:
        # (i) the one remaining collector is wired inside `_validate_registration` (`_vocabulary_collect!` left at stage 5's E9, `_mode_gate_collect!`
        # with the Heading's separate lane at stage 1 of the Alterants build) and the retired
        # ones never return; (ii) `publish` calls `validate(` before `return AlterantRegistry(` and
        # derives its tables through `_derive_tables`, whose spec index is FIRST-wins (the clash law
        # that refused a duplicate left; the legacy's Dict assignment was last-wins).
        src = read(joinpath(dirname(dirname(@__DIR__)), "src", "alterants",
            "registry.jl"), String)
        chain = src[findfirst("function _validate_registration", src)[1]:end]
        chain = chain[1:findfirst("return diags", chain)[1]]
        for checkname in ("_encodability_collect!",)
            @test occursin(checkname, chain)   # the remaining check is wired
        end
        for gone in ("_record_wellformed_collect!", "_dependency_collect!", "_inventory_collect!",
                     "_register_actions_collect!", "_reflection_collect!", "_value_algebra_collect!",
                     "_reachability_collect!", "_candidacy_collect!", "_CLASH_DISPOSITION",
                     "_vocabulary_collect!",   # stage 5's E9: the vocabulary check left with the record's vocabulary slot
                     "_mode_gate_collect!")    # stage 1 of the Alterants build: the mode-gate laws left with the Heading's separate lane
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
        # (replaces arm-W consistency, retired with the clash law; the one-Alterant form measured on the E4 scratch —
        # PROBES-e4-validate_stage1-src-cut_on-1c9d013f.txt [4]; the TWO-Alterant form below — the duplicate on plugins 1 and 2, so the
        # OWNER table's first-wins is discriminated and not only the spec index's — MEASURED on the s5c37 scratch at 0cf389d4:
        # PROBES-s5c37-witness-values_on-0cf389d4.txt [F]; the closing set's row L5 r2)
        b = GM.RegistryBuilder()
        GM.register!(b, GM.Alterant(; altName = :bag, setMode = :accumulate, altConstructor = Dict{Symbol,Bool}, setAltInstance = GM.Alterants.setLabels, getAltInstance = GM.Alterants.checkLabels), GM.ActionSpec(; name = :alpha, plugin = Int8(1), accepts_string_slot = 1))
        GM.register!(b, GM.Alterant(; altName = :bag2, setMode = :accumulate, altConstructor = Dict{Symbol,Bool}, setAltInstance = GM.Alterants.setLabels, getAltInstance = GM.Alterants.checkLabels), GM.ActionSpec(; name = :alpha, plugin = Int8(2), accepts_string_slot = 0))
        @test isempty(GM.validate(b))                        # no clash law refuses it
        R = GM.publish(b)
        @test R.spec_index[:alpha] == 1 && R.action_specs[1].accepts_string_slot == 1   # the FIRST declaration dispatched
        @test R.sorted_alt_actions == [:alpha] && R.action_to_plugin == Int8[1]   # the FIRST declaration's OWNER (registry.jl :1854 first-wins; a last-wins table would give Int8[2])
    end

    # (the record shape law testset was CONSCIOUSLY RETIRED at stage 5's E4 with its subject — census
    # row 3; the domain probe, the law's one remaining row, is witnessed in registry_lifecycle_tests and
    # snapshot_property_tests.)

    @testset "the commissioned capability consults — literals retired" begin
        # the head spec carries the accepting slot + the validate seam
        hs = GM.DEFAULT_REGISTRY.action_specs[GM.DEFAULT_REGISTRY.spec_index[:head]]
        @test hs.accepts_string_slot == 1
        @test hs.validate === GM.Alterants._heading_validate_text
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
        # the enqueue path carries no hard-coded action/plugin literal (the retirement grep-witness — the spec consults only;
        # since stage 1 of the Alterants build the one path for every action, the Heading's separate path gone)
        src = read(joinpath(dirname(dirname(@__DIR__)), "src", "absorb",
            "absorb_meta.jl"), String)
        fn = src[findfirst("function absorbMeta(", src)[1]:end]
        fn = fn[1:findfirst("\nend\n", fn)[1]]
        @test !occursin("=== :head", fn) && !occursin("_heading_validate_text(", fn)
        @test !occursin("_absorb_local_only!", src)   # the separate path is gone (stage 1 of the Alterants build)
    end

    # (the dispatch-boundary return-type validation testset was CONSCIOUSLY RETIRED at stage 5's E11 of the v0.4 build
    # with its subject — the declared return types of the overload rows, census row 16; the setters' methods are the
    # actions' forms and Julia dispatch the check.)

    # ── (the FULL-ARMING witnesses — the kind map, the user-arity convention, the unregistered-action, arity,
    # form and value refusals, the pass paths and the drift and return-guard internal arms of the set-invocation
    # seam `_invoke_set` — were CONSCIOUSLY RETIRED with their subject at stage 5's E6 of the v0.4 build, census
    # row 14: the seam, `_kind_type`, `_user_arity` and the `_unchecked_registry` test seam left at stage 5's E6;
    # the setters are called bare, as his legacy called them — his §120.)
end
