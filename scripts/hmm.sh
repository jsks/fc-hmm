#!/bin/bash
#
#SBATCH -J hmm
#SBATCH -t 04:00:00
#SBATCH -n 4
#SBATCH --mail-type=ALL

echo "Starting HMM job at $(date)"

apptainer run --bind $PWD:/data hmm.sif num_chains=4 num_threads=4 \
          output sig_figs=4 file=/data/output.csv
apptainer exec --bind $PWD:/data hmm.sif /diagnose /data/output_{1..4}.csv
