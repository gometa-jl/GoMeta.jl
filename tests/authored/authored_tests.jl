# authored_tests.jl — the AUTHORED-TRUTH layer of the GoMeta test suite (owner ruling R-V04B-15 (c);
#   landed under R-V04B-24 (R), 2026-09-11: "the authored-test runner lands BEFORE the move").
#
# IS:   the runner of tests/authored/README.md — for every `NNN_<name>.toml` whose `status` is
#       "confirmed", it runs the sibling input `NNN_<name>.jl` through `goMeta` and checks each
#       `[[expect]]` statement against the Engine's evaluated values (`altValues_evals`).
# DOES: (1) reads the expectation file (TOML); skips a `draft` (a draft has no authority — README rule 3).
#       (2) runs the input; requires PROCESS_OK. (3) maps every POSITION the file names to a Component
#       of the parsed tree: `line@N` = the Line whose input line number is N; `block@N` = the Block whose
#       FIRST Line is line N (README rule 2). (4) maps every evaluated row to its Component by decoding the
#       row's occurrence handle (the documented layout of src/occurrence.jl: schema 0x01 · namespace ·
#       grain · path steps · origin steps; the last path step's ordinal is the cell's store position) and
#       matching the grain and that ordinal. (5) derives the value that APPLIES to a Component:
#         - the Component's OWN rows for the Alterant, if it has any;
#         - else, for a Line, its Block's rows — the owner's indirect-application principle
#           (OWNER-WORDS §8; README rule 2: a value applies to the Component it was evaluated for and
#           INDIRECTLY to that Component's children). This is the ONLY derivation the runner makes: it
#           reads the Engine's rows and applies the owner's stated principle to reach a child; it never
#           re-evaluates a metaStatement. When the Engine delivers a resolved answer per Component (D-4),
#           step (5) reads that answer instead (README:63 "and, after D-1, the resolved rows");
#         - else, no row applies: for Visib the DOCUMENTED default `show` (docs/SYNTAX-AND-SEMANTICS.md
#           §7 "The default is show"; R-V04B-21 — the Engine declares no default at v0.4; whether it
#           delivers one is D-4's 3a-DESIGN), for Labels the empty set, for Heading absence.
#       (6) compares: a SINGLE value (Visib, Heading) as a string; an ACCUMULATING value (Labels) as the
#           SET of label names; `present = false` as absence. (7) `decided_by` is NOT asserted: the Engine
#           delivers no provenance at v0.4 (the handle's origin names only a Segment-carried remap); it is
#           read and reported once per run, never checked — until D-4.
#       (8) EXPECTED FAILURES: a confirmed statement the Engine is KNOWN not to meet yet is listed in
#           `EXPECTED_FAILURES` with its ruling and runs as `@test_broken` — the suite stays green while
#           the gap stays visible, and the day the Engine meets it the `@test_broken` UNEXPECTED PASS
#           fails the suite so the entry is removed.
# REASONING: R-V04B-15 (c) — the confirmed statements are the specification the Engine (and the parallel
#       new-GoMeta effort) must meet; the layer must be implementation-neutral in what it reads from the
#       files (positions, values) and must not depend on the renderer (the owner, OWNER-WORDS §18: a test
#       that re-derives the evaluations tests the wrong layer — the Engine's values are what is tested).
# PURPOSE: the Engine does what the owner means. Run via tests/runtests.jl (layer: authored), or alone:
#       JULIA_LOAD_PATH="@:@stdlib" julia --project=tests tests/runtests.jl authored
#
# Honest edges: Segment positions (`segment@N.k`) and the File (`file`) are not yet mapped (no confirmed
#   file states them; the File is D-4's row 21a) — an expectation naming them fails loudly with a clear
#   message rather than passing vacuously. Id's per-field form is undefined (README rule 2) — likewise.
#   Extension chains (a Component whose `idExtended` ≠ 0) are not normalized here (the five confirmed
#   inputs have none) — the runner refuses such an input loudly. The rows are read through the PUBLIC
#   `altValues_evals`; the tree through `result.state.parse` and the parser module — the same read the
#   golden layer makes (`_preapply_tree`), inside the repository's own tests.

using Test, TOML
using GoMeta
const GA = GoMeta
const GB = GoMeta.BLS

const AUTHORED_DIR = @__DIR__

