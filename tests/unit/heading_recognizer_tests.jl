# heading_recognizer_tests.jl — v0.2 CH-3: the heading lane's unit guards (APPEND-ONLY).
#
# IS:   step 8 (the STRING-LANE WIDENING — this file's first population) and, at step 9, the
#       quoted-first recognizer + level law + Heading registration rows the testplan assigns
#       here. At step 8 ONLY the lane mechanics land: quote-aware parseArgs, the widened
#       Symbol|String args wall (AlterantArgT), the kind-preserving coercion, and the quote
#       NEGATIVE rows — while NO metaLine grammar accepts a string argument (the step-8 gate:
#       suite byte-identical before any grammar accepts strings). The law is held by a
#       TRANSITIONAL guarded refusal at absorbMeta's ENQUEUE seam — dispatch CANNOT hold it,
#       because the built-in toy setters keep an UNTYPED value slot (`setId` parses
#       `string(idValue)`, so `cell("7")` would silently ACCEPT through dispatch;
#       byte-probed — an earlier revision of this header claimed the dispatch seam held
#       the law, the exact opposite of the delivered design; three review seats caught it).
# DOES: [SL] String-lane mechanism rows (testplan names: test_quoted_arg_single_token ·
#       test_comma_inert_inside_quotes · test_kind_preserving_coercion ·
#       test_args_wall_widened) · [SLN] the quote negative rows (unterminated · escaped ·
#       malformed/glued, on the parseArgs route; the former quote-blind one-word-label route is gone since stage 5's s5c29 —
#       a '"' after ':' meets the grammar's one refusal, the rows below) ·
#       [SLE] end-to-end: a quoted argument at the metaLine surface meets the TRANSITIONAL
#       guarded refusal at the enqueue seam (nothing accepted strings at step 8; step 9 carved
#       the head text slot out — the step-9 sections below own that surface), and the
#       pre-widening quote-free envelope is untouched (numeric args stay Symbol-kind — the integer
#       space is RESERVED out of the literal floor, hd-5).
# PURPOSE: the widened lane is proven present AND provably not yet accepting — the step-8 law.

using Test
import GoMeta as GM

@testset "heading lane — step 8: the String-lane widening (mechanism only)" begin

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
        # (hd-5): the coercion NEVER mints an Int, so numeric args keep their byte-exact
        # pre-widening fates at the setter (cell(7) accepted; cell(99999) is `parse`'s own OverflowError
        # since stage 5's E6 of the v0.4 build — census row 14; the working form pinned in arg_guard_tests.jl)
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
        @test GM.AlterantArgT == Union{Symbol,String}             # the floor, EXACTLY (hd-5)
    end

    @testset "[SLN] quote negative rows — loud refusals, never a silent mangle" begin
        # unterminated quoted argument
        e1 = try _pa("(\"abc)"); nothing catch e; e end
        @test e1 isa ErrorException && occursin("unterminated '\"'", e1.msg)
        # backslash — the WHOLE backslash character is RESERVED inside quoted spans at
        # v0.2 (owner-broadened from the former `\"`-only reservation)
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

    @testset "[SLE] no grammar accepts strings at step 8 — the transitional wall + untouched pre-widening envelope" begin
        # a quoted argument at the metaLine surface flows the lane as a String KIND and
        # meets the TRANSITIONAL guarded refusal at absorbMeta's enqueue seam. The wall must
        # sit THERE, not at dispatch: the built-in toy setters keep an UNTYPED value slot, so
        # `cell("7")` would otherwise silently ACCEPT (parse(Int16, string("7")) succeeds)
        # — the byte-probed reason this row exists. `cell("7")` is therefore the SHARPEST
        # witness of the step-8 law: text that WOULD be accepted through dispatch refuses.
        for s in ["#~ cell(\"7\")\n# c\n", "#~ hide(\"x\")\n# c\n"]
            err = _err(s)
            @test err isa ErrorException
            @test occursin("string argument not accepted", err.msg)
            @test occursin("GoMeta absorb:", err.msg)
        end
        # the unterminated-quote refusal reaches the surface as an absorb refusal naming the INNERMOST opener left open — the quote,
        # before the enclosing '(' (the one scanner of the metaLine parser effort, stage 5's s5c29; the E seat's R2 as he approved it)
        eu = _err("#~ cell(\"x\n# c\n")
        @test eu isa ErrorException && occursin("unterminated '\"'", eu.msg)
        # THE LABEL ROUTE since the metaLine parser effort (stage 5's s5c29; his §362): the six structural characters end a name or a
        # label, so a '"' after ':' or inside a label meets the grammar's one refusal naming the character — the quote lane's former
        # coercion-side validation of a quote-blind label token is gone with the quote-blind route
        el1 = _err("#~ :\"x\"\n# c\n")
        @test el1 isa ErrorException && occursin("unexpected character '\"' after ':'", el1.msg)
        el2 = _err("#~ :\"ab\n# c\n")
        @test el2 isa ErrorException && occursin("unexpected character '\"' after ':'", el2.msg)
        el3 = _err("#~ :\"\n# c\n")
        @test el3 isa ErrorException && occursin("unexpected character '\"' after ':'", el3.msg)
        # … and a label token merely CONTAINING a quote ends at it (the quote is structural, §362): the refusal names the quote
        ed = _err("#~ :a\"b\n# c\n")
        @test ed isa ErrorException && occursin("unexpected character '\"' after the metaStatement \":a\"", ed.msg)
        # QUOTE × INVALID UTF-8 (the module's own doctrine class): a quoted span carrying
        # an invalid byte sequence stays a LOUD guarded refusal, never a raw decode crash —
        # and the CLASS is pinned (delta-review: the span is well-formed, its content the
        # invalid byte, so the fate is the transitional wall, not some accidental refusal)
        ei = _err("#~ cell(\"\xff\")\n# c\n")
        @test ei isa ErrorException && occursin("string argument not accepted", ei.msg)
        # the quote-free pre-widening envelope is byte-untouched: the working numeric form still
        # works (its full fate battery lives in arg_guard_tests.jl — this row is the
        # step-8 sentinel that the widening changed nothing for it)
        r = _run("#~ cell(7)\n# c\n")
        @test string(r.status) == "PROCESS_OK"
    end
