# answer.jl — THE ONE ANSWER FUNCTION (stage 2's commit 4 of the v0.4 build; R-V04B-35 (c); R-V04B-52 (2); R-V04B-53;
# R-V04B-55 (2); the plan v8.1 :56).
#
# IS:   for ONE Component and ONE Alterant, the Engine's resolved value and its SOURCE — computed ON DEMAND from the delivered
#       rows (`altValues_evals`) and their provenance (`decided_by`, stage 2's commit 2), never stored; ONE answer shape across
#       Alterants, so no consumer meets a set mode (R-V04B-35 (c)).
# DOES: finds the Component's own rows — the rows keyed on it; a Segment-carried row (keyed on a Line with the Segment as the
#       key's origin) counts as the Line's; a rowless child inherits its parent's rows (a Segment its Line's, a Line its Block's
#       — OQ-148: a child equal to its parent is not recorded; R-V04B-52 (2)); no rows anywhere → the Alterant's declared
#       default with the source `:default` (R-V04B-55 (2)), or `:none` for an Alterant without one; the source from the deciding
#       statements' handles: `:own` when every deciding handle is the asked Component's own, else by the first foreign handle's
#       class — the user context `:user`, the File `:file` (the File level's room, R-V04B-53; no feed today), a document
#       Component `:indirect` THROUGH that Component (named in `via`); `:fallBack` RESERVED for the fallBack level's carrier
#       once the metaLevel Alterant feeds it (R-V04B-55 (4)); the File's own answer `:none` — NOTHING built (card 6 "next").
# REASONING: his §67/§68 and R-V04B-35 (a): the rows stay as today and ONE provenance field rides them; the answer is DERIVED
#       from the rows at the call, so the delivered rows remain the one truth and no second store can drift from them.
# PURPOSE: the Extension-facing question "what applies to this Component for this Alterant, and through whom" (R-V04B-35 (c);
#       R-V04B-55 (2) (v): an Extension that needs a value where GoMeta provided none may use the Alterant's default).
# NOT FINAL (put at stage 2's review, R-V04B-40 (2)): the function's NAME (`answerFor` — the branch's working name under his
#       casing rule R-V04B-31; alternatives there), its TIER (package-public — the session's default), the File's case, the
#       equal-child rows (OQ-148), the per-call tree walk behind `via` (the cached index, Q6).

"""
    AltAnswer

IS: the Engine's resolved answer for ONE Component and ONE Alterant — `value` (the Alterant's own datum: Visib a `Symbol`;
Labels the SET of label names, a sorted `Vector{Symbol}`; Id the compound, a `NamedTuple` of the recorded fields; Heading the
`String` of the Component's first heading row), `source` (`:own` · `:indirect` · `:user` · `:file` · `:fallBack` · `:default`
· `:none`) and `via` (the deciding Component for `:indirect`; `nothing` otherwise).
DOES: carries the answer; `value` is `nothing` for `:none`.
REASONING: ONE source tag per Component per Alterant (R-V04B-35 (c)) — the deciding statement's for a single-valued mode, the
SET's for an accumulating one (which Component contributed which label is Q4 (ii), open), the compound's for Id.
PURPOSE: the return of `answerFor`. Package-public (docs/public-api.md §1.2); NOT exported. Stage 2's commit 4; not final
until his word (the NAME and the TIER at the review).
"""
struct AltAnswer
    value::Any
    source::Symbol
    via::Union{Nothing,BLS.AbstractComponent}
end

## the namespace the delivered rows were keyed under, decoded from the first handle (schema (1B) · UInt16-BE length · UTF-8
## bytes — `key_bytes`'s fixed field order); `:default` for an empty store (then only a default can answer).
function _store_namespace(store::EvalStore)
    isempty(store.records) && return :default
    h = store.records[1].cell_handle
    length(h) >= 3 || return :default
    n = (Int(h[2]) << 8) | Int(h[3])
    length(h) >= 3 + n || return :default
    return Symbol(String(h[4:(3 + n)]))
end

