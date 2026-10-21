# probe_devtools.jl — the devtools.jl assertion battery (canon R3: probes over claims).
#   (2026-09-12, owner ruling — the v0.4 build record's OWNER-WORDS §26) The battery lives HERE,
#   beside the tools it tests (devtools/probes/), since the play became a self-contained fork;
#   the play keeps its own frozen copy of it. Its two fixture inputs: fixtures/ (the mini
#   Documenter source, copied from the play) and examples/InFileFolder/file_for_Example_Extended.jl.
#
# IS:   the empirical check of every devtools surface the byte-parity sweep cannot
#       cover — filters, dispatch validation, format inference, the
#       drift alarm. (Byte parity
#       vs the creator-approved mockups is the OTHER half of verification:
#       plan/2026-08-19-gometa-dev-print-tools/, 34/34 at build.)
# DOES: runs goMeta on the two standing fixture inputs,
#       drives both printers through the filter/error tiers into
#       IOBuffers/tempfiles, and counts failed checks.
# PURPOSE: re-runnable ANY session (esp. after a change under src/ or devtools/, together
#       as THE drift alarm — the tools' own self-check left at stage 5's T1, R-V04B-111); exit code 0 = all green.
#
#   GM=/home/fido/Dropbox/_01_Crypto_Dropbox/07_Claude/GoMetaEcosystem/GoMeta
#   julia --startup-file=no --project=$GM/tests $GM/devtools/probes/probe_devtools.jl

const _PB_HOME = normpath(joinpath(@__DIR__, "..", ".."))   # the code home (the repository root)
const _PB_FIX  = joinpath(@__DIR__, "fixtures")             # the battery's own fixture inputs
import GoMeta
include(joinpath(@__DIR__, "..", "load_basic_renderer.jl"))   # the ONE path to the basic renderer
include(joinpath(@__DIR__, "..", "devtools.jl"))   # the tools, one level up

fails = 0
check(cond, msg) = (cond ? nothing : (global fails += 1; println("FAIL  ", msg)); nothing)
plain(f) = (b = IOBuffer(); f(b); String(take!(b)))

mini = GoMeta.goMeta(read(joinpath(_PB_FIX, "mini-Documenter-Source-File.jl")))
ext  = GoMeta.goMeta(read(joinpath(_PB_HOME, "examples", "InFileFolder", "file_for_Example_Extended.jl")))

## 1 — the drift alarm is this battery itself (the tools' self-check `devtools_selfcheck()` left at stage 5's T1 — R-V04B-111, census row 18)

## 2 — attrs filter: count agreement with the raw surface + explicit never-minted state
raw_visib = count(r -> r[2] === :visib, GoMeta.readAltValuesEvals(ext.altValues_evals))
out = plain(io -> print_altValues_evals(io, ext; layout = :rows, attrs = :visib))
nrows = count(l -> occursin("visib", l) && occursin("=>", l), split(out, '\n'))
check(nrows == raw_visib, "attrs=:visib rendered $nrows rows, expected $raw_visib")
check(occursin(":visib: $raw_visib match", out), "attrs echo count ≠ raw altValues_evals count ($raw_visib)")
check(!occursin("label_", out), "attrs=:visib leaked label rows")
out = plain(io -> print_altValues_evals(io, ext; layout = :rows, attrs = [:label_nope]))
check(occursin("0 matches — :label_nope never minted", out), "never-minted state not explicit")

## 3 — lines filter restricts anchored rows (the unanchored-row half of this probe — a heading fed through the user profile — left at
##     stage 1 of the Alterants build: a heading in the profile refuses at the read, §D242; no shipped path produces an unanchored row)
out = plain(io -> print_altValues_evals(io, mini; layout = :rows, lines = 1:1))
check(!occursin("label_🍻", out), "lines=1:1 leaked a row outside the range")
check(occursin("filter lines=", out), "the lines filter echo missing")
uhd = try GoMeta.goMeta(read(joinpath(_PB_FIX, "mini-Documenter-Source-File.jl"));
                         config = GoMeta.GoMetaConfig(user_mh_profile = "head(\"Fed head\", 1)")); nothing catch e; e end
