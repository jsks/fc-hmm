#!/usr/bin/env Rscript

library(jsonlite)

N <- 100
K <- 2

# Simulate X with a standard normal to prevent overflow in the gamma
# rate in neg_binomial_2_log_rng
X <- rnorm(N, 0, 1)

n_conflicts <- 4
conflict_starts <- c(1, 30, 45, 79)
conflict_ends <- c(29, 44, 78, 100)

mu_location <- c(0, 6.9)
mu_scale <- c(0.5, 0.5)

stopifnot(length(mu_location) == K,
          length(mu_scale) == K)

stan_data <- list(N = N,
                  K = K,
                  D = 1,
                  X = data.matrix(X),
                  n_conflicts = n_conflicts,
                  conflict_id = findInterval(1:N, c(1, conflict_ends),
                                             rightmost.closed = T, left.open = T),
                  conflict_starts = conflict_starts,
                  conflict_ends = conflict_ends,
                  mu_location = mu_location,
                  mu_scale = mu_scale)
str(stan_data)

dir.create("data/json", showWarnings = F)
write_json(stan_data, "data/json/sbc.json", auto_unbox = T)
