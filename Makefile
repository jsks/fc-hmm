SHELL = /bin/bash -eo pipefail

manuscript := paper.qmd
token      := .token.gpg

raw := data/raw

# Escape codes for colourized output in `help` command
blue   := \033[1;34m
green  := \033[0;32m
white  := \033[0;37m
reset  := \033[0m

all: $(manuscript:.qmd=.pdf)
.PHONY: build push run

build: ## Build the Stan model container image
	podman build -t ghcr.io/jsks/hmm --target=hmm . && \
		podman build -t ghcr.io/jsks/sbc --target=sbc .

clean: ## Remove all generated files
	rm -rf $(foreach ext, pdf docx html, $(manuscript:%.qmd=%.$(ext))) \
		$(manuscript:%.qmd=%_files) $(manuscript:%.qmd=%.cache) \
		data/model_data.rds

help:
	@printf 'To compile $(manuscript) as a pdf:\n\n'
	@printf '\t$$ make\n\n'
	@printf 'Additionally, the following commands are available:\n\n'
	@grep -E '^\S+:.*##' $(MAKEFILE_LIST) | \
		sort | \
		awk -F ':.*##' \
			'{ printf "\t$(blue)%-10s $(white)%s$(reset)\n", $$1, $$2 }'
	@printf '\n'

push: ## Push the Stan model container image to GitHub Container Registry
	gpg -q -d $(token) | podman login ghcr.io --username jsks --password-stdin
	podman push ghcr.io/jsks/hmm:latest
	podman push ghcr.io/jsks/sbc:latest

wc: ## Rough estimate of word count for manuscript
	@printf '$(manuscript): '
	@scripts/wordcount.sh $(manuscript)

###
# Data prep
data/sequences.rds: $(raw)/ucdp-peace-agreements-221.xlsx \
			$(raw)/ucdp-term-acd-3-2021.xlsx \
			$(raw)/GEDEvent_v23_1.rds \
			$(raw)/UcdpPrioConflict_v23_1.rds \
			R/sequences.R
	Rscript R/sequences.R

data/model_data.rds: data/sequences.rds \
			$(raw)/V-Dem-CY-Full+Others-v14.rds \
			$(raw)/Third-Party-PKMs-version-3.5.xls \
			$(raw)/Conflict_onset_2022-1.xlsx \
			$(raw)/import-export-values_1950-2023.csv \
			R/merge.R
	Rscript R/merge.R

###
# Manuscript targets
$(foreach ext, pdf docx html, $(manuscript:%.qmd=%.$(ext))): \
	data/model_data.rds \
	fit.rds

%.docx: %.qmd
	quarto render $< --to docx

%.html: %.qmd
	quarto render $< --to html

%.pdf: %.qmd
	quarto render $< --to pdf
