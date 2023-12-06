FROM debian:testing-slim AS base

RUN apt-get update && \
    apt-get install -y --no-install-recommends \
        build-essential \
        ca-certificates \
        curl \
        patchelf && \
    rm -rf /var/lib/apt/lists/*

FROM base AS cmdstan

ARG CMDSTAN_VERSION=2.34.1

RUN curl -LO https://github.com/stan-dev/cmdstan/releases/download/v${CMDSTAN_VERSION}/cmdstan-${CMDSTAN_VERSION}.tar.gz \
    && mkdir -p cmdstan \
    && tar -xzf cmdstan-${CMDSTAN_VERSION}.tar.gz --strip 1 -C cmdstan
WORKDIR /cmdstan

COPY etc/stan/local /cmdstan/make/local
COPY stan/hmm.stan .
RUN make -j$(nproc) hmm && \
    patchelf --set-rpath /usr/local/lib hmm && \
    strip -s hmm

FROM base

RUN apt-get update && \
    apt-get install -y --no-install-recommends r-base-core && \
    rm -rf /var/lib/apt/lists/*

RUN Rscript -e "install.packages(c('docopt', 'dplyr', 'cmdstanr'), \
                                 repos = c('https://mc-stan.org/r-packages/', getOption('repos')), \
                                 Ncpus = parallel::detectCores())"

RUN mkdir -p /project/data
WORKDIR /project

COPY --from=cmdstan /cmdstan/hmm .
COPY --from=cmdstan /cmdstan/stan/lib/stan_math/lib/tbb/libtbb.so.2 /usr/local/lib/libtbb.so.2
COPY R/hmm.R .

CMD Rscript hmm.R --stan-file=hmm --output data/fit.rds data/model_data.rds
