# labels_vocabulary_file_tests.jl — THE VOCABULARY FILES OF THE LABELS ALTERANT (0.4.3) — the creator's design: the vocabulary in a data file
# outside the Engine; a user's additions and removals PERSISTENT in a file of the user's own, the shipped file never written and the revert
# source; every persisted change reported. The code: src/alterants-std/labels.jl (`shipped_vocabulary_path`, `user_vocabulary_path`,
# `parse_vocabulary`, `base_vocabulary` with its memo, `_persist_vocabulary!`, the hook `declareLabels!`), src/arguments.jl (the edge class the
# lines are trimmed with), the data file data/alterants-std/labels-vocabulary.txt.
#
# IS:   twelve witnesses [F1]–[F12] over the files and the public entry, EVERY expected value READ from the measured printouts of the built
#       tree (the F set F00 … F18: the run log and the traces with the files printed whole; the view of each run). Every witness names its OWN
#       temporary user file (`TestSupport.fresh_vocabulary!()`) — the real one (`~/.gometa/labels-vocabulary.txt`) is never touched; the path
#       with the variable unset is computed, never created. THE PATHS ([F1]); THE FIRST NEED creates the user file from the shipped one, 46
#       names ([F2]); THE MEMO — the same object twice, a file changed by hand seen ([F3]); `++` PERSISTS — the info row with its read-time
#       place, the file's line, a later run on the same file ([F4]); `--` PERSISTS — the line removed, the comments kept, a later run reports
#       ([F5]); a SHIPPED name removed for good, the shipped file untouched ([F6]); THE NO-OPS ([F7]); THE PROFILE's statement persists ([F8]);
#       two names in one list, an add then a remove on one line ([F9]); THE FORM of a file — comments, blank lines, the edge trim, a duplicate,
#       CRLF; an inner invisible character refused with the line named ([F10]); a user file that cannot be created — the shipped file read, a
#       `++` reported NOT_WRITTEN ([F11]); the memo after a run's write ([F12]).
# REASONING: the one function `base_vocabulary()` reads the user file once and remembers it by its stat (a `stat` per call, never a read); the
#       hook edits the file atomically and returns the run state with the rows the Engine's door delivers at the read, for every Alterant alike.
# PURPOSE: the vocabulary files, measured — never inferred from the docstrings or from prose.

using Test
import GoMeta as GM
const _VF = GM.Alterants

_vf_bytes(s::String) = Vector{UInt8}(codeunits(s))
_vf_run(s::String; profile = nothing) = GM.goMeta(_vf_bytes(s); config = GM.GoMetaConfig(; user_mh_profile = profile))   # NO fresh file here: the witnesses name their own
_vf_fresh() = TestSupport.fresh_vocabulary!()
_vf_user() = ENV["GOMETA_LABELS_VOCABULARY"]
_vf_names(p) = _VF.parse_vocabulary(read(p, String), p)
_vf_rows(r) = GM.readAltValuesEvals(r.altValues_evals)
_vf_keys(r) = [GM.key_bytes(GM.occurrence_key(r.blsComponentTree, b)) for b in GM.BLS.children(r.blsComponentTree)]
const _VF_KU = GM.key_bytes(GM.user_context_key(:default, 1))
const _VF_SHIPPED = _VF.shipped_vocabulary_path()
const _VF_SHIPPED_BYTES = read(_VF_SHIPPED)
"the shipped list, as the shipped file's comments state it: label1 … label5, doc, the 33 pictograph names in the glued form, the seven everyday names"
function _vf_shipped_shape(names)
    @test length(names) == 46 && names[1:6] == [:label1, :label2, :label3, :label4, :label5, :doc]
    @test names[end-6:end] == [:warning, :note, :info, :definition, :todo, :public, :private]
    @test all(n -> startswith(String(n), "label") && length(String(n)) > 5 && !isdigit(String(n)[6]), names[7:39]) && length(unique(names)) == 46
end
"one `LABELS_VOCABULARY_FILE_CHANGED` info row with the read-time place the door attached"
function _vf_info(d, change::Symbol, label::Symbol, stated_by::Vector{UInt8}, level::Int, statement::String)
    @test d.code === :LABELS_VOCABULARY_FILE_CHANGED && d.severity === :info
    @test d.context == (file = _vf_user(), change = change, label = label, stated_by = stated_by, level = level, statement = statement)
    head = change === :added ? "GoMeta absorb: `:++$label` added $label to the vocabulary file " : "GoMeta absorb: `:--$label` removed $label from the vocabulary file "
    tail = change === :added ? " — it holds for this run and every later one; `:--$label` removes it again; see docs/public-api.md §2" :
                               " — it is unknown for this run and every later one; `:++$label` adds it again (the shipped file keeps the original list); see docs/public-api.md §2"
    @test d.message == head * _vf_user() * tail
