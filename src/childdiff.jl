# childdiff.jl — THE CHILD-DIFFERS SIGNAL, COMPUTED FROM THE ANSWER (stage 2's commit 6 of the v0.4 build; R-V04B-35 (e) — "his (ii)
# child-differs signal COMPUTED from that answer, its stored form left to the benchmark phase he named"; the plan v8.1 :58; his §37 item 4.2
# — the evaluations of a Block's child Components "only REQUIRE to be explicitly recorded … IF they differ from their parent's corresponding
# evaluation"; OQ-148).
#
# IS:   one Boolean per Component per Alterant — does the Component's resolved answer DIFFER from its parent's? — derived from `answerFor`
#       (commit 4) at the call; nothing stored (the stored form is the benchmark phase's).
# DOES: compares the two answers' VALUES (a Segment's with its Line's, a Line's with its Block's, a Block's with the File's); the source is
#       not part of the signal — a child inheriting its parent's value does not differ although its source reads `:indirect`; the File has
#       no parent and never differs.
# REASONING: his §37 item 4.2 names the signal as the rule for what a child needs recorded; computed from the one answer function it can
#       never disagree with the rows; the File's side (today `:none`, so a Block with any VALUE differs and a Block answering `:none` does
#       not) is the File's case at the review. His (ii) Boolean sits beside a PARENT's entry and asks whether ANY of its children differ —
#       `any` of this function over the parent's children; this function is the per-child primitive (his §37 item 4.2's question for ONE
#       child); the aggregate's own form — a function of its own, or the stored flag beside the parent's row — is the benchmark phase's.
# PURPOSE: the Extension's and the benchmark phase's "does this child need its own record" (R-V04B-35 (e)). Package-public; NOT exported;
#       NOT FINAL (the name, the Block-against-File reading, at the review).

"""
    childDiffers(delivery::GoMetaDelivery, component, alterant::Symbol; registry::AlterantRegistry = DEFAULT_REGISTRY) -> Bool

IS: THE CHILD-DIFFERS SIGNAL (R-V04B-35 (e); his §37 item 4.2) — `true` when the Component's resolved answer for the Alterant
(`answerFor`) has a VALUE different from its parent's resolved answer; COMPUTED at the call, never stored.
DOES: `!isequal(answerFor(c).value, answerFor(parent(c)).value)` — a Segment against its Line, a Line against its Block, a Block
against the File (which answers `nothing` at v0.4 — NOTHING built for it, card 6 "next" — so a Block with any VALUE, the declared
default included, differs, and a Block answering `:none` — value `nothing`: an Alterant without a declared default and no rows, Labels
today — does not); the File itself → `false`. A rowless child, which inherits its parent's rows, never differs; a child with
its own statement differs exactly when that statement's value is another. An unknown Alterant name throws `ArgumentError` (through
`answerFor`) for every Component but the File, whose `false` precedes the name's check. HIS (ii) BOOLEAN sits beside the PARENT's
entry and asks whether ANY of its children differ — for a parent P it is `any(c -> childDiffers(delivery, c, alterant),
BLS.children(delivery.blsComponentTree, P))`; this function is the per-child primitive (his §37 item 4.2's question for ONE child)
from which that aggregate is computed; the aggregate's own form — a function of its own, or the stored flag beside the parent's row —
is the benchmark phase's (the seat of commit 6, F-3). Pure.
REASONING: the signal is what a child needs recorded (his §37 item 4.2, OQ-148); derived from the one answer function, it can never
disagree with the rows; the VALUE is compared, not the source, because a child hidden "as PART OF" its Block (his §7 item 2) is not a
difference.
PURPOSE: the Extension's and the benchmark phase's question (R-V04B-35 (e): "its stored form left to the benchmark phase"). Package-
public (docs/public-api.md §1.2), NOT exported; NOT FINAL until the review (the name; the Block-against-File reading).
"""
function childDiffers(delivery::GoMetaDelivery, component::BLS.AbstractComponent, alterant::Symbol;
                      registry::AlterantRegistry = DEFAULT_REGISTRY)::Bool
    component isa BLS.File && return false
    par = BLS.parent(delivery.blsComponentTree, component)
    par === nothing && return false
    mine = answerFor(delivery, component, alterant; registry = registry)
    theirs = answerFor(delivery, par, alterant; registry = registry)
    return !isequal(mine.value, theirs.value)
end
