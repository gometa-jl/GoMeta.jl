# probe_devtools.jl — the devtools.jl assertion battery (canon R3: probes over claims).
#   (2026-09-12, owner ruling — the v0.4 build record's OWNER-WORDS §26) The battery lives HERE,
#   beside the tools it tests (devtools/probes/), since the play became a self-contained fork;
#   the play keeps its own frozen copy of it. Its two fixture inputs: fixtures/ (the mini
#   Documenter source, copied from the play) and examples/InFileFolder/file_for_Example_Extended.jl.
#
# IS:   the empirical check of every devtools surface the byte-parity sweep cannot
#       cover — filters, checked fetch, dispatch validation, format inference, the
#       drift alarm, and (§16) the slide option's sharp edges: the classifier/aligner
#       grammar + attack-class pins, tier degradations (T0→T1→R2), the slide error
#       contract of all seven slide-bearing tools, and capture totality. (Byte parity
#       vs the owner-approved mockups is the OTHER half of verification:
#       plan/2026-08-19-gometa-dev-print-tools/, 34/34 at build; the slide corpus
#       sweep + python validator are the third: probes/slide_sweep.jl +
#       plan/2026-08-20-devtools-slide-output/validate_sidecars.py.)
# DOES: runs goMeta on the two standing fixture inputs (+ §16's inline slide fixtures),
#       drives both printers and all slide paths through the filter/error tiers into
#       IOBuffers/tempfiles, and counts failed checks.
# PURPOSE: re-runnable ANY session (esp. after a change under src/ or devtools/, together
#       with devtools_selfcheck()); exit code 0 = all green.
#
#   GM=/home/fido/Dropbox/_01_Crypto_Dropbox/07_Claude/GoMetaEcosystem/GoMeta
#   julia --startup-file=no --project=$GM/tests $GM/devtools/probes/probe_devtools.jl

const _PB_HOME = normpath(joinpath(@__DIR__, "..", ".."))   # the code home (the repository root)
const _PB_FIX  = joinpath(@__DIR__, "fixtures")             # the battery's own fixture inputs
import GoMeta
include(joinpath(@__DIR__, "..", "load_basic_renderer.jl"))   # the ONE path to the basic renderer (R-V04B-24 obligation 7)
include(joinpath(@__DIR__, "..", "devtools.jl"))   # the tools, one level up

fails = 0
check(cond, msg) = (cond ? nothing : (global fails += 1; println("FAIL  ", msg)); nothing)
plain(f) = (b = IOBuffer(); f(b); String(take!(b)))

mini = GoMeta.goMeta(read(joinpath(_PB_FIX, "mini-Documenter-Source-File.jl")))
ext  = GoMeta.goMeta(read(joinpath(_PB_HOME, "examples", "InFileFolder", "file_for_Example_Extended.jl")))

## 1 — the drift alarm itself
check(devtools_selfcheck() === true, "devtools_selfcheck() did not return true")

## 2 — attrs filter: count agreement with the raw surface + explicit never-minted state
raw_visib = count(r -> r[2] === :visib, GoMeta.readAltValuesEvals(ext.altValues_evals))
out = plain(io -> print_altValues_evals(io, ext; layout = :rows, attrs = :visib))
nrows = count(l -> occursin("visib", l) && occursin("=>", l), split(out, '\n'))
check(nrows == raw_visib, "attrs=:visib rendered $nrows rows, expected $raw_visib")
check(occursin(":visib: $raw_visib match", out), "attrs echo count ≠ raw altValues_evals count ($raw_visib)")
check(!occursin("label_", out), "attrs=:visib leaked label rows")
out = plain(io -> print_altValues_evals(io, ext; layout = :rows, attrs = [:label_nope]))
check(occursin("0 matches — :label_nope never minted", out), "never-minted state not explicit")

## 3 — lines filter keeps unanchored rows + restricts anchored ones
uctx = GoMeta.goMeta(read(joinpath(_PB_FIX, "mini-Documenter-Source-File.jl"));
                     config = GoMeta.GoMetaConfig(user_mh_profile = "head(\"Fed head\", 1)"))
out = plain(io -> print_altValues_evals(io, uctx; layout = :rows, lines = 1:1))
check(occursin("USER_CONTEXT", out), "lines= hid an unanchored row (must never)")
check(!occursin("label_🍻", out), "lines=1:1 leaked a row outside the range")

## 4 — tool-1 checked blocks= fetch: invalid ids reported, valid ones render
out = plain(io -> print_BLS_Component_Tree(io, mini; blocks = [999, 2]))
check(occursin("requested Block id 999 is not a valid File-census Block", out), "invalid blocks= id not reported")
check(occursin("Block #2", out), "valid blocks= id did not render")

## 5 — dispatch validation: conflicting kwargs ERROR, never silently no-op
expect_throw(f, msg) = (try f(); global fails += 1; println("FAIL  no-throw: ", msg)
                        catch e e isa ErrorException || rethrow() end; nothing)
expect_throw(() -> plain(io -> print_BLS_Component_Tree(io, mini; style = :mix, detail = :full)),
             "style=:mix + explicit detail must error")
expect_throw(() -> plain(io -> print_BLS_Component_Tree(io, mini; style = :nope)),
             "unknown style must error")
