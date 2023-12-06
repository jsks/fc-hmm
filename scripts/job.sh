#!/bin/bash
#
#SBATCH -J hmm
#SBATCH -t 03:00:00
#SBATCH -n 4

singularity run --pwd /project --no-home --bind $PWD:/project/data hmm.sif
