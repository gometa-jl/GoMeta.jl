# labels_unknown_tests.jl — THE UNKNOWN LABEL OF THE LABELS ALTERANT (0.4.3) — the creator's design: a name outside the run's vocabulary
# (never declared, removed, misspelled, or carrying an invisible separator swallowed inside) is NOT refused; it is SKIPPED under every verb and
# REPORTED by ONE warning diagnostic per name occurrence at each affected Component, the run proceeding PROCESS_OK; a list applies its other
# names; the message renders the statement's form per verb — the plain `:zzz`, the withhold `:-zzz`, the explicit `:+zzz` — and the remedy, the
# accepted set not listed; an EMPTY member of a plain list (a stray comma) is a SHAPE and is refused as in the signed lists; a QUERIED unknown
# name answers false silently as before. The code: src/alterants-std/labels.jl (`setLabels(::LabelsInstance, …)` — the vocabulary check per
# name; `_unknown_message`), src/alterants/apply.jl (the door), src/state.jl (`_deliver_diagnostics!`).
#
# IS:   eleven witnesses [N1]–[N11] over the public entry, EVERY expected value READ from the measured printouts of the built tree (the FULL
#       delivery views and the `decided_by` traces with their diagnostics blocks — the U set U01 … U33, the DT set T08); every refusal message
#       and every diagnostic message a byte-exact copy of its printout, never retyped — the `raw"""…"""` literals below. Every document runs
#       on a FRESH user-level vocabulary file (a vocabulary statement persists since 0.4.3). THE PLAIN UNKNOWN and the misspelling ([N1]); A
#       LIST applies its other names ([N2]); a name written twice, two unknown names ([N3]); deeper and at the file level ([N4]); INLINE
#       ([N5]); THE FED forms ([N6]); THE SIGNED forms and the removed name under them ([N7]); the conditional form, the query role unchanged
#       ([N8]); THE STRAY COMMA of a plain list ([N9]); THE SWALLOWED SEPARATORS reported with their escapes, a trailing one trimmed ([N10]);
#       a removed name in a list ([N11]).
# REASONING: the setter's per-name check turns the former refusal (naming the accepted set) into a reported skip — one row per name occurrence
#       through the same door as the withheld rows (the place: the applying Component, the stating statement, the Labels statements applied
#       there so far); nothing else of the setter moved — the shapes keep their refusals (labels_withhold_tests.jl [B-W9]).
# PURPOSE: the unknown label, measured — never inferred from the setter's docstring or from prose.

using Test
import GoMeta as GM
const _UN_BLS = GM.BLS

_un_bytes(s::String) = Vector{UInt8}(codeunits(s))
_un_run(s::String; profile = nothing) = (TestSupport.fresh_vocabulary!(); GM.goMeta(_un_bytes(s); config = GM.GoMetaConfig(; user_mh_profile = profile)))
_un_msg(s::String) = try; _un_run(s); nothing; catch e; sprint(showerror, e); end
_un_recs(r) = collect(r.altValues_evals.records)
_un_key(r, c) = GM.key_bytes(GM.occurrence_key(r.blsComponentTree, c))
_un_blocks(r) = _UN_BLS.children(r.blsComponentTree)
_un_keys(r) = [_un_key(r, b) for b in _un_blocks(r)]      # k[i] = the i-th Block's handle = Block #(i+1) of the FULL delivery view
_un_rows(r, h) = [x for x in _un_recs(r) if x.cell_handle == h]
_un_labels(r, h) = Set(x.attr for x in _un_rows(r, h))
const _UN_KU = GM.key_bytes(GM.user_context_key(:default, 1))
"one `LABEL_NOT_APPLIED_UNKNOWN` warning row: the code, the severity, the message bytes (the measured printout), the context — the label, the Component (`cell`), the stating statement (`stated_by`), the Labels statements applied there so far (`statements`)"
function _un_warn(d, msg::String, label::Symbol, cell::Vector{UInt8}, stated_by::Vector{UInt8}, statements::Vector{Vector{UInt8}})
    @test d.code === :LABEL_NOT_APPLIED_UNKNOWN && d.severity === :warning && d.message == msg
    @test d.context == (label = label, cell = cell, stated_by = stated_by, statements = statements)