expect_throw(() -> plain(io -> print_altValues_evals(io, mini; layout = :rows, include_empty = true)),
             "include_empty on layout=:rows must error")
expect_throw(() -> plain(io -> print_altValues_evals(io, mini; layout = :nope)),
             "unknown layout must error")

## 6 — :tree detail=:full = the :tree LOOK plus typed dumps (never the :mix look);
##     grain= caps the walk; in :mix, grain=:line moves strings up to the Line
out = plain(io -> print_BLS_Component_Tree(io, mini; style = :tree, detail = :full))
check(occursin("Int64", out) && occursin("idComponent=", out), ":tree detail=:full lacks typed dumps")
check(occursin("{", out), ":tree detail=:full lost the inline flag sets (rendered :mix instead)")
mixout = plain(io -> print_BLS_Component_Tree(io, mini))
check(out != mixout, ":tree detail=:full is byte-identical to :mix — the dead-treeform bug")
out = plain(io -> print_BLS_Component_Tree(io, mini; grain = :block))
check(!occursin("Line #", out), "grain=:block leaked Line rows")
out = plain(io -> print_BLS_Component_Tree(io, mini; grain = :line))
check(occursin("\"# Manual: the area of a circle", out) || occursin("# Manual", out),
      ":mix grain=:line suppressed multi-segment Line strings (print-once at deepest DISPLAYED owner)")

## 6b — Segment-grain rows (inline head) attach to the owning Line in :tree; totality holds
seg = GoMeta.goMeta(Vector{UInt8}(codeunits("x = 1 #~ head(\"Inline head\", 2)\n# a Text line\n")))
out = plain(io -> print_altValues_evals(io, seg; include_empty = true))
check(occursin("[Segment #", out) && occursin("head_2", out),
      "Segment-grain head row not attached with a [Segment #N] tag in :tree")
check(!occursin("unanchored rows", out), "Segment-grain head row fell to the unanchored section")
nbullets = count(l -> occursin("●", l), split(out, '\n'))
nrows = length(GoMeta.readAltValuesEvals(seg.altValues_evals))
check(nbullets == nrows, ":tree rendered $nbullets bullets for $nrows rows — totality broken")
out = plain(io -> print_altValues_evals(io, seg; layout = :cells))
check(occursin("head_2", out), "Segment-grain head row missing from :cells")

## 6c — elision labels stay truthful under filters (never assert engine-level absence)
out = plain(io -> print_altValues_evals(io, ext; lines = 14:14))
check(!occursin("(no evals)", out) || occursin("(no matching evals)", out),
      "filtered collapse asserted '(no evals)' where rows were filtered out")
check(occursin("showing", out), "filtered/total echo line missing")

## 7 — write twins: format inference + ANSI-on-request (tempdir; never into the repository)
tmp = mktempdir()
p = write_BLS_Component_Tree_to_file(joinpath(tmp, "t.html"), mini)
check(startswith(read(p, String), "<!doctype html>"), ".html inference failed")
p = write_altValues_evals_to_file(joinpath(tmp, "t.txt"), mini)
check(!occursin('\e', read(p, String)), ".txt default carried ANSI escapes")
p = write_altValues_evals_to_file(joinpath(tmp, "t2.txt"), mini; color = :always)
check(occursin('\e', read(p, String)), "color=:always wrote no ANSI escapes")

## 7b — R-DEV-9: the flavor triple (256-color) renders in BOTH tools' colored output
ansi(f) = (b = IOBuffer(); f(IOContext(b, :color => true)); String(take!(b)))
out = ansi(io -> print_BLS_Component_Tree(io, ext))
for (code, name) in ((172, "Meta"), (149, "Code"), (134, "Text"))
    check(occursin("38;5;$code", out), "flavor color 38;5;$code ($name) missing from tool-1 output")
end
out = ansi(io -> print_altValues_evals(io, ext; include_empty = true))
check(occursin("38;5;172", out) && occursin("38;5;134", out),
      "flavor triple missing from tool-2 :tree output")
check(occursin("38;5;75m", out), "attr azure (R-DEV-10) missing from tool-2 output")

## 8 — color=:auto passthrough honors a deliberate IOContext(:color=>true)
b = IOBuffer()
print_altValues_evals(IOContext(b, :color => true), mini)
check(occursin('\e', String(take!(b))), ":auto did not pass a :color=>true IOContext through")

## 9 — friendly kwarg validation (typed errors, not raw MethodErrors)
expect_throw(() -> plain(io -> print_altValues_evals(io, mini; attrs = "visib")),
             "attrs=\"visib\" (a String) must raise the typed error")
expect_throw(() -> plain(io -> print_altValues_evals(io, mini; lines = "5:12")),
             "lines=\"5:12\" (a String) must raise the typed error")
expect_throw(() -> plain(io -> print_BLS_Component_Tree(io, mini; blocks = :al)),
             "blocks=:al must raise the typed error")

## 10 — invalid UTF-8 content renders without throwing (byte-faithful engine input)
raw = vcat(Vector{UInt8}(codeunits("# ok line\n# bad ")), [0xff, 0xc3], Vector{UInt8}(codeunits(" tail\n")))
badr = GoMeta.goMeta(raw)
out = plain(io -> print_BLS_Component_Tree(io, badr))
check(!isempty(out), "invalid-UTF-8 input rendered empty")

