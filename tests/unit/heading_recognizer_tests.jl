# heading_recognizer_tests.jl — the heading lane's unit guards (APPEND-ONLY).
#
# IS:   the STRING-LANE WIDENING (this file's first population) and, after it, the
#       quoted-first recognizer + level law + Heading registration rows assigned
#       here. At the widening ONLY the mechanics landed: quote-aware parseArgs, the widened
#       Symbol|String args wall (AlterantArgT), the kind-preserving coercion, and the quote
#       NEGATIVE rows — while NO metaLine grammar accepts a string argument (the widening's gate:
#       suite byte-identical before any grammar accepts strings). The law is held by a
#       TRANSITIONAL guarded refusal at absorbMeta's ENQUEUE seam — dispatch CANNOT hold it,
#       because the built-in toy setters keep an UNTYPED value slot (`setId` parses
#       `string(idValue)`, so `cell("7")` would silently ACCEPT through dispatch;
#       byte-probed).
# DOES: [SL] String-lane mechanism rows (test_quoted_arg_single_token ·
#       test_comma_inert_inside_quotes · test_kind_preserving_coercion ·
#       test_args_wall_widened) · [SLN] the quote negative rows (unterminated · escaped ·
#       malformed/glued, on the parseArgs route; the former quote-blind one-word-label route is gone —
#       a '"' after ':' meets the grammar's one refusal, the rows below) ·
#       [SLE] end-to-end: a quoted argument at the metaLine surface meets the TRANSITIONAL
#       guarded refusal at the enqueue seam (nothing accepted strings at the widening; the heading build carved
#       the head text slot out — the heading sections below own that surface), and the
#       pre-widening quote-free envelope is untouched (numeric args stay Symbol-kind — the integer
#       space is RESERVED out of the literal floor).
# PURPOSE: the widened lane is proven present AND provably not yet accepting — the widening's law.

using Test
import GoMeta as GM

