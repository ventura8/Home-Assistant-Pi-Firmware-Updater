ARG BASE_IMAGE=debian:bookworm-slim
FROM ${BASE_IMAGE}

# Install dependencies
RUN apt-get update && apt-get install -y \
    bash \
    bats \
    openssh-client \
    coreutils \
    shellcheck \
    yamllint \
    dos2unix \
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

# Install kcov (Split steps for debugging)
WORKDIR /app
RUN wget https://github.com/SimonKagstrom/kcov/archive/refs/tags/v42.tar.gz -O kcov.tar.gz
RUN tar xzf kcov.tar.gz
WORKDIR /app/kcov-42/build
RUN cmake ..
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
