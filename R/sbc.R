#!/usr/bin/env Rscript

library(cmdstanr)
library(dplyr)
library(parallel)

options(mc.cores = parallel::detectCores() / 2)

assignInNamespace("cmdstan_version", function(...) "2.34.1", ns = "cmdstanr")

rank_statistic <- function(draws, true_value) {
    sum(draws < true_value)
}

iter <- 5000
n <- 100
k <- 2

X <- rnorm(n, 0, 5)

n_conflicts <- 4
conflict_start <- c(1, 30, 45, 79)
conflict_end <- c(29, 44, 78, 100)

lambda_location <- c(0, 6.2)
lambda_scale <- c(1, 1)

stopifnot(length(lambda_location) == k,
          length(lambda_scale) == k)

data <- list(N = n,
             K = k,
             D = 1,
             X = data.matrix(X),
             n_conflicts = n_conflicts,
             conflict_start = conflict_start,
             conflict_end = conflict_end,
             lambda_location = lambda_location,
             lambda_scale = lambda_scale)
str(data)

sim <- cmdstan_model(exe_file = "sim")
sim_data <- sim$sample(data = data, fixed_param = T, chains = 1, iter_sampling = iter)

y_sim <- sim_data$draws("y", format = "matrix")

parameters <- c("pi", "beta", "nu", "lambda")
pv <- sim_data$draws(parameters, format = "data.frame")

###
# Simulation based calibration
mod <- cmdstan_model(exe_file = "simple")
ranks <- mclapply(1:nrow(y_sim), function(i) {
    stan_data <- data
    stan_data$y <- as.vector(y_sim[i, ])
    stan_data$interaction_id <- 1

    fit <- mod$sample(data = stan_data, chains = 2, adapt_delta = 0.95, refresh = 0)

    diagnostics <- fit$diagnostic_summary()
    if (sum(diagnostics$num_divergent) > 0 | sum(diagnostics$num_max_treedepth) > 0) {
        warning("Divergent transitions or max treedepth exceeded")
        return(NULL)
    }

    mapply(rank_statistic, fit$draws(parameters, format = "data.frame"), pv[i, ])
})

df <- bind_rows(ranks)
saveRDS(df, "data/sbc.rds")
