SHELL = /bin/bash -eo pipefail

manuscript := paper.qmd
raw        := data/raw
json       := data/json

post        := posteriors
fits        := $(patsubst %,$(post)/output_%.csv,$(shell seq 1 4))
transitions != printf "$(post)/transitions/prob_%d.rds\n" {1..3}{1..3}

# Escape codes for colourized output in `help` command
blue   := \033[1;34m
green  := \033[0;32m
white  := \033[0;37m
reset  := \033[0m

all: $(manuscript:.qmd=.pdf)
.PHONY: build clean help preview wc

build: $(json)/hmm.json $(json)/sbc.json ## Build the Stan model container image
	podman build -t jsks/hmm --target=hmm . && \
		podman build -t jsks/sbc --target=sbc .

clean: ## Remove all generated files
	rm -rf $(foreach ext, pdf docx html, $(manuscript:%.qmd=%.$(ext))) \
		$(manuscript:%.qmd=%_files) $(manuscript:%.qmd=%.cache) \
		data/merge_data.rds $(json)

help:
	@printf 'To compile $(manuscript) as a pdf:\n\n'
	@printf '\t$$ make\n\n'
	@printf 'Additionally, the following commands are available:\n\n'
	@grep -E '^\S+:.*##' $(MAKEFILE_LIST) | \
		sort | \
		awk -F ':.*##' \
			'{ printf "\t$(blue)%-10s $(white)%s$(reset)\n", $$1, $$2 }'
	@printf '\n'

preview: ## Auto-rebuild html manuscript
	quarto preview $(manuscript) --to html

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

data/merge_data.rds: data/sequences.rds \
			$(raw)/V-Dem-CY-Full+Others-v14.rds \
			$(raw)/Third-Party-PKMs-version-3.5.xls \
			$(raw)/CFD_oct_2022_id-1.xlsx \
			$(raw)/import-export-values_1950-2023.csv \
			R/merge.R
	Rscript R/merge.R

$(json)/%.json: R/%.R data/merge_data.rds
	Rscript $<

###
# Post-processing
$(transitions) &: $(fits)
	Rscript R/effects.R

###
# Manuscript targets
$(foreach ext, pdf docx html, $(manuscript:%.qmd=%.$(ext))): \
	data/merge_data.rds \
	$(fits) \
	$(transitions)

%.docx: %.qmd
	quarto render $< --to docx

%.html: %.qmd
	quarto render $< --to html

%.pdf: %.qmd
	quarto render $< --to pdf
