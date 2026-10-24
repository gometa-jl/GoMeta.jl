# labels_vocabulary_tests.jl — 0.4.2: THE VOCABULARY STATEMENTS `:++x` / `:(++, x, y)` / `:--x` / `:(--, x)` — since 0.4.3 PERSISTENT —
# the creator's design (the vocabulary first; the places `#~0` and the user level's profile; the mechanism at the read; the reach
# from the own metaBlock onward; the malformed shapes refused; no row, nothing delivered for a declaration but the `:info` row of a persisted
# change — or, where the file cannot be written, the `:warning` row `LABELS_VOCABULARY_FILE_NOT_WRITTEN` (labels_vocabulary_file_tests.jl [F11]); the noun re-cut); the code: src/alterants-std/labels.jl `declareLabels!` (the hook), src/state.jl (`onRead`, `alt_run`, the one door),
# src/absorb/absorb_meta.jl (the hook before the slot bound; its return in one grammar), src/alterants/apply.jl (`_freshInstance`).
#
# IS:   sixteen witnesses [V-W1]–[V-W16] over the public entry, EVERY expected value READ from the measured printouts of the built
#       tree (the FULL delivery views and the `decided_by` traces with their diagnostics blocks; every literal re-checked against the proofs' run);
#       every refusal message and every diagnostic message a byte-exact copy of its printout, never retyped —
#       the `raw"""…"""` literals below — or from the custom-registration probe. Since 0.4.3 EVERY DOCUMENT RUNS ON A FRESH USER-LEVEL
#       VOCABULARY FILE (`_lv_run`): a vocabulary statement persists into that file and is reported by ONE `:info` row per added or removed
#       name, delivered through the Engine's door at the read with the read-time place (the stating statement's handle, the level, the
#       statement's text); an applied name outside the run's vocabulary is REPORTED by a warning row per affected Component and SKIPPED, the run
#       proceeding (before 0.4.3 it refused). THE FORMS at `#~0` and at the user level ([V-W1], [V-W2]); THE PLACE refused elsewhere, the
#       place checked first ([V-W3], [V-W15]); THE UNKNOWN NAME after a removal or a declaration ([V-W4]); THE REACH — from the own metaBlock onward,
#       a Block above untouched ([V-W5], [V-W10]); THE FOLD in reading order, the no-ops ([V-W6]); THE MALFORMED SHAPES ([V-W7]); a
#       declared name in a condition ([V-W8]); the one-line orders ([V-W9]); the user level against the file ([V-W10]); THE ENGINE'S DOOR —
#       the record's `onRead` default and the shipped registration ([V-W11]), consumed at the read and not enqueued ([V-W12]), two calls on
#       different files and on the same file ([V-W13]), a CUSTOM Alterant's hook through the door ([V-W14]); the hook's delta called directly ([V-W16]).
# REASONING: a vocabulary statement is CONSUMED at the read by the Labels Alterant's hook — no slot action, no evals row — the run's
#       vocabulary (the base plus the additions minus the removals, kept apart) is handed to every later instance, and the change is written
#       into the user file for every later run (labels_vocabulary_file_tests.jl holds the file's witnesses); a run without a
#       vocabulary statement is pinned already (fed_profile_order_tests.jl [W1]–[W13]; vocabulary_tests.jl [2] / [2b]) — no new testset for it.
#       NOT witnessed here (the oracle's alone): V10, V18, V21, V23, V27 (026 with a declaration prepended: 28 rows unchanged), V38, the
#       28-input fed sweep with `:++🪵 :🪵` and with `:++🪵` alone; the glued-digit gap is open.
# PURPOSE: the vocabulary statements, measured — never inferred from the hook's docstring or from prose.

using Test
import GoMeta as GM
const _LV_BLS = GM.BLS

_lv_bytes(s::String) = Vector{UInt8}(codeunits(s))
_lv_run(s::String; profile = nothing, registry = nothing) =   # every document on a FRESH user-level vocabulary file: a vocabulary statement persists (0.4.3)
    (TestSupport.fresh_vocabulary!(); GM.goMeta(_lv_bytes(s); (registry === nothing ? (;) : (; registry = registry))..., config = GM.GoMetaConfig(; user_mh_profile = profile)))
