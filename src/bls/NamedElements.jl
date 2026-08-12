# NamedElements.jl

module NamedElements

using StaticArrays
export NamedElement, @namedElement, updateNEtypesToNamedTuplePDict, printElement

moduleToRefOfTuplesPDict::Dict{Module,Base.PersistentDict{DataType,Ref{NamedTuple}}
} = Dict{Module,Base.PersistentDict{DataType,Ref{NamedTuple}}}()
####################################################################################
function updateNEtypesToNamedTuplePDict(
    crntModule::Module,
    NewNEType::DataType,
    # nameModulePDict::Symbol,
    aRefNamedTuple::Ref{NamedTuple})
    if !haskey(moduleToRefOfTuplesPDict, crntModule)
        moduleToRefOfTuplesPDict[crntModule] = Base.PersistentDict{DataType,Ref{NamedTuple}}()
    end
    moduleToRefOfTuplesPDict[crntModule] = Base.PersistentDict{DataType,Ref{NamedTuple}}(
        moduleToRefOfTuplesPDict[crntModule], NewNEType => aRefNamedTuple
    )
end

abstract type NamedElement{T<:DataType,sizeTuple<:Tuple} end

import Base.eltype
eltype(::Type{<:NamedElement{T,sizeTuple}}) where
{T<:DataType,sizeTuple<:Tuple} = T.parameters[1]

####################################################################################
##~ Macro argument parsing (extracted from @namedElement for readability)
####################################################################################

"""
    parse_named_element_args(elementNames)

Parse the `elementNames` varargs from `@namedElement` into structured data.
Returns `(sizesVec, vecOfSymbolVecs, superType, crntDim, elementNames)`.
"""
function parse_named_element_args(elementNames)
    argsAreSymbols = true
    crntDim = 0
    sizesVec::Vector{Int} = Vector{Int}()
    vecOfSymbolVecs = Vector{Vector{Symbol}}()
    if length(elementNames) == 1 &&
       elementNames[1] isa Expr &&
       elementNames[1].head === :block
        elementNames = elementNames[1].args
    end
    superType = nothing
    for arg1 ∈ elementNames
        arg1 isa LineNumberNode && continue
        if isa(arg1, Expr) && arg1.head === :(=) &&
           length(arg1.args) == 2 &&
           isa(arg1.args[1], Symbol)
            if arg1.args[1] == :superType
                superType = arg1.args[2]
            else
                error("Found something which ought to be a `keyWord` but seems not to match anything.")
            end
            continue
        end
        crntDim += 1
        push!(sizesVec, 0)
        push!(vecOfSymbolVecs, Vector{Symbol}())
        if isa(arg1, Symbol)
            argsAreSymbols == false && throw((ArgumentError(
                LazyString("Inconsistency in types of 'elementNames' arguments. ",
                    " Encountered 'Tuple' of 'Symbols' as well as individual 'Symbol(s).")
            )))
            args = elementNames
        elseif isa(arg1, Expr) && arg1.head === :tuple
            args = arg1.args
            argsAreSymbols == true && (argsAreSymbols = false)
        else
            throw(ArgumentError(LazyString("Invalid Vararg 'elementNames': ", elementNames)))
        end
        for arg2 ∈ args
            arg2 isa LineNumberNode && continue
            if isa(arg2, Expr) &&
               arg2.head === :(=) && length(arg2.args) == 2 &&
               isa(arg2.args[1], Symbol)
                if arg2.args[1] == :superType
                    superType = arg2.args[2]
                else
                    error("Found something which ought to be a `keyWord` but seems not to match anything.")
                end
                continue
            end
            if !isa(arg2, Symbol)
                throw((ArgumentError(
                    LazyString("Current 'arg' must be a 'Symbol' but ",
                        "'typeof(arg2)' = ", typeof(arg2),
                        "\n\t(arg2 = ", arg2, ")."))))
            end
            sizesVec[crntDim] += 1
            push!(vecOfSymbolVecs[crntDim], arg2)
        end
        argsAreSymbols == true && break
    end
    return (sizesVec, vecOfSymbolVecs, superType, crntDim, elementNames)
end

####################################################################################
##~ Code generation helpers (each returns expressions to push into the macro block)
####################################################################################

