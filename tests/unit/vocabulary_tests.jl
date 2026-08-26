# vocabulary_tests.jl — v0.4 T4: the WHITELIST-RELOCATION witnesses (T4-DESIGN §6).
#
# IS:   the T4 acceptance witnesses — the digest-pinned artifact loads and the DEFAULT
#       publishes through the `_vocabulary_collect!` gate; membership is unchanged and
#       ORDER-INDEPENDENT; the registration-surface FLIP (a record's declared vocabulary
#       governs, zero code edits — M-AC-12); the ZWJ write-only valve at its REACHABLE
#       seam (direct checkLabels) + the absorb-shape sibling pin; the stale-pin and
#       malformed-artifact refusal classes; the G-VOC read surface with its
#       DEFENSIVE-COPY ownership rule; the re-homed T3 checkpoint-(7) ledger-keying
#       assert; and the zero-literal law in its DECIDABLE form.
# DOES: drives the shipped vocabulary end-to-end through goMeta, publishes builders whose
#       labels record carries a DIFFERENT vocabulary declaration (inline · stale
#       VocabularyRef), calls the loader's parse seam on malformed temp bytes, and greps
#       the src tree against the ENUMERATED survivor census.
# REASONING: the relocation is a BUG-FIX with a byte-identical corpus (R-V04-20/29) — no
#       golden or corpus path can distinguish a Core literal from a declared artifact, so
#       these witnesses are the only proof the declaration is LOAD-BEARING (the flip),
#       the pin is INDEPENDENT (the stale-pin row), and the planes read ONE source.
# PURPOSE: the T4 acceptance rows (Σ = 18 asserts here; +2 in snapshot_property_tests'
#       VocabularyRef named case = the T4-DESIGN §6 Σ = 20).

using Test
import GoMeta as GM
import SHA

