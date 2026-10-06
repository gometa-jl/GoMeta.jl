# vocabulary_tests.jl — the Labels vocabulary witnesses (v0.4 T4's whitelist relocation, trimmed at stage 5's E9 of the v0.4
# build: the digest pin, the capture cache, the artifact grammar, the scope law, the G-VOC read surface and the write-only
# valve left with their subjects — census rows 10, 28 and 55, OWNER-WORDS §317; the 38 names stay in the plain file).
#
# IS:   the membership witnesses over the plain file ([2] the set role refuses an unknown name; [3] the late-order name in
#       both roles — the ∈-scan, never `insorted`), the zero-literal law in its DECIDABLE form ([10]: no Core literal of the
#       names re-enters src outside alterants-std/), and the crx-t3t4 cure witnesses that live here by history ([11]'s A3,
#       [12]–[18]: the zero-dispatch validate chain, the DomainRef read-once law ([14] — retired at stage 5's E10 with `DomainRef`), the identity/getfield hardening, the
#       structural callable name, the String-only encoder, the getfield numeric leaf).
# DOES: drives the shipped vocabulary through goMeta and the direct setter, publishes hostile builders through validate,
#       and greps the src tree against the ENUMERATED survivor census.
# PURPOSE: the T4 acceptance rows that survive E9 (the retired testsets, with their counts: [1] 2, [4] 2, [5] 3, [6] 2, [7] 2,
#       [9] 1, [11]'s A4/B4/C2 3, C1 1 and B2 1 — 17 asserts — the earlier [8] 1 at E2, and [14] 1 at E10 with `DomainRef`).

using Test
import GoMeta as GM

# the [12]/[13] fixtures: types whose `show(::IO, ::Type)` / `nameof(::Type)` /
# `hasmethod(::Type, ...)` specializations THROW — the zero-dispatch validate chain must
# never invoke any of them (t3t4r seat A's hostile-show class; t3t4r2's pirated-nameof /
# pirated-hasmethod / hostile-payload / hostile-sig classes)
@eval module _VocHostile
    struct Hostile end
    struct Hostile2 end
    struct Hostile3 end     # [13] pirated hasmethod (a no-field struct — a REAL zero-arg ctor exists)
    struct HostileP end     # [13] a declared VALUE whose type's show throws (the emit render)
    struct HostileS end     # [13] a sig-slot / return_type whose show throws (the reflection + algebra renders)
end
Base.show(io::IO, ::Type{_VocHostile.Hostile}) = error("hostile-show-invoked (must never render)")
Base.nameof(::Type{_VocHostile.Hostile2}) = error("hostile-nameof-invoked (must never render)")
Base.hasmethod(::Type{_VocHostile.Hostile3}, ::Type{Tuple{}}) = error("hostile-hasmethod-invoked (must never dispatch)")
Base.show(io::IO, ::Type{_VocHostile.HostileP}) = error("hostileP-show-invoked (must never render)")
Base.show(io::IO, ::Type{_VocHostile.HostileS}) = error("hostileS-show-invoked (must never render)")

# the [15] fixtures (the t3t4r3 in-model rows): a Function-subtype setter whose
# hash/isequal/== throw; a type whose getproperty throws; a function whose nameof throws
# (as a to-be-refused Dict KEY); a setter whose exact signature-tuple type carries a
# throwing == specialization. None of these methods may ever dispatch from validate.
@eval module _VocR3
    struct HFn <: Function end
    (f::HFn)(d::Dict{Symbol,Bool}, s::Symbol, r::Symbol...) = (d[s] = true; nothing)
    struct HG end
    hkey(x...) = true
    heq(d::Dict{Symbol,Bool}, s::Symbol) = (d[s] = true; nothing)
    const EQCALLS = Base.RefValue{Int}(0)   # (r4-B2) proves the piracy is never SELECTED
    const KCALLS = Base.RefValue{Int}(0)    # (r4-B1) proves the key nameof never EXECUTES
