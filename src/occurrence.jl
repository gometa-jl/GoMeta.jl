# occurrence.jl — the normalized structural occurrence handle: the evals-plane identity key.
#
# IS: the evals-plane identity substrate — `OccurrenceKey`, a pure, re-derivable, schema-versioned
#     STRUCTURAL handle for a parsed cell, and its deterministic byte serialization `key_bytes`.
#     The evals store keys by THIS handle (content demotes to a per-record fingerprint field).
# DOES: (1) `occurrence_key(parse, cell; origin=nothing, namespace=:default)::OccurrenceKey` —
#     TOTAL on parsed cells, NEVER throws: derives the cell's root→cell STORE-EXPLICIT ordinal
#     path by upward `idParent` walk, normalizing every component to its EXTENSION-CHAIN ROOT
#     first (`idExtended` chase — order-, multiplicity-, and type-preserving: each chain's root
#     identity is unique, so distinct non-equivalent chains never normalize identically); the
#     `origin` kwarg carries the SEGMENT-grain origin split for segment-carried evals (the
#     remap keys a Segment's evals on its Line — target = the Line's path, origin = the Segment's
#     OWN path — injective by construction; the byte span demotes to metadata, never identity).
#     (2) `key_bytes(k)::Vector{UInt8}` — deterministic FIXED-field-order serialization
#     (length-prefixed namespace + fixed-width big-endian steps), injective per namespace.
# REASONING: identity must be re-derivable from the parse alone (purity) and must not
#     collapse distinct occurrences the way content-addressing does (the WARN_VERDICT_COLLISION
#     distinct-cell class is impossible by construction). STORE-EXPLICIT means the engine's
#     signed-id convention (positive ⇒ [1] direct store, negative ⇒ [2] insert store) NEVER
#     crosses this boundary — each path step carries an explicit store tag + an unsigned ordinal.
#     NO HASHING core-side: the key is plain structural data; an adapter layer hashes.
#     TOTALITY arm: a broken parent link, an out-of-bounds store index, or a hop-cap overrun
#     appends the distinguished TRUNCATED marker step (store = 0x00 — no natural step uses it)
#     and stops — total + deterministic, and degenerate keys can never alias well-formed ones.
# PURPOSE: cheap/fast identity for the evals plane that survives insertion within a parse and
#     normalizes extension overflow invisibly; cross-EDIT identity is an adapter mint layer's
#     job (stated limit), and cross-document uniqueness is the namespace supplier's obligation
#     (per-call store).
#
# LOAD-ORDER: included directly after `bls/BLS.jl` (depends on BLS ONLY);
#     everything downstream (state/annotations/absorb/apply) may reference it.

"""
    OccurrenceStep(store, ordinal)

One store-explicit path element: `store` = 0x01 (direct `[1]` store) | 0x02 (insert `[2]` store) |
0x00 (the TRUNCATED marker — degenerate-walk arm only); `ordinal` = the UNSIGNED position within
that store. The engine's signed-id sign encoding never crosses this boundary.
"""
struct OccurrenceStep
    store::UInt8
    ordinal::UInt32
end

const OCCURRENCE_SCHEMA_VERSION = 0x01

"""
    OccurrenceKey

The normalized occurrence handle: `schema_version` (replay provenance),
`namespace` (opaque PURE input — supplied, never inferred), `grain` — the HANDLE-CLASS tag:
the DOCUMENT ladder is its capacity-coded sub-vocabulary (the cell's `Component{N}` N as
UInt8-clamped code: Segment=1, Line=10, Block=70, File=210 — all ≤ 0xd2), and the
NON-DOCUMENT handle-class plane is 0xd3–0xfe (0xff is CARVED OUT permanently: it is the
UInt8-clamp landing point of an oversized capacity and must never name a class; the one
resident class today is the user context, `USER_CONTEXT_GRAIN` below), `path` (for document
keys: root→cell store-explicit ordinals, extension-normalized; for user-context keys: the
single region-ordinal step at v0.2 — the MINT's first-step shape, not a class invariant),
`origin` (the segment-carried origin path for the segment-carried remap; EMPTY ⇒ the key addresses
the cell itself). Ordering note: `namespace` precedes `grain` in `key_bytes`, so byte-sort
guarantees are NAMESPACE-SCOPED — one process call carries one namespace, so within every
result store the non-document classes sort after all document rows; consumers DECODE the
class at its fixed offset, never infer it from row position.
"""
struct OccurrenceKey
    schema_version::UInt8
    namespace::Symbol
    grain::UInt8
    path::Vector{OccurrenceStep}
    origin::Vector{OccurrenceStep}
