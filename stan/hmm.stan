data {
    int N; // Total number of observations
    int K; // Number of latent states

    int D;
    matrix[N, D] X;

    int n_conflicts; // Number of conflicts
    array[n_conflicts] int<lower=1, upper=N> conflict_starts; // Start of each conflict
    array[n_conflicts] int<lower=1, upper=N> conflict_ends; // End of each conflict

    array[N] int<lower=0> y; // Emissions

    // Prior parameters
    array[K] real lambda_location;
    array[K] real lambda_scale;
}

parameters {
    simplex[K] pi;              // Initial state distribution
    array[K] matrix[K, D] beta; // Covariate coefficients
    matrix[K, K] nu;            // Transition intercepts

    ordered[K] lambda; // Log-mean of each state
    real<lower=0> phi; // Overdispersion parameter
}

transformed parameters {
    array[N] vector[K] Gamma;
    {
        for (conflict in 1:n_conflicts) {
            int start = conflict_starts[conflict],
                end = conflict_ends[conflict];

            // Initial log-likelihoods
            for (j in 1:K)
                Gamma[start, j] = log(pi[j]) + neg_binomial_2_log_lpmf(y[start] | lambda[j], phi);

            for (t in (start + 1):end) {
                // Time-varying transition matrix (To x From), each
                // column should be a probability simplex
                matrix[K, K] Omega;
                for (i in 1:K)
                    // K x 1 + K x D * D x 1 -> K x 1
                    Omega[, i] = log_softmax(nu[, i] + beta[i] * X[t, ]');

                // Log-likelihood, transition from state i -> j
                for (j in 1:K)
                    Gamma[t, j] = log_sum_exp(Gamma[t - 1] + Omega[j, ]' +
                                              neg_binomial_2_log_lpmf(y[t] | lambda[j], phi));
            }
        }
    }
}

model {
    // Priors
    target += dirichlet_lpdf(pi | rep_vector(1, K));
    target += gamma_lpdf(phi | 2, 0.1);
    target += student_t_lpdf(to_vector(nu) | 3, 0, 1);
    for (i in 1:K) {
        target += normal_lpdf(to_vector(beta[i]) | 0, 2.5);
        target += normal_lpdf(lambda[i] | lambda_location[i], lambda_scale[i]);
    }

    // Likelihood
    for (t in conflict_ends)
        target += log_sum_exp(Gamma[t, ]);
}

generated quantities {
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
                    Omega[, i] = nu[, i] + beta[i] * X[t+1, ]';

                for (i in 1:K) {
                    // Transition from i -> j
                    vector[K] acc;
                    for (j in 1:K)
                        acc[j] = Gamma_backward[t + 1, j] + Omega[j, i] +
                                  neg_binomial_2_log_lpmf(y[t + 1] | lambda[j], phi);

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
        yhat[i] = neg_binomial_2_log_rng(lambda[Z[i]], phi);
    }
}
