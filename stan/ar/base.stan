/*
 * Hidden Markov Model
 *
 * Assumes first-order, discrete markov process with negative binomial
 * emissions. Transition matrix is time-varying as a function of
 *  covariates, X.
 */

parameters {
    simplex[K] pi;              // Initial state distribution
    array[K] matrix[K, D] beta; // Covariate coefficients

    // Partially pooled transition intercepts
    array[n_conflicts] matrix[K, K] zeta_raw;
    matrix[K, K] nu;
    matrix<lower=0>[K, K] sigma;

    // Partially pooled negbin log-mean for each state
    ordered[K] eta;

    vector<lower=0, upper=1>[K] rho;

    // Negative binomial overdispersion parameter
    real<lower=0> phi;
}

transformed parameters {
    array[N] vector[K] Gamma;             // Forward log-probabilities
    array[n_conflicts] matrix[K, K] zeta; // Transition intercepts

    {
        for (conflict in 1:n_conflicts) {
            int start = conflict_starts[conflict],
                end = conflict_ends[conflict];

            zeta[conflict] = nu + sigma .* zeta_raw[conflict];

            // Initialize forward probabilities
            for (i in 1:K)
                Gamma[start, i] = log(pi[i]) + neg_binomial_2_log_lpmf(y[start] | eta[i], phi);

            for (t in (start + 1):end) {
                // Time-varying transition matrix (To x From), each
                // row is a probability simplex
                matrix[K, K] Omega;
                for (i in 1:K)
                    // K x 1 + K x D * D x 1 -> K x 1
                    Omega[i, ] = log_softmax(zeta[conflict][, i] + beta[i] * X[t, ]')';

                // Forward log-probability, log p(y_1, ..., y_t, Z_t = j)
                for (j in 1:K)
                    // Transitioning from state i -> j
                    Gamma[t, j] = log_sum_exp(Gamma[t - 1] +
                                              Omega[, j] +
                                              neg_binomial_2_log_lpmf(y[t] | eta[j] + rho[j] * log1p(y[t-1]), phi));
            }
        }
    }
}

model {
    // Priors
    target += dirichlet_lpdf(pi | rep_vector(1, K));
    target += gamma_lpdf(phi | 2, 0.1);
    target += normal_lpdf(rho | 0, 0.25);
    for (i in 1:K)
        target += std_normal_lpdf(to_vector(beta[i]));

    // Partially pooled transition intercepts
    target += student_t_lpdf(to_vector(nu) | 3, 0, 1);
    target += normal_lpdf(to_vector(sigma) | 0, sigma_scale);
    for (conflict in 1:n_conflicts)
        target += std_normal_lpdf(to_vector(zeta_raw[conflict]));

    // Partially pooled negative binomial log mean intercept
    for (i in 1:K)
        target += normal_lpdf(eta[i] | mu_location[i], mu_scale[i]);

    // Likelihood, formed by marginalizing over Z_T
    for (end in conflict_ends)
        target += log_sum_exp(Gamma[end]);
}
