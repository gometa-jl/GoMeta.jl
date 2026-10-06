# registry_lifecycle_tests.jl — v0.4 T2: the registry LIFECYCLE witnesses (APPEND-ONLY).
#
# IS:   the unit witnesses of Builder → validate → PUBLISH, the remaining checks on every public
#       construction route (the route-U cure; no generated/public positional form accepts a seal —
#       the token-gated constructor; the token form itself is reachable by loaded code, the
#       disclosed accident-grade bound; the validation chain of v0.4 T2–T4 left at stage 5's E4 — census
#       row 3, OWNER-WORDS §317: the domain probe and the capture mode-gate laws remain — the vocabulary check
#       left at stage 5's E9), the typed diagnostics with FULL collection (validate
#       never throws), atomic domain-copy publication, the fingerprint + the T2-bis ONE-check door
#       (the eleven `_SNAPSHOT_FIELDS` compared structurally against the publish-time snapshot —
#       REPRESENTATIVE fields mutated here, not every one; the property file is the proof), the STRICT
#       published-only door at `goMeta(bytes; registry)` (an unpublished value refuses typed NAMING the
#       sanctioned path; the internal callable seam that ran the door too left at stage 5's E2), the real freeze gate
#       (`POST_SEAL_MUTATION` on declared, derived, re-ordered, cyclic and callable-identity mutations by
#       conforming code), `register!`'s binding + pool refusals, the slot encoding's distinctions
#       (length-prefixed boundaries, concrete numeric types incl. bit-exact floats, vectors vs tuples,
#       the CLOSED domain — data slots hold concrete data, the refusals witnessed below; the
#       fingerprint is a lossy CACHE KEY since T2-bis — its residual collision classes are
#       fingerprint-only, each caught at the door by the snapshot's `===` leaf compare; the former
#       (iv)/(v) hard-stop classes are CLOSED — docs/public-api.md §1.2), `register!`'s pool refusal + the
#       stable-message per-call slot-pool guard, and full collection at the entry (config + registry
#       diagnostics in ONE result).
# DOES: builds registries through every route, mutates published values, drives the door, and pins
#       the codes and the messages' load-bearing substrings.
# REASONING: the golden layer proves the PUBLISHED default is byte-neutral; only these witnesses prove
#       the refusals fire, fully, typed, and in deterministic order.
# PURPOSE: the T2 acceptance rows of the v0.4 build (M-AC-9 registry gates; the door; FM-REG rows).

using Test
import GoMeta as GM

