# public-api.md — GoMeta's declared public API (the semver surface) + the error-mode catalogue

**Status:** the declared public API and error-mode catalogue of GoMeta `0.4.0` (candidate; the v0.4
build's branch `cc/v04-delivery` in progress — its stages and every ruling in the build record
`plan/2026-08-24-gometa-v04-build/`; alpha maturity). Backward compatibility with 0.3.x is NOT
promised (the v0.4 ruling); the breaking-change register ships with the release.

---

## §0 — Scope

**IS.** The reference for `GoMeta`'s **public API** — the declared, semver-versioned surface a
consumer (a script, a downstream tool, or another implementation of the GoMeta language) programs
against — together with the **typed error-mode catalogue** (the codes a `goMeta` call can surface
as `Diagnostic`s) and the honest partition of which codes are armed, which are deferred, and which
crashes remain latent or are guarded by a stable refusal.

**DOES.** (1) names the **exported** surface (§1.1) and the **package-public** supporting names
(§1.2); (2) names the Engine's output surface — `altValues_evals` (+ `serialize_evals`),
the Engine's delivered surface after the move — and the development tool's (tree, render) pair, obtained only
through `Main.BasicRenderer.outputs` loaded by the one loader and pinned byte-exact by the test layer (§1.3); (3) restates each public signature + its contract (§2); (4) enumerates
the typed error catalogue with its honest partition (§3 — the 0.3.x rows as the tables list them, plus the v0.4
registration/door rows of §3.5); (5) records the
CRLF-normalization convention (§4), the explicitly **deferred / not-v0** surfaces (§5), and the
**versioning policy** (§6: clean cuts — no compatibility promise — until at least v0.7; R-V04B-61).

