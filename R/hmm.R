#!/usr/bin/env Rscript

library(cmdstanr)
library(docopt)
library(dplyr)
library(tools)

options(mc.cores = 8)

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
    filter(high_intensity) |>
    arrange(conflict_id, year)

# Time-varying covariates affecting transition probabilities.
X <- select(df, tiv, ceasefire, pko, ongoing, v2x_polyarchy, e_gdppc, duration) |>
    mutate(duration = normalize(duration),
           duration2 = normalize(duration^2),
           duration3 = normalize(duration^3),
           tiv = normalize(tiv),
           e_gdppc = log(e_gdppc) |> normalize(),
           v2x_polyarchy = normalize(v2x_polyarchy))
stopifnot(!anyNA(X))

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
             y = df$brd,
             lambda_location = c(0, 6.2),
             lambda_scale = c(1, 1))
str(data)
stopifnot(!anyNA(data))

###
# Fit the model
if (!file.exists(sf <- arguments$stan_file))
    stop("Invalid stan file: ", sf)

mod <- if (file_ext(sf) == "stan") cmdstan_model(sf) else cmdstan_model(exe_file = sf)
fit <- mod$sample(data = data, chains = 8, adapt_delta = 0.95, max_treedepth = 12)

# Save, save, save!
fit$save_object(arguments$output)
