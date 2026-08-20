# parseBLS.jl — the vendored Block-Line-Segment (BLS) parser: raw bytes in, component tree out.
#
# IS: the parse stage of the GoMeta pipeline, included by BLS.jl into the vendored `BLS`
#   module. It holds `ParseState` — all mutable state of one parse session: the collected
#   input lines, the per-type component stores, and the `endsWithNewline` terminal-newline
#   fact — plus the functions that build and serialize the File → Block → Line → Segment
#   hierarchy (`parentChildComponentPDict` fixes that parent→child mapping).
# DOES: `setUpToProcessFromBytes(bytes)` is the sole setup entry — file-free (an in-memory
#   IOBuffer), reentrancy-safe (it sets no module globals), sizes the component stores from
#   the line count, and captures whether the raw bytes end in a newline BEFORE `eachline`
#   discards terminators, so the emit layer can render byte-faithfully. Line ENDINGS
#   normalize CRLF→LF; content bytes stay faithful (docs/CANONICAL-OUTPUT.md §6).
#   `parseBLS(state)` runs the line loop: empty lines; ```-fences (md or untagged → Text,
#   julia/jl → Code, an unknown tag → generic Code); `#`-headers via `parseHashHeader!` —
#   whitespace→Text, `~`→metaLine (depth digit, trailing-`!` ignore), `##`→comment,
#   `-`/`[`/`]` block boundaries, `+`/`>` directives; an unrecognized form is a plain
#   comment, never a metaLine (of its branches only `~` sets `:hasMetaStr`). Children are
#   added via `addChildComponentTo`; fixed per-type child capacities overflow into
#   extension chains (`createExtensionFor`, `getLastInExtensionChain`); store growth is
#   normal. Content flags propagate
#   child→parent→file; the return is the component-store dict plus a config dict (the
#   first-metaLine index, when one exists). `structural_serialization(state)` (over
#   `writeBlsStructureToIO`; file-writing twin `writeBlsStructureToFile`) emits the
#   deterministic `{:B-… :L-… […]}` structure dump — the verdict-free tree half of
#   `outputs` (docs/CANONICAL-OUTPUT.md §2).
# REASONING: the tree half is pinned byte-for-byte by tests/golden/golden_tests.jl, so the
#   parse must be a pure, deterministic function of the input bytes — setup and parse touch
#   no filesystem and no module globals; all state threads through the explicit `ParseState`.
# PURPOSE: one deterministic parse substrate under GoMeta's absorb/apply/emit stages.
# Honest edges: `insertChildComponentAt` and each store's second (insert) vector are
#   unexercised by any v0 input (a documented latent path); this file's own internal
#   `error()` messages keep their existing forms — they are not part of the typed-diagnostic
#   catalogue (docs/public-api.md §3).
#########################################################################################
mutable struct ParseState
    collectedLines::Vector{String}
    componentsPDict::Base.PersistentDict{
        Type{<:Component},NTuple{2,Vector{<:AbstractComponent}}}
    addedStrings::Vector{String}
    ## Whether the PARSED source content ends with a terminal newline (0x0a). IS: a Bool captured at
    ## setup from the raw bytes' FINAL byte, BEFORE `eachline` (keep=false) discards every line
    ## terminator — then COMPLETED by `parseBLS` for a PREFIX range: a `toLine` stopping BEFORE
    ## the last source line ends at a line BOUNDARY by construction (the following lines exist), so
    ## the parser sets it true; whole-file parses keep the setup-captured value untouched. DOES:
    ## `render_bytes` (emit.jl) reads it to decide whether to keep or trim the emit buffer's
    ## unconditional trailing 0x0a, so the render is byte-faithful to the terminal newline of what
    ## was PARSED. REASONING: parse drops the fact and emit re-fabricates one terminator per emitted
    ## line; output ends 0x0a IFF input ends 0x0a — held range-faithfully. PURPOSE: byte-faithful
    ## terminal-newline rendering without touching per-line emit semantics.
    endsWithNewline::Bool
    ## The document's FlavorProfile record, populated at setup (the `flavor` kwarg
    ## below, default FLAVOR_JULIA — zero call-site churn) and read by the parse
    ## loop (hoisted once at `parseBLS` entry) and the downstream flavor consumers
    ## (the walk's introducer regex; the outputs hide-marker pair).
    flavor::FlavorProfile
end

## All mutable parse state threads through the explicit `state::ParseState` — this module keeps NO
## parse globals, and `setUpToProcessFromBytes` below is the sole setup entry (there is no
## file-based setup path and no reentrancy-unsafe module state here).

## The bytes-path setup — file-free + byte-faithful on non-UTF8 input (reads an in-memory
## `IOBuffer(bytes)`) + reentrancy-safe (sets NO module globals). Thread the returned state
## explicitly: `parseBLS(state, …)`. The store-capacity construction (incl. the `max(1, …)` floors)
## is byte-exact-verified against the golden corpus (tests/golden/golden_tests.jl).
function setUpToProcessFromBytes(
    bytes::Vector{UInt8};
    ## The flavor channel: a kwarg with the Julia default keeps every '#'-flavor
    ## call site byte-identical; `goMeta` passes the once-resolved profile, so a
    ## `:c` state carries FLAVOR_CFAM.
    flavor::FlavorProfile = FLAVOR_JULIA
)::ParseState

    lines = collect(eachline(IOBuffer(bytes)))
    ## Capture the terminal-newline fact from the RAW bytes BEFORE `eachline` (keep=false, above)
    ## discards it. The whole-file source ends 0x0a iff its LAST byte is 0x0a (empty input ⇒ false;
    ## there is no terminator to keep). `render_bytes` trims its unconditional trailing 0x0a iff this
    ## is false, making the render byte-faithful to the terminal newline.
    ends_nl = !isempty(bytes) && @inbounds(bytes[end]) == 0x0a
    numOfLines = length(lines)
    pDict = Base.PersistentDict{
        Type{<:Component},
        NTuple{2,Vector{<:AbstractComponent}}}(
        File => (
            Vector{File}(undef, 2),
            Vector{File}(undef, 1),
        ),
        Block => (
            Vector{Block}(undef, numOfLines ÷ 2 + 1),
            Vector{Block}(undef, max(1, round(Int, (numOfLines ÷ 5) * 0.3))),
        ),
        Line => (
            Vector{Line}(undef, numOfLines + 1),
            Vector{Line}(undef, max(1, round(Int, numOfLines * 0.3)))
        ),
        Segment => (
            Vector{Segment}(undef, max(1, round(Int, numOfLines * 2.5))),
            Vector{Segment}(undef, max(1, round(Int, round(numOfLines * 2.5) * 0.3)))
        )
    )
    for (_, value) ∈ pDict
        value[1][1] = eltype(value[1])()
        value[2][1] = eltype(value[2])()
    end
    return ParseState(lines, pDict, String[], ends_nl, flavor)
end
const orderedComponentTypesNamedT = NamedTuple{
    (:noMetaEnvYet, :Segment, :Line, :Block, :File),NTuple{5,Int}}((1:5))

const parentChildComponentPDict = Base.PersistentDict{
    Type{<:Component},
    Type{<:Component}}(
    File => Block,
    Block => Line,
    Line => Segment
)
parentChildComponentPDict[File]

#########################################################################################
function getParentComponent(state::ParseState, c::Segment)
    state.componentsPDict[Line][1][getElement(c.cmpntNamedInt, :idParent)]
end
function getParentComponent(state::ParseState, c::Line)
    state.componentsPDict[Block][1][getElement(c.cmpntNamedInt, :idParent)]
end
function getParentComponent(state::ParseState, c::Block)
    state.componentsPDict[File][1][getElement(c.cmpntNamedInt, :idParent)]
end
#########################################################################################
## Extension chain helpers for dynamic overflow of childComponentsIdxVec
#########################################################################################
function getLastInExtensionChain(
    state::ParseState,
    component::T
)::T where T<:Component
    crnt = component
    while (extId = getElement(crnt.cmpntNamedInt, :idExtension)) != 0
        crnt = state.componentsPDict[typeof(crnt)][1][extId]
    end
    return crnt
end

function createExtensionFor(
    state::ParseState,
    component::T
)::T where T<:Component
    ParentType = typeof(component)
    componentsVec = state.componentsPDict[ParentType][1]

    extId = addToElement(componentsVec[1].cmpntNamedInt, :startMainStr, 1)
    parentId = getElement(component.cmpntNamedInt, :idParent)
    componentId = getElement(component.cmpntNamedInt, :idComponent)

    if extId <= length(componentsVec)
        componentsVec[extId] = ParentType(
            component.contentType,
            parentId,
            extId,
            :isExtention)
    else
        push!(componentsVec,
            ParentType(
                component.contentType,
                parentId,
                extId,
                :isExtention))
    end
    setElement(componentsVec[extId].cmpntNamedInt, :idExtended => componentId)
    setElement(component.cmpntNamedInt, :idExtension => extId)
    setElement(component.componentSettribute, :hasExtention => true)

    return componentsVec[extId]
end

function getAllChildIds(state::ParseState, component::T)::Vector{Int} where T<:Component
    ids = Int[]
    sizehint!(ids, getElement(component.cmpntNamedInt, :numChildren))
    for id in eachchildid(component, state.componentsPDict[typeof(component)][1])
        push!(ids, id)
    end
    return ids
end

