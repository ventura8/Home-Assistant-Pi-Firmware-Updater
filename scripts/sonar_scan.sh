#!/bin/bash
# Run a SonarQube Cloud analysis of this repository.
#
# Usage:
#   SONAR_TOKEN=<token> ./scripts/sonar_scan.sh
#
# The scanner runs in Docker so no local Java/sonar-scanner install is needed.
# If a merged kcov report exists, its container-absolute paths are rewritten to
# repository-relative paths so SonarQube Cloud can match them to source files.
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SCANNER_IMAGE="${SCANNER_IMAGE:-sonarsource/sonar-scanner-cli:11}"
COVERAGE_REPORT="${REPO_ROOT}/coverage/merged/kcov-merged/sonarqube.xml"

TOKEN_FILE="${SONAR_TOKEN_FILE:-${HOME}/.sonar_token}"
if [ -z "${SONAR_TOKEN:-}" ] && [ -r "$TOKEN_FILE" ]; then
    SONAR_TOKEN="$(tr -d '[:space:]' < "$TOKEN_FILE")"
    export SONAR_TOKEN
fi

if [ -z "${SONAR_TOKEN:-}" ]; then
    echo "SONAR_TOKEN is not set and ${TOKEN_FILE} is unreadable." >&2
    echo "Create a token at https://sonarcloud.io/account/security" >&2
    exit 1
fi

function normalise_coverage_paths {
    if [ ! -f "$COVERAGE_REPORT" ]; then
        echo "No merged coverage report at ${COVERAGE_REPORT}; running analysis without coverage."
        return 0
    fi

    echo "Rewriting coverage paths in ${COVERAGE_REPORT}..."
    sed -i 's#path="/app/#path="#g' "$COVERAGE_REPORT"
}

function run_scanner {
    echo "Running SonarQube Cloud scanner (${SCANNER_IMAGE})..."
    docker run --rm \
        -e SONAR_TOKEN \
        -e SONAR_HOST_URL="${SONAR_HOST_URL:-https://sonarcloud.io}" \
        -v "${REPO_ROOT}:/usr/src" \
        "$SCANNER_IMAGE"
}

normalise_coverage_paths
run_scanner
