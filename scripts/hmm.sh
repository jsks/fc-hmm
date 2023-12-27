#!/bin/bash
#
#SBATCH -J hmm
#SBATCH -t 03:00:00
#SBATCH -n 8
#SBATCH --mail-type=ALL

singularity run --pwd /project --no-home --bind $PWD:/project/data image.sif
