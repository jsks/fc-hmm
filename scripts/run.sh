#!/usr/bin/env zsh
#
# Sync project to tetralith and submit a model run to slurm. Assumes
# that the project directory is symlinked to ~/storage.
###

setopt err_exit

function error() {
    print -u 2 $*
    exit 127
}

function usage() {
    print "Usage: $ZSH_SCRIPT [options] <image>"
}

function help() {
<<EOF
$(usage)

Submit and run <image> on tetralith.

Options:
    --samples, -s <samples>  Number of post-warmup iterations (non-SBC only) [Default: 1000]
    --warmup, -w <warmup>    Number of warmup iterations (non-SBC only) [Default: 1000]
    --sync-only              Only sync the project directory
    --help, -h               Print this help message
EOF

exit
}

typeset -A opts=(--samples 2000 --warmup 1000)
zparseopts -A opts -D -E -F -K -M -- -local l=-local -help h=-help -sync-only \
            -samples: s:=-samples -warmup: w:=-warmup || { usage >&2; exit 127 }

[[ -v opts[--help] ]] && help
if [[ -z $1 ]]; then
    print -u 2 "Mising model image"
    usage >&2
    exit 127
fi

image=ghcr.io/jsks/fc-hmm/$1
hash=$(date +'%s' | md5sum | cut -c1-5)
proj="storage/$hash-${1:t}-$(date +'%y-%m-%d-%H.%M.%S')"
if [[ "$1" =~ -sbc$ ]]; then
    job_script="sbc.sh"
else
    job_script="hmm.sh"
fi

print "Model directory: $proj"

[[ ! -f scripts/slurm/$job_script ]] && error "Cannot find job submission file for $1"

id=$(podman images -q $image)
[[ -z $id ]] && error "Cannot find image $image"

ssh tetralith "mkdir -p $proj"
scp scripts/slurm/${job_script} tetralith:$proj/$job_script
if [[ $1 =~ -sbc$ ]]; then
    scp R/pp.R tetralith:$proj/pp.R
else
    thin=$((opts[--samples] / 1000))
    [[ $thin -lt 1 ]] && thin=1

    ssh tetralith bash <<EOF
sed -E -e "s/(num_warmup=)[[:digit:]]+/\1${opts[--warmup]}/" \
       -e "s/(num_samples=)[[:digit:]]+/\1${opts[--samples]}/" \
       -e "s/(thin=)[[:digit:]]+/\1${thin}/" \
    -i $proj/$job_script
EOF
fi

podman save $image | gzip | ssh tetralith "cat > $proj/${1:t}-$id.tar.gz"

# Note: apparently apptainer doesn't like tilde expansion...
ssh tetralith "apptainer build $proj/image.sif docker-archive:$proj/${1:t}-$id.tar.gz"

if [[ ! -v opts[--sync-only] ]]; then
    ssh tetralith "cd $proj && sbatch $job_script"
fi