## 11 — a namespace=:other run's OWN rows anchor (native, not foreign)
nsr = GoMeta.goMeta(read(joinpath(_PB_FIX, "mini-Documenter-Source-File.jl"));
                    config = GoMeta.GoMetaConfig(namespace = :other))
out = plain(io -> print_altValues_evals(io, nsr; layout = :rows))
check(!occursin("unanchored", out) && occursin("label_🍻", out),
      "namespace=:other rows failed to anchor against their own result")

## 12 — USER_CONTEXT totality in ALL THREE layouts + the ordinal tag
uctx2 = GoMeta.goMeta(read(joinpath(_PB_FIX, "mini-Documenter-Source-File.jl"));
                      config = GoMeta.GoMetaConfig(user_mh_profile = "head(\"Fed head\", 1)"))
nraw = length(GoMeta.readAltValuesEvals(uctx2.altValues_evals))
out = plain(io -> print_altValues_evals(io, uctx2; layout = :rows))
nrend = count(l -> occursin("=>", l), split(out, '\n'))
check(nrend == nraw, ":rows rendered $nrend rows for $nraw raw rows — totality broken")
for lay in (:rows, :tree, :cells)
    o = plain(io -> print_altValues_evals(io, uctx2; layout = lay,
                                          (lay === :tree ? (include_empty = true,) : ())...))
    check(occursin("USER_CONTEXT", o), "USER_CONTEXT row missing from layout=$lay")
end
out = plain(io -> print_altValues_evals(io, uctx2; layout = :rows))
check(occursin("USER_CONTEXT #1", out), "USER_CONTEXT ordinal tag missing in the unanchored label")
out = plain(io -> print_altValues_evals(io, uctx2; layout = :rows, show_handles = true))
check(occursin("path=[(direct,1)]", out), "show_handles did not print the full decoded path for the unanchored row")

## 13 — PROCESS_ERROR: status precedes everything; empty docs show the File summary in EVERY style
err = GoMeta.goMeta(read(joinpath(_PB_FIX, "mini-Documenter-Source-File.jl"));
                    config = GoMeta.GoMetaConfig(profile = :no_such_profile))
out = plain(io -> print_BLS_Component_Tree(io, err))
check(startswith(out, "status: PROCESS_ERROR"), "status banner is not FIRST on PROCESS_ERROR")
emptyr = GoMeta.goMeta(UInt8[])
for st in (:mix, :tree, :legacy, :banner)
    o = plain(io -> print_BLS_Component_Tree(io, emptyr; style = st))
    check(occursin("(no Blocks", o), "empty document lacks the (no Blocks) marker in style=$st")
    if st === :legacy
        check(occursin("printComponentStates(...)", o), "empty :legacy lost its frozen chrome (D-14)")
    else
        check(occursin("0 Blocks", o), "empty document lacks the File summary in style=$st")
    end
end
out = plain(io -> print_BLS_Component_Tree(io, mini; lines = 9999:9999))
check(occursin("no Blocks matched the lines= range", out), "lines= no-match stayed silent")

## 14 — oversized / bogus blocks= ids are reported, never thrown
out = plain(io -> print_BLS_Component_Tree(io, mini; blocks = [big"99999999999999999999", 2]))
check(occursin("skipped", out) && occursin("Block #2", out),
      "oversized blocks= id not reported-and-skipped")

## 15 — warning visibility (unit-level: the renderers must SHOW the origin's non-verified states; the two fingerprint-state
## probes left with the tools' fingerprint column at stage 2's commit 9b — R-V04B-43 (1): the Engine stores no copy to compare)
mkrow(ost) = DTEvalRow(:visib, :hide, true, nothing, nothing, ost, UInt8[0x01], 0xe0,
                       "default", [(0x01, UInt32(1))], Tuple{UInt8,UInt32}[], :non_document_grain)
docstub = _dt_doc(mini)
b = IOBuffer(); _dt_print_unanchored(b, docstub, [mkrow(:failed)]); ub = String(take!(b))
check(occursin("⚠ origin unverified", ub), "unanchored section hides origin_status=:failed")
b = IOBuffer(); _dt_print_unanchored(b, docstub, [mkrow(:unverifiable)]); ub = String(take!(b))
check(occursin("origin unverifiable", ub), "unanchored section hides origin_status=:unverifiable")

## 16 — §H slide option: the seat-D1 grammar + aligner edge pins (each row kills one
## attack class from the design record; the corpus sweep proper lives in
## slide_sweep.jl + validate_sidecars.py — these are the sharp cases the corpus lacks)
slsrc(s) = _dt_sl_source_lines(GoMeta.goMeta(Vector{UInt8}(codeunits(s))), length(_dt_sl_splitlines(Vector{UInt8}(codeunits(s)))[1]))   # the count from the probe's own bytes (R-V04B-85 (D))
slren(s) = (r = GoMeta.goMeta(Vector{UInt8}(codeunits(s)));
            _dt_sl_render_lines(r, copy(Main.BasicRenderer.outputs(r).render_bytes)))

## grammar rows (D1 §e.3-5): modifier forms, non-tokens, close-marker, strictness
check(slsrc("#~0! x\n")[1] == [("#~0!", "marker"), (" x", "payload")], "slide: #~0! token")
check((try GoMeta.goMeta(Vector{UInt8}(codeunits("#~!0 x\n# t\n"))); false
       catch e; occursin("bang-first meta marker", sprint(showerror, e)) end),
      "slide: #~!0 REFUSES at the engine (v0.3.1 bang-first law) — the classifier can never see it")
