# answer.jl — THE ONE ANSWER FUNCTION.
#
# IS:   for ONE Component and ONE Alterant, the Engine's resolved value and its SOURCE — computed ON DEMAND from the delivered
#       rows (`altValues_evals`) and their provenance (`decided_by`), never stored; ONE answer shape across
#       Alterants, so no consumer meets a set mode.
# DOES: finds the Component's own rows — the rows keyed on it; a Segment-carried row (keyed on a Line with the Segment as the
#       key's origin) counts as the Line's, and its statement as the Line's OWN (the trailing metaSegment's statement is applied
#       DIRECTLY to its Line — the creator's decision); a rowless child inherits its parent's rows (a Segment its Line's, a Line its Block's
#       — a rowless child has no statement of its own; whether a child's own row equal to its parent's is recorded is
#       an open point — today it is: every captured cell's rows are kept); no rows anywhere → the Alterant's declared
#       default with the source `:default` — every built-in Alterant declares one (the creator's decision:
#       Visib `show`, Labels the empty set, Heading none, Id the zero compound); `:none` only for an Alterant without a declared
#       default in a custom registry, and for the File; the source from the deciding
#       statements' handles: `:own` when every deciding handle is the asked Component's own, else by the first foreign handle's
#       class — the user context `:user`, the File `:file` (the File level's room; no feed today), a document
#       Component `:indirect` THROUGH that Component (named in `via`); `:fallBack` RESERVED for the fallBack level's carrier
#       once the metaLevel Alterant feeds it; the File's own answer `:none` — NOTHING built (an open point).
# REASONING: the creator's design: the rows stay as they are and ONE provenance field rides them; the answer is DERIVED
#       from the rows at the call, so the delivered rows remain the one truth and no second store can drift from them.
# PURPOSE: the Extension-facing question "what applies to this Component for this Alterant, and through whom" (an
#       Extension that needs a value where GoMeta provided none may use the Alterant's default).
# NOT FINAL: its TIER (package-public), the File's case and the
#       equal-child rows are open points; the per-call row scan (a cached index;
#       the former per-call tree walk behind `via` was removed — `_component_of` below) is DEFERRED to a later benchmark
#       phase (the creator's decision). The NAME is DECIDED: `evaluatedAltValue`, the creator's word of 2026-10-03,
#       replacing a working name `answerFor`.

"""
    EvaluatedAltValue

IS: the Engine's resolved answer for ONE Component and ONE Alterant — `value` (the Alterant's own datum: Visib a `Symbol`;
Labels the SET of label names, a sorted `Vector{Symbol}`; Id the compound, a `NamedTuple` of the recorded fields; Heading the
`String` of the Component's first heading row), `source` (`:own` · `:indirect` · `:user` · `:file` · `:fallBack` · `:default`
· `:none`) and `via` (the deciding Component for `:indirect`; `nothing` otherwise).
DOES: carries the answer; `value` is `nothing` for `:none`.
REASONING: ONE source tag per Component per Alterant — the deciding statement's for a single-valued mode, the
SET's for an accumulating one (which Component contributed which label is Q4 (ii), open), the compound's for Id.
PURPOSE: the return of `evaluatedAltValue`. Package-public (docs/public-api.md §1.2); NOT exported. The NAME the creator's
word of 2026-10-03; the TIER an open point.
"""
struct EvaluatedAltValue
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
## and `:per_field` the stem plus `_<member>` (`:label_<name>`, `:id_<field>`); `:per_entry` (the Heading's —
## `:per_occurrence` before 0.4.0) the stem, leveled or not (`:head`, `:head_<level>`, `:head_<level>_<k>`).
function _attr_matches(attr::Symbol, stem::Symbol, scheme::Symbol)
    scheme === :single && return attr === stem
    attr === stem && return scheme === :per_entry
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

## the value in the Alterant's own shape (the EvaluatedAltValue docstring): the rows are non-empty and sorted by (handle, attr).
function _answer_value(rows::Vector{EvalRecord}, stem::Symbol, scheme::Symbol)
    scheme === :single && return rows[1].value
    cut = ncodeunits(String(stem)) + 2          # the stems are ASCII identifiers; the member name follows "<stem>_"
    if scheme === :per_key
        return sort!(unique!([Symbol(String(r.attr)[cut:end]) for r in rows]))
    elseif scheme === :per_field
        ks = Tuple(Symbol(String(r.attr)[cut:end]) for r in rows)
        return NamedTuple{ks}(Tuple(r.value for r in rows))
    end
    return rows[1].value                        # :per_entry — the first row in attr order (a repeat stays in the rows)
