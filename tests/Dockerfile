ARG BASE_IMAGE=debian:bookworm-slim
FROM ${BASE_IMAGE}

ARG SHELLCHECK_VERSION=v0.11.0
ARG SHELLCHECK_SHA256=8c3be12b05d5c177a04c29e3c78ce89ac86f1595681cab149b65b97c4e227198
ARG YAMLLINT_VERSION=1.38.0
ARG LIZARD_VERSION=1.23.0
ARG SHFMT_VERSION=v3.13.1
ARG SHFMT_SHA256=fb096c5d1ac6beabbdbaa2874d025badb03ee07929f0c9ff67563ce8c75398b1
ARG HADOLINT_VERSION=v2.14.0
ARG HADOLINT_SHA256=6bf226944684f56c84dd014e8b979d27425c0148f61b3bd99bcc6f39e9dc5a47
ARG ACTIONLINT_VERSION=v1.7.12
ARG ACTIONLINT_SHA256=8aca8db96f1b94770f1b0d72b6dddcb1ebb8123cb3712530b08cc387b349a3d8
ARG MARKDOWNLINT_CLI_VERSION=0.49.1
ARG NODE_VERSION=22.21.0
ARG NODE_SHA256=71a04f4b9144870c9407b8019fe912514229e50246bc706862eded3ac8e9025d

# Install dependencies
RUN apt-get update && apt-get install -y \
    bash \
    bats \
    openssh-client \
    coreutils \
    dos2unix \
    ca-certificates \
    curl \
    xz-utils \
    python3-pip \
    # Build dependencies for kcov
    cmake \
    build-essential \
    pkg-config \
    libcurl4-openssl-dev \
    libelf-dev \
    libdw-dev \
    binutils-dev \
    libiberty-dev \
    zlib1g-dev \
    python3 \
    libssl-dev \
    wget \
    && rm -rf /var/lib/apt/lists/*

# Install shellcheck, shfmt, hadolint, and actionlint as pinned binaries.
RUN curl -fsSL \
    --retry 6 --retry-delay 2 --retry-all-errors \
    "https://github.com/koalaman/shellcheck/releases/download/${SHELLCHECK_VERSION}/shellcheck-${SHELLCHECK_VERSION}.linux.x86_64.tar.xz" \
    -o /tmp/shellcheck.tar.xz && \
    echo "${SHELLCHECK_SHA256}  /tmp/shellcheck.tar.xz" | sha256sum -c - && \
    tar -xJf /tmp/shellcheck.tar.xz -C /tmp && \
    mv "/tmp/shellcheck-${SHELLCHECK_VERSION}/shellcheck" /usr/local/bin/shellcheck && \
    chmod +x /usr/local/bin/shellcheck && \
    rm -rf /tmp/shellcheck* && \
    curl -fsSL \
    --retry 6 --retry-delay 2 --retry-all-errors \
    "https://github.com/mvdan/sh/releases/download/${SHFMT_VERSION}/shfmt_${SHFMT_VERSION}_linux_amd64" \
    -o /usr/local/bin/shfmt && \
    echo "${SHFMT_SHA256}  /usr/local/bin/shfmt" | sha256sum -c - && \
    chmod +x /usr/local/bin/shfmt && \
    curl -fsSL \
    --retry 6 --retry-delay 2 --retry-all-errors \
    "https://github.com/hadolint/hadolint/releases/download/${HADOLINT_VERSION}/hadolint-linux-x86_64" \
    -o /usr/local/bin/hadolint && \
    echo "${HADOLINT_SHA256}  /usr/local/bin/hadolint" | sha256sum -c - && \
    chmod +x /usr/local/bin/hadolint && \
    ACTIONLINT_ARCHIVE="actionlint_${ACTIONLINT_VERSION#v}_linux_amd64.tar.gz" && \
    curl -fsSL \
    --retry 6 --retry-delay 2 --retry-all-errors \
    "https://github.com/rhysd/actionlint/releases/download/${ACTIONLINT_VERSION}/${ACTIONLINT_ARCHIVE}" \
    -o /tmp/actionlint.tar.gz && \
    echo "${ACTIONLINT_SHA256}  /tmp/actionlint.tar.gz" | sha256sum -c - && \
    tar -xzf /tmp/actionlint.tar.gz -C /tmp actionlint && \
    mv /tmp/actionlint /usr/local/bin/actionlint && \
    chmod +x /usr/local/bin/actionlint && \
    rm -rf /tmp/actionlint*

# Install a pinned Node.js runtime for markdownlint-cli.
RUN curl -fsSL --retry 6 --retry-delay 2 --retry-all-errors \
    "https://nodejs.org/dist/v${NODE_VERSION}/node-v${NODE_VERSION}-linux-x64.tar.xz" \
    -o /tmp/node.tar.xz && \
    echo "${NODE_SHA256}  /tmp/node.tar.xz" | sha256sum -c - && \
    tar -xJf /tmp/node.tar.xz -C /usr/local --strip-components=1 && \
    rm -f /tmp/node.tar.xz

# Install yamllint, lizard, and markdownlint-cli with pinned versions.
RUN pip3 install --no-cache-dir --break-system-packages \
    "yamllint==${YAMLLINT_VERSION}" \
    "lizard==${LIZARD_VERSION}" && \
    npm install --global "markdownlint-cli@${MARKDOWNLINT_CLI_VERSION}"

# Install kcov (Split steps for debugging)
WORKDIR /app
RUN wget https://github.com/SimonKagstrom/kcov/archive/refs/tags/v42.tar.gz -O kcov.tar.gz
RUN tar xzf kcov.tar.gz
WORKDIR /app/kcov-42/build
RUN cmake -DCMAKE_POLICY_VERSION_MINIMUM=3.5 ..
RUN make
RUN make install
WORKDIR /app
RUN rm -rf /app/kcov-42 /app/kcov.tar.gz

# Mock /config directory which install.sh expects
RUN mkdir -p /config/custom_components/pi_firmware_updater

# Create dummy yaml files that install.sh tries to modify
WORKDIR /config/custom_components/pi_firmware_updater
RUN touch update_notification.yaml action_handler.yaml

# Set working directory for tests
WORKDIR /app

# Copy project files
COPY . /app/

# Convert line endings for Windows compatibility
RUN find /app -type f -name "*.sh" -exec dos2unix {} + && \
    find /app -type f -name "*.bats" -exec dos2unix {} + && \
    find /app -type f -name "*.yaml" -exec dos2unix {} + && \
    find /app -type f -name "*.yml" -exec dos2unix {} + && \
    find /app -type f -name ".yamllint" -exec dos2unix {} + && \
    find /app/tests/mocks -type f -exec dos2unix {} +

# Add mocks to PATH
ENV PATH="/app/tests/mocks:$PATH"

# Make scripts executable
RUN chmod +x /app/custom_components/pi_firmware_updater/*.sh && \
    chmod +x /app/tests/mocks/* && \
    chmod +x /app/tests/run_tests.sh

CMD ["/app/tests/run_tests.sh"]