end
Base.hash(::_VocR3.HFn, ::UInt) = error("hash-pirated (must never dispatch)")
Base.isequal(::_VocR3.HFn, ::Any) = error("isequal-pirated (must never dispatch)")
Base.:(==)(::_VocR3.HFn, ::Any) = error("eq-pirated (must never dispatch)")
Base.getproperty(::Type{_VocR3.HG}, ::Symbol) = error("getproperty-pirated (must never dispatch)")
Base.nameof(::typeof(_VocR3.hkey)) = (_VocR3.KCALLS[] += 1;
    error("nameof-pirated-key (must never dispatch)"))
# (r4-B2 cure of the witness) BOTH operands typed — `(::Type{X}, ::Any)` was AMBIGUOUS
# with Base's `==(::Type, ::Type)` on the exact comparison (an ambiguity MethodError,
# not a selection); `(::Type{X}, ::Type)` is strictly more specific and WOULD be
# selected pre-cure — the counter proves the cured `===` never selects it.
Base.:(==)(::Type{Tuple{typeof(_VocR3.heq), Dict{Symbol,Bool}, Symbol}}, ::Type) =
    (_VocR3.EQCALLS[] += 1; error("sig-eq-pirated (must never dispatch)"))

# the [16] fixtures (the t3t4r4 root): a Function as a legit isbits TYPE PARAMETER whose
# nameof throws-and-counts — the structural callable render must never invoke it
@eval module _VocR4
    tag() = nothing
    struct Store{F} end
    setS(s::Store{tag}, a::Symbol) = nothing
    const TCALLS = Base.RefValue{Int}(0)
end
Base.nameof(::typeof(_VocR4.tag)) = (_VocR4.TCALLS[] += 1;
    error("tag-nameof-pirated (must never dispatch)"))

# the [17] fixtures (the t3t4r5 rows): a caller-owned AbstractString with a REAL string
# interface whose String() conversion COUNTS and, once POST-armed, throws (the stateful
# decay is the only constructible form — Base's AbstractString hash itself converts, so
# a permanently-throwing String() could never even enter the registrant's Dict); and a
# setter carrying an UNDECLARED method whose sig parameter is outside the encodable
# domain (Val{'x'} — a Char has no encoder).
@eval module _VocR5
    struct BadString <: AbstractString end
    const SCALLS = Base.RefValue{Int}(0)
    const POST = Base.RefValue{Bool}(false)
    vset(d::Dict{Symbol,Bool}, s::Symbol) = (d[s] = true; nothing)
    vset(::Val{'x'}) = nothing
end
Base.String(::_VocR5.BadString) = begin
    _VocR5.SCALLS[] += 1
    _VocR5.POST[] && error("String-pirated-at-validate (must never run)")
    "abc"
end
Base.ncodeunits(::_VocR5.BadString) = 3
Base.codeunit(::_VocR5.BadString, i::Int) = (0x61, 0x62, 0x63)[i]
Base.codeunit(::_VocR5.BadString) = UInt8
Base.isvalid(::_VocR5.BadString, i::Int) = 1 <= i <= 3
Base.iterate(::_VocR5.BadString, i::Int = 1) = i > 3 ? nothing : (Char(0x60 + i), i + 1)
Base.length(::_VocR5.BadString) = 3

# the [18] fixtures (the t3t4r6 rows): a caller Real inside Complex whose extensible
# `real` specialization COUNTS and throws (the numeric leaf must read fields, never
# dispatch); a parameterized Function SUBTYPE whose self-type carries an out-of-domain
# Char parameter (the declared-sig render must bucket, never throw).
@eval module _VocR6
    struct MyReal <: Real; v::Int; end
    struct MyIntB <: Integer; v::Int; end
    struct SetterX{C} <: Function end
    (f::SetterX)(d::Dict{Symbol,Bool}, s::Symbol) = (d[s] = true; nothing)
    const RCALLS = Base.RefValue{Int}(0)
end
Base.real(::Complex{_VocR6.MyReal}) = (_VocR6.RCALLS[] += 1;
    error("real-pirated (must never dispatch)"))
Base.numerator(::Rational{_VocR6.MyIntB}) = (_VocR6.RCALLS[] += 1;
    error("numerator-pirated (must never dispatch)"))

