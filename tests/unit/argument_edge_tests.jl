# argument_edge_tests.jl — THE TWO ENGINE FACILITIES OF 0.4.3, FOR EVERY ALTERANT (the creator's law: a change to the Engine is a facility all
# Alterants can use): THE ARGUMENT-EDGE CLASS — the public predicate `is_argument_space` (src/arguments.jl) and the trim of every bare argument's
# two edges at the reader's coercion (src/absorb/absorb_meta.jl `_coerce_arg_token`); THE ONE DOOR AT THE READ — a read-time hook's return read
# in one grammar (`nothing` | a `Vector{Diagnostic}` alone | a state | `(state, Vector{Diagnostic})`), the rows delivered by the one delivery
# function (src/state.jl `_deliver_diagnostics!`) with the read-time place (the stating statement's handle, the meta-hierarchy index the hook
# received, the statement's text).
#
# IS:   ten witnesses [A1]–[A10], EVERY expected value READ from the measured printouts of the built tree (the DT set D01 … D11, T01 … T17).
#       THE PREDICATE over the class and the carve-out ([A1]); THE TRIM for the Id Alterant's `cell` / `ids` / `parent` ([A2]), for the Labels
#       Alterant's two forms and the profile ([A3]), the Heading's quoted text UNTOUCHED ([A4]), an inner character untouched — the Alterant
#       decides ([A5]), a declared name's own edges and the carve-out's joiner name ([A6]); THE DOOR AT THE READ by a custom registration —
#       rows alone at the file level, in a metaBlock, in the profile, inline ([A7]); a tuple, a state, nothing ([A8]); two rows with mixed
#       contexts, a vector typed `Any`, an `:error` row ([A9]); rows then a tuple ([A10]).
# REASONING: the two cuts are the Engine's and serve every Alterant — the shipped ones are probed, a custom one proves the door general.
# PURPOSE: the facilities, measured — never inferred from the docstrings or from prose.

using Test
import GoMeta as GM

_ae_bytes(s::String) = Vector{UInt8}(codeunits(s))
_ae_run(s::String; profile = nothing, registry = nothing) =
    (TestSupport.fresh_vocabulary!(); GM.goMeta(_ae_bytes(s); (registry === nothing ? (;) : (; registry = registry))..., config = GM.GoMetaConfig(; user_mh_profile = profile)))
_ae_msg(s::String) = try; _ae_run(s); nothing; catch e; e; end
_ae_rows(r) = [(a, v) for (_, a, v, _) in GM.readAltValuesEvals(r.altValues_evals)]
_ae_keys(r) = [GM.key_bytes(GM.occurrence_key(r.blsComponentTree, b)) for b in GM.BLS.children(r.blsComponentTree)]
const _AE_KU = GM.key_bytes(GM.user_context_key(:default, 1))
C(cps...) = string(Char.(cps)...)
const Z = C(0x200B); const BOM = C(0xFEFF); const WJ = C(0x2060); const LS = C(0x2028); const PS = C(0x2029); const MVS = C(0x180E); const NB = C(0xA0)

