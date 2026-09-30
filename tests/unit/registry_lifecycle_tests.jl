# registry_lifecycle_tests.jl — v0.4 T2: the registry LIFECYCLE witnesses (APPEND-ONLY).
#
# IS:   the unit witnesses of Builder → validate → PUBLISH, the ONE validation chain on every public
#       construction route (the route-U cure; no generated/public positional form accepts a seal —
#       the token-gated constructor; the token form itself is reachable by loaded code, the
#       disclosed accident-grade bound), the two-tier typed diagnostics with FULL collection (validate
#       never throws), atomic domain-copy publication, the fingerprint + the T2-bis ONE-check door
#       (the eleven `_SNAPSHOT_FIELDS` compared structurally against the publish-time snapshot —
#       REPRESENTATIVE fields mutated here, not every one; the property file is the proof), the STRICT
#       published-only door at `goMeta(bytes; registry)` AND at the internal callable seam (an
#       unpublished value refuses typed NAMING the sanctioned path), the real freeze gate
#       (`POST_SEAL_MUTATION` on declared, derived, re-ordered, cyclic and callable-identity mutations by
#       conforming code), `register!`'s binding + pool refusals, the slot encoding's distinctions
#       (length-prefixed boundaries, concrete numeric types incl. bit-exact floats, vectors vs tuples,
#       the CLOSED domain — data slots hold concrete data, the refusals witnessed below; the
#       fingerprint is a lossy CACHE KEY since T2-bis — its residual collision classes are
#       fingerprint-only, each caught at the door by the snapshot's `===` leaf compare; the former
#       (iv)/(v) hard-stop classes are CLOSED — docs/public-api.md §1.2), the 0.4.x contract family, warnings emitted at publish, the two
#       exhaustion refusals (the typed registry-grain diagnostic + the stable-message per-call slot-pool
#       guard), and full collection at the entry (config + registry diagnostics in ONE result).
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
        @test isempty(Main.BasicRenderer.outputs(r).render_bytes)           # no parse, no render attempted
        @test isempty(GM.readAltValuesEvals(r.altValues_evals))                # the delivered part carries no rows on the refusal path (REAL-1 R2 #9; measured 2026-09-30: rows 0)
        @test !isempty(r.diagnostics)                                          # non-OK ⇒ non-empty diagnostics — the documented contract (src/state.jl; measured: 1, :REG_UNPUBLISHED)
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
        # a mutation through a published container (the finding-3 class): the live record no
        # longer matches the snapshot (T2-bis — the length gate on action_specs)
        push!(R.action_specs, GM.ActionSpec(:zzz, :identifier, Int8(2),
            [_ov(Type[GM.Alterants.Visib, Symbol]; rt = Bool)], 0, :none, nothing, nothing))
        r1 = GM.goMeta(Vector{UInt8}(codeunits("x = 1\n#~ hide\n\ny = 2\n")); registry = R)
        @test r1.status === GM.PROCESS_ERROR
        @test _codes(r1.diagnostics) == [:POST_SEAL_MUTATION]
        @test isempty(Main.BasicRenderer.outputs(r1).render_bytes)
        @test isempty(GM.readAltValuesEvals(r1.altValues_evals))               # the delivered part carries no rows on the refusal path (REAL-1 R2 #9; measured: rows 0)
        @test !isempty(r1.diagnostics)                                         # non-OK ⇒ non-empty diagnostics (measured: 1, :POST_SEAL_MUTATION)
        # (cure batch 1; T2-bis) a mutated DERIVED table — the declared record untouched — is
        # refused too: every table is a walked snapshot field (the CRX after-T2 breaker's
        # `action_to_settribute[:hide] = :show` attack fires at the entry's element path)
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
        # a plugin swapped for one with a SAME-NAMED evil setter (folds identically in the
        # fingerprint) is refused by the snapshot's `===` leaf compare on the setter field (T2-bis)
        R5 = GM.publish(GM.default_registry_builder())
        # a GENUINELY same-named function from another module (same `nameof` text, different identity)
        @eval module _EvilVisib; setVisib(args...) = nothing; end
        evil = _EvilVisib.setVisib
        @test nameof(evil) === nameof(GM.Alterants.setVisib)
        R5.plugins[2] = GM.PlugIn(:Visib, :mutExclusive, GM.Alterants.Visib, evil, nothing, nothing)
        @test _codes(GM._registry_door_check(R5)) == [:POST_SEAL_MUTATION]
        # (T2-bis — one of the TWO named append-only exceptions, T2BIS-DESIGN §8) the snapshot
        # BINDING is immutable: a NamedTuple has no `setindex!`, so the baseline binding cannot
        # be rewritten to match the swap through the published value (the snapshot's MEMBERS are
        # mutable — the disclosed §11 residue, deliberately NOT pinned here)
        @test R5._snapshot isa NamedTuple
        @test_throws MethodError setindex!(R5._snapshot, evil, :plugins)
        # no GENERATED/public positional form accepts a seal — the token form exists for the lifecycle
        # and is reachable by loaded code (the disclosed accident-grade bound); the all-fields constructor is gone (the forge
        # attack: copying DEFAULT_REGISTRY.seal onto hand-built tables)
        D = GM.DEFAULT_REGISTRY
        @test_throws MethodError GM.AlterantRegistry(D.plugins, D.sorted_alt_actions, D.action_to_plugin,
            D.action_index, D.alt_index, D.accum_alt_idxs, D.mutex_alt_idxs, D.action_to_settribute,
            D.action_specs, D.spec_index, D.seal)
        @test_throws MethodError GM.AlterantRegistry(D.plugins, D.sorted_alt_actions, D.action_to_plugin,
            D.action_index, D.alt_index, D.accum_alt_idxs, D.mutex_alt_idxs, D.action_to_settribute,
            D.action_specs, D.spec_index, D.seal, D._snapshot)   # (T2-bis: the second named exception — the field is `_snapshot` now)
        # the callable SEAM runs the door too (cure batch 1): an unpublished registry cannot drive it
        U = GM.AlterantRegistry(D.plugins, D.sorted_alt_actions, D.action_to_plugin, D.action_index,
                                D.alt_index, D.accum_alt_idxs, D.mutex_alt_idxs, D.action_to_settribute,
                                D.action_specs, D.spec_index)
        ps = GM.BLS.setUpToProcessFromBytes(Vector{UInt8}(codeunits("x = 1\n#~ hide\n\ny = 2\n")))
        GM.BLS.parseBLS(ps, 1, -1)
        rs = GM.run_absorb_apply!(ps; registry = U)
        @test rs.status === GM.PROCESS_ERROR && _codes(rs.diagnostics) == [:REG_UNPUBLISHED]
        @test isempty(Main.BasicRenderer.outputs(rs).render_bytes)
        # the injective slot encoding (cure batch 1): a re-cut vector boundary no longer collides
        @test GM._slot_text([Symbol("a,b")]) != GM._slot_text([:a, :b])
        @test GM._slot_text(GM.Declared(Symbol[:a, :b])) != GM._slot_text(GM.Declared(Symbol[Symbol("a,b")]))
        # (cure batch 2) the concrete numeric type and the container kind are part of the value
        @test GM._slot_text(Int8(1)) != GM._slot_text(Int64(1))
        @test GM._slot_text([:a]) != GM._slot_text((:a,))
        @test GM._slot_text(GM.Declared(Int8(1))) != GM._slot_text(GM.Declared(1))
        # (cure batch 2) validate is total over a PARAMETRIC (`where`) setter — a UnionAll method
        # signature is unwrapped, never indexed
        @eval module _ParamSetter
            paramset(store::T, ::Symbol, x::Symbol) where {T<:AbstractDict} = (store[x] = true; nothing)
        end
        base = GM.default_registry_builder()
        bp = GM.RegistryBuilder(copy(base.plugins), copy(base.action_specs))
        GM.register!(bp, GM.PlugIn(:pz, :accumulate, Dict{Symbol,Bool}, _ParamSetter.paramset, nothing, nothing),
                     GM.ActionSpec(; name = :pzset, spelling = :identifier, plugin = Int8(5),
                                     overloads = [GM.ActionOverload(; sig_types = Type[Dict{Symbol,Bool}, Symbol, Symbol],
                                                                      kinds = Symbol[:symbol])]))
        dp = GM.validate(bp)                                  # must return, not throw
        @test dp isa Vector{GM.Diagnostic}
        # (cure batch 2) broken records are skipped by INDEX: a malformed duplicate does not hide a
        # well-formed duplicate's tier-2 defect
        bd = GM.RegistryBuilder(copy(base.plugins), copy(base.action_specs))
        push!(bd.action_specs, GM.ActionSpec(:zzdup, :bogusspelling, Int8(2),
            [_ov(Type[GM.Alterants.Visib, Symbol]; rt = Bool)], 0, :none, nothing, nothing))       # malformed
        push!(bd.action_specs, GM.ActionSpec(:zzdup, :identifier, Int8(2),
            [_ov(Type[GM.Alterants.Visib, Symbol]; rt = Float64)], 0, :none, nothing, nothing))    # well-formed, bad algebra
        dd = GM.validate(bd)
        @test :REG_PROTOCOL in _errors(dd) && :REG_VALUE_ALGEBRA in _errors(dd)
        # (cure batch 2) register! refuses the ACTION pool too
        ba = GM.RegistryBuilder()
        many = [GM.ActionSpec(Symbol("act", i), :identifier, Int8(1),
                              [_ov(Type[Dict{Symbol,Bool}, Symbol])], 0, :none, nothing, nothing) for i in 1:128]
        e = try GM.register!(ba, GM.PlugIn(:big, :accumulate, Dict{Symbol,Bool}, GM.Alterants.setLabels, nothing, nothing),
                             many...); nothing catch err; err end
        @test e isa GM.RegistrationRefused && _errors(e.diagnostics) == [:REG_SLOT_EXHAUSTED]
        @test isempty(ba.plugins) && isempty(ba.action_specs)
        @test GM.next_plugin_index(ba) == 1 && GM.next_plugin_index(GM.default_registry_builder()) == 5
        # (cure batch 2) route U reports REG_DERIVED_TABLES ALONGSIDE an independent record defect
        D = GM.DEFAULT_REGISTRY
        badp = copy(D.plugins); badp[1] = GM.PlugIn(:labels, :bogus, Dict{Symbol,Bool}, GM.Alterants.setLabels,
                                                    GM.Alterants.checkLabels, nothing)
        bad_idx = copy(D.action_index); bad_idx[:hide] = Int8(99)
        e = try GM.AlterantRegistry(badp, D.sorted_alt_actions, D.action_to_plugin, bad_idx, D.alt_index,
                                    D.accum_alt_idxs, D.mutex_alt_idxs, D.action_to_settribute,
                                    D.action_specs, D.spec_index); nothing catch err; err end
        @test e isa GM.RegistrationRefused
        @test :REG_UNKNOWN_SETMODE in _errors(e.diagnostics) && :REG_DERIVED_TABLES in _errors(e.diagnostics)
        # (cure batch 2) reflection diagnostics come in DECLARATION order across two setters, twice
        @eval module _TwoSetters
            s1(::Dict{Symbol,Bool}, ::Symbol) = nothing; s1(::Dict{Symbol,Bool}, ::Symbol, ::Int) = nothing
            s2(::Dict{Symbol,Int}, ::Symbol) = nothing;  s2(::Dict{Symbol,Int}, ::Symbol, ::Int) = nothing
        end
        b2 = GM.RegistryBuilder()
        GM.register!(b2, GM.PlugIn(:one, :accumulate, Dict{Symbol,Bool}, _TwoSetters.s1, nothing, nothing),
                     GM.ActionSpec(; name = :o1, spelling = :identifier, plugin = Int8(1),
                                     overloads = [GM.ActionOverload(; sig_types = Type[Dict{Symbol,Bool}, Symbol])]))
        GM.register!(b2, GM.PlugIn(:two, :accumulate, Dict{Symbol,Int}, _TwoSetters.s2, nothing, nothing),
                     GM.ActionSpec(; name = :o2, spelling = :identifier, plugin = Int8(2),
                                     overloads = [GM.ActionOverload(; sig_types = Type[Dict{Symbol,Int}, Symbol])]))
        r1 = [(d.code, d.context) for d in GM.validate(b2) if d.code === :REG_SIG_MISMATCH]
        r2 = [(d.code, d.context) for d in GM.validate(b2) if d.code === :REG_SIG_MISMATCH]
        @test r1 == r2 && [c for (_, c) in r1] == [:s1, :s2]   # the undeclared extra methods, setters in declaration order
        # (cure batch 2, interim until T7) a PUBLISHED custom registry WITHOUT the built-in Visib RUNS
        bc = GM.RegistryBuilder()
        GM.register!(bc, GM.PlugIn(:bag, :accumulate, Dict{Symbol,Bool}, GM.Alterants.setLabels, GM.Alterants.checkLabels, nothing),
                     GM.ActionSpec(; name = Symbol(":"), spelling = :operator, plugin = Int8(1),
                                     overloads = [GM.ActionOverload(; sig_types = Type[Dict{Symbol,Bool}, Symbol],
                                                                      vararg_kind = :symbol, queryable = true)],
                                     sugar_candidacy = :activated))
        Rc = GM.publish(bc)
        rc = GM.goMeta(Vector{UInt8}(codeunits("x = 1\n#~ :label1\n\ny = 2\n")); registry = Rc)
        @test rc.status === GM.PROCESS_OK && !isempty(Main.BasicRenderer.outputs(rc).render_bytes)
        # (cure batch 3) the attacked shape "a Visib record declaring NO write-back key" is REFUSED by
        # the record's own shadow law before it can run — the resolved Visib key is always one of the
        # instance's field names (hide/show/discard), all settribute keys, so `settribute = nothing`
        # on them is `REG_RESERVED_SHADOW`; the driver's `get(action_to_settribute, …)` guard is
        # NECESSARY even for a VALIDATED registry (t2r3 A-4 / t2r4 A-7: a validated CUSTOM Visib-plugin
        # action with no `settribute` can map onto a built-in field) — cured BY the guard, not refuted
        bv = GM.RegistryBuilder(GM.DEFAULT_REGISTRY)
        h = bv.action_specs[2]
        bv.action_specs[2] = GM.ActionSpec(; name = :hide, spelling = :identifier, plugin = Int8(2),
                                             overloads = h.overloads, settribute = nothing)
        e = try GM.publish(bv); nothing catch err; err end
        @test e isa GM.RegistrationRefused && :REG_RESERVED_SHADOW in _errors(e.diagnostics)
        # (cure batch 3) floats fold BIT-EXACTLY: two NaN payloads with different bits differ
        nan1 = reinterpret(Float64, 0x7ff8000000000001); nan2 = reinterpret(Float64, 0x7ff8000000000002)
        @test string(nan1) == string(nan2) && GM._slot_text(nan1) != GM._slot_text(nan2)
        # (cure batch 3) a published container mutated into a CYCLE is refused as a mutation, not a StackOverflow
        bcy = GM.RegistryBuilder(GM.DEFAULT_REGISTRY)
        bcy.action_specs[3] = GM.ActionSpec(; name = :show, spelling = :identifier, plugin = Int8(2),
                                              overloads = bcy.action_specs[3].overloads, settribute = :show,
                                              default = GM.Declared(Any[]))
        Rcy = GM.publish(bcy)
        v = Rcy.action_specs[3].default.value; push!(v, v)
        @test _codes(GM._registry_door_check(Rcy)) == [:POST_SEAL_MUTATION]
        # (cure batch 3) a PLUGIN-level structural defect does not mark the actions broken: a sound
        # action's tier-2 defect is still reported
        bpl = GM.RegistryBuilder(GM.DEFAULT_REGISTRY)
        bpl.plugins[1] = GM.PlugIn(; altName = :labels, setMode = :accumulate, altConstructor = Dict{Symbol,Bool},
                                     setAltInstance = GM.Alterants.setLabels, getAltInstance = GM.Alterants.checkLabels,
                                     capture = GM.CaptureDecl(Dict{Symbol,Bool}, :per_bogus, :many, nothing))
        push!(bpl.action_specs, GM.ActionSpec(:zzalg, :identifier, Int8(2),
            [_ov(Type[GM.Alterants.Visib, Symbol]; rt = Float64)], 0, :none, nothing, nothing))
        dpl = GM.validate(bpl)
        @test :REG_PROTOCOL in _errors(dpl) && :REG_VALUE_ALGEBRA in _errors(dpl)
        # (cure batch 4) the encodable domain is CLOSED — composite numbers fold structurally, an
        # unknown value type is REFUSED at validation, never folded by a lossy fallback
        @test GM._slot_text(complex(nan1, 0.0)) != GM._slot_text(complex(nan2, 0.0))
        @test GM._slot_text(1//2) != GM._slot_text(2//4 + 0//1 + 1//3)   # structural, not display
        @eval module _Opaque; struct Thing; x::Int; end; end
        bu = GM.RegistryBuilder(GM.DEFAULT_REGISTRY)
        bu.action_specs[3] = GM.ActionSpec(; name = :show, spelling = :identifier, plugin = Int8(2),
                                             overloads = bu.action_specs[3].overloads, settribute = :show,
                                             default = GM.Declared(_Opaque.Thing(1)))
        du = GM.validate(bu)
        @test :REG_PROTOCOL in _errors(du) && occursin("no canonical encoder", only(filter(x -> x.code === :REG_PROTOCOL, du)).message)
        @test_throws GM.RegistrationRefused GM.publish(bu)
        # (cure batch 4) a PRE-publication cycle is a validation refusal, never a leaked internal exception
        bpc = GM.RegistryBuilder(GM.DEFAULT_REGISTRY)
        cyc = Any[]; push!(cyc, cyc)
        bpc.action_specs[3] = GM.ActionSpec(; name = :show, spelling = :identifier, plugin = Int8(2),
                                              overloads = bpc.action_specs[3].overloads, settribute = :show,
                                              default = GM.Declared(cyc))
        dpc = GM.validate(bpc)
        @test :REG_PROTOCOL in _errors(dpc) && occursin("CYCLIC", only(filter(x -> x.code === :REG_PROTOCOL, dpc)).message)
        e = try GM.publish(bpc); nothing catch err; err end
        @test e isa GM.RegistrationRefused
        # (cure batch 4) a published Dict mutated into a cycle is refused as a mutation (the Dict encoder is guarded)
        bdc = GM.RegistryBuilder(GM.DEFAULT_REGISTRY)
        bdc.action_specs[3] = GM.ActionSpec(; name = :show, spelling = :identifier, plugin = Int8(2),
                                              overloads = bdc.action_specs[3].overloads, settribute = :show,
                                              default = GM.Declared(Dict{Any,Any}(:k => 1)))
        Rdc = GM.publish(bdc)
        dd = Rdc.action_specs[3].default.value; dd[:self] = dd
        @test _codes(GM._registry_door_check(Rdc)) == [:POST_SEAL_MUTATION]
        # (cure batch 4) a DAG (the same container reached twice, no cycle) is NOT reported cyclic
        shared = Symbol[:a]
        @test GM._slot_text(Any[shared, shared]) == GM._slot_text(Any[Symbol[:a], Symbol[:a]])
        # (cure batch 4) dict encoding is canonical over entry text, not `string(key)` order
        @test GM._slot_text(Dict{Any,Any}(:x => 1, "x" => 2)) == GM._slot_text(Dict{Any,Any}("x" => 2, :x => 1))
        # (cure batch 5) DATA SLOTS HOLD DATA: a Function inside a declared value/payload is refused at
        # validation (a same-named swap there would be invisible to the fingerprint fold); the
        # designated callable fields still encode by name
        @test_throws GM._UnencodableSlot GM._slot_text(GM.Declared(Any[sin]))
        @test_throws GM._UnencodableSlot GM._slot_text(GM.EffectRow(:mark, sin))
        @test GM._slot_text(sin) == "f3:sin"
        bfn = GM.RegistryBuilder(GM.DEFAULT_REGISTRY)
        bfn.action_specs[3] = GM.ActionSpec(; name = :show, spelling = :identifier, plugin = Int8(2),
                                              overloads = bfn.action_specs[3].overloads, settribute = :show,
                                              default = GM.Declared(Any[sin]))
        dfn = GM.validate(bfn)
        @test :REG_PROTOCOL in _errors(dfn) && occursin("slot default", only(filter(x -> x.code === :REG_PROTOCOL, dfn)).message)
        # (cure batch 5) CONCRETE containers only: a range/view is not a Vector — refused, so `1:3` can
        # never collide with `[1,2,3]` inside a published value
        @test_throws GM._UnencodableSlot GM._slot_text(1:3)
        @test_throws GM._UnencodableSlot GM._slot_text(view([1, 2, 3], 1:2))
        @test GM._slot_text([1, 2, 3]) isa String
        # (cure batch 5) type parameters are TYPE-TAGGED values
        @test GM._slot_text(Val{Int8(1)}) != GM._slot_text(Val{Int64(1)})
        @test GM._slot_text(Val{:x}) != GM._slot_text(Val{1})
        @test GM._type_text(Tuple{Vararg{Symbol}}) isa String && GM._type_text(Vector{Symbol}) isa String
        # (cure batch 5) the publish → mutate → DOOR witness of the bit-exact composite encoding (t2r4 A-4:
        # the batch-4 witness only compared two encodings and passed on the pre-batch tree)
        bcx = GM.RegistryBuilder(GM.DEFAULT_REGISTRY)
        bcx.action_specs[3] = GM.ActionSpec(; name = :show, spelling = :identifier, plugin = Int8(2),
                                              overloads = bcx.action_specs[3].overloads, settribute = :show,
                                              default = GM.Declared(Any[complex(nan1, 0.0)]))
        Rcx = GM.publish(bcx)
        @test isempty(GM._registry_door_check(Rcx))
        Rcx.action_specs[3].default.value[1] = complex(nan2, 0.0)
        @test _codes(GM._registry_door_check(Rcx)) == [:POST_SEAL_MUTATION]
        # (cure batch 5) a published value mutated from encodable to UNENCODABLE is a mutation at the door
        Rcx.action_specs[3].default.value[1] = 'c'
        @test _codes(GM._registry_door_check(Rcx)) == [:POST_SEAL_MUTATION]
        # (cure batch 5) Rational: concrete-type-tagged + structural; BigInt parts are outside the machine domain
        @test GM._slot_text(Rational{Int8}(1, 2)) != GM._slot_text(1//2)
        @test_throws GM._UnencodableSlot GM._slot_text(big(1)//2)
        # (cure batch 5) a failed encode leaves the visiting set clean — a second encode in the same scope succeeds
        dv = Dict{Any,Any}(:k => 'c')
        @test_throws GM._UnencodableSlot GM._slot_text(Any[dv])
        dv[:k] = 1
        @test GM._slot_text(Any[dv]) isa String
        # (cure batch 5) encodability is probed PER SLOT with FULL collection: two defective records ⇒ two
        # diagnostics, each naming its record + slot
        bps = GM.RegistryBuilder(GM.DEFAULT_REGISTRY)
        bps.action_specs[3] = GM.ActionSpec(; name = :show, spelling = :identifier, plugin = Int8(2),
                                              overloads = bps.action_specs[3].overloads, settribute = :show,
                                              default = GM.Declared(1:3))
        bps.action_specs[2] = GM.ActionSpec(; name = :hide, spelling = :identifier, plugin = Int8(2),
                                              overloads = bps.action_specs[2].overloads, settribute = :hide,
                                              default = GM.Declared('c'))
        dps = filter(x -> x.code === :REG_PROTOCOL, GM.validate(bps))
        @test length(dps) == 2 && all(x -> occursin("slot default", x.message), dps) &&
              Set(x.context for x in dps) == Set([:hide, :show])
        # deep-copy publication: a NESTED declared container of the builder is not shared with the published value
        bdp = GM.RegistryBuilder(GM.DEFAULT_REGISTRY)
        bdp.plugins[2] = GM.PlugIn(; altName = :Visib, setMode = :mutExclusive, altConstructor = GM.Alterants.Visib,
                                     setAltInstance = GM.Alterants.setVisib, constraints = [GM.MutEx([:hide, :show])])
        Rdp = GM.publish(bdp)
        push!(bdp.plugins[2].constraints[1].actions, :discard)
        @test Rdp.plugins[2].constraints[1].actions == [:hide, :show] && isempty(GM._registry_door_check(Rdp))
        # (cure batch 3) the digest form is ABSOLUTELY anchored (a trailing newline is refused)
        @test_throws ErrorException GM.DomainRef("x", "sha256:" * "0"^64 * "\n")
        # (cure batch 3) next_plugin_index is Int8 and passes straight into ActionSpec; RegistryBuilder(published) preloads
        bx = GM.RegistryBuilder(GM.DEFAULT_REGISTRY)
        @test length(bx.plugins) == 4 && bx.plugins !== GM.DEFAULT_REGISTRY.plugins
        i5 = GM.next_plugin_index(bx)
        @test i5 isa Int8 && i5 == 5
        GM.register!(bx, GM.PlugIn(:bag2, :accumulate, Dict{Symbol,Bool}, GM.Alterants.setLabels, GM.Alterants.checkLabels, nothing),
                     GM.ActionSpec(; name = :bagset, spelling = :identifier, plugin = i5,
                                     overloads = [GM.ActionOverload(; sig_types = Type[Dict{Symbol,Bool}, Symbol],
                                                                      vararg_kind = :symbol, queryable = true)]))
        Rx = GM.publish(bx)
        rx = GM.goMeta(Vector{UInt8}(codeunits("x = 1\n#~ hide\n\ny = 2\n")); registry = Rx)
        @test rx.status === GM.PROCESS_OK
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

    @testset "the per-call slot-pool exhaustion refuses with the stable GUARDED message (r-21; the findfirst-nothing site; typed conversion = the diagnostics catalogue row)" begin
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

    @testset "T2-bis: the EIGHT snapshot-door witnesses W1–W8 (T2BIS-DESIGN §8; APPENDED)" begin
        # W1 — the CONTAINED route refuses a published value mutated into a CYCLE, typed,
        # naming the record + slot via the path (Rcx/Rcy above are testset-locals — rebuilt)
        b1 = GM.RegistryBuilder(GM.DEFAULT_REGISTRY)
        b1.action_specs[3] = GM.ActionSpec(; name = :show, spelling = :identifier, plugin = Int8(2),
                                             overloads = b1.action_specs[3].overloads, settribute = :show,
                                             default = GM.Declared(Any[]))
        R1 = GM.publish(b1)
        v1 = R1.action_specs[3].default.value; push!(v1, v1)
        e1 = try GM.RegistryBuilder(R1); nothing catch err; err end
        @test e1 isa GM.RegistrationRefused
        @test occursin("show", e1.diagnostics[1].message) && occursin("default", e1.diagnostics[1].message)
        # W2 — the contained route refuses an out-of-domain value ('c'), naming the TYPE + path
        b2 = GM.RegistryBuilder(GM.DEFAULT_REGISTRY)
        b2.action_specs[3] = GM.ActionSpec(; name = :show, spelling = :identifier, plugin = Int8(2),
                                             overloads = b2.action_specs[3].overloads, settribute = :show,
                                             default = GM.Declared(Any[1]))
        R2b = GM.publish(b2)
        R2b.action_specs[3].default.value[1] = 'c'
        e2 = try GM.RegistryBuilder(R2b); nothing catch err; err end
        @test e2 isa GM.RegistrationRefused
        @test occursin("Char", e2.diagnostics[1].message) && occursin("action_specs[3].default.value[1]", e2.diagnostics[1].message)
        # W3 — the ASYMMETRY witness: rewriting the SNAPSHOT side ALONE fires (the length gate)
        R3b = GM.publish(GM.default_registry_builder())
        push!(R3b._snapshot.plugins, R3b.plugins[1])
        d3 = GM._registry_door_check(R3b)
        @test _codes(d3) == [:POST_SEAL_MUTATION]
        @test occursin("at plugins", d3[1].message)
        # W4 — the seal-via-token-seam witness: `t` comes from the DERIVATION form (§5's ban
        # excludes a written keyword list at this snapshot-carrying site); a FOREIGN seal beside
        # DEFAULT's snapshot fires at path `seal` (a LEAF `===` failure), as does `seal = nothing`
        D = GM.DEFAULT_REGISTRY
        t4 = GM._derive_tables(D.plugins, D.action_specs)
        F4 = GM.AlterantRegistry(GM._SealToken(), D.plugins, D.action_specs, t4,
                                 "fnv1a64:0000000000000000", D._snapshot)
        d4a = GM._registry_door_check(F4)
        @test _codes(d4a) == [:POST_SEAL_MUTATION] && occursin("at seal", d4a[1].message)
        F4n = GM.AlterantRegistry(GM._SealToken(), D.plugins, D.action_specs, t4, nothing, D._snapshot)
        d4b = GM._registry_door_check(F4n)
        @test _codes(d4b) == [:POST_SEAL_MUTATION] && occursin("at seal", d4b[1].message)
        # W5 — KNOWN OPEN (v) closes: `altConstructor = Val{'c'}` is a SLOT-NAMED validate row
        # (record in context, slot in the message) + a typed publish refusal
        b5 = GM.RegistryBuilder(GM.DEFAULT_REGISTRY)
        b5.plugins[1] = GM.PlugIn(; altName = :labels, setMode = :accumulate, altConstructor = Val{'c'},
                                    setAltInstance = GM.Alterants.setLabels,
                                    getAltInstance = GM.Alterants.checkLabels)
        d5 = GM.validate(b5)
        @test any(x -> x.code === :REG_PROTOCOL && x.context === :labels &&
                       occursin("altConstructor", x.message), d5)
        @test_throws GM.RegistrationRefused GM.publish(b5)
        # W6 — a RECORD STRUCT in declared data refuses at validate (the slot-named row, never
        # the publish-containment generic row) + a typed publish refusal
        b6 = GM.RegistryBuilder(GM.DEFAULT_REGISTRY)
        b6.action_specs[3] = GM.ActionSpec(; name = :show, spelling = :identifier, plugin = Int8(2),
                                             overloads = b6.action_specs[3].overloads, settribute = :show,
                                             default = GM.Declared(GM.ActionOverload(; sig_types = Type[])))
        d6 = GM.validate(b6)
        @test any(x -> x.code === :REG_PROTOCOL && x.context === :show &&
                       occursin("slot default", x.message) && occursin("ActionOverload", x.message), d6)
        @test_throws GM.RegistrationRefused GM.publish(b6)
        # W7 — the contained route ENFORCES the position rules on its unvalidated input: a
        # Function IN DATA refuses typed, the message naming the position rule + the path
        b7 = GM.RegistryBuilder(GM.DEFAULT_REGISTRY)
        b7.action_specs[3] = GM.ActionSpec(; name = :show, spelling = :identifier, plugin = Int8(2),
                                             overloads = b7.action_specs[3].overloads, settribute = :show,
                                             default = GM.Declared(Any[1]))
        R7 = GM.publish(b7)
        R7.action_specs[3].default.value[1] = sin
        e7 = try GM.RegistryBuilder(R7); nothing catch err; err end
        @test e7 isa GM.RegistrationRefused
        @test occursin("position rule", e7.diagnostics[1].message) &&
              occursin("action_specs[3].default.value[1]", e7.diagnostics[1].message)
        # W8 — the MINT-PARITY witness of the DATA-WINS precedence: an atom nested in data has
        # its `evaluate` REFUSED (a Function in data), never the generic containment row
        b8 = GM.RegistryBuilder(GM.DEFAULT_REGISTRY)
        b8.action_specs[3] = GM.ActionSpec(; name = :show, spelling = :identifier, plugin = Int8(2),
                                             overloads = b8.action_specs[3].overloads, settribute = :show,
                                             default = GM.Declared(GM.ConditionAtom(:n, "s", sin)))
        d8 = GM.validate(b8)
        @test any(x -> x.code === :REG_PROTOCOL && x.context === :show &&
                       occursin("slot default", x.message), d8)
        @test_throws GM.RegistrationRefused GM.publish(b8)
    end

    @testset "T2-bis crx-t2bis cure witnesses (A1/A2/A3; APPENDED)" begin
        # CW1 (A1) — an admitted user UnionAll carrying its OWN `Base.show` (legitimate
        # specialization): the structural type text dispatches nothing, so the record
        # publishes and the door is silent (before the cure, `string()` dispatched the user
        # show and `publish` leaked the raw error — probe P6-A1)
        @eval module _CrxPoison
            struct Poison{T} end
            Base.show(io::IO, ::Type{Poison}) = error("A1-BOOM")
            # (v0.4 T3, the round's T3P-C3 cure — an append-only line, disclosed §S2.15):
            # the UnionAll `Poison` had no zero-argument method and would trip T3's eager
            # DEP_MISSING gate; this ctor keeps `altConstructor = Poison` — and with it the
            # only UnionAll-at-altConstructor fold coverage — while the witness itself
            # never calls the constructor (publish + door only).
            Poison() = Poison{Int}()
        end
        bc1 = GM.RegistryBuilder(GM.DEFAULT_REGISTRY)
        bc1.plugins[2] = GM.PlugIn(; altName = :Visib, setMode = :mutExclusive,
                                     altConstructor = _CrxPoison.Poison,
                                     setAltInstance = GM.Alterants.setVisib)
        Rc1 = GM.publish(bc1)
        @test Rc1 isa GM.AlterantRegistry
        @test isempty(GM._registry_door_check(Rc1))
        # CW2 (A2) — a flag-armed THROWING user `hash` on an own Type key: validation and the
        # fold never hash, but the copier's Dict-rebuild fill does — the throw converts to a
        # TYPED refusal, never a raw exception out of `publish` (probe P6-A2)
        @eval module _CrxHashBomb
            struct K end
            const ARMED = Base.RefValue(false)
            Base.hash(::Type{K}, h::UInt) = ARMED[] ? error("A2-BOOM") : (h ⊻ 0x5ca1ab1e)
        end
        bc2 = GM.RegistryBuilder(GM.DEFAULT_REGISTRY)
        s2c = bc2.action_specs[3]
        bc2.action_specs[3] = GM.ActionSpec(; name = s2c.name, spelling = s2c.spelling,
            plugin = s2c.plugin, overloads = s2c.overloads, settribute = s2c.settribute,
            default = GM.Declared(Dict{Any,Any}(_CrxHashBomb.K => 1)))
        _CrxHashBomb.ARMED[] = true
        ec2 = try GM.publish(bc2); nothing catch err; err end
        _CrxHashBomb.ARMED[] = false
        @test ec2 isa GM.RegistrationRefused
        @test _errors(ec2.diagnostics) == [:REG_PROTOCOL]
        # CW3 (A3) — UNDEFINED container elements never read raw: a resize!-widened published
        # vector FIRES at the door (was an UndefRefError leak — probe P6-A3); an undef-slot
        # declared vector refuses slot-named at validate (never a throw); the contained
        # preload route refuses typed
        bc3 = GM.RegistryBuilder(GM.DEFAULT_REGISTRY)
        s3c = bc3.action_specs[3]
        bc3.action_specs[3] = GM.ActionSpec(; name = s3c.name, spelling = s3c.spelling,
            plugin = s3c.plugin, overloads = s3c.overloads, settribute = s3c.settribute,
            default = GM.Declared(Any[1]))
        Rc3 = GM.publish(bc3)
        vc3 = Rc3.action_specs[3].default.value
        resize!(vc3, 0); resize!(vc3, 1)
        @test _codes(GM._registry_door_check(Rc3)) == [:POST_SEAL_MUTATION]
        ec3 = try GM.RegistryBuilder(Rc3); nothing catch err; err end
        @test ec3 isa GM.RegistrationRefused
        bc4 = GM.RegistryBuilder(GM.DEFAULT_REGISTRY)
        s4c = bc4.action_specs[3]
        bc4.action_specs[3] = GM.ActionSpec(; name = s4c.name, spelling = s4c.spelling,
            plugin = s4c.plugin, overloads = s4c.overloads, settribute = s4c.settribute,
            default = GM.Declared(Vector{Any}(undef, 1)))
        dc4 = GM.validate(bc4)
        @test any(x -> x.code === :REG_PROTOCOL && occursin("UNDEFINED element", x.message), dc4)
    end
end
