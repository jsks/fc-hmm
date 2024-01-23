#!/bin/bash
#
#SBATCH -J hmm
#SBATCH -t 01:00:00
#SBATCH -n 8
#SBATCH --mail-type=ALL

apptainer run --bind $PWD:/data hmm.sif num_chains=8 num_threads=8 \
          output sig_figs=4 file=/data/output.csv
