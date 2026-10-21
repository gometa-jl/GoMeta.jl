# registry_lifecycle_tests.jl — the registry LIFECYCLE witnesses (APPEND-ONLY).
#
# IS:   the unit witnesses of Builder → validate → PUBLISH, the remaining checks on every public
#       construction route (the route-U cure; no generated/public positional form accepts a publish-time snapshot —
#       the token-gated constructor; the token form itself is reachable by loaded code, the
#       disclosed accident-grade bound; the former validation chain was removed —
#       the domain probe remains; the vocabulary check was removed with the record's vocabulary slot and the
#       mode-gate laws with the Heading's separate path), the coded diagnostics with FULL collection (validate
#       never throws), atomic domain-copy publication, the ONE-check door (a former fingerprint `seal` was removed;
#       the nine `_SNAPSHOT_FIELDS` compared structurally against the publish-time snapshot —
#       REPRESENTATIVE fields mutated here, not every one; the property file is the proof), the STRICT
#       published-only door at `goMeta(bytes; registry)` (an unpublished value refuses coded NAMING the
#       sanctioned path; an internal callable seam that ran the door too was removed), the real freeze gate
#       (`POST_SEAL_MUTATION` on declared, derived, re-ordered, cyclic and callable-identity mutations by
#       conforming code), `register!`'s binding + pool refusals, the slot encoding's distinctions
#       (length-prefixed boundaries, concrete numeric types incl. bit-exact floats, vectors vs tuples,
#       the CLOSED domain — data slots hold concrete data, the refusals witnessed below; the encoder's
#       one caller is the validate walk's Dict-entry order — the fingerprint it fed was removed; the
#       former (iv)/(v) hard-stop classes are CLOSED — docs/public-api.md §1.2), `register!`'s pool refusal + the
#       stable-message per-call slot-pool guard (the entry-collection testset — config + registry rows in ONE result —
#       was removed with the config-time row).
# DOES: builds registries through every route, mutates published values, drives the door, and pins
#       the codes and the messages' load-bearing substrings.
# REASONING: the golden layer proves the PUBLISHED default is byte-neutral; only these witnesses prove
#       the refusals fire, fully, coded, and in deterministic order.
# PURPOSE: the registry's acceptance rows (the registry gates; the door; the refusal rows).

using Test
import GoMeta as GM

_plugin_with_default(p, d) = GM.Alterant(; altName = p.altName, setMode = p.setMode, altConstructor = p.altConstructor,
        setAltInstance = p.setAltInstance, getAltInstance = p.getAltInstance, precedencesTuple = p.precedencesTuple,
        default = d, capture = p.capture)   # the declared default is the ALTERANT's — the record `p` with the slot `d`, every other field copied

