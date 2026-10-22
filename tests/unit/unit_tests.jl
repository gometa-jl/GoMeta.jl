# unit_tests.jl — the UNIT layer aggregator: one `@testset "unit"` umbrella that includes every per-concern
#   unit file, in a fixed order.
#
# IS:   the unit layer's index, dispatched by tests/runtests.jl as the "unit" layer. It holds no assertions
#       of its own; each included member self-contains its own `using Test` + `import GoMeta as GM` and
#       contributes its focused @testsets. Some members reference the shared `TestSupport` module, which
#       tests/runtests.jl loads once before the layers — so members run via the dispatcher, not standalone.
# DOES: wires the per-concern members, in order:
#   - public_surface_tests.jl — the export set equals the declared semver surface (docs/public-api.md §1);
#                               the Engine's output surface (`altValues_evals`) and the development tool's
#                               pair (`Main.BasicRenderer.outputs`, the one-path assertions).
#   - slot_overflow_tests.jl  — the per-slot capacity boundary and the ninth action's message.
#   - custom_localonly_feed_tests.jl — the profile feed's refusal at the read is not the shipped Heading's alone: a custom registry's
#                               Alterant declared as the Heading is (set mode `localOnly`) meets it when fed, a custom Alterant of another
#                               set mode does not (MEASURED on ONE
#                               custom registry — the condition keys on the set mode, every registry's by shape).
#   - malformed_meta_tests.jl — the metaLine parser's valid twins; the glued form refused by name.
#   - error_message_tests.jl  — stable-message witnesses, e.g. "GoMeta apply: unknown label".
#   - arg_guard_tests.jl      — the documented WORKING argument forms (the refusal witnesses were removed
#                               with the set-invocation seam).
#   - parser_quality_tests.jl — the parser-quality battery: every inventory shape with its
#                               expected outcome — accepted with its evals row count, refused with its GoMeta head, or Julia's class.
#   - condition_tests.jl      — the condition path (Julia's parser over the re-written body; the registry's
#                               vocabulary rule; the parser-quality rows).
#   … and every further member in the include list below (the list IS the index: token law · ws alphabet ·
#   unicode cures · reserved adjacency · heading recognizer · registration ·
#   flavor profile · latex flavor · ensure token · inert semantics ·
#   record schema · registry lifecycle); each include line carries its one-liner.
# REASONING: the byte-exact golden layer cannot see these concerns — the introspected public surface and
#       the stable refusal messages — so each lives in its own self-contained file.
# PURPOSE: one stable index for the unit layer.

using Test

