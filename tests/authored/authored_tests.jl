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
#           SET of label names; `present = false` as absence. (7) `decided_by` IS ASSERTED (stage 2's commit 4a of
#           the v0.4 build; the Engine's provenance since its commit 2, R-V04B-35 (d)): the deciding statements'
#           Components of the rows that gave the applied value, named by position — a Block `block@N`, a Line
#           `line@N`, a Segment's statement by ITS LINE (`line@N` — the vocabulary of the confirmed files; the
#           session's reading, put to the owner), the fed profile `user`, no statement `default` — must equal
#           the expectation's set (a string or a list); the rows' `decided_by` handles are decoded like the
#           cell handles (step 4) and mapped to the tree's Blocks and Lines.
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
#   `altValues_evals`; the tree through `result.blsComponentTree` and the parser module — the same read the
#   golden layer makes (`_preapply_tree`), inside the repository's own tests.

using Test, TOML
using GoMeta
const GA = GoMeta
const GB = GoMeta.BLS

const AUTHORED_DIR = @__DIR__

## --- expected failures: (stem, component, alterant) => the reason and the ruling that scopes the fix ---
## (none since stage 2's commit 1: scenario 005's entry — the heading recorded on the metaLine's own Line — left when the
## heading re-key (R-V04B-50) keyed the row to the metaBlock; the scenario is green against the expectations the owner confirmed on
## 2026-09-10 (R-V04B-23))
const EXPECTED_FAILURES = Dict{Tuple{String,String,String},String}()

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

## --- the tree: positions → Components; Components → (grain, ordinal) — through the door (stage 2's commit 0) ---
_ni(c, k) = GB.getElement(c, k)
## The tree's Blocks and Lines as the door's walk yields them (`BLS.children`: source order, the stores never
## read here — the former walk over the raw store vectors with their UNASSIGNED slots is gone).
function _components(ps)
    file   = GB.root(ps)
    blocks = GB.children(ps)
    lines  = [l for b in blocks for l in GB.children(ps, b)]
    for c in Iterators.flatten((blocks, lines))
        (_ni(c, :idExtension) == 0 && _ni(c, :idExtended) == 0) ||
            error("authored: an extension chain exists in this input (idExtension/idExtended ≠ 0) — " *
                  "chain normalization is not implemented here; see src/occurrence.jl")
    end
    return (; ps, file, blocks, lines)
end

## line@N → the Line whose input line number is N
function _line_at(t, n::Int)
    hits = [l for l in t.lines if _ni(l, :inputLineNum) == n]
    length(hits) == 1 || error("authored: line@$n — expected exactly one Line with input line number $n, found $(length(hits))")
    return hits[1]
end
## block@N → the Block whose FIRST Line is line N
function _block_at(t, n::Int)
    hits = GB.Block[]
    for b in t.blocks
        kids = GB.children(t.ps, b)
        isempty(kids) && continue
        _ni(first(kids), :inputLineNum) == n && push!(hits, b)
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
_block_of(t, l::GB.Line) = GB.parent(t.ps, l)   # the Line's Block through the door (the former store index by `:idParent`)

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
## returns (value, source, used) — value: a String (Visib/Heading), a Set{String} (Labels), or `nothing` (absent);
## source: :own | :block | :default; used: the rows the value was read from (empty for :default) — the provenance
## assertion (step 7; stage 2's commit 4a) reads their `decided_by`
function _applied(rows, t, c, alterant::AbstractString)
    mine = _rows_on(rows, c)
    own = _extract(mine, alterant)
    own !== nothing && return (own, :own, mine)
    if c isa GB.Line
        theirs = _rows_on(rows, _block_of(t, c))
        viablock = _extract(theirs, alterant)
        viablock !== nothing && return (viablock, :block, theirs)
    end
    alterant == "Visib" && return ("show", :default, eltype(rows)[])        # the documented default (header, step 5)
    return (nothing, :default, eltype(rows)[])
end

## --- the provenance (step 7; stage 2's commit 4a): the deciding statements' Components of the rows a value was read from, as positions ---
const GRAIN_SEGMENT = 0x01
const GRAIN_USER    = 0xe0     # the user-context class (src/occurrence.jl USER_CONTEXT_GRAIN): the fed profile's statements
function _family(attr::Symbol, alterant::AbstractString)
    alterant == "Visib"   && return attr === :visib
    alterant == "Labels"  && return startswith(string(attr), "label_")
    alterant == "Heading" && return startswith(string(attr), "head_")
    error("authored: unknown Alterant '$alterant'")