end

@testset "heading lane: recognizer + level law + registration (owner-ratified names)" begin

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
        # LEVEL VOCABULARY (the ratified unification decision): the derived
        # recording is the AUTHOR's own `#~`-digit vocabulary (ladder−1, normalized
        # at the enqueue seam) — plain `#~` ⇒ head_1; it COINCIDES with the explicit
        # sibling's as-given vocabulary (`#~2 "T"` ≡ `head("T", 2)` ⇒ head_2).
        r = _run("#~ \"Title\"\nx = 1\n")
        @test string(r.status) == "PROCESS_OK"
        @test (:head_1, "Title") in _heads(r)
        # sugar composes with a following label and with a GLUED condition block (the
        # existing envelope's condition-attachment law — spaced '{' refuses today for
        # every action; the sugar changes nothing there). The settribute condition
        # evaluates ONCE at the HEADING's own line: a metaLine is not code, so
        # { isCode } is FALSE there — zero rows, no refusal (the ratified verdict flip
        # from the queued era's per-cell evaluation, pinned here — panel-found gap)
        @test string(_run("#~ \"T\" :label1\nx = 1\n").status) == "PROCESS_OK"
        ric = _run("#~ \"T\"{ isCode }\nx = 1\n")
        @test string(ric.status) == "PROCESS_OK"
        @test isempty(_heads(ric))
        # the recognizer sets the token inds: a bare quoted heading parses with no BoundsError
        # (the no-token guard this comment once named left at stage 5's E7 — census row 41)
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
        # non-head attrs) — no fabricated rows (hd-4)
        rh = _run("#~ \"Title\"\nx = 1\n")
        rn = _run("# plain\nx = 1\n")
        nonhead(r) = sort([String(a) for (_, a, _, _) in GM.readAltValuesEvals(r.altValues_evals) if !startswith(String(a), "head")])
        @test nonhead(rh) == nonhead(rn) == String[]
        @test !isempty(_heads(rh))
    end

    @testset "test_non_first_quote_refusal — the hd-3 reservation stands: the grammar's one refusal names the quote, with his U8 :1306 hint (the metaLine parser effort, stage 5's s5c29)" begin
        e = _err("#~ hide \"T\"\nx = 1\n")
        @test e isa ErrorException && occursin("unexpected character '\"' at the start of a metaStatement", e.msg)
        @test occursin("heading sugar at the region's first metaStatement only", e.msg)
    end

    @testset "test_empty_quote_lowers — BOTH halves: enters the recognizer, then the ratified refusal" begin
        # (conscious pin flip: the refusal was TRANSITIONAL until the heading-design
        # owner ratified it as the standing v0.2 semantic; the message says so)
        e = _err("#~ \"\"\nx = 1\n")
        @test e isa ErrorException
        @test !occursin("unexpected punctuation", e.msg)          # half 1: NOT the old wall (the wall itself left at stage 5's E7 — census row 41)
        @test occursin("empty heading text", e.msg)               # half 2: Heading validation
        @test occursin("ratified standing decision", e.msg)       # ratified, not transitional
    end

    @testset "heading-lane quote refusals (siblings of the argument-lane classes)" begin
        eu = _err("#~ \"abc\nx = 1\n")
        @test eu isa ErrorException && occursin("unterminated '\"'", eu.msg)
        # THE BACKSLASH RESERVATION (owner-broadened): ANY `\`
        # inside the span refuses — not merely `\"`. The pre-cure grammar accepted `"a\b"`
        # while refusing `"a\\"` (the trailing backslash read as `\"`) — that ragged
        # acceptance is exactly what the ruling closed; all four shapes now meet ONE
        # guarded refusal, and the future escape grammar mints on a clean slate.
        ee = _err("#~ \"a\\\"b\"\nx = 1\n")
        @test ee isa ErrorException && occursin("backslash in a quoted span", ee.msg)
        el = _err("#~ \"a\\b\"\nx = 1\n")                          # lone mid-span backslash
        @test el isa ErrorException && occursin("backslash in a quoted span", el.msg)
        et = _err("#~ \"a\\\\\"\nx = 1\n")                         # trailing double backslash
        @test et isa ErrorException && occursin("backslash in a quoted span", et.msg)
        # the ARGUMENT-lane twin holds the same law (sugar ≡ canonical): a backslash
        # inside a quoted canonical-call argument refuses in the one scanner _span (stage 5's s5c29)
        ea = _err("#~ head(\"a\\b\")\nx = 1\n")
        @test ea isa ErrorException && occursin("backslash in a quoted span", ea.msg)
    end

    @testset "test_usermh_contextless_refusal — derived context absent ⇒ guarded applicability refusal" begin
        e = try
            GM.goMeta(Vector{UInt8}(codeunits("x = 1\n"));
                config = GM.GoMetaConfig(user_mh_profile = "\"T\""))
            nothing
        catch er
            er
        end
        @test e isa ErrorException && occursin("heading without a document context", e.msg)
    end

    @testset "canonical calls — position-free deriving + the explicit sibling (N6 pair)" begin
        # deriving canonical, first AND non-first position (canonical calls are
        # position-free within applicability; only the SUGAR is first-position)
        @test (:head_1, "T") in _heads(_run("#~ head(\"T\")\nx = 1\n"))
        @test (:head_1, "T") in _heads(_run("#~ :label1 head(\"T\")\nx = 1\n"))
        # the explicit sibling stores its level AS GIVEN (user vocabulary; Symbol text
        # through the hd-5 floor, parsed setId-style at the store)
        @test (:head_2, "T") in _heads(_run("#~ head(\"T\", 2)\nx = 1\n"))
        @test (:head_7, "T") in _heads(_run("#~ head(\"T\", 7)\nx = 1\n"))
        # (the three refusals at the former set-invocation seam left at stage 5's E6 of the v0.4 build — a non-parseable
        # level, the text missing, a bare-word text — census row 14: Julia's own errors now, measured on both trees by
        # the build's probe)
    end

    @testset "localOnly delivery — the ratified `:localOnly` set mode (witnesses)" begin
        # LOCALITY: one heading governing several components mints EXACTLY ONE row,
        # keyed to the occurrence handle of the metaBLOCK the metaLine forms (R-V04B-50,
        # stage 2's commit 1 — before it, the metaLine's own Line; the outline model). The
        # per-component inheritance repetition of the first build is GONE — flipped
        # consciously at the ratified delivery decision.
        rl = _run("#~ \"Title\"\nx = 1\ny = 2\nz = 3\n")
        @test string(rl.status) == "PROCESS_OK"
        @test length(_heads(rl)) == 1 && (:head_1, "Title") in _heads(rl)
        # the row's handle is the occurrence handle of the metaBLOCK the metaLine forms (R-V04B-50), computed
        # from the delivered tree (`blsComponentTree`; the Engine's `occurrence_key` + `key_bytes`, the default namespace)
        hrow = only([h for (h, a, _, _) in GM.readAltValuesEvals(rl.altValues_evals) if startswith(String(a), "head")])
        ml = only(l for b in GM.BLS.children(rl.blsComponentTree) for l in GM.BLS.children(rl.blsComponentTree, b)
                    if GM.BLS.getElement(l, :inputLineNum) == 1)   # the metaLine at input line 1, through the door
        mb = GM.BLS.parent(rl.blsComponentTree, ml)                   # the metaBlock it forms — the row's Component
        @test hrow == GM.key_bytes(GM.occurrence_key(rl.blsComponentTree, mb; namespace = :default))
        @test hrow != GM.key_bytes(GM.occurrence_key(rl.blsComponentTree, ml; namespace = :default))   # no longer the Line's
        # SLOT-WIPE INDEPENDENCE: delivery happens at absorb, so a LATER same-depth
        # metaLine (which reuses/wipes the slot) cannot disturb an earlier heading's row
        rw = _run("#~ \"A\"\nx = 1\n#~ :label1\ny = 2\n")
        @test (:head_1, "A") in _heads(rw)
        # CONDITION-ONCE, true arm: the condition gates the HEADING at its own context
        # (evaluated exactly once, at absorb) — a true condition mints ONE row, never
        # one per governed cell (the false arm is pinned in the delta-round set below)
        rc1 = _run("#~ \"T\"{ isMeta }\nx = 1\ny = 2\n")
        @test string(rc1.status) == "PROCESS_OK"
        @test length(_heads(rc1)) == 1
        # userMH RECORDS (the user-context build — this pin FLIPPED consciously WITH
        # the public-doc statement in the same commit, superseding the former
        # zero-rows fate): the EXPLICIT head fed on the userMH surface mints exactly
        # ONE row keyed by the minted USER-CONTEXT handle (grain 0xe0 at the fixed
        # class offset) — no copy of the profile's bytes on the row since commit 9b (R-V04B-43 (1));
        # the deriving form still meets the applicability refusal there
        ru0 = GM.goMeta(Vector{UInt8}(codeunits("x = 1\n"));
            config = GM.GoMetaConfig(user_mh_profile = "head(\"U\", 3)"))
        u_rows = [(h, a, v) for (h, a, v, _) in GM.readAltValuesEvals(ru0.altValues_evals)
                  if startswith(String(a), "head")]
        @test length(u_rows) == 1
        let (h, a, v) = u_rows[1]
            @test a === :head_3 && v == "U"
            nslen = (UInt16(h[2]) << 8) | h[3]
            @test h[3 + Int(nslen) + 1] == 0xe0          # the class grain, fixed offset
            @test h == GM.key_bytes(GM.user_context_key(:default, 1))
        end
        # …and the fed row's FIFTH COLUMN in the test layer's derived five-column form is EMPTY: no Component of the
        # tree carries the user-context handle — the profile's bytes live in the configuration, which the delivery does
        # not carry (R-V04B-43 (4); his word OWNER-WORDS §277, R-V04B-90, on the row shown to him; the Engine stores no copy since
        # commit 9b, R-V04B-43 (1); the former witness pinned the configuration's bytes in the Engine's five-column form)
        fed = only(l for l in split(String(TestSupport.derive_annotations_golden(ru0)), '\n'; keepempty = false) if startswith(l, "head_3\t"))
        @test endswith(fed, string('\t', bytes2hex(u_rows[1][1]), '\t'))   # the four columns, then the empty fifth
        # NEVER-QUEUED: a heading action consumes NO slot capacity — a metaLine
        # carrying the capacity-count of OTHER enqueued actions PLUS a heading still
        # absorbs (the head never occupies a queue row)
        rq = _run("#~ \"H\" hide show discard cell( 1) parent( 2) file( 3) :label1 :label2\nx = 1\n")
        @test string(rq.status) == "PROCESS_OK" && (:head_1, "H") in _heads(rq)
        # …and, through the delivered rows, a heading-only document mints its head row and nothing else
        # — the observable face of "the slot tensors untouched"; the tensors themselves are the working
        # state's and are not delivered (the direct pin is lost — the record names it)
        rz = _run("#~ \"Only\"\nx = 1\n")
        @test [a for (_, a, _, _) in GM.readAltValuesEvals(rz.altValues_evals)] == [:head_1]
        # THE RATIFIED VOCABULARY BOUNDARIES (panel-found coverage gap): `#~0` = the
        # file level records head_0; `#~8` = the deepest depth-digit records head_8
        r0 = _run("#~0 \"Root\"\nx = 1\n")
        @test (:head_0, "Root") in _heads(r0)
        r8 = _run("#~8 \"Deep\"\nx = 1\n")
        @test (:head_8, "Deep") in _heads(r8)
        # THE RATIFIED REGISTRY ROW, pinned directly (panel-found gap: behavioral
        # guards only) — the 4th plugin IS :heading in :localOnly mode
        @test GM.DEFAULT_REGISTRY.plugins[4].altName === :heading
        @test GM.DEFAULT_REGISTRY.plugins[4].setMode === :localOnly
        # a quoted span after ':' is not a label: the grammar's one refusal names the quote (the metaLine parser effort, stage 5's
        # s5c29; his §362) — the former third quoted-span producer, the quote-blind label route, is gone
        eb3 = _err("#~ :\"a\\b\"\nx = 1\n")
        @test eb3 isa ErrorException && occursin("unexpected character '\"' after ':'", eb3.msg)
    end

    @testset "delta-round pins — injectivity, condition fates, userMH explicit, slot-scoped wall" begin
        # SAME-CELL SAME-LEVEL headings stay DISTINCT rows (review-found MAJOR: the
        # (handle, attr) dedup collapsed them later-wins with a bogus collision warning;
        # the attr is injective per (metaLine, level) — the first keeps head_<level>,
        # repeats gain the source-order ordinal (delivery-era wording: the pending
        # store preserves the meta region's source order)):
        rp = _run("#~ head(\"A\", 2) head(\"B\", 2)\nx = 1\n")
        @test string(rp.status) == "PROCESS_OK"
        hp = _heads(rp)
        @test (:head_2, "A") in hp && (:head_2_2, "B") in hp
        # CONSCIOUS PIN FLIP (the query-atom wall — panel-found MAJOR, probe-verified):
        # a label QUERY in a heading condition formerly evaluated against the stale
        # apply residue (order-dependent wrong verdicts: the identical condition
        # minted or dropped the row depending on unrelated preceding content). It now
        # meets the guarded reservation refusal — settribute predicates remain the
        # heading condition's legal vocabulary (the false-arm settribute pin lives in
        # test_quoted_first_lowering).
        ec1 = _err("#~ head(\"T\", 2){ :label2 }\nx = 1\n")
        @test ec1 isa ErrorException && occursin("alterant-state query in a heading condition", ec1.msg)
        # the residue-leak shape itself (the probe's smoking gun) must refuse too —
        # never again gate on a preceding block's labels:
        ec2 = _err("#~ :label1\nx = 1\n#~ \"T\"{ :label1 }\ny = 2\n")
        @test ec2 isa ErrorException && occursin("alterant-state query in a heading condition", ec2.msg)
        # the EXPLICIT sibling through the context-less userMH surface ACCEPTS (it
        # derives nothing — the applicability law binds the deriving form only; pinned
        # as the boundary's conscious other half)
        ru = GM.goMeta(Vector{UInt8}(codeunits("x = 1\n"));
            config = GM.GoMetaConfig(user_mh_profile = "head(\"U\", 3)"))
        @test string(ru.status) == "PROCESS_OK"
        # …EXTENDED at the user-context build: the PROCESS_OK half now records too —
        # the fed head's row is PRESENT (the row-shape pins live in the flipped
        # witness above; this asserts presence on this route's own run)
        @test any(a === :head_3 && v == "U"
                  for (_, a, v, _) in GM.readAltValuesEvals(ru.altValues_evals))
        # NEW at the user-context build (the reserved wall): a CONDITIONED head in
        # a fed profile meets its guarded refusal — the feed carries no evaluable
        # settribute state (unconditioned heads record; the lifting condition is
        # recorded at the wall)
        ecf = try
            GM.goMeta(Vector{UInt8}(codeunits("x = 1\n"));
                config = GM.GoMetaConfig(user_mh_profile = "head(\"U\", 2){ isCode }"))
            nothing
        catch e; e end
        @test ecf isa ErrorException &&
              occursin("conditioned heading in a profile feed", ecf.msg)
        # the SLOT-SCOPED wall (review-found: the setter's untyped level slot would have
        # parsed a QUOTED level — the setId-class hazard): a String outside head's TEXT
        # slot refuses; the empty-heading validation never fires on a non-String slot
        eq = _err("#~ head(\"T\", \"2\")\nx = 1\n")
        @test eq isa ErrorException && occursin("string argument not accepted", eq.msg)
        em = _err("#~ head(, \"T\")\nx = 1\n")
        @test em isa ErrorException && !occursin("empty heading text", em.msg)
        # the empty-"" refusal (ratified standing) is CONDITION-INDEPENDENT (it fires in
        # the localOnly delivery seam BEFORE the condition evaluation — witnessed with
        # one attached; delivery-era wording, formerly "the enqueue seam")
        ec = _err("#~ \"\"{ isCode }\nx = 1\n")
        @test ec isa ErrorException && occursin("empty heading text", ec.msg)
    end

    # (The step-9 interim duplicate-action assert testset was CONSCIOUSLY RETIRED
    # at the registration build with its subject; its successor, the clash law, left at stage 5's E4 —
    # a duplicate action name resolves first-wins in `_derive_tables`, witnessed in
    # tests/unit/registration_tests.jl.)
end
