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
## depth 0-8, slot 10 is the user level, 11 the line level, 12 the default — a depth-9 slot
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
## Tree visitor — generic traversal of File → Block → Line → Segment hierarchy
#########################################################################################
"""
    visit_tree(componentsPDict, blockIds; on_block, on_line, on_segment)

Walk the component tree for the given block IDs, calling the provided callbacks.
Each callback receives `(component, id)`. All callbacks are optional (default no-op).
This factored traversal is available for tree-walking code (no in-tree caller at v0).
"""
function visit_tree(
    componentsPDict::Base.PersistentDict{
        Type{<:Component},NTuple{2,Vector{<:AbstractComponent}}},
    blockIds;
    on_block::Function = (_,_) -> nothing,
    on_line::Function  = (_,_) -> nothing,
    on_segment::Function = (_,_) -> nothing
)
    blockVec  = componentsPDict[Block][1]
    lineVec   = componentsPDict[Line][1]
    segmentVec = componentsPDict[Segment][1]

    for blockId in blockIds
        crntBlock = blockVec[blockId]
        on_block(crntBlock, blockId)
        for lineId in eachchildid(crntBlock, blockVec)
            crntLine = lineVec[lineId]
            on_line(crntLine, lineId)
            for segmentId in eachchildid(crntLine, lineVec)
                crntSegment = segmentVec[segmentId]
                on_segment(crntSegment, segmentId)
            end
        end
    end
end

#########################################################################################
##~ `parseBlocksAndLines()`
include("flavor.jl")
include("parseBLS.jl")
## The multi-language function-copy fork: a `//`-adapted sibling copy served `:c`
## until the collapse proved the ONE loop + table for both flavors (four-plane
## differentials, both regimes) — then retired; every flavor now rides parseBLS.jl
## over its FlavorProfile record (the table-only law; per-flavor witnesses + the
## standing differential harness are the equivalence guard).

end