check(slsrc("#~~3 :label1\n")[1][1] == ("#~~3", "marker"), "slide: tilde-run modifier token")
check(slsrc("#] x\n")[1] == [("#]", "marker"), (" x", "payload")], "slide: close-marker #]")
check(slsrc("#~2\n")[1] == [("#~2", "marker")], "slide: bare #~2 = single marker run, no empty payload")
check(slsrc("### banner\n")[1] == [("### banner", "text")], "slide: julia ### is content (strict)")
check(slsrc("## c\n")[1] == [("## c", "comment")], "slide: julia ## c is comment")

## aligner rows (D1 §e.7-15): each is a killed attack class
lr, _, tier = slren("x = 1 ## #~ hide\n")   # B-1 double-mark
check(tier === :component &&
      lr[1] == [("## ", "hideprefix"), ("x = 1 ", "code"), ("## ", "comment"),
                ("## ", "comment"), ("#~", "marker"), (" hide", "payload")],
      "slide: double-mark render runs (B-1)")
lr, _, tier = slren("## note #~ hide\n")    # B-3/B-5 comment-hidden IDENT
check(tier === :component && lr[1][1] == ("## note ", "comment") &&
      all(r -> r[2] != "hideprefix", lr[1]), "slide: comment-hidden line renders IDENT, no hp (B-3/B-5)")
lr, _, tier = slren("x = 1 #~ hide ## note\n")   # tail comment AFTER the metaSegment
check(tier === :component &&
      lr[1] == [("## ", "hideprefix"), ("x = 1 ", "code"), ("## ", "comment"),
                ("#~", "marker"), (" hide ", "payload"), ("## note", "comment")],
      "slide: mid-insert before the FIRST Meta segment")
lr, _, tier = slren("    x = 1 #~ hide\n")  # indent: mark at column 0, gap joins code
check(tier === :component && lr[1][1] == ("## ", "hideprefix") &&
      lr[1][2] == ("    x = 1 ", "code"), "slide: indented WHOLEHIDE/TAIL shape")
lr, _, tier = slren("x = 1 #~ hide\ny = 2 #~ hide\n")   # consecutive inline tails
check(tier === :component && length(lr) == 2 &&
      all(l -> l[1] == ("## ", "hideprefix"), lr), "slide: consecutive inline tails")
lr, _, tier = slren("x = 1 #~ discard\nx = 1\n")   # discarded-identical-to-kept
check(tier === :component && length(lr) == 1 && lr[1] == [("x = 1", "code")],
      "slide: discarded line identical to a later kept line")
lr, _, tier = slren("#~ discard{ isCode }\nx = 1 #~ hide\ny = 2\n")   # fate precedence
check(tier === :component && length(lr) == 2 && lr[2][1] == ("## ", "hideprefix"),
      "slide: Line-:hide survives inside a Block-:discard (fate ladder)")
lr, _, tier = slren("#~ hide\n# a\n\n# b\n")   # blank in hidden region stays bare
check(tier === :component && isempty(lr[3]), "slide: blank line in hidden region")
lr, _, tier = slren("x = 1 #~ hide\n")   # NBSP before the inline metaSegment (TAIL)
check(tier === :component && lr[1][1] == ("## ", "hideprefix") &&
      any(r -> r == ("#~", "marker"), lr[1]) &&
      join(first.(lr[1])) == "## x = 1 ## #~ hide",
      "slide: NBSP-delimited inline metaSegment TAIL tiling")
lr, _, tier = slren("x = \"🍒🍒\" #~ hide\n")  # emoji byte offsets
check(tier === :component && join(first.(lr[1])) == "## x = \"🍒🍒\" ## #~ hide",
      "slide: emoji TAIL byte tiling")

## tiers: T1 forced by a byte-perturbed render (no hideprefix, comment default);
## R2 forced by an unparseable perturbed render (all neutral)
rt = GoMeta.goMeta(Vector{UInt8}(codeunits("x = 1 #~ hide\n# t\n")))
pert = replace(String(copy(Main.BasicRenderer.outputs(rt).render_bytes)), "## x" => "##  x")
lr, _, tier = _dt_sl_render_lines(rt, Vector{UInt8}(codeunits(pert)))
check(tier === :reparse, "slide: perturbed render must degrade to T1 (got $tier)")
check(all(r -> r[2] != "hideprefix", Iterators.flatten(lr)), "slide: T1 must never assert hideprefix")
lr, _, tier = _dt_sl_render_lines(rt, Vector{UInt8}(codeunits("#~9 :label1\n")))
check(tier === :neutral && lr[1] == [("#~9 :label1", "neutral")],
      "slide: unparseable perturbed render must fall to R2 all-neutral (got $tier)")

## error contract — TYPE-EXACT (verification order F2: an any-throw accept would
## stay green under a regression from the mandated ArgumentError/TypeError to error())
expect_exact(f, T, msg) = (try f(); global fails += 1; println("FAIL  no-throw: ", msg)
                           catch e
                               e isa InterruptException && rethrow()
                               e isa T || (global fails += 1;
                                           println("FAIL  wrong throw type: ", msg, " (", typeof(e), " not ", T, ")"))
                           end; nothing)
