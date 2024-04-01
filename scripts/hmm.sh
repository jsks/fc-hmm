#!/bin/bash
#
#SBATCH -J hmm
#SBATCH -t 08:00:00
#SBATCH -n 4
#SBATCH --mail-type=ALL

ncores=4

apptainer run --bind $PWD:/data hmm.sif num_chains=$ncores num_threads=$ncores \
          output sig_figs=4 file=/data/output.csv
apptainer exec --bind $PWD:/data hmm.sif /diagnose /data/output_{1..$ncores}.csv
