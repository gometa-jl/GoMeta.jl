# BLS.jl
module BLS

using InlineStrings
using StaticArrays
include("NamedElements.jl")
using .NamedElements

###############################################################################
NamedElements.@namedElement CmpntNamedInt Int begin
    idComponent
    idParent
    idxString
    inputLineNum
    numChildren
    startMainStr
    stopMainStr
    idExtension    # ID of extension component (0 = none)
    idExtended     # ID of component this extends (0 = not an extension)
end

###############################################################################
NamedElements.@namedElement ComponentSettribute Bool begin
    depth0
    depth1
    depth2
    depth3
    depth4
    depth5
    depth6
    depth7
    depth8
    depth9
    attachedToMeta
    stopAttachmentToMeta
    detachedFromMeta
    ignoreThisMeta
    ignoreMetaContent ## R-INERT-4 (v0.3.1): the AUTHOR's trailing-bang inert marker
                      ## ("#~N!"/"#~!") — the component IS structurally live (walks, closes,
                      ## supersedes, attaches exactly like the bare live marker) and ONLY its
                      ## content after the '!' is ignored (absorbed as EMPTY). Distinct from
                      ## :ignoreThisMeta, which stays the absorb-walk SKIP flag of the other mint
                      ## classes (the "#]" close-marker rows, comment-in-Meta, glued bucket-A).
    hide
    show
    discard
    firstInLine
    firstInBlock
    isSet
    hasExtention
    isExtention
    original
    modified
    inserted
    depricated
    includeInOutFile ## A matching `String` can be written to `outFile`.
    write ## Write to `outFile`, IF `:includeInOutFile` is true.
    comment
    isEmpty
    containsSubComponents
    continued
    insertSubContent
    startNewBlock
    containsCode
    containsMeta
    containsText
    containsEmpty
    isMeta
    isCode
    isText
    md     ## Text-specific
    julia   ## Code-specific
    ## Meta-specific:
    hasMetaStr
end

####################################################################################
abstract type AbstractContentSettribute{T,N} <: NamedElements.NamedElement{T,N} end
###############################################################################
NamedElements.@namedElement Meta Bool begin
    superType = AbstractContentSettribute ## Let Meta <: AbstractContentSettribute
    isSet
    hasExtention
    isExtention
    depth0
    depth1
    depth2
    depth3
    depth4
    depth5
    depth6
    depth7
    depth8
    title
    labels
    id
    goDoc
    comment
end

###############################################################################
NamedElements.@namedElement Code Bool begin
    superType = AbstractContentSettribute ## Let Meta <: AbstractContentSettribute
    isSet
    hasExtention
    isExtention
    julia
    c
    comment
end

###############################################################################
NamedElements.@namedElement Text Bool begin
    superType = AbstractContentSettribute ## Let Meta <: AbstractContentSettribute
    isSet
    hasExtention
    isExtention
    md
    doubleHash
    comment
end

####################################################################################
maxLengthContentSettribute = 0
for pair ∈ NamedElements.moduleToRefOfTuplesPDict[@__MODULE__]
    if length(keys(pair.first)) > maxLengthContentSettribute
        global maxLengthContentSettribute = length(keys(pair.first))
    end
end
maxLengthContentSettribute
####################################################################################
abstract type AbstractComponent end
## Must contain:
## - id
## - range
## - ComponentSettribute
## - ContentSettribute{ContentType} (i.e.: Attribute of "primary" ContentType)
## - Vector{<:crntComponentType}
##      (e.g.: If crntComponent is `Block`, then it contains `Line`(s).
##             If crtnComponent is `Line`, then it contains `Segment`(s))

struct Component{N} <: AbstractComponent where N
    cmpntNamedInt::CmpntNamedInt
    contentType::Type{T} where T<:AbstractContentSettribute
    contentSettributeBitVec::MVector{maxLengthContentSettribute,Bool}
    range::MVector{2,Int}
    componentSettribute::ComponentSettribute
    childComponentsIdxVec::MVector{N,Int}
end

const Segment = Component{1}
const Line = Component{10}
const Block = Component{70}
const File = Component{210}

