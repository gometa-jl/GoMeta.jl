# public-api.md — GoMeta's declared public API (the semver surface) + the error-mode catalogue

**Status:** the declared public API and error-mode catalogue of GoMeta `0.4.1`
(alpha maturity).
Backward compatibility with 0.3.x is NOT
promised (the policy of GoMeta's creator, §6); the breaking-change register ships with the release.

---

## §0 — Scope

**IS.** The reference for `GoMeta`'s **public API** — the declared, semver-versioned surface a
consumer (a script, a downstream tool, or another implementation of the GoMeta language) programs
against — together with the **coded error-mode catalogue** (the codes a `goMeta` call can surface
as `Diagnostic`s) and the honest partition of which codes are armed, which are deferred, and which
crashes remain latent or are guarded by a stable refusal.

**DOES.** (1) names the **exported** surface (§1.1) and the **package-public** supporting names
(§1.2); (2) names the Engine's output surface — `altValues_evals` (+ `serialize_evals`),
the Engine's delivered surface since `0.4.0` — and the development tool's (tree, render) pair, obtained only
through `Main.BasicRenderer.outputs` loaded by the one loader and pinned byte-exact by the test layer (§1.3); (3) restates each public signature + its contract (§2); (4) enumerates
the coded error catalogue with its honest partition (§3 — the 0.3.x rows as the tables list them, plus the v0.4
registration/door rows of §3.5); (5) records the
CRLF-normalization convention (§4), the explicitly **deferred / not-v0** surfaces (§5), and the
**versioning policy** (§6: clean cuts — no compatibility promise — until at least v0.7).

**REASONING.** The API is **TOTAL over the ENTRY surface** — the registry door's two refusals (§3.5) never throw an
uncaught exception; they fail-close into a `PROCESS_ERROR` result carrying a coded `Diagnostic`; an unknown `flavor_tag`
throws `flavor_for`'s stable message (§3.4 — since `0.4.0`), a `parse_range` is taken plain
(§2), and no configuration field is refusable since `0.4.0` (the config-time profile row E-03 REMOVED with the grammar
profile — §3.1). The absorb- and apply-plane rows are the honest exception: they can still throw at
v0 — the §3 partition (the stable-message refusals of §3.4; the E-04 crash-origin row of §3.1 RETIRED at `0.4.0` —
its origin was the Visib write-back). Honesty over completeness: the row not yet armed
(the E-06 guarded refusal — §3.1) and the crashes still latent or refused with a stable message (§3.4) are documented
**as such**, never papered over with a fabricated code. A `{…}` condition is Julia's since `0.4.0`: the
unknown condition key (the vocabulary's), the no-expression guard of an empty block or a bare literal and
a `(` left open inside the body are the three condition refusals GoMeta mints (stable `GoMeta absorb:`
messages); a body Julia cannot parse is Julia's own `Meta.ParseError`; a condition that fails at evaluation is Julia's own error (§3.2).

**PURPOSE.** The stable contract a consumer programs against and a reviewer audits the surface
against — the human-readable mirror of the machine-checkable export set (`names(GoMeta)`, asserted
by `tests/unit/public_surface_tests.jl`) and of the refusal behavior the shipped witnesses assert
(`tests/unit/error_message_tests.jl` · `tests/unit/arg_guard_tests.jl` · `tests/unit/condition_tests.jl` ·
`tests/unit/slot_overflow_tests.jl` · `tests/unit/malformed_meta_tests.jl` · `tests/unit/parser_quality_tests.jl` — the last three
re-cut at `0.4.0` for the grammar's one refusal and the slot bound;
the witnesses of the former v0.2–v0.3 walls REMOVED at `0.4.0`).

## §1 — The public surface

### §1.1 — Exported names (the re-exported semver surface)

`using GoMeta` brings **exactly these four** names into scope — the declared public surface:

| Name | Kind | One-line |
|---|---|---|
| `goMeta` | function | the pipeline entry — `goMeta(bytes; config, registry) -> GoMetaDelivery` |
| `readAltValuesEvals` | function | the reader over the evals rows — the evaluated Alterant values, per piece of the file (the production surface) |
| `GoMetaConfig` | type | the v0 input options |
| `GoMetaDelivery` | type | the delivered object of a run — its four public parts, in the creator's pipeline order: `blsComponentTree`, `altValues_evals`, `status`, `diagnostics` |

`names(GoMeta)` is exactly this set plus the §1.2 public names (27 since 0.4.0 — the `PlugIn` alias
REMOVED; every change of the set since 0.3.x is a row of §6) and the module name — the
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
  deterministic, binary-safe serialization of the evals surface; its `attr` column ENCODED since 0.4.0
  (a backslash, tab, newline or carriage return in an attribute name escaped as `\\`, `\t`, `\n`, `\r` —
  one row, one line, four columns; the shipped families serialize byte-identically).
- `EvalRecord` / `EvalStore` — the type of one evals row (`cell_handle`, `attr`, `value`, `polarity`; the field `content` REMOVED at 0.4.0 — a piece's text is read from the BLS Component tree through `GoMeta.BLS.content`, the register row in §6; since 0.4.0 THE ONE PROVENANCE FIELD `decided_by::Vector{Vector{UInt8}}` — the handles of the statements that produced the row, in application order: the deciding statement's for a single-valued mode, the contributing statements' for an accumulating one, a heading row's own carrier; the name from the creator's confirmed scenarios in `tests/authored/`), and the type of the part `altValues_evals` that holds them (the reader's argument; its rows unchanged).
- `GoMeta.evaluatedAltValue(delivery, component, alterant; registry = DEFAULT_REGISTRY) -> EvaluatedAltValue` — THE ONE ANSWER FUNCTION
  (since 0.4.0): for ONE Component of the delivered tree and ONE Alterant (its registered
  name) the resolved value and its SOURCE — `:own` · `:indirect` through a named Component · `:user` · `:file` · `:fallBack`
  (reserved) · `:default` · `:none` — derived at the call from the delivered rows and their `decided_by`; the contract in §2;
  the name the creator's decision; the tier and the File's case NOT FINAL.
- `EvaluatedAltValue` — the answer record `(value, source, via)`: `value` in the Alterant's own shape, `source` ONE tag, `via` the
  deciding Component for `:indirect`, else `nothing`.
- `GoMeta.scanAlterant(delivery, alterant; registry = DEFAULT_REGISTRY) -> Vector{Pair{Component,EvaluatedAltValue}}` — THE SCAN BY
  ALTERANT (since 0.4.0): every Component for which the Engine RECORDED a value of the
  Alterant (its own rows), with its answer, in the tree's order; a rowless Component is not listed (its answer is `evaluatedAltValue`'s).
- `GoMeta.evaluatedAltValues(delivery, component; registry = DEFAULT_REGISTRY) -> Vector{Pair{Symbol,EvaluatedAltValue}}` — THE ACCESS BY
  COMPONENT: every registered Alterant's answer for ONE Component, in the registry's Alterant order. The names are the creator's
  decision; the form — functions of their own — stands, its alternative
  (methods of the reader) still open (NOT FINAL).
- `GoMeta.childDiffers(delivery, component, alterant; registry = DEFAULT_REGISTRY) -> Bool` — THE CHILD-DIFFERS SIGNAL (since
  0.4.0): `true` when the Component's resolved answer has a VALUE different
  from its parent's — COMPUTED from `evaluatedAltValue` at the call, never stored (a stored form is deferred to a later benchmark phase); the File
  never differs. The name the creator's decision; the Block-against-File reading NOT FINAL; the stored form
  deferred to a later benchmark phase.
- `ProcessStatus` (the enum) + its values `PROCESS_OK` / `PROCESS_ERROR`.
- `Diagnostic` `{code::Symbol, severity::Symbol, message::String, context::Any}` — the coded,
  non-throwing diagnostic record.
- `AlterantRegistry` + the `const DEFAULT_REGISTRY` — the deterministic alterant inventory (the
  `goMeta` default registry), a PUBLISHED (validated + sealed) value since v0.4. **What a custom
  registry can do since v0.4.0 (no registration-time
  signature reflection):** it is
  built through the lifecycle below, its declared record + derived tables + callables are
  sealed and door-checked, its setters DISPATCH (the apply plane is registry-data-driven) and a
  registry without the built-in Visib RUNS; the CAPTURE plane is registration-driven since 0.4.0 (a
  declared `CaptureDecl` row mints an Alterant's evals rows; a record without one mints none — the LIFECYCLE bullet
  below and §3.4); NOT registration-driven at v0.4: the QUERY plane's argument shape
  (the getter is called with whatever the re-written condition passes — label names as Symbols; a non-Symbol argument
  meets `getAltState`'s own `Vararg{Symbol}` MethodError at apply; the getter's signature is not verified at
  registration), and the RENDER write-back (the Visib write-back REMOVED at 0.4.0 —
  the Engine writes nothing into the BLS Components; the `settribute` declarations and the derived table REMOVED at 0.4.0;
  nothing writes back).
- **The registration LIFECYCLE (v0.4):** `RegistryBuilder()` (empty) or
  `RegistryBuilder(DEFAULT_REGISTRY)` (PRELOADED with the four built-ins, copied by the domain
  copier — nothing mutable shared with the published value; a cycle, an out-of-domain value or
  a position-rule offense in the input refuses coded — the way
  to EXTEND the shipped inventory) + `GoMeta.register!(builder,
  plugin, specs...)` — the mutable declaration site; `GoMeta.validate(builder) ->
  Vector{Diagnostic}` — the remaining check (the domain probe; the vocabulary check, the validation
  chain and the capture mode-gate laws with the Heading's separate delivery REMOVED at 0.4.0,
  §6), returning EVERY defect (in
  deterministic order) and never throwing; `GoMeta.publish(builder) -> AlterantRegistry` — the
  SANCTIONED route to a SEALED registry for conforming callers (the only supported one; see the
  honest bound below — in-process Julia cannot make it the only POSSIBLE one): refuses with `RegistrationRefused` (carrying every
  diagnostic) on any error, proceeds on warnings, COPIES every container by the domain copier
  `_domain_copy` (callables/Types/Symbols/Strings/VersionNumbers/numbers carried by reference;
  containers and slot structs rebuilt at their EXACT concrete types; sharing preserved within
  each copy); `deepcopy_internal` is never dispatched, so the user-type copy
  residue is closed; derives the hot-path tables from the declarations and takes the SNAPSHOT baseline the door
  compares against (the fingerprint `seal` it also minted REMOVED at 0.4.0; the §6 row).
  `RegistrationRefused <: Exception` — `.diagnostics::Vector{Diagnostic}` with stable codes
  (`REG_PROTOCOL` for a declared value outside the closed encodable domain — the capture mode-gate laws REMOVED with the
  Heading's separate delivery at 0.4.0;
  `REG_PROTOCOL` and `REG_SLOT_EXHAUSTED` thrown by
  `register!` — the eleven inventory, clash, reflection, algebra, reachability and candidacy codes REMOVED at
  0.4.0, §3.5 + §6). Positional `AlterantRegistry(...)`
  construction from hand-built tables is GATED since v0.4.0 (it runs the same checks and refuses
  inconsistent tables with `REG_DERIVED_TABLES`) and yields an UNPUBLISHED value that `goMeta`
  refuses — build through the lifecycle; positional construction is removed at v0.5. No positional
  form accepts a snapshot (the generated all-fields constructor is suppressed by a construction
  token); a published registry's containers are READ-ONLY by contract — the door detects, for
  conforming code and within the disclosed bounds below, a mutation of ANY walked field (the
  declared record, every derived table, every callable identity) by ONE
  structural deep-egal comparison against the publish-time SNAPSHOT (`===`-only leaves; the
  first divergent path is named in the message; `POST_SEAL_MUTATION`). **The callable driver seam `run_absorb_apply!`, its
  STATE LEDGER (`STATE_REUSE_REFUSED`, added within the 0.4 development) and the carrier-store checker `validate_carrier_state` — the adapter route of v0.3.2 —
  REMOVED at 0.4.0** (by the creator's decision: a seam serving the
  .fodt adapter alone has no place in the Engine): `goMeta` is the ONE entry — validate, the
  door, setup, parse, the fresh per-call state, the user feed, the File loop, the delivery — one function, as the original engine was;
  one parse state per call by construction. *The snapshot's honest bound, stated exactly: the snapshot's own members are mutable
  and reachable through the published value, so a mutation through a published container is
  refused UNLESS the same actor also rewrites the corresponding snapshot container — a MIXED
  case (the live half accident-grade, the snapshot half a reach into an underscored
  field — the honest bound below); the frozen-container path closes it (planned for v0.5). A callable's
  IDENTITY is compared, never its BEHAVIOR — a closure's captured state, a
  `mutable struct <: Function`'s fields, or a redefined generic's methods move behavior under
  an unchanged `===` identity, on BOTH sides at once (the leaf is shared by reference), so the
  door stays silent. A
  Dict whose keys are structurally equal but DISTINCT objects is compared as a multiset of
  entries — a permutation of values across such keys stays silent although a stored-key lookup
  observes the change (reachable only through declared container/struct-keyed Dicts; the
  engine's own tables are Symbol-keyed). A degenerate NESTED duplicate-equal-key Dict tower is
  compared in time exponential in its nesting depth (reachable only through deliberately
  constructed duplicate-equal-key nests).* **The honest bound (no in-process arrangement in Julia
  constrains a loaded module):** every integrity guarantee here is ACCIDENT-grade — coded
  refusal of unpublished or post-publication-mutated registries produced by CONFORMING code.
  It is not security-grade: the construction token is reachable by
  any loaded code (Julia has no access control), a callable's identity does not pin its behavior
  (a closure over a `Ref`, a redefined generic), and the door is a check at entry, not a lock
  over the run — a task mutating a registry concurrently with a run that already passed the door
  is outside the model. A loaded module that does any of these has full process authority
  anyway; the trust act is the user's (load only trustworthy Alterants). The canonical
  encoding's domain is CLOSED (**data slots hold concrete data**):
  `Nothing` · `Symbol` · strings · `Bool` · the machine integers · the machine floats (bit-exact)
  · `Complex` and `Rational` of those · `VersionNumber` · `Type` (parameters type-tagged) ·
  CONCRETE `Vector` / `Dict` / `Tuple` / `Pair` / `NamedTuple` of encodable values · the slot
  types. A `Function` is encodable (by name) ONLY in a designated callable field (setter, getter,
  `validate`, constructor — each a snapshot leaf the door compares by `===`); inside a
  data value (`Declared`, any container in it) it is refused. A declared
  value of ANY other type — a range, a view, a user container, `BigInt`, `Char`, an enum, an
  opaque struct — or a cyclic container is REFUSED at `validate` (`REG_PROTOCOL`, one row per
  record slot), never folded by a lossy fallback; declared string VALUES are `String`-only
  since 0.4.0 (a non-`String` `AbstractString` value refuses coded).
  The canonical slot ENCODING has one reader since 0.4.0 — the validate walk's deterministic Dict-entry order (the
  registration digest it fed and the `seal` fingerprint that digest minted were REMOVED at 0.4.0 with the grammar profile —
  the §6 row): its disclosed collisions (type identities
  module-UNQUALIFIED; the designated callables by NAME; function-valued type parameters by name; untagged parameter
  categories; un-encoded container parameters) mean only that two such keys sort as equal texts. **The door's guarantee
  reads:** a post-publication mutation of any walked field by conforming code is detected iff it changes the
  content-structural value (`===` at the leaves) — the honest bound above states the disclosed exceptions; `validate`'s
  domain walk probes every type-bearing field (a type such as `Val{'c'}` refuses with a slot-named row; a type whose
  parameter tree exceeds the type-encoder budget of 256 nodes likewise refuses slot-named — the mint that budget kept
  safe was REMOVED at 0.4.0; the bound stays as the domain's declared closure). Declared values are `String`-only and
  `deepcopy_internal` is never dispatched. No shipped declaration uses any of the collision shapes.
- `GoMeta.next_plugin_index(builder) -> Int8` — the index the next `register!` assigns (§ the
  plugin index rule below); throws `RegistrationRefused` (`REG_SLOT_EXHAUSTED`) at capacity.
- **The record VOCABULARY (v0.4; what `register!` accepts — the Alterant registration record and
  its action records; construct with the keyword forms). The record type's name is
  `Alterant` — the original engine's `PlugIn` renamed at v0.4; the public alias `PlugIn` REMOVED at 0.4.0 as a
  clean cut (the §6 row); the record's FIELD NAMES are the original engine's and stay (the keyword constructor is the one
  form):**
  - `Alterant(; altName, setMode, altConstructor, setAltInstance, getAltInstance = nothing,
    precedencesTuple = nothing, default = NoDefault(), capture = nothing, onRead = nothing)` — the Alterant registration record. `default` = `NoDefault()` |
    `Declared(value)` — the Alterant's ONE declared default value (Visib declares
    `:show`; by the creator's provisional decision, Labels the EMPTY SET `Symbol[]`, Heading
    `nothing`, Id the zero compound `(cell = 0, parent = 0, file = 0)`), delivered by the answer function with the source
    "default" where no level provided a value; since 0.4.0 (the per-action `default` of the
    action record below GAVE WAY to it — REMOVED at 0.4.0). Required:
    `altName::Symbol`; `setMode ∈ (:accumulate, :mutExclusive, :mutExclusivePerField, :localOnly)`;
    `altConstructor::Type` (the instance type); `setAltInstance::Function` (the setter — its methods ARE the
    action's forms; the declared overload rows that restated them were REMOVED at 0.4.0).
    Optional, every one nothing/empty-defaulted: `getAltInstance` (the query getter, required
    for an action used as a condition atom); the v0.4 declared slots below; `onRead` (since 0.4.1) — THE READ-TIME HOOK, a function
    `(run, mhIdx, actionName, args, hasCondition) -> nothing | run′` the Engine calls at the READ of every one of the Alterant's
    statements WITH arguments, after the profile feed's one `localOnly` refusal and before the slot bound: `nothing` = the statement
    is enqueued as stated; any other value = the statement is CONSUMED at the read — nothing is queued, its condition is not kept,
    neither the String-slot law nor the declared `validate` runs for it — and the value becomes the Alterant's per-run state, handed
    back on the hook's next call and to `altConstructor(run)` for every later instance of that run (the zero-argument call where none
    was minted); a hook's own throw, and a run state handed to a constructor without a one-argument method, are Julia's own error out
    of `goMeta`. A designated callable field like the setter; the Labels Alterant's hook records the vocabulary statements (their contract: §2, THE VOCABULARY STATEMENTS; their refusals: §3.4); every
    other shipped Alterant leaves it `nothing`. The positional 0.3.x form was REMOVED at
    0.4.0 (a clean cut, §6): the keyword form is the one form.
  - `ActionSpec(; name, plugin, accepts_string_slot = 0, validate = nothing)` — one action
    record. `plugin::Int8` = the declaration-order index of the OWNING Alterant (`register!` binds it: every record
    passed with a plugin must name that plugin's index); `accepts_string_slot` = the accepting String-literal slot
    (0 = none); `validate` = the handover validation (below). (The `settribute` write-back key was REMOVED from the record at 0.4.0;
    the per-action `default` keyword was REMOVED at 0.4.0 —
    the default is the Alterant's.)
  - `ActionOverload`, `spelling`, `sugar_candidacy`, `keyed_slot` — **REMOVED at 0.4.0**
    (the §6 row): the per-setter-method rows (signature types, literal kinds, return type, effect,
    queryability, applicability, phase, grammar flag) restated what the setter's methods declare and were read at run
    time by nothing once the set-invocation seam was removed, also at 0.4.0 (the §6 row; the registration digest — REMOVED at 0.4.0 — folded them, the door walked them); the spelling tag, the
    sugar register and the reserved slot were read by nothing but the fold. An action is registered by its name and its
    owning Alterant, and Julia dispatch does the rest — the original engine's form; the 8-positional record constructor
    was REMOVED too (a clean cut, §6).
  - **The getter contract** (`Alterant.getAltInstance`, required for an action used as a condition atom — the `queryable` row flag REMOVED at 0.4.0):
    called as `getter(instance, actionName::Symbol, args::Symbol...) -> Bool` — the re-written condition calls it bare
    through `getAltState(Int8(p), Symbol("action"), args…)` as the original engine did (since 0.4.0):
    a label name reaches it as a Symbol; a non-Symbol
    argument meets `getAltState`'s own `Vararg{Symbol}` MethodError; a getter's throw propagates raw out of the `goMeta`
    call; a non-`Bool` return is Julia's own `TypeError` where the condition needs a Bool (the closed interpreter's
    `CB_QUERY_THROW` / `RES_RETURN_TYPE` envelope at its atom was REMOVED with the interpreter at 0.4.0 — §3.4). The getter's signature is
    not verified at registration (the `queryable` row flag and its existence check REMOVED at 0.4.0). No
    registration-time signature reflection runs since 0.4.0 (deferred).
  - **The validate contract** (`ActionSpec.validate`, the handover validation of the accepting
    String slot): called as `validate(text::String) -> Bool` — `true` accepts; `false` refuses with the
    catalogue-named stable message (`REG_VALIDATE_FALSE` — an `ErrorException` carrying the name, the §3.4
    seam-envelope family; its coded-`Diagnostic` conversion deferred); a non-`Bool` return refuses
    (`RES_RETURN_TYPE`); a throw of
    any other class wraps (`CB_VALIDATE_THROW`, the class named via `nameof`, never its text).
    A validator may refuse with its OWN complete stable message by throwing an `ErrorException`
    whose message begins `"GoMeta "` — the engine's guarded-refusal vocabulary, passed
    through the envelope verbatim (the shipped heading validator's empty-text refusal
    is exactly this class); any other throw is a validator DEFECT.
  - **The constructor dependency** (`Alterant.altConstructor`): is called in one of TWO forms since 0.4.1 —
    bare, `altConstructor()`, at the apply loop's instance-mint sites (`_freshInstance`, `src/alterants/apply.jl`) where the Alterant's read-time hook minted no run state — every Alterant without a hook, and the Labels Alterant in a run without a vocabulary statement — and with the run state, `altConstructor(run)`, where it did (the `onRead` contract above); so a registration without a hook must be ZERO-ARG constructible, one with a hook ONE-ARG constructible as well (the bare call alone since 0.4.0; the absorb heading seam's call was removed with the Heading's separate delivery, also at 0.4.0 — §6): an
    absent method for the call made, or a throwing constructor, is Julia's own error out of the `goMeta` call (the eager
    `DEP_MISSING` gate at `validate` REMOVED at 0.4.0; the mint wrap `CB_CTOR_THROW` REMOVED at 0.4.0, and the
    per-invocation store-identity check `RES_FOREIGN_STORE` with it — both with the set-invocation seam).
  - **The plugin index rule:** `ActionSpec.plugin` is the declaration-order index of the owning
    Alterant, an `Int8` you supply — `GoMeta.next_plugin_index(builder)` returns the index the
    NEXT `register!` call will assign (1 on an empty builder; 5 after the four built-ins), and
    `register!` REFUSES (throws `RegistrationRefused`, `REG_PROTOCOL`, nothing appended) any record
    whose index is not that one. Immutable records are never re-stamped silently.
  - The declared SLOTS: `CaptureDecl(attr_scheme ∈ (:per_key, :single, :per_field, :per_entry)[, attr_stem]; attr_stem = nothing)` —
    CONSUMED since 0.4.0: the capture walk
    is REGISTRATION-DRIVEN (the declared row is what makes an Alterant's applied state mint evals rows; the store's
    shape is the record's own `altConstructor`; a record WITHOUT a row mints none; the walk reads the store bare —
    the capture-floor warnings, the value algebra and the shape gates were REMOVED from the walk at 0.4.0, and the former `instance_type` and `multiplicity` fields with them); `:per_entry` is the Heading's scheme since
    0.4.0 — one row per entry of a Heading-shaped store, the level in the attr name, the text the value, the i-th entry's `decided_by` the origin of the i-th applied statement (the scheme's CONTRACT: the setter appends EXACTLY ONE entry per applied call, as the Heading's `setHead` does — a setter appending none or several is not refused and mis-pairs, a surplus entry carrying the whole origin list) — the ONE capture walk
    for every Alterant (the former `mode_gate` field, its closed set, the mode-gate laws and the `:per_occurrence` presence scheme of the
    Heading's separate delivery REMOVED with that delivery at 0.4.0, the §6 row; the identity, stem-shape and stem-clash laws REMOVED at 0.4.0 —
    a stem overlapping a shipped family publishes, and same-cell same-attr rows of two plugins collapse to one) ·
    `DefaultSlot` = `NoDefault()` | `Declared(v)`. `Alterant`'s keyword form defaults both slots (`capture = nothing`,
    `default = NoDefault()`); both are CONSUMED — the capture declaration by the capture walk, the default by
    the answer function. The seven other declared slots — the render-plane data
    (`RenderDecl`, `EffectRow`), the constraint rows (`MutEx`), the contributed condition atoms (`ConditionAtom`), the
    contract version and the required capabilities, the sugar rows (`SugarRow`), the provenance group (`Provenance`,
    `DomainRef`, `SignatureRecord`) and the permissions manifest (`PermissionManifest`) — were REMOVED from the record at 0.4.0
    (the §6 row): nine public types and eight record fields fewer.
  - **The Labels vocabulary (hard-coded in the Labels Alterant's OWN file since 0.4.0,
    by the creator's decision; before it — within the 0.4 development, in no released version —
    a plain file read at load):** the 39 names — the 38 shipped names in the former plain
    file's order plus `:doc` — are the Julia literal `LABELS_VOCABULARY` in `src/alterants-std/labels.jl`, beside
    `setLabels` and `checkLabels` (std-Alterant territory, never a Core literal); a later name is one line there; the
    plain file `labels_vocabulary.txt` and its loader were REMOVED at 0.4.0. `setLabels` refuses a name outside the run's vocabulary — since 0.4.1 these 39 names are the BASE, extended and pruned per run by the vocabulary statements of §2 (the setter's kept `Dict{Symbol,Bool}` method checks the shipped list alone); the refusal
    (§3.4); `checkLabels` answers false for an unset or unknown name, as the original engine did. The Labels vocabulary machinery — the record's
    `vocabulary` slot with its two types, the digest pin, the capture cache, the artifact grammar, the scope law, the
    `vocabulary` / `vocabulary_member` / `vocabulary_queryable` triple, the `SRC_DIGEST_MISMATCH` row, the write-only valve and the labels record's policy identity — REMOVED at 0.4.0 (§6).

