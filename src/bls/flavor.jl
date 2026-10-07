# flavor.jl — the per-flavor FlavorProfile records: the ONE data surface every
# armed flavor's divergence lives on (tables · policies · strictness · lead bytes ·
# the content-model Bool), read by the ONE parse loop.
#
# The record is pinned DATA (its injective digest fold left at stage 5's P1 of the v0.4 build — census row 39: a
# cache-key component no code read; the condition grammar's own profile record, whose pattern this one followed and
# whose cache key was to join it, left at stage 5's E13 — census row 1).
# The mainline threads ONE record through the ParseState `flavor` field populated
# at setup (zero call-site churn — the kwarg default): ONE loop (`parseBLS`) + ONE
# table reader (`parseLeadHeader!`) serve EVERY armed flavor over this record — the loop calls the reader
# directly (the record's header-strategy seam, a Function pointer for a fallback that no longer existed, left
# at stage 5's P1 of the v0.4 build — census row 63). The directive TABLE rows and the `fences_armed` gate Bool
# are record fields (the content-model slot is consciously kept at its inline-Bool form — the priced retreat
# position).

## The shared introducer-BODY grammar string — the SINGLE SOURCE: `_re_meta`
## (parseBLS.jl) is DERIVED from it (`Regex("^" * …)`), as are both lead-anchored walk
## recognizers (plus the record's lead), so the marker grammar cannot drift between
## parse and walk in either flavor.
## Token-delimiter law: the head must be TERMINATED by
## ws-or-EOL — the zero-width lookahead; a glued shape (`#~hide`, `#~9x`) no longer
## matches (bucket (A), resolved by the parse callers). `metaDef` is a nothing-
## preserving alternation (an empty-matching group would participate as "" and break
## the `nothing !==` guards); digit-RUN so `#~10` keeps its pinned first-digit
## semantics; `postDef` stays optional-CONSUMING so `offsets[end]==0` at EOL and the
## header offset arithmetic are byte-preserved. `hashDef` is unbounded — the depth
## clamp moved to code (`min(length, 8)`, behavior-identical to the old `{1,8}` cap).
## ## FUTURE-BLS(M6): fold into ONE profile-owned grammar — the repo carries a
## fourth, prefix-only copy in tools/export/public-overlay/notebooks_from_source.jl
## (out-of-tree).
const _RE_META_BODY_STR = raw"(?<hashDef>[~]+)(?<metaDef>[0-9]+!?|!)?(?=[\h]|$)(?<postDef>[\h])?"

## Whitespace-alphabet unification: THE delimiter class = Unicode horizontal
## whitespace — exactly the grammar's `[\h]`, unified across every token head, both
## flavors, and the before-side mid-line scanners. ONE predicate, derived from the PCRE
## class itself (never a hand-copied codepoint list, so it can never drift from the
## grammar), with an ASCII fast path for the hot scanners. Newline-class characters stay
## LINE boundaries (never in-line delimiters); zero-width format characters (U+200B et
## al.) are NOT whitespace and never delimit.
const _RE_H_WS_ONE = r"\A[\h]\z"
@inline _is_h_ws(c::Char) = (c == ' ' || c == '\t') ||
    (!isascii(c) && occursin(_RE_H_WS_ONE, string(c)))

## ─── The FlavorProfile record ─────────────────────────────────────────────────────
## (The forward declaration of `parseLeadHeader!` left with the record's header-strategy seam at stage 5's P1 of
## the v0.4 build — census row 63: the records no longer reference the reader; the loop calls it directly,
## parseBLS.jl.)

