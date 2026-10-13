# syntax=docker/dockerfile:1.7

# Paperclip self-hosted instance image for sndbx.
# Builds the server and UI from the pinned upstream source, then runs them
# under the embedded PostgreSQL database stored in the persistent home
# directory (bind-mounted at /paperclip).

ARG NODE_IMAGE=node:24-trixie-slim

# --- Source checkout ---------------------------------------------------------
# Fetch the exact upstream revision once so later stages share one tree.
FROM ${NODE_IMAGE} AS source

ARG PAPERCLIP_GIT=https://github.com/paperclipai/paperclip.git
ARG PAPERCLIP_REF=v2026.1012.0

RUN apt-get update \
    && apt-get install --yes --no-install-recommends ca-certificates git \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /src
RUN git clone --filter=blob:none "${PAPERCLIP_GIT}" . \
    && git checkout "${PAPERCLIP_REF}" \
    && rm -rf .git

# --- Application build -------------------------------------------------------
# Installs the pnpm workspace plus the Rust toolchain the native Paperclip
# runner needs, then builds the UI, plugin SDK, and server. Mirrors the
# upstream production Dockerfile without its CI-only provider-pack steps.
FROM ${NODE_IMAGE} AS builder

ARG RUSTUP_VERSION=1.29.0
ARG RUSTUP_SHA256_AMD64=4acc9acc76d5079515b46346a485974457b5a79893cfb01112423c89aeb5aa10
ARG RUSTUP_SHA256_ARM64=9732d6c5e2a098d3521fca8145d826ae0aaa067ef2385ead08e6feac88fa5792

ENV DEBIAN_FRONTEND=noninteractive \
    RUSTUP_HOME=/usr/local/rustup \
    CARGO_HOME=/usr/local/cargo \
    PATH=/usr/local/cargo/bin:${PATH}

RUN apt-get update \
    && apt-get install --yes --no-install-recommends \
        ca-certificates \
        curl \
        g++ \
        gcc \
        git \
        libc6-dev \
        make \
        pkg-config \
        python3 \
    && rm -rf /var/lib/apt/lists/* \
    && corepack enable

# The runner pins its own compiler in rust-toolchain.toml, so install only
# rustup here and let the package choose the toolchain.
RUN set -eux; \
    arch="$(dpkg --print-architecture)"; \
    case "${arch}" in \
        amd64) rust_target="x86_64-unknown-linux-gnu"; sha256="${RUSTUP_SHA256_AMD64}" ;; \
        arm64) rust_target="aarch64-unknown-linux-gnu"; sha256="${RUSTUP_SHA256_ARM64}" ;; \
        *) echo "unsupported architecture: ${arch}" >&2; exit 1 ;; \
    esac; \
    curl --fail --location --silent --show-error \
        --output /tmp/rustup-init \
        "https://static.rust-lang.org/rustup/archive/${RUSTUP_VERSION}/${rust_target}/rustup-init"; \
    printf '%s  %s\n' "${sha256}" /tmp/rustup-init | sha256sum --check --status; \
    chmod 0755 /tmp/rustup-init; \
    /tmp/rustup-init -y --no-modify-path --profile minimal --default-toolchain none; \
    rm -f /tmp/rustup-init

WORKDIR /app
COPY --from=source /src /app
RUN cd packages/paperclip-runner && rustup show

# Resolve manifest changes in the private build tree, then install from that
# exact generated lock. Matches the upstream Dockerfile's two-pass install.
RUN pnpm install --resolution-only --ignore-scripts --no-frozen-lockfile \
    && pnpm install --frozen-lockfile

ENV NODE_OPTIONS=--max-old-space-size=4096
RUN pnpm --filter @paperclipai/ui build \
    && pnpm --filter @paperclipai/plugin-sdk build \
    && pnpm --filter @paperclipai/server build \
    && test -f server/dist/index.js \
    && rm -rf packages/paperclip-runner/runner/target

# --- Runtime -----------------------------------------------------------------
FROM ${NODE_IMAGE} AS production

ARG CLI_TOOLS_CACHE_EPOCH=""

ENV DEBIAN_FRONTEND=noninteractive \
    HOME=/paperclip \
    NODE_ENV=production \
    HOST=0.0.0.0 \
    PORT=3100 \
    SERVE_UI=true \
    PAPERCLIP_HOME=/paperclip \
    PAPERCLIP_INSTANCE_ID=default \
    PAPERCLIP_CONFIG=/paperclip/instances/default/config.json \
    PAPERCLIP_DEPLOYMENT_MODE=authenticated \
    PAPERCLIP_DEPLOYMENT_EXPOSURE=private \
    OPENCODE_ALLOW_ALL_MODELS=true \
    GEMINI_SANDBOX=false \
    LANG=en_US.UTF-8 \
    LC_ALL=en_US.UTF-8

RUN echo "cli-tools-epoch: ${CLI_TOOLS_CACHE_EPOCH}" \
    && apt-get update \
    && apt-get install --yes --no-install-recommends \
        acl \
        attr \
        bash-completion \
        ca-certificates \
        curl \
        gh \
        git \
        gosu \
        jq \
        less \
        locales \
        nano \
        openssh-client \
        openssh-server \
        openssl \
        procps \
        python3 \
        ripgrep \
        rsync \
        tini \
        wget \
    && sed -i 's/^# en_US.UTF-8 UTF-8$/en_US.UTF-8 UTF-8/' /etc/locale.gen \
    && locale-gen \
    && npm install --global --omit=dev \
        @anthropic-ai/claude-code@latest \
        @openai/codex@latest \
        opencode-ai \
        @google/gemini-cli@latest \
        @moonshot-ai/kimi-code@latest \
    && printf '%s\n' \
        'PermitRootLogin no' \
        'PasswordAuthentication no' \
        'KbdInteractiveAuthentication no' \
        'UsePAM no' \
        'AllowUsers node' \
        > /etc/ssh/sshd_config.d/paperclip.conf \
    && mkdir --parents /app /paperclip/instances/default /paperclip/config /paperclip/.cache \
    && usermod --home /paperclip node \
    && chown --recursive node:node /paperclip \
    && rm -rf /var/lib/apt/lists/*

# Application tree built in the previous stage.
COPY --from=builder --chown=node:node /app /app

COPY docker/entrypoint.sh /usr/local/bin/paperclip-entrypoint
COPY docker/start-paperclip.sh /usr/local/bin/paperclip-start
COPY docker/load-paperclip-env.sh /usr/local/lib/paperclip/load-env.sh
RUN chmod 0755 /usr/local/bin/paperclip-entrypoint /usr/local/bin/paperclip-start \
    && chmod 0644 /usr/local/lib/paperclip/load-env.sh \
    && printf '%s\n' \
        'if [[ -r /usr/local/lib/paperclip/load-env.sh ]]; then' \
        '    source /usr/local/lib/paperclip/load-env.sh' \
        'fi' \
        >> /etc/bash.bashrc \
    && printf '%s\n' \
        'source /usr/local/lib/paperclip/load-env.sh' \
        > /etc/profile.d/paperclip-env.sh \
    && chmod 0644 /etc/profile.d/paperclip-env.sh

# Lifecycle hook executed by sndbx after the container starts.
COPY app.py /opt/sndbx-image/app.py
RUN chmod 0755 /opt/sndbx-image/app.py

WORKDIR /app

EXPOSE 3100

ENTRYPOINT ["/usr/bin/tini", "--", "/usr/local/bin/paperclip-entrypoint"]
CMD ["/usr/local/bin/paperclip-start"]
