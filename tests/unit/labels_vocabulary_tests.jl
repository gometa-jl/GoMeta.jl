# labels_vocabulary_tests.jl — 0.4.2: THE VOCABULARY STATEMENTS `:++x` / `:(++, x, y)` / `:--x` / `:(--, x)` —
# the creator's design (the vocabulary first; the places `#~0` and the user level's profile; the mechanism at the read; the reach
# from the own metaBlock onward; the malformed shapes refused; no row, nothing delivered, the noun re-cut); the code:
# src/alterants-std/labels.jl `declareLabels!` (the hook),
# src/state.jl (`onRead`, `alt_run`), src/absorb/absorb_meta.jl (the hook before the slot bound), src/alterants/apply.jl (`_freshInstance`).
#
# IS:   sixteen witnesses [V-W1]–[V-W16] over the public entry, EVERY expected value READ from the measured printouts of the built
#       tree (the FULL delivery views and the `decided_by` traces; every literal re-checked against the proofs' run); every refusal
#       message a byte-exact copy of its view's last line, never retyped —
#       the `raw"""…"""` literals below — or from the custom-registration probe; every literal confirmed against the
#       proofs' run. THE FORMS at `#~0` and at the user level ([V-W1], [V-W2]); THE PLACE refused elsewhere, the
#       place checked first ([V-W3], [V-W15]); THE REFUSAL'S ACCEPTED SET the run's ([V-W4]); THE REACH — from the own metaBlock onward,
#       a Block above untouched ([V-W5], [V-W10]); THE FOLD in reading order, the no-ops ([V-W6]); THE MALFORMED SHAPES ([V-W7]); a
#       declared name in a condition ([V-W8]); the one-line orders ([V-W9]); the user level against the file ([V-W10]); THE ENGINE'S DOOR —
#       the record's `onRead` default and the shipped registration ([V-W11]), consumed at the read and not enqueued ([V-W12]), nothing
#       persists between calls ([V-W13]), a CUSTOM Alterant's hook through the door ([V-W14]); the hook's delta called directly ([V-W16]).
# REASONING: a vocabulary statement is CONSUMED at the read by the Labels Alterant's hook — no slot action, no evals row — and the run's
#       vocabulary (the base plus the additions minus the removals, kept apart) is handed to every later instance; a run without a
#       vocabulary statement is pinned already (fed_profile_order_tests.jl [W1]–[W13]; vocabulary_tests.jl [2] / [2b]) — no new testset for it.
#       NOT witnessed here (the oracle's alone): V10, V18, V21, V23, V27 (026 with a declaration prepended: 28 rows unchanged), V38, the
#       28-input fed sweep with `:++🪵 :🪵` and with `:++🪵` alone; the glued-digit gap is open.
# PURPOSE: the vocabulary statements, measured — never inferred from the hook's docstring or from prose.

using Test
import GoMeta as GM
const _LV_BLS = GM.BLS

_lv_bytes(s::String) = Vector{UInt8}(codeunits(s))
_lv_run(s::String; profile = nothing, registry = nothing) =
    GM.goMeta(_lv_bytes(s); (registry === nothing ? (;) : (; registry = registry))..., config = GM.GoMetaConfig(; user_mh_profile = profile))
_lv_msg(s::String; profile = nothing) = try; _lv_run(s; profile = profile); nothing; catch e; sprint(showerror, e); end   # the message as the oracle's view prints it
_lv_recs(r) = collect(r.altValues_evals.records)
_lv_cells(r) = unique(x.cell_handle for x in _lv_recs(r))
_lv_attrs(r, h) = Set(x.attr for x in _lv_recs(r) if x.cell_handle == h)
_lv_rows(r, h, a) = [x for x in _lv_recs(r) if x.cell_handle == h && x.attr === a]
_lv_key(r, c) = GM.key_bytes(GM.occurrence_key(r.blsComponentTree, c))      # the key as the Engine's writer derives it (the code-home trap list)
_lv_blocks(r) = _LV_BLS.children(r.blsComponentTree)
"the shape of V01: `n` label rows on the metaBlock `bs[i]` and on the Code Block `bs[i+1]` — each label once per Block, every row decided by the metaBlock alone, the sources own / indirect"
function _lv_two_blocks(r, labels::Vector{Symbol}; i::Int = 1)
    bs = _lv_blocks(r); bm, bc = bs[i], bs[i + 1]; km, kc = _lv_key(r, bm), _lv_key(r, bc)
    @test _LV_BLS.kind(bm) === :Meta && _LV_BLS.kind(bc) === :Code
    @test length(_lv_recs(r)) == 2 * length(labels) && Set(_lv_cells(r)) == Set([km, kc])
    for h in (km, kc)
        @test _lv_attrs(r, h) == Set(Symbol("label_", l) for l in labels)
        for l in labels
            vs = _lv_rows(r, h, Symbol("label_", l)); @test length(vs) == 1 && vs[1].value === true && vs[1].decided_by == [km]
        end
    end
    @test GM.evaluatedAltValue(r, bm, :labels).value == labels && GM.evaluatedAltValue(r, bm, :labels).source === :own
    @test GM.evaluatedAltValue(r, bc, :labels).value == labels && GM.evaluatedAltValue(r, bc, :labels).source === :indirect