_lv_msg(s::String; profile = nothing) = try; _lv_run(s; profile = profile); nothing; catch e; sprint(showerror, e); end   # the message as the oracle's view prints it
_lv_recs(r) = collect(r.altValues_evals.records)
_lv_cells(r) = unique(x.cell_handle for x in _lv_recs(r))
_lv_attrs(r, h) = Set(x.attr for x in _lv_recs(r) if x.cell_handle == h)
_lv_rows(r, h, a) = [x for x in _lv_recs(r) if x.cell_handle == h && x.attr === a]
_lv_key(r, c) = GM.key_bytes(GM.occurrence_key(r.blsComponentTree, c))      # the key as the Engine's writer derives it (the code-home trap list)
_lv_blocks(r) = _LV_BLS.children(r.blsComponentTree)
_lv_keys(r) = [_lv_key(r, b) for b in _lv_blocks(r)]                        # k[i] = the i-th Block's handle = Block #(i+1) of the FULL delivery view
const _LV_KU = GM.key_bytes(GM.user_context_key(:default, 1))                # the user level's handle
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
"one `LABEL_NOT_APPLIED_UNKNOWN` warning row (since 0.4.3): the code, the severity, the message bytes (the measured printout) and the context — the label, the Component (`cell`), the stating statement (`stated_by`), the Labels statements applied there so far (`statements`)"
function _lv_unknown(d, msg::String, label::Symbol, cell::Vector{UInt8}, stated_by::Vector{UInt8}, statements::Vector{Vector{UInt8}})
    @test d.code === :LABEL_NOT_APPLIED_UNKNOWN && d.severity === :warning && d.message == msg
    @test d.context == (label = label, cell = cell, stated_by = stated_by, statements = statements)
end
"one `LABELS_VOCABULARY_FILE_CHANGED` info row (since 0.4.3): the code, the severity; the context — the run's user file, the change, the label, and the read-time place the Engine's door attached (the stating statement's handle, the meta-hierarchy index the hook received, the statement's text); the message's head and tail around the file's path (the path the run's temporary file)"
function _lv_info(d, change::Symbol, label::Symbol, stated_by::Vector{UInt8}, level::Int, statement::String)
    @test d.code === :LABELS_VOCABULARY_FILE_CHANGED && d.severity === :info
    @test d.context == (file = ENV["GOMETA_LABELS_VOCABULARY"], change = change, label = label, stated_by = stated_by, level = level, statement = statement)
    head = change === :added ? "GoMeta absorb: `:++$label` added $label to the vocabulary file " : "GoMeta absorb: `:--$label` removed $label from the vocabulary file "
    tail = change === :added ? " — it holds for this run and every later one; `:--$label` removes it again; see docs/public-api.md §2" :
                               " — it is unknown for this run and every later one; `:++$label` adds it again (the shipped file keeps the original list); see docs/public-api.md §2"
    @test d.message == head * ENV["GOMETA_LABELS_VOCABULARY"] * tail
end
## the unknown label's messages, byte-exact from the measured traces (the RP set: V03's, V11's, V22's warning rows)
const _LV_MSG_LABEL1 = raw"""GoMeta apply: the plain `:label1` had no effect here — not in the Labels Alterant's vocabulary; declare it with `:++label1` at `#~0` or in the user level's profile, or correct the spelling; see docs/public-api.md §3.4"""
const _LV_MSG_LABEL6 = raw"""GoMeta apply: the plain `:label6` had no effect here — not in the Labels Alterant's vocabulary; declare it with `:++label6` at `#~0` or in the user level's profile, or correct the spelling; see docs/public-api.md §3.4"""
const _LV_MSG_ZZZ = raw"""GoMeta apply: the plain `:zzz` had no effect here — not in the Labels Alterant's vocabulary; declare it with `:++zzz` at `#~0` or in the user level's profile, or correct the spelling; see docs/public-api.md §3.4"""
const _LV_V01 = "#~0 :++label6\n#~ :label6\nx = 1\n"

