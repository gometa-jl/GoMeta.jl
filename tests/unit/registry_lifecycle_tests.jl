# registry_lifecycle_tests.jl — v0.4 T2: the registry LIFECYCLE witnesses (APPEND-ONLY).
#
# IS:   the unit witnesses of Builder → validate → PUBLISH, the ONE validation chain on every public
#       construction route (the route-U cure; NO positional form accepts a seal — the token-gated
#       constructor), the two-tier typed diagnostics with FULL collection (validate never throws),
#       atomic DEEP-copy publication, the seal + the door's three checks (the declared record's seal ·
#       every derived table re-derived · the callable identities by `===`), the STRICT published-only
#       door at `goMeta(bytes; registry)` AND at the callable seam (an unpublished value refuses typed
#       NAMING the sanctioned path), the real freeze gate (`POST_SEAL_MUTATION` on declared, derived,
#       re-ordered and callable mutations), `register!`'s binding + pool refusals, the injective slot
#       encoding, the 0.4.x contract family, warnings emitted at publish, the two exhaustion refusals
#       (registry grain + the per-call slot pool), and full collection at the entry (config + registry
#       diagnostics in ONE result).
# DOES: builds registries through every route, mutates published values, drives the door, and pins
#       the codes and the messages' load-bearing substrings.
# REASONING: the golden layer proves the PUBLISHED default is byte-neutral; only these witnesses prove
#       the refusals fire, fully, typed, and in deterministic order.
# PURPOSE: the T2 acceptance rows of the v0.4 build (M-AC-9 registry gates; the door; FM-REG rows).

using Test
import GoMeta as GM