end

## the Component a deciding handle names — read DIRECTLY from the handle's LAST path step (store byte · u32 ordinal: the handle's
## own layout, `key_bytes` — schema · u16 namespace length · namespace · grain · u16 step count · the steps · the origin steps; the
## grain byte selects the store family through `_DOC_GRAIN_CODES`); `nothing` for a non-document grain, a TRUNCATED marker step
## (store 0x00), an unassigned or out-of-bounds slot (a degenerate key) — the totality arm, never a throw. Stage 3's commit 1b of the
## v0.4 build: the former walk of the whole tree (one key computed per Component until the match, once per :indirect answer) was
## MEASURED as 98.5 % of this function's cost on a 2,520-line input (16.1 of 16.3 s over its Lines);
## the direct read names the same Component for every deciding handle
## of every measured input.
function _component_of(ps::BLS.ParseState, h::Vector{UInt8})
    length(h) >= 3 || return nothing
    n = (Int(h[2]) << 8) | Int(h[3]); i = 4 + n                        # i = the grain byte's index
    length(h) >= i + 2 || return nothing
    g = h[i]
    T = g == _DOC_GRAIN_CODES.Segment ? BLS.Segment : g == _DOC_GRAIN_CODES.Line ? BLS.Line :
        g == _DOC_GRAIN_CODES.Block ? BLS.Block : g == _DOC_GRAIN_CODES.File ? BLS.File : nothing
    T === nothing && return nothing
    nsteps = (Int(h[i + 1]) << 8) | Int(h[i + 2]); nsteps >= 1 || return nothing
    j = i + 3 + 5 * (nsteps - 1)                                         # the LAST step: its store byte at j, its ordinal at j+1..j+4
    length(h) >= j + 4 || return nothing
    store = Int(h[j]); (store == 1 || store == 2) || return nothing
    ord = (Int(h[j + 1]) << 24) | (Int(h[j + 2]) << 16) | (Int(h[j + 3]) << 8) | Int(h[j + 4])
    stores = get(ps.componentsPDict, T, nothing); stores === nothing && return nothing
    store <= length(stores) || return nothing
    v = stores[store]
    (1 <= ord <= length(v) && isassigned(v, ord)) || return nothing
    return v[ord]
end

