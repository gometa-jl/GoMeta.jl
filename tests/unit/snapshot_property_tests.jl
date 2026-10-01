# snapshot_property_tests.jl — v0.4 T2-bis: the PROPERTY proof of the snapshot door (T2BIS-DESIGN §9).
#
# IS:   the ruled property test of R-V04B-4 (iv) — the proof that EVERY in-place or rebuild
#       mutation of a published registry's walked fields FIRES the door at a prefix-comparable
#       path, and that structurally identical rebuilds (fresh containers, leaves by reference,
#       DAG split/joined) stay SILENT. It REPLACES the enumerated witnesses AS THE PROOF of the
#       door's coverage; no existing test is deleted (the batch-2..5 `_slot_text` witnesses stay
#       as fingerprint regression pins, the door pins as door regression pins).
# DOES: N = 1024 iterations — each takes a FRESH publish of the fixed generator builder, checks
#       the door EMPTY, applies one site mutation (sites cycle deterministically; the rng picks
#       only replacement values), and checks ONE fire at a segment-prefix-comparable path — plus
#       the 8 false-positive rebuild cases, the named cases (Σ = 46 asserts since the v0.4 T4
#       VocabularyRef case), and 5 aggregate
#       coverage asserts. P = 1024×3 + 8 + 44 + 5 = 3129 (T2BIS-DESIGN §9's closed arithmetic).
# REASONING: the enumerated door witnesses cannot prove coverage over the whole walked domain;
#       the site-cycling property can — full site coverage is guaranteed by |sites| ≤ N.
# PURPOSE: the T2-bis acceptance row (R-V04B-4 (iv)); the door's coverage proof.

using Test
using Random
import GoMeta as GM

@eval module _PropTypes
    import GoMeta as GM
    struct TA end                                    # the Val{M.T} category-swap alphabet
    mutable struct Callable <: Function
        n::Int
    end
    (c::Callable)(args...) = c.n
    module M1; f(x...) = 1; end                      # same-NAMED functions from two modules
    module M2; f(x...) = 2; end
    struct CountKey end                              # the counting-hash witness key TYPE
    const HASH_COUNT = Base.RefValue(0)
    Base.hash(::Type{CountKey}, h::UInt) = (HASH_COUNT[] += 1; h ⊻ 0x9e3779b97f4a7c15)
    # the Ref-backed SETTER (the captured-state silence class): an anonymous function over a
    # module-global Ref — a LOCAL-capture closure cannot be a setter at all under the ratified
    # reflection law (its method sig carries the UnionAll closure type, so the EXACT
    # per-signature match refuses it — recorded at the T2-bis commit, §S2.9); the semantics
    # under test — behavior moving through a Ref while `===` identity stands — are identical
    const SETTER_REF = Base.RefValue(0)
    const setclo = (store::Dict{Symbol,Bool}, name::Symbol) ->
        (SETTER_REF[] += 1; store[name] = true; nothing)
end

