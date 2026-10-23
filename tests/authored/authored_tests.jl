# authored_tests.jl — the AUTHORED-TRUTH layer of the GoMeta test suite (the creator's decision;
#   landed 2026-09-11).
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
#       matching the grain and that ordinal. (5) the value that APPLIES to a Component is THE ENGINE's ANSWER —
#           `GoMeta.evaluatedAltValue(delivery, component, alterant)` (since 0.4.0): the Component's own rows, else its parent's up the tree (the creator's
#           indirect-application principle, as the Engine applies it — README rule 2), else the
#           Alterant's declared default (Visib `show`) or absence. The runner derives NOTHING of its
#           own (it reads the Engine's answer; it never applies the principle to the rows itself).
#       (6) compares: a SINGLE value (Visib, Heading) as a string; an ACCUMULATING value (Labels) as the
#           SET of label names; `present = false` as absence. (7) `decided_by` IS ASSERTED (the Engine's
#           provenance field): the deciding statements'
#           Components of the rows the runner finds on the Component (its own rows for the Alterant, else — for a
#           Line — its Block's: the runner's OWN search, kept beside the answer because the answer carries ONE
#           source tag where an accumulating Alterant's expectation names EVERY contributor — 4 of the 27 asserted
#           sets, Labels; an open point), named by position — a Block `block@N`, a Line
#           `line@N`, a Segment's statement by ITS LINE (`line@N` — the vocabulary of the confirmed files),
#           the fed profile `user`, no statement `default` — must equal
#           the expectation's set (a string or a list); the rows' `decided_by` handles are decoded like the
#           cell handles (step 4) and mapped to the tree's Blocks and Lines.
#       (7b) `[[expect_diagnostic]]` (since 0.4.3): a diagnostic row the creator expects the run to deliver — `code`, `severity` (default
#           "warning"), `component` (the position the row stands at: its context's `cell`, decoded like a row's handle), `label` (optional,
#           the context's `label`), `count` (default 1) — the number of matching rows of the delivery must equal `count`.
#       (7c) every scenario runs on a FRESH user-level vocabulary file of the Labels Alterant (a vocabulary statement persists since 0.4.3).
#       (8) EXPECTED FAILURES: a confirmed statement the Engine is KNOWN not to meet yet is listed in
#           `EXPECTED_FAILURES` with its reason and runs as `@test_broken` — the suite stays green while
#           the gap stays visible, and the day the Engine meets it the `@test_broken` UNEXPECTED PASS
#           fails the suite so the entry is removed.
# REASONING: the confirmed statements are the specification the Engine (and every other
#       variant of GoMeta) must meet; the layer must be implementation-neutral in what it reads from the
#       files (positions, values) and must not depend on the renderer (the creator's words: a test
#       that re-derives the evaluations tests the wrong layer — the Engine's values are what is tested).
# PURPOSE: the Engine does what the creator means. Run via tests/runtests.jl (layer: authored), or alone:
#       JULIA_LOAD_PATH="@:@stdlib" julia --project=tests tests/runtests.jl authored
#
# Honest edges: Segment positions (`segment@N.k`) and the File (`file`) are not yet mapped (no confirmed
#   file states them; the File's form is an open point) — an expectation naming them fails loudly with a clear
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

## --- expected failures: (stem, component, alterant) => the reason that scopes the fix ---
## (none since the heading re-key: scenario 005's entry — the heading recorded on the metaLine's own Line — was removed when the
## heading re-key keyed the row to the metaBlock; the scenario is green against the expectations the creator confirmed on
## 2026-09-10)
const EXPECTED_FAILURES = Dict{Tuple{String,String,String},String}()

## --- the occurrence handle, decoded — THE ONE SHARED DECODER of the development tools (the creator's word of 2026-10-03:
##     one shared decoder for the runner and the tools; devtools/handle_decoder.jl — the documented layout of
##     src/occurrence.jl, schema 0x01). The runner's ARM: a handle that does not decode cleanly is an ERROR here (the tools
##     render it unanchored instead) ---
isdefined(@__MODULE__, :decode_handle) || include(joinpath(@__DIR__, "..", "..", "devtools", "handle_decoder.jl"))
function decode_handle_strict(b::Vector{UInt8})
    d = decode_handle(b)
    d === nothing && error("authored: a row's handle does not decode cleanly (schema 0x01 · the namespace · the grain · the path and origin steps · no trailing bytes) — the decoder must be revisited")
    return d
end
const GRAIN_LINE  = 0x0a
const GRAIN_BLOCK = 0x46

## --- the tree: positions → Components; Components → (grain, ordinal) — through the door ---
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
                           "segment@N.k and file await their confirmed scenarios)")
    n = parse(Int, m.captures[2])
    return m.captures[1] == "block" ? _block_at(t, n) : _line_at(t, n)
end
_grain(c) = c isa GB.Block ? GRAIN_BLOCK : c isa GB.Line ? GRAIN_LINE : error("authored: unsupported grain $(typeof(c))")
_ordinal(c) = UInt32(abs(_ni(c, :idComponent)))
_block_of(t, l::GB.Line) = GB.parent(t.ps, l)   # the Line's Block through the door (the former store index by `:idParent`)

## --- a handle ON a Component: the grain and the last path step's ordinal (a diagnostic row's `cell`, step 7b) ---
_handle_on(h::Vector{UInt8}, c) = (d = decode_handle_strict(h); d.grain == _grain(c) && !isempty(d.path) && last(d.path)[2] == _ordinal(c))

