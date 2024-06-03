SHELL = /bin/bash -eo pipefail

manuscript := paper.qmd

post        := posteriors
fits        := $(patsubst %,$(post)/output_%.csv,$(shell seq 1 4))
transitions != printf "$(post)/transitions/prob_%d.rds\n" {1..3}{1..3}

# Escape codes for colourized output in `help` command
blue   := \033[1;34m
green  := \033[0;32m
white  := \033[0;37m
reset  := \033[0m

all: $(manuscript:.qmd=.pdf)
.PHONY: clean help preview todo wc

clean: ## Remove all generated files
	rm -rf $(foreach ext, pdf docx html, $(manuscript:%.qmd=%.$(ext))) \
		$(manuscript:%.qmd=%_files) $(manuscript:%.qmd=%.cache) \
		data/merge_data.rds data/*.json

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

todo: ## List TODO comments in project files tracked by git
	@grep --color=always --exclude=Makefile --exclude=library.bib \
		-rni todo $$(git ls-files) *.org || :

wc: ## Rough estimate of word count for manuscript
	@printf '$(manuscript): '
	@scripts/wordcount.sh $(manuscript)

###
# Post-processing
$(transitions) &: $(fits)
	Rscript R/effects.R

###
# Manuscript targets
$(foreach ext, pdf docx html, $(manuscript:%.qmd=%.$(ext))): \
	data/merge_data.rds \
	$(fits)

%.docx: %.qmd
	quarto render $< --to docx

%.html: %.qmd
	quarto render $< --to html

%.pdf: %.qmd
	quarto render $< --to typst