They are not exported; reach them qualified. `tests/unit/public_surface_tests.jl` asserts every
§1.2 name is `public` and NOT exported (no accidental leak, no silent demotion).

- `GoMeta.BLS` — the parser module, public by name since 0.4.0: the
  BLS Component tree (`result.blsComponentTree`) is BLS's own object, provided by BLS itself and travelled with BLS's
  own public functions — THE DOOR, read qualified `GoMeta.BLS.<name>`, nothing exported: `children(tree, c)` /
  `children(tree)` (the child Components in source order; the File's Blocks), `parent(tree, c)` (the parent
  Component; `nothing` for the File), `kind(c)` (`:Meta` / `:Code` / `:Text` — the Component's flavor; `nothing` for the File), `content(tree, c)`
  (the verbatim content bytes at the Component's own grain) and `content(tree)` (the document's lines joined by a newline — the File's
  text as BLS holds it, no terminal newline; the one-argument form, since 0.4.0); and, for the development tools and the tests:
  `root(tree)` (the File), `flavor(tree)` (the flavor record — the PROMISE is five of its fields, `lead`, `hide_marker`,
  `hide_fold_prefix`, `flavor_tag`, `re_meta_leaded`; every other field, `directives` first, is reachable but not part of the
  contract (the `parse_header!` pointer REMOVED at 0.4.0); its type stays internal), `endsWithNewline(tree)`, `isHorizontalSpace(c)` (the parser's horizontal-whitespace
  class — the print tools' lexer and, since 0.4.0, the renderer's whitespace guard before the hide marker), the
  settribute / position read `getElement` (over a container, or over a Component by key — through which a caller reads no
  field), the Component types `File` / `Block` / `Line` / `Segment` and the
  named-element types `ComponentSettribute` / `CmpntNamedInt`. Each name has its row in §6. Everything else in
  `GoMeta.BLS` is internal.

### §1.3 — The Engine's output surface, and the development tool's pair (since 0.4.0)

1. **The package's canonical observable output is `altValues_evals` (+
   `serialize_evals`); the Engine's delivered surface is the run
   and the evaluated values.** `readAltValuesEvals(result.altValues_evals)` is the evaluated Alterant values, per piece of the
   file: the deterministic, final-verdicts-only map `(cell_handle, attr, value, polarity)`, keyed by (handle, attr);
   `GoMeta.serialize_evals` its byte form; a cell's bytes through `GoMeta.BLS.content` since 0.4.0 (the former
   `content_fingerprint` was REMOVED at 0.4.0; the §6 row). No internal module
   (`walk`) ever needs importing for it; `GoMeta.BLS` is public for the BLS Component tree (§1.2), not needed for the evals.
