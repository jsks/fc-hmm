#!/usr/bin/env zsh

setopt err_exit

function usage() {
    print "Usage: $ZSH_SCRIPT [--rebuild] [target]"
}

function help() {
    <<EOF
$(usage)

Compile the manuscript using the 'fc.hmm/manuscript' image. Assumes
that the posteriors from all model runs have been copied to
posteriors/ and the raw/model data resides in data/.

An optional target can be specified in the form of
<manuscript>.<output extension>. By default, the target is
'paper.pdf'.

If 'fc.hmm/manuscript' does not exist, the script will build it using
the podman/r-image Containerfile.

Options:
    -r, --rebuild  Rebuild the image before running the container.
    -h, --help     Print this help message.
EOF

exit
}

typeset -A opts
zparseopts -A opts -D -F -M -- -rebuild r=rebuild -help h=help || { usage >&2; exit 127 }

[[ -v opts[--help] ]] && help

if [[ -v opts[--rebuild] ]] || ! podman image exists fc.hmm/manuscript; then
    podman build -t fc.hmm/manuscript --target=manuscript -f podman/r-image .
fi

podman run --rm -v $(git rev-parse --show-toplevel):/proj fc.hmm/manuscript \
       make ${1:-paper.pdf}
