functions {
    vector rank(vector theta, vector sim) {
        vector[size(theta)] lt;
        for (i in 1:size(theta))
            lt[i] = theta[i] < sim[i];

        return lt;
    }
}

data {
    int N;
    int K;

    int D;
    matrix[N, D] X;

    int n_conflicts;
    array[N] int<lower=1, upper=n_conflicts> conflict_id;
    array[n_conflicts] int<lower=1, upper=N> conflict_starts; // Start of each conflict
    array[n_conflicts] int<lower=1, upper=N> conflict_ends; // End of each conflict

    array[K] real mu_location; // Log-mean prior
    array[K] real<lower=0> mu_scale;    // Standard deviation of log-mean prior
}

transformed data {
    // Initial state probabilities
    simplex[K] pi_sim = dirichlet_rng(rep_vector(1, K));

    // Log-mean of negative binomial
    vector[K] mu_sim;
    vector<lower=0>[K] tau_sim;
    for (i in 1:K) {
        mu_sim[i] = normal_rng(mu_location[i], mu_scale[i]);
        tau_sim[i] = abs(normal_rng(0, 0.5));
    }
    mu_sim = sort_asc(mu_sim);

    array[n_conflicts] vector[K] eta_sim;
    for (conflict in 1:n_conflicts) {
        for (i in 1:K)
            eta_sim[conflict, i] = normal_rng(mu_sim[i], tau_sim[i]);
    }

    // Dispersion parameter for negative binomial
    real<lower=0> phi_sim = gamma_rng(2, 0.1);

    // Conflict-varying intercepts for transition matrix
    array[n_conflicts] matrix[K, K] alpha_sim;
    matrix<lower=0>[K, K] sigma_sim;
    for (i in 1:K) {
        for (j in 1:K)
            sigma_sim[i, j] = abs(cauchy_rng(0, 2.5));
    }
    for (conflict in 1:n_conflicts) {
        for (i in 1:K) {
            for (j in 1:K)
                alpha_sim[conflict, i, j] = normal_rng(0, sigma_sim[i, j]);
        }
    }

    matrix[K, K] nu_sim;            // Transition matrix intercept
    array[K] matrix[K, D] beta_sim; // Transition matrix covariate coefficients
    for (i in 1:K) {
        for (j in 1:K)
                nu_sim[i, j] = student_t_rng(3, 0, 1);

        for (j in 1:K) {
            for (d in 1:D)
                beta_sim[i, j, d] = normal_rng(0, 2.5);
        }
    }

    // Latent states and observations
    array[N] int y;
    array[N] int S;
    {
        for (conflict in 1:n_conflicts) {
            int start = conflict_starts[conflict],
                end = conflict_ends[conflict];

            S[start] = categorical_rng(pi_sim);
            y[start] = neg_binomial_2_log_rng(eta_sim[conflict,S[start]], phi_sim);

            for (t in (start + 1):end) {
                // K x D \times D x 1 -> K x 1
                vector[K] p = softmax(nu_sim[, S[t-1]] + alpha_sim[conflict][, S[t-1]] +
                                      beta_sim[S[t-1]] * X[t, ]');

                S[t] = categorical_rng(p);
                y[t] = neg_binomial_2_log_rng(eta_sim[conflict,S[t]], phi_sim);
            }
        }
    }
}

#include base.stan

generated quantities {
    vector[K] pi_lt = rank(pi, pi_sim);
    int phi_lt = phi < phi_sim;

    array[n_conflicts] matrix[K, K] alpha_lt;
    for (conflict in 1:n_conflicts) {
        for (i in 1:K)
            alpha_lt[conflict][,i] = rank(alpha[conflict][,i], alpha_sim[conflict][,i]);
    }

    array[K] matrix[K, D] beta_lt;
    for (i in 1:K) {
        for (j in 1:D)
            beta_lt[i][, j] = rank(beta[i][, j], beta_sim[i][, j]);
    }

    matrix[K, K] nu_lt;
    for (i in 1:K)
        nu_lt[, i] = rank(nu[, i], nu_sim[, i]);

    vector[K] mu_lt = rank(mu, mu_sim);
    vector[K] tau_lt = rank(tau, tau_sim);
}