@testset "snapshot_property (v0.4 T2-bis)" begin

    _codesp(diags) = [d.code for d in diags]
    _K(k) = GM._Key(k)

    # ——— the fixed Function alphabet (identities stable across every publish) ———
    _atom_named(args...) = true                                  # a named generic
    _closure_ref = _PropTypes.setclo                             # the Ref-backed setter (see _PropTypes)
    _isbits_cap = 7
    _closure_isbits = (args...) -> _isbits_cap                   # a TRUE local-capture closure (evaluate slot)
    _callable_struct = _PropTypes.Callable(3)
    _swap_fn_a(args...) = :a
    _swap_fn_b(args...) = :b

    _nan64 = reinterpret(Float64, 0x7ff8000000000001)

    # ——— the GENERATOR (§9): DEFAULT + fills on ONE plugin + lean per-spec payloads + the
    # fresh single-overload plugin; NO shared mutable container; fill Dicts UNIQUE-KEYED ———
    function _mk_prop_builder()
        b = GM.RegistryBuilder(GM.DEFAULT_REGISTRY)
        b.plugins[1] = GM.PlugIn(; altName = :labels, setMode = :accumulate,
            altConstructor = Dict{Symbol,Bool},
            setAltInstance = GM.Alterants.setLabels, getAltInstance = GM.Alterants.checkLabels,
            capture = GM.CaptureDecl(Dict{Symbol,Bool}, :per_key, :many, nothing),
            render = GM.RenderDecl([Symbol(":") => GM.EffectRow(:drop, nothing),
                                    Symbol(":") => GM.EffectRow(:mark, "mk")], [:Line, :Block], true),
            vocabulary = GM.InlineVocabulary([:aa, :bb],
                Dict(:aa => (query = true,), :bb => (query = false,))),
            constraints = [GM.MutEx([Symbol(":")])],
            atoms = [GM.ConditionAtom(:atomA, "atomA", _atom_named),
                     GM.ConditionAtom(:atomB, "atomB", _closure_isbits)],
            contract_version = v"0.4.7",
            sugar = [GM.SugarRow(:pat, Symbol(":"), :localOnly)],
            provenance = GM.Provenance(; sec_schema = v"1.0.0",
                sources = [GM.DomainRef("art", "sha256:" * "0"^64)],
                package_digest = "sha256:" * "1"^64,
                signatures = [GM.SignatureRecord(; algorithm = "ed25519")],
                acquisition_mode = :shipped, artifact_version = v"1.0.0-rc1+build.7",
                declared_capabilities = Symbol[:c1]),
            permissions = GM.PermissionManifest(; seam = [:s1], ambient = [:a1]),
            # stage 2's commit 3-ii: the default slot is the ALTERANT's — the value-domain carrier (formerly action 1's) rides plugin 1
            default = GM.Declared(Any[Int8(3), 1.5, Float32(2.5), Float16(1.0), _nan64,
                                      "str", :sym, true, Int128(7), UInt8(2),
                                      complex(1, 2), 1//2, Complex(1//2, 1//2),
                                      v"1.0.0-rc1", v"1.0.0+build.7", Val{:tp},
                                      (Int8(1), :a), (q = 1, w = :x), (:pk => 1),
                                      Dict{Any,Any}(:dk => Any[UInt16(9)], "sk" => 2.5)]))
        s1 = b.action_specs[1]
        b.action_specs[1] = GM.ActionSpec(; name = s1.name, spelling = s1.spelling,
            plugin = s1.plugin, overloads = s1.overloads,
            accepts_string_slot = s1.accepts_string_slot, sugar_candidacy = s1.sugar_candidacy,
            validate = _callable_struct)
        # the slot-struct default (formerly action 3's) rides plugin 2 (Visib; the DEFAULT_REGISTRY's fields copied)
        b.plugins[2] = GM.PlugIn(; altName = :Visib, setMode = :mutExclusive, altConstructor = GM.Alterants.Visib,
            setAltInstance = GM.Alterants.setVisib,
            capture = GM.CaptureDecl(GM.Alterants.Visib, :single, :one, nothing; attr_stem = :visib),
            default = GM.Declared(GM.EffectRow(:mark, Dict{Any,Any}(Int16(2) => "pv"))))
        GM.register!(b,
            GM.PlugIn(Symbol("prop"), :accumulate, Dict{Symbol,Bool}, _closure_ref, nothing, nothing),
            GM.ActionSpec(; name = :propset, spelling = :identifier, plugin = Int8(5),
                overloads = [GM.ActionOverload(; sig_types = Type[Dict{Symbol,Bool}, Symbol])]))
        return b
    end

    R0 = GM.publish(_mk_prop_builder())
    @assert isempty(GM._registry_door_check(R0)) "the generator must publish CLEAN"

    # ——— navigation over (Symbol field · Int index · _Key dict-key) segment paths ———
    _child(o, seg) =
        seg isa Int ? (o isa Vector ? o[seg] : o isa Tuple ? o[seg] : error("bad Int seg")) :
        seg isa GM._Key ? o[seg.k] :
        getfield(o, seg)

    function _objs_along(R, path)
        objs = Any[R]
        for seg in path
            push!(objs, _child(objs[end], seg))
        end
        objs
    end

    function _rebuild_with(o, seg, v)
        if o isa Tuple
            return ntuple(j -> j == seg ? v : o[j], length(o))
        elseif o isa NamedTuple
            ns = keys(o)
            return NamedTuple{ns}(ntuple(j -> ns[j] === seg ? v : o[ns[j]], length(ns)))
        elseif o isa Pair
            return seg === :first ? (v => o.second) : (o.first => v)
        else                                     # slot/record struct — positional rebuild
            flds = fieldnames(typeof(o))
            vals = Any[f === seg ? v : getfield(o, f) for f in flds]
            if o isa GM.Declared                 # keep the declared parameter when it still fits
                return GM.Declared{typeof(o).parameters[1]}(vals[1])
            end
            return typeof(o).name.wrapper(vals...)
        end
    end

    function _set_at!(R, path, newval)
        objs = _objs_along(R, path)
        m = findlast(j -> objs[j] isa Vector || objs[j] isa Dict, 1:(length(objs) - 1))
        @assert m !== nothing "no mutable ancestor on $path"
        v = newval
        for j in length(path):-1:(m + 1)
            v = _rebuild_with(objs[j], path[j], v)
        end
        c = objs[m]
        if c isa Vector
            c[path[m]::Int] = v
        else
            c[(path[m]::GM._Key).k] = v
        end
        return nothing
    end

    # ——— category classification + replacement values ———
    _leafcat(v) =
        v isa Bool ? :bool :
        v isa Union{Int8,Int16,Int32,Int64,Int128,UInt8,UInt16,UInt32,UInt64,UInt128} ? :int :
        v isa Union{Float16,Float32,Float64} ? :float :
        v isa Symbol ? :symbol :
        v isa String ? :string :
        v isa VersionNumber ? :version :
        v isa Complex ? :complex :
        v isa Rational ? :rational :
        v isa Type ? :type :
        v isa Function ? :function :
        v === nothing ? :nothing_leaf : :other

    _flipbits(v::Float64, i) = reinterpret(Float64, reinterpret(UInt64, v) ⊻ (UInt64(1) << i))
    _flipbits(v::Float32, i) = reinterpret(Float32, reinterpret(UInt32, v) ⊻ (UInt32(1) << min(i, 22)))
    _flipbits(v::Float16, i) = reinterpret(Float16, reinterpret(UInt16, v) ⊻ (UInt16(1) << min(i, 9)))

    function _distinct_value(v, rng)
        c = _leafcat(v)
        c === :bool && return !v
        c === :symbol && return gensym(:m)
        c === :int && return v + one(v) * (1 + rand(rng, 0:2))
        c === :float && return (isnan(v) ? _flipbits(v, 0) : _flipbits(v, rand(rng, 0:12)))
        c === :string && return v * rand(rng, ["x", "y", "z"])
        c === :version && return VersionNumber(v.major + 1, v.minor, v.patch)
        c === :complex && return Complex(real(v) isa Bool ? !real(v) : real(v) + one(real(v)), imag(v))
        c === :rational && return ((numerator(v) isa Bool ? !numerator(v) : numerator(v) + one(numerator(v))) // denominator(v))
        c === :type && return (v === Val{:tswap} ? Val{:tswap2} : Val{:tswap})
        c === :function && return (v === _swap_fn_a ? _swap_fn_b : _swap_fn_a)
        v isa NamedTuple && haskey(v, :query) && return (query = !v.query,)
        error("no distinct value for category $c ($(typeof(v)))")
    end

    # single-point substitutes, keyed by (parent struct type, field) — T2BIS-DESIGN §9's rule:
    # a distinct in-domain value ADMISSIBLE in that field, via the nearest mutable ancestor
    function _single_substitute(pT, pf, v)
        pT === GM.PlugIn && pf === :getAltInstance && return GM.Alterants.checkLabels
        pT === GM.PlugIn && pf === :precedencesTuple && return ntuple(i -> Symbol("p", i), GM.NUM_MH_LEVELS)
        pT === GM.PlugIn && pf === :capture && return GM.CaptureDecl(Dict{Symbol,Bool}, :single, :one, nothing)
        pT === GM.PlugIn && pf === :render && return GM.RenderDecl(Pair{Symbol,GM.EffectRow}[], nothing, false)
        pT === GM.PlugIn && pf === :vocabulary && return GM.InlineVocabulary(Symbol[],
            Dict{Symbol,NamedTuple{(:query,),Tuple{Bool}}}())
        pT === GM.PlugIn && pf === :contract_version && return v"0.4.2"
        pT === GM.PlugIn && pf === :requires && return (:cap,)
        pT === GM.PlugIn && pf === :permissions && return GM.PermissionManifest()
        pT === GM.ActionSpec && pf === :validate && return _swap_fn_a
        pT === GM.ActionSpec && pf === :keyed_slot && return (:ka, :kb)
        pT === GM.PlugIn && pf === :default && return GM.Declared(1)   # stage 2's commit 3-ii: the slot is the Alterant's
        pT === GM.ActionSpec && pf === :settribute && return :zz
        pT === GM.ActionOverload && pf === :vararg_kind && return :symbol
        pT === GM.EffectRow && pf === :payload && return "px"
        pT === GM.CaptureDecl && pf === :mode_gate && return :localOnly
        pT === GM.CaptureDecl && pf === :attr_stem && return :zz   # v0.4 T5 (the round's B-3 cure — the raw error() fault otherwise)
        pT === GM.SugarRow && pf === :mode_gate && return :localOnly
        pT === GM.ConditionAtom && pf === :evaluate && return _swap_fn_a
        pT === GM.RenderDecl && pf === :resolve_order && return [:Line]
        pT === GM.Provenance && pf === :acquisition_mode && return :shipped
        pT === GM.Provenance && pf === :artifact_version && return v"1.0.1"
        pT === GM.Provenance && return "sx"                      # the Union{Nothing,String} members
        pT === GM.SignatureRecord && return "sx"
        error("no single-point substitute for ($pT, $pf)")
    end

    # ——— SITE ENUMERATION (§9): a pre-walk of the published value, §2 traversal order ———
    function _enumerate_sites(R)
        sites = Vector{NamedTuple}()
        function walk(v, path, pT, pf)
            if v isa GM.PlugIn || v isa GM.ActionSpec || v isa GM.ActionOverload
                push!(sites, (path = path, cat = :record, kind = :imm, pT = pT, pf = pf))
                flds = v isa GM.PlugIn ? GM._WALK_PLUGIN_FIELDS :
                       v isa GM.ActionSpec ? GM._WALK_ACTION_FIELDS : GM._WALK_OVERLOAD_FIELDS
                for f in flds
                    walk(getfield(v, f), Any[path; f], typeof(v), f)
                end
            elseif v isa Vector
                push!(sites, (path = path, cat = :vector, kind = :vec, pT = pT, pf = pf))
                for (i, e) in enumerate(v)
                    walk(e, Any[path; i], Vector, pf)
                end
            elseif v isa Dict
                push!(sites, (path = path, cat = :dict, kind = :dict, pT = pT, pf = pf))
                for kv in v
                    if _leafcat(kv.first) in (:symbol, :string, :int, :float) # leaf-keyed by the generator
                        push!(sites, (path = Any[path; _K(kv.first)], cat = _leafcat(kv.first),
                                      kind = :dictkey, pT = Dict, pf = pf))
                    end
                    walk(kv.second, Any[path; _K(kv.first)], Dict, pf)
                end
            elseif v isa Tuple
                if isempty(v)
                    push!(sites, (path = path, cat = :tuple, kind = :single, pT = pT, pf = pf))
                else
                    push!(sites, (path = path, cat = :tuple, kind = :imm, pT = pT, pf = pf))
                    for (i, e) in enumerate(v)
                        walk(e, Any[path; i], Tuple, pf)
                    end
                end
            elseif v isa NamedTuple
                push!(sites, (path = path, cat = :namedtuple, kind = :imm, pT = pT, pf = pf))
                for f in keys(v)
                    walk(getfield(v, f), Any[path; f], NamedTuple, pf)
                end
            elseif v isa Pair
                push!(sites, (path = path, cat = :pair, kind = :imm, pT = pT, pf = pf))
                walk(v.first, Any[path; :first], Pair, pf)
                walk(v.second, Any[path; :second], Pair, pf)
            elseif v isa GM._SLOT_STRUCT_UNION
                flds = fieldnames(typeof(v))
                if isempty(flds)                                 # NoDefault() — a single-point site
                    push!(sites, (path = path, cat = :slotstruct, kind = :single, pT = pT, pf = pf))
                else
                    push!(sites, (path = path, cat = :slotstruct, kind = :imm, pT = pT, pf = pf))
                    for f in flds
                        walk(getfield(v, f), Any[path; f], typeof(v), f)
                    end
                end
            else
                c = _leafcat(v)
                @assert c !== :other "unwalkable site value $(typeof(v)) at $path"
                if c === :nothing_leaf
                    # `nothing` has no `!==` in-place replacement — a single-point site
                    push!(sites, (path = path, cat = c, kind = :single, pT = pT, pf = pf))
                else
                    push!(sites, (path = path, cat = c, kind = :leaf, pT = pT, pf = pf))
                end
            end
        end
        for f in GM._SNAPSHOT_FIELDS
            f === :seal && continue                              # no mutable path reaches it — W4 is its witness
            walk(getfield(R, f), Any[f], GM.AlterantRegistry, f)
        end
        return sites
    end

    # ——— the MUTATION engine: applies one site's category-table op; returns the mutated path ———
    _push_elem(v::Vector) =
        eltype(v) === GM.MutEx ? GM.MutEx([:zz]) :
        eltype(v) === GM.ConditionAtom ? GM.ConditionAtom(:za, "za", nothing) :
        eltype(v) === GM.SugarRow ? GM.SugarRow(:zp, :zq, nothing) :
        eltype(v) === GM.DomainRef ? GM.DomainRef("zx", "sha256:" * "2"^64) :
        eltype(v) === GM.SignatureRecord ? GM.SignatureRecord() :
        eltype(v) === Symbol ? gensym(:pe) :
        !isempty(v) ? v[end] : error("no push element for empty $(typeof(v))")

    function _apply_mutation!(R, site, i, rng, opseen)
        path = site.path
        if site.kind === :leaf
            v0 = _objs_along(R, path)[end]
            # DomainRef's validating inner constructor pins the digest FORM — replace with a
            # different valid digest (the only admissible in-place replacement class)
            newv = (site.pT === GM.DomainRef && site.pf === :digest) ?
                "sha256:" * (v0 == "sha256:" * "3"^64 ? "4"^64 : "3"^64) : _distinct_value(v0, rng)
            _set_at!(R, path, newv)
            push!(opseen, Symbol(:leaf_, site.cat))
            return path
        elseif site.kind === :single
            v0 = _objs_along(R, path)[end]
            sub = v0 isa GM.NoDefault ? GM.Declared(1) : _single_substitute(site.pT, site.pf, v0)
            _set_at!(R, path, sub)
            push!(opseen, :single_substitute)
            return path
        elseif site.kind === :imm
            objs = _objs_along(R, path)
            o = objs[end]
            segs = o isa Tuple ? collect(1:length(o)) :
                   o isa NamedTuple ? collect(keys(o)) :
                   o isa Pair ? Any[:first, :second] :
                   collect(fieldnames(typeof(o)))
            # rebuild with ONE changed element: the first directly-replaceable leaf child
            for s in segs
                o isa GM.DomainRef && s === :digest && continue   # form-pinned; :artifact serves
                cv = _child(o, s)
                if !(_leafcat(cv) in (:other, :nothing_leaf, :function))
                    _set_at!(R, Any[path; s], _distinct_value(cv, rng))
                    push!(opseen, :rebuild_imm)
                    return Any[path; s]
                end
            end
            # no direct leaf child — recurse into the first rebuildable child (finite: every
            # slot/record struct bottoms out in a leaf or a Vector)
            for s in segs
                cv = _child(o, s)
                if cv isa Vector
                    nv = copy(cv)
                    push!(nv, _push_elem(nv))
                    _set_at!(R, Any[path; s], nv)
                    push!(opseen, :rebuild_imm)
                    return Any[path; s]
                elseif cv isa Dict
                    return _apply_mutation!(R, (path = Any[path; s], cat = :dict, kind = :dict,
                                                pT = typeof(o), pf = s), i, rng, opseen)
                elseif cv isa Union{Tuple,NamedTuple,Pair} || cv isa GM._SLOT_STRUCT_UNION ||
                       cv isa GM._RECORD_STRUCT_UNION
                    return _apply_mutation!(R, (path = Any[path; s], cat = :imm, kind = :imm,
                                                pT = typeof(o), pf = s), i, rng, opseen)
                end
            end
            error("no mutable descendant for imm site at $path")
        elseif site.kind === :vec
            v = _objs_along(R, path)[end]::Vector
            op = (:push, :pop, :set)[1 + i % 3]
            if op === :pop && !isempty(v)
                pop!(v)
                push!(opseen, :vec_pop)
                return path
            elseif op === :set && !isempty(v) && !(_leafcat(v[1]) in (:other, :nothing_leaf))
                v[1] = _distinct_value(v[1], rng)
                push!(opseen, :vec_set)
                return Any[path; 1]
            else
                push!(v, _push_elem(v))
                push!(opseen, :vec_push)
                return path
            end
        elseif site.kind === :dict
            d = _objs_along(R, path)[end]::Dict
            op = (:new, :del, :set)[1 + i % 3]
            if op === :del && !isempty(d)
                delete!(d, first(keys(d)))
                push!(opseen, :dict_del)
                return path
            elseif op === :set && any(kv -> !(_leafcat(kv.second) in (:other, :nothing_leaf)), d)
                kv = first(Iterators.filter(kv -> !(_leafcat(kv.second) in (:other, :nothing_leaf)), d))
                d[kv.first] = _distinct_value(kv.second, rng)
                push!(opseen, :dict_set)
                return Any[path; _K(kv.first)]
            else
                isempty(d) && error("no :new template for empty $(typeof(d)) at $path")
                kv = first(d)
                d[d isa Dict{Symbol} || keytype(d) === Symbol ? gensym(:nk) :
                  keytype(d) === Any ? gensym(:nk) : error("no new key for $(keytype(d))")] = kv.second
                push!(opseen, :dict_new)
                return path
            end
        elseif site.kind === :dictkey
            d = _objs_along(R, path[1:end-1])[end]::Dict
            k = (path[end]::GM._Key).k
            val = d[k]
            delete!(d, k)
            d[_distinct_value(k, rng)] = val
            push!(opseen, :dict_key_replace)
            return path
        end
        error("unknown site kind $(site.kind)")
    end

    # ——— the oracle: door-reported segments, prefix-comparable at the SEGMENT level ———
    function _reported_segments(R)
        for f in GM._SNAPSHOT_FIELDS
            d = GM._deep_egal(getfield(R, f), R._snapshot[f])
            d === nothing || return Any[f; d.path]
        end
        return nothing
    end
    _seg_eq(a, b) =
        a isa GM._Key ? (b isa GM._Key && a.k === b.k) :
        b isa GM._Key ? false : a == b
    function _prefix_comparable(rep, mut)
        n = min(length(rep), length(mut))
        return all(_seg_eq(rep[j], mut[j]) for j in 1:n)
    end

    # ═══ THE MAIN PROPERTY LOOP: N = 1024, seed banked, sites cycle — 3 asserts each ═══
    N = 1024
    rng = Random.Xoshiro(0x5e2b15)
    sites = _enumerate_sites(R0)
    @assert length(sites) <= N "|sites| = $(length(sites)) exceeds N = $N — the §9 amend rule applies"
    @info "snapshot_property realized |sites|" length(sites)
    opseen = Set{Symbol}()

    for i in 1:N
        R = GM.publish(_mk_prop_builder())
        @test isempty(GM._registry_door_check(R))                          # (1) clean is SILENT
        site = sites[1 + (i - 1) % length(sites)]
        mutpath = _apply_mutation!(R, site, i, rng, opseen)
        @test _codesp(GM._registry_door_check(R)) == [:POST_SEAL_MUTATION] # (2) the mutation FIRES
        rep = _reported_segments(R)
        @test rep !== nothing && _prefix_comparable(rep, mutpath)          # (3) prefix-comparable
    end

    # ═══ the FALSE-POSITIVE half (§9): structurally identical rebuilds are SILENT — 8 ═══
    dagseen = Set{Symbol}()
    let R = GM.publish(_mk_prop_builder())                       # (1) Vector rebuilt fresh
        c = R.plugins[1].constraints
        _set_at!(R, Any[:plugins, 1, :constraints], GM.MutEx[e for e in c])
        @test isempty(GM._registry_door_check(R))
    end
    let R = GM.publish(_mk_prop_builder())                       # (2) Dict rebuilt fresh
        fl = R.plugins[1].vocabulary.flags
        _set_at!(R, Any[:plugins, 1, :vocabulary, :flags], Dict(k => v for (k, v) in fl))
        @test isempty(GM._registry_door_check(R))
    end
    let R = GM.publish(_mk_prop_builder())                       # (3) Tuple rebuilt
        t = R.plugins[1].default.value[17]
        _set_at!(R, Any[:plugins, 1, :default, :value, 17], ntuple(j -> t[j], length(t)))
        @test isempty(GM._registry_door_check(R))
    end
    let R = GM.publish(_mk_prop_builder())                       # (4) Pair rebuilt
        p = R.plugins[1].render.effects[1]
        _set_at!(R, Any[:plugins, 1, :render, :effects, 1], (p.first => GM.EffectRow(p.second.kind, p.second.payload)))
        @test isempty(GM._registry_door_check(R))
    end
    let R = GM.publish(_mk_prop_builder())                       # (5) NamedTuple rebuilt
        nt = R.plugins[1].default.value[18]
        _set_at!(R, Any[:plugins, 1, :default, :value, 18], NamedTuple{keys(nt)}(values(nt)))
        @test isempty(GM._registry_door_check(R))
    end
    let R = GM.publish(_mk_prop_builder())                       # (6) slot struct rebuilt
        cd = R.plugins[1].capture
        _set_at!(R, Any[:plugins, 1, :capture],                  # v0.4 T5: the 5th field carried (B-3 — a dropped field made this a NON-faithful rebuild)
                 GM.CaptureDecl(cd.instance_type, cd.attr_scheme, cd.multiplicity, cd.mode_gate, cd.attr_stem))
        @test isempty(GM._registry_door_check(R))
    end
    # stage 2's commit 3-ii: the default slot is the ALTERANT's — `_with_default(b, i, v)` declares `v` on the plugin OWNING action i
    # (action 4 = Visib's :discard → plugin 2), every other field copied; the readers below read `R.plugins[2].default`
    _with_default(b, i, v) = begin
        k = Int(b.action_specs[i].plugin); p = b.plugins[k]
        b.plugins[k] = GM.PlugIn(; altName = p.altName, setMode = p.setMode, altConstructor = p.altConstructor,
            setAltInstance = p.setAltInstance, getAltInstance = p.getAltInstance, precedencesTuple = p.precedencesTuple,
            default = GM.Declared(v), capture = p.capture, render = p.render, vocabulary = p.vocabulary,
            constraints = p.constraints, atoms = p.atoms, contract_version = p.contract_version, requires = p.requires,
            sugar = p.sugar, provenance = p.provenance, permissions = p.permissions)
        b
    end
    let                                                          # (7) DAG SPLIT: shared → unshared
        b = _mk_prop_builder()
        shared = Any[Int8(5)]
        b = _with_default(b, 4, Any[shared, shared])
        R = GM.publish(b)
        live = R.plugins[2].default.value
        live[2] = Any[e for e in live[1]]                        # sharing REMOVED on the live side
        @test isempty(GM._registry_door_check(R))
        push!(dagseen, :split)
    end
    let                                                          # (8) DAG JOIN: unshared → shared
        b = _mk_prop_builder()
        b = _with_default(b, 4, Any[Any[Int8(5)], Any[Int8(5)]])
        R = GM.publish(b)
        live = R.plugins[2].default.value
        live[2] = live[1]                                        # sharing INTRODUCED on the live side
        @test isempty(GM._registry_door_check(R))
        push!(dagseen, :join)
    end

    # ═══ the NAMED cases (§9): Σ = 46 asserts (44 at T2-bis + the T4 VocabularyRef case) ═══
    _with_ctor(b, T) = (b.plugins[2] = GM.PlugIn(; altName = :Visib, setMode = :mutExclusive,
        altConstructor = T, setAltInstance = GM.Alterants.setVisib); b)
    _swap_ctor!(R, T) = (R.plugins[2] = GM.PlugIn(; altName = :Visib, setMode = :mutExclusive,
        altConstructor = T, setAltInstance = GM.Alterants.setVisib); R)
    # (v0.4 T3 — the case-(iv) migration; RE-HOMED at T5: `SubString{String}` and its
    # swap target `String` are the ONLY named-case types without a zero-argument method,
    # so under the eager DEP_MISSING gate case (iv)'s TYPE half cannot ride the ctor
    # slot. T3 parked it on `capture.instance_type` while that slot was CARRIED; T5
    # CONSUMES the slot and its identity law (`instance_type === altConstructor`)
    # correctly refuses the old vehicle — the Type half now rides a DECLARED default
    # VALUE (a `Type` is an admitted domain leaf, compared `===` at the door — the same
    # Type-leaf compare the case exists to pin); cases (i)-(iii) keep the ctor slot.)

    # (i) `Val{M.f}` swapped to a same-named foreign function's Val — silent pre, fires post (2)
    let R = GM.publish(_with_ctor(_mk_prop_builder(), Val{_PropTypes.M1.f}))
        @test isempty(GM._registry_door_check(R))
        _swap_ctor!(R, Val{_PropTypes.M2.f})
        @test _codesp(GM._registry_door_check(R)) == [:POST_SEAL_MUTATION]
    end
    # (ii) `Val{M.T}` ↔ `Val{true}` category swap (2)
    let R = GM.publish(_with_ctor(_mk_prop_builder(), Val{_PropTypes.TA}))
        @test isempty(GM._registry_door_check(R))
        _swap_ctor!(R, Val{true})
        @test _codesp(GM._registry_door_check(R)) == [:POST_SEAL_MUTATION]
    end
    # (iii) a container-parameter type swap Vector{Any} ↔ Vector{Int} (2)
    let R = GM.publish(_with_ctor(_mk_prop_builder(), Vector{Any}))
        @test isempty(GM._registry_door_check(R))
        _swap_ctor!(R, Vector{Int})
        @test _codesp(GM._registry_door_check(R)) == [:POST_SEAL_MUTATION]
    end
    # (iv) SPLIT — the TYPE case SubString{String} → String fires by Type identity (2;
    # riding a DECLARED default value since T5 — see the migration comment above) + the
    # VALUE form refuses at validate (1)
    let R = GM.publish(_with_default(_mk_prop_builder(), 4, SubString{String}))
        @test isempty(GM._registry_door_check(R))
        _set_at!(R, Any[:plugins, 2, :default, :value], String)
        @test _codesp(GM._registry_door_check(R)) == [:POST_SEAL_MUTATION]
    end
    let d = GM.validate(_with_default(_mk_prop_builder(), 4, SubString("ab", 1, 1)))
        @test any(x -> x.code === :REG_PROTOCOL && occursin("slot default", x.message), d)
    end
    # (v0.4 T4 — the VocabularyRef case, T4-DESIGN §6-11: the declared digest is a String
    # LEAF inside the vocabulary slot — an equal-content REBUILD of the whole slot is
    # SILENT (the FP law over immutable-struct chains), and a digest swap fires at the
    # ELEMENT path `plugins[2].vocabulary.ref.digest` (probe-measured). The digest must be
    # a CAPTURED one — `_vocabulary_collect!` refuses any pin absent from the cache.) (2)
    _with_vocab!(R, dig) = (R.plugins[2] = GM.PlugIn(; altName = :Visib,
        setMode = :mutExclusive, altConstructor = GM.Alterants.Visib,
        setAltInstance = GM.Alterants.setVisib,
        vocabulary = GM.VocabularyRef(GM.DomainRef("labels_vocabulary.txt", dig))); R)
    let b = _mk_prop_builder()
        _with_vocab!(b, GM.Alterants.LABELS_VOCABULARY_DECLARED_DIGEST)
        R = GM.publish(b)
        _with_vocab!(R, GM.Alterants.LABELS_VOCABULARY_DECLARED_DIGEST)   # equal-content rebuild
        @test isempty(GM._registry_door_check(R))
        _with_vocab!(R, "sha256:" * "0"^64)                               # the digest-leaf swap
        ds = GM._registry_door_check(R)
        @test _codesp(ds) == [:POST_SEAL_MUTATION] &&
              occursin("plugins[2].vocabulary.ref.digest", ds[1].message)
    end
    # Dict ops with their path classes: key added (2) · deleted (2) · type-swapped 1 → 1.0
    # (2, CONTAINER) · -0.0 ↔ 0.0 (2, CONTAINER) · element appended (2) · removed (2)
    _dict_reg() = GM.publish(_with_default(_mk_prop_builder(), 4, Dict{Any,Any}(:a => 1, 1 => "one", -0.0 => :nz)))
    _dpath = Any[:plugins, 2, :default, :value]
    let R = _dict_reg()
        d = R.plugins[2].default.value
        d[:b] = 2
        @test _codesp(GM._registry_door_check(R)) == [:POST_SEAL_MUTATION]
        @test _reported_segments(R) == _dpath
    end
    let R = _dict_reg()
        delete!(R.plugins[2].default.value, :a)
        @test _codesp(GM._registry_door_check(R)) == [:POST_SEAL_MUTATION]
        @test _reported_segments(R) == _dpath
    end
    let R = _dict_reg()
        d = R.plugins[2].default.value
        delete!(d, 1); d[1.0] = "one"
        @test _codesp(GM._registry_door_check(R)) == [:POST_SEAL_MUTATION]
        @test _reported_segments(R) == _dpath                    # CONTAINER — no `===` key-match
    end
    let R = _dict_reg()
        d = R.plugins[2].default.value
        delete!(d, -0.0); d[0.0] = :nz
        @test _codesp(GM._registry_door_check(R)) == [:POST_SEAL_MUTATION]
        @test _reported_segments(R) == _dpath                    # CONTAINER — signed zero is a distinct key
    end
    let R = GM.publish(_with_default(_mk_prop_builder(), 4, Any[Int8(1), Int8(2)]))
        push!(R.plugins[2].default.value, Int8(3))
        @test _codesp(GM._registry_door_check(R)) == [:POST_SEAL_MUTATION]
        @test _reported_segments(R) == _dpath
    end
    let R = GM.publish(_with_default(_mk_prop_builder(), 4, Any[Int8(1), Int8(2)]))
        pop!(R.plugins[2].default.value)
        @test _codesp(GM._registry_door_check(R)) == [:POST_SEAL_MUTATION]
        @test _reported_segments(R) == _dpath
    end
    # the OVERLOAD LEAF case: a phase-only overload swap fires at overloads[j].phase (2)
    let R = GM.publish(_mk_prop_builder())
        ov = R.action_specs[3].overloads[1]
        R.action_specs[3].overloads[1] = GM.ActionOverload(ov.sig_types, ov.kinds, ov.kind_sources,
            ov.vararg_kind, ov.return_type, ov.effect, ov.queryable, ov.applicability,
            ov.phase === :apply ? :absorb : :apply, ov.grammar)
        @test _codesp(GM._registry_door_check(R)) == [:POST_SEAL_MUTATION]
        @test _reported_segments(R) == Any[:action_specs, 3, :overloads, 1, :phase]
    end
    # the STRUCT-KEYED-Dict silence case (1)
    let R = GM.publish(_with_default(_mk_prop_builder(), 4, Dict{Any,Any}(GM.MutEx([:hide, :show]) => 1)))
        @test isempty(GM._registry_door_check(R))
    end
    # the Ref-backed setter: clean ⇒ door empty (1); the CAPTURED-STATE silence (1)
    let R = GM.publish(_mk_prop_builder())
        @test isempty(GM._registry_door_check(R))
        _PropTypes.SETTER_REF[] += 1                             # behavior moves, identity does not
        @test isempty(GM._registry_door_check(R))                # the §11 residue, pinned as SILENCE
    end
    # the ALIAS case: a shared-container declaration publishes SILENT; a mutation through ONE
    # alias fires prefix-comparable to EITHER alias path (2)
    let b = _mk_prop_builder()
        shared = Any[Int8(7)]
        b = _with_default(b, 4, Any[shared, shared])
        R = GM.publish(b)
        @test isempty(GM._registry_door_check(R))
        R.plugins[2].default.value[1][1] = Int8(8)
        rep = _reported_segments(R)
        @test _codesp(GM._registry_door_check(R)) == [:POST_SEAL_MUTATION] && rep !== nothing &&
              (_prefix_comparable(rep, Any[_dpath; 1; 1]) || _prefix_comparable(rep, Any[_dpath; 2; 1]))
    end
    # the ROUND-2 Dict cases — the entry-matching law's witnesses (4 × 1)
    _twokey(v1, v2) = Dict{Any,Any}(GM.MutEx([:ka]) => v1, GM.MutEx([:ka]) => v2)
    let R = GM.publish(_with_default(_mk_prop_builder(), 4, _twokey(1, 2)))
        @test isempty(GM._registry_door_check(R))                # two equal keys, different values — SILENT
    end
    let R = GM.publish(_with_default(_mk_prop_builder(), 4, _twokey(1, 2)))
        d = R.plugins[2].default.value
        ks = collect(keys(d))
        v1 = d[ks[1]]; d[ks[1]] = d[ks[2]]; d[ks[2]] = v1        # a pure VALUE SWAP — structurally equal
        @test isempty(GM._registry_door_check(R))                # SILENT (scope note 4 — surfaced, ruled-covered reading)
    end
    let b = _mk_prop_builder()                                   # GUARD-ISOLATION: candidates share nested containers
        inner = Any[Int8(1)]
        b = _with_default(b, 4, Dict{Any,Any}(GM.MutEx([:ka]) => Any[inner], GM.MutEx([:ka]) => Any[inner]))
        R = GM.publish(b)
        @test isempty(GM._registry_door_check(R))
    end
    let b = _mk_prop_builder()                                   # a big equal-key Dict (16 keys), within budget
        big = Dict{Any,Any}()
        for _ in 1:16
            big[GM.MutEx([:kb])] = 1
        end
        R = GM.publish(_with_default(b, 4, big))
        @test isempty(GM._registry_door_check(R))
    end
    # the DONE-CACHE position case (1): one ActionSpec object structural AND inside data
    let b = _mk_prop_builder()
        b = _with_default(b, 4, b.action_specs[2])
        d = GM.validate(b)
        @test any(x -> x.code === :REG_PROTOCOL && x.context === b.plugins[2].altName &&   # commit 3-ii: the context is the Alterant's name
                       occursin("slot default", x.message), d)
    end
    # the NESTED-NUMERIC case (1): `Declared(Complex(1//2, 1//2))` publishes; door SILENT
    let R = GM.publish(_with_default(_mk_prop_builder(), 4, Complex(1//2, 1//2)))
        @test isempty(GM._registry_door_check(R))
    end
    # the DEPTH-TOWER case (1): a depth-20 shared two-equal-key Dict tower, SILENT within budget
    let b = _mk_prop_builder()
        cur = Any[Int8(1)]
        for _ in 1:20
            cur = Dict{Any,Any}(GM.MutEx([:t]) => cur, GM.MutEx([:t]) => cur)
        end
        R = GM.publish(_with_default(b, 4, cur))
        @test isempty(GM._registry_door_check(R))
    end
    # the TANDEM-CYCLE case (1): `d[k] = d` written on BOTH sides (a test-side B-2 act) — SILENT
    let R = GM.publish(_with_default(_mk_prop_builder(), 4, Dict{Any,Any}(:k => 1)))
        dl = R.plugins[2].default.value
        ds = R._snapshot.plugins[2].default.value
        dl[:self] = dl
        ds[:self] = ds
        @test isempty(GM._registry_door_check(R))
    end
    # the EQUAL-KEY-MUTATION case (2): a THIRD value under one of two equal keys — CONTAINER path
    let R = GM.publish(_with_default(_mk_prop_builder(), 4, _twokey(1, 2)))
        d = R.plugins[2].default.value
        d[first(keys(d))] = 3
        @test _codesp(GM._registry_door_check(R)) == [:POST_SEAL_MUTATION]
        @test _reported_segments(R) == _dpath
    end
    # the NESTED tandem cycle (1): `d2` under `d1`'s struct-keyed entry, self-cycled BOTH sides
    let R = GM.publish(_with_default(_mk_prop_builder(), 4, Dict{Any,Any}(GM.MutEx([:n]) => Dict{Any,Any}(:k => 1))))
        d2l = first(values(R.plugins[2].default.value))
        d2s = first(values(R._snapshot.plugins[2].default.value))
        d2l[:self] = d2l
        d2s[:self] = d2s
        @test isempty(GM._registry_door_check(R))
    end
    # the REJECTED-TWIN depth tower, DEPTH-CAPPED AT 10 (1): crosswise-equal values in REVERSED
    # entry order — ≈2^10 compares, exponential-in-depth by disclosure (§11), completes SILENT
    let
        mk(depth, rev) = begin
            x = Any[Int8(1)]
            y = Any[Int8(1)]
            for _ in 1:depth
                a = Dict{Any,Any}()
                b = Dict{Any,Any}()
                if rev
                    a[GM.MutEx([:r])] = x; a[GM.MutEx([:r])] = y
                    b[GM.MutEx([:r])] = y; b[GM.MutEx([:r])] = x
                else
                    a[GM.MutEx([:r])] = x; a[GM.MutEx([:r])] = y
                    b[GM.MutEx([:r])] = x; b[GM.MutEx([:r])] = y
                end
                x = a
                y = b
            end
            (x, y)
        end
        ta, tb = mk(10, true)
        @test GM._deep_egal(ta, tb) === nothing
    end
    # the DEEP-TYPE case (1): a ~10^5-deep admitted Type ⇒ the slot-named BUDGET row at validate
    let b = _mk_prop_builder()
        T = Int
        for _ in 1:100_000
            T = Val{T}
        end
        b = _with_ctor(b, T)
        d = GM.validate(b)
        @test any(x -> x.code === :REG_PROTOCOL && occursin("exceeds the type-encoder budget", x.message), d)
    end
    # the DEEP-KEY case (1): a deep tuple-shaped Dict key ⇒ `validate` RETURNS, never throws.
    # Shape + depth amended at the code commit (§S2.9, probe-grounded): a PURE tuple nest is
    # untypeable at depth in Julia itself (nested Tuple TYPE construction/inference overflows
    # at the harness-side build — outside the door's code), so the key alternates tuple over
    # `Vector{Any}` (constant type depth); Base's OWN `hash` recursion at the harness-side
    # Dict INSERT overflows at ~4×10^4, so depth = 2×10^4 — 78× over `_TYPE_BUDGET`, and the
    # iterative walk itself is depth-independent (probed at 10^5 by the DEEP-TYPE case).
    let b = _mk_prop_builder()
        t = Any[:a]
        for _ in 1:20_000
            t = (Any[t],)
        end
        b = _with_default(b, 4, Dict{Any,Any}(t => 1))
        d = GM.validate(b)
        @test d isa Vector{GM.Diagnostic}
    end
    # the COUNTING-HASH witness (2): the door dispatches NO `hash` — end-to-end
    let R = GM.publish(_with_default(_mk_prop_builder(), 4, Dict{Any,Any}(_PropTypes.CountKey => 1)))
        c0 = _PropTypes.HASH_COUNT[]                             # publish MAY hash (the copier's fill)
        @test isempty(GM._registry_door_check(R))
        @test _PropTypes.HASH_COUNT[] == c0                      # the door moved the counter by ZERO
    end

    # ═══ the 5 STRATIFIED COVERAGE asserts (§9) ═══
    recfields = Set{Tuple{DataType,Symbol}}()
    for s in sites
        objs = _objs_along(R0, s.path[1:end-1])
        for (j, seg) in enumerate(s.path)
            o = objs[j]
            (o isa GM.PlugIn || o isa GM.ActionSpec || o isa GM.ActionOverload) && seg isa Symbol &&
                push!(recfields, (typeof(o), seg))
        end
        s.pT in (GM.PlugIn, GM.ActionSpec, GM.ActionOverload) && s.path[end] isa Symbol &&
            push!(recfields, (s.pT, s.path[end]))
    end
    @test length(recfields) == 36                                # every §1 record field exercised (36: the Alterant's default slot joined at commit 3, the action's left at 3-ii — R-V04B-51)
    leafcats = Set(s.cat for s in sites if s.kind in (:leaf, :single, :dictkey))
    @test issubset(Set([:bool, :symbol, :int, :float, :string, :type, :function, :version,
                        :complex, :rational, :nothing_leaf]), leafcats)
    containercats = Set(s.cat for s in sites if s.kind in (:vec, :dict, :imm, :single))
    @test issubset(Set([:vector, :dict, :tuple, :namedtuple, :pair, :slotstruct, :record]), containercats)
    @test issubset(Set([:vec_push, :vec_pop, :vec_set, :dict_new, :dict_del, :dict_set,
                        :dict_key_replace, :single_substitute, :rebuild_imm,
                        :leaf_bool, :leaf_symbol, :leaf_int, :leaf_float, :leaf_string,
                        :leaf_type, :leaf_function, :leaf_version, :leaf_complex,
                        :leaf_rational]), opseen)
    @test dagseen == Set([:split, :join])                        # both DAG directions exercised
end