## --- the rows: those ON a Component (its own), by grain + the last path step's ordinal ---
function _rows_on(rows, c)
    g, o = _grain(c), _ordinal(c)
    out = eltype(rows)[]
    for r in rows
        h = decode_handle_strict(r[1])
        (h.grain == g && !isempty(h.path) && last(h.path)[2] == o) && push!(out, r)
    end
    return out
end

## --- the value that APPLIES (step 5 of the header): THE ENGINE's ANSWER ---
## returns (value, source, used) — value: the answer's value in the runner's comparison form — a String (Visib/Heading), a
## Set{String} (Labels), or `nothing` (absent); source: the answer's source tag (:own | :indirect | :user | :file | :default |
## :none); used: the rows the PROVENANCE assertion (step 7) reads — the Component's own rows for the
## Alterant, else (for a Line) its Block's, else none: the runner's own search, kept beside the answer (header, step 7)
const ALTERANT_NAME = Dict("Visib" => :Visib, "Labels" => :labels, "Heading" => :heading, "Id" => :id)   # the registered names
function _answer_form(v, alterant::AbstractString)
    alterant == "Id" && error("authored: Id's per-field form is not yet defined (README rule 2)")
    v === nothing && return nothing
    alterant == "Labels" && return isempty(v) ? nothing : Set{String}(string.(v))
    return string(v)
end
function _applied(r, rows, t, c, alterant::AbstractString)
    a = GA.evaluatedAltValue(r, c, ALTERANT_NAME[alterant])
    mine = _rows_on(rows, c)
    if _extract(mine, alterant) !== nothing
        used = mine
    elseif c isa GB.Line && _extract(_rows_on(rows, _block_of(t, c)), alterant) !== nothing
        used = _rows_on(rows, _block_of(t, c))
    else
        used = eltype(rows)[]
    end
    return (_answer_form(a.value, alterant), a.source, used)
end

## --- the provenance (step 7): the deciding statements' Components of the rows a value was read from, as positions ---
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
    d = decode_handle_strict(h)
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
        error("authored: Id's per-field form is not yet defined (README rule 2)")
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

@testset verbose = true "authored (the creator's confirmed statements; tests/authored/README.md)" begin
    n_confirmed = 0; n_stmt = 0; n_decided_by_asserted = 0
    for tomlname in CONFIRMED
        spec = TOML.parsefile(joinpath(AUTHORED_DIR, tomlname))
        get(spec, "status", "draft") == "confirmed" || continue      # README rule 3: a draft has no authority
        n_confirmed += 1
        stem  = spec["stem"]
        input = joinpath(AUTHORED_DIR, stem * ".jl")
        @testset verbose = true "$stem" begin
            @test isfile(input)
            TestSupport.fresh_vocabulary!()                        # step 7c: a fresh user-level vocabulary file per scenario
            r = GA.goMeta(read(input))
            @test r.status == GA.PROCESS_OK
            rows = GA.readAltValuesEvals(r.altValues_evals)
            dec  = Dict{Tuple{Vector{UInt8},Symbol},Vector{Vector{UInt8}}}((rec.cell_handle, rec.attr) => rec.decided_by for rec in r.altValues_evals.records)   # step 7: the rows' provenance by (handle, attr)
            t    = _components(r.blsComponentTree)
            for ex in get(spec, "expect_diagnostic", [])          # step 7b: the diagnostic rows the creator expects
                n_stmt += 1
                pos = ex["component"]; c = _component(t, pos)
                want_code = Symbol(ex["code"]); want_sev = Symbol(get(ex, "severity", "warning"))
                want_label = get(ex, "label", nothing); want_n = get(ex, "count", 1)
                hits = [d for d in r.diagnostics if d.code === want_code && d.severity === want_sev && d.context isa NamedTuple &&
                        haskey(d.context, :cell) && _handle_on(d.context.cell, c) &&
                        (want_label === nothing || (haskey(d.context, :label) && String(string(d.context.label)) == String(want_label)))]
                label = "$pos · diagnostic $want_code ($want_sev)$(want_label === nothing ? "" : " — label $want_label") — expected $want_n row(s), the delivery carries $(length(hits))"
                @testset "$label" begin
                    @test length(hits) == want_n
                end
            end
            for ex in spec["expect"]
                n_stmt += 1
                pos, alt = ex["component"], ex["alterant"]
                c = _component(t, pos)
                applied, source, used = _applied(r, rows, t, c, alt)
                ok = _matches(ex, applied)
                prov = ""
                if haskey(ex, "decided_by")                       # step 7: the provenance ASSERTED
                    n_decided_by_asserted += 1
                    want = ex["decided_by"]
                    want_set = Set{String}(want isa AbstractVector ? String.(want) : [String(want)])
                    got_set = _deciders(t, used, dec, alt)
                    ok = ok && got_set == want_set
                    prov = " — decided_by expected $(_show(want_set)), the rows' provenance gives $(_show(got_set))"
                end
                key = (stem, pos, alt)
                label = "$pos · $alt — expected $(get(ex, "present", true) === false ? "absent" : _show(ex["value"] isa AbstractVector ? Set{String}(String.(ex["value"])) : String(ex["value"]))), the Engine's answer gives $(_show(applied)) (source $source)" * prov
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
          "$n_decided_by_asserted `decided_by` field(s) ASSERTED against the rows' provenance (a Segment's statement attributed to its Line); " *
          "$(length(EXPECTED_FAILURES)) statement(s) listed as expected failures (@test_broken)"
end