end

# The fixed DOCUMENT grain ladder (type → grain code + parent type). Component{N} N values
# are the engine-stable capacities (BLS.jl:148-151); UInt8-safe (max 210 = 0xd2 — the
# document plane's ceiling; a capacity above it would collide with the class plane and is
# refused by the load-time pin below, never clamped into it).
# SINGLE-SOURCE ladder codes: the ceiling pin asserts THIS tuple, and the
# _grain_code methods read from it — a future capacity edit cannot bypass the pin
const _DOC_GRAIN_CODES = (Segment = 0x01, Line = 0x0a, Block = 0x46, File = 0xd2)
_grain_code(::BLS.Segment) = _DOC_GRAIN_CODES.Segment
_grain_code(::BLS.Line)    = _DOC_GRAIN_CODES.Line
_grain_code(::BLS.Block)   = _DOC_GRAIN_CODES.Block
_grain_code(::BLS.File)    = _DOC_GRAIN_CODES.File

# ── the NON-DOCUMENT handle-class plane (0xd3–0xfe; 0xff carved out) ────────────────────
# The user context: the profile-feed surface's own recordable identity. Minted ONLY by the
# feed routine (per-call config inputs; deterministic); one handle per fed meta REGION —
# today one feed = one region = ordinal 1; future cascading feeds mint 1..k in feed order.
const USER_CONTEXT_GRAIN = 0xe0
@assert USER_CONTEXT_GRAIN > 0xd2 && USER_CONTEXT_GRAIN < 0xff  # the plane law, load-pinned
@assert all(g <= 0xd2 for g in values(_DOC_GRAIN_CODES))        # the ladder ceiling (single source)

"""
    user_context_key(namespace::Symbol, ordinal::Integer) -> OccurrenceKey

The user-context handle mint (the class's ONE constructor): schema 1, the caller's own
namespace, `USER_CONTEXT_GRAIN`, a single direct-store step carrying the fed-region
ordinal, empty origin. Deliberately a SIBLING of `occurrence_key` — that constructor's
total-on-parsed-cells / pure-from-parse contract is untouched; this mint's inputs are
per-call configuration only.
"""
user_context_key(namespace::Symbol, ordinal::Integer) =
    OccurrenceKey(OCCURRENCE_SCHEMA_VERSION, namespace, USER_CONTEXT_GRAIN,
        [OccurrenceStep(0x01, UInt32(ordinal))], OccurrenceStep[])
_parent_type(::BLS.Segment) = BLS.Line
_parent_type(::BLS.Line)    = BLS.Block
_parent_type(::BLS.Block)   = BLS.File
_parent_type(::BLS.File)    = BLS.File   # terminal; the walk stops AT File before using this

const _TRUNCATED_STEP = OccurrenceStep(0x00, 0x0000_0000)
# The hop cap bounds the WHOLE upward walk (one count per parent LEVEL — a parent-link cycle
# through valid slots therefore also terminates at the cap) AND, separately, each per-level
# extension-root chase. It is a LEVEL bound, not a tree-size bound: chain-256 (the deepest bench
# input) mints max path length 3 with zero truncations (probed empirically). 64 is far above any
# legal File>Block>Line>Segment depth + chase.
const _MAX_HOPS = 64

# Fetch a component of type `T` by SIGNED id from the parse stores; `nothing` on any
# out-of-bounds/zero id (the totality arm — never throws).
function _fetch(ps::BLS.ParseState, ::Type{T}, signedId::Int) where {T<:BLS.AbstractComponent}
    signedId == 0 && return nothing
    stores = get(ps.componentsPDict, T, nothing)
    stores === nothing && return nothing
    vec = signedId > 0 ? stores[1] : stores[2]
    idx = abs(signedId)
    (1 <= idx <= length(vec) && isassigned(vec, idx)) || return nothing
    return vec[idx]
end

# Normalize a component to its EXTENSION-CHAIN ROOT (chase `idExtended` toward the original;
# 0 ⇒ already the root). Bounded; a broken/cyclic chase returns `nothing` (totality arm).
function _extension_root(ps::BLS.ParseState, c::T) where {T<:BLS.AbstractComponent}
    hops = 0
    while true
        ext = BLS.getElement(c.cmpntNamedInt, :idExtended)
        ext == 0 && return c
        hops += 1
        hops > _MAX_HOPS && return nothing
        nxt = _fetch(ps, T, ext)
        nxt === nothing && return nothing
        c = nxt
    end
end

