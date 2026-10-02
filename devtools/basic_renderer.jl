isdefined(Main, :_BASIC_RENDERER_LOADED) && error("basic_renderer.jl: loaded a SECOND time — the one-path rule (R-V04B-24 obligation 7); include devtools/load_basic_renderer.jl, never this file")
Core.eval(Main, :(const _BASIC_RENDERER_LOADED = true))
# basic_renderer.jl — the basic renderer, a DEVELOPMENT TOOL: `render_bytes` produces the jl-share-v1
# share render; `outputs` (below) the (tree, render) pair. Formerly `src/emit/emit.jl`, module
# `WriteOutFile`, the emit stage of the Engine — moved out on 2026-09-12 (R-V04B-13 / R-V04B-24).
#
# IS: module `BasicRenderer` — the basic renderer, a development tool OUTSIDE the Engine. Its entry point
#     `render_bytes(delivery)::Vector{UInt8}` walks the delivered
#     File→Block→Line→Segment tree (`delivery.blsComponentTree`) through THE DOOR (`BLS.root`, `BLS.children`, `BLS.content`,
#     `BLS.getElement`; docs/public-api.md §1.2) and writes the share-target bytes into an
#     in-memory IOBuffer — the render half of the tool's own `outputs` (below; docs/public-api.md §1.3;
#     docs/CANONICAL-OUTPUT.md §3). Every Visib verdict it applies is THE ENGINE's ANSWER —
#     `GoMeta.answerFor(delivery, component, :Visib).value` (stage 3 of the v0.4 build; R-V04B-16 (1)): the renderer
#     resolves nothing itself.
# DOES: applies the jl-share-v1 hide/discard rules (docs/CANONICAL-OUTPUT.md §3) during the walk.
#     The verdict a Line or a Segment gets is the Engine's answer for THAT Component (the Component's own
#     rows, else its parent's up the tree, else the declared default `show` — the Engine's inner-wins
#     precedence; a Segment's answer per R-V04B-52 (2)). `:discard` at any grain skips the whole subtree — zero bytes. `:hide` writes the
#     flavor's hide marker (the literal "## " in the `:julia` flavor) before each rendered
#     non-empty line and before each rendered segment, ahead of the restored indentation — an
#     ENSURE-TOKEN write, not exactly-one-prefix: the write is skipped when the source line's
#     post-indent head already begins with the hide marker, so re-rendering an ingested render is
#     byte-stable (render-idempotence; an authored marker-headed line under hide renders as-is —
#     hide stays one-way, never byte-reversible); a hidden EMPTY line renders as a BARE empty line
#     (the hide write sits in the non-empty branch — docs/CANONICAL-OUTPUT.md §3). On a
#     segmented line the leading-whitespace columns are restored once, before the first emitted
#     segment — captured from the first structural segment, so the indent survives even when that
#     segment is itself discarded; a line that is neither included verbatim nor segmented
#     contributes zero bytes. The render ends 0x0a exactly when the PARSED source content did:
#     every emitted line is "\n"-terminated, then one trailing 0x0a is trimmed iff
#     `parse_state.endsWithNewline` is false — for a whole-file parse that is the input's terminal
#     byte; for a prefix `parse_range` the parser completes the fact (a range stopping before the
#     last source line ends at a line boundary, so its newline is kept). The insert store's negative
#     child ids are resolved by `BLS.children` itself (stage 2's commit 0); this file's former id-sign
#     dispatch, with its kept latent `[2]`-store defect, is gone.
# REASONING: the golden layer pins this render byte-for-byte over the committed example corpus
#     (docs/CANONICAL-OUTPUT.md §5), which forces the emit to be pure and side-channel-free: no
#     filesystem / clock / environment read, render bytes produced solely by the `write(io, …)`
#     sites. `render_bytes` is the tool's own function, reached through the tool's `outputs`; it is no
#     longer part of the Engine (R-V04B-24 B1).
# PURPOSE: the development tool's deterministic reference render — the render half of the tool's
#     `outputs`, which the committed corpus and the golden test layer pin byte-for-byte.
# THE INTERIM CLOSED (R-V04B-24 A1, dated 2026-09-12 — a dated, temporary exception to R-V04B-13's "never
#     recompute"; closed at stage 3's first commit of the pure-consumer branch, R-V04B-16 (1)): until that commit this
#     renderer RESOLVED the Engine's stored Visib flags itself (`checkVisib`, nearest flag wins); now every verdict is
#     the Engine's answer per Component, read from the delivery (`GoMeta.answerFor`) — the renderer re-evaluates nothing
#     and resolves nothing. It reads the delivered part `result.blsComponentTree` (public by name, R-V04B-29) THROUGH THE
#     DOOR since stage 2's commit 0 (R-V04B-58, R-V04B-80): BLS's public functions and types — `BLS.root`,
#     `BLS.children`, `BLS.getElement`, `BLS.content`, `BLS.kind`, `BLS.flavor`, `BLS.endsWithNewline`, the Component
#     types (docs/public-api.md §1.2) — and no field of a BLS object. ONE RESIDUE read outside the door remains,
#     marked at its two sites: `BLS._isspace_valid`, the parser's own whitespace guard for the ensure-token head
#     read (no door name serves it — `BLS.isHorizontalSpace` is the `[\h]` class and differs at \f and \v; his word
#     is asked). The former interim (D-6(a) of 2026-08-20, widened 2026-09-11, R-V04B-24 C1 (a); lapsed 2026-09-16,
#     R-V04B-29) covered the reads this commit migrated; it covers the residue alone now. `devtools_selfcheck()` is the drift alarm.
# THE LOAD-ORDER LAW: include `devtools/load_basic_renderer.jl` at the consumer's TOP LEVEL — never this
#     file (the sentinel at the top refuses a second load) and never inside a function (Julia's world age:
#     a method defined while a function is already running is invisible to that function).

