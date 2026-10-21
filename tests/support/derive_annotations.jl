# derive_annotations.jl — THE TEST-LAYER DERIVER of the reference files' fifth column.
#
# IS:   `derive_annotations_golden(delivery) -> Vector{UInt8}` — the five-column byte form of a delivery's evals rows
#       (the twelve annotation pins' form), its fifth column DERIVED through the BLS Component tree and the door's
#       content function `BLS.content` — never read from the Engine (the creator's decision: "it is read from the BLS Component
#       tree through BLS's own access function"). Lives in the support hub (module TestSupport) because the golden
#       runner AND two unit-layer witnesses produce this form (`unicode_cure_tests.jl`, `latex_flavor_tests.jl`; a third, the fed heading's, was removed) (the hub is the one
#       file every layer loads once).
# DOES: (1) the four columns are the public reader's rows (`readAltValuesEvals`, the reader's sort order) — one row per
#       line, `<attr>\t<repr(value)>\t<polarity>\t<hex(cell_handle)>`, the attr column RAW as the Engine's former five-column
#       producer wrote it (the public four-column form encodes it; the twelve pins carry no delimiter and
#       are byte-identical either way — a conscious choice). (2) The fifth column: the row's
#       Component is the one whose key WITHOUT the empty-origin tail the handle starts with (the answer function's prefix
#       rule — a Segment-carried row keyed on its Line counts as the Line's; the step count leads the path section, so no
#       other Component's key is a prefix); `hex(BLS.content(tree, component))`. (3) A handle that MORE THAN ONE Component's
#       prefix matches is an error (fail-closed — the prefix rule promises uniqueness). (4) A handle that NO Component
#       carries yields an EMPTY fifth column: what the tree holds for that handle (the non-document plane — a heading fed
#       through the configuration's user profile — once produced such a row; now a
#       heading in the profile refuses at the read, and no shipped path produces one — the arm kept). Nothing here
#       asserts on such a row.
# REASONING: the pins stay byte-identical without the Engine's stored copy because the test layer produces the fifth column
#       itself; the proof is binary — the golden runner compares these bytes with the pinned file: one differing byte
#       fails the run.
# PURPOSE: the golden runner's producer of `ser` (`tests/golden/golden_tests.jl`) and the producer of the two
#       unit witnesses that read the five-column form.

# every Component of the tree in tree order, through the door (`BLS.root`, `BLS.children` — the walk of `evaluatedAltValue`'s resolver)
function _tree_components(ps)
    out = GM.BLS.AbstractComponent[GM.BLS.root(ps)]
    for b in GM.BLS.children(ps)
        push!(out, b)
        for l in GM.BLS.children(ps, b)
            push!(out, l)
            for s in GM.BLS.children(ps, l)
                push!(out, s)
            end
        end
    end
    return out
end

# the namespace the delivered rows were keyed under, decoded from the first handle (the key schema's fixed field order:
# 1 byte · UInt16-BE length · the UTF-8 bytes); `:default` for an empty store
function _rows_namespace(store)
    isempty(store.records) && return :default
    h = store.records[1].cell_handle
    length(h) >= 3 || return :default
    n = (Int(h[2]) << 8) | Int(h[3])
    length(h) >= 3 + n || return :default
    return Symbol(String(h[4:(3 + n)]))
end

# a Component's key bytes WITHOUT the empty-origin tail (the two zero bytes of a zero origin-step count)
_key_prefix(ps, c, ns::Symbol) = GM.key_bytes(GM.occurrence_key(ps, c; namespace = ns))[1:(end - 2)]

_hasprefix(h::Vector{UInt8}, p::Vector{UInt8}) = length(h) >= length(p) && all(i -> h[i] == p[i], eachindex(p))

"""
    derive_annotations_golden(delivery) -> Vector{UInt8}

The five-column annotations form of a delivery — the reader's four columns and, fifth, the hex of the row's Component's
verbatim content through the door (`BLS.content`); a handle no Component carries yields an empty fifth column; a handle
more than one Component's prefix matches is an error. The twelve reference files' producer in the test layer.
"""
function derive_annotations_golden(delivery)
    ps = delivery.blsComponentTree
    ns = _rows_namespace(delivery.altValues_evals)
    comps = _tree_components(ps)
    prefixes = [_key_prefix(ps, c, ns) for c in comps]
    parts = String[
        "# annotations golden — sorted (cell_handle, attr, value); final-verdicts-only.\n",
        "# columns: <attr>\\t<value>\\t<polarity>\\t<cell_handle = occurrence-key bytes, hex>\\t<content fingerprint, hex>\n",
    ]
    for (h, attr, val, pol) in GM.readAltValuesEvals(delivery.altValues_evals)
        idx = findall(p -> _hasprefix(h, p), prefixes)
        length(idx) <= 1 || error("derive_annotations_golden: the handle $(bytes2hex(h)) starts with the key prefix of $(length(idx)) Components — the prefix rule promises one")
        bytes = isempty(idx) ? UInt8[] : GM.BLS.content(ps, comps[idx[1]])
        push!(parts, string(attr, '\t', repr(val), '\t', pol, '\t', bytes2hex(h), '\t', bytes2hex(bytes), '\n'))
    end
    return Vector{UInt8}(codeunits(join(parts)))
end
