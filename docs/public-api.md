# public-api.md — GoMeta's declared public API (the semver surface) + the error-mode catalogue

**Status:** the declared public API and error-mode catalogue of GoMeta `0.3.0` (alpha maturity).

---

## §0 — Scope

**IS.** The reference for `GoMeta`'s **public API** — the declared, semver-versioned surface a
consumer (a script, a downstream tool, or another implementation of the GoMeta language) programs
against — together with the **typed error-mode catalogue** (the codes a `goMeta` call can surface
as `Diagnostic`s) and the honest partition of which codes are armed, which are deferred, and which
crashes remain latent or are guarded by a stable refusal.

**DOES.** (1) names the **exported** surface (§1.1) and the **package-public** supporting names
(§1.2); (2) names the **two output surfaces** through which every observable byte flows (§1.3 —
the sole-surface invariant); (3) restates each public signature + its contract (§2); (4) enumerates
the eight-row typed error catalogue with its honest partition (§3); (5) records the
CRLF-normalization convention (§4), the explicitly **deferred / not-v0** surfaces (§5), and the
additive-only **versioning policy** (§6).

**REASONING.** The API is **TOTAL over the CONFIG-TIME catalogued surface** — an invalid `config`
never throws an uncaught exception; it fail-closes into a `PROCESS_ERROR` result carrying a typed
`Diagnostic`. The absorb- and apply-plane rows are the honest exception: they can still throw at
v0 — the §3 partition (the E-04 crash-origin row of §3.1 and the stable-message refusals of §3.4).
Honesty over completeness: the rows not yet armed (E-07's pending mint, the E-04 crash-origin and
the E-06 guarded refusal — §3.1/§3.2) and the crashes still latent or refused with a stable
message (§3.4) are documented **as such**, never papered over with a fabricated typed code; the
other condition-path refusals ARE typed since the closed-interpreter flip (§3.2).

**PURPOSE.** The stable contract a consumer programs against and a reviewer audits the surface
against — the human-readable mirror of the machine-checkable export set (`names(GoMeta)`, asserted
by `tests/unit/public_surface_tests.jl`) and of the refusal behavior the shipped witnesses assert
(`tests/unit/error_message_tests.jl` · `tests/unit/slot_overflow_tests.jl` ·
`tests/unit/malformed_meta_tests.jl` · `tests/unit/arg_guard_tests.jl` ·
`tests/unit/condition_cap_tests.jl`).

## §1 — The public surface

### §1.1 — Exported names (the re-exported semver surface)

`using GoMeta` brings **exactly these four** names into scope — the declared public surface:

| Name | Kind | One-line |
|---|---|---|
| `goMeta` | function | the pipeline entry — `goMeta(bytes; config, registry) -> GoMetaResult` |
| `altValues_evals` | function | the evaluated Alterant values, per piece of the file (the production surface) |
| `GoMetaConfig` | type | the v0 input options |
| `GoMetaResult` | type | the typed pipeline result |

`names(GoMeta)` is exactly this set plus the eleven §1.2 public names (and the module name) — the
**machine-checkable surface oracle** that `tests/unit/public_surface_tests.jl` asserts against
this document: the four exported names via `Base.isexported`, the §1.2 names via `Base.ispublic`.

**Qualified import stays canonical for hygiene + multi-implementation use.** `import GoMeta;
GoMeta.goMeta(bytes)` is unaffected by these exports and is the recommended form when (a)
namespace hygiene matters or (b) two implementations of the language are loaded side-by-side —
qualified calls keep every name's origin explicit. The shipped test suite uses the qualified
form. Exporting serves the single-implementation `using` convenience case; it never forces a
`using`.

### §1.2 — Supporting public names (package-public; qualified access, NOT exported)

These are part of the documented public surface — declared with Julia's `public` keyword, so
`names(GoMeta)` and tooling see them — but are **not** exported: reach them qualified
(`GoMeta.<name>`):

- `GoMeta.outputs(result) -> (blsStructure_bytes, render_bytes)` — the native structural-tree +
  reference-render pair (the verification surface; §1.3 and `docs/CANONICAL-OUTPUT.md`).
- `GoMeta.serialize_evals(altValues_evals(result)) -> Vector{UInt8}` — the canonical,
  deterministic, binary-safe serialization of the evals surface.