@testset "heading lane — the String-lane widening (mechanism only)" begin

    _pa(s) = GM.AbsorbMeta.parseArgs(SubString{String}(s), 1)   # s[1] == '('
    _run(s) = GM.goMeta(Vector{UInt8}(codeunits(s)))
    _err(s) = try
        _run(s)
        nothing
    catch e
        e
    end

    @testset "[SL] test_quoted_arg_single_token — a quoted span is ONE token, delimiters kept" begin
        (ind, toks) = _pa("(\"a, b\")")
        @test toks == ["\"a, b\""]                       # the comma is CONTENT
        @test length(toks) == 1
        # parens inside quotes are content too — the list closes at the REAL ')'
        (ind2, toks2) = _pa("(\"a)b\")")
        @test toks2 == ["\"a)b\""]
        # and whitespace inside quotes survives verbatim (only token EDGES are stripped)
        (_, toks3) = _pa("(  \" a  b \"  )")
        @test toks3 == ["\" a  b \""]
    end

    @testset "[SL] test_comma_inert_inside_quotes — quote-aware splitting" begin
        (_, toks) = _pa("(\"a,b\", c)")
        @test toks == ["\"a,b\"", "c"]
        (_, toks2) = _pa("(x, \"y, z\", w)")
        @test toks2 == ["x", "\"y, z\"", "w"]
    end

    @testset "[SL] test_kind_preserving_coercion — quoted ⇒ String content, bare ⇒ Symbol" begin
        @test GM.AbsorbMeta._coerce_arg_token(SubString{String}("\"a b\"")) === "a b"
        @test GM.AbsorbMeta._coerce_arg_token(SubString{String}("abc")) === :abc
        # the empty quoted token is the empty String (delimiters stripped), not a Symbol
        @test GM.AbsorbMeta._coerce_arg_token(SubString{String}("\"\"")) === ""
        # NUMERIC text stays a Symbol — the integer space is RESERVED out of the floor
        # the coercion NEVER mints an Int, so numeric args keep their byte-exact
        # pre-widening fates at the setter (cell(7) accepted; cell(99999) is `parse`'s own OverflowError
        # since 0.4.0; the working form pinned in arg_guard_tests.jl)
        @test GM.AbsorbMeta._coerce_arg_token(SubString{String}("7")) === Symbol("7")
        @test GM.AbsorbMeta._coerce_arg_token(SubString{String}("99999")) === Symbol("99999")
    end

    @testset "[SL] test_args_wall_widened — the wall carries Symbol|String; ints stay OUT" begin
        @test (:a, "b") isa Tuple{Vararg{GM.AlterantArgT}}
        @test (:a,) isa Tuple{Vararg{GM.AlterantArgT}}
        @test ("a",) isa Tuple{Vararg{GM.AlterantArgT}}
        @test !((1,) isa Tuple{Vararg{GM.AlterantArgT}})          # integer space RESERVED
        @test !((:a, 1) isa Tuple{Vararg{GM.AlterantArgT}})
        @test fieldtype(GM.AlterantQueue, :args) ==
              Matrix{Union{Nothing,Tuple{Vararg{GM.AlterantArgT}}}}
        @test GM.AlterantArgT == Union{Symbol,String}             # the floor, EXACTLY
    end

    @testset "[SLN] quote negative rows — loud refusals, never a silent mangle" begin
        # unterminated quoted argument
        e1 = try _pa("(\"abc)"); nothing catch e; e end
        @test e1 isa ErrorException && occursin("unterminated '\"'", e1.msg)
        # backslash — the WHOLE backslash character is RESERVED inside quoted spans at
        # v0.2 (creator-broadened from the former `\"`-only reservation)
        e2 = try _pa("(\"a\\\"b\")"); nothing catch e; e end
        @test e2 isa ErrorException && occursin("backslash in a quoted span", e2.msg)
        e2b = try _pa("(\"a\\b\")"); nothing catch e; e end        # lone mid-span backslash
        @test e2b isa ErrorException && occursin("backslash in a quoted span", e2b.msg)
        # a quote glued to bare text is a malformed quoted argument …
        e3 = try _pa("(ab\"cd\")"); nothing catch e; e end
        @test e3 isa ErrorException && occursin("malformed quoted argument", e3.msg)
        # … and so is a token carrying more than one span
        e4 = try _pa("(\"a\" \"b\")"); nothing catch e; e end
        @test e4 isa ErrorException && occursin("malformed quoted argument", e4.msg)
    end

    @testset "[SLE] no grammar accepts strings at the widening — the transitional wall + untouched pre-widening envelope" begin
        # a quoted argument at the metaLine surface flows the route as a String KIND and
        # meets the TRANSITIONAL guarded refusal at absorbMeta's enqueue seam. The wall must
        # sit THERE, not at dispatch: the built-in toy setters keep an UNTYPED value slot, so
        # `cell("7")` would otherwise silently ACCEPT (parse(Int16, string("7")) succeeds)
        # — the byte-probed reason this row exists. `cell("7")` is therefore the SHARPEST
        # witness of the widening's law: text that WOULD be accepted through dispatch refuses.
        for s in ["#~ cell(\"7\")\n# c\n", "#~ hide(\"x\")\n# c\n"]
            err = _err(s)
            @test err isa ErrorException
            @test occursin("string argument not accepted", err.msg)
            @test occursin("GoMeta absorb:", err.msg)
        end
        # the unterminated-quote refusal reaches the surface as an absorb refusal naming the INNERMOST opener left open — the quote,
        # before the enclosing '(' (the one scanner of the metaLine parser — the creator's decision)
        eu = _err("#~ cell(\"x\n# c\n")
        @test eu isa ErrorException && occursin("unterminated '\"'", eu.msg)
        # THE LABEL ROUTE since 0.4.0: the six structural characters end a name or a
        # label, so a '"' after ':' or inside a label meets the grammar's one refusal naming the character — the quote lane's former
        # coercion-side validation of a quote-blind label token is gone with the quote-blind route
        el1 = _err("#~ :\"x\"\n# c\n")
        @test el1 isa ErrorException && occursin("unexpected character '\"' after ':'", el1.msg)
        el2 = _err("#~ :\"ab\n# c\n")
        @test el2 isa ErrorException && occursin("unexpected character '\"' after ':'", el2.msg)
        el3 = _err("#~ :\"\n# c\n")
        @test el3 isa ErrorException && occursin("unexpected character '\"' after ':'", el3.msg)
        # … and a label token merely CONTAINING a quote ends at it (the quote is structural): the refusal names the quote
        ed = _err("#~ :a\"b\n# c\n")
        @test ed isa ErrorException && occursin("unexpected character '\"' after the metaStatement \":a\"", ed.msg)
        # QUOTE × INVALID UTF-8 (the module's own doctrine class): a quoted span carrying
        # an invalid byte sequence stays a LOUD guarded refusal, never a raw decode crash —
        # and the CLASS is pinned (the span is well-formed, its content the
        # invalid byte, so the fate is the transitional wall, not some accidental refusal)
        ei = _err("#~ cell(\"\xff\")\n# c\n")
        @test ei isa ErrorException && occursin("string argument not accepted", ei.msg)
        # the quote-free pre-widening envelope is byte-untouched: the working numeric form still
        # works (its full fate battery lives in arg_guard_tests.jl — this row is the
        # widening's sentinel that the widening changed nothing for it)
        r = _run("#~ cell(7)\n# c\n")
        @test string(r.status) == "PROCESS_OK"
    end
