# tests/unit/flavor_profile_tests.jl — WP1-W1 (F-17) + WP1-W3 (F-18): FlavorProfile
# record + threading witnesses (SYNTHESIS-JUDGE §3 rows WP1-W1/W3; APPEND-ONLY in
# the rows-only-grow sense — the F-18 record reshape trued the construction kwargs
# and the [3] identity pins to the live regime, the declared witness churn).
#
# Covers: construction green for both armed records; the seven prototype fields
# VERBATIM-pinned; the directive TABLE rows (now with the F-18 consume verbs); the
# glued/bare policies + the run-arm strictness; the parse_header! seam identity +
# the header_strategy pins (the half-flip guard: pointer + strategy pinned side by
# side); the lead codeunit generalization; digest PROPERTIES (determinism +
# cross-flavor distinctness + data/strategy/consume/strict sensitivity +
# pointer-excluded — deliberately NO pinned UInt64); the record guards (incl. the
# F-18 collision/strategy/consume vocabularies + the positional-constructor
# removal); ParseState threading (setup default · kwarg · goMeta resolve-once for
# BOTH armed tags + the typed invalid-tag path).

using Test
import GoMeta as GM
const _FP_BLS = GM.BLS

_fp_bytes(s::String) = Vector{UInt8}(codeunits(s))

## A legal non-julia flavor kwarg set for guard/INTERIM-law witnesses (passes every
## construction value guard; LaTeX-shaped on purpose — the W5 data point's silhouette).
_fp_latexish_kwargs(; directives, flavor_tag = :latexish) = (
    flavor_tag       = flavor_tag,
    lead             = "%",
    comment_run_char = '%',
    hide_marker      = "%% ",
    hide_fold_prefix = "%%",
    extensions       = (".tex",),
    directives       = directives,
    glued_policy     = :comment,
    bare_policy      = :comment,
    parse_header!    = _FP_BLS.parseLeadHeader!,
    fences_armed     = false,
    comment_run_strict = false,
    header_strategy  = :table_v1,
)

const _FP_ABSENT4 = (
    (char = '-', status = :absent, flags = (), ws_strict = false, consume = :single),
    (char = '+', status = :absent, flags = (), ws_strict = false, consume = :single),
    (char = '>', status = :absent, flags = (), ws_strict = false, consume = :single),
    (char = '[', status = :absent, flags = (), ws_strict = false, consume = :single),
)
const _FP_CLOSE_ROW = (char = ']', status = :claimed, flags = (:startNewBlock,
    :ignoreThisMeta, :containsMeta, :stopAttachmentToMeta), ws_strict = true,
    consume = :single)

## The julia construction kwargs, shared by the [4] digest twins (F-18: 13 kwargs —
## the W1-era 11 + comment_run_strict + header_strategy).
_fp_julia_kwargs(; overrides...) = merge((
    flavor_tag       = :julia,
    lead             = "#",
    comment_run_char = '#',
    hide_marker      = "## ",
    hide_fold_prefix = "##",
    extensions       = (".jl",),
    directives       = _FP_BLS.FLAVOR_JULIA.directives,
    glued_policy     = :content,
    bare_policy      = :content,
    parse_header!    = _FP_BLS.parseLeadHeader!,
    fences_armed     = true,
    comment_run_strict = true,
    header_strategy  = :table_v1,
), NamedTuple(overrides))