**REASONING.** The API is **TOTAL over the CONFIG-TIME catalogued surface** — an invalid `config`
never throws an uncaught exception; it fail-closes into a `PROCESS_ERROR` result carrying a typed
`Diagnostic`. The absorb- and apply-plane rows are the honest exception: they can still throw at
v0 — the §3 partition (the stable-message refusals of §3.4; the E-04 crash-origin row of §3.1 RETIRED at stage 3's
commit 4 of the v0.4 build — its origin was the Visib write-back). Honesty over completeness: the rows not yet armed
(E-07's pending mint and the E-06 guarded refusal — §3.1/§3.2) and the crashes still latent or refused with a stable
message (§3.4) are documented **as such**, never papered over with a fabricated typed code; the
other condition-path refusals ARE minted typed since the closed-interpreter flip, the statement still
aborting at the absorb seam (§3.2's preamble).

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
| `goMeta` | function | the pipeline entry — `goMeta(bytes; config, registry) -> GoMetaDelivery` |
| `readAltValuesEvals` | function | the reader over the evals rows — the evaluated Alterant values, per piece of the file (the production surface) |
| `GoMetaConfig` | type | the v0 input options |
| `GoMetaDelivery` | type | the delivered object of a run — its four public parts, in his pipeline order (R-V04B-89): `blsComponentTree`, `altValues_evals`, `status`, `diagnostics` |

`names(GoMeta)` is exactly this set plus the §1.2 public names (38 since stage 5's E9 of the v0.4 build — the three vocabulary slot types and the G-VOC triple REMOVED, §6; 44 since stage 2's commit 9b of the v0.4 build, R-V04B-43 (1) — `content_fingerprint` REMOVED; 45 since commit 6, R-V04B-35 (e) — `childDiffers`; 44 since commit 5 — `scanAlterant`, `evaluatedAltValues`; 42 since commit 4 — `evaluatedAltValue`, `EvaluatedAltValue`; 40 since commit 0, R-V04B-58 — the parser module `BLS`; 39 since R-V04B-24 (2026-09-12): the
ten of 0.3.x that remain — `outputs` REMOVED, §6 —, the six lifecycle names, the twenty record-vocabulary names — `Alterant` is the
record's canonical name and `PlugIn` its PUBLIC 0.4.x deprecation alias, R-V04B-5 — and the
T4 G-VOC query triple `vocabulary`/`vocabulary_member`/`vocabulary_queryable`; and the module
name) — the
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

- `GoMeta.serialize_evals(readAltValuesEvals(result.altValues_evals)) -> Vector{UInt8}` — the canonical,
  deterministic, binary-safe serialization of the evals surface; its `attr` column ENCODED since 0.4.0's stage-2
  commit 7a (a backslash, tab, newline or carriage return in an attribute name escaped as `\\`, `\t`, `\n`, `\r` —
  one row, one line, four columns; the shipped families serialize byte-identically).
- `EvalRecord` / `EvalStore` — the type of one evals row (`cell_handle`, `attr`, `value`, `polarity`; the field `content` REMOVED at 0.4.0's stage-2 commit 9b — a piece's text is read from the BLS Component tree through `GoMeta.BLS.content`, R-V04B-43 (1), the register row in §6; since 0.4.0's stage-2 commit 2 THE ONE PROVENANCE FIELD `decided_by::Vector{Vector{UInt8}}` — the handles of the statements that produced the row, in application order: the deciding statement's for a single-valued mode, the contributing statements' for an accumulating one, a heading row's own carrier — R-V04B-35 (b), (d); the name his confirmed scenarios' word, his at stage 2's review), and the type of the part `altValues_evals` that holds them (the reader's argument; its rows unchanged — R-V04B-35 (a)).
- `GoMeta.evaluatedAltValue(delivery, component, alterant; registry = DEFAULT_REGISTRY) -> EvaluatedAltValue` — THE ONE ANSWER FUNCTION
  (since 0.4.0's stage-2 commit 4; R-V04B-35 (c)): for ONE Component of the delivered tree and ONE Alterant (its registered
  name) the resolved value and its SOURCE — `:own` · `:indirect` through a named Component · `:user` · `:file` · `:fallBack`
  (reserved) · `:default` · `:none` — derived at the call from the delivered rows and their `decided_by`; the contract in §2;
  the name his word of 2026-10-03 (OWNER-WORDS §305; R-V04B-95); the tier and the File's case carried past the branch (the review's C23).
- `EvaluatedAltValue` — the answer record `(value, source, via)`: `value` in the Alterant's own shape, `source` ONE tag, `via` the
  deciding Component for `:indirect`, else `nothing`.
- `GoMeta.scanAlterant(delivery, alterant; registry = DEFAULT_REGISTRY) -> Vector{Pair{Component,EvaluatedAltValue}}` — THE SCAN BY
  ALTERANT (since 0.4.0's stage-2 commit 5; his §6 item 9.A): every Component for which the Engine RECORDED a value of the
  Alterant (its own rows), with its answer, in the tree's order; a rowless Component is not listed (its answer is `evaluatedAltValue`'s).
- `GoMeta.evaluatedAltValues(delivery, component; registry = DEFAULT_REGISTRY) -> Vector{Pair{Symbol,EvaluatedAltValue}}` — THE ACCESS BY
  COMPONENT: every registered Alterant's answer for ONE Component, in the registry's Alterant order. The names are his word of
  2026-10-03 (§305; R-V04B-95: `scanAlterant` kept, `evaluatedAltValues`); the form — functions of their own — stands, its alternative
  (methods of the reader) banked (`receipts/S8-branch/ALTERNATIVE-s2c5_reader-methods.txt`), his to take.
- `GoMeta.childDiffers(delivery, component, alterant; registry = DEFAULT_REGISTRY) -> Bool` — THE CHILD-DIFFERS SIGNAL (since
  0.4.0's stage-2 commit 6; R-V04B-35 (e); his §37 item 4.2): `true` when the Component's resolved answer has a VALUE different
  from its parent's — COMPUTED from `evaluatedAltValue` at the call, never stored (the stored form is the benchmark phase's); the File
  never differs. The name kept by his word of 2026-10-03 (R-V04B-95); the Block-against-File reading carried past the branch (the review's C23); the stored form
  the benchmark phase's (R-V04B-35 (e)).
- `ProcessStatus` (the enum) + its values `PROCESS_OK` / `PROCESS_ERROR`.
- `Diagnostic` `{code::Symbol, severity::Symbol, message::String, context::Any}` — the typed,
  non-throwing diagnostic record.
- `AlterantRegistry` + the `const DEFAULT_REGISTRY` — the deterministic alterant inventory (the
  `goMeta` default registry), a PUBLISHED (validated + sealed) value since v0.4. **What a custom
  registry can do at THIS build state (v0.4.0-candidate; Stage-A rows T0–T5 landed; no registration-time
  signature reflection since stage 5's E4 of the v0.4 build; T11's catalogue sitting):** it is
  built through the lifecycle below, its declared record + derived tables + callables are
  sealed and door-checked, its setters DISPATCH (the apply plane is registry-data-driven) and a
  registry without the built-in Visib RUNS; the CAPTURE plane is registration-driven since T5 (a
  declared `CaptureDecl` row mints an Alterant's evals rows; `WARN_CAPTURE_FLOOR` discloses a
  missing declaration, `WARN_CAPTURE_UNREADABLE` an unreadable live value — the LIFECYCLE bullet
  below and §3.4); NOT registration-driven at v0.4 (the deferred rows): the QUERY plane's argument floor
  (T3: the getter is called with Symbol literals only; the getter's signature is not yet verified at
  registration), and the RENDER write-back (the Visib write-back LEFT at stage 3's commit 4 of the v0.4 branch, R-V04B-42 (1) —
  the Engine writes nothing into the BLS Components; the `settribute` declarations and the derived table stay until the owner's word at stage 5, R-V04B-42 (2)). The release contract page states,
  per slot, which row consumes it.
- **The registration LIFECYCLE (v0.4):** `RegistryBuilder()` (empty) or
  `RegistryBuilder(DEFAULT_REGISTRY)` (PRELOADED with the four built-ins, copied by the domain
  copier — nothing mutable shared with the published value; a cycle, an out-of-domain value or
  a position-rule offense in the input refuses typed — the way
  to EXTEND the shipped inventory) + `GoMeta.register!(builder,
  plugin, specs...)` — the mutable declaration site; `GoMeta.validate(builder) ->
  Vector{Diagnostic}` — the remaining checks (the domain probe · the capture mode-gate laws; the vocabulary check
  left at stage 5's E9, the validation chain of v0.4 T2–T4 at E4, §6), returning EVERY defect (in
  deterministic order) and never throwing; `GoMeta.publish(builder) -> AlterantRegistry` — the
  SANCTIONED route to a SEALED registry for conforming callers (the only supported one; see the
  honest bound below — in-process Julia cannot make it the only POSSIBLE one): refuses with `RegistrationRefused` (carrying every
  diagnostic) on any error, proceeds on warnings, COPIES every container by the domain copier
  `_domain_copy` (callables/Types/Symbols/Strings/VersionNumbers/numbers carried by reference;
  containers and slot structs rebuilt at their EXACT concrete types; sharing preserved within
  each copy); `deepcopy_internal` is never dispatched, so KNOWN OPEN (iv)'s user-type copy
  residue is closed; derives the hot-path tables from the declarations, seals (the fingerprint),
  and takes the SNAPSHOT baseline the door compares against.
  `RegistrationRefused <: Exception` — `.diagnostics::Vector{Diagnostic}` with stable codes
  (`REG_PROTOCOL` for a declared value outside the closed encodable domain or a capture mode-gate law;
  `REG_PROTOCOL` and `REG_SLOT_EXHAUSTED` thrown by
  `register!` — the eleven inventory, clash, reflection, algebra, reachability and candidacy codes left at
  stage 5's E4, §3.5 + §6). Positional `AlterantRegistry(...)`
  construction from hand-built tables is GATED at v0.4.0 (it runs the same checks and refuses
  inconsistent tables with `REG_DERIVED_TABLES`) and yields an UNPUBLISHED value that `goMeta`
  refuses — build through the lifecycle; positional construction is removed at v0.5. No positional
  form accepts a seal (the generated all-fields constructor is suppressed by a construction
  token); a published registry's containers are READ-ONLY by contract — the door detects, for
  conforming code and within the disclosed bounds below, a mutation of ANY walked field (the
  declared record, every derived table, every callable identity, the fingerprint) by ONE
  structural deep-egal comparison against the publish-time SNAPSHOT (`===`-only leaves; the
  first divergent path is named in the message; `POST_SEAL_MUTATION`). **The callable driver seam `run_absorb_apply!`, its
  STATE LEDGER (`STATE_REUSE_REFUSED`) and the carrier-store checker `validate_carrier_state` — the adapter route of v0.3.2/T3 —
  LEFT at stage 5's E2 of the v0.4 build** (census rows 21, 42, 23 and 44; the owner's verbatim of R-V04-31: a seam serving the
  .fodt adapter alone "will eventually have to be removed from the GoMeta engine"): `goMeta` is the ONE entry — validate, the
  door, setup, parse, the fresh per-call state, the user feed, the File loop, the delivery — one function, as in his legacy;
  one parse state per call by construction. *The T2-bis honest bound, stated exactly: the snapshot's own members are mutable
  and reachable through the published value, so a mutation through a published container is
  refused UNLESS the same actor also rewrites the corresponding snapshot container — a MIXED
  case (the live half accident-grade, the snapshot half a B-2 reach into an underscored
  field); the frozen-container path closes it (the v0.5 lane, row V05-1). A callable's
  IDENTITY is compared, never its BEHAVIOR — a closure's captured state, a
  `mutable struct <: Function`'s fields, or a redefined generic's methods move behavior under
  an unchanged `===` identity, on BOTH sides at once (the leaf is shared by reference), so the
  door stays silent — inherited from the retired callable-identity baseline's semantics. A
  Dict whose keys are structurally equal but DISTINCT objects is compared as a multiset of
  entries — a permutation of values across such keys stays silent although a stored-key lookup
  observes the change (reachable only through declared container/struct-keyed Dicts; the
  engine's own tables are Symbol-keyed). A degenerate NESTED duplicate-equal-key Dict tower is
  compared in time exponential in its nesting depth (reachable only through deliberately
  constructed duplicate-equal-key nests).* **The honest bound (the security frame's B-2 — no in-process arrangement in Julia
  constrains a loaded module):** every integrity guarantee here is ACCIDENT-grade — typed
  refusal of unpublished or post-publication-mutated registries produced by CONFORMING code.
  It is not security-grade: the construction token and the seal-minting helpers are reachable by
  any loaded code (Julia has no access control), a callable's identity does not pin its behavior
  (a closure over a `Ref`, a redefined generic), and the door is a check at entry, not a lock
  over the run — a task mutating a registry concurrently with a run that already passed the door
  is outside the model. A loaded module that does any of these has full process authority
  anyway; the trust act is the user's (load only trustworthy Alterants). The canonical
  encoding's domain is CLOSED (v0.4 T2, cure batches 4–5 — **data slots hold concrete data**):
  `Nothing` · `Symbol` · strings · `Bool` · the machine integers · the machine floats (bit-exact)
  · `Complex` and `Rational` of those · `VersionNumber` · `Type` (parameters type-tagged) ·
  CONCRETE `Vector` / `Dict` / `Tuple` / `Pair` / `NamedTuple` of encodable values · the slot
  types. A `Function` is encodable (by name) ONLY in a designated callable field (setter, getter,
  `evaluate`, `validate`, constructor — each a snapshot leaf the door compares by `===`); inside a
  data value (`Declared`, an effect payload, any container in them) it is refused. A declared
  value of ANY other type — a range, a view, a user container, `BigInt`, `Char`, an enum, an
  opaque struct — or a cyclic container is REFUSED at `validate` (`REG_PROTOCOL`, one row per
  record slot), never folded by a lossy fallback; declared string VALUES are `String`-only
  since T2-bis (a non-`String` `AbstractString` value that published before refuses typed —
  a registered 0.4.x contract narrowing). The disclosed collisions of the encoding: type
  identities fold module-UNQUALIFIED (two same-named types from different modules collide — the
  recorded trade of the profile digest); the designated callables fold by NAME in the digest (a
  same-named swap is caught by the snapshot's `===` leaf compare, not by the fingerprint);
  UnionAll/Union signature types fold by `string`.
  **The FINGERPRINT is a lossy CACHE KEY, never an identity and never the door's mechanism
  (T2-bis):** its residual collision classes — (i) a function-valued TYPE PARAMETER
  (`Val{M.f}`) folds by name; (ii) type-parameter CATEGORIES are untagged (`Val{M.T}` and
  `Val{true}` both fold as `Val{T}`); (iii) a container's CONCRETE parameters are not encoded
  (`Any[1]` ≡ `Int[1]`) — are FINGERPRINT-only: the snapshot door compares every `Type` leaf
  by `===`, so each of these swaps FIRES at the door. The former class (iv) is CLOSED —
  declared values are `String`-only and `deepcopy_internal` is never dispatched. The former
  class (v) is CLOSED — `validate`'s domain walk probes every type-bearing field (a type such
  as `Val{'c'}` refuses with a slot-named row; a type whose parameter tree exceeds the
  type-encoder budget of 256 nodes likewise refuses slot-named). The door's guarantee reads: a
  post-publication mutation of any walked field by conforming code is detected iff it changes
  the content-structural value (`===` at the leaves) — the honest bound above states the
  disclosed exceptions. No shipped declaration uses any of the collision shapes.
- `GoMeta.next_plugin_index(builder) -> Int8` — the index the next `register!` assigns (§ the
  plugin index rule below); throws `RegistrationRefused` (`REG_SLOT_EXHAUSTED`) at capacity.
- **The record VOCABULARY (v0.4; what `register!` accepts — the Alterant registration record and
  its action records; construct with the keyword forms). The record type's canonical name is
  `Alterant` (renamed from `PlugIn` at v0.4, R-V04B-5); `const PlugIn = Alterant` is a PUBLIC
  deprecation alias for the whole 0.4.x family — the examples below construct through either
  name identically; the record's FIELD NAMES are unchanged at v0.4 (keyword constructors are
  public); alias removal + field-name normalization land at v0.5:**
  - `PlugIn(; altName, setMode, altConstructor, setAltInstance, getAltInstance = nothing,
    precedencesTuple = nothing, default = NoDefault(), capture, render, constraints, atoms, contract_version,
    requires, sugar, provenance, permissions)` — the Alterant registration record. `default` = `NoDefault()` |
    `Declared(value)` — the Alterant's ONE declared default value (R-V04B-51 (1)–(2); R-V04B-55 (1): Visib declares
    `:show`; since the owner's word of 2026-10-02 (card C2, R-V04B-92 — provisional) Labels the EMPTY SET `Symbol[]`, Heading
    `nothing`, Id the zero compound `(cell = 0, parent = 0, file = 0)`), delivered by the answer function with the source
    "default" where no level provided a value (R-V04B-55 (2)); since stage 2's commit 3 (the per-action `default` of the
    action record below GAVE WAY to it at commit 3-ii). Required:
    `altName::Symbol`; `setMode ∈ (:accumulate, :mutExclusive, :mutExclusivePerField, :localOnly)`;
    `altConstructor::Type` (the instance type); `setAltInstance::Function` (the setter — its
    method signatures are the record's overloads, stated by the author — the reflection cross-check
    left at stage 5's E4). Optional, every one
    nothing/empty-defaulted: `getAltInstance` (the query getter; required iff an overload is
    `queryable`); the v0.4 declared slots below. The 6-positional 0.3.x form
    `PlugIn(altName, setMode, altConstructor, setAltInstance, getAltInstance, precedencesTuple)`
    still constructs.
  - `ActionSpec(; name, spelling, plugin, overloads, accepts_string_slot = 0, sugar_candidacy =
    :none, validate = nothing, keyed_slot = nothing, settribute = nothing)` — one action record. `plugin::Int8` = the declaration-order index of the OWNING
    Alterant (`register!` binds it: every record passed with a plugin must name that plugin's
    index); `spelling ∈ (:identifier, :operator)`; `overloads::Vector{ActionOverload}`;
    `settribute` = the `ComponentSettribute` key this action's verdict writes back to (or
    `nothing`). (The per-action `default` keyword of v0.4's T1 GAVE WAY at stage 2's commit 3-ii — the default is the Alterant's.)
  - `ActionOverload(; sig_types::Vector{Type}, kinds = Symbol[], kind_sources = [:declared …],
    vararg_kind = nothing, return_type = Nothing, effect = :set, queryable = false,
    applicability = :context_free, phase = :apply, grammar = true)` — one setter-method row
    (the keyword form; the 10-positional form takes the same fields in this order, all
    mandatory): `sig_types` = the setter's argument types AFTER the function type (instance ·
    action name · literal slots — e.g. `Type[Dict{Symbol,Bool}, Symbol, Symbol]` for one Symbol
    literal); `kinds ∈ (:symbol, :string, :raw)` per literal slot (tail-aligned to the last user
    slots); `kind_sources ∈ (:declared, :reflected)` parallel to `kinds`; `vararg_kind` a trailing
    vararg literal kind or `nothing`; `return_type ∈ (Nothing, Bool, Int16)` (the closed
    serializable set); `effect` = `:set` (the one v0.4.0 effect class); `queryable` = the action
    is usable as a condition atom (then the plugin MUST carry a getter); `applicability` =
    `:context_required` for rows that derive from placement (the heading sugar); `phase` =
    `:absorb` for `:localOnly` delivery; `grammar = false` marks an INTERNAL row.
  - **The getter contract** (`PlugIn.getAltInstance`, required iff any overload is `queryable`):
    called as `getter(instance, actionName::Symbol, args::Symbol...) -> Bool` — the query plane
    passes the action name and SYMBOL literals only (the argument floor of `getAltState`). The
    getter's signature is not yet verified at registration (the existence check is — a queryable
    overload without a getter refuses); **the runtime envelope guards the call since T3**: a
    getter throw of any class converts to the stable `CB_QUERY_THROW` refusal (the engine's own
    `GoMeta `-prefixed refusals and `InterruptException` pass through verbatim), and a non-`Bool`
    return refuses `RES_RETURN_TYPE` — at BOTH query call sites (the closed interpreter's atoms
    and `getAltState`). No registration-time signature reflection runs since stage 5's E4 (T11's
    catalogue sitting).
  - **The validate contract** (`ActionSpec.validate`, the handover validation of the accepting
    String slot): called as `validate(text::String) -> Bool` — `true` accepts; `false` refuses with the
    catalogue-named stable message (`REG_VALIDATE_FALSE` — an `ErrorException` carrying the name, the §3.4 T3
    seam-envelope family; its typed `Diagnostic` conversion the T11 catalogue); a non-`Bool` return refuses
    (`RES_RETURN_TYPE`); a throw of
    any other class wraps (`CB_VALIDATE_THROW`, the class named via `nameof`, never its text).
    A validator may refuse with its OWN complete stable message by throwing an `ErrorException`
    whose message begins `"GoMeta "` — the engine's typed-prose refusal vocabulary, passed
    through the envelope verbatim (the shipped heading validator's ratified empty-text refusal
    is exactly this class); any other throw is a validator DEFECT.
  - **The constructor dependency** (`PlugIn.altConstructor`): must be ZERO-ARG constructible —
    an absent zero-arg method meets the mint wrap at first apply as the stable `CB_CTOR_THROW`
    refusal naming the alterant and the `MethodError` (the eager `DEP_MISSING` gate at `validate` left at
    stage 5's E4). A ctor whose zero-arg method exists but THROWS converts at
    the mint to the same `CB_CTOR_THROW` refusal; a minted instance
    foreign to the matched overload's declared store type refuses `RES_FOREIGN_STORE` at every
    set-invocation.
  - **The plugin index rule:** `ActionSpec.plugin` is the declaration-order index of the owning
    Alterant, an `Int8` you supply — `GoMeta.next_plugin_index(builder)` returns the index the
    NEXT `register!` call will assign (1 on an empty builder; 5 after the four built-ins), and
    `register!` REFUSES (throws `RegistrationRefused`, `REG_PROTOCOL`, nothing appended) any record
    whose index is not that one. Immutable records are never re-stamped silently.
  - The declared SLOTS: `DomainRef(artifact, "sha256:<64 LOWERCASE hex digits>")` · `CaptureDecl(instance_type,
    attr_scheme ∈ (:per_key, :single, :per_field, :per_occurrence), multiplicity ∈ (:many, :one,
    :per_field), mode_gate ∈ (nothing, :localOnly)[, attr_stem]; attr_stem = nothing)` — CONSUMED
    since v0.4 T5: the capture walk is REGISTRATION-DRIVEN (the declared row is what makes an
    Alterant's applied state mint evals rows; a record WITHOUT one is disclosed by the typed
    `WARN_CAPTURE_FLOOR` warning, never silently evals-invisible; a declared row whose live
    instance/value falls outside the scheme's readable shape or the closed capture value set
    {Bool, Symbol, machine ints, String} meets `WARN_CAPTURE_UNREADABLE`); `validate` enforces the
    capture mode-gate laws (the gate's closed set · the bidirectional setMode⟺gate coherence · the
    :localOnly scheme and store laws; the identity, stem-shape and stem-clash laws left at stage 5's E4 —
    a stem overlapping a shipped family publishes, and same-cell same-attr rows of two plugins collapse to one) ·
    `DefaultSlot` = `NoDefault()` | `Declared(v)` · `EffectRow(kind ∈
    (:drop, :mark, :pass), payload)` + `RenderDecl(effects::Vector{Pair{Symbol,EffectRow}},
    resolve_order, materialize::Bool)` · `MutEx(actions)` · `ConditionAtom(name, print_spelling,
    evaluate)` · `SugarRow(pattern, action, mode_gate)` · `Provenance(; sec_schema = v"1.0.0",
    sources = DomainRef[], policy_id = nothing, package_digest = nothing, artifact_manifest =
    nothing, signatures = SignatureRecord[], signer = nothing, source_identity = nothing,
    acquisition_mode = nothing ∈ (:shipped, :pinned_by_user, :first_use), artifact_version =
    nothing, not_before = nothing, load_act = nothing, declared_capabilities = Symbol[])` —
    EVERY keyword optional · `SignatureRecord(; algorithm = nothing, key_id = nothing, signature
    = nothing)` (reserved) · `PermissionManifest(; seam = Symbol[], ambient = Symbol[])`
    (reserved, never enforced). `PlugIn`'s keyword form likewise defaults every slot (`capture =
    nothing`, `render = nothing`, `constraints = MutEx[]`, `atoms =
    ConditionAtom[]`, `contract_version = nothing`, `requires = ()`, `sugar = SugarRow[]`,
    `provenance = Provenance()`, `permissions = nothing`). At v0.4.0 the slots are CARRIED (validated for shape, sealed);
    their consumers land with the per-plane cures — a slot the engine does not yet consume has no
    effect on a run (the contract page of the release states, per slot, which cure consumes it).
  - **The Labels vocabulary (since stage 5's E9 of the v0.4 build — census rows 10, 28 and 55, the owner's bulk mark of
    2026-10-03, OWNER-WORDS §317, R-V04B-105; his §120 on a basic, true Labels Alterant before any hardening):** the 38
    shipped names live in the plain file `src/alterants-std/labels_vocabulary.txt`, read at load, one per line in the
    file's order — each line's first TAB field; the file is byte-identical to T4's, its one `query=false` field (the ZWJ
    name, the owner's R-V04-36 content ruling) inert data now (R-V04B-6 (a): std-Alterant territory, never a Core
    literal). `setLabels` refuses a name outside them
    (§3.4); `checkLabels` answers false for an unset or unknown name, as his legacy did. The v0.4 T4 machinery — the record's
    `vocabulary` slot with its two types, the digest pin, the capture cache, the artifact grammar, the scope law, the G-VOC
    triple, the `SRC_DIGEST_MISMATCH` row, the write-only valve and the labels record's policy identity — LEFT (§6).

They are not exported; reach them qualified. `tests/unit/public_surface_tests.jl` asserts every
§1.2 name is `public` and NOT exported (no accidental leak, no silent demotion).

- `GoMeta.BLS` — the parser module, public by name since stage 2's commit 0 of the v0.4 build (R-V04B-33/45/58): the
  BLS Component tree (`result.blsComponentTree`) is BLS's own object, provided by BLS itself and travelled with BLS's
  own public functions — THE DOOR, read qualified `GoMeta.BLS.<name>`, nothing exported: `children(tree, c)` /
  `children(tree)` (the child Components in source order; the File's Blocks), `parent(tree, c)` (the parent
  Component; `nothing` for the File), `kind(c)` (`:Meta` / `:Code` / `:Text` — the Component's flavor; `nothing` for the File), `content(tree, c)`
  (the verbatim content bytes at the Component's own grain) and `content(tree)` (the document's lines joined by a newline — the File's
  text as BLS holds it, no terminal newline; the one-argument form, since stage 5's s5c8, R-V04B-116 (3)(b)); and, for the development tools and the tests:
  `root(tree)` (the File), `flavor(tree)` (the flavor record — the PROMISE is five of its fields, `lead`, `hide_marker`,
  `hide_fold_prefix`, `flavor_tag`, `re_meta_leaded`; every other field, `parse_header!` first, is reachable but not part of the
  contract; its type stays internal), `endsWithNewline(tree)`, `isHorizontalSpace(c)` (the parser's horizontal-whitespace
  class — the print tools' lexer and, since stage 5's s5c8, the renderer's whitespace guard before the hide marker), the
  settribute / position read `getElement` (over a container, or over a Component by key — through which a caller reads no
  field), the Component types `File` / `Block` / `Line` / `Segment` and the
  named-element types `ComponentSettribute` / `CmpntNamedInt`. Each name has its row in §6. Everything else in
  `GoMeta.BLS` is internal.

### §1.3 — The Engine's output surface, and the development tool's pair (since 0.4.0, R-V04B-24)

1. **In R-V04B-24's own words: "the package's canonical observable output = `altValues_evals` (+
   `serialize_evals`, `content_fingerprint`)" and "the Engine's delivered surface after the move = the run
   and the evaluated values".** `readAltValuesEvals(result.altValues_evals)` is the evaluated Alterant values, per piece of the
   file: the deterministic, final-verdicts-only map `(cell_handle, attr, value, polarity)`, keyed by (handle, attr);
   `GoMeta.serialize_evals` its byte form; a cell's bytes through `GoMeta.BLS.content` since 0.4.0's stage-2 commit 9b (R-V04B-24's quoted
   words name `content_fingerprint`, which left at that commit — R-V04B-43 (1); the §6 row). No internal module
   (`walk`) ever needs importing for it; `GoMeta.BLS` is public for the BLS Component tree (§1.2), not needed for the evals.
2. **The (tree, render) pair is the development tool's**, not the Engine's: `Main.BasicRenderer.outputs(result)
   -> (blsStructure_bytes, render_bytes)` — the verdict-free tree print + the `jl-share-v1` share render — is
   obtained ONLY through the basic renderer (`devtools/basic_renderer.jl`) loaded by its one loader,
   `include("devtools/load_basic_renderer.jl")` at the caller's top level; `devtools/README.md` documents it.
3. **The test layer pins that pair byte-exact** against the corpus golden (`tests/golden/`) — the test
   layer's property, beside the twelve annotation pins of the Engine's values.

## §2 — Signatures + contracts

**⚠ Trust note:** under the DEFAULT profile no condition text is ever evaluated (the closed
interpreter, §3.2). Only under the explicitly opt-in full-eval mode — two operator acts, see the
SECURITY section of `README.md` — can processing input you did not write execute arbitrary code.

### `goMeta(bytes::Vector{UInt8}; config::GoMetaConfig = GoMetaConfig(), registry::AlterantRegistry = DEFAULT_REGISTRY) -> GoMetaDelivery`

(`goMeta` consumes raw bytes; from a `String` use `Vector{UInt8}(codeunits(s))` — or `read(path)`
for a file, as in the README quickstart.)

Pure, deterministic, **TOTAL over the CONFIG-TIME catalogued surface** (an invalid `config` never
throws uncaught; absorb/apply-plane catalogued failures can still throw at v0 — the §3
partition). `GoMetaDelivery` carries the run's FOUR public parts, read by name (R-V04B-28/29/30), in his pipeline order (R-V04B-89):
`blsComponentTree::BLS.ParseState` (the BLS Component tree the run was
evaluated over, provided by BLS itself; it reaches an Extension as the part `blsComponentTree`, not through any function of the
GoMeta Engine; an Extension travels it with BLS's own public functions; MUTABLE — the run wrote into it, and every reader of one delivery shares the one
object) · `altValues_evals::EvalStore` (the data container of the evaluated values — the reader over it
`readAltValuesEvals`, §2 below) · `status::ProcessStatus` · `diagnostics::Vector{Diagnostic}` (the invariant is **non-OK ⇒ non-empty
diagnostics**). Nothing internal travels: the per-call working state never leaves the core. (The (tree,
render) pair is the development tool's `Main.BasicRenderer.outputs(result)`, loaded through
`devtools/load_basic_renderer.jl` — not an Engine surface.) No filesystem / clock / environment read. **These three guarantees —
purity, determinism, isolation — cover the whole default-configured run under `DEFAULT_REGISTRY`
(under a CUSTOM registry they hold exactly as far as its own setters/getters/validators do: a
callable closing over mutable state or performing I/O is that Alterant's act, outside the
engine's guarantee — the user-loads-trustworthy-Alterants trust model):** a `{…}` condition body
is parsed and evaluated by the closed no-eval interpreter, so it cannot read the filesystem, the
clock or the environment, and cannot perform effects. (Under the explicitly opt-in
`:full_eval_v1` extension mode — see the SECURITY section of `README.md` — a condition body IS
host-evaluated, and the guarantees then hold only for inputs whose conditions are free of side
effects.) An invalid `config`
fail-closes into a `PROCESS_ERROR` `GoMetaDelivery` **before any parse** — the input
bytes are never touched; no parse or verdict work occurs (§3.1); the Engine renders nothing since
0.4.0 (§1.3), and the development tool's `Main.BasicRenderer.outputs` on such a result is the empty pair.

**The registry door (v0.4, STRICT — published-only).** `registry` must be a PUBLISHED value
(`DEFAULT_REGISTRY`, or the result of `GoMeta.publish`). A conforming-but-unpublished registry
(e.g. a gated positional construction) fail-closes exactly like an invalid config — a
`PROCESS_ERROR` result before any parse, carrying `REG_UNPUBLISHED`, whose message names the
sanctioned path `RegistryBuilder → validate → publish`. A published registry whose containers
were mutated after publication fail-closes with `POST_SEAL_MUTATION` (the live fields are
compared structurally against the publish-time snapshot at the door — the real freeze gate;
the message names the first divergent path; re-publication is the sanctioned change path).
Config-time and registry-time diagnostics are collected FULLY into ONE result (config rows
first).

### `GoMetaConfig(; profile = :jl_share_v1, flavor_tag = :julia, parse_range = nothing, user_mh_profile = nothing, namespace = :default)`

The v0 input options (the versioning policy §6). `profile::Symbol` — the closed default is
`:jl_share_v1`; the two OPT-IN names `:jl_share_v1_full_parse` / `:jl_share_v1_full_eval` are
also config-valid and additionally require the explicitly-included opt-in extension (the two-act
law, §3.2). The remainder of this paragraph describes the default: the share-profile proper is
`:jl_share_v1`. `flavor_tag::Symbol` — the content flavor: a CLOSED set of three armed flavors,
`:julia` (the `#` lead alphabet — the default) · `:c` (the C-family `//` line-comment flavor) ·
`:latex` (the `%` lead alphabet); any other value fail-closes with `ERR_UNKNOWN_FLAVOR` (§3.1)
before any parse — selected, never inferred (no file-extension or content sniffing). *(This
sentence previously said "any value is accepted and ignored; validation is deferred" — stale
since the flavor arming; corrected at v0.4 T2 on a CrossReview finding.)*
`namespace::Symbol` — the occurrence-key namespace every `altValues_evals` cell handle is scoped
under (`:default` by default; encoded as the key's length-prefixed namespace segment). One
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
profile records ONE row against the minted user-context handle (grain `0xe0`; no copy of the profile's
bytes rides the row since 0.4.0's stage-2 commit 9b, R-V04B-43 (1)), even on META-FREE input; queued fed actions apply only
where document cells exist. The deriving heading form refuses on this surface (no placement), and
a CONDITIONED heading refuses (no evaluable settribute state at this version). New rows appear
ONLY when this field is set. Deliberately scope-limited at v0.

### `readAltValuesEvals(altValues_evals::EvalStore) -> Vector{Tuple{Vector{UInt8},Symbol,Any,Bool}}`

Given the delivered PART — the data container of R-V04B-29/32, never the whole delivered object:
`readAltValuesEvals(result.altValues_evals)` (a reader takes the PART — R-V04B-29's record; the branch's default under
R-V04B-40 (2)) — the evaluated Alterant values, per piece of the file: the final map
`(cell_handle, attr, value, polarity)` — per-cell rows plus handle-classed non-cell rows (a fed
explicit heading records against the user-context handle class) — **sorted by `(cell_handle,
attr, value)`** for a deterministic, content-hashable order; **final-verdicts-only** (deduped at
capture); **empty when no metaLine exists on ANY surface** (the fed profile IS a metaLine body);
outside the `(tree, render)` pair at v0. The `(attr, value)` domains at v0:
`:label_<name> => true` (one row per accumulated label) · `:visib => :hide | :show | :discard`
(the winning visibility verdict) · `:id_<name> => Int16` (experimental Id values, one row per
NON-ZERO field — a stated zero is not recorded, so zero and unset are indistinguishable in the rows; the compound is set as a
WHOLE by the nearest statement, an unset field not inherited from an outer slot, and within one slot the last row of a field
wins — the per-field semantics DEFERRED, the contract narrowed at stage 2's commit 7, the first authored Id scenario a draft put
to the owner) · `:head_<level> => String` (author-supplied section headings, document-
or fed-profile-authored — the §2 Heading action; `head_<level>_<k>`, k ≥ 2 in source order,
for same-level repeats on one recorded handle); `polarity` is always `true` at v0 (the field
is reserved for a future negated-verdict encoding). Consumers should treat UNKNOWN attribute
families as opaque — skip them, never error: the enumeration lists the v0 families, and new
families may arrive in a later version under the versioning policy (§6 — no compatibility promise until at least v0.7). `GoMeta.serialize_evals(readAltValuesEvals(result.altValues_evals))` is its canonical
byte form — one row per line, four tab-separated columns, the `attr` column encoded (a backslash, tab, newline or
carriage return in an attribute name escaped as `\\`, `\t`, `\n`, `\r`; since 0.4.0's stage-2 commit 7a — the
CrossReview set REAL-1 R1 #2; the registry refuses no delimiter in a stem, that hardening deferred under R-V04B-37).

### `evaluatedAltValue(delivery::GoMetaDelivery, component, alterant::Symbol; registry::AlterantRegistry = DEFAULT_REGISTRY) -> EvaluatedAltValue`

THE ONE ANSWER FUNCTION (since 0.4.0's stage-2 commit 4; R-V04B-35 (c); the plan v8.1 :56) — for ONE Component of the
delivered tree (`result.blsComponentTree`, reached through `BLS.parent` for a rowless child's inheritance; a deciding handle's
Component read from the handle's own path) and ONE Alterant by
its registered name (`:Visib`, `:labels`, `:id`, `:heading` in the default registry): the resolved value and its SOURCE,
derived at the call from the delivered rows and their `decided_by` provenance — never stored, never cached, the delivery
untouched. `EvaluatedAltValue(value, source, via)`: `value` in the Alterant's own shape (Visib a `Symbol`; Labels the SET of names,
a sorted `Vector{Symbol}`; Id the compound, a `NamedTuple` of the recorded fields; Heading the `String` of the first heading
row); `source` ONE tag — `:own` (every deciding statement the Component's own), `:indirect` (through the Component `via`
whose statement decided it — the metaBlock an attached Block follows, the Line a rowless Segment answers through, R-V04B-93),
`:user` (the fed profile), `:file` (the File level's room, R-V04B-53 — no feed at v0.4), `:fallBack` (RESERVED for the
fallBack level's carrier once the metaLevel Alterant feeds it, R-V04B-55 (4)), `:default` (no rows anywhere: the Alterant's
declared default — Visib's `:show`; Labels' `Symbol[]`, Heading's `nothing`, Id's zero compound since card C2's word, R-V04B-92;
R-V04B-55 (2)), `:none` (no rows and no declared default — an Alterant of a custom registry without one; the File — NOTHING built for
it at v0.4, card 6 "next"); an Alterant without a capture DECLARATION mints no rows and answers its declared default or
`:none`, and an undeclared capture stem is derived as the walk derives it (`lowercase(altName)`). The trailing metaSegment's statement is
applied DIRECTLY to its Line — its row keyed on the Line with the Segment as the key's origin (Visib, Labels, Id): the Line answers `:own`;
the Segment itself, like every Segment of that Line, answers AS its Line answers, the Line's `:own` marked `:indirect` through the Line and
every other source unchanged (`:indirect` through the Line's own decider, `:user`, `:file`) — the owner's words of 2026-10-02 (R-V04B-93;
card C24). The inline HEADING follows the same rule since stage 5's E1 (R-V04B-98; his §309): its row is keyed on the Line with the Segment
as the key's origin and decided by the Segment — the Line answers `:own`, its Segments `:indirect` through the Line (before E1 the row
sat on the Segment itself, the heading's `:localOnly` lane keying it on its carrier). A rowless child inherits its parent's rows up the tree (a
Segment its Line's, a Line its Block's — OQ-148; R-V04B-52 (2)); a Segment-carried row (keyed on a Line with the Segment as
the key's origin) is the Line's. An unknown Alterant name throws `ArgumentError` naming the registered names. **NOT FINAL**
— the tier, the File's case and the equal-child rows (OQ-148) are carried past the branch (the review's C23);
the per-call row scan (card C8) is DEFERRED to the benchmark phase after the branch (his word of 2026-10-03, OWNER-WORDS §307;
R-V04B-97; the per-call tree walk behind `via` left at stage 3's commit 1b — the Component read from the handle's own path); no
compatibility promise before v0.7 (§6). The name is DECIDED: `evaluatedAltValue`, his word of 2026-10-03 (OWNER-WORDS §305; R-V04B-95), replacing the branch's working name `answerFor`.

### `scanAlterant(delivery, alterant; registry = DEFAULT_REGISTRY)` · `evaluatedAltValues(delivery, component; registry = DEFAULT_REGISTRY)`

THE TWO VIEWS OVER THE ONE ANSWER FUNCTION (since 0.4.0's stage-2 commit 5; his §6 item 9.A — "an Extension may scan for all
BLS Components … who got assigned Ids and what kind … the Extension must be enabled to access all such information in as
efficient a manner as possible, the information must be unambiguous, and informative"; the plan v8.1 :57; card 4). `scanAlterant`
returns, for ONE Alterant, every Component of the delivered tree for which the Engine RECORDED a value (the Component's own rows —
a Segment-carried row is its Line's), paired with its `evaluatedAltValue` answer, in the tree's order (each Block, its Lines, their
Segments); a Component without own rows is not listed — its answer is still `evaluatedAltValue`'s (inherited or the default; his §7 item 2:
the children are hidden as PART OF their Block); the File is never listed. `evaluatedAltValues` returns, for ONE Component, every registered
Alterant's answer in the registry's Alterant order (`registry.plugins`), each paired with the Alterant's registered name. Both are
pure, derived at the call, and can never disagree with `evaluatedAltValue` (they are built on it). An unknown Alterant name throws
`ArgumentError`. **NOT FINAL** — functions of their own stand (the session's default, R-V04B-40 (2)); the alternative, methods of the
reader `readAltValuesEvals`, is banked as a labelled diff (`receipts/S8-branch/ALTERNATIVE-s2c5_reader-methods.txt`); his word of
2026-10-03 named the functions (§305; R-V04B-95) and took no alternative — it stays his to take; no compatibility promise before v0.7 (§6).

### `childDiffers(delivery::GoMetaDelivery, component, alterant::Symbol; registry::AlterantRegistry = DEFAULT_REGISTRY) -> Bool`

THE CHILD-DIFFERS SIGNAL, COMPUTED FROM THE ANSWER (since 0.4.0's stage-2 commit 6; R-V04B-35 (e) "his (ii) child-differs signal
COMPUTED from that answer, its stored form left to the benchmark phase"; his §37 item 4.2 — a Block's child Components' evaluations
"only REQUIRE to be explicitly recorded … IF they differ from their parent's corresponding evaluation"; the plan v8.1 :58): `true`
when `evaluatedAltValue(component).value` differs from `evaluatedAltValue(parent).value` — a Segment against its Line, a Line against its Block, a
Block against the File (which answers `nothing` at v0.4, NOTHING built for it — card 6 "next" — so a Block with any VALUE, the
declared default included, differs, and a Block answering `:none` — value `nothing`, an Alterant without a declared default and no
rows — does not); the File itself `false`. The VALUE is compared, not the source: a rowless child inheriting its
parent's rows never differs (it is hidden "as PART OF" its Block, his §7 item 2); a child with its own statement differs exactly
when that statement's value is another. Pure; nothing stored. An unknown Alterant name throws `ArgumentError` (for every Component
but the File, whose `false` precedes the name's check). His (ii) Boolean sits beside the PARENT's entry and asks whether ANY of its
children differ — for a parent P it is `any(c -> childDiffers(delivery, c, alterant), BLS.children(delivery.blsComponentTree, P))`;
`childDiffers` is the per-child primitive (his §37 item 4.2's question for ONE child) from which that aggregate is computed; the
aggregate's own form — a function of its own, or the stored flag beside the parent's row — is the benchmark phase's. **NOT FINAL** —
the name kept by his word of 2026-10-03 (R-V04B-95); the Block-against-File reading carried past the branch (the review's C23) (R-V04B-40 (2)); no
compatibility promise before v0.7 (§6).

### The (tree, render) pair — a development tool's, since 0.4.0 (R-V04B-24)

`GoMeta.outputs` left the Engine at 0.4.0 (the breaking-change register row in §6). The pair `(blsStructure_bytes, render_bytes)` —
the verdict-free tree print + the `jl-share-v1` share render, the SAME field names and order, the same non-OK
contract (a `PROCESS_ERROR` result of an entry refusal — at `goMeta` before its parse — yields the **empty** pair) — is the basic renderer's own function
`Main.BasicRenderer.outputs(result)`, obtained ONLY after `include("devtools/load_basic_renderer.jl")` at the
caller's top level. Its render-plane qualification (the character-safe string indexing, §4) is the tool's; since stage 3 of the
v0.4 build every Visib verdict the render applies is the Engine's answer per Component (`evaluatedAltValue`, §1.2 — R-V04B-16 (1)), the
renderer resolving nothing itself. See `devtools/README.md` and `docs/CANONICAL-OUTPUT.md`.

### The metaLine argument forms (v0)

An alterant ACTION token may carry a parenthesized, comma-split argument list — `action(arg1,
arg2)` — parsed with the metaLine and handed to the action when it fires. The v0 forms:

- **Labels (the `:` action) — DOCUMENTED, both forms:** repeated one-word labels
  (`#~ :label1 :label2`) AND the parenthesized list (`#~ :(label1, label2)`) — equivalent; each
  label APPLIED is checked against the engine's closed whitelist (an unknown label ⇒ the §3.4 stable refusal); a
  label QUERIED in a condition answers false when it is unknown or unset (the legacy's checker; since stage 5's E9 of
  the v0.4 build). The corpus-documented labels are `:label1`..`:label5`; since `0.3.0`
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
  affect the recorded level (still `head_10`). The explicit level argument must land in the
  LEVEL VOCABULARY — the structural window `0..8` or the documented inline constant `10`
  (`head("T", 10)` records `head_10`, sharing the inline constant's name); any other explicit
  level (`head("T", 9)`, a negative level, `11`) is REFUSED by the Heading alterant's own
  validation seam with the §3.4 stable message `"GoMeta absorb: explicit heading level … is
  outside the level vocabulary"` — a standing v0.2 semantic. *(This passage previously claimed
  any integer level was accepted and recorded as given — stale against the code since the
  level-window guard; corrected at v0.4 T2 on a CrossReview finding.)* The `head` TEXT slot is the one
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
`Diagnostic` except where its row says otherwise — the E-06 GUARDED refusal
still throws (§3.1; its typed conversion deferred at v0; the E-04 crash origin RETIRED at stage 3's commit 4), the condition-path rows are minted typed while
the statement still aborts at the absorb seam (§3.2's preamble), and E-07's mint is pending (§3.2). The
catalogue's inventory IS the tables of §3.1–§3.5
below (no aggregate count is maintained by hand — two hand-written counts drifted at v0.4 T2);
the rows fall into three classes
(§3.1–§3.3); §3.4 additionally documents the latent crashes and the stable-message refusals that
are not catalogued typed codes.

### §3.1 — Non-condition codes (5): 3 armed config-time + 1 crash-origin with deferred typed conversion + 1 GUARDED

| Code | Status | Trigger |
|---|---|---|
| `ERR_UNKNOWN_PROFILE` (E-03) | config-time, **armed + typed** | `config.profile` outside the three profile names `{:jl_share_v1, :jl_share_v1_full_parse, :jl_share_v1_full_eval}` — fail-closed `PROCESS_ERROR`, no parse or verdict work attempted (the Engine renders nothing since 0.4.0, §1.3) (an opt-in name passes THIS row and refuses later at profile resolution unless the opt-in extension is explicitly included — the two-act law, §3.2) |
| `ERR_RANGE_INVALID` (E-08) | config-time, **armed + typed** | `config.parse_range` with `first ≠ 1`, or an empty range |
| `ERR_UNKNOWN_FLAVOR` | config-time, **armed + typed** | `config.flavor_tag` outside the three armed flavors `{:julia, :c, :latex}` — fail-closed before any parse (selected, never inferred). *(Row added at v0.4 T2 on a CrossReview finding — the code armed it at the flavor arming; the catalogue had not followed.)* |
| `ERR_VISIB_NO_FLAG` (E-04) | **RETIRED at 0.4.0** (stage 3's commit 4 of the v0.4 build; R-V04B-42 (1)) | its crash origin was the Visib write-back's flagless read of the winning action; the write-back is gone and the capture's own read is guarded — no apply-path crash origin remains catalogued |
| `ERR_DEPTH_OUT_OF_WINDOW` (E-06) | **GUARDED** — stable untyped refusal; typed conversion deferred | a `#~9`-style **digit** depth beyond the meta-hierarchy's depth window raises the stable-message `ErrorException` "meta depth out of range …" at the depth lookup (§3.4) |

E-03 / E-08 / `ERR_UNKNOWN_FLAVOR` are armed (the three config-time rows): a bad profile/range/flavor returns a `PROCESS_ERROR` `GoMetaDelivery` carrying the
typed code, with the development tool's `Main.BasicRenderer.outputs` yielding the empty `(tree, render)` pair (its non-OK contract). No apply-path crash origin remains: E-04's left
with the Visib write-back at stage 3's commit 4 (its row above).
E-06 is **GUARDED**: for a digit depth outside the window the depth lookup refuses with the stable
message "meta depth out of range …" (§3.4); its typed conversion is likewise deferred
at v0.

### §3.2 — Condition codes — TYPED at the closed-interpreter flip (this release; eval retired from the default path)

**Two intake modes ship (both available, the safe one by default).** The DEFAULT profile
`:jl_share_v1` runs the closed interpreter described here. Two OPT-IN profiles —
`:jl_share_v1_full_parse` (full Julia grammar accepted, still nothing executed) and
`:jl_share_v1_full_eval` (a strict superset of the safe grammar: everything the safe grammar
accepts behaves identically, and only text beyond it is parsed as Julia and EVALUATED) — require
TWO explicit operator acts: `include`-ing `optin/condition_modes_opt_in.jl` and then naming
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
| `ERR_UNKNOWN_CONDITION_KEY` (E-01) | **typed mint; the statement still aborts at the absorb seam** (§3.2's preamble) — a condition atom outside the derived whitelist of state-refs and action names |
| `ERR_CONDITION_CAP` (E-02) | **typed mint; the statement still aborts at the absorb seam** (§3.2's preamble) — the condition scan exhausts a profile cap (29 scan steps, whitespace counted; or the raw-byte / grouping-depth walls) with non-whitespace input unconsumed, or a label key is left unterminated — a refusal, never a silent truncation; each mint carries its governing wall or window size in the `Diagnostic`'s context |
| `ERR_CONDITION_ARG_DOMAIN` | **typed mint; the statement still aborts at the absorb seam** (§3.2's preamble) — a query argument outside the declared argument grammar above |
| `ERR_CONDITION_PARSE` | **typed mint; the statement still aborts at the absorb seam** (§3.2's preamble) — the intake's grammar refusals: an empty `{}` body · an unterminated argument list · a malformed or unterminated condition key · a worded label key carrying a parenthesized argument list · an unparsable operator sequence |
| `ERR_CONDITION_UNQUERYABLE_ALT` (E-07) | `cell` / `parent` / `file` used as a condition atom (Id has no queryable instance) — **typed mint PENDING**: the shape still aborts raw at evaluation (documented honest edge, §3.4) |

### §3.3 — Handled class (NOT an error): E-05 — meta-free input

A meta-free input is **not** an error: on the NO-FEED path `goMeta` returns `PROCESS_OK` with zero
alterant work, and the development tool's render of such a result is a byte-exact passthrough (a head-bearing fed profile still mints its
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
- **The unknown-label refusal:** a name APPLIED as a label (`#~ :labelX`, including the conditional form
  `:labelX{ … }`) from outside the shipped set — `:label1`..`:label5` plus, since `0.3.0`, the fixed pictograph
  vocabulary (`alterants-std/labels_vocabulary.txt`, 38 names) — raises the stable `ErrorException`
  `"GoMeta apply: unknown label …"`, which names the accepted set SORTED (the §2 argument-forms contract). A label
  QUERIED in a condition (`{ :labelX }`) is never refused for being unknown: the query answers false, as the legacy's
  checker did (since stage 5's E9 of the v0.4 build — the T4 membership refusal in the query role and the write-only
  valve left, census row 55). Witnesses: `tests/unit/error_message_tests.jl` (both roles).
- **The capture-floor warnings (v0.4 T5; typed, NON-fatal):** `WARN_CAPTURE_FLOOR` — an
  alterant produced applied state but declares NO capture row: its verdicts mint no evals
  rows; the run stays `PROCESS_OK` with the warning ONCE per call per alterant (recovery:
  declare a `CaptureDecl`). `WARN_CAPTURE_UNREADABLE` — a DECLARED row whose live
  instance, key, or value falls outside the scheme's readable shape or the closed capture
  value set: the affected rows are not minted, disclosed the same way (recovery: conform
  the store/values to the declared scheme, or re-declare the scheme). Channel: warning
  `Diagnostic`s on the result. Witnesses: `tests/unit/capture_tests.jl`.
- **The store-`[2]` insertion path** — a latent insertion path not exercised by any v0 input.
- **The absorb-plane grammar refusals (the same stable-message family):** beyond the entries
  above, the metaLine/condition grammar refuses with stable `GoMeta absorb:` messages on: an
  unterminated argument list (a `(` never closed) · an unterminated condition block (a `{` never
  closed) · an unterminated or malformed condition key (including a `:` that does not introduce a
  single one-word label) · an unknown condition key (an atom that is neither a component
  state-ref nor a registered action name) · a duplicate argument list or condition block on one
  alterant clause · a misplaced label token · stray punctuation at the action-name position · a
  token glued to a closing `)` or `}` · the over-cap condition (the dedicated entry above).
  The basic renderer (a development tool, `devtools/basic_renderer.jl`) carries no Visib guard of its own since stage 3 of the
  v0.4 build: it renders the Engine's answer per Component; more than one Visib value on one cell is refused by the Engine at the
  CAPTURE (`src/annotations.jl` — the stable message `GoMeta capture: more than one Visib value set for one component …`).
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

- **The bang-first meta marker — GUARDED (v0.3.1):** the transposed inert spelling — tildes,
  then ONE `!`, then digits, then an optional trailing `!`, whitespace/EOL-terminated
  (`#~!2`, `#~!2!`, `#~~~!3`) — raises the stable-message `ErrorException`
  `"GoMeta parse: bang-first meta marker …"` EARLY, at the parse-plane head reader — BOTH
  grains (metaLine and inline metaSegment), in every neighbourhood; there is no prose,
  fence, or string-literal shelter. The message names the corrected TRAILING-bang spelling
  (`#~2!`). Before v0.3.1 the shape silently fell through as plain content — the known
  authoring mistake this refusal exists to catch. Glued and multi-bang neighbours
  (`#~!!0`, `#~!0x`, `#~2!x`) stay plain content — the refusal covers exactly the one
  family. To MENTION the shape in prose, quote-glue it (`"#~!2"`; see
  `docs/SYNTAX-AND-SEMANTICS.md` §1/§9). Witnesses: `tests/unit/inert_semantics_tests.jl`.
- **The empty label LIST — GUARDED (v0.3.1):** a labels SET action that parses to zero
  labels (`#~ :` — the lone colon — or `#~ :()`) raises the stable-message `ErrorException`
  `"GoMeta apply: empty label list …"` INSIDE the Labels Alterant (`setLabels`) — before
  v0.3.1 the vacuous loop stored nothing, minted no evals row, and a mistyped label
  vanished SILENTLY. The guard fires when `setLabels` is actually INVOKED (apply-plane);
  a set action that never applies stays silent. An inert `#~2! :` is exempt by
  construction — its content is never absorbed. Witnesses:
  `tests/unit/inert_semantics_tests.jl`.
- **The empty label QUERY — GUARDED (v0.3.1):** the condition-side twin — a label check
  with zero labels (`{ :() }`) — raises the stable-message `ErrorException`
  `"GoMeta apply: empty label query …"` inside the Labels Alterant (`checkLabels`) —
  before v0.3.1 the vacuous check silently evaluated TRUE.

**Message stability:** every input-reachable engine-layer message a v0 input can trigger through
the parse/absorb/apply pipeline is STABLE and explanatory (stage-honest prefix
`GoMeta parse:` / `GoMeta absorb:` / `GoMeta apply:` — the development tool's render plane carries no message of its
own since stage 3's commit 1 of the v0.4 build, the renderer consuming the Engine's answer; the offending token
bounded, what v0 accepts, this section as the pointer); three catalogued messages are
parse-plane — the multi-inline-meta refusal and the two directive-adjacency refusals
(segment grain and line grain, `0.2.3`) above. The not-input-reachable internal checks say
"GoMeta internal invariant violated … please report". The vendored parse layer's OTHER messages
keep their existing forms; they are not part of the typed catalogue above.

Additionally, a non-fatal `:warning` `Diagnostic` — `WARN_VERDICT_COLLISION` — is emitted (the run
continues) when a later put for the SAME occurrence handle and attribute changes the recorded value
or polarity — the same cell re-applied with conflicting verdicts (the later row supersedes;
applied-state-wins); two distinct cells never share a slot, byte-identical content included, for
well-formed occurrence keys (`_putEval!`, `src/annotations.jl`).

- **The T3 SEAM-ENVELOPE family — GUARDED (v0.4 T3; catalogue-NAMED stable-message refusals,
  their typed `Diagnostic` conversion = the T11 catalogue):** each fires as an
  `ErrorException` whose message carries the catalogue name as a literal token; the engine's
  own `"GoMeta "`-prefixed refusals and `InterruptException` always pass through the
  envelopes verbatim; the containment guarantee is scoped to exceptions delivered to the
  handler (`StackOverflowError` catchability is shape-dependent; resource exhaustion may not
  allocate a refusal).
  - `CB_QUERY_THROW` — an alterant query checker (getter) threw, either query site; the class
    named via `nameof`, the action named. Trigger: any getter throw outside the pass-through
    classes. Recovery: fix the checker (its contract is total over its declared signature).
  - `RES_RETURN_TYPE` — a declared-return-type breach: the query getter returned non-`Bool`
    (either site); the setter's live return guard (the pre-existing wall, now named); or the
    handover validator returned non-`Bool`.
  - `REG_VALIDATE_FALSE` — the declared handover validation returned `false` for the presented
    String-slot text; first-offender-wins at the absorb site (the catalogue's refuse-at-gate
    shape is unreachable at this callable's only call site — full collection rides T11).
  - `CB_VALIDATE_THROW` — the handover validator threw a foreign class.
  - `CB_SET_THROW` — the set seam's malformed-argument crash conversion (the pre-existing
    "invalid arguments" wall) now carries the name + the alterant.
  - `CB_CTOR_THROW` — an `altConstructor` whose zero-arg method exists threw at any of the
    three instance-mint sites; the alterant named.
  - `RES_FOREIGN_STORE` — the store instance is foreign to the MATCHED overload's declared
    store type, checked on every set-invocation at the post-dispatch point.

### §3.5 — Registration + door codes (v0.4; typed `Diagnostic`s)

Every row below is a `Diagnostic{code, severity, message, context}`. FOUR delivery channels (a
trigger/site matrix — one CODE appears on two channels: `REG_PROTOCOL` is an immediate `register!` throw
for the plugin-index binding AND a validation row for the domain probe and the mode-gate laws;
`REG_SLOT_EXHAUSTED` is a `register!`/`next_plugin_index` throw alone since stage 5's E4): **(i) `register!`-time THROWS** — immediate and atomic (nothing appended), a thrown
`RegistrationRefused`: the plugin-index binding (`REG_PROTOCOL`) and the plugin/action pool
overflow (`REG_SLOT_EXHAUSTED`; also `next_plugin_index` at capacity) — wrap `register!` in a
`try`; **(ii) VALIDATION-time rows** — every other `REG_*` row below comes back from
`GoMeta.validate` (all validation-time rows, in one vector, deterministic order) and rides
`RegistrationRefused.diagnostics` when `publish` refuses; **(iii) ROUTE-U-only** —
`REG_DERIVED_TABLES`, raised by the gated positional constructor together with the validation
rows; **(iv) DOOR results** — `REG_UNPUBLISHED` / `POST_SEAL_MUTATION` come back as a
`PROCESS_ERROR` result from `goMeta` — an entry refusal before its parse.

| Code | Severity | Trigger | Context |
|---|---|---|---|
| `REG_PROTOCOL` | error | a STRUCTURAL defect of the record: a record passed to `register!` that names another plugin; (v0.4 T2 cure batches 4–5) a declared value outside the CLOSED encodable domain — a cyclic container, a `Function` inside a data value, a non-`Vector`/`Dict` container (range, view, user container), any type without an encoder, a `Type` whose parameter tree exceeds the type-encoder budget, or (T2-bis) any domain-walk membership failure over the FULL field lists — one row per record SLOT, naming it; a capture mode-gate law (the gate's closed set, the setMode⟺gate coherence, the :localOnly scheme and store laws). The tier-1 enum, kinds, queryable, uniqueness, plugin-index, settribute-key, MutEx, capture-identity and stem rows left at stage 5's E4 (§6) | the action or alterant name |
| `REG_UNKNOWN_SETMODE` · `REG_DUPLICATE_ALTNAME` · `REG_DUPLICATE_ACTION` · `REG_RESERVED_SHADOW` · `REG_SIG_MISMATCH` · `REG_VALUE_ALGEBRA` · `REG_UNREACHABLE` · `REG_CANDIDACY` · `REG_MUTEX_CONFLICT` · `REG_UNINTERPRETED_REQUIRES` · `REG_CONTRACT_VERSION` | **REMOVED at 0.4.0** (stage 5's E4 of the v0.4 build; census rows 3 and 51 — OWNER-WORDS §317, R-V04B-105) | the validation chain of v0.4 T2–T4 — the typed inventory, the clash law with its disposition switch, the reflection cross-check, the value-algebra and reachability refusals, the candidacy warning — left; his legacy registered unchecked; a duplicate action name resolves FIRST-wins in the derived tables; the §6 register row | — |
| `REG_SLOT_EXHAUSTED` | error | more than 127 alterants or actions (the Int8 index space) — at `register!`'s 128th append (the validate-time row for a directly-pushed builder left at stage 5's E4: such a builder fails at `publish` with Julia's `InexactError`, the honest bound of bypassing `register!`) | the alterant |
| `REG_DERIVED_TABLES` | error | positional (route-U) construction whose hand-built tables differ from the tables derived from the declarations | `nothing` |
| `REG_UNPUBLISHED` (door) | error | an unsealed registry reached `goMeta` — the message names `RegistryBuilder → validate → publish` | `nothing` |
| `POST_SEAL_MUTATION` (door) | error | a published registry whose live fields no longer match the publish-time snapshot — the message carries "at <path>", the first divergent path; re-publication is the change path | the rendered path |
| `DEP_MISSING` (v0.4 T3) | **REMOVED at 0.4.0** (stage 5's E4 of the v0.4 build; census row 3) | the eager dependency closure at publication left; an `altConstructor` with no zero-argument method publishes and meets the mint wrap at first apply — `CB_CTOR_THROW` naming the alterant and the `MethodError` (§3.4); the §6 register row | — |
| `STATE_REUSE_REFUSED` (T3 seam) | **REMOVED at 0.4.0** (stage 5's E2 of the v0.4 build; census row 42) | the seam ledger left with the callable driver seam: `goMeta` builds its parse state itself, one per call — nothing is injected, nothing can be in flight twice; the §6 register row | — |
| `STATE_SEAL_MISMATCH` (T3 seam) | **REMOVED at 0.4.0** (stage 3's commit 4 of the v0.4 build; R-V04B-42 (1)) | it guarded the Visib write-backs a run left in the caller's state; nothing is written back any more — the §6 register row | — |
| `SRC_DIGEST_MISMATCH` (v0.4 T4) | **REMOVED at 0.4.0** (stage 5's E9 of the v0.4 build; census row 10) | the vocabulary artifact's digest pin left with the record's vocabulary slot — the 38 names are a plain file read at load; the §6 register row | — |

Stable-message refusals (NOT typed codes; the §3.4 class): `"GoMeta absorb: meta-hierarchy slot pool
exhausted"` — the per-call slot pool (`NUM_MH_LEVELS` = 12 slots) fully occupied at an
`updateMetaHierarchy` allocation (v0.4 T2; previously a raw `MethodError`); guarded, nothing
displaced or aliased; its typed conversion rides the v0.4 diagnostics catalogue.

## §4 — CRLF normalization (documented, not an error)

Both setup paths chomp `\r\n` — line **endings** normalize to LF; CONTENT-line **content** bytes
stay faithful for arbitrary bytes, including invalid UTF-8 (documented engine behavior for BOTH
invalid-byte classes — lone invalid bytes and decode-requiring sequences such as overlong
encodings; the shipped suite does not exercise invalid-byte content). The
**meta-line plane indexes on character boundaries**: non-ASCII inside a metaLine parses
correctly, and — the ACTION set being ASCII-named at v0, while the label whitelist carries a
fixed pictograph vocabulary since 0.3.0 (`src/alterants-std/labels_vocabulary.txt`) — a
non-ASCII label APPLIED from outside the shipped set or a non-ASCII action meets the stable
unknown-label/unknown-action refusal naming the FULL token
(a GUARDED edge). Goldens are LF. This is a documented normalization, not an error. See
`docs/CANONICAL-OUTPUT.md`.

## §5 — Deferred / not-v0 (do not program against these at v0)

- **Growth beyond the v0 subset** — the language grows by design; the v0 subset forecloses none
  of it. `using()` is a **reserved** name — do not define or rely on it.
- **Cross-implementation conformance tooling** — a conformance interface + adapter (validating
  independent implementations of the language against the shared corpus) exists as internal
  tooling and is not part of the v0 package surface.

## §6 — Versioning policy

**No backward compatibility and no deprecation until at least GoMeta v0.7** — the owner's typed
policy of 2026-09-28 (R-V04B-61), in his words: *"I want clean cuts and no left overs from old
version in newer ones. This policy will hold AT LEAST until GoMeta v0.7."* Every change of the
public surface is a CLEAN CUT — the old name removed; no stub, no alias, no leftover of an older
version in a newer one — and the breaking-change register below is the non-silent record of every
removal or rename (its ground, its replacement, what an older caller sees). The one alias still
standing is the public `PlugIn` = `Alterant` alias of R-V04B-5 (§1.2), removed as a clean cut at
stage 5 of the v0.4 build (R-V04B-62; the v0.5 schedule superseded). The policy will change at a
later stage — maybe v0.8, maybe later — by the owner's word; nothing is promised now. `Project.toml`
carries the version.

**The breaking-change register (every removal, rename or ADDITION of a public name of EITHER tier is written here — the
non-silent record under R-V04B-61; the letter of R-V04B-24 (P) does not govern until at least v0.7).**

- **`GoMeta.outputs` — §1.2 public-not-exported since 0.3.0 — REMOVED at 0.4.0** (no deprecation stub; the
  owner's "as clean as possible NOW"); ground: the renderer and the tree print are development tools
  (R-V04B-13); replacement: the tool's `outputs` after `include("devtools/load_basic_renderer.jl")` at the
  caller's top level; a 0.3.0 caller sees `UndefVarError`; the same-commit triple (code + the document's
  §1.2/§1.3/§2/§3.4/§6 + the surface oracle); the policy's protection read as covering exported names only (P);
  `docs/CANONICAL-OUTPUT.md` re-scoped (the package's canonical observable output = `altValues_evals` (+
  `serialize_evals`, `content_fingerprint`); the pair = the tool's output pinned by the golden layer); the Engine's
  delivered surface after the move = the run and the evaluated values. (i) Of R-V04B-5's practice (the
  `PlugIn` → `Alterant` rename: a PUBLIC 0.4.x alias, removal at v0.5, and a register row with the same-commit
  triple) the REGISTER-ROW-WITH-TRIPLE half is borrowed — code + this document + the surface oracle
  `tests/unit/public_surface_tests.jl` in one commit; the ALIAS half is NOT (B1: a hard removal, no stub).
  (ii) The unified documentation's corrections-ledger row `AU-7` (`GoMetaEcosystem/unified-doc/corrections-ledger.md`)
  records the re-scoping of `U0-orientation.md:35`. Minted 2026-09-11 (R-V04B-24); landed 2026-09-12.
- **`altValues_evals` (function) — EXPORTED since 0.3.0 — RENAMED `readAltValuesEvals` at 0.4.0** (no deprecation stub, as
  R-V04B-24's practice); ground: R-V04B-32 (2026-09-16) — the name `altValues_evals` belongs to the DATA CONTAINER (the part of
  the delivered object, R-V04B-29/31), never to a function; replacement: the reader `readAltValuesEvals` — the same rows, the
  same order, the same type (its argument Q7's, R-V04B-32 — since stage 1's commit 3 the delivered PART:
  `readAltValuesEvals(result.altValues_evals)`, the branch's default under R-V04B-40 (2)); a 0.3.x caller of
  `altValues_evals(result)` sees `UndefVarError` (from stage 1's commit 2 the name `altValues_evals` is the part of
  `GoMetaDelivery`, read by name — a field, never a function); the same-commit triple (the export line `src/GoMeta.jl`, this
  document's §1.1/§1.2/§1.3/§2, the surface oracle `tests/unit/public_surface_tests.jl`). Minted 2026-09-16 (R-V04B-32);
  landed 2026-09-25 on the branch `cc/v04-delivery` (stage 1, commit 1).
- **`GoMetaResult` (type) — EXPORTED since 0.3.0 — RENAMED `GoMetaDelivery` and RE-SHAPED at 0.4.0** (no deprecation
  stub, as R-V04B-24's practice); ground: R-V04B-28 (2026-09-15: the content — `altValues_evals`, the BLS Component
  tree, the status, the diagnostics, nothing else), R-V04B-29 (2026-09-16: the shape — one named object, the four
  parts public by name, no hand-over function), R-V04B-30 (2026-09-16: the name; "result" not descriptive);
  replacement: `GoMetaDelivery` with the public parts `altValues_evals::EvalStore` (the field `verdicts` of 0.3.x,
  given the container's name — R-V04B-32), `blsComponentTree::BLS.ParseState` (the field `state.parse` of 0.3.x, now a
  part), `status`, `diagnostics`; REMOVED: the field `state::ProcessState` (INTERNAL / semver-UNSTABLE "at v0" by its
  own declaration in the 0.3.x docstring and this document's §2 — the working state is never delivered again) and the
  field name `verdicts`; a 0.3.x caller of `GoMetaResult` sees `UndefVarError`, a reader of `.state` or `.verdicts` a
  field error; the same-commit triple (the export line `src/GoMeta.jl`, this document's §1.1/§1.2/§2, the surface
  oracle `tests/unit/public_surface_tests.jl`); one `Base.show` method. Minted 2026-09-15/16 (R-V04B-28/29/30); landed
  2026-09-28 on the branch `cc/v04-delivery` (stage 1, commit 2).
- **`GoMeta.BLS` (module) — ADDED to the package-public tier at 0.4.0** (stage 2's commit 0 of the v0.4 build; R-V04B-33
  "`public BLS` at the Engine's tier with the door of travel / access functions", R-V04B-45, R-V04B-58); ground: his §19 :304
  ("Extensions MUST go through the public surface … the BLS tree structure … some functions provided to travel / access the
  required data") and his §6 :170 (the BLS Component tree "provided by BLS itself"); the same-commit triple (`src/GoMeta.jl`
  `public BLS`, this document's §1.2, the surface oracle `tests/unit/public_surface_tests.jl` — the BLS tier's own testset);
  nothing removed; the set his choice at stage 1's review (item 4 of the stage-1 brief).
- **`GoMeta.BLS.children` — ADDED (public, not exported) at 0.4.0 with the door** — ADAPTED — the legacy's child walk as carried by `eachchildid` over `parentChildComponentPDict`, the store read folded in; Components returned, the insert store's negative ids resolved; one register row (the plan v8 :35; R-V04B-58).
- **`GoMeta.BLS.parent` — ADDED (public, not exported) at 0.4.0 with the door** — ADAPTED — the legacy `getParentComponent` under the door's name; `nothing` for the File; `Base.parent` untouched (read qualified); one register row (the plan v8 :35; R-V04B-58).
- **`GoMeta.BLS.kind` — ADDED (public, not exported) at 0.4.0 with the door** — NEW — the `contentType` field read given a name: `:Meta` / `:Code` / `:Text`, `nothing` for the File (its field is the store's constructor default); no type of BLS made public for it; one register row (the plan v8 :35; R-V04B-58).
- **`GoMeta.BLS.content` — ADDED (public, not exported) at 0.4.0 with the door** — NEW in BLS — the body of the Engine's `cell_content_bytes` copied unchanged (R-V04B-43 (1); the Engine's copy stays at commit 0 and leaves at stage 2, R-V04B-43 (5)); the fifth column then served through the door; one register row (the plan v8 :35; R-V04B-58).
- **`GoMeta.BLS.root` — ADDED (public, not exported) at 0.4.0 with the door** — NEW — the store read `componentsPDict[File][1][1]` given a name; one register row (the plan v8 :35; R-V04B-58).
- **`GoMeta.BLS.flavor` — ADDED (public, not exported) at 0.4.0 with the door** — NEW — the field read `tree.flavor` given a name (the flavor record; its type internal); THE PROMISE (R-V04B-80 (2)(ii)): five fields — `lead`, `hide_marker`, `hide_fold_prefix`, `flavor_tag`, `re_meta_leaded`; the rest of the record (`parse_header!` first) reachable, not promised; one register row (the plan v8 :35; R-V04B-58).
- **`GoMeta.BLS.isHorizontalSpace` — ADDED (public, not exported) at 0.4.0 with the door** — ADAPTED — the parser's horizontal-whitespace predicate (`_is_h_ws`, flavor.jl) given a public name, so that the print tools' lexer classifies whitespace as the parser does; one register row (R-V04B-80 (2)(iii)).
- **`GoMeta.BLS.endsWithNewline` — ADDED (public, not exported) at 0.4.0 with the door** — NEW — the field read `tree.endsWithNewline` given a name; one register row (the plan v8 :35; R-V04B-58).
- **`GoMeta.BLS.getElement` — ADDED (public, not exported) at 0.4.0 with the door** — ADAPTED — the legacy named-element read (settribute flags; the named-int keys — four positions, two store indices, a count, two extension-chain links) declared public as it is, plus ONE Component-taking method `getElement(c, key)` dispatching over the two containers (R-V04B-80 (2)(i); a caller reads no field) — every settribute key and named-int key thereby readable; the Visib flags `:show` / `:hide` / `:discard` lose their meaning at stage 3 (R-V04B-42); one register row (the plan v8 :35; R-V04B-58).
- **`GoMeta.BLS.File` — ADDED (public, not exported) at 0.4.0 with the door** — ADAPTED — the legacy Component type alias declared public as it is; one register row (the plan v8 :35; R-V04B-58).
- **`GoMeta.BLS.Block` — ADDED (public, not exported) at 0.4.0 with the door** — ADAPTED — the legacy Component type alias declared public as it is; one register row (the plan v8 :35; R-V04B-58).
- **`GoMeta.BLS.Line` — ADDED (public, not exported) at 0.4.0 with the door** — ADAPTED — the legacy Component type alias declared public as it is; one register row (the plan v8 :35; R-V04B-58).
- **`GoMeta.BLS.Segment` — ADDED (public, not exported) at 0.4.0 with the door** — ADAPTED — the legacy Component type alias declared public as it is; one register row (the plan v8 :35; R-V04B-58).
- **`GoMeta.BLS.ComponentSettribute` — ADDED (public, not exported) at 0.4.0 with the door** — ADAPTED — the legacy named-element type declared public as it is (`keys(ComponentSettribute)` — the print tools); one register row (the plan v8 :35; R-V04B-58).
- **`GoMeta.BLS.CmpntNamedInt` — ADDED (public, not exported) at 0.4.0 with the door** — ADAPTED — the legacy named-element type declared public as it is (`keys(CmpntNamedInt)` — the print tools); one register row (the plan v8 :35; R-V04B-58).
- **`EvalRecord.decided_by` (field) — ADDED to the public record type at 0.4.0** (stage 2's commit 2 of the v0.4 build; R-V04B-35 (b) "ONE provenance field on the public record type `EvalRecord` — one register row", (d) "the provenance RECORDED where it is known — an origin per queued action at the enqueue, carried through the apply and captured with the record; the never-enqueued :localOnly Heading's at the flush — so that own or indirect is MEASURED, never inferred from a row's presence"); the field `decided_by::Vector{Vector{UInt8}}` — the `key_bytes` handles of the statements that produced the row, in application order (the stating Component's handle: the metaBlock a whole-line metaLine forms, the Segment of an inline one — R-V04B-50; the minted user-context handle on the userMH feed); the delivered ROWS of `readAltValuesEvals` unchanged (R-V04B-35 (a) — the four-tuple, the sort, the count); nothing removed; a 0.3.x or stage-1 caller constructing `EvalRecord` positionally with five arguments sees a `MethodError` (no constructor is public; none exists outside `src/`); the same-commit triple (the type `src/result.jl`, this document's §1.2, the witness `tests/unit/origin_tests.jl` — the surface oracle pins names, not fields); the name the authored set's word (his confirmed scenarios' `decided_by`), the session's default under R-V04B-40 (2), his at stage 2's review. Minted 2026-09-17 (R-V04B-35); landed on the branch `cc/v04-delivery` (stage 2, commit 2).
- **`GoMetaDelivery` (type) — RE-ORDERED at 0.4.0: the field order `blsComponentTree`, `altValues_evals`, `status`, `diagnostics`** (stage 2's commit 2b of the v0.4 build; the owner's word of 2026-10-01 on row 44 of stage 1's review agenda — R-V04B-89 "(b)": his pipeline order, §242 / R-V04B-71, the BLS Component tree first); ground: the parts are read BY NAME (R-V04B-29) — a reader by name sees no change; what changes: the struct's field order (`fieldnames`), the positional constructor's argument order (the two constructor sites in `src/GoMeta.jl`; none outside `src/`) and the one `Base.show` line (now in the field order); nothing removed; the same-commit triple (the type `src/state.jl`, this document's §1.1 table and §2, the surface oracle unchanged — it pins names; the `fieldnames` pin is the agenda's row 45 (a), on his word). Minted 2026-10-01 (R-V04B-89); landed on the branch `cc/v04-delivery` (stage 2, commit 2b).
- **`Alterant.default` (keyword and field) — ADDED to the Alterant registration record at 0.4.0** (stage 2's commit 3 of the v0.4 build; R-V04B-51 (1)–(2) "each Alterant declares ONE default value, as data in the Alterant registry (the Alterant's, not an action's); Visib's default is 'show'"; R-V04B-55 (1)–(3) — the meta level formerly 'default' renamed `fallBack` and consulted LAST by the apply; the Alterant's default delivered by the answer function with the source "default"); ground: his lean of 2026-09-10 (§11), his words of 2026-09-22 (§180) and 2026-09-24 (§197); the slot `NoDefault()` | `Declared(value)` on `PlugIn`'s keyword form (the 6-positional 0.3.x form still constructs, the slot undeclared); the registration digest moves (the fold carries the Alterant's slot — the pin re-measured); the per-action `default` slot of `ActionSpec` (T1) STAYS in this commit, read by no Engine path, and GIVES WAY at commit 3-ii (its removal with the test layer re-homed — a clean cut under R-V04B-61, its own register row then); the internal level constant `defaultMHIdx` renamed `fallBackMHIdx` (not public); the same-commit triple (the record `src/state.jl`, this document's record vocabulary, the witnesses `tests/unit/record_schema_tests.jl`). Minted 2026-09-22/24 (R-V04B-51/55); landed on the branch `cc/v04-delivery` (stage 2, commit 3).
- **`ActionSpec.default` (keyword and field) — REMOVED at 0.4.0** (stage 2's commit 3-ii of the v0.4 build; R-V04B-51's effects "the per-action `NoDefault()` slots of the registry give way to one per-Alterant slot"; R-V04B-61 clean cuts — no stub); ground: the default is the Alterant's (R-V04B-51 (1): "the Alterant's, not an action's"), declared at commit 3 (the row above); replacement: `PlugIn(; …, default = …)`; an action record constructed with `default = …` sees a `MethodError` (no such keyword; the 8-positional 0.3.x form still constructs), a reader of `spec.default` a field error; the registration digest moves (the per-action part leaves the fold — the pin re-measured); the same-commit triple (the record `src/state.jl`, this document's record vocabulary, the witnesses re-homed — `record_schema_tests.jl`, `registry_lifecycle_tests.jl`, `vocabulary_tests.jl`, `snapshot_property_tests.jl`). Minted 2026-09-22 (R-V04B-51); landed on the branch `cc/v04-delivery` (stage 2, commit 3-ii).
- **`GoMeta.evaluatedAltValue` (function) + `GoMeta.EvaluatedAltValue` (type) — ADDED (package-public, not exported) at 0.4.0** (stage 2's commit 4 of the v0.4 build; R-V04B-35 (c) "the ENGINE ANSWERS, on demand, ONE resolved value per Component per Alterant with a source of own / indirect-through-C / default, the answer shape UNIFORM across Alterants"; R-V04B-52 (2) a Segment's answer its own rows if any, else its Line's marked indirect; R-V04B-53 the levels' room — `:user`, `:file`, `:fallBack` reserved; R-V04B-55 (2) the Alterant's declared default with the source `:default`): `evaluatedAltValue(delivery, component, alterant; registry = DEFAULT_REGISTRY) -> EvaluatedAltValue(value, source, via)` — derived at the call from the delivered rows and `decided_by`, never stored; the delivered ROWS unchanged; nothing removed; the same-commit triple (the code `src/answer.jl` and the `public` declaration in `src/GoMeta.jl`, this document's §1.2 + §2, the witnesses `tests/unit/answer_tests.jl` with `public_surface_tests.jl` 40 → 42); NOT FINAL — the name DECIDED at stage 2's review (his word of 2026-10-03, §305; R-V04B-95 — the RENAMED row below); the per-call walk (Q6, card C8) DEFERRED to the benchmark phase (§307; R-V04B-97); the tier, the File's case (`:none`) and the equal-child rows (OQ-148) carried past the branch (C23); the letter of R-V04B-24 (P) does not govern until at least v0.7.
- **`GoMeta.scanAlterant` + `GoMeta.evaluatedAltValues` (functions) — ADDED (package-public, not exported) at 0.4.0** (stage 2's commit 5 of the v0.4 build; his §6 item 9.A — the scan for the Components that got values of an Alterant, "unambiguous, and informative"; the plan v8.1 :57; card 4): the scan by Alterant and the access by Component, thin reads over `evaluatedAltValue` — functions of their own (the session's default, R-V04B-40 (2)); the alternative as methods of the reader banked as a labelled diff beside the commit; the delivered ROWS unchanged; nothing removed; the same-commit triple (the code `src/scan.jl` with the `public` declaration, this document's §1.2 + §2, the witnesses `tests/unit/scan_tests.jl` with `public_surface_tests.jl` 42 → 44); NOT FINAL — the names DECIDED at stage 2's review (§305; R-V04B-95 — the RENAMED row below); the form (functions of their own) stands, its alternative banked; the letter of R-V04B-24 (P) does not govern until at least v0.7.
- **`GoMeta.childDiffers` (function) — ADDED (package-public, not exported) at 0.4.0** (stage 2's commit 6 of the v0.4 build; R-V04B-35 (e) "his (ii) child-differs signal COMPUTED from that answer, its stored form left to the benchmark phase"; his §37 item 4.2; the plan v8.1 :58): `true` when a Component's resolved answer's VALUE differs from its parent's — computed from `evaluatedAltValue` at the call, never stored; the per-child primitive from which his (ii) per-parent Boolean is computed (`any` over the parent's children; the aggregate's form the benchmark phase's); the delivered ROWS unchanged; nothing removed; the same-commit triple (the code `src/childdiff.jl` and the `public` declaration in `src/GoMeta.jl`, this document's §1.2 + §2, the witnesses `tests/unit/childdiff_tests.jl` with `public_surface_tests.jl` 44 → 45); NOT FINAL — the name kept at stage 2's review (R-V04B-95); the Block-against-File reading carried past the branch (C23); the letter of R-V04B-24 (P) does not govern until at least v0.7.
- **`serialize_evals(ann)` — the four-column public form's `attr` column ENCODED at 0.4.0** (stage 2's commit 7a of the v0.4 build; the CrossReview set REAL-1 R1 #2 — "a tab/newline stem breaks the one-verdict-per-line format"; the set's cure sentence verbatim: "Reject record delimiters in attr_stem at registry.jl:917, or encode attr in both serialize_evals overloads." — narrowed to the four-column form by the plan v8.1 :62, the five-column form being the test layer's since commit 8 and gone from the Engine at commit 9b; the other arm a labelled diff for his word at the review, card C9): a backslash, tab, newline or carriage return in an attribute name is escaped as `\\`, `\t`, `\n`, `\r`, so one row stays one line and four columns; a correctness fix of the form's own format — the shipped attribute families carry none of the four and serialize byte-identically (the pinned [8g] output unchanged); the five-column golden producer untouched (the twelve pins unmoved; removed at commit 9); the other arm — record delimiters refused at registration — NOT landed, hardening his §120 defers (R-V04B-37), a one-line question with its diff at stage 2's review; the same-commit triple (the code `src/annotations.jl`, this document's §1.2 + §2, the witness `tests/unit/public_surface_tests.jl` [8h]); the letter of R-V04B-24 (P) does not govern until at least v0.7.
- **`GoMeta.content_fingerprint` — §1.2 public-not-exported since 0.2 — REMOVED at 0.4.0** (stage 2's commit 9b of the v0.4 build; R-V04B-43 — the 4D phrase his word §156 adopted, its clause (1): "the stored copy goes, the public function goes, and no Engine function serves a piece's text — it is read from the BLS Component tree through BLS's own access function"; his questions OWNER-WORDS §154 and his word §156; no deprecation stub — the owner's "as clean as possible NOW"): a 0.3.x caller sees `UndefVarError`; replacement: `GoMeta.BLS.content(delivery.blsComponentTree, component)` for a piece's text, the Component reached through the door (`GoMeta.BLS.children`) or named by the answer function (`GoMeta.evaluatedAltValue(…).via`, `GoMeta.scanAlterant`); the shipped consumers (`find_by_label.jl`, `notebooks_from_source.jl`) re-routed that way at commit 9a (R-V04B-43 (2)); the same-commit triple (`src/GoMeta.jl`'s `public` line, this document's §1.2/§1.3, the surface oracle `tests/unit/public_surface_tests.jl` — the tier's count 45 → 44); the policy's protection covers exported names only (P).
- **`EvalRecord.content` (field) — REMOVED from the public record type at 0.4.0** (stage 2's commit 9b; R-V04B-43 (1); R-V04B-43's effects: "a second change to that public type beside the origin field of R-V04B-35 (b), its own register row"): a reader of `.content` sees a field error; the row names its Component by `cell_handle` and carries no copy of its text; the record's fields are `cell_handle`, `attr`, `value`, `polarity`, `decided_by`. The one row without a piece in the tree — a heading fed through the configuration's user profile — carries an empty fifth column in the test layer's derived form (R-V04B-43 (4); his word OWNER-WORDS §277, R-V04B-90).
- **`GoMeta.serialize_evals(::GoMetaDelivery)` (the five-column method) — REMOVED at 0.4.0** (stage 2's commit 9b; R-V04B-43's effects): the golden layer's five-column form is the TEST layer's since commit 8 — `TestSupport.derive_annotations_golden(delivery)` (`tests/support/derive_annotations.jl`), its fifth column a piece's text through the BLS Component tree and `GoMeta.BLS.content`; the twelve reference files byte-identical by both producers while both existed (R-V04B-43 (3); commit 8's standing proof), unmoved at the removal; the four-column `serialize_evals(ann)` stays the Engine's one serialization; the Engine's internal `cell_content_bytes` superseded by `GoMeta.BLS.content` (R-V04B-24/25's tidy-up list).
- **The Visib write-back into the BLS Components — REMOVED at 0.4.0** (stage 3's commit 4 of the v0.4 build; R-V04B-42 (1) — his word of 2026-09-22, OWNER-WORDS §153: *"I approve your recommendation: 3A."*, the phrase 3A the session's: "Remove the Visib write-back into the Components, together with the two things in the Engine that exist only for it — the internal marker it raises and the two refusals that read that marker"): the two write sites (the Block grain in the driver loop; the Segment grain onto the Line in the absorb walk), the latch `wrote_back` of the per-call state, the diagnostic code `STATE_SEAL_MISMATCH` and the POISONED variant of `STATE_REUSE_REFUSED` (the ledger's `registry` and `poisoned` fields with them). A consumer that read a Component's `:show`/`:hide`/`:discard` flag reads FALSE for every Component — the Engine's answer is `evaluatedAltValue` (§1.2; the basic renderer and the development tools read it since this stage's commits 1 and 2). The three flags' declarations STAY until his word (R-V04B-42 (2); stage 5): the registry's `settribute` slots, the derived `action_to_settribute` table, the three names inside BLS, `RenderDecl.materialize`. The E-04 crash origin (§3.1) retired with the write-back's read. Proved by 0 of 7 committed renders moving (R-V04B-42 (3)).
- **The declared defaults of Labels, Heading and Id — ADDED at 0.4.0** (card C2 of stage 2's review; the owner's word of 2026-10-02, OWNER-WORDS §287: *"I do approve your recommendation: declare."* — R-V04B-92; PROVISIONAL in his words: the values may change once used on real examples): `Labels` declares the empty set `Symbol[]`, `Heading` declares `nothing`, `Id` declares the zero compound `(cell = Int16(0), parent = Int16(0), file = Int16(0))` (Visib's `:show` since stage 2's commit 3). For a Component with no rows of the Alterant anywhere up the tree, `evaluatedAltValue` now returns `(value, :default)` where it returned `(nothing, :none)`; the source `:none` remains for the File and for an Alterant of a custom registry without a declared default. The registration digest moved with the record (the tenth re-mint, measured): `0x0956eed205fef8ac` → `0x0e7836ce6e6b53ae`. `childDiffers` FOLLOWS (card C12's reading: a top Block compares against the File's `nothing`): every top Block now differs for Labels and Id as it did for Visib (`false` → `true`); Heading's `nothing` against the File's `nothing` still does not. Id's declared compound names the type's three fields in the type's order `(cell, parent, file)`; a row-derived compound carries only the RECORDED fields — two shapes no consumer compares by `==` today (the decisions seat's F-5).
- **The answer function's SOURCE for a Line decided by its own trailing metaSegment, and for that Line's Segments — CHANGED at 0.4.0** (card C24 of stage 2's review; the owner's words of 2026-10-02, OWNER-WORDS §286 and §288 — R-V04B-93; the letter of R-V04B-52 (2)): the Line answers `:own` (before: `:indirect` through the Segment); a Segment without rows of its own answers AS its Line answers — the Line's `:own` marked `:indirect` through the Line (before: `:own` when the deciding handle was the Segment's own key; `:indirect` through that metaSegment for the Line's other Segments), every other source unchanged as before (`:indirect` through the Line's own decider, `:user` under a fed profile, `:file`). An inline heading's row stays keyed on its Segment (R-V04B-50) — not touched by this commit. The VALUES, the rows and their `decided_by` are unchanged.
- **`answerFor`, `answersFor` and `AltAnswer` — RENAMED at 0.4.0 to `evaluatedAltValue`, `evaluatedAltValues` and `EvaluatedAltValue`** (card C4 of stage 2's review; the owner's word of 2026-10-03, OWNER-WORDS §305: *"I approve C4: evaluatedAltValue"* — R-V04B-95; his §295 of 2026-10-02: "that is what you get when calling that function"): the names only — the signatures `evaluatedAltValue(delivery, component, alterant; registry)` and `evaluatedAltValues(delivery, component; registry)`, the record's fields `value`, `source`, `via`, the seven source tags, the tier (package-public, not exported) and every behaviour unchanged; `scanAlterant` and `childDiffers` keep their names; the file names `src/answer.jl` and `tests/unit/answer_tests.jl` stay. The earlier entries of this page read the new names (a living page, renamed with the code — its §6 row for card C2 among them; the two NOT FINAL notes — `src/answer.jl`'s header and this page's entry on the function — name `answerFor` as the former working name); the build record's rows, the commit messages and the receipts that say `answerFor` describe the same function under its former name.
- **The inline heading's KEY and the commented metaLine's carrier — CHANGED at 0.4.0** (item A6 of the stage-3 close sitting; the owner's word of 2026-10-03, OWNER-WORDS §309: *"1.: I approve your recommendation: (b)"* — R-V04B-98; stage 5's commit E1; the three forms on his word of 2026-10-05, OWNER-WORDS §324 — R-V04B-109; the golden re-pin on his §323 — R-V04B-108): the heading stated in a Code Line's trailing metaSegment is keyed on the LINE with the Segment as the key's origin, as every inline statement is, and the Line answers it `:own`, its Segments `:indirect` through the Line (before: keyed on the Segment, which answered `:own` while its Line answered the default); a metaLine split by a trailing `##` comment hands its statement Segment over with the metaBlock as the carrier, so its heading row is keyed on the metaBlock and EVERY statement on such a metaLine records the metaBlock as its deciding statement (before: the statement Segment — a defect against R-V04B-50; the answer function's source for the two legacy examples' rows moves from `Segment n:s-e` to `Block a-b`); the level constant `head_10` unchanged; the degenerate-key warning `WARN_DEGENERATE_OCCURRENCE_KEY` (both sites) REMOVED (census row 52, his §317); the golden `heading_quoted_first.jl.ann.txt` re-derived and the comparison forms `heading_quoted_first`, `file_for_Example_Extended`, `file_for_Example_Proposal_JuliaCon` re-made (the header's sha = the parent 79ea54cd).
- **The registration validation chain and the clash-disposition switch — REMOVED at 0.4.0** (stage 5's E4 of the v0.4 build; census rows 3 and 51 of the stage-5 census, the owner's bulk mark of 2026-10-03, OWNER-WORDS §317 — R-V04B-105; his §19 — the public surface 'RESTRICTED TO THE NECESSARY functionality' — and his §20 'RESTRICT THAT INTERFACE TO A MINIMUM'; his §120 no hardening before the framework works): the validation chain of v0.4 T2–T4 — the tier-1 record shape law (the closed enum sets, the kinds/kind_sources, queryable, dispatch-target uniqueness, plugin-index, settribute-key and MutEx rows; the capture identity, stem-shape and stem-clash laws), the tier-2 inventory law (`REG_UNKNOWN_SETMODE`, `REG_DUPLICATE_ALTNAME`, `REG_RESERVED_SHADOW`, `REG_MUTEX_CONFLICT`, `REG_UNINTERPRETED_REQUIRES`, `REG_CONTRACT_VERSION`, the validate-time `REG_SLOT_EXHAUSTED`), the clash law with both arms and the switch (`REG_DUPLICATE_ACTION`), the reflection cross-check (`REG_SIG_MISMATCH`), the value-algebra and reachability refusals (`REG_VALUE_ALGEBRA`, `REG_UNREACHABLE`), the candidacy warning (`REG_CANDIDACY`) and the eager dependency closure (`DEP_MISSING`) — left `src/alterants/registry.jl` (−726/+79 lines) with the four dead closed-set constants of `src/state.jl`; `validate` runs the domain probe (R-V04B-4 (iii) — the one domain definition shared by `validate`, `publish`'s copier and the door's walker), the four capture mode-gate laws of the Heading's :localOnly lane (until R-V04B-101, after the branch) and the vocabulary check (census row 10's commit). MEASURED consequences (the build record's receipts `PROBES-e4-validate_stage1-src-cut_on-1c9d013f.txt`, `PROBES-e4-capture-laws_stage1_on-1c9d013f.txt` and `PROBES-e4-seat-notes_on-1c9d013f.txt`):a duplicate action name resolves FIRST-wins in the derived tables (the legacy's Dict assignment was last-wins); a `:candidate` without activation publishes silently; an `altConstructor` without a zero-arg method publishes and meets `CB_CTOR_THROW` at the first mint, naming the `MethodError`; a capture `instance_type ≠ altConstructor` publishes and floors `WARN_CAPTURE_UNREADABLE`; a stem overlapping a shipped family publishes — on one cell the two plugins' same-attr rows collapse to one row (full structural namespacing is T11's row); a capture scheme outside the walk's four arms with gate `nothing` publishes and falls through the walk — no row, no floor (T11's catalogue row); a kind or source literally named k/s is no longer refused at registration, so such a record's fingerprint can alias another's — a fingerprint-only class inside R-V04B-4 (v)'s disclosed-lossy bound; a builder pushed past 127 plugins or actions, or with a dangling plugin index, DIRECTLY (bypassing `register!`, which refuses both typed) fails raw at `publish` (`InexactError`) or at apply (`BoundsError`) — the honest bound of the bypass; `publish`'s warning path stands with no remaining check that warns.
- **`GoMeta.BLS.content(tree)` — ADDED (public, not exported) at 0.4.0** (stage 5's s5c8 of the v0.4 build; his word of 2026-10-05, OWNER-WORDS §333, R-V04B-116 (3)(b)): the document's lines joined by a newline, as bytes (no terminal newline — `endsWithNewline` carries that fact; a CRLF line end's CR dropped by the line split), the one-argument method of the door's `content` — not a `(tree, ::File)` arm of the two-argument form, whose empty return for a File is the Engine's capture predicate (untouched); the development tools' last two reads outside the door left with this commit — the File's text through this method, the renderer's whitespace guard before the hide marker through `isHorizontalSpace` (R-V04B-116 (3)(a); over a Char the two predicates differ at \v, \f, \r and U+0085 — stripped by the internal guard alone — and at U+180E — by the public class alone; no corpus input carries any of the five, the build record's receipt `PROBES-s5c8-whitespace-class-bytes_on-450d1476.txt`) — and the texts of the lapsed exemption D-6(a) with them.
- **`run_absorb_apply!` (the callable driver seam), its state ledger (`STATE_REUSE_REFUSED`), `validate_carrier_state` and the `_walk_and_apply!` factoring — REMOVED at 0.4.0** (stage 5's E2 of the v0.4 build; census rows 21, 42, 23 and 44 of the stage-5 census, the owner's bulk mark of 2026-10-03, OWNER-WORDS §317 — R-V04B-105; his verbatim of R-V04-31 on the seam: "If this is only to the benefit of the .fodt adapter it will eventually have to be removed from the GoMeta engine - if not in v0.4, then in a later GoMeta version."; the legacy was one function): `goMeta(bytes; config, registry)` is the ONE route into the Engine; the driver body (the fresh per-call state, the user feed, the File loop, the delivery) runs inside it; a caller-built store has no entry and no checker; `names(GoMeta)` unchanged (none of the four was a `public` name). The corpus, the 26 pins and the twelve forms byte-identical (the pre-check); the suite count moves by the retired witnesses alone.
- **The Labels vocabulary machinery — `VocabularySlot`, `InlineVocabulary`, `VocabularyRef` (the record's `vocabulary` slot, field and keyword), the G-VOC triple `vocabulary` / `vocabulary_member` / `vocabulary_queryable`, the `SRC_DIGEST_MISMATCH` code, the digest pin, the capture cache, the artifact grammar, the scope law, the write-only valve and the labels record's policy identity — REMOVED at 0.4.0** (stage 5's E9 of the v0.4 build; census rows 10, 28 and 55 of the stage-5 census, the owner's bulk mark of 2026-10-03, OWNER-WORDS §317 — R-V04B-105; his words of 2026-09-20, OWNER-WORDS §120: "Similarly CC kept on pressuring me into making the Labels Alterant safe before we even could try working with a basic true Labels Alterant."): the 38 names stay in the plain file `src/alterants-std/labels_vocabulary.txt`, read at load (R-V04B-6 (a); the file byte-identical — the ZWJ line's `query=false` field, the owner's R-V04-36 content ruling, inert data now); `setLabels` keeps the closed check (an unknown label APPLIED refuses, naming the accepted set); `checkLabels` answers false for an unset or unknown label — the legacy's (GoMetaRetro Alterants.jl :87–:99); a `PlugIn` keyword `vocabulary = …` is a `MethodError` now; `names(GoMeta)` loses six. The corpus, the 26 pins and the twelve forms byte-identical (the pre-check); the registration digest re-minted (the labels record's slots leave the seal fold — `profile_snapshot_tests.jl`, measured).