end
## the messages, byte-exact from the measured traces
const _UN_PLAIN_ZZZ = raw"""GoMeta apply: the plain `:zzz` had no effect here — not in the Labels Alterant's vocabulary; declare it with `:++zzz` at `#~0` or in the user level's profile, or correct the spelling; see docs/public-api.md §3.4"""
const _UN_PLAIN_LABE1 = raw"""GoMeta apply: the plain `:labe1` had no effect here — not in the Labels Alterant's vocabulary; declare it with `:++labe1` at `#~0` or in the user level's profile, or correct the spelling; see docs/public-api.md §3.4"""
const _UN_PLAIN_LABEL1 = raw"""GoMeta apply: the plain `:label1` had no effect here — not in the Labels Alterant's vocabulary; declare it with `:++label1` at `#~0` or in the user level's profile, or correct the spelling; see docs/public-api.md §3.4"""
const _UN_EXPLICIT_ZZZ = raw"""GoMeta apply: the explicit `:+zzz` had no effect here — not in the Labels Alterant's vocabulary; declare it with `:++zzz` at `#~0` or in the user level's profile, or correct the spelling; see docs/public-api.md §3.4"""
const _UN_WITHHOLD_ZZZ = raw"""GoMeta apply: the withhold `:-zzz` had no effect here — not in the Labels Alterant's vocabulary; declare it with `:++zzz` at `#~0` or in the user level's profile, or correct the spelling; see docs/public-api.md §3.4"""
const _UN_EXPLICIT_LABEL1 = raw"""GoMeta apply: the explicit `:+label1` had no effect here — not in the Labels Alterant's vocabulary; declare it with `:++label1` at `#~0` or in the user level's profile, or correct the spelling; see docs/public-api.md §3.4"""
const _UN_WITHHOLD_LABEL1 = raw"""GoMeta apply: the withhold `:-label1` had no effect here — not in the Labels Alterant's vocabulary; declare it with `:++label1` at `#~0` or in the user level's profile, or correct the spelling; see docs/public-api.md §3.4"""

