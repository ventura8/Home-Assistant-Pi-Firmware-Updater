# Script to run coverage locally using Docker

$ErrorActionPreference = "Stop"

Write-Host "Building Docker environment..." -ForegroundColor Cyan
docker build -t ha-updater-test -f tests/Dockerfile .

if ($LASTEXITCODE -ne 0) {
    Write-Error "Docker build failed."
    exit 1
}

Write-Host "Running coverage for all suites..." -ForegroundColor Cyan
mkdir -p coverage
# Run suites
docker run --rm -v ${PWD}/coverage:/app/coverage ha-updater-test /app/tests/run_tests.sh coverage unit
docker run --rm -v ${PWD}/coverage:/app/coverage ha-updater-test /app/tests/run_tests.sh coverage component
docker run --rm -v ${PWD}/coverage:/app/coverage ha-updater-test /app/tests/run_tests.sh coverage e2e

Write-Host "Merging Coverage Reports..." -ForegroundColor Cyan
docker run --rm -v ${PWD}/coverage:/app/coverage ha-updater-test kcov --merge /app/coverage/merged /app/coverage/unit /app/coverage/component /app/coverage/e2e

Write-Host "Updating Coverage Badge..." -ForegroundColor Cyan
docker run --rm -v ${PWD}:/app ha-updater-test python3 /app/tests/transform_coverage.py /app/coverage/merged/kcov-merged/cobertura.xml /app/assets/coverage.svg

Write-Host "Coverage report generated in ./coverage/merged" -ForegroundColor Green
Write-Host "Coverage badge updated in assets/coverage.svg" -ForegroundColor Gray