#########################################################################################
function addChildComponentTo(
    state::ParseState,
    parentComponent::T,
    inputLineNum::Int,
    contentType::Type{S} where S<:AbstractContentSettribute,
    contentSettributeKeys::Vararg{Symbol}) where T<:Component

    ## (thisFnName used only in error messages — inlined there now)
    ## 1.: Get `ChildComponentType` of `parentComponent`:
    ##      File => Block, Block => Line, Line => Segment; Segment can't have "Children".
    ChildComponentType::Type{<:Component} =
        parentChildComponentPDict[typeof(parentComponent)]
    ## 2.: Use `ChildComponentType` to access vector containing Children
    ##      constructed based on "inFile" i.e.: `:original`, NOT `:modified`, `:inserted`.
    childComponentsVec::Vector{ChildComponentType} =
        state.componentsPDict[ChildComponentType][1]

    #################################################################
    ## !!! NOTE !!! `childComponentsVec[1]` is the DUMMY-Component
    ##      It's `:startMainStr` COUNTS the Number of Components of
    ##      current Type e.g.: Number of Blocks, Lines, Segments.
    ## Dummy-Child-Component: First component of each `componentsVec` is,
    ## among other things, used to record the number of entries in this vec.
    childId = addToElement( ## i.e.: do "+= 1" to `cmpntNamedInt[:startMainStr]`
        childComponentsVec[1].cmpntNamedInt, :startMainStr, 1)
    if childId <= length(childComponentsVec)
        childComponentsVec[childId] = ChildComponentType(
            contentType,
            getElement(parentComponent.cmpntNamedInt, :idComponent),
            childId, # `:idComponent` of this CHILD (above is of PARENT)
            contentSettributeKeys...)
        setElement(
            childComponentsVec[childId].cmpntNamedInt, :inputLineNum => inputLineNum)
    else
        push!(childComponentsVec,
            ChildComponentType(
                contentType,
                getElement(parentComponent.cmpntNamedInt, :idComponent),
                childId, # `:idComponent` of this CHILD (above is of PARENT)
                contentSettributeKeys...)
        )
        setElement(
            childComponentsVec[childId].cmpntNamedInt, :inputLineNum => inputLineNum)
    end

    ## Increase `:numChildren` by 1 on the ORIGINAL parent (tracks TOTAL):
    totalChildren = addToElement(parentComponent.cmpntNamedInt, :numChildren, 1)
    N_capacity = capacity(parentComponent)

    if totalChildren <= N_capacity
        ## Normal case: fits in the original component
        parentComponent.childComponentsIdxVec[totalChildren] = childId
    else
        ## Overflow: use or create an extension
        lastExt = getLastInExtensionChain(state, parentComponent)
        localCount = getElement(lastExt.cmpntNamedInt, :numChildren)
        extCapacity = capacity(lastExt)

        if localCount >= extCapacity
            lastExt = createExtensionFor(state, lastExt)
        end
        localIdx = addToElement(lastExt.cmpntNamedInt, :numChildren, 1)
        lastExt.childComponentsIdxVec[localIdx] = childId
    end

    return childId, childComponentsVec[childId]
end

#########################################################################################
function insertChildComponentAt(
    state::ParseState,
    parentComponent::T,
    inputLineNum::Int,
    contentType::Type{S} where S<:AbstractContentSettribute,
    insertAt::Int,
    contentSettributeKeys::Vararg{Symbol}) where T<:Component

    ## (thisFnName used only in error messages — inlined there now)

    if T == Line &&
       !getElement(parentComponent.componentSettribute, :containsSubComponents)
        ## !!! NOTE !!! Setting: `:containsSubComponents` => true
        ##       ensures that we break an otherwise endless loop (calling
        ##       `insertChildComponentAt()` over and over again.)
        setElement(parentComponent.componentSettribute, :containsSubComponents => true)
        (_, tmpSegment) = insertChildComponentAt(
            state,
            parentComponent,
            inputLineNum,
            contentType,
            1
        )
        setElement(
            tmpSegment.cmpntNamedInt,
            :startMainStr => getElement(
                parentComponent.cmpntNamedInt, :startMainStr),
            :stopMainStr => getElement(
                parentComponent.cmpntNamedInt, :stopMainStr))
    end

    ## 1.: Get `ChildComponentType` of `parentComponent`:
    ##      File => Block, Block => Line, Line => Segment; Segment can't have "Children".
    ChildComponentType::Type{<:Component} =
        parentChildComponentPDict[T]
    ## 2.: Use `ChildComponentType` to access vector containing Children
    ##      constructed based on "inFile" i.e.: `:original`, NOT `:modified`, `:inserted`.
    childComponentsVec::Vector{ChildComponentType} =
    ## NOTE: Here access `childComponentVector[2]` opposed to `1` as for
    ##       `addChildComponentTo(...)`
        state.componentsPDict[ChildComponentType][2]

    #################################################################
    ## !!! NOTE !!! `childComponentsVec[1]` is the DUMMY-Component
    ##      It's `:startMainStr` COUNTS the Number of Components of
    ##      current Type e.g.: Number of Blocks, Lines, Segments.
    ## Dummy-Child-Component: First component of each `componentsVec` is,
    ## among other things, used to record the number of entries in this vec.
    childId = addToElement(
        childComponentsVec[1].cmpntNamedInt, :startMainStr, 1)
    if childId <= length(childComponentsVec)
        childComponentsVec[childId] = ChildComponentType(
            contentType,
            getElement(parentComponent.cmpntNamedInt, :idComponent),
            childId, # `:idComponent` of this CHILD (above is of PARENT)
            contentSettributeKeys...)
    else
        push!(childComponentsVec,
            ChildComponentType(
                contentType,
                getElement(parentComponent.cmpntNamedInt, :idComponent),
                childId,
                contentSettributeKeys...))
    end
    setElement(
        childComponentsVec[childId].cmpntNamedInt, :inputLineNum => inputLineNum)

    ## Collect all existing child IDs across extension chain, insert, write back:
    existingIds = getAllChildIds(state, parentComponent)
    if 1 <= insertAt <= length(existingIds) + 1
        insert!(existingIds, insertAt, -childId)
    else
        printstyled("\n !!! ERROR !!! line: ", @__LINE__,
            ", file: ", basename(@__FILE__),
            "\n\t T = ", T, ", insertChildComponentAt:",
            "\n\t Can't insert `childComponent` at: ", insertAt, ".",
            "\n\t existingIds = ", existingIds, "\n";
            color=:red, bold=true)
        error("See message above ;-) ") #]
    end

    ## Write back into the extension chain, creating extensions as needed:
    crntComp = parentComponent
    writeIdx = 1
    for (i, id) in enumerate(existingIds)
        if writeIdx > capacity(crntComp)
            ## Current component full, need extension
            extId = getElement(crntComp.cmpntNamedInt, :idExtension)
            if extId != 0
                crntComp = state.componentsPDict[typeof(parentComponent)][1][extId]
            else
                crntComp = createExtensionFor(state, crntComp)
            end
            writeIdx = 1
        end
        crntComp.childComponentsIdxVec[writeIdx] = id
        writeIdx += 1
    end
    ## Zero out remaining slots in the last component of the chain
    while writeIdx <= capacity(crntComp)
        crntComp.childComponentsIdxVec[writeIdx] = 0
        writeIdx += 1
    end

    ## Update numChildren on parent to reflect the insertion
    addToElement(parentComponent.cmpntNamedInt, :numChildren, 1)

    for keyWord ∈ [:containsMeta, :containsText, :containsCode]
        if getElement(childComponentsVec[childId], keyWord)
            setElement(parentComponent.componentSettribute, keyWord => true)
        end
    end

    return childId, childComponentsVec[childId]
end

#########################################################################################
function writeBlsStructureToFile(
    state::ParseState,
    pathString::String
)

    blsStructureOutFileIO = open(pathString, "w")

    local oneOrTwoInt::Int
    local stringIdx::Int
    local crntLine::Line
    local crntBlock::Block
    local crntSegment::Segment
    local newBlock::Bool
    lineBuf = IOBuffer()  # reusable buffer — avoids O(n²) string concat
    ## First `fileComponent` of first `fileVector`:
    ## "componentsPDict[File][1][1]"
    crntFile::File = state.componentsPDict[File][1][1]
    fileVec = state.componentsPDict[File][1]
    blockVecs = state.componentsPDict[Block]
    lineVecs = state.componentsPDict[Line]
    segmentVecs = state.componentsPDict[Segment]

    for blockId in eachchildid(crntFile, fileVec)
        newBlock = true
        blockId > 0 ? oneOrTwoInt = 1 : (oneOrTwoInt = 2; blockId *= -1)
        crntBlock = blockVecs[oneOrTwoInt][blockId]

        for lineId in eachchildid(crntBlock, blockVecs[1])
            lineId > 0 ? oneOrTwoInt = 1 : (oneOrTwoInt = 2; lineId *= -1)
            crntLine = lineVecs[oneOrTwoInt][lineId]
            stringIdx = getElement(crntLine.cmpntNamedInt, :idxString)

            truncate(lineBuf, 0)
            print(lineBuf, "{")
            if newBlock
                print(lineBuf, ":B-", nameof(crntBlock.contentType))
            else
                print(lineBuf, "       ")
            end
            print(lineBuf, ":L-", nameof(crntLine.contentType), " [")

            if getElement(crntLine.componentSettribute, :includeInOutFile)
                if getElement(crntLine.componentSettribute, :isEmpty)
                    ## Write "Empty Line":
                    write(blsStructureOutFileIO, "\n")
                    if stringIdx != 0
                        error("@L: ", @__LINE__, ", file: ", basename(@__FILE__),
                            ":\n\t `crntLine` :isEmpty BUT stringIdx = ", stringIdx, " != 0")
                    end #]
                    continue
                else
                    print(lineBuf, state.collectedLines[stringIdx])
                end
            elseif getElement(crntLine.cmpntNamedInt, :numChildren) != 0
                for segmentId in eachchildid(crntLine, lineVecs[1])
                    segmentId > 0 ? oneOrTwoInt = 1 : oneOrTwoInt = 2
                    crntSegment = segmentVecs[oneOrTwoInt][segmentId]
                    stringIdx = getElement(crntSegment.cmpntNamedInt, :idxString)
                    if getElement(crntSegment.componentSettribute, :includeInOutFile)
                        print(lineBuf, "{:S-", nameof(crntSegment.contentType), " [",
                            SubString(state.collectedLines[stringIdx],
                                getElement(crntSegment.cmpntNamedInt, :startMainStr):
                                getElement(crntSegment.cmpntNamedInt, :stopMainStr)),
                            "]}")
                    end
                end
            end
            print(lineBuf, "]}\n")
            write(blsStructureOutFileIO, take!(lineBuf))
            newBlock = false
        end # for line
    end # for block
    close(blsStructureOutFileIO)