## --- expected failures: (stem, component, alterant) => the reason and the ruling that scopes the fix ---
const EXPECTED_FAILURES = Dict{Tuple{String,String,String},String}(
    ("005_heading_local_only", "block@1", "Heading") =>
        "the Engine records the heading on the metaLine's own Line (one head_1 row, Line grain); a Block-level " *
        "heading entry is an Engine change scoped to D-4 (R-V04B-23; R-V04B-24 (R); the file's history)",
)

## --- the occurrence handle, decoded (the documented layout of src/occurrence.jl; schema 0x01) ---
_u16(b, i) = (UInt16(b[i]) << 8) | UInt16(b[i+1])
_u32(b, i) = (UInt32(b[i]) << 24) | (UInt32(b[i+1]) << 16) | (UInt32(b[i+2]) << 8) | UInt32(b[i+3])
function _steps(b, i)
    n = Int(_u16(b, i)); i += 2
    v = Tuple{UInt8,UInt32}[]
    for _ in 1:n
        push!(v, (b[i], _u32(b, i + 1))); i += 5
    end
    return v, i
end
function decode_handle(b::Vector{UInt8})
    (isempty(b) || b[1] != 0x01) && error("authored: a row's handle does not carry schema 0x01 — the decoder must be revisited")
    i = 2
    nslen = Int(_u16(b, i)); i += 2
    ns = String(b[i:i+nslen-1]); i += nslen
    grain = b[i]; i += 1
    path, i = _steps(b, i)
    origin, i = _steps(b, i)
    i == length(b) + 1 || error("authored: trailing bytes in a row's handle — the decoder must be revisited")
    return (; namespace = ns, grain, path, origin)
end
const GRAIN_LINE  = 0x0a
const GRAIN_BLOCK = 0x46

## --- the tree: positions → Components; Components → (grain, ordinal) ---
_ni(c, k) = GB.getElement(c.cmpntNamedInt, k)

function _components(ps)
    file   = ps.componentsPDict[GB.File][1][1]
    blocks = ps.componentsPDict[GB.Block][1]
    lines  = ps.componentsPDict[GB.Line][1]
    for c in Iterators.flatten((blocks, lines))
        (_ni(c, :idExtension) == 0 && _ni(c, :idExtended) == 0) ||
            error("authored: an extension chain exists in this input (idExtension/idExtended ≠ 0) — " *
                  "chain normalization is not implemented here; see src/occurrence.jl")
    end
    return (; file, blocks, lines)
end

## line@N → the Line whose input line number is N
function _line_at(t, n::Int)
    hits = [l for l in t.lines if _ni(l, :idComponent) != 0 && _ni(l, :inputLineNum) == n]
    length(hits) == 1 || error("authored: line@$n — expected exactly one Line with input line number $n, found $(length(hits))")
    return hits[1]
end
## block@N → the Block whose FIRST Line is line N
function _block_at(t, n::Int)
    hits = GB.Block[]
    for b in t.blocks
        _ni(b, :idComponent) == 0 && continue
        kids = collect(GB.eachchildid(b, t.blocks))
        isempty(kids) && continue
        first_line = t.lines[abs(first(kids))]
        _ni(first_line, :inputLineNum) == n && push!(hits, b)
    end
    length(hits) == 1 || error("authored: block@$n — expected exactly one Block whose first Line is line $n, found $(length(hits))")
    return hits[1]
end
function _component(t, pos::AbstractString)
    m = match(r"^(block|line)@(\d+)$", pos)
    m === nothing && error("authored: the position '$pos' is not mapped by this runner (only block@N and line@N are; " *
                           "segment@N.k and file await their confirmed scenarios and D-4)")
    n = parse(Int, m.captures[2])
    return m.captures[1] == "block" ? _block_at(t, n) : _line_at(t, n)
end
_grain(c) = c isa GB.Block ? GRAIN_BLOCK : c isa GB.Line ? GRAIN_LINE : error("authored: unsupported grain $(typeof(c))")
_ordinal(c) = UInt32(abs(_ni(c, :idComponent)))
_block_of(t, l::GB.Line) = t.blocks[abs(_ni(l, :idParent))]

## --- the rows: those ON a Component (its own), by grain + the last path step's ordinal ---
function _rows_on(rows, c)
    g, o = _grain(c), _ordinal(c)
    out = eltype(rows)[]
    for r in rows
        h = decode_handle(r[1])
        (h.grain == g && !isempty(h.path) && last(h.path)[2] == o) && push!(out, r)
    end
    return out