@testset "registry_lifecycle (v0.4 T2)" begin

    _ov(sig; rt = Nothing, q = false) = GM.ActionOverload(sig, Symbol[], Symbol[], nothing, rt,
                                                          :set, q, :context_free, :apply, true)
    _codes(diags) = [d.code for d in diags]
    _errors(diags) = [d.code for d in diags if d.severity === :error]

    @testset "the default builder publishes to exactly DEFAULT_REGISTRY, sealed" begin
        b = GM.default_registry_builder()
        @test b isa GM.RegistryBuilder
        @test isempty(GM.validate(b))                       # the shipped record is clean
        R = GM.publish(b)
        D = GM.DEFAULT_REGISTRY
        @test D.seal !== nothing && startswith(D.seal, "fnv1a64:")
        @test R.seal == D.seal
        for f in (:sorted_alt_actions, :action_to_plugin, :action_index, :alt_index,
                  :accum_alt_idxs, :mutex_alt_idxs, :action_to_settribute, :spec_index)
            @test getfield(R, f) == getfield(D, f)
        end
        @test length(R.plugins) == 4 && length(R.action_specs) == 8
        # publication COPIES: no container is shared with the builder
        @test R.plugins !== b.plugins && R.action_specs !== b.action_specs
        push!(b.plugins, GM.PlugIn(:zz, :accumulate, Dict{Symbol,Bool}, identity, nothing, nothing))
        @test length(R.plugins) == 4                        # the published value is untouched
        @test isempty(GM._registry_door_check(R))
    end

    @testset "the STRICT door: an unpublished (route-U) registry refuses, naming the path" begin
        D = GM.DEFAULT_REGISTRY
        U = GM.AlterantRegistry(D.plugins, D.sorted_alt_actions, D.action_to_plugin, D.action_index,
                                D.alt_index, D.accum_alt_idxs, D.mutex_alt_idxs, D.action_to_settribute,
                                D.action_specs, D.spec_index)    # conforming; the gate passes
        @test U.seal === nothing
        r = GM.goMeta(Vector{UInt8}(codeunits("x = 1\n#~ hide\n\ny = 2\n")); registry = U)
        @test r.status === GM.PROCESS_ERROR
        @test _codes(r.diagnostics) == [:REG_UNPUBLISHED]
        @test occursin("RegistryBuilder → validate → publish", r.diagnostics[1].message)
        @test isempty(GM.outputs(r).render_bytes)           # no parse, no render attempted
        # route U REFUSES inconsistent hand-built tables (never a silently misrouting registry)
        bad_idx = copy(D.action_index); bad_idx[:hide] = Int8(99)
        e = try
            GM.AlterantRegistry(D.plugins, D.sorted_alt_actions, D.action_to_plugin, bad_idx,
                                D.alt_index, D.accum_alt_idxs, D.mutex_alt_idxs, D.action_to_settribute,
                                D.action_specs, D.spec_index); nothing
        catch err; err end
        @test e isa GM.RegistrationRefused
        @test _errors(e.diagnostics) == [:REG_DERIVED_TABLES]
        @test occursin("RegistrationRefused", sprint(showerror, e))
    end

    @testset "the REAL freeze gate: post-publication mutation fires POST_SEAL_MUTATION at the door" begin
        R = GM.publish(GM.default_registry_builder())
        r0 = GM.goMeta(Vector{UInt8}(codeunits("x = 1\n#~ hide\n\ny = 2\n")); registry = R)
        @test r0.status === GM.PROCESS_OK
        # a mutation through a published container (the finding-3 class): the seal no longer matches
        push!(R.action_specs, GM.ActionSpec(:zzz, :identifier, Int8(2),
            [_ov(Type[GM.Alterants.Visib, Symbol]; rt = Bool)], 0, :none, nothing, nothing))
        r1 = GM.goMeta(Vector{UInt8}(codeunits("x = 1\n#~ hide\n\ny = 2\n")); registry = R)
        @test r1.status === GM.PROCESS_ERROR
        @test _codes(r1.diagnostics) == [:POST_SEAL_MUTATION]
        @test isempty(GM.outputs(r1).render_bytes)
        # (cure batch 1) a mutated DERIVED table — the declared record untouched, the seal still
        # matching — is refused too: the door re-derives every table (the CRX after-T2 breaker's
        # `action_to_settribute[:hide] = :show` attack)
        R2 = GM.publish(GM.default_registry_builder())
        R2.action_to_settribute[:hide] = :show
        d2 = GM._registry_door_check(R2)
        @test _codes(d2) == [:POST_SEAL_MUTATION] && occursin("action_to_settribute", d2[1].message)
        R3 = GM.publish(GM.default_registry_builder())
        R3.action_index[:hide] = Int8(3)
        @test _codes(GM._registry_door_check(R3)) == [:POST_SEAL_MUTATION]
        # a re-ordered action_specs (the order-insensitive fold would not see it) is refused
        R4 = GM.publish(GM.default_registry_builder())
        reverse!(R4.action_specs)
        @test _codes(GM._registry_door_check(R4)) == [:POST_SEAL_MUTATION]
        # a plugin swapped for one with a SAME-NAMED evil setter (folds identically) is refused by
        # the callable-identity comparison
        R5 = GM.publish(GM.default_registry_builder())
        evil = let setVisib = (args...) -> nothing; setVisib end    # a different function, same name text
        R5.plugins[2] = GM.PlugIn(:Visib, :mutExclusive, GM.Alterants.Visib, evil, nothing, nothing)
        @test _codes(GM._registry_door_check(R5)) == [:POST_SEAL_MUTATION]
        # NO positional form accepts a seal: the generated all-fields constructor is gone (the forge
        # attack: copying DEFAULT_REGISTRY.seal onto hand-built tables)
        D = GM.DEFAULT_REGISTRY
        @test_throws MethodError GM.AlterantRegistry(D.plugins, D.sorted_alt_actions, D.action_to_plugin,
            D.action_index, D.alt_index, D.accum_alt_idxs, D.mutex_alt_idxs, D.action_to_settribute,
            D.action_specs, D.spec_index, D.seal)
        @test_throws MethodError GM.AlterantRegistry(D.plugins, D.sorted_alt_actions, D.action_to_plugin,
            D.action_index, D.alt_index, D.accum_alt_idxs, D.mutex_alt_idxs, D.action_to_settribute,
            D.action_specs, D.spec_index, D.seal, D._callables)
        # the callable SEAM runs the door too (cure batch 1): an unpublished registry cannot drive it
        U = GM.AlterantRegistry(D.plugins, D.sorted_alt_actions, D.action_to_plugin, D.action_index,
                                D.alt_index, D.accum_alt_idxs, D.mutex_alt_idxs, D.action_to_settribute,
                                D.action_specs, D.spec_index)
        ps = GM.BLS.setUpToProcessFromBytes(Vector{UInt8}(codeunits("x = 1\n#~ hide\n\ny = 2\n")))
        GM.BLS.parseBLS(ps, 1, -1)
        rs = GM.run_absorb_apply!(ps; registry = U)
        @test rs.status === GM.PROCESS_ERROR && _codes(rs.diagnostics) == [:REG_UNPUBLISHED]
        @test isempty(GM.outputs(rs).render_bytes)
        # the injective slot encoding (cure batch 1): a re-cut vector boundary no longer collides
        @test GM._slot_text([Symbol("a,b")]) != GM._slot_text([:a, :b])
        @test GM._slot_text(GM.Declared(Symbol[:a, :b])) != GM._slot_text(GM.Declared(Symbol[Symbol("a,b")]))
        # warnings are emitted by the sanctioned publish route (cure batch 1), never swallowed
        bw = GM.default_registry_builder()
        bw.action_specs[3] = GM.ActionSpec(; name = :show, spelling = :identifier, plugin = Int8(2),
                                             overloads = bw.action_specs[3].overloads,
                                             sugar_candidacy = :candidate, settribute = :show)
        @test_logs (:warn, r"sugar CANDIDACY") GM.publish(bw)
    end

    @testset "typed inventory refusals — each code, FULL collection, deterministic order" begin
        base = GM.default_registry_builder()
        # unknown setMode (FM-REG-1: silent misroute on v0.3.2)
        b = GM.RegistryBuilder(copy(base.plugins), copy(base.action_specs))
        b.plugins[1] = GM.PlugIn(:labels, :bogus, Dict{Symbol,Bool}, GM.Alterants.setLabels,
                                 GM.Alterants.checkLabels, nothing)
        @test :REG_UNKNOWN_SETMODE in _errors(GM.validate(b))
        @test_throws GM.RegistrationRefused GM.publish(b)
        # duplicate altName (FM-REG-6: silent last-wins on v0.3.2)
        b = GM.RegistryBuilder(copy(base.plugins), copy(base.action_specs))
        GM.register!(b, GM.PlugIn(:labels, :accumulate, Dict{Symbol,Bool}, GM.Alterants.setLabels,
                                  GM.Alterants.checkLabels, nothing))
        @test :REG_DUPLICATE_ALTNAME in _errors(GM.validate(b))
        # uninterpreted `requires` — WHOLE-record (R-V04-12 / HC-2 refusal half)
        b = GM.RegistryBuilder(copy(base.plugins), copy(base.action_specs))
        GM.register!(b, GM.PlugIn(; altName = :exec, setMode = :accumulate, altConstructor = Dict{Symbol,Bool},
                                    setAltInstance = GM.Alterants.setLabels, requires = (:execute,)))
        d = GM.validate(b)
        @test :REG_UNINTERPRETED_REQUIRES in _errors(d)
        @test occursin("WHOLE record", only(filter(x -> x.code === :REG_UNINTERPRETED_REQUIRES, d)).message)
        # MutEx naming an action the alterant does not register
        b = GM.RegistryBuilder(copy(base.plugins), copy(base.action_specs))
        b.plugins[2] = GM.PlugIn(; altName = :Visib, setMode = :mutExclusive, altConstructor = GM.Alterants.Visib,
                                   setAltInstance = GM.Alterants.setVisib, constraints = [GM.MutEx([:hide, :vanish])])
        @test :REG_MUTEX_CONFLICT in _errors(GM.validate(b))
        # contract version outside the accepted set
        b = GM.RegistryBuilder(copy(base.plugins), copy(base.action_specs))
        b.plugins[3] = GM.PlugIn(; altName = :id, setMode = :mutExclusivePerField, altConstructor = GM.Alterants.Id,
                                   setAltInstance = GM.Alterants.setId, contract_version = v"9.0.0")
        @test :REG_CONTRACT_VERSION in _errors(GM.validate(b))
        # reserved-vocabulary shadowing (FM-REG-3): an action named like a settribute key it does not
        # declare as its own write-back target
        b = GM.RegistryBuilder(copy(base.plugins), copy(base.action_specs))
        GM.register!(b, GM.PlugIn(:sh, :mutExclusive, GM.Alterants.Visib, GM.Alterants.setVisib, nothing, nothing),
                     GM.ActionSpec(:containsMeta, :identifier, Int8(5),
                                   [_ov(Type[GM.Alterants.Visib, Symbol]; rt = Bool)], 0, :none, nothing, nothing))
        @test :REG_RESERVED_SHADOW in _errors(GM.validate(b))
        # a dangling plugin index is STRUCTURAL (REG_PROTOCOL), never a BoundsError — pushed DIRECTLY
        # (register! itself refuses the mismatch since cure batch 1; validate must still be total)
        b = GM.RegistryBuilder(copy(base.plugins), copy(base.action_specs))
        push!(b.plugins, GM.PlugIn(:p5, :accumulate, Dict{Symbol,Bool}, GM.Alterants.setLabels, nothing, nothing))
        push!(b.action_specs, GM.ActionSpec(:zzq, :identifier, Int8(42),
                                            [_ov(Type[Dict{Symbol,Bool}, Symbol])], 0, :none, nothing, nothing))
        d = GM.validate(b)
        @test :REG_PROTOCOL in _errors(d)
        # a declared write-back key ComponentSettribute does not carry
        b = GM.RegistryBuilder(copy(base.plugins), copy(base.action_specs))
        b.action_specs[2] = GM.ActionSpec(; name = :hide, spelling = :identifier, plugin = Int8(2),
                                            overloads = base.action_specs[2].overloads, settribute = :nowhere)
        @test :REG_PROTOCOL in _errors(GM.validate(b))
        # slot-pool exhaustion at the REGISTRY grain (the Int8 index space): `register!` refuses the
        # 128th append (cure batch 1); a builder whose fields were pushed directly is caught by validate
        b = GM.RegistryBuilder(copy(base.plugins), copy(base.action_specs))
        for i in 1:123
            GM.register!(b, GM.PlugIn(Symbol("zz", i), :accumulate, Dict{Symbol,Bool},
                                      GM.Alterants.setLabels, GM.Alterants.checkLabels, nothing))
        end
        @test length(b.plugins) == 127
        e = try GM.register!(b, GM.PlugIn(:zz128, :accumulate, Dict{Symbol,Bool}, GM.Alterants.setLabels,
                                          GM.Alterants.checkLabels, nothing)); nothing catch err; err end
        @test e isa GM.RegistrationRefused && _errors(e.diagnostics) == [:REG_SLOT_EXHAUSTED]
        push!(b.plugins, GM.PlugIn(:zz128, :accumulate, Dict{Symbol,Bool}, GM.Alterants.setLabels,
                                   GM.Alterants.checkLabels, nothing))   # the direct-push bypass
        @test :REG_SLOT_EXHAUSTED in _errors(GM.validate(b))
        # `register!` binds the records to the appended plugin (cure batch 1): a record naming another
        # index refuses loudly instead of leaving the appended alterant silently actionless
        b = GM.RegistryBuilder(copy(base.plugins), copy(base.action_specs))
        e = try GM.register!(b, GM.PlugIn(:p5, :mutExclusive, GM.Alterants.Visib, GM.Alterants.setVisib, nothing, nothing),
                             GM.ActionSpec(:zzv, :identifier, Int8(2),
                                           [_ov(Type[GM.Alterants.Visib, Symbol]; rt = Bool)], 0, :none, nothing, nothing)); nothing
        catch err; err end
        @test e isa GM.RegistrationRefused && _errors(e.diagnostics) == [:REG_PROTOCOL]
        @test length(b.plugins) == 4                         # nothing appended on refusal
        # the 0.4.x contract family is accepted (the design's rule; cure batch 1)
        b = GM.RegistryBuilder(copy(base.plugins), copy(base.action_specs))
        b.plugins[3] = GM.PlugIn(; altName = :id, setMode = :mutExclusivePerField, altConstructor = GM.Alterants.Id,
                                   setAltInstance = GM.Alterants.setId, contract_version = v"0.4.7")
        @test :REG_CONTRACT_VERSION ∉ _errors(GM.validate(b))
        # validate NEVER throws on a structurally broken row (cure batch 1): tier 2 skips it
        b = GM.RegistryBuilder(copy(base.plugins), copy(base.action_specs))
        h = base.action_specs[2]
        b.action_specs[2] = GM.ActionSpec(; name = :hide, spelling = :identifier, plugin = Int8(2),
            overloads = [GM.ActionOverload(Type[GM.Alterants.Visib, Symbol], Symbol[], Symbol[], :bogus,
                                           Bool, :set, false, :context_free, :apply, true)], settribute = :hide)
        d = GM.validate(b)
        @test :REG_PROTOCOL in _errors(d) && !any(x -> x.code === :REG_SIG_MISMATCH && x.context === :hide, d)
        b.action_specs[2] = GM.ActionSpec(; name = :hide, spelling = :identifier, plugin = Int8(2),
            overloads = [GM.ActionOverload(Type[GM.Alterants.Visib, Symbol], Symbol[:symbol, :symbol, :symbol],
                                           Symbol[:declared, :declared, :declared], nothing, Bool, :set, false,
                                           :context_free, :apply, true)], settribute = :hide)
        @test :REG_PROTOCOL in _errors(GM.validate(b))       # a kinds vector longer than the arity — no throw
        # FULL collection: two independent defects ⇒ both reported, in the chain's deterministic order
        b = GM.RegistryBuilder(copy(base.plugins), copy(base.action_specs))
        b.plugins[1] = GM.PlugIn(:labels, :bogus, Dict{Symbol,Bool}, GM.Alterants.setLabels,
                                 GM.Alterants.checkLabels, nothing)
        b.plugins[3] = GM.PlugIn(; altName = :id, setMode = :mutExclusivePerField, altConstructor = GM.Alterants.Id,
                                   setAltInstance = GM.Alterants.setId, contract_version = v"9.0.0")
        d1 = GM.validate(b); d2 = GM.validate(b)
        @test _errors(d1) == [:REG_UNKNOWN_SETMODE, :REG_CONTRACT_VERSION]
        @test _codes(d1) == _codes(d2)                       # A/A-stable refusal
        e = try GM.publish(b); nothing catch err; err end
        @test e isa GM.RegistrationRefused && length(e.diagnostics) == 2
        # the clash law under both arms, through the accumulating form
        specs = [GM.ActionSpec(:alpha, :identifier, Int8(1), [_ov(Type[Dict{Symbol,Bool}, Symbol])], 0, :none, nothing, nothing),
                 GM.ActionSpec(:alpha, :identifier, Int8(2), [_ov(Type[GM.Alterants.Visib, Symbol]; rt = Bool)], 0, :none, nothing, nothing)]
        dR = GM.Diagnostic[]; GM._register_actions_collect!(dR, Dict{Symbol,Int8}(), specs)
        @test [(d.code, d.severity) for d in dR] == [(:REG_DUPLICATE_ACTION, :error)]
        dW = GM.Diagnostic[]; own = GM._register_actions_collect!(dW, Dict{Symbol,Int8}(), specs; disposition = :warn)
        @test [(d.code, d.severity) for d in dW] == [(:REG_DUPLICATE_ACTION, :warning)] && own[:alpha] == Int8(1)
        # candidacy is a WARNING: validate reports it, publish proceeds
        b = GM.RegistryBuilder(copy(base.plugins), copy(base.action_specs))
        b.action_specs[3] = GM.ActionSpec(; name = :show, spelling = :identifier, plugin = Int8(2),
                                            overloads = base.action_specs[3].overloads, sugar_candidacy = :candidate,
                                            settribute = :show)
        d = GM.validate(b)
        @test [(x.code, x.severity) for x in d] == [(:REG_CANDIDACY, :warning)]
        @test GM.publish(b) isa GM.AlterantRegistry
    end

    @testset "full collection at the ENTRY: config + registry diagnostics in ONE result" begin
        D = GM.DEFAULT_REGISTRY
        U = GM.AlterantRegistry(D.plugins, D.sorted_alt_actions, D.action_to_plugin, D.action_index,
                                D.alt_index, D.accum_alt_idxs, D.mutex_alt_idxs, D.action_to_settribute,
                                D.action_specs, D.spec_index)
        r = GM.goMeta(Vector{UInt8}(codeunits("x = 1\n")); config = GM.GoMetaConfig(profile = :nope), registry = U)
        @test r.status === GM.PROCESS_ERROR
        @test _codes(r.diagnostics) == [:ERR_UNKNOWN_PROFILE, :REG_UNPUBLISHED]   # config first, then registry
    end

    @testset "the per-call slot-pool exhaustion refuses typed (r-21; the findfirst-nothing site)" begin
        # Drive `updateMetaHierarchy` directly with every slot occupied: on v0.3.2 the Int8 store
        # of `findfirst(...) === nothing` raised a RAW MethodError (uncontained); T2 refuses with the
        # stable absorb-style message. Input-reachability is NOT claimed here (the walk allocates
        # at most one slot per live level); this is the defensive-invariant half, the Visib-
        # multiplicity precedent.
        ps = GM.BLS.setUpToProcessFromBytes(Vector{UInt8}(codeunits("x = 1\n")))
        st = GM.init_state(ps, GM.GoMetaConfig(), GM.DEFAULT_REGISTRY)
        fill!(st.mh.slot_occupied, true)
        e = Base.ScopedValues.with(GM.STATE => st) do
            try GM.CnS.updateMetaHierarchy(GM.lineMHIdx); nothing catch err; err end
        end
        @test e isa ErrorException && occursin("slot pool exhausted", e.msg)
        @test all(st.mh.slot_occupied)                       # nothing displaced, nothing aliased
    end
end
