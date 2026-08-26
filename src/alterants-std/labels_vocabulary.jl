## labels_vocabulary.jl — v0.4 T4 (T4-DESIGN §2): the Labels vocabulary ARTIFACT loader —
## std-Alterant territory (R-V04B-6 (a); content custody = the Labels lane's, R-LBL-4).
## CAPTURE at load, RE-VERIFY at publication (R-V04-37 / SEC-2's ruled shape): this file
## reads the artifact ONCE, hashes AS READ, parses THE SAME BYTES (never re-read), and
## registers the captured (digest → vocabulary) pair. NO digest adjudication happens at
## load — the declared-vs-captured comparison is `_vocabulary_collect!`'s PUBLICATION act
## (registry.jl); the DEFAULT registry publishes at module load, so a tampered shipped
## artifact fails `using GoMeta` through the publication gate (fail-closed pre-flight). A
## MALFORMED artifact fails HERE, at load (the byte grammar is fixed; witnesses drive
## temp copies only, never this file). A lane content swap updates the artifact + the
## declared literal below in ONE data-artifact version (zero Core deltas — M-AC-12).
## Per R-V04B-11 this loader carries NO reserved-name class: the Labels reserved
## spellings (`++` `--` `!!` `-` `!+`) are LANE-NAMESPACE, enforced by their absence from
## the artifact (the lane's content discipline; probe P11).
import SHA as _SHA
import ..GoMeta as GMX      # the parent (the absorb_meta precedent): the record types +
                            # STATE + the G-VOC resolver live at GoMeta top level, which
                            # the include spine defines BEFORE this file loads

"""
    LABELS_VOCABULARY_DECLARED_DIGEST

The INDEPENDENT declared pin (T4-DESIGN §2) — a literal, NEVER derived from the loaded
bytes (a self-attested digest is decoration). The tamper window the publication
re-verify closes: the artifact bytes moved without THIS literal moving.
"""
const LABELS_VOCABULARY_DECLARED_DIGEST =
    "sha256:d9d75de303b9b10a71275537d3699a267f0b9cc9c7aabeae888ba42704e88985"

"""
    _VOCAB_CACHE :: Dict{String,GMX.InlineVocabulary}

The capture cache: captured digest → the parsed vocabulary. Engine-internal MUTABLE
state — a loaded module can rewrite it (a B-2-class act, the same family as reaching
`_snapshot`); the COVERED declaration is the digest ON THE RECORD, never this cache
(T4-DESIGN §9-6). The G-VOC surface returns DEFENSIVE COPIES; the membership helpers
read only the private entries.
"""
const _VOCAB_CACHE = Dict{String,GMX.InlineVocabulary}()

"""
    _parse_labels_vocabulary(bytes, origin) -> InlineVocabulary

The artifact's FIXED byte grammar (T4-DESIGN §1): valid UTF-8 (no BOM), LF-only, no
blank/comment lines, no leading/trailing whitespace, exactly one final LF; one entry per
line in DECLARATION order; a bare `<name>` line declares `query = true`; a
`<name><TAB>query=false` line declares the write-only valve. The flags map is built
COMPLETE (every name gets an entry), so every consumer is total. Any deviation throws
the fail-closed load-error family.
"""
function _parse_labels_vocabulary(bytes::Vector{UInt8}, origin::AbstractString)
    fail(class, n) = error("GoMeta registry: labels vocabulary artifact is MALFORMED (",
        class, ") at line ", n, " of ", origin,
        " — the artifact grammar is fixed (see docs/public-api.md §3.4)")
    length(bytes) >= 3 && bytes[1] == 0xef && bytes[2] == 0xbb && bytes[3] == 0xbf &&
        fail("BOM", 0)
    text = String(copy(bytes))
    isvalid(text) || fail("invalid UTF-8", 0)
    isempty(text) && fail("empty artifact", 0)
    occursin("\r", text) && fail("CR byte", 0)
    endswith(text, "\n") || fail("missing final newline", 0)
    names = Symbol[]
    flags = Dict{Symbol,NamedTuple{(:query,),Tuple{Bool}}}()
    for (n, line) in enumerate(split(chop(text), "\n"; keepempty = true))
        isempty(line) && fail("blank line", n)
        parts = split(line, "\t"; keepempty = true)
        length(parts) > 2 && fail("extra field", n)
        name = parts[1]
        isempty(name) && fail("empty name", n)
        (startswith(name, " ") || endswith(name, " ")) && fail("whitespace-padded name", n)
        q = true
        if length(parts) == 2
            parts[2] == "query=false" || fail("unknown flag token", n)
            q = false
        end
        s = Symbol(name)
        s in names && fail("duplicate name", n)
        push!(names, s)
        flags[s] = (query = q,)
    end
    return GMX.InlineVocabulary(names, flags)
end

const _LABELS_VOCABULARY_PATH = joinpath(@__DIR__, "labels_vocabulary.txt")
Base.include_dependency(_LABELS_VOCABULARY_PATH)   # P10: without this, a content swap is
                                                   # INVISIBLE to precompiled sessions
## verify-and-capture (SEC-HC-4's load shape): READ ONCE · HASH AS READ · PARSE THE SAME
## BYTES — the artifact is never re-read
const _LABELS_ARTIFACT_BYTES = read(_LABELS_VOCABULARY_PATH)
"the digest of the bytes AS READ (captured; adjudicated against the DECLARED pin at publication only)"
const LABELS_VOCABULARY_CAPTURED_DIGEST =
    "sha256:" * Base.bytes2hex(_SHA.sha256(_LABELS_ARTIFACT_BYTES))
"the shipped Labels vocabulary, parsed from the captured bytes (38 names; the ZWJ valve `query = false`)"
const LABELS_VOCABULARY =
    _parse_labels_vocabulary(_LABELS_ARTIFACT_BYTES, "alterants-std/labels_vocabulary.txt")
_VOCAB_CACHE[LABELS_VOCABULARY_CAPTURED_DIGEST] = LABELS_VOCABULARY

"""
    _vocabulary_for_action(actionName) -> Union{Nothing,InlineVocabulary}

THE SCOPE LAW (T4-DESIGN §4; P12a): inside an engine scope the INVOKED ACTION'S owning
record's declared vocabulary governs (`nothing` declared ⇒ NO membership gate — the
vocabulary IS the record's declared content; the M-AC-12 registration-surface flip);
OUTSIDE any scope (a direct package-internal drive) the SHIPPED vocabulary governs — the
compatibility fallback keeping every bare drive byte-identical. Non-throwing on the
scope read (`Base.ScopedValues.get`).
"""
function _vocabulary_for_action(actionName::Symbol)
    st = Base.ScopedValues.get(GMX.STATE)
    st === nothing && return LABELS_VOCABULARY
    r = st.value.registry
    ai = get(r.action_index, actionName, nothing)
    ai === nothing && return LABELS_VOCABULARY   # unreachable behind _invoke_set's guard; defensive
    return GMX._resolve_vocabulary_by_index(r, r.action_to_plugin[ai])
end
