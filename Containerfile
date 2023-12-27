# Multi-stage build to avoid accumulating build dependencies in the
# final image. Output is two separate images for each HPC job.
#
# 1. Base image with build-essential
# 2. Build CmdStan and compile Stan files
# 3. R + package dependencies
# 4. Two final images:
#      - HMM image
#      - SBC image
###

FROM debian:testing-slim AS base

RUN apt-get update && \
    apt-get install -y --no-install-recommends build-essential && \
    rm -rf /var/lib/apt/lists/*

# Compile Stan models
FROM base AS cmdstan

ARG CMDSTAN_VERSION=2.34.1

RUN apt-get update && \
    apt-get install -y --no-install-recommends curl patchelf ca-certificates && \
    rm -rf /var/lib/apt/lists/*

RUN curl -LO https://github.com/stan-dev/cmdstan/releases/download/v${CMDSTAN_VERSION}/cmdstan-${CMDSTAN_VERSION}.tar.gz \
    && mkdir -p cmdstan \
    && tar -xzf cmdstan-${CMDSTAN_VERSION}.tar.gz --strip 1 -C cmdstan
WORKDIR /cmdstan

COPY etc/stan/local /cmdstan/make/local
COPY stan/*.stan .
RUN make -j$(nproc) hmm sim simple && \
    patchelf --set-rpath /usr/local/lib hmm sim simple && \
    strip -s hmm sim simple stan/lib/stan_math/lib/tbb/libtbb.so.2

FROM base AS R

ENV _R_SHLIB_STRIP_=TRUE

RUN apt-get update && \
    apt-get install -y --no-install-recommends r-base-core && \
    rm -rf /var/lib/apt/lists/*

RUN Rscript -e "install.packages(c('docopt', 'dplyr', 'cmdstanr'), \
                                 repos = c('https://mc-stan.org/r-packages/', getOption('repos')), \
                                 Ncpus = parallel::detectCores())"

RUN mkdir -p /project/data
WORKDIR /project

# Hidden markov model image
FROM R AS hmm

COPY --from=cmdstan /cmdstan/hmm .
COPY --from=cmdstan /cmdstan/stan/lib/stan_math/lib/tbb/libtbb.so.2 /usr/local/lib/libtbb.so.2
COPY R/hmm.R .

CMD Rscript hmm.R --stan-file=hmm --output data/fit.rds data/model_data.rds

# Simulation based calibration image
FROM R AS sbc

COPY --from=cmdstan /cmdstan/sim .
COPY --from=cmdstan /cmdstan/simple .
COPY --from=cmdstan /cmdstan/stan/lib/stan_math/lib/tbb/libtbb.so.2 /usr/local/lib/libtbb.so.2
COPY R/sbc.R .

CMD Rscript sbc.R
