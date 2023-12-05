#!/usr/bin/env Rscript

library(cmdstanr)
library(dplyr)

options(mc.cores = parallel::detectCores() - 1)

normalize <- \(x) scale(x) |> as.vector()

###
# Test with only Armenia - Azerbaijan conflict (conflict_id == 388)
df <- readRDS("./data/merge.rds") |>
    group_by(conflict_id) |>
    arrange(year) |>
    mutate(duration = 1:n()) |>
    ungroup() |>
    arrange(conflict_id, year)

# Time-varying covariates affecting transition probabilities.
X <- select(sub.df, ceasefire, tiv, v2x_polyarchy, e_gdppc, duration) |>
    mutate(duration = log(duration) |> normalize(),
           tiv = normalize(tiv),
           e_gdppc = log(e_gdppc) |> normalize(),
           v2x_polyarchy = normalize(v2x_polyarchy))

conflicts <- mutate(sub.df, row = row_number()) |>
    group_by(conflict_id) |>
    summarise(start = first(row),
              end = last(row))

data <- list(N = nrow(sub.df),
             K = 2,
             D = ncol(X),
             n_conflicts = n_distinct(sub.df$conflict_id),
             conflict_starts = conflicts$start,
             conflict_ends = conflicts$end,
             X = data.matrix(X),
             y = sub.df$brd)
str(data)
stopifnot(!anyNA(data))

mod <- cmdstan_model("hmm.stan")
fit <- mod$sample(data = data, chains = 4, adapt_delta = 0.95, max_treedepth = 12)