@testset "registry_lifecycle" begin

    _codes(diags) = [d.code for d in diags]
    _errors(diags) = [d.code for d in diags if d.severity === :error]

    @testset "the default builder publishes to exactly DEFAULT_REGISTRY, with its snapshot" begin
        b = GM.default_registry_builder()
        @test b isa GM.RegistryBuilder
        @test isempty(GM.validate(b))                       # the shipped record is clean
        R = GM.publish(b)
        D = GM.DEFAULT_REGISTRY
        @test D._snapshot !== nothing                          # published (the former `seal` fingerprint field was removed)
        @test R._snapshot !== nothing && keys(R._snapshot) == GM._SNAPSHOT_FIELDS
        for f in (:sorted_alt_actions, :action_to_plugin, :action_index, :alt_index,
                  :accum_alt_idxs, :mutex_alt_idxs, :spec_index)
            @test getfield(R, f) == getfield(D, f)
        end
        @test length(R.plugins) == 4 && length(R.action_specs) == 9   # 9 since the `ids` action (8 from the heading registration until then — a MEASURED re-pin)
        @test GM._deep_egal(R.plugins, D.plugins) === nothing && GM._deep_egal(R.action_specs, D.action_specs) === nothing   # the two record vectors structurally equal — the door's own comparator (the former seal's whole-record compare was removed; MEASURED)
        # publication COPIES: no container is shared with the builder
        @test R.plugins !== b.plugins && R.action_specs !== b.action_specs
        push!(b.plugins, GM.Alterant(; altName = :zz, setMode = :accumulate, altConstructor = Dict{Symbol,Bool}, setAltInstance = identity))
        @test length(R.plugins) == 4                        # the published value is untouched
        @test isempty(GM._registry_door_check(R))
    end

    @testset "the STRICT door: an unpublished (route-U) registry refuses, naming the path" begin
        D = GM.DEFAULT_REGISTRY
        U = GM.AlterantRegistry(D.plugins, D.sorted_alt_actions, D.action_to_plugin, D.action_index,
                                D.alt_index, D.accum_alt_idxs, D.mutex_alt_idxs,
                                D.action_specs, D.spec_index)    # conforming; the gate passes
        @test U._snapshot === nothing
        r = GM.goMeta(Vector{UInt8}(codeunits("x = 1\n#~ hide\n\ny = 2\n")); registry = U)
        @test r.status === GM.PROCESS_ERROR
        @test _codes(r.diagnostics) == [:REG_UNPUBLISHED]
        @test _errors(r.diagnostics) == [:REG_UNPUBLISHED]                    # the refusal's one row is an :error (MEASURED 2026-10-03) — the clause "PROCESS_ERROR ⇒ at least one :error row" (src/state.jl) pinned on the refusal path, where _entryErrorDelivery sets PROCESS_ERROR without reading severity
        @test occursin("RegistryBuilder → validate → publish", r.diagnostics[1].message)
        @test isempty(Main.BasicRenderer.outputs(r).render_bytes)           # no parse, no render attempted
        @test isempty(GM.readAltValuesEvals(r.altValues_evals))                # the delivered part carries no rows on the refusal path (measured 2026-09-30: rows 0)
        @test isempty(GM.BLS.children(r.blsComponentTree))                     # the refusal delivers a tree built from EMPTY bytes — no Block, read through the door (the former callable seam's door block was removed with the seam; goMeta's door refusal is pinned here)
        @test !isempty(r.diagnostics)                                          # non-OK ⇒ non-empty diagnostics — the documented contract (src/state.jl; measured: 1, :REG_UNPUBLISHED)
        # route U REFUSES inconsistent hand-built tables (never a silently misrouting registry)
        bad_idx = copy(D.action_index); bad_idx[:hide] = Int8(99)
        e = try
            GM.AlterantRegistry(D.plugins, D.sorted_alt_actions, D.action_to_plugin, bad_idx,
                                D.alt_index, D.accum_alt_idxs, D.mutex_alt_idxs,
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
        # a mutation through a published container: the live record no
        # longer matches the snapshot (the length gate on action_specs)
        push!(R.action_specs, GM.ActionSpec(; name = :zzz, plugin = Int8(2)))
        r1 = GM.goMeta(Vector{UInt8}(codeunits("x = 1\n#~ hide\n\ny = 2\n")); registry = R)
        @test r1.status === GM.PROCESS_ERROR
        @test _codes(r1.diagnostics) == [:POST_SEAL_MUTATION]
        @test _errors(r1.diagnostics) == [:POST_SEAL_MUTATION]                 # [h2] …and the post-seal refusal's one row an :error (MEASURED)
        @test isempty(Main.BasicRenderer.outputs(r1).render_bytes)
        @test isempty(GM.readAltValuesEvals(r1.altValues_evals))               # the delivered part carries no rows on the refusal path (measured: rows 0)
        @test !isempty(r1.diagnostics)                                         # non-OK ⇒ non-empty diagnostics (measured: 1, :POST_SEAL_MUTATION)
        # a mutated DERIVED table — the declared record untouched — is
        # refused too: every table is a walked snapshot field (a former attack on the write-back
        # table was removed with that table; the action index carries the case)
        R3 = GM.publish(GM.default_registry_builder())
        R3.action_index[:hide] = Int8(3)
        @test _codes(GM._registry_door_check(R3)) == [:POST_SEAL_MUTATION]
        # a re-ordered action_specs (the order-insensitive fold would not see it) is refused
        R4 = GM.publish(GM.default_registry_builder())
        reverse!(R4.action_specs)
        @test _codes(GM._registry_door_check(R4)) == [:POST_SEAL_MUTATION]
        # a plugin swapped for one with a SAME-NAMED evil setter (the retired fingerprint folded it
        # identically) is refused by the snapshot's `===` leaf compare on the setter field
        R5 = GM.publish(GM.default_registry_builder())
        # a GENUINELY same-named function from another module (same `nameof` text, different identity)
        @eval module _EvilVisib; setVisib(args...) = nothing; end
        evil = _EvilVisib.setVisib
        @test nameof(evil) === nameof(GM.Alterants.setVisib)
        p5 = R5.plugins[2]
        R5.plugins[2] = GM.Alterant(; altName = p5.altName, setMode = p5.setMode, altConstructor = p5.altConstructor, setAltInstance = evil, getAltInstance = p5.getAltInstance, precedencesTuple = p5.precedencesTuple, default = p5.default, capture = p5.capture)   # every field the published record's but the setter
        d5 = GM._registry_door_check(R5)
        @test _codes(d5) == [:POST_SEAL_MUTATION] && d5[1].context == "plugins[2].setAltInstance"   # the setter's === leaf alone (the path MEASURED)
        # (an append-only exception) the snapshot
        # BINDING is immutable: a NamedTuple has no `setindex!`, so the baseline binding cannot
        # be rewritten to match the swap through the published value (the snapshot's MEMBERS are
        # mutable — a known residue, deliberately NOT pinned here)
        @test R5._snapshot isa NamedTuple
        @test_throws MethodError setindex!(R5._snapshot, evil, :plugins)
        # no GENERATED/public positional form accepts a snapshot — the token form exists for the lifecycle
        # and is reachable by loaded code (the disclosed accident-grade bound); the all-fields constructor is gone (the forge
        # attack: copying DEFAULT_REGISTRY's snapshot onto hand-built tables; the seal-carrying form was removed with the seal)
        D = GM.DEFAULT_REGISTRY
        @test_throws MethodError GM.AlterantRegistry(D.plugins, D.sorted_alt_actions, D.action_to_plugin,
            D.action_index, D.alt_index, D.accum_alt_idxs, D.mutex_alt_idxs,
            D.action_specs, D.spec_index, D._snapshot)
        # the injective slot encoding: a re-cut vector boundary no longer collides
        @test GM._slot_text([Symbol("a,b")]) != GM._slot_text([:a, :b])
        @test GM._slot_text(GM.Declared(Symbol[:a, :b])) != GM._slot_text(GM.Declared(Symbol[Symbol("a,b")]))
        # the concrete numeric type and the container kind are part of the value
        @test GM._slot_text(Int8(1)) != GM._slot_text(Int64(1))
        @test GM._slot_text([:a]) != GM._slot_text((:a,))
        @test GM._slot_text(GM.Declared(Int8(1))) != GM._slot_text(GM.Declared(1))
        # validate is total over a PARAMETRIC (`where`) setter — since the reflection cross-check
        # was removed no method signature is read: the setter is a Function leaf in a designated field (registry.jl)
        @eval module _ParamSetter
            paramset(store::T, ::Symbol, x::Symbol) where {T<:AbstractDict} = (store[x] = true; nothing)
        end
        base = GM.default_registry_builder()
        bp = GM.RegistryBuilder(copy(base.plugins), copy(base.action_specs))
        GM.register!(bp, GM.Alterant(; altName = :pz, setMode = :accumulate, altConstructor = Dict{Symbol,Bool}, setAltInstance = _ParamSetter.paramset),
                     GM.ActionSpec(; name = :pzset, plugin = Int8(5)))
        dp = GM.validate(bp)                                  # must return, not throw
        @test dp isa Vector{GM.Diagnostic}
        # (a former broken-record index witness was removed with the validation chain)
        # register! refuses the ACTION pool too
        ba = GM.RegistryBuilder()
        many = [GM.ActionSpec(; name = Symbol("act", i), plugin = Int8(1)) for i in 1:128]
        e = try GM.register!(ba, GM.Alterant(; altName = :big, setMode = :accumulate, altConstructor = Dict{Symbol,Bool}, setAltInstance = GM.Alterants.setLabels),
                             many...); nothing catch err; err end
        @test e isa GM.RegistrationRefused && _errors(e.diagnostics) == [:REG_SLOT_EXHAUSTED]
        @test isempty(ba.plugins) && isempty(ba.action_specs)
        @test GM.next_plugin_index(ba) == 1 && GM.next_plugin_index(GM.default_registry_builder()) == 5
        # route U reports REG_DERIVED_TABLES
        # ALONGSIDE an independent defect of the domain probe (measured)
        D = GM.DEFAULT_REGISTRY
        badp = copy(D.plugins); badp[2] = _plugin_with_default(badp[2], GM.Declared(1:3))
        bad_idx = copy(D.action_index); bad_idx[:hide] = Int8(99)
        e = try GM.AlterantRegistry(badp, D.sorted_alt_actions, D.action_to_plugin, bad_idx, D.alt_index,
                                    D.accum_alt_idxs, D.mutex_alt_idxs,
                                    D.action_specs, D.spec_index); nothing catch err; err end
        @test e isa GM.RegistrationRefused
        @test _errors(e.diagnostics) == [:REG_PROTOCOL, :REG_DERIVED_TABLES]
        # (a former reflection-order witness was removed with the reflection cross-check)
        # a PUBLISHED custom registry WITHOUT the built-in Visib RUNS
        bc = GM.RegistryBuilder()
        GM.register!(bc, GM.Alterant(; altName = :bag, setMode = :accumulate, altConstructor = Dict{Symbol,Bool}, setAltInstance = GM.Alterants.setLabels, getAltInstance = GM.Alterants.checkLabels),
                     GM.ActionSpec(; name = Symbol(":"), plugin = Int8(1)))
        Rc = GM.publish(bc)
        rc = GM.goMeta(Vector{UInt8}(codeunits("x = 1\n#~ :label1\n\ny = 2\n")); registry = Rc)
        @test rc.status === GM.PROCESS_OK && !isempty(Main.BasicRenderer.outputs(rc).render_bytes)
        # (the shadow law and the write-back key were removed from the record) a re-built Visib record PUBLISHES and runs
        bv = GM.RegistryBuilder(GM.DEFAULT_REGISTRY)
        h = bv.action_specs[2]
        bv.action_specs[2] = GM.ActionSpec(; name = :hide, plugin = Int8(2))
        Rv = GM.publish(bv)
        @test Rv isa GM.AlterantRegistry
        @test GM.goMeta(Vector{UInt8}(codeunits("x = 1\n#~ hide\n\ny = 2\n")); registry = Rv).status === GM.PROCESS_OK
        # floats fold BIT-EXACTLY: two NaN payloads with different bits differ
        nan1 = reinterpret(Float64, 0x7ff8000000000001); nan2 = reinterpret(Float64, 0x7ff8000000000002)
        @test string(nan1) == string(nan2) && GM._slot_text(nan1) != GM._slot_text(nan2)
        # a published container mutated into a CYCLE is refused as a mutation, not a StackOverflow
        bcy = GM.RegistryBuilder(GM.DEFAULT_REGISTRY)
        bcy.plugins[2] = _plugin_with_default(bcy.plugins[2], GM.Declared(Any[]))
        Rcy = GM.publish(bcy)
        v = Rcy.plugins[2].default.value; push!(v, v)
        @test _codes(GM._registry_door_check(Rcy)) == [:POST_SEAL_MUTATION]
        # (a former plugin-level witness was removed with the validation chain)
        # the encodable domain is CLOSED — composite numbers fold structurally, an
        # unknown value type is REFUSED at validation, never folded by a lossy fallback
        @test GM._slot_text(complex(nan1, 0.0)) != GM._slot_text(complex(nan2, 0.0))
        @test GM._slot_text(1//2) != GM._slot_text(2//4 + 0//1 + 1//3)   # structural, not display
        @eval module _Opaque; struct Thing; x::Int; end; end
        bu = GM.RegistryBuilder(GM.DEFAULT_REGISTRY)
        bu.plugins[2] = _plugin_with_default(bu.plugins[2], GM.Declared(_Opaque.Thing(1)))
        du = GM.validate(bu)
        @test :REG_PROTOCOL in _errors(du) && occursin("no canonical encoder", only(filter(x -> x.code === :REG_PROTOCOL, du)).message)
        @test_throws GM.RegistrationRefused GM.publish(bu)
        # a PRE-publication cycle is a validation refusal, never a leaked internal exception
        bpc = GM.RegistryBuilder(GM.DEFAULT_REGISTRY)
        cyc = Any[]; push!(cyc, cyc)
        bpc.plugins[2] = _plugin_with_default(bpc.plugins[2], GM.Declared(cyc))
        dpc = GM.validate(bpc)
        @test :REG_PROTOCOL in _errors(dpc) && occursin("CYCLIC", only(filter(x -> x.code === :REG_PROTOCOL, dpc)).message)
        e = try GM.publish(bpc); nothing catch err; err end
        @test e isa GM.RegistrationRefused
        # a published Dict mutated into a cycle is refused as a mutation (the Dict encoder is guarded)
        bdc = GM.RegistryBuilder(GM.DEFAULT_REGISTRY)
        bdc.plugins[2] = _plugin_with_default(bdc.plugins[2], GM.Declared(Dict{Any,Any}(:k => 1)))
        Rdc = GM.publish(bdc)
        dd = Rdc.plugins[2].default.value; dd[:self] = dd
        @test _codes(GM._registry_door_check(Rdc)) == [:POST_SEAL_MUTATION]
        # a DAG (the same container reached twice, no cycle) is NOT reported cyclic
        shared = Symbol[:a]
        @test GM._slot_text(Any[shared, shared]) == GM._slot_text(Any[Symbol[:a], Symbol[:a]])
        # dict encoding is canonical over entry text, not `string(key)` order
        @test GM._slot_text(Dict{Any,Any}(:x => 1, "x" => 2)) == GM._slot_text(Dict{Any,Any}("x" => 2, :x => 1))
        # DATA SLOTS HOLD DATA: a Function inside a declared value/payload is refused at
        # validation (a same-named swap there was invisible to the retired fingerprint fold); the
        # designated callable fields still encode by name
        @test_throws GM._UnencodableSlot GM._slot_text(GM.Declared(Any[sin]))
        @test GM._slot_text(sin) == "f3:sin"
        bfn = GM.RegistryBuilder(GM.DEFAULT_REGISTRY)
        bfn.plugins[2] = _plugin_with_default(bfn.plugins[2], GM.Declared(Any[sin]))
        dfn = GM.validate(bfn)
        @test :REG_PROTOCOL in _errors(dfn) && occursin("slot default", only(filter(x -> x.code === :REG_PROTOCOL, dfn)).message)
        # CONCRETE containers only: a range/view is not a Vector — refused, so `1:3` can
        # never collide with `[1,2,3]` inside a published value
        @test_throws GM._UnencodableSlot GM._slot_text(1:3)
        @test_throws GM._UnencodableSlot GM._slot_text(view([1, 2, 3], 1:2))
        @test GM._slot_text([1, 2, 3]) isa String
        # type parameters are TYPE-TAGGED values
        @test GM._slot_text(Val{Int8(1)}) != GM._slot_text(Val{Int64(1)})
        @test GM._slot_text(Val{:x}) != GM._slot_text(Val{1})
        @test GM._type_text(Tuple{Vararg{Symbol}}) isa String && GM._type_text(Vector{Symbol}) isa String
        # the publish → mutate → DOOR witness of the bit-exact composite encoding (a comparison of two encodings
        # alone would not show a mutation at the door)
        bcx = GM.RegistryBuilder(GM.DEFAULT_REGISTRY)
        bcx.plugins[2] = _plugin_with_default(bcx.plugins[2], GM.Declared(Any[complex(nan1, 0.0)]))
        Rcx = GM.publish(bcx)
        @test isempty(GM._registry_door_check(Rcx))
        Rcx.plugins[2].default.value[1] = complex(nan2, 0.0)
        @test _codes(GM._registry_door_check(Rcx)) == [:POST_SEAL_MUTATION]
        # a published value mutated from encodable to UNENCODABLE is a mutation at the door
        Rcx.plugins[2].default.value[1] = 'c'
        @test _codes(GM._registry_door_check(Rcx)) == [:POST_SEAL_MUTATION]
        # Rational: concrete-type-tagged + structural; BigInt parts are outside the machine domain
        @test GM._slot_text(Rational{Int8}(1, 2)) != GM._slot_text(1//2)
        @test_throws GM._UnencodableSlot GM._slot_text(big(1)//2)
        # a failed encode leaves the visiting set clean — a second encode in the same scope succeeds
        dv = Dict{Any,Any}(:k => 'c')
        @test_throws GM._UnencodableSlot GM._slot_text(Any[dv])
        dv[:k] = 1
        @test GM._slot_text(Any[dv]) isa String
        # encodability is probed PER SLOT with FULL collection: two defective records ⇒ two
        # diagnostics, each naming its record + slot
        bps = GM.RegistryBuilder(GM.DEFAULT_REGISTRY)
        bps.plugins[2] = _plugin_with_default(bps.plugins[2], GM.Declared(1:3))
        bps.plugins[1] = _plugin_with_default(bps.plugins[1], GM.Declared('c'))   # the second defective default on another Alterant (labels)
        dps = filter(x -> x.code === :REG_PROTOCOL, GM.validate(bps))
        @test length(dps) == 2 && all(x -> occursin("slot default", x.message), dps) &&
              Set(x.context for x in dps) == Set([:labels, :Visib])   # the slots are the Alterants' — the contexts their names
        # deep-copy publication: a NESTED declared container of the builder is not shared with the published value
        bdp = GM.RegistryBuilder(GM.DEFAULT_REGISTRY)
        bdp.plugins[2] = GM.Alterant(; altName = :Visib, setMode = :mutExclusive, altConstructor = GM.Alterants.Visib,
                                     setAltInstance = GM.Alterants.setVisib, default = GM.Declared(Any[:hide, :show]))   # the declared default's
        Rdp = GM.publish(bdp)                                                                                         #   container
        push!(bdp.plugins[2].default.value, :discard)
        @test Rdp.plugins[2].default.value == [:hide, :show] && isempty(GM._registry_door_check(Rdp))
        # next_plugin_index is Int8 and passes straight into ActionSpec; RegistryBuilder(published) preloads
        bx = GM.RegistryBuilder(GM.DEFAULT_REGISTRY)
        @test length(bx.plugins) == 4 && bx.plugins !== GM.DEFAULT_REGISTRY.plugins
        i5 = GM.next_plugin_index(bx)
        @test i5 isa Int8 && i5 == 5
        GM.register!(bx, GM.Alterant(; altName = :bag2, setMode = :accumulate, altConstructor = Dict{Symbol,Bool}, setAltInstance = GM.Alterants.setLabels, getAltInstance = GM.Alterants.checkLabels),
                     GM.ActionSpec(; name = :bagset, plugin = i5))
        Rx = GM.publish(bx)
        rx = GM.goMeta(Vector{UInt8}(codeunits("x = 1\n#~ hide\n\ny = 2\n")); registry = Rx)
        @test rx.status === GM.PROCESS_OK
        # (a former publish-time warning witness was removed with the candidacy diagnostic — no remaining
        # check warns; publish's warning path stands unexercised)
    end

    @testset "register!'s refusals + the remaining validate rows" begin
        base = GM.default_registry_builder()
        # slot-pool exhaustion at the REGISTRY grain (the Int8 index space): `register!` refuses the 128th
        # append; the validate-time pool row for a directly-pushed builder was removed — such a
        # builder fails at `publish` with Julia's InexactError (measured),
        # the honest bound of bypassing `register!`
        b = GM.RegistryBuilder(copy(base.plugins), copy(base.action_specs))
        for i in 1:123
            GM.register!(b, GM.Alterant(; altName = Symbol("zz", i), setMode = :accumulate, altConstructor = Dict{Symbol,Bool},
                                      setAltInstance = GM.Alterants.setLabels, getAltInstance = GM.Alterants.checkLabels))
        end
        @test length(b.plugins) == 127
        e = try GM.register!(b, GM.Alterant(; altName = :zz128, setMode = :accumulate, altConstructor = Dict{Symbol,Bool},
                                          setAltInstance = GM.Alterants.setLabels, getAltInstance = GM.Alterants.checkLabels)); nothing catch err; err end
        @test e isa GM.RegistrationRefused && _errors(e.diagnostics) == [:REG_SLOT_EXHAUSTED]
        # `register!` binds the records to the appended plugin: a record naming another
        # index refuses loudly instead of leaving the appended alterant silently actionless
        b = GM.RegistryBuilder(copy(base.plugins), copy(base.action_specs))
        e = try GM.register!(b, GM.Alterant(; altName = :p5, setMode = :mutExclusive, altConstructor = GM.Alterants.Visib, setAltInstance = GM.Alterants.setVisib),
                             GM.ActionSpec(; name = :zzv, plugin = Int8(2))); nothing
        catch err; err end
        @test e isa GM.RegistrationRefused && _errors(e.diagnostics) == [:REG_PROTOCOL]
        @test length(b.plugins) == 4                         # nothing appended on refusal
        # (the odd-vararg_kind-row and the :candidate-sugar_candidacy witnesses were removed with
        # their subjects — the overload rows and the grant register)
    end

    @testset "the snapshot door's EIGHT witnesses W1–W8 (W4 and W8 removed: six stand)" begin
        # W1 — the CONTAINED route refuses a published value mutated into a CYCLE, coded,
        # naming the record + slot via the path (Rcx/Rcy above are testset-locals — rebuilt)
        b1 = GM.RegistryBuilder(GM.DEFAULT_REGISTRY)
        b1.plugins[2] = _plugin_with_default(b1.plugins[2], GM.Declared(Any[]))
        R1 = GM.publish(b1)
        v1 = R1.plugins[2].default.value; push!(v1, v1)
        e1 = try GM.RegistryBuilder(R1); nothing catch err; err end
        @test e1 isa GM.RegistrationRefused
        @test occursin("Visib", e1.diagnostics[1].message) && occursin("default", e1.diagnostics[1].message)   # the slot is the Alterant's — the record named is :Visib
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
        # (W4 — the seal-via-token-seam witness, a FOREIGN seal beside DEFAULT's snapshot firing at path `seal` — was removed
        # with the seal field; W1–W3 and W5–W7 carry the door's classes — W8 removed too, the note below.)
        # W5 — KNOWN OPEN (v) closes: `altConstructor = Val{'c'}` is a SLOT-NAMED validate row
        # (record in context, slot in the message) + a coded publish refusal
        b5 = GM.RegistryBuilder(GM.DEFAULT_REGISTRY)
        b5.plugins[1] = GM.Alterant(; altName = :labels, setMode = :accumulate, altConstructor = Val{'c'},
                                    setAltInstance = GM.Alterants.setLabels,
                                    getAltInstance = GM.Alterants.checkLabels)
        d5 = GM.validate(b5)
        @test any(x -> x.code === :REG_PROTOCOL && x.context === :labels &&
                       occursin("altConstructor", x.message), d5)
        @test_throws GM.RegistrationRefused GM.publish(b5)
        # W6 — a RECORD STRUCT in declared data refuses at validate (the slot-named row, never
        # the publish-containment generic row) + a coded publish refusal
        b6 = GM.RegistryBuilder(GM.DEFAULT_REGISTRY)
        b6.plugins[2] = _plugin_with_default(b6.plugins[2], GM.Declared(GM.ActionSpec(; name = :zz, plugin = Int8(1))))   # a record struct in data (ActionSpec — the former overload row was removed)
        d6 = GM.validate(b6)
        @test any(x -> x.code === :REG_PROTOCOL && x.context === :Visib &&   # the context is the Alterant's name
                       occursin("slot default", x.message) && occursin("ActionSpec", x.message), d6)
        @test_throws GM.RegistrationRefused GM.publish(b6)
        # W7 — the contained route ENFORCES the position rules on its unvalidated input: a
        # Function IN DATA refuses coded, the message naming the position rule + the path
        b7 = GM.RegistryBuilder(GM.DEFAULT_REGISTRY)
        b7.plugins[2] = _plugin_with_default(b7.plugins[2], GM.Declared(Any[1]))
        R7 = GM.publish(b7)
        R7.plugins[2].default.value[1] = sin
        e7 = try GM.RegistryBuilder(R7); nothing catch err; err end
        @test e7 isa GM.RegistrationRefused
        @test occursin("position rule", e7.diagnostics[1].message) &&
              occursin("plugins[2].default.value[1]", e7.diagnostics[1].message)
        # (W8 — the atom-nested-in-data witness — was removed with `ConditionAtom`; W7 above carries the Function-in-data refusal.)
    end

    @testset "the snapshot door's robustness witnesses (A1/A2/A3; APPENDED)" begin
        # CW1 (A1) — an admitted user UnionAll carrying its OWN `Base.show` (legitimate
        # specialization): the structural type text dispatches nothing, so the record
        # publishes and the door is silent (before the cure, `string()` dispatched the user
        # show and `publish` leaked the raw error — measured)
        @eval module _CrxPoison
            struct Poison{T} end
            Base.show(io::IO, ::Type{Poison}) = error("A1-BOOM")
            # the UnionAll `Poison` had no zero-argument method and would have tripped the former eager
            # DEP_MISSING gate (since removed); this ctor keeps `altConstructor = Poison` — and with it the
            # only UnionAll-at-altConstructor fold coverage — while the witness itself
            # never calls the constructor (publish + door only).
            Poison() = Poison{Int}()
        end
        bc1 = GM.RegistryBuilder(GM.DEFAULT_REGISTRY)
        bc1.plugins[2] = GM.Alterant(; altName = :Visib, setMode = :mutExclusive,
                                     altConstructor = _CrxPoison.Poison,
                                     setAltInstance = GM.Alterants.setVisib)
        Rc1 = GM.publish(bc1)
        @test Rc1 isa GM.AlterantRegistry
        @test isempty(GM._registry_door_check(Rc1))
        # CW2 (A2) — a flag-armed THROWING user `hash` on an own Type key: validation and the
        # fold never hash, but the copier's Dict-rebuild fill does — the throw converts to a
        # coded refusal, never a raw exception out of `publish` (measured)
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
        # vector FIRES at the door (was an UndefRefError leak — measured); an undef-slot
        # declared vector refuses slot-named at validate (never a throw); the contained
        # preload route refuses coded
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