expect_exact(() -> print_altValues_evals(IOBuffer(), mini; slide = "light"), TypeError,
             "slide=\"light\" must TypeError (typed kwarg)")
## unknown-Symbol contract SHARP (P2#8): ArgumentError specifically, message naming
## ALL FOUR supported values — on every slide-bearing function
expect_argerr_naming_all(f, msg) = (try
        f(); global fails += 1; println("FAIL  no-throw: ", msg)
    catch e
        e isa InterruptException && rethrow()
        ok = e isa ArgumentError &&
             all(occursin(s, sprint(showerror, e)) for s in
                 (":gometa_dark", ":cvd_dark", ":light", ":cvd_light", ":projector"))
        ok || (global fails += 1;
               println("FAIL  wrong throw class/message: ", msg, " (", typeof(e), ")"))
    end; nothing)
for thunk in (() -> print_BLS_Component_Tree(IOBuffer(), mini; slide = :bogus),
              () -> print_altValues_evals(IOBuffer(), mini; slide = :bogus),
              () -> write_BLS_Component_Tree_to_file(tempname(), mini; slide = :bogus),
              () -> write_altValues_evals_to_file(tempname(), mini; slide = :bogus),
              () -> writeBlsStructureToFile(tempname(), mini; slide = :bogus),
              () -> writeRenderToFile(tempname(), mini; slide = :bogus),
              () -> writeMarkedSourceToFile(tempname(), UInt8[]; slide = :bogus))
    expect_argerr_naming_all(thunk, "slide=:bogus must ArgumentError naming all four")
end
for thunk in (() -> print_BLS_Component_Tree(IOBuffer(), mini; slide = :light, color = :always),
              () -> print_altValues_evals(IOBuffer(), mini; slide = :light, color = :never))
    expect_exact(thunk, ArgumentError, "slide + explicit color must ArgumentError")
end

## F13: the validate-BEFORE-write promise — after every unknown-scheme throw the
## target, its sidecar, and the print stream must be UNTOUCHED
mktempdir() do f13
    ## targets live under a NONEXISTENT subdir (never mkdir'd): if any write ever
    ## preceded validation, it would surface as a SystemError, not the required
    ## ArgumentError — validation-BEFORE-write is proven by the throw TYPE (L2#7)
    nx = joinpath(f13, "nx")
    for (name, target, thunk) in (
        ("twin-t1", joinpath(nx, "a.txt"), () -> write_BLS_Component_Tree_to_file(joinpath(nx, "a.txt"), mini; slide = :bogus)),
        ("twin-t2", joinpath(nx, "b.txt"), () -> write_altValues_evals_to_file(joinpath(nx, "b.txt"), mini; slide = :bogus)),
        ("struct",  joinpath(nx, "c.jl"),  () -> writeBlsStructureToFile(joinpath(nx, "c.jl"), mini; slide = :bogus)),
        ("render",  joinpath(nx, "d.jl"),  () -> writeRenderToFile(joinpath(nx, "d.jl"), mini; slide = :bogus)),
        ("source",  joinpath(nx, "e.jl"),  () -> writeMarkedSourceToFile(joinpath(nx, "e.jl"), UInt8[0x78]; slide = :bogus)))
        threw = false
        try
            thunk()
        catch e
            e isa InterruptException && rethrow()
            threw = true
            check(e isa ArgumentError,
                  "F13: $name threw $(typeof(e)), not the pre-write ArgumentError")
        end
        check(threw, "F13: $name did not throw at all")
        check(!isfile(target) && !isfile(target * ".slideruns.json"),
              "F13: $name wrote something despite the pre-write ArgumentError")
    end
    check(isempty(readdir(f13)), "F13: unknown-scheme throws left stray files: $(readdir(f13))")
    for pf in (print_BLS_Component_Tree, print_altValues_evals)
        b13 = IOBuffer()
        threw = false
        try
            pf(b13, mini; slide = :bogus)
        catch e
            e isa InterruptException && rethrow()
            threw = true
            check(e isa ArgumentError, "F13: $pf threw $(typeof(e)), not ArgumentError")
        end
        check(threw && position(b13) == 0,
              "F13: $pf wrote to the stream despite the pre-write ArgumentError")
    end
end

## F11: the devtools-color -> slide-role map, pinned as a LITERAL table (a swapped
## mapping must RED here, not survive as merely-closed-vocabulary)
for (inp, want) in ((_DT_C_CHROME, "gutter"), (_DT_C_BLOCK, "tree"), (_DT_C_LINE, "tree"),
                    (_DT_C_SEG, "tree"), (_DT_C_ATTR, "payload"), (_DT_C_META_F, "marker"),
                    (_DT_C_CODE_F, "code"), (_DT_C_TEXT_F, "text"), (_DT_C_GOOD, "neutral"),
                    (_DT_C_WARN, "neutral"), (_DT_C_BAD, "neutral"),
                    (_DT_C_LEGACY_DUMP, "neutral"), (:normal, "neutral"), (nothing, "neutral"))
    check(_dt_slide_role_of(inp) == want, "F11: role map pin _dt_slide_role_of($(repr(inp))) != $want")
