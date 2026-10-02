#!/usr/bin/env bash
# compare_forms.sh — THE FIRST COMPARATOR of R-V04B-36 (d): a sorted-text diff of two comparison forms (stage 4 of the
# v0.4 build; the definition tests/comparison/README.md). The header lines (`#`-led) are dropped — they name each
# lane's producer and are not content; the body lines are sorted by code point (the form is already sorted; sorting
# here makes the comparator indifferent to a lane that emits in another order). Exit 0 = the same content; 1 = a
# difference (printed as diff's output: `<` the first form, `>` the second); 2 = usage. The structured Julia comparison
# function comes when GoMetaRetro's delivery exists (R-V04B-36 (d)).
# usage: devtools/compare_forms.sh <form A> <form B>
set -u
[ $# -eq 2 ] || { echo "usage: compare_forms.sh <form A> <form B>"; exit 2; }
A=$1; B=$2
[ -f "$A" ] && [ -f "$B" ] || { echo "usage: compare_forms.sh <form A> <form B> (a file is missing)"; exit 2; }
if diff <(grep -v '^#' "$A" | LC_ALL=C sort) <(grep -v '^#' "$B" | LC_ALL=C sort); then
  echo "SAME CONTENT: $(basename "$A") and $(basename "$B")"
  exit 0
fi
echo "DIFFERENT CONTENT: $(basename "$A") (<) and $(basename "$B") (>)"
exit 1
