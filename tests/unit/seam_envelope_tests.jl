# seam_envelope_tests.jl — v0.4 T3: the SEAMS witnesses (T3-DESIGN §8's fixture table).
#
# IS:   the T3 acceptance witnesses — the symmetric query-seam envelope (both call sites),
#       the consumed handover validation (with the "GoMeta "-prefix pass-through), the three-site
#       ctor-mint envelope (also the absent zero-arg method, since the eager DEP_MISSING gate left at
#       stage 5's E4 of the v0.4 build), the post-dispatch store-identity
#       check, and the state-seam ledger (in-flight enforcement · the re-injection cells — free of any
#       binding since the Visib write-back left at stage 3's commit 4 of the v0.4 build, R-V04B-42).
# DOES: publishes DEFECTIVE-callable registries through the sanctioned lifecycle, drives them
#       through goMeta / run_absorb_apply!, and pins the catalogue-name tokens + codes.
# REASONING: T3's refusals fire only on defective callables/records/states — no golden or
#       corpus path reaches them; these witnesses are the only proof the envelopes fire.
# PURPOSE: the T3 acceptance rows (Σ = 34 asserts; T3-DESIGN §8's closed arithmetic).

using Test
import GoMeta as GM

@eval module _SeamT
    import GoMeta as GM
    struct QEx <: Exception end                       # the custom query-throw class
    struct Boom; x::Int; end                          # ctor exists AND throws (the front-door route)
    Boom() = error("boom-ctor")
    struct BoomH; x::Int; end                         # the heading-mint twin
    BoomH() = error("boom-ctor-h")
    # exact-signature setters (the reflection cross-check matches per-signature):
    boom_set(store::Dict{Symbol,Bool}, a::Symbol, rest::Symbol...) = error("boom-set")
    const PSREF = Base.RefValue{Any}(nothing)         # the nested re-injection fixture's channel
    const NESTED = Base.RefValue{Any}(nothing)
    nested_set(store::Dict{Symbol,Bool}, a::Symbol, rest::Symbol...) =
        (NESTED[] = GM.run_absorb_apply!(PSREF[]); store[a] = true; nothing)
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
        b.plugins[1] = GM.PlugIn(; altName = :labels, setMode = :accumulate,
                                   altConstructor = ctor, setAltInstance = setter,
                                   getAltInstance = getter)
        return b
    end
    # a DEFAULT-derived builder with the HEAD spec's validate slot swapped
    function _head_builder(validatefn)
        b = GM.RegistryBuilder(GM.DEFAULT_REGISTRY)
        s = b.action_specs[8]
        b.action_specs[8] = GM.ActionSpec(; name = s.name, spelling = s.spelling,
            plugin = s.plugin, overloads = s.overloads,
            accepts_string_slot = s.accepts_string_slot,
            sugar_candidacy = s.sugar_candidacy, validate = validatefn)
        return b
    end
    _drive(doc, R) = try
        GM.goMeta(doc; registry = R)
        nothing
    catch e
        e
    end

    @testset "the query envelope — five throw classes + the return guard (site 1: the closed interpreter)" begin
        for thrower in ((a...) -> throw(ArgumentError("x")),
                        (a...) -> throw(OverflowError()),
                        (a...) -> throw(MethodError(+, (1,))),
                        (a...) -> error("boom-q"),
                        (a...) -> throw(_SeamT.QEx()))
            R = GM.publish(_labels_builder(; getter = thrower))
            e = _drive(_QDOC, R)
            @test e isa ErrorException && occursin("CB_QUERY_THROW", e.msg)
        end
        R = GM.publish(_labels_builder(; getter = (a...) -> "yes"))
        e = _drive(_QDOC, R)
        @test e isa ErrorException && occursin("RES_RETURN_TYPE", e.msg)
        @test occursin("String", e.msg)                    # the class rendered via nameof
    end

    @testset "the query envelope — site 2 (CnS.getAltState, the internals-drive precedent)" begin
        Rt = GM.publish(_labels_builder(; getter = (a...) -> error("boom-q2")))
        ps = GM.BLS.setUpToProcessFromBytes(Vector{UInt8}(codeunits("x = 1\n")))
        st = GM.init_state(ps, GM.GoMetaConfig(), Rt)
        st.working[Int8(1)] = Dict{Symbol,Bool}()
        e2 = Base.ScopedValues.with(GM.STATE => st) do
            try GM.getAltState(Int8(1), Symbol(":"), :x); nothing catch err; err end
        end
        @test e2 isa ErrorException && occursin("CB_QUERY_THROW", e2.msg)
        Rn = GM.publish(_labels_builder(; getter = (a...) -> 7))
        stn = GM.init_state(ps, GM.GoMetaConfig(), Rn)
        stn.working[Int8(1)] = Dict{Symbol,Bool}()
        e3 = Base.ScopedValues.with(GM.STATE => stn) do
            try GM.getAltState(Int8(1), Symbol(":"), :x); nothing catch err; err end
        end
        @test e3 isa ErrorException && occursin("RES_RETURN_TYPE", e3.msg)
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

    @testset "an absent zero-arg method publishes and meets the mint wrap (the eager DEP_MISSING gate left at stage 5's E4)" begin
        # (measured on the E4 scratch: PROBES-e4-validate_stage1-src-cut_on-1c9d013f.txt [6])
        b = GM.RegistryBuilder(GM.DEFAULT_REGISTRY)
        b.plugins[2] = GM.PlugIn(; altName = :Visib, setMode = :mutExclusive,
                                   altConstructor = SubString{String},
                                   setAltInstance = GM.Alterants.setVisib)
        @test isempty(GM.validate(b))
        e = _drive(Vector{UInt8}(codeunits("x = 1\n#~ hide\n\ny = 2\n")), GM.publish(b))
        @test e isa ErrorException && occursin("CB_CTOR_THROW", e.msg) && occursin("MethodError", e.msg) &&
              occursin("Visib", e.msg)
    end

    @testset "the ctor-mint envelope — the apply mint AND the absorb heading mint (CB_CTOR_THROW)" begin
        Ra = GM.publish(_labels_builder(; ctor = _SeamT.Boom))
        ea = _drive(_LDOC, Ra)
        @test ea isa ErrorException && occursin("CB_CTOR_THROW", ea.msg)
        @test occursin("labels", ea.msg)                   # record attribution via altName
        bh = GM.RegistryBuilder(GM.DEFAULT_REGISTRY)
        ph = bh.plugins[4]
        bh.plugins[4] = GM.PlugIn(; altName = ph.altName, setMode = ph.setMode,
                                    altConstructor = _SeamT.BoomH,
                                    setAltInstance = ph.setAltInstance)
        Rh = GM.publish(bh)
        eh = _drive(_HDOC, Rh)
        @test eh isa ErrorException && occursin("CB_CTOR_THROW", eh.msg)
        @test occursin("heading", eh.msg)
    end

    @testset "the store-identity check (RES_FOREIGN_STORE at the post-dispatch point)" begin
        Rs = GM.publish(_labels_builder(; ctor = Vector{Symbol}))
        es = _drive(_LDOC, Rs)
        @test es isa ErrorException && occursin("RES_FOREIGN_STORE", es.msg)
        @test !occursin("internal invariant", es.msg)      # NOT the wrong-class drift error
    end

    @testset "the state-seam ledger — in-flight enforcement; re-injection free of any binding (R-V04B-42, stage 3's commit 4)" begin
        _mkps() = begin
            ps = GM.BLS.setUpToProcessFromBytes(Vector{UInt8}(codeunits("x = 1\n#~ hide\n\ny = 2\n")))
            GM.BLS.parseBLS(ps, 1, -1)
            ps
        end
        # (12) REGISTRY-IDENTITY: two INDEPENDENT publishes of the same content — equal
        # fingerprints, distinct objects — so ONLY `===` discriminates (the fixture law)
        P1 = GM.publish(GM.default_registry_builder())
        P2 = GM.publish(GM.default_registry_builder())
        @test P1.seal == P2.seal && P1 !== P2
        ps1 = _mkps()
        r1 = GM.run_absorb_apply!(ps1; registry = P1)      # the run writes NOTHING into the caller's state (stage 3's commit 4) ⇒ no binding
        @test r1.status === GM.PROCESS_OK
        r2 = GM.run_absorb_apply!(ps1; registry = P2)      # (12′) re-injection under ANOTHER published registry: no refusal — nothing to mismatch
        @test r2.status === GM.PROCESS_OK &&
              GM.serialize_evals(GM.readAltValuesEvals(r2.altValues_evals)) == GM.serialize_evals(GM.readAltValuesEvals(r1.altValues_evals))
        # (14) clean re-injection, same registry ⇒ silent
        r3 = GM.run_absorb_apply!(ps1; registry = P1)
        @test r3.status === GM.PROCESS_OK
        # (13′) an abort mid-run leaves the state UNPOISONED (nothing was written into it): the re-injection runs again
        # and aborts again at the same defect — no poisoned-state refusal exists any more
        Rb = GM.publish(_labels_builder(; setter = _SeamT.boom_set))
        ps2 = GM.BLS.setUpToProcessFromBytes(Vector{UInt8}(codeunits(
            "x = 1\n#~ hide\n\ny = 2\n#~ :label1\n\nz = 3\n")))
        GM.BLS.parseBLS(ps2, 1, -1)
        eb = try GM.run_absorb_apply!(ps2; registry = Rb); nothing catch err; err end
        @test eb isa ErrorException && occursin("boom-set", eb.msg)   # the abort escapes (loudness-only at T3)
        eb2 = try GM.run_absorb_apply!(ps2; registry = Rb); nothing catch err; err end
        @test eb2 isa ErrorException && occursin("boom-set", eb2.msg)   # the re-injection RUNS (and aborts again) — not refused
        @test isempty(GM._registry_door_check(Rb))         # the PUBLISHED registry is unchanged
        # (15) an abort leaves the state clean (nothing of a run is written into it): re-injection
        # under a DIFFERENT registry is silent (the T3DB-2 cell)
        ps3 = GM.BLS.setUpToProcessFromBytes(Vector{UInt8}(codeunits("x = 1\n#~ :label1\n\ny = 2\n")))
        GM.BLS.parseBLS(ps3, 1, -1)
        ec = try GM.run_absorb_apply!(ps3; registry = Rb); nothing catch err; err end
        @test ec isa ErrorException                        # aborted (the labels setter throws)
        rc = GM.run_absorb_apply!(ps3; registry = P1)
        @test rc.status === GM.PROCESS_OK
        # (16) IN-FLIGHT enforcement: a setter re-injecting the SAME state mid-call
        Rn = GM.publish(_labels_builder(; setter = _SeamT.nested_set))
        ps4 = GM.BLS.setUpToProcessFromBytes(Vector{UInt8}(codeunits("x = 1\n#~ :label1\n\ny = 2\n")))
        GM.BLS.parseBLS(ps4, 1, -1)
        _SeamT.PSREF[] = ps4
        GM.run_absorb_apply!(ps4; registry = Rn)
        nested = _SeamT.NESTED[]
        @test nested isa GM.GoMetaDelivery && _codes(nested.diagnostics) == [:STATE_REUSE_REFUSED] &&
              occursin("IN FLIGHT", nested.diagnostics[1].message)
        @test nested.status === GM.PROCESS_ERROR && nested.diagnostics[1].severity === :error   # [C14h4] card C14 (h), R-V04B-96 (his §306): the in-flight refusal's row an :error (MEASURED 2026-10-03, receipts/S8-branch/PROBES-c14-pins_cd3ee9d3.txt)
        @test nested.blsComponentTree !== ps4                                                    # [C14g4] card C14 (g): the refusal delivers a tree that is NOT the injected state (the one ledger refusal left since stage 3's commit 4 — the in-flight check; the door's is pinned in registry_lifecycle_tests.jl)
        @test isempty(GM.BLS.children(nested.blsComponentTree))                                 # [C14g5] …with no Block, through the door
        @test isempty(GM.readAltValuesEvals(nested.altValues_evals))                            # [C14g6] …and an EMPTY store
    end

    @testset "the InterruptException arm + the set-seam catalogue tokens" begin
        Ri = GM.publish(_labels_builder(; getter = (a...) -> throw(InterruptException())))
        ei = try GM.goMeta(_QDOC; registry = Ri); nothing catch err; err end
        @test ei isa InterruptException                    # rethrown VERBATIM, never wrapped
        src = read(joinpath(dirname(dirname(@__DIR__)), "src", "alterants", "apply.jl"), String)
        @test occursin("CB_SET_THROW", src)                # the set-arm conversion carries its name
        @test occursin("(RES_RETURN_TYPE; the value-algebra guard", src)   # ...and the return guard its own
    end
end
