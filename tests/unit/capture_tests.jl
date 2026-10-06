# capture_tests.jl — v0.4 T5: the CAPTURE RE-HOME witnesses (T5-DESIGN v2 §6).
#
# IS:   the T5 acceptance rows — the registration-driven walk mints for a CONFORMING
#       mock (the sadd2 anti-T1 cure), the per-plugin localOnly flush, the ctor
#       triple, the mode-gate laws (coherence · scheme · store; the identity and stem-clash laws left
#       at stage 5's E4 of the v0.4 build — the measured consequences pinned at [9] and [11]), and the `:per_field` positive
#       fixture the corpus never reaches.
# DOES: registers mock Alterants through the sanctioned lifecycle (the PROBE-proven
#       shapes: register! varargs; the record's five-field keyword form since stage 5's E11 — census row 16),
#       drives them through goMeta, and pins rows + diagnostics.
# REASONING: PROBE-14's sadd2 measurement — on v0.3.2 a conforming mock registered,
#       absorbed, applied PROCESS_OK and minted NO evals row (the 3-name ladder). These
#       witnesses are the only proof the declaration is now LOAD-BEARING at the capture
#       plane and the silence classes are typed.
# PURPOSE: the T5 acceptance rows (Σ = 29 in this file after the crx-t5 cure round:
#       23 at the T5 commit + [11]'s 6 + the [1] end-to-end algebra drive + the [7]
#       cross-stem pin − the [7] runtime pair made lifecycle-unreachable by the tier-1
#       store law; + 4 in record_schema_tests (the T5 3 + the B8 seal pin) —
#       4749 + 29 + 4 = 4782, every movement declared; at stage 5's E4 of the v0.4 build the 29 here
#       stand — [9]'s identity and stem-clash arms and [11]'s A6 re-cut to the measured consequences,
#       one assert each — and record_schema_tests' shape-law testset (6 asserts) left with its subject;
#       at stage 5's E5 20 stand: the floor, gate and algebra witnesses — [1]'s algebra drive, [2]'s floor assert, [3] whole,
#       [8]'s field assert, [9]'s instance-type arm, [11]'s Float and keys-less mocks — 9 asserts, left with their subjects,
#       census rows 33 and 34).

using Test
import GoMeta as GM

@eval module _CapM
    zset(d::Dict{Symbol,Bool}, a::Symbol, r::Symbol...) = (for x in r; d[x] = true; end; nothing)
    yset(d::Dict{Symbol,Bool}, a::Symbol, r::Symbol...) = (for x in r; d[x] = true; end; nothing)
    badset(d::Dict{Symbol,Bool}, a::Symbol, r::Symbol...) = (d[a] = true; nothing)
end