## the handle-class byte of a key (`grain` — the fixed offset after the namespace field; the document ladder or the
## non-document plane, `USER_CONTEXT_GRAIN` today); 0x00 for a malformed handle.
function _grain_of(h::Vector{UInt8})
    length(h) >= 3 || return 0x00
    n = (Int(h[2]) << 8) | Int(h[3])
    return length(h) >= 4 + n ? h[4 + n] : 0x00
end

## the key bytes of a Component WITHOUT the empty-origin tail (the two zero bytes of a zero step count): every row keyed on the
## Component — with or without a Segment origin — starts with these bytes, and no other Component's key does (the path section
## carries its own step count first).
function _path_prefix(ps::BLS.ParseState, c::BLS.AbstractComponent, ns::Symbol)
    k = key_bytes(occurrence_key(ps, c; namespace = ns))
    return k[1:(end - 2)]
end

function _starts_with(h::Vector{UInt8}, p::Vector{UInt8})
    length(h) >= length(p) || return false
    @inbounds for i in eachindex(p)
        h[i] == p[i] || return false
    end
    return true
end

## the attribute family of an Alterant's rows, from its capture declaration: `:single` the stem itself (`:visib`); `:per_key`
## and `:per_field` the stem plus `_<member>` (`:label_<name>`, `:id_<field>`); `:per_occurrence` the stem, leveled or not
## (`:head`, `:head_<level>`, `:head_<level>_<k>`).
function _attr_matches(attr::Symbol, stem::Symbol, scheme::Symbol)
    scheme === :single && return attr === stem
    attr === stem && return scheme === :per_occurrence
    return startswith(String(attr), String(stem) * "_")
end

function _rows_on(store::EvalStore, prefix::Vector{UInt8}, stem::Symbol, scheme::Symbol)
    out = EvalRecord[]
    for r in store.records
        (_starts_with(r.cell_handle, prefix) && _attr_matches(r.attr, stem, scheme)) && push!(out, r)
    end
    sort!(out; by = r -> (r.cell_handle, r.attr))
    return out
end

## the value in the Alterant's own shape (the AltAnswer docstring): the rows are non-empty and sorted by (handle, attr).
function _answer_value(rows::Vector{EvalRecord}, stem::Symbol, scheme::Symbol)
    scheme === :single && return rows[1].value
    cut = ncodeunits(String(stem)) + 2          # the stems are ASCII identifiers; the member name follows "<stem>_"
    if scheme === :per_key
        return sort!(unique!([Symbol(String(r.attr)[cut:end]) for r in rows]))
    elseif scheme === :per_field
        ks = Tuple(Symbol(String(r.attr)[cut:end]) for r in rows)
        return NamedTuple{ks}(Tuple(r.value for r in rows))
    end
    return rows[1].value                        # :per_occurrence — the first row in attr order (a repeat stays in the rows)
end

## the Component a deciding handle names — the tree walked through the door (`BLS.root`, `BLS.children`); `nothing` when no
## Component's own key equals the handle (a non-document class, or a degenerate key).
function _component_of(ps::BLS.ParseState, h::Vector{UInt8}, ns::Symbol)
    f = BLS.root(ps)
    key_bytes(occurrence_key(ps, f; namespace = ns)) == h && return f
    for b in BLS.children(ps)
        key_bytes(occurrence_key(ps, b; namespace = ns)) == h && return b
        for l in BLS.children(ps, b)
            key_bytes(occurrence_key(ps, l; namespace = ns)) == h && return l
            for s in BLS.children(ps, l)
                key_bytes(occurrence_key(ps, s; namespace = ns)) == h && return s
            end
        end
    end
    return nothing
end