## The versioned per-flavor record. `directives` IS the data the table-driven `parseLeadHeader!` reads (the loop
## calls the reader directly — the header-strategy seam and its flip-back axis left at stage 5's P1 of the v0.4
## build, census row 63). Field notes:
##   - the six prototype fields carry their NamedTuple-era values VERBATIM (the `extensions` field, read by no
##     code, left at stage 5's P1 — census row 72);
##   - `directives`: the per-flavor directive TABLE (an `absent` verb is part of
##     the design): five rows `(char, status ∈ (:claimed, :absent), flags = today's
##     settribute flags, ws_strict, consume ∈ (:run, :single))` in the canonical
##     head-char order `- + > [ ]`. The table is the SOLE encoding of the
##     offset/consumption conventions — they are never encoded twice.
##   - `glued_policy` / `bare_policy`: what a glued/bare lead shape classifies as —
##     `:content` (the julia bucket-A sentinel — the token-delimiter law) vs
##     `:comment` (the cfam every-arm-sets-a-flag class).
##   - `fences_armed`: the content-model slot's inline-Bool form (the trivial
##     per-flavor gate Bool): :julia arms the ```-fence cluster; :c consciously declines (its docblock
##     scope fence). The slot may later be widened per the recorded content-model fallback.
##   - `lead_ncu` / `lead_cus`: the lead's codeunit width + bytes, record-carried for the lead compares (the
##     `_CFAM_LEAD_*` consts they generalized left at stage 5's P1 — census row 58).
##   CONSTRUCTION LAW: records are minted ONLY via the INNER keyword constructor
##   below (reachable directly or through the `_mk_flavor` alias) — the guard
##   surface + every derived field live there, and defining it REMOVES the default
##   positional constructor, so the bypass hazard (guards skipped) no longer type-checks. Positional construction throws
##   MethodError (witness-pinned).
##   `comment_run_strict` (the run arm's exact-token strictness — julia `##`-only
##   vs the cfam any-run comment; explicit data, NOT coupled to the glued policy)
##   · per-row `consume ∈ (:run, :single)` (the arm's offset/consumption
##   convention as table data) (the `header_strategy` identifier left with the seam at stage 5's P1 — census
##   row 63) · the struct is PARAMETRIC over the two tuple
##   fields, so every INSTANCE is fully concrete (the parse-state field stays
##   `::FlavorProfile`, the UnionAll — the loop hoists once; the declared
##   benchmark retreat is a one-line function barrier).
struct FlavorProfile{D<:Tuple,C<:Tuple{Vararg{UInt8}}}
    flavor_tag::Symbol
    lead::String
    comment_run_char::Char
    hide_marker::String
    hide_fold_prefix::String
    re_meta_leaded::Regex
    directives::D
    glued_policy::Symbol
    bare_policy::Symbol
    fences_armed::Bool
    comment_run_strict::Bool
    lead_ncu::Int
    lead_cus::C

    function FlavorProfile(; flavor_tag::Symbol, lead::String, comment_run_char::Char,
                     hide_marker::String, hide_fold_prefix::String,
                     directives::Tuple, glued_policy::Symbol, bare_policy::Symbol,
                     fences_armed::Bool, comment_run_strict::Bool)
        @assert isascii(lead) && ncodeunits(lead) >= 1
        ## The mis-paired-marker guard — the first mechanical guard this hazard has ever had:
        ## a hide marker that does not open a comment in its own language would emit "hidden"
        ## lines as LIVE target-language code (silent at the GoMeta level). NECESSARY, not
        ## sufficient: the language-convention half (rustdoc/doxygen collisions) and the
        ## hide-TIME output hazards (`\`-EOL splicing, multi-line string interiors —
        ## FORK-README bounds 3) stay documented per-flavor checks.
        @assert startswith(hide_marker, lead)
        ## The DISPATCH-CLASS half of the marker guard — begins-with-lead alone is
        ## INSUFFICIENT: a marker that merely begins with a lead can still dispatch as
        ## METADATA (`//~ `), CLOSE (`//] `), a structural directive, or the TEXT lead
        ## (`// `) — hidden lines would then mint live metadata, fire close semantics, or
        ## degrade classification on re-ingestion. The first character after the lead must
        ## land in the ordinary-COMMENT dispatch class.
        local _after = SubString(hide_marker, ncodeunits(lead) + 1)
        @assert !isempty(_after)
        @assert first(_after) ∉ ('~', ']', ' ', '\t', '-', '+', '>', '[')
        ## The comment run doubles the lead's LAST character (Julia `##`-run / C-family
        ## `///`-run). Coupled by assert: a flavor inheriting a run char that is not its
        ## lead's last char would silently mis-classify every run line.
        @assert comment_run_char == last(lead)
        ## The run char must not COLLIDE with the reader's other arm triggers — under the
        ## fixed arm order a colliding run char is mis-ordered EITHER way ('~' would be
        ## shadowed BY the meta arm; a directive char would be PREFERRED by the run arm
        ## over its table row). Latent-only for '#'/'/'/'%'; closed at mint.
        @assert comment_run_char ∉ ('~', '-', '+', '>', '[', ']')
        ## Fold eligibility is NOT a "doubled token" test (wrong for `//`) — the test is
        ## the flavor's BLS-comment CLASSIFICATION + this per-flavor eligibility prefix:
        ## `hide_fold_prefix` = the byte prefix a COMMENT-CLASSIFIED component must carry
        ## (post-indent) to be fold-eligible — hidden, it takes NO additional hide marker
        ## (ensure-token; the render already reads as a comment). Julia: "##" (the
        ## BLS-comment form; bare `#`/glued `#x` comments stay MARKED — the ##-initial
        ## scope); C-family: "//" (every C comment is fold-eligible; `// ` TEXT lacks
        ## :comment and stays marked — the class split does the work).
        @assert !isempty(hide_fold_prefix) && startswith(hide_fold_prefix, string(first(lead)))
        ## Record guards — the directive table's closed row set: exactly the five head
        ## chars in the canonical order, each row (char, status, flags, ws_strict,
        ## consume); an :absent row carries NO flags.
        @assert map(r -> r.char, directives) == ('-', '+', '>', '[', ']')
        @assert all(r -> r.status === :claimed || r.status === :absent, directives)
        @assert all(r -> r.status === :claimed || isempty(r.flags), directives)
        ## The consumption-verb vocabulary — the reader's offset arithmetic is row data,
        ## closed at mint.
        @assert all(r -> r.consume === :run || r.consume === :single, directives)
        ## The POLICY vocabularies close at mint too — the reader's `=== :content`
        ## compares would silently treat a typo'd Symbol as `:comment`.
        @assert glued_policy in (:content, :comment)
        @assert bare_policy in (:content, :comment)
        ## The `]`-arm invariant, lifted to the table: a row
        ## whose flags type a component Meta WITHOUT a :depthN flag MUST carry
        ## :ignoreThisMeta — the one flag between the Meta-context :hasMetaStr synthesis
        ## and the absorb machinery's depth refusal.
        @assert all(r -> !(:containsMeta in r.flags) || (:ignoreThisMeta in r.flags),
            directives)
        ## INTERIM law: the four reserved directive arms (`-`, `+`, `>`, `[`) are
        ## claimable by :julia ONLY — every other flavor declares them :absent. The `]`
        ## close row is claimable by any flavor.
        @assert flavor_tag === :julia ||
            all(r -> r.char == ']' || r.status === :absent, directives)
        ## ASCII lead (asserted above) ⇒ byte width == char count; the tuple form
        ## is the record-carried byte tuple (the `_CFAM_LEAD_CU` const it generalized left at stage 5's P1 — census row 58).
        lead_cus = Tuple(codeunits(lead))
        return new{typeof(directives), typeof(lead_cus)}(flavor_tag, lead,
            comment_run_char, hide_marker, hide_fold_prefix,
            ## `\Q…\E` quotes the lead verbatim (PCRE) — `//` carries no metacharacter
            ## today, but the derivation must not silently assume that.
            Regex(string(raw"^\Q", lead, raw"\E", _RE_META_BODY_STR)),
            directives, glued_policy, bare_policy, fences_armed, comment_run_strict,
            ncodeunits(lead), lead_cus)
    end
