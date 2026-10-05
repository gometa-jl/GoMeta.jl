## labels_vocabulary.jl — the shipped Labels vocabulary: the 38 names of `labels_vocabulary.txt` beside this file, read at
## load, one name per line in the file's order (std-Alterant territory — R-V04B-6 (a): the names live under alterants-std/,
## never as a Core literal; content custody the Labels lane's, R-LBL-4). The v0.4 T4 relocation's digest pin, capture cache,
## artifact grammar, scope law and write-only valve left at stage 5's E9 of the v0.4 build (census rows 10, 28 and 55; his
## §317 mark, R-V04B-105; his §120: a basic, true Labels Alterant before any hardening). The legacy's TODO stands (GoMetaRetro
## Alterants.jl :61–:62): an expandable container for NEW labels added from within the metaData — later. The file is
## byte-identical to T4's: a line's first TAB field is the name; the one second field (`query=false` on the ZWJ name — the
## owner's R-V04-36 content ruling, 'Carry it query=false, disclosed') is inert data since E9, the valve that read it gone.
const _LABELS_VOCABULARY_PATH = joinpath(@__DIR__, "labels_vocabulary.txt")
Base.include_dependency(_LABELS_VOCABULARY_PATH)   # an edit of the file must reach a precompiled session
"the shipped Labels vocabulary — the 38 names of `labels_vocabulary.txt`, in the file's order (each line's first TAB field)"
const LABELS_VOCABULARY = Symbol[Symbol(first(split(l, '\t'))) for l in eachline(_LABELS_VOCABULARY_PATH)]
