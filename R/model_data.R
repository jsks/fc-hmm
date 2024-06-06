#!/usr/bin/env Rscript
#
# Input data for HMM model. This script parametrically sets the number
# of latent states as well as which TIV variable to use.
###

library(docopt)
library(dplyr)
library(fc.hmm)
library(jsonlite)
library(tools)

doc <- "
Usage: model_data.R [options] <output>

-x, --variable=<variable>  Variable of interest [default: tiv_1].
-k, --states=<states>      Number of latent states states [default: 3]."

arguments <- docopt(doc)
stopifnot(arguments$states %in% c(2, 3))

###
# Load merged data
df <- readRDS("data/merge_data.rds") |>
    arrange(unit_id, year)

stopifnot(arguments$variable %in% colnames(df))

# Time-varying covariates affecting transition probabilities.
X <- select(df, arguments$variable, ceasefire, pko, ongoing,
            v2x_polyarchy, e_pop, e_gdppc, duration) |>
    polynomial("v2x_polyarchy", 2) |>
    polynomial("duration", 3) |>
    mutate(e_pop = log(e_pop),
           e_gdppc = log(e_gdppc)) |>
    mutate(across(c(e_pop, e_gdppc), normalize))

X[[arguments$variable]] <- asinh(X[[arguments$variable]]) |> normalize()

# We assume throughout the project that our primary variable of
# interest is always the first column in the covariate matrix.
stopifnot(colnames(X)[1] == arguments$variable)
stopifnot(!anyNA(X))

# Starts, ends for each conflict sequence
conflicts <- mutate(df, row = row_number()) |>
    group_by(unit_id) |>
    summarise(start = first(row),
              end = last(row))

# BRD mean log-scale priors
if (arguments$states == 3) {
    mu_location <- c(log(1), log(50), log(1000))
    mu_scale <- c(2, 0.5, 0.25)
} else {
    mu_location <- c(log(1), log(500))
    mu_scale <- c(2, 0.5)
}

###
# Stan input data
data <- list(N = nrow(df),
             K = as.numeric(arguments$states),
             D = ncol(X),
             n_conflicts = n_distinct(df$unit_id),
             conflict_id = to_idx(df$unit_id),
             conflict_starts = conflicts$start,
             conflict_ends = conflicts$end,
             X = data.matrix(X),
             y = df$brd,

             # Priors
             mu_location = mu_location,
             mu_scale = mu_scale,
             sigma_scale = 0.1,
             tau_scale = 0.1)
str(data)

stopifnot(!anyNA(data))
stopifnot(data$K == length(data$mu_location),
          data$K == length(data$mu_scale))

info("Variables: %s", paste0(colnames(X), collapse = ", "))
info("N = %d, K = %d", data$N, data$K)
info("BRD prior (exp(location) = %.2f, scale = %.2f)", exp(data$mu_location), data$mu_scale)

write_json(data, arguments$output, auto_unbox = T)
