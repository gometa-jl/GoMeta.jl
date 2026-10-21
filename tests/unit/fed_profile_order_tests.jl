# fed_profile_order_tests.jl — 0.4.1: THE USER LEVEL'S PLACE IN THE APPLY LOOP — the creator's decisions of 2026-10-18
# and 2026-10-19 (the former place of the user level — the loop's first slot — was not intended), replacing
# the placement of 2026-10-16; the cure:
# src/alterants/apply.jl `detAltValuesForSetOfSlots`.
#
# IS:   thirteen witnesses [W1]–[W13] over the public entry, EVERY expected value MEASURED on the cured tree
#       (the FULL delivery views and the `decided_by` traces) and
#       never written before that run. THE THREE LIMBS of the cure under a fed profile: (a) a Component's own metaBlock applies in WRITTEN
#       order — a condition stated before its label does not see that label, as the creator's example files' own comments say ([W1] 026 fed `:label2`,
#       [W2] 027 fed `:doc`, [W5] two documents fed `:label3`, [W8] the Segment overload); (b) a user-level NON-accumulate statement sees the
#       Component's own labels ([W3] on a Segment-carried label, [W4] on a metaBlock's; [W7] the other way — a file condition sees a fed
#       label); (c) an applicable user-level value OVERRIDES the file's — `decided_by` the user context alone, replaced not appended ([W6]
#       over an own CONDITIONED value, [W9] the Id compound replaced whole, [W11] the within-user-level stop and the set-vector's capacity; [W13] a second user-level Id row fills the same fresh instance).
#       The user level's labels are the OUTERMOST level ([W10]: the profile's own NON-accumulate conditions see its labels stated after them; a fed conditional label is blind to
#       the file's labels; a file's conditional label sees a fed label) and the answer function's Labels source under a feed reads `:user`
#       ([W12]). WITHOUT a feed nothing changes — the no-feed twins inside [W1], [W2], [W5], [W6], [W8], [W12].
# REASONING: before the cure the loop took the FIRST eligible slot for the Component's own; with a fed profile that slot was the user
#       level's, so a Component's own labels were collected in the first pass before its own conditions ran (MEASURED
#       before the cure). The cure identifies the own slot by what it is (the first non-user slot), evaluates the user level after
#       it with full sight and with the override; pass 1 walks the user level's slot when fed and the outer slots for their accumulate rows, pass 2 every slot for the rest, so no row is evaluated twice — a row the prior-slot guard, the within-slot
#       `:mutExclusive` stop or the localOnly rule skips is not evaluated at all (the second user-level row of [W11], the `show`). These witnesses pin the three limbs and the declared
#       consequences at the public entry, each against the measured rows. NOT witnessed here: the wider set of fed
#       inputs (measured, pinned by no unit test); the vector of the user level's slot alone
#       (UNMEASURED — no fed oracle input reaches it); the fallBack slot under a feed is pinned by fallback_order_tests.jl [F3] over a test-built slot.
# PURPOSE: the user level's place, measured — never inferred from the feed's docstring or from the loop's comments.

using Test
import GoMeta as GM
const _FO_BLS = GM.BLS

_fo_bytes(s::String) = Vector{UInt8}(codeunits(s))
_fo_run(s::String; profile = nothing) = profile === nothing ? GM.goMeta(_fo_bytes(s)) :
                                                               GM.goMeta(_fo_bytes(s); config = GM.GoMetaConfig(; user_mh_profile = profile))
_fo_recs(r) = collect(r.altValues_evals.records)
_fo_rowset(r) = Set((x.cell_handle, x.attr, x.value) for x in _fo_recs(r))
_fo_visset(r) = Set((x.cell_handle, x.value) for x in _fo_recs(r) if x.attr === :visib)
_fo_cells(r) = unique(x.cell_handle for x in _fo_recs(r))
_fo_attrs(r, h) = Set(x.attr for x in _fo_recs(r) if x.cell_handle == h)
_fo_rows(r, h, a) = [x for x in _fo_recs(r) if x.cell_handle == h && x.attr === a]
_fo_key(r, c) = GM.key_bytes(GM.occurrence_key(r.blsComponentTree, c))      # the key as the Engine's writer derives it
_fo_blocks(r) = _FO_BLS.children(r.blsComponentTree)
const _FO_UC = GM.key_bytes(GM.user_context_key(:default, 1))
const _FO_CORPUS = joinpath(@__DIR__, "..", "golden", "corpus", "InFileFolder")   # 026 / 027 byte-identical to the measurement inputs