"""
    capacity(::Component{N}) -> Int
    capacity(::Type{Component{N}}) -> Int

Return the maximum number of children that fit in a single component's
childComponentsIdxVec before an extension is needed. Compile-time constant.
"""
capacity(::Component{N}) where N = N
capacity(::Type{Component{N}}) where N = N
Component{n}() where n = Component{n}(
    ## The following is a hack to (mis-)use Component{n}() when it is the first entry
    ## within a Vector{Component{n}} namely as a counter to keep track how many entries
    ## of Component{n} have been added to Vector{Component{n}}.
    ## This is used while parsing the input file adding entry after entry.
    ## Counter starts at `1` because that´s where this `dummy-Component` is kept.
    CmpntNamedInt(0, :startMainStr => 1),
    Meta,
    MVector{maxLengthContentSettribute,Bool}(ntuple(_->false, Val(maxLengthContentSettribute))),
    ## The following is a hack to (mis-)use Component{n}() when it is the first entry
    ## within a Vector{Component{n}} namely as a counter to keep track how many entries
    ## of Component{n} have been added to Vector{Component{n}}.
    ## This is used while parsing the input file adding entry after entry.
    ## Counter starts at `1` because that´s where this `dummy-Component` is kept.
    MVector{2,Int}(1, 0), # NOTE: Dummy-Component used to count components added.
    ComponentSettribute(),
    MVector{n,Int}(ntuple(_->0, Val(n)))
)

###############################################################################
Component{n}(
    contentType::Type{T} where T<:AbstractContentSettribute,
    parentComponentId::Int,
    keys::Vararg{Symbol}
) where n = begin
    if contentType == Code
        isOfType = :isCode
        containsType = :containsCode
    elseif contentType == Meta
        isOfType = :isMeta
        containsType = :containsMeta
    elseif contentType == Text
        isOfType = :isText
        containsType = :containsText
    else
        error("BLS.jl: Constructing Component not possible:\n",
            "\tprovided `contentType` appears not to match any",
            " of Code, Meta, Text!!")
    end
    Component{n}(
        CmpntNamedInt(0, :idParent => parentComponentId),
        contentType,
        MVector{maxLengthContentSettribute,Bool}(ntuple(_->false, Val(maxLengthContentSettribute))),
        MVector{2,Int}(0, 0),
        ComponentSettribute(isOfType, containsType, keys...),
        MVector{n,Int}(ntuple(_->0, Val(n)))
    )
end

###############################################################################
Component{n}(
    contentType::Type{T} where T<:AbstractContentSettribute,
    parentComponentId::Int,
    thisComponentId::Int,
    keys::Vararg{Symbol}
) where n = begin
    if contentType == Code
        isOfType = :isCode
        containsType = :containsCode
    elseif contentType == Meta
        isOfType = :isMeta
        containsType = :containsMeta
    elseif contentType == Text
        isOfType = :isText
        containsType = :containsText
    else
        error("BLS.jl: Constructing Component not possible:\n",
            "\tprovided `contentType` appears not to match any",
            " of Code, Meta, Text!!")
    end
    Component{n}(
        CmpntNamedInt(0, :idParent => parentComponentId, :idComponent => thisComponentId),
        contentType,
        MVector{maxLengthContentSettribute,Bool}(ntuple(_->false, Val(maxLengthContentSettribute))),
        MVector{2,Int}(0, 0),
        ComponentSettribute(isOfType, containsType, keys...),
        MVector{n,Int}(ntuple(_->0, Val(n)))
    )
end
###############################################################################
#####~ Helper-Fns for `ComponentSettribute`:
const depthLevelsMH =
    (:depth0, :depth1, :depth2, :depth3, :depth4, :depth5, :depth6, :depth7, :depth8)
## The depth window :depth0..:depth8 is ARCHITECTURAL (state.jl's slot map: slots 1-9 carry
## depth 0-8, slot 10 is the user level, 11 the line level, 12 the fallBack level (R-V04B-55 (3)) — a depth-9 slot
## would collide with the user level). This lookup is TOTAL by construction: a slot index or
## the stable refusal — `nothing` can never escape into the Int conversion.
function getGivenDepthMH(crntComponent::Component)::Int
    idxDepth0::Int = findfirst(isequal(:depth0), keys(ComponentSettribute))
    ## NOTE:
    ## Return values STARTING from 1 NOT 0 !!!
    ## This corresponds then to the idx into metaHLevelVecs etc.:
    local idx = findfirst(
        view(crntComponent.componentSettribute.array,
            idxDepth0:(idxDepth0+length(depthLevelsMH)-1))
    ) #- 1
    idx === nothing && error("GoMeta absorb: meta depth out of range — this metaLine's ",
        "depth has no v0 meta-hierarchy slot; v0 supports #~ (depth 1) through #~8, and ",
        "digit 0 = the file level (see docs/public-api.md §3.4)")
    return idx