@testset "unit" begin
    include(joinpath(@__DIR__, "public_surface_tests.jl"))
    include(joinpath(@__DIR__, "slot_overflow_tests.jl"))           # the per-slot capacity boundary and the ninth action's message + [C] the capacity EIGHT for every registry — a custom registry of 4 actions and an extended one of 11
    include(joinpath(@__DIR__, "custom_localonly_feed_tests.jl"))   # the profile feed's refusal is not the shipped Heading's alone — a custom registry's `localOnly` Alterant meets it too, MEASURED on one (the condition keys on the set mode) — [W1]–[W5]
    include(joinpath(@__DIR__, "malformed_meta_tests.jl"))          # the metaLine parser's valid twins; the glued form refused by name
    include(joinpath(@__DIR__, "error_message_tests.jl"))           # stable error-message witnesses
    include(joinpath(@__DIR__, "arg_guard_tests.jl"))               # the documented WORKING argument forms (the refusal witnesses were removed with the set-invocation seam) + [F] the `ids` faults' standing class
    include(joinpath(@__DIR__, "parser_quality_tests.jl"))          # the parser-quality battery — every shape of the inventory with its expected outcome (GENERATED)
    include(joinpath(@__DIR__, "condition_tests.jl"))               # the condition path — Julia's parser over the re-written body, the registry's vocabulary rule (the retired-keys testset re-homed), the parser-quality rows
    include(joinpath(@__DIR__, "token_law_tests.jl"))               # the token-delimiter-law verification matrix (the creator's decision of 2026-08-08)
    include(joinpath(@__DIR__, "ws_alphabet_tests.jl"))             # the ws-alphabet matrix (the creator's decision of 2026-08-08: Unicode \h unified; GENERATED file, real codepoints; [8] = the live `\h` pin relocated from the former text-law kernel's tests)
    include(joinpath(@__DIR__, "unicode_cure_tests.jl"))            # the Unicode cure witnesses (GENERATED, real codepoints)
    include(joinpath(@__DIR__, "reserved_adjacency_tests.jl"))      # directive-adjacency SHIP-CLASS tripwire (the 0.2.3 cure; ships)
    include(joinpath(@__DIR__, "heading_recognizer_tests.jl"))      # the String-lane widening + quote negative rows (APPEND-ONLY)
    include(joinpath(@__DIR__, "registration_tests.jl"))            # the registration record (the arming guard's witnesses, the clash law and the atomic refusals removed; APPEND-ONLY)
    include(joinpath(@__DIR__, "flavor_profile_tests.jl"))          # the FlavorProfile record + threading witnesses (APPEND-ONLY)
    include(joinpath(@__DIR__, "latex_flavor_tests.jl"))            # the FLAVOR_LATEX pure-data acceptance battery (APPEND-ONLY)
    include(joinpath(@__DIR__, "ensure_token_tests.jl"))            # the ensure-token witness battery (the second disjunct; APPEND-ONLY)
    include(joinpath(@__DIR__, "inert_semantics_tests.jl"))         # v0.3.1: the inert-marker differential oracle + the bang-first refusal + the Alterant guards (APPEND-ONLY)
    include(joinpath(@__DIR__, "record_schema_tests.jl"))           # the registration-record schema extension witnesses (APPEND-ONLY)
    include(joinpath(@__DIR__, "registry_lifecycle_tests.jl"))      # Builder → validate → publish, the one chain, the STRICT door, the seal gate, the exhaustion refusals (APPEND-ONLY)
    include(joinpath(@__DIR__, "snapshot_property_tests.jl"))       # the snapshot door's PROPERTY proof (N=1024 site mutations + FP rebuilds + named cases)
    include(joinpath(@__DIR__, "seam_envelope_tests.jl"))           # the seams — the bare getter call (its throw raw, a non-Bool Julia's TypeError; the former query envelope removed), the handover validation CONSUMED, the InterruptException pass-through (the ctor-mint envelope, the store-identity check, DEP_MISSING and the state-seam ledger removed)
    include(joinpath(@__DIR__, "vocabulary_tests.jl"))              # the whitelist's relocation: the membership over the Labels Alterant's hard-coded list (the plain file's before), the zero-literal law, the validate-chain hardening witnesses
    include(joinpath(@__DIR__, "fallback_order_tests.jl"))          # the fallBack level consulted LAST — three witnesses over a prepared slot
    include(joinpath(@__DIR__, "userfeed_visib_tests.jl"))        # the fed Visib evals rows against authored ones — five witnesses at the public entry ([U5]: the empty and the whitespace-only profile inert)
    include(joinpath(@__DIR__, "fed_profile_order_tests.jl"))     # 0.4.1 (the creator's decisions of 2026-10-18 and 2026-10-19): THE USER LEVEL'S PLACE IN THE APPLY LOOP — the Component's own metaBlock in written order with or without a feed; the user level's labels the outermost level; its other statements evaluated after the own slot with full sight and the override — thirteen witnesses [W1]–[W13], every value MEASURED
    include(joinpath(@__DIR__, "labels_vocabulary_tests.jl"))     # THE VOCABULARY STATEMENTS `:++x` / `:(++, x, y)` / `:--x` / `:(--, x)` at `#~0` and in the profile — consumed at the read by the Labels Alterant's hook (the registration record's `onRead`), no row; the run's vocabulary the base plus the additions minus the removals; the place and the malformed shapes refused; the Engine's door by a custom registration — sixteen witnesses [V-W1]–[V-W16], every value from the measured printouts
    include(joinpath(@__DIR__, "labels_withhold_tests.jl"))       # THE WITHHOLD `:-x` / `:(-, x, y)` AND THE EXPLICIT APPLY `:+x` / `:(+, x)` — a plain `:x` met by a withhold applies nothing and the run proceeds with ONE warning diagnostic `LABEL_NOT_APPLIED_WITHHELD` per statement and name at each affected Component, delivered through the Engine's door (the setter's `Vector{Diagnostic}` return, the place merged into the context); the malformed shapes and the unknown name refused — seventeen witnesses [B-W1]–[B-W17], every value from the measured printouts
    include(joinpath(@__DIR__, "origin_tests.jl"))                  # the provenance field decided_by — recorded at the enqueue, carried through the apply, captured with the row
    include(joinpath(@__DIR__, "answer_tests.jl"))                  # THE ONE ANSWER FUNCTION — ten witnesses over measured rows ([A10] the `ids` action)
    include(joinpath(@__DIR__, "scan_tests.jl"))                    # the scan by Alterant and the access by Component — six witnesses
    include(joinpath(@__DIR__, "childdiff_tests.jl"))               # the child-differs signal — four witnesses over measured rows
    include(joinpath(@__DIR__, "capture_tests.jl"))                 # the capture re-home — the registration-driven walk, a second `localOnly` Alterant through the apply loop and the deriving level's set-mode scope (the per-plugin flush and the mode-gate laws removed with the Heading's separate path; the floor, gate and algebra witnesses removed)
    include(joinpath(@__DIR__, "renderer_free_process_tests.jl"))  # ONE fresh child process with `import GoMeta` only — the delivered object needs no development tool
end
