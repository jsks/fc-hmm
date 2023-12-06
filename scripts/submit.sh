#!/usr/bin/env zsh
#
# This script syncs the project to tetralith and submits a model run
# to slurm. Assumes that the project directory is symlinked to
# ~/storage.
###

setopt err_exit

proj='~/storage/'
model_run=$(date +'%F-%s')

print "Model run directory: ${proj}/${model_run}"

function usage() {
    print "Usage: $0 [--sync-only] [dataset]"
}

typeset -A opts
zparseopts -A opts -D -E -F -- -help -sync-only
[[ -v opts[--help] ]] && { usage; exit }

ssh tetralith "mkdir ${proj}/${model_run}"
scp ${1:-data/model_data.rds} tetralith:${proj}/${model_run}/model_data.rds
scp scripts/job.sh tetralith:${proj}/${model_run}/job.sh

gpg -q -d .token.gpg | ssh tetralith "singularity registry login --username jsks docker://ghcr.io"
ssh tetralith "singularity pull ${proj}/${model_run}/hmm.sif docker://ghcr.io/jsks/hmm:latest"

if [[ ! -v opts[--sync-only] ]]; then
    ssh tetralith "cd ${proj}/${model_run} && sbatch job.sh"
fi
