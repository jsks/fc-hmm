#!/usr/bin/env Rscript
#
# Average predicted transition probabilities
###

library(cmdstanr)
library(docopt)
library(dplyr)
library(fc.hmm)
library(jsonlite)

doc <- "Usage: effects.R <model-run>"
arguments <- docopt(doc)

stopifnot(dir.exists(arguments$model_run))
model <- basename(arguments$model_run)
info("Generating posterior predicted probabilities for %s", model)

files <- list.files(arguments$model_run, "^output_\\d.csv$", full.names = T)
stopifnot(length(files) > 0)

fit <- as_cmdstan_fit(files)
data <- sprintf("./data/hmm-%s.json", model) |> read_json(simplifyVector = T)

X_tilde <- data$X[-data$conflict_starts, ]
unit_id <- data$conflict_id[-data$conflict_starts]

df <- readRDS("./data/merge_data.rds")

observed <- asinh(df$tiv_1)
newdata <- seq(0, max(df$tiv), by = 1)
v <- (asinh(newdata) - mean(observed)) / sd(observed)

for (i in 1:data$K) {
    info("Calculating posterior probabilities from state %d", i)
    probs <- posterior_transitions(fit, X_tilde, unit_id, v, i, 500)

    for (j in 1:data$K) {
        info("Saving %d -> %d", i, j)
        m <- lapply(probs, \(p) p[j, ]) |> do.call(rbind, args = _)

        sprintf("%s/prob_%d%d.rds", arguments$model_run, i, j) |>
            saveRDS(m, file = _)
    }
}

data.frame(tiv = newdata, normalized = v) |> saveRDS("posteriors/tiv.rds")
