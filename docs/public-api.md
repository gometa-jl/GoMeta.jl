# public-api.md — GoMeta's declared public API (the semver surface) + the error-mode catalogue

**Status:** the declared public API and error-mode catalogue of GoMeta `0.4.0` (candidate; the v0.4
build's branch `cc/v04-delivery` in progress — its stages and every ruling in the build record
`plan/2026-08-24-gometa-v04-build/`; alpha maturity). Backward compatibility with 0.3.x is NOT
promised (the v0.4 ruling); the breaking-change register ships with the release.

---

## §0 — Scope

**IS.** The reference for `GoMeta`'s **public API** — the declared, semver-versioned surface a
consumer (a script, a downstream tool, or another implementation of the GoMeta language) programs
against — together with the **coded error-mode catalogue** (the codes a `goMeta` call can surface
as `Diagnostic`s) and the honest partition of which codes are armed, which are deferred, and which
crashes remain latent or are guarded by a stable refusal.

**DOES.** (1) names the **exported** surface (§1.1) and the **package-public** supporting names
(§1.2); (2) names the Engine's output surface — `altValues_evals` (+ `serialize_evals`),
the Engine's delivered surface after the move — and the development tool's (tree, render) pair, obtained only
through `Main.BasicRenderer.outputs` loaded by the one loader and pinned byte-exact by the test layer (§1.3); (3) restates each public signature + its contract (§2); (4) enumerates
the coded error catalogue with its honest partition (§3 — the 0.3.x rows as the tables list them, plus the v0.4
registration/door rows of §3.5); (5) records the
CRLF-normalization convention (§4), the explicitly **deferred / not-v0** surfaces (§5), and the
**versioning policy** (§6: clean cuts — no compatibility promise — until at least v0.7; R-V04B-61).

**REASONING.** The API is **TOTAL over the ENTRY surface** — the registry door's two refusals (§3.5) never throw an
uncaught exception; they fail-close into a `PROCESS_ERROR` result carrying a coded `Diagnostic`; an unknown `flavor_tag`
throws `flavor_for`'s stable message (§3.4 — stage 5's E8 of the v0.4 build, census row 30), a `parse_range` is taken plain
(§2), and no configuration field is refusable since stage 5's E13 (the config-time profile row E-03 left with the grammar
profile — census rows 1 and 30; §3.1). The absorb- and apply-plane rows are the honest exception: they can still throw at
v0 — the §3 partition (the stable-message refusals of §3.4; the E-04 crash-origin row of §3.1 RETIRED at stage 3's
commit 4 of the v0.4 build — its origin was the Visib write-back). Honesty over completeness: the row not yet armed
(the E-06 guarded refusal — §3.1) and the crashes still latent or refused with a stable message (§3.4) are documented
**as such**, never papered over with a fabricated code. A `{…}` condition is Julia's since stage 5's E13: the
unknown condition key (the vocabulary's), the no-expression guard of an empty block or a bare literal and — since s5c31, the
owner's word §366 — a `(` left open inside the body are the three condition refusals GoMeta mints (stable `GoMeta absorb:`
messages); a body Julia cannot parse is Julia's own `Meta.ParseError`; a condition that fails at evaluation is Julia's own error (§3.2).

**PURPOSE.** The stable contract a consumer programs against and a reviewer audits the surface
against — the human-readable mirror of the machine-checkable export set (`names(GoMeta)`, asserted
by `tests/unit/public_surface_tests.jl`) and of the refusal behavior the shipped witnesses assert
(`tests/unit/error_message_tests.jl` · `tests/unit/arg_guard_tests.jl` · `tests/unit/condition_tests.jl` ·
`tests/unit/slot_overflow_tests.jl` · `tests/unit/malformed_meta_tests.jl` · `tests/unit/parser_quality_tests.jl` — the last three
re-cut at stage 5's s5c29 for the grammar's one refusal and the slot bound; the witnesses of the former v0.2–v0.3 walls left at E7 —
census row 41).

## §1 — The public surface

### §1.1 — Exported names (the re-exported semver surface)

`using GoMeta` brings **exactly these four** names into scope — the declared public surface:

| Name | Kind | One-line |
|---|---|---|
| `goMeta` | function | the pipeline entry — `goMeta(bytes; config, registry) -> GoMetaDelivery` |
| `readAltValuesEvals` | function | the reader over the evals rows — the evaluated Alterant values, per piece of the file (the production surface) |
| `GoMetaConfig` | type | the v0 input options |
| `GoMetaDelivery` | type | the delivered object of a run — its four public parts, in his pipeline order (R-V04B-89): `blsComponentTree`, `altValues_evals`, `status`, `diagnostics` |

`names(GoMeta)` is exactly this set plus the §1.2 public names (27 since stage 5's E14 of the v0.4 build — census row 54, the tier at its
ruled names, the `PlugIn` alias left, R-V04B-62; every change of the set since 0.3.x is a row of §6) and the module name — the
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
- `Diagnostic` `{code::Symbol, severity::Symbol, message::String, context::Any}` — the coded,
  non-throwing diagnostic record.
