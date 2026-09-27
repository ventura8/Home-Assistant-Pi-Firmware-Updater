# syntax=docker/dockerfile:1
ARG BASE_IMAGE=debian:bookworm-slim
FROM ${BASE_IMAGE}

ARG SHELLCHECK_VERSION=v0.11.0
ARG SHELLCHECK_SHA256=8c3be12b05d5c177a04c29e3c78ce89ac86f1595681cab149b65b97c4e227198
ARG YAMLLINT_VERSION=1.38.0
ARG LIZARD_VERSION=1.24.0
ARG SHFMT_VERSION=v3.14.1
ARG SHFMT_SHA256=76e77641faa025814b77f153b29796b8e6fa2fca03e0c76a691608b86c7ea7bf
ARG HADOLINT_VERSION=v2.15.1
ARG HADOLINT_SHA256=c7187db94eeeeca956519a6af171adc31453941a1e777961f6e680f697c8c507
ARG ACTIONLINT_VERSION=v1.7.12
ARG ACTIONLINT_SHA256=8aca8db96f1b94770f1b0d72b6dddcb1ebb8123cb3712530b08cc387b349a3d8
ARG MARKDOWNLINT_CLI_VERSION=0.49.1
ARG NODE_VERSION=26.10.0
ARG NODE_SHA256=ca70e9e349de048b9522abb3adc05b3bd6f43c5ffd3ec57916c7da292f59f022
ARG KCOV_VERSION=v43
ARG KCOV_SHA256=4cbba86af11f72de0c7514e09d59c7927ed25df7cebdad087f6d3623213b95bf
# Unprivileged test user. The default matches the GitHub-hosted runner user so
# bind-mounted coverage directories stay writable; override on other hosts.
ARG TEST_UID=1001
ARG TEST_GID=1001

# Fetch pinned tool artifacts; ADD --checksum verifies every download.
ADD --checksum=sha256:${SHELLCHECK_SHA256} \
    "https://github.com/koalaman/shellcheck/releases/download/${SHELLCHECK_VERSION}/shellcheck-${SHELLCHECK_VERSION}.linux.x86_64.tar.xz" \
    /tmp/tools/shellcheck.tar.xz
ADD --checksum=sha256:${SHFMT_SHA256} --chmod=755 \
    "https://github.com/mvdan/sh/releases/download/${SHFMT_VERSION}/shfmt_${SHFMT_VERSION}_linux_amd64" \
    /usr/local/bin/shfmt
ADD --checksum=sha256:${HADOLINT_SHA256} --chmod=755 \
    "https://github.com/hadolint/hadolint/releases/download/${HADOLINT_VERSION}/hadolint-linux-x86_64" \
    /usr/local/bin/hadolint
ADD --checksum=sha256:${ACTIONLINT_SHA256} \
    "https://github.com/rhysd/actionlint/releases/download/${ACTIONLINT_VERSION}/actionlint_${ACTIONLINT_VERSION#v}_linux_amd64.tar.gz" \
    /tmp/tools/actionlint.tar.gz
ADD --checksum=sha256:${NODE_SHA256} \
    "https://nodejs.org/dist/v${NODE_VERSION}/node-v${NODE_VERSION}-linux-x64.tar.xz" \
    /tmp/tools/node.tar.xz
ADD --checksum=sha256:${KCOV_SHA256} \
    "https://github.com/SimonKagstrom/kcov/archive/refs/tags/${KCOV_VERSION}.tar.gz" \
    /tmp/tools/kcov.tar.gz

# Install system packages, unpack the pinned tools (shellcheck, actionlint,
# Node.js for markdownlint-cli), install yamllint/lizard/markdownlint-cli,
# build kcov, then create the unprivileged test user and hand it the paths the
# suites write to: the mock /config tree (with the dummy YAML files install.sh
# modifies), the host_check.sh log, and /root, which stands in for the Home
# Assistant host's root home that ssh_wrapper.sh manages.
RUN apt-get update && apt-get install -y --no-install-recommends \
    bash \
    bats \
    binutils-dev \
    build-essential \
    ca-certificates \
    cmake \
    coreutils \
    curl \
    dos2unix \
    libcurl4-openssl-dev \
    libdw-dev \
    libelf-dev \
    libiberty-dev \
    libssl-dev \
    openssh-client \
    pkg-config \
    python3 \
    python3-pip \
    xz-utils \
    zlib1g-dev \
    && rm -rf /var/lib/apt/lists/* && \
    tar -xJf /tmp/tools/shellcheck.tar.xz -C /tmp/tools && \
    install -m 755 "/tmp/tools/shellcheck-${SHELLCHECK_VERSION}/shellcheck" /usr/local/bin/shellcheck && \
    tar -xzf /tmp/tools/actionlint.tar.gz -C /tmp/tools actionlint && \
    install -m 755 /tmp/tools/actionlint /usr/local/bin/actionlint && \
    tar -xJf /tmp/tools/node.tar.xz -C /usr/local --strip-components=1 && \
    pip3 install --no-cache-dir --break-system-packages --only-binary :all: \
    "lizard==${LIZARD_VERSION}" \
    "yamllint==${YAMLLINT_VERSION}" && \
    npm install --global --ignore-scripts "markdownlint-cli@${MARKDOWNLINT_CLI_VERSION}" && \
    mkdir -p /tmp/tools/kcov && \
    tar -xzf /tmp/tools/kcov.tar.gz -C /tmp/tools/kcov --strip-components=1 && \
    cmake -DCMAKE_POLICY_VERSION_MINIMUM=3.5 -S /tmp/tools/kcov -B /tmp/tools/kcov/build && \
    cmake --build /tmp/tools/kcov/build && \
    cmake --install /tmp/tools/kcov/build && \
    rm -rf /tmp/tools && \
    groupadd --non-unique --gid "${TEST_GID}" tester && \
    useradd --non-unique --uid "${TEST_UID}" --gid "${TEST_GID}" --create-home --shell /bin/bash tester && \
    mkdir -p /config/custom_components/pi_firmware_updater /app/coverage && \
    touch /config/custom_components/pi_firmware_updater/update_notification.yaml \
    /config/custom_components/pi_firmware_updater/action_handler.yaml \
    /var/log/pi_firmware_update.log && \
    chown -R tester:tester /config /app /root /var/log/pi_firmware_update.log

# Set working directory for tests
WORKDIR /app

# Copy only what the in-image test suites need (lint runs against a mounted
# workspace instead).
COPY --chown=tester:tester custom_components /app/custom_components
COPY --chown=tester:tester tests /app/tests

USER ${TEST_UID}:${TEST_GID}

# Add mocks to PATH
ENV PATH="/app/tests/mocks:$PATH"

# Convert line endings for Windows compatibility and make scripts executable
RUN find /app -type f \( -name "*.sh" -o -name "*.bats" -o -name "*.yaml" -o -name "*.yml" \) \
    -exec dos2unix {} + && \
    find /app/tests/mocks -type f -exec dos2unix {} + && \
    chmod +x /app/custom_components/pi_firmware_updater/*.sh && \
    chmod +x /app/tests/mocks/* && \
    chmod +x /app/tests/run_tests.sh

CMD ["/app/tests/run_tests.sh"]