end
#########################################################################################
## Extension chain child iterator — replaces duplicated traversal loops
#########################################################################################
struct EachChildId{T<:Component}
    root::T
    componentsVec::Vector{T}
end

"""
    eachchildid(component, componentsVec)

Iterate over all child IDs across a component's extension chain.
`componentsVec` is the vector used to follow extension links
(e.g. `componentsPDict[Block][1]`).
"""
eachchildid(component::T, componentsVec::Vector{T}) where T<:Component =
    EachChildId{T}(component, componentsVec)

function Base.iterate(iter::EachChildId{T}, state=(iter.root, 1)) where T
    crnt, idx = state
    while true
        if idx > capacity(crnt)
            extId = getElement(crnt.cmpntNamedInt, :idExtension)
            extId == 0 && return nothing
            crnt = iter.componentsVec[extId]
            idx = 1
            continue
        end
        childId = crnt.childComponentsIdxVec[idx]
        childId == 0 && return nothing
        return (childId, (crnt, idx + 1))
    end
end

Base.IteratorSize(::Type{<:EachChildId}) = Base.SizeUnknown()
Base.eltype(::Type{<:EachChildId}) = Int

#########################################################################################
##~ `parseBlocksAndLines()`
include("flavor.jl")
include("parseBLS.jl")
## The multi-language function-copy fork: a `//`-adapted sibling copy served `:c`
## until the collapse proved the ONE loop + table for both flavors (four-plane
## differentials, both regimes) — then retired; every flavor now rides parseBLS.jl
## over its FlavorProfile record (the table-only law; per-flavor witnesses + the
## standing differential harness are the equivalence guard).

#########################################################################################
## THE DOOR — BLS's own public travel / access functions over the BLS Component tree.
## The BLS Component tree is provided by BLS itself and travelled with BLS's own public
## functions (R-V04B-45); the public surface of every part an absolute minimum (his §18);
## a BLS object stated to be a BLS object (his §48 lean) — every name below is read
## QUALIFIED, `BLS.<name>`; nothing is exported. Each function is marked as an existing
## BLS function ADAPTED or as NEW (R-V04B-48 (2)(c)).
#########################################################################################
public children, parent, kind, content

"""
    children(tree::ParseState, c::Component) -> Vector{<:Component}
    children(tree::ParseState) -> Vector{Block}

IS: BLS's public downward step over the BLS Component tree — the door's walk.
DOES: returns the child Components of `c` in source order (a File's Blocks, a Block's Lines,
a Line's Segments; an empty vector for a Segment); without a Component, the Blocks of the
tree's one File. Follows the extension chain through `eachchildid`; resolves a positive id in
the original store and a negative id in the insert store, so a caller never reads the stores.
REASONING: the legacy's child walk (the March writer's loop over `childComponentsIdxVec`,
`WriteOutFile.jl` :105) as v0.4's `eachchildid` carries it, over the legacy's own map
`parentChildComponentPDict` — ADAPTED, so that an Extension and the development tools walk
down with one function (his §42 3 (ii)) and no store is read outside BLS (his §19).
PURPOSE: the tree provided by BLS itself (R-V04B-45), travelled with BLS's own function.
BOUND: for a tree with no Block (the empty input; an error delivery) `children(tree)` is
empty; `root(tree)` still returns the tree's File Component (the slot setup always writes it).
"""
function children(tree::ParseState, c::T) where T<:Component
    T === Segment && return Segment[]
    C = parentChildComponentPDict[T]
    stores = tree.componentsPDict[C]
    out = C[]
    for id in eachchildid(c, tree.componentsPDict[T][1])
        push!(out, id > 0 ? stores[1][id] : stores[2][-id])
    end
    return out