check(uhd isa ErrorException && occursin("in the profile feed has no Component of the file levels to be local to", uhd.msg),
      "a heading fed through the user profile must meet the one refusal (stage 1 of the Alterants build)")

## 4 — blocks= selects the named Blocks; an id that names no Block selects nothing (the checked fetch left at stage 5's T3)
out = plain(io -> print_BLS_Component_Tree(io, mini; blocks = [999, 2]))
check(occursin("Block #2", out) && !occursin("999", out), "blocks= did not select the named Block alone")

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

## 6b — the inline head row (keyed on its Line since R-V04B-98, the Segment its origin) shows under the Line in :tree; totality holds
seg = GoMeta.goMeta(Vector{UInt8}(codeunits("x = 1 #~ head(\"Inline head\", 2)\n# a Text line\n")))
out = plain(io -> print_altValues_evals(io, seg; include_empty = true))
check(occursin("← Segment #", out) && occursin("head_2", out),
      "the inline head row does not show under its Line with its Segment origin (← Segment #N) in :tree")
check(!occursin("unanchored rows", out), "the inline head row fell to the unanchored section")
nbullets = count(l -> occursin("●", l), split(out, '\n'))
nrows = length(GoMeta.readAltValuesEvals(seg.altValues_evals))
check(nbullets == nrows, ":tree rendered $nbullets bullets for $nrows rows — totality broken")
out = plain(io -> print_altValues_evals(io, seg; layout = :cells))
check(occursin("head_2", out), "the inline head row missing from :cells")

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

## 9 — friendly kwarg validation (friendly errors, not raw MethodErrors)
expect_throw(() -> plain(io -> print_altValues_evals(io, mini; attrs = "visib")),
             "attrs=\"visib\" (a String) must raise the friendly error")
expect_throw(() -> plain(io -> print_altValues_evals(io, mini; lines = "5:12")),
             "lines=\"5:12\" (a String) must raise the friendly error")
expect_throw(() -> plain(io -> print_BLS_Component_Tree(io, mini; blocks = :al)),
             "blocks=:al must raise the friendly error")

## 10 — invalid UTF-8 content renders without throwing (byte-faithful engine input)
raw = vcat(Vector{UInt8}(codeunits("# ok line\n# bad ")), [0xff, 0xc3], Vector{UInt8}(codeunits(" tail\n")))
badr = GoMeta.goMeta(raw)
out = plain(io -> print_BLS_Component_Tree(io, badr))
check(!isempty(out), "invalid-UTF-8 input rendered empty")

## 11 — a namespace=:other run's rows anchor (no namespace check since stage 5's T3)
nsr = GoMeta.goMeta(read(joinpath(_PB_FIX, "mini-Documenter-Source-File.jl"));
                    config = GoMeta.GoMetaConfig(namespace = :other))
out = plain(io -> print_altValues_evals(io, nsr; layout = :rows))
check(!occursin("unanchored", out) && occursin("label_🍻", out),
      "namespace=:other rows failed to anchor against their own result")

## 12 — (the USER_CONTEXT totality probe over a fed heading's unanchored row left at stage 1 of the Alterants build: no shipped path
##       produces an unanchored row since a `localOnly` statement in the profile refuses at the read — his §D242 on the fed heading;
##       the reach to every `localOnly` statement of every registry the condition's (src/absorb/absorb_meta.jl), R-ALT-15 (ii)(1);
##       landed d904689, 2026-10-16; the tools' unanchored arms stand as the totality guard for a row the tools cannot place, their
##       texts re-cut to the dated fact at the clean-up of 2026-10-17 on his word — the Alterants build lane's R-ALT-41) — a fed
##       QUEUED action anchors on the Components as every row does
uctx2 = GoMeta.goMeta(read(joinpath(_PB_FIX, "mini-Documenter-Source-File.jl"));
                      config = GoMeta.GoMetaConfig(user_mh_profile = "show"))