"""Generate const NamedTuple definitions and the numDims constant."""
function gen_const_namedtuples(blk, typeName, elementNames, sizesVec, vecOfSymbolVecs, crntDim)
    _baseNameInternals = Symbol(:_NamedElementMeta_, typeName)
    _numDimsInternals = Symbol(_baseNameInternals, :_numDims)
    push!(blk.args, esc(:(const $_numDimsInternals = $crntDim)))
    for dimIdx ∈ 1:crntDim
        _nameCrntNamedTuple = Symbol(_baseNameInternals, :_, dimIdx)
        push!(blk.args,
            if crntDim > 1
                esc(:(const $_nameCrntNamedTuple = NamedTuple{
                    Tuple($elementNames[$dimIdx].args),NTuple{$sizesVec[$dimIdx],Int32}}(
                    1:$sizesVec[$dimIdx])))
            else
                esc(:(const $_nameCrntNamedTuple = NamedTuple{
                    Tuple($(vecOfSymbolVecs[1])),NTuple{$sizesVec[$dimIdx],Int32}}(
                    1:$sizesVec[$dimIdx])))
            end
        )
    end
end

"""Generate the struct definition and registration call."""
function gen_struct_def(blk, typeName, elementType, sizesVec, superType, __module__)
    _baseNameInternals = Symbol(:_NamedElementMeta_, typeName)
    push!(blk.args, esc(:(using StaticArrays)))
    superType === nothing && (superType = :(NamedElements.NamedElement))
    push!(blk.args,
        esc(:(
            struct $typeName <: $superType{
                Type{$elementType},Tuple{$sizesVec...}}
                array::MArray{Tuple{$sizesVec...},$elementType}
            end
        ))
    )
    push!(blk.args,
        esc(:(
            NamedElements.updateNEtypesToNamedTuplePDict(
            $(__module__),
            $typeName,
            Ref{NamedTuple}($(Symbol(_baseNameInternals, :_, 1))))
        ))
    )
end

"""Generate constructors: default, fill-value, Bool-keys, default+pairs."""
function gen_constructors(blk, typeName, elementType, sizesVec, __module__)
    _baseNameInternals = Symbol(:_NamedElementMeta_, typeName)
    ## Default constructor (zero-initialized)
    push!(blk.args,
        esc(:(
            $typeName() = $typeName(
                MArray{Tuple{$sizesVec...},$elementType}(undef) .=
                    isprimitivetype($elementType) ? zero($elementType) : nothing
        )))
    )
    ## Fill-value constructor
    push!(blk.args,
        esc(:(
            $typeName(fillValue::$elementType) = $typeName(
                MArray{Tuple{$sizesVec...},$elementType}(undef) .= fillValue
            )))
    )
    ## Bool-keys constructor (only for Bool element types)
    if Core.eval(__module__, elementType) == Bool
        push!(blk.args,
            esc(:(
                function $typeName(
                    theKeys::Vararg{Symbol})
                    array::MArray{Tuple{$sizesVec...},$elementType} =
                        MArray{Tuple{$sizesVec...},$elementType}(undef)
                    array .= false
                    array[getIdxsToKeys($typeName, theKeys...)] .= true
                    return $typeName(array)
                end
            )))
    end
    ## Default+pairs constructor
    push!(blk.args,
        esc(:(
            function $typeName(
                defaultValue::$elementType,
                keyValuePairs::Vararg{Pair{Symbol,$elementType}})
                array::MArray{Tuple{$sizesVec...},$elementType} =
                    MArray{Tuple{$sizesVec...},$elementType}(undef)
                array .= defaultValue
                array[getIdxsToKeys($typeName,
                    [kvPair.first for kvPair ∈ keyValuePairs]...)] .=
                    [kvPair.second for kvPair ∈ keyValuePairs]
                return $typeName(array)
            end
        )))
end