end

@testset "heading lane: recognizer + level law + registration (the creator's names)" begin

    _run(s) = GM.goMeta(Vector{UInt8}(codeunits(s)))
    _err(s) = try
        _run(s)
        nothing
    catch e
        e
    end
    _heads(r) = [(a, v) for (_, a, v, _) in GM.readAltValuesEvals(r.altValues_evals) if startswith(String(a), "head")]

    @testset "test_quoted_first_lowering — the sugar lowers to the deriving head call" begin
        # the fenced first-position String becomes the head action's argument; the level
        # derives from the attachment (the MetaContext record) and rides the row's attr.
        # LEVEL VOCABULARY (the unification decision): the derived
        # recording is the AUTHOR's own `#~`-digit vocabulary (ladder−1, normalized
        # at the enqueue seam) — plain `#~` ⇒ head_1; it COINCIDES with the explicit
        # sibling's as-given vocabulary (`#~2 "T"` ≡ `head("T", 2)` ⇒ head_2).
        r = _run("#~ \"Title\"\nx = 1\n")
        @test string(r.status) == "PROCESS_OK"
        @test (:head_1, "Title") in _heads(r)
        # sugar composes with a following label and with a GLUED condition block (the
        # existing envelope's condition-attachment law — spaced '{' refuses today for
        # every action; the sugar changes nothing there). The settribute condition
        # evaluates ONCE, at the apply of the Component the heading is applied to — the metaBlock (the creator's decision; before it the metaLine's own snapshot at the absorb seam): a metaBlock is not Code, so
        # { isCode } is FALSE there — zero rows, no refusal (the decided flip of the evals rows
        # from the queued era's per-cell evaluation, pinned here)
        @test string(_run("#~ \"T\" :label1\nx = 1\n").status) == "PROCESS_OK"
        ric = _run("#~ \"T\"{ isCode }\nx = 1\n")
        @test string(ric.status) == "PROCESS_OK"
        @test isempty(_heads(ric))
        # the recognizer sets the token inds: a bare quoted heading parses with no BoundsError
        # (the no-token guard this comment once named was removed)
        @test isempty([e for e in [_err("#~ \"T\"\nx = 1\n")] if e !== nothing])
    end

    @testset "test_level_from_attachment — attachment-derived, metaSegment inherits the metaLine" begin
        # depth-marked attachment: `#~2` records head_2 — the author's own digit
        # (ladder 3, normalized −1 at the seam), coinciding with the
        # explicit `head("Sub", 2)`
        r2 = _run("#~2 \"Sub\"\nx = 1\n")
        @test (:head_2, "Sub") in _heads(r2)
        # the SEGMENT-attached heading (inline `#~ "…"` after code — SPACED: the walk's
        # header regex consumes a GLUED token as its metaDef, so only the spaced form
        # reaches absorb) inherits the metaLine's level — the walk sets lineMHIdx (11)
        # for segment metas; the RECORDED level is the documented vocabulary constant
        # 10 (lineMHIdx−1 — no depth-digit spelling exists for the inline surface):
        rs = _run("x = 1 #~ \"T\"\ny = 2\n")
        @test string(rs.status) == "PROCESS_OK"
        @test (:head_10, "T") in _heads(rs)
    end

    @testset "test_depth_existing_rows_only — the level rides EXISTING head rows, none fabricated" begin
        # the level fact appears ONLY in head-row attrs (`:head_<level>`); a heading input
        # mints NO extra non-head rows vs its heading-free twin (row-set equality on the
        # non-head attrs) — no fabricated rows
        rh = _run("#~ \"Title\"\nx = 1\n")
        rn = _run("# plain\nx = 1\n")
        nonhead(r) = sort([String(a) for (_, a, _, _) in GM.readAltValuesEvals(r.altValues_evals) if !startswith(String(a), "head")])
        @test nonhead(rh) == nonhead(rn) == String[]
        @test !isempty(_heads(rh))
    end

    @testset "test_non_first_quote_refusal — the non-first-quote reservation stands: the grammar's one refusal names the quote" begin
        e = _err("#~ hide \"T\"\nx = 1\n")
        @test e isa ErrorException && occursin("unexpected character '\"' at the start of a metaStatement", e.msg)
        @test occursin("heading sugar at the region's first metaStatement only", e.msg)
    end

    @testset "test_empty_quote_lowers — BOTH halves: enters the recognizer, then the standing refusal" begin
        # (conscious pin flip: the refusal was TRANSITIONAL until the creator decided it
        # as the standing v0.2 semantic; the message says so)
        e = _err("#~ \"\"\nx = 1\n")
        @test e isa ErrorException
        @test !occursin("unexpected punctuation", e.msg)          # half 1: NOT the old wall (the wall itself was removed)
        @test occursin("empty heading text", e.msg)               # half 2: Heading validation
        @test occursin("a standing decision", e.msg)       # standing, not transitional
    end

    @testset "heading-lane quote refusals (siblings of the argument-lane classes)" begin
        eu = _err("#~ \"abc\nx = 1\n")
        @test eu isa ErrorException && occursin("unterminated '\"'", eu.msg)
        # THE BACKSLASH RESERVATION (creator-broadened): ANY `\`
        # inside the span refuses — not merely `\"`. The earlier grammar accepted `"a\b"`
        # while refusing `"a\\"` (the trailing backslash read as `\"`) — that ragged
        # acceptance is exactly what the reservation closed; all four shapes now meet ONE
        # guarded refusal, and the future escape grammar mints on a clean slate.
        ee = _err("#~ \"a\\\"b\"\nx = 1\n")
        @test ee isa ErrorException && occursin("backslash in a quoted span", ee.msg)
        el = _err("#~ \"a\\b\"\nx = 1\n")                          # lone mid-span backslash
        @test el isa ErrorException && occursin("backslash in a quoted span", el.msg)
        et = _err("#~ \"a\\\\\"\nx = 1\n")                         # trailing double backslash
        @test et isa ErrorException && occursin("backslash in a quoted span", et.msg)
        # the ARGUMENT-lane twin holds the same law (sugar ≡ canonical): a backslash
        # inside a quoted canonical-call argument refuses in the one scanner _span
        ea = _err("#~ head(\"a\\b\")\nx = 1\n")
        @test ea isa ErrorException && occursin("backslash in a quoted span", ea.msg)
    end

    @testset "test_usermh_heading_refusal — a heading in the profile feed meets the ONE refusal at the read" begin
        # the sugar, the deriving form and the explicit form alike — the feed has no Component of the
        # file levels (the creator's term) for a statement of the set mode `localOnly` to be local to (before: the deriving form met
        # "heading without a document context", the explicit form recorded one row against the user-context handle)
        for prof in ("\"T\"", "head(\"T\")", "head(\"U\", 3)")
            e = try
                GM.goMeta(Vector{UInt8}(codeunits("x = 1\n")); config = GM.GoMetaConfig(user_mh_profile = prof))
                nothing
            catch er
                er
            end
            @test e isa ErrorException && occursin("a heading (Heading Alterant) in the profile feed has no Component of the file levels to be local to", e.msg)
        end
    end

    @testset "canonical calls — position-free deriving + the explicit sibling (N6 pair)" begin
        # deriving canonical, first AND non-first position (canonical calls are
        # position-free within applicability; only the SUGAR is first-position)
        @test (:head_1, "T") in _heads(_run("#~ head(\"T\")\nx = 1\n"))
        @test (:head_1, "T") in _heads(_run("#~ :label1 head(\"T\")\nx = 1\n"))
        # the explicit sibling stores its level AS GIVEN (user vocabulary; Symbol text
        # through the literal floor, parsed setId-style at the store)
        @test (:head_2, "T") in _heads(_run("#~ head(\"T\", 2)\nx = 1\n"))
        @test (:head_7, "T") in _heads(_run("#~ head(\"T\", 7)\nx = 1\n"))
        # (the three refusals at the former set-invocation seam were removed — a non-parseable
        # level, the text missing, a bare-word text: Julia's own errors now, measured before and after the change)
    end

    @testset "the set mode `:localOnly` through the apply loop (witnesses)" begin
        # LOCALITY: one heading governing several components mints EXACTLY ONE row,
        # keyed to the occurrence handle of the metaBLOCK the metaLine forms (since 0.4.0 —
        # before it, the metaLine's own Line; the outline model): the apply loop's ONE RULE for the
        # set mode `localOnly` — a row applies only at the Component the statement is applied to; the attached Code Block
        # and the Lines pass over it (the creator's words: "applied to the first Block only, that is it"). The per-component
        # inheritance repetition of the first build is GONE.
        rl = _run("#~ \"Title\"\nx = 1\ny = 2\nz = 3\n")
        @test string(rl.status) == "PROCESS_OK"
        @test length(_heads(rl)) == 1 && (:head_1, "Title") in _heads(rl)
        # the row's handle is the occurrence handle of the metaBLOCK the metaLine forms, computed
        # from the delivered tree (`blsComponentTree`; the Engine's `occurrence_key` + `key_bytes`, the default namespace)
        hrow = only([h for (h, a, _, _) in GM.readAltValuesEvals(rl.altValues_evals) if startswith(String(a), "head")])
        ml = only(l for b in GM.BLS.children(rl.blsComponentTree) for l in GM.BLS.children(rl.blsComponentTree, b)
                    if GM.BLS.getElement(l, :inputLineNum) == 1)   # the metaLine at input line 1, through the door
        mb = GM.BLS.parent(rl.blsComponentTree, ml)                   # the metaBlock it forms — the row's Component
        @test hrow == GM.key_bytes(GM.occurrence_key(rl.blsComponentTree, mb; namespace = :default))
        @test hrow != GM.key_bytes(GM.occurrence_key(rl.blsComponentTree, ml; namespace = :default))   # no longer the Line's
        # A LATER same-depth metaLine (which reuses/wipes the slot) cannot disturb an earlier heading's row: the metaBlock is
        # queued, applied and recorded in one step of the walk, before the next region's wipe
        rw = _run("#~ \"A\"\nx = 1\n#~ :label1\ny = 2\n")
        @test (:head_1, "A") in _heads(rw)
        # THE CONDITION, true arm: a heading's condition is evaluated at the apply of the Component the heading is applied to
        # (the metaBlock — the creator's decision) — a true condition mints ONE row, never one per governed
        # cell (the false arm is pinned in test_quoted_first_lowering above)
        rc1 = _run("#~ \"T\"{ isMeta }\nx = 1\ny = 2\n")
        @test string(rc1.status) == "PROCESS_OK"
        @test length(_heads(rc1)) == 1
        # a WHOLE-LINE heading's condition reads the metaBlock's facts (the creator's decision; MEASURED before and after the change) — the
        # meta string is the metaLine's flag, not the metaBlock's: no row (the former separate path read the metaLine's and recorded head_1)
        @test isempty(_heads(_run("#~ \"T\"{ hasMetaStr }\nx = 1\n")))
        # THE PROFILE FEED (the creator's decision; the wording his): a heading fed on the userMH surface — the explicit form as the sugar — meets the ONE refusal at the read; no
        # row (before: the explicit form recorded one row against the minted user-context handle, grain 0xe0 — the former separate path's)
        eu0 = try
            GM.goMeta(Vector{UInt8}(codeunits("x = 1\n")); config = GM.GoMetaConfig(user_mh_profile = "head(\"U\", 3)"))
            nothing
        catch er; er end
        @test eu0 isa ErrorException && occursin("in the profile feed has no Component of the file levels to be local to", eu0.msg)
        # THE SLOT (the creator's decision): a heading action takes a place in its slot
        # like every action — a metaLine carrying the capacity-count of OTHER actions PLUS a heading meets the slot refusal (the
        # capacity eight, raised by hand if an example needs it; before: the head never occupied a queue row)
        eq9 = _err("#~ \"H\" hide show discard cell( 1) parent( 2) file( 3) :label1 :label2\nx = 1\n")
        @test eq9 isa ErrorException && occursin("more than 8 actions in one meta-hierarchy slot", eq9.msg)
        # …and, through the delivered rows, a heading-only document mints its head row and nothing else
        # (the queued head applied at the metaBlock, nothing else on the surface)
        rz = _run("#~ \"Only\"\nx = 1\n")
        @test [a for (_, a, _, _) in GM.readAltValuesEvals(rz.altValues_evals)] == [:head_1]
        # (MEASURED) a heading on a metaLine split by a trailing `##` comment records on the metaBlock
        # alone; a heading beside `hide` records ONCE while `hide` governs both Blocks (the two pins below count the rows and their attrs;
        # the Components are the oracle's views — the metaBlock key itself is pinned for a plain metaLine above, `hrow`)
        @test [a for (_, a, _, _) in GM.readAltValuesEvals(_run("#~ \"T\" ## a trailing comment\nx = 1\n").altValues_evals)] == [:head_1]
        r15 = GM.readAltValuesEvals(_run("#~ \"T\" hide\nx = 1\n").altValues_evals)
        @test length(r15) == 3 && count(t -> t[2] === :head_1, r15) == 1 && count(t -> t[2] === :visib && t[3] === :hide, r15) == 2
        # THE DECIDED VOCABULARY BOUNDARIES: `#~0` = the
        # file level records head_0; `#~8` = the deepest depth-digit records head_8
        r0 = _run("#~0 \"Root\"\nx = 1\n")
        @test (:head_0, "Root") in _heads(r0)
        r8 = _run("#~8 \"Deep\"\nx = 1\n")
        @test (:head_8, "Deep") in _heads(r8)
        # THE REGISTRY ROW AS DECIDED, pinned directly (not through the
        # behavioral guards alone) — the 4th plugin IS :heading in :localOnly mode (the set mode's name stays — the creator's decision)
        @test GM.DEFAULT_REGISTRY.plugins[4].altName === :heading
        @test GM.DEFAULT_REGISTRY.plugins[4].setMode === :localOnly
        # a quoted span after ':' is not a label: the grammar's one refusal names the quote (the metaLine parser's
        # one scanner) — the former third quoted-span producer, the quote-blind label route, is gone
        eb3 = _err("#~ :\"a\\b\"\nx = 1\n")
        @test eb3 isa ErrorException && occursin("unexpected character '\"' after ':'", eb3.msg)
    end

    @testset "the further pins — injectivity, the label test in a heading's condition, the fed heading, slot-scoped wall" begin
        # SAME-CELL SAME-LEVEL headings stay DISTINCT rows (a former defect: the
        # (handle, attr) dedup collapsed them later-wins with a bogus collision warning;
        # the attr is injective per (Component, level) — the first keeps head_<level>,
        # repeats gain the source-order ordinal (the Heading store's `entries` keep the applied statements'
        # source order — the `:per_entry` arm's attr-fold, annotations.jl)):
        rp = _run("#~ head(\"A\", 2) head(\"B\", 2)\nx = 1\n")
        @test string(rp.status) == "PROCESS_OK"
        hp = _heads(rp)
        @test (:head_2, "A") in hp && (:head_2_2, "B") in hp
        # TWO HEADING metaLines GLUED into one metaBlock at the same level (MEASURED
        # before and after the change): one row per heading occurrence (the creator's decision); the former separate path's per-metaLine flush kept
        # only the later
        @test _heads(_run("#~ \"A\"\n#~ \"B\"\nx = 1\n")) == [(:head_1, "A"), (:head_1_2, "B")]
        # THE LABEL TEST IN A HEADING'S OWN CONDITION — LEGAL since 0.4.0 (the creator's decision:
        # the refusal lifts with the move; the loop's order his meaning); the former wall "alterant-state query in a
        # heading condition" is gone. The loop's order: the labels of the levels ABOVE and those stated BEFORE the heading on
        # its metaLine are seen, those stated AFTER it are not (as for `hide`) — with or without a fed profile since 0.4.1 (the
        # creator's decisions of 2026-10-18 and 2026-10-19: the metaBlock's own written order holds under a feed too — pinned below;
        # before it a fed profile made the user level the loop's first slot); the quoted-first sugar is always first on its
        # line, so on a metaBlock's first metaLine its condition sees the levels above only (on a metaLine glued to an earlier one it
        # also sees the labels stated on the metaBlock's earlier metaLines). MEASURED after the move.
        rl1 = _run("#~ head(\"T\", 2){ :label2 }\nx = 1\n")             # no label2 anywhere: the condition false — no row, no refusal
        @test string(rl1.status) == "PROCESS_OK" && isempty(_heads(rl1))
        rl2 = _run("#~ :label1\nx = 1\n#~ \"T\"{ :label1 }\ny = 2\n")   # a SIBLING region's label is not in the lineage: no row
        @test string(rl2.status) == "PROCESS_OK" && isempty(_heads(rl2))
        rl3 = _run("#~ :label1\nx = 1\n#~2 \"T\"{ :label1 }\ny = 2\n")   # the level ABOVE: seen — the heading records (MEASURED: a `#~2` metaLine GLUED to a
        @test (:head_2, "T") in _heads(rl3)                                      #   `#~` metaLine forms ONE metaBlock with it and its heading takes the region's level, head_1 —
                                                                                  #   the shape with a Code Line between is the depth-2 region)
        @test _heads(_run("#~ :label1\n#~2 \"T\"{ :label1 }\ny = 2\n")) == [(:head_1, "T")]    # GLUED: ONE metaBlock, its level
        @test _heads(_run("#~ :label1\n\n#~2 \"T\"{ :label1 }\ny = 2\n")) == [(:head_2, "T")]  # a BLANK Line between: the depth-2 region
        rl4 = _run("#~2 :label2 head(\"T\"){ :label2 }\nx = 1\n")         # stated BEFORE the heading on its metaLine: seen
        @test (:head_2, "T") in _heads(rl4)
        rl5 = _run("#~2 head(\"T\"){ :label2 } :label2\nx = 1\n")         # stated AFTER it: not seen — no row
        @test string(rl5.status) == "PROCESS_OK" && isempty(_heads(rl5))
        rl6 = _run("#~ \"T\"{ :label9 }\nx = 1\n")                        # a label unknown to the vocabulary answers false (the creator's decision): no row
        @test string(rl6.status) == "PROCESS_OK" && isempty(_heads(rl6))
        # WITH a fed profile the metaBlock's own WRITTEN order holds as without one (0.4.1 — the creator's decision of
        # 2026-10-18 and 2026-10-19, superseding the placement of 2026-10-16, under which
        # the user level was the loop's first slot and the own labels were collected before the heading and the `hide` were decided): a
        # label stated AFTER the heading or the `hide` is not seen — the fed `:label3` adds its label row and leaves the heading and the Visib rows as in
        # the no-feed run (MEASURED after the cure — no head row, no Visib row, each 4 rows where its
        # no-feed twin has 2; the Labels rows' `decided_by` begin with the user context and their answer source reads `:user` where the no-feed twins read
        # `own` / `indirect`)
        _fed(s, p) = GM.goMeta(Vector{UInt8}(codeunits(s)); config = GM.GoMetaConfig(user_mh_profile = p))
        _vis(r) = [v for (_, a, v, _) in GM.readAltValuesEvals(r.altValues_evals) if a === :visib]
        @test isempty(_heads(_fed("#~2 head(\"T\"){ :label2 } :label2\nx = 1\n", ":label3")))
        @test isempty(_vis(_fed("#~ hide{ :label1 } :label1\nx = 1\n", ":label3"))) &&
              isempty(_vis(_run("#~ hide{ :label1 } :label1\nx = 1\n")))
        # THE CONDITION'S SUBJECT (the creator's decision): a trailing heading's condition reads the LINE's facts
        # (before: the carrier metaSegment's) — `{ isCode }` on a Code Line is now TRUE, `{ isMeta }` there FALSE
        @test (:head_10, "T") in _heads(_run("z = 3 #~ \"T\"{ isCode }\n"))
        @test isempty(_heads(_run("z = 3 #~ \"T\"{ isMeta }\n")))
        # THE FED HEADING, explicit and conditioned alike — the ONE refusal (the former "a conditioned heading in a profile
        # feed" wall was removed with the separate path — the creator's decision)
        for prof in ("head(\"U\", 3)", "head(\"U\", 2){ isCode }")
            ef = try
                GM.goMeta(Vector{UInt8}(codeunits("x = 1\n")); config = GM.GoMetaConfig(user_mh_profile = prof))
                nothing
            catch e; e end
            @test ef isa ErrorException && occursin("in the profile feed has no Component of the file levels to be local to", ef.msg)
        end
        # the SLOT-SCOPED wall (the setter's untyped level slot would have
        # parsed a QUOTED level — the setId-class hazard): a String outside head's TEXT
        # slot refuses; the empty-heading validation never fires on a non-String slot
        eq = _err("#~ head(\"T\", \"2\")\nx = 1\n")
        @test eq isa ErrorException && occursin("string argument not accepted", eq.msg)
        em = _err("#~ head(, \"T\")\nx = 1\n")
        @test em isa ErrorException && !occursin("empty heading text", em.msg)
        # the empty-"" refusal (standing) is CONDITION-INDEPENDENT (the declared validation runs at the READ —
        # the enqueue seam, for every action with a String slot — before any condition is evaluated at the apply)
        ec = _err("#~ \"\"{ isCode }\nx = 1\n")
        @test ec isa ErrorException && occursin("empty heading text", ec.msg)
    end

    # (The interim duplicate-action assert testset was CONSCIOUSLY RETIRED
    # at the registration build with its subject; its successor, the clash law, was removed —
    # a duplicate action name resolves first-wins in `_derive_tables`, witnessed in
    # tests/unit/registration_tests.jl.)
end