end

## ADDITIVE IN-MEMORY SIBLING of `writeBlsStructureToFile`. Byte-identical
## structure serialization, but ALL handle-writes target the passed `io` — INCLUDING the empty-line
## DIRECT `write(io, "\n")` that does NOT go via `lineBuf` — and it neither opens nor closes `io`
## (the caller owns it). This sibling's output is pinned by the structure goldens (the 7 tree
## goldens in tests/golden/MANIFEST.toml).
function writeBlsStructureToIO(
    state::ParseState,
    io::IO
)

    local oneOrTwoInt::Int
    local stringIdx::Int
    local crntLine::Line
    local crntBlock::Block
    local crntSegment::Segment
    local newBlock::Bool
    lineBuf = IOBuffer()  # reusable buffer — avoids O(n²) string concat
    crntFile::File = state.componentsPDict[File][1][1]
    fileVec = state.componentsPDict[File][1]
    blockVecs = state.componentsPDict[Block]
    lineVecs = state.componentsPDict[Line]
    segmentVecs = state.componentsPDict[Segment]

    for blockId in eachchildid(crntFile, fileVec)
        newBlock = true
        blockId > 0 ? oneOrTwoInt = 1 : (oneOrTwoInt = 2; blockId *= -1)
        crntBlock = blockVecs[oneOrTwoInt][blockId]

        for lineId in eachchildid(crntBlock, blockVecs[1])
            lineId > 0 ? oneOrTwoInt = 1 : (oneOrTwoInt = 2; lineId *= -1)
            crntLine = lineVecs[oneOrTwoInt][lineId]
            stringIdx = getElement(crntLine.cmpntNamedInt, :idxString)

            truncate(lineBuf, 0)
            print(lineBuf, "{")
            if newBlock
                print(lineBuf, ":B-", nameof(crntBlock.contentType))
            else
                print(lineBuf, "       ")
            end
            print(lineBuf, ":L-", nameof(crntLine.contentType), " [")

            if getElement(crntLine.componentSettribute, :includeInOutFile)
                if getElement(crntLine.componentSettribute, :isEmpty)
                    ## Write "Empty Line":
                    write(io, "\n")
                    if stringIdx != 0
                        error("@L: ", @__LINE__, ", file: ", basename(@__FILE__),
                            ":\n\t `crntLine` :isEmpty BUT stringIdx = ", stringIdx, " != 0")
                    end #]
                    continue
                else
                    print(lineBuf, state.collectedLines[stringIdx])
                end
            elseif getElement(crntLine.cmpntNamedInt, :numChildren) != 0
                for segmentId in eachchildid(crntLine, lineVecs[1])
                    segmentId > 0 ? oneOrTwoInt = 1 : oneOrTwoInt = 2
                    crntSegment = segmentVecs[oneOrTwoInt][segmentId]
                    stringIdx = getElement(crntSegment.cmpntNamedInt, :idxString)
                    if getElement(crntSegment.componentSettribute, :includeInOutFile)
                        print(lineBuf, "{:S-", nameof(crntSegment.contentType), " [",
                            SubString(state.collectedLines[stringIdx],
                                getElement(crntSegment.cmpntNamedInt, :startMainStr):
                                getElement(crntSegment.cmpntNamedInt, :stopMainStr)),
                            "]}")
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
## `writeBlsStructureToIO`. This is the tree half that `GoMeta.outputs` returns.
function structural_serialization(state::ParseState)::Vector{UInt8}
    io = IOBuffer()
    writeBlsStructureToIO(state, io)
    return take!(io)
end

####################################################################################
## Character-based findStartOf replacing regex for common patterns
####################################################################################
function findStartOf(regex::Base.Regex, string::AbstractString)::Tuple{Int,Bool}
    rangeFound::Union{Nothing,UnitRange{Int}} = findfirst(regex, string)
    if rangeFound === nothing
        return (lastindex(string), true)
    else
        return (rangeFound.start, false)
    end
end

"""
    findFirstNonSpace(s) -> (pos, endOfLine)

Fast replacement for `findStartOf(r"\\S", s)`. Returns the byte position of
the first non-space character, or `(lastindex(s), true)` if the line is all whitespace.
"""
function findFirstNonSpace(s::AbstractString)::Tuple{Int,Bool}
    pos = findfirst(!_isspace_valid, s)
    if pos === nothing
        return (lastindex(s), true)
    else
        return (pos, false)
    end
end

####################################################################################
## The header dispatch: a character-dispatch reader (`parseHashHeader!`) served the
## '#' flavor from the alpha builds through the parser collapse, and RETIRED once the
## table-driven reader proved equivalent (four-plane differentials at both regimes,
## per-substring reader equivalence, a mutation probe set); its full history lives in
## the development fork. The live reader for EVERY flavor is `parseLeadHeader!` below;
## the flavor-generic `findLeadAfterSpace` serves all leads.
####################################################################################
## The token-delimiter law's head grammar, DERIVED from the single-source body in
## flavor.jl — flavor.jl is included before this file (BLS.jl), and deriving (not
## copying) is what kills the parse/walk grammar-drift class.
const _re_meta = Regex("^" * _RE_META_BODY_STR)

####################################################################################
## The TABLE-DRIVEN unified head reader + the composition helper
####################################################################################
## `parseLeadHeader!` consumes the AFTER-LEAD substring and returns the inherited Int
## convention: the ARM-SPECIFIC post-head scan index (the `~` arm returns
## `offsets[end]` — the postDef WS position; the run/directive arms the
## post-consumption index — ON the delimiter ws for ws-terminated shapes, on the
## glued NEXT CHAR for accept-path glued forms like `#+x`), 1 at EOL, and **0 = the
## bucket-A sentinel** (produced only under `:content` policies). Every divergence
## between the flavors is RECORD DATA: the policies (glued/bare), the run-arm
## strictness, the directive rows (status·flags·ws_strict·consume).
## The per-flavor witnesses + the standing flavor-equivalence differential
## (forkchecks/differential_flavor.jl, both modes) guard the reader's behavior for
## every armed flavor.

## The unrecognized/glued fallthrough — the ONE policy resolution shared by the
## `~`-arm's glued no-match, the strict run arm's failure, the ws-strict glued
## closer, the :absent directive rows, and the unrecognized head. (The BARE/empty
## arm resolves `bare_policy` INLINE in the reader — it never calls this helper;
## the two policies coincide on every armed flavor today, and a future flavor
## with divergent bare/glued policies must keep that separation.)
@inline function _lead_fallthrough!(profile::FlavorProfile,
        thisComponentSettribute::ComponentSettribute)::Int
    profile.glued_policy === :content && return 0
    setElement(thisComponentSettribute, :comment => true)
    return one(Int)
end

