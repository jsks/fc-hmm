#!/bin/bash
#
#SBATCH -J sbc
#SBATCH -t 12:00:00
#SBATCH -N 1
#SBATCH --exclusive
#SBATCH --mail-type=ALL

singularity run --pwd /project --no-home --bind $PWD:/project/data image.sif
