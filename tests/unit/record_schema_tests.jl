# record_schema_tests.jl — v0.4 T1: the registration-record schema EXTENSION witnesses (APPEND-ONLY).
#
# IS:   the unit witnesses of the T1 schema extension — the declared slots ride the record (seven of the ten
#       left at stage 5's E10 of the v0.4 build — census rows 24 and 29, OWNER-WORDS §317; the record keeps eight fields)
#       nothing/empty-defaulted; the v0.3.2 positional constructors still admit (the additive-extension
#       law); the generic `action_to_settribute` table DERIVES from the declared per-action
#       `settribute` slots (the Alterant-named `visib_to_settribute` field and the `===` alias
#       `VISIB_TO_SETTRIBUTE` are GONE); the closed enums of the two slots that remain (their record-shape refusals left at
#       stage 5's E4 of the v0.4 build; the enums of the seven other slots went with those slots at E10);
#       the registration digest's fold COVERS the new slots (flipped at T2 when the publication seal
#       was minted — at T1 this file witnessed the fold's blindness by name, as the T2 flip target).
# DOES: constructs records positionally and by keyword, inspects DEFAULT_REGISTRY, and pins the
#       digest-COVERAGE witness (the former blindness witness,
#       flipped at T2).
# REASONING: the golden layer proves T1 is BEHAVIOR-NEUTRAL (byte-identical renders); only unit
#       introspection can prove the schema carries what the later cures consume.
# PURPOSE: the T1 acceptance row of the v0.4 build (the cure inventory's slot substrate).

using Test
import GoMeta as GM

@testset "record_schema (v0.4 T1)" begin

    @testset "positional v0.3.2 shapes still construct, slots nothing/empty-defaulted" begin
        p = GM.PlugIn(:zz, :accumulate, Dict{Symbol,Bool}, identity, nothing, nothing)
        @test p.capture === nothing
        ov = GM.ActionOverload(Type[Dict{Symbol,Bool}, Symbol], Symbol[], Symbol[], nothing,
                               Nothing, :set, false, :context_free, :apply, true)
        s = GM.ActionSpec(:zza, :identifier, Int8(1), [ov], 0, :none, nothing, nothing)
        @test s.settribute === nothing
        @test p.default === GM.NoDefault()   # stage 2's commit 3: the ALTERANT's default slot (R-V04B-51), undeclared by the positional form
    end

    @testset "keyword shapes round-trip every slot" begin
        cap = GM.CaptureDecl(:per_key, nothing)
        # v0.4 T5 (T5-DESIGN §6, the +3 declared movements): the attr_stem default
        # admits through the 2-positional outer method; the 3-positional round-trips (stage 5's E5: the row's 3 fields);
        # the stem participates in the SEAL fold (two rows differing only in stem
        # encode differently — the SEVENTH re-mint's mechanism).
        @test cap.attr_stem === nothing
        @test GM.CaptureDecl(:per_key, nothing, :st5).attr_stem === :st5
        @test GM._slot_text(cap) !=
              GM._slot_text(GM.CaptureDecl(:per_key, nothing, :st5))
        # (the crx-t5 B8 strengthening) SEAL participation proper: two published
        # registries differing ONLY in a capture stem carry different seals — the fold
        # provably covers the slot (encoder inequality alone would stay green if the
        # fold dropped capture).
        _bstem(s) = begin
            b = GM.RegistryBuilder(GM.DEFAULT_REGISTRY)
            b.plugins[2] = GM.PlugIn(; altName = :Visib, setMode = :mutExclusive,
                altConstructor = GM.Alterants.Visib, setAltInstance = GM.Alterants.setVisib,
                capture = GM.CaptureDecl(:single, nothing; attr_stem = s))
            GM.publish(b)
        end
        @test _bstem(:sa1).seal != _bstem(:sa2).seal
        p = GM.PlugIn(; altName = :zz, setMode = :accumulate, altConstructor = Dict{Symbol,Bool},
                        setAltInstance = identity, capture = cap)
        @test p.capture === cap
        ov = GM.ActionOverload(Type[Dict{Symbol,Bool}, Symbol], Symbol[], Symbol[], nothing,
                               Bool, :set, false, :context_free, :apply, true)
        s = GM.ActionSpec(; name = :zzh, spelling = :identifier, plugin = Int8(1), overloads = [ov],
                            settribute = :zzh)
        @test s.settribute === :zzh
    end

    @testset "the generic action_to_settribute table derives from declarations" begin
        R = GM.DEFAULT_REGISTRY
        @test R.action_to_settribute == Dict(:hide => :hide, :show => :show, :discard => :discard)
        # every table entry is a DECLARED datum on its spec; every non-declaring spec is absent
        for s in R.action_specs
            if s.settribute === nothing
                @test !haskey(R.action_to_settribute, s.name)
            else
                @test R.action_to_settribute[s.name] === s.settribute
            end
        end
        @test !hasfield(GM.AlterantRegistry, :visib_to_settribute)
        @test !isdefined(GM, :VISIB_TO_SETTRIBUTE)
        @test !hasfield(GM.ActionSpec, :default)   # stage 2's commit 3-ii: the per-action slot of T1 GAVE WAY to the Alterant's (R-V04B-51)
        # stage 2's commit 3 (R-V04B-51 (1)–(2); R-V04B-55 (1)): the default is the ALTERANT's — Visib declares 'show'; the
        # others declared on his word at stage 2's review (card C2, R-V04B-92, 2026-10-02): Labels the empty set, Heading none, Id the zero compound
        @test R.plugins[R.alt_index[:Visib]].default === GM.Declared(:show)
        @test R.plugins[R.alt_index[:labels]].default isa GM.Declared && R.plugins[R.alt_index[:labels]].default.value == Symbol[]   # a Declared{Vector} compares by its value (the struct's == is identity)
        @test R.plugins[R.alt_index[:heading]].default === GM.Declared(nothing)
        @test R.plugins[R.alt_index[:id]].default == GM.Declared((cell = Int16(0), parent = Int16(0), file = Int16(0)))
    end

    # (the record shape law testset was CONSCIOUSLY RETIRED at stage 5's E4 of the v0.4 build with its
    # subject — census row 3, OWNER-WORDS §317: a mis-tagged enum slot registers unchecked, as the legacy did.)

    @testset "the registration digest COVERS the new slots (flipped at T2 — the seal covers the record)" begin
        # WITNESS, flipped at T2 as registered at T1: at T1 the fold read the v0.3.2 fields only
        # (this assertion was `==`); T2 extended the fold over every declared slot so the HC-9 seal
        # covers the record — a declared default or write-back key now MOVES the digest. The
        # profile's bootstrap registration pin re-minted with it (profile_snapshot_tests.jl,
        # disclosed old → new); the grammar pin did not move.
        specs = GM.DEFAULT_REGISTRY.action_specs
        alt = copy(specs)
        i = findfirst(s -> s.name === :hide, alt)
        h = alt[i]
        alt[i] = GM.ActionSpec(; name = h.name, spelling = h.spelling, plugin = h.plugin,
                                 overloads = h.overloads, accepts_string_slot = h.accepts_string_slot,
                                 sugar_candidacy = h.sugar_candidacy, validate = h.validate,
                                 keyed_slot = h.keyed_slot,
                                 settribute = :elsewhere)
        @test GM._registration_digest(alt) != GM._registration_digest(specs)   # flipped at T2 (was ==)
    end
end
