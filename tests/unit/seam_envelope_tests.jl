# seam_envelope_tests.jl — v0.4 T3: the SEAMS witnesses (T3-DESIGN §8's fixture table).
#
# IS:   the seams' acceptance witnesses — the query seam (the `getAltState` call is BARE —
#       the closed interpreter's own query envelope, CB_QUERY_THROW / RES_RETURN_TYPE at its atom, was removed with
#       the interpreter: a getter's throw propagates raw out of the goMeta call, a non-Bool
#       return is Julia's own TypeError where the condition needs a Bool),
#       the consumed handover validation (with the "GoMeta "-prefix pass-through) and the InterruptException
#       pass-through; an absent zero-arg method publishes (the eager DEP_MISSING gate was removed).
#       The three-site ctor-mint envelope (CB_CTOR_THROW) was removed, and
#       the post-dispatch store-identity check (RES_FOREIGN_STORE) with it — the set-invocation seam
#       (the state-seam ledger's witnesses — in-flight enforcement, the re-injection cells — left with the
#       ledger and the callable driver seam).
# DOES: publishes DEFECTIVE-callable registries through the sanctioned lifecycle, drives them
#       through goMeta, and pins the catalogue-name tokens + codes.
# REASONING: T3's refusals fire only on defective callables/records/states — no golden or
#       corpus path reaches them; these witnesses are the only proof the envelopes fire.
# PURPOSE: the seams' acceptance rows (Σ = 36 asserts at first — the closed arithmetic, its 34 amended to 36 at the realized count (the two fixture-soundness asserts); the ledger testset's 14 — ten of
#       the seams' and four door pins — removed; 9 more — the mint-wrap assert, the ctor-mint 4,
#       the store-identity 2, the two source greps — removed with the set-invocation seam; 2 more removed
#       with the capture laws (measured per file)).

using Test
import GoMeta as GM

@eval module _SeamT
    import GoMeta as GM
    struct QEx <: Exception end                       # the custom query-throw class
    # (a throwing setter fixture, shaped exact-signature for the reflection cross-check of the time — since removed; its last driver, the state-seam ledger's abort re-injection cell, was removed with the ledger; driven by no testset since)
    boom_set(store::Dict{Symbol,Bool}, a::Symbol, rest::Symbol...) = error("boom-set")
end

