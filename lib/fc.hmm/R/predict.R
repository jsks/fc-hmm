ndraws <- function(fit) {
    fit$metadata()$iter_sampling
}

#' Predicted transition probabilities
#'
#' This function computes the average predicted transition probability
#' from state `from` to each state 1, \ldots, K for each value of
#' `tiv` across all transition cases in `X`.
#'
#' @param fit A `cmdstanr` object containing the posterior draws
#' @param X Covariate matrix representing `nrow(X)` observations with
#'     `ncol(X)` matching columns to the original model run data
#' @param unit_id Numeric vector of conflict episode IDs from the
#'     original model run data
#' @param tiv Numeric vector of TIV values
#' @param from Integer representing the latent state to transition from
#' @param ndraws Number of posterior draws to use in the computation
#' @param mc.cores Number of cores to be used by OpenMP
#'
#' @note Warning, this function assumes that the first column of `X`,
#'     and correspondingly the first row for each array element in
#'     `beta`, corresponds to the TIV variable. This is a bad
#'     practice; however, this function is not meant to be a general
#'     library function for other projects and our assumption
#'     simplifies the code across a number of different scripts.
#'
#' @return A `ndraw` length list of matrices with dimensions `K` x
#'     `length(tiv)`, *i.e.*, the average posterior probability for
#'     transition to each state given the different values of TIV for
#'     each posterior draw from `fit`.
#'
#' @export
posterior_transitions <- function(fit, ...) UseMethod("posterior_transitions")

#' @export
posterior_transitions.CmdStanFit <- function(fit,
                                             X,
                                             unit_id,
                                             tiv,
                                             from = 1,
                                             ndraws = ndraws(fit),
                                             mc.cores = parallel::detectCores(logical = F)) {
    if (length(unit_id) != nrow(X))
        stop("unit_id must have the same length as the total number of observations")

    # Number of latent states
    K <- fit$metadata()$stan_variable_sizes$beta[1]
    if (!from %in% 1:K)
        stop("Provided `from` is not a valid latent state")

    # Number of covariates
    D <- fit$metadata()$stan_variable_sizes$beta[3]
    if (ncol(X) != D)
        stop("Number of columns in X does not match the number of covariates in model")

    beta <- fit$draws("beta", format = "matrix") |>
        posterior::subset_draws(sprintf("^beta\\[%d,\\d+,", from), regex = T)

    zeta <- fit$draws("zeta", format = "matrix") |>
        posterior::subset_draws(sprintf("^zeta\\[\\d+,%d,", from), regex = T)

    beta.ll <- lapply(1:ndraws, \(m) matrix(beta[m, ], K, D))
    zeta.ll <- lapply(1:ndraws, function(m) {
        z <- matrix(0, nrow(X), K)
        for (i in 1:K) {
            cols <- sprintf("zeta[%d,%d,%d]", unit_id, from, i)
            z[, i] <- zeta[m, cols]
        }

        z
    })

    posterior_predict(beta.ll, zeta.ll, X[, -1], tiv, mc.cores)
}
