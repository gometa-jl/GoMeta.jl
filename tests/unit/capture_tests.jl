# capture_tests.jl — v0.4 T5: the CAPTURE RE-HOME witnesses (T5-DESIGN v2 §6).
#
# IS:   the T5 acceptance rows — the registration-driven walk mints for a CONFORMING
#       mock (the sadd2 anti-T1 cure), a second Alterant of the set mode `localOnly` through the apply loop beside the
#       Heading (the per-plugin flush of the former separate path, the mode-gate laws and the
#       `:per_occurrence` presence arm were removed with that path — the creator's decision; the measured consequences pinned at [9] and [11]),
#       the ctor pair, and the `:per_field` positive fixture the corpus never reaches.
# DOES: registers mock Alterants through the sanctioned lifecycle (the PROBE-proven
#       shapes: register! varargs; the record's four-field keyword form — the settribute key was removed),
#       drives them through goMeta, and pins rows + diagnostics.
# REASONING: PROBE-14's sadd2 measurement — on v0.3.2 a conforming mock registered,
#       absorbed, applied PROCESS_OK and minted NO evals row (the 3-name ladder). These
#       witnesses are the only proof the declaration is now LOAD-BEARING at the capture
#       plane and the silence classes are coded.
# PURPOSE: the T5 acceptance rows (Σ = 29 in this file after the review cures:
#       23 at the T5 commit + [11]'s 6 + the [1] end-to-end algebra drive + the [7]
#       cross-stem pin − the [7] runtime pair made lifecycle-unreachable by the tier-1
#       store law; + 4 in record_schema_tests (3 + the seal pin — the pin was removed with the seal) —
#       4749 + 29 + 4 = 4782, every movement declared; after the validation chain's removal the 29 here
#       stand — [9]'s identity and stem-clash arms and [11]'s A6 re-cut to the measured consequences,
#       one assert each — and record_schema_tests' shape-law testset (6 asserts) left with its subject;
#       after the capture laws' removal 20 stand: the floor, gate and algebra witnesses — [1]'s algebra drive, [2]'s floor assert, [3] whole,
#       [8]'s field assert, [9]'s instance-type arm, [11]'s Float and keys-less mocks — 9 asserts, removed with their subjects).
#       After the Heading's move 19 stand: [6] removed (−1), [9]'s coherence arm (−1) and [11]'s A5 and A4/C3 (−2) with the
#       Heading's separate path; [7]'s locality pin (+1), [8]'s field-names pin (+1) and [12], the witness of a review cure
#       (+1), added — every movement declared. After a further review's cures 20 stand: [7]'s key pin (+1).
#       With the `ids` action 22 stand: [4b], its `:per_field` rows (+2).

using Test
import GoMeta as GM

@eval module _CapM
    zset(d::Dict{Symbol,Bool}, a::Symbol, r::Symbol...) = (for x in r; d[x] = true; end; nothing)
    nset(d::Dict{Symbol,Bool}, a::Symbol, r...) = (d[Symbol("n", length(r))] = true; nothing)   # [12]: records how many arguments the apply handed over
end

