# record_schema_tests.jl — v0.4 T1: the registration-record schema EXTENSION witnesses (APPEND-ONLY).
#
# IS:   the unit witnesses of the T1 schema extension — the declared slots ride the record (seven of the ten
#       left at stage 5's E10 of the v0.4 build — census rows 24 and 29, OWNER-WORDS §317; the record keeps eight fields)
#       nothing/empty-defaulted; the v0.3.2 positional constructors left at stage 5's E11 of the v0.4 build (census row 65 — the keyword form is the one form; the former additive-extension
#       law); the generic `action_to_settribute` table and the per-action `settribute` slot it derived from LEFT at stage 5's E12
#       of the v0.4 build (census row 45 — his §317 mark; the Alterant-named `visib_to_settribute` field and the `===` alias
#       `VISIB_TO_SETTRIBUTE` were already GONE); the closed enums of the two slots that remain (their record-shape refusals left at
#       stage 5's E4 of the v0.4 build; the enums of the seven other slots went with those slots at E10);
#       the registration digest's coverage witness and the seal-participation pin left at stage 5's E13 of the v0.4 build with the
#       digest and the seal field (census row 6; the slot TEXT's distinctness, :33, stays — the encoder serves the validate walk).
# DOES: constructs records by keyword (the positional forms left at stage 5's E11 — census row 65) and inspects DEFAULT_REGISTRY.
# REASONING: the golden layer proves T1 is BEHAVIOR-NEUTRAL (byte-identical renders); only unit
#       introspection can prove the schema carries what the later cures consume.
# PURPOSE: the T1 acceptance row of the v0.4 build (the cure inventory's slot substrate).

using Test
import GoMeta as GM

@testset "record_schema (v0.4 T1)" begin

    # (the positional-shapes testset was CONSCIOUSLY RETIRED at stage 5's E11 of the v0.4 build with its subject — the
    # v0.3.2 positional constructors of PlugIn and ActionSpec, census row 65, R-V04B-61; a positional construction is
    # Julia's own MethodError now, measured on both trees by the build's probe.)

    @testset "keyword shapes: CaptureDecl's two- and three-positional forms and its slot text, the Alterant's capture slot, ActionSpec without its settribute slot (stage 5's E12)" begin
        cap = GM.CaptureDecl(:per_key, nothing)
        # v0.4 T5 (T5-DESIGN §6, the +3 declared movements): the attr_stem default
        # admits through the 2-positional outer method; the 3-positional round-trips (stage 5's E5: the row's 3 fields);
        # two rows differing only in stem encode differently (the slot text — the seal fold it joined left at stage 5's E13).
        @test cap.attr_stem === nothing
        @test GM.CaptureDecl(:per_key, nothing, :st5).attr_stem === :st5
        @test GM._slot_text(cap) !=
              GM._slot_text(GM.CaptureDecl(:per_key, nothing, :st5))
        p = GM.Alterant(; altName = :zz, setMode = :accumulate, altConstructor = Dict{Symbol,Bool},
                        setAltInstance = identity, capture = cap)
        @test p.capture === cap
        s = GM.ActionSpec(; name = :zzh, plugin = Int8(1))
        @test !hasfield(GM.ActionSpec, :settribute)   # stage 5's E12 of the v0.4 build (census row 45): the write-back key left the record
    end

    @testset "the write-back declarations LEFT the record, the registry and BLS (stage 5's E12, census row 45; R-V04B-99)" begin
        R = GM.DEFAULT_REGISTRY
        @test !hasfield(GM.AlterantRegistry, :action_to_settribute)   # the derived table left at stage 5's E12 — nothing had read it since stage 3's commit 4
        @test !hasfield(GM.AlterantRegistry, :visib_to_settribute)
        @test !isdefined(GM, :VISIB_TO_SETTRIBUTE)
        @test !hasfield(GM.ActionSpec, :default)   # stage 2's commit 3-ii: the per-action slot of T1 GAVE WAY to the Alterant's (R-V04B-51)
        @test all(k -> k ∉ keys(GM.BLS.ComponentSettribute), (:hide, :show, :discard))   # the three names left BLS's record — necessary, not sufficient: R-V04B-99 rides on this TOGETHER WITH the registry's queryable_action rule (the names out alone left `{show}` accepted — PROBES-e12-edges-AFTER_59d7558.txt)
        # stage 2's commit 3 (R-V04B-51 (1)–(2); R-V04B-55 (1)): the default is the ALTERANT's — Visib declares 'show'; the
        # others declared on his word at stage 2's review (card C2, R-V04B-92, 2026-10-02): Labels the empty set, Heading none, Id the zero compound
        @test R.plugins[R.alt_index[:Visib]].default === GM.Declared(:show)
        @test R.plugins[R.alt_index[:labels]].default isa GM.Declared && R.plugins[R.alt_index[:labels]].default.value == Symbol[]   # a Declared{Vector} compares by its value (the struct's == is identity)
        @test R.plugins[R.alt_index[:heading]].default === GM.Declared(nothing)
        @test R.plugins[R.alt_index[:id]].default == GM.Declared((cell = Int16(0), parent = Int16(0), file = Int16(0)))
    end

    # (the record shape law testset was CONSCIOUSLY RETIRED at stage 5's E4 of the v0.4 build with its
    # subject — census row 3, OWNER-WORDS §317: a mis-tagged enum slot registers unchecked, as the legacy did.)

end
