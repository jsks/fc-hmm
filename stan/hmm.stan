data {
  int N; // Total number of observations
  int K; // Number of latent states

  int D; // Dimensions for transition model covariates

  int n_conflicts;                        // Number of conflicts
  array[n_conflicts] int conflict_starts; // Starting index position for each conflict
  array[n_conflicts] int conflict_ends;   // Ending index position for each conflict

  matrix[N, D] X;          // Transition model covariates
  array[N] int<lower=0> y; // Emissions (eg BRD)
}

parameters {
  real<lower=0> phi;              // Overdispersion parameter
  array[D] matrix[K, K] beta;     // Transition probability coefficients
  vector<lower=0>[K] upsilon;     // Transition probability scale
  cholesky_factor_corr[K] L_corr; // Transition coefficient correlation

  simplex[K] pi; // Initial state probabilities

  // Partially pooled varying transition intercepts
  array[n_conflicts] matrix[K, K] alpha_raw;
  matrix<lower=0>[K, K] sigma;
  matrix[K, K] mu;

  // Partially pooled varying negative binomial rates
  array[n_conflicts] vector[K] eta_raw;
  ordered[K] lambda;
  vector<lower=0>[K] tau;
}

transformed parameters {
  array[N] vector[K] Gamma;

  array[n_conflicts] vector[K] eta;
  array[n_conflicts] matrix[K, K] alpha;

  {
    for (conflict in 1:n_conflicts) {
      // eta_{conflict} ~ normal(lambda, tau)
      eta[conflict] = lambda + tau .* eta_raw[conflict];

      // alpha_{conflict} ~ normal(mu, sigma)
      alpha[conflict] = mu + sigma .* alpha_raw[conflict];

      int start = conflict_starts[conflict],
          end = conflict_ends[conflict];

      // Initial log-likelihoods
      for (i in 1:K)
        Gamma[start, i] = log(pi[i]) + neg_binomial_2_log_lpmf(y[start] | eta[conflict, i], phi);

      for (t in (start + 1):end) {
        // Time varying transition probabilities matrix
        matrix[K, K] nu = alpha[conflict, ];
        for (d in 1:D)
          nu += X[t, d] * beta[d];

        for (j in 1:K)
          nu[, j] = log_softmax(nu[, j]);

        for (i in 1:K) {
          // Log-likelihoods for y_t when transitioning to from j -> i
          Gamma[t, i] = log_sum_exp(Gamma[t-1] + nu[i, ]' +
                                    neg_binomial_2_log_lpmf(y[t] | eta[conflict, i], phi));
        }
      }
    }
  }
}

model {
  // Priors
  target += gamma_lpdf(phi | 2, 0.1);
  target += dirichlet_lpdf(pi | rep_vector(1, K));

  target += lkj_corr_cholesky_lpdf(L_corr | 1);
  target += cauchy_lpdf(upsilon | 0, 1);
  for (d in 1:D)
    target += multi_normal_cholesky_lpdf(to_vector(beta[d]) | rep_vector(0, K * K), diag_pre_multiply(upsilon, L_corr));

  target += normal_lpdf(lambda[1] | 0, 1);
  target += normal_lpdf(lambda[2] | 6.2, 1);
  target += normal_lpdf(tau | 0, 0.5);

  target += normal_lpdf(to_vector(mu) | 0, 1);
  target += normal_lpdf(to_vector(sigma) | 0, 0.5);

  for (conflict in 1:n_conflicts) {
    target += std_normal_lpdf(to_vector(eta_raw[conflict]));
    target += std_normal_lpdf(to_vector(alpha_raw[conflict]));
  }

  // Likelihood
  for (conflict in 1:n_conflicts)
      target += log_sum_exp(Gamma[conflict_ends[conflict]]);
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

      // Stan doesn't support reverse iteration :(
      for (idx in 1:(end - start)) {
        int t = end - idx;

        matrix[K, K] nu = alpha[conflict, ];
        for (d in 1:D)
          nu += X[t, d] * beta[d];

        for (i in 1:K) {
          vector[K] kappa;
          for (j in 1:K)
            kappa[j] = neg_binomial_2_log_lpmf(y[t+1] | eta[conflict, j], phi);

          Gamma_backward[t, i] = log_sum_exp(Gamma_backward[t+1] + log_softmax(nu[, i]) + kappa);
        }
      }
    }
  }

  // Probabilities of each state at each time point
  array[N] vector[K] Z_star;
  for (i in 1:N)
    Z_star[i] = exp(Gamma[i] + Gamma_backward[i] - log_sum_exp(Gamma[i] + Gamma_backward[i]));

  for (conflict in 1:n_conflicts) {
    int start = conflict_starts[conflict],
        end = conflict_ends[conflict];

    for (t in start:end) {
      int state = categorical_rng(Z_star[t]);
      y_pred[t] = neg_binomial_2_log_rng(eta[conflict, state], phi);
    }
  }
}
