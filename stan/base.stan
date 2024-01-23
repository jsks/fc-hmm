parameters {
    simplex[K] pi;              // Initial state distribution
    array[K] matrix[K, D] beta; // Covariate coefficients
    matrix[K, K] nu;            // Transition intercepts

    // Partially pooled negbin log-mean for each state
    array[n_conflicts] vector[K] eta_raw;
    ordered[K] mu;
    vector<lower=0>[K] tau;

    // Partially pooled transition intercepts
    array[n_conflicts] matrix[K, K] alpha_raw;
    matrix<lower=0>[K, K] sigma;

    // Negative binomial overdispersion parameter
    real<lower=0> phi;
}

transformed parameters {
    array[N] vector[K] Gamma;
    array[n_conflicts] vector[K] eta;
    array[n_conflicts] matrix[K, K] alpha;

    {
        for (conflict in 1:n_conflicts) {
            int start = conflict_starts[conflict],
                end = conflict_ends[conflict];

            // Conflict specific state transition intercepts
            for (i in 1:K)
               alpha[conflict][, i] = sigma[, i] .* alpha_raw[conflict][, i];

            // Conflict specific emission log-means
            for (i in 1:K)
                eta[conflict, i] = mu[i] + tau[i] * eta_raw[conflict, i];

            // Initial log-likelihoods
            for (j in 1:K)
                Gamma[start, j] = log(pi[j]) + neg_binomial_2_log_lpmf(y[start] | eta[conflict,j], phi);

            for (t in (start + 1):end) {
                // Time-varying transition matrix (To x From), each
                // column should be a probability simplex
                matrix[K, K] Omega;
                for (i in 1:K)
                    // K x 1 + K x D * D x 1 -> K x 1
                    Omega[, i] = log_softmax(nu[, i] + alpha[conflict][, i] + beta[i] * X[t, ]');

                // Log-likelihood, transition from state i -> j
                for (j in 1:K)
                    Gamma[t, j] = log_sum_exp(Gamma[t - 1] + Omega[j, ]' +
                                              neg_binomial_2_log_lpmf(y[t] | eta[conflict,j], phi));
            }
        }
    }
}

model {
    // Priors
    target += dirichlet_lpdf(pi | rep_vector(1, K));
    target += gamma_lpdf(phi | 2, 0.1);
    target += student_t_lpdf(to_vector(nu) | 3, 0, 1);
    for (i in 1:K)
        target += normal_lpdf(to_vector(beta[i]) | 0, 2.5);

    // Partially pooled transition intercepts
    target += cauchy_lpdf(to_vector(sigma) | 0, 2.5);
    for (conflict in 1:n_conflicts)
        target += std_normal_lpdf(to_vector(alpha_raw[conflict]));

    // Partially pooled negative binomial log mean
    target += normal_lpdf(tau | 0, 0.5);
    for (conflict in 1:n_conflicts)
        target += std_normal_lpdf(eta_raw[conflict]);

    for (i in 1:K)
        target += normal_lpdf(mu[i] | mu_location[i], mu_scale[i]);

    // Likelihood
    for (end in conflict_ends)
        target += log_sum_exp(Gamma[end]);
}
