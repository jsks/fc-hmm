# Multi-stage build to avoid accumulating build dependencies in the
# final image. Output is two separate images for each HPC job.
#
# 1. Build CmdStan and compile Stan files
# 2. SBC image
# 3. HMM image
###

# Compile Stan models
FROM debian:12 AS cmdstan

ARG CMDSTAN_VERSION=2.34.1

RUN apt-get update && \
    apt-get install -y --no-install-recommends \
        build-essential \
        curl \
        patchelf \
        ca-certificates  && \
    rm -rf /var/lib/apt/lists/*

RUN curl -LO https://github.com/stan-dev/cmdstan/releases/download/v${CMDSTAN_VERSION}/cmdstan-${CMDSTAN_VERSION}.tar.gz \
    && mkdir -p cmdstan \
    && tar -xzf cmdstan-${CMDSTAN_VERSION}.tar.gz --strip 1 -C cmdstan
WORKDIR /cmdstan

COPY etc/stan/local /cmdstan/make/local
COPY stan/*.stan .

RUN STANCFLAGS="--include-paths /cmdstan" make -j$(nproc) bin/diagnose hmm sbc && \
    patchelf --set-rpath / hmm sbc && \
    strip -s bin/diagnose hmm sbc stan/lib/stan_math/lib/tbb/libtbb.so.2

# Simulation based calibration image
FROM gcr.io/distroless/cc-debian12 AS sbc

# This is unnecessary for the image, but it's nice to know exactly
# which model code was run.
COPY stan/*.stan .

COPY --from=cmdstan /cmdstan/bin/diagnose .
COPY --from=cmdstan /cmdstan/sbc .
COPY --from=cmdstan /cmdstan/stan/lib/stan_math/lib/tbb/libtbb.so.2 libtbb.so.2
COPY data/json/sbc.json .

ENTRYPOINT ["/sbc", "data", "file=/sbc.json", "sample"]

# Hidden markov model image
FROM gcr.io/distroless/cc-debian12 AS hmm

COPY stan/*.stan .

COPY --from=cmdstan /cmdstan/bin/diagnose .
COPY --from=cmdstan /cmdstan/hmm .
COPY --from=cmdstan /cmdstan/stan/lib/stan_math/lib/tbb/libtbb.so.2 libtbb.so.2
COPY data/json/hmm.json .

ENTRYPOINT ["/hmm", "data", "file=/hmm.json", "sample", "num_warmup=5000", \
            "num_samples=2000", "thin=2", "adapt", "delta=0.95", \
            "algorithm=hmc", "engine=nuts"]