## BasicRenderer.jl
module BasicRenderer

import GoMeta
import GoMeta.BLS

## The HIDE-aware render. Every Visib verdict is THE ENGINE's ANSWER for the Component in hand —
## `GoMeta.answerFor(delivery, component, :Visib).value`, one of `:show` / `:hide` / `:discard` (the three Visib
## actions of the default registry): the Component's own rows, else its parent's up the tree (a Line its Block's, a
## Segment its Line's — R-V04B-52 (2)), else the declared default `show` (R-V04B-51). The renderer resolves nothing
## itself (R-V04B-16 (1)): the former flag read (`checkVisib` on the settribute keys the Apply wrote back), the
## nearest-wins precedence and the sticky per-line Segment cascade left at stage 3's first commit — MEASURED equal
## to the answer on every Block, Line and Segment of the corpus and the authored scenarios before the change
## (plan `receipts/S8-branch/precheck-s3c1/PROBES-s3-consumer-equivalence.txt`); the renderer's own multi-Visib
## guard went with the flag read (the Engine's capture refuses multiplicity — src/annotations.jl). What stays is
## the WRITE side: `discard` is ABSENCE entire (no content, no newline — the inherited `wroteToLine` law); `hide`
## writes the flavor's marker before each rendered non-empty line and each rendered segment (ensure-token, below);
## a hidden EMPTY line renders as a BARE empty line; a verdict outside the three renders plain (as the former
## `notAvailable` did). There is NO component-level `:discard` subtree-skip: an inner `show` (or `hide`) under a
## discarded ancestor RESURFACES — at every grain — because the inner Component's own answer is its own.
## FLAVOR AXIS: the hide marker is the flavor's `hide_marker` ("## " for :julia — the
## default, byte-identical for every existing caller — and "//# " for :c), passed as the
## `hide_marker` kwarg at the output-assembly site from the delivered tree's FlavorProfile record
## (`BLS.flavor(result.blsComponentTree)`). Hide is VISIBILITY-only — the marker is a plain comment
## form in its flavor and hidden metadata remains live on re-ingestion, by design.

## visib_of — the Engine's resolved Visib verdict for ONE Component of the delivered tree (R-V04B-16 (1)): the value of
## the one answer function; the SOURCE (own / indirect / user / default) is not the renderer's business.
visib_of(delivery::GoMeta.GoMetaDelivery, c::Union{BLS.Block,BLS.Line,BLS.Segment})::Symbol =
    GoMeta.answerFor(delivery, c, :Visib).value

