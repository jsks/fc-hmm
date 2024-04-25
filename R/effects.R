#!/usr/bin/env Rscript
#
# Average predicted transition probabilities
###

library(cmdstanr)
library(dplyr)
library(fc.hmm)
library(jsonlite)

dir.create("posteriors/transitions", showWarnings = F)

files <- list.files("posteriors", "^output_\\d.csv$", full.names = T)
stopifnot(length(files) > 0)

fit <- as_cmdstan_fit(files)

data <- read_json("./data/json/hmm.json", simplifyVector = T)

X_tilde <- data$X[-data$conflict_starts, ]
unit_id <- data$conflict_id[-data$conflict_starts]

df <- readRDS("./data/merge_data.rds")

observed <- asinh(df$tiv_1)
newdata <- seq(0, max(df$tiv), by = 1)
v <- (asinh(newdata) - mean(observed)) / sd(observed)

for (i in 1:3) {
    info("Calculating posterior probabilities from state %d", i)
    probs <- posterior_transitions(fit, X_tilde, unit_id, v, 1, 500)

    for (j in 1:3) {
        info("Saving %d -> %d", i, j)
        m <- lapply(probs, \(p) p[j, ]) |> do.call(rbind, args = _)
        saveRDS(m, sprintf("posteriors/transitions/prob_%d%d.rds", i, j))
    }
}

data.frame(tiv = newdata, normalized = v) |>
    saveRDS("posteriors/transitions/tiv.rds")
