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

proj='~/storage/'
model_run="$(date +'%F-%s')-$1"
job_script="${1}.sh"

[[ ! -f scripts/$job_script ]] && error "Cannot find job submission file for $1"

print "Running $1"
print "Model run directory: ${proj}/${model_run}"

typeset -A opts
zparseopts -A opts -D -E -F -- -help -sync-only
[[ -v opts[--help] ]] && { usage; exit }

# Ensure that input data is up to date
make data/model_data.rds

ssh tetralith "mkdir ${proj}/${model_run}"
scp data/model_data.rds tetralith:${proj}/${model_run}/model_data.rds
scp scripts/${job_script} tetralith:${proj}/${model_run}/${job_script}

gpg -q -d .token.gpg | ssh tetralith "singularity registry login --username jsks docker://ghcr.io"
ssh tetralith "singularity pull ${proj}/${model_run}/image.sif docker://ghcr.io/jsks/${1}"

if [[ ! -v opts[--sync-only] ]]; then
    ssh tetralith "cd ${proj}/${model_run} && sbatch ${job_script}"
fi
