# labels_withhold_tests.jl — THE WITHHOLD `:-x` / `:(-, x, y)` AND THE EXPLICIT APPLY `:+x` / `:(+, x)` OF THE LABELS ALTERANT (0.4.3)
# — the creator's design: a label withheld from a Component's set for one run without the file rewritten; a plain `:x` met by a withhold
# APPLIES NOTHING and the run proceeds — ONE warning diagnostic per statement and name at each affected Component, the status PROCESS_OK; the rule the same for the
# user level's profile and for the file; the Engine's door = the setter's `Vector{Diagnostic}` return read at the apply and delivered with
# the place merged into the context; a withheld label answers false in a condition; the unknown name reported, not refused (since 0.4.3 — labels_unknown_tests.jl); the malformed shapes
# refused; the reach as the Engine's walk gives it. The code: src/alterants-std/labels.jl (`setLabels(::LabelsInstance, …)` — the sign read
# from the first token; `LabelsInstance.withheld`), src/alterants/apply.jl (`_deliver_diagnostics!` at the two setter call sites),
# src/alterants/registry.jl, src/result.jl, src/state.jl.
#
# IS:   seventeen witnesses [B-W1]–[B-W17] over the public entry, EVERY expected value READ from the measured printouts of the built tree (the
#       FULL delivery views and the `decided_by` traces with their diagnostics blocks — the probes W01 … W45, W46 / W46b, W47a / W47b, C01 … C14; every refusal
#       message and the warning diagnostic's message a byte-exact copy of its printout, never retyped — the `raw"""…"""` literals below) or
#       from the door probe (D1 … D10, K1 … K4), and never written before those runs. THE FORMS ([B-W1]); THE CREATOR's SEQUENCE in the colon
#       forms ([B-W2]); THE PLAIN `:x` MET BY A WITHHOLD — nothing applied, the run proceeds, the warning diagnostic with its place ([B-W3]);
#       THE EXPLICIT APPLY and the fold ([B-W4]); THE UNKNOWN and the removed names — reported since 0.4.3 ([B-W5]); THE CONDITIONS ([B-W6]); THE INLINE
#       metaSegment ([B-W7]); THE USER LEVEL ([B-W8]); THE MALFORMED SHAPES ([B-W9]); THE SUPERSESSION ([B-W10]); `#~0` and the one-line
#       orders ([B-W11]); THE CREATOR's 026 with a withhold ([B-W12]); THE `Dict{Symbol,Bool}` METHOD unchanged ([B-W13]); THE PROVENANCE
#       of a withhold ([B-W14]); THE COIN CASE ([B-W15]); THE ENGINE'S DOOR by a custom registration ([B-W16]); THE DOOR at the apply loop's FIRST setter call — an outer slot's plain label met by a withhold applied before it ([B-W17]).
# REASONING: a withhold removes a name from the Component's applied set and marks it withheld for the rest of that slot's walk; an explicit
#       apply applies the name and lifts the mark; a plain name met by the mark applies nothing and returns a `Vector{Diagnostic}` of `:warning` rows, one per such name occurrence, the Engine
#       delivers with the result (the status untouched — the user is INFORMED and the run PROCEEDS); a run without a sign form is pinned
#       already (labels_vocabulary_tests.jl, fed_profile_order_tests.jl, vocabulary_tests.jl) — no new testset for it. NOT witnessed here (the
#       measured sweeps' alone): W03b's Line answers, W35 (`:doc`), the 28-input sweep × 3 but for A12's `:-label1` twin ([B-W17]) (its `:-label1` run: 22 inputs with diagnostics,
#       6 without, the condition-decided Visib rows gone in seven inputs — fourteen rows — and one replaced).
# PURPOSE: the withhold and the explicit apply, measured — never inferred from the setter's docstring or from prose.

using Test
import GoMeta as GM
const _LW_BLS = GM.BLS

_lw_bytes(s::String) = Vector{UInt8}(codeunits(s))
_lw_run(s::String; profile = nothing, registry = nothing) =   # every document on a FRESH user-level vocabulary file: a vocabulary statement persists (0.4.3)
    (TestSupport.fresh_vocabulary!(); GM.goMeta(_lw_bytes(s); (registry === nothing ? (;) : (; registry = registry))..., config = GM.GoMetaConfig(; user_mh_profile = profile)))
_lw_msg(s::String; profile = nothing, registry = nothing) = try; _lw_run(s; profile = profile, registry = registry); nothing; catch e; sprint(showerror, e); end   # the message as the oracle's view prints it
_lw_recs(r) = collect(r.altValues_evals.records)
_lw_diags(r) = r.diagnostics
_lw_key(r, c) = GM.key_bytes(GM.occurrence_key(r.blsComponentTree, c))      # the key as the Engine's writer derives it (the code-home trap list)
_lw_blocks(r) = _LW_BLS.children(r.blsComponentTree)
_lw_lines(r, b) = _LW_BLS.children(r.blsComponentTree, b)
_lw_keys(r) = [_lw_key(r, b) for b in _lw_blocks(r)]                        # k[i] = the i-th Block's handle = Block #(i+1) of the FULL delivery view
_lw_rows(r, h) = [x for x in _lw_recs(r) if x.cell_handle == h]
_lw_rows(r, h, a) = [x for x in _lw_recs(r) if x.cell_handle == h && x.attr === a]
_lw_labels(r, h) = Set(x.attr for x in _lw_rows(r, h))
_lw_answer(r, c) = (a = GM.evaluatedAltValue(r, c, :labels); (a.value, a.source))
_lw_line_answers(r) = [_lw_answer(r, l) for b in _lw_blocks(r) for l in _lw_lines(r, b)]
const _LW_KU = GM.key_bytes(GM.user_context_key(:default, 1))                # the user level's handle (fed_profile_order_tests.jl)
"the two-Block shape: `labels` on the Blocks `bs[i]` (a metaBlock) and `bs[i+1]` (the Block attached to it) — each label once per Block, every row `true` with the decided_by list `dec`; the answers with the sources given"
function _lw_pair(r, i::Int, labels::Vector{Symbol}, dec::Vector{Vector{UInt8}}; sources = (:own, :indirect))
    bs = _lw_blocks(r); bm, bc = bs[i], bs[i + 1]; km, kc = _lw_key(r, bm), _lw_key(r, bc)
    for h in (km, kc)
        @test _lw_labels(r, h) == Set(Symbol("label_", l) for l in labels)
        for l in labels
            vs = _lw_rows(r, h, Symbol("label_", l)); @test length(vs) == 1 && vs[1].value === true && vs[1].decided_by == dec
        end
    end
    @test _lw_answer(r, bm) == (labels, sources[1]) && _lw_answer(r, bc) == (labels, sources[2])
end
"one `LABEL_NOT_APPLIED_WITHHELD` warning row of the shipped Labels Alterant: the code, the severity, the message bytes (the AFTER trace W04's diagnostics block) and the decoded context — the label, the Component (`cell`), the statement's Component (`stated_by`), the Labels statements applied there so far (`statements`)"
function _lw_withheld(d, label::Symbol, cell::Vector{UInt8}, stated_by::Vector{UInt8}, statements::Vector{Vector{UInt8}})
    @test d.code === :LABEL_NOT_APPLIED_WITHHELD && d.severity === :warning
    @test d.message == raw"""GoMeta apply: the plain `:label1` did not apply label1 here — withheld; if this run means to withhold it, nothing to do; drop `:-label1` (in the user level's profile or in the file) to apply it everywhere; write `:+label1` where one statement must apply it regardless — a written `:+label1` then holds against a withhold stated above it or in the user level's profile; see docs/public-api.md §3.4"""
    @test d.context == (label = label, cell = cell, stated_by = stated_by, statements = statements)