"""
    answerFor(delivery::GoMetaDelivery, component, alterant::Symbol; registry::AlterantRegistry = DEFAULT_REGISTRY) -> AltAnswer

IS: THE ONE ANSWER FUNCTION — for ONE Component of the delivered tree and ONE Alterant (its registered name: `:Visib`,
`:labels`, `:id`, `:heading` in the default registry) the Engine's resolved value and its SOURCE, derived at the call from
the delivered rows and their provenance (R-V04B-35 (c)).
DOES: (1) the Component's own rows — the rows keyed on it, a Segment-carried row counting as its Line's; (2) a rowless child
inherits its parent's rows up the tree (Segment → Line → Block; never the File); (3) no rows anywhere → the Alterant's
declared default as `(value, :default)` or `(nothing, :none)` when it declares none; (4) the source: `:own` when every
deciding handle of the rows is the asked Component's own key; otherwise the first foreign deciding handle's class —
`USER_CONTEXT_GRAIN` ⇒ `:user`, the File grain ⇒ `:file`, a document grain ⇒ `:indirect` through the Component the handle
names (`via`; `nothing` when none is found); rows without any recorded origin answer `:own` on the Component itself and
`:indirect` through the carrier Component otherwise. The File answers `(nothing, :none)` — NOTHING built for it (card 6
"next"; his question at the review). An Alterant name outside the registry throws an `ArgumentError` naming the registered
names; an Alterant without a capture DECLARATION mints no rows and answers its declared default (`:default`) or `:none`; an
undeclared capture stem is derived as the walk derives it (`lowercase(altName)`). Pure: no state, no cache, no mutation of the delivery.
REASONING: one function, uniform across Alterants (the value in each Alterant's own shape, the source ONE tag), so an
Extension asks one question (R-V04B-35 (c); R-V04B-55 (2)); the rows stay the one truth (R-V04B-35 (a)).
PURPOSE: the Extension-facing read of "what applies here and through whom". Package-public (docs/public-api.md §1.2), NOT
exported. NOT FINAL: the name, the tier, the File's case, the equal-child rows and the per-call walk are put at stage 2's
review (R-V04B-40 (2)); nothing here is promised before v0.7 (§6).
"""
function answerFor(delivery::GoMetaDelivery, component::BLS.AbstractComponent, alterant::Symbol;
                   registry::AlterantRegistry = DEFAULT_REGISTRY)::AltAnswer
    idx = get(registry.alt_index, alterant, nothing)
    idx === nothing && throw(ArgumentError(string("GoMeta answerFor: no Alterant named `", alterant,
        "` in the registry — the registered names: ", join(string.(sort!(collect(keys(registry.alt_index)))), ", "))))
    p = registry.plugins[idx]
    component isa BLS.File && return AltAnswer(nothing, :none, nothing)
    cap = p.capture
    if cap === nothing                  # no capture declaration: the capture floor mints NO rows (`_capture_floor!`) — R-V04B-55 (2): the declared default
        d = p.default
        return d isa Declared ? AltAnswer(d.value, :default, nothing) : AltAnswer(nothing, :none, nothing)
    end
    stem = cap.attr_stem === nothing ? Symbol(lowercase(String(p.altName))) : cap.attr_stem   # the walk's own derivation (annotations.jl's capture; registry.jl's effective stem) — the seat wf-s10-s2c4-check F-1
    scheme = cap.attr_scheme
    ps = delivery.blsComponentTree
    store = delivery.altValues_evals
    ns = _store_namespace(store)
    c = component
    rows = _rows_on(store, _path_prefix(ps, c, ns), stem, scheme)
    while isempty(rows)
        par = BLS.parent(ps, c)
        (par === nothing || par isa BLS.File) && break
        c = par
        rows = _rows_on(store, _path_prefix(ps, c, ns), stem, scheme)
    end
    if isempty(rows)
        d = p.default
        return d isa Declared ? AltAnswer(d.value, :default, nothing) : AltAnswer(nothing, :none, nothing)
    end
    value = _answer_value(rows, stem, scheme)
    ownkey = key_bytes(occurrence_key(ps, component; namespace = ns))
    any_origin = false
    foreign = nothing
    for r in rows, h in r.decided_by
        any_origin = true
        h == ownkey && continue
        foreign = h
        break
    end
    any_origin || return c === component ? AltAnswer(value, :own, nothing) : AltAnswer(value, :indirect, c)
    foreign === nothing && return AltAnswer(value, :own, nothing)
    g = _grain_of(foreign)
    g == USER_CONTEXT_GRAIN && return AltAnswer(value, :user, nothing)
    g == _DOC_GRAIN_CODES.File && return AltAnswer(value, :file, nothing)
    return AltAnswer(value, :indirect, _component_of(ps, foreign, ns))
end
