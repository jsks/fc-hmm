#!/usr/bin/env Rscript

library(jsonlite)

n <- 100
k <- 2

X <- rnorm(n, 0, 5)

n_conflicts <- 4
conflict_starts <- c(1, 30, 45, 79)
conflict_ends <- c(29, 44, 78, 100)

mu_location <- c(0, 6.2)
mu_scale <- c(1, 1)

stopifnot(length(mu_location) == k,
          length(mu_scale) == k)

stan_data <- list(N = n,
                  K = k,
                  D = 1,
                  X = data.matrix(X),
                  n_conflicts = n_conflicts,
                  conflict_id = findInterval(1:n, c(1, conflict_ends),
                                             rightmost.closed = T, left.open = T),
                  conflict_starts = conflict_starts,
                  conflict_ends = conflict_ends,
                  mu_location = mu_location,
                  mu_scale = mu_scale)
str(stan_data)

dir.create("json", showWarnings = F)
write_json(stan_data, "json/sim.json", auto_unbox = T)