@testset "flavor_profile_tests (WP1-W1 record + threading)" begin

    @testset "[1] construction + the seven prototype fields, verbatim" begin
        @test _FP_BLS.FLAVOR_JULIA isa _FP_BLS.FlavorProfile
        @test _FP_BLS.FLAVOR_CFAM  isa _FP_BLS.FlavorProfile
        jl = _FP_BLS.FLAVOR_JULIA; cf = _FP_BLS.FLAVOR_CFAM
        @test jl.flavor_tag === :julia && cf.flavor_tag === :c
        @test jl.lead == "#" && cf.lead == "//"
        @test jl.comment_run_char == '#' && cf.comment_run_char == '/'
        @test jl.hide_marker == "## " && cf.hide_marker == "//# "
        @test jl.hide_fold_prefix == "##" && cf.hide_fold_prefix == "//"
        @test jl.extensions == (".jl",) && cf.extensions == (".c", ".h", ".rs")
        ## The compat aliases ARE the records' fields (identity, not equality).
        @test jl.re_meta_leaded === _FP_BLS._RE_META_LEADED_JULIA
        @test cf.re_meta_leaded === _FP_BLS._RE_META_LEADED_CFAM
    end

    @testset "[2] the directive TABLE (the deletion-note shape) + policies" begin
        jl = _FP_BLS.FLAVOR_JULIA; cf = _FP_BLS.FLAVOR_CFAM
        @test map(r -> r.char, jl.directives) == ('-', '+', '>', '[', ']')
        @test map(r -> r.char, cf.directives) == ('-', '+', '>', '[', ']')
        @test all(r -> r.status === :claimed, jl.directives)
        ## Julia rows carry the dispatch flags (byte-derived at F-17 from the
        ## then-live parseHashHeader! — retired F-21; the table is the sole
        ## encoding now and these pins ARE its witnesses).
        @test jl.directives[1].flags == (:startNewBlock,)
        @test jl.directives[2].flags == (:continued,)
        @test jl.directives[3].flags == (:insertSubContent,)
        @test jl.directives[4].flags == (:startNewBlock,)
        @test jl.directives[5].flags == (:startNewBlock, :ignoreThisMeta,
            :containsMeta, :stopAttachmentToMeta)
        @test jl.directives[5].ws_strict && !jl.directives[1].ws_strict
        ## WP1-W3 (F-18): the consume verbs — the offset convention as table data
        ## (`-` run-consumes; every other arm single-unit).
        @test map(r -> r.consume, jl.directives) == (:run, :single, :single, :single, :single)
        @test all(r -> r.consume === :single, cf.directives)
        ## cfam: the four Literate arms :absent (flag-free); `]` claimed verbatim.
        @test all(r -> r.status === :absent && isempty(r.flags), cf.directives[1:4])
        @test cf.directives[5].status === :claimed && cf.directives[5].ws_strict
        @test cf.directives[5].flags == jl.directives[5].flags
        ## Policies: julia = the bucket-A sentinel class; cfam = the every-arm comment class.
        @test jl.glued_policy === :content && jl.bare_policy === :content
        @test cf.glued_policy === :comment && cf.bare_policy === :comment
        @test jl.fences_armed && !cf.fences_armed
        ## WP1-W3 (F-18): the run-arm strictness — julia exact-`##` (F-13), cfam any-run.
        @test jl.comment_run_strict && !cf.comment_run_strict
    end

    @testset "[3] the parse_header! seam + the lead generalization" begin
        ## WP1-W3 (F-18): the LIVE regime pins — pointer AND strategy side by side
        ## (the half-flip guard: a fallback flip that edits one and forgets the
        ## other REDs here instead of aliasing the digest).
        @test _FP_BLS.FLAVOR_JULIA.parse_header! === _FP_BLS.parseLeadHeader!
        @test _FP_BLS.FLAVOR_JULIA.header_strategy === :table_v1
        ## F-20 (WP1-W4): the cfam pins flip WITH the route (pointer + strategy
        ## together — the half-flip law).
        @test _FP_BLS.FLAVOR_CFAM.parse_header!  === _FP_BLS.parseLeadHeader!
        @test _FP_BLS.FLAVOR_CFAM.header_strategy === :table_v1
        @test _FP_BLS.FLAVOR_JULIA.lead_ncu == 1
        @test _FP_BLS.FLAVOR_JULIA.lead_cus == (UInt8('#'),)
        @test _FP_BLS.FLAVOR_CFAM.lead_ncu == 2
        @test _FP_BLS.FLAVOR_CFAM.lead_cus == (UInt8('/'), UInt8('/'))
        ## The record values equal the standing consts (the _CFAM_LEAD_* generalization).
        @test _FP_BLS.FLAVOR_CFAM.lead_ncu == _FP_BLS._CFAM_LEAD_NCU
        @test _FP_BLS.FLAVOR_CFAM.lead_cus == _FP_BLS._CFAM_LEAD_CU
    end

    @testset "[4] digest properties (NO pinned constant — the fold reshapes with the table)" begin
        jl = _FP_BLS.FLAVOR_JULIA; cf = _FP_BLS.FLAVOR_CFAM
        ## Determinism: an identical reconstruction folds to the identical digest.
        twin = _FP_BLS._mk_flavor(; _fp_julia_kwargs()...)
        @test twin.digest == jl.digest
        ## Cross-flavor distinctness.
        @test jl.digest != cf.digest
        ## Data sensitivity: one changed declared value moves the digest (a legal
        ## variant — "##\t" passes every value guard).
        variant = _FP_BLS._mk_flavor(; _fp_julia_kwargs(hide_marker = "##\t")...)
        @test variant.digest != jl.digest
        ## The parse_header! FUNCTION deliberately does not join the fold (behavior
        ## identity is the differential harness's job, never a function pointer's;
        ## the STRATEGY is the fold's proxy for the regime — CRX finding A): a twin
        ## differing ONLY in the pointer (same strategy) folds identically. (F-21:
        ## the retired earlier adapter gave way to `identity` as the distinct
        ## Function — the guard never validates the pointer, which is the point.)
        fn_twin = _FP_BLS._mk_flavor(;
            _fp_julia_kwargs(parse_header! = identity)...)
        @test fn_twin.digest == jl.digest
        ## WP1-W3 (F-18) sensitivity rows — every new behavior-bearing datum moves
        ## the fold (the design-panel convergent injectivity finding):
        ## (a) the strategy identifier;
        strat_twin = _FP_BLS._mk_flavor(;
            _fp_julia_kwargs(header_strategy = :legacy_hash)...)
        @test strat_twin.digest != jl.digest
        ## (b) one row's consume verb (:run → :single on the `-` row);
        consume_rows = ((char = '-', status = :claimed, flags = (:startNewBlock,),
            ws_strict = false, consume = :single), jl.directives[2:5]...)
        consume_twin = _FP_BLS._mk_flavor(; _fp_julia_kwargs(directives = consume_rows)...)
        @test consume_twin.digest != jl.digest
        ## (c) the run-arm strictness Bool.
        strict_twin = _FP_BLS._mk_flavor(;
            _fp_julia_kwargs(comment_run_strict = false)...)
        @test strict_twin.digest != jl.digest
    end

    @testset "[5] record guards + the INTERIM reserved-arms law" begin
        ## The INTERIM law: a NON-julia flavor claiming a reserved arm REFUSES at
        ## construction (LaTeX-shaped witness — the W5 data point lands :absent).
        bad_claim = (
            (char = '-', status = :claimed, flags = (:startNewBlock,), ws_strict = false,
                consume = :run),
            _FP_ABSENT4[2:4]...,
            _FP_CLOSE_ROW,
        )
        @test_throws AssertionError _FP_BLS._mk_flavor(;
            _fp_latexish_kwargs(directives = bad_claim)...)
        ## The legal non-julia shape constructs green (all-absent + claimed close).
        ok = _FP_BLS._mk_flavor(;
            _fp_latexish_kwargs(directives = (_FP_ABSENT4..., _FP_CLOSE_ROW))...)
        @test ok isa _FP_BLS.FlavorProfile
        ## Row-set guard: a wrong char order refuses.
        @test_throws AssertionError _FP_BLS._mk_flavor(;
            _fp_latexish_kwargs(directives = (_FP_ABSENT4[2], _FP_ABSENT4[1],
                _FP_ABSENT4[3], _FP_ABSENT4[4], _FP_CLOSE_ROW))...)
        ## The lifted `]`-invariant: :containsMeta without :ignoreThisMeta refuses.
        bad_meta_row = (char = ']', status = :claimed,
            flags = (:startNewBlock, :containsMeta, :stopAttachmentToMeta),
            ws_strict = true, consume = :single)
        @test_throws AssertionError _FP_BLS._mk_flavor(;
            _fp_latexish_kwargs(directives = (_FP_ABSENT4..., bad_meta_row))...)
        ## An :absent row carrying flags refuses.
        bad_absent = (char = '-', status = :absent, flags = (:startNewBlock,),
            ws_strict = false)
        @test_throws AssertionError _FP_BLS._mk_flavor(;
            _fp_latexish_kwargs(directives = (bad_absent, _FP_ABSENT4[2:4]...,
                _FP_CLOSE_ROW))...)
        ## The status-vocabulary guard: an out-of-domain status refuses (cure round —
        ## the round-1 ceremony seat found this guard witness-free). UNIQUE TARGETING:
        ## julia-tagged so the INTERIM law short-circuits, flags empty so the
        ## absent-guard passes — deleting the status-domain assert would construct
        ## GREEN and flip exactly this row red.
        bad_status_rows = ((char = '-', status = :maybe, flags = (), ws_strict = false,
            consume = :single),
            _FP_BLS.FLAVOR_JULIA.directives[2:5]...)
        @test_throws AssertionError _FP_BLS._mk_flavor(;
            _fp_julia_kwargs(directives = bad_status_rows)...)
        ## ── WP1-W3 (F-18) guard witnesses ──
        ## The consume-vocabulary guard: an out-of-domain verb refuses (unique
        ## targeting mirrors the status witness: julia-tagged, flags empty).
        bad_consume_rows = ((char = '-', status = :claimed, flags = (:startNewBlock,),
            ws_strict = false, consume = :gulp),
            _FP_BLS.FLAVOR_JULIA.directives[2:5]...)
        @test_throws AssertionError _FP_BLS._mk_flavor(;
            _fp_julia_kwargs(directives = bad_consume_rows)...)
        ## The strategy-vocabulary guard.
        @test_throws AssertionError _FP_BLS._mk_flavor(;
            _fp_julia_kwargs(header_strategy = :bogus)...)
        ## The run-char collision guard (delta-panel cure): a lead whose run char
        ## lands in the reader's other arm triggers refuses at mint — '~' here;
        ## every EARLIER guard passes (ASCII lead; hide marker "~x " has a
        ## comment-class second char; run char == last(lead)), so only the
        ## collision assert can fire.
        @test_throws AssertionError _FP_BLS._mk_flavor(; flavor_tag = :tildeish,
            lead = "~", comment_run_char = '~', hide_marker = "~x ",
            hide_fold_prefix = "~", extensions = (".t",),
            directives = (_FP_ABSENT4..., _FP_CLOSE_ROW),
            glued_policy = :comment, bare_policy = :comment,
            parse_header! = _FP_BLS.parseLeadHeader!, fences_armed = false,
            comment_run_strict = false, header_strategy = :legacy_slash)
        ## The policy-vocabulary guards (W4-close panel cure): an out-of-domain
        ## policy Symbol refuses at mint (the reader's === compares would silently
        ## comment-ize a typo).
        @test_throws AssertionError _FP_BLS._mk_flavor(;
            _fp_julia_kwargs(glued_policy = :contnet)...)
        @test_throws AssertionError _FP_BLS._mk_flavor(;
            _fp_julia_kwargs(bare_policy = :komment)...)
        ## The positional constructor CEASED TO EXIST at F-18 (the inner keyword
        ## constructor replaced it — the W1 CONSTRUCTION-LAW hazard closed
        ## mechanically): positional construction throws MethodError.
        @test_throws MethodError _FP_BLS.FlavorProfile(:julia, "#", '#', "## ",
            "##", (".jl",), r"^x", _FP_BLS.FLAVOR_JULIA.directives, :content,
            :content, _FP_BLS.parseLeadHeader!, true, true, :table_v1, 1,
            (UInt8('#'),), UInt64(0))
    end

    @testset "[6] ParseState threading (setup default · kwarg · goMeta resolve-once)" begin
        st_default = _FP_BLS.setUpToProcessFromBytes(_fp_bytes("x = 1\n"))
        @test st_default.flavor === _FP_BLS.FLAVOR_JULIA
        st_c = _FP_BLS.setUpToProcessFromBytes(_fp_bytes("// x\n");
            flavor = _FP_BLS.FLAVOR_CFAM)
        @test st_c.flavor === _FP_BLS.FLAVOR_CFAM
        ## goMeta resolves ONCE post-validation and threads the record: the state
        ## carries the CONFIG's flavor for BOTH armed tags (the behavior-safety row —
        ## a :c state must never carry the julia record).
        r_jl = GM.goMeta(_fp_bytes("#~ hide\nx = 1\n"))
        @test r_jl.state.parse.flavor === _FP_BLS.FLAVOR_JULIA
        r_c = GM.goMeta(_fp_bytes("//~ hide\nint x;\n");
            config = GM.GoMetaConfig(flavor_tag = :c))
        @test r_c.state.parse.flavor === _FP_BLS.FLAVOR_CFAM
        ## The invalid-tag path keeps its TYPED refusal (the resolve-once placement
        ## law: flavor_for must never see an unvalidated tag).
        r_bad = GM.goMeta(_fp_bytes("x\n");
            config = GM.GoMetaConfig(flavor_tag = :cobol))
        @test r_bad.status === GM.PROCESS_ERROR
        @test any(d -> d.code === :ERR_UNKNOWN_FLAVOR, r_bad.diagnostics)
    end
end
