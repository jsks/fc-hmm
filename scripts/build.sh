#!/usr/bin/env zsh
#
###

setopt err_exit
zmodload zsh/zutil

function usage() {
    print "Usage: $ZSH_SCRIPT [options]... <model>"
}

function help() {
<<EOF
$(usage)

This builds a model as a standalone container image along with its
accompanying simulation based calibration code.

Options:
    --variable, -x <variable>  Primary regressor [Default: "tiv_avg"]
    --states, -k <states>      Number of HMM states [Default: 3]
    --help, -h                 Print this help message
EOF

exit
}

root=$(git rev-parse --show-toplevel)

typeset -A opts=(--variable "tiv_avg" --states 3)
zparseopts -A opts -D -F -E -K -M -- \
           -variable: x:=-variable -states: k:=-states -help h=-help || \
    { usage >&2; exit 127 }

[[ -v opts[--help] ]] && help
if [[ -z $1 ]]; then
    print -u 2 "Missing model argument"
    usage >&2
    exit 127
fi

if [[ ! -d $root/stan/$1 ]]; then
    print -u 2 "Cannot find model, $1, under $root/stan/"
    exit 127
fi

print "Building model: $1"
print "Input data: ${data:=data/hmm-${1:t}-k${opts[--states]}.json}"
print "SBC data: ${sbc:=data/sbc.json}"

###
# Build and run the data clean/merge pipeline
podman run --rm -v $root:/proj ghcr.io/jsks/fc-hmm/r-image \
       scripts/pipeline.sh -x $opts[--variable] -k $opts[--states] $data

###
# Build model/sbc images
podman build -t ghcr.io/jsks/fc-hmm/$1-k${opts[--states]} --target=hmm --build-arg=MODEL=$1 \
       --build-arg=DATA=$data -f podman/hmm $root
podman build -t ghcr.io/jsks/fc-hmm/$1-sbc --target=sbc --build-arg=MODEL=$1 -f podman/hmm $root