@testset "the user level's place in the apply loop (0.4.1)" begin

    @testset "[W1] 026 fed `:label2`: every Visib value the no-feed run's; every cell with rows carries label_label2; Block #6's and #7's hide decided by Block #2" begin
        # MEASURED: 38 rows = the no-feed 28 + one label_label2 per cell with rows (10 cells); Blocks #6 / #7 `visib => :hide`,
        # decided_by[1] = Block #2 (the depth-1 `hide{ :label4 , isCode }`) — the creator's comment at 026 lines 26–29 holds under a feed
        doc = read(joinpath(_FO_CORPUS, "file_for_Example_Proposal_JuliaCon.jl"), String)
        rf = _fo_run(doc; profile = ":label2"); rn = _fo_run(doc)
        @test rf.status === GM.PROCESS_OK && rn.status === GM.PROCESS_OK
        @test _fo_visset(rf) == _fo_visset(rn)
        @test length(_fo_cells(rf)) == 10 && all(h -> :label_label2 in _fo_attrs(rf, h), _fo_cells(rf))
        @test _fo_rowset(rn) ⊆ _fo_rowset(rf)
        @test setdiff(_fo_rowset(rf), _fo_rowset(rn)) == Set((h, :label_label2, true) for h in _fo_cells(rf))
        @test length(_fo_recs(rf)) == 38 && length(_fo_recs(rn)) == 28
        bs = _fo_blocks(rf); @test length(bs) == 8                               # Blocks #2–#9 of the FULL view
        b2, b6, b7 = bs[1], bs[5], bs[6]
        @test _FO_BLS.kind(b2) === :Meta && _FO_BLS.kind(b6) === :Meta && _FO_BLS.kind(b7) === :Text
        for b in (b6, b7)
            vs = _fo_rows(rf, _fo_key(rf, b), :visib); @test length(vs) == 1
            @test vs[1].value === :hide && vs[1].decided_by == [_fo_key(rf, b2)]
        end
    end

    @testset "[W2] 027 fed `:doc`: every Visib value the no-feed run's; every cell with rows carries label_doc; Block #7 no Visib row; Block #8's hide decided by Block #5" begin
        # MEASURED: 34 rows = the no-feed 24 + one label_doc per cell with rows (10 cells); Block #7 (`#~3 discard{:label4} :label4`)
        # carries no Visib row; Block #8 `visib => :hide`, decided_by[1] = Block #5 — the creator's comment at 027 lines 41–42 holds under a feed
        doc = read(joinpath(_FO_CORPUS, "file_for_Example_Extended.jl"), String)
        rf = _fo_run(doc; profile = ":doc"); rn = _fo_run(doc)
        @test rf.status === GM.PROCESS_OK && rn.status === GM.PROCESS_OK
        @test _fo_visset(rf) == _fo_visset(rn)
        @test length(_fo_cells(rf)) == 10 && all(h -> :label_doc in _fo_attrs(rf, h), _fo_cells(rf))
        @test setdiff(_fo_rowset(rf), _fo_rowset(rn)) == Set((h, :label_doc, true) for h in _fo_cells(rf))
        @test length(_fo_recs(rf)) == 34 && length(_fo_recs(rn)) == 24
        bs = _fo_blocks(rf); @test length(bs) == 9                               # Blocks #2–#10 of the FULL view
        b5, b7, b8 = bs[4], bs[6], bs[7]
        @test _FO_BLS.kind(b5) === :Meta && _FO_BLS.kind(b7) === :Meta && _FO_BLS.kind(b8) === :Text
        @test isempty(_fo_rows(rf, _fo_key(rf, b7), :visib))
        vs = _fo_rows(rf, _fo_key(rf, b8), :visib); @test length(vs) == 1 && vs[1].value === :hide && vs[1].decided_by == [_fo_key(rf, b5)]
    end

    @testset "[W3] `x = 1 #~ :label1` fed `discard{ :label1 }`: the fed condition sees a Segment-carried own label — the Line discarded, decided by the user context" begin
        # MEASURED: 2 rows on the Line — label_label1 (decided_by the Segment), visib :discard (decided_by [uc]); source :user
        rf = _fo_run("x = 1 #~ :label1\n"; profile = "discard{ :label1 }")
        recs = _fo_recs(rf); @test length(recs) == 2
        @test length(unique(x.cell_handle for x in recs)) == 1           # ONE cell — the Line; a Segment-carried row's handle carries the Segment as its origin, so it is not the Line's plain occurrence key
        lab = [x for x in recs if x.attr === :label_label1]; vis = [x for x in recs if x.attr === :visib]
        @test length(lab) == 1 && length(lab[1].decided_by) == 1 && lab[1].decided_by[1] != _FO_UC
        @test length(vis) == 1 && vis[1].value === :discard && vis[1].decided_by == [_FO_UC]
        bs = _fo_blocks(rf); @test length(bs) == 1
        ls = _FO_BLS.children(rf.blsComponentTree, bs[1]); @test length(ls) == 1
        a = GM.evaluatedAltValue(rf, ls[1], :Visib); @test a.value === :discard && a.source === :user
    end

    @testset "[W4] `#~ :label1⏎x = 1` fed `discard{ :label1 }`: the fed condition sees the metaBlock's own label — both Blocks discarded" begin
        # MEASURED: 4 rows — label_label1 and visib :discard (decided_by [uc]) on both Blocks
        rf = _fo_run("#~ :label1\nx = 1\n"; profile = "discard{ :label1 }")
        @test length(_fo_recs(rf)) == 4
        bs = _fo_blocks(rf); @test length(bs) == 2
        for b in bs
            h = _fo_key(rf, b)
            @test _fo_attrs(rf, h) == Set([:label_label1, :visib])
            vis = _fo_rows(rf, h, :visib); @test length(vis) == 1 && vis[1].value === :discard && vis[1].decided_by == [_FO_UC]
            @test GM.evaluatedAltValue(rf, b, :Visib).source === :user
        end
    end

    @testset "[W5] two documents fed `:label3`: a label stated AFTER the heading or the `hide` is not seen — the fed label adds its row and leaves the heading and the Visib rows the no-feed run's" begin
        # MEASURED: fed `:label3` — the heading document 4 rows (label_label2, label_label3 on both Blocks; NO head row) and
        # the hide document 4 rows (label_label1, label_label3 on both; NO visib row); the no-feed twins 2 rows each
        p24 = "#~2 head(\"T\"){ :label2 } :label2\nx = 1\n"; p25 = "#~ hide{ :label1 } :label1\nx = 1\n"
        f24 = _fo_run(p24; profile = ":label3"); n24 = _fo_run(p24)
        @test !any(x -> startswith(String(x.attr), "head"), _fo_recs(f24)) && !any(x -> startswith(String(x.attr), "head"), _fo_recs(n24))
        @test _fo_rowset(n24) ⊆ _fo_rowset(f24)
        @test setdiff(_fo_rowset(f24), _fo_rowset(n24)) == Set((h, :label_label3, true) for h in _fo_cells(f24))
        @test length(_fo_recs(f24)) == 4 && length(_fo_recs(n24)) == 2
        f25 = _fo_run(p25; profile = ":label3"); n25 = _fo_run(p25)
        @test isempty(_fo_visset(f25)) && isempty(_fo_visset(n25))
        @test _fo_rowset(n25) ⊆ _fo_rowset(f25)
        @test setdiff(_fo_rowset(f25), _fo_rowset(n25)) == Set((h, :label_label3, true) for h in _fo_cells(f25))
        @test length(_fo_recs(f25)) == 4 && length(_fo_recs(n25)) == 2
    end

    @testset "[W6] `#~ :label1 hide{ :label1 }⏎x = 1` fed `show`: the override over an own CONDITIONED value — show, decided by the user context alone (replaced, not appended)" begin
        # MEASURED: visib :show on both Blocks, decided_by == [uc] (length 1); the no-feed twin: visib :hide on both
        d = "#~ :label1 hide{ :label1 }\nx = 1\n"
        rf = _fo_run(d; profile = "show"); rn = _fo_run(d)
        @test length(_fo_cells(rn)) == 2 && _fo_visset(rn) == Set((h, :hide) for h in _fo_cells(rn))
        bs = _fo_blocks(rf); @test length(bs) == 2
        for b in bs
            vis = _fo_rows(rf, _fo_key(rf, b), :visib); @test length(vis) == 1 && vis[1].value === :show && vis[1].decided_by == [_FO_UC]
            @test GM.evaluatedAltValue(rf, b, :Visib).source === :user
        end
    end

    @testset "[W7] `#~ hide{ :label1 }⏎x = 1` and `#~0 hide{ :label1 }⏎x = 1` fed `:label1`: a file condition sees the fed label — hide, decided by the file's metaBlock" begin
        # MEASURED: label_label1 decided_by [uc]; visib :hide decided_by the first Block, on both Blocks
        for d in ("#~ hide{ :label1 }\nx = 1\n", "#~0 hide{ :label1 }\nx = 1\n")
            rf = _fo_run(d; profile = ":label1"); bs = _fo_blocks(rf); @test length(bs) == 2
            @test length(_fo_recs(rf)) == 4
            for b in bs
                h = _fo_key(rf, b)
                vis = _fo_rows(rf, h, :visib); @test length(vis) == 1 && vis[1].value === :hide && vis[1].decided_by == [_fo_key(rf, bs[1])]
                lab = _fo_rows(rf, h, :label_label1); @test length(lab) == 1 && lab[1].decided_by == [_FO_UC]
            end
        end
    end

    @testset "[W8] `x = 1 #~ hide{ :label1 } :label1` fed `:label2`: the Segment overload's own slot is the line slot — written order, no hide" begin
        # MEASURED: 2 rows on the Line — label_label2, label_label1; NO visib row; the no-feed twin: 1 row (label_label1)
        d = "x = 1 #~ hide{ :label1 } :label1\n"
        rf = _fo_run(d; profile = ":label2"); rn = _fo_run(d)
        @test isempty(_fo_visset(rf)) && length(_fo_recs(rf)) == 2 && Set(x.attr for x in _fo_recs(rf)) == Set([:label_label1, :label_label2])
        @test isempty(_fo_visset(rn)) && length(_fo_recs(rn)) == 1
    end

    @testset "[W9] `#~ parent(2)⏎x = 1` fed `cell(7)`: the Id compound replaced WHOLE — `cell 7` alone, decided by the user context (as before 0.4.1); an own row that fails at evaluation fails the fed run as it fails the no-feed one" begin
        # MEASURED: `#~ cell(x)⏎x = 1` fed `cell(7)`
        # throws `ArgumentError: invalid base 10 digit 'x' in "x"` out of the goMeta call — the error the no-feed run throws (before the cure
        # the fed run was PROCESS_OK with `cell 7` on both Blocks, the own row skipped unevaluated)
        @test_throws ArgumentError _fo_run("#~ cell(x)\nx = 1\n"; profile = "cell(7)")
        @test_throws ArgumentError _fo_run("#~ cell(x)\nx = 1\n")
        # MEASURED: exactly 2 rows — id_cell => 7 on both Blocks, decided_by [uc]; no id_parent row
        rf = _fo_run("#~ parent(2)\nx = 1\n"; profile = "cell(7)")
        recs = _fo_recs(rf); @test length(recs) == 2
        @test all(x -> x.attr === :id_cell && x.value == 7 && x.decided_by == [_FO_UC], recs)
    end

    @testset "[W10] the user level the OUTERMOST level: the profile's own non-accumulate conditions see its labels stated after them; a fed conditional label blind to the file's labels; a file conditional label sees a fed label" begin
        # MEASURED — the first document: 6 rows, visib :discard (decided_by [uc]) and label_label1 + label_label3 on both Blocks; the second: exactly 2 rows, both
        # label_label1 (no label_label2); the third: 4 rows, label_label2 + label_label3 on both Blocks
        r11 = _fo_run("#~ :label3\nx = 1\n"; profile = "discard{ :label1 } :label1")
        @test length(_fo_recs(r11)) == 6
        for b in _fo_blocks(r11)
            h = _fo_key(r11, b); @test _fo_attrs(r11, h) == Set([:label_label1, :label_label3, :visib])
            vis = _fo_rows(r11, h, :visib); @test length(vis) == 1 && vis[1].value === :discard && vis[1].decided_by == [_FO_UC]
        end
        r12 = _fo_run("#~ :label1\nx = 1\n"; profile = ":label2{ :label1 }")
        @test length(_fo_recs(r12)) == 2 && all(x -> x.attr === :label_label1, _fo_recs(r12))
        r16 = _fo_run("#~ :label3{ :label2 }\nx = 1\n"; profile = ":label2")
        @test length(_fo_recs(r16)) == 4 && length(_fo_cells(r16)) == 2 && all(h -> _fo_attrs(r16, h) == Set([:label_label2, :label_label3]), _fo_cells(r16))
    end

    @testset "[W11] the within-user-level stop after an override; four Alterants set in the own slot, two overridden (the set-vector's capacity)" begin
        # MEASURED: `#~ hide :label1⏎x = 1` fed `discard{ :label1 } show` — visib :discard (decided_by [uc]) on both Blocks, the `show` stopped;
        # `#~ "T" :label1 hide cell(2)⏎x = 1` fed `show cell(7)` — 7 rows: Block #2 label_label1, visib :show [uc], id_cell 7 [uc], head_1 "T"
        # (decided_by Block #2); Block #3 label_label1, visib :show [uc], id_cell 7 [uc]
        r13 = _fo_run("#~ hide :label1\nx = 1\n"; profile = "discard{ :label1 } show")
        @test length(_fo_recs(r13)) == 4
        for b in _fo_blocks(r13)
            vis = _fo_rows(r13, _fo_key(r13, b), :visib); @test length(vis) == 1 && vis[1].value === :discard && vis[1].decided_by == [_FO_UC]
        end
        r14 = _fo_run("#~ \"T\" :label1 hide cell(2)\nx = 1\n"; profile = "show cell(7)")
        @test length(_fo_recs(r14)) == 7
        bs = _fo_blocks(r14); @test length(bs) == 2
        h2, h3 = _fo_key(r14, bs[1]), _fo_key(r14, bs[2])
        @test _fo_attrs(r14, h2) == Set([:label_label1, :visib, :id_cell, :head_1]) && _fo_attrs(r14, h3) == Set([:label_label1, :visib, :id_cell])
        for h in (h2, h3)
            vis = _fo_rows(r14, h, :visib); @test length(vis) == 1 && vis[1].value === :show && vis[1].decided_by == [_FO_UC]
            idc = _fo_rows(r14, h, :id_cell); @test length(idc) == 1 && idc[1].value == 7 && idc[1].decided_by == [_FO_UC]
        end
        hd = _fo_rows(r14, h2, :head_1); @test length(hd) == 1 && hd[1].value == "T" && hd[1].decided_by == [h2]
    end

    @testset "[W13] `#~ cell(2)⏎x = 1` fed `cell(7) parent(3)`: the user level's second Id row fills the SAME fresh instance — no second rebuild (the override guard's in-slot clause)" begin
        # MEASURED 2026-10-19 — every value below from the measured trace: id_cell => 7 decided_by ['USER_CONTEXT', 'USER_CONTEXT']; id_parent => 3 decided_by ['USER_CONTEXT', 'USER_CONTEXT']
        rf = _fo_run("#~ cell(2)\nx = 1\n"; profile = "cell(7) parent(3)")
        @test rf.status === GM.PROCESS_OK
        bs = _fo_blocks(rf); @test length(bs) == 2
        @test length(_fo_recs(rf)) == 4
        for b in bs
            h = _fo_key(rf, b)
            @test _fo_attrs(rf, h) == Set([:id_cell, :id_parent])
            r_id_cell = _fo_rows(rf, h, :id_cell); @test length(r_id_cell) == 1 && r_id_cell[1].value == 7 && r_id_cell[1].decided_by == [_FO_UC, _FO_UC]
            r_id_parent = _fo_rows(rf, h, :id_parent); @test length(r_id_parent) == 1 && r_id_parent[1].value == 3 && r_id_parent[1].decided_by == [_FO_UC, _FO_UC]
        end
    end

    @testset "[W12] the answer function's Labels source under a feed: `:user` on 026's Blocks #6 / #7 (no feed: `:indirect`) and on the `#~0` document's Code Block; its Labels rows' `decided_by` begin with the user context" begin
        # MEASURED: Blocks (direct,6) / (direct,7) `labels … source=user`; the no-feed run: `source=indirect`;
        # MEASURED (`#~0 :label1⏎x = 1` fed `:label2`): the Code Block `source=user` (before 0.4.1: `indirect`)
        doc = read(joinpath(_FO_CORPUS, "file_for_Example_Proposal_JuliaCon.jl"), String)
        rf = _fo_run(doc; profile = ":label2"); rn = _fo_run(doc)
        bs = _fo_blocks(rf); bn = _fo_blocks(rn); @test length(bs) == 8 && length(bn) == 8
        for i in (5, 6)
            @test GM.evaluatedAltValue(rf, bs[i], :labels).source === :user
            @test GM.evaluatedAltValue(rn, bn[i], :labels).source === :indirect
        end
        rb = _fo_run("#~0 :label1\nx = 1\n"; profile = ":label2"); bb = _fo_blocks(rb); @test length(bb) == 2
        @test GM.evaluatedAltValue(rb, bb[2], :labels).source === :user
        # MEASURED: 4 rows, every one `decided_by` [USER_CONTEXT, Block #2 — the `#~0` metaBlock] — the user context FIRST (the cure
        # changed this document's order and answer source alone)
        @test length(_fo_recs(rb)) == 4 && all(x -> x.decided_by == [_FO_UC, _fo_key(rb, bb[1])], _fo_recs(rb))
    end
end
