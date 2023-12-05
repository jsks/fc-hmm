data {
  int N; // Total number of observations
  int K; // Number of latent states

  int D; // Dimensions for transition model covariates
  int M; // Dimensions for observation model covariates

  int n_conflicts;                        // Number of conflicts
  array[n_conflicts] int conflict_ends;   // Ending index position for each conflict
  array[n_conflicts] int conflict_starts; // Starting index position for each conflict

  matrix[N, M] W;          // Observation model covariates
  matrix[N, D] X;          // Transition model covariates
  array[N] int<lower=0> y; // Emissions (ie BRD)
}

parameters {
  real<lower=0> phi;          // Overdispersion parameter
  array[K, K] vector[D] beta; // Transition probability coefficients

  // Partially pooled varying negative binomial rates
  array[n_conflicts] vector[K] eta_raw;
  vector[K] lambda;
  vector<lower=0>[K] tau;

  // Partially pooled varying transition intercepts
  array[n_conflicts] matrix[K, K] alpha_raw;
  matrix<lower=0>[K, K] sigma;
  matrix[K, K] mu;
}

transformed parameters {
  matrix[N, K] Gamma;

  array[n_conflicts] ordered[K] eta;
  array[n_conflicts] matrix[K, K] alpha;

  {
    for (conflict in 1:n_conflicts) {
      // eta_{conflict} ~ normal(lambda, tau)
      eta[conflict] = lambda + tau .* eta_raw[conflict];

      // alpha_{conflict} ~ normal(mu, sigma)
      alpha[conflict] = mu + sigma .* alpha_raw[conflict];

      int end = conflict_ends[conflict];
      int start = conflict_starts[conflict];

      // Initial state probabilities
      for (i in 1:K)
        Gamma[start, i] = neg_binomial_2_log_lpmf(y[start] | eta[conflict, i], phi);

      for (t in (start + 1):end) {
        for (i in 1:K) {
          vector[K] nu;
          for (j in 1:K)
            nu[j] = alpha[conflict, j, i] + X[t, ] * beta[j, i];

          // Log simplex of time-varying transition probabilities
          vector[K] lp = log_softmax(nu);

          // Log-likelihoods for y_t when transitioning to state i
          vector[K] aux = Gamma[t-1, ]' + lp + neg_binomial_2_log_lpmf(y[t] | eta[conflict, i], phi);
          Gamma[t, i] = log_sum_exp(aux);
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

  for (i in 1:n_conflicts) {
    target += std_normal_lpdf(to_vector(eta_raw[i]));
    target += normal_lpdf(lambda[1] | 0, 1);
    target += normal_lpdf(lambda[2] | 10, 5);
    target += normal_lpdf(tau | 0, 0.5);

    target += std_normal_lpdf(to_vector(alpha_raw[i]));
    target += normal_lpdf(to_vector(mu) | 0, 1);
    target += normal_lpdf(to_vector(sigma) | 0, 0.5);
  }

  // Likelihood
  for (i in 1:n_conflicts)
      target += log_sum_exp(Gamma[conflict_ends[i], ]);
}
