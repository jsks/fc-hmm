#!/usr/bin/env Rscript

library(cmdstanr)
library(dplyr)

options(mc.cores = 4)

###
# Test with only Armenia - Azerbaijan conflict
df <- readRDS("./data/merge.rds") |>
    group_by(conflict_id) |>
    arrange(year) |>
    mutate(duration = 1:n()) |>
    ungroup()

#sub.df <- filter(df, conflict_id %in% c(221, 223, 288, 227, 388) | (conflict_id == 401 & year <= 2007)) |>
#    arrange(conflict_id, year)
sub.df <- filter(df, conflict_id == 388) |>
    arrange(conflict_id, year)

# Time-varying covariates affecting transition probabilities.
X <- select(sub.df, ceasefire, tiv, duration) |>
    mutate(duration = scale(duration) |> as.vector(),
           duration_sq = scale(duration^2) |> as.vector(),
           duration_cubed = scale(duration^3) |> as.vector(),
           tiv = scale(tiv) |> as.vector())

W <- select(sub.df, v2x_polyarchy, e_pop, e_gdppc) |>
    mutate(v2x_polyarchy = scale(v2x_polyarchy) |> as.vector(),
           e_pop = log(e_pop) |> scale() |> as.vector(),
           e_gdppc = log(e_gdppc) |> scale() |> as.vector())

conflicts <- mutate(sub.df, row = row_number()) |>
    group_by(conflict_id) |>
    summarise(start = first(row),
              length = n())

data <- list(N = nrow(sub.df),
             K = 2,
             D = ncol(X),
             M = ncol(W),
             n_conflicts = n_distinct(sub.df$conflict_id),
             conflict_lens = conflicts$length,
             conflict_starts = conflicts$start,
             W = data.matrix(W),
             X = data.matrix(X),
             y = sub.df$brd)
str(data)
stopifnot(!anyNA(data))

mod <- cmdstan_model("hmm.stan")
fit <- mod$sample(data = data, chains = 4)