function parseLeadHeader!(
    profile::FlavorProfile,
    subStr::SubString{String},
    thisComponentSettribute::ComponentSettribute)::Int

    if isempty(subStr)
        ## Bare lead at EOL — the bare policy (:julia sentinel 0; :c graceful
        ## empty comment).
        profile.bare_policy === :content && return 0
        setElement(thisComponentSettribute, :comment => true)
        return one(Int)
    end
    c = first(subStr)

    if _is_h_ws(c)
        ## Text arm — flavor-neutral, byte-identical in both retired readers incl.
        ## the deliberate head-test/offset-scan ASYMMETRY (`_is_h_ws` head test,
        ## `_isspace_valid` offset scan — preserved VERBATIM; the
        ## findfirst===nothing→1 fallback is post-rstrip UNREACHABLE at both
        ## grains, replicated anyway and proven by the header differential's
        ## synthetic all-ws probes).
        setElement(thisComponentSettribute, :containsText => true)
        pos = findfirst(!_isspace_valid, subStr)
        return pos === nothing ? one(Int) : pos

    elseif c == '~'
        ## Meta arm — the SHARED `_re_meta` (flavor-neutral post-lead DSL); a
        ## glued no-match resolves by the glued policy.
        matchFound = match(_re_meta, subStr)
        if matchFound === nothing
            ## §4.1 refusal (v0.3.1, R-INERT-1 family): the TRANSPOSED inert
            ## marker — tildes, then '!', then digits (ws/EOL-terminated) — is the known
            ## "#~!N" mistake for the canonical trailing-bang "#~N!". It must NEVER silently
            ## become content of any flavor (it did: bucket-(A) made it Text at file start,
            ## Code after code, an inert Meta line in a Meta neighbourhood — three meanings
            ## across three engine generations). REFUSE loudly, before the glued fallthrough.
            ## The refused FAMILY is exactly: tildes + ONE '!' + digits + an OPTIONAL trailing
            ## '!' ("#~!N" and "#~!N!"), ws/EOL-terminated. Multi-bang shapes ("#~!!0") and
            ## glued tails ("#~!0x") stay bucket-(A) user content (the token-delimiter
            ## law; this refusal narrows it by exactly the one family).
            local _bangFirst = match(r"\A([~]+)!([0-9]+)!?(?=[\h]|$)", subStr)
            if _bangFirst !== nothing
                error("GoMeta parse: bang-first meta marker \"#", _bangFirst.match,
                    "\" — the inert marker is the TRAILING bang (\"#",
                    _bangFirst.captures[1], _bangFirst.captures[2],
                    "!\": depth, then !); \"#~!N\" is not a metaLine and is refused ",
                    "(SYNTAX-AND-SEMANTICS.md §9 — ships at docs/ in the released package)")
            end
            return _lead_fallthrough!(profile, thisComponentSettribute)
        end
        setElement(thisComponentSettribute, :containsMeta => true, :hasMetaStr => true)
        givenDepthMH::Int = min(length(matchFound[:hashDef]), 8)
        if nothing !== matchFound[:metaDef]
            if isdigit(first(matchFound[:metaDef]))
                givenDepthMH = parse(Int, first(matchFound[:metaDef]))
            end
            if last(matchFound[:metaDef]) == '!'
                ## R-INERT-4 (v0.3.1): the author's trailing-bang marker mints
                ## :ignoreMetaContent — NOT :ignoreThisMeta. The component stays structurally
                ## LIVE (the absorb gates key on :ignoreThisMeta, which this line no longer
                ## carries, so it walks/closes/supersedes exactly like the bare live marker);
                ## only its content is absorbed as EMPTY (walk.jl applyAbsorbFn). The other
                ## :ignoreThisMeta mint classes (comment-in-Meta, bucket-A-in-Meta, the "#]"
                ## flavor rows) are UNCHANGED and stay absorb-skipped.
                setElement(thisComponentSettribute, :ignoreMetaContent => true)
            end
        end
        setElement(thisComponentSettribute, Symbol("depth", string(givenDepthMH)) => true)
        return !iszero(matchFound.offsets[end]) ? matchFound.offsets[end] : one(Int)

    elseif c == profile.comment_run_char
        ## Comment-run arm — strictness is RECORD DATA (`comment_run_strict`):
        ## strict = :comment iff EXACTLY one run char + ws-or-EOL (the julia
        ## token-delimiter law; longer runs/glued fall through); lax = every run length is a
        ## comment with the POST-RUN offset (the cfam host convention — the
        ## offset is byte-load-bearing, which is why laxness cannot collapse
        ## into the policy fallthrough).
        i = firstindex(subStr)
        run = 0
        while i <= lastindex(subStr) && subStr[i] == profile.comment_run_char
            run += 1
            i = nextind(subStr, i)
        end
        if profile.comment_run_strict &&
           !(run == 1 && (i > lastindex(subStr) || _is_h_ws(subStr[i])))
            return _lead_fallthrough!(profile, thisComponentSettribute)
        end
        setElement(thisComponentSettribute, :comment => true)
        return i <= lastindex(subStr) ? i : one(Int)

    else
        ## Directive arms — the TABLE walk (five rows, closed set, mint-guarded).
        for row in profile.directives
            row.char == c || continue
            row.status === :absent &&
                return _lead_fallthrough!(profile, thisComponentSettribute)
            if row.ws_strict && ncodeunits(subStr) >= 2
                j = nextind(subStr, firstindex(subStr))
                ## The glued ws-strict shape resolves by the glued policy BEFORE
                ## any flag is set (the token-delimiter `#]x` law).
                if !_is_h_ws(subStr[j])
                    return _lead_fallthrough!(profile, thisComponentSettribute)
                end
            end
            for flag in row.flags
                setElement(thisComponentSettribute, flag => true)
            end
            if row.consume === :run
                i = firstindex(subStr)
                while i <= lastindex(subStr) && subStr[i] == c
                    i = nextind(subStr, i)
                end
                return i <= lastindex(subStr) ? i : one(Int)
            end
            return ncodeunits(subStr) >= 2 ?
                nextind(subStr, firstindex(subStr)) : one(Int)
        end
        ## Unrecognized head — the glued policy (julia bucket-A; cfam comment).
        return _lead_fallthrough!(profile, thisComponentSettribute)
    end
end

## The composed head helper: ONE definition serves BOTH grains (skip+parse+compose;
## lead DETECT stays the branch predicate), so the composition arithmetic cannot
## half-drift. THE COMPOSITION-ORDER CONTRACT: the bucket-A sentinel is tested on
## the RAW return BEFORE the lead-width term joins (a raw 0 + width term would
## fake a real offset); the uniform `(lead_ncu - 1) + (bucketA ? 1 : raw)` form is
## byte-identical for the 1-cu julia lead and future-safe for multi-cu
## `:content`-policy leads. PERMANENCE NOTE: the ORDER property is enforced by
## this single definition site AND exhibited mechanically by the synthetic
## composition witness (the latex battery's [12] row — a 2-codeunit-lead sentinel
## profile makes sentinel-before-width observable); no ARMED flavor combines a
## sentinel-capable reader with a multi-unit lead, so only the width MAGNITUDE is
## differential-live for real flavors. The `::Int` assert restores inference
## through the deliberately-loose `::Function` field at the hottest per-head site.
@inline function _lead_head!(profile::FlavorProfile, line::AbstractString,
        startSegment::Int,
        thisComponentSettribute::ComponentSettribute)::Tuple{Bool,Int}
    ## ASCII lead (mint-asserted) ⇒ byte arithmetic; ≡ nextind for lead_ncu == 1.
    sub = SubString(line, startSegment + profile.lead_ncu)
    raw = (profile.parse_header!(profile, sub, thisComponentSettribute))::Int
    bucketA = raw == 0
    return (bucketA, (profile.lead_ncu - 1) + (bucketA ? 1 : raw))
end

#########################################################################################
##~ Extracted helpers for `parseBLS()`:
#########################################################################################

"""
    propagate_content_flags_up!(child, parent)

Copy `:containsMeta`, `:containsText`, `:containsCode` from child to parent
if they are set on the child's `componentSettribute`.
"""
function propagate_content_flags_up!(
    child::Component, parent::Component)
    for keyWord ∈ (:containsMeta, :containsText, :containsCode)
        if getElement(child.componentSettribute, keyWord)
            setElement(parent.componentSettribute, keyWord => true)
        end
    end
end

"""
    propagate_content_flags_up!(child, parent, grandparent)

Two-level propagation: child → parent, parent → grandparent.
"""
function propagate_content_flags_up!(
    child::Component, parent::Component, grandparent::Component)
    for keyWord ∈ (:containsMeta, :containsText, :containsCode)
        if getElement(child.componentSettribute, keyWord)
            setElement(parent.componentSettribute, keyWord => true)
            setElement(grandparent.componentSettribute, keyWord => true)
        elseif getElement(parent.componentSettribute, keyWord)
            setElement(grandparent.componentSettribute, keyWord => true)
        end
    end
end

"""
    determine_content_type!(settribute, fallbackContentType) -> Type

Given a `ComponentSettribute` with flags already set (e.g. by `parseLeadHeader!`),
determine and return the segment content type (`Meta`, `Code`, `Text`), and set
the corresponding `:is...` flag on the settribute.

`fallbackContentType` is used when only `:comment` is set — comments inherit
the content type of their enclosing line/block.
"""
function determine_content_type!(
    crntComponentSettribute::ComponentSettribute,
    fallbackContentType::Union{Nothing, Type{<:AbstractContentSettribute}}
)
    if getElement(crntComponentSettribute, :containsText)
        setElement(crntComponentSettribute, :isText => true)
        return Text
    elseif getElement(crntComponentSettribute, :containsCode)
        setElement(crntComponentSettribute, :isCode => true)
        return Code
    elseif getElement(crntComponentSettribute, :containsMeta)
        setElement(crntComponentSettribute, :isMeta => true)
        return Meta
    elseif getElement(crntComponentSettribute, :comment)
        ct = fallbackContentType === nothing ? Text : fallbackContentType
        if ct == Meta
            setElement(crntComponentSettribute, :ignoreThisMeta => true)
        end
        return ct
    end
    return nothing
end

