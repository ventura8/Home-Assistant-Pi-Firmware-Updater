# Script to run tests locally using Docker, mirroring GitHub Actions

$ErrorActionPreference = "Stop"

Write-Host "Building Docker environment..." -ForegroundColor Cyan
docker build -t ha-updater-test -f tests/Dockerfile .

if ($LASTEXITCODE -ne 0) {
    Write-Error "Docker build failed."
    exit 1
}

docker run --rm ha-updater-test /app/tests/run_tests.sh shellcheck

docker run --rm ha-updater-test /app/tests/run_tests.sh yamllint

Write-Host "Running All Tests (Unit, Component, E2E)..." -ForegroundColor Cyan
docker run --rm ha-updater-test /app/tests/run_tests.sh tests

Write-Host "Generating Coverage Reports..." -ForegroundColor Cyan
docker run --rm -v ${PWD}/coverage:/app/coverage ha-updater-test /app/tests/run_tests.sh coverage unit
docker run --rm -v ${PWD}/coverage:/app/coverage ha-updater-test /app/tests/run_tests.sh coverage component
docker run --rm -v ${PWD}/coverage:/app/coverage ha-updater-test /app/tests/run_tests.sh coverage e2e

Write-Host "Merging Coverage Reports..." -ForegroundColor Cyan
# Replicate the merge logic: kcov --merge output_dir input_dirs...
# The input dirs in the container are /app/coverage/unit, /app/coverage/component, etc.
docker run --rm -v ${PWD}/coverage:/app/coverage ha-updater-test kcov --merge /app/coverage/merged /app/coverage/unit /app/coverage/component /app/coverage/e2e

Write-Host "All tests and coverage generation passed!" -ForegroundColor Green