end
## F11 representatives: one captured run per view-reachable role, from a 3-flavor fixture
r11 = GoMeta.goMeta(Vector{UInt8}(codeunits("#~ hide{ isText }\n# a Text line\nx = 1\n")))
cap11 = _dt_slide_cap(); print_BLS_Component_Tree(_dt_slide_capio(cap11), r11)
runs11 = collect(Iterators.flatten(first(_dt_slide_lines(cap11))))
for (pred, want, label) in ((run -> startswith(run[1], "Block #"), "tree", "grain tag"),
                            (run -> startswith(run[1], "Meta"), "marker", "Meta flavor word"),
                            (run -> startswith(run[1], "Code"), "code", "Code flavor word"),
                            (run -> startswith(run[1], "Text"), "text", "Text flavor word"),
                            (run -> occursin("├", run[1]) || occursin("└", run[1]), "gutter", "tree guide chrome"),
                            (run -> occursin(r"Int\d+", run[1]), "gutter", "dump type label"),
                            (run -> occursin("idComponent=", run[1]), "neutral", "dump values"))
    i = findfirst(pred, runs11)
    check(i !== nothing && runs11[i][2] == want,
          "F11: representative run for $label must be role $want (got $(i === nothing ? "ABSENT" : runs11[i]))")
end
cap12 = _dt_slide_cap(); print_altValues_evals(_dt_slide_capio(cap12), r11)
runs12 = collect(Iterators.flatten(first(_dt_slide_lines(cap12))))
i = findfirst(run -> occursin("visib", run[1]) && run[2] == "payload", runs12)
check(i !== nothing, "F11: attr name run (visib) must be role payload")
i = findfirst(run -> occursin(":hide", run[1]) && run[2] == "neutral", runs12)
check(i !== nothing, "F11: :hide value run must be role neutral (status flattening)")

## FR-fold: directory + symlink destinations are REJECTED before staging (slide on)
mktempdir() do fd
    d = joinpath(fd, "adir"); mkdir(d)
    expect_exact(() -> writeRenderToFile(d, mini; slide = :gometa_dark), ArgumentError,
                 "slide-on write to a DIRECTORY must ArgumentError")
    tgt = joinpath(fd, "real.jl"); write(tgt, "x\n")
    lnk = joinpath(fd, "lnk.jl"); symlink(tgt, lnk)
    expect_exact(() -> writeMarkedSourceToFile(lnk, UInt8[0x78]; slide = :gometa_dark), ArgumentError,
                 "slide-on write to a SYMLINK must ArgumentError")
    check(read(tgt, String) == "x\n", "symlink guard must not touch the link target")
end

## FR-fold: the publication MODE POLICY — an existing X keeps its mode across a
## slide-on rewrite; the sidecar is never more permissive than X, never executable
mktempdir() do fm
    pm = joinpath(fm, "m.jl")
    write(pm, "x\n"); chmod(pm, 0o600)
    writeRenderToFile(pm, mini; slide = :gometa_dark)
    check(filemode(pm) & 0o777 == 0o600,
          "mode policy: existing 0600 X must KEEP its mode (got $(string(filemode(pm) & 0o777, base = 8)))")
    scm = filemode(pm * ".slideruns.json") & 0o777
    check(scm & 0o111 == 0 && scm <= 0o600,
          "mode policy: sidecar must be non-executable and never more permissive than X (got $(string(scm, base = 8)))")
end

## F5: a slide-off rewrite retires the stale sidecar — ALL FIVE file tools (L2#4)
mktempdir() do f5
    srcb = Vector{UInt8}(codeunits("x = 1\n"))
    for (name, on, off) in (
        ("render", p -> writeRenderToFile(p, mini; slide = :gometa_dark), p -> writeRenderToFile(p, mini)),
        ("struct", p -> writeBlsStructureToFile(p, mini; slide = :gometa_dark), p -> writeBlsStructureToFile(p, mini)),
        ("source", p -> writeMarkedSourceToFile(p, srcb; slide = :gometa_dark), p -> writeMarkedSourceToFile(p, srcb)),
        ("twin-t1", p -> write_BLS_Component_Tree_to_file(p, mini; slide = :gometa_dark), p -> write_BLS_Component_Tree_to_file(p, mini)),
        ("twin-t2", p -> write_altValues_evals_to_file(p, mini; slide = :gometa_dark), p -> write_altValues_evals_to_file(p, mini)))
        p5 = joinpath(f5, name * ".jl")
        on(p5)
        check(isfile(p5 * ".slideruns.json"), "F5 setup ($name): sidecar missing after slide-on write")
        off(p5)
        check(!isfile(p5 * ".slideruns.json"),
              "F5 ($name): slide-off rewrite must RETIRE the stale sidecar")
    end
