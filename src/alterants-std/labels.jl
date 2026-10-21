## labels.jl — THE LABELS ALTERANT'S OWN FILE (the creator's words:
## 2026-08-22 — the whitelist "for some unknown reason hard part of GoMeta Core. That is a MISTAKE and must be rectified.
## It is NOT a new feature or improvement, it is fixing a bug."; 2026-10-08 — "CC and/or the user may add labels by simply
## writing it into the code of the Labels Alterant (i.e.: hard coded). … If the label :doc or some other label is required, then
## simply hard code it into the Alterant for now."; "a basic true Labels Alterant first, inside v0.4. Keep it SIMPLE AND
## ELEGANT."). Under `alterants-std/` — the std-Alterants' territory
## (never a Core literal; vocabulary_tests [10] scans `src/` around this directory).
##
## IS:   the Labels Alterant's code — THE HARD-CODED LIST `LABELS_VOCABULARY` (the 38 names the plain file `labels_vocabulary.txt`
##       carried before, in that file's order, plus `:doc`; a later name is one line here — the creator's decision; none of the
##       original engine's other names; `public` / `private` out for now); `setLabels` — the closed check, the
##       original engine's (GoMetaRetro Alterants.jl :73–:78 at 47f0521: an applied name outside the list refuses with a message naming the
##       accepted set, sorted for display); `checkLabels` — the original engine's checker (:87–:99): an unset or unknown name answers false.
## DOES: moved here byte for byte from `src/alterants/registry.jl` (the two functions) — their module stays `Alterants`, their
##       behaviour the original engine's; nothing of the August design (`++` / `--` / import / declared sets) — later; the
##       original engine's TODO stands (GoMetaRetro Alterants.jl :61–:62 at 47f0521, carried here from the removed loader):
##       an expandable container for NEW labels added from within the metaData — later.
## REASONING: the ∈-scan over the list in declaration order (the C4E-4 law — never `insorted` over an unsorted declaration);
##       the ZWJ name `⛓️‍💥` is one name (its former `query=false` field was inert data).
## PURPOSE: a basic, true Labels Alterant that works at least as well as the original engine's — the whitelist where it belongs.

"the hard-coded Labels vocabulary — the 38 shipped names in the former plain file's order, plus `:doc` (39 names)"
const LABELS_VOCABULARY = Symbol[Symbol(n) for n in (
    "label1",
    "label2",
    "label3",
    "label4",
    "label5",
    "⛔",
    "💯",
    "🇨🇭",
    "🏔️",
    "🍒",
    "🫕",
    "💡",
    "💣",
    "🧮",
    "📝",
    "💕",
    "⌛",
    "💸",
    "💾",
    "⛓️‍💥",
    "⛓️",
    "📸",
    "🎨",
    "🍻",
    "🔥",
    "🐣",
    "😘",
    "🎿",
    "🚀",
    "🌍",
    "🌳",
    "🌛",
    "🌷",
    "🌹",
    "🌼",
    "🍀",
    "🌞",
    "💫",
    "doc",
)]

function setLabels(
    crntLabels::Dict{Symbol,Bool}, # The Alterant here.
    actionName::Symbol,
    labels::Vararg{Symbol} # 
)

    if actionName == :(:)
        ## §4.8 guard (v0.3.1, "fixed WITHIN THE Labels Alterant"): a lone ':'
        ## (or ':()') reaches this setter with ZERO labels — the vacuous loop below then stored
        ## nothing, minted no evals row, and the author's mistyped label vanished SILENTLY
        ## (probe m_lone_colon). The Alterant verifies its own input: an empty label list
        ## refuses loudly. error() (not ArgumentError): chosen when a former setter seam —
        ## since removed — reduced an ArgumentError to its type name; an ArgumentError now
        ## propagates with its message; kept as the Alterant's own refusal (the unknown-label mechanics below).
        isempty(labels) && error("GoMeta apply: empty label list — the labels action ':' ",
            "names no label; v0 requires at least one label (e.g. ':label1'); ",
            "see docs/public-api.md §3.4")
        ## the closed check (the original engine's): the ∈-scan over the file's order (never `insorted` over declaration
        ## order — the C4E-4 law); the refusal renders a SORTED display copy of the accepted set
        for label ∈ labels
            if label ∈ LABELS_VOCABULARY
                crntLabels[label] = true
            else
                error("GoMeta apply: unknown label ", repr(first(String(label), 40)),
                    " — not in v0's closed label whitelist (the accepted set = ",
                    sort(copy(LABELS_VOCABULARY)), "); see docs/public-api.md §3.4")
            end
        end
    else
        error("GoMeta internal invariant violated: setLabels called with actionName = ",
            actionName, " != :(:) — please report this (not reachable from any v0 input)")
    end
end

function checkLabels(
    crntLabels::Dict{Symbol,Bool}, # The Alterant here.
    actionName::Symbol,
    labels::Vararg{Symbol}
)
    ## §4.8 twin guard (v0.3.1, with the setLabels guard above): the word-less
    ## label query ':()' reached this checker with ZERO labels and returned a vacuous TRUE —
    ## a wrong-outcome class (the K5/K6 family). The K2 pin that held the misapply at its old
    ## fate ("so it cannot drift silently") is flipped by name in the same change. The corpus
    ## sweep (v0.3.1) found no input depending on the vacuous form.
    isempty(labels) && error("GoMeta apply: empty label query — ':()' names no label to ",
        "check; v0 requires at least one label (e.g. ':(:label1)'); ",
        "see docs/public-api.md §3.4")
    ## no membership gate, no valve: a label outside the shipped set is simply not set — the query answers false
    ## (the original engine's checker, GoMetaRetro Alterants.jl :87–:99; a membership refusal and a write-only
    ## valve of the 0.4 development were removed)
    for label ∈ labels
        if label ∉ keys(crntLabels)
            return false
        end
    end
    return true
end
