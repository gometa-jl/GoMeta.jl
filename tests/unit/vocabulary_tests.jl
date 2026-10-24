# vocabulary_tests.jl — the Labels vocabulary witnesses (the whitelist's relocation, trimmed within the 0.4
# development: the digest pin, the capture cache, the artifact grammar, the scope law, the G-VOC read surface and the write-only
# valve were removed with their subjects; the 38 names stayed in the plain file until
# the Labels Alterant moved them — with `:doc` — into its own file `alterants-std/labels.jl` as a hard-coded list,
# the creator's decision; [2b] below its witnesses).
#
# IS:   the membership witnesses over the Labels Alterant's vocabulary (the vocabulary file since 0.4.3, the hard-coded list before it — [2] the set role
#       reports an unknown name by a warning diagnostic; [2b] `:doc` applied and queried, an unknown name reported, the shipped count 46; [3] the late-order
#       name in its glued form — the ∈-scan
#       in the set role, the applied hide in the query role), the zero-literal law in its DECIDABLE form ([10]: no Core literal of the
#       names re-enters src outside alterants-std/), and the validate-chain hardening witnesses that live here by history ([11]'s A3,
#       [12]–[18]: the zero-dispatch validate chain, the DomainRef read-once law ([14] — retired with `DomainRef`), the identity/getfield hardening, the
#       structural callable name, the String-only encoder, the getfield numeric leaf).
# DOES: drives the shipped vocabulary through goMeta and the direct setter, publishes hostile builders through validate,
#       and greps the src tree against the ENUMERATED survivor census.
# PURPOSE: the vocabulary's acceptance rows that stand (the retired testsets, with their counts: [1] 2, [4] 2, [5] 3, [6] 2, [7] 2,
#       [9] 1, [11]'s A4/B4/C2 3, C1 1 and B2 1 — 17 asserts — the earlier [8] 1, and [14] 1 with `DomainRef`).

using Test
import GoMeta as GM

# the [12]/[13] fixtures: types whose `show(::IO, ::Type)` / `nameof(::Type)` /
# `hasmethod(::Type, ...)` specializations THROW — the zero-dispatch validate chain must
# never invoke any of them (the hostile-show class; the pirated-nameof /
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

# the [15] fixtures: a Function-subtype setter whose
# hash/isequal/== throw; a type whose getproperty throws; a function whose nameof throws
# (as a to-be-refused Dict KEY); a setter whose exact signature-tuple type carries a
# throwing == specialization. None of these methods may ever dispatch from validate.
@eval module _VocR3
    struct HFn <: Function end
    (f::HFn)(d::Dict{Symbol,Bool}, s::Symbol, r::Symbol...) = (d[s] = true; nothing)
    struct HG end
    hkey(x...) = true
    heq(d::Dict{Symbol,Bool}, s::Symbol) = (d[s] = true; nothing)
    const EQCALLS = Base.RefValue{Int}(0)   # proves the piracy is never SELECTED
    const KCALLS = Base.RefValue{Int}(0)    # proves the key nameof never EXECUTES
end
Base.hash(::_VocR3.HFn, ::UInt) = error("hash-pirated (must never dispatch)")
Base.isequal(::_VocR3.HFn, ::Any) = error("isequal-pirated (must never dispatch)")
Base.:(==)(::_VocR3.HFn, ::Any) = error("eq-pirated (must never dispatch)")
Base.getproperty(::Type{_VocR3.HG}, ::Symbol) = error("getproperty-pirated (must never dispatch)")
Base.nameof(::typeof(_VocR3.hkey)) = (_VocR3.KCALLS[] += 1;
    error("nameof-pirated-key (must never dispatch)"))
# BOTH operands typed — `(::Type{X}, ::Any)` was AMBIGUOUS
# with Base's `==(::Type, ::Type)` on the exact comparison (an ambiguity MethodError,
# not a selection); `(::Type{X}, ::Type)` is strictly more specific and WOULD be
# selected before the fix — the counter proves the `===` never selects it.
Base.:(==)(::Type{Tuple{typeof(_VocR3.heq), Dict{Symbol,Bool}, Symbol}}, ::Type) =
    (_VocR3.EQCALLS[] += 1; error("sig-eq-pirated (must never dispatch)"))

# the [16] fixtures: a Function as a legit isbits TYPE PARAMETER whose
# nameof throws-and-counts — the structural callable render must never invoke it
@eval module _VocR4
    tag() = nothing
    struct Store{F} end
    setS(s::Store{tag}, a::Symbol) = nothing
    const TCALLS = Base.RefValue{Int}(0)