"""Generate accessor functions: keys, getIdxToKey, getIdxsToKeys, getElement, setElement, addToElement."""
function gen_accessors(blk, typeName, elementType, sizesVec, crntDim, __module__)
    _baseNameInternals = Symbol(:_NamedElementMeta_, typeName)

    ## keys()
    push!(blk.args,
        esc(
            quote
                import Base.keys
                keys(::Type{$typeName}) = Base.keys($(Symbol(_baseNameInternals, :_, 1)))
            end
        ))

    ## getIdxToKey
    push!(blk.args,
        esc(:(
            function getIdxToKey(::Type{$typeName}, theKey::Symbol)::Int
                return $(Symbol(_baseNameInternals, :_, 1))[theKey]
            end
        )))

    ## getIdxsToKeys
    push!(blk.args,
        esc(:(
            function getIdxsToKeys(::Type{$typeName}, theKeys::Vararg{Symbol})::Vector{Int}
                idxVec = Vector{Int}(undef, length(theKeys))
                for (j, key) ∈ enumerate(theKeys)
                    idxVec[j] = $(Symbol(_baseNameInternals, :_, 1))[key]
                end
                return idxVec
            end
        )))

    ## getElement (instance)
    push!(blk.args,
        esc(:(
            function getElement(aNamedElement::$typeName, nameOfElement::Symbol)::$elementType
                return aNamedElement.array[
                    $(Symbol(_baseNameInternals, :_, 1))[nameOfElement]]
            end
        )))

    ## getElement (type + array)
    push!(blk.args,
        esc(:(
            function getElement(
                ::Type{$typeName},
                anArray::AbstractArray{$elementType,$crntDim},
                nameOfElement::Symbol
            )::$elementType
                return anArray[getIdxToKey($typeName, nameOfElement)]
            end
        )))

    ## setElement (instance)
    push!(blk.args,
        esc(:(
            function setElement(
                aNamedElement::$typeName,
                keyValuePairs::Vararg{Pair{Symbol,$elementType}}
            )
                aNamedElement.array[
                    getIdxsToKeys($typeName,
                    [kvPair.first for kvPair ∈ keyValuePairs]...)] .=
                    [kvPair.second for kvPair ∈ keyValuePairs]
                return keyValuePairs[end].second
            end
        ))
    )

    ## setElementToFalseIfTrue (Bool only)
    if Core.eval(__module__, elementType) == Bool
        push!(blk.args,
            esc(:(
                function setElementToFalseIfTrue(
                    aNamedElement::$typeName,
                    nameOfElement::Symbol
                )
                    if !aNamedElement.array[getIdxToKey($typeName, nameOfElement)]
                        return false
                    else
                        aNamedElement.array[getIdxToKey($typeName, nameOfElement)] = false
                        return true
                    end
                end
            ))
        )
    end

    ## setElement (type + array)
    push!(blk.args,
        esc(:(
            function setElement(
                ::Type{$typeName},
                anArray::AbstractArray{$elementType,$crntDim},
                keyValuePairs::Vararg{Pair{Symbol,$elementType}}
            )
                anArray[
                    getIdxsToKeys($typeName,
                    [kvPair.first for kvPair ∈ keyValuePairs]...)] .=
                    [kvPair.second for kvPair ∈ keyValuePairs]
                return keyValuePairs[end].second
            end
        ))
    )

    ## addToElement (non-Int types only)
    if !isa(Core.eval(__module__, elementType), Int)
        push!(blk.args,
            esc(:(
                function addToElement(
                    aNamedElement::$typeName,
                    nameOfElement::Symbol,
                    valueToAdd::$elementType
                )
                    return aNamedElement.array[
                        $(Symbol(_baseNameInternals, :_, 1))[nameOfElement]] += valueToAdd
                end
            )))
    end
end

####################################################################################
##~ The @namedElement macro — now delegates to the helpers above
####################################################################################

macro namedElement(typeName, elementType, elementNames...)
    if !isa(typeName, Symbol)
        throw(ArgumentError(LazyString(
            "First argument, 'typeName' must be parsed to type 'Symbol'",
            "\nHowever, 'typeName' = ", typeName, ".\n"
        )))
    end
    if !isa(Core.eval(__module__, elementType), DataType)
        throw(ArgumentError(LazyString(
            "Second argument, 'elementType', must evaluate to a 'DataType'",
            "\nHowever, 'elementType' evaluates in containing module to: ",
            Core.eval(__module__, elementType), ".\n"
        )))
    end
    if isempty(elementNames)
        throw(ArgumentError(LazyString("No arguments given for NamedElement ", T)))
    end

    ## 1) Parse arguments
    (sizesVec, vecOfSymbolVecs, superType, crntDim, elementNames) =
        parse_named_element_args(elementNames)

    ## 2) Generate code
    blk = quote end
    gen_const_namedtuples(blk, typeName, elementNames, sizesVec, vecOfSymbolVecs, crntDim)
    gen_struct_def(blk, typeName, elementType, sizesVec, superType, __module__)
    gen_constructors(blk, typeName, elementType, sizesVec, __module__)
    gen_accessors(blk, typeName, elementType, sizesVec, crntDim, __module__)

    return blk
end

end
