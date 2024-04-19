#!/usr/bin/env Rscript
#
# Input data for HMM model
###

library(dplyr)
library(fc.hmm)
library(jsonlite)
library(tools)

###
# Load merged data
df <- readRDS("data/merge_data.rds") |>
    arrange(unit_id, year)

# Time-varying covariates affecting transition probabilities.
X <- select(df, tiv_1, ceasefire, pko, ongoing, v2x_polyarchy,
                     e_pop, e_gdppc, duration) |>
    polynomial("v2x_polyarchy", 2) |>
    polynomial("duration", 3) |>
    mutate(tiv_1 = asinh(tiv_1),
           e_pop = log(e_pop),
           e_gdppc = log(e_gdppc)) |>
    mutate(across(c(tiv_1, e_pop, e_gdppc), normalize))

stopifnot(!anyNA(X))

# Starts, ends for each conflict sequence
conflicts <- mutate(df, row = row_number()) |>
    group_by(unit_id) |>
    summarise(start = first(row),
              end = last(row))

###
# Stan input data
data <- list(N = nrow(df),
             K = 3,
             D = ncol(X),
             n_conflicts = n_distinct(df$unit_id),
             conflict_id = df$unit_id,
             conflict_starts = conflicts$start,
             conflict_ends = conflicts$end,
             X = data.matrix(X),
             y = df$brd,
             mu_location = c(0, 3.91, 6.91),
             mu_scale = c(0.1, 0.1, 0.1))
str(data)

stopifnot(!anyNA(data))
stopifnot(data$K == length(data$mu_location),
          data$K == length(data$mu_scale))

info("Variables: %s", paste0(colnames(X), collapse = ", "))
info("N = %d, K = %d", data$N, data$K)
info("BRD prior (location = %.2f, scale = %.2f)", exp(data$mu_location), data$mu_scale)

dir.create("data/json", showWarnings = F)
write_json(data, "data/json/hmm.json", auto_unbox = T)
