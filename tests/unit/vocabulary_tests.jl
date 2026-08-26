# vocabulary_tests.jl — v0.4 T4: the WHITELIST-RELOCATION witnesses (T4-DESIGN §6).
#
# IS:   the T4 acceptance witnesses — the digest-pinned artifact loads and the DEFAULT
#       publishes through the `_vocabulary_collect!` gate; membership is unchanged and
#       ORDER-INDEPENDENT; the registration-surface FLIP (a record's declared vocabulary
#       governs, zero code edits — M-AC-12); the ZWJ write-only valve at its REACHABLE
#       seam (direct checkLabels) + the absorb-shape sibling pin; the stale-pin and
#       malformed-artifact refusal classes; the G-VOC read surface with its
#       DEFENSIVE-COPY ownership rule; the re-homed T3 checkpoint-(7) ledger-keying
#       assert; and the zero-literal law in its DECIDABLE form.
# DOES: drives the shipped vocabulary end-to-end through goMeta, publishes builders whose
#       labels record carries a DIFFERENT vocabulary declaration (inline · stale
#       VocabularyRef), calls the loader's parse seam on malformed temp bytes, and greps
#       the src tree against the ENUMERATED survivor census.
# REASONING: the relocation is a BUG-FIX with a byte-identical corpus (R-V04-20/29) — no
#       golden or corpus path can distinguish a Core literal from a declared artifact, so
#       these witnesses are the only proof the declaration is LOAD-BEARING (the flip),
#       the pin is INDEPENDENT (the stale-pin row), and the planes read ONE source.
# PURPOSE: the T4 acceptance rows (Σ = 18 asserts here + the [11] milestone-set cure
#       witnesses (6) + the [12] reconfirm/closure-cure witnesses (4) + the [13] family-
#       cure witnesses (6) = 34; +2 in snapshot_property_tests' VocabularyRef named case
#       = the T4-DESIGN §6 Σ = 20 + the crx-t3t4 cure batch + the crx-t3t4r/r2
#       hardenings + the zero-dispatch family).

using Test
import GoMeta as GM
import SHA

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