## The mid-line triple-quote tracker's counter (the fence-exit fix, class b): a
## single character walk that counts TRACKED `"""` runs — replacing two weaker
## predecessors each caught by a review round (a lookbehind that miscounted
## even-backslash shapes and skip-jumped overlapping runs; a first-character
## comment exclusion that missed TRAILING comments and wrongly excluded
## hash-leading lines INSIDE an open string). The walk:
##   - tracks escapes char-by-char: a backslash escapes exactly the NEXT char, so
##     `\"""` is content (escaped quote + two quotes) while `\\"""` is a REAL run
##     (the backslash escaped itself);
##   - counts consecutive unescaped quotes; every third completes a run
##     (non-overlapping by construction, correct on 4-quote and 6-quote lines);
##   - each completed run toggles the crude string-interior state, seeded from
##     `in_open_string` (the caller's fence state);
##   - a `#` OUTSIDE the string state starts a comment — the rest of the line is
##     comment text and never counted (covers hash-LEADING lines and TRAILING
##     comments alike); a `#` INSIDE the string state is content, so a
##     hash-leading line inside an open string CAN terminate it, matching Julia.
## LONG-RUN PARITY (the convergence-delta MAJOR, cured): Julia's triple strings
## terminate on the LAST three quotes of a run (`"""a""""` == `a"`), so an
## IN-STRING run of any length ≥3 closes exactly ONCE — a naive per-3 toggle
## re-opened a closed string on 6-quote runs (tail loss on input Julia parses
## fine). The CLOSE-LOCK below suppresses further toggles for the remainder of a
## consecutive run after an inside→close toggle — INCLUDING the close inside an
## OUTSIDE-state long run: `""""""` = open + close (the empty-string pair, two
## toggles), and a 9-run is open + close + LOCKED remainder (two toggles, the
## last-3 reading — the lock, not per-3, carries runs ≥9; a prior revision of
## this note said "outside runs keep per-3", true only up to 8 — micro-delta
## trued).
## RECORDED BOUNDS (byte-approximate on purpose — a full lexer is the reserved
## escape grammar's territory): single-double-quote strings are NOT tracked, so a
## `#` inside one (`x = "a#b" * """`) reads as a comment start and the walk stops
## EARLY. On simple shapes that is an undercount (no toggle); on COMPOUND shapes
## (a close, then a `#`-carrying single-quote string, then a re-opener on ONE
## line) the dropped tail can flip parity into a phantom deferred CLOSE — both
## arms degrade toward the PRE-FIX tail behavior for those rare forms; neither
## invents a new swallowing class beyond them (delta-recorded; the bound is
## stated here in its honest, non-absolute form). A THIRD compound member
## (micro-delta-recorded): with the state seeded INSIDE, a locked long run
## followed by a code-position backslash and further quotes mis-nets one close
## (the byte-level escape model treats the backslash as escaping, where Julia's
## code-position `\\` is an operator) — contrived, same degradation class.
function _count_tracked_triple_quotes(line::AbstractString, in_open_string::Bool)::Int
    n = 0
    run = 0
    escaped = false
    inside = in_open_string
    run_locked = false      # set by an inside→close toggle; suppresses further
                            # toggles while the SAME consecutive quote run continues
    i = firstindex(line)
    while i <= lastindex(line)
        c = line[i]
        if escaped
            escaped = false
            run = 0
            run_locked = false
        elseif c == '\\'
            escaped = true
            run = 0
            run_locked = false
        elseif c == '"'
            run += 1
            if run == 3 && !run_locked
                n += 1
                run = 0
                if inside
                    inside = false
                    run_locked = true   # Julia's last-3 rule: one close per run
                else
                    inside = true       # opens keep per-3 (empty-string pairs)
                end
            elseif run == 3
                run = 0                 # locked: swallow the rest of the run
            end
        else
            run = 0
            run_locked = false
            if c == '#' && !inside
                break
            end
        end
        i = nextind(line, i)
    end
    return n
end

