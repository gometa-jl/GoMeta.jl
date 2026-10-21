# childdiff.jl — THE CHILD-DIFFERS SIGNAL, COMPUTED FROM THE ANSWER (the creator's design: a
# child-differs signal COMPUTED from the answer, its stored form left to a later benchmark phase; the creator's words
# — the evaluations of a Block's child Components "only REQUIRE to be explicitly recorded … IF they differ from their parent's corresponding
# evaluation").
#
# IS:   one Boolean per Component per Alterant — does the Component's resolved answer DIFFER from its parent's? — derived from `evaluatedAltValue`
#       at the call; nothing stored (the stored form is a later benchmark phase's).
# DOES: compares the two answers' VALUES (a Segment's with its Line's, a Line's with its Block's, a Block's with the File's); the source is
#       not part of the signal — a child inheriting its parent's value does not differ although its source reads `:indirect`; the File has
#       no parent and never differs.
# REASONING: the creator's words name the signal as the rule for what a child needs recorded; computed from the one answer function it can
#       never disagree with the rows; the File's side (today `:none`, so a Block with any VALUE differs and a Block answering `:none` does
#       not) is the File's case, an open point. The creator's Boolean sits beside a PARENT's entry and asks whether ANY of its children differ —
#       `any` of this function over the parent's children; this function is the per-child primitive (the creator's question for ONE
#       child); the aggregate's own form — a function of its own, or the stored flag beside the parent's row — is a later benchmark phase's.
# PURPOSE: the Extension's and a later benchmark phase's "does this child need its own record". Package-public; NOT exported;
#       the name the creator's word of 2026-10-03; the Block-against-File reading an open point.

"""
    childDiffers(delivery::GoMetaDelivery, component, alterant::Symbol; registry::AlterantRegistry = DEFAULT_REGISTRY) -> Bool

IS: THE CHILD-DIFFERS SIGNAL (the creator's design) — `true` when the Component's resolved answer for the Alterant
(`evaluatedAltValue`) has a VALUE different from its parent's resolved answer; COMPUTED at the call, never stored.
DOES: `!isequal(evaluatedAltValue(c).value, evaluatedAltValue(parent(c)).value)` — a Segment against its Line, a Line against its Block, a Block
against the File (which answers `nothing` at v0.4 — NOTHING built for it, an open point — so a Block with any VALUE, the declared
default included, differs — Labels', Heading's and Id's declared defaults as Visib's `:show`: a top Block
differs for Labels and Id, Heading's `nothing` against the File's `nothing` does not — and a Block answering `:none` — value `nothing`: an
Alterant of a custom registry without a declared default and no rows — does not); the File itself → `false`. A rowless child, which inherits its parent's rows, never differs; a child with
its own statement differs exactly when that statement's value is another. An unknown Alterant name throws `ArgumentError` (through
`evaluatedAltValue`) for every Component but the File, whose `false` precedes the name's check. THE CREATOR'S BOOLEAN sits beside the PARENT's
entry and asks whether ANY of its children differ — for a parent P it is `any(c -> childDiffers(delivery, c, alterant),
BLS.children(delivery.blsComponentTree, P))`; this function is the per-child primitive (the creator's question for ONE child)
from which that aggregate is computed; the aggregate's own form — a function of its own, or the stored flag beside the parent's row —
is a later benchmark phase's. Pure.
REASONING: the signal is what a child needs recorded (the creator's words); derived from the one answer function, it can never
disagree with the rows; the VALUE is compared, not the source, because a child hidden "as PART OF" its Block (his words) is not a
difference.
PURPOSE: the Extension's and a later benchmark phase's question. Package-
public (docs/public-api.md §1.2), NOT exported; the name the creator's word of 2026-10-03; the Block-against-File reading
an open point.
"""
function childDiffers(delivery::GoMetaDelivery, component::BLS.AbstractComponent, alterant::Symbol;
                      registry::AlterantRegistry = DEFAULT_REGISTRY)::Bool
    component isa BLS.File && return false
    par = BLS.parent(delivery.blsComponentTree, component)
    par === nothing && return false
    mine = evaluatedAltValue(delivery, component, alterant; registry = registry)
    theirs = evaluatedAltValue(delivery, par, alterant; registry = registry)
    return !isequal(mine.value, theirs.value)
end
