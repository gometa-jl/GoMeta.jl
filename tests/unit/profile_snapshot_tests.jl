# tests/unit/profile_snapshot_tests.jl — v0.2 full arming: the canonicalized profile
# snapshot + the profile error oracle (APPEND-ONLY).
#
# IS:   the witnesses of the profile provenance substrate: the registration digest's
#       CANONICALIZATION (multi-order determinism over ACTION-SPEC and OVERLOAD-ROW order — plugin
#       order is index-bearing and folds as declared), its SNAPSHOT-NOT-LIVE purity (a spec vector backed by NO real methods
#       digests identically well — a live method-table consult would refuse or drift), the
#       BOOTSTRAP pins of the default profile's two digests (any grammar or registration
#       drift trips a conscious re-pin), the cache-key composition point, and the error
#       oracle's corrupt/incompatible arms (constructed bad records — the always-passing
#       resolve path is not the witness). The unknown-profile arm is pinned in
#       condition_interp_tests.jl; the missing-opt-in arm is pinned in
#       condition_modes_tests.jl (order-coupled to the one file that performs the opt-in
#       include — deliberately not duplicated here).
# PURPOSE: plan row 12's gate — the profile snapshot + error oracle witnessed.

using Test
import GoMeta as GM

@testset "full arming — profile snapshot + error oracle" begin

    # synthetic, method-LESS specs (no setter anywhere carries these signatures), with
    # plugin indices FAR OFF the real plugin table (a live consult of methods() or of
    # DEFAULT_REGISTRY.plugins would error on them — hardened at the panel round): the
    # digest must treat the record as pure DATA
    _syn(name; plugin = 99, sig = Type[Dict{Symbol,Bool}, Symbol, Int],
         kinds = Symbol[:symbol], srcs = Symbol[:declared], validate = nothing) =
        GM.ActionSpec(
        name, :identifier, Int8(plugin),
        [GM.ActionOverload(sig, kinds, srcs, nothing, Nothing, :set, false,
            :context_free, :apply, true)],
        0, :none, validate, nothing)

    @testset "test_registration_digest_multi_order_determinism" begin
        specs = [_syn(:zza), _syn(:zzb; plugin = 98), _syn(:zzc; plugin = 97)]
        d0 = GM._registration_digest(specs)
        @test d0 isa UInt64
        @test GM._registration_digest(specs) == d0                       # repeat ≡
        @test GM._registration_digest(reverse(specs)) == d0              # reversed ≡
        @test GM._registration_digest(specs[[2, 3, 1]]) == d0            # permuted ≡
        # overload-row order inside ONE spec is canonicalized too
        two = GM.ActionSpec(:zzd, :identifier, Int8(1),
            [GM.ActionOverload(Type[Dict{Symbol,Bool}, Symbol], Symbol[], Symbol[],
                 nothing, Nothing, :set, false, :context_free, :apply, true),
             GM.ActionOverload(Type[Dict{Symbol,Bool}, Symbol, Int], Symbol[:symbol],
                 Symbol[:declared], nothing, Nothing, :set, false, :context_free,
                 :apply, true)],
            0, :none, nothing, nothing)
        two_r = GM.ActionSpec(:zzd, :identifier, Int8(1),
            reverse(two.overloads), 0, :none, nothing, nothing)
        @test GM._registration_digest([two]) == GM._registration_digest([two_r])
        # and the digest SEES record content (not just names): a changed declared
        # return type moves the fingerprint
        rt = GM.ActionSpec(:zza, :identifier, Int8(1),
            [GM.ActionOverload(Type[Dict{Symbol,Bool}, Symbol, Int], Symbol[:symbol],
                 Symbol[:declared], nothing, Bool, :set, false, :context_free,
                 :apply, true)],
            0, :none, nothing, nothing)
        @test GM._registration_digest([rt]) != GM._registration_digest([_syn(:zza)])
        # parameter-faithful type text: a changed type PARAMETER moves the fingerprint
        pt = _syn(:zza; sig = Type[Dict{Symbol,Int}, Symbol, Int])
        @test GM._registration_digest([pt]) != GM._registration_digest([_syn(:zza)])
        # validate folds by IDENTITY (function name), not presence (panel-cured):
        # swapping the validator moves the fingerprint
        _va(x) = nothing; _vb(x) = nothing
        @test GM._registration_digest([_syn(:zza; validate = _va)]) !=
              GM._registration_digest([_syn(:zza; validate = _vb)])
        @test GM._registration_digest([_syn(:zza; validate = _va)]) !=
              GM._registration_digest([_syn(:zza)])
        # plugin declaration data folds when supplied (panel-cured): a set-mode flip
        # moves the fingerprint; the same plugins leave it stable
        pl1 = [GM.PlugIn(:zz, :accumulate, Dict{Symbol,Bool}, identity, nothing, nothing)]
        pl2 = [GM.PlugIn(:zz, :localOnly, Dict{Symbol,Bool}, identity, nothing, nothing)]
        @test GM._registration_digest(specs; plugins = pl1) ==
              GM._registration_digest(specs; plugins = pl1)
        @test GM._registration_digest(specs; plugins = pl1) !=
              GM._registration_digest(specs; plugins = pl2)
        @test GM._registration_digest(specs; plugins = pl1) !=
              GM._registration_digest(specs)
        # plugin ORDER is index-bearing and folds as declared (the header's claim, witnessed —
        # t2r4 C-11): the same two plugins in the other order move the fingerprint
        plq = GM.PlugIn(:zq, :accumulate, Dict{Symbol,Bool}, identity, nothing, nothing)
        @test GM._registration_digest(specs; plugins = [pl1[1], plq]) !=
              GM._registration_digest(specs; plugins = [plq, pl1[1]])
        # clash-arm-W shape: the digest fingerprints the EFFECTIVE first-wins record —
        # a same-named loser spec never moves it (panel-cured)
        loser = _syn(:zza; sig = Type[Dict{Symbol,Bool}, Symbol])
        @test GM._registration_digest([_syn(:zza), loser]) ==
              GM._registration_digest([_syn(:zza)])
        # INJECTIVITY of the component fold (external-review-cured): delimiter-bearing
        # field values can never re-arrange into a colliding serialization — the
        # length-prefixed fold distinguishes what a naive joined text would conflate
        @test GM._fold_parts(GM._FNV_OFFSET, "a|b", "c") !=
              GM._fold_parts(GM._FNV_OFFSET, "a", "b|c")
        @test GM._fold_parts(GM._FNV_OFFSET, "ab", "") !=
              GM._fold_parts(GM._FNV_OFFSET, "a", "b")
    end

    @testset "test_profile_snapshot_not_live" begin
        # the specs above are backed by NO executable method anywhere AND their plugin
        # indices point far off the real plugin table — a digest that consulted live
        # method tables (`methods`/`hasmethod`) or resolved plugins through
        # DEFAULT_REGISTRY would error or drift; the pure-data fold computes, stably
        specs = [_syn(:zza), _syn(:zzb; plugin = 98)]
        d1 = GM._registration_digest(specs)
        d2 = GM._registration_digest(deepcopy(specs))
        @test d1 == d2
        # record→const linkage (NOT a purity witness — recomputes the const's own
        # construction path; the purity witness is the method-less fold above):
        # recomputing from the record reproduces the const's stored value
        @test GM._registration_digest(GM.DEFAULT_REGISTRY.action_specs;
                  plugins = GM.DEFAULT_REGISTRY.plugins) ==
              GM.DEFAULT_GRAMMAR_PROFILE.registration_digest
    end

    @testset "test_bootstrap_fixed_base_grammar" begin
        # the BOOTSTRAP pins: literal fingerprints of the pinned base grammar + the
        # declared registration record. Any drift in caps/precedence/grants/mode or in
        # the declared inventory trips one of these — a CONSCIOUS re-pin is the only
        # green path. (FNV-1a over canonical text — deterministic across sessions and
        # Julia versions; not `Base.hash`.)
        # (pins RE-MINTED twice, both consciously: at the full-arming panel round the
        # fold gained validate-identity + plugin data + first-wins dedup; at the
        # external-review round BOTH folds moved to the injective length-prefixed
        # component serialization, and the cache key gained the engine-version
        # component — asserted composition-wise so the pin is version-agnostic
        # across the two build variants)
        # (registration pin RE-MINTED a third time, consciously, at v0.4 T2: the fold was
        # EXTENDED over every declared record slot so the publication SEAL covers the record
        # (0x887ec3b4c760dc70 → 0x29012b84e8284212, registered at the build's T1 close; the
        # grammar pin did NOT move — a moved grammar pin here would mean the fold touched
        # what it must not)
        # (registration pin RE-MINTED a FOURTH time, consciously, at the after-T2 CRX cure batch:
        # the slot encoding gained length-prefixed element boundaries (a boundary can no longer be
        # re-cut; NOT global injectivity — see the lifecycle tests' header) and the fold gained the setter/getter
        # names + precedencesTuple — 0x29012b84e8284212 → 0xd9356f388ea12597; the grammar pin
        # still unmoved)
        # (a FIFTH re-mint at cure batch 2: the encoding now tags the concrete numeric type and
        # distinguishes tuples from vectors — 0xd9356f388ea12597 → 0x33c214cef7ea13d3; grammar
        # pin unmoved)
        # (the SIXTH re-mint at v0.4 T4 — DECLARED in T4-DESIGN §7 BEFORE the run that learned
        # it: the labels record's vocabulary slot moved from `nothing` to the VocabularyRef pin
        # + its provenance gained the independent policy_id — the registration fold covers both
        # slots, so the record change re-mints — 0x33c214cef7ea13d3 → 0x10720f0a578f8d6b, at
        # exactly TWO loci (this pin + the cache_key r-component below); the grammar pin
        # asserted UNMOVED — a move there is STOP-and-diagnose, the fold touched what it must not)
        # (the SEVENTH re-mint at v0.4 T5 — DECLARED in T5-DESIGN §1 BEFORE the run that
        # learned it: every DEFAULT record's capture slot moved from `nothing` to its
        # declared CaptureDecl row, the CaptureDecl schema gained the attr_stem field,
        # and `_slot_text(::CaptureDecl)` gained the stem as a FIFTH seal component —
        # 0x10720f0a578f8d6b → 0x014a5cb7a2c21a4e, at the SAME two loci; the grammar
        # pin asserted UNMOVED as always)
        p = GM.resolve_profile(GM.GoMetaConfig())
        @test p.grammar_digest      == 0x12972c9924c2bf2b
        @test p.registration_digest == 0x014a5cb7a2c21a4e
        @test GM.cache_key(p) == string("gometa/v", GM._ENGINE_VERSION,
            "/jl_share_v1/closed_v1/s3/g12972c9924c2bf2b/r14a5cb7a2c21a4e")   # the r-component re-minted with the pin above (v0.4 T5 = the seventh)
    end

    @testset "test_error_oracle_corrupt_and_incompatible" begin
        ok = GM.DEFAULT_GRAMMAR_PROFILE
        # the oracle returns the profile it blessed
        @test GM._profile_wellformed_check(ok) === ok
        _mk(; schema = ok.schema_version, outer = ok.outer_scan_cap,
             grants = ok.grants, mode = ok.mode, prec = ok.precedence,
             gdig = ok.grammar_digest, mcb = ok.max_condition_bytes) =
            GM.GrammarProfile(schema, ok.name, grants, outer, ok.inner_scan_cap,
                mcb, ok.max_parser_depth, prec, mode,
                ok.registration_digest, gdig)
        _err(p) = (try GM._profile_wellformed_check(p); nothing catch e; e end)
        # INCOMPATIBLE: an alien schema names the supported set — never a fallback
        e = _err(_mk(; schema = 0x7f))
        @test e isa ErrorException && occursin("INCOMPATIBLE", e.msg) &&
              occursin("NO fallback", e.msg)
        # CORRUPT: non-positive cap
        e = _err(_mk(; outer = 0))
        @test e isa ErrorException && occursin("CORRUPT", e.msg) &&
              occursin("positive", e.msg)
        # CORRUPT: unknown grant
        e = _err(_mk(; grants = (:colon_labels, :nope)))
        @test e isa ErrorException && occursin("CORRUPT", e.msg) &&
              occursin("grant", e.msg)
        # CORRUPT: unknown mode
        e = _err(_mk(; mode = :nope))
        @test e isa ErrorException && occursin("CORRUPT", e.msg) &&
              occursin("mode", e.msg)
        # CORRUPT: precedence table off the closed shape
        e = _err(_mk(; prec = (:not => 5, :and => 4, :or => 3, :sc_and => 2, :sc_or => 5)))
        @test e isa ErrorException && occursin("CORRUPT", e.msg) &&
              occursin("precedence", e.msg)
        # CORRUPT: cross-field inconsistency — individually valid fields, mutually
        # inconsistent (the raw-byte wall below the inner scan cap; the external
        # review's relational-validation arm)
        e = _err(_mk(; mcb = 7))
        @test e isa ErrorException && occursin("CORRUPT", e.msg) &&
              occursin("cross-field", e.msg)
        # CORRUPT: field-valid record with a LYING stored digest — the consistency arm
        # re-folds the record's own fields (panel-commissioned at the full-arming round)
        e = _err(_mk(; gdig = ok.grammar_digest ⊻ 0x01))
        @test e isa ErrorException && occursin("CORRUPT", e.msg) &&
              occursin("re-fold", e.msg)
        # the RESOLVE path routes through the oracle (both arms return blessed records)
        @test GM.resolve_profile(GM.GoMetaConfig()) isa GM.GrammarProfile
    end

    @testset "test_cache_key_composition" begin
        p = GM.DEFAULT_GRAMMAR_PROFILE
        k = GM.cache_key(p)
        @test occursin(String(p.name), k) && occursin(String(p.mode), k)
        @test occursin(string(p.grammar_digest, base = 16), k)
        @test occursin(string(p.registration_digest, base = 16), k)
    end
end
