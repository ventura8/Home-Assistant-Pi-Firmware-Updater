# Script to run tests locally using Docker, mirroring GitHub Actions

$ErrorActionPreference = "Stop"

function Invoke-NativeStep {
    param(
        [scriptblock]$Command
    )

    $previousErrorActionPreference = $ErrorActionPreference
    $ErrorActionPreference = "Continue"
    try {
        $output = & $Command 2>&1
        $exitCode = $LASTEXITCODE
        if ($null -ne $output) {
            $output | Out-Host
        }
        return $exitCode
    }
    finally {
        $ErrorActionPreference = $previousErrorActionPreference
    }
}

Write-Host "Building Docker environment..." -ForegroundColor Cyan
$exitCode = Invoke-NativeStep { docker build -t ha-updater-test -f tests/Dockerfile . }

if ($exitCode -ne 0) {
    Write-Error "Docker build failed."
    exit 1
}

Write-Host "Running Mandatory Lint/Format Suite..." -ForegroundColor Cyan
$exitCode = Invoke-NativeStep { docker run --rm -v ${PWD}:/work -w /work ha-updater-test /work/tests/run_tests.sh lint }
if ($exitCode -ne 0) {
    Write-Error "Lint/format suite failed."
    exit 1
}

Write-Host "Running All Tests (Unit, Component, E2E)..." -ForegroundColor Cyan
$exitCode = Invoke-NativeStep { docker run --rm ha-updater-test /app/tests/run_tests.sh tests }
if ($exitCode -ne 0) {
    Write-Error "Test suite failed."
    exit 1
}

Write-Host "Generating Coverage Reports..." -ForegroundColor Cyan
$exitCode = Invoke-NativeStep {
    docker run --rm -v ${PWD}/coverage:/app/coverage ha-updater-test `
        /app/tests/run_tests.sh coverage unit
}
if ($exitCode -ne 0) {
    Write-Error "Coverage run failed for unit suite."
    exit 1
}
$exitCode = Invoke-NativeStep {
    docker run --rm -v ${PWD}/coverage:/app/coverage ha-updater-test `
        /app/tests/run_tests.sh coverage component
}
if ($exitCode -ne 0) {
    Write-Error "Coverage run failed for component suite."
    exit 1
}
$exitCode = Invoke-NativeStep {
    docker run --rm -v ${PWD}/coverage:/app/coverage ha-updater-test `
        /app/tests/run_tests.sh coverage e2e
}
if ($exitCode -ne 0) {
    Write-Error "Coverage run failed for e2e suite."
    exit 1
}

Write-Host "Merging Coverage Reports..." -ForegroundColor Cyan
# Replicate the merge logic: kcov --merge output_dir input_dirs...
$exitCode = Invoke-NativeStep {
    docker run --rm -v ${PWD}/coverage:/app/coverage ha-updater-test `
        kcov --merge /app/coverage/merged `
        /app/coverage/unit /app/coverage/component /app/coverage/e2e
}
if ($exitCode -ne 0) {
    Write-Error "Coverage merge failed."
    exit 1
}

Write-Host "Updating Coverage Badge..." -ForegroundColor Cyan
# Run the transform script inside docker to generate the badge
# We mount the whole directory so it can write directly to assets/
$exitCode = Invoke-NativeStep {
    docker run --rm -v ${PWD}:/app ha-updater-test `
        python3 /app/tests/transform_coverage.py `
        /app/coverage/merged/kcov-merged/cobertura.xml `
        /app/assets/coverage.svg `
        /app/coverage/coverage-summary.md
}
if ($exitCode -ne 0) {
    Write-Error "Coverage transform failed."
    exit 1
}

Write-Host "Validating Coverage Threshold (>= 90%)..." -ForegroundColor Cyan
$coberturaPath = Join-Path $PWD "coverage/merged/kcov-merged/cobertura.xml"
if (-not (Test-Path $coberturaPath)) {
    Write-Error "Cobertura report not found at $coberturaPath"
    exit 1
}

[xml]$coverageXml = Get-Content -Path $coberturaPath
$lineRate = [double]$coverageXml.coverage.'line-rate'
$coveragePercent = [Math]::Round($lineRate * 100, 2)
if ($lineRate -lt 0.90) {
    Write-Error "Coverage threshold failed: $coveragePercent% < 90%"
    exit 1
}

$coverageSummaryPath = Join-Path $PWD "coverage/coverage-summary.md"
if (-not (Test-Path $coverageSummaryPath)) {
    Write-Error "Coverage summary not found at $coverageSummaryPath"
    exit 1
}

Write-Host "All tests and coverage generation passed!" -ForegroundColor Green
Write-Host "Coverage threshold validated: $coveragePercent%" -ForegroundColor Green
Write-Host "Coverage badge updated in assets/coverage.svg" -ForegroundColor Gray
Write-Host "Coverage and complexity summary:" -ForegroundColor Cyan
Get-Content -Path $coverageSummaryPath
