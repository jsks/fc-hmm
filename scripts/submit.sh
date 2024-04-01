#!/usr/bin/env zsh
#
# This script syncs the project to tetralith and submits a model run
# to slurm. Assumes that the project directory is symlinked to
# ~/storage.
###

setopt err_exit

function error() {
    print -u 2 $*
    exit 1
}

function usage() {
    print "Usage: $0 [--sync-only] IMAGE"
}

[[ -z $1 ]] && { usage; exit 1 }

typeset -A opts
zparseopts -A opts -D -E -F -- -help -sync-only
[[ -v opts[--help] ]] && { usage; exit }

proj="storage/$(date +'%F-%s')-$1"
job_script="$1.sh"

print "Running $1"
print "Model run directory: $proj"

[[ ! -f scripts/$job_script ]] && error "Cannot find job submission file for $1"

ssh tetralith "mkdir -p $proj"
scp scripts/${job_script} tetralith:$proj/$job_script
scp R/pp.R tetralith:$proj/pp.R

id=$(podman images -q jsks/${1})
[[ -z $id ]] && error "Cannot find image jsks/${1}"

podman save jsks/$1 | gzip | ssh tetralith "cat > $proj/$1-$id.tar.gz"

# Note: apparently apptainer doesn't like tilde expansion...
ssh tetralith "apptainer build $proj/$1.sif docker-archive:$proj/$1-$id.tar.gz"

if [[ ! -v opts[--sync-only] ]]; then
    ssh tetralith "cd $proj && sbatch $job_script"
fi
