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
docker run --rm -v ${PWD}/coverage:/app/coverage ha-updater-test kcov --merge /app/coverage/merged /app/coverage/unit /app/coverage/component /app/coverage/e2e

Write-Host "Updating Coverage Badge..." -ForegroundColor Cyan
# Run the transform script inside docker to generate the badge
# We mount the whole directory so it can write directly to assets/
docker run --rm -v ${PWD}:/app ha-updater-test python3 /app/tests/transform_coverage.py /app/coverage/merged/kcov-merged/cobertura.xml /app/assets/coverage.svg

Write-Host "All tests and coverage generation passed!" -ForegroundColor Green
Write-Host "Coverage badge updated in assets/coverage.svg" -ForegroundColor Gray
