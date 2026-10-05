# record_schema_tests.jl — v0.4 T1: the registration-record schema EXTENSION witnesses (APPEND-ONLY).
#
# IS:   the unit witnesses of the T1 schema extension — the ten declared slots ride the record
#       nothing/empty-defaulted; the v0.3.2 positional constructors still admit (the additive-extension
#       law); the generic `action_to_settribute` table DERIVES from the declared per-action
#       `settribute` slots (the Alterant-named `visib_to_settribute` field and the `===` alias
#       `VISIB_TO_SETTRIBUTE` are GONE); the new closed enums (their record-shape refusals left at stage 5's
#       E4 of the v0.4 build);
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
        @test p.render === nothing
        @test isempty(p.constraints) && isempty(p.atoms) && isempty(p.sugar)
        @test p.contract_version === nothing
        @test p.requires === ()
        @test p.provenance isa GM.Provenance
        @test p.permissions === nothing
        ov = GM.ActionOverload(Type[Dict{Symbol,Bool}, Symbol], Symbol[], Symbol[], nothing,
                               Nothing, :set, false, :context_free, :apply, true)
        s = GM.ActionSpec(:zza, :identifier, Int8(1), [ov], 0, :none, nothing, nothing)
        @test s.settribute === nothing
        @test p.default === GM.NoDefault()   # stage 2's commit 3: the ALTERANT's default slot (R-V04B-51), undeclared by the positional form
    end

    @testset "keyword shapes round-trip every slot" begin
        ref = GM.DomainRef("labels/vocab.toml", "sha256:" * "0"^64)
        cap = GM.CaptureDecl(Dict{Symbol,Bool}, :per_key, :many, nothing)
        # v0.4 T5 (T5-DESIGN §6, the +3 declared movements): the attr_stem default
        # admits through the 4-positional outer method; the 5-positional round-trips;
        # the stem participates in the SEAL fold (two rows differing only in stem
        # encode differently — the SEVENTH re-mint's mechanism).
        @test cap.attr_stem === nothing
        @test GM.CaptureDecl(Dict{Symbol,Bool}, :per_key, :many, nothing, :st5).attr_stem === :st5
        @test GM._slot_text(cap) !=
              GM._slot_text(GM.CaptureDecl(Dict{Symbol,Bool}, :per_key, :many, nothing, :st5))
        # (the crx-t5 B8 strengthening) SEAL participation proper: two published
        # registries differing ONLY in a capture stem carry different seals — the fold
        # provably covers the slot (encoder inequality alone would stay green if the
        # fold dropped capture).
        _bstem(s) = begin
            b = GM.RegistryBuilder(GM.DEFAULT_REGISTRY)
            b.plugins[2] = GM.PlugIn(; altName = :Visib, setMode = :mutExclusive,
                altConstructor = GM.Alterants.Visib, setAltInstance = GM.Alterants.setVisib,
                capture = GM.CaptureDecl(GM.Alterants.Visib, :single, :one, nothing; attr_stem = s))
            GM.publish(b)
        end
        @test _bstem(:sa1).seal != _bstem(:sa2).seal
        rd  = GM.RenderDecl([:hide => GM.EffectRow(:drop, nothing),
                             :show => GM.EffectRow(:pass, nothing)], [:Line, :Block], true)
        p = GM.PlugIn(; altName = :zz, setMode = :accumulate, altConstructor = Dict{Symbol,Bool},
                        setAltInstance = identity, capture = cap, render = rd,
                        constraints = [GM.MutEx([:hide, :show])],
                        atoms = [GM.ConditionAtom(:zzq, "zzq", nothing)],
                        contract_version = v"0.4.0", requires = (),
                        sugar = [GM.SugarRow(:quoted_first, :head, :localOnly)],
                        provenance = GM.Provenance(; sources = [ref], policy_id = "pol-1",
                                                     acquisition_mode = :shipped),
                        permissions = GM.PermissionManifest(; ambient = [:file_read]))
        @test p.capture === cap && p.render === rd
        @test p.constraints[1].actions == [:hide, :show]
        @test p.atoms[1].name === :zzq
        @test p.contract_version == v"0.4.0"
        @test p.sugar[1].pattern === :quoted_first
        @test p.provenance.sources == [ref] && p.provenance.policy_id == "pol-1"
        @test p.provenance.acquisition_mode === :shipped
        @test p.permissions.ambient == [:file_read]
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

    @testset "DomainRef refuses an un-tagged or mis-shaped digest" begin
        @test_throws ErrorException GM.DomainRef("x", "0"^64)
        @test_throws ErrorException GM.DomainRef("x", "sha256:" * "0"^63)
        @test_throws ErrorException GM.DomainRef("x", "SHA256:" * "0"^64)
        @test_throws ErrorException GM.DomainRef("x", "md5:" * "0"^32)
        @test GM.DomainRef("x", "sha256:" * "a"^64).digest == "sha256:" * "a"^64
    end

    @testset "Provenance is schema-versioned and otherwise nothing-defaulted" begin
        pr = GM.Provenance()
        @test pr.sec_schema == v"1.0.0"
        @test isempty(pr.sources) && isempty(pr.signatures) && isempty(pr.declared_capabilities)
        for f in (:policy_id, :package_digest, :artifact_manifest, :signer, :source_identity,
                  :acquisition_mode, :artifact_version, :not_before, :load_act)
            @test getfield(pr, f) === nothing
        end
        sr = GM.SignatureRecord()
        @test sr.algorithm === nothing && sr.key_id === nothing && sr.signature === nothing
        pm = GM.PermissionManifest()
        @test isempty(pm.seam) && isempty(pm.ambient)
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