end
children(tree::ParseState) = children(tree, tree.componentsPDict[File][1][1])

"""
    parent(tree::ParseState, c::Component) -> Union{Component,Nothing}

IS: BLS's public upward step — the door's walk to the parent.
DOES: returns a Segment's Line, a Line's Block, a Block's File; `nothing` for the File. Reads
`:idParent` in the ORIGINAL store, as `getParentComponent` does (the insert store's parents
are the clutter census's question, R-V04B-49).
REASONING: ADAPTED — the legacy `getParentComponent` (the March `parseBLS.jl` :55, one method
with a type ladder; v0.4's three per-grain methods `parseBLS.jl` :121–:129) under the door's
name, its read unchanged. The name `parent` also belongs to Julia's `Base` (over arrays and
views): this function is read qualified, `BLS.parent`, and adds no method to `Base.parent`;
inside module BLS an unqualified `parent(x)` now binds to this function — the alternative,
publishing `getParentComponent` itself, is his to choose.
PURPOSE: the upward walk an Extension and the tools make today through `:idParent` reads.
"""
parent(tree::ParseState, c::Union{Segment,Line,Block}) = getParentComponent(tree, c)
parent(::ParseState, ::File) = nothing

"""
    kind(c::Component) -> Union{Symbol,Nothing}

IS: the Component's flavor in the canon's sense — `:Meta`, `:Code` or `:Text` (a metaLine is
"a BLS Line Component of flavor Meta"); NOT its grain (the grain is the Component's type —
File, Block, Line, Segment — reached by dispatch).
DOES: reads the field `contentType` the parser set (the legacy's content types `Meta`, `Code`,
`Text`) and answers its name; `nothing` for the File, whose field carries the store's
constructor default, never a parsed flavor. Inside an open fence a content Line's
`contentType` is the Block's (`parseBLS.jl` :998–:1002); a lead-led line there is classified
by its lead (:985), and the settribute flags `:isMeta` / `:isCode` / `:isText` may then
differ from the field — this function answers the field, not the flags.
REASONING: NEW — a field read given a name, so that no Extension reads a field of a BLS
object; a Symbol, not the type, so that no type of BLS becomes public for it (his §18).
(The word "flavor" also names the comment-lead record `FlavorProfile` in this code — a
second sense of the word, NOTED for his word.)
PURPOSE: an Extension's routing by flavor (his July words: a metaComponent's content to the
metadata parser; text or code otherwise).
"""
kind(c::Union{Segment,Line,Block})::Symbol = nameof(c.contentType)
kind(::File) = nothing