#########################################################################################
function parseBLS(
    state::ParseState,
    fromLine::Int=1,
    toLine::Int=-1
)

    ## (thisFnName removed — error messages use string literals now)

    ## The ONE record hoist — every flavor read below rides this local (resolve-once
    ## at loop scope); if loop-scope reads ever price too high, the declared retreat
    ## is a function barrier on exactly this value.
    profile = state.flavor

    crntFile::File = state.componentsPDict[File][1][1]
    setElement(crntFile.cmpntNamedInt, :idComponent => 1)
    blockContentType::Union{Nothing,Type{T}} where T<:AbstractContentSettribute =
        nothing
    segmentContentType::Union{Nothing,Type{T}} where T<:AbstractContentSettribute =
        nothing

    local crntBlock::Block
    local crntLine::Line
    local crntSegment::Segment
    local prevComponent::Component{N} where N
    blockId::Int = 1 # The 1st `line` in "blockComponentVec" is a Dummy-block.
    lineId::Int = 1 # The 1st `line` in "lineComponentVec" is a Dummy-block.
    idxFirstMetaLine::Int = 0
    cntEmptyLines::Int = 0

    lineContenTypeDetermined::Bool = false
    startSegment::Int = 0
    stopSegment::Int = 0
    local offset::Int = 1
    reachedEndOfLine::Bool = false
    ## Fence store: a plain String — the fence grammar admits delimiters of ANY length ({3,}),
    ## so a fixed-width store is a capacity cliff (a 16-character delimiter crashed the convert).
    ## NOTE: InlineStrings is a core dependency (BLS.jl's `using`; Project.toml + Manifest carry it).
    fenceStr::String = ""
    fenceOpen::Bool = false
    fenceJustClosed::Bool = false   ## the fence-exit boundary's DEFERRED reset flag
                                    ## (armed at true closure; consumed at the next
                                    ## line's iteration — see the closure branch)
    fenceToggleNextLine::Bool = false ## the mid-line triple-quote tracker's DEFERRED
                                    ## toggle (armed on an odd `"""` count; consumed
                                    ## at the next line's iteration — see the tracker)
    crntComponentSettribute::ComponentSettribute = ComponentSettribute()
    configDict = Dict{String,Any}()

    if toLine <= 0
        toLine = length(state.collectedLines)
    end
    ## Range-completed terminal-newline fact: a parse range that stops
    ## BEFORE the last source line ends at a line BOUNDARY by construction — the following source
    ## lines exist, so the last PARSED line carries a terminator. `render_bytes` keys its
    ## trailing-0x0a trim on this field; whole-file parses keep the setup-captured value.
    if toLine < length(state.collectedLines)
        state.endsWithNewline = true
    end
    for (lineNum, line) ∈ enumerate(state.collectedLines)
        if lineNum > toLine
            break
        end
        ## THE FENCE-EXIT BLOCK BOUNDARY, deferred half (see the closure branch):
        ## the FIRST line after a true fence closure starts a fresh block — exactly
        ## what the line after an OPENING fence gets — so post-fence metaLines
        ## become their own Meta blocks again (absorb AND apply), and post-fence
        ## content regains its true type. Consumed once per closure.
        if fenceJustClosed
            blockContentType = nothing
            fenceJustClosed = false
        end
        ## The mid-line triple-quote tracker's deferred toggle (see the tracker
        ## below): a mid-line OPEN arms the string state for the interior lines; a
        ## mid-line CLOSE ends it and sets the same fence-exit boundary as a
        ## line-start closure. Consumed once per toggle.
        if fenceToggleNextLine
            if fenceOpen
                fenceOpen = false
                blockContentType = nothing
            else
                fenceOpen = true
                fenceStr = "\"\"\""
            end
            fenceToggleNextLine = false
        end
        lineId += 1
        rawStopMainStr::Int = lastindex(line)  ## the ORIGINAL line end, captured before the rstrip below
        inlineMetaMarkers::Int = 0  ## reserved-syntax refusal: `#~` marker EVENTS on this line
        leadLedLine::Bool = false   ## directive-adjacency guard scope: set ONLY by the lead-led dispatch
                                    ## arm below — fence open/close lines arrive at the type resolution
                                    ## flag-less (`resolved === nothing`) WITHOUT being directive-
                                    ## classified; an unscoped guard would mis-fire on a ```-close line
        line = rstrip(_isspace_valid, line)
        ###################################################
        # 4 possible scenarios follow:
        # the difference between the first 2 cases `#-` and `#+` is according to:
        # https://fredrikekre.github.io/Literate.jl/v2/pipeline/#Custom-control-over-chunk-splits
        # "The difference between #+ and #- is that #+ enables Documenter's "continued"-blocks,
        # see the Documenter manual."
        (startSegment, reachedEndOfLine) = findFirstNonSpace(line)
        #############################################################
        # Case 1: is `empty line`
        if reachedEndOfLine
            cntEmptyLines += 1
            if blockContentType == Meta
                blockContentType = nothing ## Start NEW Block once done with empty lines.
            end
            continue
            #############################################################
            ## Case 2: opening or closing ```...-fences:
            ##       Starting NEW Block either way
            ## i.e.: Set blockContentType = nothing
            ## The arm is GATED on the record's content-model slot (`fences_armed`, an
            ## inline Bool): an armed flavor (:julia) makes the gate a constant-true
            ## conjunct — byte-identical behavior; an unarmed flavor never fences.
        elseif profile.fences_armed && nothing !== (matchFound = match(
            r"^(?<md>md)?(?<fence>[`\"]{3,})(?<fenceDef>[^[:space:]]+)?(?<postFence>[\h])?",
            SubString(line, startSegment))
        )
            if fenceOpen ## Don´t do here: "&& fenceStr == matchFound[:fence]
                ## because:
                ## IF   fenceStr != matchFound[:fence]
                ## THEN we don´t want to move to `else` below but rather:
                ##      `lineContentTypeDetermined` REMAINS `false` and so
                ##      continue looking for `lineContentType`.
                if fenceStr == matchFound[:fence]
                    fenceOpen = false ## Closure of open fence.
                    segmentContentType = blockContentType
                    lineContenTypeDetermined = true
                    ## THE FENCE-EXIT BLOCK BOUNDARY (the owner-decided v0.2 fix of the
                    ## meta-after-fence drop): the OPEN branch ends the current block
                    ## ("Starts NEW Block" below) but this CLOSE branch never did — so
                    ## no block boundary existed after a closing fence, every
                    ## subsequent line glued into the fence's block as mistyped
                    ## content, nothing after a fence was ever marked attachedToMeta,
                    ## and every later standalone metaLine ABSORBED but never APPLIED
                    ## (silent row loss to end-of-file — probe-verified; in real
                    ## Julia files every docstring tripped it). The reset is DEFERRED
                    ## to the next line's iteration (the flag below): the closing
                    ## line itself must still join the fence's block — an eager reset
                    ## here re-blocked the closing line and churned every
                    ## fence-carrying golden (caught by the byte-identical gate on
                    ## the first cut of this fix; the oracle-parity fixtures close
                    ## their fences at EOF and must stay byte-stable). A non-matching
                    ## closer (differing delimiter length) stays INSIDE the fence at
                    ## THIS branch — the flag arms on TRUE closure only, guarded by
                    ## the fenceStr equality above. (BACKTICK fences: that is the
                    ## final word — markdown semantics. QUOTE fences: the mid-line
                    ## tracker below then counts the non-matching line's quotes and
                    ## closes ONE LINE LATER — Julia string semantics; witness rN.)
                    fenceJustClosed = true
                end
            else
                fenceOpen = true
                fenceStr = matchFound[:fence]

                if matchFound[:md] == "md" ||
                   matchFound[:fenceDef] === nothing ||
                   matchFound[:fenceDef] == "md"
                    setElement(crntComponentSettribute, :containsText => true, :md => true)
                elseif matchFound[:fenceDef] == "julia" || matchFound[:fenceDef] == "jl"
                    setElement(crntComponentSettribute, :containsCode => true, :julia => true)
                else
                    ## An unknown fence tag (```@example, ```jldoctest, ```python,
                    ## ```bash, ```r, …) is classified as a generic CODE block — it has
                    ## content in *some* language. GUARDRAIL: sets :containsCode ONLY,
                    ## with NO language-specific flag (no :julia/:md) — v0 does not
                    ## invent render/highlight semantics for the tag (that is the fenced
                    ## rendering engine, DOWNSTREAM). Classifying it Code also satisfies
                    ## the later "fenced Block must be Code or Text" check.
                    ## ```@example/```jldoctest are GoMeta's own Documenter/Literate
                    ## domain, so real inputs hit this often.
                    setElement(crntComponentSettribute, :containsCode => true)
                end
                lineContenTypeDetermined = true
                blockContentType = nothing ## Starts NEW `Block`
            end
            if lineContenTypeDetermined
                if !iszero(matchFound.offsets[end])
                    offset = matchFound.offsets[end]
                else
                    offset = one(Int)
                end
            end
        end

        ## THE MID-LINE TRIPLE-QUOTE TRACKER (class b of the owner-decided fence-exit
        ## fix; discovered AT the cut — the first probe class was mis-attributed):
        ## an assignment-opened string (`s = """`) is INVISIBLE to the line-start
        ## fence regex above, so its TERMINATOR line used to phantom-OPEN a fence
        ## that swallowed the file tail (every subsequent metaLine absorbed, never
        ## applied — the drop's dominant real-world shape: Julia docstring/string
        ## assignments). The tracker counts the line's non-overlapping, UNESCAPED
        ## `\"\"\"` occurrences on lines the fence regex did NOT classify: an ODD
        ## count toggles the string state — mid-line OPEN (the interior joins the
        ## current block, the status-quo interior shape) or mid-line CLOSE (deferred
        ## boundary, same as a line-start close). A lone `\"\"\"` terminator line
        ## still routes through the fence regex's CLOSE branch (fenceStr matches),
        ## so no double-toggle is possible (`lineContenTypeDetermined` guards).
        ## COMMENT TEXT IS NEVER COUNTED (two review rounds converged here): quote
        ## bytes after a real comment start — a hash-LEADING line OR a TRAILING
        ## `# …` tail — are comment text, never string delimiters (counting them
        ## phantom-toggled on healthy input: a `# old: s = \"\"\"` comment swallowed
        ## the tail; an odd-count metaLine even crashed the fenced-type check; a
        ## TRAILING comment did the same one round later). The comment/escape/
        ## string-interior discrimination lives in the WALKING COUNTER (see
        ## `_count_tracked_triple_quotes`): escapes are per-character (`\\\"\"\"`
        ## counts — the backslash escaped itself), and a `#` INSIDE an open string
        ## is content, so a hash-leading line there CAN terminate it (Julia
        ## semantics; the earlier unconditional first-char exclusion traded that
        ## arm silently — delta-caught, cured).
        ## BOUNDED BY DESIGN, the honest width: `\"\"\"` only (mid-line backticks
        ## stay untracked); a lone mid-line `\"\"\"` in PROSE text of a Text block
        ## phantom-toggles (degrades to the pre-fix tail behavior — and inside an
        ## open line-start `\"\"\"` TEXT fence it can hand the tail to the phantom
        ## state, the md-Text-unfaithful arm of the Julia-faithful trade); a
        ## FOUR-quote line-start OPENER keeps the markdown exact-length arm
        ## (pre-existing, unchanged — asymmetric with the rN closer re-pin); the
        ## counter's single-quote-string bound (see its header) undercounts, never
        ## phantom-toggles. The bounds are WITNESSED in the fence-exit testset;
        ## real Julia string extents are what the v0.2 gate needs.
        ## The toggle is FULLY DEFERRED (both halves): the tracker line itself keeps
        ## its own classification (the opener stays a plain code line in its current
        ## block; a mid-line terminator stays fence interior) — an eager toggle
        ## re-classified the tracker line and churned structure (caught at the cut).
        ## Gated on `fences_armed` like the Case-2 arm above (the same content-model
        ## slot; constant-true for :julia).
        if profile.fences_armed && !lineContenTypeDetermined &&
           (!fenceOpen || fenceStr == "\"\"\"") &&
           isodd(_count_tracked_triple_quotes(line,
               fenceOpen && fenceStr == "\"\"\""))
            fenceToggleNextLine = true
        end

        ## Following Case 1 and Case 2:
        ## IF `lineContenTypeDetermined` in EITHER Case1 or Case2 above,
        ## THEN re-set to `false` and progress.
        ## The token-delimiter law: the head reader signals bucket (A) — a glued/
        ## undelimited lead-shape that is PLAIN CONTENT under a `:content` glued
        ## policy — with the raw sentinel 0 and no flags (mapped inside _lead_head!).
        bucketA = false
        if lineContenTypeDetermined
            lineContenTypeDetermined &= false
            ## ELSE (if `lineContenTypeDetermined` was not determined / set to true above)
            ## THEN we are in EITHER of the two following scenarios:
        else
            if _starts_with_lead(profile, line, startSegment)
                leadLedLine = true
                ## The composed head helper — skip + the 3-arg reader call + the
                ## sentinel-before-width composition, ONE definition for both grains
                ## (offset arrives sentinel-mapped; a bucket-A contentType resolves by
                ## inheritance after the fallback computation below).
                (bucketA, offset) = _lead_head!(profile, line, startSegment,
                    crntComponentSettribute)
                ## Reserved-syntax marker event (line grain): ONLY the `~` branch sets
                ## :hasMetaStr, and the settribute is freshly reset before this parse.
                if getElement(crntComponentSettribute, :hasMetaStr)
                    inlineMetaMarkers += 1
                end
            elseif fenceOpen
                if crntBlock.contentType == Text
                    setElement(crntComponentSettribute, :containsText => true)
                elseif crntBlock.contentType == Code
                    setElement(crntComponentSettribute, :containsCode => true)
                else
                    error("@L ", @__LINE__, "Fenced `Block`s must be of type",
                        " `Code` or `Text`")
                end
            else
                setElement(crntComponentSettribute, :containsCode => true)
            end
        end
        fallbackCT = @isdefined(crntLine) ? crntLine.contentType : nothing
        resolved = determine_content_type!(crntComponentSettribute, fallbackCT)
        ## Token-delimiter-law bucket (A): inherit the neighbourhood contentType
        ## EXACTLY as determine_content_type!'s comment arm does (file-start → Text;
        ## Meta context → Meta AND :ignoreThisMeta — the inertness shield the absorb
        ## gates key on), WITHOUT the `:comment` classification. This is what keeps a
        ## bucket-(A) line from splitting its block (the KEY integrity invariant) and
        ## from ever reaching the metaLine DSL in a Meta neighbourhood.
        if resolved === nothing && bucketA
            resolved = fallbackCT === nothing ? Text : fallbackCT
            resolved == Meta && setElement(crntComponentSettribute, :ignoreThisMeta => true)
        end
        ## Reserved directive-adjacency guard, LINE grain (the segment-grain twin
        ## sits in the segment loop below): a structural-directive LINE
        ## (`#-`/`#+`/`#[`/`#>` forms incl. `#----` dividers and `#->` arrows —
        ## `resolved === nothing && !bucketA` is exactly that class) DIRECTLY after
        ## a metaLine/meta block is RESERVED syntax at v0 — refuse EARLY. Without
        ## this guard neither assignment arm fired and `segmentContentType` LEAKED
        ## the preceding LINE's `Meta`; the new block seeded Meta and the
        ## Meta-context :hasMetaStr synthesis produced a metaLine-shaped component
        ## with NO :depthN and NO :ignoreThisMeta — violating the invariant that
        ## Meta without :depthN MUST set :ignoreThisMeta — so the walk refused
        ## "meta depth out of range" (wrong-class: blames a metaLine the author
        ## never wrote) or died at the leaded-marker re-match (`#>` shapes; an
        ## internal error, not a clean refusal). A blank line between does NOT
        ## defuse (empties forward); an interposed content line does; `##`-initial
        ## dividers are bucket-A content and SAFE. Directive lines after Code/Text
        ## keep their measured behavior (the leak lands the benign neighbourhood
        ## type). The arms are RESERVED future GoMeta syntax — the message stays
        ## neutral about a future arming.
        ## Guard SCOPE: (i) `leadLedLine` — fence open/close lines arrive here
        ## flag-less without being directive-classified; an unscoped guard would
        ## wrong-class-refuse a ```-close line after a fenced `#]` (an accepted
        ## file). (ii) inside an OPEN fence (incl. the triple-quote string state)
        ## the `#+`/`#>` interior lines are string/fence CONTENT and stay accepted
        ## (walk-invisible mistype, harmless) — the guard fires in-fence ONLY for
        ## the `:startNewBlock` arms (`#-`/`#[`), whose in-fence twin crashed even
        ## pre-guard (depth error): that half stays a crash→refusal conversion.
        ## Witnesses: tests/unit/reserved_adjacency_tests.jl.
        if resolved === nothing && !bucketA && segmentContentType == Meta &&
           leadLedLine &&
           (!fenceOpen || getElement(crntComponentSettribute, :startNewBlock))
            error("GoMeta parse: a structural-directive line (a `#-`, `#+`, `#[` or ",
                "`#>` form) directly after a metaLine or metaBlock is RESERVED ",
                "syntax at v0 — a blank line between does not defuse the adjacency; ",
                "write the divider `##`-initial (plain content) or put a content ",
                "line between")
        end
        if resolved !== nothing
            segmentContentType = resolved
        end
        if segmentContentType == Meta && idxFirstMetaLine == 0
            idxFirstMetaLine = lineId
            configDict = Dict{String,Any}("idxFirstMetaLine" => idxFirstMetaLine)
        end
        if setElementToFalseIfTrue(crntComponentSettribute, :startNewBlock)
            blockContentType = nothing
        end

        #################################################################################
        ## NEW `Block`?
        if blockContentType === nothing ||
           (blockContentType != segmentContentType && !fenceOpen)

            ## Yes, NEW Component Block:
            blockContentType = segmentContentType
            ## A structural-directive line (#- #+ #[ #>) resolving to NO content
            ## type (determine_content_type! returns nothing) at file start has no prior block to
            ## inherit from, leaving blockContentType === nothing → MethodError in addChildComponentTo.
            ## Default such a block to Code (these are Literate.jl chunk directives in code context;
            ## mirrors the plain-line non-#/non-fence :containsCode fallback above). GUARDRAIL: Code, NEVER Meta —
            ## sets no :hasMetaStr/:containsMeta, so the line cannot enter the fenced DSL. Mid-file
            ## directives are unaffected (they inherit the prior block's non-nothing type); the
            ## segment loop below is consequently safe (its fallback crntLine.contentType is now
            ## non-nothing and segmentContentType is seeded from blockContentType).
            if blockContentType === nothing
                blockContentType = Code
            end
            setElement(crntComponentSettribute,
                :hasMetaStr => false, :attachedToMeta => false,
                :containsCode => false, :containsMeta => false, :containsText => false,
                :containsEmpty => false, :md => false, :julia => false)
            ## NOTE:
            ## Here above(?) BELOW it is ensured / checked that `crntBlock` exists!!!
            if getElement(crntFile.cmpntNamedInt, :numChildren) > 0
                setElement(crntBlock.cmpntNamedInt,
                    :stopMainStr => (lineNum - 1 - cntEmptyLines))
                ## Propagate `containsComponentType` upwards
                ##            BEFORE creating the NEW `Block`:
                propagate_content_flags_up!(crntLine, crntBlock, crntFile)

                if !getElement(prevComponent.componentSettribute, :stopAttachmentToMeta)
                    if (cntEmptyLines == 0 &&
                        getElement(crntBlock.componentSettribute, :attachedToMeta))

                        setElement(crntComponentSettribute, :attachedToMeta => true)
                    end
                else
                    setElement(crntComponentSettribute, :detachedFromMeta => true)
                end
            end
            (tmpBlockIdx, crntBlock) = addChildComponentTo(state,
                crntFile, (lineNum - cntEmptyLines), blockContentType,
                keys(ComponentSettribute)[crntComponentSettribute.array]...)
            if blockContentType == Meta
                setElement(crntBlock.componentSettribute,
                    :attachedToMeta => true)
            end
            setElement(crntBlock.cmpntNamedInt,
                :startMainStr => (lineNum - cntEmptyLines))
            blockId += 1
        ## END of: "## NEW `Block`"
        elseif fenceOpen
            segmentContentType = blockContentType
        end
        #################################################################################
        #################################################################################
        ## Add NEW Component`Line` to `crntBlock`:
        setElement(crntComponentSettribute, :includeInOutFile => true)
        blockContentType == Meta ?
        setElement(crntComponentSettribute, :hasMetaStr => true) : nothing
        ## Propagate `containsComponentType` upwards:
        ## Here, `crntLine` has NO CHILDREN `Segment(s)` YET:
        if getElement(crntBlock.cmpntNamedInt, :numChildren) > 0
            propagate_content_flags_up!(crntLine, crntBlock)
        end
        #################################################################################
        ## Are there EMPTY `Line`[s]? IF so, THEN add them first to `crntBlock`:
        while cntEmptyLines != 0
            (tmpLineIdx, crntLine) = addChildComponentTo(state,
                crntBlock, (lineNum - cntEmptyLines), blockContentType,
                :includeInOutFile, :isEmpty)
            cntEmptyLines -= 1
        end

        #################################################################################
        ## Add NEW NON-EMPTY `Line` to `crntBlock`:
        (tmpLineId, crntLine) = addChildComponentTo(state, crntBlock, lineNum, blockContentType,
            [key for key ∈ keys(ComponentSettribute)
             if getElement(crntComponentSettribute, key)]...)
        setElement(crntLine.cmpntNamedInt, :idxString => lineNum)
        prevComponent = crntLine
        stopSegment = prevind(line, stopSegment + startSegment + offset)
        ## The flavor-generic inline finder (for a 1-code-unit '#' lead this is the
        ## classic hash-after-space scan).
        (offset, reachedEndOfLine) = findLeadAfterSpace(profile, SubString(line, stopSegment))

        #################################################################################
        ## Add `Segment(s)` to `crntLine`?
        if reachedEndOfLine
            setElement(crntLine.cmpntNamedInt,
                :startMainStr => startSegment, :stopMainStr => lastindex(line))
        else
            safetyCount::Int = 0
            while stopSegment <= lastindex(line)
                ## Data-driven loop-guard: a fixed segment cap would refuse legitimately dense lines
                ## (many ##-comment segments on one line). lastindex(line) is the last BYTE index;
                ## since every segment consumes ≥1 byte, segment count ≤ byte length, so safetyCount
                ## exceeding lastindex(line)+2 can only indicate a genuine non-advancing loop. Pure
                ## infinite-loop safety-net.
                if safetyCount > lastindex(line) + 2
                    error("\n @L ", @__LINE__, ", @F ", basename(@__FILE__),
                        "\n\t safetyCount = ", safetyCount,
                        " exceeded lastindex(line)+2 — non-advancing segment loop !!! EXIT !!!")
                end
                safetyCount += 1
                ## `crntLine` has NO `outFileStr` anymore since its String is now
                ## contained and represented by Segment(s):
                setElement(crntLine.componentSettribute,
                    :includeInOutFile => false, :hasMetaStr => false)
                setElement(crntLine.cmpntNamedInt, :idxString => 0)
                ## `crntSegment` DOES `hasOutFileStr` since it's representing now
                ## this `crntLine`s String-content:
                setElement(crntComponentSettribute, :includeInOutFile => true)
                ## Segment-level nothing-contentType guard: a structural-directive segment (e.g. the `#-` of
                ## `#- # Section header`) can leave segmentContentType === nothing when the line
                ## splits into segments — the directive resolves to no content type and the non-fence
                ## new-block path (unlike the line-level fenceOpen branch above) does NOT seed segmentContentType.
                ## Default to Code: fence-safe (NEVER Meta, mirroring the block-level guard), so
                ## the Segment is created instead of crashing addChildComponentTo(::Nothing).
                if segmentContentType === nothing
                    segmentContentType = Code
                end
                segmentContentType == Meta ?
                setElement(crntComponentSettribute, :hasMetaStr => true) : nothing
                #########################################################################
                ## NEW Segment:
                (_, crntSegment) = addChildComponentTo(state,
                    crntLine, lineNum, segmentContentType,
                    keys(ComponentSettribute)[crntComponentSettribute.array]...)
                stopSegment += offset - 1
                ## Propagate `containsComponentType` upwards ("propUP"):
                propagate_content_flags_up!(crntSegment, crntLine)
                setElement(crntSegment.cmpntNamedInt,
                    :idxString => lineNum,
                    :startMainStr => startSegment,
                    :stopMainStr => stopSegment)
                prevComponent = crntSegment
                if stopSegment >= lastindex(line)
                    break
                end
                startSegment = stopSegment + nextind(SubString(line, stopSegment), 1) - 1
                ## (RE-)sets complete `crntComponentSettribute` .= false
                crntComponentSettribute.array .= false
                ## The SAME composed helper as the line grain (one definition site — the
                ## composition cannot half-drift). Token-delimiter law: the sentinel maps to
                ## the bare-head convention (1) inside the helper, so a glued mid-line lead
                ## shape stays a PLAIN segment (no flags, no meta semantics; keep-the-split,
                ## drop-the-marking; drift fixture c1_inline_nospace pins the two-segment
                ## shape) and the scan advances exactly as the comment class does.
                (bucketA, segHeadOffset) = _lead_head!(profile, line, startSegment,
                    crntComponentSettribute)
                stopSegment = startSegment + segHeadOffset
                ## Reserved-syntax refusal (marker event, segment grain): more than one
                ## inline `#~` marker on one line is RESERVED syntax at v0 — refuse the
                ## process EARLY (no success-then-crash, no ad-hoc semantics). The
                ## settribute was reset for this segment just above, so :hasMetaStr here
                ## is exactly this parse's `~`-branch event; `#]` closers and comments
                ## never set it.
                if getElement(crntComponentSettribute, :hasMetaStr)
                    inlineMetaMarkers += 1
                    if inlineMetaMarkers > 1
                        error("GoMeta parse: more than one inline meta segment on one ",
                            "line — v0 accepts at most one inline meta segment per line ",
                            "(see docs/public-api.md §3.4)")
                    end
                end

                resolved = determine_content_type!(
                    crntComponentSettribute, crntLine.contentType)
                ## Token-delimiter-law bucket (A): inherit the line's contentType
                ## exactly as the comment arm does (Meta context → Meta AND
                ## :ignoreThisMeta), minus `:comment` — see the line-grain twin above.
                if resolved === nothing && bucketA
                    resolved = crntLine.contentType === nothing ?
                        Text : crntLine.contentType
                    resolved == Meta &&
                        setElement(crntComponentSettribute, :ignoreThisMeta => true)
                end
                ## Reserved directive-adjacency guard, SEGMENT grain (the line-grain
                ## twin sits at the line-type resolution above): a structural-
                ## directive segment (a `#-`/`#+`/`#[`/`#>` form —
                ## `resolved === nothing && !bucketA` is EXACTLY that class: every
                ## other header-parser branch either sets a content flag or returns
                ## the bucket-A sentinel) in a META context — the loop variable
                ## `segmentContentType` still `Meta` from the directly-preceding
                ## meta segment OR `#]` closer segment — is RESERVED syntax at v0:
                ## refuse the process EARLY. WITHOUT this guard the directive fell
                ## through BOTH assignment arms here and LEAKED that `Meta` — born
                ## Meta/:hasMetaStr, the walk's leaded-marker re-match died (an
                ## internal error, not a clean refusal). THE PREDICATE IS THE LEAK
                ## ITSELF, not a marker count: a marker-count form is over-broad (an
                ## intervening `# note`/`## note` segment resets the loop variable —
                ## those shapes stay ACCEPTED, byte-pinned) and under-broad (a `#]`
                ## closer types Meta with NO marker event — `x = 1 #] #- y` crashed
                ## straight through it). Directive shapes outside a Meta context
                ## keep their measured behavior (the leak lands the benign Code/Text
                ## neighbourhood type). The arms are RESERVED future GoMeta syntax —
                ## the message stays neutral about a future arming. Witnesses:
                ## tests/unit/reserved_adjacency_tests.jl.
                if resolved === nothing && !bucketA && segmentContentType == Meta
                    error("GoMeta parse: a structural-directive segment (a `#-`, `#+`, ",
                        "`#[` or `#>` form) directly after an inline meta segment or ",
                        "`#]` closer on one line is RESERVED syntax at v0 — separate ",
                        "the directive from the metadata; an intervening plain ",
                        "fragment (a ` # note` or ` ## note`) defuses the adjacency")
                end
                if resolved !== nothing
                    segmentContentType = resolved
                end
                if segmentContentType == Meta && idxFirstMetaLine == 0
                    idxFirstMetaLine = lineId
                end
                if setElementToFalseIfTrue(crntComponentSettribute, :startNewBlock)
                    blockContentType = nothing
                end
                (offset, reachedEndOfLine) = findLeadAfterSpace(profile,
                    SubString(line, stopSegment))
            end ## END of: "while stopSegment < length(line) && safetyCount < 20"
            ## Segment coverage reconciliation — the stated LAW:
            ## after the segment loop, the stored slices cover the line to its ORIGINAL end
            ## (`rawStopMainStr`, captured before the rstrip). ANY uncovered tail — rstripped
            ## whitespace OR content a scan gap dropped (e.g. a terminal bare '#') — joins the
            ## LAST segment, so no byte of the line can silently vanish from the render. The ONE
            ## recorded exception: a Meta-typed last segment keeps its bounds (its slice feeds the
            ## meta reader, which has always been whitespace-free — the recorded carve-out); the
            ## gate reads the SEGMENT'S OWN type, never the loop variable, which can hold a
            ## dropped phantom's type at a non-break exit. The loop runs at least once whenever
            ## this branch is entered, so `crntSegment` is this line's last segment.
            if crntSegment.contentType != Meta &&
               rawStopMainStr > getElement(crntSegment.cmpntNamedInt, :stopMainStr)
                setElement(crntSegment.cmpntNamedInt, :stopMainStr => rawStopMainStr)
            end
        end ## END of: Did NOT `reachedEndOfLine`

        stopSegment = 0
        offset = 1
        ## (RE-)sets complete `crntComponentSettribute` .= false
        crntComponentSettribute.array .= false
    end ## END of: "for (lineNum, line) ∈ enumerate(collectedLines

    ## Trailing-empty-line flush: inside the loop, pending empty lines materialize only when a
    ## LATER non-empty line arrives (the while-flush above), so empties at END-OF-INPUT need this
    ## flush — otherwise a trailing blank line would be absent from the render and blank-only
    ## input would render empty. Flush them here for end-of-input parses; a range stopping BEFORE the
    ## last source line keeps its boundary structural (the recorded ranged bound). The mid-file
    ## rules are mirrored exactly: empties join the CURRENT block when one of matching type is open;
    ## after a Meta block (whose type Case 1 reset to `nothing`) or on blank-only input they get a
    ## fresh default-type block — mid-file empties always land in the FOLLOWING block, never a Meta
    ## one. `prevComponent` is never read here (undefined on blank-only input); the attachedToMeta
    ## bookkeeping is skipped consciously — its set-arm requires zero pending empties, and the
    ## else-arm's `:detachedFromMeta` flag has no readers.
    if cntEmptyLines != 0 && toLine >= length(state.collectedLines)
        lineNumAfter::Int = length(state.collectedLines) + 1
        if blockContentType === nothing
            ## Blank-only input, or trailing empties after a Meta block: fresh block, default type
            ## `Code` (the same default the structural-directive path uses above).
            if getElement(crntFile.cmpntNamedInt, :numChildren) > 0
                setElement(crntBlock.cmpntNamedInt,
                    :stopMainStr => (lineNumAfter - 1 - cntEmptyLines))
                propagate_content_flags_up!(crntLine, crntBlock, crntFile)
            end
            blockContentType = Code
            (tmpBlockIdx, crntBlock) = addChildComponentTo(state,
                crntFile, (lineNumAfter - cntEmptyLines), blockContentType)
            setElement(crntBlock.cmpntNamedInt,
                :startMainStr => (lineNumAfter - cntEmptyLines))
            blockId += 1
        elseif getElement(crntBlock.cmpntNamedInt, :numChildren) > 0
            ## The mid-file pre-flush propagate: the LAST content line's flags must reach the
            ## Block BEFORE `crntLine` is reassigned to a flushed empty below (the absorb walk
            ## gates on Block-level content flags).
            propagate_content_flags_up!(crntLine, crntBlock)
        end
        while cntEmptyLines != 0
            (tmpLineIdx, crntLine) = addChildComponentTo(state,
                crntBlock, (lineNumAfter - cntEmptyLines), blockContentType,
                :includeInOutFile, :isEmpty)
            cntEmptyLines -= 1
        end
    end

    ## Close + propagate the FINAL block — the Block CLOSURE law: every non-final Block is
    ## closed by its successor's open (stop => the line before the successor, empties excluded);
    ## the final Block has no successor, so it closes HERE by the SAME law at the virtual next
    ## line (the effective parsed end + 1). Whole-file parses arrive with cntEmptyLines == 0
    ## (the flush above drained any), so stop == length(collectedLines) — byte-identical to the
    ## consumers' former end-of-input fallback; RANGED parses exclude pending boundary empties
    ## (the recorded ranged bound), so no excluded line can enter any bounds-reading consumer.
    if getElement(crntFile.cmpntNamedInt, :numChildren) > 0
        setElement(crntBlock.cmpntNamedInt,
            :stopMainStr => (min(toLine, length(state.collectedLines)) - cntEmptyLines))
        propagate_content_flags_up!(crntLine, crntBlock, crntFile)
    end

    return state.componentsPDict, configDict
end

## Whitespace predicate over possibly-invalid UTF-8: an invalid byte sequence is CONTENT, never
## whitespace — the Unicode-category `isspace` would throw at decode on sequences that require it
## (overlong encodings and kin), so every input-facing whitespace test in this file goes through
## this guard. On every VALID char it is exactly `isspace`.
_isspace_valid(c::AbstractChar) = isvalid(c) && isspace(c)