@testset "vocabulary (v0.4 T4)" begin

    _zwj = Symbol("⛓️‍💥")
    _doc(s) = Vector{UInt8}(codeunits(s))
    _drive(s; R = GM.DEFAULT_REGISTRY) = try
        GM.goMeta(_doc(s); registry = R)
    catch e
        e
    end
    # a DEFAULT-derived builder with the labels record's vocabulary slot REPLACED
    _vocab_builder(slot) = begin
        b = GM.RegistryBuilder(GM.DEFAULT_REGISTRY)
        b.plugins[1] = GM.PlugIn(; altName = :labels, setMode = :accumulate,
            altConstructor = Dict{Symbol,Bool}, setAltInstance = GM.Alterants.setLabels,
            getAltInstance = GM.Alterants.checkLabels, vocabulary = slot)
        b
    end

    @testset "[1] the DEFAULT publishes through the gate; the door is silent" begin
        # `import GoMeta` ran the load-time capture AND the publication-time re-verify
        # (`_vocabulary_collect!` on the DEFAULT's VocabularyRef) — the fail-closed law:
        # a tampered shipped artifact would have failed `using GoMeta` before this line.
        @test GM.DEFAULT_REGISTRY isa GM.AlterantRegistry
        @test isempty(GM._registry_door_check(GM.DEFAULT_REGISTRY))
    end

    @testset "[2] membership UNCHANGED end-to-end (the relocation is behavior-zero)" begin
        r = _drive("x = 1\n#~ :label1\n\ny = 2\n")
        @test r isa GM.GoMetaResult && r.status === GM.PROCESS_OK
        e = _drive("x = 1\n#~ :nope\n\ny = 2\n")
        @test e isa ErrorException && occursin("unknown label", e.msg)
    end

    @testset "[3] the LATE-order name :💫 (the C4E-4 order-independence pin)" begin
        # `:💫` sits late in DECLARATION order, which is UNSORTED — an `insorted` scan
        # over it would silently lose the names after the first sort break while the
        # corpus stayed green (the 28/38 class). Both roles must pass through the ∈-scan.
        rs = _drive("x = 1\n#~ :💫\n\ny = 2\n")
        @test rs isa GM.GoMetaResult && rs.status === GM.PROCESS_OK
        rq = _drive("x = 1\n#~1 :💫 hide{ :💫 }\n\ny = 2\n")
        @test rq isa GM.GoMetaResult && rq.status === GM.PROCESS_OK
    end

    @testset "[4] the registration-surface FLIP (M-AC-12: the declaration is load-bearing)" begin
        Rz = GM.publish(_vocab_builder(GM.InlineVocabulary([:zz1],
            Dict(:zz1 => (query = true,)))))
        rz = _drive("x = 1\n#~ :zz1\n\ny = 2\n"; R = Rz)
        @test rz isa GM.GoMetaResult && rz.status === GM.PROCESS_OK
        ez = _drive("x = 1\n#~ :label1\n\ny = 2\n"; R = Rz)   # the SHIPPED name is now foreign
        @test ez isa ErrorException && occursin("unknown label", ez.msg) &&
              occursin("zz1", ez.msg)
    end

    @testset "[5] the ZWJ write-only valve at its REACHABLE seam + the absorb-shape sibling" begin
        d = Dict{Symbol,Bool}()
        GM.Alterants.setLabels(d, :(:), _zwj)                 # setting the valve name works
        @test d[_zwj] === true
        eq = try GM.Alterants.checkLabels(d, :(:), _zwj); nothing catch err; err end
        @test eq isa ErrorException && occursin("write-only", eq.msg)
        # the SIBLING pin (C4E-3, probe-measured): the ZWJ name cannot ride a DOCUMENT
        # condition — the absorb-shape refusal PRECEDES the valve (the U+200D joiner
        # breaks the condition scan), so direct checkLabels above is the valve's ONLY
        # reachable seam at v0.
        ea = _drive("x = 1\n#~1 :⛓️‍💥 hide{ :⛓️‍💥 }\n\ny = 2\n")
        @test ea isa ErrorException && occursin("unparsable condition", ea.msg) &&
              !occursin("write-only", ea.msg)
    end

    @testset "[6] the refusal classes: the STALE pin (publication) · the MALFORMED copy (load)" begin
        # a TAMPERED artifact copy against the ORIGINAL declared pin: the captured cache
        # holds only the shipped digest, so a builder declaring the tampered bytes' digest
        # (any digest the loader never captured) meets the publication-time
        # `:SRC_DIGEST_MISMATCH` row — the R-V04-37 re-verify, NON-circular by the
        # independent declared literal.
        tam = copy(GM.Alterants._LABELS_ARTIFACT_BYTES)
        append!(tam, _doc("zzz\n"))
        stale = "sha256:" * Base.bytes2hex(SHA.sha256(tam))
        dt = GM.validate(_vocab_builder(GM.VocabularyRef(
            GM.DomainRef("alterants-std/labels_vocabulary.txt", stale))))
        @test any(x -> x.code === :SRC_DIGEST_MISMATCH && x.context === :labels &&
                       occursin("matches NO loaded artifact", x.message), dt)
        # a MALFORMED copy fails at the PARSE arm (its own digest would verify — crx
        # C11's argument law: the parse witness must not be masked by a digest mismatch,
        # so the parser seam is driven DIRECTLY on the malformed bytes).
        em = try GM.Alterants._parse_labels_vocabulary(_doc("ok\n\nbad\n"), "tmp-malformed")
            nothing
        catch err; err end
        @test em isa ErrorException && occursin("MALFORMED (blank line)", em.msg) &&
              occursin("line 2", em.msg)
    end

    @testset "[7] the G-VOC read surface over the DEFAULT" begin
        v = GM.vocabulary(GM.DEFAULT_REGISTRY, :labels)
        @test v isa GM.InlineVocabulary && length(v.names) == 38 && v.names[1] === :label1
        @test v.flags[_zwj] == (query = false,)               # the declared valve, disclosed
    end

    @testset "[8] the seam ledger keys by IDENTITY (the re-homed T3 checkpoint-(7) assert)" begin
        _mkps() = begin
            ps = GM.BLS.setUpToProcessFromBytes(_doc("x = 1\n#~ hide\n\ny = 2\n"))
            GM.BLS.parseBLS(ps, 1, -1)
            ps
        end
        P = GM.publish(GM.default_registry_builder())
        psA = _mkps(); psB = _mkps()                          # equal CONTENT, distinct objects
        GM.run_absorb_apply!(psA; registry = P)               # hide writes back ⇒ both bind
        GM.run_absorb_apply!(psB; registry = P)
        eA, eB = lock(GM._SEAM_LEDGER_LOCK) do
            (get(GM._SEAM_LEDGER, psA, nothing), get(GM._SEAM_LEDGER, psB, nothing))
        end
        @test eA isa GM._SeamEntry && eB isa GM._SeamEntry && eA !== eB
    end

    @testset "[9] the DEFENSIVE-COPY ownership rule (mutating a returned copy changes nothing)" begin
        v = GM.vocabulary(GM.DEFAULT_REGISTRY, :labels)
        push!(v.names, :evil); v.flags[:evil] = (query = true,)
        @test !GM.vocabulary_member(GM.DEFAULT_REGISTRY, :labels, :evil) &&
              length(GM.vocabulary(GM.DEFAULT_REGISTRY, :labels).names) == 38
    end

    @testset "[10] the zero-literal law (the C4E-7 DECIDABLE form)" begin
        # (a) the deleted collection identifiers survive NOWHERE in src outside
        # `alterants-std/` on a NON-comment line (the tombstone comments are prose);
        # (b) the vocabulary-name literal census over src (the union pattern
        # `label1` ∪ `:🔥`) equals EXACTLY the enumerated survivor set — every survivor
        # is prose (docstrings, comments, the two kept empty-list-message examples), so
        # any new enumeration of shipped names re-entering Core trips this comparison.
        srcdir = joinpath(dirname(dirname(@__DIR__)), "src")
        id_offenders = String[]
        census = Dict{String,Int}()
        for (root, _, files) in walkdir(srcdir)
            occursin("alterants-std", root) && continue
            for f in files
                endswith(f, ".jl") || continue
                fp = joinpath(root, f)
                rel = replace(relpath(fp, srcdir), '\\' => '/')
                for (i, ln) in enumerate(eachline(fp))
                    if !startswith(lstrip(ln), "#") &&
                       (occursin("goMetaLabels", ln) || occursin("sortedSetOfLabelsSVec", ln))
                        push!(id_offenders, string(rel, ":", i))
                    end
                    if occursin("label1", ln) || occursin(":🔥", ln)
                        census[rel] = get(census, rel, 0) + 1
                    end
                end
            end
        end
        survivors = Dict("config.jl" => 1,                    # §1 feed docstring example
                         "condition.jl" => 4,                 # the `{:🔥}` + `:abc(:label1)` comment set
                         "GoMeta.jl" => 1,                    # the profile-feed docstring example
                         "alterants/apply.jl" => 1,           # the condition-side-atoms comment
                         "alterants/registry.jl" => 3)        # the header note + the TWO kept empty-list messages
        @test isempty(id_offenders) && census == survivors
    end
end
