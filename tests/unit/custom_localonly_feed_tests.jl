# custom_localonly_feed_tests.jl — the profile feed's refusal at the read is not the shipped Heading's alone: a CUSTOM registry's `localOnly` Alterant meets it too (MEASURED on one custom registry; the condition keys on the set mode — every registry's by shape)
#
# IS:   the witness that the ONE REFUSAL of a `localOnly` statement in the profile feed (src/absorb/absorb_meta.jl — the condition keyed on
#       the SET MODE `localOnly` with a user context present; the creator's decision of
#       2026-10-14; the message HIS sentence) is the
#       condition's, not the shipped Heading's alone: a CUSTOM registry's Alterant declared as the Heading is (set mode `localOnly`) meets
#       it when fed, and a custom Alterant of another set mode does not.
# DOES: builds through the public door the DEFAULT_REGISTRY extended with `xhead` (declared as the Heading is — registry.jl's declaration
#       and its ActionSpec with the declared String slot and validator; the action `xhead`) and `xvis` (set mode `mutExclusive`, the Visib's
#       constructor, default and capture shape, a setter of this file's own mapping its two action names onto the Visib's elements — the
#       shipped setter indexes the Visib by the action's name; the actions `xhide`, `xshow`); then: [W1] `xhead("U", 3)` FED meets the
#       refusal with the creator's sentence (MEASURED); [W2] the shipped `head("U", 3)` FED meets the same (the pair); [W3]
#       `#~ xhead("U", 3)` STATED in a document is PROCESS_OK with one `xhead_3` row; [W4] `xshow` FED over a `#~ hide` document is
#       PROCESS_OK, no refusal, rows of `visib` and `xvis`; [W5] `#~ xhide` STATED is PROCESS_OK with `xvis` rows (every value
#       MEASURED first from the FULL delivery views).
# REASONING: the condition's shape covers every registry, but until this file no pin exercised a custom registry's `localOnly` Alterant
#       — and a cross-module read gets a
#       witness on EVERY path that reaches it. Tests never change the Engine: the custom Alterants live here.
# PURPOSE: the refusal's reach, measured and pinned — never inferred from the condition's text.
using Test
import GoMeta as GM

@testset "custom_localonly_feed" begin

    xset(v::GM.Alterants.Visib, a::Symbol) = GM.Alterants.setVisib(v, a === :xshow ? :show : :hide)
    xset(v::GM.Alterants.Visib, a::SubString{String}) = xset(v, Symbol(a))
    b = GM.RegistryBuilder(GM.DEFAULT_REGISTRY)
    pH = GM.next_plugin_index(b)
    GM.register!(b, GM.Alterant(; altName = :xhead, setMode = :localOnly, altConstructor = GM.Alterants.Heading,
                                  setAltInstance = GM.Alterants.setHead, default = GM.Declared(nothing),
                                  capture = GM.CaptureDecl(:per_entry; attr_stem = :xhead)),
                 GM.ActionSpec(; name = :xhead, plugin = Int8(pH), accepts_string_slot = 1, validate = GM.Alterants._heading_validate_text))
    pV = GM.next_plugin_index(b)
    GM.register!(b, GM.Alterant(; altName = :xvis, setMode = :mutExclusive, altConstructor = GM.Alterants.Visib, setAltInstance = xset,
                                  default = GM.Declared(:show), capture = GM.CaptureDecl(:single; attr_stem = :xvis)),
                 GM.ActionSpec(; name = :xhide, plugin = Int8(pV)), GM.ActionSpec(; name = :xshow, plugin = Int8(pV)))
    REG = GM.publish(b)
    @test GM.num_alt_actions(REG) == 12
    @test [p.setMode for p in REG.plugins if p.altName in (:xhead, :xvis)] == [:localOnly, :mutExclusive]
    bytes(s) = Vector{UInt8}(codeunits(s))
    attrs(r) = sort(unique(String(a) for (_, a, _, _) in GM.readAltValuesEvals(r.altValues_evals)))
    nrows(r) = length(collect(GM.readAltValuesEvals(r.altValues_evals)))
    REFUSAL = "a heading (Heading Alterant) in the profile feed has no Component of the file levels to be local to"

    @testset "[W1] a custom localOnly Alterant FED meets the refusal at the read (MEASURED: run B)" begin
        e = try GM.goMeta(bytes("x = 1\n"); registry = REG, config = GM.GoMetaConfig(user_mh_profile = "xhead(\"U\", 3)")); nothing catch err; err end
        @test e isa ErrorException && occursin(REFUSAL, e.msg)
    end
    @testset "[W2] the shipped Heading FED meets the same refusal (MEASURED: run A — the pair)" begin
        e = try GM.goMeta(bytes("x = 1\n"); registry = REG, config = GM.GoMetaConfig(user_mh_profile = "head(\"U\", 3)")); nothing catch err; err end
        @test e isa ErrorException && occursin(REFUSAL, e.msg)
    end
    @testset "[W3] the custom localOnly Alterant STATED in a document records its row (MEASURED: run C)" begin
        r = GM.goMeta(bytes("#~ xhead(\"U\", 3)\nx = 1\n"); registry = REG)
        @test r.status === GM.PROCESS_OK && nrows(r) == 1 && attrs(r) == ["xhead_3"]
    end
    @testset "[W4] a custom NON-localOnly Alterant FED is not refused (MEASURED: run D)" begin
        r = GM.goMeta(bytes("#~ hide\nx = 1\n"); registry = REG, config = GM.GoMetaConfig(user_mh_profile = "xshow"))
        @test r.status === GM.PROCESS_OK && nrows(r) == 4 && attrs(r) == ["visib", "xvis"]
    end
    @testset "[W5] the custom non-localOnly Alterant STATED in a document records its rows (MEASURED: run E)" begin
        r = GM.goMeta(bytes("#~ xhide\nx = 1\n"); registry = REG)
        @test r.status === GM.PROCESS_OK && nrows(r) == 2 && attrs(r) == ["xvis"]
    end
end
