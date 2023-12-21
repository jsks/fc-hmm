#!/usr/bin/env bash
#
# Approximate word count for a quarto/Rmarkdown file. Includes body
# text count + references, abstract, and figure captions while
# excluding appendix and code blocks.
###

set -eo pipefail

if [[ $# -ne 1 ]]; then
    printf "Missing file argument\n" >&2
    printf "Usage: $0 <file.[qmd|Rmd|md]>\n" >&2
    exit 1
fi

if [[ ! -f "$1" ]]; then
    printf "Invalid file: $1\n" >&2
    exit 1
fi

abstract=$(yq -f extract '.abstract' $1 | wc -w)

body=$(sed -e '/^```/,/^```/d' -e '/^#\s*Appendix/,$d' $1 | \
           pandoc --quiet --citeproc -f markdown -t plain | \
           wc -w)

# This assumes that only fig-cap values are multiline within code
# blocks
figure_captions=$(grep '^#|' $1 | sed -e 's/^#|\s*//' -e '/^.*:/d' | wc -w)

printf "%d\n" "$((abstract + body + figure_captions))"
