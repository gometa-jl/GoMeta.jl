# record_schema_tests.jl — the registration-record schema EXTENSION witnesses (APPEND-ONLY).
#
# IS:   the unit witnesses of the schema extension — the declared slots ride the record (seven of the ten
#       were removed within the 0.4 development; the record keeps eight fields — nine since 0.4.2, the read-time hook `onRead` the ninth)
#       nothing/empty-defaulted; the v0.3.2 positional constructors were removed (the keyword form is the one form; the former additive-extension
#       law); the generic `action_to_settribute` table and the per-action `settribute` slot it derived from were REMOVED
#       (the Alterant-named `visib_to_settribute` field and the `===` alias
#       `VISIB_TO_SETTRIBUTE` were already GONE); the closed enums of the two slots that remain (their record-shape refusals
#       removed; the enums of the seven other slots went with those slots);
#       the registration digest's coverage witness and the seal-participation pin were removed with the
#       digest and the seal field (the slot TEXT's distinctness stays — the encoder serves the validate walk).
# DOES: constructs records by keyword (the positional forms were removed) and inspects DEFAULT_REGISTRY.
# REASONING: the golden layer proves the extension is BEHAVIOR-NEUTRAL (byte-identical renders); only unit
#       introspection can prove the schema carries what the later cures consume.
# PURPOSE: the record schema's acceptance row (the slot substrate).

using Test
import GoMeta as GM

@testset "record_schema" begin

    # (the positional-shapes testset was CONSCIOUSLY RETIRED with its subject — the
    # v0.3.2 positional constructors of PlugIn and ActionSpec; a positional construction is
    # Julia's own MethodError now, measured before and after the change.)

    @testset "keyword shapes: CaptureDecl's one- and two-positional forms and its slot text, the Alterant's capture slot, ActionSpec without its settribute slot" begin
        cap = GM.CaptureDecl(:per_key)
        # the attr_stem default
        # admits through the 1-positional outer method; the 2-positional round-trips (the row's 2 fields —
        # the `mode_gate` field was removed with the Heading's separate path);
        # two rows differing only in stem encode differently (the slot text — the seal fold it once joined was removed).
        @test cap.attr_stem === nothing
        @test GM.CaptureDecl(:per_key, :st5).attr_stem === :st5
        @test !hasfield(GM.CaptureDecl, :mode_gate)   # the field was removed with the Heading's separate path
        @test GM._slot_text(cap) !=
              GM._slot_text(GM.CaptureDecl(:per_key, :st5))
        p = GM.Alterant(; altName = :zz, setMode = :accumulate, altConstructor = Dict{Symbol,Bool},
                        setAltInstance = identity, capture = cap)
        @test p.capture === cap
        s = GM.ActionSpec(; name = :zzh, plugin = Int8(1))
        @test !hasfield(GM.ActionSpec, :settribute)   # the write-back key was removed from the record
    end

    @testset "the write-back declarations LEFT the record, the registry and BLS" begin
        R = GM.DEFAULT_REGISTRY
        @test !hasfield(GM.AlterantRegistry, :action_to_settribute)   # the derived table was removed — nothing had read it since the answer function
        @test !hasfield(GM.AlterantRegistry, :visib_to_settribute)
        @test !isdefined(GM, :VISIB_TO_SETTRIBUTE)
        @test !hasfield(GM.ActionSpec, :default)   # the per-action slot GAVE WAY to the Alterant's
        @test all(k -> k ∉ keys(GM.BLS.ComponentSettribute), (:hide, :show, :discard))   # the three names were removed from BLS's record — necessary, not sufficient: the refusal rides on this TOGETHER WITH the registry's queryable_action rule (the names out alone left `{show}` accepted)
        # the default is the ALTERANT's — Visib declares 'show'; the
        # others declared on the creator's word of 2026-10-02: Labels the empty set, Heading none, Id the zero compound
        @test R.plugins[R.alt_index[:Visib]].default === GM.Declared(:show)
        @test R.plugins[R.alt_index[:labels]].default isa GM.Declared && R.plugins[R.alt_index[:labels]].default.value == Symbol[]   # a Declared{Vector} compares by its value (the struct's == is identity)
        @test R.plugins[R.alt_index[:heading]].default === GM.Declared(nothing)
        @test R.plugins[R.alt_index[:id]].default == GM.Declared((cell = Int16(0), parent = Int16(0), file = Int16(0)))
    end

    # (the record shape law testset was CONSCIOUSLY RETIRED with its
    # subject: a mis-tagged enum slot registers unchecked, as the original engine did.)

end
