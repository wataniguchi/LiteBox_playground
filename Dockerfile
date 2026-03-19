# syntax=docker/dockerfile:1

ARG RUST_VERSION=1.94

# dependency management with cargo-chef
FROM lukemathwalker/cargo-chef:latest-rust-${RUST_VERSION} AS chef
WORKDIR /app

FROM chef AS planner
COPY ./litebox/ ./litebox/
COPY ./helloworld/ ./helloworld/
RUN cd ./litebox && cargo chef prepare --recipe-path recipe.json \
    && cd ../helloworld && cargo chef prepare --recipe-path recipe.json

FROM chef AS builder
# Build dependencies - this is the caching Docker layer!
COPY --from=planner /app/litebox/recipe.json ./litebox/recipe.json
COPY --from=planner /app/helloworld/recipe.json ./helloworld/recipe.json
RUN --mount=type=cache,target=/usr/local/cargo/registry,sharing=locked \
    --mount=type=cache,target=/usr/local/cargo/git,sharing=locked \
    cd ./litebox && cargo chef cook --release --recipe-path recipe.json \
    && cd ../helloworld && cargo chef cook --release --recipe-path recipe.json

# Build application - this layer will be rebuilt on source code changes
COPY ./litebox/ ./litebox/
COPY ./helloworld/ ./helloworld/
ENV DEBIAN_FRONTEND=noninteractive
RUN --mount=type=cache,target=/usr/local/cargo/registry,sharing=locked \
    --mount=type=cache,target=/usr/local/cargo/git,sharing=locked \
    apt-get update && apt-get install -y libclang-dev \
    && cd ./litebox && cargo build --release \
    && cd ../helloworld && cargo build --release

# Test LiteBox packager and syscall rewriter
FROM chef AS test
COPY ./litebox/ ./litebox/
COPY --from=builder /app/litebox/target/ ./litebox/target/
ENV DEBIAN_FRONTEND=noninteractive
RUN --mount=type=cache,target=/usr/local/cargo/registry,sharing=locked \
    --mount=type=cache,target=/usr/local/cargo/git,sharing=locked \
    cd ./litebox && cargo test --release --package litebox_runner_linux_userland test_syscall_rewriter \
    && cargo test --release --package litebox_packager

# Final runtime image for further testing and exploration
# Note: the entire litebox directory is copied here for ease of testing and exploration,
#       including source code and build artifacts.
#       The helloworld binary is also copied separately for ease of reference and testing.
FROM ubuntu:24.04 AS runtime
#FROM chef AS runtime
WORKDIR /app
COPY ./litebox/ ./litebox/
COPY --from=test /app/litebox/target/release/ ./litebox/target/release/
COPY --from=builder /app/helloworld/target/release/helloworld ./helloworld
ENV DEBIAN_FRONTEND=noninteractive
# Generate the initial file system tarball for the helloworld binary using litebox_packager.
RUN apt-get update && apt-get install -y iproute2 curl iputils-ping traceroute \
    && ./litebox/target/release/litebox_packager --verbose -o ./litebox-_app_helloworld.tar /app/helloworld
# When the container runs with --network=host, no need to execute tun-setup.sh.
CMD ["/bin/bash", "-c", "tail -f /dev/null"]
# When the container runs without --network=host,
# execute tun-setup.sh to make tun device ready for use by litebox_runner_linux_userland.
#CMD ["/bin/bash", "-c", "./litebox/litebox_platform_linux_userland/scripts/tun-setup.sh \
#    && tail -f /dev/null"]