@testset "capture (v0.4 T5)" begin

    _doc(s) = Vector{UInt8}(codeunits(s))
    function _mockb(; capture = GM.CaptureDecl(:per_key; attr_stem = :zm),
                      setter = _CapM.zset, store = Dict{Symbol,Bool}, name = :zmark)
        b = GM.RegistryBuilder(GM.DEFAULT_REGISTRY)
        pi = GM.next_plugin_index(b)
        GM.register!(b,
            GM.Alterant(; altName = :zmock, setMode = :accumulate, altConstructor = store,
                setAltInstance = setter, capture = capture),
            GM.ActionSpec(; name = name, plugin = pi))
        b
    end

    @testset "[1] sadd2 — the conforming mock MINTS (the anti-T1 cure; three witnesses)" begin
        R = GM.publish(_mockb())
        r = GM.goMeta(_doc("x = 1\n#~ zmark(aa)\n\ny = 2\n"); registry = R)
        rows = GM.readAltValuesEvals(r.altValues_evals)
        # the three witnesses are INDEPENDENT: existence+
        # uniqueness selects by the stem PREFIX (not the expected attr), the attr is
        # then pinned, then the payload
        zrows = [t for t in rows if startswith(String(t[2]), "zm")]
        @test r.status === GM.PROCESS_OK && length(zrows) == 1     # exactly ONE mock row
        @test zrows[1][2] === :zm_aa                               # attr = stem + key
        @test zrows[1][3] === true && zrows[1][4] === true         # value + polarity faithful
    end

    @testset "[2] no capture row: zero rows, PROCESS_OK (the former floor warning removed)" begin
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

    @testset "[4b] the :per_field arm with the `ids` action — three fields in one statement (the rows' names and values MEASURED on `#~ ids(…)⏎x = 1`; on THIS document — the metaLine after `x = 1`, the [4] shape — the one recorded Component and its exact row set by the testset's own run)" begin
        R = GM.publish(GM.default_registry_builder())
        r = GM.goMeta(_doc("x = 1\n#~ ids(1, 2, 3)\n\ny = 2\n"); registry = R)
        idrows = sort([(t[2], t[3]) for t in GM.readAltValuesEvals(r.altValues_evals) if startswith(String(t[2]), "id_")])
        @test idrows == [(:id_cell, Int16(1)), (:id_file, Int16(3)), (:id_parent, Int16(2))]     # one row per non-default field, the three at once
        r0 = GM.goMeta(_doc("x = 1\n#~ ids(0, 5, 2)\n\ny = 2\n"); registry = R)
        @test !any(t -> t[2] === :id_cell, GM.readAltValuesEvals(r0.altValues_evals))            # the stated zero (the default) mints no row
    end

    @testset "[5] the Visib multiplicity refuse VERBATIM through the :single arm" begin
        src = read(joinpath(dirname(dirname(@__DIR__)), "src", "annotations.jl"), String)
        @test occursin("more than one Visib value set for one component — v0's Visib ", src) &&
              occursin("actions (show/hide/discard) are mutually exclusive per component ", src)
    end

    # ([6] — the ungated `:per_occurrence` presence arm — was RETIRED with the Heading's separate
    # path, on the creator's selection of 2026-10-16: after the move no shipped Alterant used it; a future Alterant declares what it
    # needs when it comes.)

    @testset "[7] a SECOND Alterant of the set mode `localOnly` beside the Heading — both through the apply loop, each under its own stem" begin
        # the creator's decision — the same process for every Alterant: a Heading-shaped
        # store registered as a second `localOnly` Alterant with the `:per_entry` scheme is queued, applied by the loop's one rule at
        # the metaBlock and recorded by the one capture walk under ITS stem — beside the shipped Heading's row on the same metaBlock
        b = GM.RegistryBuilder(GM.DEFAULT_REGISTRY)
        pi = GM.next_plugin_index(b)
        GM.register!(b,
            GM.Alterant(; altName = :zhead, setMode = :localOnly,
                altConstructor = GM.Alterants.Heading, setAltInstance = GM.Alterants.setHead,
                capture = GM.CaptureDecl(:per_entry; attr_stem = :zh)),
            GM.ActionSpec(; name = :zhd, plugin = pi, accepts_string_slot = 1))
        R = GM.publish(b)
        r = GM.goMeta(_doc("x = 1\n#~ \"T\" zhd(\"U\", 2)\n\ny = 2\n"); registry = R)
        rows = GM.readAltValuesEvals(r.altValues_evals)
        @test r.status === GM.PROCESS_OK &&
              any(t -> t[2] === :head_1 && t[3] == "T", rows) &&
              any(t -> t[2] === :zh_2 && t[3] == "U", rows)
        # (B6) the CROSS-STEM ABSENCES pin the per-Alterant stores: no head-row carries "U" and no zh-row carries "T"
        @test !any(t -> startswith(String(t[2]), "head") && t[3] == "U", rows) &&
              !any(t -> startswith(String(t[2]), "zh") && t[3] == "T", rows)
        # the LOCALITY of the second Alterant too: the attached Code Block (`y = 2`) carries neither row — only the metaBlock does
        @test count(t -> t[2] === :zh_2, rows) == 1 && count(t -> t[2] === :head_1, rows) == 1
        ml7 = only(l for bk in GM.BLS.children(r.blsComponentTree) for l in GM.BLS.children(r.blsComponentTree, bk)
                     if GM.BLS.getElement(l, :inputLineNum) == 2)   # the metaLine at input line 2, through the door
        mb7 = GM.key_bytes(GM.occurrence_key(r.blsComponentTree, GM.BLS.parent(r.blsComponentTree, ml7); namespace = :default))
        @test only(t[1] for t in rows if t[2] === :zh_2) == mb7 && only(t[1] for t in rows if t[2] === :head_1) == mb7
    end

    @testset "[8] the CaptureDecl ctor triple (the two-field row)" begin
        c4 = GM.CaptureDecl(:per_key)
        c5 = GM.CaptureDecl(:per_key, :zz)
        ck = GM.CaptureDecl(:per_key; attr_stem = :zz)
        @test c4.attr_stem === nothing
        @test c5.attr_stem === :zz && ck.attr_stem === :zz
        @test fieldnames(GM.CaptureDecl) == (:attr_scheme, :attr_stem)
    end

    @testset "[9] the stem-overlap collapse (the identity and stem-clash laws removed; the mode-gate coherence law with the Heading's separate path)" begin
        # a mock declaring the shipped :label stem PUBLISHES; on ONE cell the two plugins' same-attr
        # rows collapse to one `label_label1` row — the silent cross-plugin supersede the stem-clash law refused
        # (measured: [b]; full structural namespacing is T11's row)
        bc = _mockb(; capture = GM.CaptureDecl(:per_key; attr_stem = :label))
        rc = GM.goMeta(_doc("x = 1\n#~ :label1 zmark(label1)\n\ny = 2\n"); registry = GM.publish(bc))
        @test rc.status === GM.PROCESS_OK &&
              [t[2] for t in GM.readAltValuesEvals(rc.altValues_evals)] == [:label_label1]
    end

    @testset "[10] the derived-fallback stem (a mock with attr_stem = nothing)" begin
        R = GM.publish(_mockb(; capture = GM.CaptureDecl(:per_key)))
        r = GM.goMeta(_doc("x = 1\n#~ zmark(aa)\n\ny = 2\n"); registry = R)
        @test any(t -> t[2] === :zmock_aa, GM.readAltValuesEvals(r.altValues_evals))   # lowercase(String(:zmock)) = "zmock"
    end

    @testset "[11] the review cure witnesses (the floor warning, the scheme law and the store law removed with the Heading's separate path)" begin
        # (A1) a `localOnly` Alterant with capture === nothing: through the loop it is queued and applied like every action and
        # MINTS NOTHING — no row, no diagnostic (the capture floor's coded warning was removed with the separate path; a record without a row
        # mints nothing, as for every Alterant)
        b1 = GM.RegistryBuilder(GM.DEFAULT_REGISTRY)
        p1 = GM.next_plugin_index(b1)
        GM.register!(b1,
            GM.Alterant(; altName = :znone, setMode = :localOnly,
                altConstructor = GM.Alterants.Heading, setAltInstance = GM.Alterants.setHead),
            GM.ActionSpec(; name = :znh, plugin = p1, accepts_string_slot = 1))
        r1 = GM.goMeta(_doc("x = 1\n#~ \"T\" znh(\"V\", 2)\n\ny = 2\n"); registry = GM.publish(b1))
        @test r1.status === GM.PROCESS_OK && isempty(r1.diagnostics) &&
              !any(t -> t[3] == "V", GM.readAltValuesEvals(r1.altValues_evals)) &&
              any(t -> t[2] === :head_1 && t[3] == "T", GM.readAltValuesEvals(r1.altValues_evals))
        # (A5 — the localOnly scheme law — and A4/C3 — the localOnly store law — were RETIRED with
        # the former separate path's flush they guarded: a `localOnly` record declares its scheme like any record, and a store outside
        # its scheme's shape is Julia's own error at the capture, as for every Alterant.)
        # (A6; the stem-clash law removed) :label_x beside the shipped :label family
        # PUBLISHES; distinct keys mint distinct rows (measured: label_label1 · label_x_aa)
        bp = _mockb(; capture = GM.CaptureDecl(:per_key; attr_stem = :label_x))
        rp = GM.goMeta(_doc("x = 1\n#~ :label1 zmark(aa)\n\ny = 2\n"); registry = GM.publish(bp))
        @test rp.status === GM.PROCESS_OK &&
              sort([t[2] for t in GM.readAltValuesEvals(rp.altValues_evals)]) == [:label_label1, :label_x_aa]
    end

    @testset "[12] the deriving form's level is the set mode `localOnly`'s alone" begin
        # a String-slot action of ANOTHER set mode, stated with ONE quoted argument, is handed that one argument — no placement level
        # appended (the retired separate path's scope); fed through the profile it meets no internal error — the status alone asserts it:
        # over this meta-free document the fed action applies nowhere (no Block attached to meta — userfeed_visib_tests.jl [U3])
        b = GM.RegistryBuilder(GM.DEFAULT_REGISTRY)
        pi = GM.next_plugin_index(b)
        GM.register!(b,
            GM.Alterant(; altName = :znote, setMode = :accumulate, altConstructor = Dict{Symbol,Bool},
                setAltInstance = _CapM.nset, capture = GM.CaptureDecl(:per_key; attr_stem = :zn)),
            GM.ActionSpec(; name = :znt, plugin = pi, accepts_string_slot = 1))
        R = GM.publish(b)
        rows = GM.readAltValuesEvals(GM.goMeta(_doc("#~ znt(\"x\")\nx = 1\n"); registry = R).altValues_evals)
        rf = GM.goMeta(_doc("x = 1\n"); config = GM.GoMetaConfig(user_mh_profile = "znt(\"y\")"), registry = R)
        @test any(t -> t[2] === :zn_n1, rows) && !any(t -> t[2] === :zn_n2, rows) && rf.status === GM.PROCESS_OK
    end
end