@testset "the vocabulary statements of the Labels Alterant (0.4.2; persistent since 0.4.3)" begin

    @testset "[V-W1] the forms at `#~0`, each with a use after it: `:++x` (V01), `:(++, x, y)` (V02) applied and PERSISTED — one `:info` row per added name; `:(--, x, y)` (V30) removes label1 and label2 from the run's file and the use of label1 is REPORTED, not refused (since 0.4.3)" begin
        # AFTER view V01: Block #2 Meta L1–L2 `#~0 :++label6⏎#~ :label6` one `label_label6` row, Block #3 Code L3 `x = 1` one `label_label6` row;
        # trace: both decided_by Block #2; sources own / indirect — the declaration mints no row of its own (the metaBlock carries ONE row);
        # 1 diagnostic LABELS_VOCABULARY_FILE_CHANGED (info): label6 added to the run's file, stated by Block #2, level 1, the statement `:++label6`
        r = _lv_run(_LV_V01); @test r.status === GM.PROCESS_OK; _lv_two_blocks(r, [:label6]); k = _lv_keys(r)
        @test length(r.diagnostics) == 1; _lv_info(r.diagnostics[1], :added, :label6, k[1], 1, ":++label6")
        # AFTER trace V02: 4 rows — label_label7 and label_label6 on each of the two Blocks; answer value [:label6, :label7]; 2 info rows (label6, label7 added), the statement `:(++, label6, label7)`
        r2 = _lv_run("#~0 :(++, label6, label7)\n#~ :(label6, label7)\nx = 1\n"); @test r2.status === GM.PROCESS_OK; _lv_two_blocks(r2, [:label6, :label7]); k = _lv_keys(r2)
        @test length(r2.diagnostics) == 2; _lv_info(r2.diagnostics[1], :added, :label6, k[1], 1, ":(++, label6, label7)"); _lv_info(r2.diagnostics[2], :added, :label7, k[1], 1, ":(++, label6, label7)")
        # AFTER trace V30 `#~0 :(--, label1, label2)⏎#~ :label1⏎x = 1`: PROCESS_OK, 0 rows; 4 diagnostics — two info rows (label1, label2 removed; Block #2, level 1), then the plain `:label1` reported at Block #2 and Block #3 (stated_by Block #2, statements [#2])
        r30 = _lv_run("#~0 :(--, label1, label2)\n#~ :label1\nx = 1\n"); @test r30.status === GM.PROCESS_OK && isempty(_lv_recs(r30)); k = _lv_keys(r30); d = r30.diagnostics; @test length(d) == 4
        _lv_info(d[1], :removed, :label1, k[1], 1, ":(--, label1, label2)"); _lv_info(d[2], :removed, :label2, k[1], 1, ":(--, label1, label2)")
        _lv_unknown(d[3], _LV_MSG_LABEL1, :label1, k[1], k[1], [k[1]]); _lv_unknown(d[4], _LV_MSG_LABEL1, :label1, k[2], k[1], [k[1]])
    end

    @testset "[V-W2] the user level's profile: `:++label6` fed, the file's `:label6` applied with the metaBlock deciding, the addition persisted from the profile (V07); `:--label1` fed, the file's `:label1` REPORTED, not refused (V08)" begin
        # AFTER trace V07 (profile ":++label6"): 2 rows, both decided_by Block #2 (the file's metaBlock) — not the user context; sources own / indirect; 1 info row — stated by the user context, level 10, the statement `:++label6`
        r = _lv_run("#~ :label6\nx = 1\n"; profile = ":++label6"); @test r.status === GM.PROCESS_OK; _lv_two_blocks(r, [:label6])
        @test all(x -> x.decided_by != [_LV_KU], _lv_recs(r))
        @test length(r.diagnostics) == 1; _lv_info(r.diagnostics[1], :added, :label6, _LV_KU, 10, ":++label6")
        # AFTER trace V08 (profile ":--label1"): PROCESS_OK, 0 rows; 3 diagnostics — the info row (label1 removed; the user context, level 10, `:--label1`), then the plain `:label1` reported at Block #2 and Block #3 (stated_by Block #2, statements [#2])
        r8 = _lv_run("#~ :label1\nx = 1\n"; profile = ":--label1"); @test r8.status === GM.PROCESS_OK && isempty(_lv_recs(r8)); k = _lv_keys(r8); d = r8.diagnostics; @test length(d) == 3
        _lv_info(d[1], :removed, :label1, _LV_KU, 10, ":--label1"); _lv_unknown(d[2], _LV_MSG_LABEL1, :label1, k[1], k[1], [k[1]]); _lv_unknown(d[3], _LV_MSG_LABEL1, :label1, k[2], k[1], [k[1]])
    end

    @testset "[V-W3] the place: a `#~` metaBlock (V05) and an inline metaSegment (V06) refused at the read, the message naming the two places; the place checked before the shape (V40)" begin
        @test _lv_msg("#~ :++label6\nx = 1\n") == raw"""GoMeta absorb: a vocabulary statement (`:++x`, `:(++, x, y)`) is legal at `#~0` and in the user level's profile only — here a metaBlock of depth 1; see docs/public-api.md §3.4"""
        @test _lv_msg("x = 1 #~ :++label6\n") == raw"""GoMeta absorb: a vocabulary statement (`:++x`, `:(++, x, y)`) is legal at `#~0` and in the user level's profile only — here an inline metaSegment; see docs/public-api.md §3.4"""
        # V40 `#~ :++label6{ isCode }` — malformed AND misplaced: the place refusal, the same text as V05's
        @test _lv_msg("#~ :++label6{ isCode }\nx = 1\n") == raw"""GoMeta absorb: a vocabulary statement (`:++x`, `:(++, x, y)`) is legal at `#~0` and in the user level's profile only — here a metaBlock of depth 1; see docs/public-api.md §3.4"""
        @test _lv_msg("#~ :++label6{ isCode }\nx = 1\n") == _lv_msg("#~ :++label6\nx = 1\n")
    end

    @testset "[V-W4] the unknown name after a removal or a declaration (since 0.4.3 reported, not refused): after `:--label1` the use of label1 is reported (V03); after `:++label6` an unknown `:zzz` is reported, label6 known (V22); after `:++label6 :++label6` the same — the second declaration a no-op, ONE info row (V31)" begin
        # AFTER trace V03 `#~0 :--label1⏎#~ :label1⏎x = 1`: 0 rows; 3 diagnostics — the info row (label1 removed, Block #2, level 1, `:--label1`), the plain `:label1` reported at Block #2 / #3
        r3 = _lv_run("#~0 :--label1\n#~ :label1\nx = 1\n"); @test r3.status === GM.PROCESS_OK && isempty(_lv_recs(r3)); k = _lv_keys(r3); d = r3.diagnostics; @test length(d) == 3
        _lv_info(d[1], :removed, :label1, k[1], 1, ":--label1"); _lv_unknown(d[2], _LV_MSG_LABEL1, :label1, k[1], k[1], [k[1]]); _lv_unknown(d[3], _LV_MSG_LABEL1, :label1, k[2], k[1], [k[1]])
        # AFTER trace V22 `#~0 :++label6⏎#~ :zzz⏎x = 1`: 0 rows; 3 diagnostics — the info row (label6 added), the plain `:zzz` reported at Block #2 / #3
        r22 = _lv_run("#~0 :++label6\n#~ :zzz\nx = 1\n"); @test r22.status === GM.PROCESS_OK && isempty(_lv_recs(r22)); k = _lv_keys(r22); d = r22.diagnostics; @test length(d) == 3
        _lv_info(d[1], :added, :label6, k[1], 1, ":++label6"); _lv_unknown(d[2], _LV_MSG_ZZZ, :zzz, k[1], k[1], [k[1]]); _lv_unknown(d[3], _LV_MSG_ZZZ, :zzz, k[2], k[1], [k[1]])
        # AFTER trace V31 `#~0 :++label6 :++label6⏎#~ :zzz⏎x = 1`: as V22 — ONE info row (the second `:++label6` finds the name in the file: nothing written, nothing reported)
        r31 = _lv_run("#~0 :++label6 :++label6\n#~ :zzz\nx = 1\n"); @test r31.status === GM.PROCESS_OK && isempty(_lv_recs(r31)); k = _lv_keys(r31); d = r31.diagnostics; @test length(d) == 3
        _lv_info(d[1], :added, :label6, k[1], 1, ":++label6"); _lv_unknown(d[2], _LV_MSG_ZZZ, :zzz, k[1], k[1], [k[1]]); _lv_unknown(d[3], _LV_MSG_ZZZ, :zzz, k[2], k[1], [k[1]])
        @test startswith(_LV_MSG_ZZZ, "GoMeta apply: the plain `:zzz` had no effect here — not in the Labels Alterant's vocabulary; declare it with `:++zzz` at `#~0` or in the user level's profile, or correct the spelling")   # the accepted set is not listed (one print away in the development tools)
    end

    @testset "[V-W5] the reach: a declaration holds for a later `#~0` metaBlock (V09); a use in an earlier Block is reported — the later declaration read after the earlier Block's apply (V11); a use before a removal on one line is reported (V34)" begin
        # AFTER trace V09 `#~0 :++label6⏎⏎y = 1⏎#~0 :label6⏎x = 1`: 2 rows on Blocks #4 (Meta) and #5 (Code), both decided_by Block #4; the first metaBlock and the Code Block between carry none; 1 info row
        r = _lv_run("#~0 :++label6\n\ny = 1\n#~0 :label6\nx = 1\n"); @test r.status === GM.PROCESS_OK
        bs = _lv_blocks(r); @test length(bs) == 4 && _LV_BLS.kind(bs[1]) === :Meta && _LV_BLS.kind(bs[2]) === :Code
        _lv_two_blocks(r, [:label6]; i = 3); @test length(r.diagnostics) == 1 && r.diagnostics[1].code === :LABELS_VOCABULARY_FILE_CHANGED
        # AFTER trace V11 `#~ :label6⏎x = 1⏎#~0 :++label6⏎y = 1`: 0 rows; 3 diagnostics IN DELIVERY ORDER — the plain `:label6` reported at Block #2 / #3 (applied before the later declaration is read), then the info row (label6 added, stated by Block #4 — the later `#~0` metaBlock)
        r11 = _lv_run("#~ :label6\nx = 1\n#~0 :++label6\ny = 1\n"); @test r11.status === GM.PROCESS_OK && isempty(_lv_recs(r11)); k = _lv_keys(r11); @test length(k) == 4; d = r11.diagnostics; @test length(d) == 3
        _lv_unknown(d[1], _LV_MSG_LABEL6, :label6, k[1], k[1], [k[1]]); _lv_unknown(d[2], _LV_MSG_LABEL6, :label6, k[2], k[1], [k[1]]); _lv_info(d[3], :added, :label6, k[3], 1, ":++label6")
        # AFTER trace V34 `#~0 :label1 :--label1⏎x = 1`: 0 rows; 3 diagnostics — the info row (label1 removed), the plain `:label1` reported at Block #2 / #3 (the removal read before the apply of the metaBlock: the order inside a metaBlock immaterial)
        r34 = _lv_run("#~0 :label1 :--label1\nx = 1\n"); @test r34.status === GM.PROCESS_OK && isempty(_lv_recs(r34)); k = _lv_keys(r34); d = r34.diagnostics; @test length(d) == 3
        _lv_info(d[1], :removed, :label1, k[1], 1, ":--label1"); _lv_unknown(d[2], _LV_MSG_LABEL1, :label1, k[1], k[1], [k[1]]); _lv_unknown(d[3], _LV_MSG_LABEL1, :label1, k[2], k[1], [k[1]])
    end

    @testset "[V-W6] the fold in reading order: `:--label6 :++label6` declares (V12); `:++label6 :--label6` removes (V13); a base name added is a no-op — nothing written, nothing reported (V14); a base name added then removed is removed (V35); a base name removed then added again is back (V41)" begin
        r12 = _lv_run("#~0 :--label6 :++label6\n#~ :label6\nx = 1\n"); @test r12.status === GM.PROCESS_OK; _lv_two_blocks(r12, [:label6]); k = _lv_keys(r12)
        @test length(r12.diagnostics) == 1; _lv_info(r12.diagnostics[1], :added, :label6, k[1], 1, ":++label6")   # `--` of a name never present: nothing written, nothing reported
        # AFTER trace V13 `#~0 :++label6 :--label6⏎#~ :label6⏎x = 1`: 0 rows; 4 diagnostics — label6 added then removed (two info rows), the plain `:label6` reported at Block #2 / #3; the file as before
        r13 = _lv_run("#~0 :++label6 :--label6\n#~ :label6\nx = 1\n"); @test r13.status === GM.PROCESS_OK && isempty(_lv_recs(r13)); k = _lv_keys(r13); d = r13.diagnostics; @test length(d) == 4
        _lv_info(d[1], :added, :label6, k[1], 1, ":++label6"); _lv_info(d[2], :removed, :label6, k[1], 1, ":--label6"); _lv_unknown(d[3], _LV_MSG_LABEL6, :label6, k[1], k[1], [k[1]]); _lv_unknown(d[4], _LV_MSG_LABEL6, :label6, k[2], k[1], [k[1]])
        r14 = _lv_run("#~0 :++label1\n#~ :label1\nx = 1\n"); @test r14.status === GM.PROCESS_OK; _lv_two_blocks(r14, [:label1]); @test isempty(r14.diagnostics)
        # AFTER trace V41 `#~0 :--label1 :++label1⏎#~ :label1⏎x = 1`: a BASE name removed then added again is back — 2 rows label1; 2 info rows (removed, added)
        r41 = _lv_run("#~0 :--label1 :++label1\n#~ :label1\nx = 1\n"); @test r41.status === GM.PROCESS_OK; _lv_two_blocks(r41, [:label1]); k = _lv_keys(r41); d = r41.diagnostics; @test length(d) == 2
        _lv_info(d[1], :removed, :label1, k[1], 1, ":--label1"); _lv_info(d[2], :added, :label1, k[1], 1, ":++label1")
        # AFTER trace V35 `#~0 :++label1 :--label1⏎#~ :label1⏎x = 1`: 0 rows; 3 diagnostics — ONE info row (label1 removed; the `++` of a shipped name wrote nothing), the plain `:label1` reported at Block #2 / #3
        r35 = _lv_run("#~0 :++label1 :--label1\n#~ :label1\nx = 1\n"); @test r35.status === GM.PROCESS_OK && isempty(_lv_recs(r35)); k = _lv_keys(r35); d = r35.diagnostics; @test length(d) == 3
        _lv_info(d[1], :removed, :label1, k[1], 1, ":--label1"); _lv_unknown(d[2], _LV_MSG_LABEL1, :label1, k[1], k[1], [k[1]]); _lv_unknown(d[3], _LV_MSG_LABEL1, :label1, k[2], k[1], [k[1]])
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

    @testset "[V-W9] one line: the use BEFORE the declaration applies (V19 — the order inside a metaBlock immaterial); the one-line bracket `:++label6 :label6 :--label6` is reported (V36)" begin
        r = _lv_run("#~0 :label6 :++label6\nx = 1\n"); @test r.status === GM.PROCESS_OK; _lv_two_blocks(r, [:label6]); @test length(r.diagnostics) == 1; _lv_info(r.diagnostics[1], :added, :label6, _lv_keys(r)[1], 1, ":++label6")   # the AFTER view V19's run section: ONE LABELS_VOCABULARY_FILE_CHANGED info row — label6 added, stated by L1 (Block #2), level 1, the statement `:++label6`
        # AFTER trace V36 `#~0 :++label6 :label6 :--label6⏎x = 1`: 0 rows; 4 diagnostics — added, removed (two info rows), the plain `:label6` reported at Block #2 / #3
        r36 = _lv_run("#~0 :++label6 :label6 :--label6\nx = 1\n"); @test r36.status === GM.PROCESS_OK && isempty(_lv_recs(r36)); k = _lv_keys(r36); d = r36.diagnostics; @test length(d) == 4
        _lv_info(d[1], :added, :label6, k[1], 1, ":++label6"); _lv_info(d[2], :removed, :label6, k[1], 1, ":--label6"); _lv_unknown(d[3], _LV_MSG_LABEL6, :label6, k[1], k[1], [k[1]]); _lv_unknown(d[4], _LV_MSG_LABEL6, :label6, k[2], k[1], [k[1]])
    end

    @testset "[V-W10] the user level against the file: fed `:++label6` then the file's `:--label6` — the use reported (V24); fed `:--label6` then the file's `:++label6` applies (V25); a removal after a use is reported at a later use (V26) and leaves the earlier rows (V26b); a fed `:label1` reported under the file's `:--label1` (V37); a fed `:--label1` then the file's `:++label1` re-admits the BASE name (V46)" begin
        # AFTER trace V24 (profile ":++label6") `#~0 :--label6⏎#~ :label6⏎x = 1`: 0 rows; 4 diagnostics — added from the profile (the user context, level 10), removed by the file (Block #2, level 1), the plain `:label6` reported at Block #2 / #3
        r24 = _lv_run("#~0 :--label6\n#~ :label6\nx = 1\n"; profile = ":++label6"); @test r24.status === GM.PROCESS_OK && isempty(_lv_recs(r24)); k = _lv_keys(r24); d = r24.diagnostics; @test length(d) == 4
        _lv_info(d[1], :added, :label6, _LV_KU, 10, ":++label6"); _lv_info(d[2], :removed, :label6, k[1], 1, ":--label6"); _lv_unknown(d[3], _LV_MSG_LABEL6, :label6, k[1], k[1], [k[1]]); _lv_unknown(d[4], _LV_MSG_LABEL6, :label6, k[2], k[1], [k[1]])
        r25 = _lv_run("#~0 :++label6\n#~ :label6\nx = 1\n"; profile = ":--label6"); @test r25.status === GM.PROCESS_OK; _lv_two_blocks(r25, [:label6]); k = _lv_keys(r25)
        @test length(r25.diagnostics) == 1; _lv_info(r25.diagnostics[1], :added, :label6, k[1], 1, ":++label6")   # the fed `--` of a name never present writes nothing
        # V46 (MEASURED FIRST): the file's `++` re-admits a BASE name the profile removed — 2 rows label1; 2 info rows (removed from the profile, added by the file)
        r46 = _lv_run("#~0 :++label1\n#~ :label1\nx = 1\n"; profile = ":--label1"); @test r46.status === GM.PROCESS_OK; _lv_two_blocks(r46, [:label1]); k = _lv_keys(r46); d = r46.diagnostics; @test length(d) == 2
        _lv_info(d[1], :removed, :label1, _LV_KU, 10, ":--label1"); _lv_info(d[2], :added, :label1, k[1], 1, ":++label1")
        # AFTER trace V26 `#~ :label1⏎x = 1⏎#~0 :--label1⏎#~ :label1⏎y = 1`: 2 rows (label1 on Blocks #2 / #3); 3 diagnostics — the info row stated by Block #4, the plain `:label1` reported at Block #4 / #5
        r26 = _lv_run("#~ :label1\nx = 1\n#~0 :--label1\n#~ :label1\ny = 1\n"); @test r26.status === GM.PROCESS_OK; k = _lv_keys(r26); @test length(k) == 4; _lv_two_blocks(r26, [:label1]); d = r26.diagnostics; @test length(d) == 3
        _lv_info(d[1], :removed, :label1, k[3], 1, ":--label1"); _lv_unknown(d[2], _LV_MSG_LABEL1, :label1, k[3], k[3], [k[3]]); _lv_unknown(d[3], _LV_MSG_LABEL1, :label1, k[4], k[3], [k[3]])
        # AFTER trace V26b `#~ :label1⏎x = 1⏎#~0 :--label1⏎y = 1`: 2 rows on Blocks #2 / #3 (label1), the later metaBlock and its Code Block none; 1 info row
        r26b = _lv_run("#~ :label1\nx = 1\n#~0 :--label1\ny = 1\n"); @test r26b.status === GM.PROCESS_OK
        @test length(_lv_blocks(r26b)) == 4; _lv_two_blocks(r26b, [:label1]); @test length(r26b.diagnostics) == 1 && r26b.diagnostics[1].code === :LABELS_VOCABULARY_FILE_CHANGED
        # AFTER trace V37 (profile ":label1") `#~0 :--label1⏎x = 1`: 0 rows; 3 diagnostics — the info row (Block #2, level 1), the fed plain `:label1` reported at Block #2 / #3 — stated by the user context, statements [the user context]
        r37 = _lv_run("#~0 :--label1\nx = 1\n"; profile = ":label1"); @test r37.status === GM.PROCESS_OK && isempty(_lv_recs(r37)); k = _lv_keys(r37); d = r37.diagnostics; @test length(d) == 3
        _lv_info(d[1], :removed, :label1, k[1], 1, ":--label1"); _lv_unknown(d[2], _LV_MSG_LABEL1, :label1, k[1], _LV_KU, [_LV_KU]); _lv_unknown(d[3], _LV_MSG_LABEL1, :label1, k[2], _LV_KU, [_LV_KU])
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

    @testset "[V-W13] two `goMeta` calls: on DIFFERENT user files nothing carries over (V01 and V07, then `#~ :label6` alone on a fresh file is reported — V28); on the SAME file a vocabulary statement PERSISTS (V04's `:--label1`, then `#~ :label1` on that file reported; labels_vocabulary_file_tests.jl holds the file's witnesses); the base behind `base_vocabulary()` is the run's user file, 46 names" begin
        r1 = _lv_run(_LV_V01); @test r1.status === GM.PROCESS_OK
        r7 = _lv_run("#~ :label6\nx = 1\n"; profile = ":++label6"); @test r7.status === GM.PROCESS_OK   # V07 fed, run IMMEDIATELY before the un-fed run of the same document below — the oracle's order (V28 stands right after V07)
        # AFTER trace V28 on a FRESH file: 0 rows; 2 warning rows — the plain `:label6` reported at Block #2 / #3
        r28 = _lv_run("#~ :label6\nx = 1\n"); @test r28.status === GM.PROCESS_OK && isempty(_lv_recs(r28)); k = _lv_keys(r28); d = r28.diagnostics; @test length(d) == 2
        _lv_unknown(d[1], _LV_MSG_LABEL6, :label6, k[1], k[1], [k[1]]); _lv_unknown(d[2], _LV_MSG_LABEL6, :label6, k[2], k[1], [k[1]])
        @test length(GM.Alterants.base_vocabulary()) == 46 && :label6 ∉ GM.Alterants.base_vocabulary()   # the fresh file's names: the shipped 46 (the user level's copy of the shipped file)
        r4 = _lv_run("#~0 :--label1\nx = 1\n"); @test r4.status === GM.PROCESS_OK && isempty(_lv_recs(r4)) && length(r4.diagnostics) == 1     # AFTER trace V04: 0 rows, the info row
        r5 = GM.goMeta(_lv_bytes("#~ :label1\nx = 1\n"))   # NO fresh file — the file r4 edited: label1 removed for good, the use reported
        @test r5.status === GM.PROCESS_OK && isempty(_lv_recs(r5)) && length(r5.diagnostics) == 2 && all(x -> x.code === :LABEL_NOT_APPLIED_UNKNOWN, r5.diagnostics)
        r = _lv_run("#~ :label1\nx = 1\n"); @test r.status === GM.PROCESS_OK; _lv_two_blocks(r, [:label1])   # a fresh file again: label1 shipped
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

    @testset "[V-W16] the hook called directly (MEASURED: the F set and the RP set; the fold's three shapes V12 / V13 / V35): the delta kept apart — base, added, removed — and the run state returned WITH the `:info` rows of a persisted change (the one grammar of a hook's return; the state alone where the file is unchanged); a plain label and a quoted token handed back; the place and the malformed shapes refused with the same texts; a declared name carrying an invisible character inside refused" begin
        TestSupport.fresh_vocabulary!()   # the hook's direct calls persist into the named file
        D = GM.Alterants.declareLabels!
        ret = D(nothing, 1, :(:), (Symbol("++label6"),), false)
        @test ret isa Tuple && length(ret) == 2 && ret[1] isa GM.Alterants.LabelsVocabulary && ret[2] isa Vector{GM.Diagnostic} && length(ret[2]) == 1
        v = ret[1]; @test v.added == [:label6] && isempty(v.removed) && length(v.effective) == 47 && v.effective[end] === :label6 && length(v.base) == 46 && length(GM.Alterants.base_vocabulary()) == 47 && v.base !== GM.Alterants.base_vocabulary()   # the write renamed a new file over the old: the memo re-reads (F18 — 46 → 47, a new object)
        @test ret[2][1].code === :LABELS_VOCABULARY_FILE_CHANGED && ret[2][1].severity === :info && ret[2][1].context == (file = ENV["GOMETA_LABELS_VOCABULARY"], change = :added, label = :label6)   # the hook's own context — the Engine merges the read-time place at the door
        ret2 = D(v, 1, :(:), (Symbol("--"), :label1), false)
        @test ret2 isa Tuple && ret2[1] === v && v.added == [:label6] && v.removed == [:label1] && length(v.effective) == 46 && :label1 ∉ v.effective && ret2[2][1].context.change === :removed && ret2[2][1].context.label === :label1
        @test D(v, 1, :(:), (Symbol("++"), :label6), false) === v   # label6 is in the file now: nothing written, the state alone returned
        # the delta after the fold's three shapes, each on a fresh file: V12 `:--label6 :++label6`, V13 `:++label6 :--label6`, V35 `:++label1 :--label1` — added / removed / |effective|: [:label6] / [] / 47; [] / [] / 46; [] / [:label1] / 45 (MEASURED: the RP set)
        st(x) = x isa Tuple ? x[1] : x
        seq(a, b) = (TestSupport.fresh_vocabulary!(); st(D(st(D(nothing, 1, :(:), (Symbol(a),), false)), 1, :(:), (Symbol(b),), false)))
        v12 = seq("--label6", "++label6"); @test v12.added == [:label6] && isempty(v12.removed) && length(v12.effective) == 47
        v13 = seq("++label6", "--label6"); @test isempty(v13.added) && isempty(v13.removed) && length(v13.effective) == 46
        v35 = seq("++label1", "--label1"); @test isempty(v35.added) && v35.removed == [:label1] && length(v35.effective) == 45
        TestSupport.fresh_vocabulary!(); w0 = st(D(nothing, 1, :(:), (Symbol("++label6"),), false))
        @test D(w0, 1, :(:), (:label1,), false) === nothing && D(w0, 1, :(:), (Symbol("++"), "x"), false) === nothing
        @test st(D(nothing, 10, :(:), (Symbol("++label7"),), false)) isa GM.Alterants.LabelsVocabulary
        refusal(f) = try; f(); nothing; catch e; sprint(showerror, e); end
        @test refusal(() -> D(nothing, 2, :(:), (Symbol("++label6"),), false)) == raw"""GoMeta absorb: a vocabulary statement (`:++x`, `:(++, x, y)`) is legal at `#~0` and in the user level's profile only — here a metaBlock of depth 1; see docs/public-api.md §3.4"""
        @test refusal(() -> D(nothing, 11, :(:), (Symbol("++label6"),), false)) == raw"""GoMeta absorb: a vocabulary statement (`:++x`, `:(++, x, y)`) is legal at `#~0` and in the user level's profile only — here an inline metaSegment; see docs/public-api.md §3.4"""
        @test refusal(() -> D(nothing, 1, :(:), (Symbol("++label6"), :label7), false)) == raw"""GoMeta absorb: the prefixed vocabulary statement `:++label6` takes one name — 2 arguments given (the list form is `:(++, x, y)`); see docs/public-api.md §3.4"""
        @test refusal(() -> D(nothing, 1, :(:), (Symbol("++"),), false)) == raw"""GoMeta absorb: the vocabulary statement `:++` names no label — the forms are `:++x` and `:(++, x, y)`; see docs/public-api.md §3.4"""
        @test refusal(() -> D(nothing, 1, :(:), (Symbol("++"), :label6, Symbol("--label7")), false)) == raw"""GoMeta absorb: a label name in a vocabulary statement may not begin with `+` or `-` — got "--label7" in `:++`; see docs/public-api.md §3.4"""
        @test refusal(() -> D(nothing, 1, :(:), (Symbol("++label6"),), true)) == raw"""GoMeta absorb: a vocabulary statement takes no condition — `:++label6{ … }` (a declaration is a fact of the run, not of a Component); see docs/public-api.md §3.4"""
        # a declared name beginning with `#` (the vocabulary file reads such a line as a comment): refused (PC03 of the PC set)
        @test refusal(() -> D(nothing, 1, :(:), (Symbol("++#x"),), false)) == raw"""GoMeta absorb: a label name in a vocabulary statement may not begin with `#` — got "#x" in `:++#x` (the vocabulary file reads a line beginning with `#` as a comment); see docs/public-api.md §3.4"""
        # a declared name carrying a zero-width space INSIDE (the argument-edge class; the name shown by its escape): refused (T12 of the DT set)
        @test refusal(() -> D(nothing, 1, :(:), (Symbol("++zz" * string(Char(0x200B)) * "z"),), false)) == raw"""GoMeta absorb: a label name in a vocabulary statement may not carry white space or an invisible character inside — got "zz\u200bz" in `:++zz\u200bz`; see docs/public-api.md §3.4"""
        TestSupport.fresh_vocabulary!(); w = GM.Alterants.LabelsVocabulary(); @test w.effective === w.base && length(GM.Alterants.LabelsInstance().vocab.effective) == 46   # a fresh file: the shipped 46
    end
end