nraw = length(GoMeta.readAltValuesEvals(uctx2.altValues_evals))
out = plain(io -> print_altValues_evals(io, uctx2; layout = :rows))
nrend = count(l -> occursin("=>", l), split(out, '\n'))
check(nrend == nraw, ":rows rendered $nrend rows for $nraw raw rows — totality broken")
check(count(l -> occursin("=> :show", l), split(out, '\n')) >
      count(l -> occursin("=> :show", l), split(plain(io -> print_altValues_evals(io, mini; layout = :rows)), '\n')),
      "the fed show minted no anchored row")   # the review's C12: the fixture's own `#~1 show{ :🍻 && !isMeta }` mints one
                                               # `=> :show` row WITHOUT a feed (Block #6), so the fed run must render MORE of them
                                               # (MEASURED: 4 with the feed, the lane's PROBE-c12-fed-show_scratch.txt; 1 without, the
                                               # lane's receipts/measure-labels/views/A at da86f4c2)
check(!occursin("unanchored", out) && !occursin("USER_CONTEXT", out), "a fed queued action produced an unanchored row")

## 13 — an error delivery prints as the empty document its tree is (the status-first banner left at stage 5's T3 — the
## command-line entry prints the status to stderr); empty docs show the File summary in EVERY style
_pbD = GoMeta.DEFAULT_REGISTRY   # a conforming UNPUBLISHED registry (route U) — the door refuses it coded (REG_UNPUBLISHED);
_pbU = GoMeta.AlterantRegistry(_pbD.plugins, _pbD.sorted_alt_actions, _pbD.action_to_plugin, _pbD.action_index,   # the unknown-
                               _pbD.alt_index, _pbD.accum_alt_idxs, _pbD.mutex_alt_idxs, _pbD.action_specs, _pbD.spec_index)   # profile route left at stage 5's E13
err = GoMeta.goMeta(read(joinpath(_PB_FIX, "mini-Documenter-Source-File.jl")); registry = _pbU)
out = plain(io -> print_BLS_Component_Tree(io, err))
check(err.status == GoMeta.PROCESS_ERROR && occursin("0 Blocks", out) && !occursin("status", out),
      "an error delivery does not print as the empty document")
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

## 17 — owner fix-order 2026-08-21 (#2B): rails (fix-order #1, the reference-true structure slide runs, left with the slide option at stage 5's T2 — census rows 2 and 9, his §317)

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

