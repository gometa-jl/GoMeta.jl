# capture_tests.jl — v0.4 T5: the CAPTURE RE-HOME witnesses (T5-DESIGN v2 §6).
#
# IS:   the T5 acceptance rows — the registration-driven walk mints for a CONFORMING
#       mock (the sadd2 anti-T1 cure), the typed capture floor's two arms, the scheme
#       conformance gates, the value algebra, the per-plugin localOnly flush, the ctor
#       triple, the tier-1 coherence/identity/stem laws, and the `:per_field` positive
#       fixture the corpus never reaches.
# DOES: registers mock Alterants through the sanctioned lifecycle (the PROBE-proven
#       shapes: register! varargs; the vararg-tail overload matching the setter's
#       method exactly), drives them through goMeta, and pins rows + diagnostics.
# REASONING: PROBE-14's sadd2 measurement — on v0.3.2 a conforming mock registered,
#       absorbed, applied PROCESS_OK and minted NO evals row (the 3-name ladder). These
#       witnesses are the only proof the declaration is now LOAD-BEARING at the capture
#       plane and the silence classes are typed.
# PURPOSE: the T5 acceptance rows (Σ = 29 in this file after the crx-t5 cure round:
#       23 at the T5 commit + [11]'s 6 + the [1] end-to-end algebra drive + the [7]
#       cross-stem pin − the [7] runtime pair made lifecycle-unreachable by the tier-1
#       store law; + 4 in record_schema_tests (the T5 3 + the B8 seal pin) —
#       4749 + 29 + 4 = 4782, every movement declared).

using Test
import GoMeta as GM

@eval module _CapM
    zset(d::Dict{Symbol,Bool}, a::Symbol, r::Symbol...) = (for x in r; d[x] = true; end; nothing)
    yset(d::Dict{Symbol,Bool}, a::Symbol, r::Symbol...) = (for x in r; d[x] = true; end; nothing)
    vset(v::Vector{Symbol}, a::Symbol, r::Symbol...) = (append!(v, r); nothing)
    badset(d::Dict{Symbol,Bool}, a::Symbol, r::Symbol...) = (d[a] = true; nothing)
    fset(d::Dict{Symbol,Any}, a::Symbol, r::Symbol...) = (for x in r; d[x] = 1.5; end; nothing)   # the out-of-algebra value
end

# the [11] fixtures: a Float64-array store (the machine-int narrowing) and a
# keys-less Bool store (the arm envelope) — both registrable, both must FLOOR
@eval module _CapF
    mutable struct FStore
        array::Vector{Float64}
        FStore() = new([0.0, 0.0])
    end
    nset(s::FStore, a::Symbol, r::Symbol...) = (s.array[1] = 1.5; nothing)
    mutable struct KStore
        array::Vector{Bool}
        KStore() = new([false])
    end
    kset(s::KStore, a::Symbol, r::Symbol...) = (s.array[1] = true; nothing)
end
Base.eltype(::Type{_CapF.FStore}) = Float64
Base.eltype(::Type{_CapF.KStore}) = Bool     # eltype passes; keys(KStore) does NOT exist

