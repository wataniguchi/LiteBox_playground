# syntax=docker/dockerfile:1

ARG RUST_VERSION=1.94
ARG APP_NAME=litebox

# dependency management with cargo-chef
FROM lukemathwalker/cargo-chef:latest-rust-${RUST_VERSION} AS chef
WORKDIR /app

FROM chef AS planner
COPY ./litebox .
RUN cargo chef prepare --recipe-path recipe.json

FROM chef AS builder
# Build dependencies - this is the caching Docker layer!
COPY --from=planner /app/recipe.json recipe.json
RUN --mount=type=cache,target=/usr/local/cargo/registry,sharing=locked \
    --mount=type=cache,target=/usr/local/cargo/git,sharing=locked \
    cargo chef cook --release --recipe-path recipe.json

# Build application
COPY ./litebox .
ENV DEBIAN_FRONTEND=noninteractive
RUN --mount=type=cache,target=/usr/local/cargo/registry,sharing=locked \
    --mount=type=cache,target=/usr/local/cargo/git,sharing=locked \
    --mount=type=cache,target=/app/target,sharing=locked \
    apt-get update && apt-get install -y libclang-dev \
    && cargo build --release

# Test LiteBox library
FROM chef AS test
COPY ./litebox .
ENV DEBIAN_FRONTEND=noninteractive
RUN --mount=type=cache,target=/usr/local/cargo/registry,sharing=locked \
    --mount=type=cache,target=/usr/local/cargo/git,sharing=locked \
    --mount=type=cache,target=/app/target,sharing=locked \
    apt-get update && apt-get install -y iproute2 \
    && cargo test --release --package litebox --lib -- --skip nine_p

CMD ["/bin/bash", "-c", "./litebox_platform_linux_userland/scripts/tun-setup.sh && tail -f /dev/null"]