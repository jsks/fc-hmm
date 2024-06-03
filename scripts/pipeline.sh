#!/usr/bin/env zsh

setopt err_exit

function usage() {
    print "Usage: $ZSH_SCRIPT [options]... <output>"
}

function help() {
<<EOF
$(usage)

Data cleaning/merging pipeline. Output argument is the final json file
for CmdStan.

Options:
    -x, --variable <variable>    Primary regressor [Default: "tiv_avg"]
    -k, --states <states>        Number of HMM states [Default: 3]
    -h, --help                   Display this help and exit

Options
EOF

exit
}

typeset -A opts=(--variable "tiv_avg" --states 3)
zparseopts -A opts -D -F -E -K -M -- \
           -variable: x:=-variable -states: k:=-states -help h=-help || \
    { usage >&2; exit 127 }

[[ -v opts[--help] ]] && help
if [[ -z $1 ]]; then
    print -u 2 "Missing output argument"
    usage
    exit 127
fi

print "Creating conflict sequences..."
Rscript R/sequences.R

print "Merging covariates..."
Rscript R/merge.R

print "Creating model input $1..."
Rscript R/model_data.R -x $opts[--variable] -k $opts[--states] $1

print "Simulating SBC input..."
Rscript R/sbc.R ${1:h}/sbc.json
