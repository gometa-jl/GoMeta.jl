# tests/unit/flavor_profile_tests.jl — the FlavorProfile
# record + threading witnesses (APPEND-ONLY in
# the rows-only-grow sense — the record reshape trued the construction kwargs
# and the [3] identity pins to the live regime).
#
# Covers: construction green for both armed records; the five prototype fields (six before the extensions pin was removed)
# VERBATIM-pinned; the directive TABLE rows (now with the consume verbs); the
# glued/bare policies + the run-arm strictness; the lead codeunit generalization; the
# record guards (incl. the collision/consume vocabularies + the positional-constructor
# removal); ParseState threading (setup default · kwarg · goMeta resolve-once for
# BOTH armed tags + the guarded invalid-tag path). (The parse_header! seam identity was removed
# with the header_strategy pins, the digest PROPERTIES testset, the
# extensions pin and the compat-alias identities — each with its subject.)

using Test
import GoMeta as GM
const _FP_BLS = GM.BLS

_fp_bytes(s::String) = Vector{UInt8}(codeunits(s))

## A legal non-julia flavor kwarg set for guard/INTERIM-law witnesses (passes every
## construction value guard; LaTeX-shaped on purpose — the LaTeX record's silhouette).
_fp_latexish_kwargs(; directives, flavor_tag = :latexish) = (
    flavor_tag       = flavor_tag,
    lead             = "%",
    comment_run_char = '%',
    hide_marker      = "%% ",
    hide_fold_prefix = "%%",
    directives       = directives,
    glued_policy     = :comment,
    bare_policy      = :comment,
    fences_armed     = false,
    comment_run_strict = false,
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

## The julia construction kwargs, shared by the guard witnesses (10 kwargs —
## the extensions field, the parse_header! pointer and the header_strategy identifier removed).
_fp_julia_kwargs(; overrides...) = merge((
    flavor_tag       = :julia,
    lead             = "#",
    comment_run_char = '#',
    hide_marker      = "## ",
    hide_fold_prefix = "##",
    directives       = _FP_BLS.FLAVOR_JULIA.directives,
    glued_policy     = :content,
    bare_policy      = :content,
    fences_armed     = true,
    comment_run_strict = true,
), NamedTuple(overrides))

@testset "flavor_profile_tests (record + threading)" begin

    @testset "[1] construction + the five prototype fields, verbatim (the extensions pin removed)" begin
        @test _FP_BLS.FLAVOR_JULIA isa _FP_BLS.FlavorProfile
        @test _FP_BLS.FLAVOR_CFAM  isa _FP_BLS.FlavorProfile
        jl = _FP_BLS.FLAVOR_JULIA; cf = _FP_BLS.FLAVOR_CFAM
        @test jl.flavor_tag === :julia && cf.flavor_tag === :c
        @test jl.lead == "#" && cf.lead == "//"
        @test jl.comment_run_char == '#' && cf.comment_run_char == '/'
        @test jl.hide_marker == "## " && cf.hide_marker == "//# "
        @test jl.hide_fold_prefix == "##" && cf.hide_fold_prefix == "//"
        ## (the extensions pin and the compat-alias identities were removed)
    end

    @testset "[2] the directive TABLE (the deletion-note shape) + policies" begin
        jl = _FP_BLS.FLAVOR_JULIA; cf = _FP_BLS.FLAVOR_CFAM
        @test map(r -> r.char, jl.directives) == ('-', '+', '>', '[', ']')
        @test map(r -> r.char, cf.directives) == ('-', '+', '>', '[', ']')
        @test all(r -> r.status === :claimed, jl.directives)
        ## Julia rows carry the dispatch flags (byte-derived from the
        ## then-live parseHashHeader! — since retired; the table is the sole
        ## encoding now and these pins ARE its witnesses).
        @test jl.directives[1].flags == (:startNewBlock,)
        @test jl.directives[2].flags == (:continued,)
        @test jl.directives[3].flags == (:insertSubContent,)
        @test jl.directives[4].flags == (:startNewBlock,)
        @test jl.directives[5].flags == (:startNewBlock, :ignoreThisMeta,
            :containsMeta, :stopAttachmentToMeta)
        @test jl.directives[5].ws_strict && !jl.directives[1].ws_strict
        ## the consume verbs — the offset convention as table data
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
        ## the run-arm strictness — julia exact-`##`, cfam any-run.
        @test jl.comment_run_strict && !cf.comment_run_strict
    end

    @testset "[3] the lead generalization (the parse_header! seam pins removed)" begin
        @test _FP_BLS.FLAVOR_JULIA.lead_ncu == 1
        @test _FP_BLS.FLAVOR_JULIA.lead_cus == (UInt8('#'),)
        @test _FP_BLS.FLAVOR_CFAM.lead_ncu == 2
        @test _FP_BLS.FLAVOR_CFAM.lead_cus == (UInt8('/'), UInt8('/'))
        ## (the `_CFAM_LEAD_*` consts the record values generalized were removed)
    end

    # (the [4] digest-properties testset was CONSCIOUSLY RETIRED with its subject — the
    # flavor record's digest fold: a cache-key component no code read.)

    @testset "[5] record guards + the INTERIM reserved-arms law" begin
        ## The INTERIM law: a NON-julia flavor claiming a reserved arm REFUSES at
        ## construction (LaTeX-shaped witness — the LaTeX data point lands :absent).
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
        ## The status-vocabulary guard: an out-of-domain status refuses (this
        ## row is the guard's witness). UNIQUE TARGETING:
        ## julia-tagged so the INTERIM law short-circuits, flags empty so the
        ## absent-guard passes — deleting the status-domain assert would construct
        ## GREEN and flip exactly this row red.
        bad_status_rows = ((char = '-', status = :maybe, flags = (), ws_strict = false,
            consume = :single),
            _FP_BLS.FLAVOR_JULIA.directives[2:5]...)
        @test_throws AssertionError _FP_BLS._mk_flavor(;
            _fp_julia_kwargs(directives = bad_status_rows)...)
        ## ── guard witnesses ──
        ## The consume-vocabulary guard: an out-of-domain verb refuses (unique targeting as the status witness's: julia-tagged so the INTERIM law short-circuits; the row otherwise the julia table's own `-` row
        ## — status :claimed, flags (:startNewBlock,) — so the order, status and absent guards pass and only the consume assert can fire).
        bad_consume_rows = ((char = '-', status = :claimed, flags = (:startNewBlock,),
            ws_strict = false, consume = :gulp),
            _FP_BLS.FLAVOR_JULIA.directives[2:5]...)
        @test_throws AssertionError _FP_BLS._mk_flavor(;
            _fp_julia_kwargs(directives = bad_consume_rows)...)
        ## The run-char collision guard: a lead whose run char
        ## lands in the reader's other arm triggers refuses at mint — '~' here;
        ## every EARLIER guard passes (ASCII lead; hide marker "~x " has a
        ## comment-class second char; run char == last(lead)), so only the
        ## collision assert can fire.
        @test_throws AssertionError _FP_BLS._mk_flavor(; flavor_tag = :tildeish,
            lead = "~", comment_run_char = '~', hide_marker = "~x ",
            hide_fold_prefix = "~",
            directives = (_FP_ABSENT4..., _FP_CLOSE_ROW),
            glued_policy = :comment, bare_policy = :comment,
            fences_armed = false, comment_run_strict = false)
        ## The policy-vocabulary guards: an out-of-domain
        ## policy Symbol refuses at mint (the reader's === compares would silently
        ## comment-ize a typo).
        @test_throws AssertionError _FP_BLS._mk_flavor(;
            _fp_julia_kwargs(glued_policy = :contnet)...)
        @test_throws AssertionError _FP_BLS._mk_flavor(;
            _fp_julia_kwargs(bare_policy = :komment)...)
        ## The positional constructor CEASED TO EXIST (the inner keyword
        ## constructor replaced it — the construction-law hazard closed
        ## mechanically): positional construction throws MethodError.
        @test_throws MethodError _FP_BLS.FlavorProfile(:julia, "#", '#', "## ",
            "##", r"^x", _FP_BLS.FLAVOR_JULIA.directives, :content,
            :content, true, true, 1, (UInt8('#'),))   # the record's 13 values
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
        @test r_jl.blsComponentTree.flavor === _FP_BLS.FLAVOR_JULIA
        r_c = GM.goMeta(_fp_bytes("//~ hide\nint x;\n");
            config = GM.GoMetaConfig(flavor_tag = :c))
        @test r_c.blsComponentTree.flavor === _FP_BLS.FLAVOR_CFAM
        ## The invalid-tag path throws raw at flavor_for — the closed inventory's stable message, no
        ## fallback (the former coded refusal was removed).
        @test_throws ErrorException GM.goMeta(_fp_bytes("x\n");
            config = GM.GoMetaConfig(flavor_tag = :cobol))
    end
end
