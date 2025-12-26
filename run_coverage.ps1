# Script to run coverage locally using Docker

$ErrorActionPreference = "Stop"

Write-Host "Building Docker environment..." -ForegroundColor Cyan
docker build -t ha-updater-test -f tests/Dockerfile .

if ($LASTEXITCODE -ne 0) {
    Write-Error "Docker build failed."
    exit 1
}

Write-Host "Running tests with coverage..." -ForegroundColor Cyan
# Mount current directory to /app/coverage to extract the report
mkdir -p coverage_report
docker run --rm -v ${PWD}/coverage_report:/app/coverage ha-updater-test /app/tests/run_tests.sh coverage

if ($LASTEXITCODE -ne 0) {
    Write-Error "Coverage tests failed."
    exit 1
}

Write-Host "Coverage report generated in ./coverage_report" -ForegroundColor Green
Write-Host "Open ./coverage_report/index.html to view results." -ForegroundColor Gray