2. **The (tree, render) pair is the development tool's**, not the Engine's: `Main.BasicRenderer.outputs(result)
   -> (blsStructure_bytes, render_bytes)` — the verdict-free tree print + the `jl-share-v1` share render — is
   obtained ONLY through the basic renderer (`devtools/basic_renderer.jl`) loaded by its one loader,
   `include(joinpath(pkgdir(GoMeta), "devtools", "load_basic_renderer.jl"))` at the caller's top level; `devtools/README.md` documents it.
   **No Extension takes this pair** (the creator's rule): an
   Extension consumes the Engine's answer through the delivered object and the BLS Component tree, which reaches it as
   the part `blsComponentTree` (BLS's own delivery) — the pair is the tool's own, proved by its seven render
   reference files, never by an Extension.
3. **The test layer pins that pair byte-exact** against the corpus golden (`tests/golden/`) — the test
   layer's property, beside the twelve annotation pins of the Engine's values.

## §2 — Signatures + contracts

**⚠ Trust note:** a `{…}` condition is Julia text, read by Julia's parser at absorb and evaluated by Julia at apply
(§3.2; since 0.4.0 — the creator's design: a full parser must be available to those who, for instance, work only
with their own GoMeta statements, provided there is no security risk). Processing a file
you did not write therefore runs its conditions — see the SECURITY section of `README.md`.

### `goMeta(bytes::Vector{UInt8}; config::GoMetaConfig = GoMetaConfig(), registry::AlterantRegistry = DEFAULT_REGISTRY) -> GoMetaDelivery`

(`goMeta` consumes raw bytes; from a `String` use `Vector{UInt8}(codeunits(s))` — or `read(path)`
for a file, as in the README quickstart.)

Pure, deterministic, **TOTAL over the ENTRY surface** (the registry door's refusals are delivered coded, §3.5; an
unknown `flavor_tag` throws its stable message, §3.4 — since 0.4.0; absorb/apply-plane catalogued failures can still throw at v0 — the §3
partition). `GoMetaDelivery` carries the run's FOUR public parts, read by name, in the order of the pipeline:
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
evaluated by Julia (since 0.4.0; the creator's design), so what it reads or does is the
author's act in the same way — the guarantees hold for inputs whose conditions are free of side effects and of reads of changing state (a clock, a file, the environment).** The
registry door's refusal (below) fail-closes into a `PROCESS_ERROR` `GoMetaDelivery` **before any parse** — the input
bytes are never touched; no parse or verdict work occurs (§3.5); the Engine renders nothing since
0.4.0 (§1.3), and the development tool's `Main.BasicRenderer.outputs` on such a result is the empty pair. (The
config-time profile refusal that fail-closed the same way — E-03 — was REMOVED at 0.4.0 with the profile; §3.1.)

**The registry door (v0.4, STRICT — published-only).** `registry` must be a PUBLISHED value
(`DEFAULT_REGISTRY`, or the result of `GoMeta.publish`). A conforming-but-unpublished registry
(e.g. a gated positional construction) fail-closes before any parse — a
`PROCESS_ERROR` result before any parse, carrying `REG_UNPUBLISHED`, whose message names the
sanctioned path `RegistryBuilder → validate → publish`. A published registry whose containers
were mutated after publication fail-closes with `POST_SEAL_MUTATION` (the live fields are
compared structurally against the publish-time snapshot at the door — the real freeze gate;
the message names the first divergent path; re-publication is the sanctioned change path).
The door's diagnostics are the entry refusal: no configuration field is refusable since 0.4.0 (the profile row
was REMOVED with the grammar profile; the range is taken plain, and an unknown flavor tag meets `flavor_for`'s own message).

### `GoMetaConfig(; flavor_tag = :julia, parse_range = nothing, user_mh_profile = nothing, namespace = :default)`

The v0 input options (the versioning policy §6). (The `profile::Symbol` field and keyword — the selector of the closed
condition grammar's profile and its two opt-in names — were REMOVED at 0.4.0 with that grammar;
the EXPORTED type RE-SHAPED, the §6 row: `GoMetaConfig(profile = …)` is a `MethodError` since. The RENDER's
share-profile `jl-share-v1` is the development tool's and was never this field.) `flavor_tag::Symbol` — the content flavor: a CLOSED set of three armed flavors,
`:julia` (the `#` lead alphabet — the default) · `:c` (the C-family `//` line-comment flavor) ·
`:latex` (the `%` lead alphabet); any other value throws at `BLS.flavor_for` — a stable message naming the
inventory, no fallback (§3.4) — before any parse; selected, never inferred (no file-extension or content
sniffing). *(The coded `ERR_UNKNOWN_FLAVOR` refusal that an unknown tag met before was
REMOVED at 0.4.0 —
its row in the §3.1 table.)*
`namespace::Symbol` — the occurrence-key namespace every `altValues_evals` cell handle is scoped
under (`:default` by default; encoded as the key's length-prefixed namespace segment). One
constructor-time guard: a namespace over 65535 bytes throws an `ArgumentError` at
`GoMetaConfig(; …)` construction (the keyword form; the generated positional form carries no guard) — before any `goMeta` run, hence outside the fail-close rows
below (which require a constructed config).
`parse_range::Union{Nothing,UnitRange{Int}}` — `nothing` ⇒ the whole input; a given range is taken
**plain**: `last` is the parse end line and `first` is never read (`5:10` parses lines 1..10). Its unit is
**line indices of the input**, and a `last` beyond the input's final line is accepted without complaint —
`1:99` on a two-line input returns `PROCESS_OK` and renders both lines, with no diagnostic; a non-positive
`last` (`1:0`) parses the whole file (the parser's contract). *(The coded `ERR_RANGE_INVALID` fail-close was REMOVED at 0.4.0:
it refused `first ≠ 1` and the empty range.)*
`user_mh_profile::Union{Nothing,String}` — RESERVED / experimental: `nothing` (default) ⇒ no feed,
byte-identical to the no-feed path — and so an EMPTY or whitespace-only String (inert like `nothing` since 0.4.0;
before it an empty profile occupied the user slot and so made it
the loop's first slot; white space as the absorb's ONE predicate `_isspace_valid` reads it — Julia's `isspace` guarded by
`isvalid` — so a profile whose edge character is an invalid byte sequence is content and FED; the profile of one
overlong sequence `"\xe0\x80\x80"` is refused by the absorb); any
other `String` ⇒ that metaLine BODY is seeded into the reserved
user slot of the meta-hierarchy before the walk — THE USER LEVEL (since 0.4.1; the §6 register row): its accumulating
statements (labels) are collected before the file's, as the outermost level; its other statements are evaluated AFTER the
Component's own slot — its metaBlock, or for a Line its trailing metaSegment — with full sight of the Component's own labels,
and with PRIORITY — an applicable user-level value overrides the file's; the Component's own metaBlock (or trailing
metaSegment) applies in written order with or without a feed. The one exception, UNMEASURED (as the code reads, only a `#]`
close Block before any absorbed metaBlock reaches it, and no fed input measured holds one): a Component whose only eligible
slot is the user level's has no own slot and runs the no-feed path — the profile's rows in written order, its labels not collected first.
Since 0.4.1 the profile may also carry the Labels Alterant's VOCABULARY statements — `:++x` / `:(++, x, y)` / `:--x` / `:(--, x)` (§3.4) —
consumed when the profile is read, before the walk: the profile's vocabulary statements precede every statement of the file.
THE USER CONTEXT: the feed carries its own identity — the minted user-context handle (grain `0xe0`) rides the fed
actions' `decided_by`; queued fed actions apply only where document cells exist. A HEADING in a fed profile — the sugar, the
deriving `head(text)` and the explicit `head(text, level)` alike — REFUSES at the read with the one stable message
`"GoMeta absorb: a heading (Heading Alterant) in the profile feed has no Component of the file levels to be local to (see docs/public-api.md §3.4)"` (the message's
wording and the decision on the fed heading — no row, a refusal at the read — are the creator's; since 0.4.0;
before it the explicit form recorded one row against the user-context handle). New rows appear
ONLY when this field is set. Deliberately scope-limited at v0.

### `readAltValuesEvals(altValues_evals::EvalStore) -> Vector{Tuple{Vector{UInt8},Symbol,Any,Bool}}`

Given the delivered PART — the data container, never the whole delivered object:
`readAltValuesEvals(result.altValues_evals)` (a reader takes the PART)
— the evaluated Alterant values, per piece of the file: the final map
`(cell_handle, attr, value, polarity)` — per-cell rows (no non-cell row exists since 0.4.0: a heading
in the fed profile refuses at the read) — **sorted by `(cell_handle,
attr, value)`** for a deterministic, content-hashable order; **final-verdicts-only** (deduped at
capture); **empty when no metaLine exists on ANY surface** (the fed profile IS a metaLine body);
outside the `(tree, render)` pair at v0. The `(attr, value)` domains at v0:
`:label_<name> => true` (one row per accumulated label) · `:visib => :hide | :show | :discard`
(the winning visibility verdict) · `:id_<name> => Int16` (experimental Id values, one row per
NON-ZERO field — a stated zero is not recorded, so zero and unset are indistinguishable in the rows; the compound is set as a
WHOLE by the nearest statement, an unset field not inherited from an outer slot, and within one slot the last row of a field
wins — the per-field semantics DEFERRED, the contract narrowed, the first authored Id scenario a
draft) · `:head_<level> => String` (author-supplied section headings — the §2 Heading action; `head_<level>_<k>`, k ≥ 2 in source order,
for same-level repeats on one recorded handle); `polarity` is always `true` at v0 (the field
is reserved for a future negated-verdict encoding). Consumers should treat UNKNOWN attribute
families as opaque — skip them, never error: the enumeration lists the v0 families, and new
families may arrive in a later version under the versioning policy (§6 — no compatibility promise until at least v0.7). `GoMeta.serialize_evals(readAltValuesEvals(result.altValues_evals))` is its canonical
byte form — one row per line, four tab-separated columns, the `attr` column encoded (a backslash, tab, newline or
carriage return in an attribute name escaped as `\\`, `\t`, `\n`, `\r`, since 0.4.0; the
registry refuses no delimiter in a stem, that hardening deferred).

### `evaluatedAltValue(delivery::GoMetaDelivery, component, alterant::Symbol; registry::AlterantRegistry = DEFAULT_REGISTRY) -> EvaluatedAltValue`

THE ONE ANSWER FUNCTION (since 0.4.0) — for ONE Component of the
delivered tree (`result.blsComponentTree`, reached through `BLS.parent` for a rowless child's inheritance; a deciding handle's
Component read from the handle's own path) and ONE Alterant by
its registered name (`:Visib`, `:labels`, `:id`, `:heading` in the default registry): the resolved value and its SOURCE,
derived at the call from the delivered rows and their `decided_by` provenance — never stored, never cached, the delivery
untouched. `EvaluatedAltValue(value, source, via)`: `value` in the Alterant's own shape (Visib a `Symbol`; Labels the SET of names,
a sorted `Vector{Symbol}`; Id the compound, a `NamedTuple` of the recorded fields; Heading the `String` of the first heading
row); `source` ONE tag — `:own` (every deciding statement the Component's own), `:indirect` (through the Component `via`
whose statement decided it — the metaBlock an attached Block follows, the Line a rowless Segment answers through),
`:user` (the fed profile), `:file` (the File level's room — no feed at v0.4), `:fallBack` (RESERVED for the
fallBack level's carrier once the metaLevel Alterant feeds it), `:default` (no rows anywhere: the Alterant's
declared default — Visib's `:show`; Labels' `Symbol[]`, Heading's `nothing`, Id's zero compound),
`:none` (no rows and no declared default — an Alterant of a custom registry without one; the File — NOTHING built for
it at v0.4); an Alterant without a capture DECLARATION mints no rows and answers its declared default or
`:none`, and an undeclared capture stem is derived as the walk derives it (`lowercase(altName)`). The trailing metaSegment's statement is
applied DIRECTLY to its Line — its row keyed on the Line with the Segment as the key's origin (Visib, Labels, Id): the Line answers `:own`;
the Segment itself, like every Segment of that Line, answers AS its Line answers, the Line's `:own` marked `:indirect` through the Line and
every other source unchanged (`:indirect` through the Line's own decider, `:user`, `:file`) — the creator's design.
The inline HEADING follows the same rule since 0.4.0: its row is keyed on the Line with the Segment
as the key's origin and decided by the Segment — the Line answers `:own`, its Segments `:indirect` through the Line (before 0.4.0 the row
sat on the Segment itself, the heading's former separate `:localOnly` delivery keying it on its carrier). Since 0.4.0 the Heading runs
through the apply loop like every Alterant (the creator's design): its
row is keyed and decided by the common capture — the same rule by the machinery itself, the separate delivery gone. A rowless child inherits its parent's rows up the tree (a
Segment its Line's, a Line its Block's); a Segment-carried row (keyed on a Line with the Segment as
the key's origin) is the Line's. An unknown Alterant name throws `ArgumentError` naming the registered names. **NOT FINAL**
— the tier, the File's case and the equal-child rows remain open after 0.4.0;
the per-call row scan stands; a cached index behind the answer function is DEFERRED to a later benchmark phase after 0.4.0 (by the creator's decision; no per-call tree walk
behind `via` — the Component read from the handle's own path); no
compatibility promise before v0.7 (§6). The name is DECIDED by the creator: `evaluatedAltValue`, replacing the former working name `answerFor`.

### `scanAlterant(delivery, alterant; registry = DEFAULT_REGISTRY)` · `evaluatedAltValues(delivery, component; registry = DEFAULT_REGISTRY)`

THE TWO VIEWS OVER THE ONE ANSWER FUNCTION (since 0.4.0; the creator's requirement: an Extension may scan for all
BLS Components that were assigned Ids, and for what kind of Ids, and must be able to access all such information as
efficiently as possible, the information unambiguous and informative). `scanAlterant`
returns, for ONE Alterant, every Component of the delivered tree for which the Engine RECORDED a value (the Component's own rows —
a Segment-carried row is its Line's), paired with its `evaluatedAltValue` answer, in the tree's order (each Block, its Lines, their
Segments); a Component without own rows is not listed — its answer is still `evaluatedAltValue`'s (inherited or the default; in the creator's design
the children are hidden as PART OF their Block); the File is never listed. `evaluatedAltValues` returns, for ONE Component, every registered
Alterant's answer in the registry's Alterant order (`registry.plugins`), each paired with the Alterant's registered name. Both are
pure, derived at the call, and can never disagree with `evaluatedAltValue` (they are built on it). An unknown Alterant name throws
`ArgumentError`. **NOT FINAL** — functions of their own stand; the alternative, methods of the
reader `readAltValuesEvals`, stays open (the functions' names are the creator's decision);
no compatibility promise before v0.7 (§6).

### `childDiffers(delivery::GoMetaDelivery, component, alterant::Symbol; registry::AlterantRegistry = DEFAULT_REGISTRY) -> Bool`

THE CHILD-DIFFERS SIGNAL, COMPUTED FROM THE ANSWER (since 0.4.0; its stored form deferred to a later benchmark phase; by the creator's
design a Block's child Components' evaluations need to be recorded explicitly only if they differ from their parent's
corresponding evaluation): `true`
when `evaluatedAltValue(component).value` differs from `evaluatedAltValue(parent).value` — a Segment against its Line, a Line against its Block, a
Block against the File (which answers `nothing` at v0.4, NOTHING built for it — so a Block with any VALUE, the
declared default included, differs, and a Block answering `:none` — value `nothing`, an Alterant without a declared default and no
rows — does not); the File itself `false`. The VALUE is compared, not the source: a rowless child inheriting its
parent's rows never differs (it is hidden as PART OF its Block, in the creator's design); a child with its own statement differs exactly
when that statement's value is another. Pure; nothing stored. An unknown Alterant name throws `ArgumentError` (for every Component
but the File, whose `false` precedes the name's check). In the creator's design a Boolean sits beside the PARENT's entry and asks whether ANY of its
children differ — for a parent P it is `any(c -> childDiffers(delivery, c, alterant), BLS.children(delivery.blsComponentTree, P))`;
`childDiffers` is the per-child primitive (the same question for ONE child) from which that aggregate is computed; the
aggregate's own form — a function of its own, or the stored flag beside the parent's row — is a later benchmark phase's. **NOT FINAL** —
the name kept by the creator's decision; the Block-against-File reading remains open after 0.4.0; no
compatibility promise before v0.7 (§6).

### The (tree, render) pair — a development tool's, since 0.4.0

`GoMeta.outputs` left the Engine at 0.4.0 (the breaking-change register row in §6). The pair `(blsStructure_bytes, render_bytes)` —
the verdict-free tree print + the `jl-share-v1` share render, the SAME field names and order, the same non-OK
contract (a `PROCESS_ERROR` result of an entry refusal — at `goMeta` before its parse — yields the **empty** pair) — is the basic renderer's own function
`Main.BasicRenderer.outputs(result)`, obtained ONLY after `include(joinpath(pkgdir(GoMeta), "devtools", "load_basic_renderer.jl"))` at the
caller's top level. Its render-plane qualification (the character-safe string indexing, §4) is the tool's; since 0.4.0
every Visib verdict the render applies is the Engine's answer per Component (`evaluatedAltValue`, §1.2), the
renderer resolving nothing itself. See `devtools/README.md` and `docs/CANONICAL-OUTPUT.md`.

### The metaLine argument forms (v0)

An alterant ACTION token may carry a parenthesized, comma-split argument list — `action(arg1,
arg2)` — parsed with the metaLine and handed to the action when it fires. The v0 forms:

- **Labels (the `:` action) — DOCUMENTED, both forms:** repeated one-word labels
  (`#~ :label1 :label2`) AND the parenthesized list (`#~ :(label1, label2)`) — equivalent; each
  label APPLIED is checked against the Labels Alterant's vocabulary — since 0.4.1 the RUN's (an unknown label ⇒ the §3.4 stable refusal, its message naming the run's accepted set); a
  label QUERIED in a condition answers false when it is unknown or unset (as the original engine answered; since
  `0.4.0`). The corpus-documented labels are `:label1`..`:label5`; since `0.3.0`
  the shipped vocabulary additionally holds a fixed pictograph vocabulary (e.g. `:💡`, `:📝`,
  `:🔥`) and, since `0.4.0`, `:doc` — the whole list hard-coded in the Labels Alterant's own
  file `src/alterants-std/labels.jl` (§1.2; the full set is the refusal message's accepted-set listing; byte-exact names, no
  normalization: an emoji variant with different bytes is a different — unknown — name).
  **THE VOCABULARY STATEMENTS (since 0.4.1):** a file may ADD names to the Labels Alterant's vocabulary for the run — `:++x` (one name)
  or `:(++, x, y)` (several) — and REMOVE names from it — `:--x` or `:(--, x)`, a shipped name as well as one added before; the run
  starts from the shipped list (the base) and the effective set is the base plus the additions minus the removals, the last statement
  in reading order winning (a removed name added again is back; a base name added is a no-op; a name never present removed is a
  no-op). THE PLACES: a metaBlock OPENED by `#~0` (every metaLine of it; a `#~0` written as a non-first metaLine under a `#~` opener is
  read at that opener's level) and the user's profile (`GoMetaConfig.user_mh_profile`) — anywhere else the statement is REFUSED at the
  read with a message naming the two places. RECORDED ONCE AT THE READ by the Labels Alterant's read-time hook (§1.2): it takes no
  slot (the per-slot capacity of 8 is untouched), mints no evals row, applies to no Component, and a later `#~0` metaBlock does not
  undo it; it takes effect for the apply of its own metaBlock and of every later Block — a Block applied before it is untouched, and
  inside its own metaBlock the order of the statements is immaterial (a use before a declaration applies; a use before a removal
  refuses); the profile's vocabulary statements, read at the feed, precede every statement of the file (a file's statement therefore
  wins over the profile's for the same name). FIVE MALFORMED SHAPES are refused at the read: a condition on a vocabulary statement; a
  declared name beginning with `+` or `-`; a vocabulary statement naming no label (`:++`, `:(++)`); a list with an EMPTY member, a stray
  comma (`:(++,)`, `:(++, x, )`); the prefixed sign with several arguments (`:(++x, y)` — the list form names several). A quoted token
  among the arguments (`:(++, "x")`) makes no vocabulary statement: the statement is handed to the enqueue, where the String-slot law
  refuses it as before. A run WITHOUT a vocabulary statement evaluates as before; nothing is delivered for a declaration and nothing
  persists beyond the run (a vocabulary data file outside the Engine, its loading chosen at the user or file level, and a run's
  additions written back belong to a later release).
- **The Heading action (`head`) — DOCUMENTED at this release; evaluated-surface only:** section
  titles are metadata. A metaLine whose FIRST token starts with a `""`-fenced string lowers
  to the deriving `head` call — `#~2 "Title"` ≡ `#~2 head("Title")` — and the canonical calls
  are position-free: `head("Title")` (level derived from the placement — the depth of the metaBlock its metaLine belongs
  to; a metaLine glued to a preceding metaLine shares that metaBlock's level, its own `#~` digit not read for it) and
  `head("Title", 2)` (explicit — its level needs no placement; in a fed profile every heading form refuses, §3.4). Captured
  headings surface as
  `head_<level>` rows in `altValues_evals` (same-level repeats on one recorded handle:
  `head_<level>_<k>` — the `altValues_evals` domain line above) and have NO render effect. The recorded level
  follows the author's own numbering — the `#~` digit of the metaBlock's first metaLine (a metaLine glued to it takes that level, above) or the explicit level argument, never
  a renormalized outline level: `#~ "T"` records `head_1`, `#~2 "T"` and `head("T", 2)` both
  record `head_2`, `#~0 "T"` records `head_0` (a file-level heading), and an inline segment
  meta (`x = 1 #~ "T"`) records the documented constant `head_10` — the one fixed exception;
  an inline DEPTH DIGIT (`x = 1 #~2 "T"`) is accepted by the structural parse but does not
  affect the recorded level (still `head_10`). The explicit level argument must land in the
  LEVEL VOCABULARY — the structural window `0..8` or the documented inline constant `10`
  (`head("T", 10)` records `head_10`, sharing the inline constant's name); any other explicit
  level (`head("T", 9)`, a negative level, `11`) is REFUSED by the Heading alterant's own
  validation seam with the §3.4 stable message `"GoMeta absorb: explicit heading level … is
  outside the level vocabulary"` — a standing v0.2 semantic. The `head` TEXT slot is the one
  String-accepting argument position on the one String-accepting action — every other slot
  of every action, including `head`'s level slot, refuses a String. A NON-first quoted token
  on a metaLine is reserved and refuses with the grammar's one refusal — `GoMeta absorb: unexpected character '"' at the start of a
  metaStatement …`, with the hint that a quoted text is the heading sugar at the region's first metaStatement only (since
  `0.4.0`, by the creator's design). `head`, like `cell`/`parent`/`file`, is no condition key — a condition naming it meets the usual
  unknown-condition-key refusal (the registry's `queryable_action` rule since `0.4.0`: the Heading and Id answer no
  query). A heading's own condition is Julia's, evaluated at the apply of the Component the heading is applied to (the
  metaBlock for a whole-line heading, the Line for a trailing one) against that Component's settributes and the labels in
  force there — like every other Alterant's condition (since `0.4.0`, by the creator's decisions):
  a label test is legal — `#~2 "T"{ :label1 }` on a metaLine below a `#~ :label1` region, a Code or blank Line
  between the two, records `head_2`; GLUED to the `#~ :label1` metaLine it forms ONE metaBlock with it, takes that
  metaBlock's level and records `head_1`, the label seen as stated before the heading in that metaBlock; within one metaLine a label stated BEFORE the heading is seen by the heading's condition, one stated
  AFTER it is not (the loop's source order, as for `hide`) — with or without a fed profile since 0.4.1 (a fed label is seen as a level above, and the metaBlock's own written order holds under a feed too — in 0.4.0 a fed profile made the user level the loop's first slot, so a label stated after the heading was seen), and the quoted-first heading is always first on its line, so its
  condition sees the labels of the levels above; false means no row (a label unknown to the vocabulary answers false).
  The former wall "alterant-state query in a heading condition" was removed at `0.4.0` with the Heading's separate delivery (§3.4).
  Refusal catalogue: §3.4.
- **Id actions (`cell` / `parent` / `file`, and `ids` since `0.4.0`) — EXPERIMENTAL at this release:** the three single actions take one integer value
  argument each (`#~ cell(7)`), Int16 domain; `ids` takes the three at once — `#~ ids(c, p, f)` sets cell, parent and file exactly as
  `cell(c) parent(p) file(f)` would (the same `Int16` parse, the same `id_*` rows, the same fault class: a wrong arity, a
  non-parsable or an overflowing value is Julia's own error out of `goMeta`, below — a one-value `ids(7)` among them). The Id alterant is a v0 placeholder implementation;
  this syntax may change — do not build durable content on it
  at v0. Inherited Id values do not cross a block separation at v0.
- **Visib actions (`show` / `hide` / `discard`) take NO arguments;** an empty list (`hide()`) is
  accepted as the bare form.
- **Malformed arguments** (wrong arity; non-parsable or overflowing values) are Julia's own error out of the
  `goMeta` call since `0.4.0` (the former stable `"GoMeta apply: invalid arguments …"` refusal
  was removed at `0.4.0` with the set-invocation seam; §3.4).
- **Condition-side atoms** (`{ cell(7) }`, `{ cell }` inside `{}`) meet the usual unknown-condition-key refusal at the
  absorb seam, with or without arguments — `cell` declares no getter (the registry's rule since `0.4.0`; the
  closed intake's argument-domain refusal and the E-07 pending mint were removed with the interpreter at `0.4.0`, §3.2).

## §3 — The coded error-mode catalogue

`Diagnostic = {code::Symbol, severity, message, context}`; a catalogued failure is a coded
`Diagnostic` except where its row says otherwise — the E-06 GUARDED refusal
still throws (§3.1; its coded conversion deferred at v0; the E-04 crash origin RETIRED at `0.4.0`), and the
condition path is Julia's since `0.4.0` (§3.2: three stable `GoMeta absorb:` refusals of GoMeta's — the unknown condition key, the
no-expression guard of an empty block or a bare literal and the unterminated `(` inside a body — Julia's own errors
for the rest — the condition rows REMOVED). The
catalogue's inventory IS the tables of §3.1–§3.5
below (no aggregate count is maintained by hand);
the rows fall into three classes
(§3.1–§3.3); §3.4 additionally documents the latent crashes and the stable-message refusals that
are not catalogued codes.

### §3.1 — Non-condition codes (5): 0 armed config-time + 3 REMOVED at 0.4.0 + 1 RETIRED at 0.4.0 (E-04) + 1 GUARDED (E-06)

| Code | Status | Trigger |
|---|---|---|
| `ERR_UNKNOWN_PROFILE` (E-03) | **REMOVED at 0.4.0** (the §6 row) | was: `config.profile` outside the three profile names of the closed condition grammar — a fail-closed `PROCESS_ERROR` before any parse; the field, the three names and the grammar they selected were removed at 0.4.0 — no configuration field is refusable since (the registry door's refusals are the entry's, §3.5) |
| `ERR_RANGE_INVALID` (E-08) | **REMOVED at 0.4.0** | was: `config.parse_range` with `first ≠ 1`, or an empty range — a coded refusal the creator never specified; a range is taken plain since (§2: `first` never read, a non-positive `last` the whole file) |
| `ERR_UNKNOWN_FLAVOR` | **REMOVED at 0.4.0** | was: `config.flavor_tag` outside the three armed flavors `{:julia, :c, :latex}` — fail-closed before any parse; an unknown tag now throws `flavor_for`'s stable message (§3.4) |
| `ERR_VISIB_NO_FLAG` (E-04) | **RETIRED at 0.4.0** | its crash origin was the Visib write-back's flagless read of the winning action; the write-back is gone and the capture's own read is guarded — no apply-path crash origin remains catalogued |
| `ERR_DEPTH_OUT_OF_WINDOW` (E-06) | **GUARDED** — a stable refusal without a code; its coded conversion deferred | a `#~9`-style **digit** depth beyond the meta-hierarchy's depth window raises the stable-message `ErrorException` "meta depth out of range …" at the depth lookup (§3.4) |

No config-time row remains since `0.4.0`: the entry refusals are the registry door's (§3.5) — a `PROCESS_ERROR`
`GoMetaDelivery` carrying the code, with the development tool's `Main.BasicRenderer.outputs` yielding the empty `(tree, render)` pair (its non-OK contract). No apply-path crash origin remains: E-04's was removed
with the Visib write-back at `0.4.0` (its row above).
E-06 is **GUARDED**: for a digit depth outside the window the depth lookup refuses with the stable
message "meta depth out of range …" (§3.4); its coded conversion is likewise deferred
at v0.

### §3.2 — The condition path (since 0.4.0, by the creator's decision): Julia's parser, Julia's evaluation — the five condition codes REMOVED

A `{…}` condition body is READ BY JULIA'S PARSER AND EVALUATED BY JULIA, as the original engine did.
At absorb the body's GoMeta-specific parts are re-written to Julia text (`src/absorb/absorb_meta.jl`,
`_rewrite_condition`): a settribute key becomes its state read (`isCode` → `getState(:isCode)`); an action of an Alterant that
ANSWERS QUERIES becomes its query call (`getAltState(Int8(p), Symbol("action"), args…)` — the registry's one rule
`queryable_action`: the Alterant declares `getAltInstance`; Labels at v0); a label test `:name` is the
Labels Alterant's query of that name (every admitted name spelled the one way — `Symbol("name")` —, a pictograph with a
ZWJ included); GoMeta's `,` becomes `||`; everything else — `&&`, `!`, `()`, `|`, `&`, numbers, Julia operators, whitespace —
is copied verbatim. `Meta.parse` reads the result ONCE; the `Expr` is stored and evaluated by `Core.eval` in module `GoMeta` at
apply (`src/alterants/apply.jl`). So a Julia Boolean expression over
the GoMeta names is a condition (`{ 1 == 1 }` is one; `{ (isText && containsMeta), isMeta }` is the corpus's own), and a
13-atom condition applies where the closed interpreter's 29-step scan cap refused it.

**What refuses, and in which class.** THREE refusals are GoMeta's: the unknown condition key — a bare word that is neither a
settribute key nor a queryable action (`{ show }`, `{ cell(7) }`, `{ head }`; the keyword literals `true`, `false`, `nothing`
among them — the original engine's reading; a quoted text is NOT read word by word:
it is copied whole to Julia, so `{ isCode == "abc" }` is Julia's comparison, false
at `0.4.0` where every value a condition reads is a Bool), the stable `GoMeta absorb: unknown condition
key …` message at the absorb seam (§3.4); an empty block or a bare literal (`{}`, `{ 1 }`, `{ "abc" }`, `{ | }`) — "carries no condition
expression" (an unconditional action is written without `{}`); and a `(` left open inside the body — the one scanner's
"unterminated '('" refusal naming the innermost opener (a `"` or the block's `{` left open meets it at the block's extent). A worded label carrying a parenthesized list
(`:abc(:label1)`) reads as the label test of the word followed by a Julia call on its Bool, a `MethodError` at
apply — the original engine dropped the word and queried the list, the closed interpreter refused the shape (the creator may still revert to
either). A body Julia cannot parse (`{ isCode ! }`,
`{ :(:x)) }`) is Julia's own `Meta.ParseError` out of the `goMeta` call; an INCOMPLETE body (`{ isCode && }`) is thrown as
the same class at absorb — never stored for a later reader. A condition that fails at EVALUATION is Julia's own error at
apply: an argument Julia cannot dispatch (`{ :(7) }` — `getAltState`'s `Vararg{Symbol}`), an undefined name (`{ :(x) }`), a
non-Bool value where a Bool is needed (`TypeError`), a getter's own throw (raw). The condition grammar's walls — the
29-step scan cap, the 29-code-unit atom wall, the 4096-byte wall, the depth-32 wall — and its declared argument grammar
were removed with the interpreter at `0.4.0`: Julia's parser has none of them. Witnesses: `tests/unit/condition_tests.jl`.

| Code | Status |
|---|---|
| `ERR_UNKNOWN_CONDITION_KEY` (E-01) · `ERR_CONDITION_CAP` (E-02) · `ERR_CONDITION_ARG_DOMAIN` · `ERR_CONDITION_PARSE` · `ERR_CONDITION_UNQUERYABLE_ALT` (E-07, never minted) | **REMOVED at 0.4.0** (the §6 row) — the coded `Diagnostic` carriers of the closed interpreter's refusals; the unknown condition key stays a stable-message refusal (§3.4), the rest are Julia's own classes |

### §3.3 — Handled class (NOT an error): E-05 — meta-free input

A meta-free input is **not** an error: on the NO-FEED path `goMeta` returns `PROCESS_OK` with zero
alterant work, and the development tool's render of such a result passes the PARSED content through unchanged —
byte-exact up to the documented line-ending normalization (CRLF → LF, §4; `docs/CANONICAL-OUTPUT.md` §6) and the
selected `parse_range` (a given range is taken plain, `last` the parse end line — §2) (a head-bearing fed profile refuses at
the read since `0.4.0` — §2 and the one message of §3.4; a refusal-carrying feed aborts regardless
of document meta-freeness). It carries
no code — it is a normal success path.
(An input whose only meta is inline is NOT this class: inline `#~` actions on content lines DO
apply — `docs/SYNTAX-AND-SEMANTICS.md` §9.)

### §3.4 — Known latent crashes + stable-message refusals (NOT catalogued codes)

These are the honest edges of the v0 engine. Entries marked GUARDED are refusals with a stable
message (no longer raw crashes); the rest remain latent, documented as such — **not** assigned a
fabricated code:

- **The per-slot action overflow — GUARDED (this refusal since `0.4.0`, by the creator's
  decision):** the queue tensor holds 8 actions per meta-hierarchy slot — `SLOT_CAPACITY` (`src/state.jl`), a named
  constant DECOUPLED from the registered action count since `0.4.0` (it may easily be increased by hand, hard coded, if experience
  shows that 8 is too small or when an example
  asks; the count is 9 with `ids`) — a fixed size, raised by hand when an example needs it (the slower overflow buffer is a later design); a
  further action in one slot meets `GoMeta absorb: more than 8 actions in one meta-hierarchy slot …` BEFORE the write.
  Witnesses: `tests/unit/slot_overflow_tests.jl` (the boundary and the ninth).
- **Malformed metaLines — THE GRAMMAR'S ONE REFUSAL since `0.4.0` (by the creator's decision: the original engine's
  reader with its grammar made explicit):** a metaStatement is a name, a `:` label or (the
  region's first statement only) a `"…"` heading, then at most one `()`, then at most one `{}`, and ENDS at white space or at the
  region's end; any other character meets `GoMeta absorb: unexpected character '<c>' <where> in the meta region "…" (the token "…")`
  — `where` is "at the start of a metaStatement" (`#~ ,`, `#~ ( hide`, a space before `(` or `{`: `hide (isCode)`, with the hint
  that `()` and `{}` are written glued to the name), "after ':'" (`:"ab"`, `:{isCode}`), or "after the metaStatement "…"" (a token
  glued to a closing bracket — `hide()junk`, `hide{isCode}show`; a second `(` or `{`; a `(` after `{}`; a `,` after a one-word
  label — `:label1,label2`, with the hint that several labels are written `:(label1, label2)`). The six structural characters
  `( ) { } , "` end a name or a one-word label; every other non-white-space character is a name or label character —
  pictographs and emojis among them; a leading punctuation is part of the name and meets the unknown-action refusal
  (`#~ -hide` → `unknown alterant action "-hide"` — the prefix sugar a later design). An empty argument piece
  (`cell(7,)`) is handed on as the empty token for the Alterant to judge; an argument's arity or type fault is the
  Alterant's own setter error. The original engine read these shapes without the grammar's refusal (a leading
  punctuation skipped, a glued token dropped, an empty region Julia's `BoundsError`). VALID input is unaffected — the creator's two example
  files and the twelve frozen forms read byte-equal. Witnesses: `tests/unit/parser_quality_tests.jl` (the battery: every
  inventory shape with its expected outcome), `tests/unit/malformed_meta_tests.jl` (the valid twins; the glued form).
- **The quoted-string path — GUARDED (stable messages; the span refusals re-worded at
  `0.4.0`):** a `"` never closed meets `unterminated '"' — never closed …` (the ONE
  scanner names the innermost opener left open — the quote before an enclosing `(`); an argument list carrying a `"` meets "malformed
  quoted argument" (a quote glued to bare text, a stray quote, or more than one span in
  one token), or "string argument not accepted" (a WELL-FORMED quoted argument anywhere
  except the slot the action's DECLARED record names — `head`'s TEXT slot; every other
  slot of every shipped action, including `head`'s level slot, refuses a String). The Heading
  adds two siblings: "empty heading text" (an
  empty `""` heading is refused by the v0 semantics — condition-independent, the declared validation runs at the read for
  every action with a String slot; relaxing it later would be a compatible widening), and "a heading (Heading Alterant) in the
  profile feed has no Component of the file levels to be local to" (every heading form in a fed profile — the creator's decision and
  wording, since `0.4.0`; the former three messages "heading without a document
  context", "alterant-state query in a heading condition" and "a conditioned heading in a profile feed" were REMOVED with the Heading's
  separate delivery). The backslash is RESERVED inside GoMeta's own
  quoted texts — the heading sugar, a quoted argument, a label list: "backslash in a quoted span — reserved for the future escape
  grammar" (the creator's decision at v0.2, given for these two producers) — so a future escape grammar can land as a purely additive
  widening without reinterpreting any shipped document; inside a CONDITION a quoted text is Julia's (the creator's design) and there the
  backslash escapes the next character as Julia reads it — by the creator's decision, since `0.4.0`:
  the quoted text is copied whole to Julia, never read by the rewrite. Witnesses: `tests/unit/heading_recognizer_tests.jl`,
  `tests/unit/parser_quality_tests.jl` (the quote-scan rows).
- **The out-of-window meta depth — GUARDED:** the refusal is witnessed on the **DIGIT** depth
  form — a digit depth marker outside the v0 window (`#~9`, `#~99` — v0 supports `#~` through
  `#~8`, and digit `0` addresses the file level, accepted) raises
  the stable-message `ErrorException` ("meta depth out of range …") at the depth lookup —
  never a raw conversion crash. In-window depths work unchanged. Note: `#~10` parses its
  first digit only and behaves as depth 1.
- **Empty, literal and malformed condition bodies (since `0.4.0`):** an EMPTY condition block (`{}` or `{ }`) or a bare
  literal (`{ 1 }`, `{ | }`) raises the stable-message `ErrorException` "… carries no condition expression …"
  — an unconditional action is written without `{}`; a body Julia cannot parse (`{isCode !}`, an unbalanced `)`) or
  cannot complete (`{isCode &&}`) is Julia's own `Meta.ParseError` out of the `goMeta` call (the former coded
  "unparsable condition" refusal was REMOVED with the interpreter at `0.4.0`). Since `0.4.0` the
  block's EXTENT is found quote-aware — a `}` inside a quoted text closes nothing (`hide{ isCode == "}" }` is read as Julia reads
  it), a condition's quoted text is Julia's and its `\` Julia's escape; by the creator's decision, the
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
  context, wider than metaLine/meta-block adjacency alone). Pre-`0.2.3` both grains
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
- **The over-cap condition — the walls REMOVED at `0.4.0`:** the closed
  interpreter's 29-step scan cap (the coded `ERR_CONDITION_CAP` refusal "condition too complex"), its 29-code-unit atom
  wall, its 4096-byte wall and its depth-32 wall were REMOVED with the interpreter — Julia's parser reads the whole body, so a
  13-atom condition applies where it refused and a 40-character label name is a label test like any other. Witnesses:
  `tests/unit/condition_tests.jl` (the inversion).
- **The unknown-alterant refusal:** an out-of-registry alterant name throws a stable, stage-honest,
  bounded `ErrorException` ("GoMeta absorb: unknown alterant action …"). Its coded-`Diagnostic`
  conversion is deferred (the E-01 family).
- **The unknown-label refusal:** a name APPLIED as a label (`#~ :labelX`, including the conditional form
  `:labelX{ … }`) from outside the Labels Alterant's vocabulary — since `0.4.1` the RUN's: the shipped list, the base — `:label1`..`:label5` plus, since `0.3.0`, the fixed pictograph
  vocabulary, plus `:doc` since `0.4.0` (the hard-coded list in the Labels Alterant's own file
  `src/alterants-std/labels.jl`, 39 names) — plus the names the run's vocabulary statements ADDED, minus the names they REMOVED (§2, THE VOCABULARY STATEMENTS: a declared name applies, a removed shipped name refuses) — raises the stable `ErrorException`
  `"GoMeta apply: unknown label …"`, which names the accepted set SORTED — the run's (the §2 argument-forms contract). A label
  QUERIED in a condition (`{ :labelX }`) is never refused for being unknown: the query answers false, as the original engine's
  checker did (since `0.4.0` — the membership refusal in the query role and the write-only
  valve were removed). Witnesses: `tests/unit/error_message_tests.jl` (both roles); `tests/unit/labels_vocabulary_tests.jl` [V-W4] (the accepted set the run's).
- **The vocabulary-statement refusals (since `0.4.1`; the contract: §2, THE VOCABULARY STATEMENTS):** a vocabulary statement of the Labels Alterant — `:++x` / `:(++, x, y)` / `:--x` / `:(--, x)` — is read by the Alterant's read-time hook (§1.2) before the slot bound and, where it is misplaced or malformed, refused THERE with a stable `ErrorException` whose message begins "GoMeta absorb: " and ends "; see docs/public-api.md §3.4" — the run stops at the statement; nothing is delivered for a declaration. THE PLACE is checked first: anywhere but a metaBlock opened by `#~0` or the user's profile, "GoMeta absorb: a vocabulary statement (…) is legal at `#~0` and in the user level's profile only — here …" (the forms named with the statement's sign; the tail names the offending place — a metaBlock of depth N, an inline metaSegment); a misplaced AND malformed statement meets this one. Then the five malformed shapes, each with its own message: the prefixed sign with several arguments ("… the prefixed vocabulary statement … takes one name — N arguments given (the list form is …)"), a statement naming no label ("… the vocabulary statement … names no label — the forms are …"), a list with an EMPTY member, a stray comma ("… names an empty label (a stray comma) — the forms are …"), a declared name beginning with `+` or `-` ("… a label name in a vocabulary statement may not begin with `+` or `-` — got …"), a condition on the statement ("… a vocabulary statement takes no condition — … (a declaration is a fact of the run, not of a Component)"). A name later APPLIED from outside the run's vocabulary meets the unknown-label refusal above. Witnesses: `tests/unit/labels_vocabulary_tests.jl` [V-W3], [V-W7], [V-W15], [V-W16].
- **The unknown flavor_tag — a stable-message throw (since `0.4.0`):**
  a `config.flavor_tag` outside the closed inventory `(:julia, :c, :latex)` raises the stable `ErrorException`
  `"flavor_for: unknown flavor_tag …"` at `goMeta`'s flavor resolve, before any parse — no fallback, no
  file-extension or content sniffing; the coded `ERR_UNKNOWN_FLAVOR` config-time refusal was removed at `0.4.0` with
  the range refusal (§3.1). Witnesses: `tests/unit/flavor_profile_tests.jl`, `tests/unit/latex_flavor_tests.jl`.
- **The capture-floor warnings `WARN_CAPTURE_FLOOR` / `WARN_CAPTURE_UNREADABLE` (codes of the 0.4 development, in no released version) — REMOVED at 0.4.0 with the
  Heading's separate delivery**: the one
  capture walk reads every Alterant's store bare and emits neither (a store outside its declared scheme's shape is Julia's own
  error; a record without a row mints nothing); a run's `diagnostics` vector is empty on the PROCESS_OK path (the §6 row).
  Witnesses: `tests/unit/capture_tests.jl` [11].
- **The store-`[2]` insertion path** — a latent insertion path not exercised by any v0 input.
- **The absorb-plane grammar refusals (the same stable-message family):** beyond the entries
  above, the metaLine/condition grammar refuses with stable `GoMeta absorb:` messages on: an
  unterminated `(`, `{` or `"` on the metaLine ("unterminated '<o>' — never closed … (n still open)" — the one scanner names the
  innermost opener left open; since `0.4.0`) and, likewise since `0.4.0`, a `(` left open inside a condition body
  (the same scanner, the same message) · an unknown condition key (a bare name inside `{}` that is neither a component
  state-ref nor a QUERYABLE action name — an action of a getter-less Alterant, Visib's `show`/`hide`/`discard` among them
  with Id's and the Heading's, is no condition key since `0.4.0`, by the registry's one rule;
  the vocabulary's one refusal since `0.4.0` — the seam's others are the next item and the open `(` above) · an empty or literal condition block (the entry above) · a
  second argument list or condition block, a bracket after `{}`, a glued token or a stray structural character (the grammar's one
  refusal `unexpected character …`, the entry above; the former "duplicate argument list" / "duplicate condition block" /
  "misplaced one-word label" texts were removed at `0.4.0`); the malformed- and
  unterminated-key refusals and the over-cap refusal were removed with the closed interpreter at `0.4.0` (a malformed body is Julia's
  own `Meta.ParseError`); the punctuation and glued-token walls were removed at `0.4.0` and the grammar's one refusal took their place (the entry above).
  The basic renderer (a development tool, `devtools/basic_renderer.jl`) carries no Visib guard of its own since `0.4.0`:
  it renders the Engine's answer per Component; more than one Visib value on one cell is refused by the Engine at the
  CAPTURE (`src/annotations.jl` — the stable message `GoMeta capture: more than one Visib value set for one component …`).
  Each refusal is stable and points at this section; most name the offending token, region, or
  bracket count.
- **The action-args walls — REMOVED at 0.4.0** (by the creator's decision —
  the framework before hardening; the original engine called the setter directly): malformed alterant-action ARGUMENTS —
  non-parsable or overflowing Id values and wrong-arity forms, including arguments on Visib actions — meet
  Julia's own dispatch error or the setter's own `parse` error out of the `goMeta` call; the stable
  `"GoMeta apply: invalid arguments …"` refusal and the apply-plane `_invoke_set` seam were removed at `0.4.0`.
  Working forms are unaffected (the §2 argument-forms contract). Condition-side atoms of a getter-less Alterant
  (`{ cell(7) }`, `{ cell }`, `{ parent }`, `{ file }`) meet the usual unknown-condition-key refusal at absorb, with or
  without arguments (the registry's rule since `0.4.0`; the E-07 pending mint retired at `0.4.0`); a QUERYABLE
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
`Meta.ParseError`, as a malformed action argument is Julia's own error, both since `0.4.0` (stage-honest prefix
`GoMeta parse:` / `GoMeta absorb:` / `GoMeta apply:` — the development tool's render plane carries no message of its
own since `0.4.0`, the renderer consuming the Engine's answer; the offending token
bounded, what v0 accepts, this section as the pointer); four catalogued messages are
parse-plane — the bang-first meta-marker refusal (`0.3.1`), the multi-inline-meta refusal and the two directive-adjacency refusals
(segment grain and line grain, `0.2.3`) above. The not-input-reachable internal checks say
"GoMeta internal invariant violated … please report". The vendored parse layer's OTHER messages
keep their existing forms; they are not part of the coded catalogue above.

A later put for the SAME occurrence handle and attribute supersedes the recorded row (later wins; applied-state-wins) —
the non-fatal `WARN_VERDICT_COLLISION` diagnostic that accompanied a value-changing supersede was removed at `0.4.0`
(§6); two distinct cells never share a slot, byte-identical content included, for well-formed
occurrence keys (`_putEval!`, `src/annotations.jl`).

- **The SEAM-ENVELOPE family — GUARDED (since `0.4.0`; catalogue-NAMED stable-message refusals,
  their coded-`Diagnostic` conversion deferred):** each fires as an
  `ErrorException` whose message carries the catalogue name as a literal token; the engine's
  own `"GoMeta "`-prefixed refusals and `InterruptException` always pass through the
  envelopes verbatim; the containment guarantee is scoped to exceptions delivered to the
  handler (`StackOverflowError` catchability is shape-dependent; resource exhaustion may not
  allocate a refusal).
  - `CB_QUERY_THROW` — **REMOVED at 0.4.0**: the closed interpreter's query
    envelope was removed with the interpreter — the getter is called bare through `getAltState`,
    as the original engine called it: a getter's throw propagates raw out of the `goMeta` call, in its own class.
  - `RES_RETURN_TYPE` — a declared-return-type breach: the handover validator returned non-`Bool` (the query getter's
    non-`Bool` return is Julia's own `TypeError` at the condition since `0.4.0`; the setter's live return
    guard was removed with the set-invocation seam at `0.4.0`).
  - `REG_VALIDATE_FALSE` — the declared handover validation returned `false` for the presented
    String-slot text; first-offender-wins at the absorb site (the catalogue's refuse-at-gate
    shape is unreachable at this callable's only call site — full collection is deferred).
  - `CB_VALIDATE_THROW` — the handover validator threw a foreign class.
  - `CB_SET_THROW`, `CB_CTOR_THROW`, `RES_FOREIGN_STORE` — **REMOVED at 0.4.0**:
    the set seam's malformed-argument crash conversion, the three-site constructor-mint
    envelope and the per-invocation store-identity check were removed with the set-invocation seam `_invoke_set`;
    the setters and constructors are called bare, as the original engine called them (by the creator's decision).

### §3.5 — Registration + door codes (v0.4; coded `Diagnostic`s)

Every row below is a `Diagnostic{code, severity, message, context}`. FOUR delivery channels (a
trigger/site matrix — one CODE appears on two channels: `REG_PROTOCOL` is an immediate `register!` throw
for the plugin-index binding AND a validation row for the domain probe (the mode-gate laws were removed at 0.4.0 with the Heading's
separate delivery);
`REG_SLOT_EXHAUSTED` is a `register!`/`next_plugin_index` throw alone since 0.4.0): **(i) `register!`-time THROWS** — immediate and atomic (nothing appended), a thrown
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
| `REG_PROTOCOL` | error | a STRUCTURAL defect of the record: a record passed to `register!` that names another plugin; a declared value outside the CLOSED encodable domain — a cyclic container, a `Function` inside a data value, a non-`Vector`/`Dict` container (range, view, user container), any type without an encoder, a `Type` whose parameter tree exceeds the type-encoder budget, or any domain-walk membership failure over the FULL field lists — one row per record SLOT, naming it. The tier-1 enum, kinds, queryable, uniqueness, plugin-index, settribute-key, MutEx, capture-identity and stem rows were removed at 0.4.0, and so were the capture mode-gate laws (the gate's closed set, the setMode⟺gate coherence, the :localOnly scheme and store laws), with the Heading's separate delivery (§6) | the action or alterant name |
| `REG_UNKNOWN_SETMODE` · `REG_DUPLICATE_ALTNAME` · `REG_DUPLICATE_ACTION` · `REG_RESERVED_SHADOW` · `REG_SIG_MISMATCH` · `REG_VALUE_ALGEBRA` · `REG_UNREACHABLE` · `REG_CANDIDACY` · `REG_MUTEX_CONFLICT` · `REG_UNINTERPRETED_REQUIRES` · `REG_CONTRACT_VERSION` | **REMOVED at 0.4.0** | the validation chain — the coded inventory refusals, the clash law with its disposition switch, the reflection cross-check, the value-algebra and reachability refusals, the candidacy warning — was removed; the original engine registered unchecked; a duplicate action name resolves FIRST-wins in the derived tables; the §6 register row | — |
| `REG_SLOT_EXHAUSTED` | error | more than 127 alterants or actions (the Int8 index space) — at `register!`'s 128th append (the validate-time row for a directly-pushed builder was removed at 0.4.0: such a builder fails at `publish` with Julia's `InexactError`, the honest bound of bypassing `register!`) | the alterant |
| `REG_DERIVED_TABLES` | error | positional (route-U) construction whose hand-built tables differ from the tables derived from the declarations | `nothing` |
| `REG_UNPUBLISHED` (door) | error | an unsealed registry reached `goMeta` — the message names `RegistryBuilder → validate → publish` | `nothing` |
| `POST_SEAL_MUTATION` (door) | error | a published registry whose live fields no longer match the publish-time snapshot — the message carries "at <path>", the first divergent path; re-publication is the change path | the rendered path |
| `DEP_MISSING` | **REMOVED at 0.4.0** | the eager dependency closure at publication was removed; an `altConstructor` without a method for the call the apply makes — the zero-argument call, or since 0.4.1 the one-argument call with the run state where the Alterant's read-time hook minted one (§1.2) — publishes and is Julia's own error at first apply out of the `goMeta` call (a `MethodError` for the missing zero-argument method) (the mint wrap `CB_CTOR_THROW` that named it was removed at 0.4.0; §3.4); the §6 register row | — |
| `STATE_REUSE_REFUSED` (driver seam) | **REMOVED at 0.4.0** | the seam ledger was removed with the callable driver seam: `goMeta` builds its parse state itself, one per call — nothing is injected, nothing can be in flight twice; the §6 register row | — |
| `STATE_SEAL_MISMATCH` (driver seam) | **REMOVED at 0.4.0** | it guarded the Visib write-backs a run left in the caller's state; nothing is written back any more — the §6 register row | — |
| `SRC_DIGEST_MISMATCH` | **REMOVED at 0.4.0** | the vocabulary artifact's digest pin was removed with the record's vocabulary slot — the 38 names are hard-coded, with `:doc`, in the Labels Alterant's own file `src/alterants-std/labels.jl` since 0.4.0; the §6 register rows | — |

The stable-message refusal `"GoMeta absorb: meta-hierarchy slot pool exhausted"`, added within the 0.4 development (in no released version), was REMOVED at 0.4.0
(§6): an exhausted per-call slot pool (`NUM_MH_LEVELS` = 12 slots) is Julia's own `MethodError`
at the Int8 store, as in 0.3.2; the walk allocates at most one slot per live level, so no input reaches it.

## §4 — CRLF normalization (documented, not an error)

The parser's one setup path chomps `\r\n` — line **endings** normalize to LF; CONTENT-line **content** bytes
stay faithful for arbitrary bytes, including invalid UTF-8 (documented engine behavior for BOTH
invalid-byte classes — lone invalid bytes and decode-requiring sequences such as overlong
encodings). The shipped suite pins both planes: an overlong sequence inside a hidden content
line is carried byte-faithfully (`tests/unit/ensure_token_tests.jl`, row [8]); on the meta-line
plane an invalid byte inside a quoted argument in a slot that takes no text meets the
string-argument refusal (`tests/unit/heading_recognizer_tests.jl`, the QUOTE × INVALID UTF-8 row)
and, at the condition rewrite's two identifier tests inside a condition body (guarded since
0.4.0), Julia's own `Meta.ParseError` or the
unknown-key refusal (`tests/unit/parser_quality_tests.jl`, the rows jG1–jG3). The
**meta-line plane indexes on character boundaries**: non-ASCII inside a metaLine parses
correctly, and — the ACTION set being ASCII-named at v0, while the Labels Alterant's vocabulary carries a
fixed pictograph vocabulary since 0.3.0 (hard-coded in the Labels Alterant's own file `src/alterants-std/labels.jl`
since 0.4.0) — a
non-ASCII label APPLIED from outside the run's vocabulary (the shipped list with the run's vocabulary statements folded in, §2) or a non-ASCII action meets the stable
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

**No backward compatibility and no deprecation until at least GoMeta v0.7** — the creator's
policy.
Every change of the
public surface is a CLEAN CUT — the old name removed; no stub, no alias, no leftover of an older
version in a newer one — and the breaking-change register below is the non-silent record of every
removal or rename (its ground, its replacement, what an older caller sees). No alias stands: the public
`PlugIn` = `Alterant` alias was REMOVED at 0.4.0 as a clean cut (its row below).
The policy will change at a
later stage — maybe v0.8, maybe later — by the creator's decision; nothing is promised now. `Project.toml`
carries the version.

**The breaking-change register (every removal, rename or ADDITION of a public name of EITHER tier is written here — the
non-silent record under the policy above; no deprecation for a name of either tier until at least v0.7).** A row's REMOVED or
ADDED (or CHANGED, RENAMED, RE-ORDERED) at 0.4.0 — and every such mark elsewhere in this document — also covers what was added and changed or removed again within the 0.4 development, before the tag: such a thing was
in no released version.

- **`GoMeta.outputs` — §1.2 public-not-exported since 0.3.0 — REMOVED at 0.4.0** (no deprecation stub, by the
  creator's decision); ground: the renderer and the tree print are development tools;
  replacement: the tool's `outputs` after `include(joinpath(pkgdir(GoMeta), "devtools", "load_basic_renderer.jl"))` at the
  caller's top level; a 0.3.0 caller sees `UndefVarError`; the same-commit triple (code + the document's
  §1.2/§1.3/§2/§3.4/§6 + the surface oracle);
  `docs/CANONICAL-OUTPUT.md` re-scoped (the package's canonical observable output = `altValues_evals` (+
  `serialize_evals`, `content_fingerprint` — itself REMOVED at 0.4.0, its row below); the pair = the tool's output pinned by the golden layer); the Engine's
  delivered surface after the move = the run and the evaluated values.
  The row's practice — the same-commit triple:
  code + this document + the surface oracle
  `tests/unit/public_surface_tests.jl` in one commit;
  no alias — a hard removal,
  no stub.
- **`altValues_evals` (function) — EXPORTED since 0.3.0 — RENAMED `readAltValuesEvals` at 0.4.0** (no deprecation stub, as
  for `GoMeta.outputs` above); ground: by the creator's decision, the name `altValues_evals` belongs to the DATA CONTAINER (the part of
  the delivered object), never to a function; replacement: the reader `readAltValuesEvals` — the same rows, the
  same order, the same type (its argument is the delivered PART:
  `readAltValuesEvals(result.altValues_evals)`); a 0.3.x caller of
  `altValues_evals(result)` sees `UndefVarError` (since 0.4.0 the name `altValues_evals` is the part of
  `GoMetaDelivery`, read by name — a field, never a function); the same-commit triple (the export line `src/GoMeta.jl`, this
  document's §1.1/§1.2/§1.3/§2,
  the surface oracle `tests/unit/public_surface_tests.jl`).
- **`GoMetaResult` (type) — EXPORTED since 0.3.0 — RENAMED `GoMetaDelivery` and RE-SHAPED at 0.4.0** (no deprecation
  stub, as for `GoMeta.outputs` above); ground: the creator's decisions on the content (`altValues_evals`, the BLS Component
  tree, the status, the diagnostics, nothing else), on the shape (one named object, the four
  parts public by name, no hand-over function) and on the name ("result" not descriptive);
  replacement: `GoMetaDelivery` with the public parts `altValues_evals::EvalStore` (the field `verdicts` of 0.3.x,
  given the container's name), `blsComponentTree::BLS.ParseState` (the field `state.parse` of 0.3.x, now a
  part), `status`, `diagnostics`; REMOVED: the field `state::ProcessState` (INTERNAL / semver-UNSTABLE "at v0" by its
  own declaration in the 0.3.x docstring and this document's §2 — the working state is never delivered again) and the
  field name `verdicts`; a 0.3.x caller of `GoMetaResult` sees `UndefVarError`, a reader of `.state` or `.verdicts` a
  field error; the same-commit triple (the export line `src/GoMeta.jl`, this document's §1.1/§1.2/§2, the surface
  oracle `tests/unit/public_surface_tests.jl`);
  one `Base.show` method.
- **`GoMeta.BLS` (module) — ADDED to the package-public tier at 0.4.0** (`public BLS` at the Engine's tier with the door of
  travel / access functions); ground: the creator's design — Extensions must go through the public surface (the BLS tree
  structure and some functions provided to travel / access the required data), and the BLS Component tree is provided by
  BLS itself; the same-commit triple (`src/GoMeta.jl`
  `public BLS`, this document's §1.2, the surface oracle `tests/unit/public_surface_tests.jl` — the BLS tier's own testset);
  nothing removed; the door's set the creator's choice.
- **`GoMeta.BLS.children` — ADDED (public, not exported) at 0.4.0 with the door** — ADAPTED — the original engine's child walk as carried by `eachchildid` over `parentChildComponentPDict`, the store read folded in; Components returned, the insert store's negative ids resolved; one register row.
- **`GoMeta.BLS.parent` — ADDED (public, not exported) at 0.4.0 with the door** — ADAPTED — the original engine's `getParentComponent` under the door's name; `nothing` for the File; `Base.parent` untouched (read qualified); one register row.
- **`GoMeta.BLS.kind` — ADDED (public, not exported) at 0.4.0 with the door** — NEW — the `contentType` field read given a name: `:Meta` / `:Code` / `:Text`, `nothing` for the File (its field is the store's constructor default); no type of BLS made public for it; one register row.
- **`GoMeta.BLS.content` — ADDED (public, not exported) at 0.4.0 with the door** — NEW in BLS — the body of the Engine's `cell_content_bytes` copied unchanged (the Engine's copy removed at 0.4.0); the test layer's five-column form takes its fifth column, a piece's text, through it (the register's row on `GoMeta.serialize_evals(::GoMetaDelivery)`); one register row.
- **`GoMeta.BLS.root` — ADDED (public, not exported) at 0.4.0 with the door** — NEW — the store read `componentsPDict[File][1][1]` given a name; one register row.
- **`GoMeta.BLS.flavor` — ADDED (public, not exported) at 0.4.0 with the door** — NEW — the field read `tree.flavor` given a name (the flavor record; its type internal); THE PROMISE: five fields — `lead`, `hide_marker`, `hide_fold_prefix`, `flavor_tag`, `re_meta_leaded`; the rest of the record (`directives` first; the `parse_header!` pointer REMOVED at 0.4.0) reachable, not promised; one register row.
- **`GoMeta.BLS.isHorizontalSpace` — ADDED (public, not exported) at 0.4.0 with the door** — ADAPTED — the parser's horizontal-whitespace predicate (`_is_h_ws`, flavor.jl) given a public name, so that the print tools' lexer classifies whitespace as the parser does; one register row.
- **`GoMeta.BLS.endsWithNewline` — ADDED (public, not exported) at 0.4.0 with the door** — NEW — the field read `tree.endsWithNewline` given a name; one register row.
- **`GoMeta.BLS.getElement` — ADDED (public, not exported) at 0.4.0 with the door** — ADAPTED — the original engine's named-element read (settribute flags; the named-int keys — four positions, two store indices, a count, two extension-chain links) declared public as it is, plus ONE Component-taking method `getElement(c, key)` dispatching over the two containers (a caller reads no field) — every settribute key and named-int key thereby readable; the Visib flags `:show` / `:hide` / `:discard` lost their meaning and were REMOVED from the key set at 0.4.0 — a read of one is an error; one register row.
- **`GoMeta.BLS.File` — ADDED (public, not exported) at 0.4.0 with the door** — ADAPTED — the original engine's Component type alias declared public as it is; one register row.
- **`GoMeta.BLS.Block` — ADDED (public, not exported) at 0.4.0 with the door** — ADAPTED — the original engine's Component type alias declared public as it is; one register row.
- **`GoMeta.BLS.Line` — ADDED (public, not exported) at 0.4.0 with the door** — ADAPTED — the original engine's Component type alias declared public as it is; one register row.
- **`GoMeta.BLS.Segment` — ADDED (public, not exported) at 0.4.0 with the door** — ADAPTED — the original engine's Component type alias declared public as it is; one register row.
- **`GoMeta.BLS.ComponentSettribute` — ADDED (public, not exported) at 0.4.0 with the door** — ADAPTED — the original engine's named-element type declared public as it is (`keys(ComponentSettribute)` — the print tools); one register row.
- **`GoMeta.BLS.CmpntNamedInt` — ADDED (public, not exported) at 0.4.0 with the door** — ADAPTED — the original engine's named-element type declared public as it is (`keys(CmpntNamedInt)` — the print tools); one register row.
- **`EvalRecord.decided_by` (field) — ADDED to the public record type at 0.4.0** (ONE provenance field on the public record type `EvalRecord`, one register row; the provenance RECORDED where it is known — an origin per queued action at the enqueue, carried through the apply and captured with the record — so that own or indirect is MEASURED, never inferred from a row's presence); the field `decided_by::Vector{Vector{UInt8}}` — the `key_bytes` handles of the statements that produced the row, in application order (the stating Component's handle: the metaBlock a whole-line metaLine forms, the Segment of an inline one; the minted user-context handle on the userMH feed); the delivered ROWS of `readAltValuesEvals` unchanged (the four-tuple, the sort, the count); nothing removed; a 0.3.x caller constructing `EvalRecord` positionally with five arguments sees a `MethodError` (no constructor is public; none exists outside `src/`); the same-commit triple (the type `src/result.jl`, this document's §1.2, the witness `tests/unit/origin_tests.jl` — the surface oracle pins names, not fields); the name the authored set's word (`decided_by` in the scenarios the creator confirmed, `tests/authored/`).
- **`GoMetaDelivery` (type) — RE-ORDERED at 0.4.0: the field order `blsComponentTree`, `altValues_evals`, `status`, `diagnostics`** (the creator's decision: the order of the pipeline, the BLS Component tree first); ground: the parts are read BY NAME — a reader by name sees no change; what changes: the struct's field order (`fieldnames`), the positional constructor's argument order (the two constructor sites in `src/GoMeta.jl`; none outside `src/`) and the one `Base.show` line (now in the field order); nothing removed; the same-commit triple (the type `src/state.jl`, this document's §1.1 table and §2, the surface oracle unchanged — it pins names; the `fieldnames` pin (`tests/unit/public_surface_tests.jl`) added on the creator's separate decision).
- **`Alterant.default` (keyword and field) — ADDED to the Alterant registration record at 0.4.0** (each Alterant declares ONE default value, as data in the Alterant registry — the Alterant's, not an action's; Visib's default is `:show`; the meta level formerly 'default' renamed `fallBack` and consulted LAST by the apply; the Alterant's default delivered by the answer function with the source `:default`); ground: the creator's design; the slot `NoDefault()` | `Declared(value)` on the record's keyword form (`Alterant(; …, default = …)`; the alias `PlugIn` REMOVED at 0.4.0, its row below; the 6-positional 0.3.x form REMOVED at 0.4.0); the registration digest (REMOVED at 0.4.0, its row below) moved (the fold carried the Alterant's slot — the pin re-measured); the per-action `default` slot of `ActionSpec` REMOVED at 0.4.0 — a clean cut, its own register row (the next row); the internal level constant `defaultMHIdx` renamed `fallBackMHIdx` (not public); the same-commit triple (the record `src/state.jl`, this document's record vocabulary, the witnesses `tests/unit/record_schema_tests.jl`).
- **`ActionSpec.default` (keyword and field) — REMOVED at 0.4.0** (the per-action `NoDefault()` slots of the registry give way to one per-Alterant slot; a clean cut — no stub); ground: the default is the Alterant's, not an action's (the row above); replacement: `Alterant(; …, default = …)` (the alias `PlugIn` REMOVED at 0.4.0, the register's `PlugIn` row); an action record constructed with `default = …` sees a `MethodError` (no such keyword; the 8-positional 0.3.x form REMOVED at 0.4.0, its row below), a reader of `spec.default` a field error; the registration digest (REMOVED at 0.4.0, its row below) moved (the per-action part left the fold — the pin re-measured); the same-commit triple (the record `src/state.jl`, this document's record vocabulary, the witnesses re-homed — `record_schema_tests.jl`, `registry_lifecycle_tests.jl`, `vocabulary_tests.jl`, `snapshot_property_tests.jl`).
- **`GoMeta.evaluatedAltValue` (function) + `GoMeta.EvaluatedAltValue` (type) — ADDED (package-public, not exported) at 0.4.0** (the Engine answers, on demand, ONE resolved value per Component per Alterant with a source of own / indirect through a named Component / default, the answer shape UNIFORM across Alterants; a Segment's answer its own rows if any, else its Line's marked indirect; the levels' room — `:user`, `:file`, `:fallBack` reserved; the Alterant's declared default with the source `:default`): `evaluatedAltValue(delivery, component, alterant; registry = DEFAULT_REGISTRY) -> EvaluatedAltValue(value, source, via)` — derived at the call from the delivered rows and `decided_by`, never stored; the delivered ROWS unchanged; nothing removed; the same-commit triple (the code `src/answer.jl` and the `public` declaration in `src/GoMeta.jl`, this document's §1.2 + §2, the witnesses `tests/unit/answer_tests.jl` with `public_surface_tests.jl`); NOT FINAL — the name DECIDED by the creator (the RENAMED row below); the per-call row scan stands at 0.4.0 — an index behind the answer function DEFERRED to a later benchmark phase (§2); the tier, the File's case (`:none`) and the equal-child rows still open; no compatibility promise until at least v0.7 (§6).
- **`GoMeta.scanAlterant` + `GoMeta.evaluatedAltValues` (functions) — ADDED (package-public, not exported) at 0.4.0** (the creator's design: the scan for the Components that got values of an Alterant, its information unambiguous and informative): the scan by Alterant and the access by Component, thin reads over `evaluatedAltValue` — functions of their own (the alternative: methods of the reader); the delivered ROWS unchanged; nothing removed; the same-commit triple (the code `src/scan.jl` with the `public` declaration, this document's §1.2 + §2, the witnesses `tests/unit/scan_tests.jl` with `public_surface_tests.jl`); NOT FINAL — the names DECIDED by the creator (the RENAMED row below); the form (functions of their own) stands; no compatibility promise until at least v0.7 (§6).
- **`GoMeta.childDiffers` (function) — ADDED (package-public, not exported) at 0.4.0** (the creator's child-differs signal, COMPUTED from the answer of `evaluatedAltValue`, its stored form deferred to a later benchmark phase): `true` when a Component's resolved answer's VALUE differs from its parent's — computed from `evaluatedAltValue` at the call, never stored; the per-child primitive from which the creator's per-parent Boolean is computed (`any` over the parent's children; the aggregate's form a later benchmark phase's); the delivered ROWS unchanged; nothing removed; the same-commit triple (the code `src/childdiff.jl` and the `public` declaration in `src/GoMeta.jl`, this document's §1.2 + §2, the witnesses `tests/unit/childdiff_tests.jl` with `public_surface_tests.jl`); NOT FINAL — the name kept by the creator's decision (the RENAMED row below); the Block-against-File reading still open; no compatibility promise until at least v0.7 (§6).
- **`serialize_evals(ann)` — the four-column public form's `attr` column ENCODED at 0.4.0** (a tab or newline in an attribute stem would break the one-row-per-line format; the encoding applied to the four-column form alone, the five-column form being the test layer's — REMOVED from the Engine at 0.4.0, its row below): a backslash, tab, newline or carriage return in an attribute name is escaped as `\\`, `\t`, `\n`, `\r`, so one row stays one line and four columns; a correctness fix of the form's own format — the shipped attribute families carry none of the four and serialize byte-identically (the pinned [8g] output unchanged); the five-column golden producer untouched (the twelve pins unmoved; the producer REMOVED at 0.4.0, its row below); the alternative cure — record delimiters refused at registration — NOT implemented, hardening the creator defers until the basic framework works; the same-commit triple (the code `src/annotations.jl`, this document's §1.2 + §2, the witness `tests/unit/public_surface_tests.jl` [8h]); no compatibility promise until at least v0.7 (§6).
- **`GoMeta.content_fingerprint` — §1.2 public-not-exported since 0.2 — REMOVED at 0.4.0** (by the creator's decision: the stored copy and the public function removed, no Engine function serving a piece's text — it is read from the BLS Component tree through BLS's own access function; no deprecation stub — a cut as clean as possible): a 0.3.x caller sees `UndefVarError`; replacement: `GoMeta.BLS.content(delivery.blsComponentTree, component)` for a piece's text, the Component reached through the door (`GoMeta.BLS.children`) or named by the answer function (`GoMeta.evaluatedAltValue(…).via`, `GoMeta.scanAlterant`); the shipped consumers (`find_by_label.jl`, `notebooks_from_source.jl`) re-routed that way; the same-commit triple (`src/GoMeta.jl`'s `public` line, this document's §1.2/§1.3, the surface oracle `tests/unit/public_surface_tests.jl`).
- **`EvalRecord.content` (field) — REMOVED from the public record type at 0.4.0** (a second change to that public type beside the origin field `decided_by`, its own register row): a reader of `.content` sees a field error; the row names its Component by `cell_handle` and carries no copy of its text; the record's fields are `cell_handle`, `attr`, `value`, `polarity`, `decided_by`. The one row without a piece in the tree — a heading fed through the configuration's user profile — carried an empty fifth column in the test layer's derived form (the creator's decision); at 0.4.0 no such row exists (a heading in the profile refuses at the read), the test layer's arm kept.
- **`GoMeta.serialize_evals(::GoMetaDelivery)` (the five-column method) — REMOVED at 0.4.0**: the golden layer's five-column form is the TEST layer's since 0.4.0 — `TestSupport.derive_annotations_golden(delivery)` (`tests/support/derive_annotations.jl`), its fifth column a piece's text through the BLS Component tree and `GoMeta.BLS.content`; the twelve reference files byte-identical by both producers while both existed, unmoved at the removal; the four-column `serialize_evals(ann)` stays the Engine's one serialization; the Engine's internal `cell_content_bytes` superseded by `GoMeta.BLS.content`.
- **The Visib write-back into the BLS Components — REMOVED at 0.4.0** (by the creator's decision): the two write sites (the Block grain in the driver loop; the Segment grain onto the Line in the absorb walk), the latch `wrote_back` of the per-call state, the diagnostic code `STATE_SEAL_MISMATCH` and the POISONED variant of `STATE_REUSE_REFUSED` (the ledger's `registry` and `poisoned` fields with them). Within the 0.4 development, after this removal and until the three flags' declarations were removed as well, a consumer that read a Component's `:show`/`:hide`/`:discard` flag read FALSE for every Component — the Engine's answer is `evaluatedAltValue` (§1.2; the basic renderer and the development tools read it). The three flags' declarations STAYED until later decisions of the creator removed them as well, also at 0.4.0 (the rows on the carried declaration slots and on the three Visib declarations below): the registry's `settribute` slots, the derived `action_to_settribute` table, the three names inside BLS, `RenderDecl.materialize`. The E-04 crash origin (§3.1) retired with the write-back's read. Proved by 0 of 7 committed renders moving. Since the removal of the three names inside BLS (the row on the three Visib declarations below) the three flags are no longer keys of the BLS record at all — `getElement(c, :hide)` fails loud in the key table's own lookup (Julia's no-such-field error on the record's key NamedTuple — not a `KeyError`), not FALSE.
- **The declared defaults of Labels, Heading and Id — ADDED at 0.4.0** (by the creator's decision, PROVISIONAL: the values may change once used on real examples): `Labels` declares the empty set `Symbol[]`, `Heading` declares `nothing`, `Id` declares the zero compound `(cell = Int16(0), parent = Int16(0), file = Int16(0))` (Visib's `:show` since 0.4.0). For a Component with no rows of the Alterant anywhere up the tree, `evaluatedAltValue` returns `(value, :default)` at 0.4.0 (earlier within the 0.4 development, before these defaults were declared, it returned `(nothing, :none)`); the source `:none` remains for the File and for an Alterant of a custom registry without a declared default. The registration digest (REMOVED at 0.4.0, its row below) moved with the record. `childDiffers` FOLLOWS (the Block-against-File reading: a top Block compares against the File's `nothing`): every top Block now differs for Labels and Id as it did for Visib (`false` → `true`); Heading's `nothing` against the File's `nothing` still does not. Id's declared compound names the type's three fields in the type's order `(cell, parent, file)`; a row-derived compound carries only the RECORDED fields — two shapes no consumer compares by `==` today.
- **The answer function's SOURCE for a Line decided by its own trailing metaSegment, and for that Line's Segments — CHANGED at 0.4.0** (by the creator's decision): the Line answers `:own` (earlier within the 0.4 development: `:indirect` through the Segment); a Segment without rows of its own answers AS its Line answers — the Line's `:own` marked `:indirect` through the Line (earlier within the 0.4 development: `:own` when the deciding handle was the Segment's own key; `:indirect` through that metaSegment for the Line's other Segments), every other source unchanged (`:indirect` through the Line's own decider, `:user` under a fed profile, `:file`). An inline heading's row stayed keyed on its Segment — not touched by this change (the row on the inline heading's KEY below keys it on the Line, also at 0.4.0). The VALUES, the rows and their `decided_by` are unchanged.
- **`answerFor`, `answersFor` and `AltAnswer` — RENAMED at 0.4.0 to `evaluatedAltValue`, `evaluatedAltValues` and `EvaluatedAltValue`** (by the creator's decision: the name says what a call of the function returns — the evaluated altValue): the names only — the signatures `evaluatedAltValue(delivery, component, alterant; registry)` and `evaluatedAltValues(delivery, component; registry)`, the record's fields `value`, `source`, `via`, the seven source tags, the tier (package-public, not exported) and every behaviour unchanged; `scanAlterant` and `childDiffers` keep their names; the file names `src/answer.jl` and `tests/unit/answer_tests.jl` stay. The earlier entries of this page read the new names (the two NOT FINAL notes — `src/answer.jl`'s header and this page's entry on the function — name `answerFor` as the former working name); the repository's commit messages that say `answerFor` describe the same function under its former name.
- **The inline heading's KEY and the commented metaLine's carrier — CHANGED at 0.4.0** (by the creator's decisions): the heading stated in a Code Line's trailing metaSegment is keyed on the LINE with the Segment as the key's origin, as every inline statement is, and the Line answers it `:own`, its Segments `:indirect` through the Line (before — in 0.3.2 and earlier within the 0.4 development — the row was keyed on the Segment itself; once the answer function existed, within the 0.4 development, that Segment answered `:own` while its Line answered the default); a metaLine split by a trailing `##` comment hands its statement Segment over with the metaBlock as the carrier, so its heading row is keyed on the metaBlock and EVERY statement on such a metaLine records the metaBlock as its deciding statement (earlier within the 0.4 development: the statement Segment — a defect against the rule that the stating Component of a whole-line metaLine is the metaBlock it forms; the answer function's source for the creator's two example files' rows moved from `Segment n:s-e` to `Block a-b`); the level constant `head_10` unchanged; the degenerate-key warning `WARN_DEGENERATE_OCCURRENCE_KEY` (both sites) REMOVED; the golden `heading_quoted_first.jl.ann.txt` re-derived and the comparison forms `heading_quoted_first`, `file_for_Example_Extended`, `file_for_Example_Proposal_JuliaCon` re-made (the header's sha = the parent 79ea54cd).
- **The registration validation chain and the clash-disposition switch — REMOVED at 0.4.0** (by the creator's decision: the public surface restricted to the necessary functionality and kept to a minimum; no hardening before the framework works): the validation chain — the tier-1 record shape law (the closed enum sets, the kinds/kind_sources, queryable, dispatch-target uniqueness, plugin-index, settribute-key and MutEx rows; the capture identity, stem-shape and stem-clash laws), the tier-2 inventory law (`REG_UNKNOWN_SETMODE`, `REG_DUPLICATE_ALTNAME`, `REG_RESERVED_SHADOW`, `REG_MUTEX_CONFLICT`, `REG_UNINTERPRETED_REQUIRES`, `REG_CONTRACT_VERSION`, the validate-time `REG_SLOT_EXHAUSTED`), the clash law with both arms and the switch (`REG_DUPLICATE_ACTION`), the reflection cross-check (`REG_SIG_MISMATCH`), the value-algebra and reachability refusals (`REG_VALUE_ALGEBRA`, `REG_UNREACHABLE`), the candidacy warning (`REG_CANDIDACY`) and the eager dependency closure (`DEP_MISSING`) — were removed from `src/alterants/registry.jl`, together with the four dead closed-set constants of `src/state.jl`; `validate` runs the domain probe (the one domain definition shared by `validate`, `publish`'s copier and the door's walker), the four capture mode-gate laws of the Heading's separate delivery (until their removal with it, also at 0.4.0 — its row below) and the vocabulary check (until its removal with the Labels vocabulary machinery, also at 0.4.0 — its row below). MEASURED consequences of this removal, on the code of that time: a duplicate action name resolves FIRST-wins in the derived tables (the original engine's Dict assignment was last-wins); a `:candidate` without activation publishes silently; an `altConstructor` without a zero-arg method publishes and meets `CB_CTOR_THROW` at the first mint, naming the `MethodError`; a capture `instance_type ≠ altConstructor` publishes and floors `WARN_CAPTURE_UNREADABLE`; a stem overlapping a shipped family publishes — on one cell the two plugins' same-attr rows collapse to one row (full structural namespacing deferred); a capture scheme outside the walk's four arms with gate `nothing` publishes and falls through the walk — no row, no floor (its handling deferred); a kind or source literally named k/s is no longer refused at registration, so such a record's fingerprint can alias another's — a fingerprint-only class inside the fingerprint's disclosed bound as a lossy cache-key component (the registration fingerprint itself REMOVED at 0.4.0 — its row below); a builder pushed past 127 plugins or actions, or with a dangling plugin index, DIRECTLY (bypassing `register!`, which refuses both coded) fails raw at `publish` (`InexactError`) or at apply (`BoundsError`) — the honest bound of the bypass; `publish`'s warning path stands with no remaining check that warns.
- **`GoMeta.BLS.content(tree)` — ADDED (public, not exported) at 0.4.0** (by the creator's decision): the document's lines joined by a newline, as bytes (no terminal newline — `endsWithNewline` carries that fact; a CRLF line end's CR dropped by the line split), the one-argument method of the door's `content` — not a `(tree, ::File)` arm of the two-argument form, whose empty return for a File is the Engine's capture predicate (untouched); the development tools' last two reads outside the door were removed with this addition — the File's text now through this method, the renderer's whitespace guard before the hide marker through `isHorizontalSpace` (over a Char the two predicates differ at \v, \f, \r and U+0085 — stripped by the internal guard alone — and at U+180E — by the public class alone; no corpus input carries any of the five).
- **`run_absorb_apply!` (the callable driver seam), its state ledger (`STATE_REUSE_REFUSED`), `validate_carrier_state` and the `_walk_and_apply!` factoring — REMOVED at 0.4.0** (by the creator's decision: a seam that serves only one adapter, the .fodt adapter, does not belong in the Engine; the original engine was one function): `goMeta(bytes; config, registry)` is the ONE route into the Engine; the driver body (the fresh per-call state, the user feed, the File loop, the delivery) runs inside it; a caller-built store has no entry and no checker; `names(GoMeta)` unchanged (none of the four was a `public` name). The corpus, the golden layer's 26 pins (the twelve annotation pins, the seven render and the seven tree references under `tests/golden/`) and the twelve frozen forms (`tests/comparison/`) byte-identical (measured); the suite count moves by the retired witnesses alone.
- **The Labels vocabulary machinery — `VocabularySlot`, `InlineVocabulary`, `VocabularyRef` (the record's `vocabulary` slot, field and keyword), the triple `vocabulary` / `vocabulary_member` / `vocabulary_queryable`, the `SRC_DIGEST_MISMATCH` code, the digest pin, the capture cache, the artifact grammar, the scope law, the write-only valve and the labels record's policy identity — REMOVED at 0.4.0** (by the creator's decision — a basic Labels Alterant first, before any hardening): the 38 names stayed, within the 0.4 development, in the plain file `src/alterants-std/labels_vocabulary.txt`, read at load (the file byte-identical — the ZWJ line's `query=false` field, the creator's content decision, inert data from this change on), until a later change, also at 0.4.0, hard-coded them, with `:doc`, in the Labels Alterant's own file `src/alterants-std/labels.jl` (the register's row on the Labels vocabulary's home); `setLabels` keeps the closed check (an unknown label APPLIED refuses, naming the accepted set); `checkLabels` answers false for an unset or unknown label — as the original engine answered; a `vocabulary = …` keyword on the record's constructor is a `MethodError` (the alias `PlugIn` itself an `UndefVarError` since its own removal, also at 0.4.0 — its row below); `names(GoMeta)` loses six. The corpus, the golden layer's 26 pins and the twelve frozen forms byte-identical (measured); the registration digest re-minted (the labels record's slots left the seal fold, measured; the digest itself REMOVED at 0.4.0 — its row below).
- **The carried declaration slots and the reserved security frame of the Alterant record — the types `RenderDecl`, `EffectRow`, `MutEx`, `ConditionAtom`, `SugarRow`, `DomainRef`, `Provenance`, `SignatureRecord`, `PermissionManifest` (nine public names) and the record's fields `render`, `constraints`, `atoms`, `contract_version`, `requires`, `sugar`, `provenance`, `permissions` — REMOVED at 0.4.0** (by the creator's decision — permission levels and hash checks deferred; the basic framework first, before any hardening; no unnecessary clutter): the record keeps eight fields (the six of 0.3.2; the declared default and the capture declaration, both since 0.4.0); a record naming a removed keyword no longer constructs (a keyword error at the call); the seal's fold covered the capture slot alone of the declared slots from this change on (the seal itself REMOVED later, also at 0.4.0 — the register's row on the registration fingerprint) — the registration digest re-minted (a cache key, measured); nothing a run produces changes (the corpus byte-identical before and after the change). `RenderDecl.materialize` — one of the four Visib declarations (the register's row on the Visib write-back) — is REMOVED here with its type, at 0.4.0.
- **The capture walk's hardening, the capture declaration's `instance_type` and `multiplicity` fields, the `getAltState` query envelope, the `WARN_VERDICT_COLLISION` diagnostic and the meta-hierarchy slot-pool guard — REMOVED at 0.4.0** (by the creator's decision — the basic framework first, before any hardening; the original engine read the stores and called the getter bare): the capture walk reads each Alterant's store bare under its declared scheme (a store outside the shape is Julia's own error; a record without a capture row mints nothing); `CaptureDecl(attr_scheme, mode_gate[, attr_stem])` (the `mode_gate` field REMOVED later, also at 0.4.0 — the register's row on the Heading's separate delivery) — the store's shape is the record's own `altConstructor`; the stem derivation folded into `_capture_stem` (four copies); the registration digest re-minted (the capture row's seal text; the digest itself REMOVED at 0.4.0 — its row below); the flush of the Heading's separate delivery kept `_capture_floor!` and its two warnings until the Heading ran through the apply loop, also at 0.4.0 (the register's row on the Heading's separate delivery); the closed interpreter's query envelope stayed until its removal with the interpreter, also at 0.4.0 (the register's row on the closed condition interpreter; §3.4 — the getter is called bare at 0.4.0); a conflicting re-apply on one cell supersedes silently, later wins; an exhausted slot pool is Julia's own error; the occurrence key's totality arm (deferred) NOT taken here.
- **The set-invocation seam `_invoke_set` with its pre-checks and envelopes, the instance-mint wrap `_mint_instance`, the kind map `_kind_type` with `_LITERAL_KINDS`, the user-arity helper `_user_arity`, and the `_unchecked_registry` test seam — REMOVED at 0.4.0** (by the creator's decision — the basic framework first, before any hardening; the original engine called the setters and constructors directly): the apply loop and the absorb heading seam (the latter REMOVED later, also at 0.4.0 — the register's row on the Heading's separate delivery) call `altConstructor()` and `setAltInstance(store, action, args...)` bare — a malformed argument, an absent or throwing constructor, a store foreign to the setter's method and a declaration the method does not implement are Julia's own errors out of the `goMeta` call, and a setter's return is not checked; the codes `CB_SET_THROW`, `CB_CTOR_THROW` and `RES_FOREIGN_STORE` leave the catalogue, `RES_RETURN_TYPE` kept two surviving sites at that time — the closed interpreter's query site (removed with the interpreter, also at 0.4.0 — the register's row on the closed condition interpreter) and the handover validator, its one site at 0.4.0 (§3.4); the registration record and its digest unchanged by this change; the refusal witnesses were removed with their subject (arg_guard, registration, seam_envelope, heading_recognizer); measured before and after the change.
- **The declared action record's overload rows (`ActionOverload`, `ActionSpec.overloads`), its `spelling` tag, its `sugar_candidacy` grant register and its reserved `keyed_slot`, and the v0.3.2 positional constructors of `PlugIn` (6-positional) and `ActionSpec` (8-positional) — REMOVED at 0.4.0** (by the creator's decision under the versioning policy above — clean cuts, no leftovers of an old version in newer ones; the original engine registered an action by its name and let Julia dispatch do the rest): `ActionSpec` became five fields `(name, plugin, accepts_string_slot, validate, settribute)` — four at 0.4.0 (§1.2) — with the keyword form as the one form — `accepts_string_slot` and `validate` stay for the Heading (the register's row on the Heading's separate delivery), `settribute` stayed until its own removal, also at 0.4.0 (the register's row on the three Visib DECLARATIONS); the registration digest no longer folded the rows, the tag, the register or the slot (measured and pinned; the digest itself REMOVED at 0.4.0 — its row below); the door walks two record structs; the public name `ActionOverload` leaves the tier (27 names at 0.4.0 — the register's `PlugIn` row); no behaviour on the shipped Alterants (the corpus, the forms, the pins, the evals trees); a custom registry written in the old form — an `overloads =` keyword, a positional `PlugIn(...)` — is Julia's own MethodError at construction (since the alias's own removal, also at 0.4.0, `PlugIn` itself is an `UndefVarError` — the register's `PlugIn` row; an API break for custom registries under the versioning policy above; measured before and after the change), the keyword five-field form registered, validated, published and ran before and after the change, within the 0.4 development (at 0.4.0 the keyword form has FOUR fields — §1.2 — and `settribute = …` is a `MethodError`, the register's row on the three Visib DECLARATIONS).
- **The flavor record's digest fold (`_flavor_digest` and the `digest` field), its header-strategy seam (the `parse_header!` pointer, the `header_strategy` identifier, the forward declaration), its `extensions` field and the `_CFAM_LEAD_*` / `_RE_META_LEADED_*` compatibility aliases — REMOVED at 0.4.0** (by the creator's decision — the basic framework first, before any hardening; clean cuts under the versioning policy above): the parser's loop calls `parseLeadHeader!` directly for every armed flavor (the seam switched to a fallback that no longer existed); the digest was a cache-key component no code read (the cache key composed name, mode, schema, grammar and registration — no flavor component, pre-existing; the cache key itself REMOVED at 0.4.0 with the grammar profile — the register's row on the closed condition interpreter); the extensions were read by no code; the aliases' cited referents were not in the repository. The door's promise of five fields (the register's `GoMeta.BLS.flavor` row) is untouched; no behaviour on any flavor — the three armed flavors' tree and render bytes equal before and after the change (measured); an internal `_mk_flavor` call carrying the three former keywords is Julia's own error now.
- **The four guarded refusals ADDED to the original engine's metaLine parser — the punctuation wall at the action-name position, the glued-token wall after a closing `)` or `}` (with its gating flag), the no-token guard ("GoMeta absorb: malformed metaLine …") and the per-slot capacity guard ("GoMeta absorb: slot action capacity …") — REMOVED at 0.4.0** (by the creator's decision — the basic framework first, before any hardening): a malformed metaLine was then read as the original engine read it — punctuation at the action-name position skipped to the next identifier, a token glued to a closing bracket dropped — or met Julia's own `BoundsError` (an empty meta region; a further action in a full slot — the queue tensor's width was the registered action count, 8, until a later change, also at 0.4.0, made it the named capacity `SLOT_CAPACITY = 8`, the register's row on the `ids` action), until the grammar made explicit, also at 0.4.0, refused these shapes with its one refusal (the row below; §3.4) — at 0.4.0 none of them is read silently; the removal itself kept every re-worded message of the original engine (the messages standing at 0.4.0: §3.4); no public name changes — the row is written for the behaviour's sake, as the row on the capture walk's hardening was.
- **The metaLine parser's grammar made explicit — CHANGED at 0.4.0 (by the creator's decisions):** a metaStatement is a HEAD (a name, a `:` label, or the region's first `"…"` heading), then at most one `()`, then at most one `{}`, and ENDS at white space; any other character meets `GoMeta absorb: unexpected character …` (§3.4) — the original engine's silent skip of a leading punctuation, its silent drop of a glued token and its `BoundsError` on an empty region (the row above) end here; the ninth action in a slot meets "more than 8 actions in one meta-hierarchy slot" before the write; ONE scanner finds every span quote-aware (a `}` or `)` inside a quoted text closes nothing) and the five span refusals are re-worded to "unterminated '<o>' — never closed …" and "backslash in a quoted span — reserved …" (the former "unterminated quoted argument / heading / argument list / condition block" and "backslash in a quoted argument / heading" texts, "duplicate argument list / condition block" and "misplaced one-word label" were removed); ONE text-argument rule from the registration at both seams; `:label1,label2` refused with the right form named; the full argument list with its empty pieces handed to the Alterant. VALID input unchanged — the twelve frozen forms (`tests/comparison/`) and the two example files byte-equal; the parser-quality battery `tests/unit/parser_quality_tests.jl` (263 rows) the witness; no public name changes.
- **The three Visib DECLARATIONS — the per-action write-back key `ActionSpec.settribute`, the derived table `AlterantRegistry.action_to_settribute` and the three names `hide`, `show`, `discard` in BLS's `ComponentSettribute` — REMOVED at 0.4.0** (by the creator's decision; in the creator's words, the flags were stored in the BLS Components "for simplicity and as an interim step", to be removed later): nothing had written back since the Visib write-back's removal (its row above) — the Engine's answer is `evaluatedAltValue` (§1.2). What an older caller sees: `ActionSpec(; …, settribute = …)` is a `MethodError` (the keyword is gone); `R.action_to_settribute` an error (the field is gone); the registration digest re-minted (the seal fold lost the slot; the digest itself REMOVED at 0.4.0 — its row below); and — by the creator's decision — a condition naming `show`, `hide` or `discard` meets the usual unknown-condition-key refusal where, earlier within the 0.4 development, it was accepted and silently false (measured: `#~ hide{ show }` PROCESS_OK with 0 evals rows before the change, the refusal after; witnesses: `tests/unit/condition_tests.jl`'s retired-keys testset). HOW it is delivered — MEASURED, not inferred: taking the three names out of BLS alone did NOT refuse them (the intake read `show` as a registered ACTION and minted a query — silently false without a Visib instance, measured there; with one, a CB_QUERY_THROW at apply by the mechanism measured for Id before the change, `#~ cell(3) hide{ cell }`); the rule that delivers the creator's decision is the registry's `queryable_action` (`src/state.jl`): a bare name in a condition is a settribute key, or an action of an Alterant that ANSWERS queries (Labels at v0 — Visib, Id and the Heading declare no getter), or it meets the usual refusal — whose text gains the one word that became false ("nor a registered" → "nor a queryable alterant action"). Its reach beyond the three names: a query of Id or the Heading (`{cell}`, `{head}`), which, earlier within the 0.4 development, answered FALSE silently or threw CB_QUERY_THROW at apply, refuses at absorb the same way — one principled rule in place of a patch per key (the creator's principle: a fix from the ground up, not a patch per issue), placed on the registry so it outlives the closed condition interpreter (the row below); in the creator's design, the condition parser recognises the GoMeta-specific parts (§3.2).
- **The closed condition interpreter, the opt-in condition modes and the grammar profile — `src/condition.jl` whole (`parse_condition`, the algebra `CondStateAtom` / `CondQueryAtom` / `CondRawArg` / `CondNot` / `CondAnd` / `CondOr` / `CondScAnd` / `CondScOr` under `ConditionAST`, `print_condition`, `evaluate`, `cond_atom_for`, `cond_query_for`, `has_query_atom`, the condition codes `ERR_UNKNOWN_CONDITION_KEY` (E-01), `ERR_CONDITION_CAP` (E-02), `ERR_CONDITION_ARG_DOMAIN`, `ERR_CONDITION_PARSE` and the never-minted `ERR_CONDITION_UNQUERYABLE_ALT` (E-07)), the marker `FullEvalCondition` with `_FULL_EVAL_HANDLER` / `register_full_eval_handler!` and the alias `ConditionT` (`src/state.jl`), `src/grammar_profile.jl` whole (`GrammarProfile`, the caps and precedence data, `_grammar_digest`, `_mk_profile`, `cache_key`, `_profile_wellformed_check`, the opt-in seam `_CONDITION_MODES` / `register_condition_mode!` / `condition_mode_fn`, `_PROFILE_MODES`, `resolve_profile`), the pinned `DEFAULT_GRAMMAR_PROFILE` (`src/alterants/registry.jl`), the extension `optin/condition_modes_opt_in.jl` with `optin/README.md` (the directory `optin/` emptied), and the field and keyword `GoMetaConfig.profile` with `validate_config` and `ERR_UNKNOWN_PROFILE` (E-03) — REMOVED at 0.4.0** (by the creator's decision — no additional safe parser and, for now, no opt-in: a full parser must be available to those users who, for instance, work only with their private GoMeta statements; the creator's design: the parser recognises the GoMeta-specific parts and slightly re-writes the condition into a Julia Expression evaluated on demand by Julia; a clean cut, as this section's policy requires): a `{…}` condition is READ BY JULIA'S PARSER AND EVALUATED BY JULIA, as the original engine did — the body re-written at absorb (a settribute key to its state read; a QUERYABLE action to its query call; a label test `:name` to the Labels query, every admitted name spelled `Symbol("name")`; `,` to `||`; the rest verbatim — `_rewrite_condition`, `src/absorb/absorb_meta.jl`), parsed ONCE by `Meta.parse`, carried as Julia's `Expr` (`AlterantQueue.conditions`) and evaluated by `Core.eval` in module `GoMeta` at apply (`src/alterants/apply.jl`; a heading's once at the absorb seam until the Heading's separate delivery was removed — the register's row on it); the vocabulary rule KEPT — the registry's `queryable_action` (`src/state.jl`; since 0.4.0 — the register's row on the three Visib DECLARATIONS): a bare name is a settribute key, or an action of an Alterant that declares `getAltInstance` (Labels at v0), or it meets the usual `GoMeta absorb: unknown condition key …` refusal — the vocabulary's refusal, the keyword literals `true` / `false` / `nothing` and, until a quoted text was copied whole to Julia (§3.2), a quoted string's word among the bare words it refuses (the original engine's reading); an empty block or a bare literal is refused as carrying no condition expression — the seam's second refusal (the original engine applied unconditionally; this refusal provisional); a worded label carrying a parenthesized list (`:abc(:label1)`) reads as the label test of the word followed by a Julia call on its Bool — a `MethodError` at apply, where the original engine dropped the word and queried the list and the closed interpreter refused the shape (this reading provisional); the three profile names `:jl_share_v1` / `:jl_share_v1_full_parse` / `:jl_share_v1_full_eval`, the two-act law and the forward-provisioned cache key leave with the modes; the EXPORTED type `GoMetaConfig` RE-SHAPED — `GoMetaConfig(; flavor_tag, parse_range, user_mh_profile, namespace)`, the same-commit triple (the type `src/config.jl`, this document's §2/§3.1, the surface oracle unchanged — the four exported names and the 27 public names at 0.4.0 — the register's `PlugIn` row); none of the removed names was public. What an older caller sees: `GoMetaConfig(profile = …)` a `MethodError`; `include(… "optin/condition_modes_opt_in.jl")` no such file; a document whose condition met a coded refusal: a body Julia cannot parse is Julia's own `Meta.ParseError` out of the `goMeta` call (the messages 'condition too complex', 'condition too large', 'unterminated label key', 'unparsable condition', 'malformed condition key', 'label key with an argument list', 'unsupported condition argument' gone; 'empty condition block' re-worded to 'carries no condition expression'); a `PROCESS_ERROR` delivery carrying `[:ERR_UNKNOWN_PROFILE]` never again. What an author gains: the 29-step scan wall, the 29-code-unit atom wall, the 4096-byte wall and the depth-32 wall are gone (a 13-atom condition applies where it refused), the argument grammar is Julia's, a Julia Boolean expression over the GoMeta names (`{ 1 == 1 }`) is accepted and evaluated, a glued grouping `{(isCode)}` reads and a ZWJ pictograph label queried reads — MEASURED before and after the change, over 26 condition bodies and the condition shapes pinned as the H rows of `tests/unit/parser_quality_tests.jl`; the TWELVE FROZEN FORMS UNMOVED (nine carry conditions — a moved line is a defect); the heading-condition walls (`src/absorb/absorb_meta.jl`): the full-eval arm was removed with its marker; the label-test wall ("alterant-state query in a heading condition") KEPT here as the ONE minimal refusal until the Heading ran through the apply loop — a walk over the stored `Expr` for a `getAltState` call — then REMOVED with the Heading's separate delivery (the register's row on it); the getter is called bare through `getAltState` — `CB_QUERY_THROW` leaves the catalogue, `RES_RETURN_TYPE` keeps the validator site; the evaluation's cost MEASURED (65–155 µs per `Core.eval` on the corpus shapes — the original engine's known cost; the lowered form would be a hundredfold cheaper, an open choice). Witnesses: `tests/unit/condition_tests.jl` (new — the retired-keys testset of `condition_cap_tests.jl` re-homed with its control; the Julia-intake rows); `condition_cap_tests.jl`, `condition_modes_tests.jl` and `profile_snapshot_tests.jl` deleted whole; `unicode_cure_tests.jl` [1]/[3]/[5] re-cut end-to-end and `seam_envelope_tests.jl`'s query testset re-cut to Julia's own classes; `heading_recognizer_tests.jl`'s two wall witnesses unchanged by this removal (flipped when the Heading's separate delivery was removed — the register's row on it).
- **The registration fingerprint — `_registration_digest` (`src/alterants/registry.jl`), the FNV-1a fold helpers `_FNV_OFFSET` / `_digest_fold` / `_fold_parts` (`src/grammar_profile.jl`), `_mint_seal` and the `seal` field of `AlterantRegistry` (the `fnv1a64:<16 hex>` text; its `_SNAPSHOT_FIELDS` entry; the constructor argument) — REMOVED at 0.4.0** (by the creator's decision, for simplicity, together with its one consumer, the grammar profile; the fingerprint had been demoted to a lossy cache-key component): the fingerprint's consumer was the grammar profile's `registration_digest` / `cache_key` (the row above); the `seal` field carried the digest and nothing else — the DOOR never read its value: `_registry_door_check` gates on `_snapshot === nothing` (`REG_UNPUBLISHED`) and compares the nine walked fields against the publish-time snapshot, `===` at the leaves, firing `POST_SEAL_MUTATION` at the first divergent path — both guarantees kept; the word "seal" names that snapshot mechanism, so `_SealToken` and `POST_SEAL_MUTATION` keep their names; the `_slot_text` encoder family STAYS for its one remaining caller — the validate walk's canonical Dict-entry order (`_walk_dict_entries`; its removal together with that order is the creator's to decide); the type-encoder budget (predicate 2 of the domain probe) STAYS as the domain's declared closure. What an older caller sees: `R.seal` a field error (`hasfield(AlterantRegistry, :seal)` false); the digest re-mints this register records end here (the rows above on the Labels vocabulary machinery, the carried declaration slots, the declared action record's overload rows and the three Visib DECLARATIONS stand as history); no public name moves. Witnesses: `registry_lifecycle_tests.jl` — the two seal pins re-cut to the snapshot, the route-U pin to `_snapshot === nothing`, the seal-carrying forge form and W4 (the foreign-seal leaf witness) retired, the 22 encoder pins unchanged; `record_schema_tests.jl` — the seal-participation pin and the digest-coverage testset retired, the slot-text distinctness pin unchanged; `snapshot_property_tests.jl` unchanged in count (the `:seal` skip line gone — the door's proof, 3127).
- **`PlugIn` (the public alias `const PlugIn = Alterant`) — §1.2 public-not-exported since 0.4.0's `Alterant` rename — REMOVED at 0.4.0** (by the creator's decision: the package-public tier cut back to the names the creator decided, and the alias removed as a clean cut under the versioning policy above; the rename the creator's own choice: the name 'PlugIn' would clash with another kind of PlugIn the creator has in mind for later): the record type is `Alterant` and its keyword constructor `Alterant(; altName, setMode, altConstructor, setAltInstance, getAltInstance = nothing, precedencesTuple = nothing, default = NoDefault(), capture = nothing)` the one form; the FIELD NAMES are the original engine's and unchanged — no renaming of the fields is scheduled; what an older caller sees: `GoMeta.PlugIn` an `UndefVarError`; replacement: `GoMeta.Alterant`; the same-commit triple (the `public` line of `src/GoMeta.jl` and `src/state.jl`, this document's §1.1/§1.2/§6, the surface oracle `tests/unit/public_surface_tests.jl` — its set at 27 names and the clean-cut witness [10] `!isdefined(GoMeta, :PlugIn)`). THE TIER MEASURED at the removal: every other package-public name stands on a decision of the creator's — the one name without a ground was this alias; `DefaultSlot` and `ProcessStatus`, type names a consumer never writes, stay with their mechanisms (the creator may still drop them); the word "plugin" in `next_plugin_index`, `ActionSpec.plugin` and `RegistryBuilder.plugins` stays — the rename was the type's alone. Witnesses: `public_surface_tests.jl` [1b] at 27 names and [10]; eleven test files construct through `GM.Alterant(; …)` at 0.4.0; the twelve forms, the golden layer's 26 pins and the corpus unmoved.
- **The Heading's separate delivery — the absorb seam's `_absorb_local_only!` with its once-per-region flush, the recorder `capture_heading!`, the capture-floor diagnostic `_capture_floor!` with the codes `WARN_CAPTURE_FLOOR` / `WARN_CAPTURE_UNREADABLE`, the mode-gate laws `_mode_gate_collect!` with the field `CaptureDecl.mode_gate` and its closed set, the capture scheme `:per_occurrence`, the condition wall `_has_query` and the three refusals "heading without a document context", "alterant-state query in a heading condition" and "a conditioned heading in a profile feed" — REMOVED at 0.4.0** (by the creator's design and decisions: the Heading is an Alterant like any other within the GoMeta Engine, apart from its syntactic sugar, and goes through exactly the same process, using the set mode `localOnly`): the Heading's action is QUEUED like every action (the deriving form's level materialised at the enqueue from the walk's record — the level rides from the queue, never read from the Component's depth), decided by the apply loop's ONE RULE for the set mode `localOnly` — a row of this mode applies only at the Component the statement is applied to, the new provenance column `AlterantQueue.applied_to` its referent; every other Component that meets it on a shared level passes over it, unevaluated and unblocked — and recorded by the one capture walk under the new scheme `:per_entry` (one row per entry, the level in the attr name, the text the value, each entry's deciding statement its own applied row's origin); the declared handover validation (`ActionSpec.validate`) runs at the read for every action with a String slot; `CaptureDecl` is `CaptureDecl(attr_scheme[, attr_stem]; attr_stem = nothing)` — two fields. What an older caller sees: `CaptureDecl(scheme, nothing, stem)` a `MethodError`; `CaptureDecl(scheme, nothing)` CONSTRUCTS with the stem `nothing` (the derived fallback — the same effect as before); `CaptureDecl(scheme, :localOnly)` CONSTRUCTS with the STEM `:localOnly` (no gate exists any more — a silent re-reading of an old form, named here under §6's clean-cut rule); a registry declaring `:per_occurrence` falls through the walk (no row, no floor); a heading fed through `user_mh_profile` REFUSES with the one message of §3.4 where the explicit form recorded one row; a label test in a heading's condition is ACCEPTED where it refused; a metaLine with eight other actions and a heading meets the slot refusal where it absorbed; a trailing heading's condition reads the LINE's facts (`z = 3 #~ "T"{ isCode }` records where it did not, `{ isMeta }` there no longer does); a whole-line heading's condition reads the metaBlock's facts where the separate delivery read its metaLine's (by the creator's decision — `#~ "T"{ hasMetaStr }` records no row where it recorded `head_1`: the meta string is the metaLine's flag, not the metaBlock's); two heading metaLines glued into one metaBlock at the same level (`#~ "A"` directly followed by `#~ "B"`) record TWO rows on it, `head_1 => "A"` and `head_1_2 => "B"` — one row per heading occurrence (by the creator's decision) — where, within the 0.4 development, the separate delivery's per-metaLine flush recorded ONE (`head_1 => "B"`, the later superseding the earlier), so that metaBlock's heading answer moves from "B" to "A" (both measured before and after the change); the two warning codes leave the catalogue (a run's `diagnostics` vector is empty on the PROCESS_OK path). UNCHANGED by this change — the Heading's move into the apply loop, measured before and after it within the 0.4 development: every other whole-line heading row and its key (the metaBlock the metaLine forms, since 0.4.0; in 0.3.2 the key was the metaLine's own Line), the inline heading's key (the Line since 0.4.0 — the row on the inline heading's KEY above; in 0.3.2 the Segment) and its level 10, the attr names `head_<level>` / `head_<level>_<k>`, the twelve frozen forms, the goldens, scenario 005. Witnesses: `tests/unit/heading_recognizer_tests.jl` (the pins flipped on the creator's decisions), `capture_tests.jl` (its mocks re-cut to the loop), `registration_tests.jl`, `record_schema_tests.jl`, `snapshot_property_tests.jl`, the parser battery's row G09, the battery `devtools/probes/probe_devtools.jl` (its fed-heading probes re-cut).
- **The Labels vocabulary's home — the plain file `src/alterants-std/labels_vocabulary.txt` (38 names, one per line) and its loader `labels_vocabulary.jl` (the constant read at load) — REMOVED at 0.4.0; the Labels Alterant's OWN file `src/alterants-std/labels.jl` ADDED, holding the hard-coded list `LABELS_VOCABULARY` (39 names: the 38 shipped in the former file's order + `:doc`) and `setLabels` / `checkLabels` moved there byte for byte from `src/alterants/registry.jl`; an EMPTY or whitespace-only `user_mh_profile` made INERT like `nothing`** (the creator's design and decisions: the label whitelist belongs in the Labels Alterant, not in the Core — its place there was a mistake, and moving it out fixes a bug; a basic, true Labels Alterant, kept simple, that works at least as well as the original engine's, its names hard-coded in its own file — the 38 shipped names plus `:doc`, and the names the examples and test files need, measured as none beyond these; `public` / `private` not among them; the empty or whitespace-only profile inert): WHAT AN OLDER CALLER SEES — `GoMeta.Alterants.LABELS_VOCABULARY` holds the vocabulary at 0.4.0 (39 names; `:doc ∈` it; the name unchanged across the relocation within the 0.4 development — in 0.3.2 the vocabulary was the literal `goMetaLabels` in `src/alterants/registry.jl`, with no plain file and no loader), `GoMeta.Alterants.setLabels` / `checkLabels` keep their names and module; a reader of the plain file's path finds nothing; an applied `:doc` records `label_doc` where it met the unknown-label refusal, and that refusal's SORTED accepted-set display gains `:doc`; a profile `""` or `"  "` runs as no profile (before: it occupied the user slot, the loop's first slot, so a label stated after a `hide` on the same metaLine was seen — and, within the 0.4 development once the Heading ran through the apply loop, a label stated after a heading as well). UNCHANGED, measured (only the probes of `:doc` — applied, queried, and named in an unknown name's refusal — and of the empty or whitespace-only profile differ; a profile of ONE overlong sequence meets the same absorb refusal before and after): every row measured for the Heading's change (its row above) and the twelve corpus inputs, the twelve frozen forms, the goldens, the authored scenarios, the original engine's behaviour of the set (an unknown applied name refused with the accepted set named) and the check (an unset or unknown queried name false). Witnesses: `tests/unit/vocabulary_tests.jl` ([2b] `:doc` applied and queried, and in the accepted set an unknown name's refusal names; [10] the zero-literal scan green by the directory, its enumerated survivor census holding one survivor in `alterants/registry.jl` — the two kept empty-list messages having moved with the setter and the checker into the skipped directory; no new literal), `userfeed_visib_tests.jl` (the empty and the whitespace-only profile inert — white space as the absorb's one predicate reads it, so a profile whose edge character is an invalid byte sequence is content and FED — the profile of ONE overlong sequence refused by the absorb as before this change, an invalid sequence GLUED to the label sugar `:` fed and NOT refused by the absorb (measured: PROCESS_OK, no row over a meta-free document)), `unicode_cure_tests.jl` (the constant's membership pins unchanged).
- **The `ids` action of the Id Alterant — ADDED at 0.4.0 (the creator's design: `#~ ids(c, p, f)`), and the slot capacity DECOUPLED (the creator's decision):** a fourth `ActionSpec` of the Id Alterant (plugin 3) and two `setId` methods setting cell, parent and file at once, each as the single action sets it (the same `Int16` parse, the same `:per_field` rows, the same fault class — Julia's own error out of `goMeta` for a wrong arity, a non-parsable or an overflowing value, and for the one-value form `ids(7)`, which reaches the single-value method and meets Julia's `FieldError` on the field name `ids`); the queue's per-slot capacity a named constant `SLOT_CAPACITY = 8` in `src/state.jl` beside `NUM_MH_LEVELS`, the creator's decision stated beside it (the matrix size chosen to start with, hard coded, raised by hand when an example asks for more; the former registered-count sizing the code's own, as the original engine's `numAltActions`), `init_state` sizing the tensors from it and the absorb's refusal naming the capacity while keeping its "more than 8 actions in one meta-hierarchy slot" words — so a ninth registered action changed the capacity not at all. What an older caller sees: the three single actions unchanged by this change in every form but one — a single action written with THREE values (`cell(1, 2, 3)`; `parent` and `file` alike), which in 0.3.2 met the apply seam's "GoMeta apply: invalid arguments" refusal (REMOVED at 0.4.0 — the row on the set-invocation seam above) and, earlier within the 0.4 development, Julia's `MethodError` (no five-argument `setId` then), since 0.4.0 reaches the three-value method, whose guard throws the setter's own `ArgumentError` "setId: three values belong to the action `ids` alone (got `cell`)" (MEASURED) — the guard by design (without it the single action would set all three fields silently), its class the standing one (the Alterant's own setter error), its wording not final; `num_alt_actions` 9; the unknown-action refusal's sorted list gains `:ids`; the per-slot bound 8 as before for the default registry — and 8 for a CUSTOM registry too, where the queue had been sized by that registry's own action count (`num_alt_actions(registry)`, as the original engine's `numAltActions` sized its queue): a registry of fewer than 8 actions now admits up to 8 statements in one slot where the count-sized queue refused the one past its count, and a registry of more than 8 (an Extension's `RegistryBuilder(DEFAULT_REGISTRY)` with its own Alterant: 9 + n actions) refuses the ninth statement where the count-sized queue admitted up to its count (TRACED in `init_state`, `src/state.jl`, and MEASURED: a registry of 4 actions, the shipped Labels and Visib, refused the fifth statement under the registered-count sizing and admits five and eight and refuses the ninth since 0.4.0; `DEFAULT_REGISTRY` with an Extension Alterant of two actions — 11 actions (10 without `ids`) — admitted the ninth under the registered-count sizing and admits eight and refuses the ninth since 0.4.0; pinned by `tests/unit/slot_overflow_tests.jl` [C]). MEASURED before and after the addition, within the 0.4 development: `#~ ids(1, 2, 3)⏎x = 1` → `id_cell => 1`, `id_parent => 2`, `id_file => 3` on the metaBlock and on the Code Block (six rows) where `ids`, unregistered before 0.4.0, met the unknown-alterant refusal (§3.4); `ids(0, 5, 2)` → the parent and file rows alone (the stated zero equals the default and is not recorded — zero and unset indistinguishable in the rows, as §2 states); `ids(1, 2, 3) cell(7)` → `id_cell => 7` (the later statement overwrites the field, as `cell(1) cell(7)` does); `ids(1, 2)` → Julia's `MethodError` (= `cell(1, 2)`), and so `ids(1, 2, 3, 4)` and `ids()`; `ids(7)` → Julia's `FieldError` (above); `cell(1, 2, 3)` → the guard's `ArgumentError` (above); `ids("7", 2, 3)` → REFUSED at the absorb's string-argument wall, as `cell("7")`; `ids(x, 2, 3)` → `ArgumentError`; `ids(70000, 1, 1)` → `OverflowError`; the trailing form `z = 3 #~ ids(1, 2, 3)` → the three rows on the Line; `ids(1, 2, 3){ isCode }` → the three rows; the nine-action document REFUSED before and after (the message's text re-cut, its "more than 8 actions in one meta-hierarchy slot" words kept); every other probed input unchanged in outcome and in its message's head but one, whose refusal lists the sorted registered actions and gains `:ids` (REFUSED before and after) — the control `cell(1, 2)`'s `MethodError` lists the new five-argument `setId` among Julia's closest candidates; the twelve corpus inputs and the twelve frozen forms unchanged. Witnesses: `tests/unit/answer_tests.jl` [A10] (the three compounds — the answer names the fields alphabetically, MEASURED), `capture_tests.jl` [4b] (the `:per_field` rows of `ids`; the stated zero mints none), `arg_guard_tests.jl` [F] (the faults' standing class beside the single-action controls, and the three-value single action's guard), `registry_lifecycle_tests.jl` (the action count re-pinned 8 → 9), `seam_envelope_tests.jl` (the head spec addressed BY NAME — position 8 holds `ids` since 0.4.0), `slot_overflow_tests.jl` (the 8-boundary and the ninth under the nine-action default registry — the capacity no longer the count; [C]: the bound EIGHT for a custom registry of 4 actions and an extended one of 11, pinned at five, eight and nine statements in one slot for the first and at eight and nine for the second), `snapshot_property_tests.jl` (the realised |sites| 225 with `ids`, a multiple of 3, froze the per-site op residue of both selectors; both rotate per pass at every site — the property test's budget and arithmetic unchanged, 3127).
- **The user level's place in the apply loop (`GoMetaConfig.user_mh_profile`) — a BEHAVIOUR under a fed profile CHANGED at 0.4.1** (no public name added, removed or renamed): BEFORE, the loop took the FIRST eligible slot for the Component's own, and with a fed profile that slot was the user level's — a Component's own labels were then collected before its own conditions ran, so the committed example's own comment (`examples/InFileFolder/file_for_Example_Proposal_JuliaCon.jl`, lines 26–27, quoted line by line: *"It is NOT "discarded" since label3 has not been applied yet"* / *"when `discard{:label3}` is issued."*) held only without a feed. SINCE 0.4.1 (`src/alterants/apply.jl`, `detAltValuesForSetOfSlots`): the Component's own slot is the first eligible slot that is NOT the user level's and applies in WRITTEN order with or without a feed; the user level's accumulating statements (labels) are collected FIRST, as the outermost level; its other statements are evaluated AFTER the Component's own slot, with full sight of the Component's own labels, and with PRIORITY — an applicable user-level value OVERRIDES the value the own slot decided (`decided_by` the user context alone; the Id compound replaced whole, as before) — where a non-user slot is eligible; a Component whose ONLY eligible slot is the user level's has no own slot and runs the no-feed path, the profile's rows in written order, its labels not collected first: UNMEASURED (as the code reads, only a `#]` close Block before any absorbed metaBlock reaches it, and no fed input measured holds one). MEASURED: the no-feed delivery UNCHANGED (the goldens, the twelve forms, the authored scenarios, and the no-feed twins inside the witnesses below); under a feed — a condition written before its label no longer sees that label (the Blocks concerned in the two committed examples `file_for_Example_Proposal_JuliaCon.jl` and `file_for_Example_Extended.jl` return to their no-feed outcomes: `hide`, or no Visib row at all); the profile's own NON-accumulate conditions see its labels stated after them (a fed `discard{ :label1 } :label1` discards both Blocks, where before it recorded no Visib row) — its accumulating statements are collected first, as the outermost level, in the profile's written order, so a fed conditional label sees only the profile's labels stated before it (unmeasured); a fed CONDITIONAL label no longer sees the file's labels, while a file's conditional label sees a fed label; the Labels answer source under a feed reads `:user` where it read `:indirect`; a fed `cell(7)` over an own `parent(2)` ends `cell 7` alone, as before; with a feed the Component's own non-accumulate rows are now EVALUATED even where the user level then decides the Alterant (before, a guard on the prior slot skipped them unevaluated), so an own row that fails at evaluation fails the fed run as it fails the no-feed one (`#~ cell(x)` over `x = 1`: fed `cell(7)` it was `PROCESS_OK` with `cell 7` on both Blocks before, the own row skipped unevaluated; since 0.4.1 `ArgumentError: invalid base 10 digit 'x' in "x"` out of the `goMeta` call — the error the no-feed run of the same document throws). Witnesses: `tests/unit/fed_profile_order_tests.jl` [W1]–[W13]; the two pins of the former order in `tests/unit/heading_recognizer_tests.jl` re-pinned to the no-feed values.
- **The Labels Alterant's VOCABULARY STATEMENTS `:++x` / `:(++, x, y)` / `:--x` / `:(--, x)` — ADDED at 0.4.1; `Alterant.onRead` (keyword and field) — ADDED to the registration record at 0.4.1; the unknown-label refusal's noun RE-CUT** (the creator's design: a file at `#~0` or the user's profile adds names to the Labels Alterant's vocabulary for the run and removes names from it; the vocabulary's home outside the Engine, its loading chosen at the user or file level and a run's additions written back are a later release's, and nothing of this change stands in their way — the shipped list sits behind ONE function `base_vocabulary()`, and a run's additions and removals are kept apart from it): THE ENGINE — one optional registration field `onRead` (the ninth, appended last, `nothing` by default and for every other shipped Alterant and every custom registration; designated at the registry's callable loci), one per-run cell `ProcessState.alt_run`, the hook consulted by the absorb for the Alterant's statements WITH arguments after the profile feed's one `localOnly` refusal and before the slot bound (`nothing` enqueues as before; any value consumes the statement — no slot, no queue, no evals row — and is handed to the instance constructor as `altConstructor(run)`), the argument coercion moved to the same place; THE LABELS ALTERANT (`src/alterants-std/labels.jl`) — `base_vocabulary()`, the run state `LabelsVocabulary` (the base, the additions and the removals kept apart; the effective set the base plus the additions minus the removals), the per-Component instance `LabelsInstance` (the applied labels and the run's vocabulary), the hook `declareLabels!` (the place first, then the five malformed shapes, then the fold — §3.4), the setter checking the run's set, the message "not in v0's closed label whitelist" → "not in the Labels Alterant's vocabulary" (the set printed the run's). WHAT AN OLDER CALLER SEES — the record's keyword form gains an optional `onRead = nothing` and its positional form a ninth argument; `GoMeta.Alterants.LABELS_VOCABULARY` unchanged (39 names), now the base behind `base_vocabulary()`; the setter's and the checker's `Dict{Symbol,Bool}` methods kept (a custom registration pairing them with `altConstructor = Dict{Symbol,Bool}` runs as before, without the hook); a `#~0 :++x` or `#~0 :--x` that was refused as an unknown label (`"++x"`) is now a vocabulary statement, and `:(++, x, y)` / `:(--, x)` at `#~0` likewise; `#~ :+x`, `#~ :-x`, `:(+, x)`, `:(-, x)` and a signed list member are refused as before, their message's noun re-cut; the user level's VALUE statements keep their 0.4.1 priority over the file's, while its VOCABULARY statements are read first and a file's later statement wins for the same name — two directions, each by design. MEASURED: the no-feed delivery UNCHANGED for every input without a vocabulary statement (the goldens, the twelve forms, the authored scenarios, the twelve corpus inputs; the behaviour change of 0.4.1 above measured again, unchanged); with a vocabulary statement — a declaration then a use applies the name to the metaBlock and to the Block attached to it, each one row, decided by the metaBlock; a removal of a shipped name refuses its later use with the accepted set printed without it; the places, the reach, the fold, the no-ops, the five malformed shapes, the one-line orders, the profile against the file in both orders, nine statements on one `#~0` line applied (the declaration takes no slot), two `goMeta` calls in one process independent. Witnesses: `tests/unit/labels_vocabulary_tests.jl` (sixteen testsets, every value from the measured printouts; a custom registration's hook through the door among them); the record-field count of the snapshot property test 12 → 13; the authored scenario `028_labels_vocabulary_declared` DRAFTED for the creator's confirmation (`tests/authored/`, `status = "draft"`); the pages: this reference's §1.2, §2, §3.4, the README's Documented v0 limits, the syntax reference's §5 and §7.
