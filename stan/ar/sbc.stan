/*
 * Simulation-Based Calibration
 *
 * This validates the HMM implementation in `base.stan` according to
 * the following procedure:
 *   1. Generate simulated data, theta' ~ p(theta) and y' ~ p(y|theta', X)
 *      for fixed covariates X.
 *   2. Fit full inference model to the simulated data
 *   3. Calculate rank statistics comparing posterior draws from p(theta
 *        | y', X) to theta'
 *
 * The file `scripts/sbc.sh` repeats this procedure ITER times and the
 * histograms are plotted in the appendix of the paper.
 */

functions {
    vector rank(vector theta, vector sim) {
        vector[size(theta)] lt;
        for (i in 1:size(theta))
            lt[i] = theta[i] < sim[i];

        return lt;
    }
}

data {
  int N;          // Total number of observations across all sequences
  int K;          // Number of latent states
  int D;          // Number of regressor covariates
  matrix[N, D] X; // Transition regressor covariates

  int n_conflicts;                                          // Number of conflicts
  array[N] int<lower=1, upper=n_conflicts> conflict_id;     // Conflict id for each obs.
  array[n_conflicts] int<lower=1, upper=N> conflict_starts; // Start of each conflict
  array[n_conflicts] int<lower=1, upper=N> conflict_ends;   // End of each conflict

  // Prior parameters - emission log-means
  array[K] real mu_location;
  array[K] real mu_scale;

  // SD prior for partially pooled intercepts
  real<lower=0> sigma_scale;
  real<lower=0> tau_scale;
}

transformed data {
    // Initial state probabilities
    simplex[K] pi_sim = dirichlet_rng(rep_vector(1, K));

    // Dispersion parameter for negative binomial
    real<lower=0> phi_sim = gamma_rng(2, 0.1);

    // Covariate coefficients for transition matrix
    array[K] matrix[K, D] beta_sim;
    for (i in 1:K) {
        for (j in 1:K) {
            for (d in 1:D)
                beta_sim[i, j, d] = std_normal_rng();
        }
    }

    // Partially pooled transition intercepts
    matrix[K, K] nu_sim;
    matrix<lower=0>[K, K] sigma_sim;

    for (i in 1:K) {
        for (j in 1:K) {
            nu_sim[i, j] = student_t_rng(3, 0, 1);
            sigma_sim[i, j] = abs(normal_rng(0, sigma_scale));
        }
    }

    array[n_conflicts] matrix[K, K] zeta_sim;
    for (conflict in 1:n_conflicts) {
        for (i in 1:K) {
            for (j in 1:K) {
                zeta_sim[conflict, i, j] = normal_rng(nu_sim[i, j], sigma_sim[i, j]);
            }
        }
    }

    // Conflict specific negative binomial log-means
    vector<lower=-1, upper=1>[K] rho_sim;
    vector[K] eta_sim;
    for (i in 1:K) {
        rho_sim[i] = normal_rng(0, 0.5);
        eta_sim[i] = normal_rng(mu_location[i], mu_scale[i]);
    }
    eta_sim = sort_asc(eta_sim);

    // Latent states and observations
    array[N] int y;
    array[N] int S;
    {
        for (conflict in 1:n_conflicts) {
            int start = conflict_starts[conflict],
                end = conflict_ends[conflict];

            S[start] = categorical_rng(pi_sim);
            y[start] = neg_binomial_2_log_rng(eta_sim[S[start]], phi_sim);

            for (t in (start + 1):end) {
                // K x 1 + K x D \times D x 1 -> K x 1
                vector[K] p = softmax(zeta_sim[conflict][, S[t-1]] + beta_sim[S[t-1]] * X[t, ]');

                S[t] = categorical_rng(p);
                y[t] = neg_binomial_2_log_rng(eta_sim[S[t]] + rho_sim[S[t]] * (log1p(y[t-1]) - eta_sim[S[t]]), phi_sim);
            }
        }
    }
}

#include base.stan

generated quantities {
    vector[K] pi_lt = rank(pi, pi_sim);
    int phi_lt = phi < phi_sim;

    array[K] matrix[K, D] beta_lt;
    for (i in 1:K) {
        for (j in 1:D)
            beta_lt[i][, j] = rank(beta[i][, j], beta_sim[i][, j]);
    }

    matrix[K, K] nu_lt;
    matrix[K, K] sigma_lt;
    for (i in 1:K) {
        nu_lt[, i] = rank(nu[, i], nu_sim[, i]);
        sigma_lt[, i] = rank(sigma[, i], sigma_sim[, i]);
    }

    vector[K] eta_lt = rank(eta, eta_sim);
    vector[K] rho_lt = rank(rho, rho_sim);
}
