#!/usr/bin/env Rscript

library(cmdstanr)
library(docopt)
library(dplyr)
library(tools)

options(mc.cores = 4)

doc <- "Fit a hidden markov model to the merged conflict data.

Usage: hmm.R [--stan-file=<file>] [--output=<file>] <input-data>

Options:
    --stan-file=<file>  Stan file [default: stan/hmm.stan]
    --output=<file>     Output file [default: fit.rds]"

arguments <- docopt(doc)

# force cmdstanr to not check the version using a locally installed
# copy of CmdStan
assignInNamespace("cmdstan_version", function(...) "2.34.1", ns = "cmdstanr")

normalize <- \(x) scale(x) |> as.vector()

###
# Load merged data
if (!file.exists(arguments$input_data))
    stop("Invalid input file: ", arguments$input_data)

df <- readRDS(arguments$input_data) |>
    group_by(conflict_id) |>
    arrange(year) |>
    mutate(duration = 1:n()) |>
    ungroup() |>
    arrange(conflict_id, year)

# Time-varying covariates affecting transition probabilities.
X <- select(df, ceasefire, tiv, v2x_polyarchy, e_gdppc, duration) |>
    mutate(duration = log(duration) |> normalize(),
           tiv = normalize(tiv),
           e_gdppc = log(e_gdppc) |> normalize(),
           v2x_polyarchy = normalize(v2x_polyarchy))

# Starts, ends for each conflict sequence
conflicts <- mutate(df, row = row_number()) |>
    group_by(conflict_id) |>
    summarise(start = first(row),
              end = last(row))

###
# Stan input data
data <- list(N = nrow(df),
             K = 2,
             D = ncol(X),
             n_conflicts = n_distinct(df$conflict_id),
             conflict_starts = conflicts$start,
             conflict_ends = conflicts$end,
             X = data.matrix(X),
             y = df$brd)
str(data)
stopifnot(!anyNA(data))

###
# Fit the model
if (!file.exists(sf <- arguments$stan_file))
    stop("Invalid stan file: ", sf)

mod <- if (file_ext(sf) == "stan") cmdstan_model(sf) else cmdstan_model(exe_file = sf)
fit <- mod$sample(data = data, chains = 4, adapt_delta = 0.95, max_treedepth = 12)

# Save, save, save!
fit$save_object(arguments$output)