- `AlterantRegistry` + the `const DEFAULT_REGISTRY` — the deterministic alterant inventory (the
  `goMeta` default registry), a PUBLISHED (validated + sealed) value since v0.4. **What a custom
  registry can do at THIS build state (v0.4.0-candidate; Stage-A rows T0–T5 landed; no registration-time
  signature reflection since stage 5's E4 of the v0.4 build; T11's catalogue sitting):** it is
  built through the lifecycle below, its declared record + derived tables + callables are
  sealed and door-checked, its setters DISPATCH (the apply plane is registry-data-driven) and a
  registry without the built-in Visib RUNS; the CAPTURE plane is registration-driven since T5 (a
  declared `CaptureDecl` row mints an Alterant's evals rows; a record without one mints none — the LIFECYCLE bullet
  below and §3.4); NOT registration-driven at v0.4 (the deferred rows): the QUERY plane's argument shape
  (the getter is called with whatever the re-written condition passes — label names as Symbols; a non-Symbol argument
  meets `getAltState`'s own `Vararg{Symbol}` MethodError at apply, stage 5's E13; the getter's signature is not verified at
  registration), and the RENDER write-back (the Visib write-back LEFT at stage 3's commit 4 of the v0.4 branch, R-V04B-42 (1) —
  the Engine writes nothing into the BLS Components; the `settribute` declarations and the derived table LEFT at stage 5's E12 of the v0.4 build — census row 45, the word R-V04B-42 (2) waited for; nothing writes back). The release contract page states,
  per slot, which row consumes it.
- **The registration LIFECYCLE (v0.4):** `RegistryBuilder()` (empty) or
  `RegistryBuilder(DEFAULT_REGISTRY)` (PRELOADED with the four built-ins, copied by the domain
  copier — nothing mutable shared with the published value; a cycle, an out-of-domain value or
  a position-rule offense in the input refuses coded — the way
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
  residue is closed; derives the hot-path tables from the declarations and takes the SNAPSHOT baseline the door
  compares against (the fingerprint `seal` it also minted left at stage 5's E13 of the v0.4 build — census row 6; the §6 row).
  `RegistrationRefused <: Exception` — `.diagnostics::Vector{Diagnostic}` with stable codes
  (`REG_PROTOCOL` for a declared value outside the closed encodable domain or a capture mode-gate law;
  `REG_PROTOCOL` and `REG_SLOT_EXHAUSTED` thrown by
  `register!` — the eleven inventory, clash, reflection, algebra, reachability and candidacy codes left at
  stage 5's E4, §3.5 + §6). Positional `AlterantRegistry(...)`
  construction from hand-built tables is GATED at v0.4.0 (it runs the same checks and refuses
  inconsistent tables with `REG_DERIVED_TABLES`) and yields an UNPUBLISHED value that `goMeta`
  refuses — build through the lifecycle; positional construction is removed at v0.5. No positional
  form accepts a snapshot (the generated all-fields constructor is suppressed by a construction
  token); a published registry's containers are READ-ONLY by contract — the door detects, for
  conforming code and within the disclosed bounds below, a mutation of ANY walked field (the
  declared record, every derived table, every callable identity) by ONE
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
  constrains a loaded module):** every integrity guarantee here is ACCIDENT-grade — coded
  refusal of unpublished or post-publication-mutated registries produced by CONFORMING code.
  It is not security-grade: the construction token is reachable by
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
  `validate`, constructor — each a snapshot leaf the door compares by `===`); inside a
  data value (`Declared`, any container in it) it is refused. A declared
  value of ANY other type — a range, a view, a user container, `BigInt`, `Char`, an enum, an
  opaque struct — or a cyclic container is REFUSED at `validate` (`REG_PROTOCOL`, one row per
  record slot), never folded by a lossy fallback; declared string VALUES are `String`-only
  since T2-bis (a non-`String` `AbstractString` value that published before refuses coded —
  a registered 0.4.x contract narrowing). The canonical slot ENCODING has one reader since stage 5's E13 of the v0.4
  build — the validate walk's deterministic Dict-entry order (the registration digest it fed — E13 —, and the `seal` fingerprint
  that digest minted, left with the grammar profile — census row 6; the §6 row): its disclosed collisions (type identities
  module-UNQUALIFIED; the designated callables by NAME; function-valued type parameters by name; untagged parameter
  categories; un-encoded container parameters) mean only that two such keys sort as equal texts. **The door's guarantee
  reads:** a post-publication mutation of any walked field by conforming code is detected iff it changes the
  content-structural value (`===` at the leaves) — the honest bound above states the disclosed exceptions; `validate`'s
  domain walk probes every type-bearing field (a type such as `Val{'c'}` refuses with a slot-named row; a type whose
  parameter tree exceeds the type-encoder budget of 256 nodes likewise refuses slot-named — the mint that budget kept
  safe left at E13, the bound stays as the domain's declared closure). Declared values are `String`-only and
  `deepcopy_internal` is never dispatched. No shipped declaration uses any of the collision shapes.
- `GoMeta.next_plugin_index(builder) -> Int8` — the index the next `register!` assigns (§ the
  plugin index rule below); throws `RegistrationRefused` (`REG_SLOT_EXHAUSTED`) at capacity.
- **The record VOCABULARY (v0.4; what `register!` accepts — the Alterant registration record and
  its action records; construct with the keyword forms). The record type's name is
  `Alterant` — his legacy's `PlugIn` renamed at v0.4 (R-V04B-5); the public alias `PlugIn` LEFT at stage 5's E14 of the v0.4 build as a
  clean cut (R-V04B-62, R-V04B-61; the §6 row); the record's FIELD NAMES are his legacy's and stay (the keyword constructor is the one
  form):**
  - `Alterant(; altName, setMode, altConstructor, setAltInstance, getAltInstance = nothing,
    precedencesTuple = nothing, default = NoDefault(), capture)` — the Alterant registration record. `default` = `NoDefault()` |
    `Declared(value)` — the Alterant's ONE declared default value (R-V04B-51 (1)–(2); R-V04B-55 (1): Visib declares
    `:show`; since the owner's word of 2026-10-02 (card C2, R-V04B-92 — provisional) Labels the EMPTY SET `Symbol[]`, Heading
    `nothing`, Id the zero compound `(cell = 0, parent = 0, file = 0)`), delivered by the answer function with the source
    "default" where no level provided a value (R-V04B-55 (2)); since stage 2's commit 3 (the per-action `default` of the
    action record below GAVE WAY to it at commit 3-ii). Required:
    `altName::Symbol`; `setMode ∈ (:accumulate, :mutExclusive, :mutExclusivePerField, :localOnly)`;
    `altConstructor::Type` (the instance type); `setAltInstance::Function` (the setter — its methods ARE the
    action's forms; the declared overload rows that restated them left at stage 5's E11 of the v0.4 build —
    census row 16). Optional, every one nothing/empty-defaulted: `getAltInstance` (the query getter, required
    for an action used as a condition atom); the v0.4 declared slots below. The positional 0.3.x form left at
    stage 5's E11 of the v0.4 build (census row 65; R-V04B-61 — clean cuts): the keyword form is the one form.
  - `ActionSpec(; name, plugin, accepts_string_slot = 0, validate = nothing)` — one action
    record. `plugin::Int8` = the declaration-order index of the OWNING Alterant (`register!` binds it: every record
    passed with a plugin must name that plugin's index); `accepts_string_slot` = the accepting String-literal slot
    (0 = none); `validate` = the handover validation (below). (The `settribute` write-back key left the record at stage 5's E12 of the
    v0.4 build — census row 45; the per-action `default` keyword of v0.4's T1 GAVE WAY at
    stage 2's commit 3-ii — the default is the Alterant's.)
  - `ActionOverload`, `spelling`, `sugar_candidacy`, `keyed_slot` — **REMOVED at 0.4.0** (stage 5's E11 of the v0.4 build;
    census row 16; the §6 row): the per-setter-method rows (signature types, literal kinds, return type, effect,
    queryability, applicability, phase, grammar flag) restated what the setter's methods declare and were read at run
    time by nothing since stage 5's E6 (the registration digest — left at E13 — folded them, the door walked them); the spelling tag, the
    sugar register and the reserved slot were read by nothing but the fold. An action is registered by its name and its
    owning Alterant, and Julia dispatch does the rest — his legacy's form; the 8-positional record constructor left too (census row 65,
    R-V04B-61).
  - **The getter contract** (`Alterant.getAltInstance`, required for an action used as a condition atom — the `queryable` row flag left at stage 5's E11, census row 16):
    called as `getter(instance, actionName::Symbol, args::Symbol...) -> Bool` — the re-written condition calls it bare
    through `getAltState(Int8(p), Symbol("action"), args…)` as his legacy did (stage 5's E13 of the v0.4 build; the
    `getAltState` call bare since stage 5's E5 — census row 56): a label name reaches it as a Symbol; a non-Symbol
    argument meets `getAltState`'s own `Vararg{Symbol}` MethodError; a getter's throw propagates raw out of the `goMeta`
    call; a non-`Bool` return is Julia's own `TypeError` where the condition needs a Bool (E13: the closed interpreter's
    `CB_QUERY_THROW` / `RES_RETURN_TYPE` envelope at its atom left with the interpreter at E13 — §3.4). The getter's signature is
    not verified at registration (the `queryable` row flag and its existence check left — stage 5's E4 and E11). No
    registration-time signature reflection runs since stage 5's E4 (T11's catalogue sitting).
  - **The validate contract** (`ActionSpec.validate`, the handover validation of the accepting
    String slot): called as `validate(text::String) -> Bool` — `true` accepts; `false` refuses with the
    catalogue-named stable message (`REG_VALIDATE_FALSE` — an `ErrorException` carrying the name, the §3.4 T3
    seam-envelope family; its coded-`Diagnostic` conversion the T11 catalogue); a non-`Bool` return refuses
    (`RES_RETURN_TYPE`); a throw of
    any other class wraps (`CB_VALIDATE_THROW`, the class named via `nameof`, never its text).
    A validator may refuse with its OWN complete stable message by throwing an `ErrorException`
    whose message begins `"GoMeta "` — the engine's guarded-refusal vocabulary, passed
    through the envelope verbatim (the shipped heading validator's ratified empty-text refusal
    is exactly this class); any other throw is a validator DEFECT.
  - **The constructor dependency** (`Alterant.altConstructor`): must be ZERO-ARG constructible —
    it is called bare at the three instance-mint sites since stage 5's E6 of the v0.4 build (census row 14): an
    absent zero-arg method or a throwing constructor is Julia's own error out of the `goMeta` call (the eager
    `DEP_MISSING` gate at `validate` left at stage 5's E4; the mint wrap `CB_CTOR_THROW` left at stage 5's E6, and the
    per-invocation store-identity check `RES_FOREIGN_STORE` with it — census row 14, the set-invocation seam).
  - **The plugin index rule:** `ActionSpec.plugin` is the declaration-order index of the owning
    Alterant, an `Int8` you supply — `GoMeta.next_plugin_index(builder)` returns the index the
    NEXT `register!` call will assign (1 on an empty builder; 5 after the four built-ins), and
    `register!` REFUSES (throws `RegistrationRefused`, `REG_PROTOCOL`, nothing appended) any record
    whose index is not that one. Immutable records are never re-stamped silently.
  - The declared SLOTS: `CaptureDecl(attr_scheme ∈ (:per_key, :single, :per_field, :per_occurrence),
    mode_gate ∈ (nothing, :localOnly)[, attr_stem]; attr_stem = nothing)` — CONSUMED since v0.4 T5: the capture walk
    is REGISTRATION-DRIVEN (the declared row is what makes an Alterant's applied state mint evals rows; the store's
    shape is the record's own `altConstructor`; a record WITHOUT a row mints none; the walk reads the store bare —
    the capture-floor warnings, the value algebra and the shape gates left the walk at stage 5's E5 of the v0.4 build (census rows 33 and 34), and the former `instance_type` and `multiplicity` fields with them); `validate` enforces the
    capture mode-gate laws (the gate's closed set · the bidirectional setMode⟺gate coherence · the
    :localOnly scheme and store laws; the identity, stem-shape and stem-clash laws left at stage 5's E4 —
    a stem overlapping a shipped family publishes, and same-cell same-attr rows of two plugins collapse to one) ·
    `DefaultSlot` = `NoDefault()` | `Declared(v)`. `Alterant`'s keyword form defaults both slots (`capture = nothing`,
    `default = NoDefault()`); both are CONSUMED — the capture declaration by the capture walk (v0.4 T5), the default by
    the answer function (stage 2's commit 3). The seven other declared slots of v0.4 T1 — the render-plane data
    (`RenderDecl`, `EffectRow`), the constraint rows (`MutEx`), the contributed condition atoms (`ConditionAtom`), the
    contract version and the required capabilities, the sugar rows (`SugarRow`), the provenance group (`Provenance`,
    `DomainRef`, `SignatureRecord`) and the permissions manifest (`PermissionManifest`) — left the record at stage 5's E10
    of the v0.4 build (census rows 24 and 29; the §6 row): nine public types and eight record fields fewer.
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
  `hide_fold_prefix`, `flavor_tag`, `re_meta_leaded`; every other field, `directives` first, is reachable but not part of the (the `parse_header!` pointer left at stage 5's P1 — census row 63)
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
   `include(joinpath(pkgdir(GoMeta), "devtools", "load_basic_renderer.jl"))` at the caller's top level; `devtools/README.md` documents it.
   **No Extension takes this pair** (R-V04B-56 — the owner's word of 2026-09-24: "no Extension takes the pair"): an
   Extension consumes the Engine's answer through the delivered object and the BLS Component tree, which reaches it as
   the part `blsComponentTree` (BLS's own delivery, R-V04B-45) — the pair is the tool's own, proved by its seven render
   reference files, never by an Extension.
3. **The test layer pins that pair byte-exact** against the corpus golden (`tests/golden/`) — the test
   layer's property, beside the twelve annotation pins of the Engine's values.

## §2 — Signatures + contracts

**⚠ Trust note:** a `{…}` condition is Julia text, read by Julia's parser at absorb and evaluated by Julia at apply
(§3.2; stage 5's E13 of the v0.4 build — the owner's design, OWNER-WORDS §120: a full parser "for those users who …
work only with their private GoMeta statements (i.e.: If there is NO security risk whatsoever)"). Processing a file
you did not write therefore runs its conditions — see the SECURITY section of `README.md`.

### `goMeta(bytes::Vector{UInt8}; config::GoMetaConfig = GoMetaConfig(), registry::AlterantRegistry = DEFAULT_REGISTRY) -> GoMetaDelivery`

(`goMeta` consumes raw bytes; from a `String` use `Vector{UInt8}(codeunits(s))` — or `read(path)`
for a file, as in the README quickstart.)

Pure, deterministic, **TOTAL over the ENTRY surface** (the registry door's refusals are delivered coded, §3.5; an
unknown `flavor_tag` throws its stable message, §3.4 — stage 5's E8, census row 30; absorb/apply-plane catalogued failures can still throw at v0 — the §3
partition). `GoMetaDelivery` carries the run's FOUR public parts, read by name (R-V04B-28/29/30), in his pipeline order (R-V04B-89):
`blsComponentTree::BLS.ParseState` (the BLS Component tree the run was
evaluated over, provided by BLS itself; it reaches an Extension as the part `blsComponentTree`, not through any function of the
GoMeta Engine; an Extension travels it with BLS's own public functions; MUTABLE — the run wrote into it, and every reader of one delivery shares the one
object) · `altValues_evals::EvalStore` (the data container of the evaluated values — the reader over it
`readAltValuesEvals`, §2 below) · `status::ProcessStatus` · `diagnostics::Vector{Diagnostic}` (the invariant is **non-OK ⇒ non-empty
diagnostics**). Nothing internal travels: the per-call working state never leaves the core. (The (tree,
render) pair is the development tool's `Main.BasicRenderer.outputs(result)`, loaded through
`devtools/load_basic_renderer.jl` — not an Engine surface.) No filesystem / clock / environment read by the Engine. **These
three guarantees — purity, determinism, isolation — cover the ENGINE'S OWN OPERATIONS under `DEFAULT_REGISTRY`
(under a CUSTOM registry they hold exactly as far as its own setters/getters/validators do: a
callable closing over mutable state or performing I/O is that Alterant's act, outside the
engine's guarantee — the user-loads-trustworthy-Alterants trust model); a `{…}` condition body is Julia text
evaluated by Julia (stage 5's E13 of the v0.4 build; the owner's §120 and §D174), so what it reads or does is the
author's act in the same way — the guarantees hold for inputs whose conditions are free of side effects and of reads of changing state (a clock, a file, the environment).** The
registry door's refusal (below) fail-closes into a `PROCESS_ERROR` `GoMetaDelivery` **before any parse** — the input
bytes are never touched; no parse or verdict work occurs (§3.5); the Engine renders nothing since
0.4.0 (§1.3), and the development tool's `Main.BasicRenderer.outputs` on such a result is the empty pair. (The
config-time profile refusal that fail-closed the same way — E-03 — left at stage 5's E13 with the profile; §3.1.)

**The registry door (v0.4, STRICT — published-only).** `registry` must be a PUBLISHED value
(`DEFAULT_REGISTRY`, or the result of `GoMeta.publish`). A conforming-but-unpublished registry
(e.g. a gated positional construction) fail-closes before any parse — a
`PROCESS_ERROR` result before any parse, carrying `REG_UNPUBLISHED`, whose message names the
sanctioned path `RegistryBuilder → validate → publish`. A published registry whose containers
were mutated after publication fail-closes with `POST_SEAL_MUTATION` (the live fields are
compared structurally against the publish-time snapshot at the door — the real freeze gate;
the message names the first divergent path; re-publication is the sanctioned change path).
The door's diagnostics are the entry refusal: no configuration field is refusable since stage 5's E13 (the profile row
left with the grammar profile; E8 took the range plain and sent the flavor to `flavor_for`'s own message).

### `GoMetaConfig(; flavor_tag = :julia, parse_range = nothing, user_mh_profile = nothing, namespace = :default)`

The v0 input options (the versioning policy §6). (The `profile::Symbol` field and keyword — the selector of the closed
condition grammar's profile and its two opt-in names — left at stage 5's E13 of the v0.4 build with that grammar, census
rows 1 and 30; the EXPORTED type RE-SHAPED, the §6 row: `GoMetaConfig(profile = …)` is a `MethodError` since. The RENDER's
share-profile `jl-share-v1` is the development tool's and was never this field.) `flavor_tag::Symbol` — the content flavor: a CLOSED set of three armed flavors,
`:julia` (the `#` lead alphabet — the default) · `:c` (the C-family `//` line-comment flavor) ·
`:latex` (the `%` lead alphabet); any other value throws at `BLS.flavor_for` — a stable message naming the
inventory, no fallback (§3.4) — before any parse; selected, never inferred (no file-extension or content
sniffing). *(This sentence previously said "any value is accepted and ignored; validation is deferred" — stale
since the flavor arming; corrected at v0.4 T2 on a CrossReview finding; the coded `ERR_UNKNOWN_FLAVOR` refusal it then named left at stage 5's E8
of the v0.4 build — census row 30.)*
`namespace::Symbol` — the occurrence-key namespace every `altValues_evals` cell handle is scoped
under (`:default` by default; encoded as the key's length-prefixed namespace segment). One
constructor-time guard: a namespace over 65535 bytes throws an `ArgumentError` at
`GoMetaConfig(; …)` construction (the keyword form; the generated positional form carries no guard) — before any `goMeta` run, hence outside the fail-close rows
below (which require a constructed config).
`parse_range::Union{Nothing,UnitRange{Int}}` — `nothing` ⇒ the whole input; a given range is taken
**plain**: `last` is the parse end line and `first` is never read (`5:10` parses lines 1..10). Its unit is
**line indices of the input**, and a `last` beyond the input's final line is accepted without complaint —
`1:99` on a two-line input returns `PROCESS_OK` and renders both lines, with no diagnostic; a non-positive
`last` (`1:0`) parses the whole file (the parser's contract). *(The coded `ERR_RANGE_INVALID` fail-close left at stage 5's E8
of the v0.4 build — census row 30: it refused `first ≠ 1` and the empty range.)*
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
`Main.BasicRenderer.outputs(result)`, obtained ONLY after `include(joinpath(pkgdir(GoMeta), "devtools", "load_basic_renderer.jl"))` at the
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
  on a metaLine is reserved and refuses with the grammar's one refusal — `GoMeta absorb: unexpected character '"' at the start of a
  metaStatement …`, with the hint that a quoted text is the heading sugar at the region's first metaStatement only (the metaLine
  parser effort of 2026-10-08, stage 5's s5c29; the owner's U8 :1306). `head`, like `cell`/`parent`/`file`, is no condition key — a condition naming it meets the usual
  unknown-condition-key refusal (the registry's `queryable_action` rule, stage 5's E12: the Heading and Id answer no
  query) — and a heading's own condition may use settribute state only — evaluated ONCE at the heading's own line,
  GATING the recording (false means no row); a label test there meets the stable refusal "alterant-state query in a
  heading condition" (the one wall kept until R-V04B-101; §3.4).
  Refusal catalogue: §3.4.
- **Id actions (`cell` / `parent` / `file`) — EXPERIMENTAL at this release:** one integer value
  argument (`#~ cell(7)`), Int16 domain. The Id alterant is a v0 placeholder implementation;
  this syntax may change — do not build durable content on it
  at v0. Inherited Id values do not cross a block separation at v0.
- **Visib actions (`show` / `hide` / `discard`) take NO arguments;** an empty list (`hide()`) is
  accepted as the bare form.
- **Malformed arguments** (wrong arity; non-parsable or overflowing values) are Julia's own error out of the
  `goMeta` call since stage 5's E6 of the v0.4 build (the stable `"GoMeta apply: invalid arguments …"` refusal
  left with the set-invocation seam — census row 14; §3.4).
- **Condition-side atoms** (`{ cell(7) }`, `{ cell }` inside `{}`) meet the usual unknown-condition-key refusal at the
  absorb seam, with or without arguments — `cell` declares no getter (the registry's rule since stage 5's E12; the
  closed intake's argument-domain refusal and the E-07 pending mint left with the interpreter at E13, §3.2).

## §3 — The coded error-mode catalogue

`Diagnostic = {code::Symbol, severity, message, context}`; a catalogued failure is a coded
`Diagnostic` except where its row says otherwise — the E-06 GUARDED refusal
still throws (§3.1; its coded conversion deferred at v0; the E-04 crash origin RETIRED at stage 3's commit 4), and the
condition path is Julia's since stage 5's E13 (§3.2: three stable `GoMeta absorb:` refusals of GoMeta's — the unknown condition key, the
no-expression guard of an empty block or a bare literal and, since s5c31, the unterminated `(` inside a body — Julia's own errors
for the rest — the condition rows REMOVED). The
catalogue's inventory IS the tables of §3.1–§3.5
below (no aggregate count is maintained by hand — two hand-written counts drifted at v0.4 T2);
the rows fall into three classes
(§3.1–§3.3); §3.4 additionally documents the latent crashes and the stable-message refusals that
are not catalogued codes.

### §3.1 — Non-condition codes (5): 0 armed config-time + 3 REMOVED at 0.4.0 (stage 5's E8 and E13) + 1 RETIRED at 0.4.0 (E-04) + 1 GUARDED (E-06)

| Code | Status | Trigger |
|---|---|---|
| `ERR_UNKNOWN_PROFILE` (E-03) | **REMOVED at 0.4.0** (stage 5's E13 of the v0.4 build; census rows 1 and 30; the §6 row) | was: `config.profile` outside the three profile names of the closed condition grammar — a fail-closed `PROCESS_ERROR` before any parse; the field, the three names and the grammar they selected left at E13 — no configuration field is refusable since (the registry door's refusals are the entry's, §3.5) |
| `ERR_RANGE_INVALID` (E-08) | **REMOVED at 0.4.0** (stage 5's E8 of the v0.4 build; census row 30) | was: `config.parse_range` with `first ≠ 1`, or an empty range — a coded refusal he never named; a range is taken plain since (§2: `first` never read, a non-positive `last` the whole file) |
| `ERR_UNKNOWN_FLAVOR` | **REMOVED at 0.4.0** (stage 5's E8 of the v0.4 build; census row 30) | was: `config.flavor_tag` outside the three armed flavors `{:julia, :c, :latex}` — fail-closed before any parse; an unknown tag now throws `flavor_for`'s stable message (§3.4). *(Row added at v0.4 T2 on a CrossReview finding — the code armed it at the flavor arming; the catalogue had not followed.)* |
| `ERR_VISIB_NO_FLAG` (E-04) | **RETIRED at 0.4.0** (stage 3's commit 4 of the v0.4 build; R-V04B-42 (1)) | its crash origin was the Visib write-back's flagless read of the winning action; the write-back is gone and the capture's own read is guarded — no apply-path crash origin remains catalogued |
| `ERR_DEPTH_OUT_OF_WINDOW` (E-06) | **GUARDED** — a stable refusal without a code; its coded conversion deferred | a `#~9`-style **digit** depth beyond the meta-hierarchy's depth window raises the stable-message `ErrorException` "meta depth out of range …" at the depth lookup (§3.4) |

No config-time row remains since stage 5's E13: the entry refusals are the registry door's (§3.5) — a `PROCESS_ERROR`
`GoMetaDelivery` carrying the code, with the development tool's `Main.BasicRenderer.outputs` yielding the empty `(tree, render)` pair (its non-OK contract). No apply-path crash origin remains: E-04's left
with the Visib write-back at stage 3's commit 4 (its row above).
E-06 is **GUARDED**: for a digit depth outside the window the depth lookup refuses with the stable
message "meta depth out of range …" (§3.4); its coded conversion is likewise deferred
at v0.

### §3.2 — The condition path (since 0.4.0, stage 5's E13 of the v0.4 build — census row 1; the owner's order §319, R-V04B-106; his §120, §D174): Julia's parser, Julia's evaluation — the five condition codes REMOVED

A `{…}` condition body is READ BY JULIA'S PARSER AND EVALUATED BY JULIA, as the original engine did (GoMetaRetro `src/AbsorbMeta.jl`
:116–:282). At absorb the body's GoMeta-specific parts are re-written to Julia text (`src/absorb/absorb_meta.jl`,
`_rewrite_condition`): a settribute key becomes its state read (`isCode` → `getState(:isCode)`); an action of an Alterant that
ANSWERS QUERIES becomes its query call (`getAltState(Int8(p), Symbol("action"), args…)` — the registry's one rule
`queryable_action`, R-V04B-99 / stage 5's E12: the Alterant declares `getAltInstance`; Labels at v0); a label test `:name` is the
Labels Alterant's query of that name (every admitted name spelled the one way — `Symbol("name")` —, a pictograph with a
ZWJ included); the owner's `,` becomes `||`; everything else — `&&`, `!`, `()`, `|`, `&`, numbers, Julia operators, whitespace —
is copied verbatim. `Meta.parse` reads the result ONCE; the `Expr` is stored and evaluated by `Core.eval` in module `GoMeta` at
apply (`src/alterants/apply.jl`) — or, for a heading's condition, once at the absorb seam. So a Julia Boolean expression over
the GoMeta names is a condition (`{ 1 == 1 }` is one; `{ (isText && containsMeta), isMeta }` is the corpus's own), and a
13-atom condition applies where the closed interpreter's 29-step scan cap refused it (E13).

**What refuses, and in which class.** THREE refusals are GoMeta's: the unknown condition key — a bare word that is neither a
settribute key nor a queryable action (`{ show }`, `{ cell(7) }`, `{ head }`; the keyword literals `true`, `false`, `nothing`
among them — his legacy's reading, the register's E13-14; a quoted text is NOT read word by word since stage 5's s5c31 — the
owner's word of 2026-10-08, OWNER-WORDS §366: it is copied whole to Julia, so `{ isCode == "abc" }` is Julia's comparison, false
at `0.4.0` where every value a condition reads is a Bool), the stable `GoMeta absorb: unknown condition
key …` message at the absorb seam (§3.4); an empty block or a bare literal (`{}`, `{ 1 }`, `{ "abc" }`, `{ | }`) — "carries no condition
expression" (an unconditional action is written without `{}`; E13-6); and a `(` left open inside the body — the one scanner's
"unterminated '('" refusal naming the innermost opener (s5c31; a `"` or the block's `{` left open met it at the block's extent since s5c29). A worded label carrying a parenthesized list
(`:abc(:label1)` — the K6 corner) reads as the label test of the word followed by a Julia call on its Bool, a `MethodError` at
apply — his legacy dropped the word and queried the list, the closed interpreter refused the shape (E13-13, his to revert to
either). A body Julia cannot parse (`{ isCode ! }`,
`{ :(:x)) }`) is Julia's own `Meta.ParseError` out of the `goMeta` call; an INCOMPLETE body (`{ isCode && }`) is thrown as
the same class at absorb — never stored for a later reader. A condition that fails at EVALUATION is Julia's own error at
apply: an argument Julia cannot dispatch (`{ :(7) }` — `getAltState`'s `Vararg{Symbol}`), an undefined name (`{ :(x) }`), a
non-Bool value where a Bool is needed (`TypeError`), a getter's own throw (raw). The condition grammar's walls — the
29-step scan cap, the 29-code-unit atom wall, the 4096-byte wall, the depth-32 wall (E13) — and its declared argument grammar
left with the interpreter at E13: Julia's parser has none of them. Witnesses: `tests/unit/condition_tests.jl`.

| Code | Status |
|---|---|
| `ERR_UNKNOWN_CONDITION_KEY` (E-01) · `ERR_CONDITION_CAP` (E-02) · `ERR_CONDITION_ARG_DOMAIN` · `ERR_CONDITION_PARSE` · `ERR_CONDITION_UNQUERYABLE_ALT` (E-07, never minted) | **REMOVED at 0.4.0** (stage 5's E13 of the v0.4 build; the §6 row) — the coded `Diagnostic` carriers of the closed interpreter's refusals; the unknown condition key stays a stable-message refusal (§3.4), the rest are Julia's own classes |

### §3.3 — Handled class (NOT an error): E-05 — meta-free input

A meta-free input is **not** an error: on the NO-FEED path `goMeta` returns `PROCESS_OK` with zero
alterant work, and the development tool's render of such a result passes the PARSED content through unchanged —
byte-exact up to the documented line-ending normalization (CRLF → LF, §4; `docs/CANONICAL-OUTPUT.md` §6) and the
selected `parse_range` (a given range is taken plain, `last` the parse end line — §2) (a head-bearing fed profile still mints its
user-context row; a refusal-carrying feed aborts regardless of document meta-freeness). It carries
no code — it is a normal success path.
(An input whose only meta is inline is NOT this class: inline `#~` actions on content lines DO
apply — `docs/SYNTAX-AND-SEMANTICS.md` §9.)

### §3.4 — Known latent crashes + stable-message refusals (NOT catalogued codes)

These are the honest edges of the v0 engine. Entries marked GUARDED are refusals with a stable
message (no longer raw crashes); the rest remain latent, documented as such — **not** assigned a
fabricated code:

- **The per-slot action overflow — GUARDED since the metaLine parser effort (stage 5's s5c29 of the v0.4 build; the owner's
  Decision 3 of 2026-10-08, OWNER-WORDS §358):** the queue tensor holds as many actions per meta-hierarchy slot as the registry
  declares (8 today) — a fixed size, raised by hand when an example needs it (the slower overflow buffer is a later design); a
  further action in one slot meets `GoMeta absorb: more than 8 actions in one meta-hierarchy slot …` BEFORE the write (between
  E7 and s5c29 it met Julia's own `BoundsError`). Witnesses: `tests/unit/slot_overflow_tests.jl` (the boundary and the ninth).
- **Malformed metaLines — THE GRAMMAR'S ONE REFUSAL since the metaLine parser effort (stage 5's s5c29; the owner's Decision 1 of
  2026-10-08, §356: Design E — his legacy's reader with its grammar made explicit):** a metaStatement is a name, a `:` label or (the
  region's first statement only) a `"…"` heading, then at most one `()`, then at most one `{}`, and ENDS at white space or at the
  region's end; any other character meets `GoMeta absorb: unexpected character '<c>' <where> in the meta region "…" (the token "…")`
  — `where` is "at the start of a metaStatement" (`#~ ,`, `#~ ( hide`, a space before `(` or `{`: `hide (isCode)`, with the hint
  that `()` and `{}` are written glued to the name), "after ':'" (`:"ab"`, `:{isCode}`), or "after the metaStatement "…"" (a token
  glued to a closing bracket — `hide()junk`, `hide{isCode}show`; a second `(` or `{`; a `(` after `{}`; a `,` after a one-word
  label — `:label1,label2`, with the hint that several labels are written `:(label1, label2)`). The six structural characters
  `( ) { } , "` end a name or a one-word label (§362); every other non-white-space character is a name or label character —
  pictographs and emojis among them (§360); a leading punctuation is part of the name and meets the unknown-action refusal
  (`#~ -hide` → `unknown alterant action "-hide"`, §361 — the prefix sugar a later design). An empty argument piece
  (`cell(7,)`) is handed on as the empty token for the Alterant to judge (§359 (1)); an argument's arity or type fault is the
  Alterant's own setter error (§359 (9)). Between E7 and s5c29 these shapes were read as his legacy read them (a leading
  punctuation skipped, a glued token dropped, an empty region Julia's `BoundsError`). VALID input is unaffected — his two example
  files and the twelve frozen forms read byte-equal (§78). Witnesses: `tests/unit/parser_quality_tests.jl` (the battery: every
  inventory shape with its expected outcome), `tests/unit/malformed_meta_tests.jl` (the valid twins; the glued form).
- **The quoted-string lane — GUARDED (stable messages; the span refusals re-worded at the metaLine parser effort, stage 5's s5c29,
  in the words the owner approved as drafted, §359 (6)):** a `"` never closed meets `unterminated '"' — never closed …` (the ONE
  scanner names the innermost opener left open — the quote before an enclosing `(`); an argument list carrying a `"` meets "malformed
  quoted argument" (a quote glued to bare text, a stray quote, or more than one span in
  one token), or "string argument not accepted" (a WELL-FORMED quoted argument anywhere
  except the slot the action's DECLARED record names — `head`'s TEXT slot; every other
  slot of every shipped action, including `head`'s level slot, refuses a String). The heading
  lane adds its own siblings: "empty heading text" (an
  empty `""` heading is refused by ratified v0 semantics; relaxing it later would be a
  compatible widening), and "heading without a document context" (the deriving form on the
  fed-profile surface, where nothing gives it a placement; the explicit
  `head(text, level)` form is context-free). The condition walls carry their own stable
  messages: "alterant-state query in a heading condition" (a heading condition may test
  only settribute predicates at v0) and "a conditioned heading in a profile feed"
  (fed-heading conditions are reserved). The backslash is RESERVED inside GoMeta's own
  quoted texts — the heading sugar, a quoted argument, a label list: "backslash in a quoted span — reserved for the future escape
  grammar" (the owner's v0.2 decision, given for these two producers) — so a future escape grammar can land as a purely additive
  widening without reinterpreting any shipped document; inside a CONDITION a quoted text is Julia's (the owner's §D174) and there the
  backslash escapes the next character as Julia reads it — the owner's word of 2026-10-08, §366 ("strings in conditions: now",
  stage 5's s5c31): the quoted text is copied whole to Julia, never read by the rewrite. Witnesses: `tests/unit/heading_recognizer_tests.jl`,
  `tests/unit/parser_quality_tests.jl` (the quote-scan rows).
- **The out-of-window meta depth — GUARDED:** the refusal is witnessed on the **DIGIT** depth
  form — a digit depth marker outside the v0 window (`#~9`, `#~99` — v0 supports `#~` through
  `#~8`, and digit `0` addresses the file level, accepted) raises
  the stable-message `ErrorException` ("meta depth out of range …") at the depth lookup —
  never a raw conversion crash. In-window depths work unchanged. Note: `#~10` parses its
  first digit only and behaves as depth 1.
- **Empty, literal and malformed condition bodies (stage 5's E13):** an EMPTY condition block (`{}` or `{ }`) or a bare
  literal (`{ 1 }`, `{ | }`) raises the stable-message `ErrorException` "… carries no condition expression …"
  — an unconditional action is written without `{}`; a body Julia cannot parse (`{isCode !}`, an unbalanced `)`) or
  cannot complete (`{isCode &&}`) is Julia's own `Meta.ParseError` out of the `goMeta` call (the former coded
  "unparsable condition" refusal left with the interpreter at E13). Since the metaLine parser effort (stage 5's s5c29) the
  block's EXTENT is found quote-aware — a `}` inside a quoted text closes nothing (`hide{ isCode == "}" }` is read as Julia reads
  it), a condition's quoted text is Julia's and its `\` Julia's escape; since s5c31 (the owner's word of 2026-10-08, §366) the
  REWRITE copies a quoted text whole — `{ isCode == "abc" }` is Julia's comparison (false at `0.4.0`: every value a condition reads
  is a Bool), `{ "abc" }` a bare literal ("carries no condition expression") — and the condition's `(…)` lists are found by the one
  scanner (an unclosed `(` meets "unterminated '('"). Working conditions are unaffected byte-for-byte.
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
- **The over-cap condition — the walls left at stage 5's E13 of the v0.4 build (census row 1):** the closed
  interpreter's 29-step scan cap (the coded `ERR_CONDITION_CAP` refusal "condition too complex" — E13), its 29-code-unit atom
  wall, its 4096-byte wall and its depth-32 wall left with the interpreter — Julia's parser reads the whole body, so a
  13-atom condition applies where it refused and a 40-character label name is a label test like any other. Witnesses:
  `tests/unit/condition_tests.jl` (the inversion).
- **The unknown-alterant refusal:** an out-of-registry alterant name throws a stable, stage-honest,
  bounded `ErrorException` ("GoMeta absorb: unknown alterant action …"). Its coded-`Diagnostic`
  conversion is deferred (the E-01 family).
- **The unknown-label refusal:** a name APPLIED as a label (`#~ :labelX`, including the conditional form
  `:labelX{ … }`) from outside the shipped set — `:label1`..`:label5` plus, since `0.3.0`, the fixed pictograph
  vocabulary (`alterants-std/labels_vocabulary.txt`, 38 names) — raises the stable `ErrorException`
  `"GoMeta apply: unknown label …"`, which names the accepted set SORTED (the §2 argument-forms contract). A label
  QUERIED in a condition (`{ :labelX }`) is never refused for being unknown: the query answers false, as the legacy's
  checker did (since stage 5's E9 of the v0.4 build — the T4 membership refusal in the query role and the write-only
  valve left, census row 55). Witnesses: `tests/unit/error_message_tests.jl` (both roles).
- **The unknown flavor_tag — a stable-message throw (since stage 5's E8 of the v0.4 build, census row 30):**
  a `config.flavor_tag` outside the closed inventory `(:julia, :c, :latex)` raises the stable `ErrorException`
  `"flavor_for: unknown flavor_tag …"` at `goMeta`'s flavor resolve, before any parse — no fallback, no
  file-extension or content sniffing; the coded `ERR_UNKNOWN_FLAVOR` config-time refusal left at stage 5's E8 with
  the range refusal (§3.1). Witnesses: `tests/unit/flavor_profile_tests.jl`, `tests/unit/latex_flavor_tests.jl`.
- **The capture-floor warnings (v0.4 T5; coded, NON-fatal) — the Heading lane's alone since stage 5's E5 of the v0.4 build
  (census row 33):** `WARN_CAPTURE_FLOOR` — a localOnly alterant produced applied state but declares NO capture row;
  `WARN_CAPTURE_UNREADABLE` — its declared row's live instance falls outside the flush's readable shape. Both emitted by
  the absorb seam's flush (`src/absorb/absorb_meta.jl`) until the Heading runs through the apply loop (R-V04B-101); the
  capture walk of the other Alterants reads its stores bare and emits neither (a store outside its declared scheme's
  shape is Julia's own error; a record without a row mints nothing). Channel: warning `Diagnostic`s on the result.
  Witnesses: `tests/unit/capture_tests.jl` [11] (A1).
- **The store-`[2]` insertion path** — a latent insertion path not exercised by any v0 input.
- **The absorb-plane grammar refusals (the same stable-message family):** beyond the entries
  above, the metaLine/condition grammar refuses with stable `GoMeta absorb:` messages on: an
  unterminated `(`, `{` or `"` on the metaLine ("unterminated '<o>' — never closed … (n still open)" — the one scanner names the
  innermost opener left open; stage 5's s5c29) and, since s5c31 (the owner's word §366), a `(` left open inside a condition body
  (the same scanner, the same message) · an unknown condition key (a bare name inside `{}` that is neither a component
  state-ref nor a QUERYABLE action name — an action of a getter-less Alterant, Visib's `show`/`hide`/`discard` among them
  with Id's and the Heading's, is no condition key since stage 5's E12, census row 45: R-V04B-99 by the registry's one rule;
  the vocabulary's one refusal since stage 5's E13 — the seam's others are the next item and the open `(` above) · an empty or literal condition block (the entry above) · a
  second argument list or condition block, a bracket after `{}`, a glued token or a stray structural character (the grammar's one
  refusal `unexpected character …`, the entry above; the former "duplicate argument list" / "duplicate condition block" /
  "misplaced one-word label" texts left at stage 5's s5c29); the malformed- and
  unterminated-key refusals and the over-cap refusal left with the closed interpreter at E13 (a malformed body is Julia's
  own `Meta.ParseError`); the punctuation and glued-token walls left at stage 5's E7 — census row 41 — and the grammar's one refusal took their place at s5c29 (the entry above).
  The basic renderer (a development tool, `devtools/basic_renderer.jl`) carries no Visib guard of its own since stage 3 of the
  v0.4 build: it renders the Engine's answer per Component; more than one Visib value on one cell is refused by the Engine at the
  CAPTURE (`src/annotations.jl` — the stable message `GoMeta capture: more than one Visib value set for one component …`).
  Each refusal is stable and points at this section; most name the offending token, region, or
  bracket count.
- **The action-args walls — REMOVED at 0.4.0** (stage 5's E6 of the v0.4 build; census row 14; his §120 —
  the framework before hardening; his legacy called the setter directly): malformed alterant-action ARGUMENTS —
  non-parsable or overflowing Id values and wrong-arity forms, including arguments on Visib actions — meet
  Julia's own dispatch error or the setter's own `parse` error out of the `goMeta` call; the stable
  `"GoMeta apply: invalid arguments …"` refusal and the apply-plane `_invoke_set` seam left at stage 5's E6.
  Working forms are unaffected (the §2 argument-forms contract). Condition-side atoms of a getter-less Alterant
  (`{ cell(7) }`, `{ cell }`, `{ parent }`, `{ file }`) meet the usual unknown-condition-key refusal at absorb, with or
  without arguments (the registry's rule since stage 5's E12; the E-07 pending mint retired at E13); a QUERYABLE
  action's argument text is spliced as Julia text and judged by Julia at apply (§3.2). Witnesses of
  the working forms: `tests/unit/arg_guard_tests.jl`.

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
the parse/absorb/apply pipeline is STABLE and explanatory — a malformed condition body excepted, which is Julia's own
`Meta.ParseError` since stage 5's E13 as a malformed action argument is Julia's own error since E6 (stage-honest prefix
`GoMeta parse:` / `GoMeta absorb:` / `GoMeta apply:` — the development tool's render plane carries no message of its
own since stage 3's commit 1 of the v0.4 build, the renderer consuming the Engine's answer; the offending token
bounded, what v0 accepts, this section as the pointer); four catalogued messages are
parse-plane — the bang-first meta-marker refusal (`0.3.1`), the multi-inline-meta refusal and the two directive-adjacency refusals
(segment grain and line grain, `0.2.3`) above. The not-input-reachable internal checks say
"GoMeta internal invariant violated … please report". The vendored parse layer's OTHER messages
keep their existing forms; they are not part of the coded catalogue above.

A later put for the SAME occurrence handle and attribute supersedes the recorded row (later wins; applied-state-wins) —
the non-fatal `WARN_VERDICT_COLLISION` diagnostic that accompanied a value-changing supersede left at stage 5's E5 of the
v0.4 build (census row 66; §6); two distinct cells never share a slot, byte-identical content included, for well-formed
occurrence keys (`_putEval!`, `src/annotations.jl`).

- **The T3 SEAM-ENVELOPE family — GUARDED (v0.4 T3; catalogue-NAMED stable-message refusals,
  their coded-`Diagnostic` conversion = the T11 catalogue):** each fires as an
  `ErrorException` whose message carries the catalogue name as a literal token; the engine's
  own `"GoMeta "`-prefixed refusals and `InterruptException` always pass through the
  envelopes verbatim; the containment guarantee is scoped to exceptions delivered to the
  handler (`StackOverflowError` catchability is shape-dependent; resource exhaustion may not
  allocate a refusal).
  - `CB_QUERY_THROW` — **REMOVED at 0.4.0** (stage 5's E13 of the v0.4 build; census row 1): the closed interpreter's query
    envelope left with the interpreter — the getter is called bare through `getAltState` (bare since stage 5's E5 of the
    v0.4 build), as his legacy called it: a getter's throw propagates raw out of the `goMeta` call, in its own class.
  - `RES_RETURN_TYPE` — a declared-return-type breach: the handover validator returned non-`Bool` (the query getter's
    non-`Bool` return is Julia's own `TypeError` at the condition since stage 5's E13; the setter's live return
    guard left with the set-invocation seam at stage 5's E6 of the v0.4 build — census row 14).
  - `REG_VALIDATE_FALSE` — the declared handover validation returned `false` for the presented
    String-slot text; first-offender-wins at the absorb site (the catalogue's refuse-at-gate
    shape is unreachable at this callable's only call site — full collection rides T11).
  - `CB_VALIDATE_THROW` — the handover validator threw a foreign class.
  - `CB_SET_THROW`, `CB_CTOR_THROW`, `RES_FOREIGN_STORE` — **REMOVED at 0.4.0** (stage 5's E6 of the v0.4 build;
    census row 14): the set seam's malformed-argument crash conversion, the three-site constructor-mint
    envelope and the per-invocation store-identity check left with the set-invocation seam `_invoke_set` at E6;
    the setters and constructors are called bare, as his legacy called them (his §120).

### §3.5 — Registration + door codes (v0.4; coded `Diagnostic`s)

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
| `REG_UNKNOWN_SETMODE` · `REG_DUPLICATE_ALTNAME` · `REG_DUPLICATE_ACTION` · `REG_RESERVED_SHADOW` · `REG_SIG_MISMATCH` · `REG_VALUE_ALGEBRA` · `REG_UNREACHABLE` · `REG_CANDIDACY` · `REG_MUTEX_CONFLICT` · `REG_UNINTERPRETED_REQUIRES` · `REG_CONTRACT_VERSION` | **REMOVED at 0.4.0** (stage 5's E4 of the v0.4 build; census rows 3 and 51 — OWNER-WORDS §317, R-V04B-105) | the validation chain of v0.4 T2–T4 — the coded inventory refusals, the clash law with its disposition switch, the reflection cross-check, the value-algebra and reachability refusals, the candidacy warning — left; his legacy registered unchecked; a duplicate action name resolves FIRST-wins in the derived tables; the §6 register row | — |
| `REG_SLOT_EXHAUSTED` | error | more than 127 alterants or actions (the Int8 index space) — at `register!`'s 128th append (the validate-time row for a directly-pushed builder left at stage 5's E4: such a builder fails at `publish` with Julia's `InexactError`, the honest bound of bypassing `register!`) | the alterant |
| `REG_DERIVED_TABLES` | error | positional (route-U) construction whose hand-built tables differ from the tables derived from the declarations | `nothing` |
| `REG_UNPUBLISHED` (door) | error | an unsealed registry reached `goMeta` — the message names `RegistryBuilder → validate → publish` | `nothing` |
| `POST_SEAL_MUTATION` (door) | error | a published registry whose live fields no longer match the publish-time snapshot — the message carries "at <path>", the first divergent path; re-publication is the change path | the rendered path |
| `DEP_MISSING` (v0.4 T3) | **REMOVED at 0.4.0** (stage 5's E4 of the v0.4 build; census row 3) | the eager dependency closure at publication left; an `altConstructor` with no zero-argument method publishes and is Julia's own `MethodError` at first apply out of the `goMeta` call (the mint wrap `CB_CTOR_THROW` that named it left at stage 5's E6 of the v0.4 build — census row 14; §3.4); the §6 register row | — |
| `STATE_REUSE_REFUSED` (T3 seam) | **REMOVED at 0.4.0** (stage 5's E2 of the v0.4 build; census row 42) | the seam ledger left with the callable driver seam: `goMeta` builds its parse state itself, one per call — nothing is injected, nothing can be in flight twice; the §6 register row | — |
| `STATE_SEAL_MISMATCH` (T3 seam) | **REMOVED at 0.4.0** (stage 3's commit 4 of the v0.4 build; R-V04B-42 (1)) | it guarded the Visib write-backs a run left in the caller's state; nothing is written back any more — the §6 register row | — |
| `SRC_DIGEST_MISMATCH` (v0.4 T4) | **REMOVED at 0.4.0** (stage 5's E9 of the v0.4 build; census row 10) | the vocabulary artifact's digest pin left with the record's vocabulary slot — the 38 names are a plain file read at load; the §6 register row | — |

The stable-message refusal `"GoMeta absorb: meta-hierarchy slot pool exhausted"` of v0.4 T2 LEFT at stage 5's E5 of the
v0.4 build (census row 71; §6): an exhausted per-call slot pool (`NUM_MH_LEVELS` = 12 slots) is Julia's own `MethodError`
at the Int8 store, as in 0.3.2; the walk allocates at most one slot per live level, so no input reaches it.

## §4 — CRLF normalization (documented, not an error)

Both setup paths chomp `\r\n` — line **endings** normalize to LF; CONTENT-line **content** bytes
stay faithful for arbitrary bytes, including invalid UTF-8 (documented engine behavior for BOTH
invalid-byte classes — lone invalid bytes and decode-requiring sequences such as overlong
encodings). The shipped suite pins both planes: an overlong sequence inside a hidden content
line is carried byte-faithfully (`tests/unit/ensure_token_tests.jl`, row [8]); on the meta-line
plane an invalid byte inside a quoted argument in a slot that takes no text meets the
string-argument refusal (`tests/unit/heading_recognizer_tests.jl`, the QUOTE × INVALID UTF-8 row)
and, at the condition rewrite's two identifier tests inside a condition body (guarded since
stage 5's s5c38 of the v0.4 build, the owner's §384), Julia's own `Meta.ParseError` or the
unknown-key refusal (`tests/unit/parser_quality_tests.jl`, the rows jG1–jG3). The
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
removal or rename (its ground, its replacement, what an older caller sees). No alias stands: the public
`PlugIn` = `Alterant` alias of R-V04B-5 LEFT at stage 5's E14 of the v0.4 build as a clean cut (R-V04B-62; the v0.5 schedule
superseded; its row below). The policy will change at a
later stage — maybe v0.8, maybe later — by the owner's word; nothing is promised now. `Project.toml`
carries the version.

**The breaking-change register (every removal, rename or ADDITION of a public name of EITHER tier is written here — the
non-silent record under R-V04B-61; the letter of R-V04B-24 (P) does not govern until at least v0.7).**

- **`GoMeta.outputs` — §1.2 public-not-exported since 0.3.0 — REMOVED at 0.4.0** (no deprecation stub; the
  owner's "as clean as possible NOW"); ground: the renderer and the tree print are development tools
  (R-V04B-13); replacement: the tool's `outputs` after `include(joinpath(pkgdir(GoMeta), "devtools", "load_basic_renderer.jl"))` at the
  caller's top level; a 0.3.0 caller sees `UndefVarError`; the same-commit triple (code + the document's
  §1.2/§1.3/§2/§3.4/§6 + the surface oracle); the policy's protection read as covering exported names only (P);
  `docs/CANONICAL-OUTPUT.md` re-scoped (the package's canonical observable output = `altValues_evals` (+
  `serialize_evals`, `content_fingerprint`); the pair = the tool's output pinned by the golden layer); the Engine's
  delivered surface after the move = the run and the evaluated values. (i) Of R-V04B-5's practice (the
  `PlugIn` → `Alterant` rename, R-V04B-5: a PUBLIC 0.4.x alias, removal at v0.5 — the alias left at stage 5's E14, R-V04B-62 —, and a register row with the same-commit
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
- **`GoMeta.BLS.flavor` — ADDED (public, not exported) at 0.4.0 with the door** — NEW — the field read `tree.flavor` given a name (the flavor record; its type internal); THE PROMISE (R-V04B-80 (2)(ii)): five fields — `lead`, `hide_marker`, `hide_fold_prefix`, `flavor_tag`, `re_meta_leaded`; the rest of the record (`directives` first; the `parse_header!` pointer left at stage 5's P1 of the v0.4 build — census row 63) reachable, not promised; one register row (the plan v8 :35; R-V04B-58).
- **`GoMeta.BLS.isHorizontalSpace` — ADDED (public, not exported) at 0.4.0 with the door** — ADAPTED — the parser's horizontal-whitespace predicate (`_is_h_ws`, flavor.jl) given a public name, so that the print tools' lexer classifies whitespace as the parser does; one register row (R-V04B-80 (2)(iii)).
- **`GoMeta.BLS.endsWithNewline` — ADDED (public, not exported) at 0.4.0 with the door** — NEW — the field read `tree.endsWithNewline` given a name; one register row (the plan v8 :35; R-V04B-58).
- **`GoMeta.BLS.getElement` — ADDED (public, not exported) at 0.4.0 with the door** — ADAPTED — the legacy named-element read (settribute flags; the named-int keys — four positions, two store indices, a count, two extension-chain links) declared public as it is, plus ONE Component-taking method `getElement(c, key)` dispatching over the two containers (R-V04B-80 (2)(i); a caller reads no field) — every settribute key and named-int key thereby readable; the Visib flags `:show` / `:hide` / `:discard` lose their meaning at stage 3 (R-V04B-42) and leave the key set at stage 5's E12 (census row 45) — a read of one is an error since; one register row (the plan v8 :35; R-V04B-58).
- **`GoMeta.BLS.File` — ADDED (public, not exported) at 0.4.0 with the door** — ADAPTED — the legacy Component type alias declared public as it is; one register row (the plan v8 :35; R-V04B-58).
- **`GoMeta.BLS.Block` — ADDED (public, not exported) at 0.4.0 with the door** — ADAPTED — the legacy Component type alias declared public as it is; one register row (the plan v8 :35; R-V04B-58).
- **`GoMeta.BLS.Line` — ADDED (public, not exported) at 0.4.0 with the door** — ADAPTED — the legacy Component type alias declared public as it is; one register row (the plan v8 :35; R-V04B-58).
- **`GoMeta.BLS.Segment` — ADDED (public, not exported) at 0.4.0 with the door** — ADAPTED — the legacy Component type alias declared public as it is; one register row (the plan v8 :35; R-V04B-58).
- **`GoMeta.BLS.ComponentSettribute` — ADDED (public, not exported) at 0.4.0 with the door** — ADAPTED — the legacy named-element type declared public as it is (`keys(ComponentSettribute)` — the print tools); one register row (the plan v8 :35; R-V04B-58).
- **`GoMeta.BLS.CmpntNamedInt` — ADDED (public, not exported) at 0.4.0 with the door** — ADAPTED — the legacy named-element type declared public as it is (`keys(CmpntNamedInt)` — the print tools); one register row (the plan v8 :35; R-V04B-58).
- **`EvalRecord.decided_by` (field) — ADDED to the public record type at 0.4.0** (stage 2's commit 2 of the v0.4 build; R-V04B-35 (b) "ONE provenance field on the public record type `EvalRecord` — one register row", (d) "the provenance RECORDED where it is known — an origin per queued action at the enqueue, carried through the apply and captured with the record; the never-enqueued :localOnly Heading's at the flush — so that own or indirect is MEASURED, never inferred from a row's presence"); the field `decided_by::Vector{Vector{UInt8}}` — the `key_bytes` handles of the statements that produced the row, in application order (the stating Component's handle: the metaBlock a whole-line metaLine forms, the Segment of an inline one — R-V04B-50; the minted user-context handle on the userMH feed); the delivered ROWS of `readAltValuesEvals` unchanged (R-V04B-35 (a) — the four-tuple, the sort, the count); nothing removed; a 0.3.x or stage-1 caller constructing `EvalRecord` positionally with five arguments sees a `MethodError` (no constructor is public; none exists outside `src/`); the same-commit triple (the type `src/result.jl`, this document's §1.2, the witness `tests/unit/origin_tests.jl` — the surface oracle pins names, not fields); the name the authored set's word (his confirmed scenarios' `decided_by`), the session's default under R-V04B-40 (2), his at stage 2's review. Minted 2026-09-17 (R-V04B-35); landed on the branch `cc/v04-delivery` (stage 2, commit 2).
- **`GoMetaDelivery` (type) — RE-ORDERED at 0.4.0: the field order `blsComponentTree`, `altValues_evals`, `status`, `diagnostics`** (stage 2's commit 2b of the v0.4 build; the owner's word of 2026-10-01 on row 44 of stage 1's review agenda — R-V04B-89 "(b)": his pipeline order, §242 / R-V04B-71, the BLS Component tree first); ground: the parts are read BY NAME (R-V04B-29) — a reader by name sees no change; what changes: the struct's field order (`fieldnames`), the positional constructor's argument order (the two constructor sites in `src/GoMeta.jl`; none outside `src/`) and the one `Base.show` line (now in the field order); nothing removed; the same-commit triple (the type `src/state.jl`, this document's §1.1 table and §2, the surface oracle unchanged — it pins names; the `fieldnames` pin is the agenda's row 45 (a), on his word). Minted 2026-10-01 (R-V04B-89); landed on the branch `cc/v04-delivery` (stage 2, commit 2b).
- **`Alterant.default` (keyword and field) — ADDED to the Alterant registration record at 0.4.0** (stage 2's commit 3 of the v0.4 build; R-V04B-51 (1)–(2) "each Alterant declares ONE default value, as data in the Alterant registry (the Alterant's, not an action's); Visib's default is 'show'"; R-V04B-55 (1)–(3) — the meta level formerly 'default' renamed `fallBack` and consulted LAST by the apply; the Alterant's default delivered by the answer function with the source "default"); ground: his lean of 2026-09-10 (§11), his words of 2026-09-22 (§180) and 2026-09-24 (§197); the slot `NoDefault()` | `Declared(value)` on `PlugIn`'s keyword form (the 6-positional 0.3.x form left at stage 5's E11 of the v0.4 build — census row 65; until then it constructed with the slot undeclared); the registration digest moves (the fold carries the Alterant's slot — the pin re-measured); the per-action `default` slot of `ActionSpec` (T1) STAYS in this commit, read by no Engine path, and GIVES WAY at commit 3-ii (its removal with the test layer re-homed — a clean cut under R-V04B-61, its own register row then); the internal level constant `defaultMHIdx` renamed `fallBackMHIdx` (not public); the same-commit triple (the record `src/state.jl`, this document's record vocabulary, the witnesses `tests/unit/record_schema_tests.jl`). Minted 2026-09-22/24 (R-V04B-51/55); landed on the branch `cc/v04-delivery` (stage 2, commit 3).
- **`ActionSpec.default` (keyword and field) — REMOVED at 0.4.0** (stage 2's commit 3-ii of the v0.4 build; R-V04B-51's effects "the per-action `NoDefault()` slots of the registry give way to one per-Alterant slot"; R-V04B-61 clean cuts — no stub); ground: the default is the Alterant's (R-V04B-51 (1): "the Alterant's, not an action's"), declared at commit 3 (the row above); replacement: `PlugIn(; …, default = …)`; an action record constructed with `default = …` sees a `MethodError` (no such keyword; the 8-positional 0.3.x form still constructs), a reader of `spec.default` a field error; the registration digest moves (the per-action part leaves the fold — the pin re-measured); the same-commit triple (the record `src/state.jl`, this document's record vocabulary, the witnesses re-homed — `record_schema_tests.jl`, `registry_lifecycle_tests.jl`, `vocabulary_tests.jl`, `snapshot_property_tests.jl`). Minted 2026-09-22 (R-V04B-51); landed on the branch `cc/v04-delivery` (stage 2, commit 3-ii).
- **`GoMeta.evaluatedAltValue` (function) + `GoMeta.EvaluatedAltValue` (type) — ADDED (package-public, not exported) at 0.4.0** (stage 2's commit 4 of the v0.4 build; R-V04B-35 (c) "the ENGINE ANSWERS, on demand, ONE resolved value per Component per Alterant with a source of own / indirect-through-C / default, the answer shape UNIFORM across Alterants"; R-V04B-52 (2) a Segment's answer its own rows if any, else its Line's marked indirect; R-V04B-53 the levels' room — `:user`, `:file`, `:fallBack` reserved; R-V04B-55 (2) the Alterant's declared default with the source `:default`): `evaluatedAltValue(delivery, component, alterant; registry = DEFAULT_REGISTRY) -> EvaluatedAltValue(value, source, via)` — derived at the call from the delivered rows and `decided_by`, never stored; the delivered ROWS unchanged; nothing removed; the same-commit triple (the code `src/answer.jl` and the `public` declaration in `src/GoMeta.jl`, this document's §1.2 + §2, the witnesses `tests/unit/answer_tests.jl` with `public_surface_tests.jl` 40 → 42); NOT FINAL — the name DECIDED at stage 2's review (his word of 2026-10-03, §305; R-V04B-95 — the RENAMED row below); the per-call walk (Q6, card C8) DEFERRED to the benchmark phase (§307; R-V04B-97); the tier, the File's case (`:none`) and the equal-child rows (OQ-148) carried past the branch (C23); the letter of R-V04B-24 (P) does not govern until at least v0.7.
- **`GoMeta.scanAlterant` + `GoMeta.evaluatedAltValues` (functions) — ADDED (package-public, not exported) at 0.4.0** (stage 2's commit 5 of the v0.4 build; his §6 item 9.A — the scan for the Components that got values of an Alterant, "unambiguous, and informative"; the plan v8.1 :57; card 4): the scan by Alterant and the access by Component, thin reads over `evaluatedAltValue` — functions of their own (the session's default, R-V04B-40 (2)); the alternative as methods of the reader banked as a labelled diff beside the commit; the delivered ROWS unchanged; nothing removed; the same-commit triple (the code `src/scan.jl` with the `public` declaration, this document's §1.2 + §2, the witnesses `tests/unit/scan_tests.jl` with `public_surface_tests.jl` 42 → 44); NOT FINAL — the names DECIDED at stage 2's review (§305; R-V04B-95 — the RENAMED row below); the form (functions of their own) stands, its alternative banked; the letter of R-V04B-24 (P) does not govern until at least v0.7.
- **`GoMeta.childDiffers` (function) — ADDED (package-public, not exported) at 0.4.0** (stage 2's commit 6 of the v0.4 build; R-V04B-35 (e) "his (ii) child-differs signal COMPUTED from that answer, its stored form left to the benchmark phase"; his §37 item 4.2; the plan v8.1 :58): `true` when a Component's resolved answer's VALUE differs from its parent's — computed from `evaluatedAltValue` at the call, never stored; the per-child primitive from which his (ii) per-parent Boolean is computed (`any` over the parent's children; the aggregate's form the benchmark phase's); the delivered ROWS unchanged; nothing removed; the same-commit triple (the code `src/childdiff.jl` and the `public` declaration in `src/GoMeta.jl`, this document's §1.2 + §2, the witnesses `tests/unit/childdiff_tests.jl` with `public_surface_tests.jl` 44 → 45); NOT FINAL — the name kept at stage 2's review (R-V04B-95); the Block-against-File reading carried past the branch (C23); the letter of R-V04B-24 (P) does not govern until at least v0.7.
- **`serialize_evals(ann)` — the four-column public form's `attr` column ENCODED at 0.4.0** (stage 2's commit 7a of the v0.4 build; the CrossReview set REAL-1 R1 #2 — "a tab/newline stem breaks the one-verdict-per-line format"; the set's cure sentence verbatim: "Reject record delimiters in attr_stem at registry.jl:917, or encode attr in both serialize_evals overloads." — narrowed to the four-column form by the plan v8.1 :62, the five-column form being the test layer's since commit 8 and gone from the Engine at commit 9b; the other arm a labelled diff for his word at the review, card C9): a backslash, tab, newline or carriage return in an attribute name is escaped as `\\`, `\t`, `\n`, `\r`, so one row stays one line and four columns; a correctness fix of the form's own format — the shipped attribute families carry none of the four and serialize byte-identically (the pinned [8g] output unchanged); the five-column golden producer untouched (the twelve pins unmoved; removed at commit 9); the other arm — record delimiters refused at registration — NOT landed, hardening his §120 defers (R-V04B-37), a one-line question with its diff at stage 2's review; the same-commit triple (the code `src/annotations.jl`, this document's §1.2 + §2, the witness `tests/unit/public_surface_tests.jl` [8h]); the letter of R-V04B-24 (P) does not govern until at least v0.7.
- **`GoMeta.content_fingerprint` — §1.2 public-not-exported since 0.2 — REMOVED at 0.4.0** (stage 2's commit 9b of the v0.4 build; R-V04B-43 — the 4D phrase his word §156 adopted, its clause (1): "the stored copy goes, the public function goes, and no Engine function serves a piece's text — it is read from the BLS Component tree through BLS's own access function"; his questions OWNER-WORDS §154 and his word §156; no deprecation stub — the owner's "as clean as possible NOW"): a 0.3.x caller sees `UndefVarError`; replacement: `GoMeta.BLS.content(delivery.blsComponentTree, component)` for a piece's text, the Component reached through the door (`GoMeta.BLS.children`) or named by the answer function (`GoMeta.evaluatedAltValue(…).via`, `GoMeta.scanAlterant`); the shipped consumers (`find_by_label.jl`, `notebooks_from_source.jl`) re-routed that way at commit 9a (R-V04B-43 (2)); the same-commit triple (`src/GoMeta.jl`'s `public` line, this document's §1.2/§1.3, the surface oracle `tests/unit/public_surface_tests.jl` — the tier's count 45 → 44); the policy's protection covers exported names only (P).
- **`EvalRecord.content` (field) — REMOVED from the public record type at 0.4.0** (stage 2's commit 9b; R-V04B-43 (1); R-V04B-43's effects: "a second change to that public type beside the origin field of R-V04B-35 (b), its own register row"): a reader of `.content` sees a field error; the row names its Component by `cell_handle` and carries no copy of its text; the record's fields are `cell_handle`, `attr`, `value`, `polarity`, `decided_by`. The one row without a piece in the tree — a heading fed through the configuration's user profile — carries an empty fifth column in the test layer's derived form (R-V04B-43 (4); his word OWNER-WORDS §277, R-V04B-90).
- **`GoMeta.serialize_evals(::GoMetaDelivery)` (the five-column method) — REMOVED at 0.4.0** (stage 2's commit 9b; R-V04B-43's effects): the golden layer's five-column form is the TEST layer's since commit 8 — `TestSupport.derive_annotations_golden(delivery)` (`tests/support/derive_annotations.jl`), its fifth column a piece's text through the BLS Component tree and `GoMeta.BLS.content`; the twelve reference files byte-identical by both producers while both existed (R-V04B-43 (3); commit 8's standing proof), unmoved at the removal; the four-column `serialize_evals(ann)` stays the Engine's one serialization; the Engine's internal `cell_content_bytes` superseded by `GoMeta.BLS.content` (R-V04B-24/25's tidy-up list).
- **The Visib write-back into the BLS Components — REMOVED at 0.4.0** (stage 3's commit 4 of the v0.4 build; R-V04B-42 (1) — his word of 2026-09-22, OWNER-WORDS §153: *"I approve your recommendation: 3A."*, the phrase 3A the session's: "Remove the Visib write-back into the Components, together with the two things in the Engine that exist only for it — the internal marker it raises and the two refusals that read that marker"): the two write sites (the Block grain in the driver loop; the Segment grain onto the Line in the absorb walk), the latch `wrote_back` of the per-call state, the diagnostic code `STATE_SEAL_MISMATCH` and the POISONED variant of `STATE_REUSE_REFUSED` (the ledger's `registry` and `poisoned` fields with them). A consumer that read a Component's `:show`/`:hide`/`:discard` flag reads FALSE for every Component — the Engine's answer is `evaluatedAltValue` (§1.2; the basic renderer and the development tools read it since this stage's commits 1 and 2). The three flags' declarations STAY until his word (R-V04B-42 (2); stage 5): the registry's `settribute` slots, the derived `action_to_settribute` table, the three names inside BLS, `RenderDecl.materialize`. The E-04 crash origin (§3.1) retired with the write-back's read. Proved by 0 of 7 committed renders moving (R-V04B-42 (3)). Since stage 5's E12 of the v0.4 build (census row 45) the three flags are no longer keys of the BLS record at all — `getElement(c, :hide)` fails loud in the key table's own lookup (Julia's no-such-field error on the record's key NamedTuple — not a `KeyError`), not FALSE.
- **The declared defaults of Labels, Heading and Id — ADDED at 0.4.0** (card C2 of stage 2's review; the owner's word of 2026-10-02, OWNER-WORDS §287: *"I do approve your recommendation: declare."* — R-V04B-92; PROVISIONAL in his words: the values may change once used on real examples): `Labels` declares the empty set `Symbol[]`, `Heading` declares `nothing`, `Id` declares the zero compound `(cell = Int16(0), parent = Int16(0), file = Int16(0))` (Visib's `:show` since stage 2's commit 3). For a Component with no rows of the Alterant anywhere up the tree, `evaluatedAltValue` now returns `(value, :default)` where it returned `(nothing, :none)`; the source `:none` remains for the File and for an Alterant of a custom registry without a declared default. The registration digest moved with the record (the tenth re-mint, measured): `0x0956eed205fef8ac` → `0x0e7836ce6e6b53ae`. `childDiffers` FOLLOWS (card C12's reading: a top Block compares against the File's `nothing`): every top Block now differs for Labels and Id as it did for Visib (`false` → `true`); Heading's `nothing` against the File's `nothing` still does not. Id's declared compound names the type's three fields in the type's order `(cell, parent, file)`; a row-derived compound carries only the RECORDED fields — two shapes no consumer compares by `==` today (the decisions seat's F-5).
- **The answer function's SOURCE for a Line decided by its own trailing metaSegment, and for that Line's Segments — CHANGED at 0.4.0** (card C24 of stage 2's review; the owner's words of 2026-10-02, OWNER-WORDS §286 and §288 — R-V04B-93; the letter of R-V04B-52 (2)): the Line answers `:own` (before: `:indirect` through the Segment); a Segment without rows of its own answers AS its Line answers — the Line's `:own` marked `:indirect` through the Line (before: `:own` when the deciding handle was the Segment's own key; `:indirect` through that metaSegment for the Line's other Segments), every other source unchanged as before (`:indirect` through the Line's own decider, `:user` under a fed profile, `:file`). An inline heading's row stays keyed on its Segment (R-V04B-50) — not touched by this commit. The VALUES, the rows and their `decided_by` are unchanged.
- **`answerFor`, `answersFor` and `AltAnswer` — RENAMED at 0.4.0 to `evaluatedAltValue`, `evaluatedAltValues` and `EvaluatedAltValue`** (card C4 of stage 2's review; the owner's word of 2026-10-03, OWNER-WORDS §305: *"I approve C4: evaluatedAltValue"* — R-V04B-95; his §295 of 2026-10-02: "that is what you get when calling that function"): the names only — the signatures `evaluatedAltValue(delivery, component, alterant; registry)` and `evaluatedAltValues(delivery, component; registry)`, the record's fields `value`, `source`, `via`, the seven source tags, the tier (package-public, not exported) and every behaviour unchanged; `scanAlterant` and `childDiffers` keep their names; the file names `src/answer.jl` and `tests/unit/answer_tests.jl` stay. The earlier entries of this page read the new names (a living page, renamed with the code — its §6 row for card C2 among them; the two NOT FINAL notes — `src/answer.jl`'s header and this page's entry on the function — name `answerFor` as the former working name); the build record's rows, the commit messages and the receipts that say `answerFor` describe the same function under its former name.
- **The inline heading's KEY and the commented metaLine's carrier — CHANGED at 0.4.0** (item A6 of the stage-3 close sitting; the owner's word of 2026-10-03, OWNER-WORDS §309: *"1.: I approve your recommendation: (b)"* — R-V04B-98; stage 5's commit E1; the three forms on his word of 2026-10-05, OWNER-WORDS §324 — R-V04B-109; the golden re-pin on his §323 — R-V04B-108): the heading stated in a Code Line's trailing metaSegment is keyed on the LINE with the Segment as the key's origin, as every inline statement is, and the Line answers it `:own`, its Segments `:indirect` through the Line (before: keyed on the Segment, which answered `:own` while its Line answered the default); a metaLine split by a trailing `##` comment hands its statement Segment over with the metaBlock as the carrier, so its heading row is keyed on the metaBlock and EVERY statement on such a metaLine records the metaBlock as its deciding statement (before: the statement Segment — a defect against R-V04B-50; the answer function's source for the two legacy examples' rows moves from `Segment n:s-e` to `Block a-b`); the level constant `head_10` unchanged; the degenerate-key warning `WARN_DEGENERATE_OCCURRENCE_KEY` (both sites) REMOVED (census row 52, his §317); the golden `heading_quoted_first.jl.ann.txt` re-derived and the comparison forms `heading_quoted_first`, `file_for_Example_Extended`, `file_for_Example_Proposal_JuliaCon` re-made (the header's sha = the parent 79ea54cd).
- **The registration validation chain and the clash-disposition switch — REMOVED at 0.4.0** (stage 5's E4 of the v0.4 build; census rows 3 and 51 of the stage-5 census, the owner's bulk mark of 2026-10-03, OWNER-WORDS §317 — R-V04B-105; his §19 — the public surface 'RESTRICTED TO THE NECESSARY functionality' — and his §20 'RESTRICT THAT INTERFACE TO A MINIMUM'; his §120 no hardening before the framework works): the validation chain of v0.4 T2–T4 — the tier-1 record shape law (the closed enum sets, the kinds/kind_sources, queryable, dispatch-target uniqueness, plugin-index, settribute-key and MutEx rows; the capture identity, stem-shape and stem-clash laws), the tier-2 inventory law (`REG_UNKNOWN_SETMODE`, `REG_DUPLICATE_ALTNAME`, `REG_RESERVED_SHADOW`, `REG_MUTEX_CONFLICT`, `REG_UNINTERPRETED_REQUIRES`, `REG_CONTRACT_VERSION`, the validate-time `REG_SLOT_EXHAUSTED`), the clash law with both arms and the switch (`REG_DUPLICATE_ACTION`), the reflection cross-check (`REG_SIG_MISMATCH`), the value-algebra and reachability refusals (`REG_VALUE_ALGEBRA`, `REG_UNREACHABLE`), the candidacy warning (`REG_CANDIDACY`) and the eager dependency closure (`DEP_MISSING`) — left `src/alterants/registry.jl` (−726/+79 lines) with the four dead closed-set constants of `src/state.jl`; `validate` runs the domain probe (R-V04B-4 (iii) — the one domain definition shared by `validate`, `publish`'s copier and the door's walker), the four capture mode-gate laws of the Heading's :localOnly lane (until R-V04B-101, after the branch) and the vocabulary check (census row 10's commit). MEASURED consequences (the build record's receipts `PROBES-e4-validate_stage1-src-cut_on-1c9d013f.txt`, `PROBES-e4-capture-laws_stage1_on-1c9d013f.txt` and `PROBES-e4-seat-notes_on-1c9d013f.txt`):a duplicate action name resolves FIRST-wins in the derived tables (the legacy's Dict assignment was last-wins); a `:candidate` without activation publishes silently; an `altConstructor` without a zero-arg method publishes and meets `CB_CTOR_THROW` at the first mint, naming the `MethodError`; a capture `instance_type ≠ altConstructor` publishes and floors `WARN_CAPTURE_UNREADABLE`; a stem overlapping a shipped family publishes — on one cell the two plugins' same-attr rows collapse to one row (full structural namespacing is T11's row); a capture scheme outside the walk's four arms with gate `nothing` publishes and falls through the walk — no row, no floor (T11's catalogue row); a kind or source literally named k/s is no longer refused at registration, so such a record's fingerprint can alias another's — a fingerprint-only class inside R-V04B-4 (v)'s disclosed-lossy bound; a builder pushed past 127 plugins or actions, or with a dangling plugin index, DIRECTLY (bypassing `register!`, which refuses both coded) fails raw at `publish` (`InexactError`) or at apply (`BoundsError`) — the honest bound of the bypass; `publish`'s warning path stands with no remaining check that warns.
- **`GoMeta.BLS.content(tree)` — ADDED (public, not exported) at 0.4.0** (stage 5's s5c8 of the v0.4 build; his word of 2026-10-05, OWNER-WORDS §333, R-V04B-116 (3)(b)): the document's lines joined by a newline, as bytes (no terminal newline — `endsWithNewline` carries that fact; a CRLF line end's CR dropped by the line split), the one-argument method of the door's `content` — not a `(tree, ::File)` arm of the two-argument form, whose empty return for a File is the Engine's capture predicate (untouched); the development tools' last two reads outside the door left with this commit — the File's text through this method, the renderer's whitespace guard before the hide marker through `isHorizontalSpace` (R-V04B-116 (3)(a); over a Char the two predicates differ at \v, \f, \r and U+0085 — stripped by the internal guard alone — and at U+180E — by the public class alone; no corpus input carries any of the five, the build record's receipt `PROBES-s5c8-whitespace-class-bytes_on-450d1476.txt`) — and the texts of the lapsed exemption D-6(a) with them.
- **`run_absorb_apply!` (the callable driver seam), its state ledger (`STATE_REUSE_REFUSED`), `validate_carrier_state` and the `_walk_and_apply!` factoring — REMOVED at 0.4.0** (stage 5's E2 of the v0.4 build; census rows 21, 42, 23 and 44 of the stage-5 census, the owner's bulk mark of 2026-10-03, OWNER-WORDS §317 — R-V04B-105; his verbatim of R-V04-31 on the seam: "If this is only to the benefit of the .fodt adapter it will eventually have to be removed from the GoMeta engine - if not in v0.4, then in a later GoMeta version."; the legacy was one function): `goMeta(bytes; config, registry)` is the ONE route into the Engine; the driver body (the fresh per-call state, the user feed, the File loop, the delivery) runs inside it; a caller-built store has no entry and no checker; `names(GoMeta)` unchanged (none of the four was a `public` name). The corpus, the 26 pins and the twelve forms byte-identical (the pre-check); the suite count moves by the retired witnesses alone.
- **The Labels vocabulary machinery — `VocabularySlot`, `InlineVocabulary`, `VocabularyRef` (the record's `vocabulary` slot, field and keyword), the G-VOC triple `vocabulary` / `vocabulary_member` / `vocabulary_queryable`, the `SRC_DIGEST_MISMATCH` code, the digest pin, the capture cache, the artifact grammar, the scope law, the write-only valve and the labels record's policy identity — REMOVED at 0.4.0** (stage 5's E9 of the v0.4 build; census rows 10, 28 and 55 of the stage-5 census, the owner's bulk mark of 2026-10-03, OWNER-WORDS §317 — R-V04B-105; his words of 2026-09-20, OWNER-WORDS §120: "Similarly CC kept on pressuring me into making the Labels Alterant safe before we even could try working with a basic true Labels Alterant."): the 38 names stay in the plain file `src/alterants-std/labels_vocabulary.txt`, read at load (R-V04B-6 (a); the file byte-identical — the ZWJ line's `query=false` field, the owner's R-V04-36 content ruling, inert data now); `setLabels` keeps the closed check (an unknown label APPLIED refuses, naming the accepted set); `checkLabels` answers false for an unset or unknown label — the legacy's (GoMetaRetro Alterants.jl :87–:99); a `PlugIn` keyword `vocabulary = …` is a `MethodError` now; `names(GoMeta)` loses six. The corpus, the 26 pins and the twelve forms byte-identical (the pre-check); the registration digest re-minted (the labels record's slots leave the seal fold — `profile_snapshot_tests.jl`, measured).
- **The carried declaration slots and the reserved security frame of the Alterant record — the types `RenderDecl`, `EffectRow`, `MutEx`, `ConditionAtom`, `SugarRow`, `DomainRef`, `Provenance`, `SignatureRecord`, `PermissionManifest` (nine public names) and the record's fields `render`, `constraints`, `atoms`, `contract_version`, `requires`, `sugar`, `provenance`, `permissions` — REMOVED at 0.4.0** (stage 5's E10 of the v0.4 build; census rows 24 and 29 of the stage-5 census, the owner's bulk mark of 2026-10-03, OWNER-WORDS §317 — R-V04B-105. He had approved those slots at the architecture sittings of 2026-08-24 — R-V04-35, the record-carried payload's vehicle; R-V04-37 SEC-4, the Rung-1 activation — and his later mark removes them: the difference between his earlier and later words is resolved by the later word, stated here; his R-V04-27 of the same day, verbatim, put permission levels and hash checks LATER; his §120 on a basic framework BEFORE HARDENING; his §18 (ii) on clutter): the record keeps eight fields (the six of 0.3.2, the declared default of stage 2's commit 3, the capture declaration of v0.4 T5); a record naming a removed keyword no longer constructs (a keyword error at the call); the seal's fold covers the capture slot alone of the declared slots — the registration digest re-minted (a cache key, measured by the build's probe); nothing a run produces changes (the corpus A/B zero bytes at the land). `RenderDecl.materialize` — piece (3) of census row 45's four Visib declarations — leaves here with its type: the judge's 'materialize follows #45' was written for the order E12-before-E10; the owner's §319 release re-slotted E12 after P3.
- **The capture walk's hardening, the capture declaration's `instance_type` and `multiplicity` fields, the `getAltState` query envelope, the `WARN_VERDICT_COLLISION` diagnostic and the meta-hierarchy slot-pool guard — REMOVED at 0.4.0** (stage 5's E5 of the v0.4 build; census rows 33, 34, 56, 66 and 71 of the stage-5 census, the owner's bulk mark of 2026-10-03, OWNER-WORDS §317 — R-V04B-105; his §120 on a basic framework BEFORE HARDENING; his legacy read the stores and called the getter bare): the capture walk reads each Alterant's store bare under its declared scheme (a store outside the shape is Julia's own error; a record without a capture row mints nothing); `CaptureDecl(attr_scheme, mode_gate[, attr_stem])` — the store's shape is the record's own `altConstructor`; the stem derivation folded into `_capture_stem` (four copies); the registration digest re-minted (the capture row's seal text, the thirteenth); the Heading lane's flush keeps `_capture_floor!` and its two warnings until R-V04B-101 (the judge's exception); the closed interpreter's query envelope stays; a conflicting re-apply on one cell supersedes silently, later wins; an exhausted slot pool is Julia's own error; the occurrence key's totality arm (census row 7, LATER) NOT taken here.
- **The set-invocation seam `_invoke_set` with its pre-checks and envelopes, the instance-mint wrap `_mint_instance`, the kind map `_kind_type` with `_LITERAL_KINDS`, the user-arity helper `_user_arity`, and the `_unchecked_registry` test seam — REMOVED at 0.4.0** (stage 5's E6 of the v0.4 build; census row 14 of the stage-5 census, the owner's bulk mark of 2026-10-03, OWNER-WORDS §317 — R-V04B-105; his §120 on a basic framework BEFORE HARDENING; his legacy called the setters and constructors directly, goMetaAddOns.jl): the apply loop and the absorb heading seam call `altConstructor()` and `setAltInstance(store, action, args...)` bare — a malformed argument, an absent or throwing constructor, a store foreign to the setter's method and a declaration the method does not implement are Julia's own errors out of the `goMeta` call, and a setter's return is not checked; the codes `CB_SET_THROW`, `CB_CTOR_THROW` and `RES_FOREIGN_STORE` leave the catalogue, `RES_RETURN_TYPE` keeps its two surviving sites (the closed interpreter's query site; the handover validator); the registration record and its digest are unchanged; the refusal witnesses left with their subject (arg_guard, registration, seam_envelope, heading_recognizer); measured on both trees by the build's edge probe (receipts/S8-branch/PROBES-e6-edges-*).
- **The declared action record's overload rows (`ActionOverload`, `ActionSpec.overloads`), its `spelling` tag, its `sugar_candidacy` grant register and its reserved `keyed_slot`, and the v0.3.2 positional constructors of `PlugIn` (6-positional) and `ActionSpec` (8-positional) — REMOVED at 0.4.0** (stage 5's E11 of the v0.4 build; census rows 16 and 65 of the stage-5 census, the owner's bulk mark of 2026-10-03, OWNER-WORDS §317 — R-V04B-105; his §223 'no left overs from old version in newer ones', R-V04B-61; his legacy registered an action by its name and let Julia dispatch do the rest): `ActionSpec` is five fields `(name, plugin, accepts_string_slot, validate, settribute)` with the keyword form as the one form — `accepts_string_slot` and `validate` stay for the Heading road (R-V04B-101), `settribute` stays for stage 5's E12 (census row 45); the registration digest no longer folds the rows, the tag, the register or the slot (the FOURTEENTH re-mint, measured and pinned); the door walks two record structs; the public name `ActionOverload` leaves (29 → 28 public names); no behaviour on the shipped Alterants (the corpus, the forms, the pins, the evals trees); a custom registry written in the old form — an `overloads =` keyword, a positional `PlugIn(...)` — is Julia's own MethodError at construction (an API break for custom registries under R-V04B-61; measured on both trees by the build's probe), the keyword five-field form registers, validates, publishes and runs on both trees.
- **The flavor record's digest fold (`_flavor_digest` and the `digest` field), its header-strategy seam (the `parse_header!` pointer, the `header_strategy` identifier, the forward declaration), its `extensions` field and the `_CFAM_LEAD_*` / `_RE_META_LEADED_*` compatibility aliases — REMOVED at 0.4.0** (stage 5's P1 of the v0.4 build; census rows 39, 63, 72 and 58 of the stage-5 census, the owner's bulk mark of 2026-10-03, OWNER-WORDS §317 — R-V04B-105; his §120 and his §223, R-V04B-61): the parser's loop calls `parseLeadHeader!` directly for every armed flavor (the seam switched to a fallback that no longer existed); the digest was a cache-key component no code read (the cache key composes name, mode, schema, grammar and registration — no flavor component today, pre-existing); the extensions were read by no code; the aliases' cited referents were not in the repository. The door's promise of five fields (R-V04B-80 (2)(ii)) is untouched; no behaviour on any flavor — the three armed flavors' tree and render bytes equal on both trees (the build's probe); an internal `_mk_flavor` call carrying the three former keywords is Julia's own error now.
- **The four guarded refusals ADDED to his legacy's metaLine parser — the punctuation wall at the action-name position, the glued-token wall after a closing `)` or `}` (with its gating flag), the no-token guard ("GoMeta absorb: malformed metaLine …") and the per-slot capacity guard ("GoMeta absorb: slot action capacity …") — REMOVED at 0.4.0** (stage 5's E7 of the v0.4 build; census row 41 of the stage-5 census, the owner's bulk mark of 2026-10-03, OWNER-WORDS §317 — R-V04B-105; his §120): a malformed metaLine is read as his legacy read it — punctuation at the action-name position skipped to the next identifier, a token glued to a closing bracket dropped — or meets Julia's own `BoundsError` (an empty meta region; a further action in a full slot — the queue tensor's width is the registered action count, 8); every re-worded legacy message stays (§3.4); no public name changes — the row is written for the behaviour's sake, as the E5 row's was.
- **The metaLine parser's grammar made explicit — Design E (stage 5's s5c29 of the v0.4 build; the owner's Decisions 1–3 of 2026-10-08, OWNER-WORDS §356–§358, and his rulings §359–§362):** a metaStatement is a HEAD (a name, a `:` label, or the region's first `"…"` heading), then at most one `()`, then at most one `{}`, and ENDS at white space; any other character meets `GoMeta absorb: unexpected character …` (§3.4) — the legacy's silent skip of a leading punctuation, its silent drop of a glued token and its `BoundsError` on an empty region (E7's row above) end here; the ninth action in a slot meets "more than 8 actions in one meta-hierarchy slot" before the write; ONE scanner finds every span quote-aware (a `}` or `)` inside a quoted text closes nothing) and the five span refusals are re-worded to "unterminated '<o>' — never closed …" and "backslash in a quoted span — reserved …" (the former "unterminated quoted argument / heading / argument list / condition block" and "backslash in a quoted argument / heading" texts, "duplicate argument list / condition block" and "misplaced one-word label" left); ONE text-argument rule from the registration at both seams; `:label1,label2` refused with the right form named; the full argument list with its empty pieces handed to the Alterant. VALID input unchanged — the twelve forms and the two example files byte-equal (§78); the parser-quality battery `tests/unit/parser_quality_tests.jl` (263 rows) the witness; no public name changes.
- **The three Visib DECLARATIONS — the per-action write-back key `ActionSpec.settribute`, the derived table `AlterantRegistry.action_to_settribute` and the three names `hide`, `show`, `discard` in BLS's `ComponentSettribute` — REMOVED at 0.4.0** (stage 5's E12 of the v0.4 build; census row 45 — the owner's bulk mark of 2026-10-03, OWNER-WORDS §317, and his order §319 "#45 remove" (R-V04B-106) — the word R-V04B-42 (2) kept them for since 2026-09-22; his §14: the flags were stored in the BLS Components "for simplicity and as an interim step"; his §69 item 5: "will be removed later"): nothing had written back since stage 3's commit 4 — the Engine's answer is `evaluatedAltValue` (§1.2). What an older caller sees: `ActionSpec(; …, settribute = …)` is a `MethodError` (the keyword is gone); `R.action_to_settribute` an error (the field is gone); the registration digest re-minted (the FIFTEENTH — the seal fold lost the slot); and — R-V04B-99, his §310 (2.3): *"Just the usual error / refusal message."* — a condition naming `show`, `hide` or `discard` meets the unknown-condition-key refusal where it was accepted and silently false before (measured: `#~ hide{ show }` PROCESS_OK with 0 evals rows before, the refusal after — `receipts/S8-branch/PROBES-e12-edges-*` in the build record; witnesses: `tests/unit/condition_cap_tests.jl`'s retired-keys testset — re-homed into `tests/unit/condition_tests.jl` at stage 5's E13). HOW it is delivered — MEASURED on the build, not inferred: taking the three names out of BLS alone did NOT refuse them (the intake read `show` as a registered ACTION and minted a query — silently false without a Visib instance, measured there; with one, a CB_QUERY_THROW at apply by the mechanism measured for Id on the BEFORE tree, `#~ cell(3) hide{ cell }`); the rule that delivers the ruling is the registry's `queryable_action` (`src/state.jl`): a bare name in a condition is a settribute key, or an action of an Alterant that ANSWERS queries (Labels at v0 — Visib, Id and the Heading declare no getter), or it meets the usual refusal — whose text gains the one word that became false ("nor a registered" → "nor a queryable alterant action"). Its reach beyond the three names: a query of Id or the Heading (`{cell}`, `{head}`), which answered FALSE silently or threw CB_QUERY_THROW at apply before, refuses at absorb the same way — one principled rule in place of a patch per key (his §342), placed on the registry so it outlives stage 5's E13; stated here for the owner's correction (his §D174: the condition parser recognises the GoMeta-specific parts).
- **The closed condition interpreter, the opt-in condition modes and the grammar profile — `src/condition.jl` whole (`parse_condition`, the algebra `CondStateAtom` / `CondQueryAtom` / `CondRawArg` / `CondNot` / `CondAnd` / `CondOr` / `CondScAnd` / `CondScOr` under `ConditionAST`, `print_condition`, `evaluate`, `cond_atom_for`, `cond_query_for`, `has_query_atom`, the condition codes `ERR_UNKNOWN_CONDITION_KEY` (E-01), `ERR_CONDITION_CAP` (E-02), `ERR_CONDITION_ARG_DOMAIN`, `ERR_CONDITION_PARSE` and the never-minted `ERR_CONDITION_UNQUERYABLE_ALT` (E-07), the K3–K6 corner register), the marker `FullEvalCondition` with `_FULL_EVAL_HANDLER` / `register_full_eval_handler!` and the alias `ConditionT` (`src/state.jl`), `src/grammar_profile.jl` whole (`GrammarProfile`, the caps and precedence data, `_grammar_digest`, `_mk_profile`, `cache_key`, `_profile_wellformed_check`, the opt-in seam `_CONDITION_MODES` / `register_condition_mode!` / `condition_mode_fn`, `_PROFILE_MODES`, `resolve_profile`), the pinned `DEFAULT_GRAMMAR_PROFILE` (`src/alterants/registry.jl`), the extension `optin/condition_modes_opt_in.jl` with `optin/README.md` (R-V04B-14's directory emptied), and the field and keyword `GoMetaConfig.profile` with `validate_config` and `ERR_UNKNOWN_PROFILE` (E-03) — REMOVED at 0.4.0** (stage 5's E13 of the v0.4 build; census row 1 `B:S2+C:default-grammar-profile` with row 30's profile arm — the owner's ORDER of 2026-10-03, OWNER-WORDS §319 *"and I order #1: remove."* (R-V04B-106 (2)); his §120 *"I never aimed for an additional safe parser. CC kept on pressuring for that."* and *"A FULL PARSER MUST BE AVAILABLE FOR THOSE USERS WHO FOR INSTANCE WORK ONLY WITH THEIR PRIVATE GoMeta statements"*; his §123 *"I actually do not want an opt-in at the moment."*; his §D174 of 2026-10-06 — the parser recognises the GoMeta-specific parts and slightly re-writes the condition into a Julia Expression evaluated on demand by Julia; his §223 'no left overs', R-V04B-61): a `{…}` condition is READ BY JULIA'S PARSER AND EVALUATED BY JULIA, as his legacy did (GoMetaRetro `src/AbsorbMeta.jl` :116–:282) — the body re-written at absorb (a settribute key to its state read; a QUERYABLE action to its query call; a label test `:name` to the Labels query, every admitted name spelled `Symbol("name")`; `,` to `||`; the rest verbatim — `_rewrite_condition`, `src/absorb/absorb_meta.jl`), parsed ONCE by `Meta.parse`, carried as Julia's `Expr` (`AlterantQueue.conditions`) and evaluated by `Core.eval` in module `GoMeta` at apply (`src/alterants/apply.jl`; a heading's once at the absorb seam); the vocabulary rule KEPT — the registry's `queryable_action` (`src/state.jl`; R-V04B-99, stage 5's E12): a bare name is a settribute key, or an action of an Alterant that declares `getAltInstance` (Labels at v0), or it meets the usual `GoMeta absorb: unknown condition key …` refusal — the vocabulary's refusal, the keyword literals `true` / `false` / `nothing` and a quoted string's word among the bare words it refuses (his legacy's reading; register E13-14); an empty block or a bare literal is refused as carrying no condition expression — the seam's second refusal (the legacy applied unconditionally — the session's choice, his to revert; E13-6); a worded label carrying a parenthesized list (`:abc(:label1)`, the K6 corner) reads as the label test of the word followed by a Julia call on its Bool — a `MethodError` at apply, where his legacy dropped the word and queried the list and the closed interpreter refused the shape (register E13-13, his to revert to either); the three profile names `:jl_share_v1` / `:jl_share_v1_full_parse` / `:jl_share_v1_full_eval`, the two-act law and the forward-provisioned cache key leave with the modes; the EXPORTED type `GoMetaConfig` RE-SHAPED — `GoMetaConfig(; flavor_tag, parse_range, user_mh_profile, namespace)`, the same-commit triple (the type `src/config.jl`, this document's §2/§3.1, the surface oracle unchanged — the four exported names and the 28 public names); none of the removed names was public. What an older caller sees: `GoMetaConfig(profile = …)` a `MethodError`; `include(… "optin/condition_modes_opt_in.jl")` no such file; a document whose condition met a coded refusal: a body Julia cannot parse is Julia's own `Meta.ParseError` out of the `goMeta` call (the messages 'condition too complex', 'condition too large', 'unterminated label key', 'unparsable condition', 'malformed condition key', 'label key with an argument list', 'unsupported condition argument' gone; 'empty condition block' re-worded to 'carries no condition expression'); a `PROCESS_ERROR` delivery carrying `[:ERR_UNKNOWN_PROFILE]` never again. What an author gains: the 29-step scan wall, the 29-code-unit atom wall, the 4096-byte wall and the depth-32 wall are gone (a 13-atom condition applies where it refused), the argument grammar is Julia's, a Julia Boolean expression over the GoMeta names (`{ 1 == 1 }`) is accepted and evaluated, a glued grouping `{(isCode)}` reads (the inventory's D-6) and a ZWJ pictograph label queried reads (D-11's query half) — MEASURED at the build by the probe pair `PROBES-e13-edges-{BEFORE_928c47bb,AFTER_<build>}.txt` over the 26 bodies of `PROBES-e12-modes-AFTER_50fb968.txt` and the parser inventory's H-rows; the TWELVE FROZEN FORMS UNMOVED (nine carry conditions — R-V04B-106 (2): a moved line is a defect); the heading-condition walls (`src/absorb/absorb_meta.jl`): the full-eval arm left with its marker; the label-test wall ("alterant-state query in a heading condition") KEPT as the ONE minimal refusal of R-V04B-106 (3) until the Heading runs through the apply loop (R-V04B-101) — a walk over the stored `Expr` for a `getAltState` call; the getter is called bare through `getAltState` — `CB_QUERY_THROW` leaves the catalogue, `RES_RETURN_TYPE` keeps the validator site; the evaluation's cost MEASURED (65–155 µs per `Core.eval` on the corpus shapes — his legacy's known cost; the lowered form a hundredfold cheaper, his to choose — the build record's register E13-9). Witnesses: `tests/unit/condition_tests.jl` (new — the E12 retired-keys testset re-homed with its control; the Julia-intake rows); `condition_cap_tests.jl`, `condition_modes_tests.jl` and `profile_snapshot_tests.jl` deleted whole; `unicode_cure_tests.jl` [1]/[3]/[5] re-cut end-to-end and `seam_envelope_tests.jl`'s query testset re-cut to Julia's own classes; `heading_recognizer_tests.jl`'s two wall witnesses unchanged.
- **The registration fingerprint — `_registration_digest` (`src/alterants/registry.jl`), the FNV-1a fold helpers `_FNV_OFFSET` / `_digest_fold` / `_fold_parts` (`src/grammar_profile.jl`), `_mint_seal` and the `seal` field of `AlterantRegistry` (the `fnv1a64:<16 hex>` text; its `_SNAPSHOT_FIELDS` entry; the constructor argument) — REMOVED at 0.4.0** (stage 5's E13 of the v0.4 build; census row 6 `C:seal-fingerprint+B:S12-seal` — R-V04B-106 (2) "the registration fingerprint (#6, its one consumer the profile) goes in the same commit"; R-V04B-4 (v) had demoted it to a lossy cache-key component; his §314 "AS SIMPLE AND ELEGANT AS POSSIBLE"): the fingerprint's consumer was the grammar profile's `registration_digest` / `cache_key` (the row above); the `seal` field carried the digest and nothing else — the DOOR never read its value: `_registry_door_check` gates on `_snapshot === nothing` (`REG_UNPUBLISHED`) and compares the nine walked fields against the publish-time snapshot, `===` at the leaves (T2-bis), firing `POST_SEAL_MUTATION` at the first divergent path — both guarantees kept; the ruling's word "seal" names that snapshot mechanism (T2BIS-DESIGN §12), so `_SealToken` and `POST_SEAL_MUTATION` keep their names; the `_slot_text` encoder family STAYS for its one remaining caller — the validate walk's canonical Dict-entry order (`_walk_dict_entries`; the census row's own carve-out, "one key-text path stays for the kept door"; its removal with the order is the build record's register E13-2, his to order); the type-encoder budget (predicate 2 of the domain probe) STAYS as the domain's declared closure (register E13-3). What an older caller sees: `R.seal` a field error (`hasfield(AlterantRegistry, :seal)` false); the sixteen digest re-mints of this register's history end here (the E9/E10/E11/E12 rows stand as history); no public name moves. Witnesses: `registry_lifecycle_tests.jl` — the two seal pins re-cut to the snapshot, the route-U pin to `_snapshot === nothing`, the seal-carrying forge form and W4 (the foreign-seal leaf witness) retired, the 22 encoder pins unchanged; `record_schema_tests.jl` — the seal-participation pin and the digest-coverage testset retired, the slot-text distinctness pin unchanged; `snapshot_property_tests.jl` unchanged in count (the `:seal` skip line gone — the door's proof, 3127).
- **`PlugIn` (the public alias `const PlugIn = Alterant` of R-V04B-5) — §1.2 public-not-exported since 0.4.0's `Alterant` rename — REMOVED at 0.4.0** (stage 5's E14 of the v0.4 build; census row 54 `B:B9-public-tier-list`, the owner's bulk mark of 2026-10-03, OWNER-WORDS §317 — R-V04B-105, the judge's row "the list is cut back to the ruled names after the other marks land"; R-V04B-62 — his word of 2026-09-28, OWNER-WORDS §224 *"Proceed as recommended by you."* on the put: the alias removed at stage 5 as a clean cut under R-V04B-61, his §223 *"I want clean cuts and no left overs from old version in newer ones"*; his words of 2026-07-28 on the legacy name — he prefers NOT to call the record 'PlugIn' anymore, the name clashing with another kind of PlugIn he has in mind (the Alterant-model user statement :178–:179; U5 OQ-149)): the record type is `Alterant` (R-V04B-5) and its keyword constructor `Alterant(; altName, setMode, altConstructor, setAltInstance, getAltInstance = nothing, precedencesTuple = nothing, default = NoDefault(), capture = nothing)` the one form; the FIELD NAMES are his legacy's and unchanged — the earlier text's clause "alias removal + field-name normalization = v0.5" was the session's plan of 2026-08-25 (SITTING-2-PACK §4 Q2), never his word, and is WITHDRAWN (the build record's register E14-3; no renaming of the fields is scheduled); what an older caller sees: `GoMeta.PlugIn` an `UndefVarError`; replacement: `GoMeta.Alterant`; the same-commit triple (the `public` line of `src/GoMeta.jl` and `src/state.jl`, this document's §1.1/§1.2/§6, the surface oracle `tests/unit/public_surface_tests.jl` — its set at 27 names and the clean-cut witness [10] `!isdefined(GoMeta, :PlugIn)`). THE TIER MEASURED at this commit (the register E14-1, `receipts/S8-branch/CENSUS-public-names_on-e9f4b631.txt`): every other package-public name stands on a ruling of the owner's or on his census mark — the one name without a ground was this alias; `DefaultSlot` and `ProcessStatus`, type names a consumer never writes, stay with their mechanisms by the census judge's criterion (E14-2, his to drop); the word "plugin" in `next_plugin_index`, `ActionSpec.plugin` and `RegistryBuilder.plugins` stays — R-V04B-5 renamed the type (E14-7). Witnesses: `public_surface_tests.jl` [1b] at 27 names and [10]; nine test files construct through `GM.Alterant(; …)`; the twelve forms, the 26 pins and the corpus unmoved; the probe pair `PROBES-e14-edges-{BEFORE_e9f4b631,AFTER_<build>}.txt`.
