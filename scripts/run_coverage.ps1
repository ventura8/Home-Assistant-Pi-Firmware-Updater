# Script to run coverage locally using Docker

$ErrorActionPreference = "Stop"

# The image runs as an unprivileged user; on Linux match the host UID/GID so
# bind-mounted directories stay writable (Docker Desktop does not need this).
$buildArgs = @()
if ($IsLinux) {
    $buildArgs = @("--build-arg", "TEST_UID=$(id -u)", "--build-arg", "TEST_GID=$(id -g)")
}

Write-Host "Building Docker environment..." -ForegroundColor Cyan
docker build @buildArgs -t ha-updater-test -f tests/Dockerfile .

if ($LASTEXITCODE -ne 0) {
    Write-Error "Docker build failed."
    exit 1
}

Write-Host "Running coverage for all suites..." -ForegroundColor Cyan
if (Test-Path -Path coverage) {
    Remove-Item -Path coverage -Recurse -Force
}
$null = New-Item -ItemType Directory -Path coverage -Force
# Run suites
docker run --rm -v ${PWD}/coverage:/app/coverage ha-updater-test `
    /app/tests/run_tests.sh coverage unit
docker run --rm -v ${PWD}/coverage:/app/coverage ha-updater-test `
    /app/tests/run_tests.sh coverage component
docker run --rm -v ${PWD}/coverage:/app/coverage ha-updater-test `
    /app/tests/run_tests.sh coverage e2e

Write-Host "Merging Coverage Reports..." -ForegroundColor Cyan
docker run --rm -v ${PWD}/coverage:/app/coverage ha-updater-test `
    kcov --merge /app/coverage/merged `
    /app/coverage/unit /app/coverage/component /app/coverage/e2e

Write-Host "Updating Coverage Badge..." -ForegroundColor Cyan
docker run --rm -v ${PWD}:/app ha-updater-test `
    python3 /app/tests/transform_coverage.py `
    /app/coverage/merged/kcov-merged/cobertura.xml `
    /app/assets/coverage.svg

Write-Host "Coverage report generated in ./coverage/merged" -ForegroundColor Green
Write-Host "Coverage badge updated in assets/coverage.svg" -ForegroundColor Gray
