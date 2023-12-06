data {
  int N; // Total number of observations
  int K; // Number of latent states

  int D; // Dimensions for transition model covariates

  int n_conflicts;                        // Number of conflicts
  array[n_conflicts] int conflict_ends;   // Ending index position for each conflict
  array[n_conflicts] int conflict_starts; // Starting index position for each conflict

  matrix[N, D] X;          // Transition model covariates
  array[N] int<lower=0> y; // Emissions (ie BRD)
}

parameters {
  real<lower=0> phi;          // Overdispersion parameter
  array[K, K] vector[D] beta; // Transition probability coefficients

  // Partially pooled varying negative binomial rates
  array[n_conflicts] vector[K] eta_raw;
  ordered[K] lambda;
  vector<lower=0>[K] tau;

  // Partially pooled varying transition intercepts
  array[n_conflicts] matrix[K, K] alpha_raw;
  matrix<lower=0>[K, K] sigma;
  matrix[K, K] mu;
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

      // Initial state probabilities
      for (i in 1:K)
        Gamma[start, i] = neg_binomial_2_log_lpmf(y[start] | eta[conflict, i], phi);

      for (t in (start + 1):end) {
        for (i in 1:K) {
          vector[K] nu;
          for (j in 1:K)
            nu[j] = alpha[conflict, j, i] + X[t, ] * beta[j, i];

          // Log-likelihoods for y_t when transitioning to state i
          Gamma[t, i] = log_sum_exp(Gamma[t-1] + log_softmax(nu) +
                                    neg_binomial_2_log_lpmf(y[t] | eta[conflict, i], phi));
        }
      }
    }
  }
}

model {
  // Priors
  target += std_normal_lpdf(phi);

  for (i in 1:K) {
    for (j in 1:K)
      target += normal_lpdf(beta[i, j] | 0, 2.5);
  }

  target += normal_lpdf(lambda[1] | 0, 1);
  target += normal_lpdf(lambda[2] | 10, 5);
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
  array[N] vector[K] Gamma_backward;
  {
    for (conflict in 1:n_conflicts) {
      int start = conflict_starts[conflict],
        end = conflict_ends[conflict];

      for (i in 1:K)
        Gamma_backward[end, i] = 0;

      // Stan doesn't support reverse iteration :(
      for (t in 1:(end - start)) {
        int idx = end - t;

        for (i in 1:K) {
          vector[K] nu;
          for (j in 1:K)
            nu[j] = alpha[conflict, i, j] + X[idx, ] * beta[i, j];

          Gamma_backward[idx, i] = log_sum_exp(Gamma_backward[idx+1] +
                                               log_softmax(nu) +
                                               neg_binomial_2_log_lpmf(y[idx+1] | eta[conflict, i], phi));
        }
      }
    }
  }

  array[N] vector[K] Z_star;
  for (i in 1:N)
    Z_star[i] = softmax(Gamma[i] + Gamma_backward[i]);
}