"""
    content(tree::ParseState, c::AbstractComponent) -> Vector{UInt8}

IS: the VERBATIM content bytes of a Component at its own grain — BLS's public read of a
piece's text (R-V04B-43 (1): "it is read from the BLS Component tree through BLS's own
access function").
DOES: a Block — its line span joined by '\n'; a Line — its full source line; a Segment —
its byte span of its own line (a multibyte final character kept whole); EMPTY for a
Component that addresses no content (a zero or out-of-range span; a zero-length Line — a
whitespace-only Line returns its whitespace bytes; the File — whose whole text is the ONE-ARGUMENT
`content(tree)` below, his word of 2026-10-05, R-V04B-116 (3)(b)). The empty return is also the
Engine's capture predicate (`captureEvals!` skips an empty return), which is why the File's text is
a method this two-argument form does not reach: the captured population is unchanged.
REASONING: NEW in BLS at stage 2's commit 0 — the body of the Engine's former `cell_content_bytes`
(`src/annotations.jl`) COPIED unchanged but for the argument names and the dropped `BLS.` qualifiers;
the Engine's copy LEFT at stage 2's commit 9b (R-V04B-43 (5)) — this function alone serves a piece's text:
the capture predicate, the test layer's derivation of the reference files' fifth column (byte-equal to the
former producer's — the probe's check and commit 8's standing proof), the tools and the consumers. Its ancestor: the legacy writer's `SubString(collectedLines[stringIdx],
start:stop)` (`WriteOutFile.jl` :129–:134).
PURPOSE: a piece's text for an Extension (the notebook Extension's join, the demo) and for
the renderer, from the tree and nothing else.
"""
function content(tree::ParseState, c::AbstractComponent)
    cni       = c.cmpntNamedInt
    startMain = getElement(cni, :startMainStr)
    stopMain  = getElement(cni, :stopMainStr)
    if c isa Block
        # Block: the span is a LINE-NUMBER range into collectedLines. Block bounds are COMPLETE
        # when the parse returns (the parse-side CLOSURE law closes the final Block at the
        # effective parsed end), so an unfinalized 0 bound addresses NO content (fail-CLOSED via
        # the range guard below) — never expanded to EOF: excluded lines cannot leak in here.
        stop = stopMain
        (1 <= startMain && startMain <= stop && stop <= length(tree.collectedLines)) || return UInt8[]
        return Vector{UInt8}(codeunits(join(view(tree.collectedLines, startMain:stop), '\n')))
    elseif c isa Line
        # Line: the FULL source line. A NEGATIVE idxString is an INSERTED Line — its content lives in the
        # addedStrings insert-store (symmetric with the Segment branch). Otherwise the source line via
        # :inputLineNum (robust for multi-segment lines where idxString == 0, where idxString cannot locate it).
        idxString = getElement(cni, :idxString)
        if idxString < 0
            (-length(tree.addedStrings) <= idxString < 0) || return UInt8[]   # the lower bound closes typemin(Int): -typemin(Int) wraps (R-V04B-80 (2)(iv))
            return Vector{UInt8}(codeunits(tree.addedStrings[-idxString]))
        end
        iln = getElement(cni, :inputLineNum)
        (1 <= iln <= length(tree.collectedLines)) || return UInt8[]
        return Vector{UInt8}(codeunits(tree.collectedLines[iln]))
    end
    # Segment (and any other grain): a byte-offset span into its own source line.
    idxString = getElement(cni, :idxString)
    (idxString != 0 && 1 <= startMain && startMain <= stopMain) || return UInt8[]
    # bounds-guard the store lookup so a malformed idxString returns UInt8[] (the docstring's total-return
    # contract), never a BoundsError.
    inbounds = idxString > 0 ? idxString <= length(tree.collectedLines) : -length(tree.addedStrings) <= idxString < 0   # the lower bound closes typemin(Int) (R-V04B-80 (2)(iv))
    inbounds || return UInt8[]
    src = idxString > 0 ? tree.collectedLines[idxString] : tree.addedStrings[-idxString]
    cu  = codeunits(src)
    stopMain <= length(cu) || return UInt8[]
    # stopMain is the final character's START byte (IV-1); widen to its LAST byte so a
    # multibyte final character is kept whole (raw codeunit ranges do not widen the way
    # String ranges do). nextind is total from any in-bounds byte index, malformed included.
    return Vector{UInt8}(cu[startMain:(nextind(src, stopMain) - 1)])
end

"""
    content(tree::ParseState) -> Vector{UInt8}

IS: the text of the whole document as BLS holds it — the collected source lines joined by '\n' — the File's
content as BLS's public read (his word of 2026-10-05, OWNER-WORDS §333; R-V04B-116 (3)(b); stage 5's s5c8 of
the v0.4 build). Not the input's bytes: the line split drops the terminal newline (`endsWithNewline(tree)`
carries that fact) and a CRLF line end's CR.
DOES: the collected source lines joined by '\n', as bytes — exactly the text the development tools joined
outside the door before this commit.
REASONING: a ONE-ARGUMENT method, not a `(tree, ::File)` arm of the two-argument `content`: that form's
empty return for a File is the Engine's capture predicate (`captureEvals!`, src/annotations.jl), so an arm
there would change which Components are captured — the File's text is read here, the predicate untouched.
PURPOSE: the development tools' whole-document read (the tree print's File row, the excerpts) and an
Extension's, through the door and nothing else — one of the last two reads outside the door left with it.
"""
content(tree::ParseState)::Vector{UInt8} = Vector{UInt8}(codeunits(join(tree.collectedLines, '\n')))

#########################################################################################
## THE DOOR, continued — what the development tools read beyond the four functions above
## (his §42 3 (ii): the same few functions and data containers ALSO used by the development
## tools): three reads given a name (NEW) and seven existing names DECLARED public as they
## are (ADAPTED: a declaration, no code).
#########################################################################################
public root, flavor, endsWithNewline, isHorizontalSpace
public getElement, File, Block, Line, Segment, ComponentSettribute, CmpntNamedInt