end
"the three `:info` rows of 029's declaration `:(++, x, y, z)` (since 0.4.3 a vocabulary statement persists into the run's user file): x, y, z added — stated by the `#~0` metaBlock, level 1, the statement's text, the run's file"
function _lw_three_added(r)
    d = _lw_diags(r); k = _lw_keys(r)
    @test length(d) == 3 && all(x -> x.code === :LABELS_VOCABULARY_FILE_CHANGED && x.severity === :info, d)
    @test [x.context.label for x in d] == [:x, :y, :z] && all(x -> x.context.change === :added && x.context.stated_by == k[1] && x.context.level == 1 && x.context.statement == ":(++, x, y, z)" && x.context.file == ENV["GOMETA_LABELS_VOCABULARY"], d)
end

@testset "the withhold and the explicit apply of the Labels Alterant (0.4.3)" begin

    @testset "[B-W1] the forms: `:-x` never applied (W02 = C02) — no row, no refusal, no diagnostic; `:+x` where nothing is withheld (W06 = C01) — applied; the list forms `:(-, x, y)` (W10, C05) and `:(+, x)` (W11, C06)" begin
        # AFTER trace W02 `#~ :-label1⏎x = 1`: PROCESS_OK, 0 rows, 0 diagnostics; both Lines answer Symbol[] :default
        r = _lw_run("#~ :-label1\nx = 1\n"); @test r.status === GM.PROCESS_OK && isempty(_lw_recs(r)) && isempty(_lw_diags(r))
        @test _lw_line_answers(r) == [(Symbol[], :default), (Symbol[], :default)]
        # AFTER trace W06 `#~ :+label1⏎x = 1` (= C01): 2 rows — label_label1 on Blocks #2 / #3, decided_by Block #2; answers [:label1] own / indirect; 0 diagnostics
        r = _lw_run("#~ :+label1\nx = 1\n"); @test r.status === GM.PROCESS_OK && length(_lw_recs(r)) == 2 && isempty(_lw_diags(r)); k = _lw_keys(r); _lw_pair(r, 1, [:label1], [k[1]])
        # AFTER traces C05 `#~ :(-, label1)⏎x = 1`: 0 rows, 0 diagnostics; C06 `#~ :(+, label1)⏎x = 1`: 2 rows as W06
        r = _lw_run("#~ :(-, label1)\nx = 1\n"); @test r.status === GM.PROCESS_OK && isempty(_lw_recs(r)) && isempty(_lw_diags(r))
        r = _lw_run("#~ :(+, label1)\nx = 1\n"); @test r.status === GM.PROCESS_OK && length(_lw_recs(r)) == 2 && isempty(_lw_diags(r)); k = _lw_keys(r); _lw_pair(r, 1, [:label1], [k[1]])
        # AFTER trace W10 `#~ :(label1, label2)⏎a = 1⏎#~2 :(-, label1, label2)⏎b = 2`: 4 rows — label1 and label2 on Blocks #2 / #3 only, decided_by Block #2; Blocks #4 / #5 (the withholding metaBlock and `b = 2`) no rows; 0 diagnostics
        r = _lw_run("#~ :(label1, label2)\na = 1\n#~2 :(-, label1, label2)\nb = 2\n"); @test r.status === GM.PROCESS_OK && length(_lw_recs(r)) == 4 && isempty(_lw_diags(r))
        k = _lw_keys(r); @test length(k) == 4; _lw_pair(r, 1, [:label1, :label2], [k[1]]); @test isempty(_lw_rows(r, k[3])) && isempty(_lw_rows(r, k[4]))
        # AFTER trace W11 … `#~3 :(+, label1)⏎c = 3`: 6 rows — the depth-3 pair {label1}, each row decided_by [Block #2, Block #4, Block #6]; answers indirect / indirect
        r = _lw_run("#~ :(label1, label2)\na = 1\n#~2 :(-, label1, label2)\nb = 2\n#~3 :(+, label1)\nc = 3\n"); @test r.status === GM.PROCESS_OK && length(_lw_recs(r)) == 6 && isempty(_lw_diags(r))
        k = _lw_keys(r); @test length(k) == 6; _lw_pair(r, 1, [:label1, :label2], [k[1]]); @test isempty(_lw_rows(r, k[3])) && isempty(_lw_rows(r, k[4]))
        _lw_pair(r, 5, [:label1], [k[1], k[3], k[5]]; sources = (:indirect, :indirect))
    end

    @testset "[B-W2] the creator's sequence in the colon forms (W03): `#~0 :(++, x, y, z)` · (a blank line) · `#~ :(x, y)` · `a = 1` · `#~2 :-x :z` · `b = 2` · `#~3 :+x` · `c = 3` — c1 {x, y}, c2 {y, z}, c3 {x, y, z} by Block, the decided_by lists as measured; the glued spelling (W03b) the same sets one Block earlier" begin
        # AFTER view + trace W03: PROCESS_OK, 14 rows on 6 cells; Block #2 Meta L1 (the `#~0` metaBlock) no rows; Block #3 Meta L2–L3 / Block #4 Code L4 {x, y} decided_by [Block #3];
        # Block #5 Meta L5 / Block #6 Code L6 {y, z} decided_by [#3, #5, #5]; Block #7 Meta L7 / Block #8 Code L8 {x, y, z} decided_by [#3, #5, #5, #7]; 3 info rows — x, y, z added to the run's file (the declaration persists since 0.4.3)
        r = _lw_run("#~0 :(++, x, y, z)\n\n#~ :(x, y)\na = 1\n#~2 :-x :z\nb = 2\n#~3 :+x\nc = 3\n"); @test r.status === GM.PROCESS_OK && length(_lw_recs(r)) == 14; _lw_three_added(r)
        k = _lw_keys(r); @test length(k) == 7 && isempty(_lw_rows(r, k[1]))
        _lw_pair(r, 2, [:x, :y], [k[2]]); _lw_pair(r, 4, [:y, :z], [k[2], k[4], k[4]]; sources = (:indirect, :indirect)); _lw_pair(r, 6, [:x, :y, :z], [k[2], k[4], k[4], k[6]]; sources = (:indirect, :indirect))
        # the eight Lines answer their Block's set indirectly (L1 of the `#~0` metaBlock: Symbol[] :default)
        @test _lw_line_answers(r) == [(Symbol[], :default), ([:x, :y], :indirect), ([:x, :y], :indirect), ([:x, :y], :indirect), ([:y, :z], :indirect), ([:y, :z], :indirect), ([:x, :y, :z], :indirect), ([:x, :y, :z], :indirect)]
        # AFTER trace W03b (no blank line — `:(x, y)` sits in the `#~0` metaBlock, the vocabulary statements' rule): 14 rows on 6 cells, the same sets on Blocks #2 … #7
        r = _lw_run("#~0 :(++, x, y, z)\n#~ :(x, y)\na = 1\n#~2 :-x :z\nb = 2\n#~3 :+x\nc = 3\n"); @test r.status === GM.PROCESS_OK && length(_lw_recs(r)) == 14; _lw_three_added(r)
        k = _lw_keys(r); @test length(k) == 6
        _lw_pair(r, 1, [:x, :y], [k[1]]); _lw_pair(r, 3, [:y, :z], [k[1], k[3], k[3]]; sources = (:indirect, :indirect)); _lw_pair(r, 5, [:x, :y, :z], [k[1], k[3], k[3], k[5]]; sources = (:indirect, :indirect))
    end

    @testset "[B-W3] a plain `:x` met by a withhold APPLIES NOTHING and the run proceeds — one warning diagnostic per statement and name at each affected Component, the status PROCESS_OK (W04, W07, W37)" begin
        # AFTER trace W04 `#~ :label1⏎a = 1⏎#~2 :-label1⏎b = 2⏎#~3 :label1⏎c = 3`: PROCESS_OK; 2 rows (label1 on Blocks #2 / #3 decided_by Block #2); Blocks #4 … #7 no rows;
        # 2 diagnostics LABEL_NOT_APPLIED_WITHHELD warning — cell Block #6 (`#~3 :label1`) / Block #7 (`c = 3`), stated_by Block #6, statements [#2, #4, #6]; the Lines L5 / L6 answer Symbol[] :default
        r = _lw_run("#~ :label1\na = 1\n#~2 :-label1\nb = 2\n#~3 :label1\nc = 3\n"); @test r.status === GM.PROCESS_OK && length(_lw_recs(r)) == 2
        k = _lw_keys(r); @test length(k) == 6; _lw_pair(r, 1, [:label1], [k[1]]); @test all(i -> isempty(_lw_rows(r, k[i])), 3:6)
        d = _lw_diags(r); @test length(d) == 2
        _lw_withheld(d[1], :label1, k[5], k[5], [k[1], k[3], k[5]]); _lw_withheld(d[2], :label1, k[6], k[5], [k[1], k[3], k[5]])
        @test _lw_line_answers(r)[5:6] == [(Symbol[], :default), (Symbol[], :default)]
        # AFTER trace W07 `#~ :-label1 :label1⏎x = 1`: 0 rows; 2 diagnostics — cell Block #2 / #3, stated_by Block #2, statements [#2, #2] (the withhold and the plain statement both recorded)
        r = _lw_run("#~ :-label1 :label1\nx = 1\n"); @test r.status === GM.PROCESS_OK && isempty(_lw_recs(r)); k = _lw_keys(r); d = _lw_diags(r); @test length(d) == 2
        _lw_withheld(d[1], :label1, k[1], k[1], [k[1], k[1]]); _lw_withheld(d[2], :label1, k[2], k[1], [k[1], k[1]])
        # AFTER trace W37 `#~ :-label1⏎a = 1⏎⏎b = 2⏎#~2 :label1⏎c = 3`: four Blocks (the Code Block L2–L4 holds `a = 1`, the blank line and `b = 2`); 0 rows;
        # 2 diagnostics at Block #4 (`#~2 :label1`) / Block #5 (`c = 3`), stated_by Block #4, statements [#2, #4] — the withhold reaches down the slot
        r = _lw_run("#~ :-label1\na = 1\n\nb = 2\n#~2 :label1\nc = 3\n"); @test r.status === GM.PROCESS_OK && isempty(_lw_recs(r)); k = _lw_keys(r); @test length(k) == 4
        d = _lw_diags(r); @test length(d) == 2; _lw_withheld(d[1], :label1, k[3], k[3], [k[1], k[3]]); _lw_withheld(d[2], :label1, k[4], k[3], [k[1], k[3]])
        @test all(x -> x == (Symbol[], :default), _lw_line_answers(r)) && length(_lw_line_answers(r)) == 6
    end

    @testset "[B-W4] the explicit apply `:+x` and the fold: W05 (readmitted at depth 3), W08 (`:-x :+x` one line), W09 (`:+x :-x` — the last word), W32 (a plain `:x` under the readmit applies — no diagnostic), W33 (withheld twice), W36 (two names), W39 (withheld again at depth 4)" begin
        # AFTER trace W05 `#~ :label1⏎a = 1⏎#~2 :-label1⏎b = 2⏎#~3 :+label1⏎c = 3`: 4 rows — Blocks #2 / #3 decided_by [#2]; Blocks #6 / #7 decided_by [#2, #4, #6]; Blocks #4 / #5 none; 0 diagnostics
        r = _lw_run("#~ :label1\na = 1\n#~2 :-label1\nb = 2\n#~3 :+label1\nc = 3\n"); @test r.status === GM.PROCESS_OK && length(_lw_recs(r)) == 4 && isempty(_lw_diags(r))
        k = _lw_keys(r); @test length(k) == 6; _lw_pair(r, 1, [:label1], [k[1]]); @test isempty(_lw_rows(r, k[3])) && isempty(_lw_rows(r, k[4])); _lw_pair(r, 5, [:label1], [k[1], k[3], k[5]]; sources = (:indirect, :indirect))
        # AFTER trace W08 `#~ :-label1 :+label1⏎x = 1`: 2 rows decided_by [#2, #2]; W09 `#~ :+label1 :-label1⏎x = 1`: 0 rows; both 0 diagnostics
        r = _lw_run("#~ :-label1 :+label1\nx = 1\n"); @test r.status === GM.PROCESS_OK && length(_lw_recs(r)) == 2 && isempty(_lw_diags(r)); k = _lw_keys(r); _lw_pair(r, 1, [:label1], [k[1], k[1]])
        r = _lw_run("#~ :+label1 :-label1\nx = 1\n"); @test r.status === GM.PROCESS_OK && isempty(_lw_recs(r)) && isempty(_lw_diags(r))
        # AFTER trace W32 … `#~3 :+label1⏎c = 3⏎#~4 :label1⏎d = 4`: 6 rows — the depth-3 pair [#2, #4, #6], the depth-4 pair [#2, #4, #6, #8]; 0 diagnostics (the plain `:label1` under the readmit applies)
        r = _lw_run("#~ :label1\na = 1\n#~2 :-label1\nb = 2\n#~3 :+label1\nc = 3\n#~4 :label1\nd = 4\n"); @test r.status === GM.PROCESS_OK && length(_lw_recs(r)) == 6 && isempty(_lw_diags(r))
        k = _lw_keys(r); @test length(k) == 8; _lw_pair(r, 1, [:label1], [k[1]]); _lw_pair(r, 5, [:label1], [k[1], k[3], k[5]]; sources = (:indirect, :indirect)); _lw_pair(r, 7, [:label1], [k[1], k[3], k[5], k[7]]; sources = (:indirect, :indirect))
        # AFTER trace W33 `#~ :label1 :-label1 :-label1⏎x = 1`: 0 rows, 0 diagnostics
        r = _lw_run("#~ :label1 :-label1 :-label1\nx = 1\n"); @test r.status === GM.PROCESS_OK && isempty(_lw_recs(r)) && isempty(_lw_diags(r))
        # AFTER trace W36 `#~ :(label1, label2)⏎a = 1⏎#~2 :-label1 :+label2⏎b = 2`: 6 rows — Blocks #2 / #3 {label1, label2} [#2]; Blocks #4 / #5 {label2} decided_by [#2, #4, #4]; 0 diagnostics
        r = _lw_run("#~ :(label1, label2)\na = 1\n#~2 :-label1 :+label2\nb = 2\n"); @test r.status === GM.PROCESS_OK && length(_lw_recs(r)) == 6 && isempty(_lw_diags(r))
        k = _lw_keys(r); @test length(k) == 4; _lw_pair(r, 1, [:label1, :label2], [k[1]]); _lw_pair(r, 3, [:label2], [k[1], k[3], k[3]]; sources = (:indirect, :indirect))
        # AFTER trace W39 … `#~4 :-label1⏎d = 4`: 4 rows — the depth-1 and depth-3 pairs as W05; the depth-4 pair none; 0 diagnostics
        r = _lw_run("#~ :label1\na = 1\n#~2 :-label1\nb = 2\n#~3 :+label1\nc = 3\n#~4 :-label1\nd = 4\n"); @test r.status === GM.PROCESS_OK && length(_lw_recs(r)) == 4 && isempty(_lw_diags(r))
        k = _lw_keys(r); @test length(k) == 8; _lw_pair(r, 1, [:label1], [k[1]]); _lw_pair(r, 5, [:label1], [k[1], k[3], k[5]]; sources = (:indirect, :indirect)); @test isempty(_lw_rows(r, k[7])) && isempty(_lw_rows(r, k[8]))
    end

    @testset "[B-W5] the unknown and the removed names — REPORTED, not refused (since 0.4.3): `:-zzz` / `:+zzz` (W12 / W13) and, after `#~0 :--label1`, `:-label1` / `:+label1` (W14 / W15) — one warning row per affected Component naming the statement's form, nothing applied, nothing withheld; the removal's info row first (the one-character asymmetry: a one-run `:-x` informs where `:--x` removes the name for good — labels_vocabulary_file_tests.jl)" begin
        # AFTER trace W12 `#~ :-zzz⏎x = 1`: PROCESS_OK, 0 rows; 2 diagnostics LABEL_NOT_APPLIED_UNKNOWN — cell Block #2 / #3, stated_by Block #2, statements [#2]; the message names the withhold `:-zzz`
        r = _lw_run("#~ :-zzz\nx = 1\n"); @test r.status === GM.PROCESS_OK && isempty(_lw_recs(r)); k = _lw_keys(r); d = _lw_diags(r); @test length(d) == 2
        for (i, c) in ((1, k[1]), (2, k[2])); @test d[i].code === :LABEL_NOT_APPLIED_UNKNOWN && d[i].severity === :warning && d[i].message == raw"""GoMeta apply: the withhold `:-zzz` had no effect here — not in the Labels Alterant's vocabulary; declare it with `:++zzz` at `#~0` or in the user level's profile, or correct the spelling; see docs/public-api.md §3.4""" && d[i].context == (label = :zzz, cell = c, stated_by = k[1], statements = [k[1]]); end
        # AFTER trace W13 `#~ :+zzz⏎x = 1`: the same shape; the message names the explicit `:+zzz`
        r = _lw_run("#~ :+zzz\nx = 1\n"); @test r.status === GM.PROCESS_OK && isempty(_lw_recs(r)); k = _lw_keys(r); d = _lw_diags(r); @test length(d) == 2
        for (i, c) in ((1, k[1]), (2, k[2])); @test d[i].code === :LABEL_NOT_APPLIED_UNKNOWN && d[i].severity === :warning && d[i].message == raw"""GoMeta apply: the explicit `:+zzz` had no effect here — not in the Labels Alterant's vocabulary; declare it with `:++zzz` at `#~0` or in the user level's profile, or correct the spelling; see docs/public-api.md §3.4""" && d[i].context == (label = :zzz, cell = c, stated_by = k[1], statements = [k[1]]); end
        # AFTER trace W14 `#~0 :--label1⏎⏎#~ :-label1⏎x = 1`: 0 rows; 3 diagnostics — the info row (label1 removed from the run's file; stated by Block #2, level 1), then the withhold `:-label1` reported at Block #3 / #4 (stated_by Block #3, statements [#3])
        r = _lw_run("#~0 :--label1\n\n#~ :-label1\nx = 1\n"); @test r.status === GM.PROCESS_OK && isempty(_lw_recs(r)); k = _lw_keys(r); @test length(k) == 3; d = _lw_diags(r); @test length(d) == 3
        @test d[1].code === :LABELS_VOCABULARY_FILE_CHANGED && d[1].severity === :info && d[1].context == (file = ENV["GOMETA_LABELS_VOCABULARY"], change = :removed, label = :label1, stated_by = k[1], level = 1, statement = ":--label1")
        for (i, c) in ((2, k[2]), (3, k[3])); @test d[i].code === :LABEL_NOT_APPLIED_UNKNOWN && d[i].severity === :warning && d[i].message == raw"""GoMeta apply: the withhold `:-label1` had no effect here — not in the Labels Alterant's vocabulary; declare it with `:++label1` at `#~0` or in the user level's profile, or correct the spelling; see docs/public-api.md §3.4""" && d[i].context == (label = :label1, cell = c, stated_by = k[2], statements = [k[2]]); end
        # AFTER trace W15 `#~0 :--label1⏎⏎#~ :+label1⏎x = 1`: the same shape; the message names the explicit `:+label1`
        r = _lw_run("#~0 :--label1\n\n#~ :+label1\nx = 1\n"); @test r.status === GM.PROCESS_OK && isempty(_lw_recs(r)); k = _lw_keys(r); d = _lw_diags(r); @test length(d) == 3
        @test d[1].code === :LABELS_VOCABULARY_FILE_CHANGED && d[1].context.change === :removed && d[1].context.label === :label1
        for (i, c) in ((2, k[2]), (3, k[3])); @test d[i].code === :LABEL_NOT_APPLIED_UNKNOWN && d[i].severity === :warning && d[i].message == raw"""GoMeta apply: the explicit `:+label1` had no effect here — not in the Labels Alterant's vocabulary; declare it with `:++label1` at `#~0` or in the user level's profile, or correct the spelling; see docs/public-api.md §3.4""" && d[i].context == (label = :label1, cell = c, stated_by = k[2], statements = [k[2]]); end
    end

    @testset "[B-W6] a condition on a withhold or an explicit apply, and a condition reading a withheld name: W16, W29, W30, W40, W43" begin
        # AFTER trace W16 `#~ :label1 :-label1{ isCode }⏎x = 1`: 1 row — label1 on Block #2 (the metaBlock is not code) decided_by [#2]; the Code Block none; L1 answers [:label1] indirect, L2 Symbol[] default; 0 diagnostics
        r = _lw_run("#~ :label1 :-label1{ isCode }\nx = 1\n"); @test r.status === GM.PROCESS_OK && length(_lw_recs(r)) == 1 && isempty(_lw_diags(r)); k = _lw_keys(r); bs = _lw_blocks(r)
        vs = _lw_rows(r, k[1], :label_label1); @test length(vs) == 1 && vs[1].decided_by == [k[1]] && isempty(_lw_rows(r, k[2]))
        @test _lw_answer(r, bs[1]) == ([:label1], :own) && _lw_line_answers(r) == [([:label1], :indirect), (Symbol[], :default)]
        # AFTER trace W29 `#~ :label1⏎a = 1⏎#~2 :-label1 hide{ :label1 }⏎b = 2`: 2 rows (the depth-1 pair); NO visib row — the condition reads the withheld name: false; 0 diagnostics
        r = _lw_run("#~ :label1\na = 1\n#~2 :-label1 hide{ :label1 }\nb = 2\n"); @test r.status === GM.PROCESS_OK && length(_lw_recs(r)) == 2 && isempty(_lw_diags(r)); k = _lw_keys(r); _lw_pair(r, 1, [:label1], [k[1]]); @test all(x -> x.attr !== :visib, _lw_recs(r))
        # AFTER trace W30 `#~2 hide{ :label1 } :-label1` (the written order — the condition before the withhold): 4 rows — the depth-1 pair label1; visib => :hide on Blocks #4 / #5 decided_by [#4]; 0 diagnostics
        r = _lw_run("#~ :label1\na = 1\n#~2 hide{ :label1 } :-label1\nb = 2\n"); @test r.status === GM.PROCESS_OK && length(_lw_recs(r)) == 4 && isempty(_lw_diags(r)); k = _lw_keys(r); _lw_pair(r, 1, [:label1], [k[1]])
        for h in (k[3], k[4]); vs = _lw_rows(r, h); @test length(vs) == 1 && vs[1].attr === :visib && vs[1].value === :hide && vs[1].decided_by == [k[3]]; end
        # AFTER trace W40 `#~ :(label1, label2)⏎a = 1⏎#~2 :(-, label1){ isCode }⏎b = 2`: 7 rows — Blocks #2 / #3 / #4 {label1, label2} [#2]; Block #5 (`b = 2`, code) {label2} decided_by [#2, #4]; 0 diagnostics
        r = _lw_run("#~ :(label1, label2)\na = 1\n#~2 :(-, label1){ isCode }\nb = 2\n"); @test r.status === GM.PROCESS_OK && length(_lw_recs(r)) == 7 && isempty(_lw_diags(r)); k = _lw_keys(r); bs = _lw_blocks(r)
        _lw_pair(r, 1, [:label1, :label2], [k[1]])
        @test _lw_labels(r, k[3]) == Set([:label_label1, :label_label2]) && all(x -> x.decided_by == [k[1]], _lw_rows(r, k[3])) && _lw_answer(r, bs[3]) == ([:label1, :label2], :indirect)
        vs = _lw_rows(r, k[4]); @test length(vs) == 1 && vs[1].attr === :label_label2 && vs[1].decided_by == [k[1], k[3]] && _lw_answer(r, bs[4]) == ([:label2], :indirect)
        # AFTER trace W43 `#~ :label1⏎a = 1⏎#~2 hide{ :-label1 }⏎b = 2`: 4 rows — label1 on Blocks #2 … #5, each decided_by [#2]; NO visib row (a SIGNED name in a condition is a query of the name `-label1`, which answers false); unchanged BEFORE / AFTER
        r = _lw_run("#~ :label1\na = 1\n#~2 hide{ :-label1 }\nb = 2\n"); @test r.status === GM.PROCESS_OK && length(_lw_recs(r)) == 4 && isempty(_lw_diags(r)); k = _lw_keys(r)
        @test all(x -> x.attr === :label_label1 && x.decided_by == [k[1]], _lw_recs(r)) && Set(x.cell_handle for x in _lw_recs(r)) == Set(k)
    end

    @testset "[B-W7] an inline withhold (W17, W17b): the Line without a label ROW of its own; its ANSWER its Block's set (W17 — the rowless Line's fallback) or the labels it keeps (W17b)" begin
        # AFTER trace W17 `#~ :label1⏎x = 1 #~ :-label1⏎y = 2`: 2 rows — label1 on Blocks #2 / #3 decided_by [#2]; NO Line-grain row; the Lines `x = 1` and `y = 2` both answer [:label1] :indirect (the Block's); 0 diagnostics
        r = _lw_run("#~ :label1\nx = 1 #~ :-label1\ny = 2\n"); @test r.status === GM.PROCESS_OK && length(_lw_recs(r)) == 2 && isempty(_lw_diags(r)); k = _lw_keys(r); _lw_pair(r, 1, [:label1], [k[1]])
        ls = _lw_lines(r, _lw_blocks(r)[2]); @test length(ls) == 2 && all(x -> x.cell_handle in k, _lw_recs(r)) && all(l -> _lw_answer(r, l) == ([:label1], :indirect), ls)
        # AFTER trace W17b `#~ :(label1, label2)⏎x = 1 #~ :-label1⏎y = 2`: 5 rows — Blocks #2 / #3 {label1, label2} [#2]; the Line `x = 1` ONE row label_label2 decided_by [Block #2, its own Segment]; it answers [:label2] :indirect; `y = 2` answers [:label1, :label2] :indirect; 0 diagnostics
        r = _lw_run("#~ :(label1, label2)\nx = 1 #~ :-label1\ny = 2\n"); @test r.status === GM.PROCESS_OK && length(_lw_recs(r)) == 5 && isempty(_lw_diags(r)); k = _lw_keys(r); _lw_pair(r, 1, [:label1, :label2], [k[1]])
        ls = _lw_lines(r, _lw_blocks(r)[2]); vs = [x for x in _lw_recs(r) if !(x.cell_handle in k)]   # the one Line-grain row — keyed by its Line with the Segment as the key's origin, so not the Line's bare occurrence key
        @test length(vs) == 1 && vs[1].attr === :label_label2 && length(vs[1].decided_by) == 2 && vs[1].decided_by[1] == k[1] && any(s -> _lw_key(r, s) == vs[1].decided_by[2], _LW_BLS.children(r.blsComponentTree, ls[1]))   # the Line's own trailing metaSegment (AFTER trace W17b: decided_by[2] grain Segment, the key's origin)
        @test _lw_answer(r, ls[1]) == ([:label2], :indirect) && _lw_answer(r, ls[2]) == ([:label1, :label2], :indirect)
        # AFTER trace W46 `#~ :-label1⏎x = 1 #~ :label1⏎y = 2` (an inline PLAIN under a Block-level withhold) — EVERY VALUE BELOW FROM THE PRINTOUT before this line is kept: the status, the rows, the one Line-grain diagnostic (its cell the Line's key with the Segment as the origin, stated_by the Segment's handle, statements [Block #2, the Segment]), every Line's answer
        r = _lw_run("#~ :-label1\nx = 1 #~ :label1\ny = 2\n"); @test r.status === GM.PROCESS_OK && isempty(_lw_recs(r)); k = _lw_keys(r); d = _lw_diags(r); @test length(d) == 1
        @test d[1].code === :LABEL_NOT_APPLIED_WITHHELD && d[1].severity === :warning && d[1].context.label === :label1 && !(d[1].context.cell in k) && length(d[1].context.statements) == 2 && d[1].context.statements[1] == k[1] && d[1].context.stated_by == d[1].context.statements[2]
        lS = _lw_lines(r, _lw_blocks(r)[2])[1]; sS = _LW_BLS.children(r.blsComponentTree, lS)[2]; kS = _lw_key(r, sS); kL = GM.key_bytes(GM.occurrence_key(r.blsComponentTree, lS; origin = sS)); _lw_withheld(d[1], :label1, kL, kS, [k[1], kS])   # the cell = the Line's key with its trailing metaSegment as the origin, the stating statement = that Segment (both keys as the Engine derives them, apply.jl); the message bytes the shared ones
        # AFTER trace W46b `#~ :-label1⏎x = 1 #~ :+label1⏎y = 2` (an inline EXPLICIT apply under it) — FROM THE PRINTOUT: the one Line-grain row label_label1, its decided_by [Block #2, the Segment], 0 diagnostics
        r = _lw_run("#~ :-label1\nx = 1 #~ :+label1\ny = 2\n"); @test r.status === GM.PROCESS_OK && isempty(_lw_diags(r)); k = _lw_keys(r); vs = [x for x in _lw_recs(r) if !(x.cell_handle in k)]; @test length(_lw_recs(r)) == 1 && length(vs) == 1 && vs[1].attr === :label_label1 && vs[1].decided_by[1] == k[1] && length(vs[1].decided_by) == 2
    end

    @testset "[B-W8] the user level's profile: `:-label1` over a plain `:label1` — nothing applied, the run proceeds, the diagnostics naming the user level (W18 = C10); `:+label1` over `:-label1` — the file's withhold the last word (W19); `:-label1` over `:label2` (W20); `:+label1` over `:label2` (W38); `:-label1` over `:+label1` — the explicit apply holds (W41)" begin
        # AFTER trace W18 (profile ":-label1") `#~ :label1⏎x = 1`: PROCESS_OK, 0 rows; 2 diagnostics — cell Block #2 / #3, stated_by Block #2, statements [the user level, Block #2]
        r = _lw_run("#~ :label1\nx = 1\n"; profile = ":-label1"); @test r.status === GM.PROCESS_OK && isempty(_lw_recs(r)); k = _lw_keys(r); d = _lw_diags(r); @test length(d) == 2
        _lw_withheld(d[1], :label1, k[1], k[1], [_LW_KU, k[1]]); _lw_withheld(d[2], :label1, k[2], k[1], [_LW_KU, k[1]])
        # AFTER trace W19 (profile ":+label1") `#~ :-label1⏎x = 1`: 0 rows, 0 diagnostics
        r = _lw_run("#~ :-label1\nx = 1\n"; profile = ":+label1"); @test r.status === GM.PROCESS_OK && isempty(_lw_recs(r)) && isempty(_lw_diags(r))
        # AFTER trace W20 (profile ":-label1") `#~ :label2⏎x = 1`: 2 rows — label2 on Blocks #2 / #3 decided_by [the user level, Block #2]; answers [:label2] :user; 0 diagnostics
        r = _lw_run("#~ :label2\nx = 1\n"; profile = ":-label1"); @test r.status === GM.PROCESS_OK && length(_lw_recs(r)) == 2 && isempty(_lw_diags(r)); k = _lw_keys(r); _lw_pair(r, 1, [:label2], [_LW_KU, k[1]]; sources = (:user, :user))
        # AFTER trace W38 (profile ":+label1") `#~ :label2⏎x = 1`: 4 rows — label1 and label2 on Blocks #2 / #3, each decided_by [the user level, Block #2]; answers [:label1, :label2] :user
        r = _lw_run("#~ :label2\nx = 1\n"; profile = ":+label1"); @test r.status === GM.PROCESS_OK && length(_lw_recs(r)) == 4 && isempty(_lw_diags(r)); k = _lw_keys(r); _lw_pair(r, 1, [:label1, :label2], [_LW_KU, k[1]]; sources = (:user, :user))
        # AFTER trace W41 (profile ":-label1") `#~ :+label1⏎x = 1`: 2 rows — label1 decided_by [the user level, Block #2]; answers :user; 0 diagnostics — the remedy a file keeps against a profile's withhold
        r = _lw_run("#~ :+label1\nx = 1\n"; profile = ":-label1"); @test r.status === GM.PROCESS_OK && length(_lw_recs(r)) == 2 && isempty(_lw_diags(r)); k = _lw_keys(r); _lw_pair(r, 1, [:label1], [_LW_KU, k[1]]; sources = (:user, :user))
    end

    @testset "[B-W9] the malformed shapes, each REFUSED at the apply with its message — the sign stands at the head of a statement, never inside a list: W21 … W27, W44a / W44b, W47a / W47b" begin
        @test _lw_msg("#~ :(label1, -label2)\nx = 1\n") == raw"""GoMeta apply: a label name may not begin with `+` or `-` inside a label list — got "-label2" (the sign stands at the head of a statement: `:-x`, `:(-, x, y)`, `:+x`, `:(+, x)`); see docs/public-api.md §3.4"""     # a signed member in a PLAIN list (= C09)
        @test _lw_msg("#~ :-\nx = 1\n") == raw"""GoMeta apply: the label statement `:(-)` names no label — the forms are `:-x` and `:(-, x, y)`; see docs/public-api.md §3.4"""                    # a withhold naming no label — read as the list head `-`
        @test _lw_msg("#~ :(-)\nx = 1\n") == raw"""GoMeta apply: the label statement `:(-)` names no label — the forms are `:-x` and `:(-, x, y)`; see docs/public-api.md §3.4"""
        @test _lw_msg("#~ :(-, )\nx = 1\n") == raw"""GoMeta apply: the label statement `:(-, )` names an empty label (a stray comma) — the forms are `:-x` and `:(-, x, y)`; see docs/public-api.md §3.4"""                # an empty member (a stray comma) in a signed list
        @test _lw_msg("#~ :(-label1, label2)\nx = 1\n") == raw"""GoMeta apply: the prefixed label statement `:-label1` takes one name — 2 arguments given (the list form is `:(-, x, y)`); see docs/public-api.md §3.4"""    # the prefixed form with two arguments
        @test _lw_msg("#~ :+-label1\nx = 1\n") == raw"""GoMeta apply: a label name may not begin with `+` or `-` inside a label list — got "-label1" (the sign stands at the head of a statement: `:-x`, `:(-, x, y)`, `:+x`, `:(+, x)`); see docs/public-api.md §3.4"""             # a name beginning with a sign
        @test _lw_msg("#~ :(-, +label1)\nx = 1\n") == raw"""GoMeta apply: a label name may not begin with `+` or `-` inside a label list — got "+label1" (the sign stands at the head of a statement: `:-x`, `:(-, x, y)`, `:+x`, `:(+, x)`); see docs/public-api.md §3.4"""         # a signed member inside a withhold list
        @test _lw_msg("#~ :+\nx = 1\n") == raw"""GoMeta apply: the label statement `:(+)` names no label — the forms are `:+x` and `:(+, x, y)`; see docs/public-api.md §3.4"""
        @test _lw_msg("#~ :(+)\nx = 1\n") == raw"""GoMeta apply: the label statement `:(+)` names no label — the forms are `:+x` and `:(+, x, y)`; see docs/public-api.md §3.4"""
        @test _lw_msg("#~ :(-, +label1, )\nx = 1\n") == raw"""GoMeta apply: the label statement `:(-, )` names an empty label (a stray comma) — the forms are `:-x` and `:(-, x, y)`; see docs/public-api.md §3.4"""    # TWO defects in one signed list — a signed member and an empty member (W47a)
        @test _lw_msg("#~ :(-, , +label1)\nx = 1\n") == raw"""GoMeta apply: the label statement `:(-, )` names an empty label (a stray comma) — the forms are `:-x` and `:(-, x, y)`; see docs/public-api.md §3.4"""    # the same two defects in the other order (W47b) — the shapes checked in order: the form, no name, an empty member, then a sign on a name
        # the PLAIN list's empty member `:(,)` is a SHAPE refusal too since 0.4.3, the plain forms named (labels_unknown_tests.jl; inert_semantics_tests.jl)
    end

    @testset "[B-W10] the withhold's reach ends with its slot: a second depth-2 metaBlock REPLACES the slot (W28) — its pair {label1, label2} decided_by [#2, #6]; a SHALLOWER supersession (W42) wipes the depth-1 and depth-2 slots — `c = 3` {label2} alone, decided_by [#6]" begin
        r = _lw_run("#~ :label1\na = 1\n#~2 :-label1\nb = 2\n#~2 :label2\nc = 3\n"); @test r.status === GM.PROCESS_OK && length(_lw_recs(r)) == 6 && isempty(_lw_diags(r)); k = _lw_keys(r); @test length(k) == 6
        _lw_pair(r, 1, [:label1], [k[1]]); @test isempty(_lw_rows(r, k[3])) && isempty(_lw_rows(r, k[4])); _lw_pair(r, 5, [:label1, :label2], [k[1], k[5]]; sources = (:indirect, :indirect))
        r = _lw_run("#~ :label1\na = 1\n#~2 :-label1\nb = 2\n#~ :label2\nc = 3\n"); @test r.status === GM.PROCESS_OK && length(_lw_recs(r)) == 4 && isempty(_lw_diags(r)); k = _lw_keys(r); @test length(k) == 6
        _lw_pair(r, 1, [:label1], [k[1]]); @test isempty(_lw_rows(r, k[3])) && isempty(_lw_rows(r, k[4])); _lw_pair(r, 5, [:label2], [k[5]])
    end

    @testset "[B-W11] `#~0` and the one-line orders: `#~0 :label1 :-label1` (W31), `#~ :label1 :-label1` (W01 = C08) — no row, no diagnostic" begin
        r = _lw_run("#~0 :label1 :-label1\nx = 1\n"); @test r.status === GM.PROCESS_OK && isempty(_lw_recs(r)) && isempty(_lw_diags(r)) && _lw_line_answers(r) == [(Symbol[], :default), (Symbol[], :default)]
        r = _lw_run("#~ :label1 :-label1\nx = 1\n"); @test r.status === GM.PROCESS_OK && isempty(_lw_recs(r)) && isempty(_lw_diags(r)) && _lw_line_answers(r) == [(Symbol[], :default), (Symbol[], :default)]
    end

    @testset "[B-W12] the creator's 026 with ` :-label5` appended to its depth-3 metaLine (W34): the depth-3 metaBlock and the Text Block under it WITHOUT label_label5 and their visib :hide → :show (line 9's `show{ !:label5}` now the first applicable Visib row); the Line L31 loses its own label_label5 row; every other row of 026 unchanged by (cell, attribute, value)" begin
        doc026 = read(joinpath(@__DIR__, "..", "authored", "026_example_proposal_juliacon.jl"), String)
        L22 = "#~3 :label4 discard{:label3} :label3"; @test count(L22, doc026) == 1
        r0 = _lw_run(doc026); r = _lw_run(replace(doc026, L22 => L22 * " :-label5")); @test r0.status === GM.PROCESS_OK && r.status === GM.PROCESS_OK && isempty(_lw_diags(r))
        @test length(_lw_recs(r0)) == 28 && length(_lw_recs(r)) == 25
        k = _lw_keys(r); @test k == _lw_keys(r0) && length(k) == 8
        lineCells = unique(x.cell_handle for x in _lw_recs(r0) if !(x.cell_handle in k))   # 026's three Line-grain cells (L8, L31, L35 — each keyed with its Segment as the origin)
        kL = only(h for h in lineCells if any(x -> x.cell_handle == h && x.attr === :label_label3, _lw_recs(r0)))   # L31, the one carrying label3 (its own `#~ show` inline statement; the last Line of the Text Block, Block #7)
        @test length(lineCells) == 3 && kL == only(x.cell_handle for x in _lw_recs(r0) if x.attr === :visib && x.value === :show && !(x.cell_handle in k))
        S(x) = Set((y.cell_handle, y.attr, y.value) for y in _lw_recs(x))
        @test setdiff(S(r0), S(r)) == Set([(k[5], :label_label5, true), (k[6], :label_label5, true), (kL, :label_label5, true), (k[5], :visib, :hide), (k[6], :visib, :hide)])
        @test setdiff(S(r), S(r0)) == Set([(k[5], :visib, :show), (k[6], :visib, :show)])
        for h in (k[5], k[6]); vs = _lw_rows(r, h, :visib); @test length(vs) == 1 && vs[1].value === :show && vs[1].decided_by == [k[3]]; end   # decided by the depth-2 metaBlock; in 026 the :hide rows are decided by Block #2
        @test all(x -> x.decided_by == [k[1]], _lw_rows(r0, k[5], :visib)) && all(x -> x.decided_by == [k[1]], _lw_rows(r0, k[6], :visib))
        @test _lw_answer(r, _lw_blocks(r)[5]) == ([:label1, :label3, :label4], :indirect) && _lw_answer(r0, _lw_blocks(r0)[5]) == ([:label1, :label3, :label4, :label5], :indirect)
        for h in (k[5], k[6], kL), a in (:label_label1, :label_label3, :label_label4); vs = _lw_rows(r, h, a); @test length(vs) == 1 && vs[1].decided_by == [k[1], k[3], k[5], k[5], k[5]]; end   # the withhold RECORDED: the depth-3 metaBlock stands a third time in the decided_by of every label row that remains under it (AFTER trace W34)
    end

    @testset "[B-W13] the `Dict{Symbol,Bool}` method of the shipped setter UNCHANGED: a custom registration pairing it with the Dict constructor (the pattern of registry_lifecycle_tests.jl :176–:180) runs a plain `:label1` and refuses `:-label1`, `:+label1` and `:(-, label1)` as unknown labels — the former body, its accepted set the 46 shipped names since 0.4.3 (MEASURED: K1–K4)" begin
        bc = GM.RegistryBuilder()
        GM.register!(bc, GM.Alterant(; altName = :bag, setMode = :accumulate, altConstructor = Dict{Symbol,Bool}, setAltInstance = GM.Alterants.setLabels, getAltInstance = GM.Alterants.checkLabels),
                     GM.ActionSpec(; name = Symbol(":"), plugin = Int8(1)))
        RC = GM.publish(bc)
        r = _lw_run("x = 1\n#~ :label1\n\ny = 2\n"; registry = RC); @test r.status === GM.PROCESS_OK && isempty(_lw_diags(r))
        @test _lw_msg("#~ :-label1\nx = 1\n"; registry = RC) == raw"""GoMeta apply: unknown label "-label1" — not in the Labels Alterant's vocabulary (the accepted set = [:definition, :doc, :info, :label1, :label2, :label3, :label4, :label5, :label⌛, :label⛓️, Symbol("label⛓️\u200d💥"), :label⛔, :label🇨🇭, :label🌍, :label🌛, :label🌞, :label🌳, :label🌷, :label🌹, :label🌼, :label🍀, :label🍒, :label🍻, :label🎨, :label🎿, :label🏔️, :label🐣, :label💕, :label💡, :label💣, :label💫, :label💯, :label💸, :label💾, :label📝, :label📸, :label🔥, :label😘, :label🚀, :label🧮, :label🫕, :note, :private, :public, :todo, :warning]); see docs/public-api.md §3.4"""
        @test _lw_msg("#~ :+label1\nx = 1\n"; registry = RC) == raw"""GoMeta apply: unknown label "+label1" — not in the Labels Alterant's vocabulary (the accepted set = [:definition, :doc, :info, :label1, :label2, :label3, :label4, :label5, :label⌛, :label⛓️, Symbol("label⛓️\u200d💥"), :label⛔, :label🇨🇭, :label🌍, :label🌛, :label🌞, :label🌳, :label🌷, :label🌹, :label🌼, :label🍀, :label🍒, :label🍻, :label🎨, :label🎿, :label🏔️, :label🐣, :label💕, :label💡, :label💣, :label💫, :label💯, :label💸, :label💾, :label📝, :label📸, :label🔥, :label😘, :label🚀, :label🧮, :label🫕, :note, :private, :public, :todo, :warning]); see docs/public-api.md §3.4"""
        @test _lw_msg("#~ :(-, label1)\nx = 1\n"; registry = RC) == raw"""GoMeta apply: unknown label "-" — not in the Labels Alterant's vocabulary (the accepted set = [:definition, :doc, :info, :label1, :label2, :label3, :label4, :label5, :label⌛, :label⛓️, Symbol("label⛓️\u200d💥"), :label⛔, :label🇨🇭, :label🌍, :label🌛, :label🌞, :label🌳, :label🌷, :label🌹, :label🌼, :label🍀, :label🍒, :label🍻, :label🎨, :label🎿, :label🏔️, :label🐣, :label💕, :label💡, :label💣, :label💫, :label💯, :label💸, :label💾, :label📝, :label📸, :label🔥, :label😘, :label🚀, :label🧮, :label🫕, :note, :private, :public, :todo, :warning]); see docs/public-api.md §3.4"""
    end

    @testset "[B-W14] a withheld name mints no row, but the withholding statement is RECORDED in the decided_by of the rows that remain at that Component (W36's depth-2 pair: one row label_label2 decided_by [#2, #4, #4]; W03's c2: [#3, #5, #5]) — a withhold's trace is its place in the provenance" begin
        r = _lw_run("#~ :(label1, label2)\na = 1\n#~2 :-label1 :+label2\nb = 2\n"); k = _lw_keys(r)
        for h in (k[3], k[4]); vs = _lw_rows(r, h); @test length(vs) == 1 && vs[1].attr === :label_label2 && vs[1].decided_by == [k[1], k[3], k[3]]; end
        r = _lw_run("#~0 :(++, x, y, z)\n\n#~ :(x, y)\na = 1\n#~2 :-x :z\nb = 2\n#~3 :+x\nc = 3\n"); k = _lw_keys(r)
        @test _lw_labels(r, k[4]) == Set([:label_y, :label_z]) && all(x -> x.decided_by == [k[2], k[4], k[4]], _lw_rows(r, k[4]))
    end

    @testset "[B-W15] the coin case `#~ :-label1 :label1 :+label1` (W45): the plain statement reports — a warning diagnostic — AND the explicit apply applies: a row and a diagnostic at one Component" begin
        # AFTER trace W45: 2 rows — label1 on Blocks #2 / #3, decided_by [#2, #2, #2] (the three statements recorded); 2 diagnostics — cell #2 / #3, stated_by #2, statements [#2, #2] (the statements applied so far at the plain one)
        r = _lw_run("#~ :-label1 :label1 :+label1\nx = 1\n"); @test r.status === GM.PROCESS_OK && length(_lw_recs(r)) == 2; k = _lw_keys(r); _lw_pair(r, 1, [:label1], [k[1], k[1], k[1]])
        d = _lw_diags(r); @test length(d) == 2; _lw_withheld(d[1], :label1, k[1], k[1], [k[1], k[1]]); _lw_withheld(d[2], :label1, k[2], k[1], [k[1], k[1]])
    end

    @testset "[B-W16] THE ENGINE'S DOOR by a CUSTOM registration (MEASURED: D1–D10): a setter's `Vector{Diagnostic}` return delivered with the place merged into each row's context (`cell`, `stated_by`, `statements`), the severity copied; `true`, `nothing` and a bare Diagnostic ignored; an `:error` row flips the status; a non-NamedTuple context kept under `alterant_context`; the place wins over a context's own `cell`" begin
        RET = Ref{Any}(nothing)
        xset(v::GM.Alterants.Visib, a::Symbol, args...) = (GM.Alterants.setVisib(v, :hide); RET[])
        xset(v::GM.Alterants.Visib, a::SubString{String}, args...) = xset(v, Symbol(a), args...)
        b = GM.RegistryBuilder(GM.DEFAULT_REGISTRY); pV = GM.next_plugin_index(b)
        GM.register!(b, GM.Alterant(; altName = :xnote, setMode = :mutExclusive, altConstructor = GM.Alterants.Visib, setAltInstance = xset,
                                      default = GM.Declared(:show), capture = GM.CaptureDecl(:single; attr_stem = :xnote)),
                     GM.ActionSpec(; name = :xnote, plugin = Int8(pV)))
        REG = GM.publish(b); @test pV == 5
        DOC = "#~ xnote\nx = 1\n"
        go(s; profile = nothing) = _lw_run(s; profile = profile, registry = REG)
        xrows(r) = [(x.attr, x.value, x.cell_handle, x.decided_by) for x in _lw_recs(r)]
        # D1 a warning row with a NamedTuple context: 2 rows xnote => :hide (Blocks #2 / #3, decided_by [#2]); 2 diagnostics, the context (k, cell, stated_by, statements)
        RET[] = [GM.Diagnostic(:X_NOTE, :warning, "a note from the setter", (k = 1,))]; r = go(DOC); k = _lw_keys(r)
        @test r.status === GM.PROCESS_OK && xrows(r) == [(:xnote, :hide, k[1], [k[1]]), (:xnote, :hide, k[2], [k[1]])]
        d = _lw_diags(r); @test length(d) == 2 && all(x -> x.code === :X_NOTE && x.severity === :warning && x.message == "a note from the setter", d)
        @test d[1].context == (k = 1, cell = k[1], stated_by = k[1], statements = [k[1]]) && d[2].context == (k = 1, cell = k[2], stated_by = k[1], statements = [k[1]])
        # D2 / D3 / D9: `true`, `nothing`, a bare Diagnostic — the rows as before, nothing delivered
        for ret in (true, nothing, GM.Diagnostic(:X_ONE, :warning, "a bare Diagnostic, not a Vector"))
            RET[] = ret; r = go(DOC); @test r.status === GM.PROCESS_OK && length(xrows(r)) == 2 && isempty(_lw_diags(r))
        end
        # D4 an `:error` row with the context `nothing`: the status PROCESS_ERROR, the rows still delivered, the context the place alone
        RET[] = [GM.Diagnostic(:X_FAIL, :error, "the setter's error row")]; r = go(DOC); k = _lw_keys(r)
        @test r.status === GM.PROCESS_ERROR && length(xrows(r)) == 2 && length(_lw_diags(r)) == 2
        @test _lw_diags(r)[1].severity === :error && _lw_diags(r)[1].context == (cell = k[1], stated_by = k[1], statements = [k[1]]) && _lw_diags(r)[2].context == (cell = k[2], stated_by = k[1], statements = [k[1]])
        # D5 an `:info` row with a String context: kept under `alterant_context`
        RET[] = [GM.Diagnostic(:X_CTX, :info, "a non-NamedTuple context", "ctx")]; r = go(DOC); k = _lw_keys(r)
        @test r.status === GM.PROCESS_OK && _lw_diags(r)[2].severity === :info && _lw_diags(r)[2].context == (alterant_context = "ctx", cell = k[2], stated_by = k[1], statements = [k[1]])
        # D6 two rows in one return: four diagnostics, in the order returned, per Component
        RET[] = [GM.Diagnostic(:X_A, :warning, "first", (k = 1,)), GM.Diagnostic(:X_B, :warning, "second", (k = 2,))]; r = go(DOC); k = _lw_keys(r)
        @test [(x.code, x.context.k, x.context.cell) for x in _lw_diags(r)] == [(:X_A, 1, k[1]), (:X_B, 2, k[1]), (:X_A, 1, k[2]), (:X_B, 2, k[2])]
        # D7 the user level states it (the profile "xnote" over `#~ hide⏎x = 1`): four rows (visib and xnote on each Block); stated_by and statements the user level's handle
        RET[] = [GM.Diagnostic(:X_NOTE, :warning, "a note from the setter", (k = 1,))]; r = go("#~ hide\nx = 1\n"; profile = "xnote"); k = _lw_keys(r)
        @test r.status === GM.PROCESS_OK && length(_lw_recs(r)) == 4 && [x.context for x in _lw_diags(r)] == [(k = 1, cell = k[1], stated_by = _LW_KU, statements = [_LW_KU]), (k = 1, cell = k[2], stated_by = _LW_KU, statements = [_LW_KU])]
        # D8 a context carrying its own `cell` key: the place wins (the key keeps its position)
        RET[] = [GM.Diagnostic(:X_OWN, :warning, "a context carrying its own cell key", (cell = :mine, k = 3))]; r = go(DOC); k = _lw_keys(r)
        @test _lw_diags(r)[1].context == (cell = k[1], k = 3, stated_by = k[1], statements = [k[1]])
        # D10 the file level and a depth-1 statement glued in ONE metaBlock (`#~0 xnote⏎#~ xnote⏎x = 1`): two rows, two diagnostics — stated_by and statements the metaBlock's
        RET[] = [GM.Diagnostic(:X_NOTE, :warning, "a note from the setter", (k = 1,))]; r = go("#~0 xnote\n#~ xnote\nx = 1\n"); k = _lw_keys(r)
        @test r.status === GM.PROCESS_OK && xrows(r) == [(:xnote, :hide, k[1], [k[1]]), (:xnote, :hide, k[2], [k[1]])] && [x.context for x in _lw_diags(r)] == [(k = 1, cell = k[1], stated_by = k[1], statements = [k[1]]), (k = 1, cell = k[2], stated_by = k[1], statements = [k[1]])]
    end

    @testset "[B-W17] the door at the apply loop's FIRST setter call — an outer slot's plain label met by a withhold applied before it: the profile `:-label1` over `#~0 :label1⏎x = 1 #~ hide{ :label1 }` (the measured S_A12): PROCESS_OK, 0 rows, three warning diagnostics in delivery order — the `#~0` metaBlock, the Line `x = 1` (keyed with its trailing metaSegment as the origin, the key of its no-feed `visib` row), the Code Block — each stated by the `#~0` metaBlock, the statements [the user level, the `#~0` metaBlock]" begin
        # AFTER traces S_A12_file_label_inline_segment (no feed: 4 rows — label1 on Blocks #2 / #3 and on the Line, `visib => :hide` on the Line) and its `:-label1` twin (0 rows; 3 diagnostics: cell Block #2 / the Line / Block #3, stated_by Block #2, statements [the user level, Block #2])
        doc = "#~0 :label1\nx = 1 #~ hide{ :label1 }\n"
        r0 = _lw_run(doc); @test r0.status === GM.PROCESS_OK && length(_lw_recs(r0)) == 4; kL = only(x.cell_handle for x in _lw_recs(r0) if x.attr === :visib)
        r = _lw_run(doc; profile = ":-label1"); @test r.status === GM.PROCESS_OK && isempty(_lw_recs(r)); k = _lw_keys(r); @test length(k) == 2 && !(kL in k)
        d = _lw_diags(r); @test length(d) == 3
        _lw_withheld(d[1], :label1, k[1], k[1], [_LW_KU, k[1]]); _lw_withheld(d[2], :label1, kL, k[1], [_LW_KU, k[1]]); _lw_withheld(d[3], :label1, k[2], k[1], [_LW_KU, k[1]])
    end
end