end
const _LV_V01 = "#~0 :++label6\n#~ :label6\nx = 1\n"

@testset "the vocabulary statements of the Labels Alterant (0.4.2)" begin

    @testset "[V-W1] the forms at `#~0`, each with a use after it: `:++x` (V01), `:(++, x, y)` (V02) applied; `:(--, x, y)` (V30) refused with label1 and label2 out of the set" begin
        # AFTER view V01: Block #2 Meta L1–L2 `#~0 :++label6⏎#~ :label6` one `label_label6` row, Block #3 Code L3 `x = 1` one `label_label6` row;
        # trace: both decided_by Block #2; sources own / indirect — the declaration mints no row of its own (the metaBlock carries ONE row)
        r = _lv_run(_LV_V01); @test r.status === GM.PROCESS_OK; _lv_two_blocks(r, [:label6])
        # AFTER trace V02: 4 rows — label_label7 and label_label6 on each of the two Blocks; answer value [:label6, :label7]
        r2 = _lv_run("#~0 :(++, label6, label7)\n#~ :(label6, label7)\nx = 1\n"); @test r2.status === GM.PROCESS_OK; _lv_two_blocks(r2, [:label6, :label7])
        # AFTER view V30 (refused): the accepted set names neither label1 nor label2
        m = _lv_msg("#~0 :(--, label1, label2)\n#~ :label1\nx = 1\n")
        @test m == raw"""GoMeta apply: unknown label "label1" — not in the Labels Alterant's vocabulary (the accepted set = [:doc, :label3, :label4, :label5, :⌛, :⛓️, Symbol("⛓️\u200d💥"), :⛔, :🇨🇭, :🌍, :🌛, :🌞, :🌳, :🌷, :🌹, :🌼, :🍀, :🍒, :🍻, :🎨, :🎿, :🏔️, :🐣, :💕, :💡, :💣, :💫, :💯, :💸, :💾, :📝, :📸, :🔥, :😘, :🚀, :🧮, :🫕]); see docs/public-api.md §3.4"""
        @test !occursin(":label1", m) && !occursin(":label2", m) && occursin(":label3", m)
    end

    @testset "[V-W2] the user level's profile: `:++label6` fed, the file's `:label6` applied with the metaBlock deciding (V07); `:--label1` fed, the file's `:label1` refused (V08)" begin
        # AFTER trace V07 (profile ":++label6"): 2 rows, both decided_by Block #2 (the file's metaBlock) — not the user context; sources own / indirect
        r = _lv_run("#~ :label6\nx = 1\n"; profile = ":++label6"); @test r.status === GM.PROCESS_OK; _lv_two_blocks(r, [:label6])
        @test all(x -> x.decided_by != [GM.key_bytes(GM.user_context_key(:default, 1))], _lv_recs(r))
        # AFTER view V08 (profile ":--label1", refused): label1 out of the set
        m = _lv_msg("#~ :label1\nx = 1\n"; profile = ":--label1")
        @test m == raw"""GoMeta apply: unknown label "label1" — not in the Labels Alterant's vocabulary (the accepted set = [:doc, :label2, :label3, :label4, :label5, :⌛, :⛓️, Symbol("⛓️\u200d💥"), :⛔, :🇨🇭, :🌍, :🌛, :🌞, :🌳, :🌷, :🌹, :🌼, :🍀, :🍒, :🍻, :🎨, :🎿, :🏔️, :🐣, :💕, :💡, :💣, :💫, :💯, :💸, :💾, :📝, :📸, :🔥, :😘, :🚀, :🧮, :🫕]); see docs/public-api.md §3.4"""
        @test !occursin(":label1", m)
    end

    @testset "[V-W3] the place: a `#~` metaBlock (V05) and an inline metaSegment (V06) refused at the read, the message naming the two places; the place checked before the shape (V40)" begin
        @test _lv_msg("#~ :++label6\nx = 1\n") == raw"""GoMeta absorb: a vocabulary statement (`:++x`, `:(++, x, y)`) is legal at `#~0` and in the user level's profile only — here a metaBlock of depth 1; see docs/public-api.md §3.4"""
        @test _lv_msg("x = 1 #~ :++label6\n") == raw"""GoMeta absorb: a vocabulary statement (`:++x`, `:(++, x, y)`) is legal at `#~0` and in the user level's profile only — here an inline metaSegment; see docs/public-api.md §3.4"""
        # V40 `#~ :++label6{ isCode }` — malformed AND misplaced: the place refusal, the same text as V05's
        @test _lv_msg("#~ :++label6{ isCode }\nx = 1\n") == raw"""GoMeta absorb: a vocabulary statement (`:++x`, `:(++, x, y)`) is legal at `#~0` and in the user level's profile only — here a metaBlock of depth 1; see docs/public-api.md §3.4"""
        @test _lv_msg("#~ :++label6{ isCode }\nx = 1\n") == _lv_msg("#~ :++label6\nx = 1\n")
    end

    @testset "[V-W4] the refusal's accepted set is the run's: after `:--label1` it omits label1 (V03); after `:++label6` it names label6 (V22); after `:++label6 :++label6` it names label6 ONCE (V31)" begin
        m3 = _lv_msg("#~0 :--label1\n#~ :label1\nx = 1\n")
        @test m3 == raw"""GoMeta apply: unknown label "label1" — not in the Labels Alterant's vocabulary (the accepted set = [:doc, :label2, :label3, :label4, :label5, :⌛, :⛓️, Symbol("⛓️\u200d💥"), :⛔, :🇨🇭, :🌍, :🌛, :🌞, :🌳, :🌷, :🌹, :🌼, :🍀, :🍒, :🍻, :🎨, :🎿, :🏔️, :🐣, :💕, :💡, :💣, :💫, :💯, :💸, :💾, :📝, :📸, :🔥, :😘, :🚀, :🧮, :🫕]); see docs/public-api.md §3.4"""
        @test !occursin(":label1", m3) && occursin("(the accepted set = [:doc, :label2, :label3, :label4, :label5, ", m3)
        m22 = _lv_msg("#~0 :++label6\n#~ :zzz\nx = 1\n")
        @test m22 == raw"""GoMeta apply: unknown label "zzz" — not in the Labels Alterant's vocabulary (the accepted set = [:doc, :label1, :label2, :label3, :label4, :label5, :label6, :⌛, :⛓️, Symbol("⛓️\u200d💥"), :⛔, :🇨🇭, :🌍, :🌛, :🌞, :🌳, :🌷, :🌹, :🌼, :🍀, :🍒, :🍻, :🎨, :🎿, :🏔️, :🐣, :💕, :💡, :💣, :💫, :💯, :💸, :💾, :📝, :📸, :🔥, :😘, :🚀, :🧮, :🫕]); see docs/public-api.md §3.4"""
        @test occursin("[:doc, :label1, :label2, :label3, :label4, :label5, :label6, ", m22) && count(":label6", m22) == 1
        m31 = _lv_msg("#~0 :++label6 :++label6\n#~ :zzz\nx = 1\n")
        @test m31 == raw"""GoMeta apply: unknown label "zzz" — not in the Labels Alterant's vocabulary (the accepted set = [:doc, :label1, :label2, :label3, :label4, :label5, :label6, :⌛, :⛓️, Symbol("⛓️\u200d💥"), :⛔, :🇨🇭, :🌍, :🌛, :🌞, :🌳, :🌷, :🌹, :🌼, :🍀, :🍒, :🍻, :🎨, :🎿, :🏔️, :🐣, :💕, :💡, :💣, :💫, :💯, :💸, :💾, :📝, :📸, :🔥, :😘, :🚀, :🧮, :🫕]); see docs/public-api.md §3.4"""
        @test m31 == m22 && count(":label6", m31) == 1
        @test startswith(m3, "GoMeta apply: unknown label \"label1\" — not in the Labels Alterant's vocabulary (the accepted set = [")   # the noun re-cut
    end

    @testset "[V-W5] the reach: a declaration holds for a later `#~0` metaBlock (V09); a use in an earlier Block refuses (V11); a use before an exclusion on one line refuses (V34)" begin
        # AFTER trace V09 `#~0 :++label6⏎⏎y = 1⏎#~0 :label6⏎x = 1`: 2 rows on Blocks #4 (Meta) and #5 (Code), both decided_by Block #4; the first metaBlock and the Code Block between carry none
        r = _lv_run("#~0 :++label6\n\ny = 1\n#~0 :label6\nx = 1\n"); @test r.status === GM.PROCESS_OK
        bs = _lv_blocks(r); @test length(bs) == 4 && _LV_BLS.kind(bs[1]) === :Meta && _LV_BLS.kind(bs[2]) === :Code
        _lv_two_blocks(r, [:label6]; i = 3)
        @test _lv_msg("#~ :label6\nx = 1\n#~0 :++label6\ny = 1\n") == raw"""GoMeta apply: unknown label "label6" — not in the Labels Alterant's vocabulary (the accepted set = [:doc, :label1, :label2, :label3, :label4, :label5, :⌛, :⛓️, Symbol("⛓️\u200d💥"), :⛔, :🇨🇭, :🌍, :🌛, :🌞, :🌳, :🌷, :🌹, :🌼, :🍀, :🍒, :🍻, :🎨, :🎿, :🏔️, :🐣, :💕, :💡, :💣, :💫, :💯, :💸, :💾, :📝, :📸, :🔥, :😘, :🚀, :🧮, :🫕]); see docs/public-api.md §3.4"""
        @test _lv_msg("#~0 :label1 :--label1\nx = 1\n") == raw"""GoMeta apply: unknown label "label1" — not in the Labels Alterant's vocabulary (the accepted set = [:doc, :label2, :label3, :label4, :label5, :⌛, :⛓️, Symbol("⛓️\u200d💥"), :⛔, :🇨🇭, :🌍, :🌛, :🌞, :🌳, :🌷, :🌹, :🌼, :🍀, :🍒, :🍻, :🎨, :🎿, :🏔️, :🐣, :💕, :💡, :💣, :💫, :💯, :💸, :💾, :📝, :📸, :🔥, :😘, :🚀, :🧮, :🫕]); see docs/public-api.md §3.4"""
    end

    @testset "[V-W6] the fold in reading order: `:--label6 :++label6` declares (V12); `:++label6 :--label6` removes (V13); a base name added is a no-op (V14); a base name added then removed is removed (V35); a base name removed then added again is back (V41)" begin
        r12 = _lv_run("#~0 :--label6 :++label6\n#~ :label6\nx = 1\n"); @test r12.status === GM.PROCESS_OK; _lv_two_blocks(r12, [:label6])
        m13 = _lv_msg("#~0 :++label6 :--label6\n#~ :label6\nx = 1\n")
        @test m13 == raw"""GoMeta apply: unknown label "label6" — not in the Labels Alterant's vocabulary (the accepted set = [:doc, :label1, :label2, :label3, :label4, :label5, :⌛, :⛓️, Symbol("⛓️\u200d💥"), :⛔, :🇨🇭, :🌍, :🌛, :🌞, :🌳, :🌷, :🌹, :🌼, :🍀, :🍒, :🍻, :🎨, :🎿, :🏔️, :🐣, :💕, :💡, :💣, :💫, :💯, :💸, :💾, :📝, :📸, :🔥, :😘, :🚀, :🧮, :🫕]); see docs/public-api.md §3.4"""
        @test !occursin(":label6", m13)
        r14 = _lv_run("#~0 :++label1\n#~ :label1\nx = 1\n"); @test r14.status === GM.PROCESS_OK; _lv_two_blocks(r14, [:label1])
        # AFTER trace V41 `#~0 :--label1 :++label1⏎#~ :label1⏎x = 1` (measured; refused before the vocabulary statements): a BASE name removed then added again is back — 2 rows label1
        r41 = _lv_run("#~0 :--label1 :++label1\n#~ :label1\nx = 1\n"); @test r41.status === GM.PROCESS_OK; _lv_two_blocks(r41, [:label1])
        m35 = _lv_msg("#~0 :++label1 :--label1\n#~ :label1\nx = 1\n")
        @test m35 ==raw"""GoMeta apply: unknown label "label1" — not in the Labels Alterant's vocabulary (the accepted set = [:doc, :label2, :label3, :label4, :label5, :⌛, :⛓️, Symbol("⛓️\u200d💥"), :⛔, :🇨🇭, :🌍, :🌛, :🌞, :🌳, :🌷, :🌹, :🌼, :🍀, :🍒, :🍻, :🎨, :🎿, :🏔️, :🐣, :💕, :💡, :💣, :💫, :💯, :💸, :💾, :📝, :📸, :🔥, :😘, :🚀, :🧮, :🫕]); see docs/public-api.md §3.4"""
        @test !occursin(":label1", m35)
    end

    @testset "[V-W7] the malformed shapes refused at the read: a condition (V15), a signed member (V16), no name (V17; an EMPTY member — a stray comma — V42, V43, V44, the place still first V45), the prefixed sign with several arguments (V39)" begin
        @test _lv_msg("#~0 :++label6{ isCode }\nx = 1\n") == raw"""GoMeta absorb: a vocabulary statement takes no condition — `:++label6{ … }` (a declaration is a fact of the run, not of a Component); see docs/public-api.md §3.4"""
        @test _lv_msg("#~0 :(++, label6, --label7)\nx = 1\n") == raw"""GoMeta absorb: a label name in a vocabulary statement may not begin with `+` or `-` — got "--label7" in `:++`; see docs/public-api.md §3.4"""
        @test _lv_msg("#~0 :++\nx = 1\n") == raw"""GoMeta absorb: the vocabulary statement `:++` names no label — the forms are `:++x` and `:(++, x, y)`; see docs/public-api.md §3.4"""
        # (iii) with an EMPTY member — a stray comma (V42 `:(++,) :(,)`, V43 `:(++, label6, )`, V44 `:(--,)`; the place still first, V45 `#~ :(++,)`): every literal below is a byte-exact copy of its probe's view's last line in the measured run (each direct assertion compared with its view; every raw literal of this file found in that run's printouts)
        @test _lv_msg("#~0 :(++,) :(,)\nx = 1\n") == raw"""GoMeta absorb: the vocabulary statement `:++` names an empty label (a stray comma) — the forms are `:++x` and `:(++, x, y)`; see docs/public-api.md §3.4"""
        @test _lv_msg("#~0 :(++, label6, )\n#~ :zzz\nx = 1\n") == raw"""GoMeta absorb: the vocabulary statement `:++` names an empty label (a stray comma) — the forms are `:++x` and `:(++, x, y)`; see docs/public-api.md §3.4"""
        @test _lv_msg("#~0 :(--,)\nx = 1\n") == raw"""GoMeta absorb: the vocabulary statement `:--` names an empty label (a stray comma) — the forms are `:--x` and `:(--, x, y)`; see docs/public-api.md §3.4"""
        @test _lv_msg("#~ :(++,)\nx = 1\n") == _lv_msg("#~ :++label6\nx = 1\n")
        @test _lv_msg("#~0 :(++label6, label7)\nx = 1\n") == raw"""GoMeta absorb: the prefixed vocabulary statement `:++label6` takes one name — 2 arguments given (the list form is `:(++, x, y)`); see docs/public-api.md §3.4"""
    end

    @testset "[V-W8] a declared name in a condition (V20): `#~0 :++label6 :label6 hide{ :label6 }` — the hide applies, decided by the metaBlock" begin
        # AFTER trace V20: 4 rows — label_label6 and visib :hide on each of the two Blocks, every row decided_by Block #2; Visib sources own / indirect
        r = _lv_run("#~0 :++label6 :label6 hide{ :label6 }\nx = 1\n"); @test r.status === GM.PROCESS_OK
        bs = _lv_blocks(r); km, kc = _lv_key(r, bs[1]), _lv_key(r, bs[2])
        @test length(_lv_recs(r)) == 4 && Set(_lv_cells(r)) == Set([km, kc])
        for h in (km, kc)
            @test _lv_attrs(r, h) == Set([:label_label6, :visib])
            vs = _lv_rows(r, h, :visib); @test length(vs) == 1 && vs[1].value === :hide && vs[1].decided_by == [km]
        end
        @test GM.evaluatedAltValue(r, bs[1], :Visib).source === :own && GM.evaluatedAltValue(r, bs[2], :Visib).source === :indirect
    end

    @testset "[V-W9] one line: the use BEFORE the declaration applies (V19 — the order inside a metaBlock immaterial); the one-line bracket `:++label6 :label6 :--label6` refuses (V36)" begin
        r = _lv_run("#~0 :label6 :++label6\nx = 1\n"); @test r.status === GM.PROCESS_OK; _lv_two_blocks(r, [:label6])
        m = _lv_msg("#~0 :++label6 :label6 :--label6\nx = 1\n")
        @test m == raw"""GoMeta apply: unknown label "label6" — not in the Labels Alterant's vocabulary (the accepted set = [:doc, :label1, :label2, :label3, :label4, :label5, :⌛, :⛓️, Symbol("⛓️\u200d💥"), :⛔, :🇨🇭, :🌍, :🌛, :🌞, :🌳, :🌷, :🌹, :🌼, :🍀, :🍒, :🍻, :🎨, :🎿, :🏔️, :🐣, :💕, :💡, :💣, :💫, :💯, :💸, :💾, :📝, :📸, :🔥, :😘, :🚀, :🧮, :🫕]); see docs/public-api.md §3.4"""
        @test !occursin(":label6", m)
    end

    @testset "[V-W10] the user level against the file: fed `:++label6` then the file's `:--label6` refuses the use (V24); fed `:--label6` then the file's `:++label6` applies (V25); an exclusion after a use refuses a later use (V26) and leaves the earlier rows (V26b); a fed `:label1` refused by the file's `:--label1` (V37); a fed `:--label1` then the file's `:++label1` re-admits the BASE name (V46)" begin
        m24 = _lv_msg("#~0 :--label6\n#~ :label6\nx = 1\n"; profile = ":++label6")
        @test m24 == raw"""GoMeta apply: unknown label "label6" — not in the Labels Alterant's vocabulary (the accepted set = [:doc, :label1, :label2, :label3, :label4, :label5, :⌛, :⛓️, Symbol("⛓️\u200d💥"), :⛔, :🇨🇭, :🌍, :🌛, :🌞, :🌳, :🌷, :🌹, :🌼, :🍀, :🍒, :🍻, :🎨, :🎿, :🏔️, :🐣, :💕, :💡, :💣, :💫, :💯, :💸, :💾, :📝, :📸, :🔥, :😘, :🚀, :🧮, :🫕]); see docs/public-api.md §3.4"""
        @test !occursin(":label6", m24)
        r25 = _lv_run("#~0 :++label6\n#~ :label6\nx = 1\n"; profile = ":--label6"); @test r25.status === GM.PROCESS_OK; _lv_two_blocks(r25, [:label6])
        # V46 (MEASURED FIRST): the file's `++` re-admits a BASE name the profile removed — V25's removal is a no-op (label6 is no base name); the other direction of the user level's value priority
        r46 = _lv_run("#~0 :++label1\n#~ :label1\nx = 1\n"; profile = ":--label1"); @test r46.status === GM.PROCESS_OK; _lv_two_blocks(r46, [:label1])
        @test _lv_msg("#~ :label1\nx = 1\n#~0 :--label1\n#~ :label1\ny = 1\n") == raw"""GoMeta apply: unknown label "label1" — not in the Labels Alterant's vocabulary (the accepted set = [:doc, :label2, :label3, :label4, :label5, :⌛, :⛓️, Symbol("⛓️\u200d💥"), :⛔, :🇨🇭, :🌍, :🌛, :🌞, :🌳, :🌷, :🌹, :🌼, :🍀, :🍒, :🍻, :🎨, :🎿, :🏔️, :🐣, :💕, :💡, :💣, :💫, :💯, :💸, :💾, :📝, :📸, :🔥, :😘, :🚀, :🧮, :🫕]); see docs/public-api.md §3.4"""
        # AFTER trace V26b `#~ :label1⏎x = 1⏎#~0 :--label1⏎y = 1`: 2 rows on Blocks #2 / #3 (label1), the later metaBlock and its Code Block none
        r26 = _lv_run("#~ :label1\nx = 1\n#~0 :--label1\ny = 1\n"); @test r26.status === GM.PROCESS_OK
        @test length(_lv_blocks(r26)) == 4; _lv_two_blocks(r26, [:label1])
        @test _lv_msg("#~0 :--label1\nx = 1\n"; profile = ":label1") == raw"""GoMeta apply: unknown label "label1" — not in the Labels Alterant's vocabulary (the accepted set = [:doc, :label2, :label3, :label4, :label5, :⌛, :⛓️, Symbol("⛓️\u200d💥"), :⛔, :🇨🇭, :🌍, :🌛, :🌞, :🌳, :🌷, :🌹, :🌼, :🍀, :🍒, :🍻, :🎨, :🎿, :🏔️, :🐣, :💕, :💡, :💣, :💫, :💯, :💸, :💾, :📝, :📸, :🔥, :😘, :🚀, :🧮, :🫕]); see docs/public-api.md §3.4"""
    end

    @testset "[V-W11] the Engine's door: the registration record's `onRead` defaults to `nothing` (the keyword form; every other shipped Alterant); the Labels Alterant's hook is `declareLabels!`, its constructor `LabelsInstance`" begin
        # PROBE-custom-hook_r3 D13 / D14 / D15
        @test GM.Alterant(; altName = :q, setMode = :mutExclusive, altConstructor = GM.Alterants.Visib, setAltInstance = GM.Alterants.setVisib).onRead === nothing
        @test [p.altName for p in GM.DEFAULT_REGISTRY.plugins] == [:labels, :Visib, :id, :heading]
        @test GM.DEFAULT_REGISTRY.plugins[1].onRead === GM.Alterants.declareLabels! && GM.DEFAULT_REGISTRY.plugins[1].altConstructor === GM.Alterants.LabelsInstance
        @test all(p -> p.onRead === nothing, GM.DEFAULT_REGISTRY.plugins[2:end])
        @test fieldnames(GM.Alterant)[end] === :onRead && length(fieldnames(GM.Alterant)) == 9
    end

    @testset "[V-W12] consumed at the read, not enqueued (V29): eight label statements and one vocabulary statement on one `#~0` line PROCESS_OK — 12 rows, six labels per Block, every row decided by the metaBlock's eight statements" begin
        # AFTER view V29: Block #2 Meta L1 and Block #3 Code L2 each label_doc / label_label1 … label_label5; trace: every row decided_by[1..8] = Block #2
        r = _lv_run("#~0 :++label6 :label1 :label2 :label3 :label4 :label5 :doc :label1 :label2\nx = 1\n"); @test r.status === GM.PROCESS_OK
        bs = _lv_blocks(r); km, kc = _lv_key(r, bs[1]), _lv_key(r, bs[2])
        @test length(_lv_recs(r)) == 12 && Set(_lv_cells(r)) == Set([km, kc])
        six = Set([:label_doc, :label_label1, :label_label2, :label_label3, :label_label4, :label_label5])
        @test _lv_attrs(r, km) == six && _lv_attrs(r, kc) == six
        @test all(x -> x.decided_by == fill(km, 8), _lv_recs(r))
        @test GM.evaluatedAltValue(r, bs[1], :labels).value == [:doc, :label1, :label2, :label3, :label4, :label5]
    end

    @testset "[V-W13] re-entrancy: nothing persists between two `goMeta` calls (V28) — after V01 and after V07 fed with `:++label6` (the oracle's order: V28 right after V07), `#~ :label6` alone refuses and the hard-coded list keeps its 39 names; after `#~0 :--label1` alone (V04), `#~ :label1` alone applies" begin
        r1 = _lv_run(_LV_V01); @test r1.status === GM.PROCESS_OK
        r7 = _lv_run("#~ :label6\nx = 1\n"; profile = ":++label6"); @test r7.status === GM.PROCESS_OK   # V07 fed (AFTER trace V07: PROCESS_OK, 2 rows decided_by the file's metaBlock), run IMMEDIATELY before the un-fed run of the same document below — the oracle's order (V28 stands right after V07)
        @test _lv_msg("#~ :label6\nx = 1\n") == raw"""GoMeta apply: unknown label "label6" — not in the Labels Alterant's vocabulary (the accepted set = [:doc, :label1, :label2, :label3, :label4, :label5, :⌛, :⛓️, Symbol("⛓️\u200d💥"), :⛔, :🇨🇭, :🌍, :🌛, :🌞, :🌳, :🌷, :🌹, :🌼, :🍀, :🍒, :🍻, :🎨, :🎿, :🏔️, :🐣, :💕, :💡, :💣, :💫, :💯, :💸, :💾, :📝, :📸, :🔥, :😘, :🚀, :🧮, :🫕]); see docs/public-api.md §3.4"""
        @test length(GM.Alterants.LABELS_VOCABULARY) == 39 && GM.Alterants.base_vocabulary() === GM.Alterants.LABELS_VOCABULARY
        r4 = _lv_run("#~0 :--label1\nx = 1\n"); @test r4.status === GM.PROCESS_OK && isempty(_lv_recs(r4))     # AFTER trace V04: 0 rows
        r = _lv_run("#~ :label1\nx = 1\n"); @test r.status === GM.PROCESS_OK; _lv_two_blocks(r, [:label1])
    end

    @testset "[V-W14] the Engine's door by a CUSTOM registration (the pattern of custom_localonly_feed_tests.jl; MEASURED: PROBE-custom-hook_r3 P2–P7): a non-Labels Alterant's hook called at the read with the level index, its `nothing` enqueuing as before, its value consumed and handed to the constructor" begin
        SEEN = Any[]; SETS = Any[]
        hook(run, mhIdx, actionName, args, hasCondition) = (push!(SEEN, (run, mhIdx, actionName, args, hasCondition)); actionName === :xhide && args == (:consume,) ? :hide : nothing)
        els(v) = (GM.Alterants.getElement(v, :hide), GM.Alterants.getElement(v, :show), GM.Alterants.getElement(v, :discard))   # the instance's elements BEFORE the set
        xset(v::GM.Alterants.Visib, a::Symbol, args...) = (push!(SETS, (els(v), a, args)); GM.Alterants.setVisib(v, a === :xshow ? :show : :hide))
        xset(v::GM.Alterants.Visib, a::SubString{String}, args...) = xset(v, Symbol(a), args...)
        b = GM.RegistryBuilder(GM.DEFAULT_REGISTRY); pV = GM.next_plugin_index(b)
        GM.register!(b, GM.Alterant(; altName = :xvis, setMode = :mutExclusive, altConstructor = GM.Alterants.Visib, setAltInstance = xset,
                                      default = GM.Declared(:show), capture = GM.CaptureDecl(:single; attr_stem = :xvis), onRead = hook),
                     GM.ActionSpec(; name = :xhide, plugin = Int8(pV)), GM.ActionSpec(; name = :xshow, plugin = Int8(pV)))
        REG = GM.publish(b)
        @test pV == 5 && [p.altName for p in REG.plugins if p.onRead !== nothing] == [:labels, :xvis]
        rows(r) = [(String(a), v) for (_, a, v, _) in GM.readAltValuesEvals(r.altValues_evals)]
        go(s; profile = nothing) = (empty!(SEEN); empty!(SETS); _lv_run(s; profile = profile, registry = REG))
        # P2 the user level: the level index 10; consumed — no row
        r = go("x = 1\n"; profile = "xhide(consume)"); @test r.status === GM.PROCESS_OK && isempty(rows(r)) && SEEN == [(nothing, 10, :xhide, (:consume,), false)] && isempty(SETS)
        # P3 inline: the level index 11; consumed
        r = go("x = 1 #~ xhide(consume)\n"); @test r.status === GM.PROCESS_OK && isempty(rows(r)) && SEEN == [(nothing, 11, :xhide, (:consume,), false)] && isempty(SETS)
        # P4 the hook's `nothing` path: `xhide(other)` at `#~0` (index 1) enqueued as before — two xvis rows, the setter given the arguments, the instance the zero-argument constructor's
        r = go("#~0 xhide(other)\nx = 1\n"); @test r.status === GM.PROCESS_OK && rows(r) == [("xvis", :hide), ("xvis", :hide)]
        @test SEEN == [(nothing, 1, :xhide, (:other,), false)] && SETS == [((false, false, false), :xhide, (:other,)), ((false, false, false), :xhide, (:other,))]
        # P5 a condition: seen by the hook as `true`; consumed
        r = go("#~0 xhide(consume){ isCode }\nx = 1\n"); @test r.status === GM.PROCESS_OK && isempty(rows(r)) && SEEN == [(nothing, 1, :xhide, (:consume,), true)]
        # P6 a statement WITHOUT arguments never reaches the hook
        r = go("#~0 xshow\nx = 1\n"); @test r.status === GM.PROCESS_OK && rows(r) == [("xvis", :show), ("xvis", :show)] && isempty(SEEN)
        # P7 consumed, then enqueued: the run state `:hide` handed back to the hook on its next call AND to the constructor — every later instance `Visib(:hide)`, the setter seeing hide already set
        r = go("#~0 xhide(consume)\n#~ xhide(other)\nx = 1\n"); @test r.status === GM.PROCESS_OK && rows(r) == [("xvis", :hide), ("xvis", :hide)]
        @test SEEN == [(nothing, 1, :xhide, (:consume,), false), (:hide, 1, :xhide, (:other,), false)]
        @test SETS == [((true, false, false), :xhide, (:other,)), ((true, false, false), :xhide, (:other,))]
    end

    @testset "[V-W15] the place is the metaBlock's level: a glued `#~` metaLine under a `#~0` opener accepted (V32); a glued `#~0` under a `#~` opener refused (V33)" begin
        # AFTER trace V32 `#~0 :label1⏎#~ :++label6⏎#~ :label6⏎x = 1`: 4 rows — label1 and label6 on Blocks #2 / #3, each decided_by Block #2 twice; answer [:label1, :label6]
        r = _lv_run("#~0 :label1\n#~ :++label6\n#~ :label6\nx = 1\n"); @test r.status === GM.PROCESS_OK
        bs = _lv_blocks(r); km, kc = _lv_key(r, bs[1]), _lv_key(r, bs[2])
        @test length(bs) == 2 && length(_lv_recs(r)) == 4 && Set(_lv_cells(r)) == Set([km, kc])
        for h in (km, kc), a in (:label_label1, :label_label6)
            vs = _lv_rows(r, h, a); @test length(vs) == 1 && vs[1].decided_by == [km, km]
        end
        @test GM.evaluatedAltValue(r, bs[1], :labels).value == [:label1, :label6]
        @test _lv_msg("#~ :label1\n#~0 :++label6\nx = 1\n") == raw"""GoMeta absorb: a vocabulary statement (`:++x`, `:(++, x, y)`) is legal at `#~0` and in the user level's profile only — here a metaBlock of depth 1; see docs/public-api.md §3.4"""
    end

    @testset "[V-W16] the hook called directly (MEASURED: PROBE-custom-hook_r3 D1–D12; PROBE-custom-hook_r4 D17–D19 — the fold's three shapes V12 / V13 / V35): the delta kept apart — base, added, removed; a plain label and a quoted token handed back; the place and the malformed shapes refused with the same texts" begin
        D = GM.Alterants.declareLabels!
        v = D(nothing, 1, :(:), (Symbol("++label6"),), false)
        @test v isa GM.Alterants.LabelsVocabulary && v.added == [:label6] && isempty(v.removed) && length(v.effective) == 40 && v.effective[end] === :label6 && v.base === GM.Alterants.LABELS_VOCABULARY
        @test D(v, 1, :(:), (Symbol("--"), :label1), false) === v && v.added == [:label6] && v.removed == [:label1] && length(v.effective) == 39 && :label1 ∉ v.effective
        # the delta after the fold's three shapes: V12 `:--label6 :++label6`, V13 `:++label6 :--label6`, V35 `:++label1 :--label1` — MEASURED: PROBE-custom-hook_r4 D17 … D19 (added / removed / |effective|: [:label6] / [] / 40; [] / [] / 39; [] / [:label1] / 38; the assertions below equal that printout)
        seq(a, b) = D(D(nothing, 1, :(:), (Symbol(a),), false), 1, :(:), (Symbol(b),), false)
        v12 = seq("--label6", "++label6"); @test v12.added == [:label6] && isempty(v12.removed) && length(v12.effective) == 40
        v13 = seq("++label6", "--label6"); @test isempty(v13.added) && isempty(v13.removed) && length(v13.effective) == 39
        v35 = seq("++label1", "--label1"); @test isempty(v35.added) && v35.removed == [:label1] && length(v35.effective) == 38
        @test D(v, 1, :(:), (:label1,), false) === nothing && D(v, 1, :(:), (Symbol("++"), "x"), false) === nothing
        @test D(nothing, 10, :(:), (Symbol("++label6"),), false) isa GM.Alterants.LabelsVocabulary
        refusal(f) = try; f(); nothing; catch e; sprint(showerror, e); end
        @test refusal(() -> D(nothing, 2, :(:), (Symbol("++label6"),), false)) == raw"""GoMeta absorb: a vocabulary statement (`:++x`, `:(++, x, y)`) is legal at `#~0` and in the user level's profile only — here a metaBlock of depth 1; see docs/public-api.md §3.4"""
        @test refusal(() -> D(nothing, 11, :(:), (Symbol("++label6"),), false)) == raw"""GoMeta absorb: a vocabulary statement (`:++x`, `:(++, x, y)`) is legal at `#~0` and in the user level's profile only — here an inline metaSegment; see docs/public-api.md §3.4"""
        @test refusal(() -> D(nothing, 1, :(:), (Symbol("++label6"), :label7), false)) == raw"""GoMeta absorb: the prefixed vocabulary statement `:++label6` takes one name — 2 arguments given (the list form is `:(++, x, y)`); see docs/public-api.md §3.4"""
        @test refusal(() -> D(nothing, 1, :(:), (Symbol("++"),), false)) == raw"""GoMeta absorb: the vocabulary statement `:++` names no label — the forms are `:++x` and `:(++, x, y)`; see docs/public-api.md §3.4"""
        @test refusal(() -> D(nothing, 1, :(:), (Symbol("++"), :label6, Symbol("--label7")), false)) == raw"""GoMeta absorb: a label name in a vocabulary statement may not begin with `+` or `-` — got "--label7" in `:++`; see docs/public-api.md §3.4"""
        @test refusal(() -> D(nothing, 1, :(:), (Symbol("++label6"),), true)) == raw"""GoMeta absorb: a vocabulary statement takes no condition — `:++label6{ … }` (a declaration is a fact of the run, not of a Component); see docs/public-api.md §3.4"""
        w = GM.Alterants.LabelsVocabulary(); @test w.effective === w.base && length(GM.Alterants.LabelsInstance().vocab.effective) == 39
    end
end