_plugin_with_default(p, d) = GM.PlugIn(; altName = p.altName, setMode = p.setMode, altConstructor = p.altConstructor,
        setAltInstance = p.setAltInstance, getAltInstance = p.getAltInstance, precedencesTuple = p.precedencesTuple,
        default = d, capture = p.capture)   # stage 2's commit 3-ii: the declared default is the ALTERANT's — the record `p` with the slot `d`, every other field copied

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
        @test _errors(r.diagnostics) == [:REG_UNPUBLISHED]                    # [C14h1] card C14 (h), R-V04B-96 (his §306): the refusal's one row is an :error (MEASURED 2026-10-03, receipts/S8-branch/PROBES-c14-pins_cd3ee9d3.txt) — the clause "PROCESS_ERROR ⇒ at least one :error row" (src/state.jl) pinned on the refusal path, where _configErrorDelivery sets PROCESS_ERROR without reading severity
        @test occursin("RegistryBuilder → validate → publish", r.diagnostics[1].message)
        @test isempty(Main.BasicRenderer.outputs(r).render_bytes)           # no parse, no render attempted
        @test isempty(GM.readAltValuesEvals(r.altValues_evals))                # the delivered part carries no rows on the refusal path (REAL-1 R2 #9; measured 2026-09-30: rows 0)
        @test isempty(GM.BLS.children(r.blsComponentTree))                     # [C14g2] card C14 (g), R-V04B-96: the refusal delivers a tree built from EMPTY bytes — no Block, read through the door (re-cut from the callable seam's door block, which left with the seam at stage 5's E2; its (g1) "not the injected state" and (h3) rows retired with the injection — goMeta's door refusal is pinned here, [C14h1])
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
        @test _errors(r1.diagnostics) == [:POST_SEAL_MUTATION]                 # [C14h2] …and the post-seal refusal's one row an :error (MEASURED)
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
        # (the cure-batch-2 broken-record index witness left at stage 5's E4 with the tier-1/tier-2 chain)
        # (cure batch 2) register! refuses the ACTION pool too
        ba = GM.RegistryBuilder()
        many = [GM.ActionSpec(Symbol("act", i), :identifier, Int8(1),
                              [_ov(Type[Dict{Symbol,Bool}, Symbol])], 0, :none, nothing, nothing) for i in 1:128]
        e = try GM.register!(ba, GM.PlugIn(:big, :accumulate, Dict{Symbol,Bool}, GM.Alterants.setLabels, nothing, nothing),
                             many...); nothing catch err; err end
        @test e isa GM.RegistrationRefused && _errors(e.diagnostics) == [:REG_SLOT_EXHAUSTED]
        @test isempty(ba.plugins) && isempty(ba.action_specs)
        @test GM.next_plugin_index(ba) == 1 && GM.next_plugin_index(GM.default_registry_builder()) == 5
        # (cure batch 2; re-cut at stage 5's E4 — the setMode enum check left) route U reports REG_DERIVED_TABLES
        # ALONGSIDE an independent defect of the domain probe (measured: PROBES-e4-validate_stage1-src-cut [2b])
        D = GM.DEFAULT_REGISTRY
        badp = copy(D.plugins); badp[2] = _plugin_with_default(badp[2], GM.Declared(1:3))
        bad_idx = copy(D.action_index); bad_idx[:hide] = Int8(99)
        e = try GM.AlterantRegistry(badp, D.sorted_alt_actions, D.action_to_plugin, bad_idx, D.alt_index,
                                    D.accum_alt_idxs, D.mutex_alt_idxs, D.action_to_settribute,
                                    D.action_specs, D.spec_index); nothing catch err; err end
        @test e isa GM.RegistrationRefused
        @test _errors(e.diagnostics) == [:REG_PROTOCOL, :REG_DERIVED_TABLES]
        # (the cure-batch-2 reflection-order witness left at stage 5's E4 with the reflection cross-check)
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
        # (cure batch 3; re-cut at stage 5's E4 — the shadow law left) a Visib record declaring NO write-back
        # key PUBLISHES; the driver's `get(action_to_settribute, …)` guard carries the run (measured:
        # PROBES-e4-validate_stage1-src-cut [5] — PROCESS_OK)
        bv = GM.RegistryBuilder(GM.DEFAULT_REGISTRY)
        h = bv.action_specs[2]
        bv.action_specs[2] = GM.ActionSpec(; name = :hide, spelling = :identifier, plugin = Int8(2),
                                             overloads = h.overloads, settribute = nothing)
        Rv = GM.publish(bv)
        @test Rv isa GM.AlterantRegistry
        @test GM.goMeta(Vector{UInt8}(codeunits("x = 1\n#~ hide\n\ny = 2\n")); registry = Rv).status === GM.PROCESS_OK
        # (cure batch 3) floats fold BIT-EXACTLY: two NaN payloads with different bits differ
        nan1 = reinterpret(Float64, 0x7ff8000000000001); nan2 = reinterpret(Float64, 0x7ff8000000000002)
        @test string(nan1) == string(nan2) && GM._slot_text(nan1) != GM._slot_text(nan2)
        # (cure batch 3) a published container mutated into a CYCLE is refused as a mutation, not a StackOverflow
        bcy = GM.RegistryBuilder(GM.DEFAULT_REGISTRY)
        bcy.plugins[2] = _plugin_with_default(bcy.plugins[2], GM.Declared(Any[]))
        Rcy = GM.publish(bcy)
        v = Rcy.plugins[2].default.value; push!(v, v)
        @test _codes(GM._registry_door_check(Rcy)) == [:POST_SEAL_MUTATION]
        # (the cure-batch-3 plugin-level/tier-2 witness left at stage 5's E4 with the chain)
        # (cure batch 4) the encodable domain is CLOSED — composite numbers fold structurally, an
        # unknown value type is REFUSED at validation, never folded by a lossy fallback
        @test GM._slot_text(complex(nan1, 0.0)) != GM._slot_text(complex(nan2, 0.0))
        @test GM._slot_text(1//2) != GM._slot_text(2//4 + 0//1 + 1//3)   # structural, not display
        @eval module _Opaque; struct Thing; x::Int; end; end
        bu = GM.RegistryBuilder(GM.DEFAULT_REGISTRY)
        bu.plugins[2] = _plugin_with_default(bu.plugins[2], GM.Declared(_Opaque.Thing(1)))
        du = GM.validate(bu)
        @test :REG_PROTOCOL in _errors(du) && occursin("no canonical encoder", only(filter(x -> x.code === :REG_PROTOCOL, du)).message)
        @test_throws GM.RegistrationRefused GM.publish(bu)
        # (cure batch 4) a PRE-publication cycle is a validation refusal, never a leaked internal exception
        bpc = GM.RegistryBuilder(GM.DEFAULT_REGISTRY)
        cyc = Any[]; push!(cyc, cyc)
        bpc.plugins[2] = _plugin_with_default(bpc.plugins[2], GM.Declared(cyc))
        dpc = GM.validate(bpc)
        @test :REG_PROTOCOL in _errors(dpc) && occursin("CYCLIC", only(filter(x -> x.code === :REG_PROTOCOL, dpc)).message)
        e = try GM.publish(bpc); nothing catch err; err end
        @test e isa GM.RegistrationRefused
        # (cure batch 4) a published Dict mutated into a cycle is refused as a mutation (the Dict encoder is guarded)
        bdc = GM.RegistryBuilder(GM.DEFAULT_REGISTRY)
        bdc.plugins[2] = _plugin_with_default(bdc.plugins[2], GM.Declared(Dict{Any,Any}(:k => 1)))
        Rdc = GM.publish(bdc)
        dd = Rdc.plugins[2].default.value; dd[:self] = dd
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
        @test GM._slot_text(sin) == "f3:sin"
        bfn = GM.RegistryBuilder(GM.DEFAULT_REGISTRY)
        bfn.plugins[2] = _plugin_with_default(bfn.plugins[2], GM.Declared(Any[sin]))
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
        bcx.plugins[2] = _plugin_with_default(bcx.plugins[2], GM.Declared(Any[complex(nan1, 0.0)]))
        Rcx = GM.publish(bcx)
        @test isempty(GM._registry_door_check(Rcx))
        Rcx.plugins[2].default.value[1] = complex(nan2, 0.0)
        @test _codes(GM._registry_door_check(Rcx)) == [:POST_SEAL_MUTATION]
        # (cure batch 5) a published value mutated from encodable to UNENCODABLE is a mutation at the door
        Rcx.plugins[2].default.value[1] = 'c'
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
        bps.plugins[2] = _plugin_with_default(bps.plugins[2], GM.Declared(1:3))
        bps.plugins[1] = _plugin_with_default(bps.plugins[1], GM.Declared('c'))   # the second defective default on another Alterant (labels)
        dps = filter(x -> x.code === :REG_PROTOCOL, GM.validate(bps))
        @test length(dps) == 2 && all(x -> occursin("slot default", x.message), dps) &&
              Set(x.context for x in dps) == Set([:labels, :Visib])   # commit 3-ii: the slots are the Alterants' — the contexts their names
        # deep-copy publication: a NESTED declared container of the builder is not shared with the published value
        bdp = GM.RegistryBuilder(GM.DEFAULT_REGISTRY)
        bdp.plugins[2] = GM.PlugIn(; altName = :Visib, setMode = :mutExclusive, altConstructor = GM.Alterants.Visib,
                                     setAltInstance = GM.Alterants.setVisib, default = GM.Declared(Any[:hide, :show]))   # the declared default's
        Rdp = GM.publish(bdp)                                                                                         #   container since stage 5's E10
        push!(bdp.plugins[2].default.value, :discard)
        @test Rdp.plugins[2].default.value == [:hide, :show] && isempty(GM._registry_door_check(Rdp))
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
        # (the publish-time warning witness left at stage 5's E4 with the candidacy diagnostic — no remaining
        # check warns; publish's warning path stands unexercised)
    end

    @testset "register!'s refusals + the remaining validate rows (re-cut at stage 5's E4: the typed inventory refusals left with the chain)" begin
        base = GM.default_registry_builder()
        # slot-pool exhaustion at the REGISTRY grain (the Int8 index space): `register!` refuses the 128th
        # append (cure batch 1); the validate-time pool row for a directly-pushed builder left at E4 — such a
        # builder fails at `publish` with Julia's InexactError (measured: PROBES-e4-validate_stage1-src-cut [8]),
        # the honest bound of bypassing `register!`
        b = GM.RegistryBuilder(copy(base.plugins), copy(base.action_specs))
        for i in 1:123
            GM.register!(b, GM.PlugIn(Symbol("zz", i), :accumulate, Dict{Symbol,Bool},
                                      GM.Alterants.setLabels, GM.Alterants.checkLabels, nothing))
        end
        @test length(b.plugins) == 127
        e = try GM.register!(b, GM.PlugIn(:zz128, :accumulate, Dict{Symbol,Bool}, GM.Alterants.setLabels,
                                          GM.Alterants.checkLabels, nothing)); nothing catch err; err end
        @test e isa GM.RegistrationRefused && _errors(e.diagnostics) == [:REG_SLOT_EXHAUSTED]
        # `register!` binds the records to the appended plugin (cure batch 1): a record naming another
        # index refuses loudly instead of leaving the appended alterant silently actionless
        b = GM.RegistryBuilder(copy(base.plugins), copy(base.action_specs))
        e = try GM.register!(b, GM.PlugIn(:p5, :mutExclusive, GM.Alterants.Visib, GM.Alterants.setVisib, nothing, nothing),
                             GM.ActionSpec(:zzv, :identifier, Int8(2),
                                           [_ov(Type[GM.Alterants.Visib, Symbol]; rt = Bool)], 0, :none, nothing, nothing)); nothing
        catch err; err end
        @test e isa GM.RegistrationRefused && _errors(e.diagnostics) == [:REG_PROTOCOL]
        @test length(b.plugins) == 4                         # nothing appended on refusal
        # validate NEVER throws (cure batch 1): an odd vararg_kind row RETURNS (the enum check left at E4)
        b = GM.RegistryBuilder(copy(base.plugins), copy(base.action_specs))
        b.action_specs[2] = GM.ActionSpec(; name = :hide, spelling = :identifier, plugin = Int8(2),
            overloads = [GM.ActionOverload(Type[GM.Alterants.Visib, Symbol], Symbol[], Symbol[], :bogus,
                                           Bool, :set, false, :context_free, :apply, true)], settribute = :hide)
        @test GM.validate(b) isa Vector{GM.Diagnostic}
        # a :candidate sugar_candidacy without activation publishes SILENTLY (the candidacy warning left at
        # E4; measured: PROBES-e4-validate_stage1-src-cut [3])
        b = GM.RegistryBuilder(copy(base.plugins), copy(base.action_specs))
        b.action_specs[3] = GM.ActionSpec(; name = :show, spelling = :identifier, plugin = Int8(2),
                                            overloads = base.action_specs[3].overloads, sugar_candidacy = :candidate,
                                            settribute = :show)
        @test isempty(GM.validate(b))
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
        b1.plugins[2] = _plugin_with_default(b1.plugins[2], GM.Declared(Any[]))
        R1 = GM.publish(b1)
        v1 = R1.plugins[2].default.value; push!(v1, v1)
        e1 = try GM.RegistryBuilder(R1); nothing catch err; err end
        @test e1 isa GM.RegistrationRefused
        @test occursin("Visib", e1.diagnostics[1].message) && occursin("default", e1.diagnostics[1].message)   # commit 3-ii: the slot is the Alterant's — the record named is :Visib
        # W2 — the contained route refuses an out-of-domain value ('c'), naming the TYPE + path
        b2 = GM.RegistryBuilder(GM.DEFAULT_REGISTRY)
        b2.plugins[2] = _plugin_with_default(b2.plugins[2], GM.Declared(Any[1]))
        R2b = GM.publish(b2)
        R2b.plugins[2].default.value[1] = 'c'
        e2 = try GM.RegistryBuilder(R2b); nothing catch err; err end
        @test e2 isa GM.RegistrationRefused
        @test occursin("Char", e2.diagnostics[1].message) && occursin("plugins[2].default.value[1]", e2.diagnostics[1].message)
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
        b6.plugins[2] = _plugin_with_default(b6.plugins[2], GM.Declared(GM.ActionOverload(; sig_types = Type[])))
        d6 = GM.validate(b6)
        @test any(x -> x.code === :REG_PROTOCOL && x.context === :Visib &&   # commit 3-ii: the context is the Alterant's name
                       occursin("slot default", x.message) && occursin("ActionOverload", x.message), d6)
        @test_throws GM.RegistrationRefused GM.publish(b6)
        # W7 — the contained route ENFORCES the position rules on its unvalidated input: a
        # Function IN DATA refuses typed, the message naming the position rule + the path
        b7 = GM.RegistryBuilder(GM.DEFAULT_REGISTRY)
        b7.plugins[2] = _plugin_with_default(b7.plugins[2], GM.Declared(Any[1]))
        R7 = GM.publish(b7)
        R7.plugins[2].default.value[1] = sin
        e7 = try GM.RegistryBuilder(R7); nothing catch err; err end
        @test e7 isa GM.RegistrationRefused
        @test occursin("position rule", e7.diagnostics[1].message) &&
              occursin("plugins[2].default.value[1]", e7.diagnostics[1].message)
        # (W8 — the atom-nested-in-data witness — left at stage 5's E10 with `ConditionAtom`; W7 above carries the Function-in-data refusal.)
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
            # the UnionAll `Poison` had no zero-argument method and would have tripped T3's eager
            # DEP_MISSING gate (left at stage 5's E4); this ctor keeps `altConstructor = Poison` — and with it the
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
        bc2.plugins[2] = _plugin_with_default(bc2.plugins[2], GM.Declared(Dict{Any,Any}(_CrxHashBomb.K => 1)))
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
        bc3.plugins[2] = _plugin_with_default(bc3.plugins[2], GM.Declared(Any[1]))
        Rc3 = GM.publish(bc3)
        vc3 = Rc3.plugins[2].default.value
        resize!(vc3, 0); resize!(vc3, 1)
        @test _codes(GM._registry_door_check(Rc3)) == [:POST_SEAL_MUTATION]
        ec3 = try GM.RegistryBuilder(Rc3); nothing catch err; err end
        @test ec3 isa GM.RegistrationRefused
        bc4 = GM.RegistryBuilder(GM.DEFAULT_REGISTRY)
        s4c = bc4.action_specs[3]
        bc4.plugins[2] = _plugin_with_default(bc4.plugins[2], GM.Declared(Vector{Any}(undef, 1)))
        dc4 = GM.validate(bc4)
        @test any(x -> x.code === :REG_PROTOCOL && occursin("UNDEFINED element", x.message), dc4)
    end
end
