#!/bin/bash
#
#SBATCH -J hmm
#SBATCH -t 06:00:00
#SBATCH -n 4
#SBATCH --mail-type=ALL

printf "Starting HMM job at $(date)\n"
printf "Model priors:\n"

# This is a hack, but that's the tradeoff from using a minimal base
# image without coreutils... Strange that `apptainer` doesn't have
# a better method for extracting files.
apptainer sif dump 4 hmm.sif > files.squashfs
unsquashfs -q -d data files.squashfs -e hmm.json
jq -c '{mu_location},{mu_scale},{sigma_scale},{tau_scale},{pi_alpha}' data/hmm.json

apptainer run --bind $PWD:/data hmm.sif num_chains=4 num_threads=4 \
          output sig_figs=4 file=/data/output.csv
apptainer exec --bind $PWD:/data hmm.sif /diagnose /data/output_{1..4}.csv
