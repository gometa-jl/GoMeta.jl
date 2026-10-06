# unit_tests.jl — the UNIT layer aggregator: one `@testset "unit"` umbrella that includes every per-concern
#   unit file, in a fixed order.
#
# IS:   the unit layer's index, dispatched by tests/runtests.jl as the "unit" layer. It holds no assertions
#       of its own; each included member self-contains its own `using Test` + `import GoMeta as GM` and
#       contributes one focused @testset. Some members reference the shared `TestSupport` module, which
#       tests/runtests.jl loads once before the layers — so members run via the dispatcher, not standalone.
# DOES: wires the per-concern members, in order:
#   - public_surface_tests.jl — the export set equals the declared semver surface (docs/public-api.md §1);
#                               the Engine's output surface (`altValues_evals`) and the development tool's
#                               pair (`Main.BasicRenderer.outputs`, the one-path assertions; R-V04B-24).
#   - slot_overflow_tests.jl  — witnesses for the "GoMeta absorb: slot action capacity" refusal.
#   - malformed_meta_tests.jl — witnesses for the "GoMeta absorb: malformed metaLine" refusal.
#   - error_message_tests.jl  — stable-message witnesses, e.g. "GoMeta apply: unknown label".
#   - arg_guard_tests.jl      — witnesses for the "GoMeta apply: invalid arguments" refusal at the
#                               action-args seam.
#   - condition_cap_tests.jl  — witnesses for the condition-length-cap refusal.
#   … and every further member in the include list below (the list IS the index: token law · ws alphabet ·
#   unicode cures · textlaw · reserved adjacency · condition modes · heading recognizer · registration ·
#   profile snapshot · flavor profile · latex flavor · ensure token · inert semantics ·
#   record schema (v0.4 T1) · registry lifecycle (v0.4 T2)); each include line carries its one-liner.
# REASONING: the byte-exact golden layer cannot see these concerns — the introspected public surface and
#       the stable refusal messages — so each lives in its own self-contained file.
# PURPOSE: one stable index for the unit layer.

using Test