end

## The documented construction alias (kept for call-site continuity — the guard
## surface itself lives in the inner constructor above).
_mk_flavor(; kwargs...) = FlavorProfile(; kwargs...)

const FLAVOR_JULIA = _mk_flavor(
    flavor_tag       = :julia,
    lead             = "#",
    comment_run_char = '#',
    hide_marker      = "## ",
    hide_fold_prefix = "##",      # the fold-eligibility prefix (BLS comments)
    ## The table IS the reader's data — `parseLeadHeader!` reads these rows
    ## (status·flags·ws_strict·consume) + the policies + the strictness Bool.
    ## `consume` IS the offset convention (`-` run-consumes; the single-unit arms
    ## nextind-or-1).
    directives       = (
        (char = '-', status = :claimed, flags = (:startNewBlock,),    ws_strict = false, consume = :run),
        (char = '+', status = :claimed, flags = (:continued,),        ws_strict = false, consume = :single),
        (char = '>', status = :claimed, flags = (:insertSubContent,), ws_strict = false, consume = :single),
        (char = '[', status = :claimed, flags = (:startNewBlock,),    ws_strict = false, consume = :single),
        (char = ']', status = :claimed, flags = (:startNewBlock, :ignoreThisMeta,
            :containsMeta, :stopAttachmentToMeta),                    ws_strict = true,  consume = :single),
    ),
    glued_policy     = :content,  # token-delimiter-law bucket-A sentinel: glued shapes are plain content
    bare_policy      = :content,  # bare '#' at EOL: sentinel 0, neighbourhood-inherited
    fences_armed     = true,      # the ```-fence cluster IS this flavor's content model
    comment_run_strict = true,    # :comment ⇔ EXACTLY `##` + ws-or-EOL (token-delimiter law)
)