function render_bytes(
    delivery::GoMeta.GoMetaDelivery;   # the delivered object: its tree is walked through the door, its answers decide every verdict
    ## The per-flavor hide render marker. Default = the TREE's own flavor record (`BLS.flavor(delivery.blsComponentTree)`), so a
    ## caller passing nothing renders with the flavor the tree was parsed under; the
    ## output-assembly site passes the delivered tree's `BLS.flavor(result.blsComponentTree).hide_marker`.
    ## Hide is VISIBILITY-only — the marker is a plain comment form in its flavor and
    ## hidden metadata remains live on re-ingestion, by design.
    hide_marker::AbstractString = BLS.flavor(delivery.blsComponentTree).hide_marker,
    ## The comment-aware hide fold's per-flavor eligibility prefix — a comment-CLASSIFIED
    ## component already carrying it (post-indent) takes NO additional marker
    ## (ensure-token). Passed by the output-assembly site from the delivered tree's
    ## flavor record (`BLS.flavor(result.blsComponentTree)`).
    hide_fold_prefix::AbstractString = BLS.flavor(delivery.blsComponentTree).hide_fold_prefix
)::Vector{UInt8}

    parse_state = delivery.blsComponentTree   # the delivered part, read through the door (its Julia type is his open item 5 — not named here)
    io = IOBuffer()

    local stringIdx::Int
    local lineText::String   # the current line's VERBATIM source text, read through the door (`BLS.content` of the Line)
    ## The wroteToLine law (inherited from the origin engine) — the line terminator fires only
    ## if the line SURVIVED resolution (content written OR a surviving empty line —
    ## the invariant is survival, not bytes-written); a fully-discarded line
    ## is ABSENT (content AND newline).
    local wroteToLine::Bool
    ## The Line's verdict — the Engine's answer for the Line (its own rows, else its Block's, else the default).
    finalVisib::Symbol = :show
    ## repin1_* — per-line indent-restore state (the line's leading columns, emitted once
    ## before the first emitted segment):
    local repin1_indent_sidx::Int   # the source-line index whose leading columns are the line indent
    local repin1_indent_start::Int  # the first-structural-segment startMainStr; indent = the columns before it
    local repin1_indent_done::Bool  # the indent has been emitted (once, before the first emitted segment)
    local repin1_first_seg::Bool    # still on the first STRUCTURAL segment (capture the indent there)
    ## The tree's one File through the door (`BLS.root`); the walk down through `BLS.children` — source order,
    ## the insert store's negative ids resolved by BLS itself (this file's former id-sign dispatch is gone).
    crntFile::BLS.File = BLS.root(parse_state)
    for crntBlock in BLS.children(parse_state, crntFile)

        ## NO block-grain discard skip — a Block's `discard` reaches its Lines through THEIR answers (a rowless
        ## Line inherits its Block's), and an inner show/hide at a finer grain is that Component's own answer.

        for crntLine in BLS.children(parse_state, crntBlock)

            ## R-1: no line-grain discard skip either — the Line's verdict is the Engine's answer for the Line;
            ## the `!= :discard` test runs per grain below (per the origin engine). wroteToLine = the inherited
            ## terminator law (original :64/:140).
            finalVisib = visib_of(delivery, crntLine)
            stringIdx = BLS.getElement(crntLine, :idxString)
            wroteToLine = false


            if BLS.getElement(crntLine, :includeInOutFile)
                ## R-1: the discard test AFTER the override (original :79) — a discarded
                ## line is ABSENT entirely: no content, and wroteToLine stays false so no
                ## newline either.
                if finalVisib != :discard
                    if BLS.getElement(crntLine, :isEmpty)
                        ## a (possibly hidden) EMPTY line renders BARE — the wroteToLine
                        ## terminator below supplies the "\n"; the hide write sits in the
                        ## non-empty branch.
                        if stringIdx != 0
                            error("GoMeta internal invariant violated: an :isEmpty line ",
                                "carries stringIdx = ", stringIdx, " != 0 — please report ",
                                "this (not reachable from any v0 input)")
                        end
                        wroteToLine = true
                    else
                        ## The line's VERBATIM source text through the door — `BLS.content` of a Line is its full
                        ## source line, byte-equal to the former `collectedLines[idxString]` read (probe-proven over
                        ## the corpus: a Line's `:idxString` and `:inputLineNum` name the same line).
                        lineText = String(BLS.content(parse_state, crntLine))
                        ## A hidden line renders hide-marker-commented — the marker is the flavor's
                        ## `hide_marker` ("## " :julia, "//# " :c, "%% " :latex; docs/CANONICAL-OUTPUT.md
                        ## §3). ENSURE-TOKEN: a comment-classified line already carrying the flavor's
                        ## fold prefix post-indent takes NO additional marker; metaLines + TEXT lines
                        ## lack :comment and stay marked (the indentation-tolerant classification is
                        ## the parser's own).
                        if finalVisib == :hide
                            let s = lineText
                                ## ENSURE-TOKEN, the second disjunct: the
                                ## marker is ALSO skipped when the source line's POST-INDENT head
                                ## already begins with the flavor's `hide_marker` (the authored/
                                ## re-ingested marker-head class the comment-gated fold cannot
                                ## reach) — the `render ∘ ingest ∘ render == render` fixed point.
                                ## Unreachable for the three armed flavors at THIS grain (every
                                ## marker-headed unsegmented line is comment-classified, and
                                ## fold is a byte-prefix of marker) — mandated by K1 at BOTH
                                ## grains regardless; load-bearing at the segment grain below.
                                ## FIDELITY BOUND (the FOLDBACK #4 disclosure): an authored
                                ## marker-headed line under hide is byte-indistinguishable from
                                ## engine-hidden output; hide stays never byte-reversible
                                ## (already true under the R-2 fold).
                                ## THE ALPHABET LAW: the ensure-token disjunct is an
                                ## INPUT-FACING whitespace test over raw source bytes, so it rides the
                                ## parser's own `_isspace_valid` guard — bare `isspace` throws at decode
                                ## on overlong-and-kin sequences the parser classifies CONTENT. The (a)
                                ## disjunct's bare lstrip stays: its `:comment &&` guard guarantees a
                                ## valid head region (R-2 unchanged, per the row).
                                if !((BLS.getElement(crntLine, :comment) &&
                                      startswith(lstrip(s), hide_fold_prefix)) ||
                                     startswith(lstrip(BLS._isspace_valid, s), hide_marker))   # RESIDUE outside the door: the parser's own whitespace guard (no door name serves it; `BLS.isHorizontalSpace` differs at \f and \v — probe-proven); his word asked at stage 2's commit 0
                                    write(io, hide_marker)
                                end
                            end
                        end
                        write(io, lineText)
                        wroteToLine = true
                    end
                end ## END of R-1: "finalVisib != discard" (line grain)
            elseif BLS.getElement(crntLine, :numChildren) != 0
                ## Reset the per-line indent-restore (repin1_*) state.
                repin1_indent_done = false
                repin1_first_seg = true
                repin1_indent_sidx = 0
                repin1_indent_start = 0
                ## Materialize the line's ORDERED segment list through the door (`BLS.children` of a Line — the
                ## insert store resolved by BLS itself; this file's former sign-dispatch ternary, with its kept
                ## `[2]`-store defect, is gone); each Segment's verdict is the Engine's answer for THAT Segment
                ## (R-V04B-52 (2): its own rows if any, else its Line's); the write loop consumes them positionally.
                orderedSegments = BLS.children(parse_state, crntLine)
                segVerdicts = Symbol[visib_of(delivery, sg) for sg in orderedSegments]
                ## The line's full source text through the door, read once: the ensure-token head test and the
                ## indent restore read the SOURCE LINE (a Segment's `:idxString` names its own Line's line — probe-proven).
                lineText = String(BLS.content(parse_state, crntLine))
                for (segIdx, crntSegment) in enumerate(orderedSegments)
                    if repin1_first_seg
                        ## re-pin #1: the LINE indent = the FIRST STRUCTURAL segment's leading-whitespace
                        ## columns before startMainStr, char-safe via prevind (captured here even if this
                        ## first segment is later discarded, so the indent precedes the first EMITTED segment).
                        repin1_indent_sidx = BLS.getElement(crntSegment, :idxString)
                        repin1_indent_start = BLS.getElement(crntSegment, :startMainStr)
                        repin1_first_seg = false
                    end

                    ## R-1: the segment discard test on the Segment's own answer (original
                    ## :116) — an inner `show` under a discarded ancestor RESURFACES here.
                    if segVerdicts[segIdx] != :discard
                        if BLS.getElement(crntSegment, :includeInOutFile)
                            ## A hidden segment renders hide-marker-commented BEFORE the restored
                            ## indent (per-segment markers, the flavor's `hide_marker`;
                            ## docs/CANONICAL-OUTPUT.md §3). A hidden trailing comment segment already
                            ## carrying the flavor's fold prefix takes no second marker mid-line.
                            if segVerdicts[segIdx] == :hide
                                let sl = String(BLS.content(parse_state, crntSegment))   # the segment's own bytes through the door
                                    ## ENSURE-TOKEN at SEGMENT grain (the line-head predicate:
                                    ## "suppression applies at both grains"): the second disjunct
                                    ## reads the SOURCE LINE's post-indent head — NOT the segment
                                    ## slice (probe-proven: the growing meta segment's slice never
                                    ## carries the marker; only the line-head predicate closes the
                                    ## `render ∘ ingest ∘ render` fixed point). A marker-headed
                                    ## line takes NO per-segment markers; mid-line marker bytes
                                    ## stay untouched (the check anchors at the head).
                                    ## THE ALPHABET LAW: the line-head read
                                    ## rides `_isspace_valid` — see the line-grain site's note.
                                    if !((BLS.getElement(crntSegment, :comment) &&
                                          startswith(sl, hide_fold_prefix)) ||
                                         startswith(lstrip(BLS._isspace_valid, lineText), hide_marker))   # RESIDUE outside the door (see the line-grain site)
                                        write(io, hide_marker)
                                    end
                                end
                            end
                            if !repin1_indent_done
                                ## Restore the dropped leading-whitespace ONCE, before the
                                ## first emitted segment's main content.
                                if repin1_indent_start >= 2 && repin1_indent_sidx != 0
                                    write(io, SubString(lineText, 1:prevind(lineText, repin1_indent_start)))
                                end
                                repin1_indent_done = true
                            end
                            write(io, BLS.content(parse_state, crntSegment))   # the segment's byte span through the door
                            wroteToLine = true
                        end
                    end ## END of R-1: "finalVisib != discard" (segment grain)
                end
            else
                ## A suppressed childless line (!includeInOutFile && numChildren == 0)
                ## contributes ZERO bytes — the line terminator below is skipped, so the
                ## line contributes nothing (not exercised by the committed corpus).
                continue
            end
            ## The wroteToLine law (original :140): the terminator fires only if the
            ## line SURVIVED resolution (a surviving EMPTY line counts — its flag is
            ## set without content bytes).
            if wroteToLine
                write(io, "\n")
            end
            end # while `line`
    end # while `block`
    ## Byte-faithful terminal newline. The loop above writes "\n" after every line that
    ## SURVIVED resolution (the wroteToLine terminator law — a discarded line survives
    ## neither as content nor as a newline; a surviving empty line does), so `out` ALWAYS
    ## ends 0x0a whenever anything was emitted. Trim exactly that one trailing 0x0a iff
    ## the PARSED source content did NOT end at a line boundary (`BLS.endsWithNewline(parse_state)`, the door's read
    ## — captured pre-`eachline` at setUpToProcessFromBytes for the whole file, and
    ## COMPLETED by parseBLS for a prefix range, whose last line is terminated by
    ## construction): the render ends 0x0a IFF the parsed content did (one recorded edge:
    ## a whitespace-only TAIL line normalizes to a bare empty line, so its unterminated
    ## form still renders ending 0x0a; pinned in the render-fidelity witnesses). The
    ## `!isempty(out)` guard keeps empty renders untouched.
    out = take!(io)
    if !BLS.endsWithNewline(parse_state) && !isempty(out) && @inbounds(out[end]) == 0x0a
        pop!(out)
    end
    return out