@testset "unit" begin
    include(joinpath(@__DIR__, "public_surface_tests.jl"))
    include(joinpath(@__DIR__, "slot_overflow_tests.jl"))           # guarded refusal witnesses for slot action capacity
    include(joinpath(@__DIR__, "malformed_meta_tests.jl"))          # guarded refusal witnesses for malformed metaLine input
    include(joinpath(@__DIR__, "error_message_tests.jl"))           # stable error-message witnesses
    include(joinpath(@__DIR__, "arg_guard_tests.jl"))               # action-args refusal witnesses
    include(joinpath(@__DIR__, "condition_cap_tests.jl"))           # guarded refusal witnesses for the condition scan cap (E-02)
    include(joinpath(@__DIR__, "token_law_tests.jl"))               # F-13 token-delimiter-law verification matrix (owner-ruled 2026-08-08)
    include(joinpath(@__DIR__, "ws_alphabet_tests.jl"))             # F-14 ws-alphabet matrix (owner-ruled 2026-08-08: Unicode \h unified; GENERATED file, real codepoints)
    include(joinpath(@__DIR__, "unicode_cure_tests.jl"))            # R-U4 cure witnesses (the Unicode program W1; GENERATED, real codepoints)
    include(joinpath(@__DIR__, "textlaw_tests.jl"))                # W2 kernel conformance (pinned alphabets + nfc_key; behavior-zero, unwired)
    include(joinpath(@__DIR__, "reserved_adjacency_tests.jl"))      # directive-adjacency SHIP-CLASS tripwire (the 0.2.3 cure; ships)
    include(joinpath(@__DIR__, "condition_modes_tests.jl"))         # the dual-mode law (safe default + explicit opt-in)
    include(joinpath(@__DIR__, "heading_recognizer_tests.jl"))      # v0.2 CH-3 step 8: String-lane widening + quote negative rows (APPEND-ONLY)
    include(joinpath(@__DIR__, "registration_tests.jl"))            # v0.2 registration build: the record + the arming guard (APPEND-ONLY; the clash law and the atomic refusals left at stage 5's E4)
    include(joinpath(@__DIR__, "profile_snapshot_tests.jl"))        # v0.2 full arming: profile snapshot digests + error oracle (APPEND-ONLY)
    include(joinpath(@__DIR__, "flavor_profile_tests.jl"))          # WP1-W1 (F-17): FlavorProfile record + threading witnesses (APPEND-ONLY)
    include(joinpath(@__DIR__, "latex_flavor_tests.jl"))            # WP1-W5 (F-22): the FLAVOR_LATEX pure-data acceptance battery (APPEND-ONLY)
    include(joinpath(@__DIR__, "ensure_token_tests.jl"))            # WP1-W6 step (b): the ensure-token witness battery (K1 second disjunct; APPEND-ONLY)
    include(joinpath(@__DIR__, "inert_semantics_tests.jl"))         # v0.3.1: the R-INERT-4 differential oracle + §4.1 refusal + §4.8 Alterant guards (APPEND-ONLY)
    include(joinpath(@__DIR__, "record_schema_tests.jl"))           # v0.4 T1: the registration-record schema extension witnesses (APPEND-ONLY)
    include(joinpath(@__DIR__, "registry_lifecycle_tests.jl"))      # v0.4 T2: Builder → validate → publish, the one chain, the STRICT door, the seal gate, the exhaustion refusals (APPEND-ONLY)
    include(joinpath(@__DIR__, "snapshot_property_tests.jl"))       # v0.4 T2-bis: the snapshot door's PROPERTY proof (N=1024 site mutations + FP rebuilds + named cases; T2BIS-DESIGN §9)
    include(joinpath(@__DIR__, "seam_envelope_tests.jl"))           # v0.4 T3: the seams — query/validate/ctor envelopes, store identity (T3-DESIGN §8; DEP_MISSING left at stage 5's E4, the state-seam ledger at E2)
    include(joinpath(@__DIR__, "vocabulary_tests.jl"))              # v0.4 T4's whitelist relocation, trimmed at stage 5's E9: the plain file's membership, the zero-literal law, the crx cure witnesses
    include(joinpath(@__DIR__, "fallback_order_tests.jl"))          # stage 2 commit 3a (R-V04B-55 (3)): the fallBack level consulted LAST — three witnesses over a prepared slot
    include(joinpath(@__DIR__, "userfeed_visib_tests.jl"))        # stage 2 commit 7b (REAL-1 R2 #13): the fed Visib verdict against an authored one — four witnesses at the public entry
    include(joinpath(@__DIR__, "origin_tests.jl"))                  # stage 2 commit 2 (R-V04B-35 (d)): the provenance field decided_by — recorded at the enqueue, carried through the apply, captured with the row
    include(joinpath(@__DIR__, "answer_tests.jl"))                  # stage 2 commit 4 (R-V04B-35 (c)): THE ONE ANSWER FUNCTION — seven witnesses over measured rows
    include(joinpath(@__DIR__, "scan_tests.jl"))                    # stage 2 commit 5 (his 9.A; the plan :57): the scan by Alterant and the access by Component — six witnesses
    include(joinpath(@__DIR__, "childdiff_tests.jl"))               # stage 2 commit 6 (R-V04B-35 (e)): the child-differs signal — four witnesses over measured rows
    include(joinpath(@__DIR__, "capture_tests.jl"))                 # v0.4 T5: the capture re-home — the registration-driven walk (the sadd2 anti-T1 cure), the per-plugin localOnly flush, the mode-gate laws (T5-DESIGN §6; the floor, gate and algebra witnesses left at stage 5's E5)
    include(joinpath(@__DIR__, "renderer_free_process_tests.jl"))  # stage 1 commit 5 (REAL-1 #6): ONE fresh child process with `import GoMeta` only — the delivered object needs no development tool
end