@testset "seam_envelope (v0.4 T3)" begin

    _codes(diags) = [d.code for d in diags]
    _QDOC = Vector{UInt8}(codeunits("x = 1\n#~1 :label1 hide{ :label1 }\n\ny = 2\n"))
    _LDOC = Vector{UInt8}(codeunits("x = 1\n#~ :label1\n\ny = 2\n"))
    _HDOC = Vector{UInt8}(codeunits("x = 1\n#~ \"T\"\n\ny = 2\n"))

    # a DEFAULT-derived builder with the LABELS plugin's getter (and optionally setter/ctor) swapped
    function _labels_builder(; getter = GM.Alterants.checkLabels,
                               setter = GM.Alterants.setLabels,
                               ctor = Dict{Symbol,Bool})
        b = GM.RegistryBuilder(GM.DEFAULT_REGISTRY)
        b.plugins[1] = GM.Alterant(; altName = :labels, setMode = :accumulate,
                                   altConstructor = ctor, setAltInstance = setter,
                                   getAltInstance = getter)
        return b
    end
    # a DEFAULT-derived builder with the HEAD spec's validate slot swapped
    function _head_builder(validatefn)
        b = GM.RegistryBuilder(GM.DEFAULT_REGISTRY)
        i = findfirst(s -> s.name === :head, b.action_specs)   # BY NAME since the `ids` action holds position 8
        s = b.action_specs[i]                                    # (the head is 9th); the positional [8] had swapped the wrong spec — MEASURED: the
        b.action_specs[i] = GM.ActionSpec(; name = s.name, plugin = s.plugin,   # three handover pins returned `nothing` on the stage-3 scratch
            accepts_string_slot = s.accepts_string_slot, validate = validatefn)
        return b
    end
    _drive(doc, R) = try
        GM.goMeta(doc; registry = R)
        nothing
    catch e
        e
    end

    @testset "the query seam — five throw classes propagate RAW + a non-Bool return is Julia's TypeError (the bare call)" begin
        for (thrower, class) in (((a...) -> throw(ArgumentError("x")), ArgumentError),
                                 ((a...) -> throw(OverflowError("x")), OverflowError),   # (the former fixture's `OverflowError()` had no zero-argument
                                                                                           #  constructor — its MethodError was swallowed by the envelope; MEASURED)
                                 ((a...) -> throw(MethodError(+, (1,))), MethodError),
                                 ((a...) -> error("boom-q"), ErrorException),
                                 ((a...) -> throw(_SeamT.QEx()), _SeamT.QEx))
            R = GM.publish(_labels_builder(; getter = thrower))
            e = _drive(_QDOC, R)
            @test e isa class                              # the getter's own exception, unwrapped (the original engine's bare call)
        end
        R = GM.publish(_labels_builder(; getter = (a...) -> "yes"))
        e = _drive(_QDOC, R)
        @test e isa TypeError                              # "non-boolean (String) used in boolean context" — Julia's, at the apply site
        @test occursin("String", sprint(showerror, e))     # the class named by Julia
    end

    @testset "the handover validation CONSUMED (false · throw · non-Bool · the ratified pass-through)" begin
        Rf = GM.publish(_head_builder(t -> false))
        ef = _drive(_HDOC, Rf)
        @test ef isa ErrorException && occursin("REG_VALIDATE_FALSE", ef.msg)
        @test occursin("head", ef.msg)                     # the action named
        Rt = GM.publish(_head_builder(t -> error("boom-v")))
        et = _drive(_HDOC, Rt)
        @test et isa ErrorException && occursin("CB_VALIDATE_THROW", et.msg)
        @test occursin("ErrorException", et.msg)           # the class via nameof, never the text
        Rn = GM.publish(_head_builder(t -> 1))
        en = _drive(_HDOC, Rn)
        @test en isa ErrorException && occursin("RES_RETURN_TYPE", en.msg)
        # the PASS-THROUGH: the DEFAULT registry's own ratified empty-heading refusal
        # survives the envelope VERBATIM (the "GoMeta "-prefix law)
        ep = _drive(Vector{UInt8}(codeunits("x = 1\n#~ \"\"\n\ny = 2\n")), GM.DEFAULT_REGISTRY)
        @test ep isa ErrorException && occursin("empty heading text", ep.msg) &&
              occursin("ratified standing decision", ep.msg) && !occursin("CB_VALIDATE_THROW", ep.msg)
    end

    @testset "an absent zero-arg method publishes (the eager DEP_MISSING gate and the mint wrap removed)" begin
        # (measured)
        b = GM.RegistryBuilder(GM.DEFAULT_REGISTRY)
        b.plugins[2] = GM.Alterant(; altName = :Visib, setMode = :mutExclusive,
                                   altConstructor = SubString{String},
                                   setAltInstance = GM.Alterants.setVisib)
        @test isempty(GM.validate(b))
        @test GM.publish(b) isa GM.AlterantRegistry   # the title's verb exercised (publish on the clean validate — MEASURED)
        # (the mint wrap's CB_CTOR_THROW witness was removed with the set-invocation seam: the bare
        # mint is Julia's own MethodError out of the goMeta call, measured on both trees)
    end

    @testset "the InterruptException arm (the query site's pass-through)" begin
        Ri = GM.publish(_labels_builder(; getter = (a...) -> throw(InterruptException())))
        ei = try GM.goMeta(_QDOC; registry = Ri); nothing catch err; err end
        @test ei isa InterruptException                    # rethrown VERBATIM, never wrapped
    end
end
