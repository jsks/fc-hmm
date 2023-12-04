data {
  int N; // Total number of observations
  int K; // Number of latent states

  int D; // Dimensions for transition model covariates
  int M; // Dimensions for observation model covariates

  int n_conflicts;                        // Number of conflicts
  array[n_conflicts] int conflict_lens;   // Number of observations per conflict
  array[n_conflicts] int conflict_starts; // Starting index position for each conflict

  matrix[N, M] W;          // Observation model covariates
  matrix[N, D] X;          // Transition model covariates
  array[N] int<lower=0> y; // Emissions (ie BRD)
}

parameters {
  array[K, K] vector[D] beta; // Transition probability coefficients

  //array[n_conflicts] vector[K] lambda; // Varying intercepts for observation model
  //positive_ordered[K] lambda;
  matrix[K, K] theta;                  // Varying intercepts for transition probabilities

  matrix[n_conflicts, K] Z_raw;
  vector[K] mu;
  vector<lower=0>[K] sigma;
}

transformed parameters {
  matrix[N, K] Gamma;
  array[n_conflicts] positive_ordered[K] lambda;
  for (conflict in 1:n_conflicts) {
    lambda[conflict] = mu + sigma * Z_raw[conflict, ];
  }


  {
    for (conflict in 1:n_conflicts) {
      int len = conflict_lens[conflict];
      int start = conflict_starts[conflict];

      // Initial state probabilities
      for (i in 1:K)
        Gamma[start, i] = poisson_lpmf(y[start] | lambda[i]);

      // Forward pass
      for (t in (start + 1):(start + len - 1)) {
        for (i in 1:K) {
          vector[K] nu;
          for (j in 1:K)
            nu[j] = theta[j, i] + X[t, ] * beta[j, i];

          // Log simplex of time-varying transition probabilities
          vector[K] lp = log_softmax(nu);

          // Log-likelihoods for y_t when transitioning to state i
          vector[K] aux = Gamma[t-1, ]' + lp + poisson_lpmf(y[t] | lambda[i]);
          Gamma[t, i] = log_sum_exp(aux);
        }
      }
    }
  }
}

model {
  // Priors
  for (i in 1:K) {
    for (j in 1:K) {
      beta[i, j] ~ normal(0, 2.5);
    }
  }

  for (i in 1:K)
    theta[, i] ~ normal(0, 5);

  //for (conflict in 1:n_conflicts) {
  //  lambda[conflict, 1] ~ normal(0, 1);
  //  lambda[conflict, 2] ~ normal(10, 5);
  //}

  target += normal_lpdf(lambda[1] | 0, 1);
  target += normal_lpdf(lambda[2] | 10, 5);

  // Likelihood
  for (i in conflict_lens)
    target += log_sum_exp(Gamma[i]);
}
