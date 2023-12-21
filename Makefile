SHELL = /bin/bash -eo pipefail

manuscript := paper.qmd
token      := .token.gpg

# Escape codes for colourized output in `help` command
blue   := \033[1;34m
green  := \033[0;32m
white  := \033[0;37m
reset  := \033[0m

all: $(manuscript:.qmd=.pdf)
.PHONY: build push run

build: ## Build the Stan model container image
	podman build -t hmm . && \
	podman tag hmm ghcr.io/jsks/hmm:latest

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

push: build ## Push the Stan model container image to GitHub Container Registry
	gpg -q -d $(token) | podman login ghcr.io --username jsks --password-stdin && \
		podman push ghcr.io/jsks/hmm:latest

run: data/model_data.rds ## Run the Stan model container image on tetralith
	scripts/submit.sh data/model_data.rds

wc: ## Rough estimate of word count for manuscript
	@printf '$(manuscript): '
	@scripts/wordcount.sh $(manuscript)

data/model_data.rds: data/import-export-values_1950-2023.csv \
			data/ucdp-peace-agreements-221.xlsx \
			data/ucdp-term-acd-3-2021.xlsx \
			data/UcdpPrioConflict_v23_1.rds \
			data/GEDEvent_v23_1.rds \
			data/V-Dem-CY-Full+Others-v14.rds \
			data/Conflict_onset_2022-1.xlsx \
			R/merge.R
	Rscript R/merge.R

$(foreach ext, pdf docx html, $(manuscript:%.qmd=%.$(ext))): \
	data/model_data.rds \
	fit.rds

###
# Implicit rules for pdf and html generation
%.docx: %.qmd
	quarto render $< --to docx

%.html: %.qmd
	quarto render $< --to html

%.pdf: %.qmd
	quarto render $< --to pdf