end

@testset "the vocabulary files of the Labels Alterant (0.4.3)" begin

    @testset "[F1] the paths: the shipped file in the package's top-level data folder, located through the package's directory at run time; the user file the environment variable's path, else `~/.gometa/labels-vocabulary.txt` (computed here, never created)" begin
        @test _VF_SHIPPED == joinpath(pkgdir(GM), "data", "alterants-std", "labels-vocabulary.txt") && isfile(_VF_SHIPPED)
        @test _VF.LABELS_VOCABULARY_ENV == "GOMETA_LABELS_VOCABULARY" && _VF.user_vocabulary_path() == ENV["GOMETA_LABELS_VOCABULARY"]
        saved = ENV["GOMETA_LABELS_VOCABULARY"]
        try
            delete!(ENV, "GOMETA_LABELS_VOCABULARY"); @test _VF.user_vocabulary_path() == joinpath(homedir(), ".gometa", "labels-vocabulary.txt")
            ENV["GOMETA_LABELS_VOCABULARY"] = ""; @test _VF.user_vocabulary_path() == joinpath(homedir(), ".gometa", "labels-vocabulary.txt")   # an empty value: unset
        finally
            ENV["GOMETA_LABELS_VOCABULARY"] = saved
        end
    end

    @testset "[F2] the first need creates the user file from the shipped one — byte-equal — and reads it: 46 names in the shipped order (F01, F02)" begin
        p = _vf_fresh(); @test !isfile(p)
        r = _vf_run("#~ :label1\nx = 1\n"); @test r.status === GM.PROCESS_OK && length(_vf_rows(r)) == 2 && isempty(r.diagnostics)
        @test isfile(p) && read(p) == _VF_SHIPPED_BYTES
        names = _VF.base_vocabulary(); _vf_shipped_shape(names); @test names == _vf_names(_VF_SHIPPED)
        @test :doc ∈ names && :todo ∈ names && Symbol("label" * string(Char(0x1F340))) ∈ names && Symbol(string(Char(0x1F340))) ∉ names   # the clover: glued, not bare
    end

    @testset "[F3] the memo: `base_vocabulary()` twice is the same object; a file edited by hand is read again at the next call — a new object with the name (F02, F03)" begin
        _vf_fresh()
        b1 = _VF.base_vocabulary(); b2 = _VF.base_vocabulary(); @test b1 === b2 && length(b1) == 46
        open(_vf_user(), "a") do io; write(io, "zzz\n"); end
        b3 = _VF.base_vocabulary(); @test !(b3 === b1) && :zzz ∈ b3 && length(b3) == 47 && _VF._VOCAB_MEMO[].names === b3
        r = _vf_run("#~ :zzz\nx = 1\n"); @test r.status === GM.PROCESS_OK && length(_vf_rows(r)) == 2 && isempty(r.diagnostics)   # the hand-added name applies
    end

    @testset "[F4] `++` persists (F04, F05): the info row with the read-time place — the stating metaBlock, level 1, the statement's text — the name appended as the file's last line, the comments kept; a later run on the SAME file knows the name, no row" begin
        _vf_fresh()
        r = _vf_run("#~0 :++zzz\n#~ :zzz\nx = 1\n"); @test r.status === GM.PROCESS_OK && length(_vf_rows(r)) == 2 && all(t -> t[2] === :label_zzz, _vf_rows(r)); k = _vf_keys(r)
        @test length(r.diagnostics) == 1; _vf_info(r.diagnostics[1], :added, :zzz, k[1], 1, ":++zzz")
        text = read(_vf_user(), String); @test endswith(text, "private\nzzz\n") && count(l -> startswith(l, "#"), split(text, '\n')) == count(l -> startswith(l, "#"), split(String(copy(_VF_SHIPPED_BYTES)), '\n'))   # `String(v)` empties `v` — a copy
        @test _vf_names(_vf_user()) == vcat(_vf_names(_VF_SHIPPED), [:zzz])
        r2 = _vf_run("#~ :zzz\nx = 1\n"); @test r2.status === GM.PROCESS_OK && length(_vf_rows(r2)) == 2 && isempty(r2.diagnostics)   # F05
    end

    @testset "[F5] `--` persists (F06): the name's line removed, the comments kept, the info row; a later run on the same file reports the name" begin
        _vf_fresh(); _vf_run("#~0 :++zzz\nx = 1\n"); @test :zzz ∈ _vf_names(_vf_user())
        r = _vf_run("#~0 :--zzz\nx = 1\n"); @test r.status === GM.PROCESS_OK && isempty(_vf_rows(r)); k = _vf_keys(r)
        @test length(r.diagnostics) == 1; _vf_info(r.diagnostics[1], :removed, :zzz, k[1], 1, ":--zzz")
        @test :zzz ∉ _vf_names(_vf_user()) && _vf_names(_vf_user()) == _vf_names(_VF_SHIPPED) && count(l -> startswith(l, "#"), readlines(_vf_user())) == 11
        r2 = _vf_run("#~ :zzz\nx = 1\n"); @test r2.status === GM.PROCESS_OK && isempty(_vf_rows(r2)) && length(r2.diagnostics) == 2 && all(d -> d.code === :LABEL_NOT_APPLIED_UNKNOWN, r2.diagnostics)
    end

    @testset "[F6] a SHIPPED name removed for good (F07): the user file 45 names, a later `:label1` on it reported; the shipped file untouched" begin
        _vf_fresh()
        r = _vf_run("#~0 :--label1\nx = 1\n"); @test r.status === GM.PROCESS_OK && length(r.diagnostics) == 1 && r.diagnostics[1].context.change === :removed
        @test :label1 ∉ _vf_names(_vf_user()) && length(_vf_names(_vf_user())) == 45
        r2 = _vf_run("#~ :label1\nx = 1\n"); @test r2.status === GM.PROCESS_OK && isempty(_vf_rows(r2)) && length(r2.diagnostics) == 2 && all(d -> d.code === :LABEL_NOT_APPLIED_UNKNOWN && d.context.label === :label1, r2.diagnostics)
        @test read(_VF_SHIPPED) == _VF_SHIPPED_BYTES
    end

    @testset "[F7] the no-ops (F08, F08b): `++` of a shipped name, `--` of a name never present — nothing written (the user file byte-equal to the shipped), nothing reported" begin
        _vf_fresh(); r = _vf_run("#~0 :++label1\n#~ :label1\nx = 1\n"); @test r.status === GM.PROCESS_OK && length(_vf_rows(r)) == 2 && isempty(r.diagnostics) && read(_vf_user()) == _VF_SHIPPED_BYTES
        _vf_fresh(); r = _vf_run("#~0 :--qqq\nx = 1\n"); @test r.status === GM.PROCESS_OK && isempty(_vf_rows(r)) && isempty(r.diagnostics) && read(_vf_user()) == _VF_SHIPPED_BYTES
    end

    @testset "[F8] the profile's statement persists too (F09): the info row stated by the user context, level 10" begin
        _vf_fresh()
        r = _vf_run("#~ :zzz\nx = 1\n"; profile = ":++zzz"); @test r.status === GM.PROCESS_OK && length(_vf_rows(r)) == 2
        @test length(r.diagnostics) == 1; _vf_info(r.diagnostics[1], :added, :zzz, _VF_KU, 10, ":++zzz"); @test :zzz ∈ _vf_names(_vf_user())
    end

    @testset "[F9] two names in one list (F10) — two info rows in the list's order; an add then a remove on one line (F10b) — two info rows, the file back to the shipped bytes, the use reported" begin
        _vf_fresh()
        r = _vf_run("#~0 :(++, aa, bb)\n#~ :(aa, bb)\nx = 1\n"); @test r.status === GM.PROCESS_OK && length(_vf_rows(r)) == 4; k = _vf_keys(r)
        @test length(r.diagnostics) == 2; _vf_info(r.diagnostics[1], :added, :aa, k[1], 1, ":(++, aa, bb)"); _vf_info(r.diagnostics[2], :added, :bb, k[1], 1, ":(++, aa, bb)")
        @test _vf_names(_vf_user())[end-1:end] == [:aa, :bb]
        _vf_fresh()
        r = _vf_run("#~0 :++zzz :--zzz\n#~ :zzz\nx = 1\n"); @test r.status === GM.PROCESS_OK && isempty(_vf_rows(r)); k = _vf_keys(r); d = r.diagnostics; @test length(d) == 4
        _vf_info(d[1], :added, :zzz, k[1], 1, ":++zzz"); _vf_info(d[2], :removed, :zzz, k[1], 1, ":--zzz")
        @test d[3].code === :LABEL_NOT_APPLIED_UNKNOWN && d[4].code === :LABEL_NOT_APPLIED_UNKNOWN && read(_vf_user()) == _VF_SHIPPED_BYTES
    end

    @testset "[F10] the form of a file (F11 … F15): a comment, a blank line, edge spaces, a BOM, a tab, a no-break space, a zero-width space, a duplicate once, an indented comment, a CRLF line — four names; an invisible character INSIDE a name refuses with the line named; one name; an empty file" begin
        p = _vf_fresh()
        SP = string(Char(0x200B)); BOM = string(Char(0xFEFF)); NB = string(Char(0xA0))
        write(p, "# a comment\n\n  label1  \n" * BOM * "label2\t\n" * NB * "label3" * SP * "\nlabel1\n   # an indented comment\nlabel4\r\n")
        @test _VF.base_vocabulary() == [:label1, :label2, :label3, :label4]
        r = _vf_run("#~ :(label1, label2, label3, label4)\nx = 1\n"); @test r.status === GM.PROCESS_OK && length(_vf_rows(r)) == 8 && isempty(r.diagnostics)
        write(p, "label1\nab" * SP * "c\nlabel2\n")
        m = try; _VF.base_vocabulary(); nothing; catch e; sprint(showerror, e); end
        @test m == "GoMeta labels: the vocabulary file " * p * " carries white space or an invisible character inside a label name at line 2 — got \"ab" * string(Char(92)) * "u200bc\"; one name per line; see docs/public-api.md §2"
        write(p, "label1\nab c\n")
        m = try; _VF.base_vocabulary(); nothing; catch e; sprint(showerror, e); end
        @test m == "GoMeta labels: the vocabulary file " * p * " carries white space or an invisible character inside a label name at line 2 — got \"ab c\"; one name per line; see docs/public-api.md §2"
        write(p, "label1\n# only\n\n"); @test _VF.base_vocabulary() == [:label1]
        r = _vf_run("#~ :label2\nx = 1\n"); @test r.status === GM.PROCESS_OK && isempty(_vf_rows(r)) && length(r.diagnostics) == 2 && all(d -> d.code === :LABEL_NOT_APPLIED_UNKNOWN, r.diagnostics)
        write(p, ""); @test _VF.base_vocabulary() == Symbol[]
    end

    @testset "[F11] a user file that cannot be created (F16): the shipped file read directly — 46 names; a `++` reported by ONE `:warning` row `LABELS_VOCABULARY_FILE_NOT_WRITTEN`, the change holding for the run (the name applies)" begin
        d = mktempdir(); ro = joinpath(d, "ro"); mkpath(ro); chmod(ro, 0o500); p = joinpath(ro, "v.txt"); ENV["GOMETA_LABELS_VOCABULARY"] = p
        try
            if Sys.iswindows() || (isdir(ro) && try; touch(joinpath(ro, "probe")); rm(joinpath(ro, "probe")); true; catch; false; end)
                @test_skip false   # the directory is writable here (a privileged user): the witness cannot run on this machine — shown as skipped in the summary
            else
                n = _VF.base_vocabulary(); @test !isfile(p) && length(n) == 46
                r = _vf_run("#~0 :++zzz\n#~ :zzz\nx = 1\n"); @test r.status === GM.PROCESS_OK && length(_vf_rows(r)) == 2; k = _vf_keys(r)
                @test length(r.diagnostics) == 1 && r.diagnostics[1].code === :LABELS_VOCABULARY_FILE_NOT_WRITTEN && r.diagnostics[1].severity === :warning
                @test r.diagnostics[1].context == (file = p, change = :added, label = :zzz, stated_by = k[1], level = 1, statement = ":++zzz")
                @test startswith(r.diagnostics[1].message, "GoMeta absorb: `:++zzz` could not be written to the vocabulary file " * p * " (") && endswith(r.diagnostics[1].message, ") — the change holds for this run alone; see docs/public-api.md §2")
            end
        finally
            chmod(ro, 0o700); _vf_fresh()
        end
    end

    @testset "[F12] the memo after a run's write (F18): a new object with the name, the memo's names the returned vector" begin
        _vf_fresh()
        b1 = _VF.base_vocabulary(); _vf_run("#~0 :++zzz\nx = 1\n"); b2 = _VF.base_vocabulary()
        @test !(b2 === b1) && :zzz ∈ b2 && length(b1) == 46 && length(b2) == 47 && _VF._VOCAB_MEMO[].names === b2
    end
end