const FLAVOR_CFAM = _mk_flavor(
    flavor_tag       = :c,        # ONE `//` flavor serves C and Rust demo files
    lead             = "//",
    comment_run_char = '/',       # `///`, `////` = comment runs (rustdoc lines:
                                  # classification-only, comment-inherits-neighbourhood)
    hide_fold_prefix = "//",      # every C comment is fold-eligible (`// ` TEXT
                                  # lacks :comment and stays marked — the class split
                                  # does the work)
    hide_marker      = "//# ",    # hide is a VISIBILITY operation — hidden
                                  # metadata REMAINS LIVE metadata, so the
                                  # metadata-alive render is BY DESIGN, and this
                                  # marker is deliberately NOT a special parse verb.
                                  # Special forms are ws-strict by documented
                                  # convention; glued `//#…` (e.g. `//#include`) is a
                                  # plain comment.
    ## The four Literate directive arms are NOT claimed by this flavor (`//-`, `//+`,
    ## `//>`, `//[note]` are ordinary comments via the guardrail arm); `//]` close is
    ## claimed ws-strict with the flag set VERBATIM from the `#]` original.
    directives       = (
        (char = '-', status = :absent, flags = (), ws_strict = false, consume = :single),
        (char = '+', status = :absent, flags = (), ws_strict = false, consume = :single),
        (char = '>', status = :absent, flags = (), ws_strict = false, consume = :single),
        (char = '[', status = :absent, flags = (), ws_strict = false, consume = :single),
        (char = ']', status = :claimed, flags = (:startNewBlock, :ignoreThisMeta,
            :containsMeta, :stopAttachmentToMeta),                    ws_strict = true,  consume = :single),
    ),
    glued_policy     = :comment,  # every glued `//`-shape is an ordinary comment (host
                                  # divergence; no bucket-A sentinel)
    bare_policy      = :comment,  # bare `//` = the graceful empty comment
    fences_armed     = false,     # fence machinery consciously NOT armed (scope fence:
                                  # no `"""` string form / markdown-fence convention here)
    comment_run_strict = false,   # every `//`-run length is a comment (host
                                  # convention; the post-run offset is byte-load-bearing)
)