end

#########################################################################################
## THE TREE PRINT — the three functions that write the textual dump of the BLS tree
## (`{:B-Meta:L-Meta [...]}`): `writeBlsStructureToFile`, `writeBlsStructureToIO`,
## `structural_serialization`. They LEFT `src/bls/parseBLS.jl` (its lines 370–528 at code
## commit 86ec5d0) for this development tool on 2026-09-12 (R-V04B-24 B1: they exist only so
## a committed reference can be bytes); every parser name is qualified `BLS.`. ONE destination
## file (this one) is the session's reading under the owner's §18 lean — R-V04B-24 names no
## destination file (recorded in R-V04B-25). The 7 `byte_identical` tree pins
## (tests/golden/MANIFEST.toml) pin `structural_serialization`. The owner's VERY STRONG LEAN
## (OWNER-WORDS §18): re-mint the tree pins to the newer print and delete this dump — a row of
## the keep/cut ledger (R-V04B-24's tidy-up list).
#########################################################################################
function writeBlsStructureToFile(
    state,   # the delivered part `result.blsComponentTree`, read through the door (its Julia type is his open item 5 — not named here)
    pathString::String
)
    ## The file-writing sibling DELEGATES to the IO sibling below since stage 2's commit 0 — one body (before it,
    ## two byte-identical copies kept in step by hand); the file is opened and closed here, as before.
    open(pathString, "w") do blsStructureOutFileIO
        writeBlsStructureToIO(state, blsStructureOutFileIO)
    end
    return nothing
