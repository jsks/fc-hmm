test_that("posterior_predict", {
    set.seed(5025)

    softmax <- \(x) exp(x) / sum(exp(x))

    K <- 2  # Number of states
    D <- 3  # Number of covariates
    N <- 10 # Number of observations
    M <- 2  # Number of posterior draws

    # List of K x D matrices of regression coefficients
    beta <- lapply(1:M, \(m) matrix(rnorm(K * D), K, D))

    # List of N x K matrices of intercepts
    zeta <- lapply(1:M, \(m) matrix(rnorm(N * K), N, K))

    # N x D matrix of covariates
    X <- matrix(rnorm(N * D), N, D)
    tiv <- as.numeric(1:5)

    probs <- lapply(1:M, function(m) {
        # For each pseudo-tiv value, calculate transition probabilities
        sapply(tiv, function(v) {
            X[, 1] <- v
            apply(zeta[[m]] + X %*% t(beta[[m]]), 1, softmax) |> rowMeans()
        })
    })

    out <- posterior_predict(beta, zeta, X[, -1], tiv, 1)

    for (m in 1:M)
        expect_equal(out[[m]], probs[[m]], tolerance = 1e-6)

    expect_error(posterior_predict(list(), list(), matrix(0), 0, 1))
    expect_error(posterior_predict(list(matrix(0), matrix(0)), list(matrix(0)),
                                   matrix(0), 0, 1))
})