end
## empty input succeeds header-only (D1 e.22); invalid UTF-8 throws the documented
## ArgumentError on the writer paths (CrossReview L1/L2/L3 unanimous fix)
mktempdir() do tmp
    pe = joinpath(tmp, "empty.jl")
    writeMarkedSourceToFile(pe, UInt8[]; slide = :gometa_dark)
    sc = read(pe * ".slideruns.json", String)
    check(occursin("\"lines\": []", sc) && occursin("\"final_newline\": false", sc),
          "empty-input sidecar must be header-only with final_newline false")
    try
        writeMarkedSourceToFile(joinpath(tmp, "bad.jl"), UInt8[0x23, 0xff, 0x0a]; slide = :light)
        global fails += 1; println("FAIL  invalid UTF-8 + slide must ArgumentError")
    catch e
        e isa ArgumentError ||
            (global fails += 1; println("FAIL  invalid UTF-8 threw ", typeof(e), " not ArgumentError"))
        check(!isfile(joinpath(tmp, "bad.jl")), "invalid UTF-8 + slide must write NOTHING")
    end
    ## twin color=:always + slide: X carries ANSI, sidecar still describes the plain view
    pa = joinpath(tmp, "ansi.txt")
    write_altValues_evals_to_file(pa, mini; color = :always, slide = :gometa_dark, _name = "twin.txt")
    check(occursin('\e', read(pa, String)), "twin color=:always + slide lost its ANSI X")
    pb = joinpath(tmp, "plain.txt")
    write_altValues_evals_to_file(pb, mini; slide = :gometa_dark, _name = "twin.txt")
    check(read(pa * ".slideruns.json") == read(pb * ".slideruns.json"),
          "twin sidecar must be color-independent (describe the PLAIN view; R1#4 byte-cmp)")
    check(!occursin("\\u001b", read(pa * ".slideruns.json", String)),
          "twin sidecar must not carry ANSI escapes")
end
rerr = GoMeta.goMeta(read(joinpath(_PB_FIX, "mini-Documenter-Source-File.jl"));
                     config = GoMeta.GoMetaConfig(profile = :no_such_profile))
capr = _dt_slide_cap()
print_altValues_evals(_dt_slide_capio(capr), rerr)
lrr, fnlr = _dt_slide_lines(capr)
plc = IOBuffer(); print_altValues_evals(IOContext(plc, :color => false), rerr)
check(join([join(first.(l)) for l in lrr], "\n") * (fnlr ? "\n" : "") == String(take!(plc)),
      "slide: PROCESS_ERROR status banner capture is total (B12)")

## B5 pinned run list — one MIX line of the selfcheck fixture (drift alarm at run level)
rsc = GoMeta.goMeta(Vector{UInt8}(codeunits("#~1 :label1\n# a Text line\nx = 1 #~ head(\"selfcheck head\", 2)\n")))
capr = _dt_slide_cap()
print_BLS_Component_Tree(_dt_slide_capio(capr), rsc)
lrs, _ = _dt_slide_lines(capr)
mixline = findfirst(l -> !isempty(l) && occursin("Block #", join(first.(l))), lrs)
check(mixline !== nothing &&
      any(r -> r[2] == "tree" && startswith(r[1], "Block #"), lrs[mixline]) &&
      any(r -> r[2] == "marker" && startswith(r[1], "Meta"), lrs[mixline]) &&
      lrs[mixline][1][2] == "gutter",
      "slide: pinned MIX Block-row runs (chrome→gutter, grain→tree, Meta→marker) drifted")

## 17 — owner fix-orders 2026-08-21: reference-true tree coloring (#1) + rails (#2B)
## §17a — s13 reference run splits, role-for-role, BOTH flavor families (the run-exact
## reference: plan/2026-08-20-devtools-slide-output/reference-tree-coloring.md)
s13_jl = "#~ hide ## A first 'metaLine'\n\n# This first line is 'Text'. \n## This is a 'comment' of 'Text'\n\n#~2 :\U0001F352\na = 1 ## A 'Block' of 'Code'\nb = 2 #~ discard{ :\U0001F352 }\n"
s13_c  = "//~ hide //# A first 'metaLine'\n\n// This first line is 'Text'. \n//# This is a 'comment' of 'Text'\n\n//~2 :\U0001F352\nint a = 1; //# A 'Block' of 'Code'\nint b = 2; //~ discard{ :\U0001F352 }\n"
## rows 7-8 differ by flavor in the code text — appended per family below
for (tag, src, cfg, mk, code7, code8) in (
        ("julia", s13_jl, GoMeta.GoMetaConfig(), "#~", "a = 1 ", "b = 2 "),
        ("cfam", s13_c, GoMeta.GoMetaConfig(flavor_tag = :c), "//~", "int a = 1; ", "int b = 2; "))
    cm = tag == "julia" ? "##" : "//#"
    want = [
        [("{:B-Meta:L-Meta [{:S-Meta [", "tree"), (mk, "marker"), (" hide ", "payload"),
         ("]}{:S-Meta [", "tree"), (cm * " A first 'metaLine'", "comment"), ("]}]}", "tree")],
        Tuple{String,String}[],
        [("{:B-Text:L-Text [", "tree"),
         ((tag == "julia" ? "# " : "// ") * "This first line is 'Text'. ", "text"), ("]}", "tree")],
        [("{       :L-Text [", "tree"), (cm * " This is a 'comment' of 'Text'", "comment"), ("]}", "tree")],
        Tuple{String,String}[],
        [("{:B-Meta:L-Meta [", "tree"), (mk * "2", "marker"), (" :\U0001F352", "payload"), ("]}", "tree")],
        [("{:B-Code:L-Code [{:S-Code [", "tree"), (code7, "code"), ("]}{:S-Code [", "tree"),
         (cm * " A 'Block' of 'Code'", "comment"), ("]}]}", "tree")],
        [("{       :L-Code [{:S-Code [", "tree"), (code8, "code"), ("]}{:S-Meta [", "tree"),
         (mk, "marker"), (" discard{ :\U0001F352 }", "payload"), ("]}]}", "tree")]]
    r17 = GoMeta.goMeta(Vector{UInt8}(codeunits(src)); config = cfg)
    check(r17.status == GoMeta.PROCESS_OK, "s13 ($tag): source refused")
    sb = copy(Main.BasicRenderer.outputs(r17).blsStructure_bytes)
    got = _dt_sl_structure_runs(r17, sb)
    check(got !== nothing, "s13 ($tag): structure mirror DEGRADED (must be reference-true)")
    if got !== nothing
        check(length(got) == 8, "s13 ($tag): expected 8 structure lines, got $(length(got))")
        for i in 1:min(8, length(got))
            check(got[i] == want[i],
                  "s13 ($tag) line $i run split drifted:\n    got  $(got[i])\n    want $(want[i])")
        end
    end
    ## and end-to-end: the sidecar written by the public writer carries the marker run
    mktempdir() do td
        ps = joinpath(td, "s.jl")
        writeBlsStructureToFile(ps, r17; slide = :gometa_dark)
        sc = read(ps * ".slideruns.json", String)
        check(occursin("{ \"text\": \"$(mk)\", \"role\": \"marker\"", sc),
              "s13 ($tag): sidecar lost the marker run")
        check(occursin("\"role\": \"comment\"", sc) && occursin("\"role\": \"code\"", sc),
              "s13 ($tag): sidecar lost comment/code roles")
    end