@testset "the unknown label of the Labels Alterant (0.4.3)" begin

    @testset "[N1] the plain unknown name (U01 `#~ :zzz`) and the misspelling (U02 `#~ :labe1`): nothing applied, the run proceeds — one warning row per affected Component (the metaBlock and the Code Block attached to it), the message naming the statement and the remedy, the accepted set not listed" begin
        # AFTER trace U01: PROCESS_OK, 0 rows; 2 diagnostics LABEL_NOT_APPLIED_UNKNOWN — cell Block #2 / #3, stated_by Block #2, statements [#2]
        r = _un_run("#~ :zzz\nx = 1\n"); @test r.status === GM.PROCESS_OK && isempty(_un_recs(r)); k = _un_keys(r); d = r.diagnostics; @test length(d) == 2
        _un_warn(d[1], _UN_PLAIN_ZZZ, :zzz, k[1], k[1], [k[1]]); _un_warn(d[2], _UN_PLAIN_ZZZ, :zzz, k[2], k[1], [k[1]])
        @test _UN_PLAIN_ZZZ == "GoMeta apply: the plain `:zzz` had no effect here — not in the Labels Alterant's vocabulary; declare it with `:++zzz` at `#~0` or in the user level's profile, or correct the spelling; see docs/public-api.md §3.4"
        @test !occursin("accepted set", _UN_PLAIN_ZZZ)
        # AFTER trace U02: the same shape for `labe1`
        r = _un_run("#~ :labe1\nx = 1\n"); @test r.status === GM.PROCESS_OK && isempty(_un_recs(r)); k = _un_keys(r); d = r.diagnostics; @test length(d) == 2
        _un_warn(d[1], _UN_PLAIN_LABE1, :labe1, k[1], k[1], [k[1]]); _un_warn(d[2], _UN_PLAIN_LABE1, :labe1, k[2], k[1], [k[1]])
        @test _un_msg("#~ :zzz\nx = 1\n") === nothing   # no refusal
    end

    @testset "[N2] a list applies its other names and reports the unknown one (U04 `#~ :(label1, zzz, label2)`): label1 and label2 on both Blocks, decided by the metaBlock; two warning rows for zzz" begin
        # AFTER trace U04: 4 rows — label_label2, label_label1 on Block #2 and on Block #3, each decided_by [Block #2]; 2 diagnostics for zzz — cell #2 / #3, stated_by #2, statements [#2]
        r = _un_run("#~ :(label1, zzz, label2)\nx = 1\n"); @test r.status === GM.PROCESS_OK && length(_un_recs(r)) == 4; k = _un_keys(r)
        for h in (k[1], k[2]); @test _un_labels(r, h) == Set([:label_label1, :label_label2]) && all(x -> x.decided_by == [k[1]] && x.value === true, _un_rows(r, h)); end
        @test GM.evaluatedAltValue(r, _un_blocks(r)[1], :labels).value == [:label1, :label2]
        d = r.diagnostics; @test length(d) == 2; _un_warn(d[1], _UN_PLAIN_ZZZ, :zzz, k[1], k[1], [k[1]]); _un_warn(d[2], _UN_PLAIN_ZZZ, :zzz, k[2], k[1], [k[1]])
    end

    @testset "[N3] a name written twice is reported twice (U28 `#~ :zzz :zzz`); two unknown names in a list, each reported (U27 `#~ :(zzz, yyy)`)" begin
        # AFTER trace U28: 0 rows; 4 diagnostics — Block #2 twice, Block #3 twice (the statements applied so far: the first [#2], the second [#2, #2])
        r = _un_run("#~ :zzz :zzz\nx = 1\n"); @test r.status === GM.PROCESS_OK && isempty(_un_recs(r)); k = _un_keys(r); d = r.diagnostics; @test length(d) == 4
        _un_warn(d[1], _UN_PLAIN_ZZZ, :zzz, k[1], k[1], [k[1]]); _un_warn(d[2], _UN_PLAIN_ZZZ, :zzz, k[1], k[1], [k[1], k[1]])
        _un_warn(d[3], _UN_PLAIN_ZZZ, :zzz, k[2], k[1], [k[1]]); _un_warn(d[4], _UN_PLAIN_ZZZ, :zzz, k[2], k[1], [k[1], k[1]])
        # AFTER trace U27: 0 rows; 4 diagnostics — zzz then yyy at Block #2, zzz then yyy at Block #3 (the token order)
        r = _un_run("#~ :(zzz, yyy)\nx = 1\n"); @test r.status === GM.PROCESS_OK && isempty(_un_recs(r)); k = _un_keys(r); d = r.diagnostics; @test length(d) == 4
        @test [(x.context.label, x.context.cell) for x in d] == [(:zzz, k[1]), (:yyy, k[1]), (:zzz, k[2]), (:yyy, k[2])] && all(x -> x.code === :LABEL_NOT_APPLIED_UNKNOWN && x.context.stated_by == k[1] && x.context.statements == [k[1]], d)
        @test occursin("the plain `:yyy` had no effect here", d[2].message)
    end

    @testset "[N4] deeper (U03): the depth-2 `:zzz` under a depth-1 `:label1` — label1 on all four Blocks, the warnings at the depth-2 pair with both statements recorded; at the file level (U33 `#~0 :zzz`): two warnings" begin
        # AFTER trace U03 `#~ :label1⏎a = 1⏎#~2 :zzz⏎b = 2`: 4 rows label1 — Blocks #2 / #3 decided_by [#2], Blocks #4 / #5 decided_by [#2, #4]; 2 diagnostics — cell #4 / #5, stated_by #4, statements [#2, #4]
        r = _un_run("#~ :label1\na = 1\n#~2 :zzz\nb = 2\n"); @test r.status === GM.PROCESS_OK && length(_un_recs(r)) == 4; k = _un_keys(r); @test length(k) == 4
        @test all(x -> x.attr === :label_label1, _un_recs(r)) && [x.decided_by for x in _un_recs(r)] == [[k[1]], [k[1]], [k[1], k[3]], [k[1], k[3]]]
        d = r.diagnostics; @test length(d) == 2; _un_warn(d[1], _UN_PLAIN_ZZZ, :zzz, k[3], k[3], [k[1], k[3]]); _un_warn(d[2], _UN_PLAIN_ZZZ, :zzz, k[4], k[3], [k[1], k[3]])
        # AFTER trace U33: 0 rows; 2 diagnostics — cell Block #2 / #3, stated_by Block #2 (the `#~0` metaBlock), statements [#2]
        r = _un_run("#~0 :zzz\nx = 1\n"); @test r.status === GM.PROCESS_OK && isempty(_un_recs(r)); k = _un_keys(r); d = r.diagnostics; @test length(d) == 2
        _un_warn(d[1], _UN_PLAIN_ZZZ, :zzz, k[1], k[1], [k[1]]); _un_warn(d[2], _UN_PLAIN_ZZZ, :zzz, k[2], k[1], [k[1]])
    end

    @testset "[N5] inline (U10 `x = 1 #~ :zzz`): ONE warning row at the Line — its key with the trailing metaSegment as the origin, the stating statement the Segment, the statements [the Segment]" begin
        # AFTER trace U10: 0 rows; 1 diagnostic — cell the Line (grain Line, origin the Segment), stated_by the Segment
        r = _un_run("x = 1 #~ :zzz\ny = 2\n"); @test r.status === GM.PROCESS_OK && isempty(_un_recs(r)); k = _un_keys(r); d = r.diagnostics; @test length(d) == 1
        l = _UN_BLS.children(r.blsComponentTree, _un_blocks(r)[1])[1]; seg = _UN_BLS.children(r.blsComponentTree, l)[2]
        kL = GM.key_bytes(GM.occurrence_key(r.blsComponentTree, l; origin = seg)); kS = _un_key(r, seg)
        _un_warn(d[1], _UN_PLAIN_ZZZ, :zzz, kL, kS, [kS]); @test !(kL in k)
    end

    @testset "[N6] the fed forms: a fed plain `:zzz` over a file's `:label1` (U05) — label1 applied with the user level among its deciders, the warnings stated by the user level; a fed withhold `:-zzz` (U30) the same; a fed `:zzz` and the file's `:zzz` (U31) — four warnings, the fed ones first at each Block" begin
        # AFTER trace U05 (profile ":zzz"): 2 rows label1 on Blocks #2 / #3, decided_by [the user level, #2]; 2 diagnostics — cell #2 / #3, stated_by the user level, statements [the user level]
        r = _un_run("#~ :label1\nx = 1\n"; profile = ":zzz"); @test r.status === GM.PROCESS_OK && length(_un_recs(r)) == 2; k = _un_keys(r)
        @test all(x -> x.attr === :label_label1 && x.decided_by == [_UN_KU, k[1]], _un_recs(r))
        d = r.diagnostics; @test length(d) == 2; _un_warn(d[1], _UN_PLAIN_ZZZ, :zzz, k[1], _UN_KU, [_UN_KU]); _un_warn(d[2], _UN_PLAIN_ZZZ, :zzz, k[2], _UN_KU, [_UN_KU])
        # AFTER trace U30 (profile ":-zzz"): the same rows; the message names the withhold
        r = _un_run("#~ :label1\nx = 1\n"; profile = ":-zzz"); @test r.status === GM.PROCESS_OK && length(_un_recs(r)) == 2; k = _un_keys(r)
        d = r.diagnostics; @test length(d) == 2; _un_warn(d[1], _UN_WITHHOLD_ZZZ, :zzz, k[1], _UN_KU, [_UN_KU]); _un_warn(d[2], _UN_WITHHOLD_ZZZ, :zzz, k[2], _UN_KU, [_UN_KU])
        # AFTER trace U31 (profile ":zzz") `#~ :zzz⏎x = 1`: 0 rows; 4 diagnostics — at Block #2 the fed one (stated_by the user level, statements [the user level]) then the file's (stated_by #2, statements [the user level, #2]); at Block #3 the same pair
        r = _un_run("#~ :zzz\nx = 1\n"; profile = ":zzz"); @test r.status === GM.PROCESS_OK && isempty(_un_recs(r)); k = _un_keys(r); d = r.diagnostics; @test length(d) == 4
        _un_warn(d[1], _UN_PLAIN_ZZZ, :zzz, k[1], _UN_KU, [_UN_KU]); _un_warn(d[2], _UN_PLAIN_ZZZ, :zzz, k[1], k[1], [_UN_KU, k[1]])
        _un_warn(d[3], _UN_PLAIN_ZZZ, :zzz, k[2], _UN_KU, [_UN_KU]); _un_warn(d[4], _UN_PLAIN_ZZZ, :zzz, k[2], k[1], [_UN_KU, k[1]])
    end

    @testset "[N7] the signed forms of an unknown name — reported and skipped under every verb (the one law): `:+zzz` (U11), `:-zzz` (U12), the list `:(-, label1, zzz)` withholding label1 and reporting zzz (U15); the removed name under the signed forms: after `#~0 :--label1`, `:+label1` (U13) and `:-label1` (U14) — the removal's info row first" begin
        # AFTER traces U11 / U12: 0 rows; 2 diagnostics each — the messages name the explicit `:+zzz` / the withhold `:-zzz`
        r = _un_run("#~ :+zzz\nx = 1\n"); @test r.status === GM.PROCESS_OK && isempty(_un_recs(r)); k = _un_keys(r); d = r.diagnostics; @test length(d) == 2
        _un_warn(d[1], _UN_EXPLICIT_ZZZ, :zzz, k[1], k[1], [k[1]]); _un_warn(d[2], _UN_EXPLICIT_ZZZ, :zzz, k[2], k[1], [k[1]])
        @test startswith(_UN_EXPLICIT_ZZZ, "GoMeta apply: the explicit `:+zzz` had no effect here")
        r = _un_run("#~ :-zzz\nx = 1\n"); @test r.status === GM.PROCESS_OK && isempty(_un_recs(r)); k = _un_keys(r); d = r.diagnostics; @test length(d) == 2
        _un_warn(d[1], _UN_WITHHOLD_ZZZ, :zzz, k[1], k[1], [k[1]]); _un_warn(d[2], _UN_WITHHOLD_ZZZ, :zzz, k[2], k[1], [k[1]])
        @test startswith(_UN_WITHHOLD_ZZZ, "GoMeta apply: the withhold `:-zzz` had no effect here")
        # AFTER trace U15 `#~ :(-, label1, zzz)⏎x = 1`: 0 rows (label1 withheld, nothing applied); 2 diagnostics for zzz — the withhold's message
        r = _un_run("#~ :(-, label1, zzz)\nx = 1\n"); @test r.status === GM.PROCESS_OK && isempty(_un_recs(r)); k = _un_keys(r); d = r.diagnostics; @test length(d) == 2
        _un_warn(d[1], _UN_WITHHOLD_ZZZ, :zzz, k[1], k[1], [k[1]]); _un_warn(d[2], _UN_WITHHOLD_ZZZ, :zzz, k[2], k[1], [k[1]])
        # AFTER traces U13 / U14 `#~0 :--label1⏎⏎#~ :+label1⏎x = 1` and the withhold twin: 0 rows; 3 diagnostics — the info row (label1 removed from the run's file; stated by Block #2, level 1), then the signed statement reported at Block #3 / #4 (stated_by Block #3, statements [#3])
        for (doc, msg) in (("#~0 :--label1\n\n#~ :+label1\nx = 1\n", _UN_EXPLICIT_LABEL1), ("#~0 :--label1\n\n#~ :-label1\nx = 1\n", _UN_WITHHOLD_LABEL1))
            r = _un_run(doc); @test r.status === GM.PROCESS_OK && isempty(_un_recs(r)); k = _un_keys(r); @test length(k) == 3; d = r.diagnostics; @test length(d) == 3
            @test d[1].code === :LABELS_VOCABULARY_FILE_CHANGED && d[1].severity === :info && d[1].context == (file = ENV["GOMETA_LABELS_VOCABULARY"], change = :removed, label = :label1, stated_by = k[1], level = 1, statement = ":--label1")
            _un_warn(d[2], msg, :label1, k[2], k[2], [k[2]]); _un_warn(d[3], msg, :label1, k[3], k[2], [k[2]])
        end
        @test startswith(_UN_EXPLICIT_LABEL1, "GoMeta apply: the explicit `:+label1` had no effect here") && startswith(_UN_WITHHOLD_LABEL1, "GoMeta apply: the withhold `:-label1` had no effect here")
    end

    @testset "[N8] the conditional form (U29 `#~ :zzz{ isCode }`): the statement fires at the Code Block alone — ONE warning row there; the query role unchanged (U08 `#~ :label1 hide{ :zzz }`): the unknown name answers false silently — the label rows, no visib row, no diagnostic" begin
        # AFTER trace U29: 0 rows; 1 diagnostic — cell Block #3 (the Code Block, where the condition holds), stated_by Block #2, statements [#2]
        r = _un_run("#~ :zzz{ isCode }\nx = 1\n"); @test r.status === GM.PROCESS_OK && isempty(_un_recs(r)); k = _un_keys(r); d = r.diagnostics; @test length(d) == 1
        _un_warn(d[1], _UN_PLAIN_ZZZ, :zzz, k[2], k[1], [k[1]])
        # AFTER trace U08: 2 rows label1 (Blocks #2 / #3), no visib row, 0 diagnostics
        r = _un_run("#~ :label1 hide{ :zzz }\nx = 1\n"); @test r.status === GM.PROCESS_OK && length(_un_recs(r)) == 2 && all(x -> x.attr === :label_label1, _un_recs(r)) && isempty(r.diagnostics)
    end

    @testset "[N9] the stray comma of a PLAIN list is a SHAPE refusal (since 0.4.3; before it the empty name met the unknown-label refusal): `:(,)` (U16), `:(label1, )` (U17), `:(, label1)` (U18) — the plain forms named" begin
        @test _un_msg("#~ :(,)\nx = 1\n") == raw"""GoMeta apply: the label statement `:(, )` names an empty label (a stray comma) — the forms are `:x` and `:(x, y)`; see docs/public-api.md §3.4"""
        @test _un_msg("#~ :(label1, )\nx = 1\n") == raw"""GoMeta apply: the label statement `:(label1, )` names an empty label (a stray comma) — the forms are `:x` and `:(x, y)`; see docs/public-api.md §3.4"""
        @test _un_msg("#~ :(, label1)\nx = 1\n") == raw"""GoMeta apply: the label statement `:(, label1)` names an empty label (a stray comma) — the forms are `:x` and `:(x, y)`; see docs/public-api.md §3.4"""
    end

    @testset "[N10] the swallowed invisible separators (U19 U+2028, U20 U+2029, U21 U+180E — the reader sees no boundary, the run of characters one name): reported as an unknown name with the escape shown, not applied, the word after the separator lost with it; a TRAILING separator is trimmed by the Engine's reader (U22): the clean name applies; an inner zero-width space (T08) reported likewise" begin
        for (cp, msg) in ((0x2028, raw"""GoMeta apply: the plain `:label1\u2028hide` had no effect here — not in the Labels Alterant's vocabulary; declare it with `:++label1\u2028hide` at `#~0` or in the user level's profile, or correct the spelling; see docs/public-api.md §3.4"""), (0x2029, raw"""GoMeta apply: the plain `:label1\u2029hide` had no effect here — not in the Labels Alterant's vocabulary; declare it with `:++label1\u2029hide` at `#~0` or in the user level's profile, or correct the spelling; see docs/public-api.md §3.4"""), (0x180E, raw"""GoMeta apply: the plain `:label1\u180ehide` had no effect here — not in the Labels Alterant's vocabulary; declare it with `:++label1\u180ehide` at `#~0` or in the user level's profile, or correct the spelling; see docs/public-api.md §3.4"""))
            r = _un_run("#~ :label1" * string(Char(cp)) * "hide\nx = 1\n"); @test r.status === GM.PROCESS_OK && isempty(_un_recs(r)); k = _un_keys(r); d = r.diagnostics; @test length(d) == 2
            n = Symbol("label1" * string(Char(cp)) * "hide")
            _un_warn(d[1], msg, n, k[1], k[1], [k[1]]); _un_warn(d[2], msg, n, k[2], k[1], [k[1]])
            @test occursin("`:label1" * string(Char(92)) * "u" * lowercase(string(cp, base = 16, pad = 4)) * "hide`", msg)   # the escape shown, never the invisible character
        end
        # AFTER trace U22 `#~ :label1<U+2028>⏎x = 1`: 2 rows label1, 0 diagnostics — the trailing separator trimmed at the argument's edge
        r = _un_run("#~ :label1" * string(Char(0x2028)) * "\nx = 1\n"); @test r.status === GM.PROCESS_OK && length(_un_recs(r)) == 2 && all(x -> x.attr === :label_label1, _un_recs(r)) && isempty(r.diagnostics)
        # AFTER trace T08 `#~ :label<U+200B>1⏎x = 1`: 0 rows; 2 diagnostics with the escape
        r = _un_run("#~ :label" * string(Char(0x200B)) * "1\nx = 1\n"); @test r.status === GM.PROCESS_OK && isempty(_un_recs(r)); k = _un_keys(r); d = r.diagnostics; @test length(d) == 2
        n = Symbol("label" * string(Char(0x200B)) * "1"); _un_warn(d[1], raw"""GoMeta apply: the plain `:label\u200b1` had no effect here — not in the Labels Alterant's vocabulary; declare it with `:++label\u200b1` at `#~0` or in the user level's profile, or correct the spelling; see docs/public-api.md §3.4""", n, k[1], k[1], [k[1]]); _un_warn(d[2], raw"""GoMeta apply: the plain `:label\u200b1` had no effect here — not in the Labels Alterant's vocabulary; declare it with `:++label\u200b1` at `#~0` or in the user level's profile, or correct the spelling; see docs/public-api.md §3.4""", n, k[2], k[1], [k[1]])
    end

    @testset "[N11] a removed name inside a list (U32 `#~0 :--label1⏎⏎#~ :(label1, label2)`): label2 applies on the depth-1 pair, label1 is reported — the removal's info row first" begin
        # AFTER trace U32: 2 rows label2 on Blocks #3 / #4 decided_by [#3]; 3 diagnostics — the info row (stated by Block #2), the plain `:label1` reported at Block #3 / #4 (stated_by #3, statements [#3])
        r = _un_run("#~0 :--label1\n\n#~ :(label1, label2)\nx = 1\n"); @test r.status === GM.PROCESS_OK && length(_un_recs(r)) == 2; k = _un_keys(r); @test length(k) == 3
        @test all(x -> x.attr === :label_label2 && x.decided_by == [k[2]], _un_recs(r)) && Set(x.cell_handle for x in _un_recs(r)) == Set([k[2], k[3]])
        d = r.diagnostics; @test length(d) == 3 && d[1].code === :LABELS_VOCABULARY_FILE_CHANGED && d[1].context.change === :removed && d[1].context.stated_by == k[1]
        _un_warn(d[2], _UN_PLAIN_LABEL1, :label1, k[2], k[2], [k[2]]); _un_warn(d[3], _UN_PLAIN_LABEL1, :label1, k[3], k[2], [k[2]])
    end
end
