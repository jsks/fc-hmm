#!/bin/bash
#
#SBATCH -J sbc
#SBATCH -t 48:00:00
#SBATCH -N 1
#SBATCH --exclusive
#SBATCH --mail-type=ALL

module load R/4.2.2-hpc1-gcc-11.3.0-bare

ITER=5000
NPROC=$(nproc)

echo "Running $ITER iterations of SBC with $NPROC parallel processes"

mkdir -p posteriors

function run() {
    output=$(mktemp -p posteriors -d)
    apptainer run --bind $PWD/$output:/data sbc.sif output file=/data/output.csv refresh=0
}
export -f run

function diagnose() {
    echo "Running diagnostics for $1"
    apptainer exec --bind $(pwd -P)/$1:/data sbc.sif '/diagnose' '/data/output.csv' | \
        grep -q 'no problems detected'
}
export -f diagnose

function clean() {
    if ! diagnose "$1"; then
        echo "Removing $1"
        rm -rf "$1"
    else
        echo "All checks passed: $1"
    fi
}
export -f clean

seq 1 $ITER | xargs -i -P $NPROC bash -c 'run'
find posteriors -name 'tmp.*' -type d | xargs -i -P $NPROC bash -c 'clean {}'

Rscript pp.R --cores $NPROC posteriors
