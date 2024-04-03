#!/usr/bin/env Rscript

library(dplyr)
library(jsonlite)
library(tools)

normalize <- \(x) scale(x) |> as.vector()
polynomial <- function(df, var, n) {
    m <- poly(df[[var]], n)
    colnames(m) <- paste(var, 1:n, sep = "_")
    df[[var]] <- NULL

    bind_cols(df, m)
}

###
# Load merged data
df <- readRDS("data/merge_data.rds") |>
    arrange(conflict_id, year)

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
    group_by(conflict_id) |>
    summarise(start = first(row),
              end = last(row))

###
# Stan input data
data <- list(N = nrow(df),
             K = 3,
             D = ncol(X),
             n_conflicts = n_distinct(df$conflict_id),
             conflict_id = as.factor(df$conflict_id) |> as.numeric(),
             conflict_starts = conflicts$start,
             conflict_ends = conflicts$end,
             X = data.matrix(X),
             y = df$brd,
             mu_location = c(1, 4, 6.21),
             mu_scale = c(1, 1, 1))
str(data)

stopifnot(!anyNA(data))
stopifnot(data$K == length(data$mu_location),
          data$K == length(data$mu_scale))

dir.create("json", showWarnings = F)
write_json(data, "json/hmm.json", auto_unbox = T)
