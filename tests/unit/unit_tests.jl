# unit_tests.jl — the UNIT layer aggregator: one `@testset "unit"` umbrella that includes every per-concern
#   unit file, in a fixed order.
#
# IS:   the unit layer's index, dispatched by tests/runtests.jl as the "unit" layer. It holds no assertions
#       of its own; each included member self-contains its own `using Test` + `import GoMeta as GM` and
#       contributes one focused @testset. Some members reference the shared `TestSupport` module, which
#       tests/runtests.jl loads once before the layers — so members run via the dispatcher, not standalone.
# DOES: wires the per-concern members, in order:
#   - public_surface_tests.jl — the export set equals the declared semver surface (docs/public-api.md §1)
#                               and the two output surfaces are sole.
#   - slot_overflow_tests.jl  — witnesses for the "GoMeta absorb: slot action capacity" refusal.
#   - malformed_meta_tests.jl — witnesses for the "GoMeta absorb: malformed metaLine" refusal.
#   - error_message_tests.jl  — stable-message witnesses, e.g. "GoMeta apply: unknown label".
#   - arg_guard_tests.jl      — witnesses for the "GoMeta apply: invalid arguments" refusal at the
#                               action-args seam.
#   - condition_cap_tests.jl  — witnesses for the condition-length-cap refusal.
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
    include(joinpath(@__DIR__, "registration_tests.jl"))            # v0.2 registration build: the record + clash law + atomic refusals (APPEND-ONLY)
    include(joinpath(@__DIR__, "profile_snapshot_tests.jl"))        # v0.2 full arming: profile snapshot digests + error oracle (APPEND-ONLY)
    include(joinpath(@__DIR__, "flavor_profile_tests.jl"))          # WP1-W1 (F-17): FlavorProfile record + threading witnesses (APPEND-ONLY)
    include(joinpath(@__DIR__, "carrier_seam_tests.jl"))            # WP1-W2: run_absorb_apply! seam + validate_carrier_state witnesses (APPEND-ONLY)
    include(joinpath(@__DIR__, "latex_flavor_tests.jl"))            # WP1-W5 (F-22): the FLAVOR_LATEX pure-data acceptance battery (APPEND-ONLY)
    include(joinpath(@__DIR__, "ensure_token_tests.jl"))            # WP1-W6 step (b): the ensure-token witness battery (K1 second disjunct; APPEND-ONLY)
    include(joinpath(@__DIR__, "inert_semantics_tests.jl"))         # v0.3.1: the R-INERT-4 differential oracle + §4.1 refusal + §4.8 Alterant guards (APPEND-ONLY)
end