end
_pos_of_block(t, b) = "block@" * string(_ni(first(GB.children(t.ps, b)), :inputLineNum))
_pos_of_line(l) = "line@" * string(_ni(l, :inputLineNum))
## a deciding handle → the position of the Component whose metaStatement it names; a Segment's statement → ITS LINE
function _position(t, h::Vector{UInt8})
    d = decode_handle(h)
    d.grain == GRAIN_USER && return "user"
    isempty(d.path) && error("authored: a deciding handle with an empty path")
    if d.grain == GRAIN_BLOCK
        o = last(d.path)[2]
        hits = [b for b in t.blocks if _ordinal(b) == o]
        length(hits) == 1 || error("authored: the deciding Block ordinal $o maps to $(length(hits)) Blocks")
        return _pos_of_block(t, hits[1])
    elseif d.grain == GRAIN_LINE || d.grain == GRAIN_SEGMENT
        length(d.path) >= 3 || error("authored: a Line or Segment handle with fewer than three path steps")
        o = d.grain == GRAIN_LINE ? last(d.path)[2] : d.path[3][2]     # a Segment's path: file · block · LINE · segment
        hits = [l for l in t.lines if _ordinal(l) == o]
        length(hits) == 1 || error("authored: the deciding Line ordinal $o maps to $(length(hits)) Lines")
        return _pos_of_line(hits[1])
    end
    error("authored: a deciding handle of grain $(d.grain) is not mapped by this runner")
end
## the SET of positions that decided the rows of the Alterant's family among `used`; {"default"} when no row applied
function _deciders(t, used, dec, alterant::AbstractString)
    isempty(used) && return Set(["default"])
    out = Set{String}()
    for r in used
        _family(r[2], alterant) || continue
        for h in dec[(r[1], r[2])]
            push!(out, _position(t, h))
        end
    end
    isempty(out) && error("authored: the rows that gave the value carry no provenance — the Engine's decided_by is empty")
    return out
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
    n_confirmed = 0; n_stmt = 0; n_decided_by_asserted = 0
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
            rows = GA.readAltValuesEvals(r.altValues_evals)
            dec  = Dict{Tuple{Vector{UInt8},Symbol},Vector{Vector{UInt8}}}((rec.cell_handle, rec.attr) => rec.decided_by for rec in r.altValues_evals.records)   # step 7: the rows' provenance by (handle, attr)
            t    = _components(r.blsComponentTree)
            for ex in spec["expect"]
                n_stmt += 1
                pos, alt = ex["component"], ex["alterant"]
                c = _component(t, pos)
                applied, source, used = _applied(rows, t, c, alt)
                ok = _matches(ex, applied)
                prov = ""
                if haskey(ex, "decided_by")                       # step 7 (stage 2's commit 4a): the provenance ASSERTED
                    n_decided_by_asserted += 1
                    want = ex["decided_by"]
                    want_set = Set{String}(want isa AbstractVector ? String.(want) : [String(want)])
                    got_set = _deciders(t, used, dec, alt)
                    ok = ok && got_set == want_set
                    prov = " — decided_by expected $(_show(want_set)), the rows' provenance gives $(_show(got_set))"
                end
                key = (stem, pos, alt)
                label = "$pos · $alt — expected $(get(ex, "present", true) === false ? "absent" : _show(ex["value"] isa AbstractVector ? Set{String}(String.(ex["value"])) : String(ex["value"]))), the Engine's rows give $(_show(applied)) (via $source)" * prov
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
    @test n_decided_by_asserted >= 1   # non-vacuity: the provenance assertion ran (step 7)
    @info "authored layer: $n_confirmed confirmed scenario file(s), $n_stmt statement(s) checked; " *
          "$n_decided_by_asserted `decided_by` field(s) ASSERTED against the rows' provenance (stage 2's commit 4a; a Segment's statement attributed to its Line); " *
          "$(length(EXPECTED_FAILURES)) statement(s) listed as expected failures (@test_broken)"
end
