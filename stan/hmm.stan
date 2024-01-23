data {
    int N; // Total number of observations
    int K; // Number of latent states

    int D;
    matrix[N, D] X;

    int n_conflicts; // Number of conflicts
    array[N] int<lower=1, upper=n_conflicts> conflict_id;     // Conflict id for each obs.
    array[n_conflicts] int<lower=1, upper=N> conflict_starts; // Start of each conflict
    array[n_conflicts] int<lower=1, upper=N> conflict_ends;   // End of each conflict

    array[N] int<lower=0> y; // Emissions

    // Prior parameters
    array[K] real mu_location;
    array[K] real mu_scale;
}

#include base.stan

generated quantities {
    vector[n_conflicts] log_lik;
    for (conflict in 1:n_conflicts)
        log_lik[conflict] = log_sum_exp(Gamma[conflict_ends[conflict]]);

    array[N] int y_pred;
    array[N] vector[K] Gamma_backward;

    {
        for (conflict in 1:n_conflicts) {
            int start = conflict_starts[conflict],
                end = conflict_ends[conflict];

            for (i in 1:K)
                Gamma_backward[end, i] = 0;

            for (idx in 1:(end - start)) {
                int t = end - idx;

                matrix[K, K] Omega;
                for (i in 1:K)
                    Omega[, i] = log_softmax(nu[, i] + alpha[conflict][, i] + beta[i] * X[t+1, ]');

                for (i in 1:K) {
                    // Transition from i -> j
                    vector[K] acc;
                    for (j in 1:K)
                        acc[j] = Gamma_backward[t + 1, j] + Omega[j, i] +
                                  neg_binomial_2_log_lpmf(y[t + 1] | eta[conflict,j], phi);

                    // Log-likelihood b_{t, T}
                    Gamma_backward[t, i] = log_sum_exp(acc);
                }
            }
        }
    }

    array[N] vector[K] Z_prob;
    array[N] int Z;
    array[N] int yhat;
    for (i in 1:N) {
        Z_prob[i] = exp(Gamma[i] + Gamma_backward[i] - log_sum_exp(Gamma[i] + Gamma_backward[i]));
        Z[i] = categorical_rng(Z_prob[i]);
        yhat[i] = neg_binomial_2_log_rng(eta[conflict_id[i], Z[i]], phi);
    }
}