end
## degrade honesty: a result whose structure bytes were perturbed must fall back
## to whole-line tree, never mis-role
r17b = GoMeta.goMeta(Vector{UInt8}(codeunits(s13_jl)))
pert = replace(String(copy(Main.BasicRenderer.outputs(r17b).blsStructure_bytes)), "hide" => "hidE")
check(_dt_sl_structure_runs(r17b, Vector{UInt8}(codeunits(pert))) === nothing,
      "s13: perturbed structure bytes must DEGRADE the mirror to fallback")

## §17b — rails, mechanical acceptance (order #2B): in the kitchen fixture, every
## attribute row between a parent and its FIRST printed child carries │ at the
## child's connector column; the leaf Segment's dump rows keep it blank
kitchen = GoMeta.goMeta(Vector{UInt8}(codeunits("#~1 :label1\n# t\nx = 1 #~ head(\"h\", 2)\ny = 2\n")))
for style_kw in ((;), (; style = :tree, detail = :full))
    out17 = plain(io -> print_BLS_Component_Tree(io, kitchen; style_kw...))
    ls17 = split(out17, '\n')
    viol = 0
    nwalked = 0        # FX1#1: the checker must PROVE it walked attribute rows
    for (i, l) in enumerate(ls17)
        m = match(r"^((?:│  |   )*)(├─|└─)", l)
        m === nothing && continue
        col = ncodeunits(m.captures[1]) + 1   # byte col of the connector glyph
        ## walk BACK over attribute rows to the parent header; each must carry │ at col
        j = i - 1
        while j >= 1 && match(r"^((?:│  |   )*)(├─|└─)", ls17[j]) === nothing
            occursin(r"Int\d+|Bool", ls17[j]) || break
            nwalked += 1
            prefix = ls17[j]
            cu = codeunits(prefix)
            ok17 = ncodeunits(prefix) >= col + 2 &&
                   String(cu[col:col+2]) == "│"   # │ is 3 bytes
            ok17 || (viol += 1)
            j -= 1
        end
    end
    check(viol == 0, "rails: $viol attribute row(s) missing │ at the first-child connector column (style=$(isempty(style_kw) ? ":mix" : ":tree full"))")
    check(nwalked >= 4, "rails: the checker walked only $nwalked attribute row(s) — degenerate pass (FX1#1)")
end
## childless-blank clause (FX2#2): a leaf Segment's dump rows must carry NO │
## beyond the leaf's own connector column (the would-be child rail stays blank)
outls = split(plain(io -> print_BLS_Component_Tree(io, kitchen)), '\n')
seg_rows = [i for (i, l) in enumerate(outls) if occursin("Segment #", l)]
check(!isempty(seg_rows), "rails: kitchen fixture lost its Segment rows")
ndump17 = 0
for i in seg_rows
    m = match(r"^((?:│  |   )*)(├─|└─)", outls[i])
    m === nothing && continue
    conncol = ncodeunits(m.captures[1]) + 1
    for j in (i + 1):min(i + 2, length(outls))
        mm = match(r"Int\d+|Bool", outls[j])
        mm === nothing && continue
        global ndump17 += 1
        cu = codeunits(outls[j])
        beyond = String(cu[min(conncol + 3, length(cu)):max(1, mm.offset - 1)])
        check(!occursin("│", beyond),
              "rails childless-blank: leaf Segment dump row carries │ beyond its connector column")
    end
end
check(ndump17 >= 2, "rails childless-blank: walked only $ndump17 leaf dump rows — degenerate (FX2#2)")

println(fails == 0 ? "probe_devtools: ALL GREEN" : "probe_devtools: $fails FAILURE(S)")
exit(fails == 0 ? 0 : 1)
