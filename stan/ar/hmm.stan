/*
 * This file contains the Stan code for the input data and generating
 * posterior quantities. The actual HMM implementation is defined in
 * `base.stan`.
 */

data {
  int N;          // Total number of observations across all sequences
  int K;          // Number of latent states
  int D;          // Number of regressor covariates
  matrix[N, D] X; // Transition regressor covariates

  int n_conflicts;                                          // Number of conflicts
  array[N] int<lower=1, upper=n_conflicts> conflict_id;     // Conflict id for each obs.
  array[n_conflicts] int<lower=1, upper=N> conflict_starts; // Start of each conflict
  array[n_conflicts] int<lower=1, upper=N> conflict_ends;   // End of each conflict

  array[N] int<lower=0> y; // Emissions

  // Prior parameters - emission log-means
  array[K] real mu_location;
  array[K] real mu_scale;

  // SD prior for partially pooled intercepts
  real<lower=0> sigma_scale;
  real<lower=0> tau_scale;
}

#include base.stan

generated quantities {
    vector[n_conflicts] log_lik;
    for (conflict in 1:n_conflicts)
        log_lik[conflict] = log_sum_exp(Gamma[conflict_ends[conflict]]);

    // Backwards pass log-probabilities
    array[N] vector[K] Gamma_backward;
    {
        vector[K] aux; // Accumulator for log-probabilities
        for (conflict in 1:n_conflicts) {
            int start = conflict_starts[conflict],
                end = conflict_ends[conflict];

            for (i in 1:K)
                Gamma_backward[end, i] = 0;

            for (idx in 1:(end - start)) {
                int t = end - idx;

                // Time-varying transition matrix, again each row is a
                // probability simplex
                matrix[K, K] Omega;
                for (i in 1:K)
                    Omega[i, ] = log_softmax(zeta[conflict][, i] + beta[i] * X[t+1, ]')';

                // Backwards log-probability, log p(y_{t+1:T} | Z_t = i)
                for (i in 1:K) {
                    // Transition from i -> j
                    for (j in 1:K)
                        aux[j] = Gamma_backward[t + 1, j] + Omega[i, j] +
                                  neg_binomial_2_log_lpmf(y[t + 1] | eta[j] + rho[j] * log1p(y[t]), phi);

                    Gamma_backward[t, i] = log_sum_exp(aux);
                }
            }
        }
    }

    array[N] vector[K] Zprob; // Posterior probability p(Z_t = k | y_{1:T})
    array[N] int Zhat;        // Latent state estimate
    array[N] int yhat;        // Posterior predicted emissions

    for (i in 1:N) {
        Zprob[i] = exp(Gamma[i] + Gamma_backward[i] - log_lik[conflict_id[i]]);
        Zhat[i] = categorical_rng(Zprob[i]);

        real lambda = (i == conflict_starts[conflict_id[i]])
                         ? eta[Zhat[i]]
                         : eta[Zhat[i]] + rho[Zhat[i]] * log1p(y[i - 1]);
        yhat[i] = neg_binomial_2_log_rng(lambda, phi);
    }
}