end
Base.nameof(::typeof(_VocR4.tag)) = (_VocR4.TCALLS[] += 1;
    error("tag-nameof-pirated (must never dispatch)"))

# the [17] fixtures: a caller-owned AbstractString with a REAL string
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

# the [18] fixtures: a caller Real inside Complex whose extensible
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

@testset "vocabulary" begin

    _doc(s) = Vector{UInt8}(codeunits(s))
    _plugin_with_default(p, d) = GM.Alterant(; altName = p.altName, setMode = p.setMode, altConstructor = p.altConstructor,
        setAltInstance = p.setAltInstance, getAltInstance = p.getAltInstance, precedencesTuple = p.precedencesTuple,
        default = d, capture = p.capture)   # the declared default is the ALTERANT's — the record `p` with the slot `d`, every other field copied
    _drive(s; R = GM.DEFAULT_REGISTRY) = try
        GM.goMeta(_doc(s); registry = R)
    catch e
        e
    end

    @testset "[2] membership over the Alterant's vocabulary: a shipped name applies, an unknown name is REPORTED in the SET role (since 0.4.3; refused before)" begin
        TestSupport.fresh_vocabulary!()   # the one-row count read on a fresh copy of the shipped file (PC07), whatever an earlier witness persisted
        r = _drive("x = 1\n#~ :label1\n\ny = 2\n")
        @test r isa GM.GoMetaDelivery && r.status === GM.PROCESS_OK && isempty(r.diagnostics) && count(t -> t[2] === :label_label1, GM.readAltValuesEvals(r.altValues_evals)) == 1   # the shipped name applies: one row, the metaBlock alone (the blank line keeps `y = 2` unattached), no diagnostic
        # MEASURED: PROCESS_OK, 0 evals rows, ONE warning row LABEL_NOT_APPLIED_UNKNOWN (the metaBlock alone — the blank line keeps `y = 2` unattached)
        r2 = _drive("x = 1\n#~ :nope\n\ny = 2\n")
        @test r2 isa GM.GoMetaDelivery && r2.status === GM.PROCESS_OK && isempty(GM.readAltValuesEvals(r2.altValues_evals))
        @test length(r2.diagnostics) == 1 && r2.diagnostics[1].code === :LABEL_NOT_APPLIED_UNKNOWN && r2.diagnostics[1].severity === :warning && occursin("`:nope`", r2.diagnostics[1].message)
    end

    @testset "[2b] `:doc` — a shipped name of the Labels Alterant (the creator's decision; MEASURED; the vocabulary file since 0.4.3)" begin
        TestSupport.fresh_vocabulary!()   # the count 46 read on a fresh copy of the shipped file, whatever an earlier witness persisted
        rd = _drive("#~ :doc\nx = 1\n")                                  # L01: two `label_doc` rows — the metaBlock and the attached Code Block
        @test rd isa GM.GoMetaDelivery && rd.status === GM.PROCESS_OK && count(t -> t[2] === :label_doc, GM.readAltValuesEvals(rd.altValues_evals)) == 2
        rq = _drive("#~ :doc\n#~2 hide{ :doc }\nx = 1\n")              # L02: the label SET then QUERIED (two glued metaLines, ONE metaBlock): the hide APPLIES on both Blocks
        @test rq isa GM.GoMetaDelivery && rq.status === GM.PROCESS_OK && count(t -> t[2] === :visib && t[3] === :hide, GM.readAltValuesEvals(rq.altValues_evals)) == 2
        ez = _drive("#~ :zzz\nx = 1\n")                                  # L03: an unknown name REPORTED (since 0.4.3) — two warning rows, the metaBlock and the attached Code Block; the accepted set is not listed (the development tools print it)
        @test ez isa GM.GoMetaDelivery && ez.status === GM.PROCESS_OK && isempty(GM.readAltValuesEvals(ez.altValues_evals)) && length(ez.diagnostics) == 2 && all(d -> d.code === :LABEL_NOT_APPLIED_UNKNOWN, ez.diagnostics)
        @test :doc ∈ GM.Alterants.base_vocabulary() && length(GM.Alterants.base_vocabulary()) == 46   # the shipped file's 46 names (the user level's copy): label1 … label5, doc, the 33 glued pictograph names, the seven everyday names
    end

    @testset "[3] the LATE-order name :label💫 (the C4E-4 order-independence pin; the glued shipped form since 0.4.3)" begin
        # `:label💫` sits late in DECLARATION order, which is UNSORTED — an `insorted` scan over it would silently lose the names after
        # the first sort break while the corpus stayed green (the 28/38 class). The SET role passes through the ∈-scan; the QUERY role
        # has no membership gate (`checkLabels`: a label not set answers false), so the query witness pins the applied hide, never a refusal.
        rs = _drive("x = 1\n#~ :label💫\n\ny = 2\n")
        @test rs isa GM.GoMetaDelivery && rs.status === GM.PROCESS_OK
        rq = _drive("x = 1\n#~1 :label💫 hide{ :label💫 }\n\ny = 2\n")
        @test rq isa GM.GoMetaDelivery && rq.status === GM.PROCESS_OK
        @test any(t -> t[2] === :visib && t[3] === :hide, GM.readAltValuesEvals(rq.altValues_evals))   # the late-order label SET then QUERIED on one metaLine: the hide APPLIES (MEASURED; a query answering false would leave PROCESS_OK with no hide row)
    end

    @testset "[10] the zero-literal law (the C4E-7 DECIDABLE form)" begin
        # (a) the deleted collection identifiers survive NOWHERE in src outside
        # `alterants-std/` on a NON-comment line (the tombstone comments are prose);
        # (b) the vocabulary-name literal census over src (the union pattern
        # `label1` ∪ `:🔥`) equals EXACTLY the enumerated survivor set — every survivor
        # is prose (docstrings and comments — the two kept empty-list-message examples moved with `setLabels` / `checkLabels`
        # into `alterants-std/labels.jl`, outside this scan), so
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
                         "GoMeta.jl" => 1,                    # the profile-feed docstring example
                         # (apply.jl's one — the seam header's condition-side-atoms comment — was removed with the set-invocation seam;
                         # measured before and after the change: apply.jl 1 → 0, every other file equal)
                         "alterants/registry.jl" => 1)        # the header note alone: the TWO kept
                                                              # empty-list messages moved with `setLabels` / `checkLabels` into
                                                              # `alterants-std/labels.jl`, which this scan skips (MEASURED:
                                                              # registry.jl 1, config.jl 1, GoMeta.jl 1 by `grep -c`)
        # DISCLOSED LIMIT: this is a SOURCE-TEXT tripwire, not a
        # semantic guarantee — a computed enumeration (names built from strings or
        # codepoints, or a literal subset avoiding both sentinel patterns) passes both
        # prongs. Its real coverage: the two retired identifiers can never return, and
        # any prose/code re-using the sentinel names trips the census comparison.
        @test isempty(id_offenders) && census == survivors
    end

    @testset "[11] validate's totality over a Union-typed altConstructor" begin
        # (A4/B4/C2 — the artifact grammar's three refusal classes; C1 — the call-grain two-pass law of the valve; B2 — the
        # G-VOC predicates' fail-closed law) were CONSCIOUSLY RETIRED with their
        # subjects: the artifact grammar, the write-only valve and the G-VOC read surface.
        # (A3; the DEP_MISSING row was removed with the eager dependency closure) `validate`
        # is total over a Union-typed altConstructor: it RETURNS (the domain probe walks the type)
        bu = GM.RegistryBuilder(GM.DEFAULT_REGISTRY)
        bu.plugins[2] = GM.Alterant(; altName = :Visib, setMode = :mutExclusive,
            altConstructor = Union{Int,String}, setAltInstance = GM.Alterants.setVisib)
        @test GM.validate(bu) isa Vector{GM.Diagnostic}
    end

    @testset "[12] the NON-DISPATCHING ctor renderer" begin
        # (the three DEP_MISSING render arms were CONSCIOUSLY RETIRED with their subject, the
        # eager dependency closure; the structural renderer stays for the domain probe's unencodable-value row
        # (`_emit_unencodable!`, registry.jl; the localOnly store law it also served was removed with the Heading's separate
        # path) — its bottom leaf pinned)
        @test GM._ctor_type_name(Union{}) == "Union{}"   # the bottom leaf, pinned total
    end

    @testset "[13] the zero-dispatch validate chain" begin
        _vis(alt) = GM.Alterant(; altName = :Visib, setMode = :mutExclusive,
            altConstructor = alt, setAltInstance = GM.Alterants.setVisib)
        # (A3/A4 — the invoke-pinned `hasmethod` gate and the Union{} refusal — were CONSCIOUSLY RETIRED
        # with their subject, the eager dependency closure.)
        # (A5) a budget-refused ctor type: the 300-member Union is over the 256-node budget — the
        # registration refuses on the encodability row.
        bigU = reduce((a, i) -> Union{a, Val{i}}, 1:300; init = Union{})
        b5 = GM.RegistryBuilder(GM.DEFAULT_REGISTRY); b5.plugins[2] = _vis(bigU)
        @test any(x -> x.code === :REG_PROTOCOL, GM.validate(b5))
        # a declared VALUE outside the encodable domain renders its type
        # STRUCTURALLY — before the fix the REG_PROTOCOL row's own interpolation ran the
        # hostile `show` and validate threw "hostileP-show".
        b6 = GM.RegistryBuilder(GM.DEFAULT_REGISTRY)
        s6 = b6.action_specs[4]
        b6.action_specs[4] = GM.ActionSpec(; name = s6.name, plugin = s6.plugin, accepts_string_slot = s6.accepts_string_slot,
            validate = s6.validate)
        b6.plugins[2] = _plugin_with_default(b6.plugins[2], GM.Declared(_VocHostile.HostileP()))   # the hostile value rides the Alterant's slot
        d6 = GM.validate(b6)
        @test any(x -> x.code === :REG_PROTOCOL && occursin("HostileP", x.message), d6)
        # (A7/A8 — the hostile-typed SIG_MISMATCH and VALUE_ALGEBRA renders — were CONSCIOUSLY RETIRED
        # with their subjects, the reflection cross-check and the value-algebra refusal.)
    end

    @testset "[15] the identity/getfield hardening of the chain" begin
        _vset(setter) = begin
            b = GM.RegistryBuilder(GM.DEFAULT_REGISTRY)
            b.plugins[2] = GM.Alterant(; altName = :Visib, setMode = :mutExclusive,
                altConstructor = GM.Alterants.Visib, setAltInstance = setter)
            b
        end
        # (the reflection pooling was removed with the cross-check) a
        # setter whose hash/isequal/== all throw: validate RETURNS without dispatching them
        d60 = GM.validate(_vset(_VocR3.HFn()))
        @test d60 isa Vector
        # (A4=B2; the exact-signature `===` match was removed with the cross-check) a
        # throwing == specialization on the setter's OWN signature-tuple type never dispatches:
        # validate returns and the pirated == is never SELECTED.
        bq = GM.RegistryBuilder(GM.DEFAULT_REGISTRY)
        sq = bq.action_specs[1]
        bq.plugins[1] = GM.Alterant(; altName = :labels, setMode = :accumulate,
            altConstructor = Dict{Symbol,Bool}, setAltInstance = _VocR3.heq,
            getAltInstance = GM.Alterants.checkLabels)
        bq.action_specs[1] = GM.ActionSpec(; name = sq.name, plugin = sq.plugin, accepts_string_slot = sq.accepts_string_slot,
            validate = sq.validate)
        dq = GM.validate(bq)
        @test dq isa Vector && _VocR3.EQCALLS[] == 0     # the pirated == never dispatched from validate (the exact-signature === match it once guarded was removed)
        # the budget walkers read the type graph via getfield only: a
        # type whose getproperty throws walks clean (before the fix the walk itself threw).
        @test GM._type_budget_check(_VocR3.HG)[1] === :ok &&
              GM._key_order_budget(_VocR3.HG)
        # a to-be-refused Function KEY inside a declared Dict: the
        # ordering prepass falls back to iteration order on ANY key-encode throw (the
        # pirated nameof never escapes) and the WALK refuses the key coded.
        bk = GM.RegistryBuilder(GM.DEFAULT_REGISTRY)
        sk = bk.action_specs[4]
        bk.action_specs[4] = GM.ActionSpec(; name = sk.name, plugin = sk.plugin, accepts_string_slot = sk.accepts_string_slot,
            validate = sk.validate)
        bk.plugins[2] = _plugin_with_default(bk.plugins[2], GM.Declared(Dict{Any,Any}(_VocR3.hkey => 1)))   # the Alterant's slot
        dk = GM.validate(bk)
        @test dk isa Vector && any(x -> x.code === :REG_PROTOCOL, dk) &&
              _VocR3.KCALLS[] == 0      # the key's nameof never EXECUTED (the
                                        # order budget blocks Function keys outright)
        # an over-budget Type leaf is refused on the encodability row (the
        # reflection that once skipped the broken spec was removed — no SIG row exists).
        bigU2 = reduce((a, i) -> Union{a, Val{i}}, 1:300; init = Union{})
        bb = GM.RegistryBuilder(GM.DEFAULT_REGISTRY)
        # (the over-budget type once rode an overload row's sig_types;
        # it rides the Alterant's store type now, the record's one remaining Type leaf)
        bb.plugins[1] = GM.Alterant(; altName = :labels, setMode = :accumulate, altConstructor = bigU2,
            setAltInstance = GM.Alterants.setLabels, getAltInstance = GM.Alterants.checkLabels)
        db = GM.validate(bb)
        @test any(x -> x.code === :REG_PROTOCOL, db)
        # the reflection unwrap is LOCAL: the
        # IDENTIFIER itself — under ANY qualification or bare import — no longer
        # appears in registry.jl (a decidable source scan, the [10] pattern).
        srcreg = read(joinpath(dirname(dirname(@__DIR__)), "src", "alterants",
            "registry.jl"), String)
        @test !occursin(r"\bunwrap_unionall\b", srcreg)
    end

    @testset "[16] the structural callable name" begin
        # a Function is a LEGITIMATE isbits type parameter of a
        # declared signature (`Store{tag}`): reflection's param render reached
        # `_slot_text(::Function)` whose nameof dispatched a pirated specialization
        # raw out of validate. Since the reflection cross-check was removed no validate path reaches `_slot_text(::Function)`: the constructor slot
        # passes the domain probe as a Type leaf whose Function parameter is in-domain, and the encoder's one caller, the Dict-entry order, refuses any
        # Function in a key graph. The assert below therefore pins validate's totality only (the structural render is pinned on `sin` at :303).
        bs = GM.RegistryBuilder(GM.DEFAULT_REGISTRY)
        bs.plugins[2] = GM.Alterant(; altName = :Visib, setMode = :mutExclusive,
            altConstructor = _VocR4.Store{_VocR4.tag}, setAltInstance = _VocR4.setS)
        ds = GM.validate(bs)
        @test ds isa Vector && _VocR4.TCALLS[] == 0
        # the order budget BLOCKS a Function anywhere in a key graph — the
        # direct predicate pin (the prepass never encodes such a key).
        @test !GM._key_order_budget(_VocR4.tag) &&
              !GM._key_order_budget((1, _VocR4.tag)) &&
              GM._key_order_budget((1, :a))
        # the text-parity pin: for an ordinary NAMED function the structural render
        # equals the old `nameof` text (the mechanism; the seal pin it once protected was removed).
        @test GM._callable_text(sin) == String(nameof(sin))
    end

    @testset "[17] the String-only encoder" begin
        # a caller-owned non-String AbstractString
        # as a declared Dict KEY: the encoder is now String-only (matching
        # _domain_leaf's own law), so validate REFUSES coded with ZERO validate-time
        # String() conversions (before the fix: one call, its stateful throw escaping raw).
        bs5 = GM.RegistryBuilder(GM.DEFAULT_REGISTRY)
        ss = bs5.action_specs[4]
        bs5.action_specs[4] = GM.ActionSpec(; name = ss.name, plugin = ss.plugin, accepts_string_slot = ss.accepts_string_slot,
            validate = ss.validate)
        bs5.plugins[2] = _plugin_with_default(bs5.plugins[2], GM.Declared(Dict{Any,Any}(_VocR5.BadString() => 1)))   # the Alterant's slot
        _VocR5.POST[] = true
        c0 = _VocR5.SCALLS[]
        d5 = GM.validate(bs5)
        @test d5 isa Vector && any(x -> x.code === :REG_PROTOCOL, d5) &&
              _VocR5.SCALLS[] == c0     # zero validate-time conversions
        # (the guarded SIG_MISMATCH render was CONSCIOUSLY RETIRED
        # with its subject, the reflection cross-check.)
    end

    @testset "[18] the getfield numeric leaf" begin
        # the domain predicate reads Complex/Rational PARTS via
        # getfield — a caller's `Base.real(::Complex{MyReal})` specialization never
        # dispatches (before the fix it executed and threw from `_domain_leaf` itself).
        z = Complex(_VocR6.MyReal(1), _VocR6.MyReal(2))
        r0 = _VocR6.RCALLS[]
        @test GM._domain_leaf(z) === false &&
              GM._type_budget_check(Val{z})[1] === :bad_param &&
              _VocR6.RCALLS[] == r0     # zero dispatches through both walkers
        # the ENCODER arms too, plus the Rational
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
        # (the guarded declared-sig render was CONSCIOUSLY RETIRED with
        # its subject, the reflection cross-check.)
    end
end