@testset "the argument-edge class and the door at the read (0.4.3, for every Alterant)" begin

    @testset "[A1] the predicate `is_argument_space`: true for the ordinary white space and the six invisible separators; false for the carve-out (the joiner, the non-joiner, the variation selectors), for letters, digits, a pictograph and an invalid character; package-public, not exported; the trim as `strip`" begin
        for c in (' ', '\t', '\n', Char(0x85), Char(0xA0), Char(0x2028), Char(0x2029), Char(0x180E), Char(0x200B), Char(0x2060), Char(0xFEFF)); @test GM.is_argument_space(c); end
        for c in (Char(0x200D), Char(0x200C), Char(0xFE0E), Char(0xFE0F), 'a', '1', Char(0x1F340)); @test !GM.is_argument_space(c); end
        @test !GM.is_argument_space(reinterpret(Char, 0xff000000))
        @test strip(GM.is_argument_space, Z * " label1 " * BOM) == "label1"
        @test Base.ispublic(GM, :is_argument_space) && !Base.isexported(GM, :is_argument_space)
    end

    @testset "[A2] the trim for the Id Alterant (T01 … T04): `cell(<ZWSP>7)`, `cell(<BOM>7<BOM>)`, `ids(<WJ>1, 2<LS>, <PS>3<MVS>)`, `parent(<NBSP>5<NBSP>)` — the clean values parsed, the rows as without the characters" begin
        r = _ae_run("#~ cell(" * Z * "7)\nx = 1\n"); @test r.status === GM.PROCESS_OK && _ae_rows(r) == [(:id_cell, Int16(7)), (:id_cell, Int16(7))] && isempty(r.diagnostics)
        r = _ae_run("#~ cell(" * BOM * "7" * BOM * ")\nx = 1\n"); @test r.status === GM.PROCESS_OK && _ae_rows(r) == [(:id_cell, Int16(7)), (:id_cell, Int16(7))]
        r = _ae_run("#~ ids(" * WJ * "1, 2" * LS * ", " * PS * "3" * MVS * ")\nx = 1\n"); @test r.status === GM.PROCESS_OK && _ae_rows(r) == [(:id_cell, Int16(1)), (:id_file, Int16(3)), (:id_parent, Int16(2)), (:id_cell, Int16(1)), (:id_file, Int16(3)), (:id_parent, Int16(2))]   # the per-field rows in the capture's order (MEASURED: cell, file, parent per Block)
        r = _ae_run("#~ parent(" * NB * "5" * NB * ")\nx = 1\n"); @test r.status === GM.PROCESS_OK && _ae_rows(r) == [(:id_parent, Int16(5)), (:id_parent, Int16(5))]
    end

    @testset "[A3] the trim for the Labels Alterant (T05 … T07, T14): the list form's pieces, the one-word form's leading and trailing character, the profile's label — the clean names apply, no diagnostic" begin
        r = _ae_run("#~ :(" * Z * "label1, label2" * BOM * ")\nx = 1\n"); @test r.status === GM.PROCESS_OK && sort(_ae_rows(r)) == sort([(:label_label1, true), (:label_label2, true), (:label_label1, true), (:label_label2, true)]) && isempty(r.diagnostics)
        r = _ae_run("#~ :" * Z * "label1\nx = 1\n"); @test r.status === GM.PROCESS_OK && _ae_rows(r) == [(:label_label1, true), (:label_label1, true)] && isempty(r.diagnostics)
        r = _ae_run("#~ :label1" * WJ * "\nx = 1\n"); @test r.status === GM.PROCESS_OK && _ae_rows(r) == [(:label_label1, true), (:label_label1, true)] && isempty(r.diagnostics)
        # T14: the profile `:<ZWSP>label1<ZWSP>` over `#~ hide⏎x = 1`: label1 decided by the user level, the hide by the metaBlock; 4 rows, no diagnostic
        r = _ae_run("#~ hide\nx = 1\n"; profile = ":" * Z * "label1" * Z); @test r.status === GM.PROCESS_OK && isempty(r.diagnostics); k = _ae_keys(r)
        @test [(x.attr, x.value, x.decided_by) for x in collect(r.altValues_evals.records)] == [(:label_label1, true, [_AE_KU]), (:visib, :hide, [k[1]]), (:label_label1, true, [_AE_KU]), (:visib, :hide, [k[1]])]
    end

    @testset "[A4] a quoted text is content, not trimmed (T09, T10): `head(\"<ZWSP>A title<ZWSP>\")` and the sugar `\"<BOM>B title\"` keep their characters" begin
        r = _ae_run("#~ head(\"" * Z * "A title" * Z * "\")\nx = 1\n"); @test r.status === GM.PROCESS_OK && _ae_rows(r) == [(:head_1, Z * "A title" * Z)]
        r = _ae_run("#~ \"" * BOM * "B title\"\nx = 1\n"); @test r.status === GM.PROCESS_OK && _ae_rows(r) == [(:head_1, BOM * "B title")]
    end

    @testset "[A5] an inner character is untouched — the Alterant decides (T15, T08, T16, T17): `cell(1<ZWSP>7)` the Id Alterant's own parse error; `:label<ZWSP>1` the Labels Alterant's warning; a member that is empty after the trim the stray-comma refusal; `hide` unaffected" begin
        e = _ae_msg("#~ cell(1" * Z * "7)\nx = 1\n"); @test e isa ArgumentError && occursin("invalid base 10 digit", sprint(showerror, e))
        r = _ae_run("#~ :label" * Z * "1\nx = 1\n"); @test r.status === GM.PROCESS_OK && isempty(_ae_rows(r)) && length(r.diagnostics) == 2 && all(d -> d.code === :LABEL_NOT_APPLIED_UNKNOWN && d.message == raw"""GoMeta apply: the plain `:label\u200b1` had no effect here — not in the Labels Alterant's vocabulary; declare it with `:++label\u200b1` at `#~0` or in the user level's profile, or correct the spelling; see docs/public-api.md §3.4""", r.diagnostics)
        e = _ae_msg("#~ :(label1, " * Z * ")\nx = 1\n"); @test e isa ErrorException && e.msg == raw"""GoMeta apply: the label statement `:(label1, )` names an empty label (a stray comma) — the forms are `:x` and `:(x, y)`; see docs/public-api.md §3.4"""
        r = _ae_run("#~ hide\nx = 1\n"); @test r.status === GM.PROCESS_OK && _ae_rows(r) == [(:visib, :hide), (:visib, :hide)]
    end

    @testset "[A6] a declared name (T11, T12, T13): `:++<ZWSP>zzz<BOM>` — the name's own edges trimmed after the glued sign, zzz declared and applied; `:++zz<ZWSP>z` refused with the escape shown; the shipped joiner name (the chain with the collision, U+200D inside — the carve-out) applies" begin
        r = _ae_run("#~0 :++" * Z * "zzz" * BOM * "\n#~ :zzz\nx = 1\n"); @test r.status === GM.PROCESS_OK && _ae_rows(r) == [(:label_zzz, true), (:label_zzz, true)] && length(r.diagnostics) == 1 && r.diagnostics[1].code === :LABELS_VOCABULARY_FILE_CHANGED && r.diagnostics[1].context.label === :zzz
        e = _ae_msg("#~0 :++zz" * Z * "z\nx = 1\n"); @test e isa ErrorException && e.msg == raw"""GoMeta absorb: a label name in a vocabulary statement may not carry white space or an invisible character inside — got "zz\u200bz" in `:++zz\u200bz`; see docs/public-api.md §3.4"""
        joiner = "label" * C(0x26D3, 0xFE0F, 0x200D, 0x1F4A5)
        r = _ae_run("#~ :" * joiner * "\nx = 1\n"); @test r.status === GM.PROCESS_OK && _ae_rows(r) == [(Symbol("label_" * joiner), true), (Symbol("label_" * joiner), true)] && isempty(r.diagnostics)
    end

    ## ── the door at the read, by a custom registration (the pattern of labels_vocabulary_tests.jl [V-W14]) ─────────────────────────────
    SEEN = Any[]; RET = Ref{Any}(nothing)
    hook(run, mhIdx, actionName, args, hasCondition) = (push!(SEEN, (run, mhIdx, actionName, args, hasCondition)); RET[] isa Function ? RET[](run, mhIdx, args) : RET[])
    xset(v::GM.Alterants.Visib, a::Symbol, args...) = GM.Alterants.setVisib(v, a === :xshow ? :show : :hide)
    xset(v::GM.Alterants.Visib, a::SubString{String}, args...) = xset(v, Symbol(a), args...)
    b = GM.RegistryBuilder(GM.DEFAULT_REGISTRY); pV = GM.next_plugin_index(b)
    GM.register!(b, GM.Alterant(; altName = :xvis, setMode = :mutExclusive, altConstructor = GM.Alterants.Visib, setAltInstance = xset,
                                  default = GM.Declared(:show), capture = GM.CaptureDecl(:single; attr_stem = :xvis), onRead = hook),
                 GM.ActionSpec(; name = :xhide, plugin = Int8(pV)), GM.ActionSpec(; name = :xshow, plugin = Int8(pV)))
    REG = GM.publish(b)
    go(s, ret; profile = nothing) = (empty!(SEEN); RET[] = ret; _ae_run(s; profile = profile, registry = REG))
    rowsWarn = [GM.Diagnostic(:X_READ_NOTE, :warning, "a note at the read", (k = 1,))]
    rowsMixed = [GM.Diagnostic(:X_READ_A, :info, "first at the read"), GM.Diagnostic(:X_READ_B, :warning, "second at the read", "ctx")]

    @testset "[A7] rows ALONE: delivered with the read-time place and the statement enqueued as stated — at the file level (D01: level 1), in a metaBlock (D02: level 2), in the profile (D03: level 10, the user context, no row), inline (D04: level 11, the Segment)" begin
        r = go("#~0 xhide(a)\nx = 1\n", rowsWarn); k = _ae_keys(r)
        @test r.status === GM.PROCESS_OK && _ae_rows(r) == [(:xvis, :hide), (:xvis, :hide)] && SEEN == [(nothing, 1, :xhide, (:a,), false)]
        @test length(r.diagnostics) == 1 && r.diagnostics[1].code === :X_READ_NOTE && r.diagnostics[1].severity === :warning && r.diagnostics[1].message == "a note at the read" && r.diagnostics[1].context == (k = 1, stated_by = k[1], level = 1, statement = "xhide(a)")
        r = go("#~ xhide(a)\nx = 1\n", rowsWarn); k = _ae_keys(r)
        @test _ae_rows(r) == [(:xvis, :hide), (:xvis, :hide)] && length(r.diagnostics) == 1 && r.diagnostics[1].context == (k = 1, stated_by = k[1], level = 2, statement = "xhide(a)")
        r = go("x = 1\n", rowsWarn; profile = "xhide(a)")
        @test r.status === GM.PROCESS_OK && isempty(_ae_rows(r)) && length(r.diagnostics) == 1 && r.diagnostics[1].context == (k = 1, stated_by = _AE_KU, level = 10, statement = "xhide(a)") && SEEN == [(nothing, 10, :xhide, (:a,), false)]
        r = go("x = 1 #~ xhide(a)\ny = 2\n", rowsWarn)
        l = GM.BLS.children(r.blsComponentTree, GM.BLS.children(r.blsComponentTree)[1])[1]; seg = GM.BLS.children(r.blsComponentTree, l)[2]; kS = GM.key_bytes(GM.occurrence_key(r.blsComponentTree, seg))
        @test _ae_rows(r) == [(:xvis, :hide)] && length(r.diagnostics) == 1 && r.diagnostics[1].context == (k = 1, stated_by = kS, level = 11, statement = "xhide(a)") && SEEN == [(nothing, 11, :xhide, (:a,), false)]
    end

    @testset "[A8] a tuple `(state, rows)` — consumed AND delivered, the state handed to the hook's next call (D05); a state alone — consumed, nothing delivered (D06); `nothing` — enqueued, nothing delivered (D07)" begin
        r = go("#~0 xhide(consume)\n#~ xhide(other)\nx = 1\n", (:hide, rowsWarn)); k = _ae_keys(r)
        @test r.status === GM.PROCESS_OK && isempty(_ae_rows(r)) && length(r.diagnostics) == 2
        @test [d.context for d in r.diagnostics] == [(k = 1, stated_by = k[1], level = 1, statement = "xhide(consume)"), (k = 1, stated_by = k[1], level = 1, statement = "xhide(other)")]
        @test SEEN == [(nothing, 1, :xhide, (:consume,), false), (:hide, 1, :xhide, (:other,), false)]
        r = go("#~0 xhide(consume)\n#~ xhide(other)\nx = 1\n", :hide); @test r.status === GM.PROCESS_OK && isempty(_ae_rows(r)) && isempty(r.diagnostics)
        r = go("#~0 xhide(a)\nx = 1\n", nothing); @test r.status === GM.PROCESS_OK && _ae_rows(r) == [(:xvis, :hide), (:xvis, :hide)] && isempty(r.diagnostics)
    end

    @testset "[A9] two rows with mixed contexts (D08): an info row with no context of its own carries the place alone, a warning with a String context keeps it under `alterant_context`; a vector typed `Any` is no vector of diagnostics — consumed as a state (D09); an `:error` row at the read makes the run PROCESS_ERROR, the rows delivered (D10)" begin
        r = go("#~0 xhide(a)\nx = 1\n", rowsMixed); k = _ae_keys(r)
        @test r.status === GM.PROCESS_OK && _ae_rows(r) == [(:xvis, :hide), (:xvis, :hide)] && length(r.diagnostics) == 2
        @test r.diagnostics[1].code === :X_READ_A && r.diagnostics[1].severity === :info && r.diagnostics[1].context == (stated_by = k[1], level = 1, statement = "xhide(a)")
        @test r.diagnostics[2].code === :X_READ_B && r.diagnostics[2].severity === :warning && r.diagnostics[2].context == (alterant_context = "ctx", stated_by = k[1], level = 1, statement = "xhide(a)")
        r = go("#~0 xhide(a)\nx = 1\n", Any[GM.Diagnostic(:X_ANY, :warning, "typed Any — not read")]); @test r.status === GM.PROCESS_OK && isempty(_ae_rows(r)) && isempty(r.diagnostics)
        r = go("#~0 xhide(a)\nx = 1\n", [GM.Diagnostic(:X_READ_FAIL, :error, "an error row at the read")]); k = _ae_keys(r)
        @test r.status === GM.PROCESS_ERROR && _ae_rows(r) == [(:xvis, :hide), (:xvis, :hide)] && length(r.diagnostics) == 1 && r.diagnostics[1].severity === :error && r.diagnostics[1].context == (stated_by = k[1], level = 1, statement = "xhide(a)")
    end

    @testset "[A10] rows then a tuple (D11): the first statement's rows delivered and the statement enqueued; the second statement's state consumed and its rows delivered — three rows in delivery order, each with its own statement's text" begin
        r = go("#~0 xhide(a)\n#~ xhide(b)\nx = 1\n", (run, mhIdx, args) -> args == (:a,) ? rowsWarn : (:hide, rowsMixed)); k = _ae_keys(r)
        @test r.status === GM.PROCESS_OK && _ae_rows(r) == [(:xvis, :hide), (:xvis, :hide)] && length(r.diagnostics) == 3
        @test [(d.code, d.context.statement, d.context.level) for d in r.diagnostics] == [(:X_READ_NOTE, "xhide(a)", 1), (:X_READ_A, "xhide(b)", 1), (:X_READ_B, "xhide(b)", 1)] && all(d -> d.context.stated_by == k[1], r.diagnostics)
        @test SEEN == [(nothing, 1, :xhide, (:a,), false), (nothing, 1, :xhide, (:b,), false)]
    end
end