end

## THE ONE BODY of the structure serialization (the file-writing sibling above delegates here). ALL
## handle-writes target the passed `io` — INCLUDING the empty-line DIRECT `write(io, "\n")` that does NOT
## go via `lineBuf` — and it neither opens nor closes `io` (the caller owns it). This function's output is
## pinned by the structure goldens (the 7 tree goldens in tests/golden/MANIFEST.toml). It reads the tree
## THROUGH THE DOOR: `BLS.children` (the insert store's negative ids resolved by BLS itself — the former
## id-sign dispatch of these functions is gone), `BLS.getElement`, `BLS.kind` (the flavor word: `print` of the
## Symbol `:Meta` / `:Code` / `:Text` writes the same bytes the former `nameof(c.contentType)` did) and
## `BLS.content` (a Line's full source line; a Segment's byte span — byte-equal to the former
## `collectedLines` reads, probe-proven over the corpus).
function writeBlsStructureToIO(
    state,   # the delivered part `result.blsComponentTree`, read through the door
    io::IO
)

    local stringIdx::Int
    local newBlock::Bool
    lineBuf = IOBuffer()  # reusable buffer — avoids O(n²) string concat

    for crntBlock in BLS.children(state)
        newBlock = true

        for crntLine in BLS.children(state, crntBlock)
            stringIdx = BLS.getElement(crntLine, :idxString)

            truncate(lineBuf, 0)
            print(lineBuf, "{")
            if newBlock
                print(lineBuf, ":B-", BLS.kind(crntBlock))
            else
                print(lineBuf, "       ")
            end
            print(lineBuf, ":L-", BLS.kind(crntLine), " [")

            if BLS.getElement(crntLine, :includeInOutFile)
                if BLS.getElement(crntLine, :isEmpty)
                    ## Write "Empty Line":
                    write(io, "\n")
                    if stringIdx != 0
                        error("@L: ", @__LINE__, ", file: ", basename(@__FILE__),
                            ":\n\t `crntLine` :isEmpty BUT stringIdx = ", stringIdx, " != 0")
                    end #]
                    continue
                else
                    write(lineBuf, BLS.content(state, crntLine))
                end
            elseif BLS.getElement(crntLine, :numChildren) != 0
                for crntSegment in BLS.children(state, crntLine)
                    if BLS.getElement(crntSegment, :includeInOutFile)
                        print(lineBuf, "{:S-", BLS.kind(crntSegment), " [")
                        write(lineBuf, BLS.content(state, crntSegment))
                        print(lineBuf, "]}")
                    end
                end
            end
            print(lineBuf, "]}\n")
            write(io, take!(lineBuf))
            newBlock = false
        end # for line
    end # for block