end

## --- the value that APPLIES (step 5 of the header) ---
## returns (value, source) — value: a String (Visib/Heading), a Set{String} (Labels), or `nothing` (absent);
## source: :own | :block | :default
function _applied(rows, t, c, alterant::AbstractString)
    own = _extract(_rows_on(rows, c), alterant)
    own !== nothing && return (own, :own)
    if c isa GB.Line
        viablock = _extract(_rows_on(rows, _block_of(t, c)), alterant)
        viablock !== nothing && return (viablock, :block)
    end
    alterant == "Visib" && return ("show", :default)        # the documented default (header, step 5)
    return (nothing, :default)
end
function _extract(rows, alterant::AbstractString)
    if alterant == "Visib"
        vs = [string(r[3]) for r in rows if r[2] === :visib]
        isempty(vs) && return nothing
        length(vs) == 1 || error("authored: more than one Visib row on one Component: $vs")
        return vs[1]
    elseif alterant == "Labels"
        names = Set{String}(String(string(r[2]))[7:end] for r in rows if startswith(string(r[2]), "label_") && r[3] === true)
        return isempty(names) ? nothing : names
    elseif alterant == "Heading"
        vs = [string(r[3]) for r in rows if startswith(string(r[2]), "head_")]
        isempty(vs) && return nothing
        length(vs) == 1 || error("authored: more than one Heading row on one Component: $vs")
        return vs[1]
    elseif alterant == "Id"
        error("authored: Id's per-field form is not yet defined (README rule 2; D-4)")
    else
        error("authored: unknown Alterant '$alterant'")
    end
end

## --- the comparison of one [[expect]] against the applied value ---
function _matches(ex, applied)
    if get(ex, "present", true) === false
        return applied === nothing
    end
    want = ex["value"]
    if want isa AbstractVector
        return applied isa Set && applied == Set{String}(String.(want))
    end
    return applied isa AbstractString && applied == String(want)
end
_show(v) = v === nothing ? "absent" : v isa Set ? "{" * join(sort(collect(v)), ", ") * "}" : repr(v)

## --- the run ---
const CONFIRMED = sort([f for f in readdir(AUTHORED_DIR) if endswith(f, ".toml")])

@testset verbose = true "authored (the owner's confirmed statements; tests/authored/README.md)" begin
    n_confirmed = 0; n_stmt = 0; n_decided_by_unchecked = 0
    for tomlname in CONFIRMED
        spec = TOML.parsefile(joinpath(AUTHORED_DIR, tomlname))
        get(spec, "status", "draft") == "confirmed" || continue      # README rule 3: a draft has no authority
        n_confirmed += 1
        stem  = spec["stem"]
        input = joinpath(AUTHORED_DIR, stem * ".jl")
        @testset verbose = true "$stem" begin
            @test isfile(input)
            r = GA.goMeta(read(input))
            @test r.status == GA.PROCESS_OK
            rows = GA.altValues_evals(r)
            t    = _components(r.state.parse)
            for ex in spec["expect"]
                n_stmt += 1
                pos, alt = ex["component"], ex["alterant"]
                haskey(ex, "decided_by") && (n_decided_by_unchecked += 1)
                c = _component(t, pos)
                applied, source = _applied(rows, t, c, alt)
                ok = _matches(ex, applied)
                key = (stem, pos, alt)
                label = "$pos · $alt — expected $(get(ex, "present", true) === false ? "absent" : _show(ex["value"] isa AbstractVector ? Set{String}(String.(ex["value"])) : String(ex["value"]))), the Engine's rows give $(_show(applied)) (via $source)"
                if haskey(EXPECTED_FAILURES, key)
                    @testset "EXPECTED FAILURE — $label — $(EXPECTED_FAILURES[key])" begin
                        @test_broken ok
                    end
                else
                    @testset "$label" begin
                        @test ok
                    end
                end
            end
        end
    end
    @test n_confirmed >= 1        # non-vacuity: at least one confirmed scenario ran
    @info "authored layer: $n_confirmed confirmed scenario file(s), $n_stmt statement(s) checked; " *
          "$n_decided_by_unchecked `decided_by` field(s) read but NOT asserted (the Engine delivers no provenance at v0.4 — D-4); " *
          "$(length(EXPECTED_FAILURES)) statement(s) listed as expected failures (@test_broken)"
end
