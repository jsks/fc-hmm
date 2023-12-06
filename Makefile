SHELL = /bin/bash -eo pipefail

all: data/model_data.rds
.PHONY: build push

build:
	podman build -t hmm . && \
	podman tag hmm ghcr.io/jsks/hmm:latest

push:
	podman push ghcr.io/jsks/hmm:latest

data/model_data.rds: data/import-export-values_1950-2023.csv \
			data/ucdp-peace-agreements-221.xlsx \
			data/ucdp-term-acd-3-2021.xlsx \
			data/UcdpPrioConflict_v23_1.rds \
			data/GEDEvent_v23_1.rds \
			data/V-Dem-CY-Full+Others-v14.rds \
			data/Conflict_onset_2022-1.xlsx \
			R/merge.R
	Rscript R/merge.R

data/fit.rds: data/model_data.rds \
		stan/hmm.stan \
		R/hmm.R
	Rscript R/hmm.R $<