# One store-explicit step for a (already extension-normalized) component.
function _step_of(c::BLS.AbstractComponent)
    idc = BLS.getElement(c.cmpntNamedInt, :idComponent)
    idc == 0 && return nothing
    return OccurrenceStep(idc > 0 ? 0x01 : 0x02, UInt32(abs(idc)))
end

# The root→cell store-explicit path (extension-normalized at every level). TOTAL: any broken
# link / cap overrun yields a path ending in the TRUNCATED marker — deterministic, never throws.
function _ordinal_path(ps::BLS.ParseState, cell::BLS.AbstractComponent)
    rev = OccurrenceStep[]          # collected cell→root, reversed at the end
    c = cell
    hops = 0
    while true
        hops += 1
        if hops > _MAX_HOPS
            push!(rev, _TRUNCATED_STEP); break
        end
        root = _extension_root(ps, c)
        if root === nothing
            push!(rev, _TRUNCATED_STEP); break
        end
        if root isa BLS.File
            # The engine has exactly ONE File root, definitionally [1][1] (every driver/suite
            # walk reads componentsPDict[File][1][1]) — encoded as the fixed (direct, 1) step.
            push!(rev, OccurrenceStep(0x01, 0x0000_0001)); break
        end
        st = _step_of(root)
        if st === nothing
            push!(rev, _TRUNCATED_STEP); break
        end
        push!(rev, st)
        parent = _fetch(ps, _parent_type(root), BLS.getElement(root.cmpntNamedInt, :idParent))
        if parent === nothing
            push!(rev, _TRUNCATED_STEP); break
        end
        c = parent
    end
    return reverse!(rev)
end

"""
    occurrence_key(parse, cell; origin = nothing, namespace = :default) -> OccurrenceKey

Plan Contract 1 — TOTAL on parsed cells, never throws, pure function of its inputs (no clock /
random / env / global state). `origin` (a Segment, typically) mints the segment-carried
target/origin split of the segment-carried remap: the KEY's `path` addresses `cell` (the remap TARGET,
e.g. the owning Line) while `origin` carries the origin cell's OWN path — two same-kind inline
Segment evals on one Line stay distinct through the remap (injective by construction).
`namespace` is the opaque pure input (constraint (5)) — supplied by the caller (the capture seam
reads it from `GoMetaConfig`), NEVER inferred here.
"""
function occurrence_key(ps::BLS.ParseState, cell::BLS.AbstractComponent;
                        origin::Union{Nothing,BLS.AbstractComponent} = nothing,
                        namespace::Symbol = :default)
    return OccurrenceKey(
        OCCURRENCE_SCHEMA_VERSION,
        namespace,
        _grain_code(cell),
        _ordinal_path(ps, cell),
        origin === nothing ? OccurrenceStep[] : _ordinal_path(ps, origin),
    )
end

"""
    key_bytes(k::OccurrenceKey) -> Vector{UInt8}

Plan Contract 2 — the deterministic FIXED-field-order serialization: `schema_version (1B)` ·
`namespace` (UInt16-BE byte-length prefix + UTF-8 bytes) · `grain (1B)` · `path` (UInt16-BE step
count + per step `store (1B)` + `ordinal (UInt32-BE)`) · `origin` (same shape). Length-prefixed
variable field + fixed-width steps ⇒ INJECTIVE per namespace by construction (no two distinct
keys share bytes). NO hashing — these are the plain structural bytes.
"""
function key_bytes(k::OccurrenceKey)::Vector{UInt8}
    ns = codeunits(String(k.namespace))
    out = Vector{UInt8}()
    sizehint!(out, 6 + length(ns) + 5 * (length(k.path) + length(k.origin)) + 4)
    push!(out, k.schema_version)
    _push_u16!(out, length(ns))
    append!(out, ns)
    push!(out, k.grain)
    _push_steps!(out, k.path)
    _push_steps!(out, k.origin)
    return out
end

function _push_u16!(out::Vector{UInt8}, n::Integer)
    v = UInt16(min(n, typemax(UInt16)))
    push!(out, UInt8(v >> 8)); push!(out, UInt8(v & 0xff))
    return out
end

function _push_steps!(out::Vector{UInt8}, steps::Vector{OccurrenceStep})
    _push_u16!(out, length(steps))
    for s in steps
        push!(out, s.store)
        push!(out, UInt8((s.ordinal >> 24) & 0xff)); push!(out, UInt8((s.ordinal >> 16) & 0xff))
        push!(out, UInt8((s.ordinal >> 8) & 0xff));  push!(out, UInt8(s.ordinal & 0xff))
    end
    return out
end