"""
    evaluatedAltValue(delivery::GoMetaDelivery, component, alterant::Symbol; registry::AlterantRegistry = DEFAULT_REGISTRY) -> EvaluatedAltValue

IS: THE ONE ANSWER FUNCTION — for ONE Component of the delivered tree and ONE Alterant (its registered name: `:Visib`,
`:labels`, `:id`, `:heading` in the default registry) the Engine's resolved value and its SOURCE, derived at the call from
the delivered rows and their provenance.
DOES: (1) the Component's own rows — the rows keyed on it, a Segment-carried row counting as its Line's; (2) a rowless child
inherits its parent's rows up the tree (Segment → Line → Block; never the File); (3) no rows anywhere → the Alterant's
declared default as `(value, :default)` or `(nothing, :none)` when it declares none; (4) the source: `:own` when every
deciding handle of the rows is the asked Component's own key; otherwise the first foreign deciding handle's class —
`USER_CONTEXT_GRAIN` ⇒ `:user`, the File grain ⇒ `:file`, a document grain ⇒ `:indirect` through the Component the handle
names (`via`, read from the handle's own path; `nothing` for a degenerate key) — a handle naming one of the asked LINE's own
Segments is the Line's own statement (the trailing metaSegment applies DIRECTLY to its Line — the creator's decision); a SEGMENT
without rows of its own answers as the Component whose rows it inherits answers (its Line, or its Block when the Line is rowless too),
that Component's `:own` becoming `:indirect` through it — its statement was applied to the Line, not to the Segment — and every other
source (`:indirect` through the same decider, `:user`, `:file`) unchanged, as a rowless Line's relates to its Block's; rows without any recorded origin answer `:own` on the Component itself and
`:indirect` through the carrier Component otherwise. The File answers `(nothing, :none)` — NOTHING built for it (card 6
"next"; the File's case carried past the branch (the review's C23)). An Alterant name outside the registry throws an `ArgumentError` naming the registered
names; an Alterant without a capture DECLARATION mints no rows and answers its declared default (`:default`) or `:none`; an
undeclared capture stem is derived as the walk derives it (`lowercase(altName)`). Pure: no state, no cache, no mutation of the delivery.
REASONING: one function, uniform across Alterants (the value in each Alterant's own shape, the source ONE tag), so an
Extension asks one question; the rows stay the one truth.
PURPOSE: the Extension-facing read of "what applies here and through whom". Package-public (docs/public-api.md §1.2), NOT
exported. The name is the creator's word of 2026-10-03; the per-call row scan is DEFERRED to a later
benchmark phase; the tier, the File's case and the equal-child rows are open points;
nothing here is promised before v0.7 (§6).
"""
function evaluatedAltValue(delivery::GoMetaDelivery, component::BLS.AbstractComponent, alterant::Symbol;
                   registry::AlterantRegistry = DEFAULT_REGISTRY)::EvaluatedAltValue
    idx = get(registry.alt_index, alterant, nothing)
    idx === nothing && throw(ArgumentError(string("GoMeta evaluatedAltValue: no Alterant named `", alterant,
        "` in the registry — the registered names: ", join(string.(sort!(collect(keys(registry.alt_index)))), ", "))))
    p = registry.plugins[idx]
    component isa BLS.File && return EvaluatedAltValue(nothing, :none, nothing)
    cap = p.capture
    if cap === nothing                  # no capture declaration: the walk mints NO rows — the declared default
        d = p.default
        return d isa Declared ? EvaluatedAltValue(d.value, :default, nothing) : EvaluatedAltValue(nothing, :none, nothing)
    end
    stem = _capture_stem(p)   # the walk's own derivation (annotations.jl's capture; registry.jl's effective stem) — the seat wf-s10-s2c4-check F-1
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
        return d isa Declared ? EvaluatedAltValue(d.value, :default, nothing) : EvaluatedAltValue(nothing, :none, nothing)
    end
    value = _answer_value(rows, stem, scheme)
    if component isa BLS.Segment && c !== component
        ## The creator's rule: today a metaStatement reaches a Segment INDIRECTLY only — a Segment without rows of
        ## its own answers the ANSWER of the Component whose rows it inherits (its Line; its Block when the Line is rowless too):
        ## that Component's OWN statement (the Line's trailing metaSegment's — even when the deciding handle is this Segment's own
        ## key, the carrier's: the statement was applied DIRECTLY to the Line, not to itself) reaches the Segment INDIRECTLY through
        ## it; every other source stays as that Component answers it — :indirect through the same decider, the fed profile's :user,
        ## the File's :file — exactly as a rowless Line relates to its Block (the decisions seat's F-1: the user case unchanged).
        a = evaluatedAltValue(delivery, c, alterant; registry = registry)
        return a.source === :own ? EvaluatedAltValue(a.value, :indirect, c) : a
    end
    ownkey = key_bytes(occurrence_key(ps, component; namespace = ns))
    any_origin = false
    foreign = nothing
    for r in rows, h in r.decided_by
        any_origin = true
        h == ownkey && continue
        if component isa BLS.Line
            ## the trailing metaSegment's statement is applied DIRECTLY to its Line (the creator's rule): a deciding handle that names one of
            ## the Line's OWN Segments is the Line's own statement — the Segment is its carrier, not a foreign decider
            hc = _component_of(ps, h)
            hc isa BLS.Segment && BLS.parent(ps, hc) === component && continue
        end
        foreign = h
        break
    end
    any_origin || return c === component ? EvaluatedAltValue(value, :own, nothing) : EvaluatedAltValue(value, :indirect, c)
    foreign === nothing && return EvaluatedAltValue(value, :own, nothing)
    g = _grain_of(foreign)
    g == USER_CONTEXT_GRAIN && return EvaluatedAltValue(value, :user, nothing)
    g == _DOC_GRAIN_CODES.File && return EvaluatedAltValue(value, :file, nothing)
    return EvaluatedAltValue(value, :indirect, _component_of(ps, foreign))
end
