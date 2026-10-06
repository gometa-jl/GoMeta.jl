# scan.jl — THE SCAN BY ALTERANT AND THE ACCESS BY COMPONENT (stage 2's commit 5 of the v0.4 build; the plan v8.1 :57; card 4 of the
# walk; his §6 item 9.A — "an Extension may scan for all BLS Components (Block, Line, Segment or even File) who got assigned Ids and what
# kind of Ids … the Extension must be enabled to access all such information in as efficient a manner as possible, the information
# must be unambiguous, and informative").
#
# IS:   two thin reads over `evaluatedAltValue` (commit 4) — functions of their own (the session's default under R-V04B-40 (2); the alternative,
#       methods of the reader, is banked as a labelled diff beside this commit; his word of 2026-10-03 named the functions — §305,
#       R-V04B-95 — and took no alternative, which stays his to take).
# DOES: `scanAlterant` lists every Component for which the Engine RECORDED a value of ONE Alterant (its own rows — a Segment-carried row
#       counting as its Line's), each with its answer, in the tree's order; a rowless Component is not listed (it is covered as PART OF
#       its Block — his §7 item 2: the children hidden as PART OF their Block, not individually — its answer is `evaluatedAltValue`'s).
#       `evaluatedAltValues` lists every registered Alterant's answer for
#       ONE Component, in the registry's Alterant order.
# REASONING: his 9.A's two views — by Alterant across the tree, by Component across the Alterants — over the one answer function, so the
#       two views can never disagree with it or with each other.
# PURPOSE: the Extension-facing scans (R-V04B-35 (c); his 9.A). Package-public; NOT exported; the names his word of 2026-10-03 (§305; R-V04B-95), the form standing, its alternative banked.

"""
    scanAlterant(delivery::GoMetaDelivery, alterant::Symbol; registry::AlterantRegistry = DEFAULT_REGISTRY) -> Vector{Pair{BLS.AbstractComponent,EvaluatedAltValue}}

IS: THE SCAN BY ALTERANT (his §6 item 9.A) — every Component of the delivered tree for which the Engine RECORDED a value of the
Alterant (the Component's own rows; a Segment-carried row is its Line's), paired with its answer (`evaluatedAltValue`), in the tree's order
(each Block, its Lines, their Segments).
DOES: walks the tree through the door (`BLS.children`); a Component without own rows of the Alterant is NOT listed
— its answer is still `evaluatedAltValue`'s (inherited or the default); the File is never listed (NOTHING built for it, card 6 "next").
An unknown Alterant name throws `ArgumentError` naming the registered names (the scan's own refusal, before any `evaluatedAltValue` call —
the same refusal `evaluatedAltValue` gives). Pure.
REASONING: the recorded Components are the ones an Extension must find efficiently (9.A); the inherited ones are implied by their
Block (his §7 item 2) and derivable on demand.
PURPOSE: the Extension's "which Components carry this Alterant, and what". Package-public (docs/public-api.md §1.2), NOT exported;
the name kept by his word of 2026-10-03 (§305; R-V04B-95); the form — a function of its own — stands, its alternative (a method of the
reader) banked.
"""
function scanAlterant(delivery::GoMetaDelivery, alterant::Symbol;
                      registry::AlterantRegistry = DEFAULT_REGISTRY)::Vector{Pair{BLS.AbstractComponent,EvaluatedAltValue}}
    idx = get(registry.alt_index, alterant, nothing)
    idx === nothing && throw(ArgumentError(string("GoMeta scanAlterant: no Alterant named `", alterant,
        "` in the registry — the registered names: ", join(string.(sort!(collect(keys(registry.alt_index)))), ", "))))
    p = registry.plugins[idx]
    out = Pair{BLS.AbstractComponent,EvaluatedAltValue}[]
    cap = p.capture
    cap === nothing && return out                # no capture declaration: the walk mints NO rows — nothing recorded, nothing to list
    stem = _capture_stem(p)   # the walk's own derivation, as evaluatedAltValue derives it (the seat of commit 4, F-1)
    scheme = cap.attr_scheme
    ps = delivery.blsComponentTree
    store = delivery.altValues_evals
    isempty(store.records) && return out
    ns = _store_namespace(store)
    for b in BLS.children(ps)
        isempty(_rows_on(store, _path_prefix(ps, b, ns), stem, scheme)) || push!(out, b => evaluatedAltValue(delivery, b, alterant; registry = registry))
        for l in BLS.children(ps, b)
            isempty(_rows_on(store, _path_prefix(ps, l, ns), stem, scheme)) || push!(out, l => evaluatedAltValue(delivery, l, alterant; registry = registry))
            for s in BLS.children(ps, l)
                isempty(_rows_on(store, _path_prefix(ps, s, ns), stem, scheme)) || push!(out, s => evaluatedAltValue(delivery, s, alterant; registry = registry))
            end
        end
    end
    return out
end

"""
    evaluatedAltValues(delivery::GoMetaDelivery, component; registry::AlterantRegistry = DEFAULT_REGISTRY) -> Vector{Pair{Symbol,EvaluatedAltValue}}

IS: THE ACCESS BY COMPONENT — every registered Alterant's answer (`evaluatedAltValue`) for ONE Component, in the registry's Alterant order
(`registry.plugins`), each paired with the Alterant's registered name.
DOES: one `evaluatedAltValue` per Alterant; an Alterant without a capture DECLARATION answers its declared default (`:default`) or `:none`
when it declares none, an undeclared capture stem derived as the walk derives it (as `evaluatedAltValue`); the File answers `:none`
throughout. Pure.
REASONING: his 9.A's other view — a Component's whole evaluation at one read, unambiguous (one tag per Alterant) and informative
(the value, the source, the deciding Component).
PURPOSE: the Extension's "what applies to this Component, Alterant by Alterant". Package-public, NOT exported; the name his word of
2026-10-03 (§305; R-V04B-95: `evaluatedAltValues`); the form stands, its alternative banked.
"""
function evaluatedAltValues(delivery::GoMetaDelivery, component::BLS.AbstractComponent;
                    registry::AlterantRegistry = DEFAULT_REGISTRY)::Vector{Pair{Symbol,EvaluatedAltValue}}
    return Pair{Symbol,EvaluatedAltValue}[p.altName => evaluatedAltValue(delivery, component, p.altName; registry = registry) for p in registry.plugins]
end