@testset "vocabulary (v0.4 T4)" begin

    _doc(s) = Vector{UInt8}(codeunits(s))
    _plugin_with_default(p, d) = GM.PlugIn(; altName = p.altName, setMode = p.setMode, altConstructor = p.altConstructor,
        setAltInstance = p.setAltInstance, getAltInstance = p.getAltInstance, precedencesTuple = p.precedencesTuple,
        default = d, capture = p.capture)   # stage 2's commit 3-ii: the declared default is the ALTERANT's — the record `p` with the slot `d`, every other field copied
    _drive(s; R = GM.DEFAULT_REGISTRY) = try
        GM.goMeta(_doc(s); registry = R)
    catch e
        e
    end

    @testset "[2] membership over the plain file: a shipped name applies, an unknown name refuses in the SET role" begin
        r = _drive("x = 1\n#~ :label1\n\ny = 2\n")
        @test r isa GM.GoMetaDelivery && r.status === GM.PROCESS_OK
        e = _drive("x = 1\n#~ :nope\n\ny = 2\n")
        @test e isa ErrorException && occursin("unknown label", e.msg)
    end

    @testset "[3] the LATE-order name :💫 (the C4E-4 order-independence pin)" begin
        # `:💫` sits late in DECLARATION order, which is UNSORTED — an `insorted` scan
        # over it would silently lose the names after the first sort break while the
        # corpus stayed green (the 28/38 class). Both roles must pass through the ∈-scan.
        rs = _drive("x = 1\n#~ :💫\n\ny = 2\n")
        @test rs isa GM.GoMetaDelivery && rs.status === GM.PROCESS_OK
        rq = _drive("x = 1\n#~1 :💫 hide{ :💫 }\n\ny = 2\n")
        @test rq isa GM.GoMetaDelivery && rq.status === GM.PROCESS_OK
    end

    @testset "[10] the zero-literal law (the C4E-7 DECIDABLE form)" begin
        # (a) the deleted collection identifiers survive NOWHERE in src outside
        # `alterants-std/` on a NON-comment line (the tombstone comments are prose);
        # (b) the vocabulary-name literal census over src (the union pattern
        # `label1` ∪ `:🔥`) equals EXACTLY the enumerated survivor set — every survivor
        # is prose (docstrings, comments, the two kept empty-list-message examples), so
        # any new enumeration of shipped names re-entering Core trips this comparison.
        srcdir = joinpath(dirname(dirname(@__DIR__)), "src")
        id_offenders = String[]
        census = Dict{String,Int}()
        for (root, _, files) in walkdir(srcdir)
            occursin("alterants-std", root) && continue
            for f in files
                endswith(f, ".jl") || continue
                fp = joinpath(root, f)
                rel = replace(relpath(fp, srcdir), '\\' => '/')
                for (i, ln) in enumerate(eachline(fp))
                    if !startswith(lstrip(ln), "#") &&
                       (occursin("goMetaLabels", ln) || occursin("sortedSetOfLabelsSVec", ln))
                        push!(id_offenders, string(rel, ":", i))
                    end
                    if occursin("label1", ln) || occursin(":🔥", ln)
                        census[rel] = get(census, rel, 0) + 1
                    end
                end
            end
        end
        survivors = Dict("config.jl" => 1,                    # §1 feed docstring example
                         "condition.jl" => 4,                 # the `{:🔥}` + `:abc(:label1)` comment set
                         "GoMeta.jl" => 1,                    # the profile-feed docstring example
                         # (apply.jl's one — the seam header's condition-side-atoms comment — left with the set-invocation seam at stage 5's E6
                         # of the v0.4 build, census row 14; measured on both trees: apply.jl 1 → 0, every other file equal)
                         "alterants/registry.jl" => 3)        # the header note + the TWO kept empty-list messages
        # DISCLOSED LIMIT (the crx-t3t4 C3 row): this is a SOURCE-TEXT tripwire, not a
        # semantic guarantee — a computed enumeration (names built from strings or
        # codepoints, or a literal subset avoiding both sentinel patterns) passes both
        # prongs. Its real coverage: the two retired identifiers can never return, and
        # any prose/code re-using the sentinel names trips the census comparison.
        @test isempty(id_offenders) && census == survivors
    end

    @testset "[11] the crx-t3t4 milestone-set cure witnesses" begin
        # (A4/B4/C2 — the artifact grammar's three refusal classes; C1 — the call-grain two-pass law of the valve; B2 — the
        # G-VOC predicates' fail-closed law) were CONSCIOUSLY RETIRED at stage 5's E9 of the v0.4 build with their
        # subjects: the artifact grammar, the write-only valve and the G-VOC read surface (census rows 10, 28, 55).
        # (A3; re-cut at stage 5's E4 — the DEP_MISSING row left with the eager dependency closure) `validate`
        # is total over a Union-typed altConstructor: it RETURNS (the domain probe walks the type)
        bu = GM.RegistryBuilder(GM.DEFAULT_REGISTRY)
        bu.plugins[2] = GM.PlugIn(; altName = :Visib, setMode = :mutExclusive,
            altConstructor = Union{Int,String}, setAltInstance = GM.Alterants.setVisib)
        @test GM.validate(bu) isa Vector{GM.Diagnostic}
    end

    @testset "[12] the crx-t3t4r reconfirm cure — the NON-DISPATCHING ctor renderer" begin
        # (the three DEP_MISSING render arms were CONSCIOUSLY RETIRED at stage 5's E4 with their subject, the
        # eager dependency closure — census row 3; the structural renderer stays for the localOnly store
        # law's row — its bottom leaf pinned)
        @test GM._ctor_type_name(Union{}) == "Union{}"   # the bottom leaf, pinned total
    end

    @testset "[13] the t3t4r2 FAMILY cures — the zero-dispatch validate chain" begin
        _vis(alt) = GM.PlugIn(; altName = :Visib, setMode = :mutExclusive,
            altConstructor = alt, setAltInstance = GM.Alterants.setVisib)
        # (A3/A4 — the invoke-pinned `hasmethod` gate and the Union{} refusal — were CONSCIOUSLY RETIRED at
        # stage 5's E4 with their subject, the eager dependency closure.)
        # (A5) a budget-refused ctor type: the 300-member Union is over the 256-node budget — the
        # registration refuses on the encodability row.
        bigU = reduce((a, i) -> Union{a, Val{i}}, 1:300; init = Union{})
        b5 = GM.RegistryBuilder(GM.DEFAULT_REGISTRY); b5.plugins[2] = _vis(bigU)
        @test any(x -> x.code === :REG_PROTOCOL, GM.validate(b5))
        # (A6, probe P54) a declared VALUE outside the encodable domain renders its type
        # STRUCTURALLY — pre-cure the REG_PROTOCOL row's own interpolation ran the
        # hostile `show` and validate threw "hostileP-show".
        b6 = GM.RegistryBuilder(GM.DEFAULT_REGISTRY)
        s6 = b6.action_specs[4]
        b6.action_specs[4] = GM.ActionSpec(; name = s6.name, plugin = s6.plugin, accepts_string_slot = s6.accepts_string_slot,
            validate = s6.validate)
        b6.plugins[2] = _plugin_with_default(b6.plugins[2], GM.Declared(_VocHostile.HostileP()))   # the hostile value rides the Alterant's slot (commit 3-ii)
        d6 = GM.validate(b6)
        @test any(x -> x.code === :REG_PROTOCOL && occursin("HostileP", x.message), d6)
        # (A7/A8 — the hostile-typed SIG_MISMATCH and VALUE_ALGEBRA renders — were CONSCIOUSLY RETIRED at
        # stage 5's E4 with their subjects, the reflection cross-check and the value-algebra refusal.)
    end

    @testset "[15] the crx-t3t4r3 cures — the identity/getfield hardening of the chain" begin
        _vset(setter) = begin
            b = GM.RegistryBuilder(GM.DEFAULT_REGISTRY)
            b.plugins[2] = GM.PlugIn(; altName = :Visib, setMode = :mutExclusive,
                altConstructor = GM.Alterants.Visib, setAltInstance = setter)
            b
        end
        # (A3=B1=C2, probe P60; re-cut at stage 5's E4 — the reflection pooling left with the cross-check) a
        # setter whose hash/isequal/== all throw: validate RETURNS without dispatching them
        d60 = GM.validate(_vset(_VocR3.HFn()))
        @test d60 isa Vector
        # (A4=B2; the exact-signature `===` match left with the cross-check at stage 5's E4) a
        # throwing == specialization on the setter's OWN signature-tuple type never dispatches:
        # validate returns and the pirated == is never SELECTED.
        bq = GM.RegistryBuilder(GM.DEFAULT_REGISTRY)
        sq = bq.action_specs[1]
        bq.plugins[1] = GM.PlugIn(; altName = :labels, setMode = :accumulate,
            altConstructor = Dict{Symbol,Bool}, setAltInstance = _VocR3.heq,
            getAltInstance = GM.Alterants.checkLabels)
        bq.action_specs[1] = GM.ActionSpec(; name = sq.name, plugin = sq.plugin, accepts_string_slot = sq.accepts_string_slot,
            validate = sq.validate)
        dq = GM.validate(bq)
        @test dq isa Vector && _VocR3.EQCALLS[] == 0     # (r4-B2) the piracy was never SELECTED under ===
        # (A2, probe P62) the budget walkers read the type graph via getfield only: a
        # type whose getproperty throws walks clean (pre-cure the walk itself threw).
        @test GM._type_budget_check(_VocR3.HG)[1] === :ok &&
              GM._key_order_budget(_VocR3.HG)
        # (C1, probe P63) a to-be-refused Function KEY inside a declared Dict: the
        # ordering prepass falls back to iteration order on ANY key-encode throw (the
        # pirated nameof never escapes) and the WALK refuses the key typed.
        bk = GM.RegistryBuilder(GM.DEFAULT_REGISTRY)
        sk = bk.action_specs[4]
        bk.action_specs[4] = GM.ActionSpec(; name = sk.name, plugin = sk.plugin, accepts_string_slot = sk.accepts_string_slot,
            validate = sk.validate)
        bk.plugins[2] = _plugin_with_default(bk.plugins[2], GM.Declared(Dict{Any,Any}(_VocR3.hkey => 1)))   # commit 3-ii: the Alterant's slot
        dk = GM.validate(bk)
        @test dk isa Vector && any(x -> x.code === :REG_PROTOCOL, dk) &&
              _VocR3.KCALLS[] == 0      # (r4-B1) the key's nameof never EXECUTED (the
                                        # order budget blocks Function keys outright)
        # (A6, probe P64) an over-budget Type leaf is refused on the encodability row (the
        # reflection that once skipped the broken spec left at stage 5's E4 — no SIG row exists).
        bigU2 = reduce((a, i) -> Union{a, Val{i}}, 1:300; init = Union{})
        bb = GM.RegistryBuilder(GM.DEFAULT_REGISTRY)
        # (the over-budget type rode an overload row's sig_types until stage 5's E11 of the v0.4 build — census row 16;
        # it rides the Alterant's store type now, the record's one remaining Type leaf)
        bb.plugins[1] = GM.PlugIn(; altName = :labels, setMode = :accumulate, altConstructor = bigU2,
            setAltInstance = GM.Alterants.setLabels, getAltInstance = GM.Alterants.checkLabels)
        db = GM.validate(bb)
        @test any(x -> x.code === :REG_PROTOCOL, db)
        # (A5; the r4-B3 cure of this scan) the reflection unwrap is LOCAL: the
        # IDENTIFIER itself — under ANY qualification or bare import — no longer
        # appears in registry.jl (a decidable source scan, the [10] pattern).
        srcreg = read(joinpath(dirname(dirname(@__DIR__)), "src", "alterants",
            "registry.jl"), String)
        @test !occursin(r"\bunwrap_unionall\b", srcreg)
    end

    @testset "[16] the crx-t3t4r4 cures — the structural callable name" begin
        # (r4-A1, probe P70) a Function is a LEGITIMATE isbits type parameter of a
        # declared signature (`Store{tag}`): reflection's param render reached
        # `_slot_text(::Function)` whose nameof dispatched a pirated specialization
        # raw out of validate. The structural `_callable_text` render cures the whole
        # route: validate RETURNS (since stage 5's E4, with no reflection row to mint; the
        # pirated nameof still never runs).
        bs = GM.RegistryBuilder(GM.DEFAULT_REGISTRY)
        bs.plugins[2] = GM.PlugIn(; altName = :Visib, setMode = :mutExclusive,
            altConstructor = _VocR4.Store{_VocR4.tag}, setAltInstance = _VocR4.setS)
        ds = GM.validate(bs)
        @test ds isa Vector && _VocR4.TCALLS[] == 0
        # (r4-B1) the order budget BLOCKS a Function anywhere in a key graph — the
        # direct predicate pin (the prepass never encodes such a key).
        @test !GM._key_order_budget(_VocR4.tag) &&
              !GM._key_order_budget((1, _VocR4.tag)) &&
              GM._key_order_budget((1, :a))
        # the fold-parity pin: for an ordinary NAMED function the structural render
        # equals the old `nameof` text (the seal did not move for the shipped class —
        # the profile_snapshot pins assert the DEFAULT; this pins the mechanism).
        @test GM._callable_text(sin) == String(nameof(sin))
    end

    @testset "[17] the crx-t3t4r5 cures — the String-only encoder + the guarded sig render" begin
        # (three seats convergent, probe P80) a caller-owned non-String AbstractString
        # as a declared Dict KEY: the encoder is now String-only (matching
        # _domain_leaf's own law), so validate REFUSES typed with ZERO validate-time
        # String() conversions (pre-cure: one call, its stateful throw escaping raw).
        bs5 = GM.RegistryBuilder(GM.DEFAULT_REGISTRY)
        ss = bs5.action_specs[4]
        bs5.action_specs[4] = GM.ActionSpec(; name = ss.name, plugin = ss.plugin, accepts_string_slot = ss.accepts_string_slot,
            validate = ss.validate)
        bs5.plugins[2] = _plugin_with_default(bs5.plugins[2], GM.Declared(Dict{Any,Any}(_VocR5.BadString() => 1)))   # commit 3-ii: the Alterant's slot
        _VocR5.POST[] = true
        c0 = _VocR5.SCALLS[]
        d5 = GM.validate(bs5)
        @test d5 isa Vector && any(x -> x.code === :REG_PROTOCOL, d5) &&
              _VocR5.SCALLS[] == c0     # zero validate-time conversions
        # (seat A row 2, probe P81 — the guarded SIG_MISMATCH render — was CONSCIOUSLY RETIRED at stage 5's E4
        # with its subject, the reflection cross-check.)
    end

    @testset "[18] the crx-t3t4r6 cures — the getfield numeric leaf + the guarded declared render" begin
        # (r6-A1, probe P90) the domain predicate reads Complex/Rational PARTS via
        # getfield — a caller's `Base.real(::Complex{MyReal})` specialization never
        # dispatches (pre-cure it executed and threw from `_domain_leaf` itself).
        z = Complex(_VocR6.MyReal(1), _VocR6.MyReal(2))
        r0 = _VocR6.RCALLS[]
        @test GM._domain_leaf(z) === false &&
              GM._type_budget_check(Val{z})[1] === :bad_param &&
              _VocR6.RCALLS[] == r0     # zero dispatches through both walkers
        # (the r7-C1 witness strengthening) the ENCODER arms too, plus the Rational
        # accessor: reverting either encoder hunk or either numeric-domain hunk now
        # fails a counter — `_slot_text` on the hostile Complex refuses TYPED with zero
        # `real` dispatches, and the Rational{MyIntB} (built via unsafe_rational, which
        # skips gcd) drives `_numeric_leaf` + the encoder with zero `numerator`
        # dispatches.
        ec = try GM._slot_text(z); nothing catch err; err end
        rq = Base.unsafe_rational(_VocR6.MyIntB(1), _VocR6.MyIntB(2))
        er = try GM._slot_text(rq); nothing catch err; err end
        @test ec isa GM._UnencodableSlot && er isa GM._UnencodableSlot &&
              GM._numeric_leaf(rq) === false && _VocR6.RCALLS[] == r0
        # (r6-A2, probe P91 — the guarded declared-sig render — was CONSCIOUSLY RETIRED at stage 5's E4 with
        # its subject, the reflection cross-check.)
    end
end
