# Testing & Quality Standards

## Mandatory Code Coverage

- **Threshold:** Minimum **90%** coverage for all Bash scripts.
- **Enforcement:** The CI pipeline (`test.yml`) will fail if coverage falls below 90%.

## GitHub Releases

Pushing an annotated `vX.Y.Z` tag runs `.github/workflows/release.yml`, which:

1. Checks out that tag and verifies `manifest.json` `"version"` matches `X.Y.Z`.
2. Requires `docs/releases/vX.Y.Z_github_description.md`.
3. Publishes a GitHub Release whose title is the file’s H1 and whose body is
   the file contents.

To backfill an existing tag: Actions → **Publish GitHub Release** → Run workflow
(or `gh workflow run release.yml -f tag=vX.Y.Z`). Coverage badges are still
updated only locally — not by this workflow.

## Local Development Workflow

Coverage badges are **not** updated by the CI pipeline. They must be updated locally before committing changes.

### Running Tests and Updating Badge

To run all tests and update the coverage badge in `assets/coverage.svg`, use the provided PowerShell script:

```powershell
./scripts/run_local_tests.ps1
```

This script will:

1. Build the Docker test environment.
2. Run the mandatory lint and formatter gate via `./tests/run_tests.sh lint`.
3. The lint and formatter gate includes: ShellCheck, cyclomatic complexity enforcement, shfmt (check mode), YamlLint, markdownlint (Markdown line-length excluded), hadolint, actionlint, JSON manifest validation, and a non-Markdown max line-length check (140).
4. Execute all Bats test suites (Unit, Component, E2E).
5. Generate and merge coverage reports.
6. Update `assets/coverage.svg` using `tests/transform_coverage.py`.
7. Generate `coverage/coverage-summary.md` with overall and per-file coverage and complexity, then print that summary at the end of the local run.

## Mandatory Lint and Formatting Policy

- **Maximum line length:** 140 characters for all non-Markdown files.
- **Maximum cyclomatic complexity per function:** 10.
- **Markdown exception:** Markdown line-length is not enforced.
- **No suppressions:** Do not disable lint rules to pass checks.

### Committing Changes

Always ensure you commit the updated `assets/coverage.svg` along with your code changes.

## SonarQube Cloud Analysis

Static analysis runs on SonarQube Cloud (organization `ventura8`, project key
`ventura8_Home-Assistant-Pi-Firmware-Updater`). Configuration lives in
`sonar-project.properties`.

### Analysis modes

Exactly one mode can be active at a time; SonarQube Cloud rejects a CI analysis while
Automatic Analysis is enabled.

**Automatic Analysis (current).** SonarQube Cloud scans `main` and pull requests
server-side. It needs no token and no CI job, but it cannot import coverage, so the
project shows 0% coverage on SonarQube Cloud. The kcov coverage gate in `test.yml` is
unaffected and still enforces the 90% threshold.

**CI-based (needed for coverage import).** The `sonarqube` job in `test.yml` runs after
`report-coverage` and uploads the merged kcov report in SonarQube's Generic Test
Coverage format. Because kcov records container-absolute paths (`/app/...`), the
pipeline rewrites them to repository-relative paths before the scan.

The job is gated on the `SONAR_CI_ANALYSIS` repository variable so it stays inert until
the switchover. To switch:

1. Create a token at **My Account -> Security** on SonarQube Cloud.
2. `gh secret set SONAR_TOKEN`
3. `gh variable set SONAR_CI_ANALYSIS --body true`
4. Turn off **Administration -> Analysis Method -> Automatic Analysis** for the project.

### Running Locally

```bash
SONAR_TOKEN=<token> ./scripts/sonar_scan.sh
```

The script runs `sonarsource/sonar-scanner-cli` in Docker, so no local Java or scanner
install is needed. It reads the token from `~/.sonar_token` when `SONAR_TOKEN` is unset.
Run the coverage suites first if you want coverage included in the analysis.

## Tools

- **Bats-core:** Bash Automated Testing System.
- **kcov:** Code coverage tool for Bash.
- **Docker:** Used to provide a consistent test environment.
- **ShellCheck:** Linting for Bash scripts.
- **shfmt:** Formatting checks for Bash and Bats files.
- **YamlLint:** Linting for YAML configuration files.
- **markdownlint-cli:** Markdown linting checks.
- **hadolint:** Dockerfile linting checks.
- **actionlint:** GitHub Actions workflow linting checks.
- **SonarQube Cloud:** Continuous static analysis for bugs, code smells, security hotspots, and coverage tracking.