end

## The TREE-half observable: the deterministic `{:B-…:L-… […]}` structure dump (the exact
## format the 7 structure goldens pin) as an in-memory byte vector. Thin wrapper over
## `writeBlsStructureToIO`. This is the tree half that the tool's `outputs` (below) returns.
function structural_serialization(state)::Vector{UInt8}
    io = IOBuffer()
    writeBlsStructureToIO(state, io)
    return take!(io)
end

#########################################################################################
## THE PAIR — `outputs(result)`: the Engine's former `GoMeta.outputs` (src/GoMeta.jl:750-785 at
## code commit 86ec5d0) moved here UNCHANGED IN BEHAVIOUR on 2026-09-12 (R-V04B-24 B1: a hard
## removal from the Engine, no stub); the only edits are the THREE qualifications this namespace
## forces (`GoMeta.GoMetaDelivery` in the signature, `GoMeta.PROCESS_ERROR`, the local
## `structural_serialization`) and the docstring's re-scoping. It is `Main.BasicRenderer.outputs` —
## reached ONLY through devtools/load_basic_renderer.jl.

"""
    outputs(result::GoMeta.GoMetaDelivery) -> (blsStructure_bytes::Vector{UInt8}, render_bytes::Vector{UInt8})

The development tool's pair; the Engine's canonical output is `altValues_evals` (docs/public-api.md §1.3). `blsStructure_bytes` is the verdict-free
`structural_serialization` (this module's own function since R-V04B-24) of the final parse tree; `render_bytes` is the jl-share-v1 emit
(docs/CANONICAL-OUTPUT.md). The tree print is a PURE function of `result.blsComponentTree`; the render a PURE function of the
delivery — the tree walked through the door, every Visib verdict the Engine's answer (`GoMeta.answerFor`; stage 3's first commit) —
so this accessor is correct OUTSIDE the per-call `STATE` scope. Total on any OK result (the render plane's string indexing is
character-safe, docs/public-api.md §4, GUARDED); on a non-OK result the contract is
`(empty tree, empty render)` for EVERY current non-OK result (no post-parse error class exists at v0.4; a
"tree-if-parse-succeeded" distinction would be a new contract row) — for the config-time path both are empty, because the
parse never ran. The NamedTuple field order is `(blsStructure_bytes, render_bytes)`.
"""
function outputs(result::GoMeta.GoMetaDelivery)
    ## The non-OK output contract. A fail-closed PROCESS_ERROR GoMetaDelivery — an ENTRY refusal: at v0.3 the
    ## only source was a config-time validation error; at v0.4 the registry DOOR
    ## (`REG_UNPUBLISHED` / `POST_SEAL_MUTATION`) and the seam ledger's refusals of an injected parse state
    ## (`STATE_REUSE_REFUSED` / `STATE_SEAL_MISMATCH`) are the further sources — every one before any absorb
    ## or apply work, `goMeta`'s before its parse — yields an EMPTY (tree, render): "no render attempted",
    ## and the delivered tree is a container built from EMPTY bytes ⇒ an empty tree. `render_bytes` is NOT
    ## invoked (the emit path stays untriggered). No post-parse error class exists at v0.4: this branch
    ## returns two EMPTY vectors unconditionally (a "tree-if-parse-succeeded" distinction would be a new
    ## contract row).
    if result.status === GoMeta.PROCESS_ERROR
        return (blsStructure_bytes = UInt8[], render_bytes = UInt8[])
    end
    ## The hide marker rides the PARSE STATE's own FlavorProfile, never the config —
    ## under a carrier-constructed store (the `run_absorb_apply!` seam) the config
    ## need not name the flavor the store was parsed under; reading the tree's record through the door
    ## (`BLS.flavor(blsComponentTree)`) keeps `outputs` stamping the CORRECT flavor's marker by
    ## construction.
    rendered = let fl = BLS.flavor(result.blsComponentTree)
        render_bytes(result; hide_marker = fl.hide_marker, hide_fold_prefix = fl.hide_fold_prefix)
    end
    tree     = structural_serialization(result.blsComponentTree)
    return (blsStructure_bytes = tree, render_bytes = rendered)
end

end