@testset "capture (v0.4 T5)" begin

    _doc(s) = Vector{UInt8}(codeunits(s))
    _zov(store) = GM.ActionOverload(; sig_types = Type[store, Symbol],
        kinds = Symbol[], kind_sources = Symbol[], vararg_kind = :symbol,
        return_type = Nothing, effect = :set, queryable = false,
        applicability = :context_free, phase = :apply, grammar = true)
    function _mockb(; capture = GM.CaptureDecl(Dict{Symbol,Bool}, :per_key, :many, nothing; attr_stem = :zm),
                      setter = _CapM.zset, store = Dict{Symbol,Bool}, name = :zmark)
        b = GM.RegistryBuilder(GM.DEFAULT_REGISTRY)
        pi = GM.next_plugin_index(b)
        GM.register!(b,
            GM.PlugIn(; altName = :zmock, setMode = :accumulate, altConstructor = store,
                setAltInstance = setter, capture = capture),
            GM.ActionSpec(; name = name, spelling = :identifier, plugin = pi,
                overloads = [_zov(store)]))
        b
    end

    @testset "[1] sadd2 — the conforming mock MINTS (the anti-T1 cure; three witnesses)" begin
        R = GM.publish(_mockb())
        r = GM.goMeta(_doc("x = 1\n#~ zmark(aa)\n\ny = 2\n"); registry = R)
        rows = GM.altValues_evals(r)
        # (the crx-t5 B6 strengthening) the three witnesses are INDEPENDENT: existence+
        # uniqueness selects by the stem PREFIX (not the expected attr), the attr is
        # then pinned, then the payload
        zrows = [t for t in rows if startswith(String(t[2]), "zm")]
        @test r.status === GM.PROCESS_OK && length(zrows) == 1     # exactly ONE mock row
        @test zrows[1][2] === :zm_aa                               # attr = stem + key
        @test zrows[1][3] === true && zrows[1][4] === true         # value + polarity faithful
        # the value algebra END-TO-END: a store that CAN carry an out-of-set value
        # (Dict{Symbol,Any}; the setter puts 1.5) floors typed and mints NO row
        Ra = GM.publish(_mockb(; capture = GM.CaptureDecl(Dict{Symbol,Any}, :per_key, :many, nothing; attr_stem = :zx),
                                 setter = _CapM.fset, store = Dict{Symbol,Any}, name = :xmark))
        ra = GM.goMeta(_doc("x = 1\n#~ xmark(aa)\n\ny = 2\n"); registry = Ra)
        @test ra.status === GM.PROCESS_OK &&
              any(d -> d.code === :WARN_CAPTURE_UNREADABLE, ra.diagnostics) &&
              !any(t -> startswith(String(t[2]), "zx"), GM.altValues_evals(ra))
    end

    @testset "[2] the capture floor's FIRST arm (no capture row: disclosed, once, zero rows)" begin
        b = _mockb(; capture = nothing)
        R = GM.publish(b)
        r = GM.goMeta(_doc("x = 1\n#~ zmark(aa)\n\ny = 2\n#~ zmark(bb)\n\nz = 3\n"); registry = R)
        @test r.status === GM.PROCESS_OK
        floors = [d for d in r.diagnostics if d.code === :WARN_CAPTURE_FLOOR]
        @test length(floors) == 1 && floors[1].context === :zmock  # ONCE per call, not per cell
        @test !any(t -> startswith(String(t[2]), "zm"), GM.altValues_evals(r))
    end

    @testset "[3] the SECOND arm — the conformance gates + the value algebra" begin
        # a :per_key row over a non-Dict store (Vector{Symbol} — the identity law holds:
        # instance_type === altConstructor === Vector{Symbol}; the SHAPE gate refuses)
        Rv = GM.publish(_mockb(; capture = GM.CaptureDecl(Vector{Symbol}, :per_key, :many, nothing; attr_stem = :zv),
                                 setter = _CapM.vset, store = Vector{Symbol}, name = :vmark))
        rv = GM.goMeta(_doc("x = 1\n#~ vmark(aa)\n\ny = 2\n"); registry = Rv)
        @test rv.status === GM.PROCESS_OK &&
              any(d -> d.code === :WARN_CAPTURE_UNREADABLE && d.context === :zmock, rv.diagnostics)
        # a :per_field row over a non-Number-eltype store: the capability gate floors it
        Rf = GM.publish(_mockb(; capture = GM.CaptureDecl(Dict{Symbol,Bool}, :per_field, :per_field, nothing; attr_stem = :zf)))
        rf = GM.goMeta(_doc("x = 1\n#~ zmark(aa)\n\ny = 2\n"); registry = Rf)
        @test rf.status === GM.PROCESS_OK &&
              any(d -> d.code === :WARN_CAPTURE_UNREADABLE, rf.diagnostics) &&
              !any(t -> startswith(String(t[2]), "zf"), GM.altValues_evals(rf))
        # the VALUE ALGEBRA: an admitted Dict whose VALUES are in-set mints; the
        # out-of-set case is structurally unreachable from a `Dict{Symbol,Bool}` store,
        # so the algebra is pinned DIRECTLY on the predicate
        @test GM._capture_value_leaf(true) && GM._capture_value_leaf(:s) &&
              GM._capture_value_leaf("t") && GM._capture_value_leaf(Int16(3)) &&
              !GM._capture_value_leaf(1.5) && !GM._capture_value_leaf([1])
    end

    @testset "[4] the :per_field POSITIVE fixture (the corpus-inert Id arm)" begin
        # the pre-T5 ladder bytes for a populated Id, checked-in as a literal:
        # `cell(7)` ⇒ the one row (:id_cell, 7); parent/file (0) ABSENT
        R = GM.publish(GM.default_registry_builder())
        r = GM.goMeta(_doc("x = 1\n#~ cell(7)\n\ny = 2\n"); registry = R)
        rows = GM.altValues_evals(r)
        idrows = [(t[2], t[3]) for t in rows if startswith(String(t[2]), "id_")]
        @test idrows == [(:id_cell, Int16(7))]                     # one row per non-default field
        @test !any(t -> t[2] === :id_parent || t[2] === :id_file, rows)   # defaulted fields absent
    end

    @testset "[5] the Visib multiplicity refuse VERBATIM through the :single arm" begin
        src = read(joinpath(dirname(dirname(@__DIR__)), "src", "annotations.jl"), String)
        @test occursin("more than one Visib value set for one component — v0's Visib ", src) &&
              occursin("actions (show/hide/discard) are mutually exclusive per component ", src)
    end

    @testset "[6] the ungated :per_occurrence fifth arm (one presence row per governed cell)" begin
        R = GM.publish(_mockb(; capture = GM.CaptureDecl(Dict{Symbol,Bool}, :per_occurrence, :many, nothing; attr_stem = :zp)))
        r = GM.goMeta(_doc("x = 1\n#~ zmark(aa)\n\ny = 2\n"); registry = R)
        prow = [t for t in GM.altValues_evals(r) if t[2] === :zp]
        @test length(prow) == 1 && prow[1][3] === true
    end

    @testset "[7] the localOnly plumbing — per-plugin flush; the wrong-shape floor, NO poison" begin
        # a SECOND localOnly plugin (a Heading-shaped store of its own) flushes
        # independently under its own stem
        b = GM.RegistryBuilder(GM.DEFAULT_REGISTRY)
        pi = GM.next_plugin_index(b)
        GM.register!(b,
            GM.PlugIn(; altName = :zhead, setMode = :localOnly,
                altConstructor = GM.Alterants.Heading, setAltInstance = GM.Alterants.setHead,
                capture = GM.CaptureDecl(GM.Alterants.Heading, :per_occurrence, :many, :localOnly; attr_stem = :zh)),
            GM.ActionSpec(; name = :zhd, spelling = :identifier, plugin = pi,
                overloads = GM.DEFAULT_REGISTRY.action_specs[GM.DEFAULT_REGISTRY.spec_index[:head]].overloads,
                accepts_string_slot = 1))
        R = GM.publish(b)
        r = GM.goMeta(_doc("x = 1\n#~ \"T\" zhd(\"U\", 2)\n\ny = 2\n"); registry = R)
        rows = GM.altValues_evals(r)
        @test r.status === GM.PROCESS_OK &&
              any(t -> t[2] === :head_1 && t[3] == "T", rows) &&
              any(t -> startswith(String(t[2]), "zh_") && t[3] == "U", rows)
        # (B6) the CROSS-STEM ABSENCES pin the per-plugin injectivity: no head-row
        # carries "U" and no zh-row carries "T" (the shared-store failure's signature)
        @test !any(t -> startswith(String(t[2]), "head") && t[3] == "U", rows) &&
              !any(t -> startswith(String(t[2]), "zh") && t[3] == "T", rows)
        # (the crx-t5 evolution) the RUNTIME wrong-shape floor became lifecycle-
        # unreachable — the tier-1 localOnly STORE LAW (witnessed at [11]) refuses an
        # entries-less gated row at publish; the flush's floor branch stays as
        # defense-in-depth against post-publication mutation (the B-2 class).
    end

    @testset "[8] the CaptureDecl ctor triple" begin
        c4 = GM.CaptureDecl(Dict{Symbol,Bool}, :per_key, :many, nothing)
        c5 = GM.CaptureDecl(Dict{Symbol,Bool}, :per_key, :many, nothing, :zz)
        ck = GM.CaptureDecl(Dict{Symbol,Bool}, :per_key, :many, nothing; attr_stem = :zz)
        @test c4.attr_stem === nothing
        @test c5.attr_stem === :zz && ck.attr_stem === :zz
        @test c5.instance_type === Dict{Symbol,Bool} && ck.multiplicity === :many
    end

    @testset "[9] the tier-1 laws (coherence · identity · stem clash)" begin
        # gate/setMode incoherence: an :accumulate record gating :localOnly refuses
        bi = _mockb(; capture = GM.CaptureDecl(Dict{Symbol,Bool}, :per_key, :many, :localOnly; attr_stem = :zi))
        @test any(x -> x.code === :REG_PROTOCOL && occursin("INCOHERENT", x.message), GM.validate(bi))
        # instance_type ≠ altConstructor refuses
        bt = _mockb(; capture = GM.CaptureDecl(Vector{Symbol}, :per_key, :many, nothing; attr_stem = :zt))
        @test any(x -> x.code === :REG_PROTOCOL && occursin("capture identity law", x.message), GM.validate(bt))
        # the stem-clash law: a mock declaring the shipped :label stem refuses
        bc = _mockb(; capture = GM.CaptureDecl(Dict{Symbol,Bool}, :per_key, :many, nothing; attr_stem = :label))
        @test any(x -> x.code === :REG_PROTOCOL && occursin("stem-clash law", x.message), GM.validate(bc))
    end

    @testset "[10] the derived-fallback stem (a mock with attr_stem = nothing)" begin
        R = GM.publish(_mockb(; capture = GM.CaptureDecl(Dict{Symbol,Bool}, :per_key, :many, nothing)))
        r = GM.goMeta(_doc("x = 1\n#~ zmark(aa)\n\ny = 2\n"); registry = R)
        @test any(t -> t[2] === :zmock_aa, GM.altValues_evals(r))   # lowercase(String(:zmock)) = "zmock"
    end

    @testset "[11] the crx-t5 cure witnesses" begin
        # (A1) a localOnly plugin with capture === nothing: the FLOOR arm, never the
        # UNREADABLE-with-nothing crash — the drive completes and floors typed
        b1 = GM.RegistryBuilder(GM.DEFAULT_REGISTRY)
        p1 = GM.next_plugin_index(b1)
        GM.register!(b1,
            GM.PlugIn(; altName = :znone, setMode = :localOnly,
                altConstructor = GM.Alterants.Heading, setAltInstance = GM.Alterants.setHead),
            GM.ActionSpec(; name = :znh, spelling = :identifier, plugin = p1,
                overloads = GM.DEFAULT_REGISTRY.action_specs[GM.DEFAULT_REGISTRY.spec_index[:head]].overloads,
                accepts_string_slot = 1))
        r1 = GM.goMeta(_doc("x = 1\n#~ \"T\" znh(\"V\", 2)\n\ny = 2\n"); registry = GM.publish(b1))
        @test r1.status === GM.PROCESS_OK &&
              any(d -> d.code === :WARN_CAPTURE_FLOOR && d.context === :znone, r1.diagnostics)
        # (A5) the localOnly scheme law: a gated row declaring :per_key refuses at tier 1
        bs = _mockb(; capture = GM.CaptureDecl(Dict{Symbol,Bool}, :per_key, :many, :localOnly; attr_stem = :zs))
        @test any(x -> x.code === :REG_PROTOCOL && occursin("localOnly scheme law", x.message), GM.validate(bs))
        # (A4/C3) the localOnly store law: a gated :per_occurrence row on an
        # entries-less instance type refuses at tier 1 (STATIC — the fieldtype check)
        b4 = GM.RegistryBuilder(GM.DEFAULT_REGISTRY)
        p4 = GM.next_plugin_index(b4)
        GM.register!(b4,
            GM.PlugIn(; altName = :zle, setMode = :localOnly,
                altConstructor = Dict{Symbol,Bool}, setAltInstance = _CapM.badset,
                capture = GM.CaptureDecl(Dict{Symbol,Bool}, :per_occurrence, :many, :localOnly; attr_stem = :ze)),
            GM.ActionSpec(; name = :zle1, spelling = :identifier, plugin = p4,
                overloads = [GM.ActionOverload(; sig_types = Type[Dict{Symbol,Bool}, Symbol],
                    kinds = Symbol[], kind_sources = Symbol[], vararg_kind = :symbol,
                    return_type = Nothing, effect = :set, queryable = false,
                    applicability = :context_free, phase = :absorb, grammar = true)]))
        @test any(x -> x.code === :REG_PROTOCOL && occursin("localOnly store law", x.message), GM.validate(b4))
        # (A6) the stem PREFIX-FAMILY clash: :label_x overlaps the shipped :label family
        bp = _mockb(; capture = GM.CaptureDecl(Dict{Symbol,Bool}, :per_key, :many, nothing; attr_stem = :label_x))
        @test any(x -> x.code === :REG_PROTOCOL && occursin("stem-clash law", x.message), GM.validate(bp))
        # (A2/B1 narrowing) a Float-eltype :per_field mock floors typed (the machine-int
        # gate) — a foreign @namedElement Float64 store registers and floors, no row
        Rn = GM.publish(_mockb(; capture = GM.CaptureDecl(_CapF.FStore, :per_field, :per_field, nothing; attr_stem = :zn),
                                 setter = _CapF.nset, store = _CapF.FStore, name = :nmark))
        rn = GM.goMeta(_doc("x = 1\n#~ nmark(aa)\n\ny = 2\n"); registry = Rn)
        @test rn.status === GM.PROCESS_OK &&
              any(d -> d.code === :WARN_CAPTURE_UNREADABLE, rn.diagnostics) &&
              !any(t -> startswith(String(t[2]), "zn"), GM.altValues_evals(rn))
        # (the arm envelope) a custom :single-gated type whose keys(T) is MISSING
        # (eltype pirated to Bool, an :array field, no keys method): floors typed,
        # never a raw MethodError
        Rk = GM.publish(_mockb(; capture = GM.CaptureDecl(_CapF.KStore, :single, :one, nothing; attr_stem = :zk),
                                 setter = _CapF.kset, store = _CapF.KStore, name = :kmark))
        rk = GM.goMeta(_doc("x = 1\n#~ kmark(aa)\n\ny = 2\n"); registry = Rk)
        @test rk.status === GM.PROCESS_OK &&
              any(d -> d.code === :WARN_CAPTURE_UNREADABLE, rk.diagnostics)
    end
end