@testset "vocabulary (v0.4 T4)" begin

    _zwj = Symbol("⛓️‍💥")
    _doc(s) = Vector{UInt8}(codeunits(s))
    _drive(s; R = GM.DEFAULT_REGISTRY) = try
        GM.goMeta(_doc(s); registry = R)
    catch e
        e
    end
    # a DEFAULT-derived builder with the labels record's vocabulary slot REPLACED
    _vocab_builder(slot) = begin
        b = GM.RegistryBuilder(GM.DEFAULT_REGISTRY)
        b.plugins[1] = GM.PlugIn(; altName = :labels, setMode = :accumulate,
            altConstructor = Dict{Symbol,Bool}, setAltInstance = GM.Alterants.setLabels,
            getAltInstance = GM.Alterants.checkLabels, vocabulary = slot)
        b
    end

    @testset "[1] the DEFAULT publishes through the gate; the door is silent" begin
        # `import GoMeta` ran the load-time capture AND the publication-time re-verify
        # (`_vocabulary_collect!` on the DEFAULT's VocabularyRef) — the fail-closed law:
        # a tampered shipped artifact would have failed `using GoMeta` before this line.
        @test GM.DEFAULT_REGISTRY isa GM.AlterantRegistry
        @test isempty(GM._registry_door_check(GM.DEFAULT_REGISTRY))
    end

    @testset "[2] membership UNCHANGED end-to-end (the relocation is behavior-zero)" begin
        r = _drive("x = 1\n#~ :label1\n\ny = 2\n")
        @test r isa GM.GoMetaResult && r.status === GM.PROCESS_OK
        e = _drive("x = 1\n#~ :nope\n\ny = 2\n")
        @test e isa ErrorException && occursin("unknown label", e.msg)
    end

    @testset "[3] the LATE-order name :💫 (the C4E-4 order-independence pin)" begin
        # `:💫` sits late in DECLARATION order, which is UNSORTED — an `insorted` scan
        # over it would silently lose the names after the first sort break while the
        # corpus stayed green (the 28/38 class). Both roles must pass through the ∈-scan.
        rs = _drive("x = 1\n#~ :💫\n\ny = 2\n")
        @test rs isa GM.GoMetaResult && rs.status === GM.PROCESS_OK
        rq = _drive("x = 1\n#~1 :💫 hide{ :💫 }\n\ny = 2\n")
        @test rq isa GM.GoMetaResult && rq.status === GM.PROCESS_OK
    end

    @testset "[4] the registration-surface FLIP (M-AC-12: the declaration is load-bearing)" begin
        Rz = GM.publish(_vocab_builder(GM.InlineVocabulary([:zz1],
            Dict(:zz1 => (query = true,)))))
        rz = _drive("x = 1\n#~ :zz1\n\ny = 2\n"; R = Rz)
        @test rz isa GM.GoMetaResult && rz.status === GM.PROCESS_OK
        ez = _drive("x = 1\n#~ :label1\n\ny = 2\n"; R = Rz)   # the SHIPPED name is now foreign
        @test ez isa ErrorException && occursin("unknown label", ez.msg) &&
              occursin("zz1", ez.msg)
    end

    @testset "[5] the ZWJ write-only valve at its REACHABLE seam + the absorb-shape sibling" begin
        d = Dict{Symbol,Bool}()
        GM.Alterants.setLabels(d, :(:), _zwj)                 # setting the valve name works
        @test d[_zwj] === true
        eq = try GM.Alterants.checkLabels(d, :(:), _zwj); nothing catch err; err end
        @test eq isa ErrorException && occursin("write-only", eq.msg)
        # the SIBLING pin (C4E-3, probe-measured): the ZWJ name cannot ride a DOCUMENT
        # condition — the absorb-shape refusal PRECEDES the valve (the U+200D joiner
        # breaks the condition scan), so direct checkLabels above is the valve's ONLY
        # reachable seam at v0.
        ea = _drive("x = 1\n#~1 :⛓️‍💥 hide{ :⛓️‍💥 }\n\ny = 2\n")
        @test ea isa ErrorException && occursin("unparsable condition", ea.msg) &&
              !occursin("write-only", ea.msg)
    end

    @testset "[6] the refusal classes: the STALE pin (publication) · the MALFORMED copy (load)" begin
        # a TAMPERED artifact copy against the ORIGINAL declared pin: the captured cache
        # holds only the shipped digest, so a builder declaring the tampered bytes' digest
        # (any digest the loader never captured) meets the publication-time
        # `:SRC_DIGEST_MISMATCH` row — the R-V04-37 re-verify, NON-circular by the
        # independent declared literal.
        tam = copy(GM.Alterants._LABELS_ARTIFACT_BYTES)
        append!(tam, _doc("zzz\n"))
        stale = "sha256:" * Base.bytes2hex(SHA.sha256(tam))
        dt = GM.validate(_vocab_builder(GM.VocabularyRef(
            GM.DomainRef("alterants-std/labels_vocabulary.txt", stale))))
        @test any(x -> x.code === :SRC_DIGEST_MISMATCH && x.context === :labels &&
                       occursin("matches NO loaded artifact", x.message), dt)
        # a MALFORMED copy fails at the PARSE arm (its own digest would verify — crx
        # C11's argument law: the parse witness must not be masked by a digest mismatch,
        # so the parser seam is driven DIRECTLY on the malformed bytes).
        em = try GM.Alterants._parse_labels_vocabulary(_doc("ok\n\nbad\n"), "tmp-malformed")
            nothing
        catch err; err end
        @test em isa ErrorException && occursin("MALFORMED (blank line)", em.msg) &&
              occursin("line 2", em.msg)
    end

    @testset "[7] the G-VOC read surface over the DEFAULT" begin
        v = GM.vocabulary(GM.DEFAULT_REGISTRY, :labels)
        @test v isa GM.InlineVocabulary && length(v.names) == 38 && v.names[1] === :label1
        @test v.flags[_zwj] == (query = false,)               # the declared valve, disclosed
    end

    @testset "[8] the seam ledger keys by IDENTITY (the re-homed T3 checkpoint-(7) assert)" begin
        _mkps() = begin
            ps = GM.BLS.setUpToProcessFromBytes(_doc("x = 1\n#~ hide\n\ny = 2\n"))
            GM.BLS.parseBLS(ps, 1, -1)
            ps
        end
        P = GM.publish(GM.default_registry_builder())
        psA = _mkps(); psB = _mkps()                          # equal CONTENT, distinct objects
        GM.run_absorb_apply!(psA; registry = P)               # hide writes back ⇒ both bind
        GM.run_absorb_apply!(psB; registry = P)
        eA, eB = lock(GM._SEAM_LEDGER_LOCK) do
            (get(GM._SEAM_LEDGER, psA, nothing), get(GM._SEAM_LEDGER, psB, nothing))
        end
        @test eA isa GM._SeamEntry && eB isa GM._SeamEntry && eA !== eB
    end

    @testset "[9] the DEFENSIVE-COPY ownership rule (mutating a returned copy changes nothing)" begin
        v = GM.vocabulary(GM.DEFAULT_REGISTRY, :labels)
        push!(v.names, :evil); v.flags[:evil] = (query = true,)
        @test !GM.vocabulary_member(GM.DEFAULT_REGISTRY, :labels, :evil) &&
              length(GM.vocabulary(GM.DEFAULT_REGISTRY, :labels).names) == 38
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
                         "alterants/apply.jl" => 1,           # the condition-side-atoms comment
                         "alterants/registry.jl" => 3)        # the header note + the TWO kept empty-list messages
        # DISCLOSED LIMIT (the crx-t3t4 C3 row): this is a SOURCE-TEXT tripwire, not a
        # semantic guarantee — a computed enumeration (names built from strings or
        # codepoints, or a literal subset avoiding both sentinel patterns) passes both
        # prongs. Its real coverage: the two retired identifiers can never return, and
        # any prose/code re-using the sentinel names trips the census comparison.
        @test isempty(id_offenders) && census == survivors
    end

    @testset "[11] the crx-t3t4 milestone-set cure witnesses" begin
        # (A4/B4/C2) the written grammar now ENFORCED beyond ASCII: a comment-form line,
        # a Unicode-whitespace-padded name, and a U+FEFF past the leading-BOM bytes each
        # refuse the fail-closed load class (all three ACCEPTED pre-cure; probe-measured).
        for (frag, s) in (("comment line", "#c\nok\n"),
                          ("whitespace-padded", string(Char(0x00A0)) * "x\n"),
                          ("U+FEFF byte", "ok\n" * string(Char(0xFEFF)) * "x\n"))
            e = try GM.Alterants._parse_labels_vocabulary(_doc(s), "tmp-cure"); nothing
            catch err; err end
            @test e isa ErrorException && occursin("MALFORMED", e.msg) && occursin(frag, e.msg)
        end
        # (C1) the CALL-grain two-pass law: every supplied label is validated BEFORE any
        # presence verdict — an earlier unset member no longer masks a later write-only
        # (pre-cure this returned `false` without refusing the valve).
        ec = try GM.Alterants.checkLabels(Dict{Symbol,Bool}(), :(:), :label1, _zwj); nothing
        catch err; err end
        @test ec isa ErrorException && occursin("write-only", ec.msg)
        # (B2) the G-VOC predicates FAIL CLOSED on an unknown alterant (pre-cure: true).
        @test !GM.vocabulary_member(GM.DEFAULT_REGISTRY, :noSuchAlt, :label1) &&
              !GM.vocabulary_queryable(GM.DEFAULT_REGISTRY, :noSuchAlt, :label1)
        # (A3) `validate` is total over a Union-typed altConstructor: the DEP_MISSING row
        # RETURNS (pre-cure the diagnostic's own `nameof` render threw a raw MethodError
        # out of the never-throws chain).
        bu = GM.RegistryBuilder(GM.DEFAULT_REGISTRY)
        bu.plugins[2] = GM.PlugIn(; altName = :Visib, setMode = :mutExclusive,
            altConstructor = Union{Int,String}, setAltInstance = GM.Alterants.setVisib)
        du = GM.validate(bu)
        @test any(x -> x.code === :DEP_MISSING && occursin("Union{Int64, String}", x.message), du)
    end

    @testset "[12] the crx-t3t4r reconfirm cure — the NON-DISPATCHING ctor renderer" begin
        # (t3t4r seat A, MAJOR) the first A3 cure's `string(::Type)` fallback dispatched
        # `show` over a Union's member types — a member with a throwing user
        # `show(::IO, ::Type{T})` specialization made `validate` throw AGAIN while
        # rendering its own DEP_MISSING row (probe-confirmed). The structural renderer
        # never dispatches: validate RETURNS the row naming the hostile member — a mere
        # return here PROVES the user show never ran (it throws when invoked).
        bh = GM.RegistryBuilder(GM.DEFAULT_REGISTRY)
        bh.plugins[2] = GM.PlugIn(; altName = :Visib, setMode = :mutExclusive,
            altConstructor = Union{_VocHostile.Hostile, Int},
            setAltInstance = GM.Alterants.setVisib)
        dh = GM.validate(bh)
        @test any(x -> x.code === :DEP_MISSING && occursin("Hostile", x.message) &&
                       occursin("Union{", x.message), dh)
        @test GM._ctor_type_name(Union{}) == "Union{}"   # the bottom leaf, pinned total
        # (t3t4r2 seat B) `nameof` is itself an extensible generic — a pirated
        # `Base.nameof(::Type{Hostile2})` must never run either (the zero-dispatch law;
        # pre-cure validate threw "nameof-pirated" through the render).
        bn = GM.RegistryBuilder(GM.DEFAULT_REGISTRY)
        bn.plugins[2] = GM.PlugIn(; altName = :Visib, setMode = :mutExclusive,
            altConstructor = Union{_VocHostile.Hostile2, Int},
            setAltInstance = GM.Alterants.setVisib)
        dn = GM.validate(bn)
        @test any(x -> x.code === :DEP_MISSING && occursin("Hostile2", x.message), dn)
        # (t3t4r2 seat C) a UnionAll whose BODY is a Union (with a TypeVar member) broke
        # `nameof(::UnionAll)` — the structural unwrap renders it (pre-cure validate
        # threw a raw MethodError).
        bu2 = GM.RegistryBuilder(GM.DEFAULT_REGISTRY)
        bu2.plugins[2] = GM.PlugIn(; altName = :Visib, setMode = :mutExclusive,
            altConstructor = (Union{S, AbstractMatrix{Int}} where S <: AbstractMatrix),
            setAltInstance = GM.Alterants.setVisib)
        du2 = GM.validate(bu2)
        @test any(x -> x.code === :DEP_MISSING && occursin("Union{", x.message) &&
                       occursin("AbstractArray", x.message), du2)
    end

    @testset "[13] the t3t4r2 FAMILY cures — the zero-dispatch validate chain" begin
        _vis(alt) = GM.PlugIn(; altName = :Visib, setMode = :mutExclusive,
            altConstructor = alt, setAltInstance = GM.Alterants.setVisib)
        # (A3, probes P51/P53) a registered `Base.hasmethod(::Type{T}, ::Type{Tuple{}})`
        # specialization must never dispatch — the gate is invoke-pinned to the Base
        # fallback (pre-cure validate threw "hostile-hasmethod-invoked"). Hostile3 has a
        # REAL zero-arg ctor, so the pinned lookup passes and NO DEP row mints.
        b3 = GM.RegistryBuilder(GM.DEFAULT_REGISTRY); b3.plugins[2] = _vis(_VocHostile.Hostile3)
        @test !any(x -> x.code === :DEP_MISSING && x.context === :Visib, GM.validate(b3))
        # (A4, probe P52) `Union{}`'s `hasmethod` is a FALSE true (the Core vararg ctor)
        # while `Union{}()` always throws — pre-cure validate returned ZERO rows and the
        # registry PUBLISHED with an unmintable ctor; the eager gate now refuses.
        b4 = GM.RegistryBuilder(GM.DEFAULT_REGISTRY); b4.plugins[2] = _vis(Union{})
        @test any(x -> x.code === :DEP_MISSING && occursin("Union{}", x.message) &&
                       occursin("NO instances", x.message), GM.validate(b4))
        # (A5) a budget-refused ctor type SKIPS the method lookup (the unbounded-
        # `hasmethod` class): the 300-member Union is over the 256-node budget — the
        # registration refuses on the encodability row, with NO DEP row and NO lookup.
        bigU = reduce((a, i) -> Union{a, Val{i}}, 1:300; init = Union{})
        b5 = GM.RegistryBuilder(GM.DEFAULT_REGISTRY); b5.plugins[2] = _vis(bigU)
        d5 = GM.validate(b5)
        @test any(x -> x.code === :REG_PROTOCOL, d5) && !any(x -> x.code === :DEP_MISSING, d5)
        # (A6, probe P54) a declared VALUE outside the encodable domain renders its type
        # STRUCTURALLY — pre-cure the REG_PROTOCOL row's own interpolation ran the
        # hostile `show` and validate threw "hostileP-show".
        b6 = GM.RegistryBuilder(GM.DEFAULT_REGISTRY)
        s6 = b6.action_specs[4]
        b6.action_specs[4] = GM.ActionSpec(; name = s6.name, spelling = s6.spelling,
            plugin = s6.plugin, overloads = s6.overloads,
            accepts_string_slot = s6.accepts_string_slot,
            sugar_candidacy = s6.sugar_candidacy, validate = s6.validate,
            keyed_slot = s6.keyed_slot, default = GM.Declared(_VocHostile.HostileP()),
            settribute = s6.settribute)
        d6 = GM.validate(b6)
        @test any(x -> x.code === :REG_PROTOCOL && occursin("HostileP", x.message), d6)
        # (A7) the reflection cross-check renders a hostile-typed DECLARED signature
        # structurally (a well-formed no-literal overload with no executable method):
        # REG_SIG_MISMATCH returns naming HostileS — the render never dispatches.
        b7 = GM.RegistryBuilder(GM.DEFAULT_REGISTRY)
        s7 = b7.action_specs[1]
        hov = GM.ActionOverload(; sig_types = Type[Dict{Symbol,Bool}, _VocHostile.HostileS],
            kinds = Symbol[], kind_sources = Symbol[], vararg_kind = nothing,
            return_type = Nothing, effect = :set, queryable = false,
            applicability = :context_free, phase = :apply, grammar = false)
        b7.action_specs[1] = GM.ActionSpec(; name = s7.name, spelling = s7.spelling,
            plugin = s7.plugin, overloads = [s7.overloads..., hov],
            accepts_string_slot = s7.accepts_string_slot,
            sugar_candidacy = s7.sugar_candidacy, validate = s7.validate,
            keyed_slot = s7.keyed_slot, default = s7.default, settribute = s7.settribute)
        d7 = GM.validate(b7)
        @test any(x -> x.code === :REG_SIG_MISMATCH && occursin("HostileS", x.message), d7)
        # (A8) the value-algebra refusal renders a hostile declared return_type
        # structurally: REG_VALUE_ALGEBRA returns naming HostileS.
        b8 = GM.RegistryBuilder(GM.DEFAULT_REGISTRY)
        # a DISTINCT no-literal sig (a duplicate of an existing overload's sig trips the
        # tier-1 dispatch-target uniqueness law, and the BROKEN spec would then be
        # SKIPPED by the tier-2 algebra collector — the broken-record law)
        rov = GM.ActionOverload(; sig_types = Type[Dict{Symbol,Bool}, Float32],
            kinds = Symbol[], kind_sources = Symbol[], vararg_kind = nothing,
            return_type = _VocHostile.HostileS,
            effect = :set, queryable = false, applicability = :context_free,
            phase = :apply, grammar = false)
        b8.action_specs[1] = GM.ActionSpec(; name = s7.name, spelling = s7.spelling,
            plugin = s7.plugin, overloads = [s7.overloads..., rov],
            accepts_string_slot = s7.accepts_string_slot,
            sugar_candidacy = s7.sugar_candidacy, validate = s7.validate,
            keyed_slot = s7.keyed_slot, default = s7.default, settribute = s7.settribute)
        d8 = GM.validate(b8)
        @test any(x -> x.code === :REG_VALUE_ALGEBRA && occursin("HostileS", x.message), d8)
    end
end