- `GoMeta.content_fingerprint(result) -> Vector{Tuple{Vector{UInt8},Vector{UInt8}}}` — the
  sibling accessor of the evals surface: per-record `(cell_handle → content)` pairs carrying
  each cell's verbatim content bytes, in the SAME sort order as `altValues_evals(result)`
  (the contract a consumer may zip on). The occurrence-handle KEY is the identity; the
  content is the reader-facing text — the shipped `find_by_label.jl` and
  `notebooks_from_source.jl` tools join exactly this way.
- `EvalRecord` / `EvalStore` — the per-cell store underlying `altValues_evals`.
- `ProcessStatus` (the enum) + its values `PROCESS_OK` / `PROCESS_ERROR`.
- `Diagnostic` `{code::Symbol, severity::Symbol, message::String, context::Any}` — the typed,
  non-throwing diagnostic record.
- `AlterantRegistry` + the `const DEFAULT_REGISTRY` — the deterministic alterant inventory (the
  `goMeta` default registry). A custom `registry`'s mappings over the BUILT-IN inventory are
  honored per call (e.g. the Visib action→settribute mapping); custom plugin IMPLEMENTATIONS are
  outside v0's supported surface — the verdict capture reads the built-in alterant instance types.

They are not exported; reach them qualified. `tests/unit/public_surface_tests.jl` asserts every
§1.2 name is `public` and NOT exported (no accidental leak, no silent demotion).

### §1.3 — The two output surfaces (the sole-surface invariant)

Every byte a consumer obtains from the engine comes through exactly one of two surfaces; no
internal module (`emit`, `walk`, `BLS`) ever needs importing for output:

1. **`altValues_evals(result)`** — the evaluated Alterant values, per piece of the file: the
   deterministic, final-verdicts-only per-cell map `(cell_handle, attr, value, polarity)` — the
   query-facing write payload (GoMeta's semantic deliverable; the production surface).
2. **`GoMeta.outputs(result) -> (blsStructure_bytes, render_bytes)`** — the verdict-free structural tree
   half + the `jl-share-v1` reference render (the verification surface). `render_bytes` is
   produced by the package-**internal** emit; it is reached **only** through `GoMeta.outputs`,
   never exported.

## §2 — Signatures + contracts

**⚠ Trust note:** under the DEFAULT profile no condition text is ever evaluated (the closed
interpreter, §3.2). Only under the explicitly opt-in full-eval mode — two operator acts, see the
SECURITY section of `README.md` — can processing input you did not write execute arbitrary code.

### `goMeta(bytes::Vector{UInt8}; config::GoMetaConfig = GoMetaConfig(), registry::AlterantRegistry = DEFAULT_REGISTRY) -> GoMetaResult`

(`goMeta` consumes raw bytes; from a `String` use `Vector{UInt8}(codeunits(s))` — or `read(path)`
for a file, as in the README quickstart.)

Pure, deterministic, **TOTAL over the CONFIG-TIME catalogued surface** (an invalid `config` never
throws uncaught; absorb/apply-plane catalogued failures can still throw at v0 — the §3
partition). `GoMetaResult` carries the run's cargo: `status::ProcessStatus` ·
`diagnostics::Vector{Diagnostic}` (the invariant is **non-OK ⇒ non-empty diagnostics**) ·
`verdicts::EvalStore` (the store behind `altValues_evals`) · `state::ProcessState` — INTERNAL and
semver-UNSTABLE at v0: depend only on `status`, `diagnostics`, `altValues_evals(result)`, and
`GoMeta.outputs(result)`. No filesystem / clock / environment read. **These three guarantees —
purity, determinism, isolation — cover the whole default-configured run:** a `{…}` condition body
is parsed and evaluated by the closed no-eval interpreter, so it cannot read the filesystem, the
clock or the environment, and cannot perform effects. (Under the explicitly opt-in
`:full_eval_v1` extension mode — see the SECURITY section of `README.md` — a condition body IS
host-evaluated, and the guarantees then hold only for inputs whose conditions are free of side
effects.) An invalid `config`
fail-closes into a `PROCESS_ERROR` `GoMetaResult` **before any parse or render** — the input
bytes are never touched; no parse, verdict, or render work occurs (§3.1).

### `GoMetaConfig(; profile = :jl_share_v1, flavor_tag = :julia, parse_range = nothing, user_mh_profile = nothing, namespace = :default)`

The v0 input options (additive evolution only). `profile::Symbol` — the closed default is
`:jl_share_v1`; the two OPT-IN names `:jl_share_v1_full_parse` / `:jl_share_v1_full_eval` are
also config-valid and additionally require the explicitly-included opt-in extension (the two-act
law, §3.2). The remainder of this paragraph describes the default: the share-profile proper is
`:jl_share_v1`. `flavor_tag::Symbol` — the content flavor (`:julia`); RESERVED at v0: the value
is accepted and stored but read by no v0 code path (any value is accepted and ignored;
validation is deferred at v0).
`namespace::Symbol` — the occurrence-key namespace every `altValues_evals` cell handle is scoped
under (`:default` by default; the key's length-prefixed namespace segment, §1.4). One
constructor-time guard: a namespace over 65535 bytes throws an `ArgumentError` at
`GoMetaConfig(...)` construction — before any `goMeta` run, hence outside the fail-close rows
below (which require a constructed config).
`parse_range::Union{Nothing,UnitRange{Int}}` — `nothing` ⇒ the whole input; a given range
**requires** `first == 1` and a non-empty range. Its unit is **line indices of the input**, and a
`last` beyond the input's final line is accepted without complaint — `1:99` on a two-line input
returns `PROCESS_OK` and renders both lines, with no diagnostic (a `first ≠ 1` or an empty range is
the `ERR_RANGE_INVALID` fail-close instead, §3.1).
`user_mh_profile::Union{Nothing,String}` — RESERVED / experimental: `nothing` (default) ⇒ no feed,
byte-identical to the no-feed path; a `String` ⇒ that metaLine BODY is seeded into the reserved
user slot of the meta-hierarchy before the walk (first-wins override of authored Visib actions).
THE USER CONTEXT: the feed carries its own recordable identity — an EXPLICIT `head` in a fed
profile records ONE row against the minted user-context handle (grain `0xe0`; the profile's
verbatim bytes as the fingerprint column), even on META-FREE input; queued fed actions apply only
where document cells exist. The deriving heading form refuses on this surface (no placement), and
a CONDITIONED heading refuses (no evaluable settribute state at this version). New rows appear
ONLY when this field is set. Deliberately scope-limited at v0.

### `altValues_evals(result::GoMetaResult) -> Vector{Tuple{Vector{UInt8},Symbol,Any,Bool}}`

The evaluated Alterant values, per piece of the file: the final map
`(cell_handle, attr, value, polarity)` — per-cell rows plus handle-classed non-cell rows (a fed
explicit heading records against the user-context handle class) — **sorted by `(cell_handle,
attr, value)`** for a deterministic, content-hashable order; **final-verdicts-only** (deduped at
capture); **empty when no metaLine exists on ANY surface** (the fed profile IS a metaLine body);
outside the `(tree, render)` pair at v0. The `(attr, value)` domains at v0:
`:label_<name> => true` (one row per accumulated label) · `:visib => :hide | :show | :discard`
(the winning visibility verdict) · `:id_<name> => Int16` (experimental Id values, one row per
non-default field) · `:head_<level> => String` (author-supplied section headings, document-
or fed-profile-authored — the §2 Heading action; `head_<level>_<k>`, k ≥ 2 in source order,
for same-level repeats on one recorded handle); `polarity` is always `true` at v0 (the field
is reserved for a future negated-verdict encoding). Consumers should treat UNKNOWN attribute
families as opaque — skip them, never error: the enumeration lists the v0 families, and new
families may arrive as additive evolution within the documented versioning policy (§6). `GoMeta.serialize_evals(altValues_evals(result))` is its canonical
byte form.

### `GoMeta.outputs(result::GoMetaResult) -> (blsStructure_bytes::Vector{UInt8}, render_bytes::Vector{UInt8})`

The native, always-available verification surface (§1.3) — package-public, reached qualified.
`blsStructure_bytes` = the verdict-free structural
serialization of the final parse tree; `render_bytes` = the `jl-share-v1` reference render. Total
on any OK result, with one documented qualification: more than one surviving Visib verdict on a
single cell meets the render plane's stable guard error (§3.4). The render plane's string
indexing is character-safe — including a multibyte-whitespace indent — and is witnessed
(a GUARDED edge). On a non-OK (config-time `PROCESS_ERROR`) result it yields the
**empty** `(tree, render)` ("no render attempted"). The NamedTuple field order is
`(blsStructure_bytes, render_bytes)`. See `docs/CANONICAL-OUTPUT.md` for the full surface definition.

### The metaLine argument forms (v0)

An alterant ACTION token may carry a parenthesized, comma-split argument list — `action(arg1,
arg2)` — parsed with the metaLine and handed to the action when it fires. The v0 forms:

- **Labels (the `:` action) — DOCUMENTED, both forms:** repeated one-word labels
  (`#~ :label1 :label2`) AND the parenthesized list (`#~ :(label1, label2)`) — equivalent; each
  label is checked against the engine's closed whitelist, in both the label-setting and the
  condition-query roles (an unknown label ⇒ the §3.4 stable refusal, subject to §3.4's
  evaluation-scope note). The corpus-documented labels are `:label1`..`:label5`; since `0.3.0`
  the closed whitelist additionally accepts a fixed pictograph vocabulary (e.g. `:💡`, `:📝`,
  `:🔥` — the full set is the refusal message's accepted-set listing; byte-exact names, no
  normalization: an emoji variant with different bytes is a different — unknown — name).
- **The Heading action (`head`) — DOCUMENTED at this release; evaluated-surface only:** section
  titles are metadata. A metaLine whose FIRST token starts with a `""`-fenced string lowers
  to the deriving `head` call — `#~2 "Title"` ≡ `#~2 head("Title")` — and the canonical calls
  are position-free: `head("Title")` (level derived from the carrying metaLine's own depth)
  and `head("Title", 2)` (explicit, context-free). Captured headings surface as
  `head_<level>` rows in `altValues_evals` (same-level repeats on one recorded handle:
  `head_<level>_<k>` — the `altValues_evals` domain line above) and have NO render effect. The recorded level
  follows the author's own numbering — the `#~` digit or the explicit level argument, never
  a renormalized outline level: `#~ "T"` records `head_1`, `#~2 "T"` and `head("T", 2)` both
  record `head_2`, `#~0 "T"` records `head_0` (a file-level heading), and an inline segment
  meta (`x = 1 #~ "T"`) records the documented constant `head_10` — the one fixed exception;
  an inline DEPTH DIGIT (`x = 1 #~2 "T"`) is accepted by the structural parse but does not
  affect the recorded level (still `head_10`). The explicit level argument accepts any
  integer literal and records AS GIVEN — it is not constrained by the structural 0–8 depth
  window (`head("T", 9)` records `head_9`; `head("T", 10)` records `head_10`, sharing the
  inline constant's name; out-of-window and negative levels are accepted — level hygiene is
  the author's concern at v0). The `head` TEXT slot is the one
  String-accepting argument position on the one String-accepting action — every other slot
  of every action, including `head`'s level slot, refuses a String. A NON-first quoted token
  on a metaLine is reserved and refuses (today via the §3.4 malformed-metaLine punctuation
  refusal). `head` is not queryable in conditions (a condition naming it evaluates false —
  unlike the bare Id atoms, whose condition use is the §3.4 pending edge), and a heading's
  own condition may use settribute state only — evaluated ONCE at the heading's own line,
  GATING the recording (false means no row); a query atom there meets a typed refusal.
  Refusal catalogue: §3.4.
- **Id actions (`cell` / `parent` / `file`) — EXPERIMENTAL at this release:** one integer value
  argument (`#~ cell(7)`), Int16 domain. The Id alterant is a v0 placeholder implementation;
  this syntax may change — do not build durable content on it
  at v0. Inherited Id values do not cross a block separation at v0.
- **Visib actions (`show` / `hide` / `discard`) take NO arguments;** an empty list (`hide()`) is
  accepted as the bare form.
- **Malformed arguments** (wrong arity; non-parsable or overflowing values) raise the stable
  `"GoMeta apply: invalid arguments …"` refusal (§3.4) — never a raw stack trace.
- **Condition-side atoms** (`{ cell(7) }`-class queries inside `{}`) route through the closed
  condition intake instead: non-label arguments meet the typed argument-domain refusal there, and
  the BARE unqueryable atom is the E-07 pending-mint edge (§3.2/§3.4).

## §3 — The typed error-mode catalogue

`Diagnostic = {code::Symbol, severity, message, context}`; a catalogued failure is a typed
`Diagnostic` — **never** a bare `error()`. The eight catalogued rows fall into three classes
(§3.1–§3.3); §3.4 additionally documents the latent crashes and the stable-message refusals that
are not catalogued typed codes.

### §3.1 — Non-condition codes (4): 2 armed config-time + 1 crash-origin with deferred typed conversion + 1 GUARDED

| Code | Status | Trigger |
|---|---|---|
| `ERR_UNKNOWN_PROFILE` (E-03) | config-time, **armed + typed** | `config.profile` outside the three profile names `{:jl_share_v1, :jl_share_v1_full_parse, :jl_share_v1_full_eval}` — fail-closed `PROCESS_ERROR`, no parse, verdict, or render work attempted (an opt-in name passes THIS row and refuses later at profile resolution unless the opt-in extension is explicitly included — the two-act law, §3.2) |
| `ERR_RANGE_INVALID` (E-08) | config-time, **armed + typed** | `config.parse_range` with `first ≠ 1`, or an empty range |
| `ERR_VISIB_NO_FLAG` (E-04) | apply-path **crash-origin** (typed conversion deferred) | a Visib verdict carries no set flag at write-back |
| `ERR_DEPTH_OUT_OF_WINDOW` (E-06) | **GUARDED** — stable untyped refusal; typed conversion deferred | a `#~9`-style **digit** depth beyond the meta-hierarchy's depth window raises the stable-message `ErrorException` "meta depth out of range …" at the depth lookup (§3.4) |

E-03 / E-08 are armed: a bad profile/range returns a `PROCESS_ERROR` `GoMetaResult` carrying the
typed code, with `GoMeta.outputs` yielding empty `(tree, render)`. E-04 (apply-path) is the
remaining crash-origin whose **typed conversion is deferred at v0**:
its current crash-reachability is a documented v0 edge.
E-06 is **GUARDED**: for a digit depth outside the window the depth lookup refuses with the stable
message "meta depth out of range …" (§3.4); its typed conversion is likewise deferred
at v0.

### §3.2 — Condition codes — TYPED at the closed-interpreter flip (this release; eval retired from the default path)

**Two intake modes ship (both available, the safe one by default).** The DEFAULT profile
`:jl_share_v1` runs the closed interpreter described here. Two OPT-IN profiles —
`:jl_share_v1_full_parse` (full Julia grammar accepted, still nothing executed) and
`:jl_share_v1_full_eval` (a strict superset of the safe grammar: everything the safe grammar
accepts behaves identically, and only text beyond it is parsed as Julia and EVALUATED) — require
TWO explicit operator acts: `include`-ing `extensions/condition_modes_opt_in.jl` and then naming
the profile. Neither act is reachable from document content, so no document can widen its own
intake (README SECURITY).

The condition path is the **closed interpreter**: condition text is parsed into a bounded
condition AST (or a typed refusal `Diagnostic`) and evaluated as DATA by the engine itself. The
query-argument grammar is DECLARED (a `':'`-prefixed one-word label, comma-separated, one trailing
comma permitted; an all-whitespace text is the zero-argument form) — anything else meets one typed
refusal, and richer argument syntax is reached through the opt-in modes above, where it is
accepted as data. At the metaLine seam a refusal still ABORTS the statement with the same stable
message text the previous engine raised, so no input's observable outcome changed with the swap;
routing the typed carriers into the result's diagnostic list instead of the abort is a later,
separately-gated motion.

| Code | Trigger |
|---|---|
| `ERR_UNKNOWN_CONDITION_KEY` (E-01) | **typed** — a condition atom outside the derived whitelist of state-refs and action names |
| `ERR_CONDITION_CAP` (E-02) | **typed** — the condition scan exhausts a profile cap (29 scan steps, whitespace counted; or the raw-byte / grouping-depth walls) with non-whitespace input unconsumed, or a label key is left unterminated — a refusal, never a silent truncation; each mint carries its governing wall or window size in the `Diagnostic`'s context |
| `ERR_CONDITION_ARG_DOMAIN` | **typed** — a query argument outside the declared argument grammar above |
| `ERR_CONDITION_PARSE` | **typed** — the intake's grammar refusals: an empty `{}` body · an unterminated argument list · a malformed or unterminated condition key · a worded label key carrying a parenthesized argument list · an unparsable operator sequence |
| `ERR_CONDITION_UNQUERYABLE_ALT` (E-07) | `cell` / `parent` / `file` used as a condition atom (Id has no queryable instance) — **typed mint PENDING**: the shape still aborts raw at evaluation (documented honest edge, §3.4) |

### §3.3 — Handled class (NOT an error): E-05 — meta-free input

A meta-free input is **not** an error: on the NO-FEED path `goMeta` returns `PROCESS_OK` with zero
alterant work and a byte-exact passthrough render (a head-bearing fed profile still mints its
user-context row; a refusal-carrying feed aborts regardless of document meta-freeness). It carries
no typed code — it is a normal success path.
(An input whose only meta is inline is NOT this class: inline `#~` actions on content lines DO
apply — `docs/SYNTAX-AND-SEMANTICS.md` §9.)

### §3.4 — Known latent crashes + stable-message refusals (NOT catalogued typed codes)

These are the honest edges of the v0 engine. Entries marked GUARDED are refusals with a stable
message (no longer raw crashes); the rest remain latent, documented as such — **not** assigned a
fabricated typed code:

- **The >7-actions-per-slot overflow — GUARDED:** accumulating more alterant actions in one
  meta-hierarchy slot than the queue capacity (7 at v0) raises a stable-message `ErrorException`
  ("slot action capacity …") at the enqueue guard — never a raw `BoundsError`. The ≤7-per-slot
  limit is a documented v0 bound. Witnesses:
  `tests/unit/slot_overflow_tests.jl`.
- **The malformed-metaLine crash — GUARDED:** malformed metaLines raise a stable-message
  `ErrorException` ("malformed metaLine …") in `parseAlt` (`src/absorb/absorb_meta.jl`) — never a
  raw `BoundsError`. The refused classes: a meta region yielding no alterant token (e.g. `#~ ,`);
  stray punctuation at the action-name position (e.g. `#~ , discard` — the parser never skips
  ahead to the next identifier); and a token glued to a closing `)` or `}` (`hide()junk`,
  `hide{isCode}show` — a closing bracket must be followed by end-of-input or whitespace). VALID
  input is unaffected (corpus 7/7 byte-exact).
  Witnesses: `tests/unit/malformed_meta_tests.jl`.
- **The quoted-string lane — GUARDED (stable messages from birth):** an argument list
  carrying a `"` meets "unterminated quoted argument" (a `"` never closed), "malformed
  quoted argument" (a quote glued to bare text, a stray quote, or more than one span in
  one token), or "string argument not accepted" (a WELL-FORMED quoted argument anywhere
  except the `head` action's TEXT slot — the one String-accepting position; every other
  slot of every action, including `head`'s level slot, refuses a String). The heading
  lane adds its own siblings: "unterminated quoted heading", "empty heading text" (an
  empty `""` heading is refused by ratified v0 semantics; relaxing it later would be a
  compatible widening), and "heading without a document context" (the deriving form on the
  fed-profile surface, where nothing gives it a placement; the explicit
  `head(text, level)` form is context-free). The condition walls carry their own stable
  messages: "alterant-state query in a heading condition" (a heading condition may test
  only settribute predicates at v0) and "a conditioned heading in a profile feed"
  (fed-heading conditions are reserved). The backslash is RESERVED inside every
  quoted span — "backslash in a quoted argument" / "backslash in a quoted heading" — so
  a future escape grammar can land as a purely additive widening without reinterpreting
  any shipped document. Witnesses: `tests/unit/heading_recognizer_tests.jl`.
- **The out-of-window meta depth — GUARDED:** the refusal is witnessed on the **DIGIT** depth
  form — a digit depth marker outside the v0 window (`#~9`, `#~99` — v0 supports `#~` through
  `#~8`, and digit `0` addresses the file level, accepted) raises
  the stable-message `ErrorException` ("meta depth out of range …") at the depth lookup —
  never a raw conversion crash. In-window depths work unchanged. Note: `#~10` parses its
  first digit only and behaves as depth 1.
- **Empty and malformed condition bodies — GUARDED:** an EMPTY condition block (`{}` or
  `{ }`) raises the stable-message `ErrorException` ("empty condition block …") — an
  unconditional action is written without `{}`; a body that does not form a complete
  condition expression (e.g. `{isCode &&}` or `{|}`) raises "unparsable condition …".
  Working conditions are unaffected byte-for-byte.
- **The multi-inline-meta limit — GUARDED:** more than one inline `#~` marker on ONE line
  raises the stable-message `ErrorException` ("more than one inline meta segment …") EARLY,
  at parse time — never a success report followed by an output-time throw. v0 accepts at
  most one inline meta segment per line; one inline marker, explicit `#]` closers, meta
  LINES with marker-free trailing comments, and consecutive meta lines all work unchanged.
  A trailing comment that itself contains a ` #~` sequence counts as a second marker and is
  refused.
- **The directive-adjacency crash class — GUARDED at `0.2.3`:** a structural-directive form
  (`#-`, `#+`, `#[` or `#>`-initial — prefix-fired, so ordinary `#----` dividers and `#->`
  arrows are in the class) DIRECTLY adjacent to metadata raises a stable-message
  `ErrorException` EARLY, at parse time, at both grains: a directive fragment on the same
  line directly after an inline `#~` meta segment or a `#]` closer
  ("a structural-directive segment …" — an intervening plain fragment, a ` # note` or
  ` ## note`, defuses the adjacency), and a directive LINE whose PRECEDING carried
  context is meta — directly after a metaLine, a meta block, or a code/text line ENDING
  in an inline meta segment or `#]` closer ("a structural-directive line …" — a blank
  line between does not defuse the adjacency; the trigger is the carried segment
  context, wider than metaLine/meta-block adjacency alone). Pre-`0.2.3` both lanes
  crashed raw (a `MethodError`, or a wrong-class depth
  refusal blaming a metaLine the author never wrote). The escapes — write the divider
  `##`-initial (plain content, rides even a meta block inertly) or put a content line
  between — are named in the LINE-grain message; the segment-grain message asks you to
  separate the directive from the metadata and names its intervening-fragment escape.
  One measured in-fence corner: inside an OPEN
  multi-line string, `#+`/`#>` interior lines remain string content even directly after
  inline metadata (accepted; a walk-invisible mistype, harmless), while the `#-`/`#[`
  in-fence twins refuse. Directive forms anywhere else — file start, between code lines,
  after an interposed content line or benign comment fragment — are unaffected, and these
  comment forms remain reserved GoMeta syntax space at v0. Witnesses:
  `tests/unit/reserved_adjacency_tests.jl`.
- **The over-cap condition silent mis-render — now the TYPED E-02:** a condition whose scan
  exhausts a profile cap with non-whitespace input unconsumed meets the typed `ERR_CONDITION_CAP`
  refusal at the closed interpreter's scan (§3.2; the `Diagnostic` carries the governing wall) —
  the refusal exists so a truncated condition can never evaluate as if complete. The abort still
  raises the same stable message text at the metaLine seam (§3.2's routing note). A cap-hit whose
  remainder is only whitespace is semantically complete and stays accepted. Per-atom scan
  exhaustion surfaces separately as the malformed/unterminated-key refusals. Witnesses:
  `tests/unit/condition_cap_tests.jl`.
- **The unknown-alterant refusal:** an out-of-registry alterant name throws a stable, stage-honest,
  bounded `ErrorException` ("GoMeta absorb: unknown alterant action …"). Its typed-`Diagnostic`
  conversion is deferred (the E-01 family).
- **The unknown-label refusal:** **label names are validated in BOTH roles** against the engine's
  closed whitelist — a name APPLIED as a label (`#~ :labelX`, including the conditional form
  `:labelX{ … }`) and a label QUERIED in a condition (`{ :labelX }`) each raise the stable
  `ErrorException` `"GoMeta apply: unknown label …"`, which names the accepted set — the
  corpus-documented `:label1`..`:label5` plus, since `0.3.0`, the fixed pictograph vocabulary
  (the §2 argument-forms contract). One evaluation-scope
  note: the condition-role refusal fires where the query is actually consulted — in a region that
  carries no labels at all (no valid label was ever set there), the query is never consulted and
  the atom simply evaluates false; likewise a condition-side label after an already-winning true
  atom in a `,`/`||` chain is not queried (short-circuit), so it is not reached to refuse.
  Witnesses: `tests/unit/error_message_tests.jl` (both roles).
- **The store-`[2]` insertion path** — a latent insertion path not exercised by any v0 input.
- **The absorb-plane grammar refusals (the same stable-message family):** beyond the entries
  above, the metaLine/condition grammar refuses with stable `GoMeta absorb:` messages on: an
  unterminated argument list (a `(` never closed) · an unterminated condition block (a `{` never
  closed) · an unterminated or malformed condition key (including a `:` that does not introduce a
  single one-word label) · an unknown condition key (an atom that is neither a component
  state-ref nor a registered action name) · a duplicate argument list or condition block on one
  alterant clause · a misplaced label token · stray punctuation at the action-name position · a
  token glued to a closing `)` or `}` · the over-cap condition (the dedicated entry above).
  At the render plane, more than one surviving Visib verdict on a single cell meets the stable
  `GoMeta emit:` guard error (see `docs/SYNTAX-AND-SEMANTICS.md` §13 on the multi-Visib surface).
  Each refusal is stable and points at this section; most name the offending token, region, or
  bracket count.
- **The action-args walls — GUARDED:** malformed alterant-action ARGUMENTS — non-parsable or
  overflowing Id values and wrong-arity forms, including arguments on Visib actions — raise the
  stable `"GoMeta apply: invalid arguments for alterant action …"` `ErrorException` at the
  apply-plane `_invoke_set` seam. Working forms are unaffected (the §2 argument-forms contract).
  Condition-side atoms with non-label arguments (`:label1{ cell(7) }`, `{ cell(x) }`) now meet
  the TYPED argument-domain refusal at the closed intake (§3.2) — they never reach evaluation.
  The remaining raw edge is the BARE unqueryable atom (`{ cell }` / `{ parent }` / `{ file }`):
  the E-07 shape, whose typed mint is pending (§3.2). Witnesses:
  `tests/unit/arg_guard_tests.jl`.

**Message stability:** every input-reachable engine-layer message a v0 input can trigger through
the parse/absorb/apply/emit pipeline is STABLE and explanatory (stage-honest prefix
`GoMeta parse:` / `GoMeta absorb:` / `GoMeta apply:` / `GoMeta emit:`, the offending token
bounded, what v0 accepts, this section as the pointer); three catalogued messages are
parse-plane — the multi-inline-meta refusal and the two directive-adjacency refusals
(segment grain and line grain, `0.2.3`) above. The not-input-reachable internal checks say
"GoMeta internal invariant violated … please report". The vendored parse layer's OTHER messages
keep their existing forms; they are not part of the typed catalogue above.

Additionally, a non-fatal `:warning` `Diagnostic` — `WARN_VERDICT_COLLISION` — is emitted (the run
continues) when two byte-identical cells receive conflicting verdicts; cell-id disambiguation is
deferred.

## §4 — CRLF normalization (documented, not an error)

Both setup paths chomp `\r\n` — line **endings** normalize to LF; CONTENT-line **content** bytes
stay faithful for arbitrary bytes, including invalid UTF-8 (documented engine behavior for BOTH
invalid-byte classes — lone invalid bytes and decode-requiring sequences such as overlong
encodings; the shipped suite does not exercise invalid-byte content). The
**meta-line plane indexes on character boundaries**: non-ASCII inside a metaLine parses
correctly, and — the whitelist and action set being ASCII-named at v0 — a non-ASCII label or
action meets the stable unknown-label/unknown-action refusal naming the FULL token
(a GUARDED edge). Goldens are LF. This is a documented normalization, not an error. See
`docs/CANONICAL-OUTPUT.md`.

## §5 — Deferred / not-v0 (do not program against these at v0)

- **Growth beyond the v0 subset** — the language grows by design; the v0 subset forecloses none
  of it. `using()` is a **reserved** name — do not define or rely on it.
- **Cross-implementation conformance tooling** — a conformance interface + adapter (validating
  independent implementations of the language against the shared corpus) exists as internal
  tooling and is not part of the v0 package surface.

## §6 — Versioning policy

Evolution is **additive-only from this first published release forward**: new public names /
fields are added; a published exported name is never silently removed or repurposed (a
removal/rename is a breaking change handled with a deprecation under full re-validation). No
deprecation debt exists at this release. `Project.toml` carries the version; the alpha maturity states
the surface honestly — it may still move before `1.0`, additively wherever possible.