@testset "capture (v0.4 T5)" begin

    _doc(s) = Vector{UInt8}(codeunits(s))
    function _mockb(; capture = GM.CaptureDecl(:per_key, nothing; attr_stem = :zm),
                      setter = _CapM.zset, store = Dict{Symbol,Bool}, name = :zmark)
        b = GM.RegistryBuilder(GM.DEFAULT_REGISTRY)
        pi = GM.next_plugin_index(b)
        GM.register!(b,
            GM.PlugIn(; altName = :zmock, setMode = :accumulate, altConstructor = store,
                setAltInstance = setter, capture = capture),
            GM.ActionSpec(; name = name, plugin = pi))
        b
    end

    @testset "[1] sadd2 — the conforming mock MINTS (the anti-T1 cure; three witnesses)" begin
        R = GM.publish(_mockb())
        r = GM.goMeta(_doc("x = 1\n#~ zmark(aa)\n\ny = 2\n"); registry = R)
        rows = GM.readAltValuesEvals(r.altValues_evals)
        # (the crx-t5 B6 strengthening) the three witnesses are INDEPENDENT: existence+
        # uniqueness selects by the stem PREFIX (not the expected attr), the attr is
        # then pinned, then the payload
        zrows = [t for t in rows if startswith(String(t[2]), "zm")]
        @test r.status === GM.PROCESS_OK && length(zrows) == 1     # exactly ONE mock row
        @test zrows[1][2] === :zm_aa                               # attr = stem + key
        @test zrows[1][3] === true && zrows[1][4] === true         # value + polarity faithful
    end

    @testset "[2] no capture row: zero rows, PROCESS_OK (the floor warning left at stage 5's E5)" begin
        b = _mockb(; capture = nothing)
        R = GM.publish(b)
        r = GM.goMeta(_doc("x = 1\n#~ zmark(aa)\n\ny = 2\n#~ zmark(bb)\n\nz = 3\n"); registry = R)
        @test r.status === GM.PROCESS_OK
        @test !any(t -> startswith(String(t[2]), "zm"), GM.readAltValuesEvals(r.altValues_evals))
    end

    @testset "[4] the :per_field POSITIVE fixture (the corpus-inert Id arm)" begin
        # the pre-T5 ladder bytes for a populated Id, checked-in as a literal:
        # `cell(7)` ⇒ the one row (:id_cell, 7); parent/file (0) ABSENT
        R = GM.publish(GM.default_registry_builder())
        r = GM.goMeta(_doc("x = 1\n#~ cell(7)\n\ny = 2\n"); registry = R)
        rows = GM.readAltValuesEvals(r.altValues_evals)
        idrows = [(t[2], t[3]) for t in rows if startswith(String(t[2]), "id_")]
        @test idrows == [(:id_cell, Int16(7))]                     # one row per non-default field
        @test !any(t -> t[2] === :id_parent || t[2] === :id_file, rows)   # defaulted fields absent
    end

    @testset "[5] the Visib multiplicity refuse VERBATIM through the :single arm" begin
        src = read(joinpath(dirname(dirname(@__DIR__)), "src", "annotations.jl"), String)
        @test occursin("more than one Visib value set for one component — v0's Visib ", src) &&
              occursin("actions (show/hide/discard) are mutually exclusive per component ", src)
    end

    @testset "[6] the ungated :per_occurrence fifth arm (one presence row per governed cell)" begin
        R = GM.publish(_mockb(; capture = GM.CaptureDecl(:per_occurrence, nothing; attr_stem = :zp)))
        r = GM.goMeta(_doc("x = 1\n#~ zmark(aa)\n\ny = 2\n"); registry = R)
        prow = [t for t in GM.readAltValuesEvals(r.altValues_evals) if t[2] === :zp]
        @test length(prow) == 1 && prow[1][3] === true
    end

    @testset "[7] the localOnly plumbing — per-plugin flush; the wrong-shape floor, NO poison" begin
        # a SECOND localOnly plugin (a Heading-shaped store of its own) flushes
        # independently under its own stem
        b = GM.RegistryBuilder(GM.DEFAULT_REGISTRY)
        pi = GM.next_plugin_index(b)
        GM.register!(b,
            GM.PlugIn(; altName = :zhead, setMode = :localOnly,
                altConstructor = GM.Alterants.Heading, setAltInstance = GM.Alterants.setHead,
                capture = GM.CaptureDecl(:per_occurrence, :localOnly; attr_stem = :zh)),
            GM.ActionSpec(; name = :zhd, plugin = pi, accepts_string_slot = 1))
        R = GM.publish(b)
        r = GM.goMeta(_doc("x = 1\n#~ \"T\" zhd(\"U\", 2)\n\ny = 2\n"); registry = R)
        rows = GM.readAltValuesEvals(r.altValues_evals)
        @test r.status === GM.PROCESS_OK &&
              any(t -> t[2] === :head_1 && t[3] == "T", rows) &&
              any(t -> startswith(String(t[2]), "zh_") && t[3] == "U", rows)
        # (B6) the CROSS-STEM ABSENCES pin the per-plugin injectivity: no head-row
        # carries "U" and no zh-row carries "T" (the shared-store failure's signature)
        @test !any(t -> startswith(String(t[2]), "head") && t[3] == "U", rows) &&
              !any(t -> startswith(String(t[2]), "zh") && t[3] == "T", rows)
        # (the crx-t5 evolution) the RUNTIME wrong-shape floor became lifecycle-
        # unreachable — the tier-1 localOnly STORE LAW (witnessed at [11]) refuses an
        # entries-less gated row at publish; the flush's floor branch stays as
        # defense-in-depth against post-publication mutation (the B-2 class).
    end

    @testset "[8] the CaptureDecl ctor triple" begin
        c4 = GM.CaptureDecl(:per_key, nothing)
        c5 = GM.CaptureDecl(:per_key, nothing, :zz)
        ck = GM.CaptureDecl(:per_key, nothing; attr_stem = :zz)
        @test c4.attr_stem === nothing
        @test c5.attr_stem === :zz && ck.attr_stem === :zz
    end

    @testset "[9] the mode-gate coherence law (the identity and stem-clash laws left at stage 5's E4)" begin
        # gate/setMode incoherence: an :accumulate record gating :localOnly refuses
        bi = _mockb(; capture = GM.CaptureDecl(:per_key, :localOnly; attr_stem = :zi))
        @test any(x -> x.code === :REG_PROTOCOL && occursin("INCOHERENT", x.message), GM.validate(bi))
        # a mock declaring the shipped :label stem PUBLISHES since E4; on ONE cell the two plugins' same-attr
        # rows collapse to one `label_label1` row — the silent cross-plugin supersede the stem-clash law refused
        # (measured: [b]; full structural namespacing is T11's row)
        bc = _mockb(; capture = GM.CaptureDecl(:per_key, nothing; attr_stem = :label))
        rc = GM.goMeta(_doc("x = 1\n#~ :label1 zmark(label1)\n\ny = 2\n"); registry = GM.publish(bc))
        @test rc.status === GM.PROCESS_OK &&
              [t[2] for t in GM.readAltValuesEvals(rc.altValues_evals)] == [:label_label1]
    end

    @testset "[10] the derived-fallback stem (a mock with attr_stem = nothing)" begin
        R = GM.publish(_mockb(; capture = GM.CaptureDecl(:per_key, nothing)))
        r = GM.goMeta(_doc("x = 1\n#~ zmark(aa)\n\ny = 2\n"); registry = R)
        @test any(t -> t[2] === :zmock_aa, GM.readAltValuesEvals(r.altValues_evals))   # lowercase(String(:zmock)) = "zmock"
    end

    @testset "[11] the crx-t5 cure witnesses" begin
        # (A1) a localOnly plugin with capture === nothing: the FLOOR arm, never the
        # UNREADABLE-with-nothing crash — the drive completes and floors typed
        b1 = GM.RegistryBuilder(GM.DEFAULT_REGISTRY)
        p1 = GM.next_plugin_index(b1)
        GM.register!(b1,
            GM.PlugIn(; altName = :znone, setMode = :localOnly,
                altConstructor = GM.Alterants.Heading, setAltInstance = GM.Alterants.setHead),
            GM.ActionSpec(; name = :znh, plugin = p1, accepts_string_slot = 1))
        r1 = GM.goMeta(_doc("x = 1\n#~ \"T\" znh(\"V\", 2)\n\ny = 2\n"); registry = GM.publish(b1))
        @test r1.status === GM.PROCESS_OK &&
              any(d -> d.code === :WARN_CAPTURE_FLOOR && d.context === :znone, r1.diagnostics)
        # (A5) the localOnly scheme law: a gated row declaring :per_key refuses at tier 1
        bs = _mockb(; capture = GM.CaptureDecl(:per_key, :localOnly; attr_stem = :zs))
        @test any(x -> x.code === :REG_PROTOCOL && occursin("localOnly scheme law", x.message), GM.validate(bs))
        # (A4/C3) the localOnly store law: a gated :per_occurrence row on an
        # entries-less instance type refuses at tier 1 (STATIC — the fieldtype check)
        b4 = GM.RegistryBuilder(GM.DEFAULT_REGISTRY)
        p4 = GM.next_plugin_index(b4)
        GM.register!(b4,
            GM.PlugIn(; altName = :zle, setMode = :localOnly,
                altConstructor = Dict{Symbol,Bool}, setAltInstance = _CapM.badset,
                capture = GM.CaptureDecl(:per_occurrence, :localOnly; attr_stem = :ze)),
            GM.ActionSpec(; name = :zle1, plugin = p4))
        @test any(x -> x.code === :REG_PROTOCOL && occursin("localOnly store law", x.message), GM.validate(b4))
        # (A6; re-cut at stage 5's E4 — the stem-clash law left) :label_x beside the shipped :label family
        # PUBLISHES; distinct keys mint distinct rows (measured: PROBES-e4-capture-laws [b2] — label_label1 · label_x_aa)
        bp = _mockb(; capture = GM.CaptureDecl(:per_key, nothing; attr_stem = :label_x))
        rp = GM.goMeta(_doc("x = 1\n#~ :label1 zmark(aa)\n\ny = 2\n"); registry = GM.publish(bp))
        @test rp.status === GM.PROCESS_OK &&
              sort([t[2] for t in GM.readAltValuesEvals(rp.altValues_evals)]) == [:label_label1, :label_x_aa]
    end
end