## The third flavor is PURE DATA — it adds ZERO parser-file bytes (never a third
## loop copy; the SAME `parseLeadHeader!` serves it). The .tex classification
## vocabulary is the cfam-parallel default — non-lead lines fall through to Code,
## `% `-led lines take the Text arm; the deeper .tex CONTENT-vocabulary question
## stays OPEN and recorded, not invented here.
## Recorded bounds (witness-pinned): verbatim environments DECLINED (`%~` inside
## \begin{verbatim} IS live metadata — fences_armed=false, no environment
## tracking); the newline-eating hide hazard (a `%%`-hidden line's % eats its
## typeset newline — TeX joins the lines; a doc+fixture bound, not a defect);
## catcode changes that re-define `%` are out of scope (the trigraph-class
## posture).
const FLAVOR_LATEX = _mk_flavor(
    flavor_tag       = :latex,
    lead             = "%",
    comment_run_char = '%',
    hide_marker      = "%% ",
    hide_fold_prefix = "%%",      # every %%-led comment is fold-eligible (the cfam-
                                  # parallel class split: `% ` TEXT stays marked)
    ## The deletion-note shape verbatim: the four reserved arms :absent (INTERIM
    ## law — claimable by :julia only); `%]` close claimed ws-strict with the flag
    ## set from the `#]` original.
    directives       = (
        (char = '-', status = :absent, flags = (), ws_strict = false, consume = :single),
        (char = '+', status = :absent, flags = (), ws_strict = false, consume = :single),
        (char = '>', status = :absent, flags = (), ws_strict = false, consume = :single),
        (char = '[', status = :absent, flags = (), ws_strict = false, consume = :single),
        (char = ']', status = :claimed, flags = (:startNewBlock, :ignoreThisMeta,
            :containsMeta, :stopAttachmentToMeta),                    ws_strict = true,  consume = :single),
    ),
    glued_policy     = :comment,  # a glued `%`-shape is an ordinary comment
    bare_policy      = :comment,  # a bare `%` = the graceful empty comment
    fences_armed     = false,     # no ``` / """ conventions in .tex — declined
    comment_run_strict = false,   # any %-run length is a comment (cfam-parallel)
)

"""
    flavor_for(tag::Symbol)

The closed flavor inventory — total-or-throw, NO fallback: an unknown tag throws the stable message below
at `goMeta`'s flavor resolve, before any parse (docs/public-api.md §3.4; the typed config-time refusal left at
stage 5's E8 of the v0.4 build — census row 30; a silently-Julia fallback would produce a plausible render
with wrong tree bytes and zero diagnostics the moment a new flavor arms).
"""
function flavor_for(tag::Symbol)
    tag === :julia && return FLAVOR_JULIA
    tag === :c     && return FLAVOR_CFAM
    tag === :latex && return FLAVOR_LATEX   # the pure-data row
    error("flavor_for: unknown flavor_tag ", repr(tag),
        " — the closed inventory is (:julia, :c, :latex) and there is NO fallback")
end

## (The `_CFAM_LEAD_*` consts and the `_RE_META_LEADED_*` compatibility aliases left at stage 5's P1 of the v0.4
## build — census row 58, his §223: their comments cited forkchecks/s2_battery.jl and forkchecks/differential_flavor.jl,
## neither in the repository; the record carries the lead's width and bytes.)
## ## FUTURE-BLS(non-ascii-lead): a non-ASCII lead needs nextind-chained skipping
## and a stated codeunit-vs-character unit at every arithmetic site.

## ─── The flavor-GENERIC lead helpers (the `_cfam_*` generalization — the
## record-carried `lead_ncu`/`lead_cus` drive them) ───────────────────────────
@inline function _starts_with_lead(profile::FlavorProfile, s::AbstractString, i::Int)::Bool
    ## BOTH bounds guarded (the cfam original's law: `codeunit` under `@inbounds`
    ## elides checkbounds — an i <= 0 would be memory-unsafe, not a throw).
    (1 <= i && i + profile.lead_ncu - 1 <= ncodeunits(s)) || return false
    @inbounds for k in 0:(profile.lead_ncu - 1)
        codeunit(s, i + k) == profile.lead_cus[k + 1] || return false
    end
    return true
end

"""
    findLeadAfterSpace(profile, s) -> (pos, endOfLine)

THE inline-opener scanner: finds the first horizontal whitespace
followed by the profile's lead token. The ws+lead inline rule is the
architectural meta-liveness carrier — the rule lives HERE, structurally, never
per-flavor.
"""
function findLeadAfterSpace(profile::FlavorProfile, s::AbstractString)::Tuple{Int,Bool}
    i = firstindex(s)
    e = lastindex(s)
    while i <= e
        c = s[i]
        ## Whitespace-alphabet unification: the unified `[\h]` class.
        if _is_h_ws(c) && i < e
            ni = nextind(s, i)
            ## `_starts_with_lead` carries its own upper-bound check for the whole
            ## lead width (the cfam original's do-NOT-simplify law).
            if _starts_with_lead(profile, s, ni)
                return (i, false)
            end
        end
        i = nextind(s, i)
    end
    return (e, true)
end