## §18 — the comparison form (stage 4; R-V04B-36; §I): deterministic; one C line per Component (the census + the File)
## and four A lines per non-File Component (the four registered Alterants); every A line's source is a level word or a
## key among the C lines; the lines sorted by code point; the Segment spans in CHARACTERS (the emoji input); the file
## writer writes the same bytes the producer returns (the CLI verb is exercised by the pre-check's run on a corpus input, not here)
for (fx, fxname) in ((mini, "mini"), (ext, "ext"))
    cf18 = comparisonForm(fx; name = fxname, at = "-")
    check(cf18 == comparisonForm(fx; name = fxname, at = "-"), "§18 $fxname: the form is not deterministic")
    ls18 = split(chomp(cf18), '\n')
    nb18, nl18, ns18 = _dt_census(_dt_doc(fx; name = fxname))
    nC18 = count(l -> startswith(l, "C | "), ls18); nA18 = count(l -> startswith(l, "A | "), ls18)
    check(nC18 == nb18 + nl18 + ns18 + 1, "§18 $fxname: $nC18 C lines, expected $(nb18 + nl18 + ns18 + 1) (the census + the File)")
    check(nA18 == 4 * (nb18 + nl18 + ns18), "§18 $fxname: $nA18 A lines, expected $(4 * (nb18 + nl18 + ns18))")
    check(startswith(ls18[1], "# GoMeta comparison form v1 | $fxname | produced by GoMeta v0.4 at - | $nC18 Components | $nA18 answer lines"),
          "§18 $fxname: the header does not carry the counts ($(ls18[1]))")
    check(ls18[2:end] == sort(ls18[2:end]), "§18 $fxname: the body is not sorted by code point")
    check(length(unique(ls18[2:end])) == length(ls18) - 1, "§18 $fxname: a duplicate line (two Components with one key?)")
    keys18 = Set(String[join(split(l, " | ")[2:3], " ") for l in ls18 if startswith(l, "C | ")])
    for l in ls18
        startswith(l, "A | ") || continue
        fl = split(l, " | ")
        check(length(fl) == 6, "§18 $fxname: an A line with $(length(fl)) fields: $l")
        src18 = fl[6]
        check(src18 in ("user", "file", "default") || src18 in keys18, "§18 $fxname: an A line's source is neither a level nor a Component key: $l")
        check(fl[2] != "File", "§18 $fxname: the File carries an answer line (the narrowing of R-V04B-36 (a) until his word): $l")
    end
    for l in ls18
        startswith(l, "C | ") || continue
        fl = split(l, " | ")
        check(length(fl) == 8, "§18 $fxname: a C line with $(length(fl)) fields: $l")
        check(fl[4] == "-" || fl[4] in keys18, "§18 $fxname: a C line's parent key is not a Component key: $l")
        for k in (fl[6] == "-" ? String[] : String.(split(fl[6], ";")))
            check(k in keys18, "§18 $fxname: a C line names a child key that is no Component: $k in $l")
        end
        check(!occursin("component.hide", l) && !occursin("component.show", l) && !occursin("component.discard", l), "§18 $fxname: a Visib flag leaked into the form: $l")
    end
    mktempdir() do tmp
        p18 = joinpath(tmp, fxname * ".cmp.txt")
        writeComparisonFormToFile(p18, fx; name = fxname, at = "abcdef12")
        w18 = read(p18, String)
        check(occursin("produced by GoMeta v0.4 at abcdef12", split(w18, '\n')[1]), "§18 $fxname: the file writer lost the producing commit in the header")
        check(join(split(w18, '\n')[2:end], '\n') == join(split(cf18, '\n')[2:end], '\n'), "§18 $fxname: the written body differs from the producer's")
    end
end
emoji18 = GoMeta.goMeta(Vector{UInt8}(codeunits("x = \"🍒🍒\" #~ hide\n")))
cfe18 = comparisonForm(emoji18; name = "emoji", at = "-")
check(occursin("\nC | Segment | 1:1-9 | Line 1-1 | 1 | - | Code | ", cfe18) && occursin("\nC | Segment | 1:10-16 | Line 1-1 | 2 | - | Meta | ", cfe18),
      "§18 emoji: the Segment spans are not the character spans 1:1-9 and 1:10-16 (the bytes are 1-15 and 16-22)")
check(occursin("\nA | Line | 1-1 | Visib | hide | Line 1-1\n", cfe18), "§18 emoji: the Line's own Visib answer (hide, own — its trailing metaSegment's) drifted")
check(occursin("\nA | Segment | 1:1-9 | Visib | hide | Line 1-1\n", cfe18), "§18 emoji: the Segment's Visib answer (hide, through its Line) drifted")
## the value grammar on the four Alterants' shapes
check(_cf_value(nothing) == "null" && _cf_value(true) == "true" && _cf_value(:show) == "show" && _cf_value(7) == "7", "§18: the scalar value grammar drifted")
check(_cf_value("a \"q\" | b\n") == "\"a \\\"q\\\" | b\\n\"", "§18: the text value grammar drifted ($(_cf_value("a \"q\" | b\n")))")
check(_cf_value([:label5, :label1]) == "{label1,label5}" && _cf_value(Symbol[]) == "{}", "§18: the set value grammar drifted")
check(_cf_value((parent = Int16(3), cell = Int16(7))) == "(cell=7,parent=3)", "§18: the compound value grammar drifted")

println(fails == 0 ? "probe_devtools: ALL GREEN" : "probe_devtools: $fails FAILURE(S)")
exit(fails == 0 ? 0 : 1)