"""
    root(tree::ParseState) -> File

IS: the tree's one File Component — the root every walk starts from.
DOES: returns `componentsPDict[File][1][1]` — the slot setup always writes, a tree with no
Block included.
REASONING: NEW — the store read every consumer repeats today (the renderer, the tools, the
Engine, the tests) given a name, so that the store is read nowhere outside BLS.
PURPOSE: the File itself (its own rows at the file level; the print tools' File line).
"""
root(tree::ParseState)::File = tree.componentsPDict[File][1][1]

"""
    flavor(tree::ParseState) -> FlavorProfile

IS: the document's flavor record — the comment lead, the hide marker and its fold prefix the
renderer stamps, the flavor tag (`FlavorProfile`, `flavor.jl`; the type stays internal — a
caller reads the record's fields). THE PROMISE (R-V04B-80 (2)(ii)): of the record's fields FIVE are the
public contract — `lead`, `hide_marker`, `hide_fold_prefix`, `flavor_tag`, `re_meta_leaded` (the fields the
renderer and the print tools read); every other field — `directives` first, the parser's table — is reachable but NOT
part of the contract (the `parse_header!` pointer the earlier text named first left at stage 5's P1 of the v0.4 build — census
row 63): the record's remaining shape is open to his BLS review.
DOES: returns the field `tree.flavor`.
REASONING: NEW — the field read given a name (the renderer's `outputs`; the tools'
`flavor_tag`). The name is the field's; the canon's word "flavor" for Meta/Code/Text is
`kind`'s sense — NOTED for his word.
PURPOSE: the render's markers and the tools' flavor tag from the tree, not from the
configuration.
"""
flavor(tree::ParseState)::FlavorProfile = tree.flavor

"""
    endsWithNewline(tree::ParseState) -> Bool

IS: whether the parsed source ended with a terminal newline.
DOES: returns the field `tree.endsWithNewline`.
REASONING: NEW — the field read given a name; the renderer needs it to end its output as
the input ended (byte-faithful).
PURPOSE: the render's terminal-newline law from the tree.
"""
endsWithNewline(tree::ParseState)::Bool = tree.endsWithNewline

"""
    getElement(c::AbstractComponent, key::Symbol) -> Union{Int,Bool}

IS: the door's read of ONE named element of a Component — a settribute flag (Bool) or a named integer (Int) — by its key.
DOES: dispatches on the key to the Component's container: a key of `CmpntNamedInt` reads `c.cmpntNamedInt`, any other key reads
`c.componentSettribute` (the two key sets are disjoint; an unknown key fails loud in the container's own lookup).
REASONING: ADAPTED — a dispatch over the existing container reads (the methods the macro of `NamedElements.jl` generates take the
container), so that a caller through the door never reads a FIELD of a BLS object (`c.cmpntNamedInt`, `c.componentSettribute` stay
internal) — R-V04B-80 (2)(i).
PURPOSE: every flag and position read of the renderer, the print tools and the tests, through the door alone.
"""
getElement(c::AbstractComponent, key::Symbol) = key in keys(CmpntNamedInt) ? getElement(c.cmpntNamedInt, key) : getElement(c.componentSettribute, key)

"""
    isHorizontalSpace(c::Char) -> Bool

IS: the parser's own horizontal-whitespace classification of one character — the `[\\h]` class the metaLine grammar uses.
DOES: returns `_is_h_ws(c)` (flavor.jl) — true for the space, the tab, the NBSP and the other horizontal spaces the parser delimits
tokens by; false for a newline and for content.
REASONING: ADAPTED — the parser's predicate given a public name, so that the print tools' segment lexer tests whitespace exactly as the
parser does (a copy in a tool could drift from the parser's classification; R-V04B-80 (2)(iii)); the name is the
session's default — declaring `_is_h_ws` public as it is is the alternative, his to pick.
PURPOSE: the print tools' lexer (the one read beyond the tree the tools make of the parser) and, since stage 5's s5c8,
the renderer's whitespace guard before the hide marker (R-V04B-116 (3)(a)), through the door.
"""
isHorizontalSpace(c::Char)::Bool = _is_h_ws(c)

end
