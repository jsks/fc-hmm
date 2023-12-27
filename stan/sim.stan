data {
    int N;
    int K;

    int D;
    matrix[N, D] X;

    int n_conflicts;
    array[n_conflicts] int<lower=1, upper=N> conflict_start; // Start of each conflict
    array[n_conflicts] int<lower=1, upper=N> conflict_end; // End of each conflict

    array[K] real lambda_location; // Log-mean prior
    array[K] real lambda_scale;    // Standard deviation of log-mean prior
}

generated quantities {
    // Initial state probabilities
    simplex[K] pi = dirichlet_rng(rep_vector(1, K));

    // Log-mean of negative binomial
    vector[K] lambda;
    for (i in 1:K)
        lambda[i] = normal_rng(lambda_location[i], lambda_scale[i]);
    lambda = sort_asc(lambda);

    // Dispersion parameter for negative binomial
    real<lower=0> phi = gamma_rng(2, 0.1);

    matrix[K, K] nu;
    array[K] matrix[K, D] beta;
    for (i in 1:K) {
        // Transition matrix intercept
        for (j in 1:K)
                nu[i, j] = student_t_rng(3, 0, 1);

        // Transition matrix covariate coefficients
        for (j in 1:K) {
            for (d in 1:D)
                beta[i, j, d] = normal_rng(0, 2.5);
        }
    }

    // Latent states and observations
    array[N] int y;
    array[N] int S;
    {
        for (conflict in 1:n_conflicts) {
            int start = conflict_start[conflict],
                end = conflict_end[conflict];

            S[start] = categorical_rng(pi);
            y[start] = neg_binomial_2_log_rng(lambda[S[start]], phi);

            for (t in (start + 1):end) {
                // K x D \times D x 1 -> K x 1
                vector[K] p = softmax(nu[, S[t-1]] + beta[S[t-1]] * X[t, ]');

                S[t] = categorical_rng(p);
                y[t] = neg_binomial_2_log_rng(lambda[S[t]], phi);
            }
        }
    }
}
